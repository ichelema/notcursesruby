# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative '../support/nc_helpers'

RSpec.describe Notcurses::Palette do
  include_context 'con un contesto notcurses'

  it 'copia la palette del contesto (senza tty tutte le voci sono 0)' do
    pal = described_class.new(nc)
    expect(pal.size).to eq(256)
    expect(pal.context).to equal(nc)
    expect(pal.to_a.size).to eq(256)
    expect(pal[0]).to eq(0)
    pal.close
  end

  it 'imposta e legge le voci' do
    pal = nc.palette
    pal[1] = 0x123456
    expect(pal[1]).to eq(0x123456)
    expect(pal.rgb(1)).to eq([0x12, 0x34, 0x56])
    expect(pal.set_rgb(2, 255, 128, 0)).to equal(pal)
    expect(pal[2]).to eq(0xff8000)
    expect(pal.rgb(2)).to eq([255, 128, 0])
    pal.close
  end

  it 'rifiuta indici e componenti fuori intervallo (il C accetta 256: heap overflow)' do
    pal = nc.palette
    expect { pal[256] }.to raise_error(ArgumentError)
    expect { pal[-1] }.to raise_error(ArgumentError)
    expect { pal[256] = 0 }.to raise_error(ArgumentError)
    expect { pal[0] = 0x1000000 }.to raise_error(ArgumentError)
    expect { pal.set_rgb(256, 0, 0, 0) }.to raise_error(ArgumentError)
    expect { pal.set_rgb(0, 256, 0, 0) }.to raise_error(ArgumentError)
    expect { pal.rgb(256) }.to raise_error(ArgumentError)
    expect { pal['1'] }.to raise_error(TypeError)
    pal.close
  end

  it 'use installa la palette (xterm-256color può cambiare i colori)' do
    pal = nc.palette
    pal.set_rgb(3, 1, 2, 3)
    expect(pal.use).to equal(pal)
    nc.render
    pal.close
  end

  it 'close è idempotente; dopo close i metodi sollevano ClosedError; open con un blocco' do
    pal = nc.palette
    expect(pal.close).to be_nil
    expect(pal.free).to be_nil
    expect(pal).to be_closed
    expect { pal[0] }.to raise_error(Notcurses::ClosedError)
    expect { pal.use }.to raise_error(Notcurses::ClosedError)
    value = described_class.open(nc) { |p| p.size }
    expect(value).to eq(256)
  end

  it 'rifiuta un contesto non valido' do
    expect { described_class.new(:nc) }.to raise_error(TypeError)
  end
end
