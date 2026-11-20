# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require 'open3'
require 'pathname'
require_relative '../support/nc_helpers'

# Fixture in spec/fixtures/visual/, create con ffmpeg n9.0.2 (non servono per
# eseguire le spec):
#   rgbw.png: 2x4 pixel opachi, righe rossa, verde, blu, bianca
#     ruby -e 'print [[255,0,0,255],[0,255,0,255],[0,0,255,255],[255,255,255,255]].flat_map { |c| c * 2 }.pack("C*")' > rgbw.rgba
#     ffmpeg -f rawvideo -pixel_format rgba -video_size 2x4 -i rgbw.rgba -frames:v 1 rgbw.png
#   frames.mkv: 8x8 pixel, 4 frame a 10 fps (rosso, verde, blu, bianco), FFV1 senza perdita
#     ruby -e 'print [[255,0,0,255],[0,255,0,255],[0,0,255,255],[255,255,255,255]].map { |c| (c * 64).pack("C*") }.join' > frames.rgba
#     ffmpeg -f rawvideo -pixel_format rgba -video_size 8x8 -framerate 10 -i frames.rgba -c:v ffv1 frames.mkv
RSpec.describe Notcurses::Visual do
  # 4 righe x 2 colonne RGBA: rossa, verde, blu, bianca
  rgbw = [[255, 0, 0, 255], [0, 255, 0, 255], [0, 0, 255, 255], [255, 255, 255, 255]].flat_map { |c| c * 2 }.pack('C*')
  fixtures = File.expand_path('../fixtures/visual', __dir__)

  let(:ffi) { Notcurses::FFI }
  let(:rgbw) { rgbw }
  let(:png) { File.join(fixtures, 'rgbw.png') }
  let(:mkv) { File.join(fixtures, 'frames.mkv') }

  # [primo piano, sfondo, alpha dello sfondo] della cella (y, x), letti con il C.
  def cell(plane, y, x)
    c = Notcurses::FFI::NcCell.new
    Notcurses::FFI.ncplane_at_yx_cell(plane.to_ptr, y, x, c)
    ch = c[:channels]
    Notcurses::FFI.nccell_release(plane.to_ptr, c)
    [(ch >> 32) & 0xffffff, ch & 0xffffff, Notcurses::FFI.ncchannels_bg_alpha(ch)]
  end

  def rgba(*pixels) = pixels.flatten.pack('C*')

  context 'senza un contesto attivo' do
    it 'i costruttori sollevano ClosedError (in 3.0.17 il visual andrebbe in crash alla distruzione)' do
      expect(Notcurses.active_context).to be_nil
      expect { described_class.from_rgba(rgbw, rows: 4, cols: 2) }.to raise_error(Notcurses::ClosedError, /Context/)
      expect { described_class.from_file(png) }.to raise_error(Notcurses::ClosedError)
      expect { described_class.from_sixel("#0~", rows: 6, cols: 1) }.to raise_error(Notcurses::ClosedError)
      expect { described_class.media_default_blitter }.to raise_error(Notcurses::ClosedError)
    end
  end

  context 'con un contesto' do
    include_context 'con un contesto notcurses'

    let(:visual) { described_class.from_rgba(rgbw, rows: 4, cols: 2) }

    after { visual.close }

    describe '.from_rgba' do
      it 'copia i pixel R, G, B, A' do
        data = rgbw.dup
        v = described_class.from_rgba(data, rows: 4, cols: 2)
        data.replace("\0" * data.bytesize)
        expect(v.dims).to eq([4, 2])
        expect(v.at(0, 0)).to eq(Notcurses::Pixel.rgb(255, 0, 0))
        expect(v.at(3, 1)).to eq(Notcurses::Pixel.rgb(255, 255, 255))
        expect(v.context).to equal(nc)
        v.close
      end

      it 'accetta righe con padding (rowstride)' do
        data = rgba([1, 2, 3, 4], [9, 9, 9, 9], [5, 6, 7, 8], [9, 9, 9, 9])
        described_class.from_rgba(data, rows: 2, cols: 1, rowstride: 8) do |v|
          expect(v.dims).to eq([2, 1])
          expect(v.at(1, 0).to_a).to eq([5, 6, 7, 8])
        end
      end

      it 'con un blocco restituisce il valore del blocco e chiude il visual' do
        kept = nil
        result = described_class.from_rgba(rgbw, rows: 4, cols: 2) { |v| (kept = v).dims }
        expect(result).to eq([4, 2])
        expect(kept).to be_closed
      end

      it 'rifiuta rowstride che il C accetterebbe lasciando memoria non inizializzata' do
        expect { described_class.from_rgba(rgbw, rows: 2, cols: 2, rowstride: 4) }.to raise_error(ArgumentError)
        expect { described_class.from_rgba(rgbw, rows: 2, cols: 1, rowstride: 6) }.to raise_error(ArgumentError, /multiplo/)
      end

      it 'valida dati e dimensioni' do
        expect { described_class.from_rgba(rgbw, rows: 5, cols: 2) }.to raise_error(ArgumentError, /byte/)
        expect { described_class.from_rgba(rgbw, rows: 0, cols: 2) }.to raise_error(ArgumentError)
        expect { described_class.from_rgba(rgbw, rows: 4, cols: 2.0) }.to raise_error(TypeError)
        expect { described_class.from_rgba([1, 2], rows: 1, cols: 1) }.to raise_error(TypeError)
        expect { described_class.from_rgba(rgbw, rows: 40_000, cols: 40_000) }.to raise_error(ArgumentError, /troppi/)
      end
    end

    describe '.from_bgra' do
      it 'converte B, G, R, A in RGBA' do
        described_class.from_bgra(rgba([1, 2, 3, 4]), rows: 1, cols: 1) do |v|
          expect(v.at(0, 0).to_a).to eq([3, 2, 1, 4])
        end
      end

      it 'valida rowstride' do
        expect { described_class.from_bgra(rgbw, rows: 1, cols: 2, rowstride: 7) }.to raise_error(ArgumentError)
      end
    end

    describe '.from_rgb_packed' do
      it 'legge 3 byte per pixel con l\'alpha data' do
        described_class.from_rgb_packed(rgba([1, 2, 3], [4, 5, 6]), rows: 1, cols: 2, alpha: 128) do |v|
          expect(v.at(0, 0).to_a).to eq([1, 2, 3, 128])
          expect(v.at(0, 1).to_a).to eq([4, 5, 6, 128])
        end
      end

      it 'valida alpha e rowstride' do
        expect { described_class.from_rgb_packed("\0" * 6, rows: 1, cols: 2, alpha: 300) }.to raise_error(ArgumentError)
        expect { described_class.from_rgb_packed("\0" * 8, rows: 1, cols: 2, rowstride: 8) }.to raise_error(ArgumentError, /multiplo di 3/)
      end
    end

    describe '.from_rgb_loose' do
      it 'sostituisce il quarto byte con alpha' do
        described_class.from_rgb_loose(rgba([1, 2, 3, 0xee]), rows: 1, cols: 1, alpha: 7) do |v|
          expect(v.at(0, 0).to_a).to eq([1, 2, 3, 7])
        end
      end

      it 'accetta un rowstride grande (in C copierebbe oltre il buffer)' do
        data = "\x41".b * 8192
        described_class.from_rgb_loose(data, rows: 2, cols: 1, rowstride: 4096) do |v|
          expect(v.dims).to eq([2, 1])
          expect(v.at(1, 0).to_a).to eq([0x41, 0x41, 0x41, 255])
        end
      end

      it 'valida alpha' do
        expect { described_class.from_rgb_loose(rgbw, rows: 4, cols: 2, alpha: -1) }.to raise_error(ArgumentError)
      end
    end

    describe '.from_palidx' do
      let(:palette) { [Notcurses::Channel.default, Notcurses::Channel.rgb(1, 2, 3)] }

      # Prima (bug di 3.0.17, il C ignorava la palette): una voce di default diventava il colore sintetico
      # [i, 220 - i / 2, i, 255 - i] e qualsiasi altra voce un pixel trasparente (0).
      # (la quarta voce è un default reso trasparente: per il C non è più di default, ma nero trasparente)
      it 'i pixel hanno i colori della palette: RGB, trasparente, default = bianco' do
        colors = [Notcurses::Channel.rgb(10, 20, 30), Notcurses::Channel.rgb(40, 50, 60).with_alpha(:transparent),
                  Notcurses::Channel.default, Notcurses::Channel.default.with_alpha(:transparent),
                  Notcurses::Channel.rgb(200, 100, 50).with_alpha(:blend)]
        described_class.from_palidx([0, 1, 2, 3, 4, 2].pack('C*'), rows: 2, cols: 3, palette: colors) do |v|
          expect(v.dims).to eq([2, 3])
          expect((0..1).map { |y| (0..2).map { |x| v.at(y, x).to_a } }).to eq(
            [[[10, 20, 30, 255], [40, 50, 60, 0], [255, 255, 255, 255]],
             [[0, 0, 0, 0], [200, 100, 50, 255], [255, 255, 255, 255]]]
          )
        end
      end

      it 'legge solo il primo byte di ogni pixel con pstride > 1 e salta il resto della riga con rowstride' do
        described_class.from_palidx("\x01\x00\x00\x07".b, rows: 1, cols: 2, palette: palette, pstride: 2) do |v|
          expect(v.at(0, 0).to_a).to eq([1, 2, 3, 255])
          expect(v.at(0, 1).to_a).to eq([255, 255, 255, 255])
        end
        described_class.from_palidx("\x01\x00\x09\x09\x00\x01\x09\x09".b, rows: 2, cols: 2, palette: palette,
                                                                              rowstride: 4) do |v|
          expect(v.at(0, 0).to_a).to eq([1, 2, 3, 255])
          expect(v.at(0, 1).to_a).to eq([255, 255, 255, 255])
          expect(v.at(1, 0).to_a).to eq([255, 255, 255, 255])
          expect(v.at(1, 1).to_a).to eq([1, 2, 3, 255])
        end
      end

      it 'un indice fuori dalla palette solleva VisualError' do
        expect { described_class.from_palidx("\x05".b, rows: 1, cols: 1, palette: palette) }
          .to raise_error(Notcurses::VisualError, /indice 5/)
        expect { described_class.from_palidx("\x00\x02".b, rows: 1, cols: 2, palette: palette) }
          .to raise_error(Notcurses::VisualError, /indice 2/)
      end

      it 'valida la palette' do
        expect { described_class.from_palidx("\x00".b, rows: 1, cols: 1, palette: []) }.to raise_error(ArgumentError)
        expect do
          described_class.from_palidx("\x00".b, rows: 1, cols: 1, palette: [Notcurses::Channel.default] * 257)
        end.to raise_error(ArgumentError)
        expect { described_class.from_palidx("\x00".b, rows: 1, cols: 1, palette: [0]) }.to raise_error(TypeError)
        expect { described_class.from_palidx("\x00".b, rows: 1, cols: 1, palette: 0) }.to raise_error(TypeError)
        expect { described_class.from_palidx("\x00".b, rows: 1, cols: 1, palette: palette, pstride: 0) }.to raise_error(ArgumentError)
        # righe di cols * pstride byte: oltre un int del C nel calcolo degli indirizzi
        expect do
          described_class.from_palidx("\x00".b, rows: 1000, cols: 1000, palette: palette, pstride: 5000)
        end.to raise_error(ArgumentError, /troppi/)
      end

      # ICH-551: una voce con un indice di palette non ha un colore RGB (prima: l'indice 5 diventava il blu
      # del pixel, [0, 0, 5, 255]).
      it 'una voce con un indice di palette solleva ArgumentError' do
        index = Notcurses::Channel.palindex(5)
        expect { described_class.from_palidx("\x00".b, rows: 1, cols: 1, palette: [index]) }
          .to raise_error(ArgumentError, /palette\[0\]/)
        expect do
          described_class.from_palidx("\x00".b, rows: 1, cols: 1, palette: [Notcurses::Channel.rgb(1, 2, 3), index])
        end.to raise_error(ArgumentError, /palette\[1\]/)
      end
    end

    describe '.from_plane' do
      it 'converte le celle del piano in pixel' do
        nc.stdplane.create_child(rows: 2, cols: 3) do |plane|
          ffi.ncplane_set_bg_rgb(plane.to_ptr, 0x102030)
          2.times { |y| ffi.ncplane_putstr_yx(plane.to_ptr, y, 0, '   ') }
          described_class.from_plane(plane, blitter: :ascii) do |v|
            expect(v.dims).to eq([2, 3])
            expect(v.at(1, 2).to_a).to eq([0x10, 0x20, 0x30, 255])
          end
          described_class.from_plane(plane, blitter: :half, y: 1, x: 1, cols: 1) do |v|
            expect(v.dims).to eq([2, 1])
          end
        end
      end

      it 'legge la regione con y:, x:, rows: e cols:, come Plane#as_rgba' do
        nc.stdplane.create_child(rows: 2, cols: 3) do |plane|
          ffi.ncplane_set_bg_rgb(plane.to_ptr, 0x102030)
          2.times { |y| ffi.ncplane_putstr_yx(plane.to_ptr, y, 0, '   ') }
          plane.move_cursor(1, 2)
          # senza argomenti tutto il piano, anche con il cursore altrove
          described_class.from_plane(plane, blitter: :ascii) { |v| expect(v.dims).to eq([2, 3]) }
          described_class.from_plane(plane, blitter: :ascii, x: 1, rows: 1) { |v| expect(v.dims).to eq([1, 2]) }
          # nil = cursore per y: e x:, fino al bordo per rows: e cols:
          described_class.from_plane(plane, blitter: :ascii, y: nil, x: nil) { |v| expect(v.dims).to eq([1, 1]) }
          described_class.from_plane(plane, blitter: :ascii, y: 0, x: nil, rows: nil) { |v| expect(v.dims).to eq([2, 1]) }
          # -1 e 0, i valori speciali del C, sono rifiutati
          expect { described_class.from_plane(plane, blitter: :ascii, y: -1) }.to raise_error(ArgumentError)
          expect { described_class.from_plane(plane, blitter: :ascii, x: -1) }.to raise_error(ArgumentError)
          expect { described_class.from_plane(plane, blitter: :ascii, rows: 0) }.to raise_error(ArgumentError)
          expect { described_class.from_plane(plane, blitter: :ascii, cols: 0) }.to raise_error(ArgumentError)
          expect { described_class.from_plane(plane, blitter: :ascii, begy: 0) }.to raise_error(ArgumentError)
          expect { described_class.from_plane(plane, blitter: :ascii, rows: 3) }.to raise_error(Notcurses::VisualError)
        end
      end

      it 'solleva VisualError se il C rifiuta il piano o il blitter' do
        nc.stdplane.create_child(rows: 1, cols: 2) do |plane|
          expect { described_class.from_plane(plane, blitter: :ascii) }.to raise_error(Notcurses::VisualError)
          ffi.ncplane_putstr_yx(plane.to_ptr, 0, 0, 'ab')
          expect { described_class.from_plane(plane, blitter: :ascii) }.to raise_error(Notcurses::VisualError)
          expect { described_class.from_plane(plane, blitter: :default) }.to raise_error(Notcurses::VisualError)
        end
      end

      it 'valida gli argomenti' do
        expect { described_class.from_plane(:plane, blitter: :ascii) }.to raise_error(TypeError)
        expect { described_class.from_plane(nc.stdplane, blitter: :nessuno) }.to raise_error(ArgumentError)
        expect { described_class.from_plane(nc.stdplane, blitter: :ascii, rows: -1) }.to raise_error(ArgumentError)
        expect { described_class.from_plane(nc.stdplane, blitter: :ascii, y: 0.5) }.to raise_error(TypeError)
      end
    end

    describe '.from_sixel' do
      let(:red_band) { "\ePq#0;2;100;0;0#0~~-\e\\" }

      it 'decodifica una sequenza valida' do
        described_class.from_sixel(red_band, rows: 6, cols: 2) do |v|
          expect(v.dims).to eq([6, 2])
          expect(v.at(5, 1)).to eq(Notcurses::Pixel.rgb(255, 0, 0))
        end
      end

      it 'con rows non multiplo di 6 decodifica la banda intera e ritaglia' do
        described_class.from_sixel(red_band, rows: 4, cols: 2) do |v|
          expect(v.dims).to eq([4, 2])
          expect(v.at(3, 0)).to eq(Notcurses::Pixel.rgb(255, 0, 0))
        end
      end

      it 'rifiuta prima del C le sequenze che il decoder di 3.0.17 leggerebbe o scriverebbe fuori dai buffer' do
        ["\ePq#70000;2;100;0;0#0~\e\\", "\ePq#0;2;100;0;0#65535~\e\\", "\ePq#0~!\e\\", "\ePq#0;2;100;", 'abc'].each do |seq|
          expect { described_class.from_sixel(seq, rows: 6, cols: 2) }.to raise_error(ArgumentError), seq.inspect
        end
      end

      it 'rifiuta anche la sintassi che il wrapper non accetta (colori HLS, caratteri estranei)' do
        ["\ePq#0;1;100;0;0#0~\e\\", "\ePq#0~\n~\e\\"].each do |seq|
          expect { described_class.from_sixel(seq, rows: 6, cols: 2) }.to raise_error(ArgumentError), seq.inspect
        end
      end

      it 'solleva VisualError se il decoder rifiuta i dati' do
        expect { described_class.from_sixel("\ePq#0!5~\e\\", rows: 6, cols: 2) }.to raise_error(Notcurses::VisualError)
        expect { described_class.from_sixel("\ePq#0~-~\e\\", rows: 6, cols: 2) }.to raise_error(Notcurses::VisualError)
      end

      it 'valida le dimensioni' do
        expect { described_class.from_sixel(red_band, rows: 0, cols: 2) }.to raise_error(ArgumentError)
        expect { described_class.from_sixel(:sixel, rows: 6, cols: 2) }.to raise_error(TypeError)
      end
    end

    describe '.from_file e .open' do
      it 'carica un\'immagine e ne decodifica il primo frame' do
        v = described_class.from_file(png)
        expect(v.dims).to eq([4, 2])
        expect(v.at(2, 1)).to eq(Notcurses::Pixel.rgb(0, 0, 255))
        v.close
      end

      it '.open con un blocco chiude il visual e accetta un Pathname' do
        kept = nil
        expect(described_class.open(Pathname.new(png)) { |v| (kept = v).at(1, 0).to_a }).to eq([0, 255, 0, 255])
        expect(kept).to be_closed
      end

      it 'solleva VisualError per file inesistenti o non multimediali' do
        expect { described_class.from_file('/nonexistent.png') }.to raise_error(Notcurses::VisualError, /nonexistent/)
        expect { described_class.from_file(__FILE__) }.to raise_error(Notcurses::VisualError)
      end

      it 'valida il percorso' do
        expect { described_class.from_file(42) }.to raise_error(TypeError)
        expect { described_class.open('') }.to raise_error(ArgumentError)
      end
    end

    describe '.media_default_blitter' do
      it 'restituisce il blitter di default come simbolo' do
        expect(Notcurses::Util::BLITTERS.keys).to include(described_class.media_default_blitter)
        expect(described_class.media_default_blitter(scale: :stretch)).to be_a(Symbol)
        expect { described_class.media_default_blitter(scale: :enorme) }.to raise_error(ArgumentError)
      end
    end

    describe '#close' do
      it 'è idempotente, ha l\'alias destroy e rende il visual inutilizzabile' do
        v = described_class.from_rgba(rgbw, rows: 4, cols: 2)
        expect(v.close).to be_nil
        expect(v.destroy).to be_nil
        expect(v).to be_closed
        expect(v.inspect).to include('chiuso')
        plane = nc.stdplane
        [-> { v.to_ptr }, -> { v.dims }, -> { v.geometry }, -> { v.decode }, -> { v.decode_loop },
         -> { v.rotate(1.0) }, -> { v.resize(2, 2) }, -> { v.resize_noninterpolative(2, 2) },
         -> { v.polyfill(0, 0, 0) }, -> { v.at(0, 0) }, -> { v.set(0, 0, 0) }, -> { v.blit(plane: plane) },
         -> { v.create_plane(rows: 1, cols: 1) }, -> { v.subtitle_plane(plane) }, -> { v.stream }].each do |call|
          expect(&call).to raise_error(Notcurses::ClosedError)
        end
      end
    end

    describe '#dims e #geometry' do
      it 'dims restituisce [righe, colonne] in pixel' do
        expect(visual.dims).to eq([4, 2])
      end

      it 'geometry descrive il blit senza disegnare' do
        g = visual.geometry(blitter: :ascii)
        expect(g).to be_a(described_class::Geometry)
        expect(g).to be_frozen
        expect(g.to_h).to include(pixy: 4, pixx: 2, rpixy: 4, rpixx: 2, rcelly: 4, rcellx: 2, scaley: 1, scalex: 1,
                                  begy: 0, begx: 0, leny: 4, lenx: 2, blitter: :ascii)
        expect(visual.geometry(blitter: :half).rcelly).to eq(2)
        expect(visual.geometry.blitter).to eq(described_class.media_default_blitter)
        expect(visual.geometry(blitter: :ascii)).to eq(g)
        expect(visual.geometry(blitter: :ascii).hash).to eq(g.hash)
        expect(g.inspect).to include('4x2')
      end

      it 'con una regione usa la regione e conserva le dimensioni del visual' do
        g = visual.geometry(blitter: :ascii, begy: 1, begx: 1, leny: 2)
        expect(g.to_h).to include(pixy: 4, pixx: 2, begy: 1, begx: 1, leny: 2, lenx: 1, rcelly: 2, rcellx: 1)
      end

      it 'solleva gli errori del C e valida le opzioni' do
        expect { visual.geometry(blitter: :pixel, no_degrade: true) }.to raise_error(Notcurses::VisualError)
        expect { visual.geometry(child: true) }.to raise_error(ArgumentError, /child/)
        expect { visual.geometry(begy: 4) }.to raise_error(ArgumentError, /fuori/)
        expect { visual.geometry(colore: 1) }.to raise_error(ArgumentError)
      end

      it 'Geometry richiede una struct ncvgeom' do
        expect { described_class::Geometry.new({}) }.to raise_error(TypeError)
      end
    end

    describe '#decode e #decode_loop' do
      it 'un\'immagine ha un solo frame: decode restituisce false (1 dal C, non un errore)' do
        described_class.open(png) do |v|
          expect(v.decode).to be(false)
          expect(v.decode_loop).to be(false)
          expect(v.at(0, 0)).to eq(Notcurses::Pixel.rgb(255, 0, 0))
        end
      end

      it 'un video avanza di un frame, decode_loop riparte dall\'inizio' do
        described_class.open(mkv) do |v|
          expect(v.decode).to be(true)
          expect(v.at(0, 0)).to eq(Notcurses::Pixel.rgb(0, 255, 0))
          expect([v.decode_loop, v.decode_loop, v.decode_loop]).to eq([true, true, false])
          expect(v.at(0, 0)).to eq(Notcurses::Pixel.rgb(255, 0, 0))
        end
      end

      it 'un visual che non viene da un file solleva VisualError' do
        expect { visual.decode }.to raise_error(Notcurses::VisualError)
        expect { visual.decode_loop }.to raise_error(Notcurses::VisualError)
      end
    end

    describe '#rotate' do
      it 'ruota di π/2 in senso antiorario e restituisce self' do
        expect(visual.rotate(Math::PI / 2)).to equal(visual)
        expect(visual.dims).to eq([2, 4])
      end

      it 'un\'immagine trasparente non si ruota' do
        described_class.from_rgba("\0" * 16, rows: 2, cols: 2) do |v|
          expect { v.rotate(Math::PI / 2) }.to raise_error(Notcurses::VisualError)
        end
      end

      # 16 pixel opachi tutti diversi
      def distinct_visual(rows, cols)
        data = (0...rows).flat_map { |y| (0...cols).flat_map { |x| [10 + y, 20 + x, 30, 255] } }.pack('C*')
        described_class.from_rgba(data, rows: rows, cols: cols)
      end

      def pixels_of(visual)
        rows, cols = visual.dims
        (0...rows).map { |y| (0...cols).map { |x| visual.at(y, x).value } }
      end

      # Prima (bug di 3.0.17, visual.c:746): la rotazione perdeva la prima riga e la prima colonna di pixel.
      it 'quattro rotazioni di π/2 riportano un 4x4 all\'originale, pixel per pixel' do
        v = distinct_visual(4, 4)
        original = pixels_of(v)
        4.times do
          v.rotate(Math::PI / 2)
          expect(v.dims).to eq([4, 4])
        end
        expect(pixels_of(v)).to eq(original)
      ensure
        v&.close
      end

      it 'una rotazione di π/2 in senso antiorario sposta la prima riga nella prima colonna senza perdere pixel' do
        v = distinct_visual(4, 4)
        before = pixels_of(v)
        v.rotate(Math::PI / 2)
        expect(v.dims).to eq([4, 4])
        expect((0..3).map { |y| (0..3).map { |x| before[x][3 - y] } }).to eq(pixels_of(v))
        expect((0..3).map { |y| v.at(y, 0).value }).to eq(before[0].reverse)
        expect(pixels_of(v).flatten.sort).to eq(before.flatten.sort)
      ensure
        v&.close
      end

      it 'conserva la prima riga e la prima colonna anche a 0 radianti e con immagini di una riga o colonna' do
        v = distinct_visual(3, 5)
        before = pixels_of(v)
        v.rotate(0)
        expect(pixels_of(v)).to eq(before)
        v.close
        v = distinct_visual(1, 3)
        before = pixels_of(v)
        v.rotate(0)
        expect(pixels_of(v)).to eq(before)
        v.close
        v = distinct_visual(3, 1)
        before = pixels_of(v)
        v.rotate(0)
        expect(pixels_of(v)).to eq(before)
      ensure
        v&.close
      end

      it '-π/2 seguito da +π/2 riporta un\'immagine non quadrata all\'originale' do
        v = distinct_visual(3, 5)
        before = pixels_of(v)
        v.rotate(-Math::PI / 2)
        expect(v.dims).to eq([5, 3])
        v.rotate(Math::PI / 2)
        expect(v.dims).to eq([3, 5])
        expect(pixels_of(v)).to eq(before)
      ensure
        v&.close
      end

      it 'taglia i bordi trasparenti: le dimensioni seguono i soli pixel opachi' do
        data = ([0] * 16) + ([0] * 4) + [1, 2, 3, 255] + [4, 5, 6, 255] + ([0] * 4) + ([0] * 16)
        described_class.from_rgba(data.pack('C*'), rows: 3, cols: 4) do |v|
          v.rotate(Math::PI / 2)
          expect(v.dims).to eq([2, 1])
          expect([v.at(0, 0).to_a, v.at(1, 0).to_a]).to eq([[4, 5, 6, 255], [1, 2, 3, 255]])
        end
      end

      # Prima (bug di 3.0.17, visual.c:658-705): il C ruota il riquadro dei pixel opachi attorno al suo centro e i
      # pixel attorno al centro dell'immagine; con bordi trasparenti diversi sui lati i pixel finivano fuori.
      it 'con bordi trasparenti diversi sui lati ruota il blocco opaco senza perdere pixel (prima: 0 pixel su 4)' do
        data = (0...16).flat_map { |i| i.divmod(4).then { |y, x| y >= 2 && x >= 2 ? [10 + y, 20 + x, 30, 255] : Array.new(4, 0) } }
        described_class.from_rgba(data.pack('C*'), rows: 4, cols: 4) do |v|
          block = pixels_of(v)[2..3].map { |row| row[2..3] }
          v.rotate(Math::PI / 2)
          expect(v.dims).to eq([2, 2])
          expect(pixels_of(v)).to eq([[block[0][1], block[1][1]], [block[0][0], block[1][0]]])
        end
      end

      it "quattro rotazioni di π/2 con la prima riga trasparente danno le righe opache dell'originale " \
         '(prima: nessun pixel dopo la terza, VisualError alla quarta)' do
        data = (0...16).flat_map { |i| i.divmod(4).then { |y, x| y.zero? ? Array.new(4, 0) : [10 + y, 20 + x, 30, 255] } }
        described_class.from_rgba(data.pack('C*'), rows: 4, cols: 4) do |v|
          opaque = pixels_of(v)[1..]
          4.times { v.rotate(Math::PI / 2) }
          expect(v.dims).to eq([3, 4])
          expect(pixels_of(v)).to eq(opaque)
        end
      end

      it 'valida l\'angolo' do
        expect { visual.rotate('1') }.to raise_error(TypeError)
        expect { visual.rotate(Float::NAN) }.to raise_error(ArgumentError)
      end
    end

    describe '#resize e #resize_noninterpolative' do
      it 'cambiano le dimensioni e restituiscono self' do
        expect(visual.resize(8, 4)).to equal(visual)
        expect(visual.dims).to eq([8, 4])
        expect(visual.resize_noninterpolative(2, 1)).to equal(visual)
        expect(visual.dims).to eq([2, 1])
      end

      it 'resize_noninterpolative non crea colori nuovi' do
        visual.resize_noninterpolative(8, 2)
        expect((0...8).map { |y| visual.at(y, 1).to_a }).to eq(rgbw.unpack('C*').each_slice(8).flat_map { |r| [r[0, 4]] * 2 })
      end

      it 'rifiutano dimensioni nulle (il C ne accetta alcune producendo un visual vuoto)' do
        expect { visual.resize(0, 2) }.to raise_error(ArgumentError)
        expect { visual.resize_noninterpolative(3, 0) }.to raise_error(ArgumentError)
        expect { visual.resize_noninterpolative(3, nil) }.to raise_error(TypeError)
        expect(visual.dims).to eq([4, 2])
      end
    end

    describe '#at, #set e #polyfill' do
      it 'at e set leggono e scrivono pixel; set accetta Pixel o Integer' do
        expect(visual.set(0, 1, Notcurses::Pixel.rgba(1, 2, 3, 4))).to equal(visual)
        expect(visual.at(0, 1).to_a).to eq([1, 2, 3, 4])
        visual.set(0, 1, 0xff00ff00)
        expect(visual.at(0, 1)).to eq(Notcurses::Pixel.rgb(0, 255, 0))
      end

      it 'polyfill riempie i pixel collegati con lo stesso valore' do
        expect(visual.polyfill(1, 0, Notcurses::Pixel.rgb(9, 9, 9))).to eq(2)
        expect(visual.at(1, 1)).to eq(Notcurses::Pixel.rgb(9, 9, 9))
        expect(visual.at(0, 0)).to eq(Notcurses::Pixel.rgb(255, 0, 0))
        expect(visual.polyfill(1, 0, Notcurses::Pixel.rgb(9, 9, 9))).to eq(0)
      end

      it 'rifiutano coordinate fuori dal visual e pixel non validi' do
        expect { visual.at(4, 0) }.to raise_error(ArgumentError, /fuori/)
        expect { visual.set(0, 2, 0) }.to raise_error(ArgumentError)
        expect { visual.polyfill(-1, 0, 0) }.to raise_error(ArgumentError)
        expect { visual.set(0, 0, 'rosso') }.to raise_error(TypeError)
        expect { visual.set(0, 0, 0x1_0000_0000) }.to raise_error(ArgumentError)
      end
    end

    describe '#blit' do
      it 'disegna in un piano esistente e lo restituisce' do
        nc.stdplane.create_child(rows: 4, cols: 2) do |plane|
          expect(visual.blit(plane: plane, blitter: :ascii)).to equal(plane)
          expect((0..3).map { |y| cell(plane, y, 1)[1] }).to eq([0xff0000, 0x00ff00, 0x0000ff, 0xffffff])
        end
      end

      it 'con child: true crea un figlio del piano, del chiamante' do
        child = visual.blit(plane: nc.stdplane, child: true, blitter: :half, y: 1, x: 3)
        expect(child).to be_owned
        expect(child.parent).to eq(nc.stdplane)
        expect(child.dims).to eq([2, 2])
        expect(child.yx).to eq([1, 3])
        child.close
        expect(child).to be_closed
      end

      it 'senza plane: crea la radice di una nuova pila' do
        root = visual.blit(blitter: :ascii)
        expect(root).to be_root
        expect(root.dims).to eq([4, 2])
        root.close
      end

      it 'y e x simbolici allineano l\'immagine nel piano' do
        nc.stdplane.create_child(rows: 4, cols: 6) do |plane|
          visual.blit(plane: plane, blitter: :ascii, x: :center)
          expect(cell(plane, 0, 2)[1]).to eq(0xff0000)
          expect(cell(plane, 0, 1)[1]).not_to eq(0xff0000)
        end
      end

      it 'una regione con begy > 0 disegna i pixel giusti (bug di 3.0.17 aggirato)' do
        nc.stdplane.create_child(rows: 2, cols: 1) do |plane|
          visual.blit(plane: plane, blitter: :ascii, begy: 2, leny: 2, begx: 1)
          expect([cell(plane, 0, 0)[1], cell(plane, 1, 0)[1]]).to eq([0x0000ff, 0xffffff])
          visual.blit(plane: plane, blitter: :ascii, begy: 1, leny: 2, scale: :stretch, no_interpolate: true)
          expect([cell(plane, 0, 0)[1], cell(plane, 1, 0)[1]]).to eq([0x00ff00, 0x0000ff])
        end
      end

      it 'transcolor rende trasparente un colore' do
        nc.stdplane.create_child(rows: 4, cols: 2) do |plane|
          visual.blit(plane: plane, blitter: :ascii, transcolor: 0x00ff00)
          expect(cell(plane, 1, 0)[2]).to eq(ffi::NCALPHA_TRANSPARENT)
          expect(cell(plane, 0, 0)[2]).to eq(ffi::NCALPHA_OPAQUE)
        end
      end

      it 'solleva VisualError quando il C restituisce NULL' do
        expect { visual.blit(plane: nc.stdplane, blitter: :pixel, no_degrade: true) }.to raise_error(Notcurses::VisualError)
        expect { visual.blit(plane: nc.stdplane, blitter: :ascii, pxoffy: 1) }.to raise_error(Notcurses::VisualError)
        expect { visual.blit(blitter: :pixel, no_degrade: true) }.to raise_error(Notcurses::VisualError)
      end

      it 'valida le opzioni prima del C' do
        expect { visual.blit(child: true) }.to raise_error(ArgumentError, /child/)
        expect { visual.blit(x: :center) }.to raise_error(ArgumentError, /simbolici/)
        expect { visual.blit(plane: nc.stdplane, y: :left) }.to raise_error(ArgumentError)
        expect { visual.blit(plane: nc.stdplane, lenx: 3) }.to raise_error(ArgumentError, /fuori/)
        expect { visual.blit(plane: :std) }.to raise_error(TypeError)
        expect { visual.blit(plane: nc.stdplane, scale: :enorme) }.to raise_error(ArgumentError)
        expect { visual.blit(plane: nc.stdplane, blend: 1) }.to raise_error(TypeError)
        expect { visual.blit(plane: nc.stdplane, transcolor: 0x1000000) }.to raise_error(ArgumentError)
        expect { visual.blit(plane: nc.stdplane, colore: 1) }.to raise_error(ArgumentError)
      end
    end

    describe '#create_plane' do
      it 'crea un figlio di parent con la geometria data e ci disegna il visual' do
        plane = visual.create_plane(rows: 4, cols: 3, parent: nc.stdplane, y: 2, x: 1, name: 'img', blitter: :ascii)
        expect(plane.parent).to eq(nc.stdplane)
        expect([plane.dims, plane.yx, plane.name]).to eq([[4, 3], [2, 1], 'img'])
        expect(cell(plane, 3, 1)[1]).to eq(0xffffff)
        plane.close
      end

      it 'senza parent crea una pila; con un blocco distrugge il piano alla fine' do
        kept = nil
        expect(visual.create_plane(rows: 2, cols: 2, blitter: :half) { |p| (kept = p).root? }).to be(true)
        expect(kept).to be_closed
      end

      it 'solleva VisualError se il blit fallisce e valida le opzioni' do
        expect { visual.create_plane(rows: 2, cols: 2, blitter: :ascii, pxoffx: 1) }.to raise_error(Notcurses::VisualError)
        expect { visual.create_plane(rows: 2, cols: 2, x: :center) }.to raise_error(ArgumentError, /parent/)
        expect { visual.create_plane(rows: 0, cols: 2) }.to raise_error(ArgumentError)
        expect { visual.create_plane(rows: 2, cols: 2, parent: 'std') }.to raise_error(TypeError)
      end
    end

    describe '#subtitle_plane' do
      it 'restituisce nil senza sottotitoli' do
        expect(visual.subtitle_plane(nc.stdplane)).to be_nil
        described_class.open(mkv) { |v| expect(v.subtitle_plane(nc.stdplane)).to be_nil }
      end

      it 'richiede un Plane' do
        expect { visual.subtitle_plane(nil) }.to raise_error(TypeError)
      end
    end

    describe '#stream' do
      it 'chiama il blocco per ogni frame e restituisce true alla fine' do
        described_class.open(mkv) do |v|
          seen = []
          expect(v.stream(blitter: :ascii) { |plane, deadline| seen << [plane, deadline] }).to be(true)
          expect(seen.size).to eq(4)
          expect(seen.map(&:first)).to all(be_a(Notcurses::Plane))
          expect(seen.map(&:last)).to all(be_a(Float))
          expect(seen.first.first).to be_closed # piano creato da notcurses, distrutto alla fine
        end
      end

      it 'il blocco ferma lo stream con :stop' do
        described_class.open(mkv) do |v|
          calls = 0
          expect(v.stream(blitter: :ascii) { (calls += 1) == 2 ? :stop : nil }).to be(false)
          expect(calls).to eq(2)
        end
      end

      it 'senza blocco usa lo streamer di notcurses' do
        nc.stdplane.create_child(rows: 8, cols: 8) do |plane|
          described_class.open(mkv) { |v| expect(v.stream(plane: plane, blitter: :ascii, timescale: 0.01)).to be(true) }
          expect(cell(plane, 0, 0)[1]).to eq(0xffffff)
        end
      end

      it 'durante lo stream gli altri thread Ruby girano (il C rilascia il GVL)' do
        nc.stdplane.create_child(rows: 8, cols: 8) do |plane|
          described_class.open(mkv) do |v|
            ticks = 0
            ticker = Thread.new { loop { ticks += 1; sleep 0.005 } }
            sleep 0.01 until ticks.positive?
            before = ticks
            expect(v.stream(plane: plane, blitter: :ascii, timescale: 2)).to be(true) # 4 frame da 0,2 s
            during = ticks - before
            ticker.kill.join
            expect(during).to be >= 10
          end
        end
      end

      it 'rifiuta i visual non da file, che in 3.0.17 manderebbero in crash il C' do
        expect { visual.stream }.to raise_error(Notcurses::VisualError, /file/)
      end

      it 'valida le opzioni' do
        described_class.open(mkv) do |v|
          expect { v.stream(timescale: 0) }.to raise_error(ArgumentError)
          expect { v.stream(timescale: 'x') }.to raise_error(TypeError)
          expect { v.stream(plane: nc.stdplane, child: true) }.to raise_error(ArgumentError)
          expect { v.stream(begy: 1) }.to raise_error(ArgumentError)
        end
      end
    end

    describe '.blit_rgba, .blit_bgrx, .blit_rgb_loose, .blit_rgb_packed' do
      it 'disegnano pixel in memoria sul piano e lo restituiscono' do
        nc.stdplane.create_child(rows: 1, cols: 2) do |plane|
          colors = -> { [cell(plane, 0, 0)[1], cell(plane, 0, 1)[1]] }
          px = rgba([0x11, 0x22, 0x33, 0xff], [0x44, 0x55, 0x66, 0xff])
          expect(described_class.blit_rgba(px, plane: plane, rows: 1, cols: 2, blitter: :ascii)).to equal(plane)
          expect(colors.call).to eq([0x112233, 0x445566])
          described_class.blit_bgrx(px, plane: plane, rows: 1, cols: 2, blitter: :ascii)
          expect(colors.call).to eq([0x332211, 0x665544])
          described_class.blit_rgb_loose(px, plane: plane, rows: 1, cols: 2, alpha: 255, blitter: :ascii)
          expect(colors.call).to eq([0x112233, 0x445566])
          packed = rgba([0x11, 0x22, 0x33], [0x44, 0x55, 0x66])
          expect(described_class.blit_rgb_packed(packed, plane: plane, rows: 1, cols: 2, blitter: :ascii)).to equal(plane)
          expect(colors.call).to eq([0x112233, 0x445566]) # ncblit_rgb_packed darebbe 112233, 223344
        end
      end

      it 'accettano rowstride con padding, come i metodi from_*' do
        nc.stdplane.create_child(rows: 2, cols: 1) do |plane|
          px = rgba([1, 2, 3, 255], [0, 0, 0, 0], [4, 5, 6, 255], [0, 0, 0, 0])
          described_class.blit_rgba(px, plane: plane, rows: 2, cols: 1, rowstride: 8, blitter: :ascii)
          expect(cell(plane, 1, 0)[1]).to eq(0x040506)
          described_class.blit_bgrx(px, plane: plane, rows: 2, cols: 1, rowstride: 8, blitter: :ascii)
          expect(cell(plane, 1, 0)[1]).to eq(0x060504)
          described_class.blit_rgb_loose(px, plane: plane, rows: 2, cols: 1, rowstride: 8, blitter: :ascii)
          expect(cell(plane, 1, 0)[1]).to eq(0x040506)
          packed = rgba([7, 8, 9], [0, 0, 0], [10, 11, 12], [0, 0, 0])
          described_class.blit_rgb_packed(packed, plane: plane, rows: 2, cols: 1, rowstride: 6, blitter: :ascii)
          expect(cell(plane, 1, 0)[1]).to eq(0x0a0b0c)
          expect do
            described_class.blit_rgba(px, plane: plane, rows: 2, cols: 1, linesize: 8, blitter: :ascii)
          end.to raise_error(ArgumentError, /linesize/)
        end
      end

      it 'validano gli argomenti' do
        expect { described_class.blit_rgba(rgbw, plane: nil, rows: 4, cols: 2) }.to raise_error(TypeError)
        expect { described_class.blit_rgb_packed(rgbw, plane: nil, rows: 1, cols: 2) }.to raise_error(TypeError)
        expect { described_class.blit_bgrx(rgbw, plane: nc.stdplane, rows: 4, cols: 2, child: true) }.to raise_error(ArgumentError)
        expect { described_class.blit_rgb_loose(rgbw, plane: nc.stdplane, rows: 4, cols: 2, alpha: 256) }.to raise_error(ArgumentError)
        expect { described_class.blit_rgba(rgbw, plane: nc.stdplane, rows: 4, cols: 2, rowstride: 6) }.to raise_error(ArgumentError, /rowstride/)
      end

      it 'sollevano VisualError se il C fallisce' do
        expect do
          described_class.blit_rgba(rgbw, plane: nc.stdplane, rows: 4, cols: 2, blitter: :pixel, no_degrade: true)
        end.to raise_error(Notcurses::VisualError)
      end
    end

    # ICH-486: il blitter scrive ogni cella da sola, come ncplane_gradient prima di ICH-450.
    context 'su metà di un glifo largo' do
      red = [255, 0, 0, 255].pack('C*')
      blits = {
        'blit_rgba' => ->(p, x, b) { described_class.blit_rgba(red, plane: p, rows: 1, cols: 1, blitter: b, y: 0, x: x) },
        'blit_bgrx' => ->(p, x, b) { described_class.blit_bgrx(red, plane: p, rows: 1, cols: 1, blitter: b, y: 0, x: x) },
        'blit_rgb_loose' => lambda do |p, x, b|
          described_class.blit_rgb_loose(red, plane: p, rows: 1, cols: 1, blitter: b, y: 0, x: x)
        end,
        'blit_rgb_packed' => lambda do |p, x, b|
          described_class.blit_rgb_packed(red[0, 3], plane: p, rows: 1, cols: 1, blitter: b, y: 0, x: x)
        end,
        '#blit' => lambda do |p, x, b|
          described_class.from_rgba(red, rows: 1, cols: 1) { |v| v.blit(plane: p, blitter: b, y: 0, x: x) }
        end
      }
      cases = %i[ascii half quad sextant octant braille].product([2, 3])
      blits.each do |name, blit|
        it "#{name} lascia vuota l'altra metà con ogni blitter di celle (prima: \"XYZ\" nella riga sotto)" do
          cases.each do |blitter, x|
            nc.stdplane.create_child(rows: 2, cols: 4) do |p|
              p.putstr('ab漢', y: 0, x: 0)
              p.putstr('WXYZ', y: 1, x: 0)
              blit.call(p, x, blitter)
              other = x == 2 ? 3 : 2
              expect(p.at(y: 0, x: other).egc).to eq(''), "#{blitter} x=#{x}"
              p.putstr('中', y: 0, x: 2)
              expect(p.contents(y: 1, rows: 1)).to eq('WXYZ'), "#{blitter} x=#{x}"
            end
          end
        end
      end

      it 'lo script della issue stampa "WXYZ"' do
        nc.stdplane.create_child(rows: 2, cols: 4) do |pl|
          pl.putstr('ab漢', y: 0, x: 0)
          pl.putstr('WXYZ', y: 1, x: 0)
          described_class.blit_rgba("\xff\x00\x00\xff".b, plane: pl, rows: 1, cols: 1, blitter: :ascii, y: 0, x: 2)
          pl.putstr('中', y: 0, x: 2)
          expect(pl.contents(y: 1, rows: 1)).to eq('WXYZ')
        end
      end

      it 'senza glifi larghi sotto il blit disegna come prima' do
        nc.stdplane.create_child(rows: 1, cols: 4) do |p|
          p.putstr('ab漢', y: 0, x: 0)
          described_class.blit_rgba(rgba([0x11, 0x22, 0x33, 0xff]), plane: p, rows: 1, cols: 1, blitter: :ascii, y: 0, x: 1)
          expect(p.contents).to eq('a 漢')
          expect(cell(p, 0, 1)[1]).to eq(0x112233)
        end
      end

      # ICH-549: il controllo legge i glifi sui lati del rettangolo del blit, non tutte le celle del piano
      # (prima: 60x200 celle lette per un blit 1x1).
      def cell_reads
        reads = 0
        allow(ffi).to receive(:ncplane_at_yx_cell).and_wrap_original do |original, *args|
          reads += 1
          original.call(*args)
        end
        yield
        reads
      end

      it "le celle lette dipendono dall'area del blit, non dall'area del piano" do
        reads = [[4, 8], [60, 200]].map do |rows, cols|
          nc.stdplane.create_child(rows: rows, cols: cols) do |p|
            one = cell_reads { described_class.blit_rgba(red, plane: p, rows: 1, cols: 1, blitter: :ascii, y: 0, x: 0) }
            three = cell_reads do
              described_class.blit_rgba(red * 9, plane: p, rows: 3, cols: 3, blitter: :ascii, y: 0, x: 0)
            end
            whole = cell_reads do
              described_class.from_rgba(red, rows: 1, cols: 1) { |v| v.blit(plane: p, blitter: :half, scale: :stretch) }
            end
            [one, three, whole]
          end
        end
        expect(reads[0][0, 2]).to eq(reads[1][0, 2])
        expect(reads[1][0]).to be <= 4 # una riga, due lati
        expect(reads[1][1]).to be <= 12
        expect(reads[1][2]).to be <= 60 * 4 # il piano intero: le righe, non le celle
      end

      # braille_blit non tocca una cella con soli pixel trasparenti (blit.c:1203-1206): sotto un'immagine con
      # trasparenze un glifo largo resta coperto a metà anche dentro il rettangolo, non solo sui lati.
      it 'il blitter :braille con pixel trasparenti non lascia metà orfane dentro il rettangolo' do
        on = [255, 0, 0, 255]
        off = [0, 0, 0, 0]
        # celle 0, 1 e 2 del blit (4 righe x 2 colonne di pixel per cella); il glifo sta nelle celle 1 e 2
        { 2 => [on, on, off], 1 => [on, off, on] }.each do |orphan, cells|
          nc.stdplane.create_child(rows: 2, cols: 5) do |p|
            p.putstr('a漢bc', y: 0, x: 0)
            p.putstr('VWXYZ', y: 1, x: 0)
            pixels = rgba(cells.flat_map { |c| [c, c] } * 4)
            described_class.blit_rgba(pixels, plane: p, rows: 4, cols: 6, blitter: :braille, y: 0, x: 0)
            expect(p.at(y: 0, x: orphan).egc).to eq(''), "cella #{orphan}"
            p.putstr('中', y: 0, x: 1)
            expect(p.contents(y: 1, rows: 1)).to eq('VWXYZ'), "cella #{orphan}"
          end
        end
      end

      it 'il rettangolo segue y: e x: simbolici, lo scaling e la regione del visual' do
        one = ->(p, **o) { described_class.blit_rgba(red, plane: p, rows: 1, cols: 1, blitter: :ascii, **o) }
        region = lambda do |p|
          described_class.from_rgba(red * 2, rows: 1, cols: 2) { |v| v.blit(plane: p, blitter: :ascii, begx: 1, lenx: 1, x: 2) }
        end
        # testo della riga con il glifo, riga del glifo, blit, cella che deve restare vuota
        [
          ['ab漢', 0, ->(p) { one.call(p, y: 0, x: :right) }, 2],
          ['ab漢cd', 0, ->(p) { one.call(p, y: 0, x: :center) }, 3],
          ['ab漢', 2, ->(p) { one.call(p, y: :bottom, x: 3) }, 2],
          ['ab漢', 0, ->(p) { one.call(p, y: 0, x: 3, scale: :stretch) }, 2],
          ['ab漢', 0, ->(p) { one.call(p, y: 0, x: 3, scale: :scale) }, 2],
          ['ab漢', 0, region, 3]
        ].each_with_index do |(text, row, blit, empty), i|
          nc.stdplane.create_child(rows: 3, cols: text.length + 1) do |p|
            p.putstr(text, y: row, x: 0)
            blit.call(p)
            expect(p.at(y: row, x: empty).egc).to eq(''), "caso #{i}"
            expect(p.at(y: row, x: 0).egc).to eq('a'), "caso #{i}"
          end
        end
      end

      it "la scrittura larga sull'ultima riga non corrompe l'heap (prima: abort di glibc)" do
        skip 'serve libc_malloc_debug di glibc' unless File.exist?(NcHelpers::MALLOC_DEBUG)
        script = <<~'RUBY'
          require 'notcurses'
          Notcurses::Context.open(output: '/dev/null', termtype: 'xterm-256color', suppress_banners: true,
                                  drain_input: true) do |nc|
            red = "\xff\x00\x00\xff".b
            planes = Array.new(20) { nc.stdplane.create_child(rows: 1, cols: 4).tap { |q| q.putstr('ab漢', y: 0, x: 0) } }
            planes.each { |q| Notcurses::Visual.blit_rgba(red, plane: q, rows: 1, cols: 1, blitter: :ascii, y: 0, x: 2) }
            planes.each { |q| q.putstr('中', y: 0, x: 2) }
            planes.each(&:close)
          end
          puts 'ok'
        RUBY
        expect(NcHelpers.heap_check(script)).to eq([0, "ok\n"])
      end
    end

    describe 'i blitter dei plot (:four_by_one, :eight_by_one)' do
      # Senza quadranti il C li degrada a :half; con i quadranti taglia l'immagine.
      it 'blit, geometry, create_plane, stream e i blit_* li rifiutano prima del C' do
        %i[four_by_one eight_by_one].each do |b|
          expect { visual.blit(blitter: b) }.to raise_error(ArgumentError, /blitter/)
          expect { visual.geometry(blitter: b) }.to raise_error(ArgumentError, /blitter/)
          expect { visual.create_plane(rows: 2, cols: 2, blitter: b) }.to raise_error(ArgumentError, /blitter/)
          described_class.open(mkv) { |v| expect { v.stream(blitter: b) {} }.to raise_error(ArgumentError, /blitter/) }
          nc.stdplane.create_child(rows: 4, cols: 2) do |plane|
            args = { plane: plane, rows: 4, cols: 2, blitter: b }
            expect { described_class.blit_rgba(rgbw, **args) }.to raise_error(ArgumentError, /blitter/)
            expect { described_class.blit_bgrx(rgbw, **args) }.to raise_error(ArgumentError, /blitter/)
            expect { described_class.blit_rgb_loose(rgbw, **args) }.to raise_error(ArgumentError, /blitter/)
            expect { described_class.blit_rgb_packed("\0" * 24, **args) }.to raise_error(ArgumentError, /blitter/)
          end
        end
      end
    end
  end

  context 'con i quadranti (rxvt-256color, come Kitty e Ghostty)' do
    it 'from_plane e as_rgba rifiutano i blitter dei plot invece di andare in SIGSEGV' do
      # Su macOS notcurses non riconosce rxvt da TERM (unix_early_matches è dentro
      # #ifndef __APPLE__, termdesc.c:1137-1155): senza un terminale vero niente quadranti.
      skip 'rxvt-256color attiva i quadranti solo fuori da macOS' if ::FFI::Platform.mac?
      # Il blitset 4x1/8x1 ha egcs NULL (blit.c:1279, 1282): prima del fix il figlio moriva con 139.
      script = <<~'RUBY'
        require 'notcurses'
        Notcurses::Context.open(output: '/dev/null', termtype: 'rxvt-256color', suppress_banners: true,
                                drain_input: true) do |nc|
          abort 'niente quadranti' unless nc.can_quadrant?
          nc.stdplane.create_child(rows: 1, cols: 1) do |pl|
            pl.putstr(' ', y: 0, x: 0)
            [:four_by_one, :eight_by_one, Notcurses::FFI::NCBLIT_4x1, Notcurses::FFI::NCBLIT_8x1].each do |b|
              begin
                Notcurses::Visual.from_plane(pl, blitter: b)
                abort "from_plane(#{b.inspect}) non ha sollevato"
              rescue ArgumentError
              end
              begin
                pl.as_rgba(b)
                abort "as_rgba(#{b.inspect}) non ha sollevato"
              rescue ArgumentError
              end
            end
          end
        end
        puts 'ok'
      RUBY
      lib = File.expand_path('../../lib', __dir__)
      out, status = Open3.capture2e({ 'TERM' => 'xterm-256color' }, NcHelpers::TIMEOUT, '-k', '5', '-s', 'KILL', '30',
                                    RbConfig.ruby, '-I', lib, '-e', script, stdin_data: '')
      expect([status.exitstatus, out]).to eq([0, "ok\n"])
    end
  end

  context 'quando il contesto si chiude' do
    it 'i visual aperti vengono chiusi prima di notcurses_stop' do
      v = nil
      NcHelpers.open_context { v = described_class.from_rgba(rgbw, rows: 4, cols: 2) }
      expect(v).to be_closed
      expect { v.dims }.to raise_error(Notcurses::ClosedError)
      expect(v.close).to be_nil
    end
  end
end
