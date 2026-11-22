# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative '../../support/nc_helpers'

RSpec.describe Notcurses::UI::ListView do
  include_context 'con un contesto notcurses'

  let(:app) { Notcurses::UI::App.new(nc) }

  after { app.close }

  def syn(id, **opts) = Notcurses::Input.synthesize(id, **opts)

  def key(id) = app.dispatch(syn(id))

  def list(rows, cols: 10, **opts, &block)
    row = Notcurses::UI::Container.new(app.root, direction: :horizontal, size: rows)
    described_class.new(row, size: cols, **opts, &block)
  end

  def lines(component) = Array.new(component.plane.dim_y) { |y| component.plane.contents(y: y, rows: 1) }

  let(:items) { (1..10).map { |i| "voce #{i}" } }

  it 'frecce, PgUp, PgDn, Home e Fine spostano la scelta entro l\'elenco; l\'elenco scorre fino alla voce' do
    view = list(3, items: items)
    expect([view.selected, view.selected_item]).to eq([0, 'voce 1'])
    expect(lines(view)).to eq(['voce 1    ', 'voce 2', 'voce 3'])
    key(Notcurses::Key::UP)
    expect(view.selected).to eq(0)
    key(Notcurses::Key::DOWN)
    key(Notcurses::Key::PGDOWN)
    expect(view.selected).to eq(3)
    expect(lines(view)).to eq(['voce 2', 'voce 3', 'voce 4    '])
    key(Notcurses::Key::END_KEY)
    expect(lines(view).last).to eq('voce 10   ')
    key(Notcurses::Key::PGUP)
    expect(view.selected).to eq(7)
    key(Notcurses::Key::HOME)
    expect([view.selected, lines(view).first]).to eq([0, 'voce 1    '])
  end

  it 'con il focus la voce scelta usa focused_channels su tutta la riga, senza il focus è in grassetto' do
    view = list(2, items: %w[a b])
    expect(view.plane.at(y: 0, x: 5).channels).to eq(Notcurses::UI::FOCUSED_CHANNELS)
    expect(view.plane.at(y: 1, x: 0).channels).to eq(Notcurses::Channels.new)
    app.focus(nil)
    cell = view.plane.at(y: 0, x: 0)
    expect([cell.egc, cell.styles, cell.channels]).to eq(['a', [:bold], Notcurses::Channels.new])
  end

  it 'mouse: il clic sceglie la voce sotto il puntatore, la rotella sposta la scelta' do
    view = list(3, items: items)
    y, x = view.plane.abs_yx
    expect(app.dispatch(syn(Notcurses::Key::BUTTON1, y: y + 2, x: x))).to be(true)
    expect(view.selected).to eq(2)
    app.dispatch(syn(Notcurses::Key::BUTTON1, y: y + 2, x: x, evtype: :release))
    app.dispatch(syn(Notcurses::Key::SCROLL_DOWN, y: y, x: x))
    expect(view.selected).to eq(3)
    app.dispatch(syn(Notcurses::Key::SCROLL_UP, y: y, x: x))
    expect(view.selected).to eq(2)
    app.dispatch(syn(Notcurses::Key::SCROLL_DOWN, y: y, x: x)) # la rotella non ha rilascio: ogni passo conta
    app.dispatch(syn(Notcurses::Key::SCROLL_DOWN, y: y, x: x))
    expect(view.selected).to eq(4)
    short = list(3, items: %w[solo])
    sy, sx = short.plane.abs_yx
    expect(app.dispatch(syn(Notcurses::Key::BUTTON1, y: sy + 2, x: sx))).to be(false) # sotto l'ultima voce
    expect(app.focused).to equal(short)
  end

  it 'Invio chiama il blocco con l\'elenco; senza blocco o con l\'elenco vuoto l\'evento non è consumato' do
    chosen = []
    list(3, items: items) { |l| chosen << l.selected_item }
    key(Notcurses::Key::DOWN)
    expect(key(Notcurses::Key::ENTER)).to be(true)
    expect(chosen).to eq(['voce 2'])
    plain = list(3, items: items)
    app.focus(plain)
    expect(key(Notcurses::Key::ENTER)).to be(false)
    empty = list(3)
    app.focus(empty)
    expect([empty.selected, empty.selected_item]).to eq([nil, nil])
    expect(key(Notcurses::Key::DOWN)).to be(false)
    expect(plain.offer_input(syn('j'.ord))).to be(false)
  end

  it 'items= tiene la scelta allo stesso indice (o all\'ultima voce); selected= controlla l\'indice' do
    view = list(3, items: items)
    view.selected = 8
    expect(lines(view).last).to eq('voce 9    ')
    view.items = %w[x y]
    expect([view.selected, view.items]).to eq([1, %w[x y]])
    expect(view.items).to be_frozen
    view.items = []
    expect(view.selected).to be_nil
    view.items = %w[z]
    expect(view.selected).to eq(0)
    expect { view.selected = 1 }.to raise_error(ArgumentError)
    expect { view.selected = '0' }.to raise_error(TypeError)
    expect { view.items = 'x' }.to raise_error(TypeError)
    expect { view.items = ["a\tb"] }.to raise_error(ArgumentError, /items\[0\]/)
    expect { described_class.new(app.root, items: [1]) }.to raise_error(TypeError)
  end

  it 'una voce con un keycap, che notcurses 3.0.17 divide con un pezzo largo 0, è ArgumentError (ICH-232)' do
    keycap = "1\uFE0F\u20E3"
    expect { list(3, items: ['a', keycap]) }.to raise_error(ArgumentError, /items\[1\].*#{Regexp.escape(keycap.inspect)}/)
    view = list(3, items: ["\u{1F44D}"])
    expect { view.items = ['a', "b #{keycap}"] }.to raise_error(ArgumentError, /items\[1\].*#{Regexp.escape(keycap.inspect)}/)
    expect(view.items).to eq(["\u{1F44D}"])
  end
end
