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
        # clic trascinato sul Button (riga 4): notcurses perde il bit del movimento (32), il blocco va chiamato una volta
        type.("\e[<0;2;4M\e[<32;3;4M\e[<32;4;4M\e[<0;4;4m")
        wait_for('drag') { pressed.size == 2 }
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

  # Due tasti arrivati insieme su un pipe (fd 0, senza pty): il primo chiude il
  # run con stop o con un'eccezione, il secondo resta nella coda di notcurses
  # con il pipe di prontezza già vuoto. Ogni run ha un timer di sicurezza di 3 s.
  def queued_keys_script = <<~'RUBY'
    require 'notcurses'
    $stdout.sync = true
    keys_r, keys_w = IO.pipe
    STDIN.reopen(keys_r) # notcurses legge i tasti dal fd 0
    opts = { output: '/dev/null', termtype: 'xterm-256color', suppress_banners: true, drain_input: false }
    Notcurses::Context.open(**opts) do |nc|
      # un ciclo per coppia: i timer di sicurezza già scaduti dell'altra coppia sveglierebbero il run
      [['ab', 'stop'], ['cd', 'eccezione']].each do |keys, label|
        ev = Notcurses::UI::EventLoop.new(nc)
        got = []
        ev.on_key('a') { got << :a; ev.stop }
        ev.on_key('b') { got << :b; ev.stop }
        ev.on_key('c') { got << :c; raise 'boom' }
        ev.on_key('d') { got << :d; ev.stop }
        keys_w.write(keys)
        [label, "dopo #{label}"].each do |name|
          safety = ev.after(3) { got << :timeout; ev.stop }
          t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          reason = begin
            ev.run
          rescue RuntimeError => e
            e.message
          end
          fast = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0 < 1
          puts "#{name}: #{reason} #{got.inspect} #{fast ? 'subito' : 'in ritardo'}"
          safety.cancel
        end
      end
    end
    puts 'fine'
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
      system('stty', 'intr', 'undef', in: slave)
      session.('intr rimappato', {}, ctrl_c) # ISIG resta: il byte 0x03 è un tasto, non un segnale
      system('stty', 'intr', '^C', in: slave)
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

  # Finto terminale kitty: risponde anche a "\e[?u" con i flag 27, e notcurses
  # accende il protocollo tastiera. kitty.() dice se notcurses l'ha acceso.
  def kitty_prelude = <<~'RUBY'
    require 'notcurses'
    require 'io/console'
    require 'pty'
    $stdout.sync = true

    def wait_for(what)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      sleep 0.01 until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      raise "attesa scaduta: #{what}" unless yield
    end

    master, slave = PTY.open
    slave.winsize = [24, 80]
    STDIN.reopen(slave)
    lock = Mutex.new
    written = String.new
    answers = { "\e[6n" => "\e[5;7R", "\e[?u" => "\e[?27u", "\e[c" => "\e[?62;22c" }
    Thread.new do
      loop do
        data = master.readpartial(65_536)
        lock.synchronize { written << data }
        data.scan(/\e\[6n|\e\[\?u|\e\[c/) { |q| lock.synchronize { master.write(answers[q]) } }
      end
    rescue IOError, Errno::EIO
    end
    type = ->(keys) { lock.synchronize { master.write(keys) } }
    kitty = -> { lock.synchronize { written.include?("\e[>u\e[=27u") } }
  RUBY

  def kitty_text_script = kitty_prelude + <<~'RUBY'
    Notcurses::Context.open(output: slave.path, termtype: 'xterm-256color', suppress_banners: true) do |nc|
      app = Notcurses::UI::App.new(nc)
      field = Notcurses::UI::TextInput.new(app.root, size: 1)
      app.after(10) { app.stop }
      failure = nil
      user = Thread.new do
        wait_for('run') { app.running? }
        type.("\e[49;2;33u\e[50;2;64u") # kitty Shift+1 e Shift+2 (tastiera US)
        wait_for('testo') { field.text.size == 2 }
        app.stop
      rescue StandardError => e
        failure = e
        app.stop
      end
      reason = app.run
      user.join
      puts "failure #{failure.message}" if failure
      puts "kitty #{kitty.()} reason #{reason} text #{field.text.inspect}"
    end
    puts 'fine'
  RUBY

  # Più run dello stesso EventLoop, ognuno con un timer di sicurezza: stampa
  # il motivo d'uscita e i modificatori arrivati a on_key('c', ctrl: true),
  # più " stty diverso" se stty -g dopo run non è quello di prima.
  def kitty_signals_script = kitty_prelude + <<~'RUBY'
    stty = ->(flag) { IO.popen(['stty', flag], in: slave, &:read) }
    Notcurses::Context.open(output: slave.path, termtype: 'xterm-256color', suppress_banners: true) do |nc|
      ev = Notcurses::UI::EventLoop.new(nc)
      seen = []
      ev.on_key('c', ctrl: true) { |input| seen << input.modifier_list }
      evtypes = []
      ev.on_input { |input| evtypes << input.evtype } # :press per un byte solo se kitty è acceso (in.c:501)
      quits = 0
      Signal.trap('QUIT') { quits += 1 }
      session = lambda do |name, keys, **opts|
        seen.clear
        before = stty.('-g')
        user = keys && Thread.new do
          wait_for('run') { ev.running? }
          type.(keys)
        end
        timer = ev.after(1) { ev.stop }
        reason = ev.run(**opts)
        timer.cancel
        user&.join
        puts "#{name}: #{reason} #{seen.inspect}#{' stty diverso' if stty.('-g') != before}"
      end
      session.('numlock', "\e[99;133u")
      session.('capslock', "\e[99;69u")
      session.('solo ctrl', "\e[99;5u") # il segnale lo alza run, dopo aver letto l'evento
      session.('dopo solo ctrl', nil)
      session.('ripetizione e rilascio', "\e[99;133:2u\e[99;133:3u")
      session.('ctrl+\\ con numlock', "\e[92;133u")
      session.('no_linesigs', "\e[99;133u", no_linesigs: true)
      session.('xterm modifyOtherKeys', "\e[27;5;99~")
      session.('dopo xterm', nil)
      # ICH-454: ISIG cambiato fuori da notcurses
      system('stty', '-isig', in: slave)
      session.('stty -isig', "\e[99;5u", no_linesigs: true)
      system('stty', 'isig', in: slave)
      nc.linesigs_disable
      system('stty', 'isig', in: slave)
      session.('linesigs_disable e stty isig', "\e[99;5u")
      # ICH-456: un segnale per pressione, niente per la ripetizione e il rilascio
      nc.linesigs_enable # il default di notcurses: ISIG e il suo flag accesi
      session.('solo rilascio', "\e[99;5:3u")
      session.('solo ripetizione', "\e[99;5:2u")
      session.('premuto', "\e[99;5u")
      outside = begin
        type.("\e[99;5:2u\e[99;5:3u") # ripetizione e rilascio dopo run, con il contesto aperto
        sleep 0.3
        'nessun Interrupt'
      rescue Interrupt
        'Interrupt'
      end
      puts "fuori da run: #{outside}"
      ints = 0
      Signal.trap('INT') { ints += 1 }
      session.('premuto, ripetuto e rilasciato', "\e[99;5u\e[99;5:2u\e[99;5:3u")
      session.('ctrl+\\ premuto, ripetuto e rilasciato', "\e[92;5u\e[92;5:2u\e[92;5:3u")
      system('stty', 'intr', 'undef', in: slave)
      session.('byte 0x03', "\x03") # ISIG resta: con kitty il byte arriva :press, ma è un tasto
      system('stty', 'intr', '^C', in: slave)
      session.('tasto classico', 'a')
      puts "kitty #{kitty.()} quits #{quits} ints #{ints} evtypes #{evtypes.inspect}"
    end
    puts 'fine'
  RUBY

  # Una sessione kitty completa su App: ogni tasto arriva con la sua sequenza
  # CSI u, e i rilasci (evtype 3) devono raggiungere on_input e nessun componente.
  def kitty_app_script = kitty_prelude + <<~'RUBY'
    ui = Notcurses::UI
    Notcurses::Context.open(output: slave.path, termtype: 'xterm-256color', suppress_banners: true) do |nc|
      app = ui::App.new(nc)
      field = ui::TextInput.new(app.root, size: 1)
      pressed = 0
      button = ui::Button.new(app.root, 'Invia', size: 3) { pressed += 1 }
      ctrl_x = 0
      app.on_key('x', ctrl: true) { ctrl_x += 1 }
      releases = []
      app.on_input { |input| releases << input.evtype if input.release? }
      offered = []
      [field, button].each do |component|
        component.define_singleton_method(:offer_input) do |input|
          offered << input.evtype if input.release?
          super(input)
        end
      end
      app.after(10) { app.stop }
      failure = nil
      user = Thread.new do
        wait_for('run') { app.running? }
        type.("\e[97u\e[97;1:3u\e[98;1:1u\e[98;1:2u\e[98;1:3u") # a: pressione e rilascio, b: pressione, ripetizione e rilascio
        wait_for('testo') { field.text == 'abb' && releases.size == 2 }
        type.("\e[120;133u\e[120;133:3u") # Ctrl+X con NumLock
        wait_for('Ctrl+X') { ctrl_x == 1 && releases.size == 3 }
        type.("\e[9u\e[9;1:3u") # Tab
        wait_for('Tab') { app.focused.equal?(button) && releases.size == 4 }
        type.("\e[13u\e[13;1:3u") # Invio
        wait_for('Invio') { pressed == 1 && releases.size == 5 }
        type.("\e[99;5u") # Ctrl+C: il segnale lo alza run
      rescue StandardError => e
        failure = e
        app.stop
      end
      reason = app.run
      user.join
      puts "failure #{failure.message}" if failure
      puts "kitty #{kitty.()} reason #{reason} text #{field.text.inspect} ctrl_x #{ctrl_x} pressed #{pressed}"
      puts "releases #{releases.size} offered #{offered.size}"
    end
    puts 'fine'
  RUBY

  # Resize con il gestore SIGWINCH di notcurses (no_winch_sighandler: false): notcurses accoda
  # Key::RESIZE solo quando arriva altro input, prima di quell'input (in.c:2439-2445).
  def winch_script = <<~'RUBY'
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

    opts = { output: slave.path, termtype: 'xterm-256color', suppress_banners: true, no_winch_sighandler: false }
    Notcurses::Context.open(**opts) do |nc|
      app = ui::App.new(nc)
      log = []
      app.on_resize { |rows, cols| log << [:resize, rows, cols] }
      app.on_key('z') { log << [:z, app.root.plane.dims] }
      failure = nil
      user = Thread.new do
        wait_for('run') { app.running? }
        slave.winsize = [30, 100] # il kernel manda SIGWINCH al gestore di notcurses
        sleep 0.2 # il gestore deve aver girato prima del tasto
        type.('z')
        wait_for('z') { log.size == 2 }
        app.stop
      rescue StandardError => e
        failure = e
        app.stop
      end
      reason = app.run
      user.join
      puts "failure #{failure.message}" if failure
      puts "reason #{reason} log #{log.inspect}"
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
    expect(out).to include('pressed ["ab", "ab"] text "abc" ctrl_x 1')
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

  it 'un tasto rimasto in coda dopo stop o dopo un\'eccezione arriva subito nel run successivo' do
    out, status, timed_out = run_child(queued_keys_script, timeout: 30)
    expect(timed_out).to be(false), "processo figlio bloccato:\n#{out}"
    expect(status.exitstatus).to eq(0), out
    expect(out).to include("stop: stop [:a] subito\n", "dopo stop: stop [:a, :b] subito\n")
    expect(out).to include("eccezione: boom [:c] subito\n", "dopo eccezione: stop [:c, :d] subito\n")
    expect(out).to end_with("fine\n")
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
    expect(out).to include('intr rimappato: stop ["^c", "z"] stty uguale')
    expect(out).to include('ixon spento prima: stop ["^q", "z"] stty uguale')
    expect(out).to include('ixon dopo -ixon')
    expect(out).to end_with("fine\n")
  end

  it 'protocollo kitty: il TextInput riceve il testo digitato con Shift, non il tasto senza Shift' do
    skip 'pty e /proc: solo Linux' unless RUBY_PLATFORM.include?('linux')

    out, status, timed_out = run_child(kitty_text_script, timeout: 30)
    expect(timed_out).to be(false), "processo figlio bloccato:\n#{out}"
    expect(status.exitstatus).to eq(0), out
    expect(out).not_to include('failure'), out
    expect(out).to include('kitty true reason stop text "!@"')
    expect(out).to end_with("fine\n")
  end

  it 'protocollo kitty: Ctrl+C e Ctrl+\ sono segnali una volta per pressione, anche dopo stty, e non arrivano a on_key' do
    skip 'pty e /proc: solo Linux' unless RUBY_PLATFORM.include?('linux')

    out, status, timed_out = run_child(kitty_signals_script, timeout: 60)
    expect(timed_out).to be(false), "processo figlio bloccato:\n#{out}"
    expect(status.exitstatus).to eq(0), out
    expect(out).not_to include('stty diverso') # stty -g dopo ogni run è quello di prima
    expect(out).to include("numlock: interrupt []\n", "capslock: interrupt []\n", "solo ctrl: interrupt []\n")
    expect(out).to include("dopo solo ctrl: stop []\n") # l'evento in coda non viene consegnato
    expect(out).to include("ripetizione e rilascio: stop []\n")
    expect(out).to include("ctrl+\\ con numlock: stop []\n")
    expect(out).to include("no_linesigs: stop [[:ctrl, :numlock]]\n")
    expect(out).to include("xterm modifyOtherKeys: interrupt []\n", "dopo xterm: stop []\n")
    expect(out).to include("stty -isig: stop [[:ctrl]]\n", "linesigs_disable e stty isig: interrupt []\n") # ICH-454
    expect(out).to include("solo rilascio: stop []\n", "solo ripetizione: stop []\n", "premuto: interrupt []\n") # ICH-456
    expect(out).to include("fuori da run: nessun Interrupt\n")
    expect(out).to include("premuto, ripetuto e rilasciato: stop []\n", "ctrl+\\ premuto, ripetuto e rilasciato: stop []\n")
    expect(out).to include("byte 0x03: stop [[:ctrl]]\n")
    expect(out).to include('kitty true quits 2 ints 1 evtypes [:press]') # :press: notcurses ha acceso il protocollo
    expect(out).to end_with("fine\n")
  end

  it 'protocollo kitty: CSI u con rilasci e NumLock, Tab, Invio e Ctrl+C → :interrupt, i rilasci solo a on_input' do
    skip 'pty e /proc: solo Linux' unless RUBY_PLATFORM.include?('linux')

    out, status, timed_out = run_child(kitty_app_script, timeout: 30)
    expect(timed_out).to be(false), "processo figlio bloccato:\n#{out}"
    expect(status.exitstatus).to eq(0), out
    expect(out).not_to include('failure'), out
    expect(out).to include('kitty true reason interrupt text "abb" ctrl_x 1 pressed 1')
    expect(out).to include("releases 5 offered 0\n") # i 5 rilasci arrivano a on_input, a nessun componente
    expect(out).to end_with("fine\n")
  end

  it 'resize con il gestore SIGWINCH di notcurses: on_resize gira prima del tasto che lo porta' do
    skip 'TIOCSCTTY e /proc: solo Linux' unless RUBY_PLATFORM.include?('linux')

    out, status, timed_out = run_child(winch_script, timeout: 30)
    expect(timed_out).to be(false), "processo figlio bloccato:\n#{out}"
    expect(status.exitstatus).to eq(0), out
    expect(out).not_to include('failure'), out
    expect(out).to include('reason stop log [[:resize, 30, 100], [:z, [30, 100]]]')
    expect(out).to end_with("fine\n")
  end
end
