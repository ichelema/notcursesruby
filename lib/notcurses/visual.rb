# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Immagine o video (+struct ncvisual*+): una matrice di pixel RGBA (vedi
  # {Pixel}) da disegnare su un piano con {#blit}.
  #
  # Si crea da un file multimediale ({.open}, {.from_file}: tutto ciò che
  # ffmpeg sa aprire con uno stream video) o da pixel in memoria
  # ({.from_rgba}, {.from_bgra}, {.from_rgb_packed}, {.from_rgb_loose},
  # {.from_palidx}, {.from_sixel}, {.from_plane}). I costruttori copiano i
  # dati: la String sorgente si può riusare subito.
  #
  # Ciclo di vita. Serve un {Context} attivo: in notcurses 3.0.17 un ncvisual
  # creato senza contesto va in crash alla distruzione. Il visual appartiene al
  # contesto: {#close} lo distrugge, e {Context#close} (anche
  # {Context#drop_planes}) chiude i visual ancora aperti; da quel momento ogni
  # metodo solleva ClosedError. Il GC non distrugge mai un visual. Nessun piano
  # tiene un riferimento al visual: si può chiudere subito dopo {#blit}.
  #
  # Thread: notcurses non è thread-safe; usa il visual dal thread del contesto.
  #
  # @example
  #   Notcurses::Visual.open('foto.png') do |visual|
  #     plane = visual.blit(plane: nc.stdplane, child: true, scale: :scale)
  #     nc.render
  #     plane.close
  #   end
  class Visual
    include Resource

    # Allineamento delle righe che ffmpeg aggiunge allo stride interno
    # (+rowalign+ di src/media/ffmpeg.c).
    ROW_ALIGN = 64
    # Registri di colore del decoder sixel di notcurses (MAXCOLORS di sixel.h).
    SIXEL_COLORS = 65_535
    # Corpo di un sixel che il decoder di 3.0.17 legge senza uscire dai buffer.
    SIXEL_BODY = /\A(?>[?-~$-]|#\d{1,5}(?>;2;\d{1,3};\d{1,3};\d{1,3})?|!\d{1,9}[?-~])*\z/
    private_constant :ROW_ALIGN, :SIXEL_COLORS, :SIXEL_BODY

    # Geometria di un blit calcolata da notcurses (+ncvgeom+), copiata in un
    # oggetto immutabile. I campi in pixel si riferiscono all'immagine, quelli
    # in celle al piano.
    class Geometry
      # @return [Integer] righe dell'immagine, in pixel
      attr_reader :pixy
      # @return [Integer] colonne dell'immagine, in pixel
      attr_reader :pixx
      # @return [Integer] altezza di una cella in pixel (0 se il terminale non la comunica)
      attr_reader :cdimy
      # @return [Integer] larghezza di una cella in pixel (0 se il terminale non la comunica)
      attr_reader :cdimx
      # @return [Integer] righe disegnate, in pixel, dopo lo scaling
      attr_reader :rpixy
      # @return [Integer] colonne disegnate, in pixel, dopo lo scaling
      attr_reader :rpixx
      # @return [Integer] righe di celle occupate
      attr_reader :rcelly
      # @return [Integer] colonne di celle occupate
      attr_reader :rcellx
      # @return [Integer] pixel per cella in verticale con il blitter scelto
      attr_reader :scaley
      # @return [Integer] pixel per cella in orizzontale con il blitter scelto
      attr_reader :scalex
      # @return [Integer] prima riga della regione disegnata, in pixel
      attr_reader :begy
      # @return [Integer] prima colonna della regione disegnata, in pixel
      attr_reader :begx
      # @return [Integer] righe della regione disegnata, in pixel
      attr_reader :leny
      # @return [Integer] colonne della regione disegnata, in pixel
      attr_reader :lenx
      # @return [Integer] righe massime di una bitmap (blitter :pixel; altrimenti 0)
      attr_reader :maxpixely
      # @return [Integer] colonne massime di una bitmap (blitter :pixel; altrimenti 0)
      attr_reader :maxpixelx
      # @return [Symbol, Integer] blitter che notcurses userà (:ascii, :half, ...)
      attr_reader :blitter

      # @param geom [FFI::NcVgeom] struct compilata da +ncvisual_geom+
      # @raise [TypeError] se geom non è un FFI::NcVgeom
      def initialize(geom)
        raise TypeError, "geom deve essere Notcurses::FFI::NcVgeom, non #{geom.class}" unless geom.is_a?(FFI::NcVgeom)

        @pixy = geom[:pixy]
        @pixx = geom[:pixx]
        @cdimy = geom[:cdimy]
        @cdimx = geom[:cdimx]
        @rpixy = geom[:rpixy]
        @rpixx = geom[:rpixx]
        @rcelly = geom[:rcelly]
        @rcellx = geom[:rcellx]
        @scaley = geom[:scaley]
        @scalex = geom[:scalex]
        @begy = geom[:begy]
        @begx = geom[:begx]
        @leny = geom[:leny]
        @lenx = geom[:lenx]
        @maxpixely = geom[:maxpixely]
        @maxpixelx = geom[:maxpixelx]
        @blitter = Util.enum_symbol(Util::BLITTERS, geom[:blitter])
        freeze
      end

      # @return [Hash{Symbol => Integer, Symbol}] i campi, nell'ordine di +ncvgeom+
      def to_h
        { pixy: @pixy, pixx: @pixx, cdimy: @cdimy, cdimx: @cdimx, rpixy: @rpixy, rpixx: @rpixx,
          rcelly: @rcelly, rcellx: @rcellx, scaley: @scaley, scalex: @scalex, begy: @begy, begx: @begx,
          leny: @leny, lenx: @lenx, maxpixely: @maxpixely, maxpixelx: @maxpixelx, blitter: @blitter }
      end

      # @param other [Object] oggetto da confrontare
      # @return [Boolean]
      def ==(other) = other.is_a?(Geometry) && other.to_h == to_h
      alias eql? ==

      # @return [Integer]
      def hash = [Geometry, to_h].hash

      # @return [String]
      def inspect
        "#<Notcurses::Visual::Geometry #{@pixy}x#{@pixx} px -> #{@rcelly}x#{@rcellx} celle blitter=#{@blitter.inspect}>"
      end
    end

    # @return [Context] contesto a cui appartiene il visual
    attr_reader :context

    # Avvolge un ncvisual* appena creato e lo registra nel contesto, che lo
    # chiude prima di +notcurses_stop+. Di solito non serve chiamarlo: usa i
    # costruttori +from_*+.
    #
    # @api private
    # @param ptr [::FFI::Pointer] ncvisual* non NULL, di proprietà del chiamante
    # @param context [Context] il contesto attivo
    # @param file [Boolean] true se il visual viene da +ncvisual_from_file+
    # @raise [VisualError] se ptr è NULL
    def initialize(ptr, context, file: false)
      Util.check_ptr!(ptr, VisualError, 'ncvisual*')
      @ptr = ptr
      @context = context
      @owner = context
      @closed = false
      @file = file
      @in_use = [] # un oggetto per decode, decode_loop o stream in corso: rinviano ncvisual_destroy
      @claims = [] # richieste di ncvisual_destroy: la esegue solo la prima (release_native!)
      @destroyed = false
      context.adopt(self)
    end

    # --- costruttori ---

    # Apre un file multimediale, come {.from_file}; con un blocco passa il
    # visual al blocco e lo chiude alla fine, come File.open.
    #
    # @param path [String, #to_path] percorso del file
    # @yieldparam visual [Visual]
    # @return [Visual] il visual; con un blocco, il valore del blocco
    # @raise [VisualError] se +ncvisual_from_file+ restituisce NULL
    # @raise [TypeError, ArgumentError] se path non è un percorso valido
    # @raise [ClosedError] se non c'è un Context attivo
    def self.open(path, &block) = from_file(path, &block)

    # Carica un'immagine o un video e ne decodifica il primo frame
    # (+ncvisual_from_file+). Formati: tutto ciò che ffmpeg apre con uno stream
    # video (PNG, JPEG, GIF, MKV, ...).
    #
    # Thread: la chiamata C apre e legge il file con ffmpeg senza il GVL (una
    # FIFO, un URL o un file system lento non hanno limite di tempo): gli altri
    # thread Ruby girano, ma non devono usare lo stesso contesto finché la
    # chiamata non torna. La chiamata C non usa il contesto: un {Context#close}
    # durante la lettura (da un altro thread o dall'hook at_exit) ferma subito
    # notcurses, e al ritorno from_file distrugge il visual appena creato e
    # solleva ClosedError. Un'eccezione asincrona (Ctrl-C, Thread#raise,
    # Timeout, il kill di {FdPlane#close}) arriva al ritorno della chiamata C:
    # il visual creato dal C resta allocato, con il file aperto, fino alla fine
    # del processo.
    #
    # @param path [String, #to_path] percorso del file
    # @yieldparam visual [Visual] (facoltativo) il visual, chiuso alla fine del blocco
    # @return [Visual] il visual; con un blocco, il valore del blocco
    # @raise [VisualError] se il file non esiste, non è multimediale, non ha uno
    #   stream video, o se notcurses non ha ffmpeg (contesto aperto con core: true)
    # @raise [TypeError, ArgumentError] se path non è un percorso valido
    # @raise [ClosedError] se non c'è un Context attivo, o se il contesto viene
    #   chiuso durante la lettura
    def self.from_file(path, &block)
      ctx = Internal.context!
      file = Util.string!(File.path(path), 'path')
      raise ArgumentError, 'path è vuoto' if file.empty?

      # la chiamata C non usa il contesto: un close durante la lettura lo ferma subito
      ptr = FFI.ncvisual_from_file(file)
      if ptr.null?
        raise VisualError, "ncvisual_from_file(#{file.inspect}) ha restituito NULL (file inesistente, non " \
                           'multimediale o senza stream video? contesto aperto con core: true?)'
      end
      visual = Guard.run do
        ctx.to_ptr # contesto chiuso durante la lettura: il visual non ha più un contesto a cui appartenere
        new(ptr, ctx, file: true)
      rescue ClosedError
        FFI.ncvisual_destroy(ptr)
        raise
      end
      Util.with_resource(visual, &block)
    end

    # Visual da pixel RGBA (+ncvisual_from_rgba+): 4 byte per pixel, R, G, B,
    # A in quest'ordine (il formato di {Pixel}).
    #
    # Bug di 3.0.17 aggirati: il C accetta rowstride < cols * 4 lasciando pixel
    # non inizializzati (visual.c:784) e, senza ffmpeg, con rowstride >
    # cols * 4 scrive oltre il buffer (visual.c:768, 801). Il wrapper valida
    # rowstride e passa al C righe compatte.
    #
    # @param data [String] pixel, almeno rows * rowstride byte
    # @param rows [Integer] righe, >= 1
    # @param cols [Integer] colonne, >= 1
    # @param rowstride [Integer, nil] byte per riga in data, multiplo di 4 e
    #   >= cols * 4; nil = cols * 4
    # @yieldparam visual [Visual] (facoltativo) il visual, chiuso alla fine del blocco
    # @return [Visual] il visual; con un blocco, il valore del blocco
    # @raise [VisualError] se +ncvisual_from_rgba+ restituisce NULL
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ClosedError] se non c'è un Context attivo
    def self.from_rgba(data, rows:, cols:, rowstride: nil, &block)
      ctx = Internal.context!
      buf = Internal.pixel_buffer(data, rows, cols, 4, rowstride)
      wrap(ctx, FFI.ncvisual_from_rgba(buf, rows, cols * 4, cols), 'ncvisual_from_rgba', &block)
    end

    # Visual da pixel RGB compatti (+ncvisual_from_rgb_packed+): 3 byte per
    # pixel, R, G, B, con la stessa alpha per tutti.
    #
    # @param data [String] pixel, almeno rows * rowstride byte
    # @param rows [Integer] righe, >= 1
    # @param cols [Integer] colonne, >= 1
    # @param rowstride [Integer, nil] byte per riga, multiplo di 3 e >= cols * 3;
    #   nil = cols * 3
    # @param alpha [Integer] alpha dei pixel, 0..255 (il C, fuori intervallo,
    #   mette 0 senza errore)
    # @yieldparam visual [Visual] (facoltativo) il visual, chiuso alla fine del blocco
    # @return [Visual] il visual; con un blocco, il valore del blocco
    # @raise [VisualError] se +ncvisual_from_rgb_packed+ restituisce NULL
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ClosedError] se non c'è un Context attivo
    def self.from_rgb_packed(data, rows:, cols:, rowstride: nil, alpha: 255, &block)
      ctx = Internal.context!
      Util.uint8!(alpha, 'alpha')
      buf = Internal.pixel_buffer(data, rows, cols, 3, rowstride)
      wrap(ctx, FFI.ncvisual_from_rgb_packed(buf, rows, cols * 3, cols, alpha), 'ncvisual_from_rgb_packed', &block)
    end

    # Visual da pixel RGBx (+ncvisual_from_rgb_loose+): 4 byte per pixel, R, G,
    # B e un byte ignorato, sostituito da alpha.
    #
    # Bug di 3.0.17 aggirato: con rowstride maggiore dello stride interno il C
    # copia righe intere oltre il buffer (heap overflow, visual.c:884). Il
    # wrapper passa al C righe compatte.
    #
    # @param data [String] pixel, almeno rows * rowstride byte
    # @param rows [Integer] righe, >= 1
    # @param cols [Integer] colonne, >= 1
    # @param rowstride [Integer, nil] byte per riga, multiplo di 4 e >= cols * 4;
    #   nil = cols * 4
    # @param alpha [Integer] alpha dei pixel, 0..255 (il C, fuori intervallo,
    #   lascia il quarto byte di data)
    # @yieldparam visual [Visual] (facoltativo) il visual, chiuso alla fine del blocco
    # @return [Visual] il visual; con un blocco, il valore del blocco
    # @raise [VisualError] se +ncvisual_from_rgb_loose+ restituisce NULL
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ClosedError] se non c'è un Context attivo
    def self.from_rgb_loose(data, rows:, cols:, rowstride: nil, alpha: 255, &block)
      ctx = Internal.context!
      Util.uint8!(alpha, 'alpha')
      buf = Internal.pixel_buffer(data, rows, cols, 4, rowstride)
      wrap(ctx, FFI.ncvisual_from_rgb_loose(buf, rows, cols * 4, cols, alpha), 'ncvisual_from_rgb_loose', &block)
    end

    # Visual da pixel BGRA (+ncvisual_from_bgra+): 4 byte per pixel, B, G, R, A.
    #
    # @param data [String] pixel, almeno rows * rowstride byte
    # @param rows [Integer] righe, >= 1
    # @param cols [Integer] colonne, >= 1
    # @param rowstride [Integer, nil] byte per riga, multiplo di 4 e >= cols * 4;
    #   nil = cols * 4
    # @yieldparam visual [Visual] (facoltativo) il visual, chiuso alla fine del blocco
    # @return [Visual] il visual; con un blocco, il valore del blocco
    # @raise [VisualError] se +ncvisual_from_bgra+ restituisce NULL
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ClosedError] se non c'è un Context attivo
    def self.from_bgra(data, rows:, cols:, rowstride: nil, &block)
      ctx = Internal.context!
      buf = Internal.pixel_buffer(data, rows, cols, 4, rowstride)
      wrap(ctx, FFI.ncvisual_from_bgra(buf, rows, cols * 4, cols), 'ncvisual_from_bgra', &block)
    end

    # Visual da pixel indicizzati in una palette: ogni pixel occupa pstride byte
    # e il primo è l'indice.
    #
    # Bug di 3.0.17 aggirato: +ncvisual_from_palidx+ ignora i colori della
    # palette (visual.c:969): una voce con il colore di default diventa un
    # colore ricavato dall'indice e qualsiasi altra voce un pixel trasparente.
    # Il wrapper non lo chiama: costruisce in Ruby i pixel RGBA dalla palette e
    # crea il visual come {.from_rgba}. Ogni voce dà RGB = colore del canale e
    # alpha 0 se l'alpha del canale è +:transparent+, altrimenti 255 (blend e
    # highcontrast non hanno senso per un pixel: opaco); una voce con il colore
    # di default diventa il bianco 0xffffff. Costo proporzionale all'area.
    #
    # @param data [String] indici, almeno rows * rowstride byte
    # @param rows [Integer] righe, >= 1
    # @param cols [Integer] colonne, >= 1
    # @param palette [Array<Channel>] da 1 a 256 voci; ogni indice di data deve
    #   essere < palette.size
    # @param rowstride [Integer, nil] byte per riga, multiplo di pstride e >=
    #   cols * pstride; nil = cols * pstride
    # @param pstride [Integer] byte per pixel, >= 1
    # @yieldparam visual [Visual] (facoltativo) il visual, chiuso alla fine del blocco
    # @return [Visual] il visual; con un blocco, il valore del blocco
    # @raise [VisualError] se un indice di data è >= palette.size, o se
    #   +ncvisual_from_rgba+ restituisce NULL
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ClosedError] se non c'è un Context attivo
    def self.from_palidx(data, rows:, cols:, palette:, rowstride: nil, pstride: 1, &block)
      Internal.context!
      Util.integer!(pstride, 'pstride', 1..Util::INT32.max)
      raise TypeError, "palette deve essere Array di Notcurses::Channel, non #{palette.class}" unless palette.is_a?(Array)
      unless (1..FFI::NCPALETTESIZE).cover?(palette.size)
        raise ArgumentError, "palette ha #{palette.size} voci: ne servono da 1 a #{FFI::NCPALETTESIZE}"
      end

      colors = palette.each_with_index.map do |channel, i|
        raise TypeError, "palette[#{i}] deve essere Notcurses::Channel, non #{channel.class}" unless channel.is_a?(Channel)

        r, g, b = channel.default? ? [255, 255, 255] : channel.rgb
        [r, g, b, channel.alpha == :transparent ? 0 : 255].pack('C4')
      end
      buf = Internal.pixel_buffer(data, rows, cols, pstride, rowstride)
      indices = buf.get_bytes(0, rows * cols * pstride)
      rgba = Array.new(rows * cols) do |i|
        index = indices.getbyte(i * pstride)
        colors.fetch(index) { raise VisualError, "indice #{index} di data >= palette.size (#{colors.size})" }
      end.join
      from_rgba(rgba, rows: rows, cols: cols, &block)
    end

    # Visual dal contenuto di un piano (+ncvisual_from_plane+): ogni cella
    # diventa i pixel del blitter (per esempio 2 righe per cella con :half). Le
    # celle devono contenere solo spazi o i blocchi del blitter. Senza
    # argomenti converte tutto il piano, come {Plane#as_rgba}.
    #
    # @param plane [Plane]
    # @param blitter [Symbol, Integer] blitter con cui leggere le celle (:ascii,
    #   :half, ...; non :default né :pixel). :four_by_one e :eight_by_one
    #   (solo per i plot) sollevano ArgumentError
    # @param y [Integer, nil] riga di partenza, >= 0; nil = riga del cursore
    # @param x [Integer, nil] colonna di partenza, >= 0; nil = colonna del cursore
    # @param rows [Integer, nil] righe, >= 1; nil = fino al bordo
    # @param cols [Integer, nil] colonne, >= 1; nil = fino al bordo
    # @yieldparam visual [Visual] (facoltativo) il visual, chiuso alla fine del blocco
    # @return [Visual] il visual; con un blocco, il valore del blocco
    # @raise [VisualError] se il C restituisce NULL: blitter :default, :pixel o
    #   non disponibile, regione fuori dal piano, celle con altri glifi o mai scritte
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ClosedError] se il piano è chiuso
    def self.from_plane(plane, blitter:, y: 0, x: 0, rows: nil, cols: nil, &block)
      Guard.run do
        raise TypeError, "plane deve essere Notcurses::Plane, non #{plane.class}" unless plane.is_a?(Plane)

        begy, begx, leny, lenx = Util.c_region(y, x, rows, cols)
        ptr = FFI.ncvisual_from_plane(plane.to_ptr, Util.image_blitter_value(blitter), begy, begx, leny, lenx)
        wrap(plane.context, ptr, 'ncvisual_from_plane (blitter :default o :pixel? regione fuori dal piano? celle ' \
                                 'con glifi diversi da spazi e blocchi?)', &block)
      end
    end

    # Visual da una sequenza sixel (+ncvisual_from_sixel+), per esempio
    # "\ePq#0;2;100;0;0#0~~\e\\".
    #
    # Il decoder di 3.0.17 scrive o legge fuori dai buffer con indici di colore
    # >= 65535, definizioni di colore troncate, "!" senza cifre e, se rows non è
    # un multiplo di 6, con le righe dell'ultima banda oltre rows (sixel.h:131,
    # 167, 180). Il wrapper controlla la sequenza prima della chiamata e accetta
    # solo ciò che il decoder legge in sicurezza: "#n" (n < 65535) con una
    # definizione ";2;r;g;b" facoltativa, dati "?".."~", "!n" seguito da un
    # dato, "$" e "-", fino al primo ESC; l'intestazione prima del primo "#" o
    # "-" viene saltata. Con rows non multiplo di 6 decodifica le bande intere
    # e ritaglia.
    #
    # @param sixel [String] la sequenza
    # @param rows [Integer] righe dell'immagine, >= 1
    # @param cols [Integer] colonne dell'immagine, >= 1
    # @yieldparam visual [Visual] (facoltativo) il visual, chiuso alla fine del blocco
    # @return [Visual] il visual; con un blocco, il valore del blocco
    # @raise [ArgumentError] se la sequenza non rispetta la sintassi accettata
    # @raise [VisualError] se il decoder la rifiuta (per esempio dati oltre rows
    #   o cols)
    # @raise [TypeError] se un argomento ha il tipo sbagliato
    # @raise [ClosedError] se non c'è un Context attivo
    def self.from_sixel(sixel, rows:, cols:, &block)
      ctx = Internal.context!
      text = Util.string!(sixel, 'sixel')
      Internal.dims!(rows, cols)
      tall = (rows + 5) / 6 * 6
      Internal.dims!(tall, cols)
      Internal.sixel_check!(text)
      ptr = Util.check_ptr!(FFI.ncvisual_from_sixel(text, tall, cols), VisualError, 'ncvisual_from_sixel')
      unless tall == rows
        begin
          cropped = Internal.crop(ptr, 0, 0, rows, cols)
        ensure
          FFI.ncvisual_destroy(ptr)
        end
        ptr = cropped
      end
      wrap(ctx, ptr, 'ncvisual_from_sixel', &block)
    end

    # --- funzioni senza visual ---

    # Blitter che notcurses sceglie per i media con blitter: :default
    # (+ncvisual_media_defblitter+).
    #
    # @param scale [Symbol] :none, :scale, :stretch, :none_hires, :scale_hires
    # @return [Symbol] per esempio :half
    # @raise [ArgumentError] se scale non è valido
    # @raise [ClosedError] se non c'è un Context attivo
    def self.media_default_blitter(scale: :none)
      Guard.run do
        ctx = Internal.context!
        Util.enum_symbol(Util::BLITTERS, FFI.ncvisual_media_defblitter(ctx.to_ptr, Util.scale_value(scale)))
      end
    end

    # Disegna pixel RGBA su un piano senza creare un Visual (+ncblit_rgba+).
    #
    # Glifi larghi (ICH-486): il C scrive ogni cella da sola, e un blit su una
    # metà di un glifo largo lascerebbe l'altra metà orfana. Il wrapper svuota
    # l'altra metà, che diventa una cella vuota, come {Plane#polyfill}. Il
    # controllo legge solo i glifi a cavallo dei lati del rettangolo del blit
    # (ICH-549): il costo è proporzionale alle righe del blit. Con :braille,
    # che non tocca le celle con soli pixel trasparenti, legge anche i glifi
    # dentro il rettangolo: il costo è proporzionale all'area del blit.
    #
    # @param data [String] pixel R, G, B, A; almeno rows * rowstride byte
    # @param plane [Plane] piano su cui disegnare (non se ne crea uno nuovo)
    # @param rows [Integer] righe dell'immagine, >= 1
    # @param cols [Integer] colonne dell'immagine, >= 1
    # @param rowstride [Integer, nil] byte per riga, multiplo di 4 e >= cols * 4;
    #   nil = cols * 4
    # @param options [Hash] y:, x:, scale:, blitter:, pxoffy:, pxoffx:,
    #   no_degrade:, blend:, no_interpolate:, transcolor:, come in {#blit}
    # @return [Plane] plane
    # @raise [VisualError] se +ncblit_rgba+ fallisce
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ClosedError] se il piano è chiuso
    def self.blit_rgba(data, plane:, rows:, cols:, rowstride: nil, **options)
      buf = Internal.pixel_buffer(data, rows, cols, 4, rowstride)
      blit_buffer(plane, rows, cols, 'ncblit_rgba', options, pixels: buf) { |vopts| FFI.ncblit_rgba(buf, cols * 4, vopts) }
    end

    # Disegna pixel BGRx su un piano (+ncblit_bgrx+): 4 byte per pixel, B, G,
    # R e un byte ignorato; i pixel sono opachi.
    #
    # Glifi larghi: come in {.blit_rgba}.
    #
    # @param data [String] pixel, almeno rows * rowstride byte
    # @param plane [Plane] piano su cui disegnare
    # @param rows [Integer] righe, >= 1
    # @param cols [Integer] colonne, >= 1
    # @param rowstride [Integer, nil] byte per riga, multiplo di 4 e >= cols * 4;
    #   nil = cols * 4
    # @param options [Hash] come in {.blit_rgba}
    # @return [Plane] plane
    # @raise [VisualError] se +ncblit_bgrx+ fallisce
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ClosedError] se il piano è chiuso
    def self.blit_bgrx(data, plane:, rows:, cols:, rowstride: nil, **options)
      buf = Internal.pixel_buffer(data, rows, cols, 4, rowstride)
      blit_buffer(plane, rows, cols, 'ncblit_bgrx', options, pixels: buf) { |vopts| FFI.ncblit_bgrx(buf, cols * 4, vopts) }
    end

    # Disegna pixel RGBx su un piano (+ncblit_rgb_loose+): 4 byte per pixel,
    # R, G, B e un byte ignorato, sostituito da alpha.
    #
    # Glifi larghi: come in {.blit_rgba}.
    #
    # @param data [String] pixel, almeno rows * rowstride byte
    # @param plane [Plane] piano su cui disegnare
    # @param rows [Integer] righe, >= 1
    # @param cols [Integer] colonne, >= 1
    # @param rowstride [Integer, nil] byte per riga, multiplo di 4 e >= cols * 4;
    #   nil = cols * 4
    # @param alpha [Integer] alpha dei pixel, 0..255
    # @param options [Hash] come in {.blit_rgba}
    # @return [Plane] plane
    # @raise [VisualError] se +ncblit_rgb_loose+ fallisce
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ClosedError] se il piano è chiuso
    def self.blit_rgb_loose(data, plane:, rows:, cols:, rowstride: nil, alpha: 255, **options)
      Util.uint8!(alpha, 'alpha')
      buf = Internal.pixel_buffer(data, rows, cols, 4, rowstride)
      blit_buffer(plane, rows, cols, 'ncblit_rgb_loose', options, pixels: buf) do |vopts|
        FFI.ncblit_rgb_loose(buf, cols * 4, vopts, alpha)
      end
    end

    # Disegna pixel RGB compatti su un piano: 3 byte per pixel, R, G, B.
    #
    # Bug di 3.0.17 aggirato: +ncblit_rgb_packed+ legge i pixel con passo di 1
    # byte invece di 3 (visual.c:494) e disegna colori sbagliati. Il wrapper non
    # la usa: crea un visual temporaneo con +ncvisual_from_rgb_packed+, che è
    # corretta, e lo disegna con +ncvisual_blit+.
    #
    # Glifi larghi: come in {.blit_rgba}.
    #
    # @param data [String] pixel, almeno rows * rowstride byte
    # @param plane [Plane] piano su cui disegnare
    # @param rows [Integer] righe, >= 1
    # @param cols [Integer] colonne, >= 1
    # @param rowstride [Integer, nil] byte per riga, multiplo di 3 e >= cols * 3;
    #   nil = cols * 3
    # @param alpha [Integer] alpha dei pixel, 0..255
    # @param options [Hash] come in {.blit_rgba}
    # @return [Plane] plane
    # @raise [VisualError] se il visual temporaneo o +ncvisual_blit+ falliscono
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ClosedError] se il piano è chiuso
    def self.blit_rgb_packed(data, plane:, rows:, cols:, rowstride: nil, alpha: 255, **options)
      Guard.run do
        raise TypeError, "plane deve essere Notcurses::Plane, non #{plane.class}" unless plane.is_a?(Plane)

        from_rgb_packed(data, rows: rows, cols: cols, rowstride: rowstride, alpha: alpha) do |visual|
          blit_buffer(plane, rows, cols, 'ncvisual_blit', options, visual: visual.to_ptr) do |vopts|
            FFI.ncvisual_blit(plane.context.to_ptr, visual.to_ptr, vopts).null? ? -1 : 0
          end
        end
      end
    end

    # @param ctx [Context] contesto proprietario
    # @param ptr [::FFI::Pointer] puntatore restituito dal C
    # @param what [String] nome della funzione C, per il messaggio d'errore
    # @return [Visual] il visual creato; con un blocco, il valore del blocco
    # @raise [VisualError] se ptr è NULL
    def self.wrap(ctx, ptr, what, &block)
      raise VisualError, "#{what} ha restituito NULL" if ptr.null?

      Util.with_resource(new(ptr, ctx), &block)
    end

    # Esegue una ncblit_* sul piano: leny/lenx = l'immagine intera. Il
    # rettangolo del blit si calcola su visual, o senza visual su un ncvisual
    # temporaneo con i byte di pixels: conta solo la sua dimensione, uguale a
    # quella del ncvisual che la ncblit_* crea nel C (blit.c:1463).
    # @param plane [Plane] piano su cui disegnare
    # @param rows [Integer] righe dell'immagine
    # @param cols [Integer] colonne dell'immagine
    # @param what [String] nome della funzione C, per il messaggio d'errore
    # @param options [Hash] come in {.blit_rgba}
    # @param pixels [::FFI::Pointer, nil] rows * cols pixel di 4 byte
    # @param visual [::FFI::Pointer, nil] ncvisual* che il blocco disegna
    # @return [Plane] plane
    # @raise [TypeError] se plane non è un Plane
    # @raise [VisualError] se la funzione C fallisce
    def self.blit_buffer(plane, rows, cols, what, options, pixels: nil, visual: nil)
      raise TypeError, "plane deve essere Notcurses::Plane, non #{plane.class}" unless plane.is_a?(Plane)

      Guard.run do
        ctx = plane.context
        vopts = Internal.options(ctx, plane, **options)
        vopts[:leny] = rows
        vopts[:lenx] = cols
        src = visual || FFI.ncvisual_from_rgba(pixels, rows, cols * 4, cols)
        raise VisualError, "#{what}: ncvisual_from_rgba ha restituito NULL" if src.null?

        rc = begin
          Internal.keeping_glyphs_whole(ctx, plane, src, vopts) { yield vopts }
        ensure
          FFI.ncvisual_destroy(src) unless visual
        end
        ctx.raise_callback_errors!
        Util.check!(rc, VisualError, what)
        plane
      end
    end
    private_class_method :wrap, :blit_buffer

    # --- ciclo di vita ---

    # Distrugge il visual (+ncvisual_destroy+). Idempotente. I piani su cui è
    # stato disegnato non cambiano.
    #
    # Durante {#decode}, {#decode_loop} o {#stream} sul visual in un altro
    # thread, o durante un'operazione del wrapper che un gestore +trap+ ha
    # interrotto nel thread corrente (per esempio {#dims} o {#blit}), il
    # visual risulta subito chiuso, e +ncvisual_destroy+ avviene alla fine
    # dell'operazione, nel suo thread. Le operazioni in corso in altri thread
    # su altri oggetti non rinviano la distruzione. Dopo un'eccezione
    # asincrona arrivata prima della distruzione, un close successivo (o il
    # close del contesto) la esegue.
    #
    # @return [nil]
    # @raise [VisualError] dentro un callback chiamato da notcurses nel thread
    #   corrente (per esempio il blocco di {#stream}, mentre il C usa il visual)
    def close
      return nil if @destroyed

      unless @closed
        ctx = @context
        ctx.check_not_in_callback!('Visual#close', VisualError) if ctx.in_callback?
        @closed = true # prima di leggere le operazioni in corso
      end
      return nil unless @in_use.empty? # lo distrugge visual_guard all'uscita

      Guard.running_here? ? Guard.defer(self) : release_native!
      nil
    end
    alias destroy close

    # +ncvisual_destroy+, una sola volta: da {#close}, all'uscita di
    # visual_guard o dalla coda di {Guard}. Non fa niente durante {#decode},
    # {#decode_loop} o {#stream}: lo ripete visual_guard alla loro uscita.
    #
    # @api private
    # @return [nil]
    def release_native!
      return nil if @destroyed || !@in_use.empty?

      claim = Object.new
      destroying = false
      begin
        # una sola esecuzione: come in Context#release_native!
        @claims << claim
        return nil unless @claims.first.equal?(claim)

        # prima della chiamata: Ruby consegna un'eccezione asincrona al suo ritorno, a visual già liberato
        @destroyed = destroying = true
        FFI.ncvisual_destroy(@ptr)
      ensure
        @claims.clear if !destroying && @claims.first.equal?(claim) # interrotta prima: un close la ripete
      end
      @context.disown(self)
      nil
    end

    # --- geometria ---

    # Dimensioni dell'immagine in pixel (+ncvisual_geom+ senza contesto).
    #
    # @return [Array(Integer, Integer)] [righe, colonne]
    # @raise [VisualError] se +ncvisual_geom+ fallisce
    # @raise [ClosedError] se il visual è chiuso
    def dims
      Guard.run do
        geom = FFI::NcVgeom.new
        Util.check!(FFI.ncvisual_geom(nil, to_ptr, nil, geom), VisualError, 'ncvisual_geom')
        [geom[:pixy], geom[:pixx]]
      end
    end

    # Geometria che avrebbe {#blit} con le stesse opzioni (+ncvisual_geom+):
    # blitter scelto, dimensioni dopo lo scaling, celle occupate. Non disegna.
    # Con una regione il wrapper la calcola, come {#blit}, sulla copia della
    # regione; pixy, pixx, begy e begx restano quelli del visual.
    #
    # @param plane [Plane, nil] come in {#blit}
    # @param child [Boolean] come in {#blit}
    # @param begy [Integer] come in {#blit}
    # @param begx [Integer] come in {#blit}
    # @param leny [Integer] come in {#blit}
    # @param lenx [Integer] come in {#blit}
    # @param options [Hash] le altre opzioni di {#blit}
    # @return [Geometry]
    # @raise [VisualError] se +ncvisual_geom+ fallisce (per esempio blitter non
    #   disponibile con no_degrade: true)
    # @raise [TypeError, ArgumentError] se un'opzione non è valida
    # @raise [ClosedError] se il visual, il piano o il contesto sono chiusi
    def geometry(plane: nil, child: false, begy: 0, begx: 0, leny: 0, lenx: 0, **options)
      Guard.run do
        ctx = @context
        vopts = Internal.options(ctx, plane, **options)
        Internal.child!(vopts, plane, child)
        geom = FFI::NcVgeom.new
        rc = with_region(begy, begx, leny, lenx) do |src, original|
          r = FFI.ncvisual_geom(ctx.to_ptr, src, vopts, geom)
          geom[:pixy], geom[:pixx], geom[:begy], geom[:begx] = original if original
          r
        end
        Util.check!(rc, VisualError, 'ncvisual_geom')
        Geometry.new(geom)
      end
    end

    # --- frame ---

    # Decodifica il frame successivo (+ncvisual_decode+): i pixel del visual
    # diventano quelli del nuovo frame. {.from_file} ha già decodificato il
    # primo; un'immagine ha un solo frame.
    #
    # Thread: la chiamata C legge il file senza il GVL, come in {.from_file}:
    # gli altri thread Ruby girano, ma non devono usare lo stesso contesto
    # finché la chiamata non torna. La chiamata C usa solo il visual: un close
    # del contesto durante la chiamata (da un altro thread, dall'hook at_exit o
    # alla fine del blocco di {Context.open}) ferma subito notcurses; un close
    # del contesto o del visual lascia il visual in uso fino al ritorno della
    # chiamata, che lo distrugge. La chiamata in corso finisce, la successiva
    # solleva ClosedError. Il close non interrompe la chiamata C: una lettura
    # bloccata (per esempio da una FIFO) tiene il visual fino al suo ritorno,
    # e all'uscita del processo Ruby attende il thread.
    #
    # @return [Boolean] true se c'è un nuovo frame, false a fine stream (il
    #   visual conserva l'ultimo frame; il C restituisce 1, che non è un errore)
    # @raise [VisualError] se il visual non viene da un file o se la
    #   decodifica fallisce
    # @raise [ClosedError] se il visual è chiuso
    def decode
      visual_guard do
        rc = FFI.ncvisual_decode(to_ptr)
        raise VisualError, 'ncvisual_decode fallita (il visual non viene da un file?)' if rc.negative?

        rc.zero?
      end
    end

    # Come {#decode}, ma a fine stream riparte dal primo frame
    # (+ncvisual_decode_loop+). Come {#decode}, la chiamata C legge il file
    # senza il GVL: gli altri thread Ruby girano, ma non devono usare lo stesso
    # contesto finché la chiamata non torna. Un close del visual o del
    # contesto durante la chiamata si comporta come in {#decode}.
    #
    # @return [Boolean] true se c'è il frame successivo, false se è ripartito
    #   dall'inizio (il visual contiene il primo frame)
    # @raise [VisualError] se il visual non viene da un file o se la
    #   decodifica o il riavvolgimento falliscono
    # @raise [ClosedError] se il visual è chiuso
    def decode_loop
      visual_guard do
        rc = FFI.ncvisual_decode_loop(to_ptr)
        raise VisualError, 'ncvisual_decode_loop fallita (il visual non viene da un file?)' if rc.negative?

        rc.zero?
      end
    end

    # --- trasformazioni ---

    # Ruota il visual, come +ncvisual_rotate+; le dimensioni si adattano
    # all'immagine ruotata (solo i pixel diversi da 0 contano: i bordi
    # trasparenti vengono tagliati). notcurses garantisce solo ±π/2.
    #
    # Bug di 3.0.17 aggirati: +ncvisual_rotate+ perde la prima riga e la prima
    # colonna di pixel a qualsiasi angolo, anche 0 (visual.c:746 confronta con
    # +>+ invece di +>=+), e le immagini di una sola riga o colonna diventano
    # trasparenti. Con bordi trasparenti diversi sui lati perde anche pixel
    # opachi: ruota il riquadro dei pixel opachi attorno al suo centro e i
    # pixel attorno al centro dell'immagine (visual.c:658-705). Il wrapper non
    # lo chiama: ripete in Ruby l'algoritmo del C con il confronto corretto e
    # con il riquadro ruotato attorno al centro dell'immagine. Ai multipli di
    # π/2 nessun pixel opaco si perde. Le dimensioni seguono il riquadro vero
    # dei pixel diversi da 0: +ncvisual_bounding_box+ del C (visual.c:537-628)
    # a volte lo calcola più stretto (due pixel sulla diagonale di un 2x2 danno
    # una sola colonna), e in quei casi le dimensioni sono diverse da quelle
    # del C. Il wrapper legge ogni pixel con +ncvisual_at_yx+, porta il visual alle
    # dimensioni nuove con +ncvisual_resize_noninterpolative+ e riscrive ogni
    # pixel con +ncvisual_set_yx+. Il costo è proporzionale all'area, con una
    # chiamata C per pixel.
    #
    # @param radians [Numeric] angolo; positivo = senso antiorario
    # @return [self]
    # @raise [VisualError] se la rotazione fallisce (per esempio nessun pixel
    #   opaco)
    # @raise [TypeError, ArgumentError] se radians non è un numero finito
    # @raise [ClosedError] se il visual è chiuso
    def rotate(radians)
      Guard.run do
        ptr = to_ptr
        rads = Util.float!(radians, 'radians')
        rows, cols = dims
        pixels = Internal.read_pixels(ptr, rows, cols)
        rotated = Internal.rotate_pixels(pixels, rows, cols, rads)
        raise VisualError, 'ncvisual_rotate fallita (nessun pixel opaco?)' if rotated.nil?

        data, new_rows, new_cols = rotated
        Internal.dims!(new_rows, new_cols)
        Util.check!(FFI.ncvisual_resize_noninterpolative(ptr, new_rows, new_cols), VisualError,
                    "ncvisual_resize_noninterpolative(#{new_rows}, #{new_cols})")
        Internal.write_pixels(ptr, data, new_cols)
        self
      end
    end

    # Ridimensiona l'immagine con interpolazione (+ncvisual_resize+; senza
    # ffmpeg come {#resize_noninterpolative}).
    #
    # @param rows [Integer] nuove righe in pixel, >= 1
    # @param cols [Integer] nuove colonne in pixel, >= 1
    # @return [self]
    # @raise [VisualError] se il resize fallisce
    # @raise [TypeError, ArgumentError] se rows o cols non sono validi
    # @raise [ClosedError] se il visual è chiuso
    def resize(rows, cols)
      Guard.run do
        Internal.dims!(rows, cols)
        Util.check!(FFI.ncvisual_resize(to_ptr, rows, cols), VisualError, "ncvisual_resize(#{rows}, #{cols})")
        self
      end
    end

    # Ridimensiona l'immagine senza interpolazione, senza colori nuovi
    # (+ncvisual_resize_noninterpolative+). Il wrapper rifiuta 0 righe o
    # colonne, che il C di 3.0.17 accetta producendo un visual vuoto.
    #
    # @param rows [Integer] nuove righe in pixel, >= 1
    # @param cols [Integer] nuove colonne in pixel, >= 1
    # @return [self]
    # @raise [VisualError] se il resize fallisce
    # @raise [TypeError, ArgumentError] se rows o cols non sono validi
    # @raise [ClosedError] se il visual è chiuso
    def resize_noninterpolative(rows, cols)
      Guard.run do
        Internal.dims!(rows, cols)
        rc = FFI.ncvisual_resize_noninterpolative(to_ptr, rows, cols)
        Util.check!(rc, VisualError, "ncvisual_resize_noninterpolative(#{rows}, #{cols})")
        self
      end
    end

    # Riempimento a macchia d'olio (+ncvisual_polyfill_yx+): il pixel (y, x) e
    # quelli collegati (in 4 direzioni) che hanno il suo stesso valore
    # diventano pixel.
    #
    # @param y [Integer] riga, 0...righe
    # @param x [Integer] colonna, 0...colonne
    # @param pixel [Pixel, Integer] nuovo valore (Integer: il valore a 32 bit di {Pixel})
    # @return [Integer] pixel cambiati (0 se (y, x) vale già pixel)
    # @raise [VisualError] se il riempimento fallisce (memoria)
    # @raise [TypeError, ArgumentError] se un argomento non è valido o (y, x) è
    #   fuori dal visual
    # @raise [ClosedError] se il visual è chiuso
    def polyfill(y, x, pixel)
      Guard.run do
        value = Internal.pixel_value(pixel)
        point!(y, x)
        Util.check!(FFI.ncvisual_polyfill_yx(to_ptr, y, x, value), VisualError, 'ncvisual_polyfill_yx')
      end
    end

    # Pixel in (y, x) (+ncvisual_at_yx+).
    #
    # @param y [Integer] riga, 0...righe
    # @param x [Integer] colonna, 0...colonne
    # @return [Pixel]
    # @raise [TypeError, ArgumentError] se un argomento non è valido o (y, x) è
    #   fuori dal visual
    # @raise [VisualError] se +ncvisual_at_yx+ fallisce
    # @raise [ClosedError] se il visual è chiuso
    def at(y, x)
      Guard.run do
        point!(y, x)
        out = ::FFI::MemoryPointer.new(:uint32)
        Util.check!(FFI.ncvisual_at_yx(to_ptr, y, x, out), VisualError, 'ncvisual_at_yx')
        Pixel.new(value: out.read_uint32)
      end
    end

    # Cambia il pixel in (y, x) (+ncvisual_set_yx+).
    #
    # @param y [Integer] riga, 0...righe
    # @param x [Integer] colonna, 0...colonne
    # @param pixel [Pixel, Integer] nuovo valore (Integer: il valore a 32 bit di {Pixel})
    # @return [self]
    # @raise [TypeError, ArgumentError] se un argomento non è valido o (y, x) è
    #   fuori dal visual
    # @raise [VisualError] se +ncvisual_set_yx+ fallisce
    # @raise [ClosedError] se il visual è chiuso
    def set(y, x, pixel)
      Guard.run do
        value = Internal.pixel_value(pixel)
        point!(y, x)
        Util.check!(FFI.ncvisual_set_yx(to_ptr, y, x, value), VisualError, 'ncvisual_set_yx')
        self
      end
    end

    # --- disegno ---

    # Disegna il visual (+ncvisual_blit+). Destinazione:
    # - plane: nil: un piano nuovo, radice di una nuova pila (che
    #   {Context#render} non disegna: usa {Plane#render_pile});
    # - plane: p: disegna in p, con y e x posizione nel piano;
    # - plane: p, child: true: un piano nuovo figlio di p, grande quanto
    #   l'immagine, con y e x posizione nel genitore.
    # Il piano nuovo è del chiamante: chiudilo con {Plane#close}.
    #
    # Glifi larghi: con plane: p, senza child:, come in {.blit_rgba}. Con un
    # blitter che diventa :pixel (ICH-550) il C non scrive celle: i glifi larghi
    # sotto il bitmap restano interi nel piano, e tornano visibili quando un
    # resize toglie il bitmap.
    #
    # Bug di 3.0.17 aggirato: con una regione diversa dall'immagine intera il C
    # ridimensiona dall'inizio dei dati ignorando begy/begx, poi legge oltre il
    # buffer ridimensionato (ffmpeg.c:586); con no_interpolate o senza ffmpeg la
    # regione viene ignorata. Il wrapper copia la regione in un visual
    # temporaneo, pixel per pixel (costo proporzionale all'area), e disegna quello.
    #
    # @param plane [Plane, nil] piano di destinazione, o il genitore con child: true
    # @param child [Boolean] NCVISUAL_OPTION_CHILDPLANE: crea un figlio di plane
    # @param begy [Integer] prima riga della regione, in pixel, >= 0
    # @param begx [Integer] prima colonna della regione, in pixel, >= 0
    # @param leny [Integer] righe della regione, 0 = fino al bordo
    # @param lenx [Integer] colonne della regione, 0 = fino al bordo
    # @param options [Hash] le opzioni seguenti
    # @option options [Integer, Symbol] :y (0) riga, oppure :top, :center,
    #   :bottom (NCVISUAL_OPTION_VERALIGNED; richiede plane:)
    # @option options [Integer, Symbol] :x (0) colonna, oppure :left, :center,
    #   :right (NCVISUAL_OPTION_HORALIGNED; richiede plane:)
    # @option options [Symbol] :scale (:none) :none, :scale, :stretch,
    #   :none_hires, :scale_hires
    # @option options [Symbol] :blitter (:default) :default, :ascii, :half,
    #   :quad, :sextant, :octant, :braille, :pixel; :four_by_one e
    #   :eight_by_one (solo per i plot) sollevano ArgumentError
    # @option options [Integer] :pxoffy (0) offset verticale in pixel nella
    #   prima cella (solo :pixel)
    # @option options [Integer] :pxoffx (0) offset orizzontale in pixel nella
    #   prima cella (solo :pixel)
    # @option options [Boolean] :no_degrade (false) NCVISUAL_OPTION_NODEGRADE:
    #   errore invece di ripiegare su un blitter più semplice
    # @option options [Boolean] :blend (false) NCVISUAL_OPTION_BLEND: colori in
    #   NCALPHA_BLEND
    # @option options [Boolean] :no_interpolate (false)
    #   NCVISUAL_OPTION_NOINTERPOLATE: scaling senza interpolazione
    # @option options [Integer, nil] :transcolor (nil) colore 0xRRGGBB da
    #   rendere trasparente (NCVISUAL_OPTION_ADDALPHA)
    # @return [Plane] plane, oppure il piano nuovo
    # @raise [VisualError] se +ncvisual_blit+ restituisce NULL (blitter non
    #   disponibile con no_degrade: true, :pixel sullo stdplane senza child:,
    #   pxoffy/pxoffx con un blitter di celle, ...)
    # @raise [Exception] l'eccezione di un callback Ruby di resize (il blitter
    #   :pixel ridimensiona il piano)
    # @raise [TypeError, ArgumentError] se un'opzione non è valida (anche una
    #   regione fuori dal visual, child: true o y:/x: simbolici senza plane:)
    # @raise [ClosedError] se il visual, il piano o il contesto sono chiusi
    def blit(plane: nil, child: false, begy: 0, begx: 0, leny: 0, lenx: 0, **options)
      Guard.run do
        ctx = @context
        vopts = Internal.options(ctx, plane, **options)
        Internal.child!(vopts, plane, child)
        created = plane.nil? || child
        ptr = with_region(begy, begx, leny, lenx) do |src, _|
          draw = -> { FFI.ncvisual_blit(ctx.to_ptr, src, vopts) }
          created ? draw.call : Internal.keeping_glyphs_whole(ctx, plane, src, vopts, &draw)
        end
        if ptr.null?
          ctx.planes_destroyed! if created # il C distrugge il piano che aveva creato
          ctx.raise_callback_errors!
          raise VisualError, 'ncvisual_blit ha restituito NULL (blitter non disponibile con no_degrade? :pixel ' \
                             'sullo stdplane? pxoffy/pxoffx con un blitter di celle?)'
        end
        result = created ? Plane.new(ptr, owned: true, context: ctx) : plane
        ctx.raise_callback_errors!
        result
      end
    end

    # Crea un piano e ci disegna il visual (+ncvisualplane_create+): come
    # {Plane#create_child} sul genitore (o {Context#create_pile} senza parent:)
    # seguito da {#blit} nel piano nuovo, che viene distrutto se il blit
    # fallisce. L'immagine parte dall'angolo del piano. Il piano è del chiamante.
    #
    # @param rows [Integer, nil] righe del piano, >= 1 (omesso con margins:)
    # @param cols [Integer, nil] colonne del piano, >= 1 (omesso con margins:)
    # @param parent [Plane, nil] genitore; nil = radice di una nuova pila
    # @param y [Integer, Symbol] riga del piano; simboli come in
    #   {Plane#create_child}, solo con parent:
    # @param x [Integer, Symbol] colonna del piano; simboli solo con parent:
    # @param margins [Array(Integer, Integer, Integer, Integer), nil] come in {Plane#create_child}
    # @param name [String, nil] nome del piano
    # @param fixed [Boolean] come in {Plane#create_child}
    # @param autogrow [Boolean] come in {Plane#create_child}
    # @param vscroll [Boolean] come in {Plane#create_child}
    # @param resize [Symbol, #call, nil] callback di resize, come in {Plane#create_child}
    # @param begy [Integer] regione, come in {#blit}
    # @param begx [Integer] regione, come in {#blit}
    # @param leny [Integer] regione, come in {#blit}
    # @param lenx [Integer] regione, come in {#blit}
    # @param options [Hash] scale:, blitter:, pxoffy:, pxoffx:, no_degrade:,
    #   blend:, no_interpolate:, transcolor:, come in {#blit}
    # @yieldparam plane [Plane] (facoltativo) il piano, distrutto alla fine del blocco
    # @return [Plane] il piano; con un blocco, il valore del blocco
    # @raise [VisualError] se la creazione del piano o il blit falliscono
    # @raise [Exception] l'eccezione di un callback Ruby di resize
    # @raise [TypeError, ArgumentError] se un'opzione non è valida
    # @raise [ClosedError] se il visual, parent o il contesto sono chiusi
    def create_plane(rows: nil, cols: nil, parent: nil, y: 0, x: 0, margins: nil, name: nil, fixed: false,
                     autogrow: false, vscroll: false, resize: nil, begy: 0, begx: 0, leny: 0, lenx: 0,
                     **options, &block)
      created = Guard.run do
        ctx = @context
        vopts = Internal.options(ctx, parent, **options)
        if parent.nil? && (y.is_a?(Symbol) || x.is_a?(Symbol))
          raise ArgumentError, 'create_plane: y: e x: simbolici richiedono parent: (una pila non ha un genitore)'
        end

        area = parent ? parent.dims : ctx.dims
        opts, keep = Plane.build_options(context: ctx, parent_dims: area, rows: rows, cols: cols, y: y, x: x,
                                         margins: margins, name: name, fixed: fixed, autogrow: autogrow,
                                         vscroll: vscroll, resize: resize)
        ptr = with_region(begy, begx, leny, lenx) { |src, _| FFI.ncvisualplane_create(ctx.to_ptr, opts, src, vopts) }
        if ptr.null?
          ctx.planes_destroyed!
          ctx.raise_callback_errors!
          raise VisualError, 'ncvisualplane_create ha restituito NULL (piano non creato o blit fallito)'
        end
        plane = Plane.new(ptr, owned: true, context: ctx)
        plane.adopt_options!(keep)
        ctx.raise_callback_errors!
        plane
      end
      Util.with_resource(created, &block)
    end

    # Piano con il sottotitolo del frame corrente (+ncvisual_subtitle_plane+),
    # figlio di parent. Ha senso per un video con sottotitoli, dopo {#decode}.
    # Il piano è del chiamante.
    #
    # @param parent [Plane]
    # @return [Plane, nil] il piano, o nil se nel frame corrente non c'è un sottotitolo
    # @raise [TypeError, ArgumentError] se parent non è un Plane del contesto
    # @raise [ClosedError] se il visual o parent sono chiusi
    def subtitle_plane(parent)
      Guard.run do
        raise TypeError, "parent deve essere Notcurses::Plane, non #{parent.class}" unless parent.is_a?(Plane)
        raise ArgumentError, 'parent appartiene a un altro contesto' unless parent.context.equal?(@context)

        ptr = FFI.ncvisual_subtitle_plane(parent.to_ptr, to_ptr)
        ptr.null? ? nil : Plane.new(ptr, owned: true, context: @context)
      end
    end

    # Riproduce il video dal frame corrente alla fine (+ncvisual_stream+):
    # disegna ogni frame come {#blit} e poi chiama il blocco. Bloccante.
    #
    # Senza blocco fa il lavoro dello streamer di notcurses
    # (+ncvisual_simple_streamer+): render del contesto dopo ogni frame e
    # attesa fino all'istante del frame successivo; il render mostra solo la
    # pila dello stdplane, quindi passa un piano di quella pila. Con il blocco,
    # render e attesa sono compito del blocco.
    #
    # Piano: con plane: nil notcurses crea al primo frame una nuova pila e la
    # distrugge alla fine; con plane: p disegna in p, cancellandolo prima di
    # ogni frame. child: e le regioni non sono ammessi: in 3.0.17 child: true
    # crea un piano nuovo a ogni frame e li lascia tutti tranne l'ultimo
    # (ffmpeg.c:528), e la regione ha il bug descritto in {#blit}.
    #
    # Il blocco riceve il piano del frame e l'istante in cui mostrarlo, in
    # secondi di Process::CLOCK_MONOTONIC. Per fermare lo stream restituisce
    # :stop (anche con next :stop); break, return e throw non possono uscire
    # attraverso i frame C di notcurses: diventano una LocalJumpError, che
    # ferma lo stream come un'eccezione. Dentro il blocco non si possono
    # distruggere piani né chiudere visual. Un'eccezione del blocco ferma lo
    # stream ed esce da questo metodo.
    #
    # Thread: il blocco gira sul thread chiamante. La chiamata C rilascia il
    # GVL (decodifica e disegno; senza blocco anche l'attesa fra i frame) e lo
    # riprende per il blocco: durante lo stream gli altri thread Ruby girano,
    # ma non devono usare lo stesso contesto finché lo stream non torna. Un
    # close del visual o del contesto durante lo stream (da un altro thread,
    # dall'hook at_exit o da un gestore +trap+) ferma lo stream al frame
    # successivo, che non viene disegnato, e stream solleva ClosedError; la
    # chiusura fisica avviene al ritorno, nel thread dello stream. Se il
    # processo esce prima di quel frame, il terminale può restare non
    # ripristinato.
    #
    # @param plane [Plane, nil] piano di destinazione
    # @param timescale [Numeric] moltiplicatore delle durate dei frame, > 0
    #   (0.5 = velocità doppia)
    # @param options [Hash] y:, x:, scale:, blitter:, pxoffy:, pxoffx:,
    #   no_degrade:, blend:, no_interpolate:, transcolor:, come in {#blit}
    # @yieldparam plane [Plane] piano del frame (preso in prestito se l'ha
    #   creato notcurses: valido solo dentro il blocco)
    # @yieldparam deadline [Float] istante del frame, CLOCK_MONOTONIC
    # @yieldreturn [Object] :stop per fermare lo stream
    # @return [Boolean] true se lo stream è arrivato alla fine, false se il
    #   blocco l'ha fermato
    # @raise [VisualError] se il visual non viene da un file (in 3.0.17 il C
    #   andrebbe in crash) o se +ncvisual_stream+ fallisce
    # @raise [Exception] l'eccezione sollevata dal blocco o da un callback di resize
    # @raise [TypeError, ArgumentError] se un'opzione non è valida
    # @raise [ClosedError] se il visual, il piano o il contesto sono chiusi,
    #   anche durante lo stream
    def stream(plane: nil, timescale: 1.0, **options, &block)
      Guard.run do
        visual_guard do
          ptr = to_ptr
          raise VisualError, 'stream: il visual non viene da un file (from_file/open)' unless @file

          scale = Util.float!(timescale, 'timescale')
          raise ArgumentError, "timescale = #{timescale} deve essere > 0" unless scale.positive?

          ctx = @context
          vopts = Internal.options(ctx, plane, **options)
          fn = stream_function(ctx, block)
          begin
            rc = FFI.ncvisual_stream(ctx.to_ptr, ptr, scale, fn, vopts, nil)
          ensure
            ctx.planes_destroyed! # il piano creato da notcurses non esiste più
          end
          ctx.raise_callback_errors!
          to_ptr # un close arrivato durante lo stream lo ha fermato al frame successivo: ClosedError
          raise VisualError, "ncvisual_stream fallita (#{rc})" if rc.negative?

          rc.zero?
        end
      end
    end

    private

    # Esegue il blocco come operazione in corso sul visual: un {#close}
    # arrivato durante il blocco (da un gestore trap o da un altro thread)
    # distrugge il visual all'uscita.
    def visual_guard
      op = Object.new
      begin
        @in_use << op # dentro il begin, con un oggetto unico: l'ensure toglie solo questa operazione
        yield
      ensure
        @in_use.delete(op)
        release_native! if @closed # un close arrivato durante il blocco
      end
    end

    # Trampolino C → Ruby per ncstreamcb: 0 = continua, 1 = fermati, -1 =
    # eccezione (salvata nel contesto e rilanciata da {#stream}). Anche senza
    # blocco: a ogni frame controlla se il visual o il contesto sono stati
    # chiusi durante lo stream, e in quel caso lo ferma.
    def stream_function(ctx, block)
      box = ctx.callback_errors
      ::FFI::Function.new(:int, %i[pointer pointer pointer pointer]) do |_ncv, vopts, tspec, _curry|
        Util.guard(box, -1) do
          ctx.callback_scope do
            next 1 if closed?

            deadline = FFI::Timespec.new(tspec)
            at = deadline[:tv_sec] + (deadline[:tv_nsec] / 1e9)
            next default_stream_frame(ctx, at) unless block

            block.call(ctx.plane_for(FFI::NcVisualOptions.new(vopts)[:n]), at) == :stop ? 1 : 0
          end
        end
      end
    end

    # Il lavoro di ncvisual_simple_streamer (visual.c:1244-1263) senza
    # sottotitoli: render del contesto, poi attesa fino all'istante del frame
    # (secondi di CLOCK_MONOTONIC), senza il GVL.
    # @return [Integer] 0, o -1 se il render fallisce
    def default_stream_frame(ctx, at)
      Guard.run do
        return -1 unless FFI.notcurses_render(ctx.to_ptr).zero?

        pause = at - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        sleep(pause) if pause.positive?
        0
      end
    end

    # Esegue il blocco con il ncvisual* da disegnare e, se la regione non è
    # l'immagine intera, [righe, colonne, begy, begx] del visual: il ncvisual*
    # è allora una copia temporanea della regione.
    def with_region(begy, begx, leny, lenx)
      Guard.run do
        ptr = to_ptr
        rows, cols = dims
        Util.uint!(begy, 'begy')
        Util.uint!(begx, 'begx')
        Util.uint!(leny, 'leny')
        Util.uint!(lenx, 'lenx')
        raise ArgumentError, "regione da (#{begy}, #{begx}) fuori dal visual #{rows}x#{cols}" if begy >= rows || begx >= cols

        leny = rows - begy if leny.zero?
        lenx = cols - begx if lenx.zero?
        if begy + leny > rows || begx + lenx > cols
          raise ArgumentError, "regione (#{begy}, #{begx}) #{leny}x#{lenx} fuori dal visual #{rows}x#{cols}"
        end
        return yield(ptr, nil) if leny == rows && lenx == cols

        copy = Internal.crop(ptr, begy, begx, leny, lenx)
        begin
          yield copy, [rows, cols, begy, begx]
        ensure
          FFI.ncvisual_destroy(copy)
        end
      end
    end

    def point!(y, x)
      Util.uint!(y, 'y')
      Util.uint!(x, 'x')
      rows, cols = dims
      raise ArgumentError, "(#{y}, #{x}) fuori dal visual #{rows}x#{cols}" unless y < rows && x < cols
    end

    # Funzioni interne condivise dai metodi di classe e di istanza.
    #
    # @api private
    module Internal
      module_function

      # Il contesto attivo: in 3.0.17 un ncvisual creato senza contesto va in
      # crash alla distruzione (details NULL, ffmpeg.c:735).
      def context!
        ctx = Notcurses.active_context
        return ctx if ctx.is_a?(Context) && !ctx.closed?

        raise ClosedError, 'nessun Notcurses::Context attivo: un Visual si crea solo con un contesto aperto'
      end

      # ncvisual_options da opzioni Ruby; plane resta referenziato dal chiamante.
      def options(ctx, plane, y: 0, x: 0, scale: :none, blitter: :default, pxoffy: 0, pxoffx: 0,
                  no_degrade: false, blend: false, no_interpolate: false, transcolor: nil)
        Guard.run do
          vopts = FFI::NcVisualOptions.new
          unless plane.nil?
            raise TypeError, "plane deve essere Notcurses::Plane, non #{plane.class}" unless plane.is_a?(Plane)
            raise ArgumentError, 'plane appartiene a un altro contesto' unless plane.context.equal?(ctx)

            vopts[:n] = plane.to_ptr
          end
          vopts[:y], vflag = Plane.position(y, 'y', %i[top center bottom], FFI::NCVISUAL_OPTION_VERALIGNED)
          vopts[:x], hflag = Plane.position(x, 'x', %i[left center right], FFI::NCVISUAL_OPTION_HORALIGNED)
          raise ArgumentError, 'y: e x: simbolici richiedono plane:' if plane.nil? && (vflag | hflag).positive?

          vopts[:scaling] = Util.scale_value(scale)
          vopts[:blitter] = Util.image_blitter_value(blitter)
          vopts[:pxoffy] = Util.uint!(pxoffy, 'pxoffy')
          vopts[:pxoffx] = Util.uint!(pxoffx, 'pxoffx')
          flags = vflag | hflag |
                  Util.flag(no_degrade, FFI::NCVISUAL_OPTION_NODEGRADE, 'no_degrade') |
                  Util.flag(blend, FFI::NCVISUAL_OPTION_BLEND, 'blend') |
                  Util.flag(no_interpolate, FFI::NCVISUAL_OPTION_NOINTERPOLATE, 'no_interpolate')
          unless transcolor.nil?
            vopts[:transcolor] = Util.integer!(transcolor, 'transcolor', 0..0xffffff)
            flags |= FFI::NCVISUAL_OPTION_ADDALPHA
          end
          vopts[:flags] = flags
          vopts
        end
      end

      def child!(vopts, plane, child)
        return unless Util.bool!(child, 'child')
        raise ArgumentError, 'child: true richiede plane: (il genitore del piano nuovo)' if plane.nil?

        vopts[:flags] |= FFI::NCVISUAL_OPTION_CHILDPLANE
      end

      # Esegue il blocco, che disegna il ncvisual* src su plane con vopts,
      # dentro {Plane#keeping_glyphs_whole} sul rettangolo di celle del blit
      # (ICH-549). Il rettangolo viene da ncvisual_geom, la funzione con cui
      # ncvisual_blit lo calcola (visual.c:1155): se fallisce qui, il blit
      # fallisce prima di scrivere. Con y: o x: simbolici la posizione è quella
      # di visual.c:432-437. I blitter di celle riscrivono ogni cella del
      # rettangolo, anche quelle trasparenti; :braille invece non tocca una
      # cella con soli pixel trasparenti (blit.c:1203-1206), e il controllo
      # copre anche l'interno. Un blitter che il C risolve in :pixel non scrive
      # celle, e dopo il blit le celle del piano non si leggono più
      # (notcurses.c:274-277): nessun controllo, i glifi sotto il bitmap restano
      # interi (ICH-550).
      def keeping_glyphs_whole(ctx, plane, src, vopts, &block)
        Guard.run do
          geom = FFI::NcVgeom.new
          next yield if FFI.ncvisual_geom(ctx.to_ptr, src, vopts, geom).negative? || geom[:blitter] == FFI::NCBLIT_PIXEL

          y = vopts[:y]
          x = vopts[:x]
          if (vopts[:flags] & FFI::NCVISUAL_OPTION_VERALIGNED) != 0
            y = FFI.ncplane_valign(vopts[:n], y, geom[:rpixy] / geom[:scaley])
          end
          if (vopts[:flags] & FFI::NCVISUAL_OPTION_HORALIGNED) != 0
            x = FFI.ncplane_halign(vopts[:n], x, geom[:rpixx] / geom[:scalex])
          end
          braille = geom[:blitter] == FFI::NCBLIT_BRAILLE
          plane.keeping_glyphs_whole(y, x, geom[:rcelly], geom[:rcellx], all: braille, &block)
        end
      end

      # Dimensioni in pixel tali che ogni dimensione in byte del C (righe di
      # bpp byte per pixel, stride arrotondato da ffmpeg compreso) resti in un int.
      def dims!(rows, cols, bpp = 4)
        Util.integer!(rows, 'rows', 1..Util::INT32.max)
        Util.integer!(cols, 'cols', 1..Util::INT32.max)
        return if rows * ((cols * [bpp, 4].max) + ROW_ALIGN) <= Util::INT32.max

        raise ArgumentError, "#{rows}x#{cols} pixel: troppi per notcurses (le dimensioni in byte sono int del C)"
      end

      # Copia compatta (stride cols * bpp) delle righe di data: il C non legge
      # mai oltre il buffer e non riceve stride che gestisce male.
      # @return [::FFI::MemoryPointer]
      def pixel_buffer(data, rows, cols, bpp, stride)
        raise TypeError, "data deve essere String, non #{data.class}" unless data.is_a?(String)

        dims!(rows, cols, bpp)
        line = cols * bpp
        stride = Util.integer!(stride || line, 'rowstride', line..Util::INT32.max)
        raise ArgumentError, "rowstride = #{stride} non è un multiplo di #{bpp}" unless (stride % bpp).zero?
        if data.bytesize < rows * stride
          raise ArgumentError, "data ha #{data.bytesize} byte: ne servono rows * rowstride = #{rows * stride}"
        end

        bytes = if stride == line
                  data.byteslice(0, rows * line)
                else
                  Array.new(rows) { |row| data.byteslice(row * stride, line) }.join
                end
        ::FFI::MemoryPointer.new(:uint8, bytes.bytesize).put_bytes(0, bytes)
      end

      # Nuovo ncvisual* con la regione di ptr, da distruggere dal chiamante.
      def crop(ptr, begy, begx, leny, lenx)
        out = ::FFI::MemoryPointer.new(:uint32, leny * lenx)
        px = ::FFI::MemoryPointer.new(:uint32)
        leny.times do |dy|
          row = Array.new(lenx) do |dx|
            FFI.ncvisual_at_yx(ptr, begy + dy, begx + dx, px)
            px.read_uint32
          end
          out.put_array_of_uint32(4 * dy * lenx, row)
        end
        Util.check_ptr!(FFI.ncvisual_from_rgba(out, leny, lenx * 4, lenx), VisualError, 'ncvisual_from_rgba')
      end

      # I pixel di ptr (rows x cols), a righe, con ncvisual_at_yx.
      # @return [Array<Integer>] rows * cols valori a 32 bit
      def read_pixels(ptr, rows, cols)
        px = ::FFI::MemoryPointer.new(:uint32)
        Array.new(rows * cols) do |i|
          Util.check!(FFI.ncvisual_at_yx(ptr, i / cols, i % cols, px), VisualError, 'ncvisual_at_yx')
          px.read_uint32
        end
      end

      # Scrive ogni valore di data (a righe di cols pixel) con ncvisual_set_yx.
      def write_pixels(ptr, data, cols)
        data.each_with_index do |value, i|
          Util.check!(FFI.ncvisual_set_yx(ptr, i / cols, i % cols, value), VisualError, 'ncvisual_set_yx')
        end
      end

      # Porting di ncvisual_rotate (visual.c:707-763) con due correzioni. Il ciclo
      # sui pixel copia anche la prima riga e la prima colonna (+>=+ al posto di
      # +>+, visual.c:746). Gli angoli del riquadro dei pixel reali ruotano attorno
      # al centro dell'immagine, come i pixel: il C li ruota attorno al centro del
      # riquadro (visual.c:658-705), e con bordi trasparenti diversi sui lati i
      # pixel finiscono fuori. Un pixel è reale se vale diverso da 0.
      # @param pixels [Array<Integer>] rows * cols valori a 32 bit, a righe
      # @param rads [Float] angolo, positivo = senso antiorario
      # @return [Array(Array<Integer>, Integer, Integer), nil] pixel, righe e colonne
      #   del risultato; nil se non ci sono pixel reali
      def rotate_pixels(pixels, rows, cols, rads)
        rads = -rads # il C usa un piano cartesiano sinistrorso
        stheta = Math.sin(rads)
        ctheta = Math.cos(rads)
        box = bounding_box(pixels, rows, cols)
        return if box.nil?

        centy = (rows - 1) / 2
        centx = (cols - 1) / 2
        corners = [[box[0], box[2]], [box[0], box[3]], [box[1], box[3]], [box[1], box[2]]]
        rotated = corners.map { |y, x| rotate_point(y, x, stheta, ctheta, centy, centx) }
        offy = rotated.map(&:first).min
        offx = rotated.map(&:last).min
        out_rows = rotated.map(&:first).max - offy + 1
        out_cols = rotated.map(&:last).max - offx + 1

        # la rotazione è lineare e round è monotono: ogni pixel del riquadro finisce fra gli angoli ruotati
        data = Array.new(out_rows * out_cols, 0)
        rows.times do |y|
          cols.times do |x|
            pixel = pixels[(y * cols) + x]
            next if pixel.zero? # 0 come lo sfondo di data

            targy, targx = rotate_point(y, x, stheta, ctheta, centy, centx)
            data[((targy - offy) * out_cols) + targx - offx] = pixel
          end
        end
        [data, out_rows, out_cols]
      end

      # rotate_point di visual.c: [y, x] ruotato attorno a [centy, centx].
      def rotate_point(y, x, stheta, ctheta, centy, centx)
        convx = x - centx
        convy = y - centy
        [((convx * stheta) + (convy * ctheta)).round, ((convx * ctheta) - (convy * stheta)).round]
      end

      # Il riquadro dei pixel reali (diversi da 0), come ncvisual_bounding_box.
      # @return [Array(Integer, Integer, Integer, Integer), nil] prima e ultima riga,
      #   prima e ultima colonna; nil se non ce ne sono
      def bounding_box(pixels, rows, cols)
        real = pixels.each_index.reject { |i| pixels[i].zero? }
        return if real.empty?

        ys = real.map { |i| i / cols }
        xs = real.map { |i| i % cols }
        [ys.min, ys.max, xs.min, xs.max]
      end

      # @raise [ArgumentError] se il decoder sixel di 3.0.17 uscirebbe dai buffer
      def sixel_check!(text)
        start = text.index(/[#-]/)
        raise ArgumentError, "sixel senza dati: manca '#' o '-' dopo l'intestazione" if start.nil?

        body = text[start...(text.index("\e", start) || text.size)]
        return if SIXEL_BODY.match?(body) && body.scan(/#(\d+)/).all? { |(n)| n.to_i < SIXEL_COLORS }

        raise ArgumentError, 'sixel non accettato: ammessi "#n" (n < 65535) con ";2;r;g;b" facoltativo, ' \
                             'dati "?".."~", "!n" seguito da un dato, "$" e "-"'
      end

      def pixel_value(pixel)
        case pixel
        when Pixel then pixel.value
        when Integer then Util.uint32!(pixel, 'pixel')
        else raise TypeError, "pixel deve essere Notcurses::Pixel o Integer, non #{pixel.class}"
        end
      end
    end
    private_constant :Internal
  end
end
