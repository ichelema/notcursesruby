# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require_relative '../support/nc_helpers'

RSpec.describe Notcurses::Reader do
  let(:key) { Notcurses::Key }

  def ev(id, **opts) = Notcurses::Input.synthesize(id, **opts)

  def ctrl(letter) = ev(letter.ord, modifiers: [:ctrl])

  def alt(letter) = ev(letter.ord, modifiers: [:alt])

  describe 'con un contesto aperto' do
    include_context 'con un contesto notcurses'

    let(:std) { nc.stdplane }

    def new_plane(rows: 2, cols: 10) = std.create_child(rows: rows, cols: cols, y: 3, x: 3)

    def new_reader(rows: 2, cols: 10, **opts, &block) = described_class.open(new_plane(rows: rows, cols: cols), **opts, &block)

    it 'new prende possesso del piano, lo svuota e crea il piano nascosto del testo' do
      plane = new_plane
      Notcurses::FFI.ncplane_putstr_yx(plane.to_ptr, 0, 0, 'vecchio')
      Notcurses::FFI.ncplane_cursor_move_yx(plane.to_ptr, 1, 4)
      before = nc.stats.planes
      reader = described_class.new(plane)
      expect(nc.stats.planes).to eq(before + 1)
      expect(reader.plane).to equal(plane)
      expect(plane).to be_widget_plane
      expect(reader.contents).to eq('')
      expect(plane.cursor).to eq([0, 0])
      reader.close
      expect(nc.stats.planes).to eq(before - 1) # vista e piano nascosto
    end

    it 'write scrive grapheme cluster e restituisce self; in fondo alla riga sovrascrive l\'ultima colonna' do
      new_reader(rows: 1, cols: 5) do |reader|
        expect(reader.write('ab')).to equal(reader)
        expect(reader.contents).to eq('ab')
        expect(reader.plane.cursor).to eq([0, 2])
        reader.write('cdefg')
        expect(reader.contents).to eq('abcdg')
        reader.clear
        reader.write("e\u0301漢") # un grapheme di due codepoint e un glifo largo
        expect(reader.contents).to eq("e\u0301漢")
        expect(reader.write('')).to equal(reader)
      end
    end

    it 'write rifiuta i caratteri di controllo e i tipi sbagliati; un glifo largo che non entra dà WidgetError' do
      new_reader(rows: 1, cols: 5) do |reader|
        expect { reader.write("a\nb") }.to raise_error(ArgumentError, /controllo/)
        expect { reader.write("\e[1m") }.to raise_error(ArgumentError)
        expect { reader.write("\xff".b) }.to raise_error(ArgumentError, /UTF-8/)
        expect { reader.write(:testo) }.to raise_error(TypeError)
        expect(reader.contents).to eq('')
        reader.write('abcd')
        expect { reader.write('漢') }.to raise_error(Notcurses::WidgetError, /ncreader_write_egc/)
        expect(reader.contents).to eq('abcd')
      end
    end

    it 'un TAB scrive spazi fino alla tabulazione; nell\'ultima colonna uno spazio (il C scriverebbe oltre la riga)' do
      new_reader(rows: 2, cols: 5) do |reader|
        reader.write("a\tb")
        expect(reader.contents).to eq('a   b')
        reader.move_down
        reader.move_right
        expect(reader.contents).to eq('a   b')
        reader.clear
        reader.write('abcd')
        expect(reader.offer_input(ev(key::TAB))).to be true
        expect(reader.contents).to eq('abcd ') # la riga sotto resta vuota
        reader.write("\t")
        expect(reader.contents).to eq('abcd ')
      end
    end

    it 'offer_input scrive il testo degli eventi, anche di 4 codepoint, e non consuma rilasci e tasti speciali' do
      new_reader do |reader|
        expect(reader.offer_input(ev('a'.ord))).to be true
        expect(reader.offer_input(ev('b'.ord, modifiers: [:shift], eff_text: 'B'))).to be true
        expect(reader.offer_input(ev('x'.ord, eff_text: 'wxyz'))).to be true # il C leggerebbe oltre eff_text
        expect(reader.contents).to eq('aBwxyz')
        expect(reader.offer_input(ev(key::ESC))).to be true # consumato, non scrive nulla
        expect(reader.offer_input(ev('c'.ord, evtype: :release))).to be false
        expect(reader.offer_input(ev(key::ENTER))).to be false
        expect(reader.offer_input(ev(key::F01))).to be false
        expect(reader.offer_input(ev(0))).to be false
        expect(reader.offer_input(ev(0xffff_ffff))).to be false
        expect(reader.contents).to eq('aBwxyz')
        expect { reader.offer_input('a') }.to raise_error(TypeError)
      end
    end

    it 'offer_input: frecce e Backspace' do
      new_reader do |reader|
        reader.write('abc')
        expect(reader.offer_input(ev(key::LEFT))).to be true
        expect(reader.offer_input(ev(key::BACKSPACE))).to be true
        expect(reader.contents).to eq('ac') # cancella la cella, senza spostare il resto
        expect(reader.plane.cursor).to eq([0, 1])
        expect(reader.offer_input(ev(key::RIGHT))).to be true
        expect(reader.offer_input(ev(key::DOWN))).to be true
        expect(reader.offer_input(ev(key::DOWN))).to be true # consumata anche senza spostamento
        expect(reader.offer_input(ev(key::UP))).to be true
        expect(reader.plane.cursor).to eq([0, 2])
      end
    end

    it 'Backspace subito dopo il carattere della colonna 0 lo cancella, anche sotto la prima riga (prima: restava)' do
      new_reader(rows: 2, cols: 6) do |reader|
        reader.write('ab')
        2.times { expect(reader.offer_input(ev(key::BACKSPACE))).to be true }
        expect([reader.contents, reader.plane.at(y: 0, x: 0).egc, reader.plane.cursor]).to eq(['', '', [0, 0]])
        expect(reader.offer_input(ev(key::BACKSPACE))).to be true # in (0, 0) non fa nulla
        reader.write('c')
        reader.move_down
        reader.offer_input(ctrl('A'))
        reader.write('d')
        expect(reader.offer_input(ev(key::BACKSPACE))).to be true
        expect([reader.contents, reader.plane.cursor]).to eq(['c', [1, 0]])
        reader.write('e')
        expect(reader.contents).to eq('ce')
      end
    end

    it 'Backspace cancella il glifo largo della colonna 0, anche con il cursore a metà glifo, senza metà orfane' do
      [2, 1].each do |col|
        new_reader(rows: 1, cols: 6) do |reader|
          reader.write('漢')
          reader.move_left if col == 1 # la freccia sinistra sposta di una colonna
          expect(reader.offer_input(ev(key::BACKSPACE))).to be true
          expect([reader.contents, reader.plane.at(y: 0, x: 0).egc]).to eq(['', '']), "cursore in colonna #{col}"
          expect(orphan_wide_right?(reader.plane, 0)).to be(false)
          reader.offer_input(ctrl('A')) # dalla colonna 2 il C lascia il cursore in colonna 1
          reader.write('漢漢漢')
          expect(reader.contents).to eq('漢漢漢')
        end
      end
    end

    it 'Ctrl+U cancella anche il carattere della colonna 0, ASCII o glifo largo (prima: restava)' do
      new_reader(rows: 1, cols: 6) do |reader|
        reader.write('abc')
        reader.move_left
        expect(reader.offer_input(ctrl('U'))).to be true
        expect([reader.contents, reader.plane.cursor]).to eq(['c', [0, 0]])
        reader.clear.write('漢')
        reader.move_left
        expect(reader.offer_input(ctrl('U'))).to be true
        expect([reader.contents, orphan_wide_right?(reader.plane, 0)]).to eq(['', false])
      end
    end

    it 'Ctrl+W cancella la parola che parte dalla colonna 0 e lascia lo spazio della colonna 0 (prima: restava)' do
      new_reader(rows: 1, cols: 8) do |reader|
        reader.write('ab')
        expect(reader.offer_input(ctrl('W'))).to be true
        expect([reader.contents, reader.plane.cursor]).to eq(['', [0, 0]])
        reader.write('ab cd')
        3.times { reader.move_left }
        expect(reader.offer_input(ctrl('W'))).to be true
        expect(reader.contents).to eq(' cd')
        reader.clear.write(' ab') # uno spazio in colonna 0 ferma la parola, come per il C
        expect(reader.offer_input(ctrl('W'))).to be true
        expect([reader.contents, reader.plane.cursor]).to eq([' ', [0, 0]])
        reader.clear.write('漢')
        reader.move_left
        expect(reader.offer_input(ctrl('W'))).to be true
        expect([reader.contents, orphan_wide_right?(reader.plane, 0)]).to eq(['', false])
      end
    end

    it 'Backspace a inizio riga torna alla riga sopra con vista e testo allineati (prima: abort con la freccia sinistra)' do
      new_reader(rows: 3, cols: 5, cursor: true) do |reader| # cursor: true, il reader sposta il cursore del terminale
        reader.write('abcde')
        reader.move_down
        reader.offer_input(ctrl('A'))
        expect(reader.plane.cursor).to eq([1, 0])
        expect(reader.offer_input(ev(key::BACKSPACE))).to be true
        expect(reader.plane.cursor).to eq([0, 4])
        expect(nc.cursor_yx).to eq([3, 7]) # cursore del terminale: piano in (3, 3)
        expect(reader.contents).to eq('abcd')
        3.times { expect(reader.offer_input(ev(key::LEFT))).to be true }
        expect(reader.plane.cursor).to eq([0, 1])
        expect(reader.move_left).to be true
        expect(reader.move_left).to be false
        reader.write('Z')
        expect(reader.contents).to eq('Zbcd')
      end
    end

    # true se nella riga y del piano c'è una metà destra di glifo largo (gcluster 0,
    # width >= 2) senza la sua metà sinistra
    def orphan_wide_right?(plane, y)
      cell = Notcurses::FFI::NcCell.new
      cells = (0...plane.dim_x).map do |x|
        Notcurses::FFI.ncplane_at_yx_cell(plane.to_ptr, y, x, cell)
        [cell[:gcluster], cell[:width]]
      end
      cells.each_cons(2).any? { |(left, _), (right, width)| right.zero? && width >= 2 && left.zero? }
    ensure
      Notcurses::FFI.nccell_release(plane.to_ptr, cell)
    end

    it 'Backspace, Ctrl+U e Ctrl+W su un glifo largo non lasciano nella vista una metà destra orfana' do
      [ev(key::BACKSPACE), ctrl('U'), ctrl('W')].each do |input|
        new_reader(rows: 1, cols: 6) do |reader|
          reader.write('漢漢漢')
          reader.offer_input(ev(key::RIGHT))
          expect(reader.offer_input(input)).to be true
          expect(reader.contents).to eq('漢漢') if input.id == key::BACKSPACE
          expect(orphan_wide_right?(reader.plane, 0)).to be(false), input.inspect
          expect(reader.plane.cursor).to eq(input.id == key::BACKSPACE ? [0, 4] : [0, 0])
        end
      end
    end

    it 'dopo Backspace, Ctrl+U e Ctrl+W le metà destre dei glifi larghi della vista restano larghe (prima: width 0)' do
      [ev(key::BACKSPACE), ctrl('U'), ctrl('W')].each do |input|
        new_reader(rows: 1, cols: 8) do |reader|
          reader.write('漢漢漢')
          2.times { reader.move_left } # colonna 4: glifi prima e dopo il cursore
          expect(reader.offer_input(input)).to be true
          cell = Notcurses::FFI::NcCell.new
          widths = (0...8).map do |x|
            Notcurses::FFI.ncplane_at_yx_cell(reader.plane.to_ptr, 0, x, cell)
            cell[:width].tap { Notcurses::FFI.nccell_release(reader.plane.to_ptr, cell) }
          end
          lefts = (0...8).step(2).select { |x| reader.plane.at(y: 0, x: x).egc == '漢' } # metà sinistre
          expect(lefts).not_to be_empty, input.inspect
          lefts.each do |x|
            expect([widths[x + 1], reader.plane.at(y: 0, x: x + 1).egc]).to eq([2, '漢']), "#{input.inspect} x=#{x + 1}"
          end
        end
      end
    end

    it 'il glifo largo scritto in fondo alla riga dopo quei tasti resta nel piano (prima: heap corrotto, abort)' do
      skip 'serve libc_malloc_debug di glibc' unless File.exist?('/usr/lib/libc_malloc_debug.so.0')
      script = <<~'RUBY'
        require 'notcurses'
        ev = ->(id, **o) { Notcurses::Input.synthesize(id, **o) }
        keys = [ev.(Notcurses::Key::BACKSPACE), ev.('U'.ord, modifiers: [:ctrl]), ev.('W'.ord, modifiers: [:ctrl])]
        Notcurses::Context.open(output: '/dev/null', termtype: 'xterm-256color', suppress_banners: true) do |nc|
          keys.each do |input|
            Notcurses::Reader.open(nc.stdplane.create_child(rows: 1, cols: 6)) do |reader|
              reader.write('漢漢漢')
              reader.move_right
              reader.offer_input(input)
              reader.move_right while reader.plane.cursor[1] < 4
              reader.write('漢') # in colonna 4: con la metà destra orfana in 5 il C scriveva oltre la riga
            end
          end
        end
        puts 'ok'
      RUBY
      env = { 'TERM' => 'xterm-256color', 'LD_PRELOAD' => '/usr/lib/libc_malloc_debug.so.0', 'MALLOC_CHECK_' => '3' }
      lib = File.expand_path('../../lib', __dir__)
      out, status = Open3.capture2e(env, NcHelpers::TIMEOUT, '-k', '5', '-s', 'KILL', '30', RbConfig.ruby, '-I', lib, '-e', script,
                                    stdin_data: '')
      expect([status.exitstatus, out]).to eq([0, "ok\n"])
    end

    it 'Backspace, Ctrl+U e Ctrl+W sulla colonna 0 la svuotano senza corrompere l\'heap' do
      skip 'serve libc_malloc_debug di glibc' unless File.exist?('/usr/lib/libc_malloc_debug.so.0')
      script = <<~'RUBY'
        require 'notcurses'
        ev = ->(id, **o) { Notcurses::Input.synthesize(id, **o) }
        keys = [ev.(Notcurses::Key::BACKSPACE), ev.('U'.ord, modifiers: [:ctrl]), ev.('W'.ord, modifiers: [:ctrl])]
        Notcurses::Context.open(output: '/dev/null', termtype: 'xterm-256color', suppress_banners: true) do |nc|
          keys.product(%w[a 漢]).each do |input, glyph|
            Notcurses::Reader.open(nc.stdplane.create_child(rows: 1, cols: 6)) do |reader|
              reader.write(glyph)
              reader.move_left # sul glifo largo: cursore a metà, in colonna 1
              reader.move_right if glyph == 'a'
              reader.offer_input(input)
              raise "#{input.id} #{glyph}: #{reader.contents.inspect}" unless reader.contents.empty?
              reader.write('漢漢漢')
              reader.move_right while reader.plane.cursor[1] < 4
              reader.write('漢')
            end
          end
        end
        puts 'ok'
      RUBY
      env = { 'TERM' => 'xterm-256color', 'LD_PRELOAD' => '/usr/lib/libc_malloc_debug.so.0', 'MALLOC_CHECK_' => '3' }
      lib = File.expand_path('../../lib', __dir__)
      out, status = Open3.capture2e(env, NcHelpers::TIMEOUT, '-k', '5', '-s', 'KILL', '30', RbConfig.ruby, '-I', lib, '-e', script,
                                    stdin_data: '')
      expect([status.exitstatus, out]).to eq([0, "ok\n"])
    end

    it "un carattere di larghezza zero nell'ultima colonna viene scartato (prima: cursore oltre la riga, testo perso)" do
      new_reader(rows: 1, cols: 8) do |reader|
        reader.write('Mi piace')
        expect(reader.plane.cursor).to eq([0, 7])
        expect([0x2764, 0xFE0F].map { |cp| reader.offer_input(ev(cp)) }).to eq([true, true]) # "❤️" digitato
        expect([reader.plane.cursor, reader.contents]).to eq([[0, 7], 'Mi piac❤'])
        expect(reader.offer_input(ev('x'.ord))).to be true
        expect(reader.contents).to eq('Mi piacx')
      end
      ["\u200B", "\u0301"].each do |zw|
        new_reader(rows: 1, cols: 8) do |reader|
          reader.write('Mi piace').write(zw)
          expect(reader.plane.cursor).to eq([0, 7]), zw.inspect
          expect(reader.write('x').contents).to eq('Mi piacx')
        end
      end
      new_reader(rows: 1, cols: 8) do |reader| # prima dell'ultima colonna ha una cella propria, come prima
        expect(reader.write("ab\u200Bc").contents).to eq("ab\u200Bc")
        expect(reader.plane.cursor).to eq([0, 4])
      end
    end

    it "Backspace e un tasto verso sinistra dopo un carattere di larghezza zero nell'ultima colonna (prima: abort)" do
      script = <<~'RUBY'
        require 'notcurses'
        ev = ->(id, **o) { Notcurses::Input.synthesize(id, **o) }
        keys = { 'left' => ev.(Notcurses::Key::LEFT), 'ctrl_b' => ev.('B'.ord, modifiers: [:ctrl]),
                 'ctrl_w' => ev.('W'.ord, modifiers: [:ctrl]) }
        Notcurses::Context.open(output: '/dev/null', termtype: 'xterm-256color', suppress_banners: true) do |nc|
          Notcurses::Reader.open(nc.stdplane.create_child(rows: 1, cols: 8)) do |reader|
            reader.write('Mi piace')
            [0x2764, 0xFE0F].each { |cp| reader.offer_input(ev.(cp)) }
            reader.offer_input(ev.(Notcurses::Key::BACKSPACE))
            ARGV[0] == 'move_left' ? reader.move_left : reader.offer_input(keys.fetch(ARGV[0]))
            raise "cursore #{reader.plane.cursor}" unless ARGV[0] == 'ctrl_w' || reader.plane.cursor == [0, 5]
          end
        end
        puts 'ok'
      RUBY
      lib = File.expand_path('../../lib', __dir__)
      %w[left ctrl_b ctrl_w move_left].each do |final|
        out, status = Open3.capture2e({ 'TERM' => 'xterm-256color' }, NcHelpers::TIMEOUT, '-k', '5', '-s', 'KILL', '30',
                                      RbConfig.ruby, '-I', lib, '-e', script, final, stdin_data: '')
        expect([status.exitstatus, out]).to eq([0, "ok\n"]), final
      end
    end

    it 'write non perde i grapheme che notcurses divide' do
      # keycap, bandiera e congiunto devanagari: notcurses li divide, ogni pezzo ha una cella
      ["1\u{FE0F}\u{20E3}x", "\u{1F1EE}\u{1F1F9}x", "क\u094Dषx"].each do |text|
        new_reader(rows: 1, cols: 10) do |reader|
          expect([reader.write(text).contents, reader.plane.cursor]).to eq([text, [0, 3]]), text.inspect
        end
      end
      { "\u{1F44D}\u{1F3FD}x" => [0, 3], "e\u0301x" => [0, 2], "❤\u{FE0F}x" => [0, 2] }.each do |text, cursor|
        new_reader(rows: 1, cols: 10) do |reader|
          expect([reader.write(text).contents, reader.plane.cursor]).to eq([text, cursor]), text.inspect
        end
      end
      # U+2028 dipende da wcwidth della libc (egcpool.h:130-137). glibc: -1, nccell_load legge 1 byte e
      # il C riceve il carattere intero, che rifiuta. macOS: 0, U+2028 è un EGC intero e il C lo scrive.
      new_reader(rows: 1, cols: 10) do |reader|
        if ::FFI::Platform.mac?
          expect(reader.write("a\u2028b").contents).to eq("a\u2028b")
        else
          expect { reader.write("a\u2028b") }.to raise_error(Notcurses::WidgetError, /"\\u2028"/)
          expect(reader.contents).to eq('a')
        end
      end
    end

    it 'write solleva WidgetError se nccell_load fallisce (per esempio con l\'egcpool della vista pieno)' do
      new_reader(rows: 1, cols: 10) do |reader|
        allow(Notcurses::FFI).to receive(:nccell_load).and_return(-1)
        expect(Notcurses::FFI).not_to receive(:ncreader_write_egc)
        expect { reader.write("1\u{FE0F}\u{20E3}x") }.to raise_error(Notcurses::WidgetError, /nccell_load/)
      end
    end

    it 'se nccell_load fallisce a metà grapheme il primo pezzo resta scritto e il resto non arriva al C' do
      new_reader(rows: 1, cols: 10) do |reader|
        calls = 0
        allow(Notcurses::FFI).to receive(:nccell_load).and_wrap_original { |m, *a| (calls += 1) == 1 ? m.call(*a) : -1 }
        allow(Notcurses::FFI).to receive(:ncreader_write_egc).and_call_original
        expect { reader.write("1\u{FE0F}\u{20E3}") }.to raise_error(Notcurses::WidgetError, /nccell_load/)
        expect(Notcurses::FFI).to have_received(:ncreader_write_egc).once
        expect(reader.contents).to eq("1\u{FE0F}")
      end
    end

    it "un pezzo di larghezza zero di un grapheme diviso, sull'ultima colonna, viene scartato" do
      new_reader(rows: 1, cols: 5) do |reader|
        reader.write("abcd1\u{FE0F}\u{20E3}") # U+20E3 resta da solo sull'ultima colonna
        expect(reader.plane.cursor).to eq([0, 4])
        expect(reader.write('x').contents).to eq('abcdx')
      end
    end

    it "contents non fa crescere l'egcpool della vista" do
      text = ("e#{"\u0301" * 50}") * 10 # 10 EGC di 101 byte: stanno nell'egcpool della vista
      new_reader(rows: 1, cols: 10) do |reader|
        reader.write(text)
        expect(20_000.times.count { reader.contents == text }).to eq(20_000) # prima: WidgetError dopo circa 16 450
      end
    end

    it 'uno spostamento fallito del cursore della vista solleva WidgetError prima della chiamata C' do
      new_reader(rows: 1, cols: 8) do |reader|
        reader.write('abc')
        allow(Notcurses::FFI).to receive(:ncplane_cursor_move_yx).and_return(-1)
        expect(Notcurses::FFI).not_to receive(:ncreader_move_left)
        expect { reader.move_left }.to raise_error(Notcurses::WidgetError, /ncplane_cursor_move_yx/)
      end
      allow(Notcurses::FFI).to receive(:ncplane_cursor_move_yx).and_call_original
      new_reader(rows: 1, cols: 8) do |reader|
        reader.write('abc')
        allow(Notcurses::FFI).to receive(:ncplane_cursor_move_yx).and_return(0, -1) # prepare!, poi il workaround
        expect(Notcurses::FFI).not_to receive(:ncreader_offer_input)
        expect { reader.offer_input(ev(key::BACKSPACE)) }.to raise_error(Notcurses::WidgetError, /ncplane_cursor_move_yx/)
      end
    end

    it 'le scorciatoie con Ctrl e Alt' do
      new_reader(rows: 1, cols: 10) do |reader|
        reader.write('uno due')
        expect(reader.offer_input(ctrl('A'))).to be true
        expect(reader.plane.cursor).to eq([0, 0])
        expect(reader.offer_input(ctrl('F'))).to be true
        expect(reader.offer_input(ctrl('B'))).to be true
        expect(reader.plane.cursor).to eq([0, 0])
        expect(reader.offer_input(alt('f'))).to be true
        expect(reader.plane.cursor).to eq([0, 3])
        expect(reader.offer_input(ctrl('E'))).to be true
        expect(reader.plane.cursor).to eq([0, 9])
        expect(reader.offer_input(alt('b'))).to be true
        expect(reader.plane.cursor).to eq([0, 3])
        reader.offer_input(ctrl('E'))
        reader.move_left
        reader.move_left
        expect(reader.offer_input(ctrl('W'))).to be true
        expect(reader.contents).to eq('uno ')
        expect(reader.offer_input(ctrl('U'))).to be true
        expect(reader.contents).to eq(' ') # anche la colonna 0 (3.0.17 la lasciava: 'u ')
        expect(reader.plane.cursor).to eq([0, 0])
        expect(reader.offer_input(ctrl('a'))).to be false # le lettere con Ctrl arrivano maiuscole
        expect(reader.offer_input(ctrl('Z'))).to be false
        expect(reader.offer_input(alt('x'))).to be false
      end
    end

    it 'no_cmd_keys lascia Ctrl e Alt all\'applicazione' do
      new_reader(no_cmd_keys: true) do |reader|
        reader.write('ab')
        expect(reader.offer_input(ctrl('A'))).to be false
        expect(reader.offer_input(alt('b'))).to be false
        expect(reader.offer_input(ev('q'.ord, modifiers: [:ctrl], eff_text: 'q'))).to be false
        expect(reader.plane.cursor).to eq([0, 2])
        expect(reader.contents).to eq('ab')
      end
    end

    it 'move_left, move_right, move_up e move_down dicono se il cursore si è spostato' do
      new_reader(rows: 2, cols: 3) do |reader|
        expect(reader.move_left).to be false
        expect(reader.move_up).to be false
        expect(reader.move_right).to be true
        expect(reader.move_down).to be true
        expect(reader.plane.cursor).to eq([1, 1])
        expect(reader.move_down).to be false
        expect(reader.move_right).to be true
        expect(reader.move_right).to be false # ultima colonna dell'ultima riga
        expect(reader.move_up).to be true
        expect(reader.move_right).to be true # dall'ultima colonna all'inizio della riga sotto
        expect(reader.plane.cursor).to eq([1, 0])
        expect(reader.move_left).to be true # dalla colonna 0 all'ultima colonna della riga sopra
        expect(reader.plane.cursor).to eq([0, 2])
      end
    end

    it 'clear svuota il testo e riporta il cursore in (0, 0)' do
      new_reader do |reader|
        reader.write('testo')
        expect(reader.clear).to equal(reader)
        expect(reader.contents).to eq('')
        expect(reader.plane.cursor).to eq([0, 0])
      end
    end

    it 'protegge vista e testo nascosto dalle modifiche al piano' do
      new_reader(rows: 1, cols: 5) do |reader|
        reader.write('abc')
        reader.plane.move_cursor(0, 0) # il C allineerebbe male vista e testo (lettura fuori dal piano)
        expect(reader.move_left).to be true
        expect(reader.plane.cursor).to eq([0, 2])
        reader.plane.autogrow = true
        expect { reader.write('d') }.to raise_error(Notcurses::WidgetError, /autogrow/)
        reader.plane.autogrow = false
        reader.plane.scrolling = true
        expect { reader.offer_input(ev('d'.ord)) }.to raise_error(Notcurses::WidgetError)
        reader.plane.scrolling = false
        reader.plane.resize(1, 8)
        expect { reader.move_right }.to raise_error(Notcurses::WidgetError, /ridimensionato/)
        reader.plane.resize(1, 5)
        expect(reader.move_right).to be true
        expect(reader.contents).to eq('abc')
      end
    end

    it 'rifiuta lo stdplane, il piano di un widget, piani con scrolling o autogrow e opzioni non valide' do
      expect { described_class.new(std) }.to raise_error(Notcurses::WidgetError, /stdplane/)
      new_reader do |reader|
        expect { described_class.new(reader.plane) }.to raise_error(Notcurses::WidgetError, /widget/)
        expect(reader.contents).to eq('')
      end
      plane = new_plane
      plane.scrolling = true
      expect { described_class.new(plane) }.to raise_error(Notcurses::WidgetError, /scrolling/)
      plane.scrolling = false
      plane.autogrow = true
      expect { described_class.new(plane) }.to raise_error(Notcurses::WidgetError, /autogrow/)
      plane.autogrow = false
      expect { described_class.new(plane, cursor: 1) }.to raise_error(TypeError)
      expect { described_class.new(plane, no_cmd_keys: nil) }.to raise_error(TypeError)
      # HORSCROLL non è offerto: con due glifi larghi il C termina il processo (asserzione xproject >= 0)
      expect { described_class.new(plane, horizontal_scroll: true) }.to raise_error(ArgumentError)
      expect(plane).to be_owned
      plane.close
    end

    it 'cursor: true è accettato e la chiusura spegne il cursore senza errori' do
      new_reader(cursor: true) { |reader| reader.write('a') }
    end

    it 'con cursor: false ogni ridisegno rispegne il cursore del terminale, che il C accende (prima: restava acceso)' do
      nc.cursor_disable # stato noto (il contesto è dell'intero file): nascosto
      new_reader do |reader|
        expect(Notcurses::FFI).to receive(:notcurses_cursor_disable).exactly(4).times.and_call_original
        reader.write('a')
        reader.offer_input(ev(key::BACKSPACE))
        reader.move_right
        reader.offer_input(ev('b'.ord))
      end
      expect(Notcurses::FFI).not_to receive(:notcurses_cursor_disable)
      expect(nc.cursor_disable).to equal(nc) # resta nascosto per il wrapper: idempotente, senza chiamare il C
    end

    it 'con cursor: false il ridisegno rimette il cursore acceso nella posizione di Context#cursor_enable' do
      nc.cursor_enable(y: 1, x: 2)
      new_reader do |reader|
        expect(Notcurses::FFI).to receive(:notcurses_cursor_enable).with(nc.to_ptr, 1, 2).twice.and_call_original
        reader.write('a')
        reader.move_left
      end
      # senza un tty il C non spegne il cursore acceso, e cursor_disable solleva: un reader con cursor: true rende
      # lo stato sconosciuto, e cursor_disable lo tollera
      new_reader(cursor: true) { |reader| reader.write('a') }
      expect(nc.cursor_disable).to equal(nc)
    end

    it 'con cursor: true il reader lascia acceso il cursore del terminale nel campo, come vuole notcurses' do
      new_reader(cursor: true) do |reader|
        expect(Notcurses::FFI).not_to receive(:notcurses_cursor_disable)
        expect(Notcurses::FFI).not_to receive(:notcurses_cursor_enable)
        reader.write('a')
        reader.move_left
      end
    end

    it 'Context#cursor_disable non solleva se la chiusura di un reader con cursor: true ha già spento il cursore' do
      nc.cursor_enable(y: 1, x: 2)
      new_reader(cursor: true) { |reader| reader.write('a') }
      expect(nc.cursor_disable).to equal(nc)
    end

    it 'close distrugge vista e piano nascosto, è idempotente e poi i metodi sollevano ClosedError' do
      plane = new_plane
      reader = described_class.new(plane)
      reader.write('x')
      expect(reader.close).to be_nil
      expect([reader, plane]).to all(be_closed)
      expect(reader.destroy).to be_nil
      expect { reader.contents }.to raise_error(Notcurses::ClosedError)
      expect { reader.write('a') }.to raise_error(Notcurses::ClosedError)
      expect { reader.offer_input(ev('a'.ord)) }.to raise_error(Notcurses::ClosedError)
      expect { reader.clear }.to raise_error(Notcurses::ClosedError)
      expect { reader.move_left }.to raise_error(Notcurses::ClosedError)
      expect { reader.move_right }.to raise_error(Notcurses::ClosedError)
      expect { reader.move_up }.to raise_error(Notcurses::ClosedError)
      expect { reader.move_down }.to raise_error(Notcurses::ClosedError)
      expect { reader.plane }.to raise_error(Notcurses::ClosedError)
    end

    it 'open con un blocco restituisce il valore del blocco e chiude il reader' do
      kept = nil
      result = new_reader do |reader|
        kept = reader
        reader.write('ciao').contents
      end
      expect(result).to eq('ciao')
      expect(kept).to be_closed
    end

    it 'non si crea dentro un callback chiamato da notcurses' do
      parent = std.create_child(rows: 3, cols: 3)
      target = new_plane
      parent.create_child(rows: 1, cols: 1, resize: ->(_p) { described_class.new(target) })
      expect { parent.resize(4, 4) }.to raise_error(Notcurses::WidgetError, /callback/)
      parent.family_destroy
      target.close
    end
  end

  describe 'chiusura da parte del contesto (notcurses_stop con un reader vivo: double free in 3.0.17)' do
    it 'Context#close chiude i reader aperti' do
      readers = []
      planes = []
      NcHelpers.open_context do |nc|
        2.times { planes << nc.stdplane.create_child(rows: 1, cols: 5) }
        planes.each { |plane| readers << described_class.new(plane).write('ab') }
      end
      expect(readers + planes).to all(be_closed)
    end

    it 'Context#drop_planes chiude i reader aperti' do
      NcHelpers.open_context do |nc|
        reader = described_class.new(nc.stdplane.create_child(rows: 1, cols: 5))
        reader.write('ab')
        nc.drop_planes
        expect(reader).to be_closed
        expect(nc.stats.planes).to eq(1)
      end
    end
  end
end
