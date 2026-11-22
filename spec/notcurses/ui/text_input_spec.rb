# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative '../../support/nc_helpers'

RSpec.describe Notcurses::UI::TextInput do
  include_context 'con un contesto notcurses'

  let(:app) { Notcurses::UI::App.new(nc) }

  after { app.close }

  def syn(id, **opts) = Notcurses::Input.synthesize(id, **opts)

  def key(id) = app.dispatch(syn(id))

  def type(text) = text.each_char { |c| app.dispatch(syn(c.ord)) }

  def field(cols, **opts, &block)
    row = Notcurses::UI::Container.new(app.root, direction: :horizontal, size: 1)
    described_class.new(row, size: cols, **opts, &block)
  end

  def shown(input) = input.plane.contents(y: 0, rows: 1)

  it 'inserisce al cursore; frecce, Home e Fine spostano il cursore; Backspace e Canc cancellano' do
    input = field(20, text: 'ac')
    expect(input.position).to eq(2)
    key(Notcurses::Key::LEFT)
    type('b')
    expect(input.text).to eq('abc')
    key(Notcurses::Key::HOME)
    type('>')
    key(Notcurses::Key::END_KEY)
    type('!')
    expect(input.text).to eq('>abc!')
    key(Notcurses::Key::BACKSPACE)
    key(Notcurses::Key::HOME)
    key(Notcurses::Key::DEL)
    expect([input.text, input.position]).to eq(['abc', 0])
    expect(key(Notcurses::Key::BACKSPACE)).to be(true) # niente da cancellare, ma consumato
    key(Notcurses::Key::END_KEY)
    expect(key(Notcurses::Key::DEL)).to be(true)
    expect(key(Notcurses::Key::RIGHT)).to be(true)
    expect([input.text, input.position, input.cursor]).to eq(['abc', 3, [0, 3]])
    expect(shown(input)).to eq('abc')
  end

  it 'il cursore si muove per grapheme: un segno combinante si unisce al carattere prima, da solo è rifiutato' do
    input = field(20)
    expect(app.dispatch(syn(0x301))).to be(false) # all'inizio sarebbe un carattere di larghezza zero
    type('e')
    app.dispatch(syn(0x301))
    expect([input.text, input.position]).to eq(["é", 1])
    type('漢')
    expect(input.cursor).to eq([0, 3])
    key(Notcurses::Key::LEFT)
    expect(input.cursor).to eq([0, 1])
    key(Notcurses::Key::BACKSPACE)
    expect(input.text).to eq('漢')
  end

  it 'un keycap, che notcurses 3.0.17 divide con un pezzo largo 0, è rifiutato; un emoji no (ICH-232)' do
    keycap = "1️⃣"
    expect { field(20, text: keycap) }.to raise_error(ArgumentError, /#{Regexp.escape(keycap.inspect)}/)
    input = field(20, text: "\u{1F44D}")
    expect { input.text = "a#{keycap}" }.to raise_error(ArgumentError, /#{Regexp.escape(keycap.inspect)}/)
    type("1️")
    expect(app.dispatch(syn(0x20E3))).to be(false) # prima: inserito, e al disegno "?"
    expect(input.text).to eq("\u{1F44D}1️")
  end

  it 'il testo scorre in orizzontale per tenere visibile il cursore, anche con i glifi larghi' do
    input = field(5)
    type('abcd')
    expect([shown(input), input.cursor]).to eq(['abcd', [0, 4]])
    type('漢字')
    expect([shown(input), input.cursor]).to eq(['漢字', [0, 4]]) # con "d" il cursore uscirebbe dal campo
    key(Notcurses::Key::HOME)
    expect([shown(input), input.cursor]).to eq(['abcd', [0, 0]])
    key(Notcurses::Key::END_KEY)
    key(Notcurses::Key::BACKSPACE)
    key(Notcurses::Key::BACKSPACE)
    expect([shown(input), input.cursor]).to eq(['abcd', [0, 4]]) # torna a mostrare l'inizio
  end

  it 'un glifo largo sotto il cursore nell\'ultima colonna resta visibile; in 1 colonna non si blocca' do
    input = field(5, text: 'abcd漢')
    key(Notcurses::Key::LEFT)
    expect([shown(input), input.cursor]).to eq(['bcd漢', [0, 3]])
    expect(input.plane.at(y: 0, x: 3).egc).to eq('漢')
    type('x')
    expect([input.text, shown(input), input.cursor]).to eq(['abcdx漢', 'cdx漢', [0, 3]])
    narrow = field(1, text: 'a漢')
    expect(narrow.offer_input(syn(Notcurses::Key::LEFT))).to be(true) # il glifo non entra e resta nascosto
    expect([narrow.position, narrow.cursor]).to eq([1, [0, 0]])
  end

  it 'inserisce il testo digitato (eff_text), non il tasto senza Shift del protocollo kitty' do
    input = field(10)
    app.dispatch(syn('1'.ord, modifiers: [:shift], eff_text: '!')) # kitty Shift+1: id e utf8 "1"
    app.dispatch(syn(0xe8, modifiers: [:capslock], eff_text: 'È'))
    expect(input.text).to eq('!È')
    expect(input.offer_input(syn(Notcurses::Key::UP))).to be(false) # eff_text vuoto
    expect(input.offer_input(syn(0x1b))).to be(false) # eff_text "\e": carattere di controllo
    expect(input.offer_input(syn(0x09))).to be(false)
    expect(input.text).to eq('!È')
  end

  it 'Invio chiama il blocco; senza blocco, con Ctrl o Alt, o con il mouse l\'evento non è consumato' do
    sent = []
    input = field(10) { |i| sent << i.text }
    type('ok')
    expect(key(Notcurses::Key::ENTER)).to be(true)
    expect(sent).to eq(['ok'])
    expect(app.dispatch(syn('A'.ord, modifiers: [:ctrl]))).to be(false)
    expect(app.dispatch(syn('x'.ord, modifiers: [:alt]))).to be(false)
    expect(input.offer_input(syn(Notcurses::Key::BUTTON1))).to be(false)
    expect(input.offer_input(syn('z'.ord, evtype: :release))).to be(false)
    expect(input.offer_input(syn(Notcurses::Key::F01))).to be(false)
    plain = field(10)
    app.focus(plain)
    expect(key(Notcurses::Key::ENTER)).to be(false)
    expect(input.text).to eq('ok')
  end

  it 'text= porta il cursore in fondo; colori con e senza il focus; il cursore arriva all\'App' do
    input = field(10, text: 'x')
    input.text = 'nuovo'
    expect([input.text, input.position]).to eq(%w[nuovo] + [5])
    expect { input.text = "a\nb" }.to raise_error(ArgumentError)
    expect(input.plane.base.channels).to eq(Notcurses::UI::FOCUSED_CHANNELS)
    app.focus(nil)
    expect(input.plane.base.channels).to eq(Notcurses::UI::FIELD_CHANNELS)
    expect(input).to be_focusable
  end
end
