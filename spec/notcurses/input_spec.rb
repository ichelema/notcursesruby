# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/nckeys.h
# frozen_string_literal: true

require 'notcurses'

RSpec.describe Notcurses::Input do
  let(:key) { Notcurses::Key }

  it 'copia i campi di ncinput e si congela' do
    ni = Notcurses::FFI::NcInput.new
    ni[:id] = 'é'.ord
    ni[:y] = 3
    ni[:x] = 4
    ni[:utf8].to_ptr.put_bytes(0, 'é'.b)
    ni[:evtype] = Notcurses::FFI::NCTYPE_RELEASE
    ni[:modifiers] = Notcurses::FFI::NCKEY_MOD_CTRL
    ni[:ypx] = 5
    ni[:xpx] = 6
    ni[:eff_text][0] = 'É'.ord
    input = described_class.new(ni)
    ni[:id] = 0 # la copia non dipende più dalla struct
    expect(input.id).to eq('é'.ord)
    expect([input.y, input.x, input.ypx, input.xpx]).to eq([3, 4, 5, 6])
    expect(input.utf8).to eq('é')
    expect(input.utf8.encoding).to eq(Encoding::UTF_8)
    expect(input.evtype).to eq(:release)
    expect(input).to be_release
    expect(input).to be_ctrl
    expect(input.eff_text).to eq('É')
    expect(input).to be_frozen
    expect(input.utf8).to be_frozen
    expect(input.eff_text).to be_frozen
  end

  it 'congela utf8 ed eff_text: accumularci sopra non rompe l\'evento' do
    ev = described_class.synthesize('a'.ord)
    expect { ev.utf8 << 'bcdef' }.to raise_error(FrozenError)
    expect { ev.eff_text << 'x' }.to raise_error(FrozenError)
    expect(ev).to eq(described_class.synthesize('a'.ord))
    expect(ev).not_to be_alt
    up = described_class.synthesize(key::UP)
    expect([up.utf8, up.eff_text]).to all(eq('').and(be_frozen))
  end

  it 'rifiuta argomenti che non sono NcInput' do
    expect { described_class.new({}) }.to raise_error(TypeError)
  end

  describe '.synthesize' do
    it 'deriva utf8 dal codepoint stampabile' do
      expect(described_class.synthesize('a'.ord).utf8).to eq('a')
      expect(described_class.synthesize(0x1F600).utf8).to eq('😀')
      expect(described_class.synthesize(key::UP).utf8).to eq('')
      expect(described_class.synthesize(key::ENTER).utf8).to eq('')
      expect(described_class.synthesize(0x1b).utf8).to eq('')
    end

    it 'accetta modificatori come simboli o maschera' do
      i = described_class.synthesize(key::UP, modifiers: %i[shift ctrl])
      expect(i).to be_shift
      expect(i).to be_ctrl
      expect(i).not_to be_alt
      expect(i.modifier_list).to eq(%i[shift ctrl])
      m = described_class.synthesize(65, modifiers: Notcurses::FFI::NCKEY_MOD_ALT | Notcurses::FFI::NCKEY_MOD_META)
      expect(m).to be_alt
      expect(m).to be_meta
      expect(m).not_to be_nomod
      expect(described_class.synthesize(65)).to be_nomod
      %i[super hyper capslock numlock].each do |mod|
        expect(described_class.synthesize(65, modifiers: [mod]).public_send(:"#{mod}?")).to be(true)
      end
    end

    it 'valida gli argomenti' do
      expect { described_class.synthesize(-1) }.to raise_error(ArgumentError)
      expect { described_class.synthesize(65, modifiers: [:nope]) }.to raise_error(ArgumentError)
      expect { described_class.synthesize(65, modifiers: 'x') }.to raise_error(TypeError)
      expect { described_class.synthesize(65, evtype: :boh) }.to raise_error(ArgumentError)
      expect { described_class.synthesize(65, utf8: 'abcde') }.to raise_error(ArgumentError, /4 byte/)
      expect { described_class.synthesize(65, y: 2**31) }.to raise_error(ArgumentError)
    end
  end

  it '#to_ffi ricostruisce una struct equivalente' do
    i = described_class.synthesize('x'.ord, modifiers: [:shift], y: 1, x: 2)
    s = i.to_ffi
    expect(s).to be_a(Notcurses::FFI::NcInput)
    expect(s[:id]).to eq('x'.ord)
    expect(s[:utf8].to_s).to eq('x')
    expect(described_class.new(s)).to eq(i)
  end

  it '== segue ncinput_equal_p: :unknown e :press equivalgono, CapsLock è ignorato' do
    a = described_class.synthesize(65)
    expect(a).to eq(described_class.synthesize(65, evtype: :unknown))
    expect(a).to eq(described_class.synthesize(65, modifiers: [:capslock]))
    expect(a).not_to eq(described_class.synthesize(65, evtype: :release))
    expect(a).not_to eq(described_class.synthesize(66))
    expect(a.hash).to eq(described_class.synthesize(65, modifiers: [:numlock]).hash)
  end

  it 'mouse? e synthesized?' do
    expect(described_class.synthesize(key::BUTTON1)).to be_mouse
    expect(described_class.synthesize(key::BUTTON1)).to be_synthesized
    expect(described_class.synthesize(65)).not_to be_mouse
    expect(described_class.synthesize(65)).not_to be_synthesized
  end
end

RSpec.describe Notcurses::Key do
  it 'espone le costanti NCKEY_* senza prefisso' do
    expect(described_class::UP).to eq(Notcurses::FFI::NCKEY_UP)
    expect(described_class::ESC).to eq(0x1b)
    expect(described_class::END_KEY).to eq(Notcurses::FFI::NCKEY_END)
    expect(described_class::BEGIN_KEY).to eq(Notcurses::FFI::NCKEY_BEGIN)
    expect(described_class::SCROLL_UP).to eq(described_class::BUTTON4)
  end

  it 'copre tutte le costanti NCKEY_* tranne i modificatori' do
    ffi_keys = Notcurses::FFI.constants.grep(/\ANCKEY_/).reject { |c| c.to_s.start_with?('NCKEY_MOD_') }
    renamed = { NCKEY_END: :END_KEY, NCKEY_BEGIN: :BEGIN_KEY }
    ffi_keys.each do |c|
      name = renamed.fetch(c) { c.to_s.delete_prefix('NCKEY_').to_sym }
      expect(described_class.const_get(name)).to eq(Notcurses::FFI.const_get(c)), "manca Key::#{name}"
    end
  end

  it 'predicate sui codici' do
    expect(described_class.preterunicode(1)).to eq(described_class::RESIZE)
    expect(described_class.synthesized?(described_class::RESIZE)).to be(true)
    expect(described_class.mouse?(described_class::MOTION)).to be(true)
    expect(described_class.pua?(0xe000)).to be(true)
    expect(described_class.supppuaa?(0xf0000)).to be(true)
    expect(described_class.supppuab?(0x100000)).to be(true)
    expect(described_class.pua?(65)).to be(false)
    expect { described_class.preterunicode(-1) }.to raise_error(ArgumentError)
    expect { described_class.mouse?('a') }.to raise_error(TypeError)
  end
end
