# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require_relative '../support/nc_helpers'

RSpec.describe Notcurses::MultiSelector do
  let(:key) { Notcurses::Key }
  let(:space) { ev(' '.ord) }

  def ev(id, **opts) = Notcurses::Input.synthesize(id, **opts)

  describe 'con un contesto aperto' do
    include_context 'con un contesto notcurses'

    let(:std) { nc.stdplane }

    def new_plane(rows: 1, cols: 1, y: 1, x: 1, parent: std) = parent.create_child(rows: rows, cols: cols, y: y, x: x)

    it 'new prende possesso del piano e lo ridimensiona' do
      plane = new_plane
      before = nc.stats.planes
      ms = described_class.new(plane, items: [['a', 'uno', true], ['b'], 'c'], title: 'T', secondary: 's', footer: 'f')
      expect(ms.plane).to equal(plane)
      expect(plane).to be_widget_plane
      expect(plane.dims).to eq([9, 11]) # 2 (titolo) + 4 + 3 voci; "a" + "uno" + 7 colonne
      expect(ms.selected).to eq([true, false, false])
      expect(nc.stats.planes).to eq(before)
      ms.close
      expect(nc.stats.planes).to eq(before - 1)
    end

    it 'accetta voci come String, Array da 1 a 3 elementi e Hash' do
      described_class.open(new_plane, items: ['a', ['b'], ['c', nil], ['d', 'quattro', true]]) do |ms|
        expect(ms.selected).to eq([false, false, false, true])
      end
      described_class.open(new_plane, items: { 'x' => 'ics', 'y' => nil }) do |ms|
        expect(ms.selected).to eq([false, false])
      end
    end

    it 'selected restituisce anche lo stato della voce 0, che il C non scrive' do
      described_class.open(new_plane, items: [['a', '', true], ['b', '', true]]) do |ms|
        expect(ms.selected).to eq([true, true])
        expect(ms.offer_input(space)).to be true
        expect(ms.selected).to eq([false, true])
        expect(ms.offer_input(ev(key::DOWN))).to be true
        expect(ms.offer_input(space)).to be true
        expect(ms.selected).to eq([false, false])
        expect(ms.offer_input(ev(key::UP))).to be true
        expect(ms.offer_input(space)).to be true
        expect(ms.selected).to eq([true, false])
      end
      described_class.open(new_plane, items: ['solo']) do |ms|
        expect(ms.selected).to eq([false])
        ms.offer_input(space)
        expect(ms.selected).to eq([true])
        ms.offer_input(ev(' '.ord, modifiers: [:shift])) # il C commuta con qualunque modificatore
        expect(ms.selected).to eq([false])
      end
    end

    it 'lo stato coincide con un modello Ruby dopo una sequenza casuale di tasti' do
      rng = Random.new(1234)
      described_class.open(new_plane, items: %w[a b c d e]) do |ms|
        model = [false] * 5
        current = 0
        200.times do
          case rng.rand(4)
          when 0
            ms.offer_input(ev(key::DOWN))
            current = (current + 1) % 5
          when 1
            ms.offer_input(ev(key::UP))
            current = (current - 1) % 5
          else
            ms.offer_input(space)
            model[current] = !model[current]
          end
        end
        expect(ms.selected).to eq(model)
      end
    end

    it 'offer_input: navigazione, pagine, rotella e clic; non consuma Invio, rilasci ed eventi vuoti' do
      described_class.open(new_plane(y: 2, x: 2), items: %w[a b c d e], max_display: 2) do |ms|
        expect(ms.offer_input(ev(key::PGDOWN))).to be true # una pagina = 2 voci
        expect(ms.offer_input(space)).to be true
        expect(ms.selected).to eq([false, false, true, false, false])
        expect(ms.offer_input(ev(key::PGUP))).to be true
        expect(ms.offer_input(ev(key::SCROLL_DOWN))).to be true
        expect(ms.offer_input(ev(key::SCROLL_UP))).to be true
        expect(ms.offer_input(space)).to be true
        expect(ms.selected).to eq([true, false, true, false, false])
        expect(ms.offer_input(ev(key::ENTER))).to be false
        expect(ms.offer_input(ev(' '.ord, evtype: :release))).to be false
        expect(ms.offer_input(ev(0))).to be false
        expect(ms.offer_input(ev(0xffff_ffff))).to be false
        y, x = ms.plane.abs_yx
        # senza titolo: riga 1 freccia su, voci dalla riga 2; il clic sposta la voce corrente
        expect(ms.offer_input(ev(key::BUTTON1, evtype: :release, y: y + 3, x: x + 4))).to be true
        expect(ms.offer_input(space)).to be true
        expect(ms.selected).to eq([true, true, true, false, false])
        expect(ms.offer_input(ev(key::BUTTON1, evtype: :release, y: 0, x: 0))).to be false
        expect { ms.offer_input('a') }.to raise_error(TypeError)
      end
    end

    it 'rifiuta items vuoto o non valido prima della chiamata C' do
      plane = new_plane
      expect { described_class.new(plane) }.to raise_error(ArgumentError, /items/)
      expect { described_class.new(plane, items: []) }.to raise_error(ArgumentError, /almeno una voce/)
      expect { described_class.new(plane, items: 'a') }.to raise_error(TypeError)
      expect { described_class.new(plane, items: [[]]) }.to raise_error(TypeError)
      expect { described_class.new(plane, items: [['a', 'b', true, 4]]) }.to raise_error(TypeError)
      expect { described_class.new(plane, items: [['a', 'b', 'sì']]) }.to raise_error(TypeError)
      expect { described_class.new(plane, items: [["a\n"]]) }.to raise_error(ArgumentError, /controllo/)
      expect { described_class.new(plane, items: ['a'], title: "\t") }.to raise_error(ArgumentError)
      expect { described_class.new(plane, items: ['a'], max_display: 2**32) }.to raise_error(ArgumentError)
      expect { described_class.new(plane, items: ['a'], desc_channels: :blu) }.to raise_error(TypeError)
      expect(plane).to be_owned
      plane.close
    end

    it 'un genitore troppo piccolo dà WidgetError senza distruggere il piano' do
      short = new_plane(rows: 6, cols: 40)
      plane = new_plane(parent: short, y: 0, x: 0)
      expect { described_class.new(plane, items: ['a'], title: 'T') }.to raise_error(Notcurses::WidgetError, /7 righe/)
      narrow = new_plane(rows: 10, cols: 9)
      wide = new_plane(parent: narrow, y: 0, x: 0)
      expect { described_class.new(wide, items: [%w[abc def]]) }.to raise_error(Notcurses::WidgetError, /13 colonne/)
      expect([plane, wide]).to all(be_owned)
      described_class.open(plane, items: ['a']) { |ms| expect(ms.plane.dim_y).to eq(5) }
      short.family_destroy
      narrow.family_destroy
    end

    it "rifiuta lo stdplane e il piano di un altro widget" do
      expect { described_class.new(std, items: ['a']) }.to raise_error(Notcurses::WidgetError, /stdplane/)
      described_class.open(new_plane, items: ['a']) do |ms|
        expect { described_class.new(ms.plane, items: ['b']) }.to raise_error(Notcurses::WidgetError, /widget/)
        expect(ms.selected).to eq([false])
      end
    end

    it 'close distrugge widget e piano, è idempotente e poi i metodi sollevano ClosedError' do
      plane = new_plane
      ms = described_class.new(plane, items: %w[a b])
      expect(ms.close).to be_nil
      expect(ms).to be_closed
      expect(plane).to be_closed
      expect(ms.destroy).to be_nil
      expect { ms.selected }.to raise_error(Notcurses::ClosedError)
      expect { ms.offer_input(space) }.to raise_error(Notcurses::ClosedError)
      expect { ms.plane }.to raise_error(Notcurses::ClosedError)
    end

    it 'open con un blocco restituisce il valore del blocco e chiude il widget' do
      kept = nil
      result = described_class.open(new_plane, items: [['a', '', true]]) do |ms|
        kept = ms
        ms.selected
      end
      expect(result).to eq([true])
      expect(kept).to be_closed
    end

    it 'non si crea dentro un callback chiamato da notcurses' do
      parent = new_plane(rows: 3, cols: 3)
      target = new_plane
      parent.create_child(rows: 1, cols: 1, resize: ->(_p) { described_class.new(target, items: ['a']) })
      expect { parent.resize(4, 4) }.to raise_error(Notcurses::WidgetError, /callback/)
      parent.family_destroy
      target.close
    end

    it 'offer_input con il piano di una riga solleva WidgetError senza chiamare il C' do
      ms = described_class.new(new_plane, items: %w[a b c])
      ms.plane.resize(1, ms.plane.dim_x)
      expect(Notcurses::FFI).not_to receive(:ncmultiselector_offer_input)
      expect { ms.offer_input(ev(key::DOWN)) }.to raise_error(Notcurses::WidgetError, /2 righe/)
      expect { ms.offer_input(space) }.to raise_error(Notcurses::WidgetError, /2 righe/)
      expect(ms.selected).to eq([false, false, false])
      ms.close
    end

    it 'offer_input con il piano di una riga non blocca il processo (prima: circa 2^32 giri nel C)' do
      script = <<~'RUBY'
        require 'notcurses'
        $stdout.sync = true
        ev = ->(id) { Notcurses::Input.synthesize(id) }
        Notcurses::Context.open(output: '/dev/null', termtype: 'xterm-256color', suppress_banners: true) do |nc|
          ms = Notcurses::MultiSelector.new(nc.stdplane.create_child(rows: 1, cols: 1), items: %w[a b c])
          ms.plane.resize(1, ms.plane.dim_x)
          begin
            ms.offer_input(ev.(Notcurses::Key::DOWN))
          rescue Notcurses::WidgetError
            puts 'WidgetError'
          end
          ms.plane.resize(2, ms.plane.dim_x)
          down = ms.offer_input(ev.(Notcurses::Key::DOWN))
          ms.offer_input(ev.(' '.ord))
          puts(down == true && ms.selected == [false, true, false] ? 'ok' : "down=#{down} #{ms.selected}")
          ms.close
        end
      RUBY
      lib = File.expand_path('../../lib', __dir__)
      out, status = Open3.capture2e({ 'TERM' => 'xterm-256color' }, 'timeout', '-k', '5', '-s', 'KILL', '30',
                                    RbConfig.ruby, '-I', lib, '-e', script, stdin_data: '')
      expect([status.exitstatus, out]).to eq([0, "WidgetError\nok\n"])
    end
  end

  describe 'chiusura da parte del contesto' do
    it 'Context#close chiude il widget aperto' do
      ms = plane = nil
      NcHelpers.open_context do |nc|
        plane = nc.stdplane.create_child(rows: 1, cols: 1)
        ms = described_class.new(plane, items: %w[a b])
      end
      expect([ms, plane]).to all(be_closed)
      expect(ms.close).to be_nil
    end

    it 'Context#drop_planes chiude il widget aperto' do
      NcHelpers.open_context do |nc|
        plane = nc.stdplane.create_child(rows: 1, cols: 1)
        ms = described_class.new(plane, items: %w[a])
        nc.drop_planes
        expect([ms, plane]).to all(be_closed)
        expect(nc.stats.planes).to eq(1)
      end
    end
  end
end
