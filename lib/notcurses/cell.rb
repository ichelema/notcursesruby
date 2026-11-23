# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Contenuto di una cella: un grapheme cluster (EGC), gli stili e i colori.
  #
  # Una Cell è un valore Ruby immutabile, senza memoria C, e si usa con
  # qualunque piano. Il wrapper la copia in una +nccell+ temporanea del piano
  # di destinazione solo durante la chiamata C (+nccell_prime+, la chiamata,
  # +nccell_release+). Una +nccell+ C non va tenuta più a lungo: un EGC di più
  # di 4 byte vive nell'egcpool del piano che l'ha caricato, e {Plane#erase}, i
  # resize e la distruzione del piano lo liberano (una +nccell+ conservata
  # diventerebbe un use-after-free, oppure leggerebbe l'EGC di un'altra cella).
  #
  # {Plane#at}, {Plane#base} e {Context#at} restituiscono una Cell.
  #
  # Cell.new controlla l'EGC con le regole di Ruby (un solo grapheme cluster,
  # nessun carattere di controllo). Non può usare quelle di notcurses: una Cell
  # non ha un piano, e notcurses divide un grapheme solo con un piano
  # (+nccell_load+). notcurses 3.0.17 divide in più caratteri alcuni grapheme
  # che per Ruby sono uno solo, e le scritture di quelle celle ({Plane#putc},
  # {Plane#set_base}; {Plane#polyfill}, {Plane#hline}, {Plane#vline},
  # {Plane#box} e {Plane#gradient} per quelli larghi 1 colonna) sollevano
  # CellError con i pezzi e con che cosa usare ({Plane#putegc} solleva
  # CellError per i primi due casi qui sotto, ArgumentError per gli altri,
  # come {Plane#putstr}):
  # - coniugati devanagari ("क्ष"): due caratteri larghi 1 colonna;
  #   {Plane#putstr} li scrive in due celle vicine. Solo da Unicode 15.1
  #   (Ruby 4.0): prima anche Ruby li divide, e Cell.new li rifiuta;
  # - bandiere ("🇮🇹", due indicatori regionali): due caratteri larghi 1
  #   colonna; {Plane#putstr} li scrive in due celle vicine. Ghostty 1.4 e
  #   Kitty 0.51 disegnano la bandiera larga 2, come la conta notcurses; un
  #   terminale che non raggruppa i grapheme (per esempio libghostty-vt senza
  #   il modo 2027) disegna ogni indicatore largo 2, e il testo dopo la
  #   bandiera si sposta. Un indicatore regionale da solo, che anche Ghostty e
  #   Kitty disegnano largo 2, Cell.new e {Plane#putstr} lo rifiutano;
  # - sillabe hangul scritte con i jamo L, V e T ("한"): il
  #   jamo T è largo 0 colonne; la forma composta ("한",
  #   String#unicode_normalize(:nfc)) si scrive;
  # - keycap ("1️⃣"): U+20E3 è largo 0 colonne, e anche {Plane#putstr} lo
  #   rifiuta.
  # Le sillabe hangul composte, gli emoji con ZWJ e i segni combinanti ("é")
  # si scrivono in una cella.
  #
  # @example
  #   red = Notcurses::Channels.rgb(255, 0, 0, 0, 0, 0)
  #   plane.putc(Notcurses::Cell.new(egc: '★', styles: :bold, channels: red), y: 0, x: 0)
  class Cell
    # @return [String] grapheme cluster UTF-8 ("" per una cella vuota)
    attr_reader :egc
    # @return [Array<Symbol>] stili attivi
    attr_reader :styles
    # @return [Channels] colori di primo piano e sfondo
    attr_reader :channels
    # @return [Integer] colonne occupate dall'EGC: 2 per un glifo largo, 0 per
    #   "" e per i caratteri di larghezza zero
    attr_reader :width

    # @param egc [String, Integer] un grapheme cluster ("" = cella vuota), o un
    #   codepoint Unicode
    # @param styles [Integer, Symbol, Array<Symbol>] stili
    # @param channels [Channels, Integer] colori (i bit di servizio di
    #   notcurses vengono azzerati)
    # @raise [TypeError] se un argomento non è del tipo giusto
    # @raise [ArgumentError] se egc non è UTF-8 valido, contiene NUL, più di un
    #   grapheme cluster, un carattere di controllo o un indicatore regionale
    #   da solo (notcurses lo conta largo 1, i terminali lo disegnano largo 2)
    # @raise [RangeError] se il codepoint non è valido
    def initialize(egc: ' ', styles: [], channels: 0)
      text = Cell.egc!(egc)
      assign(text, Util.styles_symbols(Util.styles_value(styles)), Channels.new(value: Util.channels_value(channels)),
             Notcurses.strwidth(text))
    end

    # Cell con i dati letti dal C, senza controlli (il C può restituire anche
    # EGC che Cell.new rifiuta). La cella "\n", che ncplane_put di 3.0.17
    # lascia sotto il cursore dopo un a capo e che il C disegna come uno
    # spazio, diventa la cella vuota "".
    # @api private
    # @param egc [String] EGC (copia UTF-8 o BINARY)
    # @param stylemask [Integer]
    # @param channels [Integer]
    # @param width [Integer, nil] colonne; nil = calcolate con +ncstrwidth+
    # @return [Cell]
    def self.from_c(egc, stylemask, channels, width = nil)
      egc, width = '', 0 if egc == "\n"
      text = egc.dup.force_encoding(Encoding::UTF_8).freeze
      if width.nil?
        width = FFI.ncstrwidth(text, nil, nil)
        width = 1 if width.negative?
      end
      styles = Util.styles_symbols(stylemask)
      chans = Channels.new(value: channels)
      allocate.instance_exec { assign(text, styles, chans, width) }
    end

    # Controlla un EGC per Cell.new.
    # @api private
    # @return [String] EGC UTF-8 frozen
    def self.egc!(value, name = 'egc')
      value = value.chr(Encoding::UTF_8) if value.is_a?(Integer)
      text = Util.string!(value, name)
      raise ArgumentError, "#{name} = #{value.inspect} contiene più di un grapheme cluster" if text.grapheme_clusters.size > 1
      raise ArgumentError, "#{name} = #{value.inspect} contiene un carattere di controllo" if text.match?(/\p{Cc}/)

      Util.lone_regional_indicator!(text, name)
      text.frozen? ? text : text.dup.freeze
    end

    # CellError per un EGC che notcurses 3.0.17 divide in più caratteri: il
    # messaggio dice in quali pezzi e che cosa usare (vedi {Cell}).
    # @api private
    # @param plane_ptr [::FFI::Pointer] ncplane* per +nccell_load+
    # @param egc [String] EGC UTF-8
    # @return [CellError, nil] nil se notcurses legge egc come un solo
    #   carattere, o se un pezzo non si carica (per esempio con l'egcpool pieno)
    def self.split_error(plane_ptr, egc)
      pieces = []
      cell = FFI::NcCell.new
      off = 0
      while off < egc.bytesize
        len = FFI.nccell_load(plane_ptr, cell, egc.byteslice(off..))
        return nil unless len.positive?

        pieces << [egc.byteslice(off, len), cell[:width]]
        off += len
      end
      return nil if pieces.size < 2

      head = "notcurses 3.0.17 divide #{Util.egc_label(egc)} in #{pieces.size} caratteri " \
             "(#{pieces.map { |s, _| Util.egc_label(s) }.join(", ")})"
      zero, = pieces.find { |_, width| width.zero? }
      return CellError.new("#{head} e una cella ne tiene uno solo: usa Plane#putstr, che li scrive in celle vicine") unless zero

      message = "#{head}, e #{Util.egc_label(zero)} è largo 0 colonne: non entra in una cella e Plane#putstr lo rifiuta"
      composed = egc.unicode_normalize(:nfc)
      if composed != egc && split_error(plane_ptr, composed).nil?
        message += "; usa la forma composta #{Util.egc_label(composed)} (String#unicode_normalize(:nfc))"
      end
      CellError.new(message)
    ensure
      FFI.nccell_release(plane_ptr, cell) if cell
    end

    # @return [Boolean] true per un glifo largo (2 colonne)
    def wide? = @width > 1

    # @return [Boolean] true per una cella vuota (EGC "")
    def empty? = @egc.empty?

    # Copia con alcuni campi cambiati.
    #
    # @param egc [String, Integer] nuovo EGC
    # @param styles [Integer, Symbol, Array<Symbol>] nuovi stili
    # @param channels [Channels, Integer] nuovi colori
    # @return [Cell]
    # @raise [TypeError, ArgumentError, RangeError] come {#initialize}
    def with(egc: @egc, styles: @styles, channels: @channels)
      Cell.new(egc: egc, styles: styles, channels: channels)
    end

    # Copia la cella in nccell, legata all'egcpool del piano (+nccell_prime+).
    # Il chiamante rilascia nccell con +nccell_release+ sullo stesso piano.
    # @api private
    # @param plane_ptr [::FFI::Pointer] ncplane*
    # @param nccell [FFI::NcCell] cella azzerata o già legata a plane_ptr
    # @return [FFI::NcCell, nil] nccell; nil se +nccell_prime+ fallisce (-1):
    #   con l'EGC di Cell.new succede quando l'egcpool del piano non ha spazio,
    #   oppure per un EGC che notcurses divide (il chiamante lo distingue)
    # @raise [CellError] se notcurses non legge l'EGC come un solo carattere
    #   (il messaggio dice in quali pezzi lo divide, vedi {Cell})
    def load_into(plane_ptr, nccell)
      mask = Util.styles_value(@styles)
      rc = FFI.nccell_prime(plane_ptr, nccell, @egc, mask, @channels.value & Util::CHANNELS_MASK)
      return nccell if rc == @egc.bytesize

      # dopo un errore la cella può sembrare la metà destra di un glifo largo
      FFI.nccell_release(plane_ptr, nccell)
      return nil if rc.negative?

      raise Cell.split_error(plane_ptr, @egc) ||
        CellError.new("notcurses non accetta #{Util.egc_label(@egc)} come un solo carattere (nccell_prime: #{rc})")
    end

    # @param other [Object] oggetto da confrontare
    # @return [Boolean] stesso EGC, stili e colori
    def ==(other) = other.is_a?(Cell) && [egc, styles, channels] == [other.egc, other.styles, other.channels]
    alias eql? ==

    # @return [Integer]
    def hash = [Cell, egc, styles, channels].hash

    # @return [String] l'EGC
    def to_s = @egc

    # @return [String]
    def inspect = "#<Notcurses::Cell egc=#{egc.inspect} width=#{width} styles=#{styles.inspect} #{channels.inspect}>"

    private

    def assign(egc, styles, channels, width)
      @egc = egc
      @styles = styles.frozen? ? styles : styles.dup.freeze
      @channels = channels
      @width = width
      freeze
    end
  end
end
