# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative '../support/nc_helpers'

# Piani figli del piano dell'albero, dall'alto: [y, righe, testo della prima riga].
module TreeSpecHelpers
  def item_layout(tree_plane)
    f = Notcurses::FFI
    out = []
    ptr = f.ncpile_top(tree_plane.to_ptr)
    until ptr.null?
      if ptr.address != tree_plane.address && f.ncplane_parent(ptr).address == tree_plane.address
        text = Notcurses::Plane.new(ptr, owned: false, context: tree_plane.context, tracked: false).contents(rows: 1)
        out << [f.ncplane_y(ptr), f.ncplane_dim_y(ptr), text]
      end
      ptr = f.ncplane_below(ptr)
    end
    out.sort
  end

  # Blocco di disegno che scrive il valore e usa una riga (o rows[valore] righe).
  def drawer(log = [], rows: {})
    lambda do |plane, value, distance|
      log << [value, distance, !plane.nil?]
      next 0 unless plane

      n = rows.fetch(value, 1)
      n.times { |r| plane.putstr("#{value}.#{r}", y: r, x: 0) if r < plane.dim_y }
      n
    end
  end
end

RSpec.describe Notcurses::Tree do
  include_context 'con un contesto notcurses'
  include TreeSpecHelpers

  let(:std) { nc.stdplane }
  let(:items) { ['a', { 'b' => ['b0', { 'b1' => ['b10'] }] }, 'c'] }

  def new_plane(rows: 6, cols: 20) = std.create_child(rows: rows, cols: cols)

  def new_tree(items = self.items, rows: 6, cols: 20, indent: 2, log: [], &block)
    described_class.new(new_plane(rows: rows, cols: cols), items: items, indent: indent, &(block || drawer(log)))
  end

  # Valori visitati in pre-ordine dalla prima voce.
  def walk(tree)
    tree.goto([0])
    seen = [tree.focused]
    loop do
      v = tree.next
      break if v.equal?(seen.last)

      seen << v
    end
    seen
  end

  describe '.new' do
    it 'disegna le voci visibili e mette il fuoco sulla prima' do
      log = []
      plane = new_plane
      tree = described_class.new(plane, items: items, indent: 2, &drawer(log))
      expect(log.first).to eq(['a', 0, true])
      expect(log.map(&:first)).to eq(%w[a b b0 b1 b10 c])
      expect(tree.count).to eq(6)
      expect(tree.size).to eq(6)
      expect(tree).not_to be_empty
      expect(tree.focused).to eq('a')
      expect(tree.focused_path).to eq([0])
      expect(tree.plane).to equal(plane)
      expect(tree.context).to equal(nc)
      expect(plane).to be_widget_plane
      expect(item_layout(plane)).to eq([[0, 1, 'a.0'], [1, 1, 'b.0'], [2, 1, 'b0.0'], [3, 1, 'b1.0'], [4, 1, 'b10.0'],
                                        [5, 1, 'c.0']])
      tree.close
    end

    it 'accetta un Hash come voci e un albero vuoto' do
      tree = described_class.new(new_plane, items: { 'x' => ['y'], 'z' => [] }) { |_p, _v, _d| 1 }
      expect(walk(tree)).to eq(%w[x y z])
      tree.close
      empty = described_class.new(new_plane) { |_p, _v, _d| 1 }
      expect(empty).to be_empty
      expect(empty.count).to eq(0)
      empty.close
    end

    it 'valida gli argomenti prima di chiamare il C' do
      plane = new_plane
      expect { described_class.new(plane, items: items) }.to raise_error(ArgumentError, /blocco/)
      expect { described_class.new(plane, items: items, draw: drawer) { 1 } }.to raise_error(ArgumentError, /entrambi/)
      expect { described_class.new(plane, items: items, draw: :disegna) }.to raise_error(TypeError, /call/)
      expect { described_class.new(plane, items: 'a') { 1 } }.to raise_error(TypeError)
      expect { described_class.new(plane, items: ['a', %w[b c]]) { 1 } }.to raise_error(TypeError, /Hash/)
      expect { described_class.new(plane, items: [{ 'a' => 'b' }]) { 1 } }.to raise_error(TypeError)
      expect { described_class.new(plane, items: items, indent: -1) { 1 } }.to raise_error(ArgumentError)
      expect { described_class.new(plane, items: items, indent: 10) { 1 } }.to raise_error(ArgumentError, /indent/)
      expect { described_class.new(:piano, items: items) { 1 } }.to raise_error(TypeError)
      expect { described_class.new(std, items: items) { 1 } }.to raise_error(Notcurses::WidgetError, /stdplane/)
      expect(plane).not_to be_closed
      expect(plane).not_to be_widget_plane
      plane.close
    end

    it 'rifiuta il piano di un altro widget e un piano preso in prestito' do
      tree = new_tree
      expect { described_class.new(tree.plane, items: items) { 1 } }.to raise_error(Notcurses::WidgetError, /widget/)
      borrowed = Notcurses::Plane.new(new_plane.to_ptr, owned: false, context: nc, tracked: false)
      expect { described_class.new(borrowed, items: items) { 1 } }.to raise_error(Notcurses::WidgetError, /prestito/)
      tree.close
    end

    it 'open con un blocco chiude l\'albero e il piano' do
      plane = new_plane
      result = described_class.open(plane, items: items, draw: drawer) do |tree|
        expect(tree).not_to be_closed
        :fatto
      end
      expect(result).to eq(:fatto)
      expect(plane).to be_closed
    end

    it 'un\'eccezione del blocco nel primo disegno esce da new e distrugge albero e piano' do
      plane = new_plane
      expect { described_class.new(plane, items: items) { |_p, _v, _d| raise ArgumentError, 'boom' } }
        .to raise_error(ArgumentError, 'boom')
      expect(plane).to be_closed
      expect(nc.callback_errors).to be_empty
    end

    it 'break e throw nel blocco non attraversano il C: LocalJumpError, senza piani orfani' do
      before = nc.stats.planes
      plane = new_plane
      expect { described_class.new(plane, items: items) { |_p, _v, _d| break :uscita } }.to raise_error(LocalJumpError)
      expect(plane).to be_closed
      expect(nc.stats.planes).to eq(before)
      expect(nc.callback_errors).to be_empty
      draw = ->(_p, _v, _d) { 1 }
      tree = described_class.new(new_plane, items: items, draw: ->(pl, v, d) { draw.call(pl, v, d) })
      draw = ->(_p, _v, _d) { throw :fuori }
      expect { catch(:fuori) { tree.redraw } }.to raise_error(LocalJumpError)
      expect(nc.callback_errors).to be_empty
      tree.close
    end

    it 'non si crea dentro un callback chiamato da notcurses' do
      parent = std.create_child(rows: 3, cols: 3)
      target = new_plane
      parent.create_child(rows: 1, cols: 1, resize: ->(_p) { described_class.new(target, items: ['x']) { 1 } })
      expect { parent.resize(4, 4) }.to raise_error(Notcurses::WidgetError, /callback/)
      expect(target).not_to be_closed
      expect(target).not_to be_widget_plane
      parent.family_destroy
      target.close
    end
  end

  describe 'navigazione' do
    it 'next e prev seguono il pre-ordine e si fermano alle estremità' do
      tree = new_tree
      expect(tree.next).to eq('b')
      expect(tree.next).to eq('b0')
      expect(tree.next).to eq('b1')
      expect(tree.focused_path).to eq([1, 1])
      expect([tree.next, tree.next, tree.next]).to eq(%w[b10 c c])
      expect(tree.prev).to eq('b10')
      tree.goto([0])
      expect(tree.prev).to eq('a')
      tree.close
    end

    it 'goto sposta il fuoco in Ruby (nctree_goto di 3.0.17 è uno stub)' do
      tree = new_tree
      expect(tree.goto([1, 1, 0])).to eq('b10')
      expect(tree.focused_path).to eq([1, 1, 0])
      expect(tree.goto([2])).to eq('c')
      expect { tree.goto([3]) }.to raise_error(ArgumentError)
      expect { tree.goto([0, 0]) }.to raise_error(ArgumentError, /livello 1/)
      expect { tree.goto([]) }.to raise_error(ArgumentError, /vuoto/)
      expect { tree.goto('0') }.to raise_error(TypeError)
      expect { tree.goto([0.5]) }.to raise_error(TypeError)
      tree.close
    end

    it 'offer_input: frecce, PgUp/PgDn, Home ed End; false per i rilasci e gli altri tasti' do
      tree = new_tree
      key = ->(id, **kw) { Notcurses::Input.synthesize(id, **kw) }
      expect(tree.offer_input(key.call(Notcurses::Key::DOWN))).to be(true)
      expect(tree.focused).to eq('b')
      expect(tree.offer_input(key.call(Notcurses::Key::PGDOWN))).to be(true)
      expect(tree.focused).to eq('b0')
      expect(tree.offer_input(key.call(Notcurses::Key::UP))).to be(true)
      expect(tree.offer_input(key.call(Notcurses::Key::END_KEY))).to be(true)
      expect(tree.focused).to eq('c')
      expect(tree.offer_input(key.call(Notcurses::Key::PGUP))).to be(true)
      expect(tree.focused).to eq('b10')
      expect(tree.offer_input(key.call(Notcurses::Key::HOME))).to be(true)
      expect(tree.focused).to eq('a')
      expect(tree.offer_input(key.call(Notcurses::Key::DOWN, evtype: :release))).to be(false)
      expect(tree.offer_input(key.call('x'.ord))).to be(false)
      expect(tree.focused).to eq('a')
      expect { tree.offer_input(Notcurses::Key::DOWN) }.to raise_error(TypeError)
      tree.close
    end
  end

  describe 'modifiche' do
    it 'add inserisce una voce, anche in fondo, e il fuoco resta sulla stessa voce' do
      tree = new_tree
      tree.goto([2])
      expect(tree.add([0], 'z')).to equal(tree)
      expect(tree.focused).to eq('c')
      expect(tree.focused_path).to eq([3])
      tree.add([2, 2], 'b2').add([4], 'fine')
      expect(tree.count).to eq(9)
      expect(walk(tree)).to eq(%w[z a b b0 b1 b10 b2 c fine])
      tree.redraw
      tree.close
    end

    it 'add rifiuta percorsi non validi e un livello troppo indentato' do
      tree = new_tree([{ 'r' => [] }], cols: 5, indent: 2)
      expect { tree.add([], 'x') }.to raise_error(ArgumentError, /vuoto/)
      expect { tree.add([2], 'x') }.to raise_error(ArgumentError)
      expect { tree.add([0, 1], 'x') }.to raise_error(ArgumentError)
      expect { tree.add([1, 0], 'x') }.to raise_error(ArgumentError)
      expect { tree.add([-1], 'x') }.to raise_error(ArgumentError)
      expect { tree.add(nil, 'x') }.to raise_error(TypeError)
      tree.add([0, 0], 'f').add([0, 0, 0], 'g')
      expect { tree.add([0, 0, 0, 0], 'troppo') }.to raise_error(ArgumentError, /indent/)
      expect(tree.count).to eq(3)
      tree.close
    end

    it 'add in un albero vuoto dà il fuoco alla nuova voce' do
      tree = described_class.new(new_plane, &drawer)
      expect(tree.add([0], 'primo').focused).to eq('primo')
      expect(tree.add([0], 'prima').focused).to eq('primo')
      expect(walk(tree)).to eq(%w[prima primo])
      tree.close
    end

    it 'delete toglie la voce giusta (nctree_del legge spec[-1]) con i discendenti' do
      tree = new_tree(%w[x y z])
      expect(tree.delete([1])).to equal(tree)
      expect(walk(tree)).to eq(%w[x z])
      tree.close
      tree = new_tree
      tree.delete([1, 1])
      expect(walk(tree)).to eq(%w[a b b0 c])
      expect(tree.count).to eq(4)
      tree.redraw
      expect(item_layout(tree.plane).map(&:last)).to eq(%w[a.0 b.0 b0.0 c.0])
      tree.close
      tree = new_tree(['a', { 'b' => %w[b0 b1 b2] }])
      tree.delete([1, 0]) # una voce non ultima a profondità 2: il C sposta i fratelli successivi
      expect(walk(tree)).to eq(%w[a b b1 b2])
      expect(tree.count).to eq(4)
      tree.delete([1, 1])
      expect(walk(tree)).to eq(%w[a b b1])
      tree.close
    end

    it 'delete sposta il fuoco sulla voce che prende il posto di quella cancellata' do
      tree = new_tree
      tree.goto([1, 1, 0])
      tree.delete([1, 1])
      expect(tree.focused).to eq('c')
      tree.goto([2])
      tree.delete([2])
      expect(tree.focused).to eq('b0')
      tree.goto([0])
      tree.delete([1])
      expect(tree.focused).to eq('a')
      tree.close
    end

    it 'delete rifiuta il percorso vuoto (double free in 3.0.17) e quelli inesistenti' do
      tree = new_tree
      expect { tree.delete([]) }.to raise_error(ArgumentError, /vuoto/)
      expect { tree.delete([3]) }.to raise_error(ArgumentError)
      expect { tree.delete([0, 0]) }.to raise_error(ArgumentError)
      expect(tree.count).to eq(6)
      tree.close
    end

    it 'su un albero vuoto focused, next, prev e offer_input non chiamano il C' do
      tree = new_tree(%w[solo])
      tree.delete([0])
      expect(tree).to be_empty
      expect(tree.focused).to be_nil
      expect(tree.focused_path).to be_nil
      expect(tree.next).to be_nil
      expect(tree.prev).to be_nil
      expect(tree.offer_input(Notcurses::Input.synthesize(Notcurses::Key::HOME))).to be(false)
      expect(tree.offer_input(Notcurses::Input.synthesize(Notcurses::Key::DOWN))).to be(false)
      expect(tree.redraw).to equal(tree)
      tree.add([0], 'di nuovo')
      expect(tree.focused).to eq('di nuovo')
      tree.redraw
      expect(item_layout(tree.plane).map(&:last)).to eq(['di nuovo.0'])
      tree.close
    end
  end

  describe '#redraw' do
    it 'impila le voci di più righe sopra e sotto il fuoco senza sovrapporle' do
      rows = (1..8).to_h { |i| ["v#{i}", i == 3 ? 1 : 3] }
      tree = described_class.new(new_plane(rows: 20), items: rows.keys, &drawer(rows: rows))
      layouts = []
      [:next, :next, :next, :next, :next, :prev, :prev, :prev].each do |step|
        step == :next ? tree.next : tree.prev
        tree.redraw
        layouts << [tree.focused, item_layout(tree.plane)]
      end
      layouts.each do |focused, layout|
        # voci contigue, dentro il piano, e la voce con il fuoco è disegnata
        layout.each_cons(2) { |(y1, r1, _), (y2, _, _)| expect(y1 + r1).to eq(y2) }
        expect(layout.first[0]).to be >= 0
        expect(layout.last[0] + layout.last[1]).to be <= 20
        expect(layout.map(&:last)).to include("#{focused}.0")
      end
      tree.close
    end

    it 'passa nil per le voci spinte fuori dallo schermo' do
      log = []
      tree = new_tree((1..6).map { |i| "v#{i}" }, rows: 3, log: log)
      log.clear
      tree.goto([5])
      tree.redraw
      expect(log).to include(['v1', -5, false])
      expect(item_layout(tree.plane).map(&:last)).to eq(%w[v4.0 v5.0 v6.0])
      tree.close
    end

    it 'dopo un resize del piano riporta il fuoco dentro il piano' do
      tree = new_tree((1..10).map { |i| "v#{i}" }, rows: 10)
      tree.goto([8])
      tree.redraw
      tree.plane.resize(4, 20)
      expect(tree.redraw).to equal(tree)
      expect(tree.focused).to eq('v9')
      expect(item_layout(tree.plane).last).to eq([3, 1, 'v9.0'])
      tree.close
    end

    it 'rifiuta un piano diventato troppo stretto per l\'indentazione' do
      tree = new_tree
      tree.plane.resize(6, 4)
      expect { tree.redraw }.to raise_error(Notcurses::WidgetError, /indent/)
      tree.plane.resize(6, 20)
      expect(tree.redraw).to equal(tree)
      tree.close
    end

    it 'un\'eccezione o un ritorno non Integer del blocco escono da redraw e l\'albero resta utilizzabile' do
      fail_on = nil
      tree = new_tree do |plane, value, _distance|
        raise "boom #{value}" if value == fail_on
        next :righe if value == 'b' && fail_on == :tipo

        plane&.putstr(value, y: 0, x: 0)
        1
      end
      fail_on = 'b0'
      expect { tree.redraw }.to raise_error(RuntimeError, 'boom b0')
      fail_on = :tipo
      expect { tree.redraw }.to raise_error(TypeError, /Integer/)
      fail_on = nil
      expect(tree.redraw).to equal(tree)
      expect(nc.callback_errors).to be_empty
      expect(tree.next).to eq('b')
      tree.close
    end

    it 'dentro il blocco i metodi dell\'albero e la distruzione di piani sollevano WidgetError/PlaneError' do
      errors = []
      other = new_plane
      tree = nil
      tree = new_tree do |plane, value, _distance|
        if tree && value == 'a'
          [-> { tree.next }, -> { tree.add([0], 'x') }, -> { tree.close }, -> { tree.focused }].each do |call|
            call.call
          rescue Notcurses::WidgetError => e
            errors << e.class
          end
          begin
            other.close
          rescue Notcurses::PlaneError => e
            errors << e.class
          end
        end
        plane&.putstr(value, y: 0, x: 0)
        1
      end
      tree.redraw
      expect(errors).to eq(([Notcurses::WidgetError] * 4) + [Notcurses::PlaneError])
      expect(tree.count).to eq(6)
      expect(other).not_to be_closed
      tree.close
      other.close
    end

    it 'dentro il blocco Tree.new, Tabbed.new e Reel.new sollevano WidgetError' do
      targets = Array.new(3) { new_plane }
      makers = [->(pl) { described_class.new(pl, items: ['x']) { 1 } }, ->(pl) { Notcurses::Tabbed.new(pl) },
                ->(pl) { Notcurses::Reel.new(pl) }]
      errors = []
      tree = nil
      tree = new_tree do |plane, value, _distance|
        if tree && value == 'a'
          makers.zip(targets).each do |make, target|
            make.call(target)
          rescue Notcurses::WidgetError => e
            errors << e.message
          end
        end
        plane&.putstr(value, y: 0, x: 0)
        1
      end
      tree.redraw
      expect(errors).to eq(%w[Tree Tabbed Reel].map { |w| "#{w}.new non è permesso dentro un callback chiamato da notcurses" })
      targets.each do |target|
        expect(target).not_to be_closed
        expect(target).not_to be_widget_plane
      end
      tree.close
      targets.each(&:close)
    end
  end

  describe 'ciclo di vita' do
    it 'close distrugge albero e piano, è idempotente, e poi i metodi sollevano ClosedError' do
      tree = new_tree
      plane = tree.plane
      expect(tree.close).to be_nil
      expect(tree.close).to be_nil
      expect(tree.destroy).to be_nil
      expect(tree).to be_closed
      expect(plane).to be_closed
      expect(tree.inspect).to include('chiuso')
      expect { tree.redraw }.to raise_error(Notcurses::ClosedError)
      expect { tree.focused }.to raise_error(Notcurses::ClosedError)
      expect { tree.focused_path }.to raise_error(Notcurses::ClosedError)
      expect { tree.next }.to raise_error(Notcurses::ClosedError)
      expect { tree.prev }.to raise_error(Notcurses::ClosedError)
      expect { tree.count }.to raise_error(Notcurses::ClosedError)
      expect { tree.empty? }.to raise_error(Notcurses::ClosedError)
      expect { tree.plane }.to raise_error(Notcurses::ClosedError)
      expect { tree.goto([0]) }.to raise_error(Notcurses::ClosedError)
      expect { tree.add([0], 'x') }.to raise_error(Notcurses::ClosedError)
      expect { tree.delete([0]) }.to raise_error(Notcurses::ClosedError)
      expect { tree.offer_input(Notcurses::Input.synthesize(Notcurses::Key::DOWN)) }.to raise_error(Notcurses::ClosedError)
    end

    it 'il piano appartiene all\'albero: Plane#close non fa nulla e un antenato non si distrugge' do
      parent = new_plane(rows: 8)
      plane = parent.create_child(rows: 4, cols: 10)
      tree = described_class.new(plane, items: %w[a b], &drawer)
      expect(plane.close).to be_nil
      expect(plane).not_to be_closed
      expect { parent.family_destroy }.to raise_error(Notcurses::PlaneError, /widget/)
      tree.close
      expect(plane).to be_closed
      parent.family_destroy
    end
  end
end

RSpec.describe Notcurses::Tree, 'con il contesto' do
  include TreeSpecHelpers

  it 'Context#close chiude un albero aperto prima di notcurses_stop' do
    tree = nil
    NcHelpers.open_context do |ctx|
      tree = described_class.new(ctx.stdplane.create_child(rows: 4, cols: 10), items: %w[a b], &drawer)
    end
    expect(tree).to be_closed
    expect { tree.focused }.to raise_error(Notcurses::ClosedError)
  end

  it 'Context#drop_planes chiude un albero aperto' do
    NcHelpers.open_context do |ctx|
      plane = ctx.stdplane.create_child(rows: 4, cols: 10)
      tree = described_class.new(plane, items: %w[a b], &drawer)
      ctx.drop_planes
      expect(tree).to be_closed
      expect(plane).to be_closed
      ctx.render
    end
  end
end
