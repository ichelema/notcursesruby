# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Funzioni di supporto comuni ai wrapper: validazione ai confini, stringhe,
  # memoria ALLOC, codici di errore, conversione dei simboli Ruby nelle costanti
  # C, protezione dei callback.
  #
  # @api private
  module Util
    module_function

    INT32 = (-0x8000_0000..0x7fff_ffff).freeze
    UINT8 = (0..0xff).freeze
    UINT16 = (0..0xffff).freeze
    UINT32 = (0..0xffff_ffff).freeze
    UINT64 = (0..0xffff_ffff_ffff_ffff).freeze
    NONNEG_INT = (0..0x7fff_ffff).freeze
    INT64 = (-0x8000_0000_0000_0000..0x7fff_ffff_ffff_ffff).freeze
    # Secondi di attesa dell'input: oltre time_t IO#wait_readable solleva
    # RangeError; 2^31 - 1 (circa 68 anni) sta anche in un time_t a 32 bit.
    TIMEOUT = (0.0..0x7fff_ffff.to_f).freeze

    ALPHAS = {
      opaque: FFI::NCALPHA_OPAQUE,
      blend: FFI::NCALPHA_BLEND,
      transparent: FFI::NCALPHA_TRANSPARENT,
      highcontrast: FFI::NCALPHA_HIGHCONTRAST
    }.freeze

    ALIGNS = {
      unaligned: FFI::NCALIGN_UNALIGNED,
      left: FFI::NCALIGN_LEFT,
      center: FFI::NCALIGN_CENTER,
      right: FFI::NCALIGN_RIGHT,
      top: FFI::NCALIGN_TOP,
      bottom: FFI::NCALIGN_BOTTOM
    }.freeze

    STYLES = {
      italic: FFI::NCSTYLE_ITALIC,
      underline: FFI::NCSTYLE_UNDERLINE,
      undercurl: FFI::NCSTYLE_UNDERCURL,
      bold: FFI::NCSTYLE_BOLD,
      struck: FFI::NCSTYLE_STRUCK
    }.freeze

    # Nomi di notcurses_str_blitter/notcurses_lex_blitter come simboli.
    BLITTERS = {
      default: FFI::NCBLIT_DEFAULT,
      ascii: FFI::NCBLIT_1x1,
      half: FFI::NCBLIT_2x1,
      quad: FFI::NCBLIT_2x2,
      sextant: FFI::NCBLIT_3x2,
      octant: FFI::NCBLIT_4x2,
      braille: FFI::NCBLIT_BRAILLE,
      pixel: FFI::NCBLIT_PIXEL,
      four_by_one: FFI::NCBLIT_4x1,
      eight_by_one: FFI::NCBLIT_8x1
    }.freeze

    # Blitter delle immagini (Visual, Plane#as_rgba, Direct): 4x1 e 8x1 servono
    # solo ai plot. Il loro blitset ha egcs NULL (blit.c:1279, 1282): con i
    # quadranti ncplane_as_rgba va in SIGSEGV e i blit tagliano l'immagine.
    IMAGE_BLITTERS = BLITTERS.except(:four_by_one, :eight_by_one).freeze

    SCALES = {
      none: FFI::NCSCALE_NONE,
      scale: FFI::NCSCALE_SCALE,
      stretch: FFI::NCSCALE_STRETCH,
      none_hires: FFI::NCSCALE_NONE_HIRES,
      scale_hires: FFI::NCSCALE_SCALE_HIRES
    }.freeze

    LOGLEVELS = {
      silent: FFI::NCLOGLEVEL_SILENT,
      panic: FFI::NCLOGLEVEL_PANIC,
      fatal: FFI::NCLOGLEVEL_FATAL,
      error: FFI::NCLOGLEVEL_ERROR,
      warning: FFI::NCLOGLEVEL_WARNING,
      info: FFI::NCLOGLEVEL_INFO,
      verbose: FFI::NCLOGLEVEL_VERBOSE,
      debug: FFI::NCLOGLEVEL_DEBUG,
      trace: FFI::NCLOGLEVEL_TRACE
    }.freeze

    EVTYPES = {
      unknown: FFI::NCTYPE_UNKNOWN,
      press: FFI::NCTYPE_PRESS,
      repeat: FFI::NCTYPE_REPEAT,
      release: FFI::NCTYPE_RELEASE
    }.freeze

    PIXEL_IMPLS = {
      none: FFI::NCPIXEL_NONE,
      sixel: FFI::NCPIXEL_SIXEL,
      linuxfb: FFI::NCPIXEL_LINUXFB,
      iterm2: FFI::NCPIXEL_ITERM2,
      kitty_static: FFI::NCPIXEL_KITTY_STATIC,
      kitty_animated: FFI::NCPIXEL_KITTY_ANIMATED,
      kitty_selfref: FFI::NCPIXEL_KITTY_SELFREF
    }.freeze

    # --- validazione ---

    # @param value [Object] valore da controllare
    # @param name [String] nome usato nel messaggio d'errore
    # @param range [Range] intervallo ammesso
    # @return [Integer] value
    # @raise [TypeError] se value non è Integer
    # @raise [ArgumentError] se value è fuori da range
    def integer!(value, name, range)
      raise TypeError, "#{name} deve essere Integer, non #{value.class}" unless value.is_a?(Integer)
      raise ArgumentError, "#{name} = #{value} fuori dall'intervallo #{range}" unless range.cover?(value)

      value
    end

    # int del C (32 bit con segno).
    # @param value [Object] valore da controllare
    # @param name [String] nome usato nel messaggio d'errore
    # @return [Integer] value
    # @raise [TypeError] se value non è un Integer
    # @raise [ArgumentError] se value è fuori dall'intervallo
    def int!(value, name) = integer!(value, name, INT32)

    # unsigned del C (32 bit).
    # @param value [Object] valore da controllare
    # @param name [String] nome usato nel messaggio d'errore
    # @return [Integer] value
    # @raise [TypeError] se value non è un Integer
    # @raise [ArgumentError] se value è fuori dall'intervallo
    def uint!(value, name) = integer!(value, name, UINT32)

    # uint8_t (0..255).
    # @param value [Object] valore da controllare
    # @param name [String] nome usato nel messaggio d'errore
    # @return [Integer] value
    # @raise [TypeError] se value non è un Integer
    # @raise [ArgumentError] se value è fuori dall'intervallo
    def uint8!(value, name) = integer!(value, name, UINT8)

    # uint16_t (0..65535).
    # @param value [Object] valore da controllare
    # @param name [String] nome usato nel messaggio d'errore
    # @return [Integer] value
    # @raise [TypeError] se value non è un Integer
    # @raise [ArgumentError] se value è fuori dall'intervallo
    def uint16!(value, name) = integer!(value, name, UINT16)

    # uint32_t.
    # @param value [Object] valore da controllare
    # @param name [String] nome usato nel messaggio d'errore
    # @return [Integer] value
    # @raise [TypeError] se value non è un Integer
    # @raise [ArgumentError] se value è fuori dall'intervallo
    def uint32!(value, name) = integer!(value, name, UINT32)

    # uint64_t.
    # @param value [Object] valore da controllare
    # @param name [String] nome usato nel messaggio d'errore
    # @return [Integer] value
    # @raise [TypeError] se value non è un Integer
    # @raise [ArgumentError] se value è fuori dall'intervallo
    def uint64!(value, name) = integer!(value, name, UINT64)

    # int64_t.
    # @param value [Object] valore da controllare
    # @param name [String] nome usato nel messaggio d'errore
    # @return [Integer] value
    # @raise [TypeError] se value non è un Integer
    # @raise [ArgumentError] se value è fuori dall'intervallo
    def int64!(value, name) = integer!(value, name, INT64)

    # int del C non negativo (dimensioni, conteggi).
    # @param value [Object] valore da controllare
    # @param name [String] nome usato nel messaggio d'errore
    # @return [Integer] value
    # @raise [TypeError] se value non è un Integer
    # @raise [ArgumentError] se value è fuori dall'intervallo
    def nonneg_int!(value, name) = integer!(value, name, NONNEG_INT)

    # Regione per le funzioni C con begy, begx (-1 = cursore) e leny, lenx (0
    # = fino al bordo). In Ruby nil vale cursore o «fino al bordo», e i valori
    # speciali del C sono rifiutati.
    # @param y [Integer, nil] riga di partenza, >= 0; nil = riga del cursore
    # @param x [Integer, nil] colonna di partenza, >= 0; nil = colonna del cursore
    # @param rows [Integer, nil] righe, >= 1; nil = fino al bordo
    # @param cols [Integer, nil] colonne, >= 1; nil = fino al bordo
    # @return [Array(Integer, Integer, Integer, Integer)] begy, begx, leny, lenx del C
    # @raise [TypeError] se un valore non è Integer né nil
    # @raise [ArgumentError] se y o x sono negativi, o rows o cols valgono meno di 1
    def c_region(y, x, rows, cols)
      [y.nil? ? -1 : nonneg_int!(y, 'y'),
       x.nil? ? -1 : nonneg_int!(x, 'x'),
       rows.nil? ? 0 : integer!(rows, 'rows', 1..UINT32.max),
       cols.nil? ? 0 : integer!(cols, 'cols', 1..UINT32.max)]
    end

    # @param value [Object] valore da controllare
    # @param name [String] nome usato nel messaggio d'errore
    # @param range [Range, nil] intervallo ammesso, o nil per nessun limite
    # @return [Float]
    # @raise [TypeError] se value non è Numeric reale
    # @raise [ArgumentError] se value non è finito o è fuori da range
    def float!(value, name, range = nil)
      unless value.is_a?(Numeric) && value.real?
        raise TypeError, "#{name} deve essere un numero reale, non #{value.class}"
      end

      f = value.to_f
      raise ArgumentError, "#{name} = #{value} non è un numero finito" unless f.finite?
      raise ArgumentError, "#{name} = #{value} fuori dall'intervallo #{range}" if range && !range.cover?(f)

      f
    end

    # @param value [Object] valore da controllare
    # @param name [String] nome usato nel messaggio d'errore
    # @return [Boolean] value
    # @raise [TypeError] se value non è true o false
    def bool!(value, name)
      raise TypeError, "#{name} deve essere true o false, non #{value.inspect}" unless [true, false].include?(value)

      value
    end

    # Booleano Ruby come intero C (per i parametri +unsigned+ usati come bool).
    # @param value [Object] valore da controllare
    # @param name [String] nome usato nel messaggio d'errore
    # @return [Integer] 1 o 0
    # @raise [TypeError] se value non è true o false
    def c_bool(value, name) = bool!(value, name) ? 1 : 0

    # Stringa da passare al C: UTF-8 valido, senza NUL interni.
    #
    # Una String BINARY (ASCII-8BIT) è letta come byte UTF-8; le altre
    # codifiche sono convertite in UTF-8.
    # @param value [Object] valore da controllare
    # @param name [String] nome usato nel messaggio d'errore
    # @return [String] stringa UTF-8
    # @raise [TypeError] se value non è String
    # @raise [ArgumentError] se value contiene NUL, non è UTF-8 valido o non è
    #   convertibile in UTF-8
    def string!(value, name)
      raise TypeError, "#{name} deve essere String, non #{value.class}" unless value.is_a?(String)

      s = if value.encoding == Encoding::UTF_8
            value
          elsif value.encoding == Encoding::BINARY
            value.dup.force_encoding(Encoding::UTF_8)
          else
            value.encode(Encoding::UTF_8)
          end
      raise ArgumentError, "#{name} non è UTF-8 valido" unless s.valid_encoding?
      raise ArgumentError, "#{name} contiene un byte NUL" if s.include?("\0")

      s
    rescue EncodingError => e
      raise ArgumentError, "#{name} non è convertibile in UTF-8 (#{e.message})"
    end

    # Come {string!}, ma accetta nil (NULL).
    # @param value [String, nil] stringa da controllare
    # @param name [String] nome usato nel messaggio d'errore
    # @return [String, nil] stringa UTF-8, o nil
    # @raise [TypeError] se value non è String né nil
    # @raise [ArgumentError] se value contiene NUL o non è UTF-8 valido
    def string_or_nil!(value, name) = value.nil? ? nil : string!(value, name)

    # Stringa NUL-terminata in memoria C, da tenere referenziata finché il C
    # la usa (campi const char* delle struct di opzioni).
    # @param value [String, nil] stringa da copiare
    # @param name [String] nome usato nel messaggio d'errore
    # @return [::FFI::MemoryPointer, nil]
    # @raise [TypeError] se value non è String né nil
    # @raise [ArgumentError] se value contiene NUL o non è UTF-8 valido
    def c_string(value, name)
      return nil if value.nil?

      ::FFI::MemoryPointer.from_string(string!(value, name))
    end

    # @param klass [Class] classe attesa
    # @param name [String] nome usato nel messaggio d'errore
    # @param nil_ok [Boolean] se true, nil diventa NULL
    # @param value [Object] oggetto con +to_ptr+ (o +nil+ se nil_ok)
    # @return [::FFI::Pointer]
    # @raise [TypeError] se value non è un'istanza di klass
    def ptr_of(value, klass, name, nil_ok: false)
      return ::FFI::Pointer::NULL if nil_ok && value.nil?
      raise TypeError, "#{name} deve essere #{klass.name}, non #{value.class}" unless value.is_a?(klass)

      value.to_ptr
    end

    # Il testo spezzato dopo ogni grapheme cluster con uno ZWJ (U+200D):
    # notcurses 3.0.17 unisce al carattere con lo ZWJ tutto quello che segue.
    # @param str [String] testo UTF-8 valido
    # @return [Array<String>] [str] se str non contiene ZWJ
    def zwj_segments(str)
      return [str] unless str.include?("‍")

      segments = [+'']
      str.each_grapheme_cluster do |g|
        segments.last << g
        segments << +'' if g.include?("‍")
      end
      segments.pop if segments.last.empty?
      segments
    end

    # --- dal C a Ruby ---

    # Stringa restituita da un :string di FFI (copia BINARY) in UTF-8.
    # @param str [String, nil] stringa restituita da FFI
    # @return [String, nil]
    def utf8(str)
      str&.force_encoding(Encoding::UTF_8)
    end

    # Legge un char* allocato dal C (memoria ALLOC), lo libera con free() e
    # restituisce la String UTF-8. NULL diventa nil.
    # @param ptr [::FFI::Pointer, nil] puntatore a un char* allocato dal C
    # @return [String, nil] UTF-8 valido: i byte che non sono UTF-8 valido
    #   diventano U+FFFD
    def take_string(ptr)
      return nil if ptr.nil? || ptr.null?

      begin
        ptr.read_string.force_encoding(Encoding::UTF_8).scrub
      ensure
        FFI.free(ptr)
      end
    end

    # @param rc [Integer] codice restituito dal C
    # @param error [Class] eccezione da sollevare
    # @param what [String] nome della funzione C, per il messaggio d'errore
    # @return [Integer] rc
    # @raise [error] se rc < 0
    def check!(rc, error, what)
      raise error, "#{what} fallita (#{rc})" if rc.negative?

      rc
    end

    # @param ptr [::FFI::Pointer, nil] puntatore restituito dal C
    # @param error [Class] eccezione da sollevare
    # @param what [String] nome della funzione C, per il messaggio d'errore
    # @return [::FFI::Pointer] ptr
    # @raise [error] se ptr è NULL
    def check_ptr!(ptr, error, what)
      raise error, "#{what} ha restituito NULL" if ptr.nil? || ptr.null?

      ptr
    end

    # Secondi Ruby come struct timespec.
    # @param name [String] nome usato nel messaggio d'errore
    # @param seconds [Numeric] secondi >= 0
    # @return [FFI::Timespec]
    # @raise [TypeError, ArgumentError] se seconds non è un numero reale finito >= 0
    def timespec(seconds, name = 'timeout')
      unless seconds.is_a?(Numeric) && seconds.real?
        raise TypeError, "#{name} deve essere un numero di secondi, non #{seconds.class}"
      end
      raise ArgumentError, "#{name} = #{seconds} deve essere >= 0" if seconds.negative?
      raise ArgumentError, "#{name} = #{seconds} non è finito" if seconds.is_a?(Float) && !seconds.finite?

      sec, frac = seconds.to_r.divmod(1)
      nsec = (frac * 1_000_000_000).round
      if nsec >= 1_000_000_000
        sec += 1
        nsec -= 1_000_000_000
      end
      ts = FFI::Timespec.new
      ts[:tv_sec] = sec
      ts[:tv_nsec] = nsec
      ts
    end

    # Bit di un flag se l'opzione booleana è attiva: si combinano con +|+.
    # @param value [Object] opzione booleana
    # @param bit [Integer] bit da attivare
    # @param name [String] nome usato nel messaggio d'errore
    # @return [Integer] bit oppure 0
    # @raise [TypeError] se value non è true o false
    def flag(value, bit, name) = bool!(value, name) ? bit : 0

    # --- simboli <-> costanti C ---

    # Simbolo della tabella, oppure una delle costanti C intere della tabella.
    # @param table [Hash{Symbol => Integer}] tabella simboli e costanti C
    # @param value [Symbol, Integer] simbolo o costante C
    # @param name [String] nome usato nel messaggio d'errore
    # @return [Integer] valore C
    # @raise [ArgumentError] se value non è una chiave né un valore di table
    def enum_value(table, value, name)
      return value if value.is_a?(Integer) && table.value?(value)

      table.fetch(value) do
        raise ArgumentError, "#{name} = #{value.inspect} non valido: usa uno di #{table.keys.map(&:inspect).join(', ')}"
      end
    end

    # @param table [Hash{Symbol => Integer}] tabella simboli e costanti C
    # @param value [Integer] costante C
    # @return [Symbol, Integer] simbolo del valore C (il valore stesso se sconosciuto)
    def enum_symbol(table, value)
      table.key(value) || value
    end

    # Alpha come simbolo (:opaque, :blend, :transparent, :highcontrast) o come
    # costante NCALPHA_*.
    # @param alpha [Symbol, Integer] simbolo o costante NCALPHA_*
    # @return [Integer]
    # @raise [ArgumentError] se alpha non è valido
    def alpha_value(alpha) = enum_value(ALPHAS, alpha, 'alpha')

    # @param value [Integer] costante NCALPHA_*
    # @return [Symbol]
    def alpha_symbol(value) = enum_symbol(ALPHAS, value)

    # @param align [Symbol, Integer] simbolo o costante NCALIGN_*
    # @return [Integer]
    # @raise [ArgumentError] se align non è valido
    def align_value(align) = enum_value(ALIGNS, align, 'align')

    # Bit validi di un canale: i bit 0x87000000 sono di servizio (con tutti e
    # quattro attivi il rasterizzatore non emette lo sfondo) e alcuni setter C
    # li copiano dove non devono: il wrapper non li passa mai al C.
    CHANNEL_MASK = 0x78ff_ffff
    CHANNELS_MASK = (CHANNEL_MASK << 32) | CHANNEL_MASK

    # Valore uint64_t di un parametro channels: {Channels} o Integer, senza i
    # bit di servizio.
    # @param value [Channels, Integer] canali
    # @param name [String] nome usato nel messaggio d'errore
    # @return [Integer]
    # @raise [TypeError] se value non è Channels né Integer
    # @raise [ArgumentError] se value Integer è fuori da uint64_t
    def channels_value(value, name = 'channels')
      case value
      when Channels then value.value & CHANNELS_MASK
      when Integer then uint64!(value, name) & CHANNELS_MASK
      else raise TypeError, "#{name} deve essere Notcurses::Channels o Integer, non #{value.class}"
      end
    end

    # Come {channels_value}, per i colori di scrittura di un piano: notcurses
    # non ammette l'alpha :highcontrast per lo sfondo (+ncplane_set_channels+).
    # @param value [Channels, Integer] canali
    # @param name [String] nome usato nel messaggio d'errore
    # @return [Integer]
    # @raise [TypeError] se value non è Channels né Integer
    # @raise [ArgumentError] se value Integer è fuori da uint64_t o lo sfondo
    #   ha alpha :highcontrast
    def plane_channels_value(value, name = 'channels')
      channels = channels_value(value, name)
      raise ArgumentError, "#{name}: l'alpha :highcontrast non è ammessa per lo sfondo" if Channels.new(value: channels).bg_alpha == :highcontrast

      channels
    end

    # Valore uint32_t di un parametro channel: {Channel} o Integer, senza i bit
    # di servizio.
    # @param value [Channel, Integer] canale
    # @param name [String] nome usato nel messaggio d'errore
    # @return [Integer]
    # @raise [TypeError] se value non è Channel né Integer
    # @raise [ArgumentError] se value Integer è fuori da uint32_t
    def channel_value(value, name = 'channel')
      case value
      when Channel then value.value & CHANNEL_MASK
      when Integer then uint32!(value, name) & CHANNEL_MASK
      else raise TypeError, "#{name} deve essere Notcurses::Channel o Integer, non #{value.class}"
      end
    end

    # Allineamento usato per calcolare una posizione: rifiuta :unaligned, per
    # cui notcurses_align restituisce -INT_MAX.
    # @param align [Symbol, Integer] simbolo o costante NCALIGN_*
    # @return [Integer]
    # @raise [ArgumentError] se align non è valido
    def placement_align_value(align)
      value = align_value(align)
      raise ArgumentError, 'align = :unaligned non ammesso: usa :left, :center, :right, :top o :bottom' if value == FFI::NCALIGN_UNALIGNED

      value
    end

    # @param blitter [Symbol, Integer] simbolo o costante NCBLIT_*
    # @return [Integer]
    # @raise [ArgumentError] se blitter non è valido
    def blitter_value(blitter) = enum_value(BLITTERS, blitter, 'blitter')

    # @param blitter [Symbol, Integer] simbolo o costante NCBLIT_* di {IMAGE_BLITTERS}
    # @return [Integer]
    # @raise [ArgumentError] se blitter non è valido o è :four_by_one o :eight_by_one
    def image_blitter_value(blitter) = enum_value(IMAGE_BLITTERS, blitter, 'blitter')

    # @param scale [Symbol, Integer] simbolo o costante NCSCALE_*
    # @return [Integer]
    # @raise [ArgumentError] se scale non è valido
    def scale_value(scale) = enum_value(SCALES, scale, 'scale')

    # Stili come maschera Integer (0..0xffff), simbolo o Array di simboli.
    # @param styles [Integer, Symbol, Array<Symbol>] stili
    # @return [Integer]
    # @raise [ArgumentError] se uno stile non è valido
    def styles_value(styles)
      case styles
      when Integer then uint16!(styles, 'styles')
      when Symbol then enum_value(STYLES, styles, 'styles')
      when Array then styles.reduce(0) { |mask, s| mask | enum_value(STYLES, s, 'styles') }
      else raise TypeError, "styles deve essere Integer, Symbol o Array di Symbol, non #{styles.class}"
      end
    end

    # Stili di più argomenti (on_styles(*styles), off_styles(*styles)) in una
    # sola maschera.
    # @param list [Array<Integer, Symbol, Array<Symbol>>] stili
    # @return [Integer]
    # @raise [TypeError, ArgumentError] se uno stile non è valido
    def styles_mask(list) = list.reduce(0) { |mask, s| mask | styles_value(s) }

    # @param mask [Integer] maschera di stili
    # @return [Array<Symbol>] stili attivi nella maschera
    def styles_symbols(mask)
      STYLES.select { |_sym, bit| (mask & bit) != 0 }.keys
    end

    # --- callback ---

    # Esegue il blocco di un callback chiamato dal C. Un'eccezione Ruby non deve
    # attraversare i frame C: viene salvata in box (solo la prima) e il C riceve
    # fallback. Il wrapper la rilancia con {reraise!} dopo il ritorno al Ruby.
    # Anche break, return e throw, che non sono eccezioni, si fermano qui: in box
    # finisce una LocalJumpError. Thread#kill invece passa (FdPlane e
    # Subprocess fermano così il thread di lettura).
    # @param box [Array<Exception>] contenitore della prima eccezione
    # @param fallback [Object] valore restituito al C se il blocco solleva
    # @return [Object] il valore del blocco, o fallback se solleva
    def guard(box, fallback)
      state = :running
      result = yield
      state = :done
      result
    rescue Exception => e # rubocop:disable Lint/RescueException
      state = :raised
      box << e if box.empty?
      fallback
    ensure
      if state == :running && Thread.current.status != 'aborting'
        box << LocalJumpError.new('break, return o throw non possono uscire da un callback chiamato da notcurses') if box.empty?
        return fallback # rubocop:disable Lint/EnsureReturn
      end
    end

    # Rilancia la prima eccezione salvata da {guard} e svuota box.
    # @param box [Array<Exception>] contenitore riempito da {guard}
    # @return [nil] se box è vuoto
    # @raise [Exception] la prima eccezione salvata
    def reraise!(box)
      return if box.empty?

      error = box.first
      box.clear
      raise error
    end

    # Blocco opzionale dei metodi che creano risorse: senza blocco restituisce
    # la risorsa, con il blocco la passa al blocco e la chiude alla fine.
    # @param resource [#close] risorsa da passare al blocco
    # @return [Object] la risorsa, o il valore del blocco
    def with_resource(resource)
      return resource unless block_given?

      begin
        yield resource
      ensure
        resource.close
      end
    end
  end
end
