# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require 'notcurses'

RSpec.describe Notcurses::Pixel do
  let(:ffi) { Notcurses::FFI }

  it '.rgb costruisce un pixel opaco come ncpixel' do
    px = described_class.rgb(255, 128, 0)
    expect(px.value).to eq(ffi.ncpixel(255, 128, 0))
    expect(px.to_a).to eq([255, 128, 0, 255])
    expect([px.r, px.g, px.b, px.a]).to eq([255, 128, 0, 255])
    expect(px).to be_frozen
  end

  it '.rgba imposta anche l\'alpha' do
    expect(described_class.rgba(1, 2, 3, 4).to_a).to eq([1, 2, 3, 4])
  end

  it 'il layout in memoria è R, G, B, A' do
    px = described_class.rgba(0x11, 0x22, 0x33, 0x44)
    buf = ::FFI::MemoryPointer.new(:uint32)
    buf.write_uint32(px.value)
    expect(buf.read_bytes(4).bytes).to eq([0x11, 0x22, 0x33, 0x44])
  end

  it 'i metodi with_* restituiscono nuovi pixel' do
    px = described_class.rgb(10, 20, 30)
    expect(px.with_r(1).to_a).to eq([1, 20, 30, 255])
    expect(px.with_g(2).to_a).to eq([10, 2, 30, 255])
    expect(px.with_b(3).to_a).to eq([10, 20, 3, 255])
    expect(px.with_a(0).to_a).to eq([10, 20, 30, 0])
    expect(px.with_rgb(7, 8, 9).to_a).to eq([7, 8, 9, 255])
    expect(px.to_a).to eq([10, 20, 30, 255])
  end

  it 'valida i componenti' do
    expect { described_class.rgb(256, 0, 0) }.to raise_error(ArgumentError)
    expect { described_class.rgb(0, 0, -1) }.to raise_error(ArgumentError)
    expect { described_class.rgb(0, 0.5, 0) }.to raise_error(TypeError)
    expect { described_class.rgb(0, 0, 0).with_a(300) }.to raise_error(ArgumentError)
    expect { described_class.new(value: 0x1_0000_0000) }.to raise_error(ArgumentError)
  end

  it 'uguaglianza e hash per valore' do
    expect(described_class.rgb(1, 2, 3)).to eq(described_class.rgb(1, 2, 3))
    expect(described_class.rgb(1, 2, 3).hash).to eq(described_class.rgb(1, 2, 3).hash)
    expect(described_class.rgb(1, 2, 3)).not_to eq(described_class.rgb(1, 2, 4))
  end
end
