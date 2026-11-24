# Generated from notcurses 3.0.17
# Source: notcurses/src/lib/in.c
# frozen_string_literal: true

# Prototipo dello studio ICH-600: un Fiber scheduler minimo in Ruby puro, con
# IO.select, per Ruby 3.1-4.0. Non è il codice finale: implementa solo gli
# hook che servono alle misure di benchmark/fiber/run.rb (io_wait,
# kernel_sleep, block, unblock, fiber, close) e quelli che Ruby 4.0 chiede
# (fiber_interrupt, yield). Riprende i Fiber con resume e Fiber.yield: il
# design usa transfer, come io-event, perché Fiber.yield torna a chi ha fatto
# resume, che con Fiber annidati non è il ciclo.
#
# Il ciclo (#run) gira nel Fiber che lo chiama, di solito quello radice del
# thread, che è bloccante: IO.select e il blocco idle (il render) non passano
# dallo scheduler. I Fiber dell'applicazione sono non bloccanti: un'attesa li
# sospende con Fiber.yield e il ciclo li riprende con resume.
#
# unblock può arrivare da un altro thread o da un gestore trap: usa solo una
# Thread::Queue e write_nonblock sul pipe di risveglio, senza Mutex (dentro un
# trap Mutex#synchronize solleva ThreadError, fase3-design.md sezione 1).
class ProtoScheduler
  # Eccezione con cui #close sblocca i Fiber ancora in attesa. Non deriva da
  # StandardError: un rescue generico dell'applicazione non la ferma.
  class Stop < Exception; end # rubocop:disable Lint/InheritException

  # @param idle [#call, nil] chiamato nel Fiber del ciclo prima di ogni
  #   attesa, se dall'attesa precedente almeno un Fiber è ripartito, con
  #   true se il ciclo sta per attendere e false se un Fiber è ancora pronto
  #   (#pass): l'attesa avrà timeout 0
  def initialize(idle: nil)
    @idle = idle
    @readers = {} # io => fiber
    @writers = {} # io => fiber
    @deadlines = {} # fiber => scadenza (CLOCK_MONOTONIC, secondi)
    @blocked = {} # fiber => true, fermo in block o kernel_sleep
    @ready = Thread::Queue.new # Fiber sbloccati da unblock, anche da un altro thread
    @interrupts = Thread::Queue.new # [fiber, eccezione] di fiber_interrupt
    @wake_r, @wake_w = IO.pipe
    @ran = false
    silence_io_buffer_warning
  end

  # Esegue il ciclo finché il blocco restituisce true. Il blocco si controlla
  # dopo ogni giro: chi chiede l'uscita deve svegliare il ciclo (#wake).
  def run
    until yield
      resume_ready
      break if yield

      if @ran
        @ran = false
        @idle&.call(@ready.empty?)
      end
      select_once
    end
  end

  # Sveglia il ciclo da qualsiasi thread, anche da un trap.
  def wake = @wake_w.write_nonblock(".", exception: false)

  # Hook: attende che io sia pronto per events, al massimo timeout secondi.
  # @return [Integer, false] gli eventi pronti, o false a timeout scaduto
  def io_wait(io, events, timeout)
    fiber = Fiber.current
    @readers[io] = fiber if events.anybits?(IO::READABLE)
    @writers[io] = fiber if events.anybits?(IO::WRITABLE)
    @deadlines[fiber] = clock + timeout if timeout
    Fiber.yield
  ensure
    @readers.delete(io) if @readers[io].equal?(fiber)
    @writers.delete(io) if @writers[io].equal?(fiber)
    @deadlines.delete(fiber)
  end

  # Hook: sleep in un Fiber non bloccante.
  def kernel_sleep(duration = nil)
    block(:sleep, duration)
    true
  end

  # Hook: Mutex, Queue, ConditionVariable e join in un Fiber non bloccante.
  # @return [Boolean] true se sbloccato, false a timeout scaduto
  def block(_blocker, timeout = nil)
    fiber = Fiber.current
    @blocked[fiber] = true
    @deadlines[fiber] = clock + timeout if timeout
    Fiber.yield
  ensure
    @blocked.delete(fiber)
    @deadlines.delete(fiber)
  end

  # Hook: sblocca fiber; si può chiamare da qualsiasi thread.
  def unblock(_blocker, fiber)
    @ready.push(fiber)
    wake
  end

  # Cede il ciclo: gli altri Fiber pronti, il render e l'attesa dell'I/O
  # (senza timeout) girano prima che il Fiber corrente riparta. Serve a un
  # Fiber che legge un flusso sempre pronto, che altrimenti non passa mai
  # da io_wait e ferma il ciclo.
  def pass
    fiber = Fiber.current
    @blocked[fiber] = true
    @ready.push(fiber)
    Fiber.yield
  ensure
    @blocked.delete(fiber)
  end

  # Hook di Ruby 4.0, dopo un segnale gestito in un punto bloccante
  # (thread.c): cede il ciclo come #pass. Senza, Ruby chiama kernel_sleep(0).
  def yield = pass

  # Hook di Ruby 4.0: per esempio IO#close di un IO su cui fiber attende.
  # Ruby lo chiama con gli interrupt mascherati, anche da un altro thread,
  # e senza l'hook scrive un warning a Fiber.set_scheduler: l'eccezione la
  # solleva il ciclo, come fa async (FiberInterrupt in scheduler.rb).
  def fiber_interrupt(fiber, exception)
    @interrupts.push([fiber, exception])
    wake
  end

  # Hook di Fiber.schedule: il blocco parte subito, fino alla prima attesa.
  def fiber(&block)
    fiber = Fiber.new(blocking: false, &block)
    @ran = true
    fiber.resume
    fiber
  end

  # Hook: Fiber.set_scheduler(nil) e la fine del thread. Non esegue i Fiber
  # in attesa fino alla fine (un Fiber di input non finisce mai): li sblocca
  # con Stop, così i loro ensure girano. Se l'ensure di un Fiber solleva,
  # gli altri ricevono Stop lo stesso e close rilancia la prima eccezione,
  # dopo aver chiuso il pipe di risveglio.
  def close
    failure = nil
    waiting = (@readers.values + @writers.values + @deadlines.keys + @blocked.keys).uniq
    waiting.each do |fiber|
      fiber.raise(Stop) if fiber.alive?
    rescue Stop
      nil
    rescue Exception => e # rubocop:disable Lint/RescueException -- gli altri Fiber vanno fermati lo stesso
      failure ||= e
    end
    raise failure if failure
  ensure
    @wake_r.close
    @wake_w.close
  end

  private

  def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  def resume(fiber, value)
    @ran = true
    fiber.resume(value)
  end

  # Fiber sbloccati da unblock o fermi in #pass: solo quelli in coda
  # all'inizio, e solo se ancora fermi (un timeout può averli già ripresi).
  # Un Fiber che chiama pass di nuovo riparte al giro successivo, dopo il
  # render e l'attesa dell'I/O.
  def resume_ready
    @interrupts.size.times do
      fiber, exception = @interrupts.pop(true)
      next unless fiber.alive?

      @ran = true
      fiber.raise(exception) # un'eccezione non gestita dal Fiber esce da run
    end
    @ready.size.times do
      fiber = @ready.pop(true)
      resume(fiber, true) if @blocked.key?(fiber)
    end
  end

  # Ruby 4.0 crea un IO::Buffer per ogni scrittura da un Fiber non bloccante,
  # anche senza l'hook io_write (io.c, rb_io_write_memory), e il primo
  # IO::Buffer del processo scrive su stderr «IO::Buffer is experimental»:
  # in un'applicazione a schermo intero il testo finisce sullo schermo. Il
  # warning esce una volta sola per processo (flag static in io_buffer.c,
  # impostato anche con la categoria spenta): lo consuma qui, a categoria
  # spenta per un istante.
  def silence_io_buffer_warning
    return unless defined?(IO::Buffer)

    previous = Warning[:experimental]
    Warning[:experimental] = false
    IO::Buffer.new(1)
  ensure
    Warning[:experimental] = previous unless previous.nil?
  end

  def next_timeout
    return 0 unless @ready.empty?

    deadline = @deadlines.values.min
    deadline && [deadline - clock, 0].max
  end

  def select_once
    readable, writable = IO.select([@wake_r, *@readers.keys], @writers.keys, nil, next_timeout)
    events = Hash.new(0)
    readable&.each do |io|
      next drain_wake if io.equal?(@wake_r)

      fiber = @readers[io]
      events[fiber] |= IO::READABLE if fiber
    end
    writable&.each do |io|
      fiber = @writers[io]
      events[fiber] |= IO::WRITABLE if fiber
    end
    events.each { |fiber, ev| resume(fiber, ev) }
    expire
  end

  # Riprende con false i Fiber con la scadenza passata.
  def expire
    now = clock
    @deadlines.select { |_, deadline| deadline <= now }.each_key do |fiber|
      resume(fiber, false) if @deadlines[fiber]&.<=(now)
    end
  end

  def drain_wake
    loop do
      data = @wake_r.read_nonblock(4096, exception: false)
      break if data.nil? || data == :wait_readable
    end
  end
end
