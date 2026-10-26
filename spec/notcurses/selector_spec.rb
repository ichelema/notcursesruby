# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative '../support/nc_helpers'

RSpec.describe Notcurses::Selector do
  let(:key) { Notcurses::Key }

  def ev(id, **opts) = Notcurses::Input.synthesize(id, **opts)

  # Testo della riga y del piano, letto con le funzioni raw.
  def row_text(plane, y)
    (0...plane.dim_x).map do |x|
      Notcurses::Util.take_string(Notcurses::FFI.ncplane_at_yx(plane.to_ptr, y, x, nil, nil))
    end.join
  end

  describe 'con un contesto aperto' do
    include_context 'con un contesto notcurses'

    let(:std) { nc.stdplane }

    def new_plane(rows: 1, cols: 1, y: 1, x: 1) = std.create_child(rows: rows, cols: cols, y: y, x: x)

    def planes = nc.stats.planes

    it 'new prende possesso del piano, lo ridimensiona e disegna le voci' do
      plane = new_plane
      before = planes
      sel = described_class.new(plane, items: [%w[a uno], %w[bb due], 'c'], title: 'Titolo', secondary: 's',
                                       footer: 'f', default: 1)
      expect(sel.selected).to eq('bb')
      expect(sel.plane).to equal(plane)
      expect(sel.context).to equal(nc)
      expect(plane).to be_widget_plane
      expect(plane).not_to be_owned
      expect(plane.dims).to eq([9, 10]) # 2 (titolo) + 4 + 3 voci; 2 + 3 + 5 colonne
      expect(row_text(plane, 1)).to include('Titolo')
      expect((0...9).map { |y| row_text(plane, y) }.join).to include('bb').and include('due')
      expect(planes).to eq(before)
      sel.close
      expect(planes).to eq(before - 1)
    end

    it 'accetta voci come String, coppie e Hash, con o senza descrizione' do
      described_class.open(new_plane, items: ['a', ['b'], ['c', nil], %w[d quattro]]) do |sel|
        expect([sel.selected, sel.next_item, sel.next_item, sel.next_item]).to eq(%w[a b c d])
      end
      described_class.open(new_plane, items: { 'x' => 'ics', 'y' => 'ipsilon' }) do |sel|
        expect([sel.selected, sel.next_item]).to eq(%w[x y])
      end
    end

    it 'next_item e prev_item scorrono in modo circolare' do
      described_class.open(new_plane, items: %w[a b c]) do |sel|
        expect([sel.next_item, sel.next_item, sel.next_item]).to eq(%w[b c a])
        expect([sel.prev_item, sel.prev_item]).to eq(%w[c b])
        expect(sel.selected).to eq('b')
      end
    end

    it 'max_display limita le voci visibili e default sceglie la voce iniziale' do
      described_class.open(new_plane, items: %w[a b c d e], max_display: 2, default: 4) do |sel|
        expect(sel.selected).to eq('e')
        expect(sel.plane.dim_y).to eq(6) # 4 + 2 voci visibili
      end
    end

    it 'add_item aggiunge in fondo, fa crescere il piano e non cambia la selezione' do
      described_class.open(new_plane, items: %w[a b]) do |sel|
        rows, cols = sel.plane.dims
        expect(sel.add_item('una voce lunga', desc: 'con descrizione')).to equal(sel)
        expect(sel.add_item('z')).to equal(sel)
        expect(sel.plane.dim_y).to eq(rows + 2)
        expect(sel.plane.dim_x).to be > cols
        expect(sel.selected).to eq('a')
        expect([sel.prev_item, sel.prev_item]).to eq(['z', 'una voce lunga'])
      end
    end

    it 'un selettore senza voci: selected, next_item e prev_item restituiscono nil' do
      described_class.open(new_plane) do |sel|
        expect([sel.selected, sel.next_item, sel.prev_item]).to eq([nil, nil, nil])
        expect(sel.add_item('primo').selected).to eq('primo')
      end
      # la chiusura di un selettore vuoto non passa il char** al C (segfault in 3.0.17)
      empty = described_class.new(new_plane)
      expect { empty.close }.not_to raise_error
    end

    it 'offer_input consuma frecce, rotella e pagine; non consuma rilasci, Invio, lettere ed eventi vuoti' do
      described_class.open(new_plane, items: %w[a b c d e], max_display: 2) do |sel|
        expect(sel.offer_input(ev(key::DOWN))).to be true
        expect(sel.selected).to eq('b')
        expect(sel.offer_input(ev(key::UP))).to be true
        expect(sel.offer_input(ev(key::SCROLL_DOWN))).to be true
        expect(sel.selected).to eq('b')
        expect(sel.offer_input(ev(key::SCROLL_UP))).to be true
        expect(sel.offer_input(ev(key::PGDOWN))).to be true # una pagina = 2 voci visibili
        expect(sel.selected).to eq('c')
        expect(sel.offer_input(ev(key::PGUP))).to be true
        expect(sel.selected).to eq('a')
        expect(sel.offer_input(ev(key::DOWN, evtype: :release))).to be false
        expect(sel.offer_input(ev(key::ENTER))).to be false
        expect(sel.offer_input(ev('x'.ord))).to be false
        expect(sel.offer_input(ev(0))).to be false
        expect(sel.offer_input(ev(0xffff_ffff))).to be false
        expect(sel.selected).to eq('a')
        expect { sel.offer_input(nil) }.to raise_error(TypeError)
      end
    end

    it 'offer_input con un clic seleziona la voce sotto il mouse' do
      described_class.open(new_plane(y: 2, x: 3), items: %w[a b c]) do |sel|
        y, x = sel.plane.abs_yx
        # senza titolo: riga 0 bordo, riga 1 freccia su, voci dalla riga 2
        expect(sel.offer_input(ev(key::BUTTON1, evtype: :release, y: y + 4, x: x + 3))).to be true
        expect(sel.selected).to eq('c')
        expect(sel.offer_input(ev(key::BUTTON1, evtype: :release, y: y + 2, x: x + 3))).to be true
        expect(sel.selected).to eq('a')
        expect(sel.offer_input(ev(key::BUTTON1, evtype: :release, y: 0, x: 0))).to be false # fuori dal piano
        expect(sel.offer_input(ev(key::BUTTON1, evtype: :press, y: y + 3, x: x + 3))).to be false
      end
    end

    it 'senza voci i tasti di navigazione sono consumati e i clic no' do
      described_class.open(new_plane) do |sel|
        y, x = sel.plane.abs_yx
        expect(sel.offer_input(ev(key::DOWN))).to be true
        expect(sel.offer_input(ev(key::BUTTON1, evtype: :release, y: y + 1, x: x + 1))).to be false
        expect(sel.selected).to be_nil
      end
    end

    it 'valida gli argomenti prima della chiamata C, senza toccare il piano' do
      plane = new_plane
      expect { described_class.new(:piano) }.to raise_error(TypeError)
      expect { described_class.new(plane, items: 'a') }.to raise_error(TypeError)
      expect { described_class.new(plane, items: [42]) }.to raise_error(TypeError)
      expect { described_class.new(plane, items: [%w[a b c]]) }.to raise_error(TypeError)
      expect { described_class.new(plane, items: ["a\tb"]) }.to raise_error(ArgumentError, /controllo/)
      expect { described_class.new(plane, items: [['a', "x\n"]]) }.to raise_error(ArgumentError)
      expect { described_class.new(plane, items: ["\xff".b]) }.to raise_error(ArgumentError, /UTF-8/)
      expect { described_class.new(plane, title: "\e[1m") }.to raise_error(ArgumentError)
      expect { described_class.new(plane, footer: 3) }.to raise_error(TypeError)
      expect { described_class.new(plane, items: %w[a b], default: 2) }.to raise_error(ArgumentError)
      expect { described_class.new(plane, default: 1) }.to raise_error(ArgumentError)
      expect { described_class.new(plane, max_display: -1) }.to raise_error(ArgumentError)
      expect { described_class.new(plane, op_channels: 'rosso') }.to raise_error(TypeError)
      expect { described_class.new(plane, box_channels: -1) }.to raise_error(ArgumentError)
      expect(plane).to be_owned
      expect(plane.dims).to eq([1, 1])
      plane.close
    end

    it 'accetta i colori come Channels o Integer' do
      white_on_blue = Notcurses::Channels.combine(Notcurses::Channel.rgb(255, 255, 255), Notcurses::Channel.rgb(0, 0, 255))
      described_class.open(new_plane, items: %w[a], op_channels: white_on_blue, desc_channels: white_on_blue.value,
                                      title_channels: white_on_blue, foot_channels: 0, box_channels: white_on_blue) do |sel|
        expect(sel.selected).to eq('a')
      end
    end

    it "rifiuta lo stdplane, il piano di un altro widget, un piano preso in prestito o chiuso" do
      expect { described_class.new(std) }.to raise_error(Notcurses::WidgetError, /stdplane/)
      first = described_class.new(new_plane, items: %w[a])
      expect { described_class.new(first.plane) }.to raise_error(Notcurses::WidgetError, /widget/)
      expect(first.selected).to eq('a') # il C avrebbe distrutto il piano e l'altro widget
      first.close
      raw = Notcurses::FFI.ncplane_create(std.to_ptr, Notcurses::FFI::NcPlaneOptions.new.tap { |o| o[:rows] = o[:cols] = 1 })
      borrowed = nc.top
      expect(borrowed).not_to be_owned
      expect { described_class.new(borrowed) }.to raise_error(Notcurses::WidgetError, /posseduto/)
      Notcurses::FFI.ncplane_destroy(raw)
      closed = new_plane
      closed.close
      expect { described_class.new(closed) }.to raise_error(Notcurses::ClosedError)
    end

    it 'close distrugge widget e piano, è idempotente e poi i metodi sollevano ClosedError' do
      plane = new_plane
      sel = described_class.new(plane, items: %w[a b])
      expect(sel.close).to be_nil
      expect(sel).to be_closed
      expect(plane).to be_closed
      expect(sel.close).to be_nil
      expect(sel.destroy).to be_nil
      expect { sel.selected }.to raise_error(Notcurses::ClosedError)
      expect { sel.next_item }.to raise_error(Notcurses::ClosedError)
      expect { sel.prev_item }.to raise_error(Notcurses::ClosedError)
      expect { sel.add_item('c') }.to raise_error(Notcurses::ClosedError)
      expect { sel.offer_input(ev(key::DOWN)) }.to raise_error(Notcurses::ClosedError)
      expect { sel.plane }.to raise_error(Notcurses::ClosedError)
      expect(sel.inspect).to include('chiuso')
    end

    it 'open con un blocco restituisce il valore del blocco e chiude il selettore' do
      kept = nil
      plane = new_plane
      result = described_class.open(plane, items: %w[a b]) do |sel|
        kept = sel
        sel.next_item
      end
      expect(result).to eq('b')
      expect(kept).to be_closed
      expect(plane).to be_closed
      expect(described_class.open(new_plane).tap(&:close)).to be_closed
    end

    it 'il piano resta del widget: Plane#close non lo distrugge, family_destroy di un antenato rifiuta' do
      parent = new_plane(rows: 20, cols: 30)
      plane = parent.create_child(rows: 1, cols: 1)
      grandchild = plane.create_child(rows: 1, cols: 1)
      sel = described_class.new(plane, items: %w[a])
      expect(plane.close).to be_nil
      expect(sel.selected).to eq('a')
      expect { parent.family_destroy }.to raise_error(Notcurses::PlaneError, /widget/)
      sel.close
      expect(grandchild).not_to be_closed # i figli del piano passano al genitore
      expect(grandchild.parent).to eq(parent)
      parent.family_destroy
      expect(grandchild).to be_closed
    end

    it "l'eccezione di un callback di resize di un figlio fa fallire la creazione" do
      plane = new_plane
      child = plane.create_child(rows: 1, cols: 1, resize: ->(_p) { raise 'resize rifiutato' })
      expect { described_class.new(plane, items: %w[a]) }.to raise_error(RuntimeError, 'resize rifiutato')
      expect(plane).to be_closed # il C distrugge il piano quando la creazione fallisce
      expect(child).not_to be_closed
      child.close
    end

    it 'non si crea dentro un callback chiamato da notcurses' do
      parent = new_plane(rows: 3, cols: 3)
      target = new_plane
      parent.create_child(rows: 1, cols: 1, resize: ->(_p) { described_class.new(target, items: %w[a]) })
      expect { parent.resize(4, 4) }.to raise_error(Notcurses::WidgetError, /callback/)
      expect(target).to be_owned
      parent.family_destroy
      target.close
    end
  end

  describe 'chiusura da parte del contesto' do
    it 'Context#close chiude il selettore aperto' do
      sel = plane = nil
      NcHelpers.open_context do |nc|
        plane = nc.stdplane.create_child(rows: 1, cols: 1)
        sel = described_class.new(plane, items: %w[a b])
      end
      expect(sel).to be_closed
      expect(plane).to be_closed
      expect(sel.close).to be_nil
    end

    it 'Context#drop_planes chiude il selettore aperto' do
      NcHelpers.open_context do |nc|
        sel = described_class.new(nc.stdplane.create_child(rows: 1, cols: 1), items: %w[a])
        nc.drop_planes
        expect(sel).to be_closed
        expect { sel.selected }.to raise_error(Notcurses::ClosedError)
        expect(nc.stats.planes).to eq(1)
      end
    end
  end
end
