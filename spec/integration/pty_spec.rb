# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require 'rbconfig'

# Le funzioni che aspettano il terminale (init, posizione del cursore, readline)
# rilasciano il GVL: nella Fase 1 sono collegate con blocking: true. Qui il
# terminale è un pty con un thread Ruby che risponde alle query: con il GVL
# tenuto durante l'attesa il thread non potrebbe rispondere e il processo
# resterebbe bloccato già all'init. Gira in un processo figlio, perché lo
# stdin del processo diventa il pty. Anche le funzioni che aprono o decodificano
# un file con ffmpeg rilasciano il GVL: un esempio legge da una FIFO riempita da
# un thread dello stesso processo figlio.
RSpec.describe 'Attese del terminale senza GVL (integrazione, pty)' do
  def lib_dir = File.expand_path('../../lib', __dir__)

  # Esegue script in un processo Ruby figlio e lo uccide dopo timeout secondi.
  # @return [Array(String, Process::Status, Boolean)] output, stato, true se scaduto
  def run_child(script, timeout:, env: {})
    reader, writer = IO.pipe
    pid = spawn(env, RbConfig.ruby, '-I', lib_dir, '-e', script, in: File::NULL, out: writer, err: writer)
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

  # Terminale finto: risponde a DA1 (\e[c) e alla richiesta della posizione del
  # cursore (\e[6n) nell'ordine delle query; un altro thread conta i passi.
  def child_script = <<~'RUBY'
    require 'notcurses'
    require 'io/console'
    require 'pty'
    $stdout.sync = true
    master, slave = PTY.open
    slave.winsize = [24, 80]
    STDIN.reopen(slave)
    log = String.new(encoding: Encoding::BINARY)
    lock = Mutex.new
    Thread.new do
      loop do
        data = master.readpartial(65_536)
        lock.synchronize { log << data }
        data.scan(/\e\[6n|\e\[c/) { |q| master.write(q == "\e[6n" ? "\e[5;7R" : "\e[?62;22c") }
      end
    rescue IOError, Errno::EIO
    end
    ticks = 0
    Thread.new { loop { ticks += 1; sleep 0.005 } }
    opts = { output: slave.path, termtype: 'xterm-256color' }
    Notcurses::Context.open(**opts, suppress_banners: true) { |nc| puts "context #{nc.stdplane.dims.join('x')}" }
    Notcurses::Direct.open(**opts) do |d|
      puts "can_get_cursor #{d.can_get_cursor?}"
      puts "cursor_yx #{d.cursor_yx.join(',')}"
      d.move_cursor(y: 2) # con x: nil il C chiede la colonna al terminale
      puts 'move_cursor ok'
      Thread.new do
        sleep 0.01 until lock.synchronize { log.include?('RL> ') }
        sleep 0.3
        master.write("ab\r")
      end
      before = ticks
      line = d.readline(prompt: 'RL> ')
      puts "readline #{line.inspect} ticks #{ticks - before}"
    end
    puts 'fine'
  RUBY

  it 'init, cursor_yx, move_cursor e readline lasciano girare i thread Ruby mentre aspettano il terminale' do
    out, status, timed_out = run_child(child_script, timeout: 15)
    expect(timed_out).to be(false), "processo figlio bloccato (GVL tenuto durante un'attesa?):\n#{out}"
    expect(status.exitstatus).to eq(0), out
    expect(out).to include('context 24x80', 'can_get_cursor true', 'cursor_yx 4,6', 'move_cursor ok', 'fine')
    expect(out[/readline "ab" ticks (\d+)/, 1].to_i).to be >= 10 # readline attende circa 0,3 s
  end

  # Ctrl-C mentre l'init attende il terminale: Ruby consegna l'Interrupt al
  # ritorno della chiamata bloccante, dove il puntatore del contesto andrebbe
  # perso (contesto C orfano, registro occupato, SIGSEGV all'uscita).
  def interrupt_script = <<~'RUBY'
    require 'notcurses'
    require 'io/console'
    require 'pty'
    $stdout.sync = true
    master, slave = PTY.open
    slave.winsize = [24, 80]
    STDIN.reopen(slave)
    Thread.new do
      loop do
        data = master.readpartial(65_536)
        data.scan(/\e\[6n|\e\[c/) do |q|
          sleep 0.6 if q == "\e[c" # risposta a DA1 in ritardo: l'init attende nel C
          master.write(q == "\e[6n" ? "\e[5;7R" : "\e[?62;22c")
        end
      end
    rescue IOError, Errno::EIO
    end
    opts = { output: slave.path, termtype: 'xterm-256color' }
    [[Notcurses::Context, { suppress_banners: true }], [Notcurses::Direct, {}]].each do |klass, extra|
      Thread.new { sleep 0.2; Process.kill(:INT, Process.pid) }
      begin
        klass.new(**opts, **extra)
        puts "#{klass}: nessuna Interrupt"
      rescue Interrupt
        puts "#{klass}: Interrupt, active_context=#{Notcurses.active_context.inspect}"
      end
      klass.open(**opts, **extra) { |c| puts "#{klass}: riaperto #{c.class}" }
    end
    puts 'fine'
  RUBY

  it "un Ctrl-C durante l'attesa dell'init ferma il contesto, libera il registro ed esce pulito" do
    out, status, timed_out = run_child(interrupt_script, timeout: 30)
    expect(timed_out).to be(false), out
    expect(out).to include('Notcurses::Context: Interrupt, active_context=nil', 'Notcurses::Context: riaperto',
                           'Notcurses::Direct: Interrupt, active_context=nil', 'Notcurses::Direct: riaperto', 'fine')
    expect(status.exitstatus).to eq(0), out
  end

  # Context#get e #getvec con eventi veri scritti sul pty.
  def get_script = <<~'RUBY'
    require 'notcurses'
    require 'io/console'
    require 'pty'
    $stdout.sync = true
    master, slave = PTY.open
    slave.winsize = [24, 80]
    STDIN.reopen(slave)
    Thread.new do
      loop do
        data = master.readpartial(65_536)
        data.scan(/\e\[6n|\e\[c/) { |q| master.write(q == "\e[6n" ? "\e[5;7R" : "\e[?62;22c") }
      end
    rescue IOError, Errno::EIO
    end
    ticks = 0
    Thread.new { loop { ticks += 1; sleep 0.005 } }
    clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    Notcurses::Context.open(output: slave.path, termtype: 'xterm-256color', suppress_banners: true) do |nc|
      t0 = clock.call
      puts "timeout #{nc.get(timeout: 0.3).inspect} #{(clock.call - t0).round(1)}"
      Thread.new { sleep 0.5; master.write('ab') }
      before = ticks
      ev = nc.get(timeout: 5)
      puts "get #{ev.utf8} ticks #{ticks - before}"
      puts "get2 #{nc.get(timeout: 1).utf8}"
      Thread.new { sleep 0.3; master.write("xyz\e[A") }
      events = nc.getvec(10, timeout: 5)
      puts "getvec #{events.map { |e| e.id == Notcurses::Key::UP ? 'UP' : e.utf8 }.join(',')}"
      puts "getvec_vuoto #{nc.getvec(3, timeout: 0.2).inspect}"
      Thread.new { sleep 0.3; master.write("\ex") } # Alt+x come lo manda un terminale vero
      alt = nc.get(timeout: 5)
      puts "alt #{alt.id.chr} #{alt.alt?} #{alt.modifier_list.inspect}"
      Thread.new { sleep 0.3; Process.kill(:INT, Process.pid) }
      begin
        nc.get
      rescue Interrupt
        puts 'interrupt ok'
      end
      puts "dopo_interrupt #{nc.get(timeout: 0.1).inspect}"
    end
    puts 'fine'
  RUBY

  it 'get attende senza GVL, getvec legge più eventi, il timeout scade con nil e un Interrupt esce da get' do
    out, status, timed_out = run_child(get_script, timeout: 20)
    expect(timed_out).to be(false), "processo figlio bloccato:\n#{out}"
    expect(status.exitstatus).to eq(0), out
    expect(out).to match(/^timeout nil 0\.3$/)
    expect(out[/^get a ticks (\d+)$/, 1].to_i).to be > 20 # 0,5 s di attesa: gli altri thread girano
    expect(out).to include("get2 b\n", "getvec x,y,z,UP\n", "getvec_vuoto []\n", "alt x true [:alt]\n",
                           "interrupt ok\n", "dopo_interrupt nil\n")
    expect(out).to end_with("fine\n")
  end

  # Con il blitter :pixel ncdirect_render_image e ncdirect_raster_frame chiedono
  # la posizione del cursore al terminale (direct.c:439). Il terminale finto
  # dichiara sixel in DA1 e risponde alle query della grafica.
  def pixel_script = <<~'RUBY'
    require 'notcurses'
    require 'io/console'
    require 'pty'
    $stdout.sync = true
    master, slave = PTY.open
    slave.winsize = [24, 80, 640, 384]
    STDIN.reopen(slave)
    replies = {
      "\e[6n" => "\e[5;1R", "\e[c" => "\e[?62;4;22c", "\e[14t" => "\e[4;384;640t", "\e[18t" => "\e[8;24;80t",
      "\e[?2;1;0S" => "\e[?2;0;640;384S", "\e[?1;1;0S" => "\e[?1;0;256S"
    }
    Thread.new do
      loop do
        data = master.readpartial(65_536)
        data.scan(Regexp.union(replies.keys)) { |q| master.write(replies[q]) }
      end
    rescue IOError, Errno::EIO
    end
    Notcurses::Direct.open(output: slave.path, termtype: 'xterm-256color') do |d|
      puts "can_pixel #{d.can_pixel?}"
      d.render_image(PNG, blitter: :pixel)
      puts 'render_image ok'
      d.render_frame(PNG, blitter: :pixel).raster(align: :center)
      puts 'raster ok'
      d.stream(PNG, blitter: :pixel)
      puts 'stream ok'
    end
    puts 'fine'
  RUBY

  it 'render_image, Frame#raster e stream con il blitter :pixel lasciano girare i thread Ruby' do
    png = File.expand_path('../../notcurses/data/onedot.png', __dir__)
    out, status, timed_out = run_child("PNG = #{png.dump}\n#{pixel_script}", timeout: 20)
    expect(timed_out).to be(false), "processo figlio bloccato (GVL tenuto durante un'attesa?):\n#{out}"
    expect(out).to include('can_pixel true', 'render_image ok', 'raster ok', 'stream ok', 'fine')
    expect(status.exitstatus).to eq(0), out
  end

  # Context#close: notcurses_stop chiama tcsetattr(TCSAFLUSH) (notcurses.c:147),
  # che su macOS aspetta che il master del pty legga l'output in coda. Il thread
  # del terminale finto resta fuori da read(2) per 0,3 s dopo l'inizio della
  # chiusura: per leggere gli serve il GVL. Su Linux tcsetattr non aspetta il
  # master, e l'esempio passa anche con il GVL tenuto.
  def stop_script = <<~'RUBY'
    require 'notcurses'
    require 'io/console'
    require 'pty'
    $stdout.sync = true
    master, slave = PTY.open
    slave.winsize = [24, 80]
    STDIN.reopen(slave)
    clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    read_after = 0.0
    Thread.new do
      loop do
        sleep 0.01 while clock.call < read_after
        data = master.readpartial(65_536)
        data.scan(/\e\[6n|\e\[c/) { |q| master.write(q == "\e[6n" ? "\e[1;1R" : "\e[?62;22c") }
      end
    rescue IOError, Errno::EIO
    end
    Notcurses::Context.open(output: slave.path, termtype: 'xterm-256color', suppress_banners: true) do |nc|
      read_after = clock.call + 0.3
      slave.write(' ') # il thread esce da read(2) e resta nel ciclo di sleep
      sleep 0.1
      puts "aperto #{nc.stdplane.dims.join('x')}"
    end
    puts 'fine'
  RUBY

  it 'Context#close lascia girare i thread Ruby mentre il termios aspetta il terminale' do
    out, status, timed_out = run_child(stop_script, timeout: 20)
    expect(timed_out).to be(false), "processo figlio bloccato in Context#close (GVL tenuto in notcurses_stop?):\n#{out}"
    expect(out).to include('aperto 24x80', 'fine')
    expect(status.exitstatus).to eq(0), out
  end

  # Su macOS notcurses_stop rilascia il GVL: un'eccezione asincrona per il
  # thread che chiude sbloccherebbe tcsetattr con EINTR, e notcurses non
  # riprova. Il terminale finto è un altro processo, fermo per 0,5 s dopo il
  # byte di controllo: Thread#raise arriva mentre la chiusura aspetta. Su Linux
  # tcsetattr non aspetta, e l'eccezione arriva dopo la chiusura.
  def stop_raise_script = <<~'RUBY'
    require 'notcurses'
    require 'io/console'
    require 'pty'
    $stdout.sync = true
    master, slave = PTY.open
    slave.winsize = [24, 80]
    STDIN.reopen(slave)
    ctl_r, ctl_w = IO.pipe
    reader = fork do
      slave.close
      ctl_w.close
      STDIN.reopen(File::NULL)
      loop do
        ready, = IO.select([master, ctl_r])
        if ready.include?(ctl_r)
          break if ctl_r.read_nonblock(16, exception: false).nil?
          sleep 0.5
        end
        next unless ready.include?(master)
        data = master.readpartial(65_536)
        data.scan(/\e\[6n|\e\[c/) { |q| master.write(q == "\e[6n" ? "\e[1;1R" : "\e[?62;22c") }
      end
    rescue IOError, Errno::EIO
    end
    ctl_r.close
    termios = -> { IO.popen(%w[stty -g], in: slave, &:read) }
    before = termios.call
    raised = nil
    begin
      Notcurses::Context.open(output: slave.path, termtype: 'xterm-256color', suppress_banners: true) do
        Thread.new { sleep 0.35; Thread.main.raise(Interrupt, 'asincrona') }
        ctl_w.write('P')
        sleep 0.1
      end
      sleep 0.6
    rescue Interrupt => e
      raised = e.message
    end
    puts "eccezione #{raised}"
    puts "termios ripristinato #{termios.call == before}"
    Process.kill(:KILL, reader)
    Process.wait(reader)
    puts 'fine'
  RUBY

  it "un'eccezione asincrona durante Context#close non lascia il termios di notcurses" do
    out, status, timed_out = run_child(stop_raise_script, timeout: 20)
    expect(timed_out).to be(false), out
    expect(out).to include('eccezione asincrona', 'termios ripristinato true', 'fine')
    expect(status.exitstatus).to eq(0), out
  end

  # Ogni caso legge l'immagine da una FIFO che un thread di questo processo
  # riempie dopo 0,3 s: con il GVL tenuto durante l'apertura il thread non gira.
  def fifo_script = <<~'RUBY'
    require 'notcurses'
    require 'tmpdir'
    $stdout.sync = true
    def from_fifo(name)
      Dir.mktmpdir do |dir|
        fifo = File.join(dir, 'img.png')
        File.mkfifo(fifo)
        writer = Thread.new { sleep 0.3; File.binwrite(fifo, File.binread(PNG)) }
        yield fifo
        writer.join
        puts "#{name} ok"
      end
    end
    Notcurses::Context.open(output: '/dev/null', termtype: 'xterm-256color', suppress_banners: true,
                            drain_input: true) do
      from_fifo('from_file') { |fifo| Notcurses::Visual.from_file(fifo) { } }
    end
    Notcurses::Direct.open(output: '/dev/null', termtype: 'xterm-256color') do |d|
      from_fifo('render_frame') { |fifo| d.render_frame(fifo, blitter: :half).close }
      from_fifo('load_image') { |fifo| d.load_image(fifo) { } }
    end
  RUBY

  it 'Visual.from_file, render_frame e load_image aprono il file lasciando girare i thread Ruby' do
    png = File.expand_path('../fixtures/visual/rgbw.png', __dir__)
    out, status, timed_out = run_child("PNG = #{png.dump}\n#{fifo_script}", timeout: 20)
    expect(timed_out).to be(false), "processo figlio bloccato (GVL tenuto durante l'apertura del file?):\n#{out}"
    expect(out).to include('from_file ok', 'render_frame ok', 'load_image ok')
    expect(status.exitstatus).to eq(0), out
  end

  # Un figlio di fork esce da Context.open: il suo close non deve toccare il
  # terminale del padre (reset, \e[?1049l, termios di init).
  def fork_script = <<~'RUBY'
    require 'notcurses'
    require 'io/console'
    require 'pty'
    $stdout.sync = true
    master, slave = PTY.open
    slave.winsize = [24, 80]
    STDIN.reopen(slave)
    log = String.new(encoding: Encoding::BINARY)
    lock = Mutex.new
    Thread.new do
      loop do
        data = master.readpartial(65_536)
        lock.synchronize { log << data }
        data.scan(/\e\[6n|\e\[c/) { |q| master.write(q == "\e[6n" ? "\e[5;7R" : "\e[?62;22c") }
      end
    rescue IOError, Errno::EIO
    end
    Notcurses::Context.open(output: slave.path, termtype: 'xterm-256color', suppress_banners: true) do |nc|
      nc.render
      sleep 0.3
      before = lock.synchronize { log.bytesize }
      echo = slave.echo?
      pid = fork
      raise 'errore nel nipote' if pid.nil?
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 3
      until (done = Process.wait2(pid, Process::WNOHANG))
        break if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        sleep 0.05
      end
      unless done
        Process.kill(:KILL, pid)
        Process.wait(pid)
      end
      sleep 0.3
      puts "nipote #{done ? "uscito con #{done.last.exitstatus}" : 'bloccato'}"
      puts "byte del nipote #{lock.synchronize { log.byteslice(before..) }.inspect}"
      puts "echo #{echo} -> #{slave.echo?}"
      nc.render
      puts "render #{nc.stdplane.dims.join('x')}"
    end
    puts 'fine'
  RUBY

  it 'in un figlio di fork Context#close non scrive sul terminale e non cambia il termios del padre' do
    out, status, timed_out = run_child(fork_script, timeout: 30)
    expect(timed_out).to be(false), out
    expect(out).to include('nipote uscito con 1', 'byte del nipote ""', 'echo false -> false', 'render 24x80', 'fine')
    expect(status.exitstatus).to eq(0), out
  end

  # Testo di Direct non ancora svuotato al momento del fork: il figlio eredita
  # una copia del buffer stdio, che la libc scriverebbe alla sua uscita.
  def direct_fork_script = <<~'RUBY'
    require 'notcurses'
    require 'io/console'
    require 'pty'
    $stdout.sync = true
    master, slave = PTY.open
    slave.winsize = [24, 80]
    STDIN.reopen(slave)
    log = String.new(encoding: Encoding::BINARY)
    lock = Mutex.new
    Thread.new do
      loop do
        data = master.readpartial(65_536)
        lock.synchronize { log << data }
        data.scan(/\e\[6n|\e\[c/) { |q| master.write(q == "\e[6n" ? "\e[5;7R" : "\e[?62;22c") }
      end
    rescue IOError, Errno::EIO
    end
    count = -> { sleep 0.3; lock.synchronize { log.scan('PENDING_TOKEN').size } }
    Notcurses::Direct.open(output: slave.path, termtype: 'xterm-256color') do |d|
      d.flush
      d.putstr('PENDING_TOKEN')
      puts "prima del fork #{count.call}"
      pid = fork
      raise 'errore nel nipote' if pid.nil? # il nipote esce da open con il suo ensure, cioè close
      status = Process.wait2(pid).last
      puts "dopo il nipote #{count.call} (stato #{status.exitstatus})"
    end
    puts "dopo il padre #{count.call}"
    puts 'fine'
  RUBY

  it 'il testo di Direct non svuotato prima di un fork arriva al terminale una volta sola' do
    out, status, timed_out = run_child(direct_fork_script, timeout: 30)
    expect(timed_out).to be(false), out
    expect(out).to include('prima del fork 0', 'dopo il nipote 1 (stato 1)', 'dopo il padre 1', 'fine')
    expect(status.exitstatus).to eq(0), out
  end

  # Il terminale perde una colonna: Context#refresh restringe lo stdplane e
  # taglia il glifo largo delle colonne 10-11. Prima del fix la scrittura nella
  # nuova ultima colonna cancellava la prima cella della riga sotto.
  def shrink_script = <<~'RUBY'
    require 'notcurses'
    require 'io/console'
    require 'pty'
    $stdout.sync = true
    master, slave = PTY.open
    slave.winsize = [3, 12]
    STDIN.reopen(slave)
    Thread.new do
      loop do
        data = master.readpartial(65_536)
        data.scan(/\e\[6n|\e\[c/) { |q| master.write(q == "\e[6n" ? "\e[1;1R" : "\e[?62;22c") }
      end
    rescue IOError, Errno::EIO
    end
    Notcurses::Context.open(output: slave.path, termtype: 'xterm-256color', suppress_banners: true) do |nc|
      std = nc.stdplane
      std.putstr('ab漢', y: 1, x: 8)
      std.putstr('WXYZ', y: 2, x: 0)
      slave.winsize = [3, 11]
      puts "refresh #{nc.refresh.join('x')}"
      std.putstr('x', y: 1, x: 10)
      puts "riga 2 #{std.contents(y: 2, rows: 1).inspect}"
    end
    puts 'fine'
  RUBY

  it "dopo Context#refresh su un terminale più stretto la scrittura sul glifo tagliato lascia intatta la riga sotto" do
    out, status, timed_out = run_child(shrink_script, timeout: 30)
    expect(timed_out).to be(false), out
    expect(out).to include('refresh 3x11', 'riga 2 "WXYZ"', 'fine')
    expect(status.exitstatus).to eq(0), out
  end

  # Su uno stdplane che scorre ogni a capo ("\n" o a capo automatico) fa un
  # render dentro ncplane_put (notcurses.c:1978-1981), e il render restringe lo
  # stdplane se il terminale si è ristretto: prima del fix il resto della stessa
  # chiamata C scriveva sulla metà orfana. Il glifo di riga 2 sta nelle colonne
  # 10-11; la riga ROW è quella in cui il testo va a capo.
  def scroll_shrink_script(text, row:, col:) = "TEXT = #{text.inspect}\nROW = #{row}\nCOL = #{col}\n" + <<~'RUBY'
    require 'notcurses'
    require 'io/console'
    require 'pty'
    $stdout.sync = true
    master, slave = PTY.open
    slave.winsize = [4, 12]
    STDIN.reopen(slave)
    Thread.new do
      loop do
        data = master.readpartial(65_536)
        data.scan(/\e\[6n|\e\[c/) { |q| master.write(q == "\e[6n" ? "\e[1;1R" : "\e[?62;22c") }
      end
    rescue IOError, Errno::EIO
    end
    Notcurses::Context.open(output: slave.path, termtype: 'xterm-256color', suppress_banners: true) do |nc|
      std = nc.stdplane
      std.scrolling = true
      std.putstr('ab漢', y: ROW + 1, x: 8)
      std.putstr('WXYZ', y: 3, x: 0) if ROW + 1 < 3
      std.move_cursor(ROW, COL)
      slave.winsize = [4, 11]
      std.putstr(TEXT)
      puts "stdplane #{std.dims.join('x')} riga 3 #{std.contents(y: 3, rows: 1).inspect}"
    end
    puts 'fine'
  RUBY

  it 'su uno stdplane che scorre il render dopo "\n" non lascia la metà orfana alla scrittura che segue' do
    out, status, timed_out = run_child(scroll_shrink_script("a\n0123456789X", row: 1, col: 0), timeout: 30)
    expect(timed_out).to be(false), out
    expect(out).to include('stdplane 4x11 riga 3 "WXYZ"', 'fine')
    expect(status.exitstatus).to eq(0), out
  end

  it 'su uno stdplane che scorre il render dopo un a capo automatico non lascia la metà orfana' do
    # 11 colonne da (1, 1): la riga 1 tiene 10 "b", la riga 2 "b0123456789", "X" va a capo in (3, 0).
    # Prima del fix la riga 1 teneva 11 "b" e "X" cadeva sulla metà orfana in (2, 10): riga 3 "XYZ".
    out, status, timed_out = run_child(scroll_shrink_script("#{'b' * 11}0123456789X", row: 1, col: 1), timeout: 30)
    expect(timed_out).to be(false), out
    expect(out).to include('stdplane 4x11 riga 3 "XXYZ"', 'fine')
    expect(status.exitstatus).to eq(0), out
  end

  it 'su uno stdplane che scorre il render dopo un a capo di hline non lascia la metà orfana' do
    # 11 colonne da (1, 1): 10 "-" in riga 1, 11 in riga 2, l'ultimo va a capo in (3, 0).
    # Prima del fix la riga 1 teneva 11 "-" e l'ultimo cadeva sulla metà orfana in (2, 10): riga 3 "XYZ".
    script = scroll_shrink_script('', row: 1, col: 1).sub("std.putstr(TEXT)\n", "std.hline('-', 22, y: 1, x: 1)\n")
    out, status, timed_out = run_child(script, timeout: 30)
    expect(timed_out).to be(false), out
    expect(out).to include('stdplane 4x11 riga 3 "-XYZ"', 'fine')
    expect(status.exitstatus).to eq(0), out
  end

  it "su uno stdplane che scorre il render dopo \"\\n\" non corrompe l'heap sull'ultima riga (prima: abort di glibc)" do
    skip 'serve libc_malloc_debug di glibc' unless File.exist?('/usr/lib/libc_malloc_debug.so.0')
    env = { 'LD_PRELOAD' => '/usr/lib/libc_malloc_debug.so.0', 'MALLOC_CHECK_' => '3' }
    out, status, timed_out = run_child(scroll_shrink_script("a\n0123456789X", row: 2, col: 0), timeout: 30, env: env)
    expect(timed_out).to be(false), out
    expect(out).to include('stdplane 4x11', 'fine')
    expect(status.exitstatus).to eq(0), out
  end

  # Due wrapper dello stesso stdplane (ICH-448): A (lo stdplane tracciato)
  # controlla i bordi a 3x12, B (preso in prestito) scrive il glifo largo a
  # 3x13, poi il terminale torna a 12 colonne e taglia il glifo. Prima del fix
  # lo stato del controllo era solo di A, che a 12 colonne non rileggeva i bordi:
  # la scrittura di A sulla metà orfana cancellava la prima cella della riga sotto
  # (sull'ultima riga scriveva fuori dal framebuffer).
  def two_wrappers_script(row) = "ROW = #{row}\n" + <<~'RUBY'
    require 'notcurses'
    require 'io/console'
    require 'pty'
    $stdout.sync = true
    master, slave = PTY.open
    slave.winsize = [3, 12]
    STDIN.reopen(slave)
    Thread.new do
      loop do
        data = master.readpartial(65_536)
        data.scan(/\e\[6n|\e\[c/) { |q| master.write(q == "\e[6n" ? "\e[1;1R" : "\e[?62;22c") }
      end
    rescue IOError, Errno::EIO
    end
    Notcurses::Context.open(output: slave.path, termtype: 'xterm-256color', suppress_banners: true) do |nc|
      std = nc.stdplane
      b = Notcurses::Plane.new(std.to_ptr, owned: false, context: nc, tracked: false)
      std.putstr('WXYZ', y: 2, x: 0)
      slave.winsize = [3, 13]
      nc.refresh
      b.putstr('漢', y: ROW, x: 11)
      slave.winsize = [3, 12]
      nc.refresh
      std.putstr('x', y: ROW, x: 11)
      puts "riga 2 #{std.contents(y: 2, rows: 1).inspect}"
    end
    puts 'fine'
  RUBY

  it 'il controllo dei bordi vale per il piano C: un glifo scritto da un secondo wrapper e tagliato non rompe la riga sotto' do
    out, status, timed_out = run_child(two_wrappers_script(1), timeout: 30)
    expect(timed_out).to be(false), out
    expect(out).to include('riga 2 "WXYZ"', 'fine')
    expect(status.exitstatus).to eq(0), out
  end

  it "il glifo tagliato sull'ultima riga, scritto da un secondo wrapper, non corrompe l'heap (prima: abort di glibc)" do
    skip 'serve libc_malloc_debug di glibc' unless File.exist?('/usr/lib/libc_malloc_debug.so.0')
    env = {'LD_PRELOAD' => '/usr/lib/libc_malloc_debug.so.0', 'MALLOC_CHECK_' => '3'}
    out, status, timed_out = run_child(two_wrappers_script(2), timeout: 30, env: env)
    expect(timed_out).to be(false), out
    expect(out).to include('fine')
    expect(status.exitstatus).to eq(0), out
  end
end
