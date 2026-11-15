# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require "json"
require "rbconfig"
require "tmpdir"

# Spec grafiche su un terminale vero (Fase 5). Girano solo con NC_GRAPHICS=1,
# dentro Kitty o Ghostty, con il TERM del terminale:
#
#   NC_GRAPHICS=1 bundle exec rspec spec/graphics
#   NC_GRAPHICS=1 NC_GRAPHICS_HOLD=3 bundle exec rspec spec/graphics  # controllo a vista
#
# Senza la variabile RSpec esclude il gruppo (metadato if:), quindi la suite
# normale e la CI non lo vedono. Ogni prova gira in un processo figlio
# (probe.rb) che eredita il terminale: un solo contesto per processo. Il figlio
# resta nel process group in primo piano: in background (per esempio sotto
# timeout senza --foreground) il kernel lo fermerebbe con SIGTTOU.
RSpec.describe "Blitter e tasti su un terminale vero (Kitty, Ghostty)", if: ENV["NC_GRAPHICS"] == "1" do
  # Attese per notcurses 3.0.17: euristiche di termdesc.c:735-765 (Kitty) e
  # termdesc.c:930-934 (Ghostty); Ghostty ha i pixel dalla query della grafica
  # kitty (termdesc.c:1527-1535). Gli ottanti ci sono solo in foot >= 1.20.
  def expected
    caps = {quadrants: true, sextants: true, octants: false, braille: true, halfblocks: true}
    {
      kitty: {prefix: "Kitty ", pixel_support: "kitty_animated", caps: caps},
      ghostty: {prefix: "ghostty ", pixel_support: "kitty_static", caps: caps}
    }.fetch(terminal)
  end

  def terminal
    return :kitty if ENV["TERM"] == "xterm-kitty"

    :ghostty if ENV["TERM"] == "xterm-ghostty" || ENV["TERM_PROGRAM"] == "ghostty"
  end

  def lib_dir = File.expand_path("../../lib", __dir__)

  # Esegue probe.rb nel modo dato. Il blocco gira mentre il figlio è vivo (per
  # mandare i tasti) e riceve il percorso dell'esito.
  # @return [Hash] l'esito JSON del figlio
  def run_probe(mode, timeout: 60)
    Dir.mktmpdir("nc-graphics") do |dir|
      out = File.join(dir, "#{mode}.json")
      pid = spawn(RbConfig.ruby, "-I", lib_dir, File.expand_path("probe.rb", __dir__), mode, out)
      begin
        yield out if block_given?
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
        until Process.wait2(pid, Process::WNOHANG)
          raise "probe.rb #{mode} bloccato dopo #{timeout} s" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

          sleep 0.05
        end
        pid = nil
      ensure
        if pid
          Process.kill(:KILL, pid)
          Process.wait(pid)
          restore_terminal
        end
      end
      raise "probe.rb #{mode} non ha scritto l'esito" unless File.exist?(out)

      JSON.parse(File.read(out), symbolize_names: true)
    end
  end

  # Dopo un figlio ucciso: modo del tty, schermo normale, cursore visibile,
  # immagini kitty cancellate (regola 16).
  def restore_terminal
    system("stty", "sane")
    $stdout.write("\e[?1049l\e[?25h\e_Ga=d\e\\")
    $stdout.flush
  end

  def wait_ready(out, n)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
    sleep 0.05 until File.exist?("#{out}.ready.#{n}") || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
    raise "probe.rb non è pronto per i tasti (passo #{n})" unless File.exist?("#{out}.ready.#{n}")
  end

  # kitty @ con il socket di KITTY_LISTEN_ON e stdin da /dev/null: senza socket
  # kitty @ parlerebbe con Kitty sul tty, dove legge anche il figlio.
  # @return [String, nil] l'output del comando, nil se fallisce
  def kitty(*args)
    output = IO.popen(["kitty", "@", "--to", ENV.fetch("KITTY_LISTEN_ON"), *args], in: File::NULL, err: File::NULL,
      &:read)
    output if $?.success?
  rescue SystemCallError
    nil
  end

  def send_key(*keys) = kitty("send-key", "--match", "id:#{ENV.fetch("KITTY_WINDOW_ID")}", *keys)

  def skip_without_kitty_remote
    skip "solo in Kitty" unless terminal == :kitty
    skip "serve il remote control di Kitty con un socket (KITTY_LISTEN_ON)" unless ENV["KITTY_LISTEN_ON"] &&
      ENV["KITTY_WINDOW_ID"] && kitty("ls")
  end

  before do
    skip "serve un terminale: stdin e stdout devono essere un tty" unless $stdin.tty? && $stdout.tty?
    skip "terminale non supportato (TERM=#{ENV["TERM"].inspect}): servono Kitty o Ghostty" unless terminal
  end

  it "rileva il terminale e le capacità, e ogni blitter disponibile disegna con no_degrade: true" do
    res = run_probe("context")
    aggregate_failures do
      expect(res[:error]).to be_nil
      expect(res[:detected_terminal]).to start_with(expected[:prefix])
      expect(res[:pixel_support]).to eq(expected[:pixel_support])
      expect(res[:caps]).to eq(expected[:caps])
      expect(res[:pixel_geom]).to include(cell_pixel_y: be_positive, cell_pixel_x: be_positive, pixel_y: be_positive)
      expect(res[:blits].except(:octant)).to eq(pixel: "ok", quad: "ok", sextant: "ok", braille: "ok", half: "ok",
        ascii: "ok")
      expect(res[:blits][:octant]).to start_with("Notcurses::VisualError")
    end
  end

  it "Direct#render_image con il blitter :pixel" do
    res = run_probe("direct")
    expect(res).to include(can_pixel: true, render_image: "ok")
    expect(res[:detected_terminal]).to start_with(expected[:prefix])
  end

  it "Direct#stream disegna ogni frame sopra il precedente con :half, :quad e :pixel (ICH-284)" do
    res = run_probe("stream")
    expect(res[:error]).to be_nil
    aggregate_failures do
      {half: 4, quad: 4, pixel: nil}.each do |blitter, rows|
        run = res[:runs].fetch(blitter)
        before_row = run[:before][0]
        expect(run[:after].size).to eq(4), "#{blitter}: frame #{run[:after].size}"
        expect(run[:after].uniq.size).to eq(1), "#{blitter}: il cursore si sposta tra i frame #{run[:after]}"
        expect(run[:after][0][0]).to eq(before_row + rows) if rows
        expect(run[:after][0][0]).to be > before_row
      end
    end
  end

  it "Ctrl+C con CapsLock, con NumLock e da solo è un segnale in EventLoop#run (kitty @ send-key, ICH-280)" do
    skip_without_kitty_remote
    keys = %w[ctrl+caps_lock+c ctrl+num_lock+c ctrl+c]
    res = run_probe("signals") do |out|
      keys.each.with_index(1) do |key, n|
        wait_ready(out, n)
        send_key(key)
      end
    end
    expect(res[:error]).to be_nil
    expect(res[:runs]).to eq([{reason: "interrupt", on_key: []}] * 3)
  end

  it "il glifo largo sotto il cursore resta intero nell'ultima colonna del TextInput (kitty @ send-key, ICH-281)" do
    skip_without_kitty_remote
    screen = nil
    res = run_probe("wide") do |out|
      wait_ready(out, 1)
      send_key("left")
      sleep 0.5
      screen = kitty("get-text", "--match", "id:#{ENV.fetch("KITTY_WINDOW_ID")}", "--extent", "screen")
      send_key("ctrl+x")
    end
    expect(res[:error]).to be_nil
    expect(res).to include(reason: "stop", position: res[:cols] - 1, cursor: [0, res[:cols] - 2])
    expect(screen.to_s.lines.first.to_s.rstrip).to end_with("a漢")
  end
end
