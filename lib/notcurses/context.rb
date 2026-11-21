# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

# IO#wait_readable è nel core da Ruby 3.2: su 4.0 require 'io/wait' stampa un avviso.
require 'io/wait' unless IO.method_defined?(:wait_readable)
require 'tempfile'

module Notcurses
  @active_context = nil
  @context_lock = Mutex.new

  class << self
    # Contesto attivo nel processo (notcurses ne ammette uno solo, di qualsiasi
    # tipo: un secondo +notcurses_init+/+ncdirect_init+ fallisce).
    #
    # @return [Context, Direct, nil]
    def active_context = @active_context

    # Registra ctx come contesto attivo.
    #
    # @api private
    # @raise [InitError] se un altro contesto è già attivo
    def acquire_context(ctx)
      @context_lock.synchronize do
        if @active_context
          raise InitError, "un #{@active_context.class.name} è già attivo: notcurses ammette un solo " \
                           'contesto per processo (chiudi quello attivo prima di aprirne un altro)'
        end

        @active_context = ctx
      end
    end

    # Toglie ctx dal registro (no-op se ctx non è il contesto attivo). Funziona
    # anche dentro un gestore +trap+.
    #
    # @api private
    def release_context(ctx)
      @context_lock.synchronize { @active_context = nil if @active_context.equal?(ctx) }
    rescue ThreadError
      # in un gestore trap Ruby vieta Mutex#lock: il gestore gira nel thread principale con il GVL, e
      # solo il proprietario toglie la propria voce
      @active_context = nil if @active_context.equal?(ctx)
    end

    # Allineamento di un oggetto largo u in uno spazio largo avail
    # (+notcurses_align+).
    #
    # @param avail [Integer] spazio disponibile (colonne o righe), int del C
    # @param align [Symbol] :left, :center, :right (:top e :bottom sono
    #   sinonimi di :left e :right)
    # @param u [Integer] dimensione dell'oggetto, int del C
    # @return [Integer] offset dell'oggetto (negativo se u > avail)
    # @raise [TypeError, ArgumentError] se un argomento non è valido (anche
    #   :unaligned, per cui il C restituisce -INT_MAX)
    def align(avail, align, u)
      Util.int!(avail, 'avail')
      Util.int!(u, 'u')
      FFI.notcurses_align(avail, Util.placement_align_value(align), u)
    end
  end

  # Chiude all'uscita il contesto rimasto aperto, per lasciare il terminale in
  # uno stato pulito. Solo nel processo che l'ha creato: un figlio creato con
  # fork non deve ripristinare il terminale del padre.
  at_exit do
    ctx = Notcurses.active_context
    # anche un contesto già chiuso per le chiamate nuove: close esegue lo stop rimasto in attesa, se nessuna
    # operazione è in corso
    ctx.close if ctx && ctx.pid == Process.pid
  rescue StandardError => e
    warn "notcurses: chiusura del contesto all'uscita fallita: #{e.message}"
  end

  # Process.daemon fa il fork senza Process._fork, e il processo che ha creato
  # il contesto esce con _exit dentro daemon(3), senza lo stop: il terminale
  # resterebbe nel modo dell'init (niente echo, modo non canonico). Con un
  # contesto aperto in questo processo daemon solleva un errore prima del fork.
  # In un figlio creato con fork il contesto è del padre: daemon non cambia.
  # @api private
  module DaemonGuard
    # @raise [ContextError, DirectError] se un {Context} o un {Direct} creato
    #   da questo processo è ancora registrato (anche con lo stop in attesa)
    def daemon(...)
      ctx = Notcurses.active_context
      if ctx&.pid == Process.pid
        raise ctx.is_a?(Direct) ? DirectError : ContextError,
              "Process.daemon con un #{ctx.class.name} aperto: il processo che lo ha creato uscirebbe senza " \
              'ripristinare il terminale (chiudi il contesto prima di Process.daemon)'
      end

      super
    end
  end
  private_constant :DaemonGuard
  Process.singleton_class.prepend(DaemonGuard)

  # Capacità del terminale (+nccapabilities+), copiate al momento della lettura.
  class Capabilities
    # @return [Integer] numero di colori della palette
    attr_reader :colors

    # @param caps [FFI::NcCapabilities]
    # @api private
    def initialize(caps)
      @colors = caps[:colors]
      @utf8 = caps[:utf8]
      @rgb = caps[:rgb]
      @can_change_colors = caps[:can_change_colors]
      @halfblocks = caps[:halfblocks]
      @quadrants = caps[:quadrants]
      @sextants = caps[:sextants]
      @octants = caps[:octants]
      @braille = caps[:braille]
      @change_color = FFI.nccapability_canchangecolor(caps)
      freeze
    end

    # @return [Boolean] il terminale accetta UTF-8
    def utf8? = @utf8

    # @return [Boolean] il terminale accetta colori RGB a 24 bit
    def rgb? = @rgb

    # @return [Boolean] il terminale dichiara di poter cambiare la palette
    def can_change_colors? = @can_change_colors

    # @return [Boolean] la palette si può cambiare davvero: can_change_colors e
    #   almeno 256 colori (+nccapability_canchangecolor+)
    def can_change_color? = @change_color

    # @return [Boolean] semiblocchi (blitter 2x1) disponibili
    def halfblocks? = @halfblocks

    # @return [Boolean] quadranti (blitter 2x2) disponibili
    def quadrants? = @quadrants

    # @return [Boolean] sestanti (blitter 3x2) disponibili
    def sextants? = @sextants

    # @return [Boolean] ottanti (blitter 4x2) disponibili
    def octants? = @octants

    # @return [Boolean] Braille disponibile
    def braille? = @braille
  end

  # Contesto notcurses (+struct notcurses*+): il terminale in modalità
  # "rendered", con pile di piani, render e input.
  #
  # Un solo contesto (Context o {Direct}) può essere attivo nel processo.
  # Chiudi sempre il contesto: {.open} con un blocco lo fa da solo, anche in caso
  # di eccezione. All'uscita del processo un contesto rimasto aperto viene chiuso
  # da un hook +at_exit+, solo nel processo che l'ha creato. In un figlio creato
  # con +fork+ il contesto copiato resta del padre: {#close} lo segna chiuso
  # senza chiamare notcurses e senza toccare il terminale. +Process.daemon+
  # con il contesto aperto solleva ContextError prima del fork, e il contesto
  # resta aperto: chiudilo prima di +Process.daemon+ (il processo che lo ha
  # creato esce dentro daemon senza lo stop).
  #
  # Ciclo di vita degli oggetti collegati: i piani ({Plane}), i widget e gli
  # altri oggetti creati dal contesto diventano inutilizzabili (ClosedError)
  # quando il contesto si chiude; {#close} distrugge prima i widget ancora
  # aperti, poi chiama +notcurses_stop+, che libera tutti i piani.
  #
  # Thread: notcurses non è thread-safe. Usa il contesto e i suoi oggetti da un
  # solo thread alla volta; il wrapper non aggiunge lock.
  #
  # Effetti sul processo mentre il contesto è attivo: un thread di notcurses
  # legge stdin (fd 0, messo in O_NONBLOCK; non leggere STDIN da Ruby), il
  # terminale è in modalità cbreak e l'input non letto viene scartato da
  # {#close}. termtype: cambia ENV['TERM'] in modo permanente (il wrapper lo
  # ripristina solo se l'init fallisce).
  #
  # Resize del terminale: con il default no_winch_sighandler: true notcurses
  # non installa un gestore di SIGWINCH; {#render} e {#refresh} leggono
  # comunque le nuove dimensioni. Per reagire subito usa +trap('WINCH')+ e poi
  # {#refresh}. Con il gestore di notcurses l'evento {Key::RESIZE} arriva solo
  # insieme all'input successivo (notcurses blocca SIGWINCH e SIGCONT nel
  # thread interno che esegue l'init, non nei thread del chiamante).
  #
  # Lo stesso flag toglie anche il gestore di SIGCONT di notcurses: dopo
  # Ctrl+Z e fg il render non ridisegna tutto lo schermo (il testo scritto
  # dalla shell resta) e {Key::SIGNAL} non arriva. Il rimedio è un
  # +trap('CONT')+ che alza solo un flag, poi {#refresh} dal ciclo principale,
  # mai dentro il trap: notcurses non è rientrante. {UI::EventLoop#run} lo fa
  # già. Mentre il processo è fermo il terminale resta nel modo di notcurses
  # (schermo alternativo, tracciamento del mouse).
  #
  # @example
  #   Notcurses::Context.open do |nc|
  #     plane = nc.stdplane
  #     plane.set_fg_rgb(255, 200, 0).putstr('ciao', y: 1, x: 2)
  #     nc.render
  #     nc.get(timeout: 2)
  #   end
  class Context
    include Resource
    extend Resource::ClassMethods

    # Eventi del mouse per {#mice_enable}.
    MICE_EVENTS = {
      none: FFI::NCMICE_NO_EVENTS,
      move: FFI::NCMICE_MOVE_EVENT,
      button: FFI::NCMICE_BUTTON_EVENT,
      drag: FFI::NCMICE_DRAG_EVENT,
      all: FFI::NCMICE_ALL_EVENTS
    }.freeze

    # Slot di un blocco di lettura di {#getvec}: la coda di input di notcurses
    # tiene al più BUFSIZ eventi (8192 con glibc, in.c:1961).
    GETVEC_MAX = 8192
    private_constant :GETVEC_MAX

    # @return [Integer] pid del processo che ha creato il contesto
    # @api private
    attr_reader :pid

    # Contatore delle distruzioni di piani: invalida i piani "presi in
    # prestito" (vedi {Plane}).
    # @return [Integer]
    # @api private
    attr_reader :generation

    # Eccezioni sollevate dai callback chiamati dal C più tardi (resize, ...).
    # @return [Array<Exception>]
    # @api private
    attr_reader :callback_errors

    # Ripristini della cella base in corso (Plane#keeping_base_cell), da eseguire
    # prima di ogni callback Ruby di resize.
    # @return [Array<Proc>]
    # @api private
    attr_reader :base_restores

    # Avvia notcurses (+notcurses_init+, o +notcurses_core_init+ con core: true).
    #
    # @param termtype [String, nil] voce terminfo del terminale; nil = variabile
    #   TERM. notcurses la scrive in ENV['TERM']
    # @param output [String, ::FFI::Pointer, nil] dove scrivere i frame: nil =
    #   lo stdout della libc (fd 1); String = percorso aperto con fopen("w") e
    #   chiuso da {#close}; ::FFI::Pointer = un FILE* aperto dal chiamante, che
    #   resta suo e va chiuso dopo {#close}. Il FILE* deve avere un fd vero.
    #   Query, cursore e mouse vanno comunque al terminale (fd 1 se è un tty,
    #   altrimenti /dev/tty)
    # @param core [Boolean] true = +notcurses_core_init+ (niente multimedia)
    # @param loglevel [Symbol] :silent, :panic (default del C), :fatal, :error,
    #   :warning, :info, :verbose, :debug, :trace
    # @param margins [Array(Integer, Integer, Integer, Integer), String, nil]
    #   margini [alto, destra, basso, sinistra] (come in {Plane#create_child}),
    #   o una String nel formato di +notcurses_lex_margins+ ("1" oppure
    #   "alto,destra,basso,sinistra"); alternativo a margin_*
    # @param margin_t [Integer] margine superiore (righe), >= 0
    # @param margin_r [Integer] margine destro (colonne), >= 0
    # @param margin_b [Integer] margine inferiore (righe), >= 0
    # @param margin_l [Integer] margine sinistro (colonne), >= 0
    # @param inhibit_setlocale [Boolean] NCOPTION_INHIBIT_SETLOCALE
    # @param no_clear_bitmaps [Boolean] NCOPTION_NO_CLEAR_BITMAPS
    # @param no_winch_sighandler [Boolean] NCOPTION_NO_WINCH_SIGHANDLER. Default
    #   true (diverso dal C). Toglie il gestore di SIGWINCH e anche quello di
    #   SIGCONT: niente ridisegno completo dopo Ctrl+Z e fg, niente
    #   {Key::SIGNAL}. Rimedio: un +trap('CONT')+ che alza solo un flag, poi
    #   {#refresh} dal ciclo principale, mai dentro il trap (lo fa già
    #   {UI::EventLoop#run}). Vedi "Resize del terminale" nella descrizione
    #   della classe
    # @param no_quit_sighandlers [Boolean] NCOPTION_NO_QUIT_SIGHANDLERS. Default
    #   true (diverso dal C). Con false i gestori di notcurses per SIGINT,
    #   SIGTERM, SIGSEGV, ... terminano il processo subito (niente Interrupt,
    #   ensure o at_exit), e {#close} toglie lo stack alternativo dei segnali
    #   al thread principale di Ruby
    # @param preserve_cursor [Boolean] NCOPTION_PRESERVE_CURSOR
    # @param suppress_banners [Boolean] NCOPTION_SUPPRESS_BANNERS
    # @param no_alternate_screen [Boolean] NCOPTION_NO_ALTERNATE_SCREEN
    # @param no_font_changes [Boolean] NCOPTION_NO_FONT_CHANGES
    # @param drain_input [Boolean] NCOPTION_DRAIN_INPUT (l'input viene scartato:
    #   {#get} solleva InputError)
    # @param scrolling [Boolean] NCOPTION_SCROLLING (stdplane che scorre)
    # @param cli_mode [Boolean] NCOPTION_CLI_MODE (no_alternate_screen,
    #   no_clear_bitmaps, preserve_cursor e scrolling insieme)
    # Con un terminale vero l'init attende (senza timeout) la risposta del
    # terminale alle query iniziali, con il GVL rilasciato: gli altri thread
    # Ruby girano, ma non devono usare ENV (con termtype: notcurses chiama
    # setenv). L'init gira in un thread interno, che ferma anche il contesto
    # quando new non va a buon fine: un'eccezione asincrona durante l'attesa
    # (Ctrl-C, Thread#raise, Timeout, anche Thread#kill) arriva a init
    # completato e a contesto fermato, con il registro libero. Un secondo
    # Ctrl-C mentre new aspetta esce subito: il thread interno ferma il
    # contesto quando l'init torna, e fino ad allora il contesto resta
    # registrato (un nuovo init solleva InitError). Con un terminale che non
    # risponde mai l'init non torna, e il registro resta occupato. Resta una
    # finestra: un'eccezione arrivata proprio al ritorno di new, a contesto già
    # adottato, lo lascia aperto e registrato senza che il chiamante lo
    # riceva; lo chiudono <tt>Notcurses.active_context.close</tt> o l'hook
    # +at_exit+.
    #
    # @raise [InitError] se un altro contesto è attivo, se l'output non si apre,
    #   o se +notcurses_init+ restituisce NULL (per esempio terminfo non
    #   trovata per TERM o termtype, locale né UTF-8 né ASCII, margini che non
    #   lasciano spazio)
    # @raise [TypeError, ArgumentError] se un'opzione non è valida
    def initialize(termtype: nil, output: nil, core: false, loglevel: :panic, margins: nil,
                   margin_t: 0, margin_r: 0, margin_b: 0, margin_l: 0,
                   inhibit_setlocale: false, no_clear_bitmaps: false, no_winch_sighandler: true,
                   no_quit_sighandlers: true, preserve_cursor: false, suppress_banners: false,
                   no_alternate_screen: false, no_font_changes: false, drain_input: false,
                   scrolling: false, cli_mode: false)
      Util.bool!(core, 'core')
      opts = FFI::NotcursesOptions.new
      @termtype = Util.c_string(termtype, 'termtype')
      opts[:termtype] = @termtype || ::FFI::Pointer::NULL
      opts[:loglevel] = Util.enum_value(Util::LOGLEVELS, loglevel, 'loglevel')
      set_margins(opts, margins, margin_t, margin_r, margin_b, margin_l)
      opts[:flags] = Util.flag(inhibit_setlocale, FFI::NCOPTION_INHIBIT_SETLOCALE, 'inhibit_setlocale') |
                     Util.flag(no_clear_bitmaps, FFI::NCOPTION_NO_CLEAR_BITMAPS, 'no_clear_bitmaps') |
                     Util.flag(no_winch_sighandler, FFI::NCOPTION_NO_WINCH_SIGHANDLER, 'no_winch_sighandler') |
                     Util.flag(no_quit_sighandlers, FFI::NCOPTION_NO_QUIT_SIGHANDLERS, 'no_quit_sighandlers') |
                     Util.flag(preserve_cursor, FFI::NCOPTION_PRESERVE_CURSOR, 'preserve_cursor') |
                     Util.flag(suppress_banners, FFI::NCOPTION_SUPPRESS_BANNERS, 'suppress_banners') |
                     Util.flag(no_alternate_screen, FFI::NCOPTION_NO_ALTERNATE_SCREEN, 'no_alternate_screen') |
                     Util.flag(no_font_changes, FFI::NCOPTION_NO_FONT_CHANGES, 'no_font_changes') |
                     Util.flag(drain_input, FFI::NCOPTION_DRAIN_INPUT, 'drain_input') |
                     Util.flag(scrolling, FFI::NCOPTION_SCROLLING, 'scrolling') |
                     Util.flag(cli_mode, FFI::NCOPTION_CLI_MODE, 'cli_mode')
      @closed = true # fino alla fine dell'init: close e at_exit ignorano l'oggetto
      @pid = Process.pid # già durante l'init: la guardia di Process.daemon riconosce il contesto di questo processo
      old_term = fp = init = nil
      @own_fp = false
      go = Queue.new    # al thread di init: true per partire, poi true se il chiamante ha adottato il contesto
      ready = Queue.new # dal thread di init: il puntatore, o l'eccezione della chiamata C
      adopted = false
      start = lambda do
        old_term = ENV.fetch('TERM', nil)
        core ? FFI.notcurses_core_init(opts, fp) : FFI.notcurses_init(opts, fp)
      end
      undo = lambda do |ptr| # nel thread di init; ptr è nil se l'init non è partito
        if ptr
          stop_notcurses(ptr) unless ptr.null?
          # notcurses ha già scritto termtype in TERM: un init successivo senza termtype fallirebbe
          ENV['TERM'] = old_term unless termtype.nil?
        end
        Notcurses.release_context(self)
        FFI.fclose(fp) if @own_fp
      end
      begin
        init = Util.init_thread(go, ready, start, undo)
        Notcurses.acquire_context(self)
        # dopo acquire_context: con un altro contesto attivo il FILE* resterebbe aperto. Con le eccezioni asincrone
        # rimandate: arrivano a FILE* assegnato, e undo lo chiude
        Thread.handle_interrupt(Object => :never) { fp, @own_fp = open_output(output) }
        $stdout.flush if output.nil?
        go << true
        ptr = ready.pop
        raise ptr if ptr.is_a?(Exception)
        if ptr.null?
          raise InitError, 'notcurses_init ha restituito NULL (terminfo non trovata per TERM o termtype? ' \
                           'locale non UTF-8? margini troppo grandi?)'
        end

        @ptr = ptr
        @fp = fp
        @owner = nil
        @generation = 0
        @planes = {}
        @children = {}.compare_by_identity
        @callback_errors = []
        @base_restores = []
        @callback_depth = 0
        @callback_threads = {}.compare_by_identity
        @callback_errors_seen = 0
        @claims = [] # richieste di chiusura fisica: la esegue solo la prima (release_native!)
        @closing = false
        @closer = nil
        @close_error = nil
        @cursor_enabled = false
        @mice_enabled = false
        @drain_input = drain_input
        @no_winch_sighandler = no_winch_sighandler
        @linesigs_flag = initial_linesigs_flag
        @held_signal_keys = {}
        @input_reader = nil
        @stdplane = Plane.new(FFI.notcurses_stdplane(ptr), owned: false, context: self)
        @closed = false
        adopted = true
      ensure
        go << adopted # per prima, una sola chiamata C: né un secondo Ctrl-C né Thread#kill la saltano
        # il rollback è del thread di init: un secondo Ctrl-C esce dall'attesa, e il rollback continua
        init&.join unless adopted
      end
    end

    # Ferma notcurses e ripristina il terminale (+notcurses_stop+). Chiude prima
    # i widget e gli altri oggetti figli ancora aperti, in ordine inverso di
    # creazione; dopo la chiamata tutti i piani sono invalidi. Idempotente.
    #
    # Durante un'operazione del wrapper in corso in un altro thread (per
    # esempio {Visual#stream} o una chiamata C senza GVL) close segna subito il
    # contesto chiuso: le chiamate nuove sollevano ClosedError, anche quelle
    # del thread dell'operazione. Lo stop avviene alla fine dell'ultima
    # operazione in corso, nel suo thread, che riceve anche l'errore dello
    # stop; fino ad allora il contesto resta registrato come attivo (un nuovo
    # init solleva InitError). Se il processo esce prima che l'operazione
    # torni, il terminale può restare non ripristinato. {Visual.from_file},
    # {Visual#decode} e {Visual#decode_loop} non usano il contesto nel C e non
    # rinviano lo stop. Un'operazione sospesa in un Fiber (per esempio un
    # Enumerator esterno lasciato a metà su un metodo che passa i dati a un
    # blocco) resta in corso finché il Fiber non riprende: fino ad allora lo
    # stop resta in attesa, anche all'uscita del processo (ICH-541).
    #
    # Un'eccezione asincrona (per esempio un secondo Ctrl-C) prima dello stop
    # esce da close e lascia lo stop in attesa: un close successivo o l'hook
    # +at_exit+ lo eseguono.
    #
    # Un'eccezione sollevata durante la chiamata C (per esempio un Ctrl-C
    # mentre +notcurses_stop+ ripristina il terminale) esce da close, ma lascia
    # il contesto chiuso, i piani invalidi e il registro libero: un close
    # successivo e l'hook +at_exit+ non richiamano lo stop.
    #
    # Su macOS +notcurses_stop+ gira senza il GVL, perché aspetta che il
    # terminale legga l'output in coda: durante l'attesa gli altri thread Ruby
    # girano, e un'eccezione asincrona (Thread#raise, Timeout) per il thread
    # che chiude arriva solo dopo lo stop.
    #
    # In un processo figlio creato con +fork+ lo stato C appartiene al padre:
    # close non chiama notcurses (né il close degli oggetti figli), non scrive
    # sul terminale e non ne cambia il modo; segna solo il contesto chiuso,
    # invalida i piani e libera il registro Ruby. Nel figlio notcurses resta
    # inutilizzabile anche dopo close (i segnali restano registrati per il
    # contesto del padre, e un nuovo init solleva InitError): il figlio può
    # solo uscire o fare +exec+. +Process.daemon+ non crea un figlio così: con
    # il contesto aperto solleva ContextError prima del fork, e il contesto va
    # chiuso prima.
    #
    # close si può chiamare da un gestore +trap+ (per esempio
    # <tt>trap('TERM') { nc.close; exit }</tt>), anche se il gestore poi
    # torna al codice interrotto. Se il segnale ha interrotto un'operazione
    # del wrapper (o un callback chiamato dal C), lo stop avviene alla fine
    # dell'operazione e la chiamata successiva solleva ClosedError; durante
    # l'attesa di {#get} o {#getvec} lo stop è immediato e l'attesa solleva
    # ClosedError. Con +exit+ lo stop avviene mentre l'eccezione esce
    # dall'operazione; +exit!+ invece non esegue gli +ensure+, e lo stop
    # rinviato non avviene (terminale non ripristinato). Il registro si libera
    # allo stop, e un nuovo contesto si può aprire dopo. Durante
    # {UI::EventLoop#run} close ferma prima il thread di input; un Ctrl+C che
    # arriva mentre lo aspetta si solleva dopo lo stop. Limite di Ruby 3.1,
    # 3.2 e 3.3, dove l'Interrupt di un segnale non si rimanda (ICH-539): un
    # secondo segnale consegnato dopo il primo, prima che l'attesa ricominci,
    # esce da close prima dello stop, con il contesto aperto e il thread di
    # input che si ferma da solo poco dopo; un close successivo (o l'hook
    # +at_exit+) completa lo stop.
    #
    # @return [nil]
    # @raise [ContextError] se +notcurses_stop+ restituisce un errore (il
    #   contesto risulta comunque chiuso); con lo stop rinviato l'errore esce
    #   dall'operazione che lo esegue
    # @raise [Exception] la prima eccezione sollevata dal close di un oggetto
    #   figlio (per esempio quella del blocco di un {FdPlane}), dopo lo stop
    def close
      return nil if @closed
      # niente fclose: svuoterebbe sul terminale del padre i dati rimasti nel buffer del FILE*
      return mark_closed!(fclose: false) unless @pid == Process.pid
      return settle_close if @closing # già chiuso: esegue lo stop rimasto in attesa (hook at_exit)

      # il thread di input di run non deve chiamare notcurses dopo lo stop; un Ctrl+C arrivato mentre halt lo
      # aspetta si solleva alla fine
      interrupted = @input_reader&.halt
      # i figli con un thread Ruby (FdPlane, Subprocess) si fermano con il contesto ancora aperto: il loro
      # thread può essere dentro un'operazione sul contesto
      first_error = close_children(FdPlane)
      if @closing # un gestore trap o un altro thread hanno già chiuso il contesto
        raise interrupted if interrupted
        raise first_error if first_error

        return nil
      end

      @close_error = first_error
      @closing = true # prima di leggere il contatore delle operazioni in corso
      begin
        settle_close
      rescue Exception => e # rubocop:disable Lint/RescueException
        error = e
      end
      raise interrupted if interrupted
      raise error if error

      nil
    end
    alias stop close

    # Chiusura fisica, senza operazioni del wrapper in corso: chiude i figli in
    # ordine inverso di creazione, poi +notcurses_stop+. La esegue {#close}, o
    # l'ultima operazione in corso alla sua uscita (vedi {Guard}).
    #
    # @api private
    # @return [nil]
    # @raise [ContextError] se +notcurses_stop+ restituisce un errore
    # @raise [Exception] la prima eccezione del close di un oggetto figlio
    def release_native!
      return mark_closed!(fclose: false) unless @pid == Process.pid

      return nil if @closed

      claim = Object.new
      stopping = false
      begin
        # una sola esecuzione, anche se il contesto è in coda più volte: la esegue la prima richiesta della
        # lista. La lista, non una variabile locale, dice all'ensure se la chiusura era di questa esecuzione:
        # un'eccezione asincrona può arrivare al ritorno di ogni metodo C
        @claims << claim
        return nil unless @claims.first.equal?(claim)

        @closer = Thread.current # per questo thread il contesto resta aperto: il close dei figli lo usa
        first_error = @close_error
        children_error = close_children
        first_error ||= children_error
        # prima della chiamata: Ruby consegna un Ctrl-C al suo ritorno, quando il C ha già liberato il contesto
        @closed = true
        @closer = nil
        stopping = true
        begin
          rc = stop_notcurses(@ptr)
        ensure
          mark_closed!(fclose: @own_fp)
        end
      ensure
        if !stopping && @claims.first.equal?(claim) # interrotta prima dello stop (eccezione asincrona)
          # resta in attesa: lo stato prima della lista, la lista prima della coda
          @closed = false
          @closer = nil
          @claims.clear
          Guard.defer(self)
        end
      end
      raise first_error if first_error
      # notcurses_stop restituisce l'OR di più ritorni: qualsiasi valore diverso da 0 è un errore
      raise ContextError, "notcurses_stop fallita (#{rc})" unless rc.zero?

      nil
    end

    # true dopo {#close}. Durante la chiusura fisica il contesto resta aperto
    # solo per il thread che la esegue (il close dei figli lo usa).
    #
    # @return [Boolean]
    def closed?
      return true if @closed

      @closing && !Thread.current.equal?(@closer)
    end

    # Piano standard (+notcurses_stdplane+): sempre presente, grande quanto il
    # terminale (meno i margini), non distruggibile.
    #
    # @return [Plane]
    # @raise [ClosedError] se il contesto è chiuso
    def stdplane
      Guard.run do
        to_ptr
        @stdplane
      end
    end

    # Piano in cima alla pila dello stdplane (+notcurses_top+).
    # @return [Plane]
    # @raise [ClosedError] se il contesto è chiuso
    def top = Guard.run { plane_for(FFI.notcurses_top(to_ptr)) }

    # Piano in fondo alla pila dello stdplane (+notcurses_bottom+).
    # @return [Plane]
    # @raise [ClosedError] se il contesto è chiuso
    def bottom = Guard.run { plane_for(FFI.notcurses_bottom(to_ptr)) }

    # Dimensioni dell'area di rendering (+notcurses_term_dim_yx+): il terminale
    # meno i margini, come lo stdplane. Il valore cambia solo con {#render} o
    # {#refresh}.
    #
    # @return [Array(Integer, Integer)] [righe, colonne]
    # @raise [ClosedError] se il contesto è chiuso
    def dims
      Guard.run do
        rows = ::FFI::MemoryPointer.new(:uint)
        cols = ::FFI::MemoryPointer.new(:uint)
        FFI.notcurses_term_dim_yx(to_ptr, rows, cols)
        [rows.read_uint, cols.read_uint]
      end
    end

    # Dimensioni dello stdplane (+notcurses_stddim_yx+): uguali a {#dims}.
    #
    # @return [Array(Integer, Integer)] [righe, colonne]
    # @raise [ClosedError] se il contesto è chiuso
    def stddim
      Guard.run do
        rows = ::FFI::MemoryPointer.new(:uint)
        cols = ::FFI::MemoryPointer.new(:uint)
        FFI.notcurses_stddim_yx(to_ptr, rows, cols)
        [rows.read_uint, cols.read_uint]
      end
    end

    # Disegna la pila dello stdplane sul terminale (+notcurses_render+:
    # +ncpile_render+ più +ncpile_rasterize+).
    #
    # @return [self]
    # @raise [RenderError] se il render fallisce
    # @raise [Exception] l'eccezione sollevata da un callback Ruby (resize)
    #   durante il render
    # @raise [ClosedError] se il contesto è chiuso
    def render
      Guard.run do
        rc = FFI.notcurses_render(to_ptr)
        raise_callback_errors!
        Util.check!(rc, RenderError, 'notcurses_render')
        self
      end
    end

    # Ridisegna tutto il terminale e aggiorna le dimensioni (+notcurses_refresh+).
    #
    # @return [Array(Integer, Integer)] [righe, colonne] dell'area di rendering
    #   (il terminale meno i margini), come {#dims}
    # @raise [RenderError] se il refresh fallisce
    # @raise [ClosedError] se il contesto è chiuso
    def refresh
      Guard.run do
        rows = ::FFI::MemoryPointer.new(:uint)
        cols = ::FFI::MemoryPointer.new(:uint)
        rc = FFI.notcurses_refresh(to_ptr, rows, cols)
        raise_callback_errors!
        Util.check!(rc, RenderError, 'notcurses_refresh')
        [rows.read_uint, cols.read_uint]
      end
    end

    # Contenuto dell'ultimo frame scritto sul terminale alla posizione (y, x)
    # (+notcurses_at_yx+), in coordinate dell'area di rendering (margini
    # esclusi). La metà destra di un glifo largo risulta vuota (""), come la
    # cella "\n" che notcurses 3.0.17 lascia dopo un a capo (vedi {Plane#at}).
    #
    # @param y [Integer] riga, >= 0
    # @param x [Integer] colonna, >= 0
    # @return [Cell, nil] EGC, stili e canali della cella; nil prima del
    #   primo render o fuori dal frame
    # @raise [TypeError, ArgumentError] se y o x non sono interi >= 0
    # @raise [ClosedError] se il contesto è chiuso
    def at(y, x)
      Guard.run do
        Util.uint!(y, 'y')
        Util.uint!(x, 'x')
        styles = ::FFI::MemoryPointer.new(:uint16)
        channels = ::FFI::MemoryPointer.new(:uint64)
        egc = FFI.notcurses_at_yx(to_ptr, y, x, styles, channels)
        return nil if egc.null?

        Cell.from_c(Util.take_string(egc), styles.read_uint16, channels.read_uint64)
      end
    end

    # Distrugge tutti i piani tranne lo stdplane, in tutte le pile
    # (+notcurses_drop_planes+). I widget ancora aperti vengono chiusi prima,
    # perché i loro piani non esisterebbero più (con un ncreader aperto il C
    # farebbe un double free).
    #
    # Bug di 3.0.17 aggirato: +notcurses_drop_planes+ lascia una pila non
    # standard con 2 o più piani collegata a puntatori pendenti (double free
    # alla chiamata successiva o a {#close}). Il wrapper distrugge prima, piano
    # per piano, le pile che contengono un piano conosciuto; la funzione C
    # resta per il resto.
    #
    # Un'eccezione sollevata durante una chiamata C (per esempio un Ctrl-C)
    # esce da drop_planes: i piani già distrutti sono invalidi, gli altri
    # restano usabili, e un drop_planes successivo distrugge il resto.
    #
    # @return [self]
    # @raise [ContextError] dentro un callback chiamato da notcurses
    # @raise [ClosedError] se il contesto è chiuso
    # @raise [Exception] la prima eccezione sollevata dal close di un oggetto
    #   figlio, dopo il drop
    def drop_planes
      Guard.run do
        ptr = to_ptr
        check_not_in_callback!('drop_planes', ContextError)
        first_error = close_children
        std = @stdplane.address
        tops = {}
        tracked_planes.each do |plane|
          top = FFI.ncpile_top(plane.address_ptr)
          tops[top.address] = top
        end
        victims = []
        tops.each_value do |top|
          plane = top
          until plane.null?
            victims << plane unless plane.address == std
            plane = FFI.ncplane_below(plane)
          end
        end
        # ogni wrapper diventa invalido prima della sua distruzione: Ruby consegna un Ctrl-C al ritorno della
        # chiamata C, e un wrapper ancora aperto su un piano liberato farebbe un double free
        begin
          victims.each do |plane|
            @planes[plane.address]&.invalidate!
            FFI.ncplane_destroy(plane)
          end
          @planes.each_value { |plane| plane.invalidate! unless plane.equal?(@stdplane) }
          @planes.select! { |_addr, plane| plane.equal?(@stdplane) }
          FFI.notcurses_drop_planes(ptr)
        ensure
          planes_destroyed!
        end
        raise first_error if first_error

        self
      end
    end

    # Nuova pila con un piano radice (+ncpile_create+). Il piano restituito è
    # del chiamante. Le opzioni hanno lo stesso significato di
    # {Plane#create_child}, rispetto all'area di rendering ({#dims}: il
    # terminale meno i margini del contesto) invece che a un genitore. Una
    # pila nuova non viene disegnata da {#render}: usa {Plane#render_pile} su
    # uno dei suoi piani.
    #
    # @param rows [Integer, nil] righe, >= 1 (omesso se margins: è dato)
    # @param cols [Integer, nil] colonne, >= 1 (omesso se margins: è dato)
    # @param y [Integer] riga (gli allineamenti non sono ammessi: una pila non
    #   ha un genitore)
    # @param x [Integer] colonna
    # @param margins [Array(Integer, Integer, Integer, Integer), nil] [alto,
    #   destra, basso, sinistra] rispetto alle dimensioni attuali dell'area di
    #   rendering ({#dims}), non del terminale
    # @param name [String, nil] nome (per il debug)
    # @param fixed [Boolean] NCPLANE_OPTION_FIXED
    # @param autogrow [Boolean] NCPLANE_OPTION_AUTOGROW
    # @param vscroll [Boolean] NCPLANE_OPTION_VSCROLL
    # @param resize [Symbol, #call, nil] callback di resize (vedi {Plane#create_child})
    # @return [Plane] radice della nuova pila; con un blocco, il valore del blocco
    #   (il piano viene distrutto alla fine)
    # @raise [PlaneError] se +ncpile_create+ fallisce
    # @raise [TypeError, ArgumentError] se un'opzione non è valida
    # @raise [ClosedError] se il contesto è chiuso
    def create_pile(rows: nil, cols: nil, y: 0, x: 0, margins: nil, name: nil, fixed: false,
                    autogrow: false, vscroll: false, resize: nil, &block)
      created = Guard.run do
        if y.is_a?(Symbol) || x.is_a?(Symbol)
          raise ArgumentError, 'create_pile: y: e x: devono essere Integer (una pila non ha un genitore a cui allinearsi)'
        end

        opts, keep = Plane.build_options(context: self, parent_dims: dims, rows: rows, cols: cols, y: y, x: x,
                                         margins: margins, name: name, fixed: fixed, autogrow: autogrow,
                                         vscroll: vscroll, resize: resize)
        ptr = FFI.ncpile_create(to_ptr, opts)
        Util.check_ptr!(ptr, PlaneError, 'ncpile_create')
        plane = Plane.new(ptr, owned: true, context: self)
        plane.adopt_options!(keep)
        plane
      end
      Util.with_resource(created, &block)
    end

    # --- cursore ---

    # Mostra il cursore del terminale alla posizione (y, x) dell'area di
    # rendering (+notcurses_cursor_enable+). Il C non controlla i limiti: lo fa
    # il wrapper.
    #
    # @param y [Integer] riga, 0...righe dello stdplane
    # @param x [Integer] colonna, 0...colonne dello stdplane
    # @return [self]
    # @raise [ContextError] se il terminale non può mostrare il cursore
    # @raise [TypeError, ArgumentError] se y o x non sono interi nell'area
    # @raise [ClosedError] se il contesto è chiuso
    def cursor_enable(y: 0, x: 0)
      Guard.run do
        rows, cols = stddim
        Util.integer!(y, 'y', 0...rows)
        Util.integer!(x, 'x', 0...cols)
        Util.check!(FFI.notcurses_cursor_enable(to_ptr, y, x), ContextError, 'notcurses_cursor_enable')
        @cursor_enabled = true
        self
      end
    end

    # Nasconde il cursore del terminale (+notcurses_cursor_disable+).
    # Idempotente: con il cursore già nascosto non chiama il C (che
    # restituirebbe un errore). Dopo un'operazione di un {Reader}, che accende
    # e spegne il cursore da sé, chiama il C e tollera un cursore già nascosto.
    #
    # @return [self]
    # @raise [ContextError] se il terminale non nasconde il cursore acceso con
    #   {#cursor_enable} (sempre, senza un tty)
    # @raise [ClosedError] se il contesto è chiuso
    def cursor_disable
      Guard.run do
        ptr = to_ptr
        return self if @cursor_enabled == false

        rc = FFI.notcurses_cursor_disable(ptr)
        Util.check!(rc, ContextError, 'notcurses_cursor_disable') if @cursor_enabled
        @cursor_enabled = false
        self
      end
    end

    # Segna come sconosciuto lo stato del cursore del terminale. Lo chiama il
    # {Reader}: il suo ridisegno accende il cursore e la sua chiusura (con
    # cursor: true) lo spegne, senza passare da {#cursor_enable} e
    # {#cursor_disable}.
    # @return [void]
    # @api private
    def cursor_state_unknown!
      @cursor_enabled = nil
    end

    # Posizione di scrittura del terminale dopo l'ultimo frame
    # (+notcurses_cursor_yx+), in coordinate assolute del terminale (margini
    # compresi). Non è la posizione chiesta con {#cursor_enable}.
    #
    # @return [Array(Integer, Integer), nil] [y, x], o nil se notcurses non ha
    #   ancora scritto nulla
    # @raise [ClosedError] se il contesto è chiuso
    def cursor_yx
      Guard.run do
        y = ::FFI::MemoryPointer.new(:int)
        x = ::FFI::MemoryPointer.new(:int)
        FFI.notcurses_cursor_yx(to_ptr, y, x)
        pos = [y.read_int, x.read_int]
        pos.include?(-1) ? nil : pos
      end
    end

    # --- schermo ---

    # Passa allo schermo alternativo (+notcurses_enter_alternate_screen+).
    # Disattiva lo scrolling dello stdplane.
    #
    # @return [self]
    # @raise [ContextError] senza un tty, se il terminale non ha lo schermo
    #   alternativo o se il contesto è nato con no_alternate_screen: true
    # @raise [ClosedError] se il contesto è chiuso
    def enter_alternate_screen
      Guard.run do
        Util.check!(FFI.notcurses_enter_alternate_screen(to_ptr), ContextError, 'notcurses_enter_alternate_screen')
        self
      end
    end

    # Esce dallo schermo alternativo (+notcurses_leave_alternate_screen+).
    #
    # @return [self]
    # @raise [ContextError] senza un tty o se l'uscita fallisce
    # @raise [ClosedError] se il contesto è chiuso
    def leave_alternate_screen
      Guard.run do
        Util.check!(FFI.notcurses_leave_alternate_screen(to_ptr), ContextError, 'notcurses_leave_alternate_screen')
        self
      end
    end

    # --- input ---

    # Legge un evento di input (+notcurses_get_nblock+).
    #
    # L'attesa non avviene dentro il C: il wrapper attende con +IO#wait_readable+
    # sul descrittore di +notcurses_inputready_fd+, che rilascia il GVL, quindi
    # gli altri thread Ruby e i segnali (Ctrl-C → Interrupt) restano serviti.
    #
    # Durante {UI::EventLoop#run} i tasti li legge un thread di input del
    # contesto, che alza i segnali di Ctrl+C, Ctrl+Z e Ctrl+\ e scarta quei
    # tasti: get (per esempio in un handler) restituisce gli eventi che il
    # thread ha già letto, e attende sul suo pipe. Gli eventi letti dal thread
    # e non consegnati da run arrivano ai get successivi, prima della coda di
    # notcurses.
    #
    # Limite di notcurses 3.0.17 (ICH-463): se una lettura dell'input finisce a
    # metà di un carattere UTF-8 di più byte, il thread di input di notcurses
    # gira per sempre su quei byte (process_melange, in.c:2402-2434). get non
    # riceve più eventi e {#close} non ritorna. Succede quando notcurses legge
    # stdin senza un terminale separato: stdin sul terminale (per esempio un
    # incolla lungo di testo non ASCII) o rediretto senza /dev/tty. Il wrapper
    # non lo può evitare: la correzione è proposta a notcurses (PR #2954).
    #
    # @param timeout [Numeric, nil] secondi di attesa massima, 0..2147483647
    #   (2^31 - 1, circa 68 anni); nil = attende senza limite; 0 = non attende
    # @return [Input, nil] l'evento, o nil se il timeout scade. Con stdin chiuso
    #   restituisce un evento con id {Key::EOF}
    # @raise [InputError] se notcurses segnala un errore di input, o se il
    #   contesto scarta l'input (drain_input: true)
    # @raise [TypeError, ArgumentError] se timeout non è un numero in
    #   0..2147483647
    # @raise [ClosedError] se il contesto è chiuso, anche durante l'attesa
    def get(timeout: nil)
      wait_input(timeout) { next_input }
    end

    # Legge fino a count eventi già pronti (+notcurses_getvec+). Attende come
    # {#get} finché ce n'è almeno uno; durante {UI::EventLoop#run} legge, come
    # {#get}, gli eventi del thread di input. Il risultato si ferma al primo evento
    # {Key::EOF} (il C riempirebbe tutto il vettore di EOF). Legge a blocchi di
    # 8192 eventi, la dimensione della coda di input di notcurses, finché la
    # coda è vuota o count è raggiunto: la memoria dipende dagli eventi letti,
    # non da count.
    #
    # @param count [Integer] numero massimo di eventi, 1..INT_MAX
    # @param timeout [Numeric, nil] come in {#get}: 0..2147483647, o nil
    # @return [Array<Input>] da 1 a count eventi; vuoto se il timeout scade
    # @raise [InputError] se notcurses segnala un errore di input
    # @raise [TypeError, ArgumentError] se un argomento non è valido (count
    #   fuori da 1..INT_MAX, timeout fuori da 0..2147483647)
    # @raise [ClosedError] se il contesto è chiuso, anche durante l'attesa
    def getvec(count, timeout: nil)
      Util.integer!(count, 'count', 1..Util::INT32.max)
      result = wait_input(timeout) { queued_inputs(count) }
      return [] if result.nil?

      eof = result.index { |ev| ev.id == Key::EOF }
      eof ? result[0..eof] : result
    end

    # @return [Boolean] true se il contesto scarta l'input (drain_input: true):
    #   {#get} e {#getvec} sollevano InputError
    # @raise [ClosedError] se il contesto è chiuso
    def drain_input?
      Guard.run do
        to_ptr
        @drain_input
      end
    end

    # @return [Boolean] true se notcurses non ha installato il proprio gestore
    #   di SIGWINCH e SIGCONT (no_winch_sighandler: true, il default del
    #   wrapper): per reagire subito al resize serve +trap('WINCH')+, per
    #   ridisegnare dopo Ctrl+Z e fg serve +trap('CONT')+ e poi {#refresh} fuori
    #   dal trap (vedi "Resize del terminale" nella descrizione della classe)
    # @raise [ClosedError] se il contesto è chiuso
    def no_winch_sighandler?
      Guard.run do
        to_ptr
        @no_winch_sighandler
      end
    end

    # Descrittore che diventa leggibile quando c'è input
    # (+notcurses_inputready_fd+). Non chiuderlo. Durante {UI::EventLoop#run}
    # il descrittore è del thread di input, che svuota la coda di notcurses:
    # per attendere un tasto usa {#get} con un timeout. Dopo run il thread può
    # aver lasciato eventi nel suo buffer, che il descrittore non segnala:
    # prima di attendere su di esso chiama {#get}(timeout: 0) finché
    # restituisce nil.
    #
    # @return [Integer]
    # @raise [InputError] se il descrittore non è disponibile
    # @raise [ClosedError] se il contesto è chiuso
    def inputready_fd
      Guard.run do
        Util.check!(FFI.notcurses_inputready_fd(to_ptr), InputError, 'notcurses_inputready_fd')
      end
    end

    # Abilita gli eventi del mouse (+notcurses_mice_enable+). Il terminale ha
    # una sola modalità: :move include :drag, che include :button.
    #
    # @param events [Symbol, Array<Symbol>] :all, :move, :button, :drag, :none
    # @return [self]
    # @raise [ContextError] senza un tty o se il terminale rifiuta
    # @raise [ArgumentError] se events non è valido
    # @raise [ClosedError] se il contesto è chiuso
    def mice_enable(events: :all)
      Guard.run do
        ptr = to_ptr
        mask = Array(events).reduce(0) { |m, ev| m | Util.enum_value(MICE_EVENTS, ev, 'events') }
        Util.check!(FFI.notcurses_mice_enable(ptr, mask), ContextError, 'notcurses_mice_enable')
        @mice_enabled = !mask.zero?
        self
      end
    end

    # Disabilita gli eventi del mouse (+notcurses_mice_disable+). Idempotente:
    # con il mouse già spento non chiama il C (che senza un tty restituirebbe
    # un errore). Gli eventi già in coda restano.
    #
    # @return [self]
    # @raise [ContextError] se il terminale rifiuta
    # @raise [ClosedError] se il contesto è chiuso
    def mice_disable
      Guard.run do
        ptr = to_ptr
        return self unless @mice_enabled

        Util.check!(FFI.notcurses_mice_disable(ptr), ContextError, 'notcurses_mice_disable')
        @mice_enabled = false
        self
      end
    end

    # Disabilita i segnali generati dalla tastiera (Ctrl-C, Ctrl-Z, ...)
    # (+notcurses_linesigs_disable+).
    #
    # @return [self]
    # @raise [ContextError] se la modifica del terminale fallisce
    # @raise [ClosedError] se il contesto è chiuso
    def linesigs_disable
      Guard.run do
        Util.check!(FFI.notcurses_linesigs_disable(to_ptr), ContextError, 'notcurses_linesigs_disable')
        @linesigs_flag = false
        self
      end
    end

    # Riabilita i segnali generati dalla tastiera (+notcurses_linesigs_enable+).
    #
    # @return [self]
    # @raise [ContextError] se la modifica del terminale fallisce
    # @raise [ClosedError] se il contesto è chiuso
    def linesigs_enable
      Guard.run do
        Util.check!(FFI.notcurses_linesigs_enable(to_ptr), ContextError, 'notcurses_linesigs_enable')
        @linesigs_flag = true
        self
      end
    end

    # Stato del flag privato con cui notcurses alza SIGINT, SIGSTOP e SIGQUIT
    # per Ctrl+C, Ctrl+Z e Ctrl+\ di kitty e di xterm (in.c:506-516). Il C non
    # lo lascia leggere: lo tiene il wrapper. All'init il flag segue ISIG del
    # terminale, ed è acceso senza terminale (termdesc.c:1400-1404); lo
    # cambiano solo {#linesigs_disable} e {#linesigs_enable}. Lo usa
    # {UI::EventLoop#run}, per non chiamare linesigs_disable con il flag già
    # spento (notcurses scriverebbe un avviso).
    #
    # @return [Boolean] true se il flag è acceso
    # @raise [ClosedError] se il contesto è chiuso
    # @api private
    def linesigs_flag?
      Guard.run do
        to_ptr
        @linesigs_flag
      end
    end

    # Tasti di segnale (Ctrl+C, Ctrl+Z, Ctrl+\) per cui {UI::EventLoop#run} ha
    # alzato il segnale e di cui non è ancora arrivato il rilascio: la loro
    # ripetizione e il loro rilascio non arrivano a nessun ciclo. Sta nel
    # contesto, come la coda dei tasti. Una voce per tasto, tolta dal suo
    # rilascio o da una nuova pressione dello stesso tasto.
    #
    # @return [Hash{Integer => true}] id del tasto (per esempio 'C'.ord);
    #   modificabile, solo per {UI::EventLoop}
    # @raise [ClosedError] se il contesto è chiuso
    # @api private
    def held_signal_keys
      Guard.run do
        to_ptr
        @held_signal_keys
      end
    end

    # Avvia il thread di input di {UI::EventLoop#run} (+InputReader+), o
    # aggiunge il filtro di un run annidato di un altro ciclo sullo stesso
    # contesto: vale il filtro del run più interno. Finché il thread gira,
    # {#get} e {#getvec} leggono solo gli eventi che il thread non ha scartato.
    #
    # @param ids [#key?] id degli eventi da passare al filtro (gli altri vanno
    #   nel buffer senza filtro): un Hash, o un oggetto con key? che il thread
    #   di input chiama per ogni evento
    # @yieldparam input [Input] evento letto con un id in ids, nel thread di
    #   input
    # @yieldreturn [Boolean] true per scartarlo
    # @return [IO] pipe che diventa leggibile quando arrivano eventi; poi
    #   {#get}(timeout: 0) fino a nil
    # @raise [InputError] se il descrittore di input non è disponibile
    # @raise [ClosedError] se il contesto è chiuso
    # @api private
    def input_reader_start(ids, &filter)
      Guard.run do
        to_ptr
        @input_reader ||= InputReader.new(-> { inputready_fd }, ->(buf, slots) { getvec_into(buf, slots) })
        @input_reader.start(filter, ids)
      end
    end

    # Toglie il filtro di un run, se {#input_reader_start} l'ha registrato;
    # senza altri run ferma il thread di input. Funziona anche con il contesto
    # chiuso ({#close} ha già fermato il thread).
    #
    # @param filter [Proc] il blocco passato a {#input_reader_start}
    # @return [Exception, nil] l'eccezione asincrona (un altro Ctrl+C) arrivata
    #   mentre aspettava il thread, da sollevare dopo la pulizia del chiamante
    # @api private
    def input_reader_stop(filter)
      @input_reader&.stop(filter)
    end

    # Disattiva il controllo di flusso (IXON), che notcurses lascia attivo:
    # Ctrl+S e Ctrl+Q arrivano come input invece di fermare e riprendere
    # l'output. Agisce sul terminale da cui notcurses legge i tasti (stdin se
    # è un tty, altrimenti /dev/tty); senza terminale non fa nulla. Lo usa
    # {UI::EventLoop#run}.
    #
    # @return [Boolean] true se IXON era attivo (da riattivare con
    #   {#flow_control_enable})
    # @raise [ContextError] se tcgetattr o tcsetattr falliscono, o se IXON non
    #   è noto su questo sistema
    # @raise [ClosedError] se il contesto è chiuso
    # @api private
    def flow_control_disable
      Guard.run do
        to_ptr
        input_tty { |fd| ixon!(fd, false) }
      end
    end

    # Riattiva il controllo di flusso (IXON) sul terminale di
    # {#flow_control_disable}.
    #
    # @return [self]
    # @raise [ContextError] se tcgetattr o tcsetattr falliscono, o se IXON non
    #   è noto su questo sistema
    # @raise [ClosedError] se il contesto è chiuso
    # @api private
    def flow_control_enable
      Guard.run do
        to_ptr
        input_tty { |fd| ixon!(fd, true) }
        self
      end
    end

    # Legge ISIG sul terminale di {#flow_control_disable}: false se
    # {#linesigs_disable} o +stty -isig+ hanno già tolto i segnali. Lo usa
    # {UI::EventLoop#run}.
    #
    # @return [Boolean] true se ISIG è attivo; false anche senza terminale
    # @raise [ContextError] se tcgetattr fallisce, o se ISIG non è noto su
    #   questo sistema
    # @raise [ClosedError] se il contesto è chiuso
    # @api private
    def linesigs?
      Guard.run do
        to_ptr
        raise ContextError, "segnali da tastiera: ISIG non noto su #{RUBY_PLATFORM}" unless FFI::ISIG

        input_tty { |fd| termios(fd)[:c_lflag].anybits?(FFI::ISIG) }
      end
    end

    # Riaccende ISIG sul terminale di {#flow_control_disable}, senza
    # riaccendere i segnali che notcurses alza per i tasti kitty e xterm
    # ({#linesigs_enable} riaccende entrambi). Lo usa {UI::EventLoop#run}, che
    # quei segnali li alza da sé.
    #
    # @return [self]
    # @raise [ContextError] se tcgetattr o tcsetattr falliscono, o se ISIG non
    #   è noto su questo sistema
    # @raise [ClosedError] se il contesto è chiuso
    # @api private
    def isig_enable
      Guard.run do
        to_ptr
        raise ContextError, "segnali da tastiera: ISIG non noto su #{RUBY_PLATFORM}" unless FFI::ISIG

        input_tty { |fd| tty_flag!(fd, :c_lflag, FFI::ISIG, true) }
        self
      end
    end

    # Spegne ISIG sul terminale di {#flow_control_disable}, senza toccare il
    # flag dei segnali di notcurses ({#linesigs_flag?}). Lo usa
    # {UI::EventLoop#run}(no_linesigs: true) quando il flag è già spento.
    #
    # @return [self]
    # @raise [ContextError] se tcgetattr o tcsetattr falliscono, o se ISIG non
    #   è noto su questo sistema
    # @raise [ClosedError] se il contesto è chiuso
    # @api private
    def isig_disable
      Guard.run do
        to_ptr
        raise ContextError, "segnali da tastiera: ISIG non noto su #{RUBY_PLATFORM}" unless FFI::ISIG

        input_tty { |fd| tty_flag!(fd, :c_lflag, FFI::ISIG, false) }
        self
      end
    end

    # --- capacità ---

    # @return [Boolean] colori RGB a 24 bit (+notcurses_cantruecolor+)
    # @raise [ClosedError] se il contesto è chiuso
    def can_truecolor? = Guard.run { FFI.notcurses_cantruecolor(to_ptr) }

    # @return [Boolean] palette modificabile (+notcurses_canchangecolor+)
    # @raise [ClosedError] se il contesto è chiuso
    def can_change_color? = Guard.run { FFI.notcurses_canchangecolor(to_ptr) }

    # @return [Boolean] dissolvenze possibili (+notcurses_canfade+)
    # @raise [ClosedError] se il contesto è chiuso
    def can_fade? = Guard.run { FFI.notcurses_canfade(to_ptr) }

    # @return [Boolean] UTF-8 disponibile (+notcurses_canutf8+)
    # @raise [ClosedError] se il contesto è chiuso
    def can_utf8? = Guard.run { FFI.notcurses_canutf8(to_ptr) }

    # @return [Boolean] semiblocchi disponibili (+notcurses_canhalfblock+)
    # @raise [ClosedError] se il contesto è chiuso
    def can_halfblock? = Guard.run { FFI.notcurses_canhalfblock(to_ptr) }

    # @return [Boolean] quadranti disponibili (+notcurses_canquadrant+)
    # @raise [ClosedError] se il contesto è chiuso
    def can_quadrant? = Guard.run { FFI.notcurses_canquadrant(to_ptr) }

    # @return [Boolean] sestanti disponibili (+notcurses_cansextant+)
    # @raise [ClosedError] se il contesto è chiuso
    def can_sextant? = Guard.run { FFI.notcurses_cansextant(to_ptr) }

    # @return [Boolean] ottanti disponibili (+notcurses_canoctant+)
    # @raise [ClosedError] se il contesto è chiuso
    def can_octant? = Guard.run { FFI.notcurses_canoctant(to_ptr) }

    # @return [Boolean] Braille disponibile (+notcurses_canbraille+)
    # @raise [ClosedError] se il contesto è chiuso
    def can_braille? = Guard.run { FFI.notcurses_canbraille(to_ptr) }

    # @return [Boolean] grafica a pixel disponibile (+notcurses_canpixel+)
    # @raise [ClosedError] se il contesto è chiuso
    def can_pixel? = Guard.run { FFI.notcurses_canpixel(to_ptr) }

    # @return [Boolean] caricamento di immagini disponibile (+notcurses_canopen_images+)
    # @raise [ClosedError] se il contesto è chiuso
    def can_open_images? = Guard.run { FFI.notcurses_canopen_images(to_ptr) }

    # @return [Boolean] caricamento di video disponibile (+notcurses_canopen_videos+)
    # @raise [ClosedError] se il contesto è chiuso
    def can_open_videos? = Guard.run { FFI.notcurses_canopen_videos(to_ptr) }

    # @return [Array<Symbol>] stili che il terminale sa mostrare (+notcurses_supported_styles+)
    # @raise [ClosedError] se il contesto è chiuso
    def supported_styles = Guard.run { Util.styles_symbols(FFI.notcurses_supported_styles(to_ptr)) }

    # @return [Integer] colori della palette (+notcurses_palette_size+)
    # @raise [ClosedError] se il contesto è chiuso
    def palette_size = Guard.run { FFI.notcurses_palette_size(to_ptr) }

    # Nome del terminale rilevato (+notcurses_detected_terminal+).
    # @return [String, nil] i byte che non sono UTF-8 valido (per esempio
    #   nella versione inviata dal terminale) diventano U+FFFD
    # @raise [ClosedError] se il contesto è chiuso
    def detected_terminal = Guard.run { Util.take_string(FFI.notcurses_detected_terminal(to_ptr)) }

    # Capacità del terminale (+notcurses_capabilities+), copiate.
    # @return [Capabilities]
    # @raise [ClosedError] se il contesto è chiuso
    def capabilities = Guard.run { Capabilities.new(FFI.notcurses_capabilities(to_ptr)) }

    # Implementazione della grafica a pixel (+notcurses_check_pixel_support+).
    # @return [Symbol] :none, :sixel, :linuxfb, :iterm2, :kitty_static,
    #   :kitty_animated o :kitty_selfref
    # @raise [ClosedError] se il contesto è chiuso
    def pixel_support = Guard.run { Util.enum_symbol(Util::PIXEL_IMPLS, FFI.notcurses_check_pixel_support(to_ptr)) }

    # Colore di primo piano di default del terminale (+notcurses_default_foreground+).
    # @return [Integer, nil] 0xRRGGBB, o nil se il terminale non lo comunica
    # @raise [ClosedError] se il contesto è chiuso
    def default_foreground
      Guard.run do
        out = ::FFI::MemoryPointer.new(:uint32)
        FFI.notcurses_default_foreground(to_ptr, out).negative? ? nil : out.read_uint32
      end
    end

    # Colore di sfondo di default del terminale (+notcurses_default_background+).
    # @return [Integer, nil] 0xRRGGBB, o nil se il terminale non lo comunica
    # @raise [ClosedError] se il contesto è chiuso
    def default_background
      Guard.run do
        out = ::FFI::MemoryPointer.new(:uint32)
        FFI.notcurses_default_background(to_ptr, out).negative? ? nil : out.read_uint32
      end
    end

    # --- palette e statistiche ---

    # Copia della palette corrente (+ncpalette_new+).
    # @return [Palette]
    # @raise [ContextError] se l'allocazione fallisce
    # @raise [ClosedError] se il contesto è chiuso
    def palette = Palette.new(self)

    # Statistiche correnti (+notcurses_stats+).
    # @return [Stats]
    # @raise [ClosedError] se il contesto è chiuso
    def stats = Stats.collect(self, reset: false)

    # Statistiche correnti, poi azzera i contatori cumulativi
    # (+notcurses_stats_reset+).
    # @return [Stats] i valori prima dell'azzeramento
    # @raise [ClosedError] se il contesto è chiuso
    def reset_stats = Stats.collect(self, reset: true)

    # Stato interno delle pile, come testo (+notcurses_debug+).
    # @return [String]
    # @raise [ContextError] se il file temporaneo non si apre
    # @raise [ClosedError] se il contesto è chiuso
    def debug
      Guard.run do
        ptr = to_ptr
        Tempfile.create('notcurses-debug') do |tmp|
          fp = FFI.fopen(tmp.path, 'w')
          raise ContextError, "fopen(#{tmp.path}) fallita" if fp.null?

          begin
            FFI.notcurses_debug(ptr, fp)
          ensure
            FFI.fclose(fp)
          end
          File.read(tmp.path, mode: 'rb').force_encoding(Encoding::UTF_8)
        end
      end
    end

    # --- registro interno (usato da Plane e dai widget) ---

    # @api private
    def track_plane(plane)
      addr = plane.address
      stale = @planes[addr]
      stale.invalidate! if stale && !stale.equal?(plane)
      @planes[addr] = plane
    end

    # @api private
    def untrack_plane(plane)
      @planes.delete(plane.address) if @planes[plane.address].equal?(plane)
    end

    # Piano conosciuto con questo puntatore, oppure un piano "preso in prestito".
    # @api private
    # @return [Plane, nil] nil se ptr è NULL
    def plane_for(ptr)
      return nil if ptr.nil? || ptr.null?

      tracked_plane(ptr.address) || Plane.new(ptr, owned: false, context: self, tracked: false)
    end

    # @api private
    # @return [Plane, nil] il piano tracciato e aperto con questo indirizzo
    def tracked_plane(addr)
      plane = @planes[addr]
      plane if plane && !plane.closed?
    end

    # @api private
    # @return [Array<Plane>] piani conosciuti e ancora aperti
    def tracked_planes = @planes.values.reject(&:closed?)

    # Registra una distruzione di piani: i piani presi in prestito diventano
    # invalidi.
    # @api private
    def planes_destroyed!
      @generation += 1
    end

    # Registra un oggetto figlio (widget, ...) da chiudere prima di notcurses_stop.
    # @api private
    def adopt(child)
      @children[child] = true
    end

    # @api private
    def disown(child)
      @children.delete(child)
    end

    # Rilancia l'eccezione salvata da un callback. Dentro un callback solo quella
    # salvata dopo il suo ingresso: l'eccezione di un callback fratello la
    # rilancia la chiamata esterna, senza interrompere a metà questo callback.
    # @api private
    def raise_callback_errors!
      Util.reraise!(@callback_errors) if @callback_errors.size > @callback_errors_seen
    end

    # Esegue il blocco come callback chiamato dal C. Durante il blocco il C sta
    # ancora percorrendo le sue liste di piani: distruggere o spostare piani
    # sarebbe un use-after-free, e {#check_not_in_callback!} lo impedisce.
    # @api private
    def callback_scope
      me = Thread.current
      @callback_depth += 1
      @callback_threads[me] = @callback_threads.fetch(me, 0) + 1
      seen = @callback_errors_seen
      @callback_errors_seen = @callback_errors.size
      yield
    ensure
      @callback_errors_seen = seen
      @callback_depth -= 1
      depth = @callback_threads[me].to_i
      if depth > 1
        @callback_threads[me] = depth - 1
      else
        @callback_threads.delete(me)
      end
    end

    # true se il thread corrente è dentro un callback chiamato dal C.
    # @api private
    # @return [Boolean]
    def in_callback? = @callback_threads.key?(Thread.current)

    # @api private
    # @raise [Error] (della classe error) se è in corso un callback chiamato dal C
    def check_not_in_callback!(what, error)
      raise error, "#{what} non è permesso dentro un callback chiamato da notcurses" if @callback_depth.positive?
    end

    private

    # Chiude gli oggetti adottati in ordine inverso di creazione, anche se un
    # close solleva: un reader rimasto aperto farebbe un double free nello stop
    # o nel drop. Anche SystemExit e Interrupt, che il blocco di un FdPlane può
    # aver salvato. Con kind solo i figli di quella classe: {#close} chiude
    # prima i figli con un thread Ruby ({FdPlane}, {Subprocess}), perché il
    # loro close attende il thread, che può usare il contesto.
    # @param kind [Module] classe dei figli da chiudere
    # @return [Exception, nil] la prima eccezione
    def close_children(kind = Object)
      first_error = nil
      @children.keys.reverse_each do |child|
        child.close if child.is_a?(kind)
      rescue Exception => e # rubocop:disable Lint/RescueException
        first_error ||= e
      end
      first_error
    end

    # Mette in coda lo stop ed esegue la coda se nessuna operazione è in corso.
    # Anche più volte: un close ripetuto (o l'hook at_exit) rimette in coda uno
    # stop che un'eccezione asincrona ha tolto dalla coda, e {#release_native!}
    # lo esegue una volta sola.
    # @return [nil]
    def settle_close
      Guard.defer(self)
      Guard.settle_if_idle
    end

    # +notcurses_stop+. Su macOS la chiamata rilascia il GVL (functions.rb):
    # un'eccezione asincrona per il thread chiamante la sbloccherebbe, tcsetattr
    # uscirebbe con EINTR e il terminale resterebbe nel modo di notcurses. Lo
    # stop gira quindi in un altro thread, e il chiamante lo aspetta con le
    # interruzioni rimandate.
    # @return [Integer] il ritorno di +notcurses_stop+
    def stop_notcurses(ptr)
      return FFI.notcurses_stop(ptr) unless ::FFI::Platform.mac?

      Thread.handle_interrupt(Object => :never) { Thread.new { FFI.notcurses_stop(ptr) }.value }
    end

    # Stato Ruby di un contesto chiuso: piani invalidi, FILE* chiuso (se
    # fclose), registro libero.
    # @return [nil]
    def mark_closed!(fclose:)
      @closed = true
      @input_io = nil # il fd è di notcurses, che lo ha chiuso
      @planes.each_value(&:invalidate!)
      @planes.clear
      @children.clear
      FFI.fclose(@fp) if fclose
      Notcurses.release_context(self)
      nil
    end

    # Valore del flag dei segnali di notcurses subito dopo l'init: ISIG del
    # terminale, acceso senza terminale o con ISIG non leggibile.
    # @return [Boolean]
    def initial_linesigs_flag
      return true unless FFI::ISIG

      input_tty { |fd| termios(fd)[:c_lflag].anybits?(FFI::ISIG) ? :on : :off } != :off
    rescue ContextError
      true
    end

    # Il terminale da cui notcurses legge i tasti (init_inputlayer, in.c):
    # stdin se è un tty, altrimenti /dev/tty.
    # @return il valore del blocco, false senza terminale
    def input_tty
      return yield(STDIN.fileno) if !STDIN.closed? && STDIN.tty? # tty? solleva IOError con STDIN chiuso

      begin
        tty = File.open('/dev/tty', 'r+')
      rescue SystemCallError
        return false # nessun terminale di controllo, come notcurses senza ttyfd
      end
      begin
        yield(tty.fileno)
      ensure
        tty.close
      end
    end

    # Porta IXON a on sul terminale fd.
    # @return [Boolean] il valore precedente
    def ixon!(fd, on)
      raise ContextError, "controllo di flusso: IXON non noto su #{RUBY_PLATFORM}" unless FFI::IXON

      tty_flag!(fd, :c_iflag, FFI::IXON, on)
    end

    # Porta il bit flag del campo field di termios a on sul terminale fd.
    # @return [Boolean] il valore precedente
    def tty_flag!(fd, field, flag, on)
      tios = termios(fd)
      was = tios[field].anybits?(flag)
      return was if was == on

      tios[field] ^= flag
      termios_check!(FFI.tcsetattr(fd, FFI::TCSANOW, tios), 'tcsetattr')
      was
    end

    # @return [FFI::Termios] lo stato del terminale fd
    def termios(fd)
      tios = FFI::Termios.new
      termios_check!(FFI.tcgetattr(fd, tios), 'tcgetattr')
      tios
    end

    def termios_check!(rc, what)
      raise ContextError, "#{what} fallita (#{SystemCallError.new(nil, ::FFI.errno).message})" if rc.negative?
    end

    def open_output(output)
      case output
      when nil then [::FFI::Pointer::NULL, false]
      when ::FFI::Pointer
        raise ArgumentError, 'output è un puntatore NULL: usa nil per /dev/tty' if output.null?

        [output, false]
      when String
        fp = FFI.fopen(Util.string!(output, 'output'), 'w')
        raise InitError, "fopen(#{output.inspect}, \"w\") fallita" if fp.null?

        [fp, true]
      else raise TypeError, "output deve essere nil, String o ::FFI::Pointer (FILE*), non #{output.class}"
      end
    end

    def set_margins(opts, margins, top, right, bottom, left)
      sides = { margin_t: top, margin_r: right, margin_b: bottom, margin_l: left }
      sides.each { |name, v| opts[name] = Util.uint!(v, name.to_s) }
      return if margins.nil?

      raise ArgumentError, 'usa margins: oppure margin_t/r/b/l:, non entrambi' unless sides.values.all?(&:zero?)

      case margins
      when String
        rc = FFI.notcurses_lex_margins(Util.string!(margins, 'margins'), opts)
        raise ArgumentError, "margins = #{margins.inspect} non valido (notcurses_lex_margins)" if rc.negative?
      when Array
        raise TypeError, 'margins deve essere [alto, destra, basso, sinistra]' unless margins.size == 4

        sides.each_key.with_index { |name, i| opts[name] = Util.uint!(margins[i], 'margins') }
      else raise TypeError, "margins deve essere [alto, destra, basso, sinistra] o String, non #{margins.class}"
      end
    end

    # Prossimo evento senza attendere: durante run solo dal buffer del thread
    # di input; fuori da run prima quello che resta nel buffer, poi la coda di
    # notcurses.
    # @return [Input, nil]
    def next_input
      Guard.run do
        reader = @input_reader
        return pull_input unless reader&.active? || reader&.pending?

        to_ptr # il buffer non chiama il C, che controlla da sé il contesto chiuso
        return reader.take if reader.active?

        reader.take || pull_input
      end
    end

    # Un evento dalla coda di notcurses, senza attendere (+notcurses_get_nblock+).
    # @return [Input, nil]
    def pull_input
      Guard.run do
        ni = FFI::NcInput.new
        id = FFI.notcurses_get_nblock(to_ptr, ni)
        raise InputError, 'notcurses_get: errore di input (o input scartato con drain_input)' if id == 0xffff_ffff

        Input.new(ni) unless id.zero?
      end
    end

    # Eventi già pronti, al massimo count: come {#next_input}, prima il buffer
    # del thread di input, poi (fuori da run) la coda di notcurses.
    # @return [Array<Input>, nil] nil senza eventi
    def queued_inputs(count)
      Guard.run do
        reader = @input_reader
        events = []
        if reader&.active? || reader&.pending?
          to_ptr # il buffer non chiama il C, che controlla da sé il contesto chiuso
          events = reader.take_many(count)
          # nel buffer resta altro solo con count raggiunto o con un errore da sollevare al giro dopo
          done = reader.active? || reader.pending?
        end
        events.concat(pull_inputs(count - events.size)) unless done || events.size == count
        events.empty? ? nil : events
      end
    end

    # Eventi della coda di notcurses, al massimo count, letti a blocchi di
    # GETVEC_MAX slot. Le chiamate C sono consecutive e gli Input nascono
    # dopo: durante una raffica la coda si svuota prima che notcurses scarti
    # altri eventi.
    # @return [Array<Input>] anche vuoto
    def pull_inputs(count)
      size = FFI::NcInput.size
      blocks = []
      taken = 0
      loop do
        slots = [count - taken, GETVEC_MAX].min
        buf = ::FFI::MemoryPointer.new(FFI::NcInput, slots)
        n = getvec_into(buf, slots)
        blocks << [buf, n] if n.positive?
        taken += n
        # blocco non pieno: la coda è vuota. A fine input il C riempie ogni blocco di EOF
        break if n < slots || taken == count || FFI::NcInput.new(buf + ((n - 1) * size))[:id] == Key::EOF
      end
      blocks.flat_map { |buf, n| Array.new(n) { |i| Input.new(FFI::NcInput.new(buf + (i * size))) } }
    end

    # Scrive in buf fino a slots eventi già in coda (+notcurses_getvec+), senza
    # attendere: deadline assoluta {0, 0}, già scaduta. to_ptr a ogni chiamata:
    # un gestore trap può chiudere il contesto tra due chiamate. Lo usa anche
    # il thread di input.
    # @return [Integer] eventi scritti
    def getvec_into(buf, slots)
      Guard.run do
        n = FFI.notcurses_getvec(to_ptr, FFI::Timespec.new, buf, slots)
        raise InputError, 'notcurses_getvec: errore di input' if n.negative?

        n
      end
    end

    # Ripete il blocco finché restituisce un valore, attendendo l'input fuori
    # dal C tra un tentativo e l'altro.
    def wait_input(timeout)
      unless timeout.nil?
        Util.float!(timeout, 'timeout', Util::TIMEOUT)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      end
      loop do
        result = yield
        return result unless result.nil?
        return nil if timeout&.zero?

        remaining = deadline && (deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC))
        return nil if remaining && remaining <= 0

        # durante run il pipe del thread di input; fuori da run il descrittore di notcurses (autoclose false:
        # lo chiude notcurses_stop)
        io = @input_reader&.active? && @input_reader.ready_io
        io ||= (@input_io ||= IO.for_fd(inputready_fd, autoclose: false))
        io.wait_readable(remaining)
      end
    rescue SystemCallError, IOError
      to_ptr # un close durante l'attesa (gestore trap) ha chiuso il descrittore: ClosedError
      raise
    end
  end
end
