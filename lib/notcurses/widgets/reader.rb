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
  # Bug di 3.0.17 da conoscere:
  # - ogni ridisegno accende e sposta il cursore del terminale (con
  #   +notcurses_cursor_enable+), anche con cursor: false; con cursor: true la
  #   chiusura lo spegne. {Context#cursor_disable} lo spegne;
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

    # Crea il reader sul piano (+ncreader_create+), che viene svuotato.
    #
    # @param plane [Plane] piano posseduto dal wrapper, non lo stdplane, non
    #   già di un widget, senza scrolling né autogrow: passa al reader
    # @param no_cmd_keys [Boolean] NCREADER_OPTION_NOCMDKEYS: non gestire le
    #   scorciatoie con Ctrl e Alt (le lascia all'applicazione)
    # @param cursor [Boolean] NCREADER_OPTION_CURSOR: spegnere il cursore del
    #   terminale alla chiusura (vedi la descrizione della classe)
    # @raise [WidgetError] se +ncreader_create+ fallisce (il piano risulta
    #   distrutto); se il piano è lo stdplane, è già di un widget, non è
    #   posseduto, scorre o cresce da solo; dentro un callback chiamato da
    #   notcurses
    # @raise [TypeError] se un'opzione non è true o false
    # @raise [ClosedError] se il piano è chiuso
    def initialize(plane, no_cmd_keys: false, cursor: false)
      claim_plane!(plane)
      ctx = plane.context
      ctx.check_not_in_callback!('Reader.new', WidgetError)
      opts = FFI::NcReaderOptions.new
      opts[:flags] = Util.flag(no_cmd_keys, FFI::NCREADER_OPTION_NOCMDKEYS, 'no_cmd_keys') |
                     Util.flag(cursor, FFI::NCREADER_OPTION_CURSOR, 'cursor')
      @no_cmd_keys = no_cmd_keys
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

    # Piano del reader (+ncreader_plane+): lo stesso Plane passato a
    # {#initialize}, la vista del testo.
    #
    # @return [Plane]
    # @raise [ClosedError] se il reader è chiuso
    def plane = @context.plane_for(FFI.ncreader_plane(to_ptr))

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
    # e il ridisegno del C la ricopia dalla copia nascosta.
    #
    # Bug di 3.0.17 non aggirato: Backspace, Ctrl+U e Ctrl+W non cancellano il
    # carattere della colonna 0. Il C cancella scrivendo "" con
    # +ncplane_putegc_yx+, che in colonna 0 fallisce ((unsigned)x + cols - 1
    # con cols 0, notcurses.c:1883); il carattere successivo lo sovrascrive.
    # Per svuotare il campo usa {#clear}.
    #
    # @param input [Input] evento, per esempio da {Context#get}
    # @return [Boolean] true se il reader ha consumato l'evento; false anche
    #   per un evento vuoto (id 0 o 0xffffffff)
    # @raise [WidgetError] se il piano del reader è stato modificato dall'esterno;
    #   se il cursore della vista non torna al suo posto (+ncplane_cursor_move_yx+
    #   fallisce), prima della chiamata C
    # @raise [TypeError] se input non è un Input
    # @raise [ClosedError] se il reader è chiuso
    def offer_input(input)
      ptr = prepare!
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
      # ridisegno non confronta la width (internal.h:1512-1519): una metà destra
      # larga resterebbe nella vista. Svuotata, la vista viene ricopiata intera.
      ctrl = !@no_cmd_keys && !input.release? && input.modifiers.anybits?(FFI::NCKEY_MOD_CTRL)
      if backspace || (ctrl && x.positive? && [0x55, 0x57].include?(input.id)) # 'U', 'W'
        FFI.ncplane_erase(@plane.to_ptr)
        move_view_cursor!(y, x)
      end
      consumed = FFI.ncreader_offer_input(ptr, ni)
      wrap_backspace(y - 1) if wrap
      @cursor = @plane.cursor
      consumed
    end

    # Scrive del testo alla posizione del cursore (+ncreader_write_egc+, un
    # grapheme cluster alla volta) e ridisegna, senza render. In fondo alla
    # riga il cursore resta sull'ultima colonna e il testo successivo la
    # sovrascrive; un carattere di larghezza zero sull'ultima colonna viene
    # scartato (vedi {#offer_input}).
    #
    # @param text [String] testo UTF-8, senza caratteri di controllo tranne
    #   "\t" (diventa spazi fino alla tabulazione successiva)
    # @return [self]
    # @raise [WidgetError] se +ncreader_write_egc+ fallisce (per esempio un
    #   glifo largo che non entra nell'ultima colonna): il testo precedente
    #   resta scritto; se il piano del reader è stato modificato dall'esterno;
    #   se il cursore della vista non torna al suo posto
    #   (+ncplane_cursor_move_yx+ fallisce), prima della chiamata C
    # @raise [TypeError, ArgumentError] se text non è una String valida
    # @raise [ClosedError] se il reader è chiuso
    def write(text)
      ptr = prepare!
      str = Util.string!(text, 'text')
      raise ArgumentError, "text = #{text.inspect} contiene caratteri di controllo" if str.match?(/[\p{Cc}&&[^\t]]/)

      str.each_grapheme_cluster do |egc|
        Util.check!(put_egc(ptr, egc), WidgetError, "ncreader_write_egc(#{egc.inspect})")
      end
      self
    end

    # Testo del reader (+ncreader_contents+): le righe della vista, unite senza
    # separatori, saltando le celle vuote.
    #
    # @return [String]
    # @raise [WidgetError] se +ncreader_contents+ fallisce
    # @raise [ClosedError] se il reader è chiuso
    def contents
      Util.take_string(Util.check_ptr!(FFI.ncreader_contents(to_ptr), WidgetError, 'ncreader_contents'))
    end

    # Cancella il testo e riporta il cursore in (0, 0) (+ncreader_clear+),
    # senza ridisegnare né spostare il cursore del terminale.
    #
    # @return [self]
    # @raise [ClosedError] se il reader è chiuso
    def clear
      FFI.ncreader_clear(to_ptr)
      @cursor = @plane.cursor
      self
    end

    # Sposta il cursore di una colonna a sinistra (+ncreader_move_left+);
    # dalla colonna 0 va all'ultima colonna della riga sopra. Ridisegna.
    #
    # @return [Boolean] false se il cursore era in (0, 0)
    # @raise [WidgetError] se il piano del reader è stato modificato dall'esterno;
    #   o se il cursore della vista non torna al suo posto
    # @raise [ClosedError] se il reader è chiuso
    def move_left = moved?(FFI.ncreader_move_left(prepare!))

    # Sposta il cursore di una colonna a destra (+ncreader_move_right+),
    # anche su celle vuote; dall'ultima colonna va all'inizio della riga
    # sotto. Ridisegna.
    #
    # @return [Boolean] false se il cursore era sull'ultima colonna dell'ultima riga
    # @raise [WidgetError] se il piano del reader è stato modificato dall'esterno;
    #   o se il cursore della vista non torna al suo posto
    # @raise [ClosedError] se il reader è chiuso
    def move_right = moved?(FFI.ncreader_move_right(prepare!))

    # Sposta il cursore di una riga in alto, nella stessa colonna
    # (+ncreader_move_up+). Ridisegna.
    #
    # @return [Boolean] false se il cursore era sulla prima riga
    # @raise [WidgetError] se il piano del reader è stato modificato dall'esterno;
    #   o se il cursore della vista non torna al suo posto
    # @raise [ClosedError] se il reader è chiuso
    def move_up = moved?(FFI.ncreader_move_up(prepare!))

    # Sposta il cursore di una riga in basso, nella stessa colonna
    # (+ncreader_move_down+). Ridisegna.
    #
    # @return [Boolean] false se il cursore era sull'ultima riga
    # @raise [WidgetError] se il piano del reader è stato modificato dall'esterno;
    #   o se il cursore della vista non torna al suo posto
    # @raise [ClosedError] se il reader è chiuso
    def move_down = moved?(FFI.ncreader_move_down(prepare!))

    private

    # +ncreader_destroy+ con NULL al posto del char** del testo: il testo si
    # legge prima con {#contents}. Con cursor: true il C spegne il cursore.
    def destroy_native
      FFI.ncreader_destroy(to_ptr, nil)
      @context.cursor_state_unknown!
    end

    # Controlla la vista prima di un'operazione che il C ridisegna: stesse
    # dimensioni della copia nascosta, niente scrolling né autogrow, cursore
    # dove l'ha lasciato il reader (il C lo usa per proiettare la copia
    # nascosta: spostato, porta a leggere fuori dal piano, reader.c:134-136).
    #
    # @return [::FFI::Pointer] il puntatore del reader
    def prepare!
      ptr = to_ptr
      view = @plane.to_ptr
      if FFI.ncplane_dim_y(view) != @dims[0] || FFI.ncplane_dim_x(view) != @dims[1] ||
         FFI.ncplane_scrolling_p(view) || FFI.ncplane_autogrow_p(view)
        raise WidgetError, 'il piano del reader è stato ridimensionato o ha attivato scrolling o autogrow'
      end

      move_view_cursor!(*@cursor)
      @context.cursor_state_unknown! # il ridisegno del C accende il cursore del terminale
      ptr
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

    # Dopo il Backspace a inizio riga porta il cursore della vista, e quello
    # del terminale che il ridisegno del C ha lasciato in colonna 0, a fine
    # della riga y, dove il C ha portato la copia nascosta (reader.c:265).
    def wrap_backspace(y)
      x = @dims[1] - 1
      FFI.ncplane_cursor_move_yx(@plane.to_ptr, y, x)
      ay, ax = @plane.abs_yx
      FFI.notcurses_cursor_enable(@context.to_ptr, ay + y, ax + x) # come ncreader_redraw, esito ignorato
    end

    # Riporta il cursore della vista in (y, x): se fallisce, vista e copia
    # nascosta non sono più allineate e il C non va chiamato.
    def move_view_cursor!(y, x)
      Util.check!(FFI.ncplane_cursor_move_yx(@plane.to_ptr, y, x), WidgetError, "ncplane_cursor_move_yx(#{y}, #{x})")
    end

    # Esito di uno spostamento (-1 = nessuno spostamento possibile, non un errore).
    def moved?(rc)
      @cursor = @plane.cursor
      rc.zero?
    end
  end
end
