# Generated from notcurses 3.0.17
# Source: notcurses/src/lib/in.c
# frozen_string_literal: true

# Studio ICH-600: misura i thread di oggi di Notcurses::UI contro il
# prototipo con i Fiber (fiber_app.rb) e stampa tabelle markdown.
#
# Uso, dalla radice del repository:
#
#   ruby -Ilib benchmark/fiber/run.rb [banco...]
#
# Banchi: keys, pipe, ctrlc (default: tutti). Modelli: MODELS=threads,fibers
# (default: tutti quelli del banco). Ogni misura avvia l'applicazione
# (app.rb) in un processo figlio, su un pty servito da questo processo: il
# terminale finto non condivide il GVL con l'applicazione, quindi non si
# ferma quando l'applicazione tiene il GVL. I tempi dei due processi usano
# CLOCK_MONOTONIC, che è lo stesso per tutto il sistema.
#
# - keys: latenza dal byte del tasto scritto sul pty all'handler on_input
#   (KEYS tasti, uno ogni INTERVAL_MS), CPU dell'applicazione per tasto e CPU
#   con il ciclo fermo: due finestre senza input, di IDLE_S / 4 e IDLE_S
#   secondi, aperte e chiuse da un timer dell'applicazione. Ogni finestra ha
#   lo stesso costo fisso (un risveglio e il render di uno schermo invariato):
#   la differenza fra le due dà la CPU a ciclo fermo, il resto il costo fisso.
# - pipe: latenza dalla riga scritta su un pipe all'handler finito (KEYS
#   righe), poi throughput di PIPE_MB MB scritti di seguito, con la CPU per MB
#   e i render fatti durante il flusso. Due handler: append (LogView#append
#   di ogni blocco) e read (solo lettura: misura il trasporto).
# - ctrlc: un handler calcola per BUSY_MS ms; CTRLC_DELAY_MS ms dopo il suo
#   inizio il terminale manda Ctrl+C. Misura il tempo fino all'Interrupt, con
#   il byte 0x03 (raw: SIGINT del kernel) e con il tasto kitty \e[99;5u
#   (kitty: il segnale lo alza il wrapper). REPS ripetizioni, un processo per
#   ripetizione.

require "etc"
require "json"
require "pty"
require "io/console"
# IO#wait_readable è nel core da Ruby 3.2: su 4.0 require "io/wait" stampa un avviso (come context.rb)
require "io/wait" unless IO.method_defined?(:wait_readable)
require "rbconfig"

ROOT = File.expand_path("../..", __dir__)
APP = File.join(__dir__, "app.rb")

KEYS = Integer(ENV.fetch("KEYS", "500"))
INTERVAL_MS = Float(ENV.fetch("INTERVAL_MS", "4"))
IDLE_S = Float(ENV.fetch("IDLE_S", "2"))
PIPE_MB = Integer(ENV.fetch("PIPE_MB", "16"))
REPS = Integer(ENV.fetch("REPS", "5"))
BUSY_MS = Integer(ENV.fetch("BUSY_MS", "500"))
CTRLC_DELAY_MS = Integer(ENV.fetch("CTRLC_DELAY_MS", "50"))
TIMEOUT_S = 30

BENCH_MODELS = {
  "keys" => %w[threads fibers],
  "pipe" => %w[threads fibers fibers-pass],
  "ctrlc" => %w[threads fibers fibers-native]
}.freeze
PIPE_MODES = %w[append read].freeze

def now = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)

def percentile(values, pct)
  sorted = values.sort
  sorted[((sorted.size * pct).ceil - 1).clamp(0, sorted.size - 1)]
end

def median(values) = percentile(values, 0.5)

def fmt(value, digits = 1) = format("%.#{digits}f", value).tr(".", ",")

# Terminale finto: risponde a DA1, alla posizione del cursore e, con kitty,
# alla domanda dei flag del protocollo di tastiera di kitty.
class Terminal
  QUERIES = /\e\[6n|\e\[\?u|\e\[c/

  attr_reader :path

  def initialize(kitty:)
    @master, @slave = PTY.open
    @slave.winsize = [60, 200]
    @path = @slave.path
    @answers = {"\e[6n" => "\e[5;7R", "\e[c" => "\e[?62;22c"}
    @answers["\e[?u"] = "\e[?27u" if kitty
    @lock = Mutex.new
    @written = +""
    @thread = Thread.new { pump } # rubocop:disable ThreadSafety/NewThread -- lettore del pty
  end

  def type(bytes) = @lock.synchronize { @master.write(bytes) }

  # true quando l'applicazione ha acceso il protocollo di tastiera di kitty
  def kitty? = @lock.synchronize { @written.include?("\e[>u\e[=27u") }

  def close
    @slave.close unless @slave.closed?
    @master.close unless @master.closed?
    @thread.join(1)
  end

  private

  def pump
    loop do
      data = @master.readpartial(65_536)
      @lock.synchronize { @written << data if @written.bytesize < 1_000_000 }
      data.scan(QUERIES) { |q| type(@answers[q]) if @answers[q] }
    end
  rescue IOError, Errno::EIO
    nil
  end
end

# Processo figlio dell'applicazione, con il canale dei risultati (fd 3).
class Child
  def initialize(model, bench, term, data: nil, env: {})
    @res_r, res_w = IO.pipe
    opts = {3 => res_w, :out => :err}
    opts[4] = data if data
    env = {"KEYS" => KEYS.to_s, "PIPE_BYTES" => (PIPE_MB * 1_048_576).to_s, "BUSY_MS" => BUSY_MS.to_s,
           "IDLE_S" => IDLE_S.to_s}.merge(env)
    @pid = Process.spawn(env, RbConfig.ruby, "-I", File.join(ROOT, "lib"), APP, model, bench, term.path, opts)
    res_w.close
  end

  # La riga successiva del figlio, che deve iniziare con word.
  def expect(word)
    raise "#{word}: il figlio non risponde" unless @res_r.wait_readable(TIMEOUT_S)

    line = @res_r.gets
    raise "#{word}: il figlio ha chiuso il canale" unless line
    raise "atteso #{word}, arrivato #{line.inspect}" unless line.start_with?(word)

    line.delete_prefix(word).strip
  end

  def result = JSON.parse(expect("result"))

  def finish
    Process.kill(:KILL, @pid) unless wait(TIMEOUT_S)
    Process.wait(@pid)
  rescue Errno::ECHILD
    nil
  ensure
    @res_r.close
  end

  private

  def wait(seconds)
    deadline = now + (seconds * 1e9)
    while now < deadline
      return true if Process.wait(@pid, Process::WNOHANG)

      sleep 0.01
    end
    false
  end
end

def with_child(model, bench, kitty: false, data: nil, env: {})
  term = Terminal.new(kitty: kitty)
  child = Child.new(model, bench, term, data: data, env: env)
  data&.close
  yield child, term
ensure
  child&.finish
  term&.close
end

def keys_bench(model)
  with_child(model, "keys") do |child, term|
    child.expect("ready")
    child.expect("idle-done") # la finestra del ciclo fermo la chiude un timer del figlio
    sent = Array.new(KEYS) do
      t0 = now
      term.type("a")
      sleep INTERVAL_MS / 1000.0
      t0
    end
    term.type("q")
    res = child.result
    raise "tasti persi: #{res["t1"].size} di #{KEYS}" unless res["t1"].size == KEYS

    lat = res["t1"].zip(sent).map { |t1, t0| (t1 - t0) / 1000.0 }
    # due finestre di IDLE_S / 4 e IDLE_S con lo stesso costo fisso (risveglio e render invariato)
    (wall1, cpu1), (wall2, cpu2) = res["idle"].each_cons(2).map { |(t0, c0), (t1, c1)| [t1 - t0, c1 - c0] }
    idle_rate = (cpu2 - cpu1).to_f / (wall2 - wall1) # ns di CPU per ns
    {model: model, med: median(lat), p99: percentile(lat, 0.99), max: lat.max,
     cpu_event: res["load_cpu"] / 1000.0 / KEYS, idle_cpu: idle_rate * 1e6,
     wake_cpu: (cpu1 - (idle_rate * wall1)) / 1000.0, renders: res["renders"]}
  end
end

def pipe_bench(model, mode)
  data_r, data_w = IO.pipe
  with_child(model, "pipe", data: data_r, env: {"PIPE_MODE" => mode}) do |child, _term|
    child.expect("ready")
    sent = Array.new(KEYS) do |i|
      t0 = now
      data_w.write("L #{i}\n")
      sleep INTERVAL_MS / 1000.0
      t0
    end
    child.expect("lat-done")
    chunk = (("x" * 79) + "\n") * 819 # 65520 byte
    total = PIPE_MB * 1_048_576
    written = 0
    while written < total
      part = chunk.byteslice(0, total - written)
      data_w.write(part)
      written += part.bytesize
    end
    res = child.result
    lat = res["t1"].zip(sent).map { |t1, t0| (t1 - t0) / 1000.0 }
    secs = res["tp_wall"] / 1e9
    {model: model, mode: mode, med: median(lat), p99: percentile(lat, 0.99), max: lat.max,
     mb_s: PIPE_MB / secs, cpu_mb: res["tp_cpu"] / 1e6 / PIPE_MB, renders: res["tp_renders"],
     chunks: res["tp_chunks"]}
  end
ensure
  data_w&.close
end

def ctrlc_once(model, kind)
  with_child(model, "ctrlc", kitty: kind == "kitty") do |child, term|
    child.expect("ready")
    if kind == "kitty"
      deadline = now + 5e9
      sleep 0.01 until term.kitty? || now > deadline
      raise "kitty non acceso" unless term.kitty?
    end
    term.type("b")
    busy = child.expect("busy").to_i
    sleep_until = busy + (CTRLC_DELAY_MS * 1_000_000)
    sleep((sleep_until - now) / 1e9) if sleep_until > now
    t0 = now
    term.type((kind == "kitty") ? "\e[99;5u" : "\x03")
    res = child.result
    {ms: (res["t_int"] - t0) / 1e6, reason: res["reason"], busy_left: (busy + (BUSY_MS * 1_000_000) - t0) / 1e6}
  end
end

def ctrlc_bench(model)
  %w[raw kitty].filter_map do |kind|
    next if model == "fibers-native" && kind == "raw" # uguale a fibers: SIGINT del kernel

    runs = Array.new(REPS) { ctrlc_once(model, kind) }
    {model: model, kind: kind, med: median(runs.map { |r| r[:ms] }), max: runs.map { |r| r[:ms] }.max,
     reasons: runs.map { |r| r[:reason] }.tally, busy_left: median(runs.map { |r| r[:busy_left] })}
  end
end

def print_keys(rows)
  puts "### keys: tasto → handler (#{KEYS} tasti, uno ogni #{fmt(INTERVAL_MS)} ms)", ""
  puts "| Modello | Mediana µs | p99 µs | Max µs | CPU per tasto µs | CPU a ciclo fermo µs/s | " \
       "Risveglio e render invariato µs | Render |"
  puts "| --- | --- | --- | --- | --- | --- | --- | --- |"
  rows.each do |r|
    puts "| #{r[:model]} | #{fmt(r[:med])} | #{fmt(r[:p99])} | #{fmt(r[:max])} | #{fmt(r[:cpu_event])} | " \
         "#{fmt(r[:idle_cpu])} | #{fmt(r[:wake_cpu])} | #{r[:renders]} |"
  end
  puts
end

def print_pipe(rows)
  puts "### pipe: riga → handler (#{KEYS} righe), poi #{PIPE_MB} MB di seguito", ""
  puts "| Modello | Handler | Mediana µs | p99 µs | Max µs | MB/s | CPU ms per MB | Render nel flusso | Blocchi |"
  puts "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"
  rows.each do |r|
    puts "| #{r[:model]} | #{r[:mode]} | #{fmt(r[:med])} | #{fmt(r[:p99])} | #{fmt(r[:max])} | #{fmt(r[:mb_s])} | " \
         "#{fmt(r[:cpu_mb], 2)} | #{r[:renders]} | #{r[:chunks]} |"
  end
  puts
end

def print_ctrlc(rows)
  puts "### ctrlc: Ctrl+C → Interrupt con un handler occupato per #{BUSY_MS} ms (#{REPS} ripetizioni)", ""
  puts "| Modello | Tasto | Mediana ms | Max ms | Handler ancora da fare ms | Uscita di run |"
  puts "| --- | --- | --- | --- | --- | --- |"
  rows.each do |r|
    reasons = r[:reasons].map { |k, v| "#{k} x#{v}" }.join(", ")
    puts "| #{r[:model]} | #{r[:kind]} | #{fmt(r[:med])} | #{fmt(r[:max])} | #{fmt(r[:busy_left])} | #{reasons} |"
  end
  puts
end

benches = ARGV.empty? ? BENCH_MODELS.keys : ARGV
only = ENV["MODELS"]&.split(",")
puts "Ruby #{RUBY_VERSION}, #{Etc.nprocessors} core", ""
benches.each do |bench|
  models = BENCH_MODELS.fetch(bench) { abort "banco sconosciuto: #{bench}" }
  models &= only if only
  case bench
  when "keys" then print_keys(models.map { |m| keys_bench(m) })
  when "pipe" then print_pipe(PIPE_MODES.flat_map { |mode| models.map { |m| pipe_bench(m, mode) } })
  when "ctrlc" then print_ctrlc(models.flat_map { |m| ctrlc_bench(m) })
  end
end
