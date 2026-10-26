# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/direct.h
# frozen_string_literal: true

require 'fileutils'
require 'rbconfig'
require 'tmpdir'
require_relative '../support/nc_helpers'

# Helper delle spec di Notcurses::Direct: contesti su /dev/null o su un file
# temporaneo (mai un TTY), terminfo fisso, input scartato.
module DirectSpecHelpers
  OPTIONS = { output: '/dev/null', termtype: 'xterm-256color', drain_input: true }.freeze
  DATA_DIR = File.expand_path('../../notcurses/data', __dir__)
  LIB_DIR = File.expand_path('../../lib', __dir__)

  module_function

  # @return [Notcurses::Direct, Object] il contesto, o il valore del blocco
  def open_direct(**opts, &block) = Notcurses::Direct.open(**OPTIONS, **opts, &block)

  def data_file(name) = File.join(DATA_DIR, name)

  # GIF 1x1 con due frame (bianco, poi nero): codici LZW scritti a mano.
  def write_two_frame_gif(path)
    frame = lambda do |lzw|
      "\x21\xF9\x04\x00\x0A\x00\x00\x00".b + "\x2C\x00\x00\x00\x00\x01\x00\x01\x00\x00".b +
        "\x02\x02".b + lzw + "\x00".b
    end
    gif = "GIF89a\x01\x00\x01\x00\x80\x00\x00".b + "\xFF\xFF\xFF\x00\x00\x00".b +
          frame.call("\x44\x01".b) + frame.call("\x4C\x01".b) + "\x3B".b
    File.binwrite(path, gif)
    path
  end
end

RSpec.describe Notcurses::Direct do
  include DirectSpecHelpers

  let(:ffi) { Notcurses::FFI }
  let(:red) { Notcurses::Channels.new.with_fg_rgb(255, 0, 0) }
  let(:blue) { Notcurses::Channels.new.with_fg_rgb(0, 0, 255) }

  describe 'ciclo di vita' do
    it 'open con un blocco restituisce il valore del blocco e chiude il contesto' do
      direct = nil
      result = open_direct do |d|
        direct = d
        expect(Notcurses.active_context).to equal(d)
        expect(d.pid).to eq(Process.pid)
        :fatto
      end
      expect(result).to eq(:fatto)
      expect(direct).to be_closed
      expect(Notcurses.active_context).to be_nil
    end

    it 'open chiude il contesto anche se il blocco solleva' do
      direct = nil
      expect do
        open_direct do |d|
          direct = d
          raise 'boom'
        end
      end.to raise_error(RuntimeError, 'boom')
      expect(direct).to be_closed
      expect(Notcurses.active_context).to be_nil
    end

    it 'close è idempotente, stop è un alias, e dopo la chiusura ogni metodo solleva ClosedError' do
      d = open_direct
      expect(d.close).to be_nil
      expect(d.stop).to be_nil
      expect(d).to be_closed
      expect(Notcurses.active_context).to be_nil
      expect(d.inspect).to include('chiuso')
      png = data_file('onedot.png')
      calls = [
        [:set_fg_rgb, 1, 2, 3], [:set_bg_rgb, 1, 2, 3], [:set_fg_rgb24, 1], [:set_bg_rgb24, 1],
        [:set_fg_palindex, 1], [:set_bg_palindex, 1], [:set_fg_default], [:set_bg_default], [:palette_size],
        [:supported_styles], [:styles], [:styles=, :bold], [:on_styles, :bold], [:off_styles, :bold],
        [:putstr, 'x'], [:putegc, 'x'], [:print_aligned, 'x'], [:flush], [:dims], [:clear], [:move_cursor],
        [:cursor_enable], [:cursor_disable], [:cursor_up], [:cursor_down], [:cursor_left], [:cursor_right],
        [:cursor_yx], [:cursor_push], [:cursor_pop], [:hline, '-', 1], [:vline, '|', 1], [:box, 2, 2], [:get],
        [:inputready_fd], [:readline], [:render_image, png], [:render_frame, png], [:load_image, png],
        [:stream, png], [:capabilities], [:detected_terminal], [:can_utf8?], [:can_truecolor?],
        [:can_change_color?], [:can_fade?], [:can_open_images?], [:can_open_videos?], [:can_halfblock?],
        [:can_quadrant?], [:can_sextant?], [:can_octant?], [:can_braille?], [:can_pixel?], [:can_get_cursor?]
      ]
      calls.each do |name, *args|
        expect { d.public_send(name, *args) }.to raise_error(Notcurses::ClosedError), name.to_s
      end
      expect { d.to_ptr }.to raise_error(Notcurses::ClosedError)
    end

    it 'un Direct attivo impedisce un secondo Direct e un Context senza chiamare il C' do
      open_direct do |d|
        allow(ffi).to receive(:ncdirect_init).and_call_original
        allow(ffi).to receive(:ncdirect_core_init).and_call_original
        allow(ffi).to receive(:notcurses_init).and_call_original
        expect { open_direct }.to raise_error(Notcurses::InitError, /Direct è già attivo/)
        expect { open_direct(core: true) }.to raise_error(Notcurses::InitError, /già attivo/)
        expect { NcHelpers.open_context }.to raise_error(Notcurses::InitError, /Direct è già attivo/)
        expect(ffi).not_to have_received(:ncdirect_init)
        expect(ffi).not_to have_received(:ncdirect_core_init)
        expect(ffi).not_to have_received(:notcurses_init)
        expect(Notcurses.active_context).to equal(d)
      end
      expect(Notcurses.active_context).to be_nil
    end

    it 'un Context attivo impedisce un Direct senza chiamare il C' do
      NcHelpers.open_context do |nc|
        allow(ffi).to receive(:ncdirect_init).and_call_original
        expect { open_direct }.to raise_error(Notcurses::InitError, /Context è già attivo/)
        expect(ffi).not_to have_received(:ncdirect_init)
        expect(Notcurses.active_context).to equal(nc)
      end
      open_direct { |d| expect(d).not_to be_closed }
    end

    it 'con un termtype inesistente solleva InitError e ripristina TERM' do
      before = ENV.fetch('TERM', nil)
      expect { open_direct(termtype: 'terminale-inesistente-xyz') }.to raise_error(Notcurses::InitError)
      expect(ENV.fetch('TERM', nil)).to eq(before)
      expect(Notcurses.active_context).to be_nil
      open_direct { |d| expect(d).not_to be_closed }
    end

    it 'valida le opzioni prima di avviare notcurses' do
      allow(ffi).to receive(:ncdirect_init).and_call_original
      expect { open_direct(output: 42) }.to raise_error(TypeError)
      expect { open_direct(output: ::FFI::Pointer::NULL) }.to raise_error(ArgumentError)
      expect { open_direct(termtype: 42) }.to raise_error(TypeError)
      expect { open_direct(core: 'no') }.to raise_error(TypeError)
      expect { open_direct(drain_input: nil) }.to raise_error(TypeError)
      expect { open_direct(verbose: 1) }.to raise_error(TypeError)
      expect { open_direct(colori: true) }.to raise_error(ArgumentError)
      expect { open_direct(output: '/percorso/inesistente/out') }.to raise_error(Notcurses::InitError, /fopen/)
      expect(ffi).not_to have_received(:ncdirect_init)
      expect(Notcurses.active_context).to be_nil
    end

    it 'passa al C i flag NCDIRECT_OPTION_* delle opzioni' do
      allow(ffi).to receive(:ncdirect_init).and_return(::FFI::Pointer::NULL)
      expect do
        Notcurses::Direct.new(output: '/dev/null', inhibit_setlocale: true, inhibit_cbreak: true,
                              no_quit_sighandlers: false, verbose: true, very_verbose: true)
      end.to raise_error(Notcurses::InitError, /NULL/)
      expected = ffi::NCDIRECT_OPTION_INHIBIT_SETLOCALE | ffi::NCDIRECT_OPTION_INHIBIT_CBREAK |
                 ffi::NCDIRECT_OPTION_VERBOSE | ffi::NCDIRECT_OPTION_VERY_VERBOSE
      expect(ffi).to have_received(:ncdirect_init).with(nil, an_instance_of(::FFI::Pointer), expected)
      expect(Notcurses.active_context).to be_nil

      allow(ffi).to receive(:ncdirect_init).and_call_original
      open_direct(output: nil) { |d| expect(d).not_to be_closed }
      default = ffi::NCDIRECT_OPTION_DRAIN_INPUT | ffi::NCDIRECT_OPTION_NO_QUIT_SIGHANDLERS
      expect(ffi).to have_received(:ncdirect_init).with('xterm-256color', ::FFI::Pointer::NULL, default)
    end

    it 'core: true usa ncdirect_core_init' do
      allow(ffi).to receive(:ncdirect_core_init).and_call_original
      open_direct(core: true) { |d| expect(d.dims).to eq([24, 80]) }
      expect(ffi).to have_received(:ncdirect_core_init).once
    end

    it 'accetta un FILE* del chiamante e non lo chiude' do
      fp = ffi.fopen('/dev/null', 'w')
      open_direct(output: fp) { |d| d.putstr('x').flush }
      # se il wrapper lo avesse chiuso, questo sarebbe un secondo fclose
      expect(ffi.fclose(fp)).to eq(0)
    end

    it 'close riporta colori e stili ai default sull\'output prima di ncdirect_stop' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'out')
        start = nil
        open_direct(output: path) do |d|
          d.set_fg_rgb(1, 2, 3).set_bg_palindex(4).on_styles(:bold).flush
          start = File.size(path)
        end
        expect(File.binread(path, nil, start)).to eq("\e[39m\e[49m\e[22m")
      end
    end

    it 'un Direct rimasto aperto viene chiuso all\'uscita del processo (at_exit)' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'out')
        script = "require 'notcurses'; d = Notcurses::Direct.new(output: #{path.inspect}, " \
                 "termtype: 'xterm-256color', drain_input: true); d.set_fg_rgb(1, 2, 3)"
        pid = spawn(RbConfig.ruby, '-I', DirectSpecHelpers::LIB_DIR, '-e', script,
                    in: File::NULL, out: File::NULL, err: File::NULL)
        _, status = Process.wait2(pid)
        expect(status.exitstatus).to eq(0)
        expect(File.binread(path)).to eq("\e[38;2;1;2;3m\e[39m")
      end
    end
  end

  describe 'con un contesto su file' do
    before(:all) do
      @dir = Dir.mktmpdir
      @path = File.join(@dir, 'out')
      @gif = write_two_frame_gif(File.join(@dir, 'due.gif'))
      @d = open_direct(output: @path)
    end

    after(:all) do
      @d&.close
      FileUtils.remove_entry(@dir) if @dir
    end

    # ogni esempio parte da colori e stili di default
    before { @d.putstr('', channels: 0).styles = 0 }

    let(:d) { @d }

    # Byte scritti sull'output durante il blocco.
    def written
      @d.flush
      start = File.size(@path)
      yield
      @d.flush
      File.binread(@path, nil, start).force_encoding(Encoding::UTF_8)
    end

    describe 'colori' do
      it 'set_fg_rgb, set_bg_rgb, set_fg_rgb24 e set_bg_rgb24 scrivono colori RGB e restituiscono self' do
        expect(written { expect(d.set_fg_rgb(1, 2, 3)).to equal(d) }).to eq("\e[38;2;1;2;3m")
        expect(written { expect(d.set_bg_rgb(4, 5, 6)).to equal(d) }).to eq("\e[48;2;4;5;6m")
        expect(written { expect(d.set_fg_rgb24(0x102030)).to equal(d) }).to eq("\e[38;2;16;32;48m")
        expect(written { expect(d.set_bg_rgb24(0x405060)).to equal(d) }).to eq("\e[48;2;64;80;96m")
      end

      it 'set_fg_palindex e set_bg_palindex usano la palette' do
        expect(written { d.set_fg_palindex(5).set_bg_palindex(7) }).to eq("\e[35m\e[47m")
        expect(written { d.set_fg_palindex(200).set_bg_palindex(200) }).to eq("\e[38;5;200m\e[48;5;200m")
      end

      it 'set_fg_default e set_bg_default tornano ai colori del terminale' do
        d.set_fg_rgb(9, 9, 9).set_bg_rgb(8, 8, 8)
        expect(written { expect(d.set_fg_default.set_bg_default).to equal(d) }).to eq("\e[39m\e[49m")
        expect(written { d.set_fg_default }).to eq('')
      end

      it 'rifiuta componenti, valori e indici fuori intervallo' do
        expect { d.set_fg_rgb(256, 0, 0) }.to raise_error(ArgumentError)
        expect { d.set_bg_rgb(0, -1, 0) }.to raise_error(ArgumentError)
        expect { d.set_fg_rgb('1', 0, 0) }.to raise_error(TypeError)
        expect { d.set_fg_rgb24(0x1000000) }.to raise_error(ArgumentError)
        expect { d.set_bg_rgb24(nil) }.to raise_error(TypeError)
        expect { d.set_fg_palindex(256) }.to raise_error(ArgumentError)
        expect { d.set_bg_palindex(-1) }.to raise_error(ArgumentError)
      end

      it 'palette_size restituisce i colori del terminale' do
        expect(d.palette_size).to eq(256)
      end
    end

    describe 'stili' do
      it 'supported_styles elenca gli stili di xterm-256color' do
        expect(d.supported_styles).to contain_exactly(:italic, :underline, :bold, :struck)
      end

      it 'styles=, on_styles e off_styles cambiano gli stili attivi letti da styles, come in Plane' do
        expect(written { d.styles = :bold }).to eq("\e[1m")
        expect(d.styles).to eq([:bold])
        expect(written { expect(d.on_styles(:italic)).to equal(d) }).to eq("\e[3m")
        expect(d.styles).to eq(%i[italic bold])
        expect(written { expect(d.off_styles(:bold)).to equal(d) }).to eq("\e[22m")
        expect(d.styles).to eq([:italic])
        d.styles = []
        expect(d.styles).to eq([])
        d.styles = ffi::NCSTYLE_UNDERLINE
        expect(d.styles).to eq([:underline])
        expect(d.on_styles(:bold, %i[italic]).styles).to contain_exactly(:underline, :bold, :italic)
        expect(d.off_styles(:bold, :italic).styles).to eq([:underline])
        expect(d).not_to respond_to(:set_styles)
      end

      it 'rifiuta gli stili non supportati prima della chiamata C' do
        allow(ffi).to receive(:ncdirect_set_styles).and_call_original
        expect { d.styles = :undercurl }.to raise_error(ArgumentError, /undercurl/)
        expect { d.on_styles(0x8000) }.to raise_error(ArgumentError, /0x8000/)
        expect { d.on_styles(:bold, :undercurl) }.to raise_error(ArgumentError, /undercurl/)
        expect { d.styles = :lampeggiante }.to raise_error(ArgumentError)
        expect { d.styles = 'bold' }.to raise_error(TypeError)
        expect(ffi).not_to have_received(:ncdirect_set_styles)
        expect(d.off_styles(:undercurl)).to equal(d)
      end
    end

    describe 'output' do
      it 'putstr scrive il testo con i colori di channels e restituisce self' do
        d.set_fg_rgb(1, 1, 1)
        expect(written { expect(d.putstr('ciao')).to equal(d) }).to eq("\e[39mciao")
        expect(written { d.putstr('rosso', channels: red) }).to eq("\e[38;2;255;0;0mrosso")
        expect(written { d.putstr('ancora', channels: red.value) }).to eq('ancora')
      end

      it 'putstr valida testo e canali' do
        expect { d.putstr(nil) }.to raise_error(TypeError)
        expect { d.putstr("a\0b") }.to raise_error(ArgumentError)
        expect { d.putstr('x', channels: 'rosso') }.to raise_error(TypeError)
        expect { d.putstr('x', channels: -1) }.to raise_error(ArgumentError)
      end

      it 'putegc scrive solo il primo EGC e ne restituisce colonne e byte' do
        expect(written { expect(d.putegc("中x")).to eq([2, 3]) }).to eq('中')
        expect(d.putegc("e\u0301x")).to eq([1, 3]) # e + accento combinante: un EGC di 3 byte
        expect(d.putegc('')).to eq([0, 0])
        expect { d.putegc("\x01") }.to raise_error(ArgumentError, /controllo/)
        expect { d.putegc(nil) }.to raise_error(TypeError)
      end

      it 'print_aligned allinea il testo sulla riga y e restituisce le colonne (sull\'output, non su stdout)' do
        expect(written { expect(d.print_aligned('ciao', y: 2, align: :right)).to eq(4) }).to eq("\e[3;77Hciao")
        expect(written { d.print_aligned('ciao', y: 2, align: :center) }).to eq("\e[3;39Hciao")
        expect(written { d.print_aligned('ciao') }).to eq("\e[1Gciao")
        expect(written { d.print_aligned('x' * 100, y: 1, align: :right) }).to eq("\e[2;1H#{'x' * 100}")
        expect(written { d.print_aligned('中', y: 0, align: :right, channels: red) })
          .to eq("\e[1;79H\e[38;2;255;0;0m中")
      end

      it 'print_aligned valida gli argomenti' do
        expect { d.print_aligned('x', align: :unaligned) }.to raise_error(ArgumentError)
        expect { d.print_aligned('x', align: :top) }.to raise_error(ArgumentError)
        expect { d.print_aligned("a\x01") }.to raise_error(ArgumentError, /controllo/)
        expect { d.print_aligned('x', y: -1) }.to raise_error(ArgumentError)
        expect { d.print_aligned(:x) }.to raise_error(TypeError)
      end

      it 'flush svuota il buffer e restituisce self' do
        d.putstr('buffer')
        expect(d.flush).to equal(d)
        expect(File.binread(@path)).to end_with('buffer')
      end
    end

    describe 'schermo e cursore' do
      it 'dims restituisce 24x80 senza un terminale' do
        expect(d.dims).to eq([24, 80])
      end

      it 'clear pulisce lo schermo' do
        expect(written { expect(d.clear).to equal(d) }).to eq("\e[H\e[2J")
      end

      it 'move_cursor sposta il cursore su uno o due assi; senza argomenti non fa nulla' do
        expect(written { expect(d.move_cursor(y: 3, x: 4)).to equal(d) }).to eq("\e[4;5H")
        expect(written { d.move_cursor(x: 7) }).to eq("\e[8G")
        allow(ffi).to receive(:ncdirect_cursor_move_yx).and_call_original
        expect(written { expect(d.move_cursor).to equal(d) }).to eq('')
        expect(ffi).not_to have_received(:ncdirect_cursor_move_yx)
      end

      it 'move_cursor(y:) senza un terminale che riporti il cursore solleva invece di perdere la colonna' do
        expect { d.move_cursor(y: 5) }.to raise_error(Notcurses::DirectError, /colonna/)
        expect { d.move_cursor(y: -1, x: 0) }.to raise_error(ArgumentError)
        expect { d.move_cursor(x: 2**31) }.to raise_error(ArgumentError)
        expect { d.move_cursor(x: 'a') }.to raise_error(TypeError)
      end

      it 'cursor_up, cursor_down, cursor_left e cursor_right spostano di count (default 1)' do
        expect(written { expect(d.cursor_up(count: 3)).to equal(d) }).to eq("\e[3A")
        expect(written { d.cursor_up }).to eq("\e[1A")
        expect(written { d.cursor_left(count: 2).cursor_right(count: 2) }).to eq("\e[2D\e[2C")
        expect(written { d.cursor_down(count: 2) }).to eq("\v\v")
        expect(written { d.cursor_down.cursor_left.cursor_right }).to eq("\v\e[1D\e[1C")
        expect(written { d.cursor_up(count: 0).cursor_down(count: 0).cursor_left(count: 0).cursor_right(count: 0) }).to eq('')
        %i[cursor_up cursor_down cursor_left cursor_right].each do |m|
          expect { d.public_send(m, -1) }.to raise_error(ArgumentError), m.to_s
        end
      end

      it 'cursor_enable, cursor_disable, cursor_push e cursor_pop' do
        expect(written { expect(d.cursor_enable).to equal(d) }).to eq("\e[?12l\e[?25h")
        expect(written { expect(d.cursor_disable).to equal(d) }).to eq("\e[?25l")
        expect(written { expect(d.cursor_push.cursor_pop).to equal(d) }).to eq("\e7\e8")
      end

      it 'cursor_yx senza un terminale solleva DirectError senza chiamare il C' do
        allow(ffi).to receive(:ncdirect_cursor_yx).and_call_original
        expect(d.can_get_cursor?).to be(false)
        expect { d.cursor_yx }.to raise_error(Notcurses::DirectError, /cursore/)
        expect(ffi).not_to have_received(:ncdirect_cursor_yx)
      end
    end

    describe 'linee e box' do
      it 'hline interpola i colori da channels a to' do
        out = written { expect(d.hline('-', 5, channels: red, to: blue)).to equal(d) }
        expect(out).to eq("\e[38;2;255;0;0m-\e[38;2;204;0;51m-\e[38;2;153;0;102m-\e[38;2;102;0;153m-" \
                          "\e[38;2;51;0;204m-")
        expect(written { d.hline('=', 3) }).to eq("\e[39m===")
      end

      it 'vline scende di una riga per carattere' do
        expect(written { expect(d.vline('|', 3)).to equal(d) }).to eq("|\v\e[1D|\v\e[1D|")
      end

      it 'hline e vline rifiutano EGC larghi, lunghezze pericolose e canali a palette' do
        allow(ffi).to receive(:ncdirect_vline_interp).and_call_original
        ['ab', '中', '', "\n", "\t"].each do |egc|
          expect { d.hline(egc, 1) }.to raise_error(ArgumentError), egc.inspect
        end
        expect { d.hline(nil, 1) }.to raise_error(TypeError)
        expect { d.hline('-', 0) }.to raise_error(ArgumentError)
        expect { d.hline('-', Notcurses::Direct::MAX_LINE + 1) }.to raise_error(ArgumentError)
        # con UINT_MAX il C va in SIGFPE
        expect { d.vline('|', 0xffff_ffff) }.to raise_error(ArgumentError)
        palette = Notcurses::Channels.new.with_bg_palindex(3)
        expect { d.vline('|', 2, to: palette) }.to raise_error(ArgumentError, /palette/)
        expect(ffi).not_to have_received(:ncdirect_vline_interp)
      end

      it 'box disegna gli stili predefiniti' do
        { light: '┌──┐', heavy: '┏━━┓', rounded: '╭──╮', double: '╔══╗', ascii: '/--\\' }.each do |set, top|
          out = written { expect(d.box(3, 4, set: set)).to equal(d) }
          expect(out).to start_with(top), set.to_s
        end
        expect(written { d.box(3, 4) }).to eq("┌──┐\e[4D\v│\e[2C│\e[4D\v└──┘")
      end

      it 'box accetta 6 caratteri, colori degli angoli, lati omessi e soglia degli angoli' do
        expect(written { d.box(3, 4, set: 'abcdef') }).to eq("aeeb\e[4D\vf\e[2Cf\e[4D\vceed")
        expect(written { d.box(2, 2, ul: red, lr: blue) }).to eq("\e[38;2;255;0;0m┌┐\e[2D\v└\e[38;2;0;0;255m┘")
        out = written { d.box(3, 4, hide: :top, corners: 2) }
        expect(out).not_to include('┌', '┐', '──┐')
        expect(out).to end_with('└──┘')
        expect(written { d.box(3, 4, corners: 3) }).not_to match(/[┌┐└┘]/)
        expect(written { d.box(3, 4, hide: %i[left right]) }).not_to include('│')
      end

      it 'box valida gli argomenti' do
        expect { d.box(1, 4) }.to raise_error(ArgumentError)
        expect { d.box(3, Notcurses::Direct::MAX_LINE + 1) }.to raise_error(ArgumentError)
        expect { d.box(3, 4, set: :tratteggiato) }.to raise_error(ArgumentError, /set/)
        expect { d.box(3, 4, set: 'abc') }.to raise_error(ArgumentError)
        expect { d.box(3, 4, set: 'ab中def') }.to raise_error(ArgumentError)
        expect { d.box(3, 4, set: "abcde\n") }.to raise_error(ArgumentError)
        expect { d.box(3, 4, hide: [:centro]) }.to raise_error(ArgumentError)
        expect { d.box(3, 4, corners: 4) }.to raise_error(ArgumentError)
        expect { d.box(3, 4, ul: Notcurses::Channels.new.with_fg_palindex(1)) }.to raise_error(ArgumentError)
        expect { d.box(3, 4, lr: 'blu') }.to raise_error(TypeError)
      end
    end

    describe 'capacità' do
      it 'capabilities è una copia congelata, detected_terminal il nome del terminale' do
        caps = d.capabilities
        expect(caps).to be_a(Notcurses::Capabilities).and be_frozen
        expect(caps.colors).to eq(256)
        expect(caps.rgb?).to be(true)
        expect(d.detected_terminal).to eq('xterm-256color')
      end

      it 'le predicate can_*? restituiscono booleani' do
        %i[can_utf8? can_truecolor? can_change_color? can_fade? can_open_images? can_open_videos? can_halfblock?
           can_quadrant? can_sextant? can_octant? can_braille? can_pixel? can_get_cursor?].each do |m|
          expect(d.public_send(m)).to be(true).or(be(false)), m.to_s
        end
        expect(d.can_utf8?).to be(true)
        expect(d.can_truecolor?).to be(true)
        expect(d.can_open_images?).to be(true)
        expect(d.can_pixel?).to be(false)
        expect(d.can_get_cursor?).to be(false)
      end
    end

    describe 'input con drain_input' do
      it 'get e readline sollevano InputError; inputready_fd è un descrittore' do
        expect { d.get(timeout: 0) }.to raise_error(Notcurses::InputError, /drain_input/)
        expect { d.get }.to raise_error(Notcurses::InputError)
        expect { d.readline(prompt: '> ') }.to raise_error(Notcurses::InputError)
        expect(d.inputready_fd).to be >= 0
      end
    end

    describe 'immagini' do
      it 'render_image disegna un\'immagine e restituisce self' do
        out = written { expect(d.render_image(data_file('onedot.png'), align: :center, blitter: :half)).to equal(d) }
        expect(out).not_to be_empty
        expect(d.render_image(data_file('onedot.png'), scale: :stretch, blitter: ffi::NCBLIT_1x1)).to equal(d)
      end

      it 'render_image segnala i file mancanti e valida align, blitter e scale' do
        expect { d.render_image(File.join(@dir, 'manca.png')) }.to raise_error(Notcurses::DirectError)
        png = data_file('onedot.png')
        expect { d.render_image(png, align: :unaligned) }.to raise_error(ArgumentError)
        expect { d.render_image(png, blitter: :four_by_one) }.to raise_error(ArgumentError)
        expect { d.render_image(png, blitter: 99) }.to raise_error(ArgumentError)
        expect { d.render_image(png, scale: :zoom) }.to raise_error(ArgumentError)
        expect { d.render_image(nil) }.to raise_error(TypeError)
      end

      it 'render_frame restituisce un Frame che raster disegna una sola volta' do
        frame = d.render_frame(data_file('worldmap.png'), max_rows: 10, max_cols: 20)
        expect(frame).to be_a(Notcurses::Direct::Frame)
        expect(frame.dims).to eq([5, 20])
        out = written { expect(frame.raster(align: :center)).to be_nil }
        expect(out.count("\n")).to eq(5)
        expect(frame).to be_closed
        expect { frame.raster }.to raise_error(Notcurses::ClosedError)
        expect { frame.dims }.to raise_error(Notcurses::ClosedError)
      end

      it 'raster con un align non valido non consuma il frame' do
        frame = d.render_frame(data_file('worldmap.png'), blitter: :ascii, max_rows: 4, max_cols: 8)
        expect { frame.raster(align: :bottom) }.to raise_error(ArgumentError)
        expect(frame).not_to be_closed
        frame.raster(align: :right)
        expect(frame).to be_closed
      end

      it 'render_frame segnala gli errori e valida gli argomenti' do
        expect { d.render_frame(File.join(@dir, 'manca.png')) }.to raise_error(Notcurses::DirectError)
        expect { d.render_frame(data_file('onedot.png'), scale: :none) }.to raise_error(Notcurses::DirectError)
        expect { d.render_frame(data_file('worldmap.png'), max_rows: -1) }.to raise_error(ArgumentError)
        expect { d.render_frame(data_file('worldmap.png'), blitter: :eight_by_one) }.to raise_error(ArgumentError)
      end

      it 'Frame#close abbandona il frame ed è idempotente' do
        frame = d.render_frame(data_file('onedot.png'))
        expect(frame.close).to be_nil
        expect(frame.close).to be_nil
        expect(frame).to be_closed
        expect { frame.raster }.to raise_error(Notcurses::ClosedError)
      end

      it 'load_image carica un\'immagine riusabile con render e geometry' do
        image = d.load_image(data_file('worldmap.png'))
        expect(image).to be_a(Notcurses::Direct::Image)
        geom = image.geometry(d, blitter: :half)
        # rcelly/rcellx dipendono da LINES/COLUMNS senza un tty: non si controllano
        expect(geom.to_h).to include(pixy: 475, pixx: 860, scaley: 2, scalex: 1, blitter: :half)
        expect(geom).to be_a(Notcurses::Visual::Geometry)
        first = image.render(d, blitter: :half)
        second = image.render(d, blitter: :ascii, scale: :stretch)
        expect(first.dims).to eq([22, 80])
        expect(second.dims.first).to be_positive
        first.raster
        second.raster
        expect(image.close).to be_nil
        expect(image.free).to be_nil
        expect(image).to be_closed
        expect { image.render(d) }.to raise_error(Notcurses::ClosedError)
      end

      it 'load_image con un blocco chiude l\'immagine; Image.open fa lo stesso' do
        kept = d.load_image(data_file('onedot.png')) { |image| image }
        expect(kept).to be_closed
        result = Notcurses::Direct::Image.open(d, data_file('onedot.png')) { |image| image.geometry(d).pixx }
        expect(result).to eq(1)
      end

      it 'Image segnala gli errori e valida gli argomenti' do
        expect { d.load_image(File.join(@dir, 'manca.png')) }.to raise_error(Notcurses::DirectError)
        expect { Notcurses::Direct::Image.new(:direct, data_file('onedot.png')) }.to raise_error(TypeError)
        d.load_image(data_file('onedot.png')) do |image|
          expect { image.render(d, scale: :none) }.to raise_error(Notcurses::DirectError)
          expect { image.render(nil) }.to raise_error(TypeError)
          expect { image.geometry(d, blitter: :quadrato) }.to raise_error(ArgumentError)
        end
      end

      it 'stream disegna tutti i frame e passa al blocco il loro indice' do
        seen = []
        out = written { expect(d.stream(@gif, align: :center) { |i| seen << i }).to equal(d) }
        expect(seen).to eq([0, 1])
        expect(out).not_to be_empty
        expect(d.stream(data_file('onedot.png'), blitter: :ascii)).to equal(d)
      end

      it 'stream si ferma con break e chiude l\'immagine' do
        allow(ffi).to receive(:ncdirect_raster_frame).and_call_original
        allow(ffi).to receive(:ncdirectf_free).and_call_original
        seen = []
        result = d.stream(@gif) do |i|
          seen << i
          break :basta
        end
        expect(result).to eq(:basta)
        expect(seen).to eq([0])
        expect(ffi).to have_received(:ncdirect_raster_frame).once
        expect(ffi).to have_received(:ncdirectf_free).once
      end

      it 'stream propaga le eccezioni del blocco e segnala i file mancanti' do
        expect { d.stream(@gif) { raise 'basta' } }.to raise_error(RuntimeError, 'basta')
        expect { d.stream(File.join(@dir, 'manca.gif')) }.to raise_error(Notcurses::DirectError)
        expect { d.stream(@gif, align: :unaligned) }.to raise_error(ArgumentError)
        expect { d.stream(@gif, scale: :zoom) }.to raise_error(ArgumentError)
      end
    end
  end

  describe 'input da stdin chiuso' do
    before(:all) { @d = open_direct(drain_input: false) }
    after(:all) { @d&.close }

    it 'readline senza un terminale solleva; get restituisce EOF, poi sempre lo stesso EOF' do
      expect { @d.readline }.to raise_error(Notcurses::DirectError, /cursore/)
      expect { @d.get(timeout: -1) }.to raise_error(ArgumentError)
      expect { @d.get(timeout: 'presto') }.to raise_error(TypeError)
      ev = @d.get(timeout: 2)
      expect(ev).to be_a(Notcurses::Input)
      expect(ev.id).to eq(Notcurses::Key::EOF)
      allow(Notcurses::FFI).to receive(:ncdirect_get).and_call_original
      expect(@d.get(timeout: 0)).to equal(ev)
      expect(@d.get).to equal(ev)
      expect(Notcurses::FFI).not_to have_received(:ncdirect_get)
      expect(@d.readline(prompt: '> ')).to be_nil
      expect { @d.get(timeout: -1) }.to raise_error(ArgumentError)
    end
  end

  describe 'Image e Frame dopo la chiusura del contesto' do
    it 'l\'immagine resta valida e si chiude; i frame non disegnati diventano chiusi' do
      image = nil
      frame = nil
      d = open_direct do |direct|
        image = direct.load_image(data_file('onedot.png'))
        frame = image.render(direct)
        direct
      end
      expect(frame).to be_closed
      expect { frame.raster }.to raise_error(Notcurses::ClosedError)
      expect(image).not_to be_closed
      expect { image.render(d) }.to raise_error(Notcurses::ClosedError)
      expect(image.close).to be_nil
    end
  end
end
