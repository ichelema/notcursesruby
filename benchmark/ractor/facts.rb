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

# Il prototipo di background.rb con un ciclo finto: post mette il blocco in
# una coda, e il caso lo esegue con LOOP.q.pop.call.
PROTO = <<~RUBY
  require "#{ROOT}/benchmark/ractor/jobs"
  require "#{ROOT}/benchmark/ractor/background"
  class FakeLoop
    attr_reader :q
    def initialize = @q = Thread::Queue.new
    def post(&block) = @q << block
  end
  LOOP = FakeLoop.new
  BG = ProtoBackground.new(LOOP)
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
  ["Warning acceso: un secondo Ractor.new dopo la fine del primo (Ractor.count di nuovo 1)", <<~RUBY],
    a = stderr_of { WAIT.(Ractor.new { 1 }) }
    sleep 0.05
    count = Ractor.count
    b = stderr_of { WAIT.(Ractor.new { 1 }) }
    puts "\#{a.bytesize} byte, poi con Ractor.count = \#{count} \#{b.bytesize} byte su stderr"
  RUBY
  ["Warning spento a un primo Ractor.new che fallisce (argomento non copiabile), poi acceso", <<~RUBY],
    Warning[:experimental] = false
    a = stderr_of { Ractor.new(Thread.current) { 1 } rescue nil }
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
  ["Eccezione mandata dal Ractor: backtrace, NoMethodError, move: true", <<~RUBY],
    Warning[:experimental] = false
    out = []
    Ractor.new { begin; raise ArgumentError, "x"; rescue => e; Ractor.main.send(e); end }
    out << "ArgumentError con backtrace \#{Ractor.receive.backtrace.inspect}"
    out << WAIT.(Ractor.new { begin; nil.foo; rescue => e; begin; Ractor.main.send(e); "NoMethodError copiato"; rescue => x; "NoMethodError: \#{x.class}: \#{x.message}"; end; end })
    Ractor.receive if out.last == "NoMethodError copiato"
    out << WAIT.(Ractor.new { begin; raise ArgumentError, "x"; rescue => e; begin; Ractor.main.send(e, move: true); "move ok"; rescue => x; "move: \#{x.class}: \#{x.message}"; end; end })
    Ractor.receive if out.last == "move ok"
    puts out.join("; ")
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
  ["Ractor.select si sveglia con un messaggio (Ractor.current su 3.x, un Port su 4.0)", <<~RUBY],
    Warning[:experimental] = false
    wake = defined?(Ractor::Port) ? Ractor::Port.new : Ractor.current
    slow = Ractor.new { sleep 0.3; :slow }
    got = Thread.new { Ractor.select(wake, slow) }
    sleep 0.05
    t0 = now
    defined?(Ractor::Port) ? wake << :wake : Ractor.current.send(:wake)
    r, v = got.value
    puts "\#{r.equal?(slow) ? "il Ractor" : "il risveglio"} (\#{v.inspect}) dopo \#{((now - t0) * 1000).round(1)} ms"
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
  ["Ractor.make_shareable di una lambda del programma (self = main)", <<~RUBY],
    begin; Ractor.make_shareable(->(v) { v }); puts "ok"; rescue => e; puts "\#{e.class}: \#{e.message[0, 60]}"; end
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
    path = "#{ROOT}/notcurses/data/changes.jpg"
    abort "\#{path} assente: serve notcurses/data (submodule o link)" unless File.exist?(path)
    v = Notcurses::FFI.ncvisual_from_file(path)
    puts v.null? ? "NULL: il motore delle immagini lo installa notcurses_init (media/shim.c:12)" : "un ncvisual"
  RUBY
  ["ncvisual_from_file in un Ractor, con un Context aperto nel Ractor principale", <<~RUBY],
    require "notcurses"
    Warning[:experimental] = false
    path = "#{ROOT}/notcurses/data/changes.jpg"
    abort "\#{path} assente: serve notcurses/data (submodule o link)" unless File.exist?(path)
    Notcurses::Context.open(output: File::NULL, termtype: "xterm-256color", suppress_banners: true) do
      ok = WAIT.(Ractor.new(path) { |p| v = Notcurses::FFI.ncvisual_from_file(p); r = !v.null?; Notcurses::FFI.ncvisual_destroy(v) if r; r })
      $stdout.puts ok ? "un ncvisual: funziona, ma la regola 3 vuole notcurses in un solo thread alla volta" : "NULL"
    end
  RUBY
  ["Cancellazione: un thread nel Ractor riceve un messaggio e alza un flag (messaggio dopo 0, 20, 50, 80 ms)", <<~RUBY],
    Warning[:experimental] = false
    lat = [0, 20, 50, 80].map do |ms|
      r = Ractor.new do
        Thread.new { Ractor.receive; Ractor.current[:cancel] = true }
        n = 0
        n += 1 until Ractor.current[:cancel]
        :cancelled
      end
      sleep ms / 1000.0
      t0 = now
      r.send(:cancel)
      WAIT.(r)
      ((now - t0) * 1000).round
    end
    puts "flag alzato dopo \#{lat.join(", ")} ms"
  RUBY
  ["exit con un Ractor in un calcolo senza fine", <<~RUBY],
    Warning[:experimental] = false
    rd, wr = IO.pipe
    pid = fork { Ractor.new { loop {} }; sleep 0.05; wr.puts now; exit 0 }
    wr.close
    Process.wait(pid)
    puts "stato \#{$?.exitstatus}, \#{((now - rd.read.to_f) * 1000).round} ms dall'exit"
  RUBY
  ["exit con un Ractor in un calcolo senza fine e un secondo thread fermo in Ractor.receive (il corpo di RUNNER)", <<~RUBY],
    Warning[:experimental] = false
    rd, wr = IO.pipe
    pid = fork { Ractor.new { Thread.new { Ractor.receive }; loop {} }; sleep 0.05; wr.puts now; exit 0 }
    wr.close
    Process.wait(pid)
    puts "stato \#{$?.exitstatus}, \#{((now - rd.read.to_f) * 1000).round} ms dall'exit"
  RUBY
  ["Ractor vivi 50 ms dopo la fine di 20 Ractor con un secondo thread fermo in Ractor.receive", <<~RUBY],
    Warning[:experimental] = false
    20.times.map { Ractor.new { Thread.new { Ractor.receive }; :ok } }.each { |r| WAIT.(r) }
    sleep 0.05
    puts "\#{Ractor.count - 1} vivi su 20"
  RUBY
  ["kill e join del secondo thread fermo in Ractor.receive, in 100 Ractor", <<~RUBY],
    Warning[:experimental] = false
    rs = Array.new(100) { Ractor.new { t = Thread.new { Ractor.receive }; t.kill; t.join; :ok } }
    puts "\#{rs.map { |r| WAIT.(r) }.size} Ractor finiti"
  RUBY
  ["Prototipo: dopo un job consegnato, l'applicazione attende un suo Ractor con take o value", PROTO + <<~RUBY],
    BG.start(Jobs::Fail, on_error: ->(_) {}) { nil }
    LOOP.q.pop.call
    WAIT.(Ractor.new(200) { |ms| Busy.call(ms) })
    puts "take o value tornato"
  RUBY
  ["Prototipo: dopo un job consegnato, l'applicazione usa Ractor.select su un suo Ractor", PROTO + <<~RUBY],
    BG.start(Jobs::Fail, on_error: ->(_) {}) { nil }
    LOOP.q.pop.call
    Ractor.select(Ractor.new(200) { |ms| Busy.call(ms) })
    puts "select tornato"
  RUBY
  ["Prototipo: un job crea un Ractor annidato e ne attende il valore", PROTO + <<~RUBY]
    module Nested
      def self.call = (r = Ractor.new { 42 }; r.respond_to?(:value) ? r.value : r.take)
    end
    got = nil
    err = stderr_of do
      BG.start(Nested, on_error: ->(e) { got = "on_error: \#{e.class}: \#{e.message}" }) { |v| got = "consegnato \#{v}" }
      t = Thread.new { LOOP.q.pop.call }
      got = "nessuna consegna in 3 s" unless t.join(3)
    end
    puts "\#{got}; \#{err.bytesize} byte su stderr"
  RUBY
].freeze

# Esegue il fatto in un processo figlio: il risultato è l'ultima riga scritta.
# Se il figlio non finisce entro TIMEOUT_S, lo ferma e riporta l'ultima riga
# scritta prima del blocco (per esempio un take che torna e un processo che
# poi non esce).
def run_fact(code)
  cmd = [RbConfig.ruby, "-I", File.join(ROOT, "lib"), "-e", PRELUDE + code]
  Open3.popen2e(*cmd) do |stdin, out, wait|
    stdin.close
    reader = Thread.new { out.read } # rubocop:disable ThreadSafety/NewThread -- legge il figlio mentre si attende la sua fine
    finished = wait.join(TIMEOUT_S)
    Process.kill(:KILL, wait.pid) unless finished
    last = reader.value.strip.lines.last.to_s.strip
    next "bloccato (fermato dopo #{TIMEOUT_S} s)#{", dopo «#{last}»" unless last.empty?}" unless finished

    wait.value.success? ? last : "errore: #{last}"
  end
end

puts "Ruby #{RUBY_VERSION}", ""
puts "| Fatto | Risultato |"
puts "| --- | --- |"
FACTS.each { |label, code| puts "| #{label} | #{run_fact(code).gsub("|", "\\|")} |" }
puts
