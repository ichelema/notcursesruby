# Generated from notcurses 3.0.17
# Source: notcurses/src/lib/in.c
# frozen_string_literal: true

# Applicazione di benchmark/fiber/run.rb (studio ICH-600), in un processo
# figlio: la avvia run.rb, non si esegue a mano.
#
#   ruby -Ilib benchmark/fiber/app.rb MODELLO BANCO TTY
#
# MODELLO: threads (Notcurses::UI::App di oggi), fibers (FiberApp del
# prototipo: i segnali di linea li alza il Fiber di input) o fibers-native
# (FiberApp: i segnali di linea li alza notcurses). BANCO: keys, pipe, ctrlc.
# Il processo diventa leader di sessione e prende TTY come terminale di
# controllo. fd 3: righe per run.rb ("ready", "busy T", "lat-done",
# "result JSON"); fd 4, solo nel banco pipe: il pipe dei dati. PIPE_MODE:
# append (LogView#append di ogni blocco) o read (solo lettura).

require "json"
require "notcurses"

model, bench, tty_path = ARGV
require_relative "fiber_app" unless model == "threads"

TIOCSCTTY = 0x540E # Linux
KEYS = Integer(ENV.fetch("KEYS"))

def now = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)

def cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID, :nanosecond)

Process.setsid
tty = File.open(tty_path, File::RDWR)
tty.ioctl(TIOCSCTTY, 0)
$stdin.reopen(tty)
results = IO.new(3, "w")
results.sync = true

Notcurses::Context.open(output: tty_path, termtype: "xterm-256color", suppress_banners: true) do |nc|
  app = (model == "threads") ? Notcurses::UI::App.new(nc) : FiberApp.new(nc)
  run_opts = (model == "fibers-native") ? {linesigs: :native} : {}
  out = {}

  case bench
  when "keys"
    stamps = []
    marks = {}
    app.on_input do |input|
      case input.id
      when 97 # a
        t = now
        marks[:first] ||= [t, cpu, nc.stats.renders]
        stamps << t
        nc.stdplane.putstr(stamps.size.to_s, y: 0, x: 0)
      when 113 # q
        marks[:end] = [now, cpu, nc.stats.renders]
        app.stop
      end
    end
    app.post do
      marks[:ready] = [now, cpu]
      results.puts "ready"
    end
    out[:reason] = app.run(**run_opts)
    out.merge!(t1: stamps, idle_wall: marks[:first][0] - marks[:ready][0],
      idle_cpu: marks[:first][1] - marks[:ready][1], load_cpu: marks[:end][1] - marks[:first][1],
      renders: marks[:end][2] - marks[:first][2])

  when "pipe"
    log = Notcurses::UI::LogView.new(app.root, weight: 1)
    data = IO.new(4, "rb")
    expected = Integer(ENV.fetch("PIPE_BYTES"))
    append = ENV.fetch("PIPE_MODE") == "append"
    lat = []
    tp = nil
    handle = lambda do |bytes|
      t_in = now
      log.append(bytes) if append
      t = now
      if tp.nil?
        bytes.scan(/^L \d+$/) { lat << t }
        if lat.size >= KEYS
          tp = {bytes: 0, chunks: 0}
          results.puts "lat-done"
        end
      else
        tp.merge!(t: t_in, cpu: cpu, renders: nc.stats.renders) if tp[:chunks].zero?
        tp[:bytes] += bytes.bytesize
        tp[:chunks] += 1
        if tp[:bytes] >= expected
          out.merge!(tp_wall: now - tp[:t], tp_cpu: cpu - tp[:cpu], tp_renders: nc.stats.renders - tp[:renders],
            tp_chunks: tp[:chunks])
          app.stop
        end
      end
    end
    if model == "threads"
      # come in fase3-design.md, sezione 5: il thread di lettura passa i dati al ciclo con post
      Notcurses::FdPlane.new(log.plane, data) { |_f, bytes| app.post { handle.call(bytes) unless log.closed? } }
    else
      data.nonblock = true # una read bloccante fermerebbe il thread, non solo il Fiber
      pass = model == "fibers-pass"
      app.async do
        loop do
          handle.call(data.readpartial(Notcurses::FdPlane::CHUNK_SIZE))
          app.pass if pass
        end
      rescue EOFError
        nil
      end
    end
    app.post { results.puts "ready" }
    out[:reason] = app.run(**run_opts)
    out[:t1] = lat

  when "ctrlc"
    busy_ns = Integer(ENV.fetch("BUSY_MS")) * 1_000_000
    app.on_input do |input|
      next unless input.id == 98 # b

      t = now
      results.puts "busy #{t}"
      deadline = t + busy_ns
      begin
        nil while now < deadline
      rescue Interrupt
        out[:t_int] ||= now
        raise
      end
    end
    app.post { results.puts "ready" }
    out[:reason] = app.run(**run_opts)
    out[:t_int] ||= now
  end

  results.puts "result #{JSON.generate(out)}"
end
