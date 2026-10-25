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
  # nessun carattere di controllo). notcurses 3.0.17 segmenta alcuni grapheme
  # in modo diverso (bandiere, sillabe hangul composte, coniugati devanagari):
  # quelle celle fanno sollevare CellError quando vengono scritte su un piano.
  #
  # @example
  #   red = Notcurses::Channels.rgb(255, 0, 0, 0, 0, 0)
  #   plane.putc(Notcurses::Cell.new('★', styles: :bold, channels: red), y: 0, x: 0)
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
    #   grapheme cluster o un carattere di controllo
    # @raise [RangeError] se il codepoint non è valido
    def initialize(egc = ' ', styles: [], channels: 0)
      text = Cell.egc!(egc)
      assign(text, Util.styles_symbols(Util.styles_value(styles)), Channels.new(Util.channels_value(channels)),
             Notcurses.strwidth(text))
    end

    # Cell con i dati letti dal C, senza controlli (il C può restituire anche
    # EGC che Cell.new rifiuta).
    # @api private
    # @param egc [String] EGC (copia UTF-8 o BINARY)
    # @param stylemask [Integer]
    # @param channels [Integer]
    # @param width [Integer, nil] colonne; nil = calcolate con +ncstrwidth+
    # @return [Cell]
    def self.from_c(egc, stylemask, channels, width = nil)
      text = egc.dup.force_encoding(Encoding::UTF_8).freeze
      if width.nil?
        width = FFI.ncstrwidth(text, nil, nil)
        width = 1 if width.negative?
      end
      styles = Util.styles_symbols(stylemask)
      chans = Channels.new(channels)
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

      text.frozen? ? text : text.dup.freeze
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
      Cell.new(egc, styles: styles, channels: channels)
    end

    # Copia la cella in nccell, legata all'egcpool del piano (+nccell_prime+).
    # Il chiamante rilascia nccell con +nccell_release+ sullo stesso piano.
    # @api private
    # @param plane_ptr [::FFI::Pointer] ncplane*
    # @param nccell [FFI::NcCell] cella azzerata o già legata a plane_ptr
    # @return [FFI::NcCell] nccell
    # @raise [CellError] se notcurses non legge l'EGC come un solo carattere
    def load_into(plane_ptr, nccell)
      mask = Util.styles_value(@styles)
      rc = FFI.nccell_prime(plane_ptr, nccell, @egc, mask, @channels.value & Util::CHANNELS_MASK)
      return nccell if rc == @egc.bytesize

      # dopo un errore la cella può sembrare la metà destra di un glifo largo
      FFI.nccell_release(plane_ptr, nccell)
      raise CellError, "notcurses non accetta #{@egc.inspect} come un solo carattere (nccell_prime: #{rc})"
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
