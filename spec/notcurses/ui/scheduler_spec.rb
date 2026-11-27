# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require "timeout"
require_relative "../../support/nc_helpers"

# rubocop:disable ThreadSafety/NewThread -- le spec provano unblock, post, stop e close da un altro thread

# ICH-606: durante run il ciclo è anche il Fiber scheduler del thread. I task
# (Fiber.schedule) attendono I/O, sleep, Queue e Timeout senza fermare il
# ciclo; gli handler restano sul Fiber del ciclo, che è bloccante.
RSpec.describe "Fiber scheduler di Notcurses::UI::EventLoop" do
  include_context "con un contesto notcurses"

  def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  # Ciclo con un timer di sicurezza: un risveglio mancato fa fallire l'esempio
  # (:timeout) invece di bloccare la suite.
  def new_loop(context = nc)
    ev = Notcurses::UI::EventLoop.new(context)
    ev.after(5) { ev.stop && (@timed_out = true) }
    ev
  end

  def run_loop(ev, **opts)
    @timed_out = false
    reason = ev.run(**opts)
    @timed_out ? :timeout : reason
  end

  # Script per un processo figlio: un ciclo su un contesto muto, con il blocco
  # di setup che riceve ev; il figlio stampa "ok" dopo run.
  def child_script(setup)
    <<~RUBY
      require "notcurses"
      $stdout.sync = true
      opts = { output: "/dev/null", termtype: "xterm-256color", suppress_banners: true, drain_input: true }
      Notcurses::Context.open(**opts) do |nc|
        ev = Notcurses::UI::EventLoop.new(nc)
        ev.after(5) { ev.stop }
        #{setup}
        ev.run
      end
      puts "ok"
    RUBY
  end

  it "run installa lo scheduler solo per la sua durata, e gli handler restano bloccanti" do
    ev = new_loop
    seen = nil
    ev.post do
      seen = [Fiber.scheduler.nil?, Fiber.current.blocking?]
      ev.stop
    end
    expect(run_loop(ev)).to eq(:stop)
    expect(seen).to eq([false, true])
    expect(Fiber.scheduler).to be_nil
  end

  it "fiber: Fiber.schedule parte subito, fino alla prima attesa, poi torna all'handler" do
    ev = new_loop
    log = []
    ev.post do
      fiber = Fiber.schedule do
        log << :task_start
        sleep 0.01
        log << :task_end
        ev.stop
      end
      log << [:handler, fiber.class, fiber.alive?]
    end
    expect(run_loop(ev)).to eq(:stop)
    expect(log).to eq([:task_start, [:handler, Fiber, true], :task_end])
  end

  it "io_wait: un task legge un pipe senza fermare il ciclo; timeout e scrittura" do
    ev = new_loop
    r, w = IO.pipe
    got = {}
    ev.post do
      Fiber.schedule do
        got[:timeout] = r.wait_readable(0.05)
        got[:writable] = w.wait_writable(1).equal?(w)
        got[:data] = r.readpartial(10)
        ev.stop
      end
    end
    ev.after(0.2) { got[:timer] = true } # il ciclo serve i timer mentre il task attende
    writer = Thread.new do
      sleep 0.4
      w.write("ciao")
    end
    expect(run_loop(ev)).to eq(:stop)
    expect(got).to eq(timeout: nil, writable: true, timer: true, data: "ciao")
    writer.join
  ensure
    r&.close
    w&.close
  end

  it "io_wait: due task attendono lo stesso IO e ripartono tutti e due" do
    ev = new_loop
    r, w = IO.pipe
    woken = []
    ev.post do
      2.times do |i|
        Fiber.schedule do
          r.wait_readable
          woken << i
          ev.stop if woken.size == 2
        end
      end
      ev.after(0.05) { w.write("x") }
    end
    expect(run_loop(ev)).to eq(:stop)
    expect(woken.sort).to eq([0, 1])
  ensure
    r&.close
    w&.close
  end

  # IO#close di un IO su cui attende un task: su Ruby 4.0 close passa da fiber_interrupt e attende la fine
  # dell'operazione del task. In un processo figlio, perché un risveglio mancato blocca close (regola 11).
  context "un IO chiuso mentre un task lo attende" do
    # Ruby 3.1-3.4: close lascia l'attesa del task in una lista sullo stack di close (thread.c:2682-2750 di
    # 3.4.12); dal thread del ciclo close esce con IOError e l'uscita del task scrive sulla lista rimossa
    # (segfault su 3.4.12). Difetto di Ruby, documentato nello YARD di EventLoop.
    before { skip "Ruby #{RUBY_VERSION}: close di un IO che un task attende è sicuro solo da Ruby 4.0" if RUBY_VERSION < "4.0" }

    def closing(closer)
      script = child_script(<<~RUBY)
        r, w = IO.pipe
        ev.post do
          Fiber.schedule do
            r.read(1)
          rescue IOError => e
            puts "task: \#{e.class}"
            ev.after(0.05) { ev.stop }
          end
          #{closer}
        end
      RUBY
      output, status, timed_out = NcHelpers.run_child(script, timeout: 20)
      expect(timed_out).to be(false), output
      expect(status).to be_success, output
      output
    end

    # su Ruby 4.0 close finisce dopo che il task è uscito dall'operazione: l'ordine delle due righe cambia
    it "da un altro task: il task in attesa riceve IOError" do
      expect(closing('Fiber.schedule { r.close; puts "chiuso" }').lines.sort).to eq(["chiuso\n", "ok\n", "task: IOError\n"])
    end

    it "da un altro thread: il task in attesa riceve IOError" do
      expect(closing('Thread.new { r.close; puts "chiuso" }').lines.sort).to eq(["chiuso\n", "ok\n", "task: IOError\n"])
    end

    it "da un handler: close solleva Error e l'IO resta aperto; il consiglio dell'errore funziona" do
      output = closing(<<~RUBY)
        begin
          r.close
          puts "chiuso"
        rescue Notcurses::Error => e
          puts "Error: \#{e.message[/chiudi .*/]}, aperto: \#{!r.closed?}"
          Fiber.schedule { r.close } # il consiglio del messaggio
        end
      RUBY
      expect(output).to eq("Error: chiudi l'IO da un altro task o da un altro thread, aperto: true\ntask: IOError\nok\n")
    end
  end

  it "kernel_sleep: sleep in un task non ferma il ciclo; sleep(0) cede agli altri task" do
    ev = new_loop
    log = []
    t0 = nil
    ev.post do
      t0 = clock
      Fiber.schedule do
        sleep 0.2
        log << [:slept, clock - t0 >= 0.2]
        ev.stop
      end
      Fiber.schedule {
        3.times {
          log << :a
          sleep(0)
        }
      }
      Fiber.schedule {
        3.times {
          log << :b
          sleep(0)
        }
      }
    end
    ev.after(0.05) { log << :timer }
    expect(run_loop(ev)).to eq(:stop)
    expect(log).to eq([:a, :b, :a, :b, :a, :b, :timer, [:slept, true]])
  end

  it "block e unblock: Queue#pop in un task attende il push di un altro thread; ConditionVariable con timeout" do
    ev = new_loop
    queue = Thread::Queue.new
    got = {}
    ev.post do
      Fiber.schedule do
        mutex = Thread::Mutex.new
        t0 = clock
        mutex.synchronize { Thread::ConditionVariable.new.wait(mutex, 0.05) }
        got[:waited] = clock - t0 >= 0.05
        got[:popped] = queue.pop
        ev.stop
      end
    end
    pusher = Thread.new do
      sleep 0.2
      queue << :valore
    end
    expect(run_loop(ev)).to eq(:stop)
    expect(got).to eq(waited: true, popped: :valore)
    pusher.join
  end

  it "timeout_after: Timeout.timeout in un task solleva nel task, e il ciclo continua" do
    ev = new_loop
    got = nil
    ev.post do
      Fiber.schedule do
        Timeout.timeout(0.05) { sleep 5 }
      rescue Timeout::Error => e
        got = e.class
        ev.after(0.05) { ev.stop }
      end
    end
    expect(run_loop(ev)).to eq(:stop)
    expect(got).to eq(Timeout::Error)
  end

  it "fiber_interrupt: da un altro thread e da un task l'eccezione arriva al task in attesa; da un handler Error" do
    ev = new_loop
    r, w = IO.pipe
    log = []
    ev.post do
      scheduler = Fiber.scheduler
      first = Fiber.schedule do
        r.read(1)
      rescue IOError => e
        log << [:first, e.message]
      end
      Thread.new { scheduler.fiber_interrupt(first, IOError.new("dal thread")) }
      ev.after(0.1) do
        second = Fiber.schedule do
          r.read(1)
        rescue IOError => e
          log << [:second, e.message]
        end
        Fiber.schedule { scheduler.fiber_interrupt(second, IOError.new("dal task")) }
        begin
          scheduler.fiber_interrupt(second, IOError.new("dall'handler"))
        rescue Notcurses::Error => e
          log << [:handler, e.message[/chiudi .*/]]
        end
        ev.after(0.05) { ev.stop }
      end
    end
    expect(run_loop(ev)).to eq(:stop)
    expect(log).to eq([[:first, "dal thread"], [:handler, "chiudi l'IO da un altro task o da un altro thread"],
      [:second, "dal task"]])
  ensure
    r&.close
    w&.close
  end

  it "yield: l'hook cede il ciclo agli altri task pronti" do
    ev = new_loop
    log = []
    ev.post do
      %i[a b].each do |name|
        Fiber.schedule do
          3.times do
            log << name
            Fiber.scheduler.yield
          end
          ev.stop if name == :b
        end
      end
    end
    expect(run_loop(ev)).to eq(:stop)
    expect(log).to eq(%i[a b a b a b])
  end

  it "close: all'uscita di run i task in attesa ricevono un'eccezione non StandardError e i loro ensure girano" do
    ev = new_loop
    seen = []
    ev.post do
      Fiber.schedule do
        sleep 10
      rescue
        seen << :rescued
      ensure
        seen << [:ensure, $!.is_a?(Exception) && !$!.is_a?(StandardError)]
      end
      ev.stop
    end
    expect(run_loop(ev)).to eq(:stop)
    expect(seen).to eq([[:ensure, true]])
    expect(Fiber.scheduler).to be_nil
  end

  it "close: l'eccezione dell'ensure di un task esce da run dopo la pulizia" do
    ev = new_loop
    ev.post do
      Fiber.schedule do
        sleep 10
      ensure
        raise "ensure del task"
      end
      ev.stop
    end
    expect { ev.run }.to raise_error(RuntimeError, "ensure del task")
    expect(Fiber.scheduler).to be_nil
    expect(ev).not_to be_running
  end

  it "un'eccezione non gestita di un task esce da run, come quella di un handler" do
    ev = new_loop
    ev.post {
      Fiber.schedule {
        sleep 0.01
        raise ArgumentError, "dal task"
      }
    }
    expect { ev.run }.to raise_error(ArgumentError, "dal task")
    expect(Fiber.scheduler).to be_nil
    expect(ev).not_to be_running
  end

  it "con Ruby 4.0 un task che scrive su un pipe non scrive niente su stderr (warning di IO::Buffer)" do
    script = child_script(<<~RUBY)
      r, w = IO.pipe
      ev.post do
        Fiber.schedule do
          w.write("x" * 100)
          r.read(100)
          ev.stop
        end
      end
    RUBY
    output, status, timed_out = NcHelpers.run_child(script, timeout: 20)
    expect(timed_out).to be(false), output
    expect(status).to be_success, output
    expect(output).to eq("ok\n")
  end

  context "post e stop svegliano il ciclo con un task in attesa" do
    def waiting_loop
      ev = new_loop
      ev.post { Fiber.schedule { Thread::Queue.new.pop } } # attende per sempre
      ev
    end

    it "da un altro thread" do
      ev = waiting_loop
      log = []
      Thread.new do
        sleep 0.1
        ev.post { log << :post }
        sleep 0.1
        ev.stop
      end
      t0 = clock
      expect(run_loop(ev)).to eq(:stop)
      expect(clock - t0).to be < 2
      expect(log).to eq([:post])
    end

    it "da un gestore trap" do
      ev = waiting_loop
      log = []
      old1 = Signal.trap("USR1") { ev.post { log << :post } }
      old2 = Signal.trap("USR2") { ev.stop }
      Thread.new do
        sleep 0.1
        Process.kill("USR1", Process.pid)
        sleep 0.1
        Process.kill("USR2", Process.pid)
      end
      t0 = clock
      expect(run_loop(ev)).to eq(:stop)
      expect(clock - t0).to be < 2
      expect(log).to eq([:post])
    ensure
      Signal.trap("USR1", old1 || "DEFAULT")
      Signal.trap("USR2", old2 || "DEFAULT")
    end
  end

  context "scheduler già attivo" do
    # scheduler esterno minimo, come quello di Async
    let(:external) do
      Class.new do
        def io_wait(_io, events, _timeout) = events
        def block(*) = true
        def unblock(*) = nil
        def kernel_sleep(*) = true
        def fiber_interrupt(*) = nil
        def close = nil
        def fiber(&) = Fiber.new(blocking: false, &).tap(&:resume)
      end
    end

    it "run dentro uno scheduler esterno solleva Error, senza cambiare il terminale" do
      ev = new_loop
      Fiber.set_scheduler(external.new)
      expect { ev.run }.to raise_error(Notcurses::Error, /scheduler/)
      expect(ev).not_to be_running
    ensure
      Fiber.set_scheduler(nil)
    end

    it "un run annidato in un handler resta permesso e usa lo scheduler del run esterno" do
      outer = new_loop
      seen = nil
      outer.post do
        scheduler = Fiber.scheduler
        inner = new_loop
        inner.post do
          seen = Fiber.scheduler.equal?(scheduler)
          inner.stop
        end
        seen = [inner.run, seen]
        outer.stop
      end
      expect(run_loop(outer)).to eq(:stop)
      expect(seen).to eq([:stop, true])
    end
  end

  # Prima: FiberError (attempt to transfer to a resuming fiber), perché l'attesa tornava al Fiber del ciclo,
  # fermo nel resume di Enumerator#next.
  it "un Fiber che un handler riprende con resume (Enumerator#next) attende in modo bloccante, come senza scheduler" do
    ev = new_loop
    r, w = IO.pipe
    queue = Thread::Queue.new
    log = []
    ev.post do
      e = Enumerator.new do |y|
        sleep 0.01
        y << :sleep
        Thread.new { (sleep 0.05) && queue.push(:queue) }
        y << queue.pop
        Thread.new { (sleep 0.05) && w.write("x") }
        y << r.read(1)
        y << begin
          Timeout.timeout(0.05) { sleep 1 }
        rescue Timeout::Error
          :timeout
        end
        Fiber.schedule do
          log << :task
          ev.stop
        end
        y << :scheduled
      end
      log.concat(Array.new(5) { e.next })
      log << :handler
    end
    expect(run_loop(ev)).to eq(:stop)
    expect(log).to eq([:sleep, :queue, "x", :timeout, :scheduled, :handler, :task])
  ensure
    r&.close
    w&.close
  end

  # Review di ICH-606, finding 1: un unblock arrivato prima che l'attesa bloccante registrasse il Fiber si perdeva,
  # e il processo restava fermo. In un processo figlio con timeout (regola 11).
  it "un Enumerator#next su una Queue riempita da un altro thread non perde risvegli" do
    script = child_script(<<~RUBY)
      queue = Thread::Queue.new
      count = 20_000
      ev.post do
        producer = Thread.new do
          count.times do |i|
            queue << i
            Thread.pass
          end
        end
        e = Enumerator.new { |y| loop { y << queue.pop } }
        got = Array.new(count) { e.next }
        producer.join
        puts "consegnati: \#{got.size}, in ordine: \#{got == (0...count).to_a}"
        ev.stop
      end
    RUBY
    output, status, timed_out = NcHelpers.run_child(script, timeout: 30)
    expect(timed_out).to be(false), output
    expect(status).to be_success, output
    expect(output).to eq("consegnati: 20000, in ordine: true\nok\n")
  end

  # Review di ICH-606, finding 2: un unblock rimasto in coda dopo il timeout dell'attesa riprendeva l'attesa
  # successiva del task. ConditionVariable#wait passa da kernel_sleep anche su Ruby 3.1.
  it "un unblock arrivato durante il timeout di un'attesa non accorcia l'attesa successiva del task" do
    ev = new_loop
    mutex = Thread::Mutex.new
    cond = Thread::ConditionVariable.new
    slept = nil
    ev.post do
      Fiber.schedule do
        mutex.synchronize { cond.wait(mutex, 0.1) } # scade mentre l'handler sotto tiene il ciclo
        t0 = clock
        sleep 0.3
        slept = clock - t0
        ev.stop
      end
      Thread.new { (sleep 0.15) && mutex.synchronize { cond.signal } } # unblock in coda con il ciclo fermo
      sleep 0.25 # bloccante: il timer del wait e l'unblock arrivano allo stesso giro
    end
    expect(run_loop(ev)).to eq(:stop)
    expect(slept).to be >= 0.3
  end

  it "run in un Fiber non bloccante senza scheduler: gli handler girano bloccanti" do
    ev = new_loop
    seen = nil
    ev.post do
      sleep 0.01 # bloccante: non passa dallo scheduler
      seen = Fiber.current.blocking?
      ev.stop
    end
    reason = Fiber.new(blocking: false) { run_loop(ev) }.resume
    expect(reason).to eq(:stop)
    expect(seen).to be_truthy
    expect(Fiber.scheduler).to be_nil
  end

  context "render" do
    it "con un task sempre pronto il ciclo fa al massimo max_fps render al secondo" do
      ev = new_loop
      turns = 0
      ev.post do
        Fiber.schedule do
          t0 = clock
          while clock - t0 < 0.5
            turns += 1
            sleep(0)
          end
          ev.stop
        end
      end
      renders = nc.stats.renders
      expect(run_loop(ev, max_fps: 20)).to eq(:stop)
      expect(turns).to be > 100
      expect(nc.stats.renders - renders).to be_between(3, 14) # 0,5 s a 20 al secondo, più avvio e uscita
    end

    it "quando il ciclo sta per attendere, rende subito dopo il lavoro di un task" do
      ev = new_loop
      wakes = 0
      ev.post do
        Fiber.schedule do
          5.times do
            sleep 0.02
            wakes += 1
          end
          ev.stop
        end
      end
      renders = nc.stats.renders
      expect(run_loop(ev, max_fps: 1)).to eq(:stop)
      expect(wakes).to eq(5)
      expect(nc.stats.renders - renders).to be >= 6 # avvio e un render per ogni risveglio
    end

    it "i timer interni fermati escono dalla lista dei timer" do
      ev = new_loop
      r, w = IO.pipe
      ev.post do
        Fiber.schedule do
          200.times do
            w.write("x")
            r.wait_readable(60)
            r.read(1)
          end
          ev.stop
        end
      end
      expect(run_loop(ev)).to eq(:stop)
      expect(ev.instance_variable_get(:@timers).size).to eq(1) # solo il timer di sicurezza di new_loop
    ensure
      r&.close
      w&.close
    end
  end

  it "max_fps: un numero finito maggiore di 0, anche in App#run" do
    ev = new_loop
    expect { ev.run(max_fps: "60") }.to raise_error(TypeError, /max_fps/)
    [0, -1, Float::INFINITY].each do |bad|
      expect { ev.run(max_fps: bad) }.to raise_error(ArgumentError, /max_fps/)
    end
    expect(ev).not_to be_running
    app = Notcurses::UI::App.new(nc)
    expect { app.run(max_fps: nil) }.to raise_error(TypeError, /max_fps/)
    app.post { app.stop }
    expect(app.run(max_fps: 30.5)).to eq(:stop)
  ensure
    app&.close
  end
end
# rubocop:enable ThreadSafety/NewThread
