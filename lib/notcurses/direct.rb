# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/direct.h
# frozen_string_literal: true

# IO#wait_readable è nel core da Ruby 3.2: su 4.0 require 'io/wait' stampa un avviso.
require 'io/wait' unless IO.method_defined?(:wait_readable)

module Notcurses
  # Modalità "direct" di notcurses (+struct ncdirect*+): colori, stili,
  # movimenti del cursore, linee, box e immagini scritti subito sul terminale,
  # senza piani né render. Serve a colorare un normale output a righe.
  #
  # Un solo contesto ({Context} o Direct) può essere attivo nel processo: un
  # secondo solleva InitError prima di chiamare il C. {.open} con un blocco
  # chiude il contesto anche in caso di eccezione; un contesto rimasto aperto
  # viene chiuso all'uscita del processo da un hook +at_exit+.
  #
  # Output: il testo ({#putstr}, {#putegc}, linee, box, movimenti del cursore)
  # passa dal buffer stdio del FILE* e diventa visibile con {#flush} o con la
  # chiamata successiva che cambia colori o stili (queste scrivono subito). Con
  # output: nil il FILE* è lo stdout della libc, distinto da +$stdout+ di Ruby:
  # chiama {#flush} prima di scrivere da Ruby e +$stdout.flush+ prima di
  # tornare a Direct.
  #
  # Colori: {#putstr}, {#putegc}, {#print_aligned}, {#hline}, {#vline} e {#box}
  # impostano primo piano e sfondo dal parametro channels (0 = colori di
  # default del terminale) e sostituiscono quelli scelti con set_fg_*/set_bg_*;
  # questi valgono per il testo scritto da Ruby e per il prompt di {#readline}.
  #
  # Input: arriva sempre da stdin (fd 0), letto da un thread di notcurses: non
  # leggere STDIN da Ruby mentre il contesto è aperto. {#get} attende fuori dal
  # C (gli altri thread e i segnali restano serviti). L'init, {#readline},
  # {#cursor_yx} e {#cursor_move} con x: nil attendono il terminale dentro il C,
  # senza timeout ma con il GVL rilasciato: gli altri thread Ruby girano, i
  # segnali vengono serviti al ritorno della chiamata.
  #
  # Effetti sul processo mentre il contesto è attivo: fd 0 in O_NONBLOCK e
  # terminale in cbreak (ripristinati da {#close}); termtype: cambia ENV['TERM']
  # in modo permanente (il wrapper lo ripristina solo se l'init fallisce).
  #
  # Thread: notcurses non è thread-safe; usa il contesto da un solo thread alla
  # volta (il wrapper non aggiunge lock).
  #
  # @example
  #   Notcurses::Direct.open do |d|
  #     red = Notcurses::Channels.new.with_fg_rgb(255, 0, 0)
  #     d.putstr("errore\n", channels: red).flush
  #   end
  class Direct
    include Resource
    extend Resource::ClassMethods

    # Lati del box per l'opzione omit: di {#box} (+NCBOXMASK_*+).
    BOX_EDGES = {
      top: FFI::NCBOXMASK_TOP,
      right: FFI::NCBOXMASK_RIGHT,
      bottom: FFI::NCBOXMASK_BOTTOM,
      left: FFI::NCBOXMASK_LEFT
    }.freeze

    # Stili di box predefiniti di {#box}.
    BOX_STYLES = %i[light heavy rounded double ascii].freeze

    # Lunghezza massima di {#hline} e {#vline}: oltre INT_MAX il C esegue fino
    # a 2^32 iterazioni con colori sbagliati, e vline_interp con UINT_MAX va in
    # SIGFPE (direct.c:1351).
    MAX_LINE = Util::INT32.max - 1

    # Validazione degli argomenti comuni a Direct, Image e Frame.
    # @api private
    module Args
      module_function

      # ncdirect_align accetta solo questi: con gli altri valori restituisce
      # INT_MAX e il C scrive una sequenza spazzatura (direct.c:411-426).
      ALIGNS = Util::ALIGNS.slice(:left, :center, :right).freeze
      # 4x1 e 8x1 servono solo ai plot.
      BLITTERS = Util::BLITTERS.except(:four_by_one, :eight_by_one).freeze

      # Allineamento ammesso da ncdirect_align.
      # @param value [Symbol, Integer] :left, :center, :right o la costante C
      # @return [Integer] costante NCALIGN_*
      # @raise [ArgumentError] se value non è ammesso
      def align(value) = Util.enum_value(ALIGNS, value, 'align')

      # Blitter ammesso dal render direct.
      # @param value [Symbol, Integer] simbolo o costante NCBLIT_*
      # @return [Integer] costante NCBLIT_*
      # @raise [ArgumentError] se value non è ammesso
      def blitter(value) = Util.enum_value(BLITTERS, value, 'blitter')

      # Percorso di un file immagine.
      # @param value [String] percorso del file
      # @return [String] percorso UTF-8
      # @raise [TypeError] se value non è String
      # @raise [ArgumentError] se value contiene NUL o non è UTF-8 valido
      def path(value) = Util.string!(value, 'path')

      # Opzioni lette dal render direct: solo blitter e scaling (direct.c:635-737).
      # @param blitter_arg [Symbol, Integer] blitter
      # @param scale_arg [Symbol, Integer] scaling
      # @return [FFI::NcVisualOptions] opzioni con blitter e scaling
      # @raise [ArgumentError] se blitter o scaling non sono validi
      def visual_options(blitter_arg, scale_arg)
        vopts = FFI::NcVisualOptions.new
        vopts[:blitter] = blitter(blitter_arg)
        vopts[:scaling] = Util.scale_value(scale_arg)
        vopts
      end

      # Valore uint64_t di un parametro channels.
      # @param value [Channels, Integer] canali
      # @param name [String] nome usato nel messaggio d'errore
      # @return [Integer] valore uint64_t
      # @raise [TypeError] se value non è Channels né Integer
      # @raise [ArgumentError] se value Integer è fuori da uint64_t
      def channels(value, name)
        case value
        when Channels then value.value
        when Integer then Util.uint64!(value, name)
        else raise TypeError, "#{name} deve essere Notcurses::Channels o Integer, non #{value.class}"
        end
      end

      # Le linee interpolano i bit RGB anche dei canali a palette (l'indice
      # finirebbe nel blu: direct.c:1285-1292).
      # @param value [Channels, Integer] canali
      # @param name [String] nome usato nel messaggio d'errore
      # @return [Integer] valore uint64_t
      # @raise [TypeError] se value non è Channels né Integer
      # @raise [ArgumentError] se value è fuori da uint64_t o usa indici di palette
      def line_channels(value, name)
        v = channels(value, name)
        if FFI.ncchannels_fg_palindex_p(v) || FFI.ncchannels_bg_palindex_p(v)
          raise ArgumentError, "#{name}: linee e box usano solo colori RGB o di default, non indici di palette"
        end

        v
      end

      # Un solo EGC largo una colonna: vline torna indietro di una colonna
      # dopo ogni carattere (direct.c:1389).
      # @param value [String] testo da controllare
      # @return [String] l'EGC
      # @raise [TypeError] se value non è String
      # @raise [ArgumentError] se value non è un solo EGC largo una colonna
      def line_egc(value)
        egc = Util.string!(value, 'egc')
        unless egc.grapheme_clusters.size == 1 && !egc.match?(/\p{Cc}/) && FFI.ncstrwidth(egc, nil, nil) == 1
          raise ArgumentError, "egc = #{egc.inspect}: serve un solo carattere (EGC) largo una colonna"
        end

        egc
      end
    end
    private_constant :Args

    # @return [Integer] pid del processo che ha creato il contesto
    # @api private
    attr_reader :pid

    # Avvia la modalità direct (+ncdirect_init+, o +ncdirect_core_init+ con
    # core: true).
    #
    # Con un terminale vero l'init interroga il terminale e ne attende (senza
    # timeout) la risposta; query e report del cursore vanno al terminale di
    # controllo anche quando output è un file. Durante l'init il GVL è
    # rilasciato: gli altri thread Ruby girano, ma non devono usare ENV (con
    # termtype: notcurses chiama setenv).
    #
    # @param termtype [String, nil] voce terminfo del terminale; nil = variabile
    #   TERM. notcurses la scrive in ENV['TERM']
    # @param output [String, ::FFI::Pointer, nil] dove scrivere: nil = lo stdout
    #   della libc (fd 1); String = percorso aperto con fopen("w") e chiuso da
    #   {#close}; ::FFI::Pointer = un FILE* aperto dal chiamante, che resta suo e
    #   va chiuso dopo {#close}. Il FILE* deve avere un fd vero (niente
    #   fmemopen)
    # @param core [Boolean] true = +ncdirect_core_init+: niente immagini, salvo
    #   che il processo abbia già avviato un contesto multimediale
    # @param inhibit_setlocale [Boolean] NCDIRECT_OPTION_INHIBIT_SETLOCALE
    # @param inhibit_cbreak [Boolean] NCDIRECT_OPTION_INHIBIT_CBREAK
    # @param drain_input [Boolean] NCDIRECT_OPTION_DRAIN_INPUT: l'input viene
    #   scartato ({#get} e {#readline} sollevano InputError)
    # @param no_quit_sighandlers [Boolean] NCDIRECT_OPTION_NO_QUIT_SIGHANDLERS.
    #   Default true (diverso dal C): con false i gestori di notcurses per
    #   SIGINT, SIGTERM, SIGSEGV, ... terminano il processo subito (niente
    #   Interrupt, ensure o at_exit)
    # @param verbose [Boolean] NCDIRECT_OPTION_VERBOSE (log su stderr)
    # @param very_verbose [Boolean] NCDIRECT_OPTION_VERY_VERBOSE (log completo
    #   su stderr)
    # @raise [InitError] se un altro contesto è attivo, se l'output non si apre
    #   o se l'init restituisce NULL (per esempio terminfo non trovata per TERM
    #   o termtype, stdin chiuso)
    # @raise [TypeError, ArgumentError] se un'opzione non è valida
    def initialize(termtype: nil, output: nil, core: false, inhibit_setlocale: false, inhibit_cbreak: false,
                   drain_input: false, no_quit_sighandlers: true, verbose: false, very_verbose: false)
      Util.bool!(core, 'core')
      term = Util.string_or_nil!(termtype, 'termtype')
      flags = Util.flag(inhibit_setlocale, FFI::NCDIRECT_OPTION_INHIBIT_SETLOCALE, 'inhibit_setlocale') |
              Util.flag(inhibit_cbreak, FFI::NCDIRECT_OPTION_INHIBIT_CBREAK, 'inhibit_cbreak') |
              Util.flag(drain_input, FFI::NCDIRECT_OPTION_DRAIN_INPUT, 'drain_input') |
              Util.flag(no_quit_sighandlers, FFI::NCDIRECT_OPTION_NO_QUIT_SIGHANDLERS, 'no_quit_sighandlers') |
              Util.flag(verbose, FFI::NCDIRECT_OPTION_VERBOSE, 'verbose') |
              Util.flag(very_verbose, FFI::NCDIRECT_OPTION_VERY_VERBOSE, 'very_verbose')
      check_output!(output)

      Notcurses.acquire_context(self)
      old_term = ENV.fetch('TERM', nil)
      own_fp = false
      begin
        fp, own_fp = open_output(output)
        $stdout.flush if output.nil?
        ptr = core ? FFI.ncdirect_core_init(term, fp, flags) : FFI.ncdirect_init(term, fp, flags)
        if ptr.null?
          # il C ha già scritto termtype in TERM: un init successivo senza termtype fallirebbe
          ENV['TERM'] = old_term unless term.nil?
          raise InitError, 'ncdirect_init ha restituito NULL (terminfo non trovata per TERM o termtype? stdin chiuso?)'
        end
      rescue StandardError
        Notcurses.release_context(self)
        FFI.fclose(fp) if own_fp
        raise
      end

      @ptr = ptr
      @fp = fp
      @own_fp = own_fp
      @closed = false
      @owner = nil
      @pid = Process.pid
      @drain_input = drain_input
      @eof_input = nil
      @input_io = nil
    end

    # Ripristina il terminale e libera il contesto (+ncdirect_stop+).
    # Idempotente. Prima dello stop scrive sull'output il ritorno ai colori di
    # default e agli stili normali; i {Frame} non ancora disegnati diventano
    # inutilizzabili (la loro memoria C resta allocata). Le {Image} restano
    # valide.
    #
    # Bug di 3.0.17 (direct.c:841): +ncdirect_stop+ scrive il proprio reset
    # (+\e[39;49m\e(B\e[m+) sullo stdout del processo anche quando output è
    # un file.
    #
    # @return [nil]
    # @raise [DirectError] se +ncdirect_stop+ restituisce un errore (il
    #   contesto risulta comunque chiuso)
    def close
      return nil if @closed

      # ncdirect_stop non resetta il FILE* (solo stdout): lo fa il wrapper, prima, perché lo stop ne fa ancora il flush
      FFI.ncdirect_set_fg_default(@ptr)
      FFI.ncdirect_set_bg_default(@ptr)
      FFI.ncdirect_set_styles(@ptr, 0)
      FFI.ncdirect_flush(@ptr)
      @input_io = nil # il fd è di notcurses: lo chiude ncdirect_stop
      rc = FFI.ncdirect_stop(@ptr)
      @closed = true
      FFI.fclose(@fp) if @own_fp
      Notcurses.release_context(self)
      # ncdirect_stop restituisce l'OR di più ritorni: qualsiasi valore diverso da 0 è un errore
      raise DirectError, "ncdirect_stop fallita (#{rc})" unless rc.zero?

      nil
    end
    alias stop close

    # --- colori ---

    # Colore di primo piano RGB (+ncdirect_set_fg_rgb8+). Senza colori RGB il
    # terminale riceve il colore più vicino della palette; senza colori,
    # niente.
    #
    # @param r [Integer] 0..255
    # @param g [Integer] 0..255
    # @param b [Integer] 0..255
    # @return [self]
    # @raise [TypeError, ArgumentError] se un componente non è un Integer in 0..255
    # @raise [DirectError] se la scrittura fallisce
    # @raise [ClosedError] se il contesto è chiuso
    def set_fg_rgb(r, g, b)
      rgb8!(r, g, b)
      Util.check!(FFI.ncdirect_set_fg_rgb8(to_ptr, r, g, b), DirectError, 'ncdirect_set_fg_rgb8')
      self
    end

    # Colore di sfondo RGB (+ncdirect_set_bg_rgb8+).
    #
    # @param r [Integer] 0..255
    # @param g [Integer] 0..255
    # @param b [Integer] 0..255
    # @return [self]
    # @raise [TypeError, ArgumentError] se un componente non è un Integer in 0..255
    # @raise [DirectError] se la scrittura fallisce
    # @raise [ClosedError] se il contesto è chiuso
    def set_bg_rgb(r, g, b)
      rgb8!(r, g, b)
      Util.check!(FFI.ncdirect_set_bg_rgb8(to_ptr, r, g, b), DirectError, 'ncdirect_set_bg_rgb8')
      self
    end

    # Colore di primo piano da un valore 0xRRGGBB (+ncdirect_set_fg_rgb+).
    #
    # @param rgb [Integer] 0..0xffffff
    # @return [self]
    # @raise [TypeError, ArgumentError] se rgb non è un Integer in 0..0xffffff
    # @raise [DirectError] se la scrittura fallisce
    # @raise [ClosedError] se il contesto è chiuso
    def set_fg_rgb24(rgb)
      Util.integer!(rgb, 'rgb', 0..0xffffff)
      Util.check!(FFI.ncdirect_set_fg_rgb(to_ptr, rgb), DirectError, 'ncdirect_set_fg_rgb')
      self
    end

    # Colore di sfondo da un valore 0xRRGGBB (+ncdirect_set_bg_rgb+).
    #
    # @param rgb [Integer] 0..0xffffff
    # @return [self]
    # @raise [TypeError, ArgumentError] se rgb non è un Integer in 0..0xffffff
    # @raise [DirectError] se la scrittura fallisce
    # @raise [ClosedError] se il contesto è chiuso
    def set_bg_rgb24(rgb)
      Util.integer!(rgb, 'rgb', 0..0xffffff)
      Util.check!(FFI.ncdirect_set_bg_rgb(to_ptr, rgb), DirectError, 'ncdirect_set_bg_rgb')
      self
    end

    # Colore di primo piano dalla palette (+ncdirect_set_fg_palindex+). Il C
    # non confronta index con {#palette_size}.
    #
    # @param index [Integer] 0..255
    # @return [self]
    # @raise [TypeError, ArgumentError] se index non è un Integer in 0..255
    # @raise [DirectError] se il terminale non ha colori a palette o la
    #   scrittura fallisce
    # @raise [ClosedError] se il contesto è chiuso
    def set_fg_palindex(index)
      Util.integer!(index, 'index', 0...FFI::NCPALETTESIZE)
      Util.check!(FFI.ncdirect_set_fg_palindex(to_ptr, index), DirectError, 'ncdirect_set_fg_palindex')
      self
    end

    # Colore di sfondo dalla palette (+ncdirect_set_bg_palindex+).
    #
    # @param index [Integer] 0..255
    # @return [self]
    # @raise [TypeError, ArgumentError] se index non è un Integer in 0..255
    # @raise [DirectError] se il terminale non ha colori a palette o la
    #   scrittura fallisce
    # @raise [ClosedError] se il contesto è chiuso
    def set_bg_palindex(index)
      Util.integer!(index, 'index', 0...FFI::NCPALETTESIZE)
      Util.check!(FFI.ncdirect_set_bg_palindex(to_ptr, index), DirectError, 'ncdirect_set_bg_palindex')
      self
    end

    # Primo piano con il colore di default del terminale
    # (+ncdirect_set_fg_default+).
    #
    # @return [self]
    # @raise [DirectError] se la scrittura fallisce
    # @raise [ClosedError] se il contesto è chiuso
    def set_fg_default
      Util.check!(FFI.ncdirect_set_fg_default(to_ptr), DirectError, 'ncdirect_set_fg_default')
      self
    end

    # Sfondo con il colore di default del terminale (+ncdirect_set_bg_default+).
    #
    # @return [self]
    # @raise [DirectError] se la scrittura fallisce
    # @raise [ClosedError] se il contesto è chiuso
    def set_bg_default
      Util.check!(FFI.ncdirect_set_bg_default(to_ptr), DirectError, 'ncdirect_set_bg_default')
      self
    end

    # @return [Integer] colori della palette dichiarati dal terminale, 1 senza
    #   colori (+ncdirect_palette_size+)
    # @raise [ClosedError] se il contesto è chiuso
    def palette_size = FFI.ncdirect_palette_size(to_ptr)

    # --- stili ---

    # @return [Array<Symbol>] stili che il terminale sa mostrare insieme ai
    #   colori (+ncdirect_supported_styles+)
    # @raise [ClosedError] se il contesto è chiuso
    def supported_styles = Util.styles_symbols(FFI.ncdirect_supported_styles(to_ptr))

    # @return [Array<Symbol>] stili attivi impostati con {#set_styles},
    #   {#on_styles} e {#off_styles} (+ncdirect_styles+)
    # @raise [ClosedError] se il contesto è chiuso
    def styles = Util.styles_symbols(FFI.ncdirect_styles(to_ptr))

    # Imposta esattamente questi stili (+ncdirect_set_styles+). I colori non
    # cambiano.
    #
    # @param styles [Symbol, Array<Symbol>, Integer] :bold, :italic,
    #   :underline, :undercurl, :struck, oppure una maschera NCSTYLE_*; [] o 0
    #   = nessuno
    # @return [self]
    # @raise [ArgumentError] se uno stile non è valido o il terminale non lo
    #   supporta ({#supported_styles})
    # @raise [TypeError] se styles non è Symbol, Array o Integer
    # @raise [DirectError] se la scrittura fallisce
    # @raise [ClosedError] se il contesto è chiuso
    def set_styles(styles)
      ptr = to_ptr
      mask = supported_styles!(ptr, styles)
      Util.check!(FFI.ncdirect_set_styles(ptr, mask), DirectError, 'ncdirect_set_styles')
      self
    end

    # Aggiunge stili a quelli attivi (+ncdirect_on_styles+).
    #
    # @param styles [Symbol, Array<Symbol>, Integer] come in {#set_styles}
    # @return [self]
    # @raise [ArgumentError] se uno stile non è valido o il terminale non lo
    #   supporta
    # @raise [TypeError] se styles non è Symbol, Array o Integer
    # @raise [DirectError] se la scrittura fallisce
    # @raise [ClosedError] se il contesto è chiuso
    def on_styles(styles)
      ptr = to_ptr
      mask = supported_styles!(ptr, styles)
      Util.check!(FFI.ncdirect_on_styles(ptr, mask), DirectError, 'ncdirect_on_styles')
      self
    end

    # Toglie stili da quelli attivi (+ncdirect_off_styles+). Accetta anche
    # stili non supportati dal terminale.
    #
    # @param styles [Symbol, Array<Symbol>, Integer] come in {#set_styles}
    # @return [self]
    # @raise [ArgumentError] se uno stile non è valido
    # @raise [TypeError] se styles non è Symbol, Array o Integer
    # @raise [DirectError] se la scrittura fallisce
    # @raise [ClosedError] se il contesto è chiuso
    def off_styles(styles)
      mask = Util.styles_value(styles)
      Util.check!(FFI.ncdirect_off_styles(to_ptr, mask), DirectError, 'ncdirect_off_styles')
      self
    end

    # --- output ---

    # Scrive text con i colori di channels (+ncdirect_putstr+). Il testo resta
    # nel buffer finché non chiami {#flush}.
    #
    # @param text [String] testo UTF-8 (anche più righe)
    # @param channels [Channels, Integer] primo piano e sfondo; 0 = colori di
    #   default. L'alpha è ignorata
    # @return [self]
    # @raise [TypeError, ArgumentError] se text o channels non sono validi
    # @raise [DirectError] se la scrittura fallisce
    # @raise [ClosedError] se il contesto è chiuso
    def putstr(text, channels: 0)
      ptr = to_ptr
      s = Util.string!(text, 'text')
      # il ritorno è quello di fputs (1 con glibc): conta solo il segno
      Util.check!(FFI.ncdirect_putstr(ptr, Args.channels(channels, 'channels'), s), DirectError, 'ncdirect_putstr')
      self
    end

    # Scrive il primo EGC (carattere percepito, anche di più codepoint) di text
    # con i colori di channels (+ncdirect_putegc+); il resto di text è
    # ignorato.
    #
    # @param text [String] testo UTF-8; "" non scrive nulla
    # @param channels [Channels, Integer] come in {#putstr}
    # @return [Array(Integer, Integer)] [colonne, byte] dell'EGC scritto
    #   (newline e tab contano una colonna)
    # @raise [TypeError, ArgumentError] se text o channels non sono validi, o
    #   se text inizia con un carattere di controllo
    # @raise [DirectError] se la scrittura fallisce
    # @raise [ClosedError] se il contesto è chiuso
    def putegc(text, channels: 0)
      ptr = to_ptr
      s = Util.string!(text, 'text')
      chans = Args.channels(channels, 'channels')
      sbytes = ::FFI::MemoryPointer.new(:int)
      sbytes.write_int(-1)
      cols = FFI.ncdirect_putegc(ptr, chans, s, sbytes)
      if cols.negative?
        # il C scrive sbytes solo dopo aver riconosciuto l'EGC
        if sbytes.read_int.negative?
          raise ArgumentError, "text = #{s.inspect} inizia con un carattere di controllo (o non valido nella locale)"
        end

        raise DirectError, "ncdirect_putegc fallita (#{cols})"
      end
      [cols, sbytes.read_int]
    end

    # Scrive text sulla riga y, allineato rispetto alla larghezza del
    # terminale. Sostituisce +ncdirect_printf_aligned+, che in 3.0.17 scrive
    # il testo su stdout invece che sull'output e aggiunge un "\n"
    # (direct.c:818): il wrapper calcola la colonna come +ncdirect_align+,
    # sposta il cursore e chiama +ncdirect_putstr+. Non va a capo.
    #
    # @param text [String] testo UTF-8 senza caratteri di controllo (salvo
    #   newline e tab, contati come una colonna)
    # @param y [Integer, nil] riga, 0..INT_MAX; nil = la riga del cursore
    # @param align [Symbol] :left, :center o :right
    # @param channels [Channels, Integer] come in {#putstr}
    # @return [Integer] colonne occupate da text (+ncstrwidth+)
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [DirectError] se lo spostamento del cursore o la scrittura
    #   falliscono
    # @raise [ClosedError] se il contesto è chiuso
    def print_aligned(text, y: nil, align: :left, channels: 0)
      ptr = to_ptr
      s = Util.string!(text, 'text')
      Util.nonneg_int!(y, 'y') unless y.nil?
      a = Args.align(align)
      chans = Args.channels(channels, 'channels')
      width = FFI.ncstrwidth(s, nil, nil)
      raise ArgumentError, "text = #{s.inspect} contiene caratteri di controllo" if width.negative?

      x = a == FFI::NCALIGN_LEFT ? 0 : aligned_x(a, width, dims[1])
      Util.check!(FFI.ncdirect_cursor_move_yx(ptr, y || -1, x), DirectError, 'ncdirect_cursor_move_yx')
      Util.check!(FFI.ncdirect_putstr(ptr, chans, s), DirectError, 'ncdirect_putstr')
      width
    end

    # Svuota il buffer dell'output (+ncdirect_flush+).
    #
    # @return [self]
    # @raise [DirectError] se fflush fallisce (dopo un errore glibc il FILE*
    #   non scrive più nulla)
    # @raise [ClosedError] se il contesto è chiuso
    def flush
      Util.check!(FFI.ncdirect_flush(to_ptr), DirectError, 'ncdirect_flush')
      self
    end

    # --- schermo ---

    # Dimensioni del terminale (+ncdirect_dim_y+, +ncdirect_dim_x+), rilette a
    # ogni chiamata. Senza un terminale di controllo valgono sempre 24x80.
    #
    # @return [Array(Integer, Integer)] [righe, colonne]
    # @raise [DirectError] se il C non riesce a leggere le dimensioni
    # @raise [ClosedError] se il contesto è chiuso
    def dims
      ptr = to_ptr
      rows = FFI.ncdirect_dim_y(ptr)
      cols = FFI.ncdirect_dim_x(ptr)
      raise DirectError, 'ncdirect_dim_y/ncdirect_dim_x fallita (0)' if rows.zero? || cols.zero?

      [rows, cols]
    end

    # Pulisce lo schermo e porta il cursore in alto a sinistra
    # (+ncdirect_clear+).
    #
    # @return [self]
    # @raise [DirectError] se il terminale non sa pulire lo schermo o la
    #   scrittura fallisce
    # @raise [ClosedError] se il contesto è chiuso
    def clear
      Util.check!(FFI.ncdirect_clear(to_ptr), DirectError, 'ncdirect_clear')
      self
    end

    # --- cursore ---

    # Sposta il cursore (+ncdirect_cursor_move_yx+). Un asse nil resta dov'è;
    # con entrambi nil non succede nulla.
    #
    # Bug di 3.0.17 (direct.c:233, condizione invertita): per conservare la
    # colonna (x: nil) il C legge la posizione dal terminale, quindi serve
    # {#can_get_cursor?} (senza, il wrapper solleva invece di andare alla
    # colonna 0 come il C) e la chiamata attende la risposta del terminale
    # (senza timeout, con il GVL rilasciato).
    # Con y: nil su un terminale senza +hpa+ e senza tty il C va alla riga 0.
    #
    # @param y [Integer, nil] riga, 0..INT_MAX
    # @param x [Integer, nil] colonna, 0..INT_MAX
    # @return [self]
    # @raise [TypeError, ArgumentError] se y o x non sono interi >= 0
    # @raise [DirectError] se x è nil e il terminale non riporta il cursore,
    #   o se lo spostamento fallisce
    # @raise [ClosedError] se il contesto è chiuso
    def cursor_move(y: nil, x: nil)
      ptr = to_ptr
      Util.nonneg_int!(y, 'y') unless y.nil?
      Util.nonneg_int!(x, 'x') unless x.nil?
      return self if y.nil? && x.nil?
      if x.nil? && !FFI.ncdirect_canget_cursor(ptr)
        raise DirectError, 'cursor_move(x: nil): senza un terminale che riporti il cursore la colonna non si conserva'
      end

      Util.check!(FFI.ncdirect_cursor_move_yx(ptr, y || -1, x || -1), DirectError, 'ncdirect_cursor_move_yx')
      self
    end

    # Rende visibile il cursore (+ncdirect_cursor_enable+). {#close} lo rende
    # comunque visibile.
    #
    # @return [self]
    # @raise [DirectError] se il terminale non lo permette
    # @raise [ClosedError] se il contesto è chiuso
    def cursor_enable
      Util.check!(FFI.ncdirect_cursor_enable(to_ptr), DirectError, 'ncdirect_cursor_enable')
      self
    end

    # Nasconde il cursore (+ncdirect_cursor_disable+).
    #
    # @return [self]
    # @raise [DirectError] se il terminale non lo permette
    # @raise [ClosedError] se il contesto è chiuso
    def cursor_disable
      Util.check!(FFI.ncdirect_cursor_disable(to_ptr), DirectError, 'ncdirect_cursor_disable')
      self
    end

    # Sposta il cursore in su, fermandosi al bordo (+ncdirect_cursor_up+).
    #
    # @param count [Integer] righe, 0..INT_MAX
    # @return [self]
    # @raise [TypeError, ArgumentError] se count non è un intero >= 0
    # @raise [DirectError] se il terminale non lo permette
    # @raise [ClosedError] se il contesto è chiuso
    def cursor_up(count = 1)
      Util.nonneg_int!(count, 'count')
      Util.check!(FFI.ncdirect_cursor_up(to_ptr, count), DirectError, 'ncdirect_cursor_up')
      self
    end

    # Sposta il cursore in giù (+ncdirect_cursor_down+): emette count tab
    # verticali, quindi sull'ultima riga lo schermo scorre e la colonna resta.
    #
    # @param count [Integer] righe, 0..INT_MAX
    # @return [self]
    # @raise [TypeError, ArgumentError] se count non è un intero >= 0
    # @raise [DirectError] se la scrittura fallisce
    # @raise [ClosedError] se il contesto è chiuso
    def cursor_down(count = 1)
      Util.nonneg_int!(count, 'count')
      Util.check!(FFI.ncdirect_cursor_down(to_ptr, count), DirectError, 'ncdirect_cursor_down')
      self
    end

    # Sposta il cursore a sinistra (+ncdirect_cursor_left+).
    #
    # @param count [Integer] colonne, 0..INT_MAX
    # @return [self]
    # @raise [TypeError, ArgumentError] se count non è un intero >= 0
    # @raise [DirectError] se il terminale non lo permette
    # @raise [ClosedError] se il contesto è chiuso
    def cursor_left(count = 1)
      Util.nonneg_int!(count, 'count')
      Util.check!(FFI.ncdirect_cursor_left(to_ptr, count), DirectError, 'ncdirect_cursor_left')
      self
    end

    # Sposta il cursore a destra (+ncdirect_cursor_right+).
    #
    # @param count [Integer] colonne, 0..INT_MAX
    # @return [self]
    # @raise [TypeError, ArgumentError] se count non è un intero >= 0
    # @raise [DirectError] se il terminale non lo permette
    # @raise [ClosedError] se il contesto è chiuso
    def cursor_right(count = 1)
      Util.nonneg_int!(count, 'count')
      Util.check!(FFI.ncdirect_cursor_right(to_ptr, count), DirectError, 'ncdirect_cursor_right')
      self
    end

    # Posizione del cursore, letta dal terminale (+ncdirect_cursor_yx+).
    #
    # Attende la risposta del terminale alla query senza timeout, con il GVL
    # rilasciato (gli altri thread Ruby girano, ma non devono usare il
    # contesto); un input che somiglia alla risposta può falsare il risultato.
    #
    # @return [Array(Integer, Integer)] [y, x] a partire da 0
    # @raise [DirectError] se il terminale non riporta il cursore
    #   ({#can_get_cursor?} falso: il wrapper non chiama il C) o la lettura
    #   fallisce
    # @raise [ClosedError] se il contesto è chiuso
    def cursor_yx
      ptr = to_ptr
      unless FFI.ncdirect_canget_cursor(ptr)
        raise DirectError, 'cursor_yx: il terminale non riporta la posizione del cursore'
      end

      y = ::FFI::MemoryPointer.new(:uint)
      x = ::FFI::MemoryPointer.new(:uint)
      Util.check!(FFI.ncdirect_cursor_yx(ptr, y, x), DirectError, 'ncdirect_cursor_yx')
      [y.read_uint, x.read_uint]
    end

    # Salva la posizione del cursore nel terminale (+ncdirect_cursor_push+).
    # La profondità della pila dipende dal terminale (xterm: un solo posto).
    #
    # @return [self]
    # @raise [DirectError] se il terminale non lo permette
    # @raise [ClosedError] se il contesto è chiuso
    def cursor_push
      Util.check!(FFI.ncdirect_cursor_push(to_ptr), DirectError, 'ncdirect_cursor_push')
      self
    end

    # Ripristina la posizione salvata con {#cursor_push} (+ncdirect_cursor_pop+).
    #
    # @return [self]
    # @raise [DirectError] se il terminale non lo permette
    # @raise [ClosedError] se il contesto è chiuso
    def cursor_pop
      Util.check!(FFI.ncdirect_cursor_pop(to_ptr), DirectError, 'ncdirect_cursor_pop')
      self
    end

    # --- linee e box ---

    # Linea orizzontale dal cursore, con i colori interpolati da channels a to
    # (+ncdirect_hline_interp+). Il C non controlla il bordo dello schermo: a
    # fine riga il terminale va a capo. L'ultimo carattere non arriva del tutto
    # a to; un lato default e l'altro no interpola dal nero.
    #
    # @param egc [String] un solo carattere largo una colonna
    # @param len [Integer] caratteri, 1..{MAX_LINE}
    # @param channels [Channels, Integer] colori del primo carattere (RGB o
    #   default, non palette)
    # @param to [Channels, Integer] colori verso cui interpolare
    # @return [self]
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [DirectError] se la scrittura fallisce
    # @raise [ClosedError] se il contesto è chiuso
    def hline(egc, len, channels: 0, to: channels)
      ptr = to_ptr
      s = Args.line_egc(egc)
      Util.integer!(len, 'len', 1..MAX_LINE)
      c1 = Args.line_channels(channels, 'channels')
      c2 = Args.line_channels(to, 'to')
      Util.check!(FFI.ncdirect_hline_interp(ptr, s, len, c1, c2), DirectError, 'ncdirect_hline_interp')
      self
    end

    # Linea verticale dal cursore verso il basso, con i colori interpolati da
    # channels a to (+ncdirect_vline_interp+). Lo schermo scorre se serve.
    # L'interpolazione è a passi interi: con differenze piccole o linee lunghe
    # il colore non cambia.
    #
    # @param egc [String] un solo carattere largo una colonna
    # @param len [Integer] caratteri, 1..{MAX_LINE}
    # @param channels [Channels, Integer] come in {#hline}
    # @param to [Channels, Integer] come in {#hline}
    # @return [self]
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [DirectError] se la scrittura o un movimento del cursore falliscono
    # @raise [ClosedError] se il contesto è chiuso
    def vline(egc, len, channels: 0, to: channels)
      ptr = to_ptr
      s = Args.line_egc(egc)
      Util.integer!(len, 'len', 1..MAX_LINE)
      c1 = Args.line_channels(channels, 'channels')
      c2 = Args.line_channels(to, 'to')
      Util.check!(FFI.ncdirect_vline_interp(ptr, s, len, c1, c2), DirectError, 'ncdirect_vline_interp')
      self
    end

    # Box di rows x cols celle con l'angolo in alto a sinistra sul cursore
    # (+ncdirect_light_box+, +ncdirect_heavy_box+, +ncdirect_rounded_box+,
    # +ncdirect_double_box+, +ncdirect_ascii_box+, +ncdirect_box+). Alla fine il
    # cursore è dopo l'angolo in basso a destra. I lati interpolano sempre fra i
    # colori degli angoli (il C ignora NCBOXGRAD_*); il C non controlla il bordo
    # dello schermo.
    #
    # @param rows [Integer] righe, 2..{MAX_LINE}
    # @param cols [Integer] colonne, 2..{MAX_LINE}
    # @param style [Symbol, String] :light, :heavy, :rounded, :double, :ascii,
    #   oppure 6 caratteri larghi una colonna: angoli in alto a sinistra, in
    #   alto a destra, in basso a sinistra, in basso a destra, lato orizzontale,
    #   lato verticale
    # @param ul [Channels, Integer] colori dell'angolo in alto a sinistra (RGB
    #   o default, non palette)
    # @param ur [Channels, Integer] angolo in alto a destra
    # @param ll [Channels, Integer] angolo in basso a sinistra
    # @param lr [Channels, Integer] angolo in basso a destra
    # @param omit [Symbol, Array<Symbol>] lati da non disegnare: :top, :right,
    #   :bottom, :left
    # @param corners [Integer] lati adiacenti disegnati che servono per
    #   disegnare un angolo: 0 = sempre, 1, 2, 3 = mai
    # @return [self]
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [DirectError] se la scrittura fallisce (per esempio caratteri non
    #   rappresentabili nella locale); l'output resta parziale
    # @raise [ClosedError] se il contesto è chiuso
    def box(rows, cols, style: :light, ul: 0, ur: ul, ll: ul, lr: ul, omit: [], corners: 0)
      ptr = to_ptr
      Util.integer!(rows, 'rows', 2..MAX_LINE)
      Util.integer!(cols, 'cols', 2..MAX_LINE)
      corner = [ul, ur, ll, lr].zip(%w[ul ur ll lr]).map { |v, name| Args.line_channels(v, name) }
      ctlword = Array(omit).reduce(0) { |m, edge| m | Util.enum_value(BOX_EDGES, edge, 'omit') } |
                (Util.integer!(corners, 'corners', 0..3) << FFI::NCBOXCORNER_SHIFT)
      rc = case style
           when :light then FFI.ncdirect_light_box(ptr, *corner, rows, cols, ctlword)
           when :heavy then FFI.ncdirect_heavy_box(ptr, *corner, rows, cols, ctlword)
           when :rounded then FFI.ncdirect_rounded_box(ptr, *corner, rows, cols, ctlword)
           when :double then FFI.ncdirect_double_box(ptr, *corner, rows, cols, ctlword)
           when :ascii then FFI.ncdirect_ascii_box(ptr, *corner, rows, cols, ctlword)
           when String then FFI.ncdirect_box(ptr, *corner, box_chars(style), rows, cols, ctlword)
           else
             raise ArgumentError, "style = #{style.inspect} non valido: usa uno di " \
                                  "#{BOX_STYLES.map(&:inspect).join(', ')} o 6 caratteri"
           end
      Util.check!(rc, DirectError, 'ncdirect_box')
      self
    end

    # --- input ---

    # Legge un evento di input (+ncdirect_get_nblock+).
    #
    # L'attesa non avviene dentro il C: il wrapper attende con +IO#wait_readable+
    # sul descrittore di +ncdirect_inputready_fd+, che rilascia il GVL.
    #
    # @param timeout [Numeric, nil] secondi di attesa massima; nil = senza
    #   limite; 0 = non attende
    # @return [Input, nil] l'evento, o nil se il timeout scade. A fine input
    #   (stdin chiuso, o Ctrl+D letto da {#readline}) restituisce un evento con
    #   id {Key::EOF}, poi lo stesso evento a ogni chiamata
    # @raise [InputError] se il contesto scarta l'input (drain_input: true)
    # @raise [TypeError, ArgumentError] se timeout non è un numero >= 0
    # @raise [ClosedError] se il contesto è chiuso
    def get(timeout: nil)
      to_ptr
      timeout = Util.float!(timeout, 'timeout', 0.0..) unless timeout.nil?
      raise InputError, 'ncdirect_get: l\'input è scartato (drain_input: true)' if @drain_input
      return @eof_input if @eof_input

      wait_input(timeout) do
        ni = FFI::NcInput.new
        id = FFI.ncdirect_get_nblock(to_ptr, ni)
        # (uint32_t)-1 senza drain: EOF già consumato dal C (da readline, o una seconda volta)
        if id == 0xffff_ffff
          ni = FFI::NcInput.new
          ni[:id] = FFI::NCKEY_EOF
          id = FFI::NCKEY_EOF
        end
        next nil if id.zero?

        input = Input.new(ni)
        @eof_input = input if id == FFI::NCKEY_EOF
        input
      end
    end

    # Descrittore che diventa leggibile quando c'è input
    # (+ncdirect_inputready_fd+). Non chiuderlo: è di notcurses, e {#close} lo
    # chiude.
    #
    # @return [Integer]
    # @raise [InputError] se il descrittore non è disponibile
    # @raise [ClosedError] se il contesto è chiuso
    def inputready_fd
      Util.check!(FFI.ncdirect_inputready_fd(to_ptr), InputError, 'ncdirect_inputready_fd')
    end

    # Legge una riga dopo aver scritto prompt, con un editing minimo
    # (+ncdirect_readline+): Backspace cancella l'ultimo carattere, frecce,
    # Ctrl+A, Ctrl+E.
    #
    # Serve un terminale che riporti il cursore ({#can_get_cursor?}). Attende
    # senza timeout fino a Invio o Ctrl+D, con il GVL rilasciato: gli altri
    # thread Ruby girano (ma non devono usare il contesto), i segnali vengono
    # serviti al ritorno.
    #
    # @param prompt [String] testo da scrivere prima della riga
    # @return [String, nil] la riga senza il newline; nil a fine input (Ctrl+D
    #   o stdin chiuso senza testo) o se la lettura fallisce
    # @raise [InputError] se il contesto scarta l'input (drain_input: true)
    # @raise [DirectError] se il terminale non riporta il cursore (il wrapper
    #   non chiama il C)
    # @raise [TypeError, ArgumentError] se prompt non è una String valida
    # @raise [ClosedError] se il contesto è chiuso
    def readline(prompt: '')
      ptr = to_ptr
      text = Util.string!(prompt, 'prompt')
      raise InputError, 'ncdirect_readline: l\'input è scartato (drain_input: true)' if @drain_input
      return nil if @eof_input
      unless FFI.ncdirect_canget_cursor(ptr)
        raise DirectError, 'readline: il terminale non riporta la posizione del cursore'
      end

      Util.take_string(FFI.ncdirect_readline(ptr, text))
    end

    # --- immagini ---

    # Carica, scala e disegna un'immagine dalla posizione del cursore
    # (+ncdirect_render_image+). L'output scorre se serve; ogni riga finisce
    # con un newline e i colori tornano quelli di prima.
    #
    # @param path [String] file immagine (qualsiasi formato di ffmpeg)
    # @param align [Symbol] :left, :center o :right rispetto al terminale
    # @param blitter [Symbol, Integer] :default, :ascii, :half, :quad,
    #   :sextant, :octant, :braille, :pixel (degrada se non disponibile)
    # @param scale [Symbol, Integer] :scale, :stretch, :none, :scale_hires,
    #   :none_hires
    # @return [self]
    # @raise [DirectError] se il file non si apre o non si decodifica, se il
    #   contesto è senza multimedia (core: true), se l'immagine è più piccola di
    #   una cella o se la scrittura fallisce
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ClosedError] se il contesto è chiuso
    def render_image(path, align: :left, blitter: :default, scale: :scale)
      ptr = to_ptr
      file = Args.path(path)
      rc = FFI.ncdirect_render_image(ptr, file, Args.align(align), Args.blitter(blitter), Util.scale_value(scale))
      Util.check!(rc, DirectError, "ncdirect_render_image(#{file.inspect})")
      self
    end

    # Carica e scala un'immagine senza disegnarla (+ncdirect_render_frame+):
    # la disegna {Frame#raster}.
    #
    # @param path [String] file immagine
    # @param blitter [Symbol, Integer] come in {#render_image}
    # @param scale [Symbol, Integer] come in {#render_image}
    # @param max_rows [Integer] righe massime, 0..INT_MAX; 0 = il terminale. Il
    #   C lo ignora se supera l'altezza dell'immagine in pixel del blitter
    # @param max_cols [Integer] colonne massime (come max_rows)
    # @return [Frame]
    # @raise [DirectError] se il file non si apre o non si decodifica, se il
    #   contesto è senza multimedia o se l'immagine è più piccola di una cella
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ClosedError] se il contesto è chiuso
    def render_frame(path, blitter: :default, scale: :scale, max_rows: 0, max_cols: 0)
      ptr = to_ptr
      file = Args.path(path)
      b = Args.blitter(blitter)
      s = Util.scale_value(scale)
      Util.nonneg_int!(max_rows, 'max_rows')
      Util.nonneg_int!(max_cols, 'max_cols')
      v = FFI.ncdirect_render_frame(ptr, file, b, s, max_rows, max_cols)
      raise DirectError, "ncdirect_render_frame(#{file.inspect}) ha restituito NULL" if v.null?

      Frame.new(v, self)
    end

    # Carica un'immagine o un video da renderizzare più volte
    # (+ncdirectf_from_file+).
    #
    # @param path [String] file immagine o video
    # @return [Image] senza blocco; con un blocco, il valore del blocco
    #   (l'immagine viene chiusa alla fine)
    # @raise [DirectError] se il file non si apre o non si decodifica, o se il
    #   processo non ha il multimedia
    # @raise [TypeError, ArgumentError] se path non è valido
    # @raise [ClosedError] se il contesto è chiuso
    def load_image(path, &block) = Util.with_resource(Image.new(self, path), &block)

    # Disegna tutti i frame di un video (o di una GIF animata) uno sopra
    # l'altro, alla velocità della decodifica: per rallentare, attendi nel
    # blocco. Reimplementa +ncdirect_stream+, che in 3.0.17 ignora il ritorno
    # del callback (direct.c:1588) e non si può fermare: qui basta +break+ nel
    # blocco. Con il blitter :pixel i frame precedenti non vengono tolti dal
    # terminale (il C usa una funzione interna).
    #
    # @param path [String] file video o immagine
    # @param align [Symbol] :left, :center o :right
    # @param blitter [Symbol, Integer] come in {#render_image}
    # @param scale [Symbol, Integer] come in {#render_image}
    # @yieldparam index [Integer] indice del frame appena disegnato, da 0
    # @return [self] (con +break+, il valore di break)
    # @raise [DirectError] se il file non si apre, se un frame non si
    #   renderizza o non si decodifica, o se la scrittura fallisce
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ClosedError] se il contesto è chiuso
    def stream(path, align: :left, blitter: :default, scale: :scale)
      ptr = to_ptr
      Args.align(align)
      Args.visual_options(blitter, scale)
      load_image(path) do |image|
        rows = cols = index = rc = 0
        while rc.zero?
          # riposizionamento di ncdirect_stream (direct.c:1550-1559), che ne ignora i ritorni
          if rows.positive?
            if cols == FFI.ncdirect_dim_x(ptr)
              cols = 0
              rows += 1
            end
            FFI.ncdirect_cursor_up(ptr, rows - 1)
          end
          FFI.ncdirect_cursor_left(ptr, cols) if cols.positive?
          frame = image.render(self, blitter: blitter, scale: scale)
          rows, cols = frame.dims
          frame.raster(align: align)
          yield index if block_given?
          index += 1
          rc = FFI.ncvisual_decode(image.to_ptr)
        end
        Util.check!(rc, DirectError, 'ncvisual_decode')
      end
      flush
    end

    # --- capacità ---

    # Capacità del terminale (+ncdirect_capabilities+), copiate.
    # @return [Capabilities]
    # @raise [ClosedError] se il contesto è chiuso
    def capabilities = Capabilities.new(FFI.ncdirect_capabilities(to_ptr))

    # Nome (e versione, se nota) del terminale rilevato
    # (+ncdirect_detected_terminal+).
    # @return [String, nil]
    # @raise [ClosedError] se il contesto è chiuso
    def detected_terminal = Util.take_string(FFI.ncdirect_detected_terminal(to_ptr))

    # @return [Boolean] UTF-8 disponibile (+ncdirect_canutf8+)
    # @raise [ClosedError] se il contesto è chiuso
    def can_utf8? = FFI.ncdirect_canutf8(to_ptr)

    # @return [Boolean] colori RGB a 24 bit (+ncdirect_cantruecolor+)
    # @raise [ClosedError] se il contesto è chiuso
    def can_truecolor? = FFI.ncdirect_cantruecolor(to_ptr)

    # @return [Boolean] palette modificabile (+ncdirect_canchangecolor+); in
    #   modalità direct non c'è un'API per cambiarla
    # @raise [ClosedError] se il contesto è chiuso
    def can_change_color? = FFI.ncdirect_canchangecolor(to_ptr)

    # @return [Boolean] dissolvenze possibili (+ncdirect_canfade+)
    # @raise [ClosedError] se il contesto è chiuso
    def can_fade? = FFI.ncdirect_canfade(to_ptr)

    # @return [Boolean] caricamento di immagini disponibile
    #   (+ncdirect_canopen_images+): dipende dal processo, non dal contesto
    # @raise [ClosedError] se il contesto è chiuso
    def can_open_images? = FFI.ncdirect_canopen_images(to_ptr)

    # @return [Boolean] caricamento di video disponibile (+ncdirect_canopen_videos+)
    # @raise [ClosedError] se il contesto è chiuso
    def can_open_videos? = FFI.ncdirect_canopen_videos(to_ptr)

    # @return [Boolean] semiblocchi disponibili (+ncdirect_canhalfblock+:
    #   in 3.0.17 equivale a {#can_utf8?})
    # @raise [ClosedError] se il contesto è chiuso
    def can_halfblock? = FFI.ncdirect_canhalfblock(to_ptr)

    # @return [Boolean] quadranti disponibili (+ncdirect_canquadrant+)
    # @raise [ClosedError] se il contesto è chiuso
    def can_quadrant? = FFI.ncdirect_canquadrant(to_ptr)

    # @return [Boolean] sestanti disponibili (+ncdirect_cansextant+)
    # @raise [ClosedError] se il contesto è chiuso
    def can_sextant? = FFI.ncdirect_cansextant(to_ptr)

    # @return [Boolean] ottanti disponibili (+ncdirect_canoctant+)
    # @raise [ClosedError] se il contesto è chiuso
    def can_octant? = FFI.ncdirect_canoctant(to_ptr)

    # @return [Boolean] Braille disponibile (+ncdirect_canbraille+)
    # @raise [ClosedError] se il contesto è chiuso
    def can_braille? = FFI.ncdirect_canbraille(to_ptr)

    # @return [Boolean] grafica a pixel disponibile (+ncdirect_check_pixel_support+);
    #   falso senza un tty
    # @raise [ClosedError] se il contesto è chiuso
    def can_pixel? = FFI.ncdirect_check_pixel_support(to_ptr).positive?

    # @return [Boolean] il terminale può riportare la posizione del cursore:
    #   serve un tty con la capability u7 (+ncdirect_canget_cursor+). Non
    #   garantisce che il terminale risponda davvero
    # @raise [ClosedError] se il contesto è chiuso
    def can_get_cursor? = FFI.ncdirect_canget_cursor(to_ptr)

    # Immagine o video caricato in memoria (+ncdirectf*+, cioè un +ncvisual+),
    # da renderizzare più volte con {#render}. Non dipende dal contesto con cui
    # è stata caricata: resta valida anche dopo {Direct#close}. Chiudila con
    # {#close} (o usa il blocco di {Direct#load_image}): il GC non la libera.
    class Image
      include Resource
      extend Resource::ClassMethods

      # Campi di +ncvgeom+ restituiti da {#geom}.
      GEOM_FIELDS = %i[pixy pixx cdimy cdimx rpixy rpixx rcelly rcellx scaley scalex begy begx leny lenx
                       maxpixely maxpixelx].freeze

      # Carica il file (+ncdirectf_from_file+). Usa di solito {Direct#load_image}.
      #
      # @param direct [Direct] contesto aperto
      # @param path [String] file immagine o video
      # @raise [DirectError] se il file non si apre o non si decodifica, o se il
      #   processo non ha il multimedia
      # @raise [TypeError, ArgumentError] se un argomento non è valido
      # @raise [ClosedError] se direct è chiuso
      def initialize(direct, path)
        dptr = Util.ptr_of(direct, Direct, 'direct')
        file = Args.path(path)
        ptr = FFI.ncdirectf_from_file(dptr, file)
        if ptr.null?
          raise DirectError, "ncdirectf_from_file(#{file.inspect}) ha restituito NULL (file mancante o non " \
                             'decodificabile? contesto senza multimedia?)'
        end

        @ptr = ptr
        @closed = false
        @owner = nil
      end

      # Libera l'immagine (+ncdirectf_free+). Idempotente; i {Frame} già
      # renderizzati restano validi.
      # @return [nil]
      def close
        return nil if @closed

        @closed = true
        FFI.ncdirectf_free(@ptr)
        nil
      end
      alias free close

      # Scala l'immagine per il terminale senza disegnarla (+ncdirectf_render+):
      # la disegna {Frame#raster}. L'immagine resta riusabile.
      #
      # @param direct [Direct] contesto aperto
      # @param blitter [Symbol, Integer] come in {Direct#render_image}
      # @param scale [Symbol, Integer] come in {Direct#render_image}
      # @return [Frame]
      # @raise [DirectError] se il render fallisce (per esempio un'immagine più
      #   piccola di una cella con scale: :none)
      # @raise [TypeError, ArgumentError] se un argomento non è valido
      # @raise [ClosedError] se l'immagine o direct sono chiusi
      def render(direct, blitter: :default, scale: :scale)
        dptr = Util.ptr_of(direct, Direct, 'direct')
        vopts = Args.visual_options(blitter, scale)
        v = FFI.ncdirectf_render(dptr, to_ptr, vopts)
        raise DirectError, 'ncdirectf_render ha restituito NULL' if v.null?

        Frame.new(v, direct)
      end

      # Geometria di un render (+ncdirectf_geom+). Senza un tty usa
      # LINES/COLUMNS mentre il render usa 24x80: le dimensioni affidabili sono
      # quelle di {Frame#dims}.
      #
      # @param direct [Direct] contesto aperto
      # @param blitter [Symbol, Integer] come in {Direct#render_image}
      # @param scale [Symbol, Integer] come in {Direct#render_image}
      # @return [Hash{Symbol => Integer, Symbol}] i campi di +ncvgeom+
      #   ({GEOM_FIELDS}: pixy/pixx = pixel dell'immagine, rcelly/rcellx =
      #   celle del render, scaley/scalex = pixel per cella, ...) e :blitter
      #   (il blitter scelto, come simbolo)
      # @raise [DirectError] se il blitter non è disponibile
      # @raise [TypeError, ArgumentError] se un argomento non è valido
      # @raise [ClosedError] se l'immagine o direct sono chiusi
      def geom(direct, blitter: :default, scale: :scale)
        dptr = Util.ptr_of(direct, Direct, 'direct')
        vopts = Args.visual_options(blitter, scale)
        g = FFI::NcVgeom.new
        Util.check!(FFI.ncdirectf_geom(dptr, to_ptr, vopts, g), DirectError, 'ncdirectf_geom')
        GEOM_FIELDS.to_h { |f| [f, g[f]] }.merge(blitter: Util.enum_symbol(Util::BLITTERS, g[:blitter])).freeze
      end
    end

    # Immagine già scalata, pronta da disegnare una sola volta (+ncdirectv*+:
    # un piano senza pila). La crea {Direct#render_frame} o {Image#render}.
    #
    # Si libera solo disegnandola con {#raster}: {#close} la abbandona senza
    # liberarla (in 3.0.17 non esiste altro modo: +ncplane_destroy+ su un
    # ncdirectv va in crash), e lo stesso succede ai frame non disegnati quando
    # il contesto si chiude.
    class Frame
      include Resource

      # @param ptr [::FFI::Pointer] ncdirectv* restituito dal C
      # @param direct [Direct] contesto che lo disegnerà
      # @api private
      def initialize(ptr, direct)
        @ptr = ptr
        @closed = false
        @owner = direct
      end

      # @return [Array(Integer, Integer)] [righe, colonne] del frame
      #   (+ncplane_dim_yx+)
      # @raise [ClosedError] se il frame è già stato disegnato o abbandonato, o
      #   se il contesto è chiuso
      def dims
        rows = ::FFI::MemoryPointer.new(:uint)
        cols = ::FFI::MemoryPointer.new(:uint)
        FFI.ncplane_dim_yx(to_ptr, rows, cols)
        [rows.read_uint, cols.read_uint]
      end

      # Disegna il frame dalla riga del cursore e lo libera
      # (+ncdirect_raster_frame+). Ogni riga finisce con un newline; con :center
      # e :right un frame più largo del terminale parte dalla colonna 0. Dopo la
      # chiamata il frame è chiuso, anche se fallisce.
      #
      # @param align [Symbol] :left, :center o :right
      # @return [nil]
      # @raise [DirectError] se la scrittura fallisce
      # @raise [ArgumentError] se align non è valido (il frame resta usabile)
      # @raise [ClosedError] se il frame è già stato disegnato o abbandonato, o
      #   se il contesto è chiuso
      def raster(align: :left)
        ptr = to_ptr
        dptr = @owner.to_ptr
        a = Args.align(align)
        @closed = true # il C libera il piano su tutti i percorsi: un secondo raster sarebbe un double free
        Util.check!(FFI.ncdirect_raster_frame(dptr, ptr, a), DirectError, 'ncdirect_raster_frame')
        nil
      end

      # Abbandona il frame senza disegnarlo. La memoria C resta allocata (vedi
      # la descrizione della classe). Idempotente.
      # @return [nil]
      def close
        @closed = true
        nil
      end
    end

    private

    def check_output!(output)
      case output
      when nil, String then nil
      when ::FFI::Pointer
        raise ArgumentError, 'output è un puntatore NULL: usa nil per lo stdout' if output.null?
      else raise TypeError, "output deve essere nil, String o ::FFI::Pointer (FILE*), non #{output.class}"
      end
    end

    # @return [Array(::FFI::Pointer, Boolean)] FILE* e true se va chiuso da close
    def open_output(output)
      return [::FFI::Pointer::NULL, false] if output.nil?
      return [output, false] if output.is_a?(::FFI::Pointer)

      fp = FFI.fopen(Util.string!(output, 'output'), 'w')
      raise InitError, "fopen(#{output.inspect}, \"w\") fallita" if fp.null?

      [fp, true]
    end

    def rgb8!(r, g, b)
      Util.uint8!(r, 'r')
      Util.uint8!(g, 'g')
      Util.uint8!(b, 'b')
    end

    # Maschera degli stili, rifiutando quelli che il C non accetta.
    def supported_styles!(ptr, styles)
      mask = Util.styles_value(styles)
      extra = mask & ~FFI.ncdirect_supported_styles(ptr)
      return mask if extra.zero?

      names = Util.styles_symbols(extra)
      names = format('0x%04x', extra) if names.empty?
      raise ArgumentError, "stili non supportati dal terminale: #{names.inspect}"
    end

    # Colonna di ncdirect_align (direct.c:411-426): 0 se il testo non sta.
    def aligned_x(align, width, cols)
      return 0 if width > cols

      align == FFI::NCALIGN_CENTER ? (cols - width) / 2 : cols - width
    end

    # Sei caratteri di un box come vettore wchar_t (UL, UR, LL, LR, HL, VL).
    def box_chars(style)
      chars = Util.string!(style, 'style').chars
      unless chars.size == 6 && chars.all? { |c| FFI.wcwidth(c.ord) == 1 }
        raise ArgumentError, "style = #{style.inspect}: servono 6 caratteri larghi una colonna"
      end

      ::FFI::MemoryPointer.new(:wchar_t, 6).put_array_of_int32(0, chars.map(&:ord))
    end

    # Ripete il blocco finché restituisce un valore, attendendo l'input fuori
    # dal C (come Context#wait_input): ogni get che consuma un evento svuota la
    # pipe di prontezza, quindi si riprova sempre prima di attendere.
    # @param timeout [Float, nil] già validato
    def wait_input(timeout)
      deadline = timeout && (Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout)
      loop do
        result = yield
        return result unless result.nil?
        return nil if timeout&.zero?

        remaining = deadline && (deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC))
        return nil if remaining && remaining <= 0

        # il descrittore è di notcurses: autoclose false, lo chiude ncdirect_stop
        @input_io ||= IO.for_fd(inputready_fd, autoclose: false)
        @input_io.wait_readable(remaining)
      end
    end
  end
end
