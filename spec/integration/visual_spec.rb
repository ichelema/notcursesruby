# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative '../support/nc_helpers'

# Flussi completi di Notcurses::Visual. Le fixture (spec/fixtures/visual/) sono
# descritte in spec/notcurses/visual_spec.rb: rgbw.png (2x4, righe rossa,
# verde, blu, bianca) e frames.mkv (8x8, 4 frame rosso, verde, blu, bianco).
RSpec.describe 'Notcurses::Visual (integrazione)' do
  fixtures = File.expand_path('../fixtures/visual', __dir__)

  let(:png) { File.join(fixtures, 'rgbw.png') }
  let(:mkv) { File.join(fixtures, 'frames.mkv') }
  let(:frame_colors) { [0xff0000, 0x00ff00, 0x0000ff, 0xffffff] }

  # Colore di sfondo della cella (y, x), letto con il C.
  def bg(plane, y, x)
    c = Notcurses::FFI::NcCell.new
    Notcurses::FFI.ncplane_at_yx_cell(plane.to_ptr, y, x, c)
    Notcurses::FFI.nccell_release(plane.to_ptr, c)
    c[:channels] & 0xffffff
  end

  # [pile, piani] secondo notcurses_debug
  def census(nc)
    text = nc.debug
    [text.scan(/ pile \*/).size, text.lines.grep(/\A\d{4} off/).size]
  end

  context 'con un contesto' do
    include_context 'con un contesto notcurses'

    it 'da pixel costruiti in Ruby a un piano esistente, poi sullo schermo' do
      pixels = Array.new(3) { |y| Array.new(4) { |x| Notcurses::Pixel.rgb(y * 100, x * 60, 7) } }
      data = pixels.flatten.map(&:value).pack('L*')
      plane = nc.stdplane.create_child(rows: 3, cols: 4, y: 1, x: 1)
      Notcurses::Visual.from_rgba(data, rows: 3, cols: 4) do |visual|
        visual.set(2, 3, Notcurses::Pixel.rgb(1, 2, 3))
        expect(visual.blit(plane: plane, blitter: :ascii)).to equal(plane)
      end
      nc.render
      expect(bg(plane, 1, 2)).to eq((100 << 16) | (120 << 8) | 7)
      expect(bg(plane, 2, 3)).to eq(0x010203) # il piano resta disegnato dopo la chiusura del visual
      plane.close
    end

    it 'da file: geometria, piano preparato con quella geometria, piano figlio creato dal blit' do
      before = census(nc)
      Notcurses::Visual.open(png) do |visual|
        geom = visual.geometry(blitter: :half)
        expect([geom.pixy, geom.pixx, geom.rcelly, geom.rcellx, geom.blitter]).to eq([4, 2, 2, 2, :half])

        nc.stdplane.create_child(rows: geom.rcelly, cols: geom.rcellx) do |plane|
          visual.blit(plane: plane, blitter: :half)
          expect([bg(plane, 0, 0), bg(plane, 1, 1)]).to eq([0x00ff00, 0xffffff]) # metà inferiore delle celle
        end

        child = visual.blit(plane: nc.stdplane, child: true, blitter: :ascii, y: :bottom, x: :right)
        rows, cols = nc.stdplane.dims
        expect(child.yx).to eq([rows - 4, cols - 2])
        expect(census(nc)).to eq([before[0], before[1] + 1])
        child.close
      end
      expect(census(nc)).to eq(before)
    end

    it 'una regione disegnata con scaling resta la regione chiesta' do
      Notcurses::Visual.open(png) do |visual|
        nc.stdplane.create_child(rows: 4, cols: 4) do |plane|
          visual.blit(plane: plane, blitter: :ascii, begy: 2, leny: 2, scale: :stretch)
          expect((0..3).map { |y| bg(plane, y, 3) }).to eq([0x0000ff, 0x0000ff, 0xffffff, 0xffffff])
        end
      end
    end

    it 'decodifica tutti i frame di un video e li disegna uno per uno' do
      seen = []
      nc.stdplane.create_child(rows: 8, cols: 8) do |plane|
        Notcurses::Visual.open(mkv) do |video|
          loop do
            video.blit(plane: plane, blitter: :ascii)
            seen << [video.at(7, 7).to_a.take(3), bg(plane, 7, 7)]
            break unless video.decode
          end
          expect(video.decode).to be(false)
          expect(video.decode_loop).to be(false) # riavvolto: di nuovo il primo frame
          expect(video.at(0, 0)).to eq(Notcurses::Pixel.rgb(255, 0, 0))
        end
      end
      expect(seen.map(&:last)).to eq(frame_colors)
      expect(seen.map(&:first)).to eq(frame_colors.map { |c| [c >> 16, (c >> 8) & 0xff, c & 0xff] })
    end

    it 'stream con callback: un frame per chiamata, piano di notcurses distrutto alla fine' do
      before = census(nc)
      colors = []
      planes = []
      Notcurses::Visual.open(mkv) do |video|
        done = video.stream(blitter: :ascii) do |plane, deadline|
          expect(deadline).to be <= Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
          planes << plane
          colors << bg(plane, 0, 0)
        end
        expect(done).to be(true)
      end
      expect(colors).to eq(frame_colors)
      expect(planes.uniq.size).to eq(1)
      expect(planes.first).to be_closed
      expect(census(nc)).to eq(before)
    end

    it 'stream in un piano dell\'utente: il piano resta vivo e con l\'ultimo frame' do
      nc.stdplane.create_child(rows: 8, cols: 8) do |plane|
        Notcurses::Visual.open(mkv) do |video|
          yielded = []
          video.stream(plane: plane, blitter: :ascii) { |p, _| yielded << p }
          expect(yielded).to all(equal(plane))
        end
        expect(plane).not_to be_closed
        expect(bg(plane, 0, 0)).to eq(0xffffff)
      end
    end

    it 'un\'eccezione nel callback ferma lo stream, esce da stream e lascia il contesto usabile' do
      before = census(nc)
      calls = 0
      Notcurses::Visual.open(mkv) do |video|
        expect do
          video.stream(blitter: :ascii) do
            calls += 1
            raise IOError, 'interrotto dal callback'
          end
        end.to raise_error(IOError, 'interrotto dal callback')
      end
      expect(calls).to eq(1)
      expect(census(nc)).to eq(before) # il piano creato dallo stream è stato distrutto
      expect(nc.callback_errors).to be_empty
      plane = nc.stdplane.create_child(rows: 1, cols: 1)
      expect(plane.close).to be_nil # fuori dal callback i piani si distruggono di nuovo
      expect(nc.render).to equal(nc)
    end

    it 'dentro il callback dello stream non si chiudono il visual né i piani' do
      nc.stdplane.create_child(rows: 8, cols: 8) do |plane|
        Notcurses::Visual.open(mkv) do |video|
          expect { video.stream(plane: plane, blitter: :ascii) { video.close } }.to raise_error(Notcurses::VisualError)
          expect(video).not_to be_closed
          expect { video.stream(plane: plane, blitter: :ascii) { plane.close } }.to raise_error(Notcurses::PlaneError)
          expect(plane).not_to be_closed
        end
      end
    end

    it 'create_plane e i blit di buffer: i piani creati sono del chiamante' do
      before = census(nc)
      Notcurses::Visual.open(png) do |visual|
        plane = visual.create_plane(rows: 2, cols: 2, parent: nc.stdplane, y: :center, x: :center, blitter: :half)
        expect(census(nc)).to eq([before[0], before[1] + 1])
        expect(bg(plane, 1, 0)).to eq(0xffffff)
        rgb = [0x11, 0x22, 0x33] * 4
        Notcurses::Visual.blit_rgb_packed(rgb.pack('C*'), plane: plane, rows: 2, cols: 2, blitter: :ascii)
        expect(bg(plane, 1, 1)).to eq(0x112233)
        expect(census(nc)).to eq([before[0], before[1] + 1]) # i blit di buffer non creano piani
        plane.close
      end
      expect(census(nc)).to eq(before)
    end
  end

  context 'ciclo di vita con il contesto' do
    it 'Context#close distrugge i visual e i piani creati dai blit ancora aperti' do
      visual = nil
      planes = nil
      NcHelpers.open_context do |nc|
        visual = Notcurses::Visual.from_file(png)
        planes = [visual.blit(blitter: :ascii), visual.blit(plane: nc.stdplane, child: true, blitter: :ascii)]
      end
      expect(visual).to be_closed
      expect(planes).to all(be_closed)
      expect { visual.blit }.to raise_error(Notcurses::ClosedError)
      expect(visual.close).to be_nil
    end

    it 'Context#drop_planes chiude anche i visual (sono figli adottati dal contesto)' do
      NcHelpers.open_context do |nc|
        visual = Notcurses::Visual.from_rgba("\xff".b * 4, rows: 1, cols: 1)
        child = visual.blit(plane: nc.stdplane, child: true, blitter: :ascii)
        nc.drop_planes
        expect(child).to be_closed
        expect(visual).to be_closed
      end
    end

    it 'un visual sopravvive ai piani su cui è stato disegnato' do
      NcHelpers.open_context do |nc|
        Notcurses::Visual.open(png) do |visual|
          visual.blit(plane: nc.stdplane, child: true, blitter: :ascii).close
          expect(visual.at(3, 0)).to eq(Notcurses::Pixel.rgb(255, 255, 255))
        end
      end
    end
  end
end
