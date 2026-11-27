# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative "../../support/nc_helpers"

# rubocop:disable ThreadSafety/NewThread -- le spec provano stop e async da un altro thread e un pipe scritto da un thread

# ICH-607: EventLoop#async (anche App#async) crea un Task sopra lo scheduler
# di run (ICH-606): il blocco attende I/O, sleep e code senza fermare il ciclo,
# e il Task si ferma (stop), si attende (wait) e cede il ciclo (pass).
RSpec.describe Notcurses::UI::Task do
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

  it "Task::Stop non deriva da StandardError" do
    expect(described_class::Stop.ancestors).to include(Exception)
    expect(described_class::Stop.ancestors).not_to include(StandardError)
  end

  it "async: il blocco parte subito, fino alla prima attesa, e riceve il Task" do
    ev = new_loop
    log = []
    task = nil
    ev.post do
      task = ev.async do |t|
        log << [:start, t.class]
        sleep 0.01
        log << [:end, t.equal?(task)]
        ev.stop
      end
      log << [:handler, task.class, task.alive?]
    end
    expect(run_loop(ev)).to eq(:stop)
    expect(log).to eq([[:start, described_class], [:handler, described_class, true], [:end, true]])
    expect(task).not_to be_alive
  end

  it "async prima di run: il blocco parte all'avvio di run" do
    ev = new_loop
    log = []
    task = ev.async do
      log << :start
      sleep 0.01
      ev.stop
    end
    expect(log).to be_empty
    expect(task).to be_alive
    expect(run_loop(ev)).to eq(:stop)
    expect(log).to eq([:start])
    expect(task).not_to be_alive
  end

  it "async: senza blocco solleva ArgumentError" do
    ev = new_loop
    expect { ev.async }.to raise_error(ArgumentError, /blocco/)
  end

  it "async da un altro thread durante run solleva Error, e il consiglio dell'errore funziona" do
    ev = new_loop
    error = nil
    seen = []
    ev.post do
      Thread.new do
        ev.async { seen << :never }
      rescue Notcurses::Error => e
        error = e
        ev.post { ev.async { seen << :posted && ev.stop } } # il consiglio del messaggio
      end
    end
    expect(run_loop(ev)).to eq(:stop)
    expect(error.message).to include("post { async { ... } }")
    expect(seen).to eq([:posted])
  end

  describe "App#async" do
    let(:app) { Notcurses::UI::App.new(nc) }

    after { app.close }

    it "un task legge un pipe e scrive in un LogView" do
      log = Notcurses::UI::LogView.new(app.root)
      r, w = IO.pipe
      reader = app.async do
        loop { log.append(r.readpartial(4096)) }
      rescue EOFError
        app.stop
      ensure
        r.close
      end
      writer = Thread.new do
        w.write("riga 1\n")
        sleep 0.05
        w.write("riga 2\n")
        w.close
      end
      timed_out = false
      app.after(5) { app.stop && (timed_out = true) }
      expect(app.run).to eq(:stop)
      writer.join
      expect(timed_out).to be(false)
      expect(log.lines).to include("riga 1", "riga 2")
      expect(reader).not_to be_alive
      expect(r).to be_closed
    end
  end

  describe "#wait" do
    it "un task attende un altro task e riceve il valore del blocco" do
      ev = new_loop
      got = nil
      ev.post do
        worker = ev.async do
          sleep 0.02
          42
        end
        ev.async do
          got = worker.wait
          ev.stop
        end
      end
      expect(run_loop(ev)).to eq(:stop)
      expect(got).to eq(42)
    end

    it "più task attendono lo stesso task e ripartono tutti" do
      ev = new_loop
      got = []
      ev.post do
        worker = ev.async do
          sleep 0.02
          :fatto
        end
        2.times { |i| ev.async { got << [i, worker.wait] } }
        ev.async do
          worker.wait
          sleep 0.01
          ev.stop
        end
      end
      expect(run_loop(ev)).to eq(:stop)
      expect(got).to contain_exactly([0, :fatto], [1, :fatto])
    end

    it "da un handler: su un task finito restituisce il valore, su uno non finito solleva Error; il consiglio funziona" do
      ev = new_loop
      results = {}
      ev.post do
        done = ev.async { :subito }
        results[:done] = done.wait
        worker = ev.async do
          sleep 0.02
          :fatto
        end
        begin
          worker.wait
        rescue Notcurses::Error => e
          results[:error] = e
        end
        ev.async do # il consiglio del messaggio: attendere da un task
          results[:advice] = worker.wait
          ev.stop
        end
      end
      expect(run_loop(ev)).to eq(:stop)
      expect(results[:done]).to eq(:subito)
      expect(results[:error].message).to include("async { task.wait }")
      expect(results[:advice]).to eq(:fatto)
    end

    it "fuori da run, su un task non finito, solleva Error" do
      ev = new_loop
      task = ev.async { :mai }
      expect { task.wait }.to raise_error(Notcurses::Error, /async \{ task.wait \}/)
    end

    it "un task che attende sé stesso solleva Error" do
      ev = new_loop
      error = nil
      ev.post do
        ev.async do |t|
          sleep 0.01
          t.wait
        rescue Notcurses::Error => e
          error = e
          ev.stop
        end
      end
      expect(run_loop(ev)).to eq(:stop)
      expect(error.message).to include("sé stesso")
    end

    it "su un task fermato restituisce nil" do
      ev = new_loop
      got = :unset
      ev.post do
        task = ev.async { sleep 10 }
        task.stop
        got = task.wait
        ev.stop
      end
      expect(run_loop(ev)).to eq(:stop)
      expect(got).to be_nil
    end
  end

  describe "#stop" do
    it "da un handler: Task::Stop arriva subito, l'ensure gira e un rescue => e non la ferma" do
      ev = new_loop
      seen = []
      ev.post do
        task = ev.async do
          sleep 10
        rescue
          seen << :rescued
        ensure
          seen << [:ensure, $!.class]
        end
        ret = task.stop
        seen << [:after_stop, task.alive?, ret.equal?(task)]
        ev.stop
      end
      expect(run_loop(ev)).to eq(:stop)
      expect(seen).to eq([[:ensure, described_class::Stop], [:after_stop, false, true]])
    end

    it "da un altro task: l'ensure del task fermato gira prima che stop ritorni" do
      ev = new_loop
      seen = []
      ev.post do
        victim = ev.async do
          sleep 10
        ensure
          seen << :ensure
        end
        ev.async do
          victim.stop
          seen << [:stopped, victim.alive?]
          ev.stop
        end
      end
      expect(run_loop(ev)).to eq(:stop)
      expect(seen).to eq([:ensure, [:stopped, false]])
    end

    it "il task su sé stesso: si ferma lì, e run continua" do
      ev = new_loop
      seen = []
      task = ev.async do |t|
        seen << :a
        t.stop
        seen << :never
      end
      ev.after(0.05) { ev.stop }
      expect(run_loop(ev)).to eq(:stop)
      expect(seen).to eq([:a])
      expect(task).not_to be_alive
    end

    it "un task fermato prima di partire non parte" do
      ev = new_loop
      seen = []
      task = ev.async { seen << :never }
      task.stop
      expect(task).not_to be_alive
      ev.post { ev.stop }
      expect(run_loop(ev)).to eq(:stop)
      expect(seen).to be_empty
      expect(task.wait).to be_nil
    end

    it "su un task finito non fa niente" do
      ev = new_loop
      task = nil
      ev.post do
        task = ev.async { :valore }
        task.stop
        ev.stop
      end
      expect(run_loop(ev)).to eq(:stop)
      expect(task.wait).to eq(:valore)
    end

    it "da un altro thread solleva Error, e il consiglio dell'errore funziona" do
      ev = new_loop
      error = nil
      seen = []
      ev.post do
        task = ev.async do
          sleep 10
        ensure
          seen << :ensure
        end
        Thread.new do
          task.stop
        rescue Notcurses::Error => e
          error = e
          ev.post do # il consiglio del messaggio
            task.stop
            ev.stop
          end
        end
      end
      expect(run_loop(ev)).to eq(:stop)
      expect(error.message).to include("post { task.stop }")
      expect(seen).to eq([:ensure])
    end
  end

  # Il thread del ciclo è quello di run, non quello che crea il task: prima
  # del fix wait da un handler bloccava il processo, quindi un processo figlio.
  it "un task creato da un altro thread prima di run: wait da un handler solleva Error, stop lo ferma" do
    script = <<~RUBY
      require "notcurses"
      $stdout.sync = true
      opts = { output: "/dev/null", termtype: "xterm-256color", suppress_banners: true, drain_input: true }
      Notcurses::Context.open(**opts) do |nc|
        ev = Notcurses::UI::EventLoop.new(nc)
        ev.after(5) { ev.stop }
        seen = []
        task = Thread.new do
          ev.async do
            sleep 10
          ensure
            seen << :ensure
          end
        end.value
        ev.post do
          begin
            task.wait
          rescue Notcurses::Error => e
            seen << e.class
          end
          task.stop
          seen << task.alive?
          ev.stop
        end
        ev.run
        puts "seen \#{seen.inspect}"
      end
    RUBY
    output, status, timed_out = NcHelpers.run_child(script, timeout: 10)
    expect(timed_out).to be(false), output
    expect(output).to include("seen [Notcurses::Error, :ensure, false]")
    expect(status).to be_success
  end

  it "all'uscita di run i task vivi ricevono Task::Stop, anche quelli di Fiber.schedule, e i loro ensure girano" do
    ev = new_loop
    seen = []
    task = ev.async do
      sleep 10
    rescue
      seen << :rescued
    ensure
      seen << [:task, $!.class]
    end
    ev.post do
      Fiber.schedule do
        sleep 10
      ensure
        seen << [:fiber, $!.class]
      end
      ev.stop
    end
    expect(run_loop(ev)).to eq(:stop)
    expect(seen).to contain_exactly([:task, described_class::Stop], [:fiber, described_class::Stop])
    expect(task).not_to be_alive
    expect(task.wait).to be_nil
    expect(Fiber.scheduler).to be_nil
  end

  it "un'eccezione non gestita di un task esce da run dopo la pulizia; wait poi restituisce nil" do
    ev = new_loop
    task = ev.async do
      sleep 0.01
      raise ArgumentError, "dal task"
    end
    expect { ev.run }.to raise_error(ArgumentError, "dal task")
    expect(ev).not_to be_running
    expect(Fiber.scheduler).to be_nil
    expect(task).not_to be_alive
    expect(task.wait).to be_nil
  end

  it "pass: due task si alternano, e restituisce il Task" do
    ev = new_loop
    log = []
    ret = nil
    ev.post do
      ev.async do |t|
        3.times do
          log << :a
          ret = t.pass
        end
      end
      ev.async do |t|
        3.times do
          log << :b
          t.pass
        end
        ev.stop
      end
    end
    expect(run_loop(ev)).to eq(:stop)
    expect(log).to eq(%i[a b a b a b])
    expect(ret).to be_a(described_class)
  end

  # Un flusso sempre pronto (/dev/zero) non fa mai attendere il task: senza
  # pass il ciclo resta fermo nel task. Il figlio legge i tasti da un pipe sul fd 0.
  it "con un flusso sempre pronto e pass, input e render continuano" do
    script = <<~RUBY
      require "notcurses"
      $stdout.sync = true
      keys_r, keys_w = IO.pipe
      STDIN.reopen(keys_r) # notcurses legge i tasti dal fd 0
      opts = { output: "/dev/null", termtype: "xterm-256color", suppress_banners: true, drain_input: false }
      Notcurses::Context.open(**opts) do |nc|
        ev = Notcurses::UI::EventLoop.new(nc)
        zero = File.open("/dev/zero")
        bytes = 0
        ev.async do |task|
          loop do
            bytes += zero.readpartial(65_536).bytesize
            task.pass
          end
        end
        keys = []
        ev.on_key("a") { keys << :a }
        ev.on_key("q") { keys << :q && ev.stop }
        ev.after(5) { keys << :timeout && ev.stop }
        Thread.new do
          sleep 0.3
          keys_w.write("a")
          sleep 0.3
          keys_w.write("q")
        end
        renders = nc.stats.renders
        reason = ev.run
        puts "reason \#{reason} keys \#{keys.inspect} renders \#{nc.stats.renders - renders >= 5} bytes \#{bytes.positive?}"
      end
    RUBY
    output, status, timed_out = NcHelpers.run_child(script, timeout: 15)
    expect(timed_out).to be(false), output
    expect(output).to include("reason stop keys [:a, :q] renders true bytes true")
    expect(status).to be_success
  end
end
# rubocop:enable ThreadSafety/NewThread
