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

  it 'un keycap, che notcurses 3.0.17 divide con un pezzo largo 0, è ArgumentError nel testo, nel titolo e nei pulsanti' do
    keycap = Regexp.escape("1\uFE0F\u20E3".inspect)
    expect { described_class.new(app, text: "1\uFE0F\u20E3") }.to raise_error(ArgumentError, /text.*#{keycap}/)
    expect { described_class.new(app, text: 'ok', title: "1\uFE0F\u20E3") }.to raise_error(ArgumentError, /title.*#{keycap}/)
    expect { described_class.new(app, text: 'ok', buttons: ["1\uFE0F\u20E3"]) }
      .to raise_error(ArgumentError, /buttons\[0\].*#{keycap}/)
    dialog = described_class.new(app, text: "\u{1F44D}", buttons: ["\u{1F44D}"])
    expect([dialog.text, dialog.buttons]).to eq(["\u{1F44D}", ["\u{1F44D}"]])
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
    app.focus(nil)
    expect { described_class.new(app, text: 'Sicuro?') }.to raise_error(ArgumentError, 'pulsante rotto')
    expect(app.focused).to be_nil # nessun focus prima, nessun focus dopo
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

  # Due resize durante run (small righe, poi 24); il blocco gira a small righe.
  def shrink_and_restore(small = 2)
    sizes = [[small, 80], [24, 80]]
    allow(nc).to receive(:refresh) { sizes.shift || [24, 80] }
    app.on_resize do |rows, _cols|
      yield if rows == small
      app.stop if rows == 24
    end
    app.post { Process.kill('WINCH', Process.pid) }
    app.after(0.2) { Process.kill('WINCH', Process.pid) }
    app.after(5) { app.stop }
    app.run
  end

  it 'il focus torna dopo il resize anche se il dialogo si chiude a terminale piccolo (ICH-292)' do
    Notcurses::UI::Label.new(app.root, text: 'x', size: 2)
    Notcurses::UI::TextInput.new(app.root, size: 1)
    under = Notcurses::UI::TextInput.new(app.root, size: 1)
    app.focus(under)
    described_class.new(app, text: 'Quit?', buttons: %w[Yes No])
    shrink_and_restore { key(Notcurses::Key::ESC) }
    expect(app.focused).to equal(under) # quello di prima, non il primo candidato
  end

  it 'il focus torna dopo il resize anche se il dialogo si apre a terminale piccolo (ICH-292)' do
    Notcurses::UI::Label.new(app.root, text: 'x', size: 2)
    Notcurses::UI::TextInput.new(app.root, size: 1)
    under = Notcurses::UI::TextInput.new(app.root, size: 1)
    app.focus(under)
    choices = []
    dialog = nil
    shrink_and_restore do
      allow(nc).to receive(:dims).and_return([2, 80])
      dialog = described_class.new(app, text: 'Quit?', buttons: %w[Yes No]) { |c| choices << c }
    end
    expect(app.focused).to equal(buttons_of(dialog).first)
    expect(key(Notcurses::Key::ENTER)).to be(true)
    expect(choices).to eq(['Yes'])
    expect(app.focused).to equal(under) # alla chiusura torna quello di prima del resize
  end

  it 'il focus torna dopo il resize anche se un pulsante del dialogo lo ha avuto a terminale piccolo (ICH-292)' do
    Notcurses::UI::Label.new(app.root, text: 'x', size: 4)
    Notcurses::UI::TextInput.new(app.root, size: 1)
    second = Notcurses::UI::TextInput.new(app.root, size: 1)
    app.focus(second)
    shrink_and_restore(4) do
      allow(nc).to receive(:dims).and_return([4, 80])
      dialog = described_class.new(app, text: 'Quit?')
      expect(app.focused).to equal(buttons_of(dialog).first) # il pulsante è visibile a 4 righe
      key(Notcurses::Key::ESC)
    end
    expect(app.focused).to equal(second)
  end

  it 'il rollback chiude il dialogo anche se il ridisegno del focus che torna solleva (ICH-291)' do
    touchy = Class.new do
      include Notcurses::UI::Component

      attr_accessor :armed

      def initialize(parent) = attach_component!(parent, size: 1, weight: nil)

      def focusable? = true

      private

      def draw = (raise 'ridisegno rotto' if armed && focused?)
    end
    broken = Class.new(described_class) do
      class << self
        attr_accessor :last
      end

      def initialize(...)
        self.class.last = self
        super
      end

      private

      def draw
        super
        raise ArgumentError, 'creazione rotta' if @body
      end
    end
    under = touchy.new(app.root)
    expect(app.focused).to equal(under)
    under.armed = true
    expect { broken.new(app, text: 'Sicuro?') }.to raise_error(ArgumentError, 'creazione rotta')
    dialog = broken.last
    expect(dialog).to be_closed
    expect(dialog.children).to eq([]) # i figli si chiudono ed escono dal dialogo
    expect(app.component_at(12, 40)).to equal(app.root) # al centro non resta il dialogo
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
