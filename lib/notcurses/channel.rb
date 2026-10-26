# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Canale colore a 32 bit (+uint32_t+ del C): RGB a 24 bit, oppure indice di
  # palette, oppure colore di default del terminale, più due bit di alpha.
  #
  # Value object immutabile: i metodi +with_*+ restituiscono un nuovo Channel.
  # Due Channel con lo stesso valore sono uguali (+==+, +eql?+, +hash+).
  #
  # @example
  #   red = Notcurses::Channel.rgb(255, 0, 0)
  #   red.rgb                       #=> [255, 0, 0]
  #   red.with_alpha(:blend).alpha  #=> :blend
  class Channel
    # @return [Integer] valore a 32 bit
    attr_reader :value
    alias to_i value

    # @param value [Integer] valore a 32 bit (0 = colore di default, opaco)
    # @raise [TypeError] se value non è Integer
    # @raise [ArgumentError] se value è fuori da 0..0xffffffff
    def initialize(value: 0)
      @value = Util.uint32!(value, 'value')
      freeze
    end

    # Canale RGB opaco (+NCCHANNEL_INITIALIZER+).
    #
    # @param r [Integer] 0..255
    # @param g [Integer] 0..255
    # @param b [Integer] 0..255
    # @return [Channel]
    # @raise [TypeError] se un componente non è Integer
    # @raise [ArgumentError] se un componente è fuori da 0..255
    def self.rgb(r, g, b)
      Util.uint8!(r, 'r')
      Util.uint8!(g, 'g')
      Util.uint8!(b, 'b')
      new(value: FFI.NCCHANNEL_INITIALIZER(r, g, b))
    end

    # Canale RGB opaco da un valore 0xRRGGBB.
    #
    # @param rgb [Integer] 0..0xffffff
    # @return [Channel]
    # @raise [TypeError, ArgumentError] se rgb non è un Integer in 0..0xffffff
    def self.rgb24(rgb) = new.with_rgb24(rgb)

    # Canale con indice di palette.
    #
    # @param index [Integer] 0..255
    # @return [Channel]
    # @raise [TypeError, ArgumentError] se index non è un Integer in 0..255
    def self.palindex(index) = new.with_palindex(index)

    # Canale con il colore di default del terminale (valore 0).
    # @return [Channel]
    def self.default = new

    # @return [Integer] componente rossa, 0..255 (+ncchannel_r+)
    def r = FFI.ncchannel_r(@value)

    # @return [Integer] componente verde, 0..255 (+ncchannel_g+)
    def g = FFI.ncchannel_g(@value)

    # @return [Integer] componente blu, 0..255 (+ncchannel_b+)
    def b = FFI.ncchannel_b(@value)

    # @return [Array(Integer, Integer, Integer)] [r, g, b] (+ncchannel_rgb8+)
    def rgb
      ptrs = Array.new(3) { ::FFI::MemoryPointer.new(:uint) }
      FFI.ncchannel_rgb8(@value, *ptrs)
      ptrs.map(&:read_uint)
    end

    # @return [Integer] colore come 0xRRGGBB (+ncchannel_rgb+)
    def rgb24 = FFI.ncchannel_rgb(@value)

    # @return [Symbol] :opaque, :blend, :transparent o :highcontrast (+ncchannel_alpha+)
    def alpha = Util.alpha_symbol(FFI.ncchannel_alpha(@value))

    # @return [Integer] indice di palette, 0..255; ha senso solo se {#palindex?} (+ncchannel_palindex+)
    def palindex = FFI.ncchannel_palindex(@value)

    # @return [Boolean] true se il canale usa il colore di default (+ncchannel_default_p+)
    def default? = FFI.ncchannel_default_p(@value)

    # @return [Boolean] true se il canale usa un indice di palette (+ncchannel_palindex_p+)
    def palindex? = FFI.ncchannel_palindex_p(@value)

    # @return [Boolean] true se il canale usa un colore RGB (+ncchannel_rgb_p+)
    def rgb? = FFI.ncchannel_rgb_p(@value)

    # Nuovo canale con colore RGB; alpha invariata (+ncchannel_set_rgb8+).
    #
    # @param r [Integer] 0..255
    # @param g [Integer] 0..255
    # @param b [Integer] 0..255
    # @return [Channel]
    # @raise [TypeError] se un componente non è Integer
    # @raise [ArgumentError] se un componente è fuori da 0..255
    def with_rgb(r, g, b)
      Util.uint8!(r, 'r')
      Util.uint8!(g, 'g')
      Util.uint8!(b, 'b')
      update { |ptr| Util.check!(FFI.ncchannel_set_rgb8(ptr, r, g, b), ArgumentError, 'ncchannel_set_rgb8') }
    end

    # Nuovo canale con colore RGB 0xRRGGBB (+ncchannel_set+).
    #
    # @param rgb [Integer] 0..0xffffff
    # @return [Channel]
    # @raise [TypeError] se rgb non è Integer
    # @raise [ArgumentError] se rgb è fuori da 0..0xffffff
    def with_rgb24(rgb)
      Util.integer!(rgb, 'rgb', 0..0xffffff)
      update { |ptr| Util.check!(FFI.ncchannel_set(ptr, rgb), ArgumentError, 'ncchannel_set') }
    end

    # Nuovo canale con colore RGB, componenti limitati a 0..255
    # (+ncchannel_set_rgb8_clipped+).
    #
    # @param r [Integer] qualsiasi int; < 0 diventa 0, > 255 diventa 255
    # @param g [Integer] come r
    # @param b [Integer] come r
    # @return [Channel]
    # @raise [TypeError, ArgumentError] se un componente non è un int del C
    def with_rgb_clipped(r, g, b)
      Util.int!(r, 'r')
      Util.int!(g, 'g')
      Util.int!(b, 'b')
      update { |ptr| FFI.ncchannel_set_rgb8_clipped(ptr, r, g, b) }
    end

    # Nuovo canale con un'altra alpha (+ncchannel_set_alpha+). Un'alpha
    # diversa da :opaque marca anche il canale come non default.
    #
    # @param alpha [Symbol, Integer] :opaque, :blend, :transparent,
    #   :highcontrast, o una costante NCALPHA_*
    # @return [Channel]
    # @raise [ArgumentError] se alpha non è valida
    def with_alpha(alpha)
      a = Util.alpha_value(alpha)
      update { |ptr| Util.check!(FFI.ncchannel_set_alpha(ptr, a), ArgumentError, 'ncchannel_set_alpha') }
    end

    # Nuovo canale con un indice di palette; alpha opaca (+ncchannel_set_palindex+).
    #
    # @param index [Integer] 0..255
    # @return [Channel]
    # @raise [TypeError, ArgumentError] se index non è un Integer in 0..255
    def with_palindex(index)
      Util.integer!(index, 'index', 0...FFI::NCPALETTESIZE)
      update { |ptr| Util.check!(FFI.ncchannel_set_palindex(ptr, index), ArgumentError, 'ncchannel_set_palindex') }
    end

    # Nuovo canale con il colore di default; alpha opaca (+ncchannel_set_default+).
    # @return [Channel]
    def with_default = update { |ptr| FFI.ncchannel_set_default(ptr) }

    # @param other [Object] oggetto da confrontare
    # @return [Boolean]
    def ==(other) = other.is_a?(Channel) && other.value == @value
    alias eql? ==

    # @return [Integer]
    def hash = [Channel, @value].hash

    # @return [String]
    def inspect
      mode = if default? then 'default'
             elsif palindex? then "palindex=#{palindex}"
             else format('rgb=%06x', rgb24)
             end
      format('#<Notcurses::Channel 0x%<v>08x %<mode>s alpha=%<a>s>', v: @value, mode: mode, a: alpha)
    end

    private

    # Applica un'inline che modifica un uint32_t* e restituisce il nuovo canale.
    def update
      ptr = ::FFI::MemoryPointer.new(:uint32)
      ptr.write_uint32(@value)
      yield ptr
      Channel.new(value: ptr.read_uint32)
    end
  end

  # Coppia di canali a 64 bit (+uint64_t+ del C): primo piano nei 32 bit alti,
  # sfondo nei 32 bit bassi.
  #
  # Value object immutabile: i metodi +with_*+ restituiscono un nuovo Channels.
  #
  # @example
  #   ch = Notcurses::Channels.combine(Notcurses::Channel.rgb(255, 255, 255),
  #                                    Notcurses::Channel.rgb(0, 0, 64))
  #   ch.fg.rgb  #=> [255, 255, 255]
  class Channels
    # @return [Integer] valore a 64 bit
    attr_reader :value
    alias to_i value

    # @param value [Integer] valore a 64 bit (0 = entrambi i canali di default)
    # @raise [TypeError] se value non è Integer
    # @raise [ArgumentError] se value è fuori da 0..0xffffffffffffffff
    def initialize(value: 0)
      @value = Util.uint64!(value, 'value')
      freeze
    end

    # Coppia di canali da primo piano e sfondo (+ncchannels_combine+).
    #
    # @param fg [Channel] primo piano
    # @param bg [Channel] sfondo
    # @return [Channels]
    # @raise [TypeError] se fg o bg non sono Channel
    def self.combine(fg, bg)
      raise TypeError, "fg deve essere Notcurses::Channel, non #{fg.class}" unless fg.is_a?(Channel)
      raise TypeError, "bg deve essere Notcurses::Channel, non #{bg.class}" unless bg.is_a?(Channel)

      new(value: FFI.ncchannels_combine(fg.value, bg.value))
    end

    # Coppia di canali RGB opachi (+NCCHANNELS_INITIALIZER+).
    #
    # @param fr [Integer] rosso del primo piano, 0..255
    # @param fg [Integer] verde del primo piano, 0..255
    # @param fb [Integer] blu del primo piano, 0..255
    # @param br [Integer] rosso dello sfondo, 0..255
    # @param bg [Integer] verde dello sfondo, 0..255
    # @param bb [Integer] blu dello sfondo, 0..255
    # @return [Channels]
    # @raise [TypeError, ArgumentError] se un componente non è un Integer in 0..255
    def self.rgb(fr, fg, fb, br, bg, bb)
      { fr: fr, fg: fg, fb: fb, br: br, bg: bg, bb: bb }.each { |name, v| Util.uint8!(v, name.to_s) }
      new(value: FFI.NCCHANNELS_INITIALIZER(fr, fg, fb, br, bg, bb))
    end

    # @return [Channel] canale di primo piano (+ncchannels_fchannel+)
    def fg = Channel.new(value: FFI.ncchannels_fchannel(@value))

    # @return [Channel] canale di sfondo (+ncchannels_bchannel+)
    def bg = Channel.new(value: FFI.ncchannels_bchannel(@value))

    # Solo i bit di colore e alpha dei due canali, senza i bit di servizio
    # (+ncchannels_channels+).
    # @return [Channels]
    def masked = Channels.new(value: FFI.ncchannels_channels(@value))

    # Primo piano e sfondo scambiati, senza toccare i bit di servizio; l'alpha
    # che diventerebbe illegale passa a :opaque (+ncchannels_reverse+).
    # @return [Channels]
    def reverse = Channels.new(value: FFI.ncchannels_reverse(@value))

    # @return [Array(Integer, Integer, Integer)] [r, g, b] del primo piano (+ncchannels_fg_rgb8+)
    def fg_rgb = rgb8_of { |ptrs| FFI.ncchannels_fg_rgb8(@value, *ptrs) }

    # @return [Array(Integer, Integer, Integer)] [r, g, b] dello sfondo (+ncchannels_bg_rgb8+)
    def bg_rgb = rgb8_of { |ptrs| FFI.ncchannels_bg_rgb8(@value, *ptrs) }

    # @return [Integer] primo piano come 0xRRGGBB (+ncchannels_fg_rgb+)
    def fg_rgb24 = FFI.ncchannels_fg_rgb(@value)

    # @return [Integer] sfondo come 0xRRGGBB (+ncchannels_bg_rgb+)
    def bg_rgb24 = FFI.ncchannels_bg_rgb(@value)

    # @return [Symbol] alpha del primo piano (+ncchannels_fg_alpha+)
    def fg_alpha = Util.alpha_symbol(FFI.ncchannels_fg_alpha(@value))

    # @return [Symbol] alpha dello sfondo (+ncchannels_bg_alpha+)
    def bg_alpha = Util.alpha_symbol(FFI.ncchannels_bg_alpha(@value))

    # @return [Integer] indice di palette del primo piano (+ncchannels_fg_palindex+)
    def fg_palindex = FFI.ncchannels_fg_palindex(@value)

    # @return [Integer] indice di palette dello sfondo (+ncchannels_bg_palindex+)
    def bg_palindex = FFI.ncchannels_bg_palindex(@value)

    # @return [Boolean] (+ncchannels_fg_default_p+)
    def fg_default? = FFI.ncchannels_fg_default_p(@value)

    # @return [Boolean] (+ncchannels_bg_default_p+)
    def bg_default? = FFI.ncchannels_bg_default_p(@value)

    # @return [Boolean] (+ncchannels_fg_palindex_p+)
    def fg_palindex? = FFI.ncchannels_fg_palindex_p(@value)

    # @return [Boolean] (+ncchannels_bg_palindex_p+)
    def bg_palindex? = FFI.ncchannels_bg_palindex_p(@value)

    # @return [Boolean] (+ncchannels_fg_rgb_p+)
    def fg_rgb? = FFI.ncchannels_fg_rgb_p(@value)

    # @return [Boolean] (+ncchannels_bg_rgb_p+)
    def bg_rgb? = FFI.ncchannels_bg_rgb_p(@value)

    # Nuova coppia con un altro canale di primo piano (+ncchannels_set_fchannel+).
    #
    # @param channel [Channel]
    # @return [Channels]
    # @raise [TypeError] se channel non è Channel
    def with_fg(channel) = update { |ptr| FFI.ncchannels_set_fchannel(ptr, channel_value(channel)) }

    # Nuova coppia con un altro canale di sfondo (+ncchannels_set_bchannel+).
    #
    # @param channel [Channel]
    # @return [Channels]
    # @raise [TypeError] se channel non è Channel
    def with_bg(channel) = update { |ptr| FFI.ncchannels_set_bchannel(ptr, channel_value(channel)) }

    # Nuova coppia con i bit di colore e alpha di other; i bit di servizio di
    # questa coppia restano (+ncchannels_set_channels+).
    #
    # @param other [Channels]
    # @return [Channels]
    # @raise [TypeError] se other non è Channels
    def with_channels(other)
      raise TypeError, "other deve essere Notcurses::Channels, non #{other.class}" unless other.is_a?(Channels)

      update { |ptr| FFI.ncchannels_set_channels(ptr, other.value) }
    end

    # Primo piano RGB (+ncchannels_set_fg_rgb8+).
    #
    # @param r [Integer] 0..255
    # @param g [Integer] 0..255
    # @param b [Integer] 0..255
    # @return [Channels]
    # @raise [TypeError, ArgumentError] se un componente non è un Integer in 0..255
    def with_fg_rgb(r, g, b)
      rgb8!(r, g, b)
      update { |ptr| Util.check!(FFI.ncchannels_set_fg_rgb8(ptr, r, g, b), ArgumentError, 'ncchannels_set_fg_rgb8') }
    end

    # Sfondo RGB (+ncchannels_set_bg_rgb8+).
    #
    # @param r [Integer] 0..255
    # @param g [Integer] 0..255
    # @param b [Integer] 0..255
    # @return [Channels]
    # @raise [TypeError, ArgumentError] se un componente non è un Integer in 0..255
    def with_bg_rgb(r, g, b)
      rgb8!(r, g, b)
      update { |ptr| Util.check!(FFI.ncchannels_set_bg_rgb8(ptr, r, g, b), ArgumentError, 'ncchannels_set_bg_rgb8') }
    end

    # Primo piano 0xRRGGBB (+ncchannels_set_fg_rgb+).
    #
    # @param rgb [Integer] 0..0xffffff
    # @return [Channels]
    # @raise [TypeError, ArgumentError] se rgb non è un Integer in 0..0xffffff
    def with_fg_rgb24(rgb)
      Util.integer!(rgb, 'rgb', 0..0xffffff)
      update { |ptr| Util.check!(FFI.ncchannels_set_fg_rgb(ptr, rgb), ArgumentError, 'ncchannels_set_fg_rgb') }
    end

    # Sfondo 0xRRGGBB (+ncchannels_set_bg_rgb+).
    #
    # @param rgb [Integer] 0..0xffffff
    # @return [Channels]
    # @raise [TypeError, ArgumentError] se rgb non è un Integer in 0..0xffffff
    def with_bg_rgb24(rgb)
      Util.integer!(rgb, 'rgb', 0..0xffffff)
      update { |ptr| Util.check!(FFI.ncchannels_set_bg_rgb(ptr, rgb), ArgumentError, 'ncchannels_set_bg_rgb') }
    end

    # Primo piano RGB con componenti limitati a 0..255 (+ncchannels_set_fg_rgb8_clipped+).
    #
    # @param r [Integer] int del C
    # @param g [Integer] int del C
    # @param b [Integer] int del C
    # @return [Channels]
    # @raise [TypeError, ArgumentError] se un componente non è un int del C
    def with_fg_rgb_clipped(r, g, b)
      int3!(r, g, b)
      update { |ptr| FFI.ncchannels_set_fg_rgb8_clipped(ptr, r, g, b) }
    end

    # Sfondo RGB con componenti limitati a 0..255 (+ncchannels_set_bg_rgb8_clipped+).
    #
    # @param r [Integer] int del C
    # @param g [Integer] int del C
    # @param b [Integer] int del C
    # @return [Channels]
    # @raise [TypeError, ArgumentError] se un componente non è un int del C
    def with_bg_rgb_clipped(r, g, b)
      int3!(r, g, b)
      update { |ptr| FFI.ncchannels_set_bg_rgb8_clipped(ptr, r, g, b) }
    end

    # Alpha del primo piano (+ncchannels_set_fg_alpha+).
    #
    # @param alpha [Symbol, Integer] :opaque, :blend, :transparent, :highcontrast
    # @return [Channels]
    # @raise [ArgumentError] se alpha non è valida
    def with_fg_alpha(alpha)
      a = Util.alpha_value(alpha)
      update { |ptr| Util.check!(FFI.ncchannels_set_fg_alpha(ptr, a), ArgumentError, 'ncchannels_set_fg_alpha') }
    end

    # Alpha dello sfondo (+ncchannels_set_bg_alpha+). Lo sfondo non ammette
    # :highcontrast.
    #
    # @param alpha [Symbol, Integer] :opaque, :blend, :transparent
    # @return [Channels]
    # @raise [ArgumentError] se alpha non è valida o è :highcontrast
    def with_bg_alpha(alpha)
      a = Util.alpha_value(alpha)
      raise ArgumentError, "alpha :highcontrast non è ammessa per lo sfondo" if a == FFI::NCALPHA_HIGHCONTRAST

      update { |ptr| Util.check!(FFI.ncchannels_set_bg_alpha(ptr, a), ArgumentError, 'ncchannels_set_bg_alpha') }
    end

    # Indice di palette del primo piano (+ncchannels_set_fg_palindex+).
    #
    # @param index [Integer] 0..255
    # @return [Channels]
    # @raise [TypeError, ArgumentError] se index non è un Integer in 0..255
    def with_fg_palindex(index)
      Util.integer!(index, 'index', 0...FFI::NCPALETTESIZE)
      update { |ptr| Util.check!(FFI.ncchannels_set_fg_palindex(ptr, index), ArgumentError, 'ncchannels_set_fg_palindex') }
    end

    # Indice di palette dello sfondo (+ncchannels_set_bg_palindex+).
    #
    # @param index [Integer] 0..255
    # @return [Channels]
    # @raise [TypeError, ArgumentError] se index non è un Integer in 0..255
    def with_bg_palindex(index)
      Util.integer!(index, 'index', 0...FFI::NCPALETTESIZE)
      update { |ptr| Util.check!(FFI.ncchannels_set_bg_palindex(ptr, index), ArgumentError, 'ncchannels_set_bg_palindex') }
    end

    # Primo piano con il colore di default (+ncchannels_set_fg_default+).
    # @return [Channels]
    def with_fg_default = update { |ptr| FFI.ncchannels_set_fg_default(ptr) }

    # Sfondo con il colore di default (+ncchannels_set_bg_default+).
    # @return [Channels]
    def with_bg_default = update { |ptr| FFI.ncchannels_set_bg_default(ptr) }

    # @param other [Object] oggetto da confrontare
    # @return [Boolean]
    def ==(other) = other.is_a?(Channels) && other.value == @value
    alias eql? ==

    # @return [Integer]
    def hash = [Channels, @value].hash

    # @return [String]
    def inspect = format('#<Notcurses::Channels 0x%<v>016x fg=%<fg>s bg=%<bg>s>', v: @value, fg: fg.inspect, bg: bg.inspect)

    private

    def update
      ptr = ::FFI::MemoryPointer.new(:uint64)
      ptr.write_uint64(@value)
      yield ptr
      Channels.new(value: ptr.read_uint64)
    end

    def rgb8_of
      ptrs = Array.new(3) { ::FFI::MemoryPointer.new(:uint) }
      yield ptrs
      ptrs.map(&:read_uint)
    end

    def channel_value(channel)
      raise TypeError, "channel deve essere Notcurses::Channel, non #{channel.class}" unless channel.is_a?(Channel)

      channel.value
    end

    def rgb8!(r, g, b)
      Util.uint8!(r, 'r')
      Util.uint8!(g, 'g')
      Util.uint8!(b, 'b')
    end

    def int3!(r, g, b)
      Util.int!(r, 'r')
      Util.int!(g, 'g')
      Util.int!(b, 'b')
    end
  end
end
