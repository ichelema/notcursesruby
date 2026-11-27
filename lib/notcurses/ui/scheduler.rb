# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  module UI
    # Fiber scheduler di {EventLoop#run} (ICH-606): {EventLoop#run} lo
    # installa per la sua durata. I task sono i Fiber non bloccanti creati con
    # +Fiber.schedule+; quando attendono (I/O, sleep, Queue, Mutex, Timeout)
    # tornano al Fiber del ciclo, che li riprende nel giro in cui l'attesa
    # finisce. Gli handler girano sul Fiber del ciclo, che è bloccante: Ruby non
    # chiama gli hook da lì.
    #
    # I Fiber ripartono con transfer: Fiber.yield tornerebbe a chi ha fatto
    # resume, che con Fiber annidati non è il ciclo. Un task che finisce torna
    # al Fiber del ciclo, e un'eccezione che il task non gestisce esce lì, cioè
    # da {EventLoop#run}.
    #
    # Un'attesa torna al ciclo solo se il ciclo è fermo in un transfer verso
    # un task (@transferring). Un Fiber non bloccante che un handler riprende
    # con resume (per esempio Enumerator#next) attende invece in modo
    # bloccante, come senza scheduler: il Fiber del ciclo è fermo in resume, e
    # un transfer verso di lui solleverebbe FiberError. Le attese bloccanti usano
    # solo IO.select, che senza l'hook io_select non passa dallo scheduler.
    #
    # Ogni attesa ha un gettone ({Wait}): un risveglio riprende il task solo se
    # il gettone è ancora quello dell'attesa in corso, così un risveglio in
    # ritardo (un unblock dopo un timeout, un timer già passato) non riprende il
    # task in un'attesa diversa. Le scadenze sono timer interni di
    # {EventLoop}, che non contano come lavoro: il render lo decide il task
    # ripartito.
    #
    # Thread e trap. {#unblock} e {#fiber_interrupt} si chiamano anche da altri
    # thread e dai gestori +trap+: usano solo una Thread::Queue e un byte su un
    # pipe, senza Mutex. Gli altri metodi girano nel thread del ciclo.
    #
    # @api private
    class Scheduler
      # Eccezione con cui {#close} ferma i task ancora in attesa all'uscita di
      # run. Non deriva da StandardError: un +rescue => e+ del task non la
      # ferma, e il suo ensure gira.
      class Stop < Exception; end # rubocop:disable Lint/InheritException

      # Attesa in corso di un task. kind: :io (io_wait), :block (block),
      # :sleep (kernel_sleep), :ready (pronto a ripartire: yield, sleep(0), un
      # task che ha avviato un Fiber), :start (task non ancora partito).
      # unblock sveglia :block e :sleep.
      Wait = Struct.new(:fiber, :kind, :io, :events, :timer)
      # messaggio di Ruby per un'operazione su un IO chiuso
      CLOSED = "closed stream"
      private_constant :Wait, :CLOSED

      # {#io_sets} senza task in attesa di un IO: nessuna allocazione per giro
      NO_IO = [[].freeze, [].freeze, [].freeze].freeze

      # @return [Exception, nil] la prima eccezione uscita da un task durante
      #   {#close}
      attr_reader :failure

      # @param event_loop [EventLoop] il ciclo: timer interni e risveglio
      def initialize(event_loop)
        @event_loop = event_loop
        @thread = Thread.current
        @loop_fiber = Fiber.current
        @waits = {}.compare_by_identity # fiber => Wait in corso
        @ready = Thread::Queue.new # Wait pronti; Fiber di unblock, anche da altri thread
        @interrupts = Thread::Queue.new # [fiber, eccezione] di fiber_interrupt, anche da un altro thread
        @transferring = false # il Fiber del ciclo è fermo in un transfer verso un task
        @sync_fiber = nil # Fiber in un'attesa bloccante (vedi la classe)
        @sync_r = @sync_w = nil
        @failure = nil
        @ran = false
        @closing = false
        silence_io_buffer_warning
      end

      # Fiber del ciclo: i task che attendono tornano qui.
      attr_writer :loop_fiber

      # @return [Boolean] true se un task può ripartire senza attendere: il
      #   giro successivo del ciclo non attende
      def ready? = !(@ready.empty? && @interrupts.empty?)

      # @return [Boolean] true se un task è ripartito dall'ultima chiamata
      def ran!
        ran = @ran
        @ran = false
        ran
      end

      # IO che i task attendono, per IO.select. Un IO chiuso mentre un task
      # lo attende non va a IO.select, che solleverebbe IOError nel ciclo: il
      # task riceve IOError al giro successivo. Riprenderlo e basta non basta:
      # Ruby 3.4 richiama io_wait sull'IO chiuso senza sollevare, e il ciclo
      # girerebbe a vuoto.
      #
      # @return [Array(Array<IO>, Array<IO>, Array<IO>)] lettura, scrittura,
      #   priorità
      def io_sets
        return NO_IO if @waits.empty?

        sets = [[], [], []]
        @waits.each_value do |wait|
          next unless wait.kind == :io
          next @interrupts.push([wait.fiber, IOError.new(CLOSED)]) if wait.io.closed?

          sets[0] << wait.io if wait.events.anybits?(IO::READABLE)
          sets[1] << wait.io if wait.events.anybits?(IO::WRITABLE)
          sets[2] << wait.io if wait.events.anybits?(IO::PRIORITY)
        end
        sets
      end

      # Riprende i task: quelli con l'IO pronto, le eccezioni di
      # {#fiber_interrupt}, e i task pronti in coda all'inizio (un task che
      # cede di nuovo riparte al giro successivo, dopo il render e l'attesa).
      # Si ferma quando il blocco restituisce false.
      #
      # @param readable [Array<IO>, nil] IO pronti in lettura (IO.select)
      # @param writable [Array<IO>, nil] IO pronti in scrittura
      # @param priority [Array<IO>, nil] IO con dati prioritari
      # @yieldreturn [Boolean] true se il ciclo consegna ancora eventi
      # @return [void]
      # @raise [Exception] l'eccezione che un task non gestisce
      def resume_ready(readable = nil, writable = nil, priority = nil, &live)
        resume_io(readable, writable, priority, &live) if !@waits.empty? && (readable || writable || priority)
        resume_interrupts(&live) unless @interrupts.empty?
        @ready.size.times do
          break unless yield

          entry = @ready.pop(true)
          if entry.is_a?(Fiber)
            wait = @waits[entry]
            # anche :sleep: Mutex#sleep e ConditionVariable#wait passano da kernel_sleep, e unblock li sveglia
            resume(wait, true) if wait && %i[block sleep].include?(wait.kind)
          else
            resume(entry, (entry.kind == :io) ? entry.events : true)
          end
        end
      end

      # Hook: attende che io sia pronto per events.
      #
      # @param io [IO]
      # @param events [Integer] IO::READABLE, IO::WRITABLE, IO::PRIORITY
      # @param timeout [Numeric, nil] secondi, nil = senza limite
      # @return [Integer, false] gli eventi pronti, false a timeout scaduto
      # @raise [IOError] se io è chiuso
      def io_wait(io, events, timeout)
        raise IOError, CLOSED if io.closed?
        return sync_io_wait(io, events, timeout) unless @transferring

        wait(:io, timeout, false, io, events)
      end

      # Hook: Mutex, Queue, ConditionVariable e join in un task.
      #
      # @param _blocker [Object]
      # @param timeout [Numeric, nil] secondi, nil = senza limite
      # @return [Boolean] true se sbloccato da {#unblock}, false a timeout
      #   scaduto
      def block(_blocker, timeout = nil)
        return sync_wait(timeout) unless @transferring

        wait(:block, timeout, false)
      end

      # Hook: sblocca un task fermo in {#block} o in {#kernel_sleep} (per
      # esempio Mutex#sleep). Da qualsiasi thread e dai gestori +trap+.
      #
      # @param _blocker [Object]
      # @param fiber [Fiber]
      # @return [void]
      def unblock(_blocker, fiber)
        if fiber.equal?(@sync_fiber)
          begin
            @sync_w.write_nonblock("\0", exception: false)
          rescue IOError
            nil # pipe chiuso da close: l'attesa è già finita
          end
        else
          @ready.push(fiber)
          @event_loop.wake
        end
      end

      # Hook: sleep in un task. sleep(0) cede il ciclo come {#yield}.
      #
      # @param duration [Numeric, nil] secondi, nil = per sempre
      # @return [true]
      def kernel_sleep(duration = nil)
        if !@transferring
          sync_wait(duration)
        elsif duration&.zero?
          self.yield
        else
          wait(:sleep, duration, true)
        end
        true
      end

      # Hook: cede il ciclo agli altri task pronti, al render e all'attesa
      # dell'I/O (senza timeout). Ruby 4.0 lo chiama dopo un segnale gestito in
      # un punto bloccante (thread.c:207-235).
      #
      # @return [void]
      def yield
        return unless @transferring

        wait = Wait.new(Fiber.current, :ready)
        @ready.push(wait) unless @closing
        suspend(wait)
      end

      # Hook di Ruby 4.0: IO#close di un IO su cui fiber attende. Ruby lo
      # chiama con gli interrupt mascherati, anche da un altro thread; il ciclo
      # solleva exception nel task al giro successivo. Dopo l'hook IO#close
      # attende che l'operazione del task finisca (rb_thread_io_close_wait in
      # thread.c:2914-2928), e il task per finirla prende il mutex che close
      # tiene (thread.c:1826-1840). Se il ciclo non può girare (close da un
      # handler, o da un Fiber che un handler ha ripreso con resume), close
      # dormirebbe per sempre: lì l'hook solleva Error, che esce da IO#close;
      # l'IO resta aperto, e un close dopo la fine del task lo chiude.
      #
      # @param fiber [Fiber]
      # @param exception [Exception]
      # @return [void]
      # @raise [Error] dal thread del ciclo, quando il ciclo non può girare
      def fiber_interrupt(fiber, exception)
        if Thread.current.equal?(@thread) && (Fiber.current.blocking? || !@transferring)
          raise Error, "IO#close: un task (Fiber.schedule) attende su questo IO, e close da un handler bloccherebbe " \
                       "il ciclo: chiudi l'IO da un altro task o da un altro thread"
        end

        @interrupts.push([fiber, exception])
        @event_loop.wake
      end

      # Hook di Fiber.schedule: il blocco parte subito, fino alla prima
      # attesa. Chiamato da un task, il task riparte a un giro successivo;
      # chiamato da un Fiber che un handler ha ripreso con resume, il blocco
      # parte al giro successivo.
      #
      # @return [Fiber] il task
      def fiber(&)
        fiber = Fiber.new(blocking: false, &)
        current = Fiber.current
        if current.equal?(@loop_fiber)
          switch { fiber.transfer }
        elsif !@transferring
          wait = Wait.new(fiber, :start)
          @waits[fiber] = wait
          @ready.push(wait)
        else
          start_from_task(fiber, current)
        end
        fiber
      end

      # Hook di Timeout.timeout in un task: allo scadere exception arriva al
      # task nel punto in cui attende. Un task che a quel punto non attende in
      # uno di questi hook (per esempio attende in un Fiber suo, con resume)
      # non la riceve. Fuori da un task (vedi la classe) un thread solleva
      # exception allo scadere, come Timeout senza scheduler.
      #
      # @param duration [Numeric] secondi
      # @param exception [Class, Exception]
      # @param message [String]
      # @return [Object] il valore del blocco
      def timeout_after(duration, exception, message, &)
        return sync_timeout(duration, exception, message, &) unless @transferring

        fiber = Fiber.current
        timer = @event_loop.add_internal_timer(duration.to_f) { interrupt(fiber, exception, message) }
        yield duration
      ensure
        @event_loop.unschedule(timer) if timer
      end

      # Hook: Fiber.set_scheduler(nil), alla fine di run. Manda {Stop} ai task
      # in attesa, così i loro ensure girano; un task che dentro l'ensure
      # attende di nuovo resta fermo e non riparte, e un task non ancora
      # partito non parte. Non solleva mai: se close solleva, Ruby 3.1 lascia
      # lo scheduler impostato. La prima eccezione uscita da un task resta in
      # {#failure}. Idempotente: dopo un'interruzione run lo richiama.
      #
      # @return [nil]
      def close
        @closing = true
        @loop_fiber = Fiber.current
        @waits.each_pair.to_a.each do |fiber, wait|
          next if wait.kind == :start || !@waits.key?(fiber) || !fiber.alive?

          switch { fiber.raise(Stop) }
        rescue Stop
          nil
        rescue Exception => e # rubocop:disable Lint/RescueException -- gli altri task vanno fermati lo stesso
          @failure ||= e
        end
        @waits.clear
        @sync_r&.close
        @sync_w&.close
        nil
      end

      private

      # Attesa di un task; durante {#close} il task resta fermo per sempre.
      # @return il valore del risveglio, o timeout_value a scadenza passata
      def wait(kind, timeout, timeout_value, io = nil, events = nil)
        wait = Wait.new(Fiber.current, kind, io, events)
        if timeout && !@closing
          wait.timer = @event_loop.add_internal_timer([timeout.to_f, 0.0].max) { resume(wait, timeout_value) }
        end
        suspend(wait)
      end

      def suspend(wait)
        return @loop_fiber.transfer if @closing

        @waits[wait.fiber] = wait
        @loop_fiber.transfer
      ensure
        @waits.delete(wait.fiber) if @waits[wait.fiber].equal?(wait)
        @event_loop.unschedule(wait.timer) if wait.timer
      end

      # Transfer dal Fiber del ciclo verso un task: finché il task gira, le
      # sue attese tornano al ciclo.
      def switch
        @ran = true
        @transferring = true
        yield
      ensure
        @transferring = false
      end

      # Fiber.schedule da un task: il task riparte a un giro successivo.
      def start_from_task(fiber, current)
        wait = Wait.new(current, :ready)
        @ready.push(wait)
        @waits[current] = wait
        fiber.transfer
      ensure
        @waits.delete(current) if @waits[current].equal?(wait)
      end

      # Riprende il task di wait con value, se wait è ancora la sua attesa.
      def resume(wait, value)
        return unless @waits[wait.fiber].equal?(wait)

        @waits.delete(wait.fiber) if wait.kind == :start # il task non ha un suspend che la tolga
        switch { wait.fiber.transfer(value) }
      end

      # Solleva exception nel task, se attende in uno di questi hook.
      def interrupt(fiber, exception, message = nil)
        return unless @waits.key?(fiber)

        switch { message ? fiber.raise(exception, message) : fiber.raise(exception) }
      end

      # Ruby 4.0 chiama fiber_interrupt una volta per ogni operazione aperta sull'IO, anche due per lo stesso task:
      # la seconda colpirebbe l'attesa successiva del task, quindi vale una sola per task e per giro.
      def resume_interrupts
        interrupted = {}.compare_by_identity
        @interrupts.size.times do
          break unless yield

          fiber, exception = @interrupts.pop(true)
          next if interrupted.key?(fiber)

          interrupted[fiber] = true
          interrupt(fiber, exception)
        end
      end

      def resume_io(readable, writable, priority)
        ready = Hash.new(0).compare_by_identity
        readable&.each { |io| ready[io] |= IO::READABLE }
        writable&.each { |io| ready[io] |= IO::WRITABLE }
        priority&.each { |io| ready[io] |= IO::PRIORITY }
        @waits.values.each do |wait|
          next unless wait.kind == :io
          break unless yield

          events = ready[wait.io] & wait.events
          resume(wait, events) unless events.zero?
        end
      end

      # io_wait bloccante (vedi la classe).
      def sync_io_wait(io, events, timeout)
        sets = [IO::READABLE, IO::WRITABLE, IO::PRIORITY].map { |event| events.anybits?(event) ? [io] : nil }
        ready = IO.select(*sets, timeout)
        return false unless ready

        [IO::READABLE, IO::WRITABLE, IO::PRIORITY].each_with_index.sum { |event, i| ready[i].empty? ? 0 : event }
      end

      # block e sleep bloccanti (vedi la classe): unblock scrive un byte sul pipe.
      # @return [Boolean] true se sbloccato, false a timeout scaduto
      def sync_wait(timeout)
        @sync_r, @sync_w = IO.pipe unless @sync_r
        nil while @sync_r.read_nonblock(64, exception: false).is_a?(String) # un byte rimasto da un unblock in ritardo
        @sync_fiber = Fiber.current
        !IO.select([@sync_r], nil, nil, timeout && [timeout.to_f, 0.0].max).nil?
      ensure
        @sync_fiber = nil
      end

      # timeout_after bloccante (vedi la classe): come Timeout senza scheduler.
      def sync_timeout(duration, exception, message)
        thread = Thread.current
        # rubocop:disable ThreadSafety/NewThread -- come il thread di Timeout: solleva exception allo scadere
        watcher = Thread.new do
          sleep duration
          thread.raise(exception, message)
        end
        # rubocop:enable ThreadSafety/NewThread
        yield duration
      ensure
        watcher&.kill # senza join: join passerebbe da questo scheduler
      end

      # Ruby 4.0 crea un IO::Buffer per ogni scrittura da un Fiber non
      # bloccante, anche senza l'hook io_write (io.c:1325-1335), e il primo
      # IO::Buffer del processo scrive su stderr «IO::Buffer is experimental»:
      # in un'applicazione a schermo intero il testo finisce sullo schermo. Il
      # warning esce una volta sola per processo (flag static in
      # io_buffer.c:170-183, impostato anche con la categoria spenta): lo
      # consuma qui, a categoria spenta per un istante (D6 dello studio
      # ICH-600). Dopo, Ruby non lo scrive più nel processo.
      def silence_io_buffer_warning
        return unless defined?(IO::Buffer)

        previous = Warning[:experimental]
        Warning[:experimental] = false
        IO::Buffer.new(1)
      ensure
        Warning[:experimental] = previous unless previous.nil?
      end
    end
    private_constant :Scheduler
  end
end
