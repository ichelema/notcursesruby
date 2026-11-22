# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative '../../support/nc_helpers'

RSpec.describe Notcurses::UI::Button do
  include_context 'con un contesto notcurses'

  let(:app) { Notcurses::UI::App.new(nc) }

  after { app.close }

  def syn(id, **opts) = Notcurses::Input.synthesize(id, **opts)

  def row(rows) = Notcurses::UI::Container.new(app.root, direction: :horizontal, size: rows)

  def lines(component) = Array.new(component.plane.dim_y) { |y| component.plane.contents(y: y, rows: 1) }

  it 'con almeno 3 righe e 4 colonne disegna l\'etichetta dentro un bordo, altrimenti fra parentesi' do
    boxed = described_class.new(row(3), 'OK', size: 8) {}
    flat = described_class.new(row(1), 'OK', size: 8) {}
    expect(lines(boxed)).to eq(['╭──────╮', '│OK│', '╰──────╯']) # contents salta le celle vuote
    expect(boxed.plane.at(y: 1, x: 3).egc).to eq('O')
    expect(lines(flat)).to eq(['[ OK ]'])
    expect(flat.plane.at(y: 0, x: 1).egc).to eq('[')
    expect(boxed.label).to eq('OK')
    expect(boxed).to be_focusable
  end

  it 'un drag non ripete il clic: notcurses lo consegna come pressioni ripetute di BUTTON1 (ICH-283)' do
    hits = []
    first = described_class.new(row(1), 'A', size: 10) { hits << :a }
    second = described_class.new(first.parent, 'B', size: 10) { hits << :b }
    y, x = first.plane.abs_yx
    bx = second.plane.abs_yx.last
    app.dispatch(syn(Notcurses::Key::BUTTON1, y: y, x: x + 1))
    app.dispatch(syn(Notcurses::Key::BUTTON1, y: y, x: x + 2)) # movimento con BUTTON1 premuto
    app.dispatch(syn(Notcurses::Key::BUTTON1, y: y, x: x + 3))
    app.dispatch(syn(Notcurses::Key::BUTTON1, y: y, x: x + 3, evtype: :release))
    expect(hits).to eq([:a])
    app.dispatch(syn(Notcurses::Key::BUTTON1, y: y, x: x + 1)) # da A trascinato su B
    app.dispatch(syn(Notcurses::Key::BUTTON1, y: y, x: bx + 1))
    app.dispatch(syn(Notcurses::Key::BUTTON1, y: y, x: bx + 1, evtype: :release))
    expect(hits).to eq(%i[a a])
    expect(app.focused).to equal(first)
  end

  it 'Invio, Spazio e il clic con BUTTON1 chiamano il blocco con il pulsante; gli altri eventi no' do
    pressed = []
    button = described_class.new(row(3), 'Vai', size: 10) { |b| pressed << b }
    y, x = button.plane.abs_yx
    expect(app.dispatch(syn(Notcurses::Key::ENTER))).to be(true)
    expect(app.dispatch(syn(Notcurses::Key::SPACE))).to be(true)
    expect(app.dispatch(syn(Notcurses::Key::BUTTON1, y: y + 1, x: x + 1))).to be(true)
    expect(pressed).to eq([button] * 3)
    expect(app.dispatch(syn(Notcurses::Key::ENTER, modifiers: [:ctrl]))).to be(false)
    expect(app.dispatch(syn('x'.ord))).to be(false)
    expect(app.dispatch(syn(Notcurses::Key::BUTTON1, y: y, x: x, evtype: :release))).to be(false)
    expect(app.dispatch(syn(Notcurses::Key::BUTTON3, y: y, x: x))).to be(false)
    expect(button.offer_input(syn(Notcurses::Key::ENTER, evtype: :release))).to be(false)
    expect(pressed.size).to eq(3)
  end

  it 'con il focus usa focused_channels, senza il focus channels' do
    plain = Notcurses::Channels.rgb(0, 0, 0, 200, 200, 200)
    a = described_class.new(row(1), 'A', channels: plain, size: 5) {}
    b = described_class.new(row(1), 'B', channels: plain, size: 5) {}
    expect(app.focused).to equal(a)
    expect(a.plane.at(y: 0, x: 2).channels).to eq(Notcurses::UI::FOCUSED_CHANNELS)
    expect(b.plane.at(y: 0, x: 2).channels).to eq(plain)
    app.focus(b)
    expect(a.plane.at(y: 0, x: 2).channels).to eq(plain)
    expect(b.plane.base.channels).to eq(Notcurses::UI::FOCUSED_CHANNELS)
  end

  it 'label= ridisegna e controlla l\'etichetta; senza blocco o con un\'etichetta non ammessa solleva' do
    button = described_class.new(row(1), 'A', size: 9) {}
    button.label = 'Nuovo'
    expect(button.plane.contents(y: 0, rows: 1)).to eq('[ Nuovo ]')
    expect { button.label = "a\nb" }.to raise_error(ArgumentError)
    expect { described_class.new(app.root, 'x') }.to raise_error(ArgumentError, /blocco/)
    expect { described_class.new(app.root, nil) {} }.to raise_error(TypeError)
    expect { described_class.new(app.root, 'x', focused_channels: 'y') {} }.to raise_error(TypeError)
  end

  it 'un keycap, che notcurses 3.0.17 divide con un pezzo largo 0, è ArgumentError; un emoji no (ICH-232)' do
    keycap = "1\uFE0F\u20E3"
    expect { described_class.new(row(1), keycap, size: 9) {} }.to raise_error(ArgumentError, /#{Regexp.escape(keycap.inspect)}/)
    button = described_class.new(row(1), "\u{1F44D}", size: 9) {}
    expect { button.label = keycap }.to raise_error(ArgumentError, /#{Regexp.escape(keycap.inspect)}/)
    expect(button.label).to eq("\u{1F44D}")
  end
end
