# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative '../../support/nc_helpers'

RSpec.describe Notcurses::UI::Dialog do
  include_context 'con un contesto notcurses'

  let(:app) { Notcurses::UI::App.new(nc) }

  after { app.close }

  def syn(id, **opts) = Notcurses::Input.synthesize(id, **opts)

  def key(id, **opts) = app.dispatch(syn(id, **opts))

  def place(component) = [component.plane.yx, component.plane.dims]

  def buttons_of(dialog) = dialog.children.last.children

  it 'è centrato e largo quanto serve al testo, al titolo e ai pulsanti' do
    dialog = described_class.new(app, text: 'Uscire davvero?', title: 'Conferma', buttons: %w[Sì No])
    expect(place(dialog)).to eq([[9, 30], [5, 19]]) # testo 15 + 4 colonne; righe: testo, vuota, pulsanti, bordo
    expect(dialog.parent).to be_nil
    expect([dialog.text, dialog.buttons, dialog.title]).to eq(['Uscire davvero?', %w[Sì No], 'Conferma'])
    expect(dialog.plane.contents(y: 0, rows: 1, cols: 12)).to eq('╭ Conferma ─')
    expect(buttons_of(dialog).map(&:label)).to eq(%w[Sì No])
  end

  it 'ogni pulsante ha spazio per tutta l\'etichetta; etichette uguali dividono la riga in parti uguali (ICH-293)' do
    { ['Save', "Don't save", 'Cancel'] => 39, %w[A B Longest] => 28 }.each do |labels, width|
      dialog = described_class.new(app, text: 'Save?', buttons: labels)
      buttons = buttons_of(dialog)
      expect(dialog.plane.dim_x).to eq(width)
      expect(buttons.map { |b| b.plane.contents(y: 0, rows: 1).strip }).to eq(labels.map { |l| "[ #{l} ]" })
      expect(buttons.zip(labels)).to all(satisfy { |b, l| b.plane.dim_x >= Notcurses.strwidth(l) + 4 })
      expect(buttons.map(&:label)).to eq(labels)
      dialog.close
    end
    even = described_class.new(app, text: 'una riga di testo piuttosto lunga', buttons: %w[A B C])
    expect(buttons_of(even).map { |b| b.plane.dim_x }.minmax.then { |lo, hi| hi - lo }).to be <= 1
  end

  it 'su un terminale stretto il testo va a capo sulle parole e il dialogo resta dentro lo schermo' do
    dialog = described_class.new(app, text: 'uno due tre quattro cinque sei')
    dialog.place(24, 14)
    expect(place(dialog)).to eq([[8, 0], [8, 14]])
    body = dialog.children.first
    expect(body.text).to eq("uno due\ntre\nquattro\ncinque sei") # a capo a 10 colonne (14 meno bordo e margini)
    dialog.place(3, 10)
    expect(place(dialog)).to eq([[0, 0], [3, 10]])
  end

  it 'misura e manda a capo il testo con una sequenza ZWJ' do
    dev = [0x1F469, 0x200D, 0x1F4BB].pack('U*') # un grapheme: 2 colonne
    dialog = described_class.new(app, text: "#{dev}abc de")
    expect(dialog.plane.dims).to eq([5, 12]) # testo 8 + 4 colonne
    dialog.place(24, 9)
    expect(dialog.children.first.text).to eq("#{dev}abc\nde") # a capo a 5 colonne: la prima parola ne occupa 5
  end

  it 'prende il focus, Tab resta dentro e il mouse fuori dal dialogo non arriva ai componenti sotto' do
    under = Notcurses::UI::Button.new(app.root, 'Sotto', size: 3) {}
    expect(app.focused).to equal(under)
    dialog = described_class.new(app, text: 'Scegli', buttons: %w[A B])
    a, b = buttons_of(dialog)
    expect(app.focused).to equal(a)
    expect(Array.new(3) { key(Notcurses::Key::TAB) && app.focused }).to eq([b, a, b])
    expect { app.focus(under) }.to raise_error(ArgumentError, /modale/)
    expect(app.component_at(1, 1)).to be_nil
    expect(key(Notcurses::Key::BUTTON1, y: 1, x: 1)).to be(false)
    expect(app.focused).to equal(b)
    y, x = dialog.plane.abs_yx
    expect(app.component_at(y, x)).to equal(dialog)
  end

  it 'un pulsante chiude il dialogo e poi chiama il blocco con l\'etichetta; il focus torna dove era' do
    under = Notcurses::UI::Button.new(app.root, 'Sotto', size: 3) {}
    choices = []
    dialog = described_class.new(app, text: 'Scegli', buttons: %w[A B]) do |choice|
      choices << [choice, dialog.closed?, app.focused]
    end
    key(Notcurses::Key::TAB)
    expect(key(Notcurses::Key::ENTER)).to be(true)
    expect(choices).to eq([['B', true, under]])
    expect(app.focused).to equal(under)
  end

  it 'Esc chiude il dialogo con nil; close lo chiude senza il blocco ed è idempotente' do
    choices = []
    described_class.new(app, text: 'x') { |c| choices << c }
    expect(key(Notcurses::Key::ESC)).to be(true)
    expect(choices).to eq([nil])
    quiet = described_class.new(app, text: 'y') { |c| choices << c }
    expect(quiet.close).to be_nil
    expect(quiet.close).to be_nil
    expect(choices).to eq([nil])
    expect(app.focused).to be_nil
  end

  it 'dialoghi annidati: chiuso quello in cima, il focus torna al dialogo sotto' do
    first = described_class.new(app, text: 'primo', buttons: %w[A B])
    key(Notcurses::Key::TAB)
    b = buttons_of(first).last
    second = described_class.new(app, text: 'secondo')
    expect(app.focused).to equal(buttons_of(second).first)
    key(Notcurses::Key::ESC)
    expect(second).to be_closed
    expect(app.focused).to equal(b)
    expect(first).not_to be_closed
  end

  it 'un componente aggiunto sotto mentre il dialogo è aperto resta sotto il dialogo' do
    dialog = described_class.new(app, text: 'sopra')
    filler = Notcurses::UI::Label.new(app.root, text: 'riempitivo')
    y, x = dialog.plane.abs_yx
    expect(app.component_at(y, x)).to equal(dialog)
    expect(nc.top.descendant_of?(dialog.plane) || nc.top.equal?(dialog.plane)).to be(true)
    expect(filler).to be_visible
  end

  it 'App#close chiude i dialoghi aperti; il resize li ricentra' do
    dialog = described_class.new(app, text: 'centro')
    allow(nc).to receive(:refresh).and_return([30, 100])
    app.on_resize { app.stop }
    app.post { Process.kill('WINCH', Process.pid) }
    app.after(5) { app.stop }
    app.run
    expect(place(dialog)).to eq([[12, 44], [5, 11]]) # largo quanto il pulsante: "OK" + 5, più 4
    app.close
    expect(dialog).to be_closed
  end

  it 'se un figlio solleva alla creazione il dialogo si chiude e il focus torna dove era (ICH-291)' do
    under = Notcurses::UI::Button.new(app.root, 'Sotto', size: 3) {}
    expect { described_class.new(app, text: 'Sicuro?', channels: 0x3000_0000) }.to raise_error(ArgumentError, /highcontrast/)
    expect(app.focused).to equal(under)
    allow(Notcurses::UI::Button).to receive(:new).and_raise(ArgumentError, 'pulsante rotto')
    expect { described_class.new(app, text: 'Sicuro?') }.to raise_error(ArgumentError, 'pulsante rotto')
    expect(app.focused).to equal(under)
    expect { app.focus(under) }.not_to raise_error
    expect(app.component_at(1, 1)).to equal(under)
    allow(nc).to receive(:refresh).and_return([30, 100])
    app.on_resize { app.stop }
    app.post { Process.kill('WINCH', Process.pid) }
    app.after(5) { app.stop }
    expect(app.run).to eq(:stop)
    expect(key(Notcurses::Key::ENTER)).to be(true) # Enter arriva di nuovo al pulsante sotto
  end

  it 'un resize che nasconde i pulsanti e poi li mostra ridà il focus; Esc ed Enter arrivano (ICH-292)' do
    [[Notcurses::Key::ESC, nil], [Notcurses::Key::ENTER, 'Yes']].each do |id, choice|
      choices = []
      dialog = described_class.new(app, text: 'Quit?', buttons: %w[Yes No]) { |c| choices << c }
      sizes = [[2, 80], [24, 80]]
      allow(nc).to receive(:refresh) { sizes.shift || [24, 80] }
      seen = :none
      app.on_resize do |rows, _cols|
        next unless rows == 24

        seen = app.focused
        app.stop
      end
      app.post { Process.kill('WINCH', Process.pid) }
      app.after(0.2) { Process.kill('WINCH', Process.pid) }
      app.after(5) { app.stop }
      app.run
      expect([seen, app.focused]).to all(equal(buttons_of(dialog).first))
      expect(key(id)).to be(true)
      expect([dialog.closed?, choices]).to eq([true, [choice]])
    end
  end

  it 'senza focus un tasto va alla radice attiva: Esc chiude il dialogo (ICH-292)' do
    choices = []
    described_class.new(app, text: 'x') { |c| choices << c }
    app.focus(nil)
    expect(key(Notcurses::Key::ESC)).to be(true)
    expect(choices).to eq([nil])
  end

  it 'valida gli argomenti; sopra l\'App stanno solo root e i dialoghi' do
    expect { described_class.new(nc, text: 'x') }.to raise_error(TypeError)
    expect { described_class.new(app, text: "a\tb") }.to raise_error(ArgumentError)
    expect { described_class.new(app, text: 'x', buttons: []) }.to raise_error(ArgumentError)
    expect { described_class.new(app, text: 'x', buttons: 'OK') }.to raise_error(TypeError)
    expect { described_class.new(app, text: 'x', buttons: ["a\nb"]) }.to raise_error(ArgumentError, /buttons\[0\]/)
    expect { Notcurses::UI::Container.new(app) }.to raise_error(ArgumentError, /root/)
    expect(app.root.children).to eq([])
  end
end
