# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative '../support/nc_helpers'

RSpec.describe Notcurses::Cell do
  let(:red) { Notcurses::Channels.rgb(255, 0, 0, 0, 0, 0) }

  describe 'valore Ruby' do
    it 'ha default spazio, nessuno stile, colori di default' do
      cell = described_class.new
      expect([cell.egc, cell.styles, cell.channels, cell.width]).to eq([' ', [], Notcurses::Channels.new, 1])
      expect(cell).to be_frozen
      expect(cell.egc).to be_frozen
      expect(cell.styles).to be_frozen
      expect(cell).not_to be_wide
      expect(cell).not_to be_empty
    end

    it 'accetta un grapheme cluster, un codepoint, stili e colori in più forme' do
      expect(described_class.new('漢').width).to eq(2)
      expect(described_class.new('漢')).to be_wide
      expect(described_class.new(0x41).egc).to eq('A')
      expect(described_class.new("é").width).to eq(1)
      astronaut = "\u{1F469}‍\u{1F680}"
      expect(described_class.new(astronaut).egc).to eq(astronaut)
      empty = described_class.new('')
      expect([empty.width, empty]).to match([0, be_empty])
      expect(described_class.new('a', styles: :bold).styles).to eq([:bold])
      expect(described_class.new('a', styles: %i[bold italic]).styles).to contain_exactly(:bold, :italic)
      expect(described_class.new('a', styles: Notcurses::FFI::NCSTYLE_UNDERLINE).styles).to eq([:underline])
      expect(described_class.new('a', channels: red).channels).to eq(red)
      expect(described_class.new('a', channels: red.value).channels).to eq(red)
    end

    it 'azzera i bit di servizio dei canali' do
      expect(described_class.new('a', channels: 0xffff_ffff_ffff_ffff).channels.value).to eq(0x78ff_ffff_78ff_ffff)
    end

    it 'rifiuta più grapheme, caratteri di controllo e testo non valido' do
      expect { described_class.new('ab') }.to raise_error(ArgumentError)
      expect { described_class.new("\n") }.to raise_error(ArgumentError)
      expect { described_class.new("\t") }.to raise_error(ArgumentError)
      expect { described_class.new("\u0085") }.to raise_error(ArgumentError)
      expect { described_class.new("\xff".b) }.to raise_error(ArgumentError)
      expect { described_class.new("\0") }.to raise_error(ArgumentError)
      expect { described_class.new(:a) }.to raise_error(TypeError)
      expect { described_class.new(0xD800) }.to raise_error(RangeError)
      expect { described_class.new('a', styles: :blink) }.to raise_error(ArgumentError)
      expect { described_class.new('a', channels: 'x') }.to raise_error(TypeError)
    end

    it '==, eql?, hash, with, to_s e inspect' do
      a = described_class.new('x', styles: :bold, channels: red)
      b = described_class.new('x', styles: [:bold], channels: red.value)
      expect(a).to eq(b)
      expect(a).to eql(b)
      expect(a.hash).to eq(b.hash)
      expect({ a => 1 }[b]).to eq(1)
      expect(a).not_to eq(described_class.new('x'))
      expect(a.with(egc: 'y')).to eq(described_class.new('y', styles: :bold, channels: red))
      expect(a.with(styles: []).styles).to eq([])
      expect(a.to_s).to eq('x')
      expect(a.inspect).to include('egc="x"', 'width=1', ':bold')
    end
  end

  describe 'con un piano' do
    include_context 'con un contesto notcurses'

    it 'una Cell scritta con putc torna uguale da Plane#at, anche con un EGC di più di 4 byte' do
      nc.stdplane.create_child(rows: 1, cols: 10) do |p|
        cell = described_class.new("\u{1F469}‍\u{1F680}", styles: :italic, channels: red)
        expect(p.putc(cell, y: 0, x: 0)).to eq(2)
        read = p.at(0, 0)
        expect(read).to eq(cell)
        expect(read.width).to eq(2)
        expect(p.at(0, 1)).to eq(cell) # metà destra: il glifo della metà sinistra
        p.erase
        expect(p.at(0, 0).egc).to eq(p.base.egc)
      end
    end

    it 'solleva CellError quando notcurses divide il grapheme (bandiere)' do
      nc.stdplane.create_child(rows: 1, cols: 10) do |p|
        flag = described_class.new("\u{1F1EE}\u{1F1F9}")
        expect { p.putc(flag, y: 0, x: 0) }.to raise_error(Notcurses::CellError)
        expect(p.contents).to eq('')
      end
    end

    it 'Plane#base restituisce una Cell con la larghezza del C' do
      nc.stdplane.create_child(rows: 1, cols: 3) do |p|
        p.set_base('漢', styles: :bold, channels: red)
        base = p.base
        expect(base).to eq(described_class.new('漢', styles: :bold, channels: red))
        expect(base.width).to eq(2)
      end
    end
  end
end
