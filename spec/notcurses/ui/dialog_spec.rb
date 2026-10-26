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

  it 'su un terminale stretto il testo va a capo sulle parole e il dialogo resta dentro lo schermo' do
    dialog = described_class.new(app, text: 'uno due tre quattro cinque sei')
    dialog.place(24, 14)
    expect(place(dialog)).to eq([[8, 0], [8, 14]])
    body = dialog.children.first
    expect(body.text).to eq("uno due\ntre\nquattro\ncinque sei") # a capo a 10 colonne (14 meno bordo e margini)
    dialog.place(3, 10)
    expect(place(dialog)).to eq([[0, 0], [3, 10]])
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
