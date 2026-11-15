# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require_relative '../support/nc_helpers'

RSpec.describe Notcurses::Plane do
  include_context 'con un contesto notcurses'

  let(:std) { nc.stdplane }

  # Figlio dello stdplane distrutto alla fine dell'esempio.
  # Figlio dello stdplane per un esempio. Alla fine distrugge l'intera famiglia:
  # close riaggancerebbe allo stdplane i figli creati nell'esempio, e un piano
  # rimasto (per esempio in fondo allo z-order) cambierebbe gli esempi successivi.
  def with_parent(rows: 10, cols: 20, y: 3, x: 4, **opts)
    parent = std.create_child(rows: rows, cols: cols, y: y, x: x, **opts)
    yield parent
  ensure
    parent.family_destroy if parent && !parent.closed?
  end

  # Piani della pila dello stdplane, dall'alto in basso.
  def z_order
    planes = []
    plane = nc.top
    while plane
      planes << plane
      plane = plane.below
    end
    planes
  end

  # Testo della riga y letto con le funzioni raw (l'output di Plane è provato altrove).
  def raw_put(plane, y, x, text) = Notcurses::FFI.ncplane_putstr_yx(plane.to_ptr, y, x, text)

  describe 'creazione e distruzione' do
    it 'create_child crea un figlio posseduto, chiuso dal blocco' do
      kept = nil
      result = std.create_child(rows: 10, cols: 20, y: 3, x: 4) do |parent|
        child = parent.create_child(rows: 2, cols: 3, y: 1, x: 2, name: 'figlio')
        kept = child
        expect(child).to be_owned
        expect(child.dims).to eq([2, 3])
        expect(child.yx).to eq([1, 2])
        expect(child.abs_yx).to eq([4, 6])
        expect(child.name).to eq('figlio')
        expect(child.parent).to equal(parent)
        expect(child.context).to equal(nc)
        :ok
      end
      expect(result).to eq(:ok)
      expect(kept).not_to be_closed # il blocco chiude solo il genitore: il figlio passa allo stdplane
      expect(kept.parent).to eq(std)
      kept.close
    end

    it 'accetta gli allineamenti come simboli' do
      with_parent do |parent|
        c = parent.create_child(rows: 2, cols: 4, y: :bottom, x: :center)
        expect(c.yx).to eq([8, 8])
        parent.resize(12, 30)
        c.resize_realign
        expect(c.yx).to eq([10, 13])
        expect { parent.create_child(rows: 1, cols: 1, x: :top) }.to raise_error(ArgumentError)
        expect { parent.create_child(rows: 1, cols: 1, y: :middle) }.to raise_error(ArgumentError)
      end
    end

    it 'margins: calcola dimensioni e posizione in Ruby (MARGINALIZED di 3.0.17 ignora alto e sinistra)' do
      with_parent do |parent|
        m = parent.create_child(margins: [1, 2, 3, 4])
        expect(m.dims).to eq([6, 14])
        expect(m.yx).to eq([1, 4])
        tiny = parent.create_child(margins: [9, 19, 9, 19])
        expect(tiny.dims).to eq([1, 1])
        expect { parent.create_child(margins: [1, 2, 3]) }.to raise_error(TypeError)
        expect { parent.create_child(margins: [1, 2, 3, -4]) }.to raise_error(ArgumentError)
        expect { parent.create_child(margins: [0, 0, 0, 0], rows: 2) }.to raise_error(ArgumentError)
      end
    end

    it 'valida le opzioni' do
      with_parent do |parent|
        expect { parent.create_child(rows: 0, cols: 1) }.to raise_error(ArgumentError)
        expect { parent.create_child(rows: 1, cols: nil) }.to raise_error(TypeError)
        expect { parent.create_child(rows: 1, cols: 1, y: 2**31) }.to raise_error(ArgumentError)
        expect { parent.create_child(rows: 1, cols: 1, fixed: 'no') }.to raise_error(TypeError)
        expect { parent.create_child(rows: 1, cols: 1, name: "a\0b") }.to raise_error(ArgumentError)
        expect { parent.create_child(rows: 1, cols: 1, resize: :enorme) }.to raise_error(ArgumentError)
        expect { parent.create_child(rows: 1, cols: 1, resize: 42) }.to raise_error(TypeError)
        expect { parent.create_child(rows: 1, cols: 1, resize: :marginalized) }.to raise_error(ArgumentError)
      end
    end

    it 'close distrugge solo il piano: i figli passano al genitore' do
      with_parent do |parent|
        mid = parent.create_child(rows: 4, cols: 4, y: 1, x: 1)
        leaf = mid.create_child(rows: 1, cols: 1, y: 1, x: 1)
        expect(mid.close).to be_nil
        expect(mid).to be_closed
        expect(mid.destroy).to be_nil
        expect(leaf).not_to be_closed
        expect(leaf.parent).to equal(parent)
        expect(leaf.abs_yx).to eq([5, 6])
        expect { mid.dims }.to raise_error(Notcurses::ClosedError)
      end
    end

    it 'la distruzione di una radice fa dei figli le radici di nuove pile' do
      root = nc.create_pile(rows: 4, cols: 4)
      a = root.create_child(rows: 1, cols: 1)
      root.close
      expect(a).to be_root
      a.close
    end

    it 'family_destroy distrugge i discendenti e solo quelli' do
      with_parent do |parent|
        a = parent.create_child(rows: 2, cols: 2)
        b = a.create_child(rows: 1, cols: 1)
        sibling = parent.create_child(rows: 1, cols: 1)
        expect(a.family_destroy).to be_nil
        expect([a, b]).to all(be_closed)
        expect(sibling).not_to be_closed
        expect(parent).not_to be_closed
      end
      expect { std.family_destroy }.to raise_error(Notcurses::PlaneError)
    end

    it 'duplicate copia contenuto e posizione (bug di posizione e z-order di 3.0.17 aggirati)' do
      with_parent do |parent|
        c = parent.create_child(rows: 2, cols: 3, y: 2, x: 1, vscroll: true, name: 'orig')
        raw_put(c, 0, 0, 'abc')
        c.duplicate do |d|
          expect(d).to be_owned
          expect(d.yx).to eq(c.yx)
          expect(d.abs_yx).to eq(c.abs_yx)
          expect(d.parent).to equal(parent)
          expect(c.above).to equal(d)
          expect(d.scrolling?).to be(true)
          expect(d.name).to eq('orig')
          egc = Notcurses::FFI.ncplane_at_yx(d.to_ptr, 0, 1, nil, nil)
          expect(Notcurses::Util.take_string(egc)).to eq('b')
        end
        root = nc.create_pile(rows: 2, cols: 2, y: 5, x: 6)
        copy = root.duplicate
        expect(copy.abs_yx).to eq([5, 6])
        expect(copy.parent).to equal(root)
        root.family_destroy
        expect(copy).to be_closed
      end
    end
  end

  describe 'resize' do
    it 'resize tiene l\'origine e il contenuto' do
      with_parent do |parent|
        raw_put(parent, 0, 0, 'xy')
        expect(parent.resize(2, 5)).to equal(parent)
        expect(parent.dims).to eq([2, 5])
        expect(parent.yx).to eq([3, 4])
        expect { std.resize(10, 10) }.to raise_error(Notcurses::PlaneError)
        expect { parent.resize(0, 1) }.to raise_error(ArgumentError)
      end
    end

    it 'resize_region conserva una regione e rifiuta i casi rotti di 3.0.17' do
      with_parent(rows: 3, cols: 4) do |p|
        raw_put(p, 0, 0, 'abcd')
        p.resize_region(rows: 4, cols: 6, keep_y: 0, keep_x: 1, keep_rows: 1, keep_cols: 2, y_off: -1, x_off: -1)
        expect(p.dims).to eq([4, 6])
        expect(p.yx).to eq([2, 4])
        egc = Notcurses::FFI.ncplane_at_yx(p.to_ptr, 1, 1, nil, nil)
        expect(Notcurses::Util.take_string(egc)).to eq('b')
        expect { p.resize_region(rows: 4, cols: 6, keep_rows: 2, keep_cols: 3, x_off: -4) }.to raise_error(ArgumentError)
        expect { p.resize_region(rows: 4, cols: 6, y_off: 1) }.to raise_error(ArgumentError)
        expect { p.resize_region(rows: 4, cols: 6, keep_rows: 1) }.to raise_error(ArgumentError)
        expect { p.resize_region(rows: 4, cols: 6, keep_rows: 1, keep_cols: 1) }.to raise_error(ArgumentError)
        expect { p.resize_region(rows: 6, cols: 6, keep_rows: 4, keep_cols: 6, y_off: -1) }.to raise_error(ArgumentError)
        expect { p.resize_region(rows: 4, cols: 6, keep_y: 4, keep_rows: 1, keep_cols: 1) }.to raise_error(Notcurses::PlaneError)
      end
    end

    it 'resize_maximize usa le dimensioni della pila' do
      with_parent do |p|
        c = p.create_child(rows: 1, cols: 1)
        expect(c.resize_maximize).to equal(c)
        expect(c.dims).to eq([24, 80])
      end
    end

    it 'resize: :marginalized riposiziona il figlio quando il genitore cambia dimensione' do
      with_parent do |p|
        m = p.create_child(margins: [1, 2, 3, 4], resize: :marginalized)
        expect(m.resize_callback).to eq(:marginalized)
        p.resize(12, 30)
        expect(m.dims).to eq([8, 24])
        expect(m.yx).to eq([1, 4])
        m.move(5, 5)
        expect(m.resize_marginalized).to equal(m)
        expect(m.yx).to eq([1, 4])
        other = p.create_child(rows: 1, cols: 1)
        expect { other.resize_marginalized }.to raise_error(Notcurses::PlaneError)
        expect { other.set_resize_callback(callback: :marginalized) }.to raise_error(Notcurses::PlaneError)
      end
    end

    it 'resize: :placewithin tiene il figlio dentro il genitore (relativo, non assoluto)' do
      with_parent do |p|
        c = p.create_child(rows: 3, cols: 5, y: 8, x: 26, resize: :placewithin)
        # con le stesse dimensioni il C non fa nulla e non chiama i callback
        p.resize(10, 21)
        expect(c.yx).to eq([7, 16])
        inside = p.create_child(rows: 2, cols: 2, y: 1, x: 1)
        expect(inside.resize_placewithin.yx).to eq([1, 1])
        expect(nc.create_pile(rows: 1, cols: 1) { |r| r.resize_placewithin.yx }).to eq([0, 0])
      end
    end

    it 'resize_realign richiede un piano allineato con un genitore' do
      with_parent do |p|
        plain = p.create_child(rows: 1, cols: 1)
        expect { plain.resize_realign }.to raise_error(Notcurses::PlaneError)
        nc.create_pile(rows: 1, cols: 1) { |r| expect { r.resize_realign }.to raise_error(Notcurses::PlaneError) }
      end
    end

    it 'set_resize_callback accetta simboli, callable, blocchi e nil' do
      with_parent do |p|
        seen = []
        c = p.create_child(rows: 1, cols: 1)
        cb = ->(plane) { seen << plane }
        expect(c.set_resize_callback(callback: cb)).to equal(c)
        expect(c.resize_callback).to equal(cb)
        p.resize(11, 21)
        expect(seen).to eq([c])
        c.set_resize_callback { |plane| seen << plane.dims }
        p.resize(10, 20)
        expect(seen.last).to eq([1, 1])
        c.set_resize_callback(callback: :maximize)
        expect(c.resize_callback).to eq(:maximize)
        c.set_resize_callback(callback: nil)
        expect(c.resize_callback).to be_nil
        expect { c.set_resize_callback(callback: cb) { nil } }.to raise_error(ArgumentError)
        expect { std.set_resize_callback(callback: :maximize) }.to raise_error(Notcurses::PlaneError)
      end
    end

    it 'un\'eccezione nel callback esce dal metodo che ha causato il resize' do
      with_parent do |p|
        p.create_child(rows: 1, cols: 1, resize: ->(_) { raise ArgumentError, 'dal callback' })
        expect { p.resize(11, 21) }.to raise_error(ArgumentError, 'dal callback')
        expect(p.dims).to eq([11, 21])
      end
    end

    it 'l\'eccezione di un callback non interrompe a metà il callback di un fratello' do
      with_parent(rows: 10, cols: 20) do |p|
        b = p.create_child(margins: [1, 1, 1, 1], resize: :marginalized) # creato prima: nella lista viene dopo
        b.move(5, 5)
        p.create_child(rows: 1, cols: 1, resize: ->(_) { raise 'A fallisce' })
        expect { p.resize(12, 30) }.to raise_error(RuntimeError, 'A fallisce')
        expect(b.dims).to eq([10, 28])
        expect(b.yx).to eq([1, 1])
        expect(nc.callback_errors).to be_empty
      end
    end

    it 'throw e return nel callback non attraversano il C: LocalJumpError dal metodo che ha causato il resize' do
      with_parent do |p|
        calls = []
        p.create_child(rows: 2, cols: 2, resize: ->(_) { calls << :a; throw :fuori })
        p.create_child(rows: 2, cols: 2, resize: ->(_) { calls << :b })
        expect { catch(:fuori) { p.resize(11, 21) } }.to raise_error(LocalJumpError, /callback/)
        expect(calls).to eq(%i[b a])
        expect(nc.callback_errors).to be_empty
      end
      runner = Object.new
      def runner.go(parent)
        parent.create_child(rows: 1, cols: 1, resize: proc { |_| return :dal_callback })
        parent.resize(12, 22)
        :normale
      end
      with_parent { |p| expect { runner.go(p) }.to raise_error(LocalJumpError) }
    end

    it 'dentro un callback non si possono distruggere o riparentare piani' do
      with_parent do |p|
        victim = p.create_child(rows: 1, cols: 1)
        p.create_child(rows: 1, cols: 1, resize: ->(_) { victim.close })
        expect { p.resize(11, 21) }.to raise_error(Notcurses::PlaneError, /callback/)
        expect(victim).not_to be_closed
        victim.set_resize_callback { |me| me.reparent(std) }
        expect { p.resize(10, 20) }.to raise_error(Notcurses::PlaneError, /callback/)
        expect(victim.parent).to equal(p)
      end
    end

    it 'un piano preso in prestito non accetta callback scritti in Ruby' do
      with_parent do |p|
        c = p.create_child(rows: 1, cols: 1)
        borrowed = described_class.new(c.address_ptr, owned: false, context: nc, tracked: false)
        expect { borrowed.set_resize_callback(callback: ->(_) {}) }.to raise_error(Notcurses::PlaneError)
        expect { borrowed.set_resize_callback(callback: :placewithin) }.to raise_error(Notcurses::PlaneError)
        borrowed.set_resize_callback(callback: :realign)
        expect(c.resize_callback).to eq(:realign)
      end
    end

    # Un resize che taglia un glifo largo lascia una metà orfana sul bordo: la
    # metà sinistra, larga 2, nell'ultima colonna, o la metà destra in colonna
    # 0. Prima del fix la scrittura successiva su quella cella cancellava una
    # cella della riga vicina o scriveva fuori dal framebuffer.
    context 'con un glifo largo tagliato dal nuovo bordo' do
      {
        "putstr('x', y: 0, x: 2)" => ->(p) { p.putstr('x', y: 0, x: 2) },
        "putstr('xyz', y: 0, x: 0)" => ->(p) { p.putstr('xyz', y: 0, x: 0) },
        "putstr('中', y: 0, x: 1)" => ->(p) { p.putstr('中', y: 0, x: 1) },
        "putegc('x', y: 0, x: 2)" => ->(p) { p.putegc('x', y: 0, x: 2) },
        'putc in (0, 2)' => ->(p) { p.putc(Notcurses::Cell.new(egc: 'q'), y: 0, x: 2) },
        "hline('-', 3, y: 0, x: 0)" => ->(p) { p.hline('-', 3, y: 0, x: 0) },
        "vline('|', 1, y: 0, x: 2)" => ->(p) { p.vline('|', 1, y: 0, x: 2) },
        "putstr('x') dal cursore in (0, 2)" => ->(p) { p.move_cursor(0, 2).putstr('x') }
      }.each do |name, write|
        it "#{name} dopo resize(2, 3) lascia intatta la riga sotto (prima: \"XY\")" do
          with_parent(rows: 2, cols: 4) do |p|
            p.putstr('ab漢', y: 0, x: 0)
            p.putstr('WXYZ', y: 1, x: 0)
            p.resize(2, 3)
            write.call(p)
            expect(p.contents(y: 1, rows: 1)).to eq('WXY')
          end
        end
      end

      it 'resize_region(keep_x: 1) con la metà destra in colonna 0: la scrittura lascia intatta la riga sopra' do
        with_parent(rows: 2, cols: 4) do |p|
          p.putstr('ZZZZ', y: 0, x: 0)
          p.putstr('漢ab', y: 1, x: 0)
          p.resize_region(rows: 2, cols: 3, keep_x: 1, keep_rows: 2, keep_cols: 3)
          p.putstr('x', y: 1, x: 0)
          expect(p.contents(y: 0, rows: 1)).to eq('ZZZ')
        end
      end

      {
        'resize_region(x_off: -1)' => ->(p) { p.resize_region(rows: 2, cols: 2, keep_x: 1, keep_rows: 2, keep_cols: 1, x_off: -1) },
        'resize_region(x_off: -1) e poi resize' => lambda { |p|
          p.resize_region(rows: 2, cols: 4, keep_x: 1, keep_rows: 2, keep_cols: 3, x_off: -1) # metà destra in (0, 1)
          p.resize(2, 2) # la metà destra finisce nell'ultima colonna
        }
      }.each do |name, cut|
        it "#{name} con la metà destra nell'ultima colonna: una scrittura larga lascia intatta la riga sotto" do
          with_parent(rows: 2, cols: 4) do |p|
            p.putstr('漢ab', y: 0, x: 0)
            cut.call(p)
            p.putstr('W', y: 1, x: 0)
            p.putstr('中', y: 0, x: 0) # il C cancellava la cella oltre la metà destra in (0, 1): la (1, 0)
            expect(p.contents(y: 1, rows: 1)).to eq('W')
          end
        end
      end

      it 'un glifo largo intero nelle ultime due colonne resta dopo i controlli dei bordi' do
        with_parent(rows: 1, cols: 4) do |p|
          p.putstr('ab漢', y: 0, x: 0)
          p.resize(1, 4) # controllo forzato, nessun taglio
          expect(p.contents).to eq('ab漢')
        end
        with_parent(rows: 1, cols: 5) do |p|
          p.putstr('xa漢b', y: 0, x: 0)
          p.resize_region(rows: 1, cols: 4, keep_x: 1, keep_rows: 1, keep_cols: 3, x_off: -1) # 漢 nelle colonne 2-3
          expect(p.contents).to eq('a漢')
          expect(p.at(y: 0, x: 2).egc).to eq('漢')
        end
      end

      {
        'resize(1, 1)' => ->(p) { p.resize(1, 1) },
        'resize_region(cols: 1, keep_x: 1)' => ->(p) { p.resize_region(rows: 1, cols: 1, keep_x: 1, keep_rows: 1, keep_cols: 1) }
      }.each do |name, cut|
        it "#{name} su un glifo largo lascia un piano largo 1 in cui si scrive" do
          with_parent(rows: 1, cols: 2) do |p|
            p.putstr('漢', y: 0, x: 0)
            cut.call(p)
            p.putstr('x', y: 0, x: 0)
            expect(p.contents).to eq('x')
          end
        end
      end

      it 'su un piano che scorre e cresce (autogrow) gli a capo non fanno rileggere i bordi a ogni scrittura' do
        with_parent(rows: 1, cols: 20, autogrow: true) do |p|
          p.scrolling = true
          allow(Notcurses::FFI).to receive(:ncplane_at_yx_cell).and_call_original
          50.times { p.putstr('x' * 20) } # ogni riga piena fa crescere il piano di una riga
          expect(p.dim_y).to be > 40
          expect(Notcurses::FFI).to have_received(:ncplane_at_yx_cell).at_most(2).times # solo il primo controllo
        end
      end

      it 'un figlio resize: :maximize ristretto dalla cascata del genitore: la scrittura lascia intatta la riga sotto' do
        cols = std.dim_x
        with_parent(rows: 2, cols: 4, x: 0) do |p|
          c = p.create_child(rows: 2, cols: cols + 1, x: 0, resize: :maximize)
          c.putstr('漢', y: 0, x: cols - 1)
          c.putstr('WXYZ', y: 1, x: 0)
          p.resize(2, 5)
          expect(c.dim_x).to eq(cols)
          c.putstr('x', y: 0, x: c.dim_x - 1)
          expect(c.contents(y: 1, rows: 1)).to eq('WXYZ')
        end
      end

      it 'merge_down seguito da resize che riportano le dimensioni controllate: la scrittura lascia intatta la riga sotto' do
        with_parent(rows: 2, cols: 4) do |p|
          p.putstr('WXYZ', y: 1, x: 0) # prima scrittura: bordi controllati con il piano 2x4
          Notcurses::FFI.ncplane_resize_simple(p.to_ptr, 2, 5) # resize fatto dal C, come lo stdplane nel render
          src = std.create_child(rows: 1, cols: 5, y: p.yx[0], x: p.yx[1])
          src.putstr('漢', y: 0, x: 3)
          src.merge_down(p) # il glifo arriva nelle colonne 3-4 senza passare dalle scritture
          src.close
          Notcurses::FFI.ncplane_resize_simple(p.to_ptr, 2, 4) # di nuovo 2x4: metà sinistra orfana in (0, 3)
          p.putstr('x', y: 0, x: 3)
          expect(p.contents(y: 1, rows: 1)).to eq('WXYZ')
        end
      end

      it "le scritture sulla metà orfana non corrompono l'heap (prima: abort di glibc)" do
        skip 'serve libc_malloc_debug di glibc' unless File.exist?('/usr/lib/libc_malloc_debug.so.0')
        script = <<~'RUBY'
          require 'notcurses'
          Notcurses::Context.open(output: '/dev/null', termtype: 'xterm-256color', suppress_banners: true,
                                  drain_input: true) do |nc|
            std = nc.stdplane
            planes = Array.new(20) { std.create_child(rows: 1, cols: 4).tap { |q| q.putstr('ab漢', y: 0, x: 0) } }
            planes.each { |q| q.resize(1, 3) }
            planes.each { |q| q.putstr('x', y: 0, x: 2) }
            planes.each(&:close)
            planes = Array.new(20) { std.create_child(rows: 1, cols: 4).tap { |q| q.putstr('漢ab', y: 0, x: 0) } }
            planes.each { |q| q.resize_region(rows: 1, cols: 3, keep_x: 1, keep_rows: 1, keep_cols: 3) }
            planes.each { |q| q.putstr('x', y: 0, x: 0) }
            planes.each(&:close)
            planes = Array.new(20) { std.create_child(rows: 1, cols: 4).tap { |q| q.putstr('漢ab', y: 0, x: 0) } }
            planes.each { |q| q.resize_region(rows: 1, cols: 2, keep_x: 1, keep_rows: 1, keep_cols: 1, x_off: -1) }
            planes.each { |q| q.putstr('中', y: 0, x: 0) }
            planes.each(&:close)
            box = std.create_child(rows: 3, cols: 5)
            box.putstr('漢', y: 2, x: 3)
            box.resize(3, 4)
            box.perimeter
            box.close
          end
          puts 'ok'
        RUBY
        env = { 'TERM' => 'xterm-256color', 'LD_PRELOAD' => '/usr/lib/libc_malloc_debug.so.0', 'MALLOC_CHECK_' => '3' }
        lib = File.expand_path('../../lib', __dir__)
        out, status = Open3.capture2e(env, NcHelpers::TIMEOUT, '-k', '5', '-s', 'KILL', '30', RbConfig.ruby, '-I', lib, '-e',
                                      script, stdin_data: '')
        expect([status.exitstatus, out]).to eq([0, "ok\n"])
      end
    end
  end

  describe 'nome, genitore e pile' do
    it 'name e name=' do
      with_parent do |p|
        expect(p.name).to eq('')
        p.name = 'àèì'
        expect(p.name).to eq('àèì')
        expect(p.name.encoding).to eq(Encoding::UTF_8)
        p.name = nil
        expect(p.name).to be_nil
        expect { p.name = 3 }.to raise_error(TypeError)
      end
    end

    it 'parent è nil per le radici' do
      expect(std.parent).to be_nil
      expect(std).to be_root
      with_parent { |p| expect(p).not_to be_root }
    end

    it 'reparent e reparent_family' do
      with_parent do |p|
        a = p.create_child(rows: 2, cols: 2)
        b = a.create_child(rows: 1, cols: 1)
        other = std.create_child(rows: 3, cols: 3)
        expect(a.reparent(other)).to equal(a)
        expect(a.parent).to equal(other)
        expect(b.parent).to equal(p)
        expect(b.reparent_family(a)).to equal(b)
        expect(a.reparent_family(p).parent).to equal(p)
        expect(b.parent).to equal(a)
        expect { p.reparent_family(b) }.to raise_error(Notcurses::PlaneError)
        expect { std.reparent(p) }.to raise_error(Notcurses::PlaneError)
        expect { a.reparent(nil) }.to raise_error(TypeError)
        a.reparent(a)
        expect(a).to be_root
        expect(a.pile_top).not_to eq(std.pile_top)
        other.close
        a.close
      end
    end

    it 'descendant_of?, pile_top, pile_bottom, above, below' do
      with_parent do |p|
        c = p.create_child(rows: 1, cols: 1)
        expect(c.descendant_of?(p)).to be(true)
        expect(c.descendant_of?(std)).to be(true)
        expect(p.descendant_of?(c)).to be(false)
        expect(c.pile_top).to equal(c)
        expect(c.pile_bottom).to equal(std)
        expect(c.below).to equal(p)
        expect(p.above).to equal(c)
        expect(c.above).to be_nil
      end
    end

    it 'render_pile disegna una pila separata' do
      nc.create_pile(rows: 2, cols: 2) do |root|
        raw_put(root, 0, 0, 'z')
        expect(root.render_pile(rasterize: false)).to equal(root)
        expect(root.render_pile).to equal(root)
        expect { root.render_pile(rasterize: 1) }.to raise_error(TypeError)
      end
    end
  end

  describe 'geometria' do
    it 'dimensioni e coordinate' do
      with_parent(rows: 5, cols: 10, y: 2, x: 3) do |p|
        expect([p.dim_y, p.dim_x, p.dims]).to eq([5, 10, [5, 10]])
        expect([p.y, p.x, p.yx]).to eq([2, 3, [2, 3]])
        expect([p.abs_y, p.abs_x, p.abs_yx]).to eq([2, 3, [2, 3]])
        expect(p.center_abs).to eq([4, 7])
        expect(p.translate(1, 1)).to eq([3, 4])
        expect(p.translate(0, 0, dst: p)).to eq([0, 0])
        expect(p.translate_abs(3, 4)).to eq([1, 1, true])
        expect(p.translate_abs(0, 0)).to eq([-2, -3, false])
        expect(p.halign(:center, 4)).to eq(3)
        expect(p.valign(:bottom, 2)).to eq(3)
        expect { p.halign(:unaligned, 4) }.to raise_error(ArgumentError)
        expect { p.halign(:center, -1) }.to raise_error(ArgumentError)
        geom = p.pixel_geom
        expect(geom).to be_frozen
        expect(geom.keys).to eq(%i[pixel_y pixel_x cell_pixel_y cell_pixel_x max_bitmap_y max_bitmap_x])
      end
    end
  end

  describe 'posizione e z-order' do
    it 'move e move_rel' do
      with_parent do |p|
        expect(p.move(5, 6).yx).to eq([5, 6])
        expect(p.move_rel(-1, 2).yx).to eq([4, 8])
        expect { std.move(1, 1) }.to raise_error(Notcurses::PlaneError)
        expect { p.move(2**31, 0) }.to raise_error(ArgumentError)
      end
    end

    it 'move_top, move_bottom e le varianti family (ordine esatto di 3.0.17)' do
      with_parent do |p|
        a = p.create_child(rows: 1, cols: 1)
        b = p.create_child(rows: 1, cols: 1)
        expect(a.move_top).to equal(a)
        expect(nc.top).to equal(a)
        expect(a.move_bottom).to equal(a)
        expect(nc.bottom).to equal(a)
        expect(z_order).to eq([b, p, std, a])
        expect(p.move_family_top).to equal(p)
        expect(z_order).to eq([b, p, a, std])
        expect(p.move_family_bottom).to equal(p)
        expect(z_order).to eq([std, b, p, a])
      end
    end

    it 'move_above e move_below' do
      with_parent do |p|
        a = p.create_child(rows: 1, cols: 1)
        b = p.create_child(rows: 1, cols: 1)
        expect(a.move_above(b)).to equal(a)
        expect(b.above).to equal(a)
        expect(a.move_below(b)).to equal(a)
        expect(b.below).to equal(a)
        expect(a.move_above(nil)).to equal(a)
        expect(nc.bottom).to equal(a)
        expect(a.move_below(nil)).to equal(a)
        expect(nc.top).to equal(a)
        expect(p.move_family_above(b)).to equal(p)
        expect(p.move_family_below(nil)).to equal(p)
        expect { a.move_above(a) }.to raise_error(Notcurses::PlaneError)
        nc.create_pile(rows: 1, cols: 1) { |r| expect { a.move_below(r) }.to raise_error(Notcurses::PlaneError) }
        expect { a.move_above(:b) }.to raise_error(TypeError)
      end
    end
  end

  describe 'scrolling' do
    it 'scrolling e autogrow' do
      with_parent do |p|
        expect(p.scrolling?).to be(false)
        p.scrolling = true
        expect(p.scrolling?).to be(true)
        p.autogrow = true
        expect(p.autogrow?).to be(true)
        p.autogrow = false
        expect { p.scrolling = 1 }.to raise_error(TypeError)
        expect { std.autogrow = true }.to raise_error(Notcurses::PlaneError)
      end
    end

    it 'scrollup fa scorrere il contenuto anche con il cursore in alto' do
      with_parent(rows: 3, cols: 4, vscroll: true) do |p|
        raw_put(p, 2, 0, 'end')
        p.home
        expect(p.scrollup(lines: 1)).to equal(p)
        egc = Notcurses::FFI.ncplane_at_yx(p.to_ptr, 1, 0, nil, nil)
        expect(Notcurses::Util.take_string(egc)).to eq('e')
        expect(p.cursor).to eq([2, 0])
        expect { p.scrollup(lines: 0) }.to raise_error(ArgumentError)
        p.scrolling = false
        expect { p.scrollup }.to raise_error(Notcurses::PlaneError)
      end
    end

    it 'scrollup_child' do
      with_parent(rows: 4, cols: 4, vscroll: true) do |p|
        c = p.create_child(rows: 2, cols: 2, y: 3)
        expect(p.scrollup_child(c)).to equal(p)
        expect(c.y).to eq(2)
        fixed = p.create_child(rows: 1, cols: 1, y: 5, fixed: true)
        expect { p.scrollup_child(fixed) }.to raise_error(Notcurses::PlaneError)
        expect { c.scrollup_child(p) }.to raise_error(Notcurses::PlaneError)
      end
    end

    it 'rotate_cw e rotate_ccw' do
      with_parent(rows: 2, cols: 4) do |p|
        expect(p.rotate_cw).to equal(p)
        expect(p.dims).to eq([2, 4])
        expect(p.rotate_ccw).to equal(p)
        odd = p.create_child(rows: 1, cols: 3)
        expect { odd.rotate_cw }.to raise_error(Notcurses::PlaneError)
      end
    end
  end

  describe 'cursore' do
    it 'move_cursor, move_cursor_rel, home, cursor' do
      with_parent(rows: 3, cols: 4) do |p|
        expect(p.move_cursor(1, 2)).to equal(p)
        expect([p.cursor, p.cursor_yx, p.cursor_y, p.cursor_x]).to eq([[1, 2], [1, 2], 1, 2])
        expect(p.move_cursor(nil, 3).cursor).to eq([1, 3])
        expect(p.move_cursor(2, nil).cursor).to eq([2, 3])
        expect(p.move_cursor(nil, nil).cursor).to eq([2, 3])
        expect(p.move_cursor(1, 3).cursor).to eq([1, 3])
        expect(p.move_cursor_rel(1, -3).cursor).to eq([2, 0])
        expect(p.home.cursor).to eq([0, 0])
      end
    end

    it 'rifiuta posizioni fuori dal piano senza cambiare il cursore' do
      with_parent(rows: 3, cols: 4) do |p|
        p.move_cursor(1, 2)
        expect { p.move_cursor(3, 0) }.to raise_error(Notcurses::PlaneError)
        expect { p.move_cursor(0, 4) }.to raise_error(Notcurses::PlaneError)
        expect { p.move_cursor(-2, 0) }.to raise_error(Notcurses::PlaneError)
        expect { p.move_cursor(-1, 0) }.to raise_error(Notcurses::PlaneError) # -1 non vuol dire «resta»: usa nil
        expect { p.move_cursor_rel(-2, 0) }.to raise_error(Notcurses::PlaneError)
        expect(p.cursor).to eq([1, 2])
        expect { p.move_cursor('1', 0) }.to raise_error(TypeError)
      end
    end
  end

  describe 'identità e piani presi in prestito' do
    it 'due wrapper dello stesso piano sono ==' do
      with_parent do |p|
        other = described_class.new(p.address_ptr, owned: false, context: nc, tracked: false)
        expect(other).to eq(p)
        expect(other.hash).to eq(p.hash)
        expect(other).not_to be_owned
      end
    end

    it 'un piano preso in prestito diventa chiuso alla prossima distruzione di piani' do
      with_parent do |p|
        borrowed = described_class.new(p.address_ptr, owned: false, context: nc, tracked: false)
        expect(borrowed).not_to be_closed
        p.create_child(rows: 1, cols: 1).close
        expect(borrowed).to be_closed
        expect { borrowed.dims }.to raise_error(Notcurses::ClosedError)
        expect(p).not_to be_closed
      end
    end

    it 'rifiuta un puntatore NULL' do
      expect { described_class.new(::FFI::Pointer::NULL, context: nc) }.to raise_error(Notcurses::PlaneError)
    end

    it 'un piano chiuso non è == al piano nuovo che riusa il suo indirizzo' do
      with_parent do |p|
        old = p.create_child(rows: 1, cols: 1)
        addr = old.address
        old.close
        # glibc riusa subito il blocco liberato della stessa dimensione
        fresh = Array.new(50) { p.create_child(rows: 1, cols: 1) }.find { |pl| pl.address == addr }
        skip "malloc non ha riusato l'indirizzo" unless fresh
        expect(old).to eq(old)
        expect(old).not_to eq(fresh)
        expect(old.eql?(fresh)).to be(false)
        expect({ old => :vecchio }[fresh]).to be_nil
      end
    end

    it 'rifiuta un secondo wrapper tracciato o posseduto di un piano che ha già un wrapper aperto' do
      with_parent do |p|
        c = p.create_child(rows: 1, cols: 1, resize: ->(_) {})
        # tracciato sfratterebbe c e il suo trampolino di resize; posseduto distruggerebbe il piano sotto c
        expect { described_class.new(c.to_ptr, owned: false, context: nc) }.to raise_error(ArgumentError, /già/)
        expect { described_class.new(c.to_ptr, context: nc, tracked: false) }.to raise_error(ArgumentError, /già/)
        expect(c).not_to be_closed
        expect(c.resize_callback).to be_a(Proc)
      end
    end
  end

  describe 'testo' do
    let(:red) { Notcurses::Channels.rgb(255, 0, 0, 0, 0, 0) }

    it 'putstr scrive dal cursore o da (y, x) e restituisce le colonne' do
      with_parent(rows: 3, cols: 10) do |p|
        expect(p.putstr('ciao', y: 1, x: 2)).to eq(4)
        expect(p.cursor).to eq([1, 6])
        expect(p.putstr('!')).to eq(1)
        expect(p.contents(y: 1, rows: 1)).to eq('ciao!')
        expect(p.putstr('')).to eq(0)
        expect(p.putstr('漢', y: 0, x: 0)).to eq(2)
      end
    end

    it 'putstr con align: allinea nella riga' do
      with_parent(rows: 3, cols: 10) do |p|
        p.putstr('ab', y: 0, align: :right)
        p.putstr('ab', y: 1, align: :center)
        expect(p.at(y: 0, x: 9).egc).to eq('b')
        expect(p.at(y: 1, x: 4).egc).to eq('a')
        expect { p.putstr('a', x: 0, align: :left) }.to raise_error(ArgumentError)
        expect { p.putstr('a', align: :top) }.to raise_error(ArgumentError)
        expect { p.putstr('x' * 11, align: :left) }.to raise_error(Notcurses::PlaneError)
      end
    end

    it 'putstr su un piano che non scorre rifiuta, senza scrivere, il testo che non entra nella riga' do
      with_parent(rows: 2, cols: 5) do |p|
        expect { p.putstr('123456', y: 0, x: 0) }.to raise_error(Notcurses::PlaneError, /non entra/)
        expect { p.putstr("a\nb", y: 0, x: 0) }.to raise_error(Notcurses::PlaneError, /scorre/)
        expect(p.contents).to eq('')
        p.putstr('12345', y: 1, x: 0)
        expect(p.cursor).to eq([1, 5])
        expect { p.putstr('a') }.to raise_error(Notcurses::PlaneError)
      end
    end

    it 'putstr su un piano che scorre va a capo e scorre' do
      with_parent(rows: 2, cols: 5) do |p|
        p.scrolling = true
        expect(p.putstr("ab\ncd\nef", y: 0, x: 0)).to eq(8)
        expect(p.contents).to eq('cdef')
        expect(p.putstr('123456')).to eq(6)
        expect(p.cursor).to eq([1, 3])
        expect(p.contents).to eq('ef123456')
      end
    end

    it 'putstr: "\n" dopo una riga piena va a capo una volta sola' do
      with_parent(rows: 5, cols: 4) do |p|
        p.scrolling = true
        lines = ->(n) { (0...n).map { |y| p.contents(y: y, rows: 1) } }
        expect(p.putstr("abcd\nefgh", y: 0, x: 0)).to eq(9)
        expect(p.cursor).to eq([1, 4])
        expect(p.putstr("\n")).to eq(1)
        expect(p.cursor).to eq([2, 0])
        expect(p.putstr("ab字\nx")).to eq(6)
        expect(p.cursor).to eq([3, 1])
        expect(p.putstr("wxyz\nq", y: 4, x: 0)).to eq(6) # sull'ultima riga: un solo scroll
        expect(p.cursor).to eq([4, 1])
        expect(lines.call(5)).to eq(%w[efgh ab字 x wxyz q])
        p.putstr('1234', y: 4, x: 0)
        expect(p.putstr("\n", y: 4)).to eq(1) # con y: e il cursore a fine riga
        expect(p.cursor).to eq([4, 0])
        expect(lines.call(4)).to eq(%w[ab字 x wxyz 1234])
      end
    end

    it 'contents e at non espongono la cella "\n" che notcurses lascia dopo una riga vuota' do
      with_parent(rows: 3, cols: 5) do |p|
        p.scrolling = true
        expect(p.putstr("a\n\nb", y: 0, x: 0)).to eq(4)
        expect(p.contents).to eq('ab')
        expect(p.at(y: 1, x: 0)).to be_empty
        expect(p.at(y: 1, x: 0)).to eq(Notcurses::Cell.new(egc: ''))
        nc.render
        expect(nc.at(4, 4)).to be_empty # il C la disegna come uno spazio (render.c:619)
      end
    end

    it 'putstr con autogrow allarga il piano' do
      with_parent(rows: 1, cols: 3) do |p|
        p.autogrow = true
        p.putstr('abcdef', y: 0, x: 0)
        expect(p.dim_x).to be >= 6
        expect(p.contents).to eq('abcdef')
      end
    end

    it 'putstr rifiuta TAB, caratteri di controllo, U+2028 e i caratteri di larghezza zero' do
      with_parent(rows: 2, cols: 10) do |p|
        expect { p.putstr("a\tb") }.to raise_error(ArgumentError, /TAB/)
        expect { p.putstr("a\rb") }.to raise_error(ArgumentError, /controllo/)
        expect { p.putstr("a b") }.to raise_error(ArgumentError, /U\+2028/)
        expect { p.putstr("a​b") }.to raise_error(ArgumentError, /larghezza zero/)
        expect { p.putstr("1️⃣") }.to raise_error(ArgumentError, /larghezza zero/)
        expect { p.putstr("a\0b") }.to raise_error(ArgumentError)
        expect { p.putstr(:a) }.to raise_error(TypeError)
        expect(p.contents).to eq('')
        expect(p.putstr("éx", y: 0, x: 0)).to eq(2)
        expect(p.at(y: 0, x: 0).egc).to eq("é")
      end
    end

    it 'una String non convertibile in UTF-8 è ArgumentError, anche in una codifica senza convertitore' do
      with_parent(rows: 1, cols: 10) do |p|
        expect { p.putstr("\x80".dup.force_encoding(Encoding::Shift_JIS)) }.to raise_error(ArgumentError, /UTF-8/)
        expect { p.create_child(rows: 1, cols: 1, name: 'abc'.dup.force_encoding('UTF-7')) }
          .to raise_error(ArgumentError, /UTF-8/)
        expect(p.putstr('ü'.encode(Encoding::ISO_8859_1), y: 0, x: 0)).to eq(1)
        expect(p.at(y: 0, x: 0).egc).to eq('ü')
      end
    end

    it 'putstr non unisce il testo dopo una sequenza ZWJ (bug di 3.0.17)' do
      with_parent(rows: 1, cols: 10) do |p|
        astronaut = "\u{1F469}‍\u{1F680}"
        expect(p.putstr("x#{astronaut}z", y: 0, x: 0)).to eq(4)
        expect([p.at(y: 0, x: 0).egc, p.at(y: 0, x: 1).egc, p.at(y: 0, x: 3).egc]).to eq(['x', astronaut, 'z'])
      end
    end

    it 'putstr rifiuta un carattere largo che non entra' do
      with_parent(rows: 2, cols: 4) do |p|
        p.scrolling = true
        expect { p.putstr('漢', y: 0, x: 3) }.to raise_error(Notcurses::PlaneError)
      end
      with_parent(rows: 2, cols: 1) do |p|
        p.scrolling = true
        expect { p.putstr('a漢') }.to raise_error(Notcurses::PlaneError)
      end
    end

    it 'putstr con stained: prende stile e colori delle celle sostituite' do
      with_parent(rows: 2, cols: 5) do |p|
        p.set_fg_rgb24(0x112233)
        p.putstr('abc', y: 0, x: 0)
        p.set_fg_rgb24(0x445566)
        expect(p.putstr('XY', y: 0, x: 0, stained: true)).to eq(2)
        expect(p.at(y: 0, x: 0).egc).to eq('X')
        expect(p.at(y: 0, x: 0).channels.fg_rgb24).to eq(0x112233)
        expect(p.fg_rgb24).to eq(0x445566)
        expect { p.putstr('123456', y: 1, x: 0, stained: true) }.to raise_error(Notcurses::PlaneError)
        p.scrolling = true
        expect { p.putstr("a\nb", y: 1, x: 0, stained: true) }.to raise_error(ArgumentError)
      end
    end

    it 'printf formatta con Kernel#format' do
      with_parent(rows: 1, cols: 10) do |p|
        expect(p.printf('%03d|%s', 7, 'z', y: 0, x: 0)).to eq(5)
        expect(p.contents).to eq('007|z')
        expect { p.printf('%d', 'x') }.to raise_error(ArgumentError)
      end
    end

    it 'putegc scrive un solo grapheme cluster' do
      with_parent(rows: 1, cols: 10) do |p|
        expect(p.putegc('漢', y: 0, x: 0)).to eq(2)
        expect(p.putegc(0x41)).to eq(1)
        expect(p.cursor).to eq([0, 3])
        expect(p.contents).to eq('漢A')
        expect { p.putegc('') }.to raise_error(ArgumentError)
        expect { p.putegc('ab') }.to raise_error(ArgumentError)
        expect { p.putegc("\u{1F1EE}\u{1F1F9}") }.to raise_error(Notcurses::CellError)
        expect { p.putegc('漢', y: 0, x: 9) }.to raise_error(Notcurses::PlaneError)
        expect { p.putegc(0xD800) }.to raise_error(RangeError)
      end
    end

    it 'putc scrive una Cell con il suo stile e i suoi colori' do
      with_parent(rows: 1, cols: 10) do |p|
        cell = Notcurses::Cell.new(egc: '★', styles: :bold, channels: red)
        expect(p.putc(cell, y: 0, x: 0)).to eq(1)
        expect(p.at(y: 0, x: 0)).to eq(cell)
        expect(p.putc(Notcurses::Cell.new(egc: ''))).to eq(1)
        expect { p.putc('a') }.to raise_error(TypeError)
      end
    end

    it 'puttext va a capo sulle parole e allinea le righe' do
      with_parent(rows: 4, cols: 10) do |p|
        expect(p.puttext('uno due tre quattro cinque', y: 0)).to eq(23)
        expect((0..3).map { |y| p.contents(y: y, rows: 1) }).to eq(['uno due', 'tre', 'quattro', 'cinque'])
        p.erase
        p.puttext("ab\n\ncd", y: 0, align: :right)
        expect([p.at(y: 0, x: 9).egc, p.at(y: 2, x: 9).egc]).to eq(%w[b d])
        expect(p.contents(y: 1, rows: 1)).to eq('')
      end
    end

    it 'puttext spezza le parole più larghe del piano' do
      with_parent(rows: 3, cols: 4) do |p|
        expect(p.puttext('abcdefghij')).to eq(10)
        expect((0..2).map { |y| p.contents(y: y, rows: 1) }).to eq(%w[abcd efgh ij])
      end
    end

    it 'puttext misura le sequenze ZWJ come putstr: le parole lunghe vanno a capo' do
      astro = [0x1F469, 0x200D, 0x1F680].pack('U*') # astronauta: un grapheme, 2 colonne
      rows = ->(p) { (0...p.dim_y).map { |y| p.contents(y: y, rows: 1) } }
      with_parent(rows: 3, cols: 4) do |p|
        expect(p.puttext("#{astro}abc", y: 0)).to eq(5)
        expect(rows.(p)).to eq(["#{astro}ab", 'c', ''])
      end
      with_parent(rows: 3, cols: 6) do |p|
        p.puttext("#{astro}ab cd", y: 0)
        expect(rows.(p)).to eq(["#{astro}ab", 'cd', ''])
      end
      with_parent(rows: 3, cols: 4) do |p|
        expect(p.puttext("abcd #{astro}abc", y: 0)).to eq(9)
        expect(rows.(p)).to eq(['abcd', "#{astro}ab", 'c'])
      end
      with_parent(rows: 2, cols: 4) do |p|
        expect { p.puttext("abcd #{astro}abc", y: 0) }.to raise_error(Notcurses::PlaneError)
        expect(rows.(p)).to eq(['', ''])
      end
    end

    it 'puttext rifiuta, senza scrivere, un testo che non entra; sui piani che scorrono scorre' do
      with_parent(rows: 2, cols: 5) do |p|
        expect { p.puttext('uno due tre quattro') }.to raise_error(Notcurses::PlaneError)
        expect(p.contents).to eq('')
        p.scrolling = true
        expect(p.puttext('uno due tre quattro', y: 0)).to eq(16)
        expect(p.contents).to eq('quattro')
        expect { p.puttext('a', align: :top) }.to raise_error(ArgumentError)
      end
    end
  end

  describe 'stile e colori' do
    it 'styles, styles=, on_styles e off_styles' do
      with_parent do |p|
        p.styles = %i[bold italic]
        expect(p.styles).to contain_exactly(:bold, :italic)
        expect(p.off_styles(:bold).on_styles(:underline, :struck)).to equal(p)
        expect(p.styles).to contain_exactly(:italic, :underline, :struck)
        p.styles = 0
        expect(p.styles).to eq([])
        expect { p.styles = :blink }.to raise_error(ArgumentError)
      end
    end

    it 'channels, fchannel e bchannel, con i bit di servizio azzerati' do
      with_parent do |p|
        chans = Notcurses::Channels.rgb(1, 2, 3, 4, 5, 6)
        p.channels = chans
        expect(p.channels).to eq(chans)
        p.fchannel = Notcurses::Channel.rgb(9, 9, 9)
        expect(p.fchannel).to eq(Notcurses::Channel.rgb(9, 9, 9))
        p.bchannel = 0xC7123456
        expect(p.bchannel.value).to eq(0x40123456)
        expect { p.bchannel = Notcurses::Channel.rgb(1, 1, 1).with_alpha(:highcontrast) }.to raise_error(ArgumentError)
        expect { p.channels = Notcurses::Channels.new.with_bg_alpha(:transparent).value | 0x3000_0000 }
          .to raise_error(ArgumentError)
      end
    end

    it 'setter RGB, palette, alpha e default restituiscono self' do
      with_parent do |p|
        expect(p.set_fg_rgb(1, 2, 3).set_bg_rgb24(0x0a0b0c)).to equal(p)
        expect(p.fg_rgb).to eq([1, 2, 3])
        expect(p.bg_rgb24).to eq(0x0a0b0c)
        expect(p.bg_rgb).to eq([10, 11, 12])
        expect(p.set_fg_rgb_clipped(-5, 300, 128).fg_rgb).to eq([0, 255, 128])
        expect(p.set_bg_rgb_clipped(1, 1, 1).bg_rgb).to eq([1, 1, 1])
        expect(p.set_bg_rgb(2, 2, 2).bg_rgb).to eq([2, 2, 2])
        expect(p.set_fg_rgb24(0x123456).fg_rgb24).to eq(0x123456)
        expect { p.set_fg_rgb(256, 0, 0) }.to raise_error(ArgumentError)
        expect { p.set_fg_rgb_clipped(2**31, 0, 0) }.to raise_error(ArgumentError)
        expect { p.set_bg_rgb24(0x1000000) }.to raise_error(ArgumentError)
        p.set_fg_palindex(200).set_bg_palindex(3)
        expect([p.fchannel.palindex?, p.fchannel.palindex, p.bchannel.palindex]).to eq([true, 200, 3])
        expect { p.set_fg_palindex(256) }.to raise_error(ArgumentError)
        expect(p.set_fg_alpha(:blend).fg_alpha).to eq(:blend)
        expect(p.set_bg_alpha(:transparent).bg_alpha).to eq(:transparent)
        expect { p.set_bg_alpha(:highcontrast) }.to raise_error(ArgumentError)
        expect(p.set_fg_alpha(:highcontrast).fg_alpha).to eq(:highcontrast)
        expect(p.set_fg_default.set_bg_default).to equal(p)
        expect([p.fg_default?, p.bg_default?]).to eq([true, true])
      end
    end
  end

  describe 'linee, box e riempimenti' do
    let(:black) { Notcurses::Channels.rgb(0, 0, 0, 0, 0, 0) }
    let(:red) { Notcurses::Channels.rgb(250, 0, 0, 0, 0, 0) }

    it 'hline disegna una linea e sposta il cursore' do
      with_parent(rows: 3, cols: 10) do |p|
        expect(p.hline('-', 10, y: 0, x: 0)).to equal(p)
        expect(p.cursor).to eq([0, 10])
        expect(p.contents(y: 0, rows: 1)).to eq('-' * 10)
        expect { p.hline('-', 11, y: 1, x: 0) }.to raise_error(ArgumentError)
        expect { p.hline('-', 0, y: 1, x: 0) }.to raise_error(ArgumentError)
        expect { p.hline('漢', 2, y: 1, x: 0) }.to raise_error(ArgumentError)
        expect { p.hline('-', 2, y: 1, x: 0, from: black) }.to raise_error(ArgumentError)
        expect { p.hline('-', 1) }.to raise_error(Notcurses::PlaneError) # cursore oltre il bordo
      end
    end

    it 'hline con from: e to: sfuma i colori senza raggiungere to' do
      with_parent(rows: 1, cols: 10) do |p|
        p.hline(Notcurses::Cell.new(egc: '='), 5, y: 0, x: 0, from: black, to: red)
        expect((0..4).map { |x| p.at(y: 0, x: x).channels.fg_rgb.first }).to eq([0, 50, 100, 150, 200])
      end
    end

    it 'vline disegna verso il basso e non scorre' do
      with_parent(rows: 4, cols: 3) do |p|
        p.scrolling = true
        expect(p.vline('|', 4, y: 0, x: 1).cursor).to eq([3, 2])
        expect((0..3).map { |y| p.at(y: y, x: 1).egc }).to eq(%w[| | | |])
        expect { p.vline('|', 2, y: 3, x: 0) }.to raise_error(ArgumentError)
        p.vline('!', 3, y: 0, x: 0, from: black, to: red)
        expect(p.at(y: 2, x: 0).channels.fg_rgb.first).to be > p.at(y: 0, x: 0).channels.fg_rgb.first
      end
    end

    it 'box disegna un box con i set con nome, una String o 6 Cell' do
      with_parent(rows: 4, cols: 10) do |p|
        expect(p.box(3, 5, y: 0, x: 0, set: :rounded)).to equal(p)
        expect(p.contents(rows: 3, cols: 5)).to eq('╭───╮││╰───╯')
        expect(p.cursor).to eq([2, 5])
        p.erase
        p.box(2, 3, y: 0, x: 0, set: '+-+-=!')
        expect(p.contents(rows: 2, cols: 3)).to eq('+=-+=-')
        p.erase
        cells = %w[a b c d e f].map { |g| Notcurses::Cell.new(egc: g) }
        p.box(3, 3, y: 0, x: 0, set: cells, hide: :left)
        expect(p.contents(rows: 3, cols: 3)).to eq('aebfced')
      end
    end

    it 'box nasconde i lati e rifiuta i box che escono o i glifi larghi' do
      with_parent(rows: 4, cols: 10) do |p|
        p.box(3, 4, y: 0, x: 0, set: :ascii, hide: %i[top])
        expect(p.contents(y: 0, rows: 1)).to eq('/\\')
        expect { p.box(5, 3, y: 0, x: 0) }.to raise_error(ArgumentError)
        expect { p.box(2, 3, y: 3, x: 0) }.to raise_error(ArgumentError)
        expect { p.box(2, 2, y: 0, x: 0, set: '漢漢漢漢漢漢') }.to raise_error(ArgumentError)
        expect { p.box(2, 2, y: 0, x: 0, set: :fancy) }.to raise_error(ArgumentError)
        expect { p.box(2, 2, y: 0, x: 0, hide: :up) }.to raise_error(ArgumentError)
        expect { p.box(2, 2, y: 0, x: 0, corners: 4) }.to raise_error(ArgumentError)
        cells = Array.new(6) { Notcurses::Cell.new(egc: '#') }
        expect { p.box(2, 2, y: 0, x: 0, set: cells, styles: :bold) }.to raise_error(ArgumentError)
      end
    end

    it 'box con set: :heavy e TypeError per un set che non è Symbol, String o Array' do
      with_parent(rows: 4, cols: 10) do |p|
        p.box(3, 5, y: 0, x: 0, set: :heavy)
        expect(p.contents(rows: 3, cols: 5)).to eq('┏━━━┓┃┃┗━━━┛')
        expect { p.box(2, 2, y: 0, x: 0, set: 42) }.to raise_error(TypeError, /set deve essere/)
      end
    end

    it 'perimeter disegna il bordo del piano' do
      with_parent(rows: 3, cols: 4) do |p|
        expect(p.perimeter(set: :double)).to equal(p)
        expect(p.contents).to eq('╔══╗║║╚══╝')
      end
      with_parent(rows: 1, cols: 4) do |p|
        expect { p.perimeter }.to raise_error(ArgumentError)
      end
    end

    it 'polyfill riempie la regione con lo stesso EGC' do
      with_parent(rows: 4, cols: 10) do |p|
        p.box(4, 10, y: 0, x: 0)
        expect(p.polyfill('#', y: 1, x: 1)).to eq(16)
        expect(p.contents(y: 1, rows: 1)).to eq('│########│')
        expect(p.polyfill('#', y: 1, x: 1)).to eq(0)
      end
    end

    it 'gradient sfuma tra gli angoli e controlla i vincoli prima di scrivere' do
      with_parent(rows: 4, cols: 10) do |p|
        blue = Notcurses::Channels.rgb(0, 0, 255, 0, 0, 0)
        expect(p.gradient('x', red, blue, red, blue)).to eq(40)
        expect(p.at(y: 0, x: 0).channels.fg_rgb).to eq([250, 0, 0])
        expect(p.at(y: 3, x: 9).channels.fg_rgb).to eq([0, 0, 255])
        p.erase
        expect { p.gradient('x', 0, red, 0, 0) }.to raise_error(ArgumentError, /default/)
        expect { p.gradient('x', red, blue, blue, red, rows: 1) }.to raise_error(ArgumentError)
        expect { p.gradient('x', red, blue, red, blue, cols: 1) }.to raise_error(ArgumentError)
        expect(p.gradient('x', red, red, blue, blue, cols: 1)).to eq(4)
        p.erase
        expect { p.gradient('x', red, blue, red, blue, rows: 1, cols: 1) }.to raise_error(ArgumentError)
        expect { p.gradient('漢', red, red, red, red) }.to raise_error(ArgumentError)
        palette = Notcurses::Channels.new.with_fg_palindex(3)
        expect { p.gradient('x', palette, palette, palette, palette) }.to raise_error(ArgumentError, /palette/)
        expect(p.contents).to eq('')
        expect(p.gradient('', red, red, red, red, y: 1, x: 2, rows: 2, cols: 3)).to eq(6)
      end
    end

    it 'gradient2x1 disegna mezzi blocchi' do
      with_parent(rows: 2, cols: 4) do |p|
        a = Notcurses::Channel.rgb(255, 0, 0)
        b = Notcurses::Channel.rgb(0, 0, 255)
        expect(p.gradient2x1(a, b, a, b)).to eq(8)
        expect(p.at(y: 0, x: 0).egc).to eq('▀')
        expect { p.gradient2x1(a, b, a, b, cols: 1) }.to raise_error(ArgumentError)
      end
    end

    it 'stain cambia solo i colori delle celle non vuote' do
      with_parent(rows: 2, cols: 4) do |p|
        p.putstr('ab', y: 0, x: 0)
        grey = Notcurses::Channels.rgb(9, 9, 9, 0, 0, 0)
        expect(p.stain(grey, grey, grey, grey)).to eq(8)
        expect(p.at(y: 0, x: 0).channels.fg_rgb).to eq([9, 9, 9])
        expect(p.at(y: 0, x: 0).egc).to eq('a')
        expect { p.stain(grey, grey, grey, grey, y: 2) }.to raise_error(ArgumentError)
      end
    end

    it 'restyle imposta gli stili di un rettangolo' do
      with_parent(rows: 2, cols: 4) do |p|
        p.putstr('abcd', y: 0, x: 0)
        expect(p.restyle(:bold, rows: 1, cols: 2)).to eq(2)
        expect(p.at(y: 0, x: 0).styles).to eq([:bold])
        expect(p.at(y: 0, x: 2).styles).to eq([])
        expect { p.restyle(:bold, cols: 5) }.to raise_error(ArgumentError)
      end
    end

    it 'merge_down fonde nel piano di destinazione; se stesso e un\'altra pila sono PlaneError, come i -1 del C' do
      with_parent(rows: 4, cols: 8) do |p|
        c = p.create_child(rows: 2, cols: 4, y: 1, x: 1)
        c.putstr('ab', y: 0, x: 0)
        expect(c.merge_down(p)).to equal(c)
        expect(p.contents(y: 1, x: 1, rows: 1, cols: 4)).to eq('ab')
        expect(c.contents).to eq('ab')
        expect { c.merge_down(c) }.to raise_error(Notcurses::PlaneError, /stesso/)
        nc.create_pile(rows: 2, cols: 2) do |pile|
          expect { c.merge_down(pile) }.to raise_error(Notcurses::PlaneError, /pila/)
        end
        expect { c.merge_down(:std) }.to raise_error(TypeError)
      end
    end

    it "le stringhe e i buffer del C si liberano con l'allocatore di notcurses (prima: abort sotto LD_PRELOAD)" do
      skip 'serve libc_malloc_debug di glibc' unless File.exist?(NcHelpers::MALLOC_DEBUG)
      script = <<~'RUBY'
        require 'notcurses'
        Notcurses::Context.open(output: '/dev/null', termtype: 'xterm-256color', suppress_banners: true,
                                drain_input: true) do |nc|
          std = nc.stdplane
          200.times do # lo script di ICH-449
            dst = std.create_child(rows: 1, cols: 4, y: 0, x: 2)
            src = std.create_child(rows: 1, cols: 8, y: 0, x: 1)
            src.putstr('漢漢漢漢')
            src.merge_down(dst)
            dst.at(y: 0, x: 0)
            dst.at(y: 0, x: 3)
            dst.putstr('x', y: 0, x: 0)
            dst.putstr('y', y: 0, x: 3)
            src.close
            dst.close
          end
          named = std.create_child(rows: 1, cols: 2, name: 'n')
          named.putstr('  ', y: 0, x: 0)
          200.times { [named.name, nc.stats, named.as_rgba(:half, y: 0, x: 0)] }
          named.close
        end
        puts 'ok'
      RUBY
      expect(NcHelpers.heap_check(script)).to eq([0, "ok\n"])
    end

    it 'erase_region cancella la regione, la taglia al bordo e non muove il cursore' do
      with_parent(rows: 2, cols: 4) do |c|
        c.putstr('ab', y: 0, x: 0)
        c.putstr('cd', y: 1, x: 0)
        expect(c.erase_region(0, 0, 1, 1)).to equal(c)
        expect(c.contents).to eq('bcd')
        expect(c.cursor).to eq([1, 2])
        expect(c.erase_region(1, 1, 5, 5).contents).to eq('bc')
        expect { c.erase_region(2, 0, 1, 1) }.to raise_error(ArgumentError)
        expect { c.erase_region(0, 0, 0, 1) }.to raise_error(ArgumentError)
      end
    end

    context 'su metà di un glifo largo' do
      red = Notcurses::Channel.rgb(255, 0, 0)
      {
        'polyfill dalla metà sinistra' => ['ab漢', ->(p) { p.polyfill('x', y: 0, x: 2) }, 'abx'],
        'polyfill da una cella vuota fino a una metà destra' => ['漢', ->(p) { p.polyfill('x', y: 0, x: 3) }, 'xxx'],
        'erase_region sulla metà sinistra' => ['ab漢', ->(p) { p.erase_region(0, 2, 1, 1) }, 'ab'],
        'erase_region sulla metà destra' => ['ab漢', ->(p) { p.erase_region(0, 3, 1, 1) }, 'ab'],
        'gradient fino alla metà sinistra' => ['ab漢', ->(p) { p.gradient('g', 0, 0, 0, 0, rows: 1, cols: 3) }, 'ggg'],
        'gradient2x1 sulla metà destra' => ['ab漢', ->(p) { p.gradient2x1(red, red, red, red, x: 3, rows: 1, cols: 1) }, 'ab▀']
      }.each do |name, (text, fill, row0)|
        it "#{name}: l'altra metà diventa una cella vuota e una scrittura larga lascia intatta la riga sotto" do
          with_parent(rows: 2, cols: 4) do |p|
            p.putstr(text, y: 0, x: 0)
            p.putstr('WXYZ', y: 1, x: 0)
            fill.call(p)
            expect(p.contents(y: 0, rows: 1)).to eq(row0)
            p.putstr('中', y: 0, x: 2)
            expect(p.contents(y: 1, rows: 1)).to eq('WXYZ') # prima: "XYZ" quando restava la metà destra
          end
        end
      end

      # Dopo merge_down notcurses lascia le metà destre con width 0 (ICH-481):
      # il glifo è intero e nessun controllo deve cancellarlo.
      {
        'una scrittura' => ['日本語テキ', ->(p) { p.putstr('*', y: 0, x: 9) }, '日本語テキ*'],
        'un resize alle stesse dimensioni' => ['漢字ab', ->(p) { p.resize(1, 10) }, '漢字ab'],
        'erase_region prima del glifo' => ['ab漢cd', ->(p) { p.erase_region(0, 0, 1, 2) }, '漢cd'],
        'erase_region accanto al glifo' => ['ab漢cd', ->(p) { p.erase_region(0, 1, 1, 1) }, 'a漢cd'],
        'gradient prima del glifo' => ['ab漢cd', ->(p) { p.gradient('g', 0, 0, 0, 0, rows: 1, cols: 2) }, 'gg漢cd'],
        'polyfill accanto al glifo' => ['a漢b', ->(p) { p.polyfill('x', y: 0, x: 0) }, 'x漢b']
      }.each do |name, (text, op, row)|
        it "dopo merge_down #{name} lascia intero il glifo largo (prima del fix di review: glifo cancellato)" do
          with_parent(rows: 1, cols: 10) do |p|
            dst = p.create_child(rows: 1, cols: 10)
            src = p.create_child(rows: 1, cols: 10)
            src.putstr(text, y: 0, x: 0)
            src.merge_down(dst)
            src.close
            op.call(dst)
            expect(dst.contents).to eq(row)
          end
        end
      end

      it "un riempimento che fallisce a metà svuota lo stesso l'altra metà (prima: \"XYZ\" dopo il PlaneError)" do
        big = 'e' + ("́" * 3_000_000) # le copie superano i 16 MiB dell'egcpool: il C si ferma a metà
        # [righe con "ab漢", riempimento, riga della scrittura larga]
        {gradient: [1, ->(p) { p.gradient(big, 0, 0, 0, 0, rows: 1, cols: 3) }, 0],
         polyfill: [2, ->(p) { p.polyfill(big, y: 1, x: 2) }, 1]}.each do |name, (glyph_rows, fill, y)|
          with_parent(rows: glyph_rows + 1, cols: 4) do |p|
            glyph_rows.times { |r| p.putstr('ab漢', y: r, x: 0) }
            p.putstr('WXYZ', y: glyph_rows, x: 0)
            expect { fill.call(p) }.to raise_error(Notcurses::PlaneError), name.to_s
            p.putstr('中', y: y, x: 2)
            expect(p.contents(y: glyph_rows, rows: 1)).to eq('WXYZ'), name.to_s
          end
        end
      end

      # ncplane_at_yx_cell duplica l'EGC nell'egcpool: con due EGC da 6 MB nel piano la copia del terzo non ci
      # sta, e la lettura delle celle fallisce. Prima del fix di review il glifo illeggibile non veniva tenuto intero.
      {
        erase_region: ->(q) { q.erase_region(0, 2, 1, 1) },
        gradient: ->(q) { q.gradient('x', 0, 0, 0, 0, x: 2, rows: 1, cols: 1) },
        gradient2x1: ->(q) { q.gradient2x1(0, 0, 0, 0, x: 2, rows: 1, cols: 1) },
        polyfill: ->(q) { q.polyfill('x', y: 0, x: 2) }
      }.each do |name, fill|
        it "#{name} su un glifo largo che notcurses non riesce a leggere (egcpool pieno) lascia intatta la riga sotto" do
          egc = '漢' + ("\u0301" * 3_000_000)
          with_parent(rows: 2, cols: 4) do |p|
            p.putstr(egc, y: 0, x: 0)
            p.putstr(egc, y: 0, x: 2)
            p.putstr('WXYZ', y: 1, x: 0)
            fill.call(p)
            p.putstr('中', y: 0, x: 2)
            expect(p.contents(y: 1, rows: 1)).to eq('WXYZ') # prima: "XYZ"
          end
        end
      end

      it "con l'egcpool pieno dopo il riempimento la pulizia svuota lo stesso la metà orfana (prima: \"XYZ\")" do
        # [riempimento, solleva?]: 5,2 MB ci stanno tre volte e il C riesce; con 6 MB il C si ferma a metà,
        # con il glifo dentro il rettangolo
        [
          [->(p) { p.gradient('e' + ("\u0301" * 2_600_000), 0, 0, 0, 0, rows: 1, cols: 3) }, false],
          [->(p) { p.gradient('e' + ("\u0301" * 3_000_000), 0, 0, 0, 0, rows: 1, cols: 4) }, true]
        ].each do |fill, raises|
          with_parent(rows: 2, cols: 4) do |p|
            p.putstr('ab漢', y: 0, x: 0)
            p.putstr('WXYZ', y: 1, x: 0)
            if raises
              expect { fill.call(p) }.to raise_error(Notcurses::PlaneError, /ncplane_gradient/)
            else
              expect(fill.call(p)).to eq(3)
            end
            p.putstr('中', y: 0, x: 2)
            expect(p.contents(y: 1, rows: 1)).to eq('WXYZ')
          end
        end
      end

      it 'senza glifi larghi i riempimenti non cambiano' do
        with_parent(rows: 1, cols: 4) do |p|
          p.putstr('abcd', y: 0, x: 0)
          p.erase_region(0, 1, 1, 2)
          expect(p.contents).to eq('ad')
          expect(p.polyfill('x', y: 0, x: 1)).to eq(2)
          expect(p.contents).to eq('axxd')
        end
      end

      it "la scrittura larga sull'ultima riga non corrompe l'heap (prima: abort di glibc)" do
        skip 'serve libc_malloc_debug di glibc' unless File.exist?(NcHelpers::MALLOC_DEBUG)
        script = <<~'RUBY'
          require 'notcurses'
          Notcurses::Context.open(output: '/dev/null', termtype: 'xterm-256color', suppress_banners: true,
                                  drain_input: true) do |nc|
            fills = [->(q) { q.erase_region(0, 2, 1, 1) }, ->(q) { q.polyfill('x', y: 0, x: 2) },
                     ->(q) { q.gradient('g', 0, 0, 0, 0, rows: 1, cols: 3) }]
            fills.each do |fill|
              planes = Array.new(20) { nc.stdplane.create_child(rows: 1, cols: 4).tap { |q| q.putstr('ab漢', y: 0, x: 0) } }
              planes.each { |q| fill.call(q) }
              planes.each { |q| q.putstr('中', y: 0, x: 2) }
              planes.each(&:close)
            end
            big = 'e' + ("\u0301" * 3_000_000) # gradient che fallisce a metà (egcpool pieno)
            planes = Array.new(3) { nc.stdplane.create_child(rows: 1, cols: 4).tap { |q| q.putstr('ab漢', y: 0, x: 0) } }
            planes.each do |q|
              q.gradient(big, 0, 0, 0, 0, rows: 1, cols: 3)
            rescue Notcurses::PlaneError
              nil
            end
            planes.each { |q| q.putstr('中', y: 0, x: 2) }
            planes.each(&:close)
          end
          puts 'ok'
        RUBY
        expect(NcHelpers.heap_check(script)).to eq([0, "ok\n"])
      end
    end

    it 'greyscale converte i colori delle celle, non quelli del piano' do
      with_parent(rows: 1, cols: 1) do |g|
        g.set_fg_rgb24(0xff0000)
        g.putstr('x', y: 0, x: 0)
        expect(g.greyscale).to equal(g)
        expect(g.at(y: 0, x: 0).channels.fg.rgb).to eq([0x4c, 0x4c, 0x4c])
        expect(g.fg_rgb24).to eq(0xff0000)
      end
    end

    it 'as_rgba legge le celle come glifi del blitter' do
      with_parent(rows: 1, cols: 2) do |q|
        q.set_fg_rgb24(0xff0000)
        q.set_bg_rgb24(0x0000ff)
        q.putstr('  ', y: 0, x: 0)
        bytes, height, width = q.as_rgba(:half, y: 0, x: 0)
        expect([height, width, bytes.bytesize]).to eq([2, 2, 16])
        expect(bytes.unpack('C*')).to eq([0, 0, 0xff, 0xff] * 4)
        q.putstr('▀ ', y: 0, x: 0)
        expect(q.as_rgba(:half, y: 0, x: 0)[0].byteslice(0, 8).unpack('C*')).to eq([0xff, 0, 0, 0xff, 0, 0, 0xff, 0xff])
        expect(q.as_rgba(:half, y: 0, x: 0, rows: nil, cols: 1)[1, 2]).to eq([2, 1])
        q.move_cursor(0, 1)
        expect(q.as_rgba(:half)[1, 2]).to eq([2, 2]) # senza argomenti tutto il piano, anche con il cursore altrove
        expect(q.as_rgba(:half, y: nil, x: nil, rows: 1, cols: nil)[1, 2]).to eq([2, 1]) # y: e x: nil = cursore
        expect { q.as_rgba(:half, y: -1, x: 0) }.to raise_error(ArgumentError) # -1 non è il cursore: usa nil
        expect { q.as_rgba(:half, y: 0, x: 0, rows: 0) }.to raise_error(ArgumentError)
        q.putstr('▀ ', y: 0, x: 0)
        expect { q.as_rgba(:half, y: nil, x: nil) }.to raise_error(Notcurses::PlaneError) # cursore in (0, 2): oltre il bordo
        q.putstr('ab', y: 0, x: 0)
        expect { q.as_rgba(:half, y: 0, x: 0) }.to raise_error(Notcurses::PlaneError)
        expect { q.as_rgba(:pixel) }.to raise_error(ArgumentError)
        q.putstr('  ', y: 0, x: 0)
        expect { q.as_rgba(:four_by_one) }.to raise_error(ArgumentError, /blitter/) # blitter dei plot
        expect { q.as_rgba(:eight_by_one) }.to raise_error(ArgumentError, /blitter/)
      end
    end

    it 'qrcode controlla gli argomenti prima del C' do
      with_parent(rows: 20, cols: 40) do |c|
        expect { c.qrcode('', rows: 20, cols: 40) }.to raise_error(ArgumentError)
        expect { c.qrcode(1, rows: 20, cols: 40) }.to raise_error(TypeError)
        expect { c.qrcode('ciao', rows: 0, cols: 40) }.to raise_error(ArgumentError)
        # senza qrcodegen (la build di Arch) lo stub del C fallisce sempre
        result = begin
          c.qrcode('ciao', rows: 20, cols: 40)
        rescue Notcurses::PlaneError
          :senza_qrcodegen
        end
        expect(result).to eq(:senza_qrcodegen).or match([Integer, Integer, Integer])
      end
    end
  end

  describe 'dissolvenze' do
    def colored_plane(parent)
      parent.set_fg_rgb24(0xc86432).set_bg_rgb24(0x102030)
      parent.putstr('fade', y: 0, x: 0)
      parent
    end

    it 'fadeout arriva al nero, anche con un blocco lento' do
      skip 'il terminale non permette le dissolvenze' unless nc.can_fade?

      with_parent(rows: 1, cols: 5) do |p|
        colored_plane(p)
        steps = 0
        expect(p.fadeout(0.05) { steps += 1; sleep 0.01; nil }).to equal(p)
        expect(steps).to be_between(2, 10)
        expect(p.at(y: 0, x: 0).channels.fg_rgb24).to eq(0)
      end
    end

    it 'fadein torna ai colori di partenza; :stop ferma' do
      skip 'il terminale non permette le dissolvenze' unless nc.can_fade?

      with_parent(rows: 1, cols: 5) do |p|
        colored_plane(p)
        p.fadein(0.02)
        expect(p.at(y: 0, x: 0).channels.fg_rgb24).to eq(0xc86432)
        expect(p.at(y: 0, x: 0).channels.bg_rgb24).to eq(0x102030)
        calls = 0
        p.fadein(5) { calls += 1; :stop }
        expect(calls).to eq(1)
      end
    end

    it 'pulse richiede un blocco e si ferma con :stop; le eccezioni del blocco escono' do
      skip 'il terminale non permette le dissolvenze' unless nc.can_fade?

      with_parent(rows: 1, cols: 5) do |p|
        colored_plane(p)
        expect { p.pulse(0.01) }.to raise_error(ArgumentError)
        calls = 0
        expect(p.pulse(0.005) { calls += 1; :stop if calls > 5 }).to equal(p)
        expect { p.fadeout(0.05) { raise 'boom' } }.to raise_error(RuntimeError, 'boom')
        expect { p.fadeout(0) }.to raise_error(ArgumentError)
        expect { p.fadeout('1') }.to raise_error(TypeError)
      end
    end
  end
end
