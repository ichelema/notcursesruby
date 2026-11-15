# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative '../support/nc_helpers'

RSpec.describe Notcurses::FadeContext do
  include_context 'con un contesto notcurses'

  before { skip 'il terminale non permette le dissolvenze' unless nc.can_fade? }

  def with_colored_plane
    nc.stdplane.create_child(rows: 1, cols: 5) do |p|
      p.set_fg_rgb24(0xc86432).set_bg_rgb24(0x102030)
      p.putstr('fade', y: 0, x: 0)
      yield p
    end
  end

  it 'Plane#fade_context fotografa i colori; con un blocco restituisce il valore del blocco e libera la fotografia' do
    with_colored_plane do |p|
      kept = nil
      result = p.fade_context do |fc|
        kept = fc
        expect(fc.plane).to equal(p)
        expect(fc.iterations).to eq(200)
        :ok
      end
      expect(result).to eq(:ok)
      expect(kept).to be_closed
      fc = p.fade_context
      expect(fc).to be_a(described_class)
      expect(fc.close).to be_nil
      expect(fc.close).to be_nil
    end
  end

  it 'fadeout e fadein applicano i passi tra i colori fotografati e il nero' do
    with_colored_plane do |p|
      p.fade_context do |fc|
        expect(fc.fadeout(fc.iterations)).to equal(fc)
        expect(p.at(y: 0, x: 0).channels.fg_rgb24).to eq(0)
        fc.fadein(fc.iterations / 2)
        expect(p.at(y: 0, x: 0).channels.fg_rgb).to eq([100, 50, 25])
        fc.fadein(fc.iterations)
        expect(p.at(y: 0, x: 0).channels.fg_rgb24).to eq(0xc86432)
        fc.fadeout(0)
        expect(p.at(y: 0, x: 0).channels.bg_rgb24).to eq(0x102030)
      end
    end
  end

  it 'su un piano che ha fatto scroll i passi colorano le righe giuste (prima: i colori di un\'altra riga, ICH-214)' do
    nc.stdplane.create_child(rows: 3, cols: 2, vscroll: true) do |p|
      [0xc80000, 0x00c800, 0x0000c8, 0x646400].each_with_index do |rgb, i|
        p.set_fg_rgb24(rgb)
        p.putstr(i.zero? ? 'ab' : "\nab") # la quarta riga fa scorrere il piano
      end
      colors = -> { Array.new(3) { |y| p.at(y: y, x: 0).channels.fg_rgb24 } }
      expect(colors.call).to eq([0x00c800, 0x0000c8, 0x646400])
      p.fade_context do |fc|
        fc.fadeout(0)
        expect(colors.call).to eq([0x00c800, 0x0000c8, 0x646400])
        fc.fadein(fc.iterations)
        expect(colors.call).to eq([0x00c800, 0x0000c8, 0x646400])
      end
    end
  end

  it 'rifiuta i passi fuori intervallo e l\'uso dopo close' do
    with_colored_plane do |p|
      fc = p.fade_context
      expect { fc.fadeout(-1) }.to raise_error(ArgumentError)
      expect { fc.fadein(fc.iterations + 1) }.to raise_error(ArgumentError)
      expect { fc.fadein(1.5) }.to raise_error(TypeError)
      fc.close
      expect { fc.fadeout(0) }.to raise_error(Notcurses::ClosedError)
    end
  end

  it 'non sopravvive al piano, e rifiuta ciò che non è un Plane' do
    fc = nil
    with_colored_plane { |p| fc = p.fade_context }
    expect { fc.fadeout(0) }.to raise_error(Notcurses::ClosedError)
    fc.close
    expect { described_class.new(:plane) }.to raise_error(TypeError)
  end
end
