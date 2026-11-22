# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Campo di testo (+ncreader+): raccoglie l'input in un piano, con il cursore,
  # le frecce, Backspace e le scorciatoie di modifica in stile readline.
  #
  # Il reader prende possesso del piano ricevuto (vedi {Widget}), che diventa
  # la vista del testo; il C tiene una copia nascosta del testo in un secondo
  # piano, figlio dello stdplane. Alla chiusura distrugge entrambi. Il testo
  # non va a capo: in fondo a una riga il cursore resta sull'ultima colonna e
  # il carattere successivo la sovrascrive; si cambia riga con le frecce. Un
  # carattere di larghezza zero (U+FE0F, ZWJ, U+200B, un segno combinante
  # isolato) scritto sull'ultima colonna viene scartato.
  #
  # Il wrapper protegge vista e copia nascosta, che il C tiene allineate senza
  # controlli (un disallineamento termina il processo con un'asserzione o
  # legge fuori dal piano): rifiuta piani con scrolling o autogrow, riporta il
  # cursore della vista al suo posto prima di ogni operazione, e solleva
  # WidgetError se nel frattempo il piano è stato ridimensionato o ha attivato
  # scrolling o autogrow. Non scrivere sul piano del reader, né sulla copia
  # nascosta: è un figlio dello stdplane che si raggiunge navigando la pila
  # (per esempio con {Plane#below}), e il wrapper non la protegge.
  #
  # Ogni ridisegno del C accende il cursore del terminale e lo porta nel campo
  # (+notcurses_cursor_enable+), anche senza NCREADER_OPTION_CURSOR. Con
  # cursor: false il wrapper lo rimette subito come l'ha chiesto l'ultima
  # chiamata a {Context#cursor_enable} o {Context#cursor_disable}, o nascosto
  # se non ce ne sono state, anche dopo un reader con cursor: true (senza un
  # tty il C non lo spegne); con cursor: true il reader lo mostra nel campo e
  # la chiusura lo spegne. Con un reader con cursor: true e uno con
  # cursor: false aperti insieme decide l'ultima operazione: il cursore resta
  # come l'ha lasciato il reader che ha ridisegnato per ultimo.
  #
  # Bug di 3.0.17 da conoscere:
  # - NCREADER_OPTION_HORSCROLL non è offerto: con lo scorrimento orizzontale
  #   due glifi larghi bastano a far terminare il processo (asserzione
  #   +xproject >= 0+, reader.c:90) e {#contents} perde il testo uscito dalla
  #   vista; NCREADER_OPTION_VERSCROLL non è implementato;
  # - i canali e lo stile del testo (+tchannels+, +tattrword+) non hanno
  #   effetto e non sono offerti.
  #
  # @example
  #   plane = nc.stdplane.create_child(rows: 1, cols: 30, y: 5, x: 2)
  #   reader = Notcurses::Reader.new(plane, cursor: true)
  #   until (ev = nc.get).id == Notcurses::Key::ENTER
  #     nc.render if reader.offer_input(ev)
  #   end
  #   nome = reader.contents
  #   reader.close
  class Reader
    include Widget
    extend Resource::ClassMethods

    # Campi privati di +struct ncreader+ fino a textarea (notcurses 3.0.17,
    # src/lib/internal.h:213-222): l'API pubblica non dà il piano nascosto del
    # testo. Il workaround della colonna 0 li usa solo attraverso text_area,
    # che controlla la versione della libreria e i campi.
    #
    # @api private
    class Internals < ::FFI::Struct
      layout :ncp, :pointer, :tchannels, :uint64, :tattrs, :uint32, :textarea, :pointer
    end
    private_constant :Internals

    # Bit dello stylemask che notcurses 3.0.17 non usa (gli stili NCSTYLE_*
    # arrivano a 0x0010): segna le celle della copia nascosta durante
    # Backspace, Ctrl+U e Ctrl+W (vedi {#offer_input}).
    RECOPY_STYLE = 0x8000
    private_constant :RECOPY_STYLE

    # Crea il reader sul piano (+ncreader_create+), che viene svuotato.
    #
    # @param plane [Plane] piano posseduto dal wrapper, non lo stdplane, non
    #   già di un widget, senza scrolling né autogrow: passa al reader
    # @param no_cmd_keys [Boolean] NCREADER_OPTION_NOCMDKEYS: non gestire le
    #   scorciatoie con Ctrl e Alt (le lascia all'applicazione)
    # @param cursor [Boolean] NCREADER_OPTION_CURSOR: il reader mostra il
    #   cursore del terminale nel campo e lo spegne alla chiusura; con false il
    #   cursore resta come l'ha chiesto l'applicazione con
    #   {Context#cursor_enable} o {Context#cursor_disable}, anche dopo un
    #   reader con cursor: true. Con un reader con cursor: true e uno con
    #   cursor: false aperti insieme decide l'ultima operazione (vedi la
    #   descrizione della classe)
    # @raise [WidgetError] se +ncreader_create+ fallisce (il piano risulta
    #   distrutto); se il piano è lo stdplane, è già di un widget, non è
    #   posseduto, scorre o cresce da solo; dentro un callback chiamato da
    #   notcurses
    # @raise [TypeError] se un'opzione non è true o false
    # @raise [ClosedError] se il piano è chiuso
    def initialize(plane, no_cmd_keys: false, cursor: false)
      Guard.run do
        claim_plane!(plane)
        ctx = plane.context
        ctx.check_not_in_callback!('Reader.new', WidgetError)
        opts = FFI::NcReaderOptions.new
        opts[:flags] = Util.flag(no_cmd_keys, FFI::NCREADER_OPTION_NOCMDKEYS, 'no_cmd_keys') |
                       Util.flag(cursor, FFI::NCREADER_OPTION_CURSOR, 'cursor')
        @no_cmd_keys = no_cmd_keys
        @manage_cursor = cursor
        # ncplane_put farebbe scorrere o crescere solo la vista (reader.c:90-104)
        raise WidgetError, 'il piano di un reader non può avere lo scrolling attivo' if plane.scrolling?
        raise WidgetError, "il piano di un reader non può avere l'autogrow attivo" if plane.autogrow?

        ptr = FFI.ncreader_create(plane.to_ptr, opts)
        if ptr.null?
          plane_destroyed_on_failure!(plane)
          raise WidgetError, 'ncreader_create ha restituito NULL (il piano è stato distrutto)'
        end
        attach!(ptr, plane)
        # la copia nascosta parte vuota con il cursore in (0, 0): così anche la vista
        FFI.ncreader_clear(ptr)
        @dims = plane.dims
        @cursor = plane.cursor
      end
    end

    # Piano del reader (+ncreader_plane+): lo stesso Plane passato a
    # {#initialize}, la vista del testo.
    #
    # @return [Plane]
    # @raise [ClosedError] se il reader è chiuso
    def plane = Guard.run { @context.plane_for(FFI.ncreader_plane(to_ptr)) }

    # Passa un evento al reader e ridisegna, senza render. Consuma:
    # - il testo dell'evento ({Input#eff_text}), scritto un codepoint alla
    #   volta con +ncreader_write_egc+ anche se la scrittura fallisce (Esc
    #   vale true e non scrive nulla);
    # - Backspace, che cancella il carattere prima del cursore;
    # - le frecce, anche quando il cursore non si può spostare;
    # - senza no_cmd_keys: Ctrl+B e Ctrl+F (carattere indietro e avanti),
    #   Ctrl+A e Ctrl+E (inizio e fine riga), Ctrl+U (cancella fino a inizio
    #   riga), Ctrl+W (cancella la parola prima del cursore), Alt+b e Alt+f
    #   (parola indietro e avanti). Le lettere con Ctrl sono maiuscole, come
    #   le produce notcurses.
    # Non consuma i rilasci dei tasti, gli altri tasti speciali (Invio, F1,
    # ...) e le altre combinazioni con Ctrl o Alt. Gli eventi che non sono
    # testo vanno a +ncreader_offer_input+.
    #
    # Il testo lo scrive il wrapper, come farebbe il C (reader.c:404-410),
    # per evitare due bug di 3.0.17: con 4 codepoint il C legge oltre l'array
    # eff_text, e un TAB nell'ultima colonna fa scrivere una cella oltre la
    # riga (oltre il piano sull'ultima riga, notcurses.c:1936, 1956-1957): lì il
    # wrapper scrive uno spazio, il risultato che il C intende. Un carattere
    # di larghezza zero nell'ultima colonna (per esempio U+FE0F di "❤️", che
    # arriva da solo) viene scartato e conta come scritto: il C porterebbe il
    # cursore oltre la riga, perdendo il testo successivo, e Backspace con una
    # freccia sinistra terminerebbe il processo. Altro bug
    # aggirato: Backspace all'inizio di una riga successiva alla prima sposta
    # sulla riga sopra solo la copia nascosta (reader.c:265); il wrapper
    # sposta anche la vista, altrimenti la freccia sinistra successiva
    # termina il processo, e il cursore del terminale. Ancora: Backspace, Ctrl+U
    # e Ctrl+W su un glifo largo lasciavano nella vista la sua metà destra, e il
    # glifo largo successivo in fondo alla riga scriveva oltre il piano
    # (notcurses.c:1957-1961): il wrapper svuota la vista prima di questi tasti
    # e il ridisegno del C la ricopia dalla copia nascosta. Il ridisegno però
    # non copiava la larghezza delle metà destre dei glifi larghi rimasti
    # (+cellcmp_and_dupfar+ non la confronta, internal.h:1510-1523), e
    # {Plane#at} su quelle celle non restituiva il glifo: il wrapper segna le
    # celle della copia nascosta durante la chiamata, così il ridisegno copia
    # ogni cella cambiata con la sua larghezza. Infine Backspace,
    # Ctrl+U e Ctrl+W non cancellavano il carattere della colonna 0: il C
    # cancella scrivendo "" con +ncplane_putegc_yx+, che in colonna 0 fallisce
    # ((unsigned)x + cols - 1 con cols 0, notcurses.c:1883). Il wrapper svuota
    # quella cella nella vista e nella copia nascosta, con le due metà di un
    # glifo largo; Ctrl+W si ferma prima, come nel C, su un separatore (per
    # esempio uno spazio) in colonna 0. Backspace dopo un glifo largo portava i
    # cursori sulla sua metà destra, perché il C cancella la colonna prima del
    # cursore e porta lì i cursori (reader.c:263-265), e il carattere
    # successivo lasciava un buco nella riga (ICH-581): il wrapper porta i
    # cursori della copia nascosta, della vista e, con cursor: true, del
    # terminale sulla prima colonna del glifo.
    #
    # @param input [Input] evento, per esempio da {Context#get}
    # @return [Boolean] true se il reader ha consumato l'evento; false anche
    #   per un evento vuoto (id 0 o 0xffffffff)
    # @raise [WidgetError] se il piano del reader è stato modificato dall'esterno;
    #   se il cursore della vista non torna al suo posto (+ncplane_cursor_move_yx+
    #   fallisce), prima della chiamata C; se la cella della colonna 0 non si
    #   svuota (+ncplane_putc_yx+ fallisce)
    # @raise [TypeError] se input non è un Input
    # @raise [ClosedError] se il reader è chiuso
    def offer_input(input)
      Guard.run do
        redraw do |ptr|
          ni = input_struct(input)
          return false if ni.nil?

          plain = !input.release? && !input.modifiers.anybits?(FFI::NCKEY_MOD_CTRL | FFI::NCKEY_MOD_ALT)
          if plain && !Key.synthesized?(input.id)
            input.eff_text.each_char { |egc| put_egc(ptr, egc) }
            return true
          end
          y, x = @cursor
          backspace = plain && input.id == Key::BACKSPACE
          wrap = backspace && x.zero? && y.positive?
          # Backspace, Ctrl+U e Ctrl+W cancellano solo nella copia nascosta, e il
          # ridisegno copia una cella solo se EGC, stile o canali sono diversi, senza
          # confrontare la width (cellcmp_and_dupfar, internal.h:1510-1523): una metà
          # destra larga resterebbe nella vista. Svuotata, la vista viene ricopiata,
          # ma le sue celle vuote hanno EGC "" come le metà destre della copia
          # nascosta, che il ridisegno lascerebbe con width 0 (ICH-484). Con
          # RECOPY_STYLE su ogni cella della copia nascosta, che il C cancella con
          # stile 0, il ridisegno copia ogni cella cambiata, anche ai ridisegni
          # successivi di Ctrl+U e Ctrl+W; poi lo stile torna 0 nei due piani.
          ctrl = !@no_cmd_keys && !input.release? && input.modifiers.anybits?(FFI::NCKEY_MOD_CTRL)
          deletion = backspace ? :backspace : (ctrl && x.positive? && {0x55 => :line, 0x57 => :word}[input.id])
          text = deletion && text_area(ptr)
          wide_start = wide_glyph_start(text, y, x) if text && backspace && x >= 2
          if deletion
            FFI.ncplane_erase(@plane.to_ptr)
            FFI.ncplane_format(text, 0, 0, 0, 0, RECOPY_STYLE) if text
            move_view_cursor!(y, x)
          end
          consumed =
            begin
              FFI.ncreader_offer_input(ptr, ni)
            ensure
              [text, @plane.to_ptr].each { |plane| FFI.ncplane_format(plane, 0, 0, 0, 0, 0) } if text
            end
          wrap_backspace(y - 1) if wrap
          rewind_wide_backspace(text, y, wide_start) if wide_start
          @cursor = @plane.cursor
          clear_column_zero!(text, deletion, y, x) if text
          consumed
        end
      end
    end

    # Scrive del testo alla posizione del cursore (+ncreader_write_egc+, un
    # EGC di notcurses alla volta) e ridisegna, senza render. In fondo alla
    # riga il cursore resta sull'ultima colonna e il testo successivo la
    # sovrascrive; un carattere di larghezza zero sull'ultima colonna viene
    # scartato (vedi {#offer_input}).
    #
    # notcurses divide alcuni grapheme di Ruby in più EGC (il keycap "1️⃣",
    # le bandiere, i congiunti devanagari come "क्ष"), e +ncreader_write_egc+
    # scrive solo il primo EGC della stringa: il wrapper passa i pezzi uno
    # alla volta, secondo la segmentazione di notcurses (+nccell_load+). Un
    # grapheme diviso occupa quindi più celle.
    #
    # @param text [String] testo UTF-8, senza caratteri di controllo tranne
    #   "\t" (diventa spazi fino alla tabulazione successiva)
    # @return [self]
    # @raise [WidgetError] se +ncreader_write_egc+ fallisce (per esempio un
    #   glifo largo che non entra nell'ultima colonna): il testo precedente
    #   resta scritto; se +nccell_load+ non riesce a dividere il testo (per
    #   esempio con l'egcpool della vista pieno), con il testo precedente
    #   scritto; se il piano del reader è stato modificato dall'esterno;
    #   se il cursore della vista non torna al suo posto
    #   (+ncplane_cursor_move_yx+ fallisce), prima della chiamata C
    # @raise [TypeError, ArgumentError] se text non è una String valida
    # @raise [ClosedError] se il reader è chiuso
    def write(text)
      Guard.run do
        redraw do |ptr|
          str = Util.string!(text, 'text')
          raise ArgumentError, "text = #{text.inspect} contiene caratteri di controllo" if str.match?(/[\p{Cc}&&[^\t]]/)

          view = @plane.to_ptr
          cell = FFI::NcCell.new
          str.each_grapheme_cluster do |g|
            off = 0
            while off < g.bytesize
              len = FFI.nccell_load(view, cell, g.byteslice(off..))
              FFI.nccell_release(view, cell) # serve solo la lunghezza: libera subito lo stash nel pool della vista
              Util.check!(len, WidgetError, "nccell_load(#{g.byteslice(off..).inspect})") # -1: per esempio pool pieno
              # un pezzo che taglia un codepoint (U+2028 dà 1 byte): il resto va al C, che lo rifiuta
              egc = g.byteslice(off, len)
              egc = g.byteslice(off..) if egc.empty? || !egc.valid_encoding?
              Util.check!(put_egc(ptr, egc), WidgetError, "ncreader_write_egc(#{egc.inspect})")
              off += egc.bytesize
            end
          end
          self
        end
      end
    end

    # Testo del reader: le righe della vista, unite senza separatori, saltando
    # le celle vuote; un glifo largo compare una volta (come
    # +ncreader_contents+).
    #
    # Bug di 3.0.17 aggirato: +ncreader_contents+ è +ncplane_contents+ sulla
    # vista, che lascia nell'egcpool della vista una copia di ogni EGC di più
    # di 4 byte a ogni chiamata (il pool cresce fino al limite di 16 MiB, poi
    # la lettura fallisce): il wrapper legge la vista con {Plane#contents}.
    #
    # @return [String]
    # @raise [PlaneError] se la lettura di una cella fallisce
    # @raise [ClosedError] se il reader è chiuso
    def contents
      Guard.run do
        to_ptr
        @plane.contents
      end
    end

    # Cancella il testo e riporta il cursore in (0, 0) (+ncreader_clear+),
    # senza ridisegnare né spostare il cursore del terminale.
    #
    # @return [self]
    # @raise [ClosedError] se il reader è chiuso
    def clear
      Guard.run do
        FFI.ncreader_clear(to_ptr)
        @cursor = @plane.cursor
        self
      end
    end

    # Sposta il cursore di una colonna a sinistra (+ncreader_move_left+);
    # dalla colonna 0 va all'ultima colonna della riga sopra. Ridisegna.
    #
    # @return [Boolean] false se il cursore era in (0, 0)
    # @raise [WidgetError] se il piano del reader è stato modificato dall'esterno;
    #   o se il cursore della vista non torna al suo posto
    # @raise [ClosedError] se il reader è chiuso
    def move_left = moved?(redraw { |ptr| FFI.ncreader_move_left(ptr) })

    # Sposta il cursore di una colonna a destra (+ncreader_move_right+),
    # anche su celle vuote; dall'ultima colonna va all'inizio della riga
    # sotto. Ridisegna.
    #
    # @return [Boolean] false se il cursore era sull'ultima colonna dell'ultima riga
    # @raise [WidgetError] se il piano del reader è stato modificato dall'esterno;
    #   o se il cursore della vista non torna al suo posto
    # @raise [ClosedError] se il reader è chiuso
    def move_right = moved?(redraw { |ptr| FFI.ncreader_move_right(ptr) })

    # Sposta il cursore di una riga in alto, nella stessa colonna
    # (+ncreader_move_up+). Ridisegna.
    #
    # @return [Boolean] false se il cursore era sulla prima riga
    # @raise [WidgetError] se il piano del reader è stato modificato dall'esterno;
    #   o se il cursore della vista non torna al suo posto
    # @raise [ClosedError] se il reader è chiuso
    def move_up = moved?(redraw { |ptr| FFI.ncreader_move_up(ptr) })

    # Sposta il cursore di una riga in basso, nella stessa colonna
    # (+ncreader_move_down+). Ridisegna.
    #
    # @return [Boolean] false se il cursore era sull'ultima riga
    # @raise [WidgetError] se il piano del reader è stato modificato dall'esterno;
    #   o se il cursore della vista non torna al suo posto
    # @raise [ClosedError] se il reader è chiuso
    def move_down = moved?(redraw { |ptr| FFI.ncreader_move_down(ptr) })

    private

    # +ncreader_destroy+ con NULL al posto del char** del testo: il testo si
    # legge prima con {#contents}. Con cursor: true il C spegne il cursore.
    def destroy_native
      Guard.run do
        FFI.ncreader_destroy(to_ptr, nil)
        @context.cursor_state_unknown! if @manage_cursor
      end
    end

    # Controlla la vista prima di un'operazione che il C ridisegna: stesse
    # dimensioni della copia nascosta, niente scrolling né autogrow, cursore
    # dove l'ha lasciato il reader (il C lo usa per proiettare la copia
    # nascosta: spostato, porta a leggere fuori dal piano, reader.c:134-136).
    #
    # @return [::FFI::Pointer] il puntatore del reader
    def prepare!
      Guard.run do
        ptr = to_ptr
        view = @plane.to_ptr
        if FFI.ncplane_dim_y(view) != @dims[0] || FFI.ncplane_dim_x(view) != @dims[1] ||
           FFI.ncplane_scrolling_p(view) || FFI.ncplane_autogrow_p(view)
          raise WidgetError, 'il piano del reader è stato ridimensionato o ha attivato scrolling o autogrow'
        end

        move_view_cursor!(*@cursor)
        @context.cursor_state_unknown! if @manage_cursor # il ridisegno del C accende il cursore del terminale
        ptr
      end
    end

    # Passa al blocco, che chiama il C, il puntatore del reader controllato da
    # prepare!. Con cursor: false poi rimette il cursore del terminale come
    # l'ha lasciato l'applicazione: ogni ridisegno del C lo accende e lo sposta
    # (reader.c:105).
    def redraw
      Guard.run do
        ptr = prepare!
        begin
          yield ptr
        ensure
          @context.restore_cursor! unless @manage_cursor
        end
      end
    end

    # +ncreader_write_egc+ di un grapheme cluster. Nell'ultima colonna un TAB
    # diventa uno spazio e un carattere di larghezza zero viene scartato: il
    # C porterebbe vista e copia nascosta a x == colonne (reader.c:240-246),
    # e da lì ogni scrittura fallisce e Backspace + freccia sinistra termina
    # il processo (asserzione xproject >= 0, reader.c:90).
    #
    # @return [Integer] il ritorno del C (0 per il carattere scartato)
    def put_egc(ptr, egc)
      last = @cursor[1] == @dims[1] - 1
      return 0 if last && FFI.ncstrwidth(egc, nil, nil).zero?

      egc = ' ' if egc == "\t" && last
      rc = FFI.ncreader_write_egc(ptr, egc)
      @cursor = @plane.cursor
      rc
    end

    # Dopo il Backspace a inizio riga porta il cursore della vista, e con
    # cursor: true quello del terminale che il ridisegno del C ha lasciato in
    # colonna 0, a fine della riga y, dove il C ha portato la copia nascosta
    # (reader.c:265).
    def wrap_backspace(y)
      Guard.run do
        x = @dims[1] - 1
        FFI.ncplane_cursor_move_yx(@plane.to_ptr, y, x)
        next unless @manage_cursor

        ay, ax = @plane.abs_yx
        FFI.notcurses_cursor_enable(@context.to_ptr, ay + y, ax + x) # come ncreader_redraw, esito ignorato
      end
    end

    # Prima di un Backspace dalla colonna x >= 2 della riga y: la colonna dove
    # inizia il glifo largo la cui metà destra è nella colonna x - 1 della copia
    # nascosta, nil se la colonna x - 1 non è una metà destra. Il C cancella
    # scrivendo "" sulla colonna x - 1 (reader.c:263), e +ncplane_put+ toglie
    # le due metà del glifo (notcurses.c:1917-1923), ma porta i cursori a x - 1,
    # la colonna della vecchia metà destra (reader.c:264-265).
    def wide_glyph_start(text, y, x)
      Guard.run do
        col = x - 1
        next unless wide_right_cell?(text, y, col)

        col -= 1 while col.positive? && wide_right_cell?(text, y, col)
        col
      end
    end

    # true se la cella (y, x) di un piano è la metà destra di un glifo largo
    # (width >= 2 e nessun EGC, come +nccell_wide_right_p+).
    def wide_right_cell?(plane, y, x)
      cell = FFI::NcCell.new
      FFI.ncplane_at_yx_cell(plane, y, x, cell) >= 0 && FFI.nccell_wide_right_p(cell)
    ensure
      FFI.nccell_release(plane, cell)
    end

    # Dopo un Backspace che ha cancellato un glifo largo, iniziato nella
    # colonna col della riga y: porta alla sua prima colonna i cursori della
    # copia nascosta e della vista, e con cursor: true quello del terminale che
    # il ridisegno del C ha lasciato sulla vecchia metà destra, come
    # {#wrap_backspace}.
    def rewind_wide_backspace(text, y, col)
      Guard.run do
        [text, @plane.to_ptr].each { |plane| FFI.ncplane_cursor_move_yx(plane, y, col) }
        next unless @manage_cursor

        ay, ax = @plane.abs_yx
        FFI.notcurses_cursor_enable(@context.to_ptr, ay + y, ax + col) # come ncreader_redraw, esito ignorato
      end
    end

    # Dopo Backspace, Ctrl+U o Ctrl+W (deletion :backspace, :line o :word, dal
    # cursore in (y, x)) svuota la colonna 0 della riga y dove il C ha provato
    # a cancellarla senza riuscirci (+ncplane_putegc_yx+ di "" fallisce in
    # colonna 0, notcurses.c:1883): Backspace dalla colonna 1, Ctrl+U sempre,
    # Ctrl+W se è arrivato alla colonna 0. Una cella vuota scritta con
    # +ncplane_putc_yx+ ha una colonna e passa il controllo; +ncplane_put+
    # toglie anche le due metà di un glifo largo (notcurses.c:1915-1927). Il
    # wrapper scrive nella copia nascosta e nella vista, poi riporta in colonna
    # 0 i loro cursori.
    def clear_column_zero!(text, deletion, y, x)
      Guard.run do
        attempted =
          case deletion
          when :backspace then x == 1
          when :line then true
          else word_reaches_column_zero?(text, y)
          end
        next unless attempted

        cell = FFI::NcCell.new
        [text, @plane.to_ptr].each do |plane|
          Util.check!(FFI.ncplane_putc_yx(plane, y, 0, cell), WidgetError, "ncplane_putc_yx(#{y}, 0)")
          FFI.ncplane_cursor_move_yx(plane, y, 0)
        end
      end
    end

    # true se Ctrl+W ha portato il cursore alla colonna 0 della riga y per
    # cancellarne il carattere. Il C si ferma prima su un separatore, che
    # resta: un carattere della categoria Unicode Z (iswordbreak,
    # internal.h:1500-1504), letto nella copia nascosta come
    # is_egc_wordbreak (reader.c:271-288); un EGC che non legge ferma il C.
    def word_reaches_column_zero?(text, y)
      Guard.run do
        next false unless @cursor == [y, 0]

        egc = Util.take_string(FFI.ncplane_at_yx(text, y, 0, nil, nil))
        !egc.nil? && !egc.match?(/\A\p{Z}/)
      end
    end

    # Piano nascosto del testo, dal campo privato textarea (vedi Internals);
    # nil, e niente workaround, se la libreria non è la 3.0.17 o i campi non
    # coincidono con l'API pubblica (ncreader_plane, dimensioni della vista).
    def text_area(ptr)
      Guard.run do
        next unless Notcurses.lib_version_components.first(3) == [3, 0, 17]

        st = Internals.new(ptr)
        text = st[:textarea]
        text if st[:ncp] == FFI.ncreader_plane(ptr) && !text.null? &&
                FFI.ncplane_dim_y(text) == @dims[0] && FFI.ncplane_dim_x(text) == @dims[1]
      end
    end

    # Riporta il cursore della vista in (y, x): se fallisce, vista e copia
    # nascosta non sono più allineate e il C non va chiamato.
    def move_view_cursor!(y, x)
      Guard.run do
        Util.check!(FFI.ncplane_cursor_move_yx(@plane.to_ptr, y, x), WidgetError, "ncplane_cursor_move_yx(#{y}, #{x})")
      end
    end

    # Esito di uno spostamento (-1 = nessuno spostamento possibile, non un errore).
    def moved?(rc)
      @cursor = @plane.cursor
      rc.zero?
    end
  end
end
