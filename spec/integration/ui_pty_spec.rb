# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require 'rbconfig'

# Il ciclo completo di Notcurses::UI::App con un terminale vero: un processo
# figlio apre un pty, ne fa il proprio terminale di controllo (così Ctrl-C e il
# cambio di dimensioni mandano SIGINT e SIGWINCH dal kernel) e un thread
# "utente" scrive i tasti sul lato master, come una persona alla tastiera.
RSpec.describe 'Notcurses::UI con un terminale (integrazione, pty)' do
  def lib_dir = File.expand_path('../../lib', __dir__)

  # Esegue script in un processo Ruby figlio e lo uccide dopo timeout secondi.
  # @return [Array(String, Process::Status, Boolean)] output, stato, true se scaduto
  def run_child(script, timeout:)
    reader, writer = IO.pipe
    pid = spawn(RbConfig.ruby, '-I', lib_dir, '-e', script, in: File::NULL, out: writer, err: writer)
    writer.close
    output = Thread.new { reader.read }
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until (done = Process.wait2(pid, Process::WNOHANG))
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        Process.kill(:KILL, pid)
        return [output.value, Process.wait2(pid).last, true]
      end
      sleep 0.05
    end
    [output.value, done.last, false]
  ensure
    reader&.close
  end

  def app_script = <<~'RUBY'
    require 'notcurses'
    require 'io/console'
    require 'pty'
    $stdout.sync = true
    ui = Notcurses::UI

    def wait_for(what)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      sleep 0.01 until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      raise "attesa scaduta: #{what}" unless yield
    end

    Process.setsid
    master, slave = PTY.open
    slave.ioctl(0x540E, 0) # TIOCSCTTY (Linux): il pty diventa il terminale di controllo
    slave.winsize = [24, 80]
    STDIN.reopen(slave)
    lock = Mutex.new
    Thread.new do
      loop do
        data = master.readpartial(65_536)
        data.scan(/\e\[6n|\e\[c/) { |q| lock.synchronize { master.write(q == "\e[6n" ? "\e[5;7R" : "\e[?62;22c") } }
      end
    rescue IOError, Errno::EIO
    end
    type = ->(keys) { lock.synchronize { master.write(keys) } }

    Notcurses::Context.open(output: slave.path, termtype: 'xterm-256color', suppress_banners: true) do |nc|
      app = ui::App.new(nc)
      form = ui::Container.new(app.root, size: 5)
      ui::Label.new(form, text: 'Nome:', size: 1)
      name = ui::TextInput.new(form, size: 1)
      pressed = []
      ui::Button.new(form, 'Invia', size: 3) { pressed << name.text }
      log = ui::LogView.new(app.root)
      sizes = []
      app.on_resize { |rows, cols| sizes << [rows, cols, app.root.plane.dims, log.plane.dims] }
      ctrl_x = 0
      app.on_key('x', ctrl: true) { ctrl_x += 1 }
      nc.mice_enable
      failure = nil
      user = Thread.new do
        wait_for('run') { app.running? }
        type.('ab')
        wait_for('testo') { name.text == 'ab' }
        type.("\t")
        wait_for('Tab') { app.focused.is_a?(ui::Button) }
        type.("\r")
        wait_for('Invio') { pressed == ['ab'] }
        type.("\e[<0;5;2M\e[<0;5;2m") # clic SGR su riga 2, colonna 5 (in base 1): il TextInput
        wait_for('clic') { app.focused.equal?(name) }
        type.("c\x18") # c e Ctrl+X
        wait_for('Ctrl+X') { name.text == 'abc' && ctrl_x == 1 }
        slave.winsize = [30, 100] # il kernel manda SIGWINCH
        wait_for('resize') { sizes.size == 1 }
        app.post do
          r, w = IO.pipe
          Notcurses::FdPlane.new(log.plane, r) { |_f, bytes| app.post { log.append(bytes) unless log.closed? } }
          Notcurses::Subprocess.new(log.plane, 'echo', 'dal figlio') do |_s, bytes|
            app.post { log.append(bytes) unless log.closed? }
          end
          w.write("riga 1\nriga 2\n")
          w.close
        end
        wait_for('dati') { (log.lines & ['riga 1', 'riga 2', 'dal figlio']).size == 3 }
        type.("\x03") # Ctrl-C: SIGINT dal terminale
      rescue StandardError => e
        failure = e
        app.stop
      end
      reason = app.run
      user.join
      puts "failure #{failure.message}" if failure
      puts "reason #{reason}"
      puts "pressed #{pressed.inspect} text #{name.text.inspect} ctrl_x #{ctrl_x}"
      puts "sizes #{sizes.inspect}"
      puts "log #{log.lines.inspect}"
    end
    puts 'fine'
  RUBY

  def eof_script = <<~'RUBY'
    require 'notcurses'
    opts = { output: '/dev/null', termtype: 'xterm-256color', suppress_banners: true, drain_input: false }
    Notcurses::Context.open(**opts) do |nc|
      app = Notcurses::UI::App.new(nc)
      app.after(5) { app.stop }
      puts "reason #{app.run}"
    end
  RUBY

  it 'tasti veri, clic SGR, resize dal kernel, dati di FdPlane e Subprocess con post, Ctrl-C → :interrupt' do
    skip 'TIOCSCTTY e /proc: solo Linux' unless RUBY_PLATFORM.include?('linux')

    out, status, timed_out = run_child(app_script, timeout: 30)
    expect(timed_out).to be(false), "processo figlio bloccato:\n#{out}"
    expect(status.exitstatus).to eq(0), out
    expect(out).not_to include('failure'), out
    expect(out).to include('reason interrupt')
    expect(out).to include('pressed ["ab"] text "abc" ctrl_x 1')
    expect(out).to include('sizes [[30, 100, [30, 100], [25, 100]]]')
    expect(out).to include('"riga 1"', '"riga 2"', '"dal figlio"') # FdPlane e Subprocess arrivano in ordine qualsiasi
    expect(out).to end_with("fine\n")
  end

  it 'a fine input (stdin su /dev/null) run restituisce :eof' do
    out, status, timed_out = run_child(eof_script, timeout: 20)
    expect(timed_out).to be(false), out
    expect(status.exitstatus).to eq(0), out
    expect(out).to include('reason eof')
  end
end
