# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative '../support/nc_helpers'

RSpec.describe 'Notcurses: funzioni di formattazione' do
  describe '.metric' do
    it 'formatta con i prefissi del sistema metrico' do
      expect(Notcurses.metric(0)).to eq('0.00')
      expect(Notcurses.metric(1500)).to eq('1.50K')
      expect(Notcurses.metric(2000, omit_decimal: true)).to eq('2K')
      expect(Notcurses.metric(2_500_000)).to eq('2.50M')
      expect(Notcurses.metric(1024, base: 1024, suffix: 'i', omit_decimal: true)).to eq('1Ki')
      expect(Notcurses.metric(1500, decimal: 1000)).to eq('1.50')
      expect(Notcurses.metric(2**64 - 1)).to end_with('E')
      expect(Notcurses.metric(1500).encoding).to eq(Encoding::UTF_8)
    end

    it 'valida gli argomenti' do
      expect { Notcurses.metric(-1) }.to raise_error(ArgumentError)
      expect { Notcurses.metric(2**64) }.to raise_error(ArgumentError)
      expect { Notcurses.metric(1, decimal: 0) }.to raise_error(ArgumentError)
      expect { Notcurses.metric(1, base: 10) }.to raise_error(ArgumentError)
      expect { Notcurses.metric(1, suffix: 'ii') }.to raise_error(ArgumentError)
      expect { Notcurses.metric(1, suffix: 'é') }.to raise_error(ArgumentError)
      expect { Notcurses.metric(1, omit_decimal: 1) }.to raise_error(TypeError)
      expect { Notcurses.metric('1') }.to raise_error(TypeError)
    end

    it 'rifiuta le coppie value/decimal che mandano ncnmetric in overflow (bug di 3.0.17)' do
      expect { Notcurses.metric(10**17, decimal: 10**18) }.to raise_error(ArgumentError)
      expect { Notcurses.metric(1, decimal: (2**64 - 1) / 10) }.to raise_error(ArgumentError)
      expect { Notcurses.metric(2**58, decimal: 2**60, base: 1024) }.to raise_error(ArgumentError)
    end

    it 'accetta le coppie con decimal grande che non vanno in overflow' do
      expect(Notcurses.metric(10**16, decimal: 10**18)).to eq('10.00m')
      expect(Notcurses.metric(5 * 10**18, decimal: 10**18)).to eq('5.00')
      expect(Notcurses.metric(0, decimal: 10**18)).to eq('0.00')
      expect(Notcurses.si_prefix(10**14, decimal: 10**15)).to eq('100.00m')
    end

    it 'con base Float controlla l\'overflow come con la base intera' do
      expect(Notcurses.metric(2**54 - 1, decimal: 2**60, base: 1024.0)).to eq('16.00m')
      expect { Notcurses.metric(313_413_999_946_230, decimal: 313_413_999_946_230_001, base: 1000.0) }
        .to raise_error(ArgumentError)
    end
  end

  describe 'prefissi standard' do
    it 'si_prefix, binary_prefix e byte_prefix' do
      expect(Notcurses.si_prefix(1500)).to eq('1.50K')
      expect(Notcurses.binary_prefix(1536)).to eq('1.50K')
      expect(Notcurses.byte_prefix(1024)).to eq('1.00Ki')
      expect(Notcurses.byte_prefix(1024, omit_decimal: true)).to eq('1Ki')
      expect(Notcurses.byte_prefix(1023)).to eq('1023.00')
      expect { Notcurses.si_prefix(-5) }.to raise_error(ArgumentError)
      expect { Notcurses.binary_prefix(1, decimal: 0) }.to raise_error(ArgumentError)
    end

    it 'rifiutano le coppie value/decimal che vanno in overflow (bug di 3.0.17)' do
      expect { Notcurses.si_prefix(10**17, decimal: 10**18) }.to raise_error(ArgumentError)
      expect { Notcurses.binary_prefix(2**58, decimal: 2**60) }.to raise_error(ArgumentError)
      expect { Notcurses.byte_prefix(2**58, decimal: 2**60) }.to raise_error(ArgumentError)
    end

    it 'dopo un contesto UTF-8 il prefisso micro è µ' do
      NcHelpers.open_context { |_nc| expect(Notcurses.metric(1, decimal: 1_000_000)).to eq('1.00µ') }
    end
  end

  describe 'nomi di blitter e scale' do
    it 'parse_blitter e blitter_name' do
      expect(Notcurses.parse_blitter('half')).to eq(:half)
      expect(Notcurses.parse_blitter('SEX')).to eq(:sextant)
      expect(Notcurses.parse_blitter('default')).to eq(:default)
      expect(Notcurses.blitter_name(:octant)).to eq('oct')
      expect(Notcurses.blitter_name(:default)).to eq('default')
      expect(Notcurses.blitter_name(Notcurses::FFI::NCBLIT_BRAILLE)).to eq('braille')
      expect { Notcurses.parse_blitter('2x1') }.to raise_error(ArgumentError)
      expect { Notcurses.parse_blitter(:half) }.to raise_error(TypeError)
      expect { Notcurses.blitter_name(:enorme) }.to raise_error(ArgumentError)
    end

    it 'parse_scale e scale_name' do
      expect(Notcurses.parse_scale('stretch')).to eq(:stretch)
      expect(Notcurses.parse_scale('hires')).to eq(:none_hires)
      expect(Notcurses.parse_scale('scalehi')).to eq(:scale_hires)
      expect(Notcurses.scale_name(:scale)).to eq('scale')
      expect { Notcurses.parse_scale('inflate') }.to raise_error(ArgumentError)
      expect { Notcurses.scale_name(:gigante) }.to raise_error(ArgumentError)
    end
  end

  describe '.ucs32_to_utf8' do
    it 'converte codepoint in UTF-8' do
      expect(Notcurses.ucs32_to_utf8([0x41, 0x754c, 0x1f600])).to eq('A界😀')
      expect(Notcurses.ucs32_to_utf8([])).to eq('')
      expect(Notcurses.ucs32_to_utf8([0x41]).encoding).to eq(Encoding::UTF_8)
    end

    it 'rifiuta codepoint non validi' do
      expect { Notcurses.ucs32_to_utf8([0xd800]) }.to raise_error(ArgumentError)
      expect { Notcurses.ucs32_to_utf8([0x110000]) }.to raise_error(ArgumentError)
      expect { Notcurses.ucs32_to_utf8(['a']) }.to raise_error(TypeError)
      expect { Notcurses.ucs32_to_utf8('abc') }.to raise_error(TypeError)
    end
  end

  describe '.strwidth' do
    it 'misura le colonne con le regole di notcurses' do
      expect(Notcurses.strwidth('')).to eq(0)
      expect(Notcurses.strwidth('abc')).to eq(3)
      expect(Notcurses.strwidth('漢字')).to eq(4)
      expect(Notcurses.strwidth("é")).to eq(1)
      expect(Notcurses.strwidth("a\nb")).to eq(3)
      expect(Notcurses.strwidth('abc'.b)).to eq(3)
    end

    it 'misura anche il testo dopo una sequenza ZWJ' do
      astro = [0x1F469, 0x200D, 0x1F680].pack('U*')
      expect(Notcurses.strwidth(astro)).to eq(2)
      expect(Notcurses.strwidth("#{astro}abc")).to eq(5)
      expect(Notcurses.strwidth("a#{astro}#{astro}b")).to eq(6)
      expect { Notcurses.strwidth("ab#{astro}cd\x01") }.to raise_error(ArgumentError, /dal byte 15/) # 2 + 11 + 2
    end

    it 'rifiuta i testi che notcurses non sa misurare' do
      expect { Notcurses.strwidth("a\x01") }.to raise_error(ArgumentError)
      expect { Notcurses.strwidth("a\xff".b) }.to raise_error(ArgumentError)
      expect { Notcurses.strwidth("a\0") }.to raise_error(ArgumentError)
      expect { Notcurses.strwidth(nil) }.to raise_error(TypeError)
    end
  end
end
