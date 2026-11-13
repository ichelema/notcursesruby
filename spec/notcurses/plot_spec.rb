# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative '../support/nc_helpers'

RSpec.describe Notcurses::Plot do
  # Piano figlio dello stdplane da dare al grafico.
  def new_plane(rows: 3, cols: 20) = nc.stdplane.create_child(rows: rows, cols: cols)

  # Chiamata raw a ncuplot_sample/ncdplot_sample con una x già in coordinate C.
  def raw_sample(plot, xc)
    if plot.type == :double
      buf = ::FFI::MemoryPointer.new(:double)
      [Notcurses::FFI.ncdplot_sample(plot.to_ptr, xc, buf), buf.read_double]
    else
      buf = ::FFI::MemoryPointer.new(:uint64)
      [Notcurses::FFI.ncuplot_sample(plot.to_ptr, xc, buf), buf.read_uint64]
    end
  end

  describe 'con un contesto condiviso' do
    include_context 'con un contesto notcurses'

    describe 'creazione' do
      it 'prende possesso del piano e calcola blitter, slot e finestra' do
        plane = new_plane(cols: 20)
        plot = described_class.new(plane)
        expect(plot.type).to eq(:uint64)
        expect(plot.blitter).to eq(:half) # 8x1 senza quadranti degrada a 4x1 e poi a 2x1
        expect(plot.slot_count).to eq(20)
        expect(plot.window).to eq(0..0)
        expect(plot.plane).to equal(plane)
        expect(plot.context).to equal(nc)
        expect(plane).to be_widget_plane
        expect(plane.close).to be_nil # il piano è del grafico: close non fa nulla
        expect(plane).not_to be_closed
        expect(plot.inspect).to match(/Notcurses::Plot 0x/)
        plot.close
      end

      it 'sceglie il blitter con la catena di ripieghi del C e il C usa lo stesso numero di slot' do
        caps = nc.capabilities
        expect(caps.quadrants? || caps.sextants? || caps.octants?).to be(false) # contesto headless
        expected = { default: :half, ascii: :ascii, half: :half, quad: :half, sextant: :half, octant: :half,
                     braille: :braille, pixel: :half, four_by_one: :half, eight_by_one: :half }
        expected.each do |requested, blitter|
          plot = described_class.new(new_plane(rows: 2, cols: 10), blitter: requested)
          expect(plot.blitter).to eq(blitter), "blitter #{requested}"
          expect(plot.slot_count).to eq(blitter == :braille ? 20 : 10)
          # dopo un salto il C ha slotx = slot_count: x C 1 è in finestra, 0 è dietro
          expect(plot.add_sample(10**12, 4)).to be(true)
          expect(raw_sample(plot, 1).first).to eq(0), "blitter #{requested}"
          expect(raw_sample(plot, 0).first).to eq(-1), "blitter #{requested}"
          plot.close
        end
      end

      it 'calcola gli slot con range_x e label_ticks come il C' do
        { [{ range_x: 5 }, :ascii, 20] => 5, [{ range_x: 50 }, :ascii, 20] => 20,
          [{ label_ticks: true }, :ascii, 20] => 13, [{ label_ticks: true }, :braille, 20] => 26,
          [{ label_ticks: true, range_x: 4 }, :ascii, 10] => 3 }.each do |(opts, requested, cols), slots|
          plot = described_class.new(new_plane(cols: cols), blitter: requested, **opts)
          expect(plot.slot_count).to eq(slots), opts.inspect
          plot.add_sample(10**9, 1)
          expect(raw_sample(plot, 1).first).to eq(0)
          expect(raw_sample(plot, 0).first).to eq(-1)
          plot.close
        end
      end

      it 'con no_degrade: rifiuta un blitter non disponibile prima del C, senza toccare il piano' do
        plane = new_plane
        expect { described_class.new(plane, blitter: :quad, no_degrade: true) }
          .to raise_error(Notcurses::WidgetError, /non disponibile/)
        expect(plane).not_to be_closed
        expect(plane).not_to be_widget_plane
        plot = described_class.new(plane, blitter: :braille, no_degrade: true)
        expect(plot.blitter).to eq(:braille)
        plot.close
      end

      it 'copia il titolo e accetta colori, stili e flag' do
        title = +'TITOLO'
        plane = new_plane(cols: 30)
        plot = described_class.new(plane, title: title, label_ticks: true, max_channels: Notcurses::Channels.new(value: 0),
                                          min_channels: 0, legend_style: %i[bold], exponential: true,
                                          print_sample: true)
        title.replace('XXXXXX')
        plot.add_sample(0, 10)
        expect(plane.contents).to include('TITOLO')
        expect(plane.contents).not_to include('XXXXXX')
        plot.close
        plot = described_class.new(new_plane, detect_max_only: true)
        expect(plot.add_sample(3, 7)).to be(true)
        plot.close
      end

      it 'valida le opzioni prima di prendere il piano' do
        plane = new_plane(cols: 7)
        expect { described_class.new(plane, type: :int) }.to raise_error(ArgumentError)
        expect { described_class.new(plane, min: -1, max: 5) }.to raise_error(ArgumentError)
        expect { described_class.new(plane, min: 2**64) }.to raise_error(ArgumentError)
        expect { described_class.new(plane, min: 1.5, max: 2) }.to raise_error(TypeError)
        expect { described_class.new(plane, min: 5, max: 5) }.to raise_error(ArgumentError, /dominio automatico/)
        expect { described_class.new(plane, min: 9, max: 5) }.to raise_error(ArgumentError, /< min/)
        expect { described_class.new(plane, min: 0, max: 5, detect_max_only: true) }.to raise_error(ArgumentError)
        expect { described_class.new(plane, type: :double, max: Float::NAN) }.to raise_error(ArgumentError)
        expect { described_class.new(plane, type: :double, min: '0') }.to raise_error(TypeError)
        expect { described_class.new(plane, blitter: :nessuno) }.to raise_error(ArgumentError)
        expect { described_class.new(plane, blitter: 42) }.to raise_error(ArgumentError) # fuori enum: abort nel C
        expect { described_class.new(plane, range_x: -1) }.to raise_error(ArgumentError)
        expect { described_class.new(plane, title: "a\nb") }.to raise_error(ArgumentError)
        expect { described_class.new(plane, title: 7) }.to raise_error(TypeError)
        expect { described_class.new(plane, legend_style: :lampeggiante) }.to raise_error(ArgumentError)
        expect { described_class.new(plane, max_channels: 'rosso') }.to raise_error(TypeError)
        expect { described_class.new(plane, exponential: 1) }.to raise_error(TypeError)
        expect { described_class.new(plane, no_degrade: nil) }.to raise_error(TypeError)
        # 7 colonne con le etichette: il C scriverebbe fuori dal piano
        expect { described_class.new(plane, label_ticks: true) }.to raise_error(Notcurses::WidgetError, /almeno 8/)
        expect(plane).not_to be_closed
        expect(plane).not_to be_widget_plane
        plane.close
        expect { described_class.new(:piano) }.to raise_error(TypeError)
        expect { described_class.new(plane) }.to raise_error(Notcurses::ClosedError)
        expect { described_class.new(nc.stdplane) }.to raise_error(Notcurses::WidgetError, /stdplane/)
      end

      it 'rifiuta il piano di un altro widget' do
        plane = new_plane
        first = described_class.new(plane)
        expect { described_class.new(plane) }.to raise_error(Notcurses::WidgetError, /già a un widget/)
        first.close
      end

      it 'passa al C il blocco scelto con NODEGRADE: se il C non lo ha, fallisce invece di cambiare gli slot' do
        # capacità finte con i quadranti: il Ruby sceglie :quad (2 slot per colonna), il C non li ha
        fake = instance_double(Notcurses::Capabilities, utf8?: true, braille?: true, octants?: false,
                                                        sextants?: false, quadrants?: true, halfblocks?: true)
        allow(nc).to receive(:capabilities).and_return(fake)
        plane = new_plane
        expect { described_class.new(plane, blitter: :quad) }.to raise_error(Notcurses::WidgetError, /NULL/)
        expect(plane).to be_closed # il C prende il piano anche quando fallisce
      end

      it 'se il C restituisce NULL solleva WidgetError e il piano risulta distrutto' do
        plane = new_plane
        ptr = plane.address_ptr
        allow(Notcurses::FFI).to receive(:ncuplot_create).and_return(::FFI::Pointer::NULL)
        expect { described_class.new(plane) }.to raise_error(Notcurses::WidgetError, /NULL/)
        expect(plane).to be_closed
        Notcurses::FFI.ncplane_destroy(ptr) # lo stub non lo ha distrutto davvero
      end
    end

    describe 'campioni uint64' do
      it 'add_sample somma, set_sample sostituisce, sample legge, e la finestra avanza' do
        plot = described_class.new(new_plane, range_x: 10)
        expect(plot.add_sample(0, 3)).to be(true)
        expect(plot.add_sample(0, 4)).to be(true)
        expect(plot.sample(0)).to eq(7)
        expect(plot.set_sample(0, 1)).to be(true)
        expect(plot.sample(0)).to eq(1)
        expect(plot.add_sample(5, 2)).to be(true)
        expect(plot.window).to eq(0..5)
        expect(plot.sample(3)).to eq(0)
        expect(plot.sample(6)).to be_nil
        expect(plot.add_sample(14, 0)).to be(true)
        expect(plot.window).to eq(5..14)
        expect(plot.sample(4)).to be_nil
        expect(plot.sample(5)).to eq(2)
        plot.close
      end

      it 'dopo un salto della finestra legge i valori giusti (bug F9.9 di 3.0.17)' do
        plot = described_class.new(new_plane, range_x: 10)
        expect(plot.add_sample(13, 7)).to be(true) # il C da solo leggerebbe 0
        expect(plot.sample(13)).to eq(7)
        expect(plot.add_sample(14, 5)).to be(true)
        expect(plot.sample(14)).to eq(5)
        expect(plot.add_sample(1_000, 3)).to be(true)
        expect(plot.add_sample(1_003, 2)).to be(true)
        expect([plot.sample(1_000), plot.sample(1_003), plot.sample(1_001)]).to eq([3, 2, 0])
        expect(plot.window).to eq(994..1_003)
        plot.close
      end

      it 'con il dominio fisso controlla lo slot giusto e restituisce false fuori dominio (valore memorizzato)' do
        plot = described_class.new(new_plane, range_x: 10, min: 1, max: 100)
        expect(plot.add_sample(13, 50)).to be(true) # il C da solo restituirebbe -1
        expect(plot.add_sample(14, 500)).to be(false)
        expect(plot.sample(14)).to eq(500)
        expect(plot.set_sample(14, 60)).to be(true)
        expect(plot.set_sample(13, 0)).to be(false)
        expect(plot.sample(13)).to eq(0)
        plot.close
      end

      it 'scarta senza chiamare il C le x dietro la finestra (set_sample scriverebbe fuori dal buffer)' do
        plot = described_class.new(new_plane, range_x: 10)
        plot.add_sample(20, 1)
        expect(Notcurses::FFI).not_to receive(:ncuplot_set_sample)
        expect(Notcurses::FFI).not_to receive(:ncuplot_add_sample)
        expect(plot.set_sample(10, 9)).to be(false)
        expect(plot.add_sample(3, 9)).to be(false)
        expect(plot.sample(11)).to eq(0)
        plot.close
      end

      it 'se la finestra del Ruby fosse più larga di quella del C, set_sample non scriverebbe fuori dal buffer' do
        plane = new_plane(cols: 20)
        allow(plane).to receive(:dim_x).and_return(40) # il Ruby calcola 40 slot, il C ne ha 20
        plot = described_class.new(plane, blitter: :ascii)
        expect(plot.slot_count).to eq(40)
        plot.add_sample(1_000, 1)
        expect(Notcurses::FFI).not_to receive(:ncuplot_set_sample)
        expect { plot.set_sample(1_000 - 30, 5) }.to raise_error(Notcurses::WidgetError, /non coerente/)
        plot.close
      end

      it 'accetta x fino a 2^64-1 senza passare al C indici negativi' do
        plot = described_class.new(new_plane, range_x: 10)
        expect(plot.add_sample(2**64 - 1, 9)).to be(true)
        expect(plot.sample(2**64 - 1)).to eq(9)
        expect(plot.set_sample(2**64 - 5, 4)).to be(true)
        expect(plot.sample(2**64 - 5)).to eq(4)
        expect { plot.add_sample(2**64, 1) }.to raise_error(ArgumentError)
        expect { plot.sample(-1) }.to raise_error(ArgumentError)
        expect { plot.set_sample(1.5, 1) }.to raise_error(TypeError)
        plot.close
      end

      it 'valida i valori e la somma' do
        plot = described_class.new(new_plane)
        expect { plot.add_sample(0, -1) }.to raise_error(ArgumentError)
        expect { plot.add_sample(0, 1.0) }.to raise_error(TypeError)
        expect { plot.set_sample(0, 2**64) }.to raise_error(ArgumentError)
        plot.set_sample(0, 2**64 - 1)
        expect { plot.add_sample(0, 1) }.to raise_error(ArgumentError, /esce dal tipo/)
        expect(plot.sample(0)).to eq(2**64 - 1)
        plot.close
      end

      # Limite di 3.0.17 documentato, non aggirato (plot.c:298-306): fallisce se un notcurses nuovo lo cambia.
      it 'con label_ticks le etichette si fermano a 184.47P (limite di 3.0.17)' do
        { 10**17 => '100.00P', 2 * 10**17 => '184.47P' }.each do |value, label|
          plot = described_class.new(new_plane, label_ticks: true, blitter: :ascii) # add_sample somma: un grafico nuovo
          plot.add_sample(0, value)
          expect((0...3).map { |y| plot.plane.contents(y: y, rows: 1, cols: 7) }).to all(eq(label))
          expect(plot.sample(0)).to eq(value)
          plot.close
        end
      end
    end

    describe 'campioni double' do
      it 'usa Float e il dominio fisso' do
        plot = described_class.new(new_plane, type: :double, range_x: 10, min: -5, max: 5)
        expect(plot.type).to eq(:double)
        expect(plot.add_sample(0, -2.5)).to be(true)
        expect(plot.sample(0)).to eq(-2.5)
        expect(plot.add_sample(1, 9)).to be(false)
        expect(plot.sample(1)).to eq(9.0)
        expect(plot.set_sample(1, 1)).to be(true)
        expect(plot.add_sample(30, 0.5)).to be(true)
        expect(plot.sample(30)).to eq(0.5)
        expect(plot.sample(1)).to be_nil
        expect { plot.add_sample(31, Float::INFINITY) }.to raise_error(ArgumentError)
        expect { plot.set_sample(31, Float::NAN) }.to raise_error(ArgumentError)
        expect { plot.add_sample(31, 'x') }.to raise_error(TypeError)
        plot.close
      end

      it 'rifiuta una somma non finita' do
        plot = described_class.new(new_plane, type: :double)
        plot.add_sample(0, Float::MAX)
        expect { plot.add_sample(0, Float::MAX) }.to raise_error(ArgumentError, /esce dal tipo/)
        plot.close
      end
    end

    describe 'piano ridimensionato' do
      it 'con label_ticks rifiuta i campioni se il piano scende a 7 colonne (il C scriverebbe fuori)' do
        plot = described_class.new(new_plane(cols: 20), label_ticks: true)
        expect(plot.add_sample(0, 1)).to be(true)
        plot.plane.resize(3, 7)
        expect { plot.add_sample(1, 1) }.to raise_error(Notcurses::WidgetError, /7 colonne/)
        expect { plot.set_sample(1, 1) }.to raise_error(Notcurses::WidgetError)
        plot.plane.resize(3, 12)
        expect(plot.add_sample(1, 1)).to be(true)
        plot.close
      end
    end

    describe 'chiusura' do
      it 'close distrugge piano e grafico, è idempotente, destroy è un alias' do
        plane = new_plane
        plot = described_class.new(plane)
        before = nc.stats.planes
        expect(plot.close).to be_nil
        expect(plot).to be_closed
        expect(plane).to be_closed
        expect(nc.stats.planes).to eq(before - 1)
        expect(plot.close).to be_nil
        expect(plot.destroy).to be_nil
        expect(plot.inspect).to include('chiuso')
        %i[plane type blitter slot_count window to_ptr].each do |m|
          expect { plot.public_send(m) }.to raise_error(Notcurses::ClosedError), m.to_s
        end
        expect { plot.add_sample(0, 1) }.to raise_error(Notcurses::ClosedError)
        expect { plot.set_sample(0, 1) }.to raise_error(Notcurses::ClosedError)
        expect { plot.sample(0) }.to raise_error(Notcurses::ClosedError)
      end

      it 'open con un blocco chiude il grafico alla fine' do
        plane = new_plane
        kept = nil
        result = described_class.open(plane, type: :double) do |plot|
          kept = plot
          plot.add_sample(0, 1.5)
          :fatto
        end
        expect(result).to eq(:fatto)
        expect(kept).to be_closed
        expect(plane).to be_closed
      end

      it 'drop_planes chiude il grafico prima di distruggere i piani' do
        plane = new_plane
        plot = described_class.new(plane, blitter: :braille)
        plot.add_sample(3, 3)
        nc.drop_planes
        expect(plot).to be_closed
        expect(plane).to be_closed
      end

      it 'family_destroy di un antenato rifiuta finché il grafico è aperto' do
        parent = new_plane(rows: 6, cols: 30)
        plot = described_class.new(parent.create_child(rows: 3, cols: 20))
        expect { parent.family_destroy }.to raise_error(Notcurses::PlaneError, /widget/)
        plot.close
        parent.family_destroy
        expect(parent).to be_closed
      end
    end
  end

  describe 'chiusura del contesto' do
    it 'Context#close chiude il grafico aperto prima di notcurses_stop' do
      plot = nil
      plane = nil
      NcHelpers.open_context do |ctx|
        plane = ctx.stdplane.create_child(rows: 3, cols: 20)
        plot = described_class.new(plane, type: :double, label_ticks: true)
        plot.add_sample(5, 2.0)
      end
      expect(plot).to be_closed
      expect(plane).to be_closed
      expect(plot.close).to be_nil
    end
  end
end
