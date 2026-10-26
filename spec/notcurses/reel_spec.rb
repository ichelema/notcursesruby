# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative '../support/nc_helpers'

# Blocchi di disegno dei tablet.
module ReelSpecHelpers
  # Scrive "nome.riga" su lines righe ("^" se il tablet è sopra il fuoco).
  def writer(name, lines = 1, log = nil)
    lambda do |tablet, from_top|
      log&.push([name, from_top, tablet.plane.dims])
      lines.times { |r| tablet.plane.putstr("#{name}.#{r}#{from_top ? '' : '^'}", y: r, x: 0) }
      lines
    end
  end
end

RSpec.describe Notcurses::Reel do
  include_context 'con un contesto notcurses'
  include ReelSpecHelpers

  let(:std) { nc.stdplane }

  # un esempio fallito non lascia piani sullo schermo degli altri
  after { nc.drop_planes }

  def new_plane(rows: 12, cols: 16) = std.create_child(rows: rows, cols: cols)

  def new_reel(count = 0, lines: 1, rows: 12, **opts)
    reel = described_class.new(new_plane(rows: rows), **opts)
    (1..count).each { |i| reel.add(&writer("t#{i}", lines)) }
    reel
  end

  # Righe dello schermo dopo un render, con i bordi in ASCII.
  def screen(rows = 12, cols = 16)
    nc.render
    (0...rows).map do |y|
      (0...cols).map { |x| (e = nc.at(y, x)&.egc.to_s).empty? ? ' ' : e }.join.tr('╭╮╰╯│─', '++++|-')
    end
  end

  # Piani dati visibili: dentro il bordo del reel, senza sovrapposizioni, e
  # il tablet con il fuoco è disegnato.
  def check_layout!(reel)
    base = reel.plane.abs_y
    rows = reel.plane.dim_y
    spans = reel.tablets.filter_map { |t| t.plane && [t.plane.abs_y - base, t.plane.dim_y] }.sort
    spans.each_cons(2) { |(y1, r1), (y2, _)| expect(y1 + r1).to be < y2 }
    spans.each do |y, r|
      expect(y).to be >= 1
      expect(y + r).to be <= rows - 1
    end
    expect(reel.focused.plane).not_to be_nil
  end

  describe '.new' do
    it 'crea un reel vuoto con il bordo; il piano diventa del reel' do
      plane = new_plane(rows: 4, cols: 6)
      reel = described_class.new(plane)
      expect(reel.plane).to equal(plane)
      expect(reel.context).to equal(nc)
      expect(reel.to_ptr.address).to eq(plane.address)
      expect(plane).to be_widget_plane
      expect(reel.tablets).to eq([])
      expect(reel.tablet_count).to eq(0)
      expect(reel.size).to eq(0)
      expect(reel.focused).to be_nil
      expect(screen(4, 6)).to eq(['+----+', '|    |', '|    |', '+----+'])
      reel.close
    end

    it 'border_mask: e tablet_mask: accettano una maschera o un Array di lati' do
      reel = described_class.new(new_plane(rows: 4, cols: 6), border_mask: %i[top right bottom left],
                                                              tablet_mask: Notcurses::FFI::NCBOXMASK_TOP | 0xe)
      reel.add(&writer('a'))
      expect(screen(4, 6)).to eq(['a.0   ', '      ', '      ', '      '])
      reel.close
      reel = described_class.new(new_plane(rows: 5, cols: 6), border_mask: 0xf, tablet_mask: [:left, :right])
      reel.add(&writer('b'))
      expect(screen(5, 6)).to eq(['------', 'b.0   ', '------', '      ', '      '])
      reel.close
    end

    it 'valida gli argomenti e lascia il piano al chiamante' do
      plane = new_plane
      expect { described_class.new(plane, border_mask: 16) }.to raise_error(ArgumentError)
      expect { described_class.new(plane, tablet_mask: -1) }.to raise_error(ArgumentError)
      expect { described_class.new(plane, border_mask: [:alto]) }.to raise_error(ArgumentError, /lato/)
      expect { described_class.new(plane, border_mask: 'top') }.to raise_error(TypeError)
      expect { described_class.new(plane, focused_channels: 'giallo') }.to raise_error(TypeError)
      expect { described_class.new(plane, infinite_scroll: 1) }.to raise_error(TypeError)
      expect { described_class.new(plane, circular: true) }.to raise_error(ArgumentError, /infinite_scroll/)
      expect { described_class.new(:piano) }.to raise_error(TypeError)
      expect { described_class.new(std) }.to raise_error(Notcurses::WidgetError, /stdplane/)
      borrowed = Notcurses::Plane.new(plane.to_ptr, owned: false, context: nc, tracked: false)
      expect { described_class.new(borrowed) }.to raise_error(Notcurses::WidgetError, /prestito/)
      reel = described_class.new(new_plane)
      expect { described_class.new(reel.plane) }.to raise_error(Notcurses::WidgetError, /widget/)
      expect(plane).not_to be_closed
      expect(plane).not_to be_widget_plane
      reel.close
      plane.close
    end

    it 'open con un blocco chiude il reel e il piano' do
      plane = new_plane
      result = described_class.open(plane, infinite_scroll: true) do |reel|
        reel.add(&writer('x'))
        :fatto
      end
      expect(result).to eq(:fatto)
      expect(plane).to be_closed
    end
  end

  describe 'tablet' do
    it 'add: il primo prende il fuoco; senza after:/before: in fondo, altrimenti accanto (anche fra ultimo e primo)' do
      reel = new_reel
      t1 = reel.add(&writer('t1'))
      expect(reel.focused).to equal(t1)
      t2 = reel.add(&writer('t2'))
      t3 = reel.add(&writer('t3'))
      expect(reel.tablets).to eq([t1, t2, t3])
      t4 = reel.add(after: t1, &writer('t4'))
      t5 = reel.add(before: t1, &writer('t5'))
      expect(reel.tablets).to eq([t5, t1, t4, t2, t3])
      t6 = reel.add(after: t3, before: t5, &writer('t6'))
      t7 = reel.add(after: t1, before: t4, &writer('t7'))
      expect(reel.tablets).to eq([t5, t1, t7, t4, t2, t3, t6])
      expect(reel.tablet_count).to eq(7)
      expect(reel.focused).to equal(t1)
      expect(t7).to be_a(Notcurses::Tablet)
      expect(t7.inspect).to start_with('#<Notcurses::Tablet')
      reel.close
    end

    it 'add rifiuta argomenti non validi' do
      reel = new_reel(3)
      t1, _t2, t3 = reel.tablets
      other = new_reel(1)
      expect { reel.add }.to raise_error(ArgumentError, /blocco/)
      expect { reel.add(after: :t1) { 1 } }.to raise_error(TypeError)
      expect { reel.add(before: other.tablets.first) { 1 } }.to raise_error(ArgumentError, /non è un tablet aperto/)
      expect { reel.add(after: t1, before: t3) { 1 } }.to raise_error(ArgumentError, /subito dopo/)
      expect { reel.add(after: t1, before: t1) { 1 } }.to raise_error(ArgumentError, /subito dopo/)
      reel.delete(t3)
      expect { reel.add(after: t3) { 1 } }.to raise_error(ArgumentError, /non è un tablet aperto/)
      expect(reel.tablet_count).to eq(2)
      other.close
      reel.close
    end

    it 'il blocco riceve il tablet e draw_from_top, una volta per ridisegno; Tablet#plane è il piano dati' do
      log = []
      reel = new_reel
      tablets = (1..3).map { |i| reel.add(&writer("t#{i}", 1, log)) }
      log.clear
      reel.redraw
      expect(log).to eq([['t1', true, [8, 12]], ['t2', true, [8, 12]], ['t3', true, [8, 12]]])
      first_plane = tablets.first.plane
      expect(first_plane.dims).to eq([1, 12])
      expect(first_plane.contents).to eq('t1.0')
      reel.next
      log.clear
      reel.next
      expect(log).to eq([['t3', true, [8, 12]], ['t2', false, [8, 12]], ['t1', false, [8, 12]]])
      expect(first_plane).to be_closed # il piano vale fino al ridisegno successivo
      expect(tablets.first.plane).not_to be_nil
      reel.close
    end

    it 'le righe restituite sono ridotte allo spazio; 0 = nessun piano dati; un valore non Integer è un errore' do
      rows = { 'zero' => 0, 'tante' => 100, 'neg' => -5 }
      reel = new_reel(rows: 16)
      zero, tante, neg = rows.map do |name, n|
        reel.add do |tablet, _from_top|
          tablet.plane.putstr(name, y: 0, x: 0)
          n
        end
      end
      expect(zero.plane).to be_nil
      expect(screen(4)).to eq(['+--------------+', '|+------------+|', '|+------------+|', '|              |'])
      expect(reel.next).to equal(tante)
      expect(tante.plane.dim_y).to eq(12) # tutto lo spazio dati: 16 righe meno due bordi
      expect(reel.next).to equal(neg)
      expect(neg.plane).to be_nil
      expect { reel.add(before: neg) { :righe } }.to raise_error(TypeError, /Integer/)
      expect(reel.tablet_count).to eq(4)
      expect(reel.tablets.map(&:plane)).to all(be_nil)
      reel.delete(reel.tablets[2])
      expect(reel.prev).to equal(tante)
      expect(tante.plane.dim_y).to eq(12)
      reel.close
    end

    it 'senza bordi orizzontali un tablet con 0 righe occupa una riga vuota e il reel resta disegnabile' do
      [%i[top bottom], 0xf].each do |mask|
        reel = described_class.new(new_plane(rows: 6), tablet_mask: mask)
        one = reel.add { |tablet, _from_top| tablet.plane.putstr('a.0', y: 0, x: 0) && 1 }
        zero = reel.add { |_tablet, _from_top| 0 }
        expect(zero.plane).to be_nil
        expect(one.plane.contents).to eq('a.0')
        if mask == 0xf
          expect(screen(6)).to eq(['+--------------+', '|a.0           |', '|              |', '|              |',
                                   '|              |', '+--------------+'])
        end
        expect(reel.next).to equal(zero) # anche con il fuoco sul tablet alto 0
        expect(reel.redraw).to equal(reel)
        expect(one.plane.contents).to eq('a.0')
        expect(zero.plane).to be_nil
        reel.close
      end
    end

    it 'delete: il fuoco passa al successivo o, se era l\'ultimo, al precedente' do
      reel = new_reel(4)
      t1, t2, t3, t4 = reel.tablets
      other = new_reel(1)
      reel.next
      expect(reel.delete(t2)).to equal(reel)
      expect(reel.focused).to equal(t3)
      expect(t2).to be_closed
      expect { t2.plane }.to raise_error(Notcurses::ClosedError)
      reel.next
      reel.delete(t4)
      expect(reel.focused).to equal(t3)
      reel.delete(t1)
      expect(reel.focused).to equal(t3)
      expect(reel.tablets).to eq([t3])
      expect { reel.delete(t2) }.to raise_error(ArgumentError, /non è un tablet aperto/)
      expect { reel.delete(other.tablets.first) }.to raise_error(ArgumentError, /non è un tablet aperto/)
      expect { reel.delete(nil) }.to raise_error(TypeError)
      reel.delete(t3)
      expect(reel.focused).to be_nil
      expect(reel.tablet_count).to eq(0)
      other.close
      expect(screen(3)).to eq(['+--------------+', '|              |', '|              |'])
      reel.close
    end

    it 'next e prev si fermano alle estremità; con infinite_scroll: passano all\'altro capo' do
      reel = new_reel(3)
      t1, t2, t3 = reel.tablets
      expect([reel.next, reel.next, reel.next]).to eq([t2, t3, t3])
      expect([reel.prev, reel.prev, reel.prev]).to eq([t2, t1, t1])
      reel.close
      reel = new_reel(3, infinite_scroll: true)
      t1, _t2, t3 = reel.tablets
      expect(reel.prev).to equal(t3)
      expect(reel.next).to equal(t1)
      reel.close
      empty = new_reel
      expect(empty.next).to be_nil
      expect(empty.prev).to be_nil
      empty.close
    end

    it 'offer_input: frecce e rotella spostano il fuoco; false per i rilasci e gli altri tasti' do
      reel = new_reel(3)
      t1, t2, t3 = reel.tablets
      key = ->(id, **kw) { Notcurses::Input.synthesize(id, **kw) }
      expect(reel.offer_input(key.call(Notcurses::Key::DOWN))).to be(true)
      expect(reel.focused).to equal(t2)
      expect(reel.offer_input(key.call(Notcurses::Key::SCROLL_DOWN))).to be(true)
      expect(reel.focused).to equal(t3)
      expect(reel.offer_input(key.call(Notcurses::Key::UP))).to be(true)
      expect(reel.offer_input(key.call(Notcurses::Key::SCROLL_UP))).to be(true)
      expect(reel.focused).to equal(t1)
      expect(reel.offer_input(key.call(Notcurses::Key::DOWN, evtype: :release))).to be(false)
      expect(reel.offer_input(key.call(Notcurses::Key::PGDOWN))).to be(false)
      expect(reel.offer_input(key.call('j'.ord))).to be(false)
      expect(reel.focused).to equal(t1)
      expect { reel.offer_input(Notcurses::Key::DOWN) }.to raise_error(TypeError)
      reel.close
      empty = new_reel
      expect(empty.offer_input(key.call(Notcurses::Key::DOWN))).to be(true)
      empty.close
    end
  end

  describe 'disposizione' do
    it 'impila i tablet con una riga vuota fra l\'uno e l\'altro e taglia in basso quello che non entra' do
      reel = new_reel(3)
      expect(screen).to eq(['+--------------+',
                            '|+------------+|',
                            '||t1.0        ||',
                            '|+------------+|',
                            '|              |',
                            '|+------------+|',
                            '||t2.0        ||',
                            '|+------------+|',
                            '|              |',
                            '|+------------+|',
                            '||t3.0        ||',
                            '+--------------+'])
      reel.close
    end

    it 'il tablet che arriva da sotto si appoggia al bordo inferiore; il fuoco poi resta dove era' do
      reel = new_reel(5)
      4.times { reel.next }
      expect(screen).to eq(['+--------------+',
                            '||t3.0^       ||',
                            '|+------------+|',
                            '|              |',
                            '|+------------+|',
                            '||t4.0^       ||',
                            '|+------------+|',
                            '|              |',
                            '|+------------+|',
                            '||t5.0        ||',
                            '|+------------+|',
                            '+--------------+'])
      reel.prev
      expect(screen[5]).to eq('||t4.0        ||')
      expect(screen[9]).to eq('||t5.0        ||')
      reel.close
    end

    it 'un tablet tagliato in alto mostra le sue ultime righe' do
      reel = new_reel
      reel.add(&writer('a', 4))
      reel.add(&writer('b', 3))
      reel.next
      expect(screen[0..5]).to eq(['+--------------+', '||a.1^        ||', '||a.2^        ||', '||a.3^        ||',
                                  '|+------------+|', '|              |'])
      reel.close
    end

    it 'circular: true dispone anche il disegno in cerchio' do
      reel = new_reel(5, infinite_scroll: true, circular: true)
      expect(reel.prev).to equal(reel.tablets.last)
      expect(screen.values_at(2, 6, 10)).to eq(['||t5.0        ||', '||t1.0        ||', '||t2.0        ||'])
      reel.close
    end

    it 'il bordo del tablet con il fuoco usa focused_channels, gli altri tablet_channels' do
      yellow = Notcurses::Channels.rgb(255, 255, 0, 0, 0, 0)
      blue = Notcurses::Channels.rgb(0, 0, 255, 0, 0, 0)
      reel = new_reel(2, focused_channels: yellow, tablet_channels: blue)
      nc.render
      expect(nc.at(1, 1).channels.fg_rgb).to eq([255, 255, 0])
      expect(nc.at(5, 1).channels.fg_rgb).to eq([0, 0, 255])
      reel.next
      nc.render
      expect(nc.at(1, 1).channels.fg_rgb).to eq([0, 0, 255])
      reel.close
    end

    it 'la sequenza di exp9b (5 tablet in 12 righe, molti next e prev) non va in crash e la disposizione resta valida' do
      [{}, { infinite_scroll: true }, { infinite_scroll: true, circular: true }].each do |opts|
        reel = described_class.new(new_plane, **opts)
        [1, 2, 3, 1, 2].each_with_index { |lines, i| reel.add(&writer("t#{i + 1}", lines)) }
        steps = (%i[next] * 30) + (%i[prev] * 30) + (%i[next prev next next prev] * 6)
        steps.each do |step|
          step == :next ? reel.next : reel.prev
          check_layout!(reel)
        end
        reel.delete(reel.focused)
        check_layout!(reel)
        reel.close
      end
    end

    it 'dopo un resize del piano il ridisegno usa le nuove dimensioni' do
      reel = new_reel(3)
      reel.plane.resize(6, 16)
      reel.redraw
      check_layout!(reel)
      expect(screen(6)).to eq(['+--------------+', '|+------------+|', '||t1.0        ||', '|+------------+|',
                               '|              |', '+--------------+'])
      reel.plane.resize(2, 16)
      expect(reel.redraw).to equal(reel)
      expect(reel.tablets.map(&:plane)).to all(be_nil)
      reel.close
    end
  end

  describe 'blocchi dei tablet' do
    it 'un\'eccezione del blocco esce dal metodo che ha avviato il disegno e il reel resta coerente' do
      fail = false
      reel = new_reel(2)
      bad = reel.add do |tablet, _from_top|
        raise ArgumentError, 'boom' if fail

        tablet.plane.putstr('ok', y: 0, x: 0)
        1
      end
      fail = true
      expect { reel.redraw }.to raise_error(ArgumentError, 'boom')
      expect(reel.tablets.map(&:plane)).to all(be_nil)
      expect { reel.next }.to raise_error(ArgumentError, 'boom')
      expect(reel.tablet_count).to eq(3)
      fail = false
      expect(reel.redraw).to equal(reel)
      check_layout!(reel)
      expect(bad.plane.contents).to eq('ok')
      expect { reel.add(before: reel.tablets[1]) { raise 'nel primo disegno' } }
        .to raise_error(RuntimeError, 'nel primo disegno')
      expect(reel.tablet_count).to eq(4)
      reel.delete(reel.tablets[1])
      check_layout!(reel)
      reel.close
    end

    it 'il blocco riceve subito l\'eccezione di un callback di resize che ha causato' do
      parent = std.create_child(rows: 5, cols: 5)
      parent.create_child(rows: 1, cols: 1, resize: ->(_) { raise 'figlio fallisce' })
      reel = described_class.new(new_plane)
      expect { reel.add { |_tablet, _from_top| parent.resize(6, 6); 1 } }.to raise_error(RuntimeError, 'figlio fallisce')
      expect(nc.callback_errors).to be_empty
      reel.close
      parent.family_destroy
    end

    it 'dentro il blocco i metodi che cambiano il reel sollevano WidgetError, distruggere piani PlaneError' do
      reel = new_reel(2)
      t1, t2 = reel.tablets
      other = new_plane
      errors = []
      seen = nil
      down = Notcurses::Input.synthesize(Notcurses::Key::DOWN)
      reel.add do |tablet, _from_top|
        seen ||= [reel.tablet_count, reel.focused.equal?(t1), reel.tablets.size]
        if errors.empty?
          [-> { reel.add { 1 } }, -> { reel.delete(t2) }, -> { reel.next }, -> { reel.prev }, -> { reel.redraw },
           -> { reel.offer_input(down) }, -> { reel.close }].each do |call|
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
        tablet.plane.putstr('x', y: 0, x: 0)
        1
      end
      expect(seen).to eq([3, true, 3])
      expect(errors).to eq(([Notcurses::WidgetError] * 7) + [Notcurses::PlaneError])
      expect(reel.tablets).to eq([t1, t2, reel.tablets.last])
      expect(other).not_to be_closed
      check_layout!(reel)
      other.close
      reel.close
    end
  end

  describe 'ciclo di vita' do
    it 'close distrugge i piani dei tablet e il piano; è idempotente; poi ClosedError' do
      reel = new_reel(3)
      tablet = reel.focused
      plane = reel.plane
      data = tablet.plane
      child = plane.create_child(rows: 1, cols: 1)
      expect(reel.close).to be_nil
      expect(reel.close).to be_nil
      expect(reel.destroy).to be_nil
      expect(reel).to be_closed
      expect(plane).to be_closed
      expect(data).to be_closed
      expect(tablet).to be_closed
      expect(tablet.inspect).to include('chiuso')
      expect(reel.inspect).to include('chiuso')
      expect(child).not_to be_closed # i figli dell'utente passano al genitore
      child.close
      [-> { reel.add { 1 } }, -> { reel.delete(tablet) }, -> { reel.redraw }, -> { reel.next }, -> { reel.prev },
       -> { reel.offer_input(Notcurses::Input.synthesize(Notcurses::Key::DOWN)) }, -> { reel.focused },
       -> { reel.tablets }, -> { reel.tablet_count }, -> { reel.size }, -> { reel.plane }, -> { reel.to_ptr },
       -> { tablet.plane }].each do |call|
        expect { call.call }.to raise_error(Notcurses::ClosedError)
      end
    end

    it 'il piano appartiene al reel: Plane#close non fa nulla e un antenato non si distrugge' do
      parent = new_plane(rows: 14)
      plane = parent.create_child(rows: 12, cols: 16)
      reel = described_class.new(plane)
      reel.add(&writer('a'))
      expect(plane.close).to be_nil
      expect(reel.focused.plane.close).to be_nil
      expect(plane).not_to be_closed
      expect { parent.family_destroy }.to raise_error(Notcurses::PlaneError, /widget/)
      reel.close
      parent.family_destroy
      expect(parent).to be_closed
    end

    it 'redraw, delete e close rifiutano un widget aperto su un piano di un tablet' do
      reel = new_reel(1)
      hosted = nil
      reel.add do |tablet, _from_top|
        hosted ||= Notcurses::Tabbed.new(tablet.plane.create_child(rows: 2, cols: 5))
        1
      end
      expect { reel.redraw }.to raise_error(Notcurses::WidgetError, /ospita/)
      expect { reel.delete(reel.tablets.last) }.to raise_error(Notcurses::WidgetError, /ospita/)
      expect { reel.close }.to raise_error(Notcurses::WidgetError, /ospita/)
      expect(reel).not_to be_closed
      expect(hosted).not_to be_closed
      hosted.close
      expect(reel.redraw).to equal(reel)
      expect(reel.close).to be_nil
    end
  end
end

RSpec.describe Notcurses::Reel, 'con il contesto' do
  include ReelSpecHelpers

  def open_reel(ctx)
    reel = described_class.new(ctx.stdplane.create_child(rows: 12, cols: 16), infinite_scroll: true)
    3.times { |i| reel.add(&writer("t#{i}")) }
    reel.next
    reel
  end

  it 'Context#close chiude un reel aperto prima di notcurses_stop' do
    reel = nil
    tablets = nil
    NcHelpers.open_context do |ctx|
      reel = open_reel(ctx)
      tablets = reel.tablets
    end
    expect(reel).to be_closed
    expect(tablets).to all(be_closed)
    expect { reel.next }.to raise_error(Notcurses::ClosedError)
  end

  it 'Context#drop_planes chiude un reel aperto e i piani dei tablet' do
    NcHelpers.open_context do |ctx|
      reel = open_reel(ctx)
      plane = reel.plane
      data = reel.focused.plane
      ctx.drop_planes
      expect([reel, plane, data]).to all(be_closed)
      ctx.render
    end
  end
end
