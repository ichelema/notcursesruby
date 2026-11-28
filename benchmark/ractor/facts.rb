# Generated from notcurses 3.0.17
# Source: notcurses/src/media/shim.c
# frozen_string_literal: true

# Studio ICH-601: i fatti sui Ractor che il design usa, provati sulla
# versione di Ruby che esegue lo script. Stampa una tabella markdown.
#
# Uso, dalla radice del repository:
#
#   ruby -Ilib benchmark/ractor/facts.rb
#
# Ogni fatto gira in un processo Ruby figlio, con un timeout di TIMEOUT_S
# secondi: un caso che si blocca scrive "bloccato" e non ferma gli altri, e
# ogni caso parte da un processo senza Ractor (il warning esce solo al primo
# Ractor.new del processo). Il figlio stampa una riga, il risultato.

require "open3"
# IO#wait_readable è nel core da Ruby 3.2: su 4.0 require "io/wait" stampa un avviso (come context.rb)
require "io/wait" unless IO.method_defined?(:wait_readable)
require "rbconfig"

ROOT = File.expand_path("../..", __dir__)
TIMEOUT_S = 5

PRELUDE = <<~RUBY
  $stdout.sync = true
  WAIT = Ractor.method_defined?(:value) ? ->(r) { r.value } : ->(r) { r.take }
  def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  # un calcolo di ms millisecondi che tiene il GVL del suo Ractor (un modulo: un proc in una costante non è condivisibile)
  module Busy; def self.call(ms) = (t = Process.clock_gettime(Process::CLOCK_MONOTONIC); 0 while Process.clock_gettime(Process::CLOCK_MONOTONIC) - t < ms / 1000.0; ms); end
  # stderr del blocco, come testo
  def stderr_of
    r, w = IO.pipe
    saved = $stderr.dup
    $stderr.reopen(w)
    yield
    $stderr.reopen(saved)
    w.close
    r.read
  end
RUBY

# Un Fiber conta un tick ogni 5 ms mentre un altro attende un Ractor di 200 ms
# sotto il ProtoScheduler di benchmark/fiber: 0 tick = l'attesa ferma il ciclo.
FIBER_WAIT = <<~RUBY
  require "#{ROOT}/benchmark/fiber/scheduler"
  Warning[:experimental] = false
  s = ProtoScheduler.new
  Fiber.set_scheduler(s)
  ticks = 0
  done = false
  Fiber.schedule { until done; sleep 0.005; ticks += 1; end }
  Fiber.schedule do
    sleep 0.02
    ticks = 0
    WAIT_UNDER_TEST.call
    done = true
  end
  s.run { done }
  puts "\#{ticks} tick in 200 ms"
RUBY

FACTS = [
  ["API dei Ractor", <<~RUBY],
    puts %w[take value].select { |m| Ractor.method_defined?(m) }.map { |m| "Ractor#" + m }
      .push(defined?(Ractor::Port) ? "Ractor::Port" : nil, Ractor.respond_to?(:shareable_proc) ? "Ractor.shareable_proc" : nil)
      .compact.join(", ")
  RUBY
  ["Warning al primo Ractor.new", <<~RUBY],
    out = stderr_of { WAIT.(Ractor.new { 1 }) }
    puts out.empty? ? "nessuno" : out[/warning: .*?\\./]
  RUBY
  ["Warning con Warning[:experimental] = false al primo Ractor.new, poi acceso", <<~RUBY],
    Warning[:experimental] = false
    a = stderr_of { WAIT.(Ractor.new { 1 }) }
    Warning[:experimental] = true
    b = stderr_of { WAIT.(Ractor.new { 1 }) }
    puts "\#{a.bytesize} byte, poi \#{b.bytesize} byte su stderr"
  RUBY
  ["Eccezione non gestita nel Ractor", <<~RUBY],
    Warning[:experimental] = false
    e = nil
    err = stderr_of do
      WAIT.(Ractor.new { raise ArgumentError, "x" })
    rescue => e
      nil
    end
    puts "\#{e.class} (cause \#{e.cause.class}); \#{err.bytesize} byte su stderr (\#{err[/terminated with exception/]})"
  RUBY
  ["Attesa con take o value in un task (Fiber scheduler)", <<~RUBY + FIBER_WAIT],
    WAIT_UNDER_TEST = -> { WAIT.(Ractor.new(200) { |ms| Busy.call(ms) }) }
  RUBY
  ["Attesa con Ractor::Port#receive in un task (solo Ruby 4.0)", <<~RUBY + FIBER_WAIT],
    abort "Ractor::Port assente" unless defined?(Ractor::Port)
    WAIT_UNDER_TEST = -> { port = Ractor::Port.new; Ractor.new(port) { |p| p << Busy.call(200) }; port.receive }
  RUBY
  ["Attesa con Queue#pop di un thread che attende il Ractor, in un task", <<~RUBY + FIBER_WAIT],
    WAIT_UNDER_TEST = -> { q = Thread::Queue.new; Thread.new { q << WAIT.(Ractor.new(200) { |ms| Busy.call(ms) }) }; q.pop }
  RUBY
  ["Due thread del Ractor principale attendono insieme (take o value) due Ractor", <<~RUBY],
    Warning[:experimental] = false
    rs = [200, 210].map { |ms| Ractor.new(ms) { |m| Busy.call(m) } }
    puts rs.map { |r| Thread.new { WAIT.(r) } }.map(&:value).inspect
  RUBY
  ["Un thread in Ractor.receive, un altro in take o value", <<~RUBY],
    Warning[:experimental] = false
    rx = Thread.new { Ractor.receive }
    sleep 0.05
    puts WAIT.(Ractor.new(200) { |ms| Busy.call(ms) }).inspect
  RUBY
  ["Un thread di consegna in Ractor.receive, i Ractor mandano a Ractor.main (move: true)", <<~RUBY],
    Warning[:experimental] = false
    rx = Thread.new { Array.new(4) { Ractor.receive.bytesize } }
    sleep 0.05
    t0 = now
    4.times { |i| Ractor.new(200 + i) { |ms| Busy.call(ms); Ractor.main.send("x" * (16 << 20), move: true) } }
    puts "\#{rx.value.size} risultati da 16 MB in \#{((now - t0) * 1000).round} ms"
  RUBY
  ["Il blocco di Ractor.new usa una variabile esterna", <<~RUBY],
    Warning[:experimental] = false
    x = 1
    begin; Ractor.new { x }; rescue => e; puts "\#{e.class}: \#{e.message}"; end
  RUBY
  ["Una lambda del programma come argomento", <<~RUBY],
    Warning[:experimental] = false
    begin; WAIT.(Ractor.new(->(v) { v }) { |j| j.(1) }); puts "ok"; rescue => e; puts "\#{(e.cause || e).class}: \#{(e.cause || e).message}"; end
  RUBY
  ["Un modulo con self.call, e una lambda resa condivisibile dentro un modulo", <<~RUBY],
    Warning[:experimental] = false
    module Job; def self.call(v) = v + 1; end
    module Jobs; INC = Ractor.make_shareable(->(v) { v + 1 }); end
    puts [WAIT.(Ractor.new(Job) { |j| j.(1) }), WAIT.(Ractor.new(Jobs::INC) { |j| j.(1) })].inspect
  RUBY
  ["require di una libreria standard (json) nel Ractor", <<~RUBY],
    Warning[:experimental] = false
    begin; puts WAIT.(Ractor.new { require "json"; JSON.parse("[1]") }).inspect; rescue => e; puts "\#{(e.cause || e).class}: \#{(e.cause || e).message[0, 90]}"; end
  RUBY
  ["json caricato prima nel Ractor principale, usato nel Ractor", <<~RUBY],
    Warning[:experimental] = false
    require "json"
    puts WAIT.(Ractor.new { JSON.parse("[1]") }).inspect
  RUBY
  ["Una costante non frozen letta dal Ractor", <<~RUBY],
    Warning[:experimental] = false
    TABLE = {a: 1}
    begin; WAIT.(Ractor.new { TABLE[:a] }); rescue => e; puts (e.cause || e).class; end
  RUBY
  ["Notcurses::FFI.ncstrwidth e Notcurses.strwidth nel Ractor", <<~RUBY],
    require "notcurses"
    Warning[:experimental] = false
    puts WAIT.(Ractor.new { [Notcurses::FFI.ncstrwidth("漢a", nil, nil), Notcurses.strwidth("漢a")] }).inspect
  RUBY
  ["ncvisual_from_file senza contesto, nel Ractor principale", <<~RUBY],
    require "notcurses"
    v = Notcurses::FFI.ncvisual_from_file("#{ROOT}/notcurses/data/changes.jpg")
    puts v.null? ? "NULL: il motore delle immagini lo installa notcurses_init (media/shim.c:7)" : "un ncvisual"
  RUBY
  ["Cancellazione: un thread nel Ractor riceve un messaggio e alza un flag", <<~RUBY],
    Warning[:experimental] = false
    r = Ractor.new do
      Thread.new { Ractor.receive; Ractor.current[:cancel] = true }
      n = 0
      n += 1 until Ractor.current[:cancel]
      :cancelled
    end
    sleep 0.05
    t0 = now
    r.send(:cancel)
    puts "\#{WAIT.(r)} in \#{((now - t0) * 1000).round(1)} ms"
  RUBY
  ["exit con un Ractor in un calcolo senza fine", <<~RUBY]
    pid = fork do
      Warning[:experimental] = false
      Ractor.new { loop {} }
      sleep 0.05
      exit 0
    end
    t0 = now
    Process.wait(pid)
    puts "stato \#{$?.exitstatus} dopo \#{((now - t0) * 1000).round} ms"
  RUBY
].freeze

def run_fact(code)
  cmd = [RbConfig.ruby, "-I", File.join(ROOT, "lib"), "-e", PRELUDE + code]
  Open3.popen2e(*cmd) do |stdin, out, wait|
    stdin.close
    unless out.wait_readable(TIMEOUT_S) && wait.join(TIMEOUT_S)
      Process.kill(:KILL, wait.pid)
      return "bloccato (fermato dopo #{TIMEOUT_S} s)"
    end
    text = out.read.strip
    wait.value.success? ? text.lines.last.to_s.strip : "errore: #{text.lines.last.to_s.strip}"
  end
end

puts "Ruby #{RUBY_VERSION}", ""
puts "| Fatto | Risultato |"
puts "| --- | --- |"
FACTS.each { |label, code| puts "| #{label} | #{run_fact(code).gsub("|", "\\|")} |" }
puts
