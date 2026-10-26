# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require 'rbconfig'

# Le funzioni che aspettano il terminale (init, posizione del cursore, readline)
# rilasciano il GVL: nella Fase 1 sono collegate con blocking: true. Qui il
# terminale è un pty con un thread Ruby che risponde alle query: con il GVL
# tenuto durante l'attesa il thread non potrebbe rispondere e il processo
# resterebbe bloccato già all'init. Gira in un processo figlio, perché lo
# stdin del processo diventa il pty.
RSpec.describe 'Attese del terminale senza GVL (integrazione, pty)' do
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
      d.cursor_move(y: 2) # con x: nil il C chiede la colonna al terminale
      puts 'cursor_move ok'
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

  it 'init, cursor_yx, cursor_move e readline lasciano girare i thread Ruby mentre aspettano il terminale' do
    out, status, timed_out = run_child(child_script, timeout: 15)
    expect(timed_out).to be(false), "processo figlio bloccato (GVL tenuto durante un'attesa?):\n#{out}"
    expect(status.exitstatus).to eq(0), out
    expect(out).to include('context 24x80', 'can_get_cursor true', 'cursor_yx 4,6', 'cursor_move ok', 'fine')
    expect(out[/readline "ab" ticks (\d+)/, 1].to_i).to be >= 10 # readline attende circa 0,3 s
  end
end
