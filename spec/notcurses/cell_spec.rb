# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative '../support/nc_helpers'

RSpec.describe Notcurses::Cell do
  let(:red) { Notcurses::Channels.rgb(255, 0, 0, 0, 0, 0) }

  describe 'valore Ruby' do
    it 'ha default spazio, nessuno stile, colori di default' do
      cell = described_class.new
      expect([cell.egc, cell.styles, cell.channels, cell.width]).to eq([' ', [], Notcurses::Channels.new, 1])
      expect(cell).to be_frozen
      expect(cell.egc).to be_frozen
      expect(cell.styles).to be_frozen
      expect(cell).not_to be_wide
      expect(cell).not_to be_empty
    end

    it 'accetta un grapheme cluster, un codepoint, stili e colori in più forme' do
      expect(described_class.new(egc: '漢').width).to eq(2)
      expect(described_class.new(egc: '漢')).to be_wide
      expect(described_class.new(egc: 0x41).egc).to eq('A')
      expect(described_class.new(egc: "e\u0301").width).to eq(1)
      astronaut = "\u{1F469}\u200D\u{1F680}"
      expect(described_class.new(egc: astronaut).egc).to eq(astronaut)
      empty = described_class.new(egc: '')
      expect([empty.width, empty]).to match([0, be_empty])
      expect(described_class.new(egc: 'a', styles: :bold).styles).to eq([:bold])
      expect(described_class.new(egc: 'a', styles: %i[bold italic]).styles).to contain_exactly(:bold, :italic)
      expect(described_class.new(egc: 'a', styles: Notcurses::FFI::NCSTYLE_UNDERLINE).styles).to eq([:underline])
      expect(described_class.new(egc: 'a', channels: red).channels).to eq(red)
      expect(described_class.new(egc: 'a', channels: red.value).channels).to eq(red)
    end

    it 'azzera i bit di servizio dei canali' do
      expect(described_class.new(egc: 'a', channels: 0xffff_ffff_ffff_ffff).channels.value).to eq(0x78ff_ffff_78ff_ffff)
    end

    it 'rifiuta più grapheme, caratteri di controllo e testo non valido' do
      expect { described_class.new(egc: 'ab') }.to raise_error(ArgumentError)
      expect { described_class.new(egc: "\n") }.to raise_error(ArgumentError)
      expect { described_class.new(egc: "\t") }.to raise_error(ArgumentError)
      expect { described_class.new(egc: "\u0085") }.to raise_error(ArgumentError)
      expect { described_class.new(egc: "\xff".b) }.to raise_error(ArgumentError)
      expect { described_class.new(egc: "\0") }.to raise_error(ArgumentError)
      expect { described_class.new(egc: :a) }.to raise_error(TypeError)
      expect { described_class.new(egc: 0xD800) }.to raise_error(RangeError)
      expect { described_class.new(egc: 'a', styles: :blink) }.to raise_error(ArgumentError)
      expect { described_class.new(egc: 'a', channels: 'x') }.to raise_error(TypeError)
    end

    it '==, eql?, hash, with, to_s e inspect' do
      a = described_class.new(egc: 'x', styles: :bold, channels: red)
      b = described_class.new(egc: 'x', styles: [:bold], channels: red.value)
      expect(a).to eq(b)
      expect(a).to eql(b)
      expect(a.hash).to eq(b.hash)
      expect({ a => 1 }[b]).to eq(1)
      expect(a).not_to eq(described_class.new(egc: 'x'))
      expect(a.with(egc: 'y')).to eq(described_class.new(egc: 'y', styles: :bold, channels: red))
      expect(a.with(styles: []).styles).to eq([])
      expect(a.to_s).to eq('x')
      expect(a.inspect).to include('egc="x"', 'width=1', ':bold')
    end
  end

  describe 'con un piano' do
    include_context 'con un contesto notcurses'

    it 'una Cell scritta con putc torna uguale da Plane#at, anche con un EGC di più di 4 byte' do
      nc.stdplane.create_child(rows: 1, cols: 10) do |p|
        cell = described_class.new(egc: "\u{1F469}\u200D\u{1F680}", styles: :italic, channels: red)
        expect(p.putc(cell, y: 0, x: 0)).to eq(2)
        read = p.at(y: 0, x: 0)
        expect(read).to eq(cell)
        expect(read.width).to eq(2)
        expect(p.at(y: 0, x: 1)).to eq(cell) # metà destra: il glifo della metà sinistra
        p.erase
        expect(p.at(y: 0, x: 0).egc).to eq(p.base.egc)
      end
    end

    # ICH-586: notcurses conta un indicatore regionale da solo largo 1 colonna, Ghostty e Kitty lo disegnano largo 2,
    # e il testo dopo si sposta sullo schermo
    it 'Cell.new rifiuta un indicatore regionale da solo e accetta la bandiera' do
      expect { described_class.new(egc: "\u{1F1EE}") }.to raise_error(ArgumentError, /indicatore regionale da solo/)
      expect(described_class.new(egc: "\u{1F1EE}\u{1F1F9}").egc).to eq("\u{1F1EE}\u{1F1F9}")
    end

    it 'solleva CellError quando notcurses divide il grapheme (bandiere)' do
      nc.stdplane.create_child(rows: 1, cols: 10) do |p|
        flag = described_class.new(egc: "\u{1F1EE}\u{1F1F9}")
        expect { p.putc(flag, y: 0, x: 0) }.to raise_error(Notcurses::CellError)
        expect(p.contents).to eq('')
      end
    end

    # ICH-217: notcurses 3.0.17 divide in più caratteri alcuni grapheme che per Ruby sono uno solo. Cell.new non ha un
    # piano e li accetta; le scritture con una Cell sollevano CellError con il motivo e con che cosa usare (prima:
    # "notcurses non accetta ... come un solo carattere", senza alternative).
    describe 'grapheme che notcurses divide (ICH-217)' do
      let(:split) do
        {flag: "\u{1F1EE}\u{1F1F9}", # due indicatori regionali, larghi 1
         ksha: "क\u094Dष", # coniugato devanagari: "क्" e "ष", larghi 1
         jamo: "한", # hangul con jamo LVT: "하" e U+11AB, largo 0
         keycap: "1\uFE0F\u20E3"} # "1️" e U+20E3, largo 0
      end

      # Prima di Unicode 15.1 (Ruby 3.x) anche Ruby divide il coniugato in due grapheme (la regola GB9c manca):
      # Cell.new lo rifiuta già con ArgumentError, come notcurses, e non c'è una differenza da spiegare.
      let(:ruby_conjunct) { split[:ksha].grapheme_clusters.size == 1 }
      let(:divided) { ruby_conjunct ? split : split.except(:ksha) }

      def message_for(name, egc)
        case name
        # ICH-586: Ghostty 1.4 e Kitty 0.51 disegnano la bandiera larga 2, come notcurses (prima il messaggio diceva
        # che molti terminali la disegnano più larga: lo faceva solo ncvt senza il modo 2027)
        when :flag, :ksha then /divide #{Regexp.escape(egc.inspect)} in 2 caratteri .*usa Plane#putstr(?!.*larga)/
        when :jamo then /#{Regexp.escape(egc.inspect)}.*largo 0.*Plane#putstr.*forma composta "\u{D55C}"/
        else /#{Regexp.escape(egc.inspect)}.*largo 0.*Plane#putstr/
        end
      end

      it 'Cell.new li accetta con le regole di Ruby' do
        divided.each_value do |egc|
          cell = described_class.new(egc: egc)
          expect([cell.egc, cell.width]).to eq([egc, Notcurses.strwidth(egc)])
        end
        expect { described_class.new(egc: split[:ksha]) }.to raise_error(ArgumentError, /grapheme/) unless ruby_conjunct
      end

      it 'putc e set_base sollevano CellError che nomina il grapheme e rimanda a Plane#putstr' do
        nc.stdplane.create_child(rows: 1, cols: 10) do |p|
          divided.each do |name, egc|
            cell = described_class.new(egc: egc)
            expect { p.putc(cell, y: 0, x: 0) }.to raise_error(Notcurses::CellError, message_for(name, egc)), name.to_s
            # prima: set_base teneva il primo pezzo ("🇮", "하", "क्", "1️") senza errore
            expect { p.set_base(egc: egc) }.to raise_error(Notcurses::CellError, message_for(name, egc)), name.to_s
          end
          expect([p.contents, p.base.egc]).to eq(['', ''])
        end
      end

      it 'le linee, il riempimento, il box e il gradiente sollevano CellError per il keycap (largo 1 colonna)' do
        nc.stdplane.create_child(rows: 3, cols: 6) do |p|
          keycap = split[:keycap]
          cell = described_class.new(egc: keycap)
          writes = {
            hline: -> { p.hline(cell, 2, y: 0, x: 0) },
            vline: -> { p.vline(cell, 2, y: 0, x: 0) },
            polyfill: -> { p.polyfill(cell, y: 0, x: 0) },
            box: -> { p.box(3, 3, y: 0, x: 0, set: [cell] * 6) },
            gradient: -> { p.gradient(keycap, 0, 0, 0, 0, rows: 1, cols: 2) }
          }
          writes.each do |name, write|
            expect { write.call }.to raise_error(Notcurses::CellError, message_for(:keycap, keycap)), name.to_s
          end
          expect(p.contents).to eq('')
        end
      end

      it 'Plane#putegc solleva CellError per bandiera e coniugato, ArgumentError per un pezzo largo 0' do
        nc.stdplane.create_child(rows: 1, cols: 10) do |p|
          (divided.keys & %i[flag ksha]).each do |name|
            expect { p.putegc(split[name], y: 0, x: 0) }.to raise_error(Notcurses::CellError, message_for(name, split[name]))
          end
          expect { p.putegc(split[:ksha], y: 0, x: 0) }.to raise_error(ArgumentError, /grapheme/) unless ruby_conjunct
          %i[jamo keycap].each do |name|
            expect { p.putegc(split[name], y: 0, x: 0) }.to raise_error(ArgumentError, /larghezza zero/)
          end
          expect(p.contents).to eq('')
        end
      end

      it 'Plane#putstr scrive bandiera e coniugato in due celle e rifiuta i grapheme con un pezzo largo 0' do
        nc.stdplane.create_child(rows: 1, cols: 10) do |p|
          {flag: ["\u{1F1EE}", "\u{1F1F9}"], ksha: ["क\u094D", "ष"]}.each do |name, pieces|
            p.erase
            expect(p.putstr(split[name], y: 0, x: 0)).to eq(2)
            expect([p.contents, p.at(y: 0, x: 0).egc, p.at(y: 0, x: 1).egc]).to eq([split[name], *pieces]), name.to_s
          end
          p.erase
          %i[jamo keycap].each do |name|
            expect { p.putstr(split[name], y: 0, x: 0) }.to raise_error(ArgumentError, /larghezza zero/), name.to_s
          end
          expect(p.contents).to eq('')
          composed = described_class.new(egc: split[:jamo].unicode_normalize(:nfc))
          expect(p.putc(composed, y: 0, x: 0)).to eq(2)
          expect(p.at(y: 0, x: 0)).to eq(composed)
        end
      end
    end

    it 'Plane#base restituisce una Cell con la larghezza del C' do
      nc.stdplane.create_child(rows: 1, cols: 3) do |p|
        p.set_base(egc: '漢', styles: :bold, channels: red)
        base = p.base
        expect(base).to eq(described_class.new(egc: '漢', styles: :bold, channels: red))
        expect(base.width).to eq(2)
      end
    end

    it 'Plane#set_base rifiuta TAB e "\n" come Cell.new: il TAB uscirebbe crudo verso il terminale' do
      nc.stdplane.create_child(rows: 1, cols: 3) do |p|
        expect { p.set_base(egc: "\t") }.to raise_error(ArgumentError, /controllo/)
        expect { p.set_base(egc: "\n") }.to raise_error(ArgumentError, /controllo/)
        expect(p.base).to be_empty
      end
    end
  end
end
