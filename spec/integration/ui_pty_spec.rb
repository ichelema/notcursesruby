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

  # Otto run sullo stesso pty: ognuno stampa il motivo d'uscita, i tasti
  # arrivati a on_key e se stty -g dopo run è uguale a prima.
  def ctrl_keys_script = <<~'RUBY'
    require 'notcurses'
    require 'io/console'
    require 'pty'
    $stdout.sync = true

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
    stty = ->(flag) { IO.popen(['stty', flag], in: slave, &:read) }

    Notcurses::Context.open(output: slave.path, termtype: 'xterm-256color', suppress_banners: true) do |nc|
      app = Notcurses::UI::App.new(nc)
      keys = []
      %w[q s c].each { |k| app.on_key(k, ctrl: true) { keys << "^#{k}" } }
      app.on_key('z') { keys << 'z' }
      app.on_key('x') { raise 'boom' }
      session = lambda do |name, opts, user|
        keys.clear
        before = stty.('-g')
        failure = nil
        thread = Thread.new do
          wait_for('run') { app.running? }
          user.()
        rescue StandardError => e
          failure = e
          app.stop
        end
        reason = begin
          app.run(**opts)
        rescue RuntimeError => e
          e.message
        end
        thread.join
        same = before == stty.('-g') ? 'uguale' : 'diverso'
        puts "#{name}: #{reason} #{keys.inspect} stty #{same}#{" failure #{failure.message}" if failure}"
      end
      on = { no_flow_control: true, no_linesigs: true }
      session.('accese', on, lambda {
        type.("\x11\x13\x03z") # Ctrl+Q, Ctrl+S, Ctrl+C, z
        wait_for('tasti') { keys.include?('z') }
        app.stop
      })
      session.('spente', {}, lambda {
        type.("\x13\x11z") # il terminale consuma Ctrl+S e Ctrl+Q
        wait_for('z') { keys.include?('z') }
        type.("\x03") # Ctrl-C: SIGINT dal terminale
      })
      session.('eccezione', on, -> { type.('x') })
      session.('solo no_linesigs', { no_linesigs: true }, lambda {
        type.("\x13\x11\x03z") # Ctrl+S e Ctrl+Q restano controllo di flusso, Ctrl+C arriva
        wait_for('z') { keys.include?('z') }
        app.stop
      })
      session.('solo no_flow_control', { no_flow_control: true }, lambda {
        type.("\x11z")
        wait_for('z') { keys.include?('z') }
        type.("\x03") # ISIG resta: Ctrl-C manda SIGINT
      })
      ctrl_c = lambda {
        type.("\x03z")
        wait_for('z') { keys.include?('z') }
        app.stop
      }
      nc.linesigs_disable
      session.('isig spento prima con linesigs_disable', on, ctrl_c)
      nc.linesigs_enable
      system('stty', '-isig', in: slave)
      session.('isig spento prima con stty', on, ctrl_c)
      system('stty', 'isig', in: slave)
      system('stty', '-ixon', in: slave)
      session.('ixon spento prima', on, lambda {
        type.("\x11z")
        wait_for('z') { keys.include?('z') }
        app.stop
      })
      puts "ixon dopo #{stty.('-a')[/-?ixon\b/]}"
    end
    puts 'fine'
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

  it 'no_flow_control e no_linesigs: Ctrl+Q, Ctrl+S e Ctrl+C arrivano a on_key, e stty -g torna quello di prima' do
    skip 'TIOCSCTTY e /proc: solo Linux' unless RUBY_PLATFORM.include?('linux')

    out, status, timed_out = run_child(ctrl_keys_script, timeout: 30)
    expect(timed_out).to be(false), "processo figlio bloccato:\n#{out}"
    expect(status.exitstatus).to eq(0), out
    expect(out).not_to include('failure'), out
    expect(out).to include('accese: stop ["^q", "^s", "^c", "z"] stty uguale')
    expect(out).to include('spente: interrupt ["z"] stty uguale')
    expect(out).to include('eccezione: boom [] stty uguale')
    expect(out).to include('solo no_linesigs: stop ["^c", "z"] stty uguale')
    expect(out).to include('solo no_flow_control: interrupt ["^q", "z"] stty uguale')
    expect(out).to include('isig spento prima con linesigs_disable: stop ["^c", "z"] stty uguale')
    expect(out).to include('isig spento prima con stty: stop ["^c", "z"] stty uguale')
    expect(out).to include('ixon spento prima: stop ["^q", "z"] stty uguale')
    expect(out).to include('ixon dopo -ixon')
    expect(out).to end_with("fine\n")
  end
end
