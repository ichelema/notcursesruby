# Generated from notcurses 3.0.17
# Source: notcurses/src/lib/in.c
# frozen_string_literal: true

# Studio ICH-601: un'applicazione di Notcurses::UI avvia JOBS job di calcolo
# e aggiorna lo schermo con i risultati. Confronta il calcolo nell'handler
# (inline), in Thread con post (thread) e in Ractor con ProtoBackground
# (ractor), e stampa una tabella markdown.
#
# Uso, dalla radice del repository:
#
#   ruby -Ilib benchmark/ractor/run.rb
#
# Variabili: MODELS=inline,thread,ractor, LOADS=Segment,PlotData,Pixels
# (default: tutti), JOBS (default 4), REPS (default 3), INTERVAL_MS (default
# 10). Ogni misura avvia l'applicazione (app.rb) in un processo figlio, su un
# pty servito da questo processo, come benchmark/fiber/run.rb: il terminale
# finto non condivide il GVL con l'applicazione. Il terminale manda g (avvia
# i job), poi un tasto a ogni INTERVAL_MS ms fino alla fine dell'ultimo job,
# poi q. Misure: tempo da g all'ultimo risultato sullo schermo, latenza dei
# tasti mandati durante il calcolo (dal byte sul pty all'handler), render
# durante il calcolo, byte che l'applicazione scrive su stderr (in
# un'applicazione vera vanno sullo schermo).

require "etc"
require "json"
require "pty"
require "io/console"
# IO#wait_readable è nel core da Ruby 3.2: su 4.0 require "io/wait" stampa un avviso (come context.rb)
require "io/wait" unless IO.method_defined?(:wait_readable)
require "rbconfig"
require "tempfile"

ROOT = File.expand_path("../..", __dir__)
APP = File.join(__dir__, "app.rb")

MODELS = ENV.fetch("MODELS", "inline,thread,ractor").split(",")
LOADS = ENV.fetch("LOADS", "Segment,PlotData,Pixels").split(",")
JOBS = Integer(ENV.fetch("JOBS", "4"))
REPS = Integer(ENV.fetch("REPS", "3"))
INTERVAL_MS = Float(ENV.fetch("INTERVAL_MS", "10"))
TIMEOUT_S = 60

def now = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)

def percentile(values, pct)
  sorted = values.sort
  sorted[((sorted.size * pct).ceil - 1).clamp(0, sorted.size - 1)]
end

def median(values) = percentile(values, 0.5)

def fmt(value, digits = 1) = format("%.#{digits}f", value).tr(".", ",")

# Terminale finto: risponde a DA1 e alla posizione del cursore.
class Terminal
  QUERIES = /\e\[6n|\e\[c/
  ANSWERS = {"\e[6n" => "\e[5;7R", "\e[c" => "\e[?62;22c"}.freeze

  attr_reader :path

  def initialize
    @master, @slave = PTY.open
    @slave.winsize = [60, 200]
    @path = @slave.path
    @lock = Mutex.new
    @thread = Thread.new { pump } # rubocop:disable ThreadSafety/NewThread -- lettore del pty
  end

  def type(bytes) = @lock.synchronize { @master.write(bytes) }

  def close
    @slave.close unless @slave.closed?
    @master.close unless @master.closed?
    @thread.join(1)
  end

  private

  def pump
    loop do
      @master.readpartial(65_536).scan(QUERIES) { |q| type(ANSWERS[q]) }
    end
  rescue IOError, Errno::EIO
    nil
  end
end

# Processo figlio dell'applicazione, con il canale dei risultati (fd 3) e
# stderr su un file.
class Child
  def initialize(model, load, term, err)
    @res_r, res_w = IO.pipe
    env = {"JOBS" => JOBS.to_s}
    @pid = Process.spawn(env, RbConfig.ruby, "-I", File.join(ROOT, "lib"), APP, model, load, term.path,
      3 => res_w, :out => err, :err => err)
    res_w.close
  end

  # La riga successiva del figlio, che deve iniziare con word.
  def expect(word, timeout = TIMEOUT_S)
    raise "#{word}: il figlio non risponde" unless @res_r.wait_readable(timeout)

    line = @res_r.gets
    raise "#{word}: il figlio ha chiuso il canale" unless line
    raise "atteso #{word}, arrivato #{line.inspect}" unless line.start_with?(word)

    line.delete_prefix(word).strip
  end

  # true se il figlio ha scritto una riga sul canale.
  def ready? = @res_r.wait_readable(0)

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

def once(model, load)
  term = Terminal.new
  err = Tempfile.new("ractor-err")
  child = Child.new(model, load, term, err)
  child.expect("ready")
  term.type("g")
  t_go = child.expect("go").to_i
  sent = []
  # con inline l'handler non ha ancora finito: "done" arriva solo alla fine dei job
  until child.ready?
    sent << now
    term.type("a")
    sleep INTERVAL_MS / 1000.0
  end
  child.expect("done")
  term.type("q")
  res = JSON.parse(child.expect("result"))
  lat = res["keys"].first(sent.size).zip(sent).map { |t1, t0| (t1 - t0) / 1e6 }
  {total: (res["t_done"] - t_go) / 1e6, keys: sent.size, lat: lat, renders: res["renders"],
   stderr: File.size(err.path)}
ensure
  child&.finish
  term&.close
  err&.close!
end

puts "Ruby #{RUBY_VERSION}, #{Etc.nprocessors} core, #{JOBS} job, mediana di #{REPS} ripetizioni, " \
     "un tasto ogni #{fmt(INTERVAL_MS)} ms", ""
puts "| Carico | Modello | Fino all'ultimo risultato ms | Tasti nel calcolo | Latenza mediana ms | " \
     "Latenza p99 ms | Latenza max ms | Render nel calcolo | Byte su stderr |"
puts "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"
LOADS.each do |load|
  MODELS.each do |model|
    runs = Array.new(REPS) { once(model, load) }
    lat = runs.flat_map { |r| r[:lat] }
    puts "| #{load} | #{model} | #{fmt(median(runs.map { |r| r[:total] }))} | #{median(runs.map { |r| r[:keys] })} | " \
         "#{fmt(median(lat), 2)} | #{fmt(percentile(lat, 0.99), 2)} | #{fmt(lat.max, 2)} | " \
         "#{median(runs.map { |r| r[:renders] })} | #{runs.map { |r| r[:stderr] }.max} |"
  end
end
puts
