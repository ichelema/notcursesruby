# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative '../../support/nc_helpers'

RSpec.describe Notcurses::UI::Label do
  include_context 'con un contesto notcurses'

  let(:app) { Notcurses::UI::App.new(nc) }

  after { app.close }

  # Riga di 'rows' righe in root, per dare al componente rows x cols.
  def row(rows) = Notcurses::UI::Container.new(app.root, direction: :horizontal, size: rows)

  def lines(component) = Array.new(component.plane.dim_y) { |y| component.plane.contents(y: y, rows: 1) }

  it 'una riga del piano per ogni riga del testo, tagliata alla larghezza; le righe in più non si vedono' do
    label = described_class.new(row(2), text: "uno\nabcd漢字\ntre", size: 6)
    expect(label.plane.dims).to eq([2, 6])
    expect(lines(label)).to eq(%w[uno abcd漢]) # 字 non entra: servirebbero 8 colonne
    expect(label.text).to eq("uno\nabcd漢字\ntre")
    expect(label.align).to eq(:left)
    expect(label).not_to be_focusable
  end

  it 'align: :center e :right allineano ogni riga nella larghezza' do
    center = described_class.new(row(1), text: 'ab', align: :center, size: 6)
    right = described_class.new(row(1), text: '漢', align: :right, size: 5)
    expect(center.plane.contents(y: 0, rows: 1, x: 2, cols: 2)).to eq('ab')
    expect(center.plane.at(y: 0, x: 1).egc).to eq(' ') # cella base
    expect(right.plane.at(y: 0, x: 3).egc).to eq('漢')
  end

  it 'taglia e allinea il testo con una sequenza ZWJ' do
    dev = [0x1F469, 0x200D, 0x1F4BB].pack('U*') # un grapheme: 2 colonne
    left = described_class.new(row(1), text: "#{dev} sviluppatrice molto brava", size: 10)
    right = described_class.new(row(1), text: "#{dev}ab", align: :right, size: 10)
    expect(lines(left)).to eq(["#{dev} svilupp"])
    expect(right.plane.at(y: 0, x: 6).egc).to eq(dev)
    expect(right.plane.at(y: 0, x: 9).egc).to eq('b')
  end

  it 'scrive con gli stili e i colori dati; lo sfondo vuoto usa gli stessi colori' do
    channels = Notcurses::Channels.rgb(255, 0, 0, 0, 0, 255)
    label = described_class.new(row(1), text: 'x', styles: [:bold], channels: channels, size: 3)
    cell = label.plane.at(y: 0, x: 0)
    expect(cell.styles).to eq([:bold])
    expect(cell.channels).to eq(channels)
    expect(label.plane.base.channels).to eq(channels)
  end

  it 'text= ridisegna; il testo è una copia, e un testo non ammesso solleva subito' do
    label = described_class.new(row(1), text: 'prima', size: 10)
    source = +'dopo'
    label.text = source
    source << '!'
    expect(label.text).to eq('dopo')
    expect(label.plane.contents(y: 0, rows: 1)).to eq('dopo')
    ["a\tb", "a\u0001", "a ", "́a", "a​b", "a\xffb".b].each do |bad|
      expect { label.text = bad }.to raise_error(ArgumentError), bad.inspect
    end
    expect { label.text = :x }.to raise_error(TypeError)
    expect(label.text).to eq('dopo')
    expect { described_class.new(app.root, text: 'x', align: :middle) }.to raise_error(ArgumentError)
    expect { described_class.new(app.root, text: "a\x01") }.to raise_error(ArgumentError)
    expect { described_class.new(app.root, styles: :blink) }.to raise_error(ArgumentError)
  end

  it 'un grapheme che notcurses 3.0.17 divide diversamente da Ruby (keycap) diventa "?" senza errori' do
    label = described_class.new(row(1), text: "1️⃣ ok", size: 6)
    expect(label.plane.contents(y: 0, rows: 1)).to eq('? ok')
  end

  it 'chiuso: text= e plane sollevano ClosedError' do
    label = described_class.new(row(1), text: 'x', size: 3)
    label.close
    expect { label.text = 'y' }.to raise_error(Notcurses::ClosedError)
    expect { label.plane }.to raise_error(Notcurses::ClosedError)
  end
end
