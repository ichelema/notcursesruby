# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  module UI
    # Timer di un {EventLoop}, creato da {EventLoop#after} o {EventLoop#every}:
    # una scadenza che il ciclo controlla a ogni giro, non un thread né uno
    # sleep. Il blocco gira nel thread del ciclo.
    class Timer
      # @return [Float, nil] secondi fra due esecuzioni; nil per un timer di
      #   {EventLoop#after}
      attr_reader :interval

      # @return [Float] scadenza, sull'orologio CLOCK_MONOTONIC
      # @api private
      attr_accessor :deadline

      # @return [Integer] ordine di creazione: decide fra due scadenze uguali
      # @api private
      attr_reader :seq

      # Lo crea {EventLoop}: non chiamarlo direttamente.
      #
      # @param deadline [Float] prima scadenza (CLOCK_MONOTONIC)
      # @param interval [Float, nil] secondi fra due esecuzioni, nil = una volta
      # @param seq [Integer] ordine di creazione
      # @param block [Proc] blocco da eseguire, riceve il timer
      # @api private
      def initialize(deadline, interval, seq, block)
        @deadline = deadline
        @interval = interval
        @seq = seq
        @block = block
        @active = true
      end

      # Ferma il timer: il blocco non viene più chiamato. Idempotente.
      #
      # @return [self]
      def cancel
        @active = false
        self
      end

      # @return [Boolean] true finché il blocco può ancora essere chiamato
      def active? = @active

      # Esegue il blocco. Un timer di {EventLoop#after} diventa inattivo prima
      # del blocco.
      #
      # @return [void]
      # @api private
      def fire
        @active = false if @interval.nil?
        @block.call(self)
      end

      # @return [String]
      def inspect
        format('#<%<cls>s %<kind>s%<state>s>', cls: self.class.name, kind: @interval ? "ogni #{@interval}s" : 'una volta',
                                              state: @active ? '' : ' (fermo)')
      end
    end

    # Ciclo degli eventi: attende l'input del terminale, i blocchi degli altri
    # thread ({#post}) e i timer, consegna ogni evento e rende lo schermo al
    # massimo una volta per giro. Si usa da solo, oppure attraverso {App}, che
    # aggiunge componenti e focus.
    #
    # Un giro di {#run}: +IO.select+ sul descrittore di
    # {Context#inputready_fd} e su un pipe di risveglio, con il timeout del
    # primo timer; poi, nell'ordine, il resize segnalato, tutto l'input pronto
    # (notcurses svuota il pipe di prontezza a ogni lettura, anche con altri
    # eventi in coda), i blocchi di {#post}, i timer scaduti, e un
    # {Context#render} se il giro ha consegnato qualcosa. {#run} rende anche lo
    # schermo all'avvio.
    #
    # Thread. Solo il thread che esegue {#run} chiama notcurses: gli handler, i
    # timer e i blocchi di {#post} girano lì. {#post} e {#stop} sono gli unici
    # metodi per gli altri thread e per i gestori +trap+ (usano una Queue e un
    # byte sul pipe, niente Mutex, che in un trap non si può usare). Gli altri
    # metodi si chiamano dal thread del ciclo, o prima di {#run}. Il ciclo non
    # aggiunge lock: un altro thread che chiama notcurses durante {#run} lo fa
    # insieme al ciclo. Per +FdPlane+ e +Subprocess+ il blocco del thread di
    # lettura passa i dati con {#post} (vedi {LogView}).
    #
    # Resize. Se il contesto non ha il gestore di SIGWINCH di notcurses
    # ({Context#no_winch_sighandler?}, il default), {#run} installa
    # +trap('WINCH')+ e lo toglie alla fine: il gestore sveglia il ciclo, che
    # chiama {Context#refresh} e gli handler di {#on_resize}. Con il gestore
    # di notcurses il ciclo reagisce invece a {Key::RESIZE}, che notcurses 3.0.17
    # mette in coda solo quando arriva altro input. In entrambi i casi, se dopo
    # un render le dimensioni sono cambiate (resize perso), il giro successivo
    # le applica. Gli handler partono solo se le dimensioni cambiano.
    #
    # Un contesto che scarta l'input ({Context#drain_input?}) non viene
    # ascoltato: il ciclo serve solo timer, {#post} e resize.
    #
    # @example
    #   Notcurses::Context.open do |nc|
    #     ev = Notcurses::UI::EventLoop.new(nc)
    #     ev.on_key('q') { ev.stop }
    #     ev.every(1) { nc.stdplane.putstr(Time.now.strftime('%T'), y: 0, x: 0) }
    #     ev.run # => :stop, :eof o :interrupt
    #   end
    class EventLoop
      MOD_CTRL = FFI::NCKEY_MOD_CTRL
      MOD_ALT = FFI::NCKEY_MOD_ALT
      MOD_SHIFT = FFI::NCKEY_MOD_SHIFT
      MOD_OTHER = FFI::NCKEY_MOD_META | FFI::NCKEY_MOD_SUPER | FFI::NCKEY_MOD_HYPER
      private_constant :MOD_CTRL, :MOD_ALT, :MOD_SHIFT, :MOD_OTHER

      # @return [Context]
      attr_reader :context

      # @param context [Context] contesto aperto
      # @raise [TypeError] se context non è un Context
      # @raise [ClosedError] se il contesto è chiuso
      def initialize(context)
        raise TypeError, "context deve essere Notcurses::Context, non #{context.class}" unless context.is_a?(Context)

        context.to_ptr
        @context = context
        @queue = Queue.new
        @timers = []
        @seq = 0
        @key_bindings = []
        @input_handlers = []
        @resize_handlers = []
        @running = false
        @stop_requested = false
        @resize_requested = false
        @wake_w = nil
      end

      # Esegue il ciclo nel thread corrente fino a {#stop}, alla fine
      # dell'input ({Key::EOF}) o a un Interrupt. Per ricevere Ctrl-C come
      # Interrupt (con il default no_quit_sighandlers: true del contesto) il
      # ciclo deve girare nel thread principale. Un'eccezione di un handler
      # esce da run dopo aver tolto il trap e chiuso il pipe di risveglio. Se
      # un handler chiude il contesto, run esce alla fine del giro.
      #
      # Tasti di controllo. Di default il terminale consuma Ctrl+S e Ctrl+Q
      # (controllo di flusso, IXON) e trasforma Ctrl+C, Ctrl+Z e Ctrl+\ in
      # segnali (ISIG): Ctrl-C fa uscire run con :interrupt. Con
      # no_flow_control: true Ctrl+S e Ctrl+Q arrivano a {#on_key}; con
      # no_linesigs: true arrivano Ctrl+C, Ctrl+Z e Ctrl+\, e Ctrl-C non ferma
      # più il ciclo: serve un tasto di uscita dell'applicazione. run tocca
      # solo i flag attivi all'avvio e alla fine, anche dopo un'eccezione, li
      # riattiva ({Context#linesigs_enable} per ISIG): il terminale torna com'era
      # prima di run. Se un handler ha chiuso il contesto, notcurses ha già
      # ripristinato il terminale e run non lo tocca. run legge e cambia IXON,
      # e legge ISIG, sul terminale da cui notcurses legge i tasti (stdin se è
      # un tty, altrimenti /dev/tty).
      #
      # @param no_flow_control [Boolean] disattiva IXON durante run
      # @param no_linesigs [Boolean] disattiva ISIG durante run
      #   ({Context#linesigs_disable})
      # @return [Symbol] :stop, :eof o :interrupt
      # @raise [Error] se il ciclo è già in esecuzione
      # @raise [ClosedError] se il contesto è chiuso
      # @raise [ContextError] se il terminale rifiuta il cambio di IXON o ISIG;
      #   un errore del ripristino finale non sostituisce l'eccezione di un
      #   handler, che resta quella sollevata
      # @raise [TypeError] se un'opzione non è un Boolean
      # @raise [Exception] l'eccezione di un handler, di un timer o di un blocco
      #   di {#post}
      def run(no_flow_control: false, no_linesigs: false)
        no_flow_control = Util.bool!(no_flow_control, 'no_flow_control')
        no_linesigs = Util.bool!(no_linesigs, 'no_linesigs')
        raise Error, 'EventLoop#run: il ciclo è già in esecuzione' if @running

        @context.to_ptr
        @running = true
        wake_r = nil
        winch = false
        ixon = false
        linesigs = false
        begin
          ixon = @context.flow_control_disable if no_flow_control
          if no_linesigs && @context.linesigs?
            @context.linesigs_disable
            linesigs = true
          end
          wake_r, @wake_w = IO.pipe
          # il descrittore è di notcurses: autoclose false, lo chiude notcurses_stop
          @input = @context.drain_input? ? nil : IO.for_fd(@context.inputready_fd, autoclose: false)
          if @context.no_winch_sighandler?
            @old_winch = Signal.trap('WINCH') { resize_signal }
            winch = true
          end
          @reason = :stop
          @dims = @context.dims
          render_frame
          watched = [@input, wake_r].compact
          until @stop_requested
            IO.select(watched, nil, nil, select_timeout)
            drain(wake_r)
            step
          end
          @reason
        rescue Interrupt
          :interrupt
        ensure
          # nil vorrebbe dire IGNORE, che i processi figli erediterebbero
          Signal.trap('WINCH', @old_winch || 'SYSTEM_DEFAULT') if winch
          @wake_w&.close
          @wake_w = nil
          wake_r&.close
          @input = nil
          @stop_requested = false
          @running = false
          restore_terminal(ixon, linesigs, $!)
        end
      end

      # Chiede a {#run} di uscire alla fine del giro, senza consegnare altri
      # eventi: restituisce :stop. Si può chiamare da qualsiasi thread e da un
      # gestore +trap+. Chiamato quando run non gira, vale per il run
      # successivo, che esce dopo il render iniziale.
      #
      # @return [self]
      def stop
        @stop_requested = true
        wake
        self
      end

      # Esegue il blocco nel thread del ciclo, al giro successivo, nell'ordine
      # di arrivo. Si può chiamare da qualsiasi thread e da un gestore +trap+.
      # La coda non ha limite: un produttore più veloce del ciclo la fa
      # crescere. Un blocco aggiunto quando run non gira aspetta il run
      # successivo.
      #
      # @yield blocco da eseguire nel thread del ciclo
      # @return [self]
      # @raise [ArgumentError] senza blocco
      def post(&block)
        raise ArgumentError, 'post: serve un blocco' unless block

        @queue << block
        wake
        self
      end

      # Esegue il blocco una volta, dopo seconds secondi (dal thread del ciclo).
      #
      # @param seconds [Numeric] attesa, >= 0
      # @yieldparam timer [Timer] il timer
      # @return [Timer]
      # @raise [ArgumentError] senza blocco, o se seconds è negativo o non finito
      # @raise [TypeError] se seconds non è un numero
      def after(seconds, &block)
        raise ArgumentError, 'after: serve un blocco' unless block

        add_timer(Util.float!(seconds, 'seconds', 0.0..), nil, block)
      end

      # Esegue il blocco ogni seconds secondi (dal thread del ciclo). Se il
      # ciclo è in ritardo di più di un intervallo, le esecuzioni perse non
      # vengono recuperate.
      #
      # @param seconds [Numeric] intervallo, > 0
      # @yieldparam timer [Timer] il timer (per esempio per {Timer#cancel})
      # @return [Timer]
      # @raise [ArgumentError] senza blocco, o se seconds non è un numero
      #   finito maggiore di 0
      # @raise [TypeError] se seconds non è un numero
      def every(seconds, &block)
        raise ArgumentError, 'every: serve un blocco' unless block

        interval = Util.float!(seconds, 'seconds', 0.0..)
        raise ArgumentError, 'every: seconds deve essere maggiore di 0' unless interval.positive?

        add_timer(interval, interval, block)
      end

      # Tasto globale: il blocco riceve l'evento quando nessun altro lo
      # consuma (in {App}: dopo il componente con il focus e i suoi
      # contenitori). Vale il primo tasto registrato che corrisponde, e
      # l'evento risulta consumato.
      #
      # Corrispondenza: solo pressioni e ripetizioni (non i rilasci né il
      # mouse); Ctrl, Alt e Shift come chiesti, CapsLock e NumLock ignorati,
      # Meta, Super e Hyper assenti. Con ctrl: true una lettera ASCII vale
      # anche maiuscola: notcurses consegna Ctrl+c come 'C' con Ctrl. Per un
      # carattere stampabile Shift non conta (è già nel carattere, per esempio
      # 'Q'); conta per gli altri codici, come {Key::TAB} (Shift+Tab).
      #
      # Tasti di controllo: notcurses 3.0.17 toglie al terminale solo ECHO,
      # ICANON e ICRNL, quindi di default Ctrl+C, Ctrl+Z e Ctrl+\ restano
      # segnali (ISIG) e Ctrl+S e Ctrl+Q restano il controllo di flusso (IXON):
      # non arrivano qui. Arrivano con {#run}(no_flow_control: true) per
      # Ctrl+S e Ctrl+Q e con {#run}(no_linesigs: true) per Ctrl+C, Ctrl+Z e
      # Ctrl+\.
      #
      # @param key [String, Integer] un carattere (String di un codepoint) o
      #   un codice: codepoint o costante {Key}
      # @param ctrl [Boolean] con Ctrl
      # @param alt [Boolean] con Alt
      # @param shift [Boolean] con Shift (solo per i codici non stampabili)
      # @yieldparam input [Input] l'evento
      # @return [self]
      # @raise [ArgumentError] senza blocco, o con una String che non è un
      #   solo codepoint
      # @raise [TypeError] se key non è String né Integer, o un'opzione non è
      #   un Boolean
      def on_key(key, ctrl: false, alt: false, shift: false, &block)
        raise ArgumentError, 'on_key: serve un blocco' unless block

        id = key_id(key)
        ctrl = Util.bool!(ctrl, 'ctrl')
        id -= 0x20 if ctrl && id.between?(0x61, 0x7a) # 'a'..'z': notcurses li consegna in maiuscolo con Ctrl
        @key_bindings << [id, ctrl, Util.bool!(alt, 'alt'), Util.bool!(shift, 'shift'), block]
        self
      end

      # Handler dell'input che nessuno ha consumato (né un componente, né
      # {#on_key}, né la navigazione del focus di {App}). Tutti gli handler
      # vengono chiamati, nell'ordine di registrazione; il valore del blocco
      # non conta.
      #
      # @yieldparam input [Input] l'evento
      # @return [self]
      # @raise [ArgumentError] senza blocco
      def on_input(&block)
        raise ArgumentError, 'on_input: serve un blocco' unless block

        @input_handlers << block
        self
      end

      # Handler del resize del terminale, chiamati quando le dimensioni
      # cambiano (in {App} dopo il layout dei componenti).
      #
      # @yieldparam rows [Integer] righe dell'area di rendering
      # @yieldparam cols [Integer] colonne dell'area di rendering
      # @return [self]
      # @raise [ArgumentError] senza blocco
      def on_resize(&block)
        raise ArgumentError, 'on_resize: serve un blocco' unless block

        @resize_handlers << block
        self
      end

      # Consegna un evento come se arrivasse dal terminale: prima {#on_key},
      # poi, se nessun tasto corrisponde, gli handler di {#on_input}. Serve per
      # gli eventi costruiti con {Input.synthesize} e nei test. {Key::EOF} e
      # {Key::RESIZE} li gestisce solo {#run}.
      #
      # @param input [Input]
      # @return [Boolean] true se un tasto di {#on_key} ha consumato l'evento
      # @raise [TypeError] se input non è un Input
      # @raise [Exception] l'eccezione di un handler
      def dispatch(input)
        input!(input)
        return true if key_binding(input)

        input_handlers(input)
        false
      end

      # @return [Boolean] true durante {#run}
      def running? = @running

      # Inserisce un timer nella lista, per scadenza e poi per creazione.
      #
      # @param timer [Timer]
      # @return [Timer] timer
      # @api private
      def schedule(timer)
        index = @timers.bsearch_index do |t|
          t.deadline > timer.deadline || (t.deadline == timer.deadline && t.seq > timer.seq)
        end
        @timers.insert(index || @timers.size, timer)
        timer
      end

      private

      def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # @raise [TypeError] se input non è un Input
      def input!(input)
        raise TypeError, "input deve essere Notcurses::Input, non #{input.class}" unless input.is_a?(Input)
      end

      # @return [Integer] il codice di key
      def key_id(key)
        case key
        when Integer then Util.uint32!(key, 'key')
        when String
          raise ArgumentError, "key = #{key.inspect}: serve un solo carattere (un codepoint)" unless Util.string!(key, 'key').length == 1

          key.ord
        else raise TypeError, "key deve essere String o Integer, non #{key.class}"
        end
      end

      def add_timer(delay, interval, block)
        @seq += 1
        schedule(Timer.new(clock + delay, interval, @seq, block))
      end

      # Gestore di trap('WINCH'): solo un flag e un byte sul pipe.
      def resize_signal
        @resize_requested = true
        wake
      end

      # Riattiva IXON e ISIG tolti da run, tentando entrambi. Con il contesto
      # chiuso notcurses_stop ha già ripristinato il terminale di prima dell'init.
      # Un errore non sostituisce pending, l'eccezione che sta uscendo da run.
      def restore_terminal(ixon, linesigs, pending)
        return if @context.closed?

        error = nil
        begin
          @context.flow_control_enable if ixon
        rescue ContextError => e
          error = e
        end
        begin
          @context.linesigs_enable if linesigs
        rescue ContextError => e
          error ||= e
        end
        raise error if error && !pending
      end

      def wake
        @wake_w&.write_nonblock("\0", exception: false)
      rescue IOError, Errno::EPIPE
        nil # pipe chiuso da run in un altro thread: il ciclo è finito
      end

      def drain(reader)
        loop do
          data = reader.read_nonblock(4096, exception: false)
          break if data.nil? || data == :wait_readable
        end
      end

      # Timeout di IO.select: 0 con blocchi in coda o un resize da applicare,
      # nil senza timer.
      def select_timeout
        return 0 if @resize_requested || !@queue.empty?

        timer = @timers.first
        timer && [timer.deadline - clock, 0].max
      end

      def live? = !@stop_requested && !@context.closed?

      def step
        worked = false
        worked |= handle_resize(refresh: true) if @resize_requested && live?
        worked |= read_input if @input && live?
        worked |= run_posted
        worked |= run_timers
        if @context.closed?
          @stop_requested = true
        elsif worked
          render_frame
        end
      end

      # @return [Boolean] true se ha consegnato almeno un evento
      def read_input
        worked = false
        while live? && (input = @context.get(timeout: 0))
          worked = true
          case input.id
          when Key::EOF
            @reason = :eof
            @stop_requested = true
          when Key::RESIZE then handle_resize(refresh: true)
          else dispatch(input)
          end
        end
        worked
      end

      # Solo i blocchi in coda all'inizio del passo.
      def run_posted
        count = @queue.size
        count.times do
          break unless live?

          @queue.pop(true).call
        end
        count.positive?
      end

      # Solo i timer scaduti e già creati all'inizio del passo: un timer
      # creato o riprogrammato qui scade dopo.
      def run_timers
        now = clock
        limit = @seq
        worked = false
        while live? && (timer = @timers.first) && timer.deadline <= now && timer.seq <= limit
          @timers.shift
          next unless timer.active?

          timer.fire
          worked = true
          reschedule(timer) if timer.interval && timer.active?
        end
        worked
      end

      def reschedule(timer)
        now = clock
        timer.deadline += timer.interval
        timer.deadline = now + timer.interval if timer.deadline <= now # niente raffiche dopo un ritardo
        schedule(timer)
      end

      # @return [Boolean] true se le dimensioni sono cambiate
      def handle_resize(refresh:)
        @resize_requested = false
        dims = refresh ? @context.refresh : @context.dims
        return false if dims == @dims

        @dims = dims
        resized(*dims)
        true
      end

      # Nuove dimensioni: {App} vi aggiunge il layout.
      def resized(rows, cols)
        @resize_handlers.each { |handler| handler.call(rows, cols) }
      end

      def render_frame
        @context.render
        # resize non segnalato (prima di run, o con il gestore di notcurses): lo applica il giro successivo
        @resize_requested = true if @context.dims != @dims
      end

      # @return [Boolean] true se un tasto di on_key ha consumato l'evento
      def key_binding(input)
        return false if input.release? || input.mouse?

        binding = @key_bindings.find { |b| key_match?(b, input) }
        return false unless binding

        binding.last.call(input)
        true
      end

      def key_match?((id, ctrl, alt, shift, _block), input)
        mods = input.modifiers
        return false unless input.id == id && mods.nobits?(MOD_OTHER)
        return false unless mods.anybits?(MOD_CTRL) == ctrl && mods.anybits?(MOD_ALT) == alt

        printable?(id) || mods.anybits?(MOD_SHIFT) == shift
      end

      def printable?(id) = id >= 0x20 && id != 0x7f && id <= 0x10ffff && !Key.synthesized?(id)

      def input_handlers(input)
        @input_handlers.each { |handler| handler.call(input) }
      end
    end
  end
end
