# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require 'open3'
require_relative '../support/nc_helpers'

RSpec.describe Notcurses::ProgBar do
  def cell(plane, y, x) = Notcurses::Util.take_string(Notcurses::FFI.ncplane_at_yx(plane.to_ptr, y, x, nil, nil))

  # Celle lungo la barra: la riga 0 se orizzontale, la colonna 0 se verticale.
  def cells(plane)
    rows, cols = plane.dims
    cols > rows ? (0...cols).map { |x| cell(plane, 0, x) } : (0...rows).map { |y| cell(plane, y, 0) }
  end

  # Celle piene (il gradiente disegna mezzi blocchi) lungo la barra.
  def filled(plane) = cells(plane).map { |c| c == '▀' }

  describe 'con un contesto aperto' do
    include_context 'con un contesto notcurses'

    let(:std) { nc.stdplane }

    def new_plane(rows, cols) = std.create_child(rows: rows, cols: cols, y: 1, x: 1)

    it 'new prende possesso del piano senza disegnare; progress parte da 0.0' do
      plane = new_plane(1, 10)
      before = nc.stats.planes
      bar = described_class.new(plane)
      expect(bar.plane).to equal(plane)
      expect(plane).to be_widget_plane
      expect(bar.progress).to eq(0.0) # il C non inizializza il valore
      expect(cells(plane)).to all(eq(''))
      expect(nc.stats.planes).to eq(before)
      bar.close
      expect(nc.stats.planes).to eq(before - 1)
    end

    it 'progress= disegna una barra orizzontale da sinistra (al contrario con retrograde)' do
      described_class.open(new_plane(1, 10)) do |bar|
        bar.progress = 0.5
        expect(bar.progress).to eq(0.5)
        expect(filled(bar.plane)).to eq([true] * 5 + [false] * 5)
        bar.progress = 1
        expect(filled(bar.plane)).to all(be true)
        bar.progress = 0
        expect(filled(bar.plane)).to all(be false)
      end
      described_class.open(new_plane(1, 10), retrograde: true) do |bar|
        bar.progress = 0.3
        expect(filled(bar.plane)).to eq([false] * 7 + [true] * 3)
      end
    end

    it 'su un piano con più righe che colonne la barra è verticale, dal basso (dall\'alto con retrograde)' do
      described_class.open(new_plane(10, 1)) do |bar|
        bar.progress = 0.5
        expect(filled(bar.plane)).to eq([false] * 5 + [true] * 5)
      end
      described_class.open(new_plane(10, 1), retrograde: true) do |bar|
        bar.progress = 0.2
        expect(filled(bar.plane)).to eq([true] * 2 + [false] * 8)
      end
    end

    it "l'orientamento segue le dimensioni correnti del piano (orizzontale se cols > rows)" do
      described_class.open(new_plane(20, 30)) do |bar|
        bar.progress = 0.5
        expect(cell(bar.plane, 0, 0)).to eq('▀')
        expect(cell(bar.plane, 19, 29)).to eq('')
        bar.plane.resize(30, 20)
        bar.progress = 0.5
        expect(cell(bar.plane, 29, 0)).to eq('▀')
        expect(cell(bar.plane, 0, 0)).to eq('')
      end
    end

    it 'progress= aggira il glifo di bordo fuori dall\'array (0.8333333333333333 su 18 celle)' do
      value = 0.8333333333333333
      [[1, 18, false], [1, 18, true], [18, 1, false], [18, 1, true]].each do |rows, cols, retro|
        described_class.open(new_plane(rows, cols), retrograde: retro) do |bar|
          expect { bar.progress = value }.not_to raise_error # il C restituirebbe -1 a barra disegnata a metà
          expect(bar.progress).to be_within(1e-14).of(value)
          expect(filled(bar.plane).count(true)).to eq(14)
        end
      end
    end

    it 'progress= rifiuta NaN, infiniti, valori fuori da 0..1 e non numerici; il valore precedente resta' do
      described_class.open(new_plane(1, 10)) do |bar|
        bar.progress = 0.25
        expect { bar.progress = Float::NAN }.to raise_error(ArgumentError, /finito/)
        expect { bar.progress = Float::INFINITY }.to raise_error(ArgumentError)
        expect { bar.progress = 1.5 }.to raise_error(ArgumentError)
        expect { bar.progress = -0.1 }.to raise_error(ArgumentError)
        expect { bar.progress = '0.5' }.to raise_error(TypeError)
        expect { bar.progress = Complex(0.5, 1) }.to raise_error(TypeError)
        expect(bar.progress).to eq(0.25)
        bar.progress = Rational(3, 4)
        expect(bar.progress).to eq(0.75)
      end
    end

    it 'con i colori dei quattro angoli come Channel o Integer' do
      green = Notcurses::Channel.rgb(0, 255, 0)
      described_class.open(new_plane(1, 4), ul_channel: green, ur_channel: green.value,
                                            bl_channel: Notcurses::Channel.rgb(0, 80, 0), br_channel: green) do |bar|
        bar.progress = 1
        expect(filled(bar.plane)).to all(be true)
      end
    end

    it 'colori incoerenti per il gradiente: progress= solleva WidgetError' do
      described_class.open(new_plane(1, 4), ul_channel: Notcurses::Channel.palindex(3)) do |bar|
        expect { bar.progress = 0.5 }.to raise_error(Notcurses::WidgetError, /ncprogbar_set_progress/)
        expect(bar.progress).to eq(0.5)
      end
    end

    # Regola di 3.0.17 documentata, non aggirata (fill.c:192-197): fallisce se un notcurses nuovo la cambia.
    it 'su un piano largo una colonna sinistra e destra devono avere gli stessi colori' do
      dark = Notcurses::Channel.rgb(0, 80, 0)
      light = Notcurses::Channel.rgb(0, 255, 0)
      [[5, 1], [1, 1]].each do |rows, cols|
        described_class.open(new_plane(rows, cols), ul_channel: dark, ur_channel: light,
                                                    bl_channel: dark, br_channel: light) do |bar|
          expect { bar.progress = 0.5 }.to raise_error(Notcurses::WidgetError, /ncprogbar_set_progress/)
        end
        described_class.open(new_plane(rows, cols), ul_channel: dark, ur_channel: dark,
                                                    bl_channel: light, br_channel: light) do |bar|
          bar.progress = 1
          expect(filled(bar.plane)).to all(be true)
        end
      end
    end

    it 'valida gli argomenti e rifiuta lo stdplane e il piano di un altro widget' do
      plane = new_plane(1, 4)
      expect { described_class.new('piano') }.to raise_error(TypeError)
      expect { described_class.new(plane, ul_channel: Notcurses::Channels.new) }.to raise_error(TypeError)
      expect { described_class.new(plane, br_channel: 2**32) }.to raise_error(ArgumentError)
      expect { described_class.new(plane, retrograde: :si) }.to raise_error(TypeError)
      expect { described_class.new(std) }.to raise_error(Notcurses::WidgetError, /stdplane/)
      described_class.open(plane) do |bar|
        expect { described_class.new(bar.plane) }.to raise_error(Notcurses::WidgetError, /widget/)
        bar.progress = 0.5
      end
    end

    it 'close distrugge widget e piano, è idempotente e poi i metodi sollevano ClosedError' do
      plane = new_plane(1, 4)
      bar = described_class.new(plane)
      expect(bar.close).to be_nil
      expect([bar, plane]).to all(be_closed)
      expect(bar.destroy).to be_nil
      expect { bar.progress }.to raise_error(Notcurses::ClosedError)
      expect { bar.progress = 0.5 }.to raise_error(Notcurses::ClosedError)
      expect { bar.plane }.to raise_error(Notcurses::ClosedError)
    end

    it 'open con un blocco restituisce il valore del blocco e chiude la barra' do
      kept = nil
      result = described_class.open(new_plane(1, 4)) do |bar|
        kept = bar
        bar.progress = 0.5
        bar.progress
      end
      expect(result).to eq(0.5)
      expect(kept).to be_closed
    end

    it 'non si crea dentro un callback chiamato da notcurses' do
      parent = std.create_child(rows: 3, cols: 3)
      target = new_plane(1, 4)
      parent.create_child(rows: 1, cols: 1, resize: ->(_p) { described_class.new(target) })
      expect { parent.resize(4, 4) }.to raise_error(Notcurses::WidgetError, /callback/)
      parent.family_destroy
      target.close
    end
  end

  describe 'chiusura da parte del contesto' do
    it 'Context#close chiude la barra aperta' do
      bar = plane = nil
      NcHelpers.open_context do |nc|
        plane = nc.stdplane.create_child(rows: 1, cols: 5)
        bar = described_class.new(plane)
        bar.progress = 0.5
      end
      expect([bar, plane]).to all(be_closed)
    end

    it 'Context#drop_planes chiude la barra aperta' do
      NcHelpers.open_context do |nc|
        bar = described_class.new(nc.stdplane.create_child(rows: 1, cols: 5))
        nc.drop_planes
        expect(bar).to be_closed
        expect(nc.stats.planes).to eq(1)
      end
    end
  end

  it 'senza UTF-8 anche su un piano alto una riga sinistra e destra devono avere gli stessi colori' do
    script = <<~'RUBY'
      require 'notcurses'
      dark = Notcurses::Channel.rgb(0, 80, 0)
      light = Notcurses::Channel.rgb(0, 255, 0)
      Notcurses::Context.open(output: '/dev/null', termtype: 'xterm-256color', suppress_banners: true) do |nc|
        puts "can_utf8? #{nc.can_utf8?}"
        [[1, 40], [2, 40]].each do |rows, cols|
          Notcurses::ProgBar.open(nc.stdplane.create_child(rows: rows, cols: cols), ul_channel: dark,
                                  ur_channel: light, bl_channel: dark, br_channel: light) do |bar|
            bar.progress = 0.5
            puts "#{rows}x#{cols}: ok"
          rescue Notcurses::WidgetError => e
            puts "#{rows}x#{cols}: #{e.message}"
          end
        end
      end
    RUBY
    env = { 'TERM' => 'xterm-256color', 'LANG' => 'C', 'LC_ALL' => 'C' }
    lib = File.expand_path('../../lib', __dir__)
    out, status = Open3.capture2e(env, NcHelpers::TIMEOUT, '-k', '5', '-s', 'KILL', '30', RbConfig.ruby, '-I', lib, '-e', script,
                                  stdin_data: '')
    expect([status.exitstatus, out]).to eq([0, "can_utf8? false\n1x40: ncprogbar_set_progress fallita (-1)\n2x40: ok\n"])
  end
end
