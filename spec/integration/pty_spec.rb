# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require 'rbconfig'
require 'tmpdir'

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

  # ICH-226: un secondo Ctrl-C mentre il rollback dell'init aspetta il terminale faceva uscire il rollback a metà
  # (registro occupato per sempre, contesto C orfano), e un Thread#kill del chiamante saltava il rescue. Il
  # terminale finto risponde a DA1 solo quando lo script lo dice: nessuna ipotesi sui tempi dell'init.
  def init_abandon_script = <<~'RUBY'
    require 'notcurses'
    require 'io/console'
    require 'pty'
    $stdout.sync = true
    master, slave = PTY.open
    slave.winsize = [24, 80]
    STDIN.reopen(slave)
    answer = Queue.new
    Thread.new do
      loop do
        data = master.readpartial(65_536)
        data.scan(/\e\[6n|\e\[c/) do |q|
          answer.pop if q == "\e[c" # fino ad allora l'init attende nel C
          master.write(q == "\e[6n" ? "\e[5;7R" : "\e[?62;22c")
        end
      end
    rescue IOError, Errno::EIO
    end
    opts = { output: slave.path, termtype: 'xterm-256color' }
    registry = lambda do
      500.times { Notcurses.active_context.nil? ? break : sleep(0.01) }
      Notcurses.active_context.inspect
    end
    [[Notcurses::Context, { suppress_banners: true }], [Notcurses::Direct, {}]].each do |klass, extra|
      # il primo Ctrl-C porta new nell'attesa del rollback, il secondo ne esce
      Thread.new { 2.times { sleep 0.2; Process.kill(:INT, Process.pid) } }
      begin
        klass.new(**opts, **extra)
        puts "#{klass}: nessuna Interrupt"
      rescue Interrupt
        again = begin
          klass.new(**opts, **extra)
        rescue Notcurses::InitError
          'InitError'
        end
        puts "#{klass}: secondo Interrupt, init in corso: nuovo init #{again}"
      end
      answer << true # il terminale risponde: il thread di init ferma il contesto e libera il registro
      puts "#{klass}: registro dopo la risposta #{registry.call}"
      answer << true
      klass.open(**opts, **extra) { puts "#{klass}: riaperto dopo il secondo Ctrl-C" }

      # Thread#kill salta i rescue: il rollback parte dall'ensure, e il join torna a contesto fermato
      t = Thread.new { klass.new(**opts, **extra) }
      sleep 0.2
      t.kill
      answer << true
      t.join
      puts "#{klass}: dopo kill e join active_context=#{Notcurses.active_context.inspect}"
      answer << true
      klass.open(**opts, **extra) { puts "#{klass}: riaperto dopo kill" }
    end
    puts 'fine'
  RUBY

  it "un secondo Ctrl-C o un Thread#kill durante l'init non lasciano il registro occupato né scrivono su stderr" do
    out, status, timed_out = run_child(init_abandon_script, timeout: 30)
    expect(timed_out).to be(false), out
    lines = %w[Context Direct].flat_map do |k|
      ["Notcurses::#{k}: secondo Interrupt, init in corso: nuovo init InitError",
        "Notcurses::#{k}: registro dopo la risposta nil", "Notcurses::#{k}: riaperto dopo il secondo Ctrl-C",
        "Notcurses::#{k}: dopo kill e join active_context=nil", "Notcurses::#{k}: riaperto dopo kill"]
    end
    expect(out.lines(chomp: true)).to eq(lines + ['fine']) # stdout e stderr insieme: niente altro
    expect(status.exitstatus).to eq(0), out
  end

  # ICH-441: Process.daemon fa il fork senza Process._fork, e il processo che ha creato il contesto esce con _exit
  # senza lo stop: il terminale restava senza echo e in modo non canonico. Con un contesto aperto Process.daemon
  # solleva un errore prima del fork, e il contesto resta aperto e usabile.
  def daemon_script = <<~'RUBY'
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
    opts = { output: slave.path, termtype: 'xterm-256color' }
    [[Notcurses::Context, { suppress_banners: true }, Notcurses::ContextError],
     [Notcurses::Direct, {}, Notcurses::DirectError]].each do |klass, extra, error|
      c = klass.new(**opts, **extra)
      c.putstr('TOKEN-441') if c.is_a?(Notcurses::Direct) # senza flush: resta nel buffer stdio
      begin
        Process.daemon(true, true)
        puts "#{klass}: nessun errore pid=#{Process.pid}"
        exit!(0)
      rescue error => e
        puts "#{klass}: #{e.class} echo=#{slave.echo?} closed=#{c.closed?} dims=#{c.dims.size}"
      end
      c.close
      puts "#{klass}: chiuso echo=#{slave.echo?}"
    end
    sleep 0.2
    puts "token #{lock.synchronize { log.scan('TOKEN-441').size }}"
    $stdout.flush
    parent = Process.pid
    Process.daemon(true, true) # senza un contesto aperto: come prima
    puts "daemon #{Process.pid != parent}"
  RUBY

  it 'Process.daemon con un Context o un Direct aperto solleva un errore e lascia il contesto usabile' do
    out, status, timed_out = run_child(daemon_script, timeout: 30)
    expect(timed_out).to be(false), out
    expect(out).to include('Notcurses::Context: Notcurses::ContextError echo=false closed=false dims=2',
                           'Notcurses::Context: chiuso echo=true',
                           'Notcurses::Direct: Notcurses::DirectError echo=false closed=false dims=2',
                           'Notcurses::Direct: chiuso echo=true', 'token 1', 'daemon true')
    expect(out).not_to include('nessun errore')
    expect(status.exitstatus).to eq(0), out
  end

  # Review della PR #30: durante l'init il contesto è già registrato e il terminale è già nel modo dell'init, ma
  # pid era nil fino all'adozione: Process.daemon da un altro thread partiva e lasciava il terminale senza echo.
  def daemon_during_init_script = <<~'RUBY'
    require 'notcurses'
    require 'io/console'
    require 'pty'
    $stdout.sync = true
    master, slave = PTY.open
    slave.winsize = [24, 80]
    STDIN.reopen(slave)
    answer = Queue.new
    Thread.new do
      loop do
        data = master.readpartial(65_536)
        data.scan(/\e\[6n|\e\[c/) do |q|
          answer.pop if q == "\e[c" # l'init attende nel C finché lo script non lo sblocca
          master.write(q == "\e[6n" ? "\e[5;7R" : "\e[?62;22c")
        end
      end
    rescue IOError, Errno::EIO
    end
    opts = { output: slave.path, termtype: 'xterm-256color' }
    [[Notcurses::Context, { suppress_banners: true }, Notcurses::ContextError],
     [Notcurses::Direct, {}, Notcurses::DirectError]].each do |klass, extra, error|
      init = Thread.new { klass.new(**opts, **extra) }
      sleep 0.01 until Notcurses.active_context # registrato, init in attesa del terminale
      begin
        Process.daemon(true, true)
        puts "#{klass}: nessun errore pid=#{Process.pid}"
        exit!(0)
      rescue error => e
        puts "#{klass}: #{e.class} durante l'init"
      end
      answer << true
      init.value.close
      puts "#{klass}: chiuso echo=#{slave.echo?}"
    end
  RUBY

  it "Process.daemon solleva un errore anche mentre un altro thread è dentro l'init di Context o Direct" do
    out, status, timed_out = run_child(daemon_during_init_script, timeout: 30)
    expect(timed_out).to be(false), out
    expect(out.lines(chomp: true)).to eq(["Notcurses::Context: Notcurses::ContextError durante l'init",
      'Notcurses::Context: chiuso echo=true',
      "Notcurses::Direct: Notcurses::DirectError durante l'init",
      'Notcurses::Direct: chiuso echo=true'])
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

  # ICH-458. Terminale sixel finto che segue il cursore (quello di pixel_script risponde sempre \e[5;1R): CUP, CUU,
  # CUD, HPA e VPA si fermano ai bordi, LF e VT sull'ultima riga e SU fanno scorrere lo schermo, \e[6n riceve la
  # posizione vera. Di ogni sixel registra la riga dello schermo, le righe già scorse e l'altezza: riga + righe
  # scorse è la riga del contenuto, che resta la stessa quando lo schermo scorre. Due frame sono uno sopra l'altro se
  # hanno la stessa riga del contenuto.
  # SCROLL = false: un sixel non fa scorrere lo schermo e lascia il cursore sulla sua ultima riga.
  # SCROLL = true: un sixel lascia il cursore sulla riga sotto; se finisce sull'ultima riga lo schermo scorre di una
  # riga (termdesc.h:165-166).
  # MAX_GEOMETRY = false: il terminale non risponde a XTSMGRAPHICS, notcurses non limita l'altezza di un sixel a
  # rows - 1 (notcurses.c:430-441) e :stretch dà un frame alto quanto lo schermo.
  def sixel_stream_script(row:, scroll:, scale: :scale, max_geometry: true)
    video = File.expand_path('../fixtures/visual/frames.mkv', __dir__)
    "VIDEO = #{video.dump}\nROW = #{row}\nSCROLL = #{scroll}\nSCALE = #{scale.inspect}\n" \
      "MAX_GEOMETRY = #{max_geometry}\n" + <<~'RUBY'
        require 'notcurses'
        require 'io/console'
        require 'pty'
        $stdout.sync = true

        class SixelTerminal
          ROWS = 24
          COLS = 80
          CELL_HEIGHT = 16
          TOKEN = /\A(?:\e[P_].*?\e\\|\e\].*?(?:\a|\e\\)|\e\[[0-?]*[ -\/]*[@-~]|\e[^\[\]P_]|[^\e])/mn
          REPLIES = {
            "\e[c" => "\e[?62;4;22c", "\e[14t" => "\e[4;384;640t", "\e[18t" => "\e[8;24;80t",
            "\e[?2;1;0S" => (MAX_GEOMETRY ? "\e[?2;0;640;384S" : nil), "\e[?1;1;0S" => "\e[?1;0;256S"
          }.compact.freeze

          attr_reader :frames, :done

          def initialize(master)
            @master = master
            @buffer = String.new(encoding: Encoding::BINARY)
            @row = ROW
            @col = @scrolled = 0
            @frames = []
            @done = Queue.new
          end

          # Una sequenza spezzata fra due letture resta nel buffer fino alla lettura successiva.
          def feed(data)
            @buffer << data
            while (token = @buffer.slice!(TOKEN))
              handle(token)
            end
          end

          def handle(token)
            if token == "\e[6n" then @master.write("\e[#{@row + 1};#{@col + 1}R")
            elsif token == "\e[5n" then @done.push(true) # lo manda lo script dopo la chiusura di Direct
            elsif REPLIES.key?(token) then @master.write(REPLIES[token])
            elsif token.start_with?("\eP") then sixel(token)
            elsif (m = token.match(/\A\e\[(\d*);?(\d*)([ABGHSd])\z/n)) then csi(m[3], m[1].to_i, m[2].to_i)
            elsif ["\n", "\v", "\f"].include?(token) then line_feed
            elsif token == "\r" then @col = 0
            end
          end

          # Un parametro assente o 0 vale 1.
          def csi(final, first, second)
            first = 1 if first.zero?
            second = 1 if second.zero?
            case final
            when 'A' then @row = [@row - first, 0].max
            when 'B' then @row = [@row + first, ROWS - 1].min
            when 'G' then @col = [first, COLS].min - 1
            when 'd' then @row = [first, ROWS].min - 1
            when 'S' then @scrolled += first
            when 'H'
              @row = [first, ROWS].min - 1
              @col = [second, COLS].min - 1
            end
          end

          def line_feed
            if @row == ROWS - 1 then @scrolled += 1
            else @row += 1
            end
          end

          # Le query DCS (XTGETTCAP) non hanno gli attributi raster: i frame sono solo i sixel.
          def sixel(token)
            height = token[/\A\eP[\d;]*q"\d+;\d+;\d+;(\d+)/n, 1] or return
            rows = (height.to_i + CELL_HEIGHT - 1) / CELL_HEIGHT
            @frames << [@row, @scrolled, rows]
            @row += SCROLL ? rows : rows - 1
            return if @row < ROWS

            @scrolled += @row - (ROWS - 1) if SCROLL
            @row = ROWS - 1
          end
        end

        master, slave = PTY.open
        slave.winsize = [24, 80, 640, 384]
        STDIN.reopen(slave)
        terminal = SixelTerminal.new(master)
        Thread.new do
          loop { terminal.feed(master.readpartial(65_536)) }
        rescue IOError, Errno::EIO
        end
        Notcurses::Direct.open(output: slave.path, termtype: 'xterm-256color') do |d|
          puts "can_pixel #{d.can_pixel?}"
          d.stream(VIDEO, blitter: :pixel, scale: SCALE)
        end
        slave.write("\e[5n") # il terminale ha letto tutto l'output di Direct quando arriva qui
        terminal.done.pop
        puts "frames #{terminal.frames.map { |frame| frame.join('/') }.join(' ')}"
        puts 'fine'
      RUBY
  end

  # @return [Array<Array(Integer, Integer, Integer)>] di ogni sixel: riga dello schermo, righe già scorse, altezza
  def sixel_frames(**opts)
    out, status, timed_out = run_child(sixel_stream_script(**opts), timeout: 30)
    expect(timed_out).to be(false), "processo figlio bloccato:\n#{out}"
    expect(out).to include('can_pixel true', 'fine')
    expect(status.exitstatus).to eq(0), out
    out[/^frames (.*)$/, 1].split.map { |frame| frame.split('/').map(&:to_i) }
  end

  # Il video ha 4 frame. Con :scale un frame è alto 23 righe (rows - 1, il massimo di un sixel) e largo 46 colonne.
  # Controlla che lo stream partito dalla riga row disegni ogni frame sulle righe del primo.
  def expect_frames_in_place(row:, scroll:)
    frames = sixel_frames(row: row, scroll: scroll)
    expect(frames.map(&:last)).to eq([23, 23, 23, 23])
    content_rows = frames.map { |screen_row, scrolled, _| screen_row + scrolled }
    expect(content_rows.uniq.size).to eq(1), "dalla riga #{row}: #{frames.inspect}"
  end

  # Dalla riga 23 il frame non entra sotto il cursore, e il C lo sposterebbe in alto fino a farlo finire sull'ultima
  # riga (direct.c:442-448); dalla riga 1 finirebbe sull'ultima riga senza spostamenti. Dopo un frame che finisce
  # sull'ultima riga il C manda una CUP alla riga sotto lo schermo (direct.c:607-613). Prima del fix i frame dopo il
  # primo partivano una riga più in alto.
  it 'stream con :pixel in fondo allo schermo disegna ogni frame sulle righe del primo: terminale che ferma la CUP' do
    aggregate_failures do
      expect_frames_in_place(row: 23, scroll: false)
      expect_frames_in_place(row: 1, scroll: false)
    end
  end

  # Passa anche prima del fix: lo scorrimento dopo il primo frame compensava la riga in meno. Fallisce se stream
  # rimette ogni frame sulla riga di schermo del primo, come suggeriva la issue: lo schermo scorre a ogni frame.
  it "stream con :pixel in fondo allo schermo: terminale che scorre dopo un sixel sull'ultima riga" do
    aggregate_failures do
      expect_frames_in_place(row: 23, scroll: true)
      expect_frames_in_place(row: 1, scroll: true)
    end
  end

  it 'stream con :pixel e spazio sotto il cursore non sposta i frame e non fa scorrere lo schermo' do
    tall = [[0, 0, 23]] * 4
    small = [[2, 0, 1]] * 4
    expect(sixel_frames(row: 0, scroll: false)).to eq(tall)
    expect(sixel_frames(row: 0, scroll: true)).to eq(tall)
    expect(sixel_frames(row: 2, scroll: false, scale: :none)).to eq(small)
    expect(sixel_frames(row: 2, scroll: true, scale: :none)).to eq(small)
  end

  # Il C porta il frame alla riga 0 e fa scorrere lo schermo di y - 1 = 4 righe (direct.c:442-455). Se un sixel
  # sull'ultima riga fa scorrere lo schermo, lo schermo scorre a ogni frame: non c'è una riga libera da lasciare.
  it 'stream con :pixel di un frame alto quanto lo schermo parte dalla riga 0 a ogni frame, come prima' do
    full = { row: 5, scale: :stretch, max_geometry: false }
    expect(sixel_frames(**full, scroll: false)).to eq([[0, 4, 24]] * 4)
    expect(sixel_frames(**full, scroll: true)).to eq([[0, 4, 24], [0, 5, 24], [0, 6, 24], [0, 7, 24]])
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

  # ICH-474: un'eccezione asincrona consegnata al ritorno di ncvisual_from_file o ncdirectf_from_file, prima che il
  # wrapper incapsulasse il puntatore, lasciava allocato il visual con il file aperto. Il writer è un processo
  # esterno: apre subito la FIFO e scrive l'immagine dopo 0,6 s; l'eccezione parte a 0,2 s.
  def fifo_raise_script = <<~'RUBY'
    require 'notcurses'
    require 'rbconfig'
    require 'tmpdir'
    $stdout.sync = true
    dir = Dir.mktmpdir
    fd_dir = File.directory?('/proc/self/fd') ? '/proc/self/fd' : '/dev/fd'
    # il blocco riceve la FIFO e restituisce l'esito, o solleva l'eccezione asincrona
    interrupted = lambda do |name, &block|
      fifo = File.join(dir, "#{name}.png")
      File.mkfifo(fifo)
      writer = spawn(RbConfig.ruby, '-e', 'File.open(ARGV[0], "w") { |f| sleep 0.6; f.write(File.binread(ARGV[1])) }',
                     fifo, PNG)
      result = begin
        block.call(fifo)
      rescue RuntimeError => e
        e.message
      end
      Process.wait(writer)
      puts "#{name}: #{result}"
    end
    raise_in = ->(thread) { Thread.new { sleep 0.2; thread.raise(RuntimeError, 'interrotto') } }
    fds = nil
    Notcurses::Context.open(output: '/dev/null', termtype: 'xterm-256color', suppress_banners: true,
                            drain_input: true) do |nc|
      fds = Dir.children(fd_dir).size
      interrupted.call('from_file') do |fifo|
        raise_in.call(Thread.current)
        Notcurses::Visual.from_file(fifo) { }
        'nessuna eccezione'
      end
      interrupted.call('fdplane') do |fifo|
        started = Queue.new
        r, w = IO.pipe
        nc.stdplane.create_child(rows: 2, cols: 10) do |plane|
          f = Notcurses::FdPlane.new(plane, r, on_data: ->(_, _) { started << true; Notcurses::Visual.from_file(fifo) { } })
          w.write('x')
          started.pop
          sleep 0.2
          f.close # il kill del thread di lettura arriva al ritorno della chiamata C
          w.close
          'close'
        end
      end
      puts "Context: descrittori in più #{Dir.children(fd_dir).size - fds}"
    end
    Notcurses::Direct.open(output: '/dev/null', termtype: 'xterm-256color') do |d|
      fds = Dir.children(fd_dir).size
      interrupted.call('load_image') do |fifo|
        raise_in.call(Thread.current)
        d.load_image(fifo) { }
        'nessuna eccezione'
      end
      puts "Direct: descrittori in più #{Dir.children(fd_dir).size - fds}"
    end
  RUBY

  it "un'eccezione asincrona durante Visual.from_file o Direct#load_image non lascia il file aperto" do
    png = File.expand_path('../fixtures/visual/rgbw.png', __dir__)
    out, status, timed_out = run_child("PNG = #{png.dump}\n#{fifo_raise_script}", timeout: 30)
    expect(timed_out).to be(false), out
    expect(out).to include('from_file: interrotto', 'fdplane: close', 'Context: descrittori in più 0',
                           'load_image: interrotto', 'Direct: descrittori in più 0')
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

  # Su un piano con un bitmap ncplane_at_yx_cell fallisce sempre (notcurses.c:274-277): i controlli dei glifi larghi
  # leggono la cella come "non è un glifo" e i metodi funzionano come prima (fix di review di ICH-450).
  # Con kitty: true il terminale finto si dichiara Kitty, che libera il buffer della sequenza dello sprixel dopo il
  # disegno (kitty.c:1186-1188); dopo nc.render ncplane_at_yx fa strdup(NULL) (notcurses.c:243): at andava in
  # crash, e ora solleva PlaneError su ogni piano con un bitmap (ICH-493).
  def bitmap_plane_script(kitty: false) = "KITTY = #{kitty}\n" + <<~'RUBY'
    require 'notcurses'
    require 'io/console'
    require 'pty'
    $stdout.sync = true
    master, slave = PTY.open
    slave.winsize = [24, 80, 640, 384]
    STDIN.reopen(slave)
    replies = {
      "\e[6n" => "\e[5;1R", "\e[c" => KITTY ? "\eP>|kitty(0.36.0)\e\\\e_Gi=1;OK\e\\\e[?62;c" : "\e[?62;4;22c",
      "\e[14t" => "\e[4;384;640t", "\e[18t" => "\e[8;24;80t",
      "\e[?2;1;0S" => "\e[?2;0;640;384S", "\e[?1;1;0S" => "\e[?1;0;256S"
    }
    Thread.new do
      loop do
        data = master.readpartial(65_536)
        data.scan(Regexp.union(replies.keys)) { |q| master.write(replies[q]) }
      end
    rescue IOError, Errno::EIO
    end
    Notcurses::Context.open(output: slave.path, termtype: 'xterm-256color', suppress_banners: true) do |nc|
      puts "pixel #{nc.pixel_support}"
      host = nc.stdplane.create_child(rows: 5, cols: 8)
      rgba = "\xff".b * (64 * 64 * 4)
      bm = Notcurses::Visual.from_rgba(rgba, rows: 64, cols: 64) { |v| v.blit(plane: host, blitter: :pixel, child: true) }
      nc.render if KITTY
      ops = {at: -> { bm.at(y: 0, x: 0) }, contents: -> { bm.contents }, erase_region: -> { bm.erase_region(0, 1, 1, 1) },
             gradient: -> { bm.gradient('g', 0, 0, 0, 0, x: 1, rows: 1, cols: 1) }, polyfill: -> { bm.polyfill('x', y: 0, x: 0) }}
      ops = ops.merge(putstr: -> { bm.putstr('x', y: 0, x: 0) }) if KITTY
      ops.each do |name, op|
        op.call
        puts "#{name} ok"
      rescue Notcurses::Error => e
        puts "#{name} #{e.class}: #{e.message}"
      end
    end
    puts 'fine'
  RUBY

  # ICH-493 (opzione A dell'utente): at solleva PlaneError su ogni piano con un bitmap, sixel compreso, come
  # contents; prima restituiva la sequenza dello sprixel (sixel) o andava in SIGSEGV (kitty dopo il render).
  it 'su un piano con un bitmap at solleva PlaneError, erase_region, gradient e polyfill funzionano come prima' do
    out, status, timed_out = run_child(bitmap_plane_script, timeout: 30)
    expect(timed_out).to be(false), out
    expect(out).to include('at Notcurses::PlaneError', 'contents Notcurses::PlaneError', 'erase_region ok', 'gradient ok', 'polyfill ok', 'fine')
    expect(status.exitstatus).to eq(0), out
  end

  # ICH-487 (review): il fallback di half_at chiamava ncplane_at_yx anche sui piani con un bitmap.
  it 'su un piano con un bitmap kitty già disegnato le scritture sollevano PlaneError (prima: SIGSEGV)' do
    out, status, timed_out = run_child(bitmap_plane_script(kitty: true), timeout: 30)
    expect(timed_out).to be(false), out
    expect(out).to include('pixel kitty_animated', 'at Notcurses::PlaneError', 'contents Notcurses::PlaneError',
                           'erase_region ok', 'gradient ok', 'polyfill ok', 'putstr Notcurses::PlaneError', 'fine')
    expect(status.exitstatus).to eq(0), out
  end

  # ICH-550. Un blit :pixel su un piano esistente non scrive celle, e dopo il blit ncplane_at_yx_cell fallisce su
  # ogni cella (notcurses.c:274-277): il controllo dei glifi larghi di ICH-486 li prendeva per coperti a metà e
  # svuotava la sola metà sinistra. Il resize e i due render tolgono il bitmap: le celle tornano leggibili.
  def pixel_over_glyphs_script = <<~'RUBY'
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
    Notcurses::Context.open(output: slave.path, termtype: 'xterm-256color', suppress_banners: true) do |nc|
      puts "pixel #{nc.pixel_support}"
      ffi = Notcurses::FFI
      pl = nc.stdplane.create_child(rows: 4, cols: 10)
      pl.putstr('漢字ab', y: 0, x: 0)
      pl.putstr('VWXYZ', y: 1, x: 0)
      rgba = "\xff".b * (32 * 80 * 4)
      Notcurses::Visual.from_rgba(rgba, rows: 32, cols: 80) { |v| v.blit(plane: pl, blitter: :pixel, scale: :none) }
      nc.render
      pl.resize(2, 7)
      2.times { nc.render }
      halves = (0...6).map do |x|
        cell = ffi::NcCell.new
        next :illeggibile if ffi.ncplane_at_yx_cell(pl.to_ptr, 0, x, cell).negative?

        half = if ffi.nccell_wide_left_p(cell) then :left
               elsif ffi.nccell_wide_right_p(cell) then :right
               else :none
               end
        ffi.nccell_release(pl.to_ptr, cell)
        half
      end
      puts "riga 0 #{halves.join(' ')}"
      # sopra una metà destra orfana in colonna 3 il C cancellerebbe anche la cella 4 (notcurses.c:1956-1962)
      pl.putstr('中', y: 0, x: 2)
      puts "scrittura larga #{pl.contents(y: 0, rows: 1) == '漢中ab'} #{pl.contents(y: 1, rows: 1) == 'VWXYZ'}"
    end
    puts 'fine'
  RUBY

  it 'un blit :pixel sopra glifi larghi li lascia interi (prima: metà destre orfane, tolto il bitmap)' do
    out, status, timed_out = run_child(pixel_over_glyphs_script, timeout: 30)
    expect(timed_out).to be(false), out
    expect(out).to include('pixel sixel', 'riga 0 left right left right none none', 'scrittura larga true true', 'fine')
    expect(status.exitstatus).to eq(0), out
  end

  # Review della PR #29 (ICH-486, ICH-549): con xterm-256color :quad, :sextant e :octant degradano a :half, e la
  # matrice di visual_spec.rb non li esercita. Il terminale finto si presenta come foot (XTVERSION): notcurses
  # attiva i tre blitter, e no_degrade: true fa fallire il blit se il blitter non c'è.
  def foot_blitters_script(mutate: false) = "MUTATE = #{mutate}\n" + <<~'RUBY'
    require 'notcurses'
    require 'io/console'
    require 'pty'
    $stdout.sync = true
    if MUTATE # senza il controllo dei glifi larghi: la spec deve fallire
      Notcurses::Plane.prepend(Module.new { def keeping_glyphs_whole(*, **) = yield })
    end
    master, slave = PTY.open
    slave.winsize = [24, 80, 640, 384]
    STDIN.reopen(slave)
    replies = { "\e[6n" => "\e[5;1R", "\e[c" => "\eP>|foot(1.20.0)\e\\\e[?62;22c" }
    Thread.new do
      loop do
        data = master.readpartial(65_536)
        data.scan(Regexp.union(replies.keys)) { |q| master.write(replies[q]) }
      end
    rescue IOError, Errno::EIO
    end
    Notcurses::Context.open(output: slave.path, termtype: 'xterm-256color', suppress_banners: true) do |nc|
      red = [255, 0, 0, 255].pack('C*')
      blits = {
        blit_rgba: ->(p, b, x) { Notcurses::Visual.blit_rgba(red, plane: p, rows: 1, cols: 1, blitter: b, no_degrade: true, y: 0, x: x) },
        blit: ->(p, b, x) { Notcurses::Visual.from_rgba(red, rows: 1, cols: 1) { |v| v.blit(plane: p, blitter: b, no_degrade: true, y: 0, x: x) } }
      }
      blits.each do |name, blit|
        %i[quad sextant octant].product([2, 3]).each do |b, x|
          nc.stdplane.create_child(rows: 2, cols: 4) do |p|
            p.putstr('ab漢', y: 0, x: 0)
            p.putstr('WXYZ', y: 1, x: 0)
            blit.call(p, b, x)
            other = p.at(y: 0, x: x == 2 ? 3 : 2).egc
            p.putstr('中', y: 0, x: 2)
            puts "#{name} #{b} x=#{x}: #{other.inspect} #{p.contents(y: 1, rows: 1)}"
          end
        end
      end
    end
    puts 'fine'
  RUBY

  it ':quad, :sextant e :octant sopra metà di un glifo largo lasciano vuota l\'altra metà (terminale foot)' do
    out, status, timed_out = run_child(foot_blitters_script, timeout: 30)
    expect(timed_out).to be(false), out
    expect(status.exitstatus).to eq(0), out
    lines = out.lines.grep(/x=/)
    expect(lines.size).to eq(12), out
    expect(lines).to all(end_with(": \"\" WXYZ\n"))
    # la spec fallisce senza il controllo: altrimenti non proteggerebbe niente
    mutated, = run_child(foot_blitters_script(mutate: true), timeout: 30)
    expect(mutated.lines.grep(/x=/).grep_v(/: "" WXYZ$/)).not_to be_empty
  end

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

  # ICH-222: con output: su un file Direct#close porta il fd 1 su /dev/null durante ncdirect_stop. Qui il fd 1 è il
  # terminale (aperto in lettura e scrittura), come in una shell interattiva. Il testo che il terminale riceve fra
  # "mark" e "fine" è l'output dello stop: niente reset del C, e dopo lo stop lo stdout è di nuovo il terminale.
  def direct_stop_tty_script(out) = "OUT = #{out.dump}\n" + <<~'RUBY'
    require 'notcurses'
    require 'io/console'
    require 'pty'
    master, slave = PTY.open
    slave.winsize = [24, 80]
    STDIN.reopen(slave)
    STDOUT.reopen(slave)
    STDOUT.sync = true
    seen = String.new(encoding: Encoding::BINARY)
    Thread.new do
      loop do
        data = master.readpartial(65_536)
        seen << data
        data.scan(/\e\[6n|\e\[c/) { |q| master.write(q == "\e[6n" ? "\e[1;1R" : "\e[?62;22c") }
      end
    rescue IOError, Errno::EIO
    end
    d = Notcurses::Direct.new(output: OUT, termtype: 'xterm-256color')
    STDOUT.write("mark\n")
    d.close
    STDOUT.write("fine\n")
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
    # il pty scrive "\r\n" al posto di "\n" (ONLCR)
    sleep 0.01 until seen.include?('fine') || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
    abort 'stdout non ripristinato: il terminale non ha ricevuto "fine" dopo lo stop' unless seen.include?('fine')
    STDERR.puts "stop #{seen[/mark\r?\n(.*)fine/m, 1].inspect}"
  RUBY

  it 'Direct#close con output: su un file e lo stdout sul terminale non scrive il reset sul terminale (prima: SIGSEGV)' do
    Dir.mktmpdir do |dir|
      out, status, timed_out = run_child(direct_stop_tty_script(File.join(dir, 'out')), timeout: 20)
      expect(timed_out).to be(false), "processo figlio bloccato:\n#{out}"
      expect(status.exitstatus).to eq(0), out
      expect(out).to match(/^stop "/)
      expect(out).not_to include('\e[39;49m')
    end
  end

  # ICH-218: il ridisegno di ncreader accende il cursore del terminale (reader.c:105). Il terminale finto registra
  # le sequenze; per ogni operazione del reader il figlio stampa l'ultima fra \e[?25h (mostra) e \e[?25l (nasconde).
  # order: i valori di cursor: dei reader, nell'ordine in cui girano (ICH-580).
  def reader_cursor_script(order) = (<<~'RUBY').sub('ORDER', order.inspect)
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
        data.scan(/\e\[6n|\e\[c/) { |q| master.write(q == "\e[6n" ? "\e[1;1R" : "\e[?62;22c") }
      end
    rescue IOError, Errno::EIO
    end
    last = lambda do |&op|
      mark = lock.synchronize { log.bytesize }
      op.call
      sleep 0.2
      lock.synchronize { log.byteslice(mark..) }.scan(/\e\[\?25[hl]/).last.inspect
    end
    backspace = Notcurses::Input.synthesize(Notcurses::Key::BACKSPACE)
    Notcurses::Context.open(output: slave.path, termtype: 'xterm-256color', suppress_banners: true) do |nc|
      ORDER.each do |managed|
        Notcurses::Reader.open(nc.stdplane.create_child(rows: 1, cols: 10, y: 2, x: 2), cursor: managed) do |reader|
          puts "cursor: #{managed} write #{last.call { reader.write('ab') }}"
          puts "cursor: #{managed} backspace #{last.call { reader.offer_input(backspace) }}"
          puts "cursor: #{managed} move_left #{last.call { reader.move_left }}"
        end
      end
    end
    puts 'fine'
  RUBY

  it 'con cursor: false il reader lascia nascosto il cursore del terminale; con cursor: true lo mostra (prima: sempre acceso)' do
    out, status, timed_out = run_child(reader_cursor_script([false, true]), timeout: 30)
    expect(timed_out).to be(false), out
    expect(status.exitstatus).to eq(0), out
    expect(out.lines.grep(/^cursor: false/)).to eq(%w[write backspace move_left].map { |op| "cursor: false #{op} \"\\e[?25l\"\n" })
    expect(out).to include('cursor: true write "\e[?25h"', 'fine')
    expect(out.lines.grep(/^cursor: true/)).not_to include(a_string_including('25l'))
  end

  it 'con cursor: false il reader lascia nascosto il cursore anche dopo un reader con cursor: true (ICH-580, prima: acceso)' do
    out, status, timed_out = run_child(reader_cursor_script([true, false]), timeout: 30)
    expect(timed_out).to be(false), out
    expect(status.exitstatus).to eq(0), out
    expect(out.lines.grep(/^cursor: false/)).to eq(%w[write backspace move_left].map { |op| "cursor: false #{op} \"\\e[?25l\"\n" })
    expect(out).to include('cursor: true write "\e[?25h"', 'fine')
  end
end
