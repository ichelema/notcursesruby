# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require_relative '../support/nc_helpers'

# Ciclo di vita degli oggetti del wrapper insieme: contesto, piani, pile,
# visual, fotografie dei fade, GC, contesti esclusivi, uscita del processo.
RSpec.describe 'Ciclo di vita (integrazione)' do
  LIB = File.expand_path('../../lib', __dir__)

  # Piani della pila di plane, contati con la navigazione dello z-order.
  def pile_count(plane)
    count = 0
    cur = plane.pile_top
    while cur
      count += 1
      cur = cur.below
    end
    count
  end

  def rgba_visual
    Notcurses::Visual.from_rgba(([255, 0, 0, 255] * 4).pack('C*'), rows: 2, cols: 2)
  end

  it 'Context.open con un blocco chiude il contesto e invalida piani, pile e visual, anche dopo un\'eccezione' do
    kept = {}
    expect do
      NcHelpers.open_context do |nc|
        kept[:child] = nc.stdplane.create_child(rows: 2, cols: 2)
        kept[:grandchild] = kept[:child].create_child(rows: 1, cols: 1)
        kept[:pile] = nc.create_pile(rows: 2, cols: 2)
        kept[:borrowed] = kept[:grandchild].pile_top
        kept[:visual] = rgba_visual
        kept[:std] = nc.stdplane
        raise 'boom'
      end
    end.to raise_error(RuntimeError, 'boom')
    kept.each do |name, obj|
      expect(obj).to be_closed, "#{name} dovrebbe essere chiuso"
    end
    expect { kept[:child].dims }.to raise_error(Notcurses::ClosedError)
    expect(Notcurses.active_context).to be_nil
  end

  it 'drop_planes distrugge i piani di tutte le pile tranne lo stdplane' do
    NcHelpers.open_context do |nc|
      std = nc.stdplane
      before = pile_count(std)
      a = std.create_child(rows: 1, cols: 1)
      b = a.create_child(rows: 1, cols: 1)
      pile = nc.create_pile(rows: 1, cols: 1)
      pile.create_child(rows: 1, cols: 1)
      expect(pile_count(std)).to eq(before + 2)
      expect(nc.drop_planes).to equal(nc)
      expect([a, b, pile]).to all(be_closed)
      expect(std).not_to be_closed
      expect(pile_count(std)).to eq(1)
      expect(std.create_child(rows: 1, cols: 1)).not_to be_closed
    end
  end

  it 'drop_planes e close chiudono tutti i figli anche se un close solleva, poi rilanciano l\'eccezione' do
    failing = Struct.new(:ctx) do
      def close
        ctx.disown(self)
        raise SystemExit, 'uscita salvata dal blocco di un figlio'
      end
    end
    NcHelpers.open_context do |nc|
      bar = Notcurses::ProgBar.new(nc.stdplane.create_child(rows: 1, cols: 10))
      nc.adopt(failing.new(nc)) # adottato dopo: si chiude per primo
      expect { nc.drop_planes }.to raise_error(SystemExit)
      expect(bar).to be_closed
      bar = Notcurses::ProgBar.new(nc.stdplane.create_child(rows: 1, cols: 10))
      nc.adopt(failing.new(nc))
      expect { nc.close }.to raise_error(SystemExit)
      expect(bar).to be_closed
      expect(nc).to be_closed
      expect(Notcurses.active_context).to be_nil
    end
  end

  it 'il GC non distrugge i piani: restano nel C finché li distrugge il contesto' do
    NcHelpers.open_context do |nc|
      std = nc.stdplane
      before = pile_count(std)
      10.times { std.create_child(rows: 1, cols: 1) }
      GC.start(full_mark: true, immediate_sweep: true)
      expect(pile_count(std)).to eq(before + 10)
      nc.drop_planes
      expect(pile_count(std)).to eq(1)
    end
  end

  it 'Context e Direct si escludono a vicenda' do
    NcHelpers.open_context do
      expect { Notcurses::Direct.new(output: '/dev/null', termtype: 'xterm-256color') }
        .to raise_error(Notcurses::InitError, /già attivo/)
    end
    Notcurses::Direct.open(output: '/dev/null', termtype: 'xterm-256color', drain_input: true) do
      expect { NcHelpers.open_context }.to raise_error(Notcurses::InitError, /già attivo/)
    end
    NcHelpers.open_context { |nc| expect(nc).not_to be_closed }
  end

  it 'le risorse chiuse sollevano ClosedError e close è idempotente' do
    NcHelpers.open_context do |nc|
      plane = nc.stdplane.create_child(rows: 1, cols: 3)
      plane.putstr('abc', y: 0, x: 0)
      resources = [plane.fade_context, rgba_visual, nc.palette, plane]
      resources.each do |res|
        expect(res.close).to be_nil
        expect(res.close).to be_nil
        expect(res).to be_closed
        expect { res.to_ptr }.to raise_error(Notcurses::ClosedError)
      end
    end
  end

  it 'dentro un callback di resize non si distruggono piani: l\'errore esce dal resize' do
    NcHelpers.open_context do |nc|
      parent = nc.stdplane.create_child(rows: 4, cols: 4)
      victim = parent.create_child(rows: 1, cols: 1)
      child = parent.create_child(rows: 2, cols: 2, resize: ->(_plane) { victim.close })
      expect { parent.resize(5, 5) }.to raise_error(Notcurses::PlaneError, /callback/)
      expect(victim).not_to be_closed
      expect(child).not_to be_closed
      victim.close
      expect(victim).to be_closed
    end
  end

  it 'un contesto lasciato aperto viene chiuso all\'uscita del processo' do
    # gli hook at_exit girano in ordine inverso: questo, registrato prima del
    # require, gira dopo quello del wrapper
    script = <<~RUBY
      at_exit { warn($nc.closed? ? 'chiuso' : 'aperto') }
      require 'notcurses'
      $nc = Notcurses::Context.new(output: '/dev/null', termtype: 'xterm-256color', suppress_banners: true)
      $nc.stdplane.create_child(rows: 1, cols: 1)
    RUBY
    out, status = Open3.capture2e({ 'TERM' => 'xterm-256color' }, RbConfig.ruby, '-I', LIB, '-e', script, stdin_data: '')
    expect(status).to be_success
    expect(out).to include('chiuso')
  end
end
