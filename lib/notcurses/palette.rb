# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Copia della palette del terminale (+ncpalette*+): 256 voci RGB. Le
  # modifiche restano nella copia finché non chiami {#use}.
  #
  # La memoria C si libera con {#close} (+ncpalette_free+) oppure, se dimentichi
  # di chiudere, quando il GC raccoglie l'oggetto: la palette è solo memoria, non
  # dipende dalla vita del contesto.
  #
  # @example
  #   pal = nc.palette
  #   pal.set_rgb(1, 255, 0, 0)
  #   pal.use if nc.can_change_color?
  #   pal.close
  class Palette
    include Resource
    extend Resource::ClassMethods

    # Releaser dell'AutoPointer: non cattura l'oggetto Palette (che altrimenti
    # non verrebbe mai raccolto).
    RELEASER = ->(ptr) { FFI.ncpalette_free(FFI::NcPalette.new(ptr)) }
    private_constant :RELEASER

    # Numero di voci della palette.
    SIZE = FFI::NCPALETTESIZE

    # @return [Context] contesto da cui è stata letta la palette
    attr_reader :context

    # Copia la palette corrente del contesto (+ncpalette_new+).
    #
    # @param context [Context]
    # @raise [TypeError] se context non è un Context
    # @raise [ContextError] se +ncpalette_new+ restituisce NULL
    # @raise [ClosedError] se il contesto è chiuso
    def initialize(context)
      raise TypeError, "context deve essere Notcurses::Context, non #{context.class}" unless context.is_a?(Context)

      raw = FFI.ncpalette_new(context.to_ptr)
      raise ContextError, 'ncpalette_new ha restituito NULL' if raw.null?

      @context = context
      @ptr = ::FFI::AutoPointer.new(raw.to_ptr, RELEASER)
      @struct = FFI::NcPalette.new(@ptr)
      @closed = false
      @owner = nil
    end

    # Libera la copia (+ncpalette_free+). Idempotente.
    # @return [nil]
    def close
      return nil if @closed

      @closed = true
      @ptr.free
      nil
    end
    alias free close

    # @return [Integer] numero di voci (256)
    def size = SIZE

    # Colore di una voce (+ncpalette_get+).
    #
    # @param index [Integer] 0..255
    # @return [Integer] 0xRRGGBB
    # @raise [TypeError, ArgumentError] se index non è un Integer in 0..255
    # @raise [ClosedError] se la palette è chiusa
    def [](index)
      check_index!(index)
      out = ::FFI::MemoryPointer.new(:uint32)
      Util.check!(FFI.ncpalette_get(struct!, index, out), ArgumentError, 'ncpalette_get')
      out.read_uint32
    end

    # Componenti di una voce (+ncpalette_get_rgb8+).
    #
    # @param index [Integer] 0..255
    # @return [Array(Integer, Integer, Integer)] [r, g, b]
    # @raise [TypeError, ArgumentError] se index non è un Integer in 0..255
    # @raise [ClosedError] se la palette è chiusa
    def rgb(index)
      check_index!(index)
      ptrs = Array.new(3) { ::FFI::MemoryPointer.new(:uint) }
      # il C restituisce (int) dell'intero canale, negativo se è attivo il bit 31:
      # con l'indice già controllato il valore non indica un errore
      FFI.ncpalette_get_rgb8(struct!, index, *ptrs)
      ptrs.map(&:read_uint)
    end

    # Imposta una voce da un valore 0xRRGGBB (+ncpalette_set+).
    #
    # @param index [Integer] 0..255
    # @param rgb [Integer] 0..0xffffff
    # @return [Integer] rgb
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ClosedError] se la palette è chiusa
    def []=(index, rgb)
      check_index!(index)
      Util.integer!(rgb, 'rgb', 0..0xffffff)
      Util.check!(FFI.ncpalette_set(struct!, index, rgb), ArgumentError, 'ncpalette_set')
    end

    # Imposta una voce dai componenti (+ncpalette_set_rgb8+).
    #
    # @param index [Integer] 0..255
    # @param r [Integer] 0..255
    # @param g [Integer] 0..255
    # @param b [Integer] 0..255
    # @return [self]
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ClosedError] se la palette è chiusa
    def set_rgb(index, r, g, b)
      check_index!(index)
      Util.uint8!(r, 'r')
      Util.uint8!(g, 'g')
      Util.uint8!(b, 'b')
      Util.check!(FFI.ncpalette_set_rgb8(struct!, index, r, g, b), ArgumentError, 'ncpalette_set_rgb8')
      self
    end

    # Installa la palette nel terminale (+ncpalette_use+).
    #
    # @return [self]
    # @raise [ContextError] se il terminale non può cambiare la palette
    # @raise [ClosedError] se la palette o il contesto sono chiusi
    def use
      Util.check!(FFI.ncpalette_use(@context.to_ptr, struct!), ContextError, 'ncpalette_use')
      self
    end

    # @return [Array<Integer>] le 256 voci come 0xRRGGBB
    # @raise [ClosedError] se la palette è chiusa
    def to_a = Array.new(SIZE) { |i| self[i] }

    private

    def struct!
      to_ptr
      @struct
    end

    def check_index!(index) = Util.integer!(index, 'index', 0...SIZE)
  end
end
