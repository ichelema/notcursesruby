# Generated from notcurses 3.0.17
# Source: notcurses/src/lib/notcurses.c
# frozen_string_literal: true

# Studio ICH-601: prototipo di un helper che esegue un job in un Ractor e
# consegna il risultato al ciclo di Notcurses::UI::EventLoop con post. Il
# wrapper e notcurses restano nel Ractor principale (regola 3): il Ractor fa
# solo calcolo su dati Ruby e restituisce dati Ruby.
#
#   bg = ProtoBackground.new(app)
#   job = bg.start(Jobs::PlotData, csv, on_error: show) { |samples| plot.add(samples) }
#   job.cancel
#   bg.cancel_all # all'uscita di run
#
# Lo schema viene dai fatti di facts.rb, uguali su Ruby 3.1.7, 3.4.12 e 4.0.7
# salvo dove è scritto:
#
# - Ractor#take (3.x), Ractor#value e Ractor::Port#receive (4.0) non passano
#   dagli hook del Fiber scheduler: in un task di app.async fermano tutto il
#   ciclo. L'attesa sta in un thread.
# - Su 3.1.7 e 3.4.12 due thread del Ractor principale che attendono insieme
#   un'operazione di Ractor (take, receive) si bloccano per sempre (4.0.7 no).
#   Quindi un solo thread di consegna per processo, che riceve i risultati
#   dal canale dei risultati: ogni job ci manda il suo messaggio.
# - Il risultato passa con move: true. Il costo lo paga soprattutto il
#   Ractor che manda: il thread del ciclo si ferma al massimo 4-14 ms per un
#   Array di 200 000 String (compute.rb e lo studio).
#
# Limite, solo su Ruby 3.x (che non ha Ractor::Port): il canale è la coda di
# Ractor.main, una sola per processo. Un'applicazione che usa Ractor.receive
# nel Ractor principale prende anche i messaggi dei job, e la sua attesa si
# blocca con quella del thread di consegna. Su Ruby 4.0 il canale è un Port.
class ProtoBackground
  # Chiave della memoria locale del Ractor che il job controlla con
  # ProtoBackground.cancelled?.
  CANCEL_KEY = :notcurses_cancel

  # Canale dei risultati. Su Ruby 4.0 un Ractor::Port dedicato: la coda di
  # Ractor.main resta all'applicazione. Su Ruby 3.x, che non ha Port, la coda
  # di Ractor.main. Ractor::Port.new non scrive warning.
  CHANNEL = defined?(Ractor::Port) ? Ractor::Port.new : Ractor.main
  RECEIVE = defined?(Ractor::Port) ? -> { CHANNEL.receive } : -> { Ractor.receive }

  # Corpo di ogni Ractor. Ractor.new isola il blocco: niente variabili
  # esterne. Il thread interno riceve il messaggio di cancellazione e alza il
  # flag che il job controlla. Il rescue tiene l'eccezione del job fuori da
  # stderr (senza, Ruby scrive "terminated with exception" sullo schermo) e
  # la manda al Ractor principale, come un risultato che non si può spostare.
  # La copia di un'eccezione arriva con il backtrace vuoto (Ruby 3.1-4.0), e
  # su Ruby 3.x NoMethodError e NameError non si copiano (allocator undefined
  # for RubyVM::InstructionSequence): il backtrace viaggia a parte, e la
  # classe (StandardError o no) si decide qui, sull'eccezione originale,
  # prima dell'eventuale RuntimeError sostitutivo.
  RUNNER = proc do |out, id, job, *args|
    Thread.new do # rubocop:disable ThreadSafety/NewThread -- riceve la cancellazione dentro il Ractor
      Ractor.receive
      Ractor.current[:notcurses_cancel] = true
    end
    begin
      out.send([id, :ok, job.call(*args)], move: true)
    rescue Exception => e # rubocop:disable Lint/RescueException -- anche le Exception del job tornano al ciclo
      trace = e.backtrace
      standard = e.is_a?(StandardError)
      begin
        out.send([id, :error, e, trace, standard])
      rescue Exception # rubocop:disable Lint/RescueException -- un'eccezione che non si può copiare
        out.send([id, :error, RuntimeError.new("#{e.class}: #{e.message}"), trace, standard])
      end
    end
    nil
  end

  # Il job che un Ractor esegue: per il job, true dopo Job#cancel.
  def self.cancelled? = Ractor.current[CANCEL_KEY] ? true : false

  @lock = Mutex.new
  # id => [Job, ProtoBackground]: i job il cui messaggio non è ancora arrivato, sotto @lock
  @jobs = {} # rubocop:disable ThreadSafety/MutableClassInstanceVariable -- tabella che cambia, protetta da @lock
  @next_id = 0
  @dispatcher = nil

  class << self
    # Registra un job e avvia il thread di consegna al primo job.
    def register(job, owner)
      @lock.synchronize do
        @dispatcher ||= Thread.new { dispatch } # rubocop:disable ThreadSafety/NewThread -- consegna dei risultati
        id = (@next_id += 1)
        @jobs[id] = [job, owner]
        id
      end
    end

    def unregister(id) = @lock.synchronize { @jobs.delete(id) }

    private

    def dispatch
      loop do
        id, status, value, trace, standard = RECEIVE.call
        job, owner = @lock.synchronize { @jobs.delete(id) }
        next unless job

        value.set_backtrace(trace) if status == :error && trace
        owner.deliver(job, status, value, standard)
      end
    end
  end

  # Un job avviato da #start.
  class Job
    attr_accessor :ractor
    attr_reader :on_result, :on_error

    def initialize(on_result, on_error)
      @on_result = on_result
      @on_error = on_error
      @ractor = nil
      @lock = Mutex.new
      @state = :running # :running, :cancelled, :done
    end

    # Chiede al job di fermarsi (se controlla ProtoBackground.cancelled?) e
    # scarta il risultato o l'errore. Dal thread del ciclo.
    def cancel
      @lock.synchronize do
        return self unless @state == :running

        @state = :cancelled
      end
      begin
        @ractor&.send(:cancel)
      rescue Ractor::ClosedError
        nil # il Ractor è già finito
      end
      self
    end

    def cancelled? = @lock.synchronize { @state == :cancelled }

    # Nel blocco di post: true se il risultato va consegnato.
    def finish = @lock.synchronize { (@state == :running) ? (@state = :done) : false }
  end

  # @param loop [Notcurses::UI::EventLoop, Notcurses::UI::App] riceve post
  def initialize(loop)
    @loop = loop
    @open = {} # Job => true: avviati e non ancora consegnati; solo dal thread del ciclo
  end

  # Avvia job.call(*args) in un Ractor nuovo e passa il risultato al blocco,
  # nel thread del ciclo. Uno StandardError del job va a on_error, nel thread
  # del ciclo; senza on_error, e per le altre eccezioni, esce da run, come
  # quella di un handler. Dopo Job#cancel non arrivano né il blocco né
  # on_error. Gli argomenti non frozen si copiano qui, nel thread del
  # chiamante: un input grande va passato frozen.
  def start(job, *args, on_error: nil, &on_result)
    raise ArgumentError, "start: serve un blocco" unless on_result
    raise ArgumentError, "start: il job deve rispondere a call ed essere condivisibile (un modulo)" unless
      job.respond_to?(:call) && Ractor.shareable?(job)
    raise TypeError, "on_error: deve rispondere a call, non #{on_error.class}" unless on_error.nil? || on_error.respond_to?(:call)

    handle = Job.new(on_result, on_error)
    id = self.class.register(handle, self)
    begin
      handle.ractor = new_ractor(id, job, args)
    rescue Exception # rubocop:disable Lint/RescueException -- per esempio un argomento che non si può copiare
      self.class.unregister(id)
      raise
    end
    @open[handle] = true
    handle
  end

  # All'uscita di run: cancella i job non ancora consegnati, anche quelli il
  # cui risultato aspetta già nella coda di post. Non attende i Ractor: un
  # job che non controlla ProtoBackground.cancelled? finisce da solo, o
  # all'uscita del processo.
  def cancel_all
    @open.each_key(&:cancel)
    @open.clear
    self
  end

  # Dal thread di consegna. Il controllo della cancellazione sta nel blocco
  # di post: un cancel fra l'arrivo del messaggio e il giro del ciclo deve
  # valere, e la coda di post sopravvive a run.
  # @api private
  def deliver(job, status, value, standard)
    @loop.post do
      @open.delete(job)
      next unless job.finish

      if status == :ok
        job.on_result.call(value)
      elsif standard && job.on_error
        job.on_error.call(value)
      else
        raise value
      end
    end
  end

  private

  # Ruby scrive "Ractor is experimental" (3.x) o "Ractor API is experimental"
  # (4.0) su stderr al primo Ractor.new del processo, quando esiste solo il
  # Ractor principale: in un'applicazione a schermo intero il testo va sullo
  # schermo. Con la categoria spenta in quel momento Ruby non lo scrive più.
  def new_ractor(id, job, args)
    previous = Warning[:experimental]
    Warning[:experimental] = false
    begin
      Ractor.new(CHANNEL, id, job, *args, &RUNNER)
    ensure
      Warning[:experimental] = previous
    end
  end
end
