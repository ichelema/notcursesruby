# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative '../../support/nc_helpers'

RSpec.describe Notcurses::UI::Container do
  include_context 'con un contesto notcurses'

  let(:app) { Notcurses::UI::App.new(nc) }

  after { app.close }

  def place(component) = [component.plane.yx, component.plane.dims]

  it 'root è un Container verticale grande quanto l\'area di rendering' do
    expect(app.root).to be_a(described_class)
    expect(app.root.direction).to eq(:vertical)
    expect(place(app.root)).to eq([[0, 0], nc.dims])
    expect(app.root.parent).to be_nil
    expect(app.root.app).to equal(app)
    expect(app.root.context).to equal(nc)
  end

  it 'in verticale: prima le dimensioni fisse, poi il resto per peso, nell\'ordine di creazione' do
    a = described_class.new(app.root, size: 3)
    b = described_class.new(app.root)
    c = described_class.new(app.root, weight: 2)
    d = described_class.new(app.root, size: 1)
    expect([a, b, c, d].map { |k| place(k) }).to eq([[[0, 0], [3, 80]], [[3, 0], [6, 80]], [[9, 0], [14, 80]],
                                                     [[23, 0], [1, 80]]])
    expect(app.root.children).to eq([a, b, c, d])
    expect([a, b, c, d].map(&:parent).uniq).to eq([app.root])
  end

  it 'in orizzontale con il bordo: i figli stanno dentro il bordo e prendono tutta l\'altezza' do
    row = described_class.new(app.root, direction: :horizontal, border: true)
    a = described_class.new(row, size: 10)
    b = described_class.new(row)
    expect(row).to be_border
    expect(place(row)).to eq([[0, 0], [24, 80]])
    expect(place(a)).to eq([[1, 1], [22, 10]])
    expect(place(b)).to eq([[1, 11], [22, 68]])
    expect(b.plane.abs_yx).to eq([1, 11])
  end

  it 'il bordo è arrotondato e il titolo sta nel bordo in alto, tagliato alla larghezza' do
    box = described_class.new(app.root, border: true, title: 'Titolo', size: 3)
    expect(box.title).to eq('Titolo')
    expect(box.plane.contents(y: 0, rows: 1, cols: 12)).to eq('╭ Titolo ───')
    expect(box.plane.contents(y: 1, rows: 1, cols: 2)).to eq('│') # contents dà "" per le celle vuote
    expect(box.plane.contents(y: 2, rows: 1, cols: 3)).to eq('╰──')
    small = described_class.new(app.root, direction: :horizontal, size: 3)
    tiny = described_class.new(small, border: true, title: 'Lunghissimo', size: 6)
    expect(tiny.plane.contents(y: 0, rows: 1)).to eq('╭ Lun╮')
  end

  it 'un figlio senza spazio è nascosto: piano 1x1 fuori dallo schermo, anche i suoi figli non sono visibili' do
    a = described_class.new(app.root, size: 20)
    b = described_class.new(app.root, size: 10)
    c = described_class.new(app.root)
    inner = described_class.new(c)
    expect(place(b)).to eq([[20, 0], [4, 80]])
    expect(c).not_to be_visible
    expect(inner).not_to be_visible
    expect(c.plane.dims).to eq([1, 1])
    expect(c.plane.abs_y).to be < -1000
    expect(a).to be_visible
    a.close # lo spazio torna: il contenitore rifà il layout
    expect(place(b)).to eq([[0, 0], [10, 80]])
    expect(place(c)).to eq([[10, 0], [14, 80]])
    expect(c).to be_visible
    expect(inner).to be_visible
  end

  it 'layout con 0 righe o colonne nasconde, con dimensioni nuove ridisegna; un contenitore chiuso li rifiuta' do
    box = described_class.new(app.root, size: 5)
    box.layout(0, 10)
    expect(box).not_to be_visible
    box.layout(4, 20)
    expect(box.plane.dims).to eq([4, 20])
    expect { box.layout(-1, 2) }.to raise_error(ArgumentError)
    expect { box.layout(1, :x) }.to raise_error(TypeError)
    box.close
    expect { box.layout(1, 1) }.to raise_error(Notcurses::ClosedError)
  end

  it 'close chiude i figli e il piano, toglie il contenitore dal genitore ed è idempotente' do
    box = described_class.new(app.root, size: 5)
    kids = Array.new(3) { described_class.new(box) }
    plane = box.plane
    expect(box.close).to be_nil
    expect(box.close).to be_nil
    expect(box).to be_closed
    expect(kids).to all(be_closed)
    expect(plane).to be_closed
    expect(app.root.children).to eq([])
    expect { box.plane }.to raise_error(Notcurses::ClosedError)
    expect { described_class.new(box) }.to raise_error(Notcurses::ClosedError)
    expect(box.inspect).to include('chiuso')
  end

  it 'valida gli argomenti' do
    expect { described_class.new(app.root, direction: :diagonal) }.to raise_error(ArgumentError)
    expect { described_class.new(app.root, size: 2, weight: 1) }.to raise_error(ArgumentError)
    expect { described_class.new(app.root, size: 0) }.to raise_error(ArgumentError)
    expect { described_class.new(app.root, weight: 1.5) }.to raise_error(TypeError)
    expect { described_class.new(app.root, border: 1) }.to raise_error(TypeError)
    expect { described_class.new(app.root, title: "a\tb") }.to raise_error(ArgumentError)
    expect { described_class.new(app.root, channels: 'x') }.to raise_error(TypeError)
    expect { described_class.new(nc.stdplane) }.to raise_error(TypeError)
    expect(app.root.children).to eq([])
  end
end
