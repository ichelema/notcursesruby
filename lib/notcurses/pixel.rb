# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Pixel RGBA a 32 bit, nel formato di memoria di notcurses e libav: i byte
  # sono R, G, B, A in quest'ordine, quindi il valore letto come +uint32_t+
  # little-endian è 0xAABBGGRR (ABGR).
  #
  # Value object immutabile: i metodi +with_*+ restituiscono un nuovo Pixel.
  #
  # @example
  #   px = Notcurses::Pixel.rgb(255, 128, 0)
  #   px.to_a          #=> [255, 128, 0, 255]
  #   px.with_a(0).a   #=> 0
  class Pixel
    # @return [Integer] valore a 32 bit, come +uint32_t+ in memoria
    attr_reader :value
    alias to_i value

    # @param value [Integer] valore a 32 bit
    # @raise [TypeError] se value non è Integer
    # @raise [ArgumentError] se value è fuori da 0..0xffffffff
    def initialize(value = 0)
      @value = Util.uint32!(value, 'value')
      freeze
    end

    # Pixel opaco (alpha 255) (+ncpixel+).
    #
    # @param r [Integer] 0..255
    # @param g [Integer] 0..255
    # @param b [Integer] 0..255
    # @return [Pixel]
    # @raise [TypeError, ArgumentError] se un componente non è un Integer in 0..255
    def self.rgb(r, g, b)
      Util.uint8!(r, 'r')
      Util.uint8!(g, 'g')
      Util.uint8!(b, 'b')
      new(FFI.ncpixel(r, g, b))
    end

    # Pixel con alpha esplicita.
    #
    # @param r [Integer] 0..255
    # @param g [Integer] 0..255
    # @param b [Integer] 0..255
    # @param a [Integer] 0..255 (0 trasparente, 255 opaco)
    # @return [Pixel]
    # @raise [TypeError, ArgumentError] se un componente non è un Integer in 0..255
    def self.rgba(r, g, b, a) = rgb(r, g, b).with_a(a)

    # @return [Integer] rosso, 0..255 (+ncpixel_r+)
    def r = FFI.ncpixel_r(@value)

    # @return [Integer] verde, 0..255 (+ncpixel_g+)
    def g = FFI.ncpixel_g(@value)

    # @return [Integer] blu, 0..255 (+ncpixel_b+)
    def b = FFI.ncpixel_b(@value)

    # @return [Integer] alpha, 0..255 (+ncpixel_a+)
    def a = FFI.ncpixel_a(@value)

    # @return [Array(Integer, Integer, Integer, Integer)] [r, g, b, a]
    def to_a = [r, g, b, a]

    # @param r [Integer] 0..255
    # @return [Pixel] (+ncpixel_set_r+)
    # @raise [TypeError, ArgumentError] se r non è un Integer in 0..255
    def with_r(r) = set_component(r, 'r') { |ptr, v| FFI.ncpixel_set_r(ptr, v) }

    # @param g [Integer] 0..255
    # @return [Pixel] (+ncpixel_set_g+)
    # @raise [TypeError, ArgumentError] se g non è un Integer in 0..255
    def with_g(g) = set_component(g, 'g') { |ptr, v| FFI.ncpixel_set_g(ptr, v) }

    # @param b [Integer] 0..255
    # @return [Pixel] (+ncpixel_set_b+)
    # @raise [TypeError, ArgumentError] se b non è un Integer in 0..255
    def with_b(b) = set_component(b, 'b') { |ptr, v| FFI.ncpixel_set_b(ptr, v) }

    # @param a [Integer] 0..255
    # @return [Pixel] (+ncpixel_set_a+)
    # @raise [TypeError, ArgumentError] se a non è un Integer in 0..255
    def with_a(a) = set_component(a, 'a') { |ptr, v| FFI.ncpixel_set_a(ptr, v) }

    # Nuovo pixel con altri componenti RGB; alpha invariata (+ncpixel_set_rgb8+).
    #
    # @param r [Integer] 0..255
    # @param g [Integer] 0..255
    # @param b [Integer] 0..255
    # @return [Pixel]
    # @raise [TypeError, ArgumentError] se un componente non è un Integer in 0..255
    def with_rgb(r, g, b)
      Util.uint8!(r, 'r')
      Util.uint8!(g, 'g')
      Util.uint8!(b, 'b')
      update { |ptr| Util.check!(FFI.ncpixel_set_rgb8(ptr, r, g, b), ArgumentError, 'ncpixel_set_rgb8') }
    end

    # @param other [Object] oggetto da confrontare
    # @return [Boolean]
    def ==(other) = other.is_a?(Pixel) && other.value == @value
    alias eql? ==

    # @return [Integer]
    def hash = [Pixel, @value].hash

    # @return [String]
    def inspect = format('#<Notcurses::Pixel r=%<r>d g=%<g>d b=%<b>d a=%<a>d>', r: r, g: g, b: b, a: a)

    private

    def set_component(value, name)
      Util.uint8!(value, name)
      update { |ptr| Util.check!(yield(ptr, value), ArgumentError, "ncpixel_set_#{name}") }
    end

    def update
      ptr = ::FFI::MemoryPointer.new(:uint32)
      ptr.write_uint32(@value)
      yield ptr
      Pixel.new(ptr.read_uint32)
    end
  end
end
