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
      # @param internal [Boolean] scadenza di un'attesa del Fiber scheduler
      #   di run: non conta come lavoro del giro
      # @api private
      def initialize(deadline, interval, seq, block, internal: false)
        @deadline = deadline
        @interval = interval
        @seq = seq
        @block = block
        @active = true
        @internal = internal
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

      # @return [Boolean] true per la scadenza di un'attesa del Fiber
      #   scheduler di run
      # @api private
      def internal? = @internal

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
    # Un giro di {#run}: +IO.select+ sul pipe del thread di input del
    # contesto (che legge i tasti da notcurses, vedi {#run}) e su un pipe di
    # risveglio, con il timeout del primo timer; poi, nell'ordine, il resize
    # segnalato, tutto l'input pronto, i blocchi di {#post}, i timer scaduti, e
    # un {Context#render} se il giro ha consegnato qualcosa. {#run} rende anche
    # lo schermo all'avvio. Il primo giro di ogni {#run} non attende: consegna
    # subito gli eventi che il run precedente ha lasciato (uscito con {#stop}
    # o con un'eccezione).
    #
    # Thread. Gli handler, i timer e i blocchi di {#post} girano nel thread
    # che esegue {#run}. Solo quel thread chiama notcurses, tranne il thread di
    # input del contesto, che durante run legge i tasti con
    # +notcurses_getvec+ (notcurses lo permette in parallelo al render; vedi
    # {Context#get}). {#post} e {#stop} sono gli unici
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
    # Ctrl+Z e fg. Senza il gestore di notcurses manca anche quello di SIGCONT,
    # che dopo la ripresa ridisegna tutto lo schermo: {#run} installa allora
    # anche +trap('CONT')+, con le stesse regole di WINCH. Dopo fg il ciclo
    # chiama {Context#refresh}, che toglie dallo schermo il testo scritto dalla
    # shell; gli handler di {#on_resize} partono solo se le dimensioni sono
    # cambiate. Con il gestore di notcurses arriva invece {Key::SIGNAL} a
    # {#on_input}. Mentre il processo è fermo il terminale resta nel modo di
    # notcurses (schermo alternativo, tracciamento del mouse): notcurses 3.0.17
    # non gestisce SIGTSTP.
    #
    # Un contesto che scarta l'input ({Context#drain_input?}) non viene
    # ascoltato: il ciclo serve solo timer, {#post} e resize.
    #
    # Task. Durante {#run} il ciclo è anche il Fiber scheduler del thread:
    # +Fiber.schedule+ in un handler crea un task, un Fiber che parte subito e
    # gira fino alla prima attesa. Quando un task attende I/O (un pipe, un
    # socket), +sleep+, una Queue, un Mutex o +Timeout.timeout+, il ciclo
    # continua a consegnare eventi, e riprende il task nel giro in cui l'attesa
    # finisce. Gli handler restano sul Fiber del ciclo, che è bloccante: dentro
    # un handler +sleep+ e l'I/O fermano il ciclo come senza task, anche in un
    # Fiber che l'handler riprende con resume (per esempio +Enumerator#next+),
    # e un +Fiber.schedule+ chiamato lì parte al giro successivo. Un task che
    # legge un flusso sempre pronto non attende mai, e ferma il ciclo finché
    # non cede con +sleep(0)+. All'uscita di run i task ancora in attesa
    # ricevono un'eccezione che non deriva da StandardError, e i loro ensure
    # girano.
    #
    # Chiudere un IO su cui un task attende. Su Ruby 4.0 un close da un altro
    # task o da un altro thread dà IOError al task; un close da un handler
    # solleva Error e lascia l'IO aperto, perché close attenderebbe per
    # sempre la fine dell'operazione del task. Su Ruby 3.1-3.4 non chiudere
    # quell'IO dal thread del ciclo: per un difetto di Ruby close lascia
    # l'attesa del task legata alla sua memoria, e quando il task esce
    # dall'attesa il processo può andare in crash (segmentation fault con Ruby
    # 3.4.12). Chiudilo dopo che il task ha smesso di attenderlo.
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
      MOD_LOCKS = FFI::NCKEY_MOD_CAPSLOCK | FFI::NCKEY_MOD_NUMLOCK
      # i segnali che notcurses alza per Ctrl+C, Ctrl+Z e Ctrl+\ (in.c:506-516)
      LINE_SIGNALS = { 'C'.ord => 'INT', 'Z'.ord => 'STOP', '\\'.ord => 'QUIT' }.freeze
      # id con cui arriva ogni tasto di segnale: senza Ctrl notcurses non lo fa maiuscolo, e la ripetizione e il
      # rilascio di un tasto tenuto arrivano senza Ctrl se l'utente lascia prima Ctrl
      SIGNAL_KEYS = { 'C'.ord => 'C'.ord, 'c'.ord => 'C'.ord, 'Z'.ord => 'Z'.ord, 'z'.ord => 'Z'.ord,
                      '\\'.ord => '\\'.ord }.freeze
      # Gli id che il thread di input passa a line_signal: C, Z e \ sempre, c e z solo mentre il tasto è tenuto
      # (held, {Context#held_signal_keys}). Ogni evento filtrato costa un Input e rallenta lo svuotamento della coda:
      # una raffica di c o z non deve perdere il Ctrl+C prima di una raffica di altre lettere.
      SignalIds = Struct.new(:held) do
        def key?(id)
          key = SIGNAL_KEYS[id]
          !key.nil? && (key == id || held.key?(key))
        end
      end
      private_constant :MOD_CTRL, :MOD_ALT, :MOD_SHIFT, :MOD_OTHER, :MOD_LOCKS, :LINE_SIGNALS, :SIGNAL_KEYS, :SignalIds

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
        @line_signals = false
        @stop_requested = false
        @resize_requested = false
        @wake_w = nil
        @scheduler = nil # Scheduler durante run, se run lo ha installato
        @dirty = false # lavoro di un giro non ancora reso
        @frame = 0.0
        @last_render = 0.0
      end

      # Esegue il ciclo nel thread corrente fino a {#stop}, alla fine
      # dell'input ({Key::EOF}) o a un Interrupt. Per ricevere Ctrl-C come
      # Interrupt (con il default no_quit_sighandlers: true del contesto) il
      # ciclo deve girare nel thread principale. Un'eccezione di un handler
      # esce da run dopo aver tolto i trap e chiuso il pipe di risveglio. Se
      # un handler chiude il contesto, run esce alla fine del giro.
      #
      # Tasti di controllo. Di default il terminale consuma Ctrl+S e Ctrl+Q
      # (controllo di flusso, IXON) e trasforma Ctrl+C, Ctrl+Z e Ctrl+\ in
      # segnali (ISIG): Ctrl-C fa uscire run con :interrupt. Con
      # no_flow_control: true Ctrl+S e Ctrl+Q arrivano a {#on_key}; con
      # no_linesigs: true arrivano Ctrl+C, Ctrl+Z e Ctrl+\, e Ctrl-C non ferma
      # più il ciclo: serve un tasto di uscita dell'applicazione. run tocca
      # solo i flag attivi all'avvio e alla fine, anche dopo un'eccezione, li
      # riattiva: il terminale torna com'era prima di run. Se un handler ha
      # chiuso il contesto, notcurses ha già ripristinato il terminale e run
      # non lo tocca. run legge e cambia IXON e ISIG sul terminale da cui
      # notcurses legge i tasti (stdin se è un tty, altrimenti /dev/tty).
      #
      # Con il protocollo tastiera kitty (Kitty, Ghostty) Ctrl+C arriva come
      # sequenza e non come byte, e il terminale non alza il segnale. notcurses
      # lo alzerebbe da un flag suo, che stty non cambia, solo con Ctrl da solo
      # e anche per la ripetizione e il rilascio: all'avvio run gli toglie
      # questo compito ({Context#linesigs_disable}, poi rimette ISIG com'era),
      # se il flag è acceso ({Context#linesigs_flag?}). Durante run un thread
      # di input del contesto legge i tasti appena arrivano, anche mentre un
      # handler, un timer o un blocco di {#post} occupa il ciclo. Con ISIG
      # attivo il thread alza subito lo stesso segnale (SIGINT, SIGSTOP,
      # SIGQUIT) al processo, una volta per pressione, e il ciclo non consegna
      # questi tasti (con o senza CapsLock e NumLock, nemmeno ripetizioni e
      # rilasci). La ripetizione e il rilascio del tasto che ha alzato il
      # segnale non arrivano nemmeno ai run successivi, anche con no_linesigs,
      # anche di un altro EventLoop sullo stesso contesto, anche dopo la
      # pressione di un altro tasto di segnale, anche se l'utente lascia Ctrl
      # prima del tasto. Lo stesso vale per il Ctrl+C di
      # xterm con modifyOtherKeys ("\e[27;5;99~"). I byte di controllo (0x03
      # con intr rimappato, input da una pipe) arrivano invece come tasti,
      # anche con kitty. run legge ISIG solo all'avvio: stty,
      # {Context#linesigs_disable} o {Context#linesigs_enable} durante run non
      # cambiano la scelta ({Context#linesigs_enable} ridà il compito a
      # notcurses: due segnali per pressione); per i tasti serve no_linesigs.
      #
      # Il thread di input tiene vuota la coda di notcurses (8192 eventi). Due
      # limiti: il thread ha bisogno del GVL per leggere, quindi un handler che
      # lo tiene (codice Ruby per un quanto di 100 ms, una chiamata C che non lo
      # rilascia per tutta la sua durata) ritarda il segnale, e se intanto
      # arrivano più di 8192 tasti notcurses scarta quelli in più, anche
      # Ctrl+C, senza segnale; notcurses consegna gli eventi
      # (+notcurses_getvec+, circa 1,5 µs l'uno) più lentamente di quanto li
      # mette in coda, quindi anche con il thread libero una raffica lunga può
      # riempire la coda. Nelle prove su un pty finto, con la macchina scarica,
      # 10000 tasti in un colpo non hanno perso niente; con altri processi che
      # occupano la CPU anche il Ctrl+C dopo 10000 tasti si è perso, di rado, e
      # con 20000-50000 tasti, sotto carico, in circa una corsa su sei.
      #
      # Un secondo Ctrl+C (o un'altra eccezione asincrona) mentre run fa
      # pulizia arriva alla fine della pulizia: run solleva Interrupt invece di
      # restituire :interrupt, con il terminale, i trap e il thread di input
      # già a posto. Su Ruby 3.1, 3.2 e 3.3 l'Interrupt di un segnale non si
      # rimanda: interrompe la pulizia, che ricomincia (i suoi passi sono
      # idempotenti) e finisce prima che run lo sollevi. Limite di queste
      # versioni (ICH-539): un secondo segnale consegnato dopo l'interruzione,
      # prima che la pulizia ricominci, fa uscire run con l'Interrupt e salta
      # i passi rimasti. Secondo il passo interrotto, i trap di WINCH e CONT
      # di run restano installati, i pipe di risveglio restano aperti, ISIG o
      # IXON non tornano com'erano, e {#running?} resta true: un nuovo run
      # dello stesso ciclo solleva Error, e serve un altro EventLoop. Servono
      # due segnali, il secondo in pochi passi di codice: nelle prove con 200
      # segnali a 0,2 ms di distanza la finestra non si è mai vista.
      #
      # Dopo run il flag di notcurses resta spento: fuori da run un Ctrl+C di
      # kitty non alza segnali e resta in coda, e il thread di input del run
      # successivo lo tratta quando lo legge. {Context#linesigs_enable} ridà il compito a notcurses,
      # con le ripetizioni e i rilasci. Con un contesto che scarta l'input
      # ({Context#drain_input?}) run non legge i tasti e lascia il compito a
      # notcurses, che scarta il tasto e alza il segnale. Limiti di notcurses
      # 3.0.17: senza un terminale (input da una pipe, niente /dev/tty)
      # linesigs_disable non spegne il flag; con input e output su due
      # terminali diversi notcurses cambia ISIG su quello di output, run su
      # quello di input; un Ctrl+C arrivato prima della presa in carico (al
      # primo run, o dopo {Context#linesigs_enable}) lo alza notcurses, e il
      # tasto resta in coda: il thread di input lo alza di nuovo, e con
      # no_linesigs lo consegna a {#on_key}; all'avvio di run un byte 0x03
      # arrivato nell'istante in cui ISIG è spento è un tasto; un carattere
      # UTF-8 di più byte spezzato fra due letture dell'input blocca il thread
      # di input di notcurses: run non riceve più tasti e {Context#close} non
      # ritorna ({Context#get}, ICH-463).
      #
      # Fiber scheduler. run installa lo scheduler dei task (vedi la classe)
      # e lo toglie alla fine. Con un task ancora pronto (che ha ceduto il
      # ciclo, o è appena stato sbloccato) il ciclo rende al massimo max_fps
      # volte al secondo; quando sta per attendere, o per uscire, rende subito.
      # Uno scheduler di un'altra libreria già attivo nel thread (per esempio
      # dentro +Async { }+) fa sollevare Error. Un run in un handler di un altro
      # run usa lo scheduler di quello: i suoi task restano fermi fino alla
      # fine del run annidato. Chiamato da un Fiber non bloccante, run esegue il
      # ciclo in un contesto bloccante; su Ruby 3.1 è un Fiber nuovo, e gli
      # handler non vedono i valori locali al Fiber (+Thread.current[:x]+).
      # Un'eccezione che un task non gestisce, anche nel suo ensure all'uscita,
      # esce da run come quella di un handler.
      #
      # @param no_flow_control [Boolean] disattiva IXON durante run
      # @param no_linesigs [Boolean] disattiva ISIG durante run
      #   ({Context#linesigs_disable})
      # @param max_fps [Numeric] render al secondo, al massimo, con un task
      #   ancora pronto: un numero finito maggiore di 0
      # @return [Symbol] :stop, :eof o :interrupt
      # @raise [Error] se il ciclo è già in esecuzione, o se nel thread è attivo
      #   il Fiber scheduler di un'altra libreria
      # @raise [ClosedError] se il contesto è chiuso
      # @raise [ContextError] se il terminale rifiuta il cambio di IXON o ISIG;
      #   un errore del ripristino finale non sostituisce l'eccezione di un
      #   handler, che resta quella sollevata
      # @raise [TypeError] se no_flow_control o no_linesigs non è un Boolean, o
      #   max_fps non è un numero
      # @raise [ArgumentError] se max_fps non è un numero finito maggiore di 0
      # @raise [Exception] l'eccezione di un handler, di un timer, di un blocco
      #   di {#post} o di un task
      def run(no_flow_control: false, no_linesigs: false, max_fps: 60)
        no_flow_control = Util.bool!(no_flow_control, 'no_flow_control')
        no_linesigs = Util.bool!(no_linesigs, 'no_linesigs')
        frame = frame_interval(max_fps)
        raise Error, 'EventLoop#run: il ciclo è già in esecuzione' if @running

        outer = Fiber.scheduler
        if outer && !outer.is_a?(Scheduler)
          raise Error, "EventLoop#run: nel thread è già attivo il Fiber scheduler #{outer.class} (per esempio " \
                       'dentro Async { }): chiama run fuori da quello scheduler'
        end

        @context.to_ptr
        @running = true
        wake_r = nil
        winch = false
        ixon = false
        linesigs = false
        filter = nil
        # qui e non nell'ensure: fra l'ingresso nell'ensure e il begin protetto un Interrupt salterebbe la pulizia
        pending = nil
        interrupted = nil
        task_error = nil
        done = false
        begin
          ixon = @context.flow_control_disable if no_flow_control
          # senza ISIG noto linesigs? solleva: con no_linesigs come prima, senza il ciclo non alza segnali
          isig = (no_linesigs || !FFI::ISIG.nil?) && @context.linesigs?
          if FFI::ISIG && !@context.drain_input?
            if @context.linesigs_flag?
              # notcurses alza i segnali dei tasti kitty e xterm da un flag suo, che stty non cambia, anche per
              # ripetizioni e rilasci (in.c:506): solo linesigs_disable lo spegne, insieme a ISIG
              linesigs = isig # da qui ISIG può restare spento: restore_terminal lo riaccende
              @context.linesigs_disable
              if isig && !no_linesigs
                @context.isig_enable
                linesigs = false
              end
            elsif no_linesigs && isig
              # flag già spento: linesigs_disable scriverebbe un avviso (in.c:2841), basta ISIG
              linesigs = true
              @context.isig_disable
            end
          elsif no_linesigs && isig
            # con drain_input notcurses scarta i tasti senza metterli in coda (in.c:518): il segnale resta suo
            @context.linesigs_disable
            linesigs = true
          end
          @line_signals = isig && !no_linesigs
          wake_r, @wake_w = IO.pipe
          # prima del thread di input: il SIGINT di un Ctrl+C già in coda non deve arrivare fra i due trap
          if @context.no_winch_sighandler?
            @old_winch = Signal.trap('WINCH') { resize_signal }
            # lo stesso flag toglie anche il gestore di SIGCONT di notcurses: dopo fg serve un refresh
            @old_cont = Signal.trap('CONT') { resize_signal }
            winch = true
          end
          # il thread di input del contesto legge i tasti e alza i segnali appena arrivano, anche con il
          # ciclo occupato; @input diventa leggibile quando ci sono eventi da consegnare
          unless @context.drain_input?
            # il filtro esiste prima dell'avvio: l'ensure lo toglie anche se un Interrupt arriva prima di @input
            filter = ->(input) { line_signal(input) }
            @input = @context.input_reader_start(SignalIds.new(@context.held_signal_keys), &filter)
          end
          @reason = :stop
          @dims = @context.dims
          render_frame
          @frame = frame
          # un run annidato usa lo scheduler del run esterno
          Fiber.set_scheduler(@scheduler = Scheduler.new(self)) unless outer
          # gli handler girano sul Fiber del ciclo, che deve essere bloccante: sleep e I/O non passano dallo scheduler
          Util.blocking { cycle([@input, wake_r].compact, wake_r) }
          @reason
        rescue Interrupt
          :interrupt
        rescue Exception => e # rubocop:disable Lint/RescueException
          # l'eccezione con cui run esce: nell'ensure $! è anche quella di un rescue esterno che chiama run
          pending = e
          raise
        ensure
          begin
            # un secondo Ctrl+C (o un'altra eccezione asincrona) arriva dopo la pulizia, non a metà
            Thread.handle_interrupt(Object => :never) do
              # per primo: i passi seguenti (join del thread di input) girano senza scheduler, anche fuori da
              # Util.blocking; close ferma i task in attesa, e gli ensure dei task girano con il contesto aperto
              if @scheduler
                Fiber.set_scheduler(nil)
                task_error ||= @scheduler.failure
                @scheduler = nil
              end
              # da qui il thread di input non alza più segnali
              stopped = @context.input_reader_stop(filter) if filter
              interrupted ||= stopped
              # nil vorrebbe dire IGNORE, che i processi figli erediterebbero
              if winch
                Signal.trap('WINCH', @old_winch || 'SYSTEM_DEFAULT')
                Signal.trap('CONT', @old_cont || 'SYSTEM_DEFAULT')
              end
              @wake_w&.close
              @wake_w = nil
              wake_r&.close
              @input = nil
              @stop_requested = false
              @running = false
              restore_terminal(ixon, linesigs, pending || interrupted)
              done = true
            end
          rescue SignalException => e
            # su Ruby 3.1, 3.2 e 3.3 handle_interrupt non rimanda l'Interrupt di un segnale: la pulizia, fatta di passi
            # idempotenti, ricomincia
            interrupted ||= e
            retry unless done
          end
          raise interrupted if interrupted && pending.nil?
          raise task_error if task_error && pending.nil?
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
      # vengono recuperate. Un'eccezione del blocco esce da {#run}, e il timer
      # resta programmato: scatta ancora nel run successivo, fino a
      # {Timer#cancel}.
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
      # anche maiuscola: notcurses consegna Ctrl+c come 'C' con Ctrl. Un
      # carattere stampabile corrisponde al carattere digitato
      # ({Input#eff_text}, per esempio '!' per Shift+1), quindi Shift non conta
      # (è già nel carattere, per esempio 'Q'); conta per gli altri codici,
      # come {Key::TAB} (Shift+Tab).
      #
      # Limite del protocollo tastiera kitty (Kitty, Ghostty): Alt o Ctrl con
      # Shift e un simbolo arrivano come il tasto senza Shift e senza testo
      # (Alt+Shift+1 è "\e[49;4u", con eff_text "1"), quindi
      # on_key('!', alt: true) corrisponde solo sui terminali classici.
      #
      # Tasti di controllo: notcurses 3.0.17 toglie al terminale solo ECHO,
      # ICANON e ICRNL, quindi di default Ctrl+C, Ctrl+Z e Ctrl+\ restano
      # segnali (ISIG) e Ctrl+S e Ctrl+Q restano il controllo di flusso (IXON):
      # non arrivano qui. Arrivano con {#run}(no_flow_control: true) per
      # Ctrl+S e Ctrl+Q e con {#run}(no_linesigs: true) per Ctrl+C, Ctrl+Z e
      # Ctrl+\. Vale anche con il protocollo kitty, dove CapsLock e NumLock si
      # aggiungono ai modificatori: {#run} li alza come segnali (vedi {#run}).
      # {#dispatch} di un evento costruito li consegna sempre.
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

      # Timer interno del Fiber scheduler di run: la scadenza di un'attesa di
      # un task. Non conta come lavoro del giro.
      #
      # @param seconds [Float] attesa, >= 0
      # @yield il blocco, nel thread del ciclo
      # @return [Timer]
      # @api private
      def add_internal_timer(seconds, &block)
        @seq += 1
        schedule(Timer.new(clock + seconds, nil, @seq, block, internal: true))
      end

      # Ferma timer e lo toglie dalla lista: un task che attende con un
      # timeout e riparte prima lascerebbe altrimenti un timer fermo nella
      # lista per ogni attesa, fino alla scadenza.
      #
      # @param timer [Timer]
      # @return [nil]
      # @api private
      def unschedule(timer)
        timer.cancel
        index = @timers.bsearch_index do |t|
          t.deadline > timer.deadline || (t.deadline == timer.deadline && t.seq >= timer.seq)
        end
        @timers.delete_at(index) if index && @timers[index].equal?(timer)
        nil
      end

      # Sveglia il ciclo: un byte sul pipe di risveglio. Da qualsiasi thread e
      # dai gestori +trap+; senza run non fa niente.
      #
      # @return [void]
      # @api private
      def wake
        @wake_w&.write_nonblock("\0", exception: false)
      rescue IOError, Errno::EPIPE
        nil # pipe chiuso da run in un altro thread: il ciclo è finito
      end

      private

      def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # @return [Float] secondi fra due render con un task ancora pronto
      def frame_interval(max_fps)
        fps = Util.float!(max_fps, 'max_fps')
        raise ArgumentError, "max_fps = #{max_fps}: serve un numero maggiore di 0" unless fps.positive?

        1.0 / fps
      end

      # I giri di run, nel Fiber bloccante del ciclo. Il primo giro non attende:
      # il run precedente può aver lasciato eventi nella coda di notcurses con il
      # pipe di prontezza già vuoto.
      def cycle(watched, wake_r)
        @scheduler&.loop_fiber = Fiber.current
        wait = false
        until @stop_requested
          # prima di select_timeout: un IO chiuso rende pronto il task
          readers, writers, priority = @scheduler ? @scheduler.io_sets : Scheduler::NO_IO
          begin
            ready = IO.select(readers.empty? ? watched : watched + readers, writers, priority, wait ? select_timeout : 0)
          rescue IOError
            # un altro thread ha chiuso l'IO di un task durante IO.select: il giro dopo io_sets lo trova chiuso
            raise unless [readers, writers, priority].any? { |ios| ios.any?(&:closed?) }

            ready = nil
          end
          wait = true
          drain(wake_r)
          step(ready)
        end
      end

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

      # Gestore di trap('WINCH') e trap('CONT'): solo un flag e un byte sul pipe.
      def resize_signal
        @resize_requested = true
        wake
      end

      # Riattiva IXON e ISIG tolti da run, tentando entrambi; il flag dei
      # segnali di notcurses resta spento (vedi {#run}), salvo con drain_input.
      # Con il contesto chiuso notcurses_stop ha già ripristinato il terminale
      # di prima dell'init. Un errore non sostituisce pending, l'eccezione che
      # sta uscendo da run.
      def restore_terminal(ixon, linesigs, pending)
        return if @context.closed?

        error = nil
        begin
          @context.flow_control_enable if ixon
        rescue ContextError => e
          error = e
        end
        begin
          if linesigs
            @context.drain_input? ? @context.linesigs_enable : @context.isig_enable
          end
        rescue ContextError => e
          error ||= e
        end
        raise error if error && !pending
      end

      def drain(reader)
        loop do
          data = reader.read_nonblock(4096, exception: false)
          break if data.nil? || data == :wait_readable
        end
      end

      # Timeout di IO.select: 0 con blocchi in coda, un resize da applicare o
      # un task pronto, nil senza timer. Al massimo un giorno: oltre time_t
      # IO.select solleva RangeError (after(Float::MAX)); il ciclo si sveglia,
      # non trova timer scaduti e riattende.
      def select_timeout
        return 0 if @resize_requested || !@queue.empty? || @scheduler&.ready?

        timer = @timers.first
        timer && (timer.deadline - clock).clamp(0, 86_400)
      end

      def live? = !@stop_requested && !@context.closed?

      # @param ready [Array(Array<IO>, Array<IO>, Array<IO>), nil] il risultato
      #   di IO.select, per i task che attendono un IO
      def step(ready = nil)
        worked = false
        worked |= handle_resize(refresh: true) if @resize_requested && live?
        worked |= read_input if @input && live?
        worked |= run_posted
        worked |= run_timers
        @scheduler&.resume_ready(*ready) { live? }
        if @context.closed?
          @stop_requested = true
        else
          ran = @scheduler&.ran!
          @dirty = true if worked || ran
          # con un task ancora pronto il giro successivo non attende: al massimo un render ogni @frame secondi
          throttled = !@stop_requested && @scheduler&.ready? && clock - @last_render < @frame
          render_frame if @dirty && !throttled
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
          else dispatch(input) # i tasti di segnale li ha già scartati il thread di input (line_signal)
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

          worked = true unless timer.internal? # il task ripartito conta da sé (Scheduler#ran!)
          begin
            timer.fire
          ensure
            # anche se il blocco solleva: un every attivo resta programmato
            reschedule(timer) if timer.interval && timer.active?
          end
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
        @dirty = false
        @last_render = clock
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
        return false unless mods.nobits?(MOD_OTHER) && mods.anybits?(MOD_CTRL) == ctrl && mods.anybits?(MOD_ALT) == alt
        # un carattere vale per il testo digitato: con il protocollo kitty id è il tasto senza Shift
        return (input.eff_text.empty? ? input.id : input.eff_text.ord) == id if printable?(id)

        input.id == id && mods.anybits?(MOD_SHIFT) == shift
      end

      # Filtro del thread di input ({Context#input_reader_start}), chiamato in
      # quel thread per gli eventi con un id di SignalIds: alza il segnale
      # appena il tasto arriva, una volta per pressione, anche con CapsLock o
      # NumLock (protocollo kitty) e con il ciclo occupato. run ha tolto il
      # compito a notcurses 3.0.17, che lo alzerebbe solo con Ctrl da solo e
      # anche per ripetizioni e rilasci (in.c:506). Con ISIG attivo questi
      # tasti non vengono consegnati.
      # Un byte classico non è un segnale: notcurses controlla Ctrl prima di
      # trasformare 0x03 in 'C' (in.c:539), e il campo ctrl della struct resta
      # falso (anche con kitty, che lo fa :press). La ripetizione e il rilascio
      # del tasto che ha alzato il segnale non arrivano nemmeno ai run dopo,
      # anche senza Ctrl (l'utente lascia Ctrl prima del tasto): il tasto resta
      # in {Context#held_signal_keys} fino al suo rilascio o a una sua nuova
      # pressione, con o senza Ctrl.
      # @return [Boolean] true se l'evento va scartato
      def line_signal(input)
        key = SIGNAL_KEYS[input.id]
        return false unless key

        held = @context.held_signal_keys
        if input.press?
          held.delete(key)
        elsif held.key?(key)
          held.delete(key) if input.release?
          return true
        end
        return false unless @line_signals && input.ctrl_field? && (input.modifiers & ~MOD_LOCKS) == MOD_CTRL

        if input.press?
          held[key] = true # prima del segnale: il thread principale lo gestisce subito, anche con un altro run
          # raise() come notcurses: pid 0 colpirebbe anche il gruppo (i figli di Subprocess)
          Process.kill(LINE_SIGNALS[key], Process.pid)
        end
        true
      end

      def printable?(id) = id >= 0x20 && id != 0x7f && id <= 0x10ffff && !Key.synthesized?(id)

      def input_handlers(input)
        @input_handlers.each { |handler| handler.call(input) }
      end
    end
  end
end
