# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

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
        reader.write("é漢") # un grapheme di due codepoint e un glifo largo
        expect(reader.contents).to eq("é漢")
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

    it 'Backspace non cancella la colonna 0 (bug di 3.0.17 non aggirato): la scrittura successiva la sovrascrive' do
      new_reader do |reader|
        reader.write('ab')
        2.times { expect(reader.offer_input(ev(key::BACKSPACE))).to be true }
        expect(reader.contents).to eq('a')
        expect(reader.plane.cursor).to eq([0, 0])
        expect(reader.offer_input(ev(key::BACKSPACE))).to be true # in (0, 0) non fa nulla
        reader.write('c')
        expect(reader.contents).to eq('c')
      end
    end

    it 'Backspace a inizio riga torna alla riga sopra con vista e testo allineati (prima: abort con la freccia sinistra)' do
      new_reader(rows: 3, cols: 5) do |reader|
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
        expect(reader.contents).to eq('u ') # la colonna 0 non si cancella (3.0.17)
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

    it 'dopo il ridisegno, che accende il cursore del terminale, Context#cursor_disable chiama il C' do
      new_reader do |reader|
        reader.write('a')
        expect(Notcurses::FFI).to receive(:notcurses_cursor_disable).once.and_call_original
        expect(nc.cursor_disable).to equal(nc) # senza un tty il C fallisce: il cursore era forse già nascosto
        expect(nc.cursor_disable).to equal(nc) # di nuovo idempotente, senza chiamare il C
      end
    end

    it 'Context#cursor_disable non solleva se la chiusura di un reader con cursor: true ha già spento il cursore' do
      nc.cursor_enable(1, 2)
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
