# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative '../support/nc_helpers'

RSpec.describe Notcurses::Tabbed do
  include_context 'con un contesto notcurses'

  let(:std) { nc.stdplane }

  # un esempio fallito non lascia piani sullo schermo degli altri
  after { nc.drop_planes }
  let(:draw) { ->(tab, content) { content.erase.putstr("contenuto #{tab.name}", y: 0, x: 0) } }

  def new_plane(rows: 4, cols: 20) = std.create_child(rows: rows, cols: cols)

  def names(tabbed) = tabbed.tabs.map(&:name)

  # Riga y dello schermo dopo un render (le celle vuote non contano).
  def screen_row(y, cols = 20)
    nc.render
    (0...cols).map { |x| nc.at(y, x)&.egc.to_s }.join
  end

  # Tabbed con i tab a, b, c, in quest'ordine; il blocco scrive il nome nel contenuto.
  def abc(plane = new_plane, **opts)
    tabbed = described_class.new(plane, **opts)
    %w[a b c].each { |n| tabbed.add(n, after: tabbed.tabs.last, &draw) }
    tabbed
  end

  describe '.new' do
    it 'crea intestazione e contenuto; il piano diventa del widget' do
      plane = new_plane
      tabbed = described_class.new(plane, separator: ' | ')
      content = tabbed.content_plane
      expect(tabbed.plane).to equal(plane)
      expect(tabbed.context).to equal(nc)
      expect(content.dims).to eq([3, 20])
      expect(content.y).to eq(1)
      expect(content.parent).to equal(plane)
      expect(plane).to be_widget_plane
      expect(content).to be_widget_plane
      expect(tabbed.tab_count).to eq(0)
      expect(tabbed.tabs).to eq([])
      expect(tabbed.selected).to be_nil
      expect(tabbed.leftmost).to be_nil
      expect(tabbed.separator).to eq(' | ')
      expect(tabbed.separator_width).to eq(3)
      expect(tabbed.redraw).to equal(tabbed)
      tabbed.close
    end

    it 'con bottom: true il contenuto sta in alto (e in 3.0.17 l\'intestazione sulla penultima riga)' do
      tabbed = described_class.new(new_plane, bottom: true)
      expect(tabbed.content_plane.y).to eq(0)
      expect(tabbed.content_plane.dim_y).to eq(3)
      tabbed.add('Basso') { |_tab, content| 3.times { |i| content.putstr("r#{i}", y: i, x: 0) } }
      tabbed.redraw
      expect([0, 1, 2, 3].map { |y| screen_row(y) }).to eq(['r0', 'r1', 'Basso', ''])
      tabbed.close
    end

    it 'valida gli argomenti e lascia il piano al chiamante' do
      plane = new_plane
      small = new_plane(rows: 1)
      expect { described_class.new(small) }.to raise_error(Notcurses::WidgetError, /2 righe/)
      small.close
      expect { described_class.new(plane, separator: "a\tb") }.to raise_error(ArgumentError, /controllo/)
      expect { described_class.new(plane, separator: "\xff".b) }.to raise_error(ArgumentError, /UTF-8/)
      expect { described_class.new(plane, separator: 5) }.to raise_error(TypeError)
      expect { described_class.new(plane, selected_channels: 'rosso') }.to raise_error(TypeError)
      expect { described_class.new(plane, bottom: 1) }.to raise_error(TypeError)
      expect { described_class.new(:piano) }.to raise_error(TypeError)
      expect { described_class.new(std) }.to raise_error(Notcurses::WidgetError, /stdplane/)
      borrowed = Notcurses::Plane.new(plane.to_ptr, owned: false, context: nc, tracked: false)
      expect { described_class.new(borrowed) }.to raise_error(Notcurses::WidgetError, /prestito/)
      expect(plane).not_to be_closed
      expect(plane).not_to be_widget_plane
      plane.close
    end

    it 'rifiuta il piano di un widget e un piano con un widget fra i discendenti' do
      parent = new_plane(rows: 8)
      inner = described_class.new(parent.create_child(rows: 3, cols: 10))
      expect { described_class.new(inner.plane) }.to raise_error(Notcurses::WidgetError, /widget/)
      expect { described_class.new(inner.content_plane) }.to raise_error(Notcurses::WidgetError, /widget/)
      expect { described_class.new(parent) }.to raise_error(Notcurses::WidgetError, /discendente/)
      expect(parent).not_to be_widget_plane
      inner.close
      tabbed = described_class.new(parent)
      tabbed.close
      expect(parent).to be_closed
    end

    it 'open con un blocco chiude il widget e il piano' do
      plane = new_plane
      result = described_class.open(plane, separator: '|') do |tabbed|
        tabbed.add('x')
        :fatto
      end
      expect(result).to eq(:fatto)
      expect(plane).to be_closed
    end
  end

  describe 'tab' do
    it 'add mette il nuovo tab dopo il selezionato, o dopo after: / prima di before:' do
      tabbed = described_class.new(new_plane)
      s = tabbed.add('s')
      expect(tabbed.selected).to equal(s)
      expect(tabbed.leftmost).to equal(s)
      a = tabbed.add('a', after: s)
      b = tabbed.add('b', after: a)
      expect(names(tabbed)).to eq(%w[s a b])
      expect(tabbed.add('z').name).to eq('z')
      expect(names(tabbed)).to eq(%w[s z a b])
      x = tabbed.add('x', after: a, before: b)
      expect(names(tabbed)).to eq(%w[s z a x b])
      tabbed.add('y', before: s)
      expect(names(tabbed)).to eq(%w[s z a x b y])
      expect(tabbed.tab_count).to eq(6)
      expect(tabbed.selected).to equal(s)
      expect(a.next).to equal(x)
      expect(a.prev.name).to eq('z')
      expect(s.prev.name).to eq('y')
      expect(tabbed.tabs.last.next).to equal(s)
      expect(x).to be_a(Notcurses::Tab)
      expect(x.tabbed).to equal(tabbed)
      tabbed.close
    end

    it 'add rifiuta nomi, after: e before: non validi (un nome NULL va in crash)' do
      tabbed = abc
      a, b, c = tabbed.tabs
      other = described_class.new(new_plane)
      foreign = other.add('o')
      expect { tabbed.add(nil) }.to raise_error(TypeError)
      expect { tabbed.add(5) }.to raise_error(TypeError)
      expect { tabbed.add("a\nb") }.to raise_error(ArgumentError, /controllo/)
      expect { tabbed.add("\u0085") }.to raise_error(ArgumentError, /controllo/)
      expect { tabbed.add("\xff".b) }.to raise_error(ArgumentError, /UTF-8/)
      expect { tabbed.add('x', after: :a) }.to raise_error(TypeError)
      expect { tabbed.add('x', before: foreign) }.to raise_error(ArgumentError, /non è un tab aperto/)
      expect { tabbed.add('x', after: a, before: a) }.to raise_error(ArgumentError, /subito dopo/)
      expect { tabbed.add('x', after: a, before: c) }.to raise_error(ArgumentError, /subito dopo/)
      expect(tabbed.add('x', after: c, before: a).name).to eq('x')
      tabbed.delete(b)
      expect { tabbed.add('y', after: b) }.to raise_error(ArgumentError, /non è un tab aperto/)
      expect(names(tabbed)).to eq(%w[a c x])
      other.close
      tabbed.close
    end

    it 'un nome BINARY con UTF-8 valido diventa UTF-8' do
      tabbed = described_class.new(new_plane)
      tab = tabbed.add('Bé'.b)
      expect(tab.name).to eq('Bé')
      expect(tab.name.encoding).to eq(Encoding::UTF_8)
      expect(tab.name_width).to eq(2)
      tabbed.close
    end

    it 'name=, name_width, callback e callback=' do
      tabbed = described_class.new(new_plane, separator: '|')
      tab = tabbed.add('uno', &draw)
      expect(tab.callback).to equal(draw)
      tab.name = 'Ж'
      expect(tab.name).to eq('Ж')
      expect(tab.name_width).to eq(1)
      expect { tab.name = nil }.to raise_error(TypeError)
      expect { tab.name = "x\ty" }.to raise_error(ArgumentError, /controllo/)
      expect(tab.name).to eq('Ж')
      tabbed.redraw
      expect(screen_row(1)).to eq('contenuto Ж')
      tab.callback = nil
      expect(tab.callback).to be_nil
      tabbed.content_plane.erase
      tabbed.redraw
      expect(screen_row(0)).to eq('Ж')
      expect(screen_row(1)).to eq('')
      tab.callback = ->(_tab, content) { content.putstr('nuovo', y: 0, x: 0) }
      tabbed.redraw
      expect(screen_row(1)).to eq('nuovo')
      expect { tab.callback = 5 }.to raise_error(TypeError, /call/)
      tabbed.close
    end

    it 'un tab senza blocco non disegna il contenuto' do
      tabbed = described_class.new(new_plane)
      tab = tabbed.add('vuoto')
      expect(tab.callback).to be_nil
      expect(tabbed.redraw).to equal(tabbed)
      expect(screen_row(0)).to eq('vuoto')
      tabbed.close
    end

    it 'delete toglie il tab; selezione e primo mostrato passano al successivo' do
      tabbed = abc
      a, b, c = tabbed.tabs
      other = described_class.new(new_plane)
      foreign = other.add('o')
      expect(tabbed.delete(a)).to equal(tabbed)
      expect(a).to be_closed
      expect(tabbed.selected).to equal(b)
      expect(tabbed.leftmost).to equal(b)
      expect(names(tabbed)).to eq(%w[b c])
      expect { a.name }.to raise_error(Notcurses::ClosedError)
      expect { tabbed.delete(a) }.to raise_error(ArgumentError, /non è un tab aperto/)
      expect { tabbed.delete(foreign) }.to raise_error(ArgumentError, /non è un tab aperto/)
      expect { tabbed.delete(:b) }.to raise_error(TypeError)
      tabbed.delete(c).delete(b)
      expect(tabbed.tab_count).to eq(0)
      expect(foreign).not_to be_closed
      other.close
      tabbed.close
    end

    it 'select, next e prev seguono la lista circolare; size è tab_count' do
      tabbed = abc
      a, b, c = tabbed.tabs
      expect(tabbed.select(c)).to equal(a)
      expect(tabbed.selected).to equal(c)
      expect(tabbed.next).to equal(a)
      expect(tabbed.prev).to equal(c)
      expect(tabbed.prev).to equal(b)
      expect(tabbed.leftmost).to equal(a)
      expect([tabbed.size, tabbed.tab_count]).to eq([3, 3])
      other = described_class.new(new_plane)
      expect { tabbed.select(other.add('o')) }.to raise_error(ArgumentError)
      expect { tabbed.select(nil) }.to raise_error(TypeError)
      expect(tabbed.selected).to equal(b)
      other.close
      tabbed.close
    end

    it 'rotate fa scorrere l\'intestazione senza cambiare la selezione' do
      tabbed = abc
      expect(tabbed.rotate(1)).to equal(tabbed)
      expect(names(tabbed)).to eq(%w[c a b])
      tabbed.rotate(-1)
      expect(names(tabbed)).to eq(%w[a b c])
      tabbed.rotate(-1)
      expect(names(tabbed)).to eq(%w[b c a])
      tabbed.rotate(3)
      expect(names(tabbed)).to eq(%w[b c a])
      tabbed.rotate(-4)
      expect(names(tabbed)).to eq(%w[c a b])
      expect(tabbed.selected.name).to eq('a')
      expect { tabbed.rotate('1') }.to raise_error(TypeError)
      tabbed.close
    end

    it 'senza tab rotate, next e prev non chiamano il C (nctabbed_rotate va in crash)' do
      tabbed = described_class.new(new_plane)
      expect(tabbed.rotate(5)).to equal(tabbed)
      expect(tabbed.rotate(-1)).to equal(tabbed)
      expect(tabbed.next).to be_nil
      expect(tabbed.prev).to be_nil
      expect(tabbed.ensure_selected_header_visible).to equal(tabbed)
      expect(tabbed.redraw).to equal(tabbed)
      tabbed.close
    end

    it 'move sposta il tab e tiene coerente il primo mostrato' do
      tabbed = abc
      a, b, c = tabbed.tabs
      expect(c.move(after: a)).to equal(c)
      expect(names(tabbed)).to eq(%w[a c b])
      a.move(after: b) # a era il primo: il primo diventa c
      expect(names(tabbed)).to eq(%w[c b a])
      a.move(before: c) # prima del primo: diventa il primo
      expect(names(tabbed)).to eq(%w[a c b])
      b.move(before: c)
      expect(names(tabbed)).to eq(%w[a b c])
      expect(tabbed.leftmost).to equal(a)
      expect(tabbed.tab_count).to eq(3)
      tabbed.close
    end

    it 'move rifiuta after: e before: insieme (adiacenza invertita in 3.0.17), nessuno dei due e tab estranei' do
      tabbed = abc
      a, b, c = tabbed.tabs
      other = described_class.new(new_plane)
      foreign = other.add('o')
      expect { c.move(after: a, before: b) }.to raise_error(ArgumentError, /esattamente uno/)
      expect { c.move }.to raise_error(ArgumentError, /esattamente uno/)
      expect { c.move(after: c) }.to raise_error(ArgumentError, /se stesso/)
      expect { c.move(before: foreign) }.to raise_error(ArgumentError, /non è un tab aperto/)
      expect { foreign.move(after: a) }.to raise_error(ArgumentError, /non è un tab aperto/)
      expect { c.move(after: 'a') }.to raise_error(TypeError)
      expect(names(tabbed)).to eq(%w[a b c])
      expect(names(other)).to eq(%w[o])
      other.close
      tabbed.close
    end

    it 'move_left e move_right scambiano il tab con il vicino, anche ai bordi' do
      tabbed = abc
      a, b, = tabbed.tabs
      expect(b.move_left).to equal(b)
      expect(names(tabbed)).to eq(%w[b a c])
      expect(b.move_right).to equal(b)
      expect(names(tabbed)).to eq(%w[a b c])
      a.move_left # il primo mostrato diventa l'ultimo
      expect(names(tabbed)).to eq(%w[b c a])
      a.move_right # l'ultimo diventa il primo mostrato
      expect(names(tabbed)).to eq(%w[a b c])
      tabbed.close
      solo = described_class.new(new_plane)
      tab = solo.add('solo')
      tab.move_left.move_right
      expect(names(solo)).to eq(%w[solo])
      solo.close
    end
  end

  describe '#redraw' do
    it 'chiama il blocco del tab selezionato con il piano del contenuto e scrive i nomi' do
      calls = []
      tabbed = described_class.new(new_plane, separator: '|')
      %w[Uno Due].each do |n|
        tabbed.add(n, after: tabbed.tabs.last) do |tab, content|
          calls << [tab.name, content.equal?(tabbed.content_plane)]
          draw.call(tab, content)
        end
      end
      tabbed.redraw
      expect(calls).to eq([['Uno', true]])
      expect(screen_row(0)).to eq('Uno|Due')
      expect(screen_row(1)).to eq('contenuto Uno')
      tabbed.next
      tabbed.redraw
      expect(screen_row(1)).to eq('contenuto Due')
      expect(calls.last).to eq(['Due', true])
      tabbed.close
    end

    it 'ensure_selected_header_visible fa scorrere l\'intestazione fino al tab selezionato' do
      tabbed = described_class.new(new_plane(rows: 3, cols: 10), separator: '|')
      tabs = %w[T1 T2 T3 T4 T5 T6].map { |n| tabbed.add(n, after: tabbed.tabs.last) }
      tabbed.redraw
      expect(screen_row(0, 12)).to eq('T1|T2|T3|T')
      tabbed.select(tabs.last)
      expect(tabbed.ensure_selected_header_visible).to equal(tabbed)
      expect(tabbed.leftmost.name).to eq('T3')
      tabbed.redraw
      expect(screen_row(0, 12)).to eq('T3|T4|T5|T')
      tabbed.close
    end

    it 'colori: valori iniziali, getter e setter' do
      tabbed = described_class.new(new_plane, selected_channels: Notcurses::Channels.new(value: 0x1234),
                                              header_channels: 0x5678, separator_channels: 0)
      expect(tabbed.selected_channels).to eq(Notcurses::Channels.new(value: 0x1234))
      expect(tabbed.header_channels.value).to eq(0x5678)
      expect(tabbed.separator_channels.value).to eq(0)
      tabbed.header_channels = Notcurses::Channels.rgb(255, 0, 0, 0, 0, 0)
      expect(tabbed.header_channels.fg_rgb).to eq([255, 0, 0])
      tabbed.selected_channels = 0
      expect(tabbed.selected_channels.value).to eq(0)
      tabbed.separator_channels = Notcurses::Channels.new(value: 0x9abc)
      expect(tabbed.separator_channels.value).to eq(0x9abc)
      expect { tabbed.header_channels = 'rosso' }.to raise_error(TypeError)
      expect { tabbed.separator_channels = -1 }.to raise_error(ArgumentError)
      tabbed.close
    end

    it 'separator e separator=' do
      tabbed = described_class.new(new_plane)
      expect(tabbed.separator).to be_nil
      expect(tabbed.separator_width).to eq(0)
      tabbed.separator = ' / '
      expect(tabbed.separator).to eq(' / ')
      expect(tabbed.separator.encoding).to eq(Encoding::UTF_8)
      expect(tabbed.separator_width).to eq(3)
      tabbed.add('a', &draw)
      tabbed.add('b', after: tabbed.tabs.last, &draw)
      tabbed.redraw
      expect(screen_row(0)).to eq('a / b')
      tabbed.separator = ''
      expect(tabbed.separator_width).to eq(0)
      expect { tabbed.separator = nil }.to raise_error(ArgumentError, /nil/)
      expect { tabbed.separator = "\t" }.to raise_error(ArgumentError, /controllo/)
      expect { tabbed.separator = 5 }.to raise_error(TypeError)
      expect(tabbed.separator).to eq('')
      tabbed.close
    end
  end

  describe 'blocchi dei tab' do
    it 'un\'eccezione del blocco esce da redraw e il widget resta coerente' do
      tabbed = described_class.new(new_plane)
      tab = tabbed.add('X') { |_tab, _content| raise ArgumentError, 'boom' }
      expect { tabbed.redraw }.to raise_error(ArgumentError, 'boom')
      expect(nc.callback_errors).to be_empty
      expect(screen_row(0)).to eq('X') # i nomi vengono scritti lo stesso
      expect(tabbed.tab_count).to eq(1)
      tab.callback = draw
      expect(tabbed.redraw).to equal(tabbed)
      expect(screen_row(1)).to eq('contenuto X')
      tabbed.close
    end

    it 'throw nel blocco non attraversa il C: LocalJumpError da redraw' do
      tabbed = described_class.new(new_plane)
      tabbed.add('X') { |_tab, _content| throw :fuori }
      expect { catch(:fuori) { tabbed.redraw } }.to raise_error(LocalJumpError)
      expect(nc.callback_errors).to be_empty
      tabbed.close
    end

    it 'dentro il blocco i metodi che cambiano il widget sollevano WidgetError, distruggere piani PlaneError' do
      tabbed = abc
      a, b, = tabbed.tabs
      other = new_plane
      errors = []
      seen = nil
      a.callback = lambda do |tab, content|
        seen = [tab.name, tabbed.tab_count, names(tabbed)]
        [-> { tabbed.add('x') }, -> { tabbed.next }, -> { tabbed.rotate(1) }, -> { tabbed.delete(b) },
         -> { tab.name = 'y' }, -> { tab.move_left }, -> { b.move(after: tab) }, -> { tab.callback = nil },
         -> { tabbed.separator = '-' }, -> { tabbed.header_channels = 0 }, -> { tabbed.close }].each do |call|
          call.call
        rescue Notcurses::WidgetError => e
          errors << e.class
        end
        [-> { other.close }, -> { content.close }].each do |call|
          call.call
        rescue Notcurses::PlaneError => e
          errors << e.class
        end
      end
      tabbed.redraw
      expect(seen).to eq(['a', 3, %w[a b c]])
      expect(errors).to eq(([Notcurses::WidgetError] * 11) + [Notcurses::PlaneError])
      expect(names(tabbed)).to eq(%w[a b c])
      expect(tabbed.selected).to equal(a)
      expect(other).not_to be_closed
      other.close
      tabbed.close
    end
  end

  describe 'ciclo di vita' do
    it 'close distrugge widget, tab, piano e discendenti; è idempotente; poi ClosedError' do
      tabbed = abc
      a, = tabbed.tabs
      plane = tabbed.plane
      content = tabbed.content_plane
      child = plane.create_child(rows: 1, cols: 1)
      grandchild = content.create_child(rows: 1, cols: 1)
      expect(tabbed.close).to be_nil
      expect(tabbed.close).to be_nil
      expect(tabbed.destroy).to be_nil
      expect(tabbed).to be_closed
      expect([plane, content, child, grandchild]).to all(be_closed)
      expect(a).to be_closed
      expect(tabbed.inspect).to include('chiuso')
      [-> { tabbed.redraw }, -> { tabbed.add('x') }, -> { tabbed.delete(a) }, -> { tabbed.selected },
       -> { tabbed.leftmost }, -> { tabbed.tab_count }, -> { tabbed.tabs }, -> { tabbed.select(a) },
       -> { tabbed.next }, -> { tabbed.prev }, -> { tabbed.rotate(1) },
       -> { tabbed.ensure_selected_header_visible }, -> { tabbed.plane }, -> { tabbed.content_plane },
       -> { tabbed.header_channels }, -> { tabbed.selected_channels }, -> { tabbed.separator_channels },
       -> { tabbed.header_channels = 0 }, -> { tabbed.selected_channels = 0 }, -> { tabbed.separator_channels = 0 },
       -> { tabbed.separator }, -> { tabbed.separator = '-' }, -> { tabbed.separator_width },
       -> { a.name }, -> { a.name = 'x' }, -> { a.name_width }, -> { a.next }, -> { a.prev },
       -> { a.callback = nil }, -> { a.move_left }, -> { a.move_right }].each do |call|
        expect { call.call }.to raise_error(Notcurses::ClosedError)
      end
    end

    it 'piano e contenuto appartengono al widget: Plane#close non fa nulla e un antenato non si distrugge' do
      parent = new_plane(rows: 8)
      plane = parent.create_child(rows: 4, cols: 10)
      tabbed = described_class.new(plane)
      expect(plane.close).to be_nil
      expect(tabbed.content_plane.close).to be_nil
      expect(plane).not_to be_closed
      expect(tabbed.content_plane).not_to be_closed
      expect { parent.family_destroy }.to raise_error(Notcurses::PlaneError, /widget/)
      tabbed.close
      parent.family_destroy
      expect(parent).to be_closed
    end

    it 'close rifiuta un discendente che è il piano di un altro widget aperto' do
      tabbed = described_class.new(new_plane(rows: 8))
      inner = described_class.new(tabbed.content_plane.create_child(rows: 3, cols: 10))
      expect { tabbed.close }.to raise_error(Notcurses::WidgetError, /discendente/)
      expect(tabbed).not_to be_closed
      expect(tabbed.tab_count).to eq(0)
      inner.close
      expect(tabbed.close).to be_nil
    end
  end
end

RSpec.describe Notcurses::Tabbed, 'con il contesto' do
  def open_tabbed(ctx)
    plane = ctx.stdplane.create_child(rows: 4, cols: 20)
    tabbed = described_class.new(plane, separator: '|')
    tab = tabbed.add('a') { |_tab, content| content.putstr('x', y: 0, x: 0) }
    tabbed.redraw
    [tabbed, tab, plane.create_child(rows: 1, cols: 1)]
  end

  it 'Context#close chiude un Tabbed aperto prima di notcurses_stop' do
    objs = nil
    NcHelpers.open_context { |ctx| objs = open_tabbed(ctx) }
    expect(objs).to all(be_closed)
    expect { objs.first.redraw }.to raise_error(Notcurses::ClosedError)
  end

  it 'Context#drop_planes chiude un Tabbed aperto e i suoi piani' do
    NcHelpers.open_context do |ctx|
      tabbed, tab, child = open_tabbed(ctx)
      plane = tabbed.plane
      ctx.drop_planes
      expect([tabbed, tab, child, plane]).to all(be_closed)
      ctx.render
    end
  end
end
