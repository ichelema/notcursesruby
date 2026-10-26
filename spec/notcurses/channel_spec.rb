# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require 'notcurses'

RSpec.describe Notcurses::Channel do
  let(:rng) { Random.new(20_261_025) }

  # Valore dell'inline FFI che modifica un uint32_t*.
  def ffi_set32(value)
    ptr = ::FFI::MemoryPointer.new(:uint32)
    ptr.write_uint32(value)
    yield ptr
    ptr.read_uint32
  end

  describe '.new' do
    it 'accetta 0..0xffffffff e congela il valore' do
      c = described_class.new(value: 0xffff_ffff)
      expect(c.value).to eq(0xffff_ffff)
      expect(c).to be_frozen
      expect(described_class.new.value).to eq(0)
    end

    it 'rifiuta valori fuori range invece di troncarli' do
      expect { described_class.new(value: 0x1_0000_0000) }.to raise_error(ArgumentError)
      expect { described_class.new(value: -1) }.to raise_error(ArgumentError)
    end

    it 'rifiuta tipi non interi' do
      expect { described_class.new(value: 1.0) }.to raise_error(TypeError)
      expect { described_class.new(value: nil) }.to raise_error(TypeError)
      expect { described_class.new(value: '1') }.to raise_error(TypeError)
    end
  end

  describe '.rgb' do
    it 'costruisce un canale RGB opaco come NCCHANNEL_INITIALIZER' do
      c = described_class.rgb(255, 136, 0)
      expect(c.value).to eq(Notcurses::FFI.NCCHANNEL_INITIALIZER(255, 136, 0))
      expect(c.rgb).to eq([255, 136, 0])
      expect([c.r, c.g, c.b]).to eq([255, 136, 0])
      expect(c.rgb24).to eq(0xff8800)
      expect(c.alpha).to eq(:opaque)
      expect(c).to be_rgb
      expect(c).not_to be_default
      expect(c).not_to be_palindex
    end

    it 'rifiuta componenti fuori da 0..255' do
      expect { described_class.rgb(256, 0, 0) }.to raise_error(ArgumentError, /r = 256/)
      expect { described_class.rgb(0, -1, 0) }.to raise_error(ArgumentError, /g = -1/)
      expect { described_class.rgb(0, 0, 1.5) }.to raise_error(TypeError, /b deve essere Integer/)
    end
  end

  it '.rgb24, .palindex e .default' do
    expect(described_class.rgb24(0x123456).rgb).to eq([0x12, 0x34, 0x56])
    expect { described_class.rgb24(0x1000000) }.to raise_error(ArgumentError)
    pal = described_class.palindex(42)
    expect(pal).to be_palindex
    expect(pal.palindex).to eq(42)
    expect { described_class.palindex(256) }.to raise_error(ArgumentError)
    expect(described_class.default).to be_default
    expect(described_class.default.value).to eq(0)
  end

  it 'i metodi with_* restituiscono un nuovo canale e lasciano invariato il ricevente' do
    c = described_class.rgb(1, 2, 3)
    blended = c.with_alpha(:blend)
    expect(blended.alpha).to eq(:blend)
    expect(c.alpha).to eq(:opaque)
    expect(c.with_rgb(9, 8, 7).rgb).to eq([9, 8, 7])
    expect(c.with_rgb24(0xabcdef).rgb24).to eq(0xabcdef)
    expect(c.with_rgb_clipped(-5, 300, 7).rgb).to eq([0, 255, 7])
    expect(c.with_default).to be_default
    expect(c.with_palindex(7).palindex).to eq(7)
    expect(c.with_alpha(Notcurses::FFI::NCALPHA_TRANSPARENT).alpha).to eq(:transparent)
    expect { c.with_alpha(:nope) }.to raise_error(ArgumentError, /alpha/)
    expect { c.with_alpha(0x1234) }.to raise_error(ArgumentError)
  end

  it 'coincide con le inline FFI su valori casuali' do
    200.times do
      v = rng.rand(0x1_0000_0000)
      r = rng.rand(256)
      g = rng.rand(256)
      b = rng.rand(256)
      c = described_class.new(value: v)
      expect(c.with_rgb(r, g, b).value).to eq(ffi_set32(v) { |p| Notcurses::FFI.ncchannel_set_rgb8(p, r, g, b) })
      expect(c.with_alpha(:highcontrast).value).to eq(ffi_set32(v) { |p| Notcurses::FFI.ncchannel_set_alpha(p, Notcurses::FFI::NCALPHA_HIGHCONTRAST) })
      expect(c.with_default.value).to eq(ffi_set32(v) { |p| Notcurses::FFI.ncchannel_set_default(p) })
      expect(c.alpha).to eq(Notcurses::Util.alpha_symbol(Notcurses::FFI.ncchannel_alpha(v)))
      expect(c.default?).to eq(Notcurses::FFI.ncchannel_default_p(v))
    end
  end

  it 'uguaglianza e hash per valore' do
    a = described_class.rgb(1, 2, 3)
    b = described_class.rgb(1, 2, 3)
    expect(a).to eq(b)
    expect(a).to eql(b)
    expect(a.hash).to eq(b.hash)
    expect({ a => 1 }[b]).to eq(1)
    expect(a).not_to eq(described_class.rgb(1, 2, 4))
    expect(a).not_to eq(a.value)
  end

  it '#inspect descrive modalità e alpha' do
    expect(described_class.rgb(255, 0, 0).inspect).to include('rgb=ff0000', 'alpha=opaque')
    expect(described_class.palindex(3).inspect).to include('palindex=3')
    expect(described_class.default.inspect).to include('default')
  end
end

RSpec.describe Notcurses::Channels do
  let(:white) { Notcurses::Channel.rgb(255, 255, 255) }
  let(:navy) { Notcurses::Channel.rgb(0, 0, 64) }

  def ffi_set64(value)
    ptr = ::FFI::MemoryPointer.new(:uint64)
    ptr.write_uint64(value)
    yield ptr
    ptr.read_uint64
  end

  it '.combine e i canali fg/bg' do
    ch = described_class.combine(white, navy)
    expect(ch.value).to eq(Notcurses::FFI.ncchannels_combine(white.value, navy.value))
    expect(ch.fg).to eq(white)
    expect(ch.bg).to eq(navy)
    expect(ch.fg_rgb).to eq([255, 255, 255])
    expect(ch.bg_rgb).to eq([0, 0, 64])
    expect(ch.fg_rgb24).to eq(0xffffff)
    expect(ch.bg_rgb24).to eq(0x000040)
    expect { described_class.combine(1, navy) }.to raise_error(TypeError)
  end

  it '.rgb come NCCHANNELS_INITIALIZER' do
    ch = described_class.rgb(1, 2, 3, 4, 5, 6)
    expect(ch.value).to eq(Notcurses::FFI.NCCHANNELS_INITIALIZER(1, 2, 3, 4, 5, 6))
    expect(ch.fg_rgb).to eq([1, 2, 3])
    expect(ch.bg_rgb).to eq([4, 5, 6])
    expect { described_class.rgb(1, 2, 3, 4, 5, 256) }.to raise_error(ArgumentError, /bb/)
  end

  it '.new valida il range a 64 bit' do
    expect(described_class.new(value: 0xffff_ffff_ffff_ffff).value).to eq(0xffff_ffff_ffff_ffff)
    expect { described_class.new(value: 0x1_0000_0000_0000_0000) }.to raise_error(ArgumentError)
    expect { described_class.new(value: -1) }.to raise_error(ArgumentError)
    expect(described_class.new).to be_frozen
  end

  it 'setter di primo piano e sfondo' do
    ch = described_class.new
    expect(ch.with_fg_rgb(1, 2, 3).fg_rgb).to eq([1, 2, 3])
    expect(ch.with_bg_rgb(4, 5, 6).bg_rgb).to eq([4, 5, 6])
    expect(ch.with_fg_rgb24(0x010203).fg_rgb).to eq([1, 2, 3])
    expect(ch.with_bg_rgb24(0x040506).bg_rgb).to eq([4, 5, 6])
    expect(ch.with_fg_rgb_clipped(-1, 999, 5).fg_rgb).to eq([0, 255, 5])
    expect(ch.with_bg_rgb_clipped(999, -9, 5).bg_rgb).to eq([255, 0, 5])
    expect(ch.with_fg_alpha(:blend).fg_alpha).to eq(:blend)
    expect(ch.with_bg_alpha(:transparent).bg_alpha).to eq(:transparent)
    expect(ch.with_fg_alpha(:highcontrast).fg_alpha).to eq(:highcontrast)
    expect { ch.with_bg_alpha(:highcontrast) }.to raise_error(ArgumentError, /sfondo/)
    expect(ch.with_fg_palindex(9)).to be_fg_palindex
    expect(ch.with_bg_palindex(9).bg_palindex).to eq(9)
    expect(ch.with_fg(white).fg).to eq(white)
    expect(ch.with_bg(navy).bg).to eq(navy)
    expect(ch.with_fg_rgb(1, 1, 1).with_fg_default).to be_fg_default
    expect(ch.with_bg_rgb(1, 1, 1).with_bg_default).to be_bg_default
    expect(ch.with_fg_rgb(1, 1, 1)).to be_fg_rgb
    expect(ch.with_bg_rgb(1, 1, 1)).to be_bg_rgb
    expect { ch.with_fg(1) }.to raise_error(TypeError)
    expect { ch.with_fg_palindex(256) }.to raise_error(ArgumentError)
  end

  it 'reverse, masked e with_channels coincidono con le inline FFI' do
    rng = Random.new(7)
    100.times do
      v = rng.rand(0x1_0000_0000_0000_0000)
      w = rng.rand(0x1_0000_0000_0000_0000)
      ch = described_class.new(value: v)
      expect(ch.reverse.value).to eq(Notcurses::FFI.ncchannels_reverse(v))
      expect(ch.masked.value).to eq(Notcurses::FFI.ncchannels_channels(v))
      expect(ch.with_channels(described_class.new(value: w)).value).to eq(ffi_set64(v) { |p| Notcurses::FFI.ncchannels_set_channels(p, w) })
      expect(ch.with_fg_default.value).to eq(ffi_set64(v) { |p| Notcurses::FFI.ncchannels_set_fg_default(p) })
    end
  end

  it 'uguaglianza e hash per valore' do
    expect(described_class.combine(white, navy)).to eq(described_class.combine(white, navy))
    expect(described_class.combine(white, navy).hash).to eq(described_class.combine(white, navy).hash)
    expect(described_class.combine(white, navy)).not_to eq(described_class.combine(navy, white))
  end
end
