# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require 'notcurses'
require 'open3'
require_relative 'guard_audit'

# Helper delle spec del wrapper: contesti su /dev/null, mai su un TTY. Le spec
# vanno eseguite con stdin su /dev/null (il thread di input di notcurses legge
# fd 0).
#
# Un solo contesto (Context o Direct) per processo: ogni gruppo apre il suo in
# before(:all) e lo chiude in after(:all), oppure usa il blocco di open_context.
module NcHelpers
  # Opzioni di un Context di test: output su /dev/null, terminfo fisso (con TERM
  # assente o "dumb" l'init fallirebbe), niente banner, input scartato.
  CONTEXT_OPTIONS = {
    output: '/dev/null', termtype: 'xterm-256color', suppress_banners: true, drain_input: true
  }.freeze

  # Cartella dei descrittori aperti del processo: /proc/self/fd su Linux,
  # /dev/fd su macOS, che non ha /proc.
  FD_DIR = File.directory?('/proc/self/fd') ? '/proc/self/fd' : '/dev/fd'

  # Comando timeout di coreutils per i processi figli: "timeout", altrimenti
  # "gtimeout", il nome con il prefisso g di coreutils di Homebrew (brew
  # install coreutils; la 9.12 installa anche "timeout", che macOS non ha).
  # Senza nessuno dei due resta "timeout", e la spec fallisce con Errno::ENOENT.
  TIMEOUT = %w[timeout gtimeout].find do |cmd|
    ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, cmd)) }
  end || 'timeout'

  # Allocatore di debug di glibc: con MALLOC_CHECK_=3 termina il processo alla
  # prima free sbagliata o su un heap corrotto.
  MALLOC_DEBUG = '/usr/lib/libc_malloc_debug.so.0'

  module_function

  # Esegue script in un processo Ruby figlio sotto {MALLOC_DEBUG}, con lib/ nel
  # load path e stdin vuoto. Chi lo chiama salta l'esempio se {MALLOC_DEBUG}
  # manca.
  #
  # @return [Array(Integer, String)] stato di uscita e output (stdout e stderr)
  def heap_check(script, timeout: 30)
    env = {'TERM' => 'xterm-256color', 'LD_PRELOAD' => MALLOC_DEBUG, 'MALLOC_CHECK_' => '3'}
    lib = File.expand_path('../../lib', __dir__)
    out, status = Open3.capture2e(env, TIMEOUT, '-k', '5', '-s', 'KILL', timeout.to_s, RbConfig.ruby, '-I', lib, '-e',
      script, stdin_data: '')
    [status.exitstatus, out]
  end

  # Esegue script in un processo Ruby figlio, con lib/ nel load path e stdin
  # vuoto, e lo uccide dopo timeout secondi: un crash o un blocco non fermano
  # la suite. Un discendente del figlio (per esempio un nipote di spawn) eredita
  # la pipe dell'output e la tiene aperta finché vive (ICH-593): al timeout
  # muore con il figlio, e dopo l'uscita del figlio l'output si aspetta al
  # massimo grace secondi; poi muore chi tiene ancora la pipe (solo Linux, vedi
  # {pipe_holders}). I discendenti si trovano con ps e non con un process
  # group: con spawn(pgroup: true) Process.setsid fallisce con EPERM negli
  # script che rendono un pty il loro terminale di controllo (ui_pty_spec.rb).
  #
  # @param env [Hash] variabili d'ambiente del figlio
  # @param grace [Numeric] secondi di attesa dell'output dopo l'uscita del figlio
  # @return [Array(String, Process::Status, Boolean)] output, stato, true se il
  #   figlio è scaduto o se un discendente tiene ancora aperto l'output
  def run_child(script, timeout:, env: {}, grace: 5)
    lib = File.expand_path('../../lib', __dir__)
    reader, writer = IO.pipe
    pid = spawn(env, RbConfig.ruby, '-I', lib, '-e', script, in: File::NULL, out: writer, err: writer)
    writer.close
    output = ''.b
    collector = Thread.new do # rubocop:disable ThreadSafety/NewThread -- legge l'output del figlio
      loop { output << reader.readpartial(65_536) }
    rescue IOError # anche EOFError
      nil
    end
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    sleep 0.05 until (done = Process.wait2(pid, Process::WNOHANG)) || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
    timed_out = done.nil?
    if timed_out
      kill_tree(pid)
      done = Process.wait2(pid)
    end
    unless collector.join(grace)
      pipe_holders(reader).each do |holder|
        Process.kill(:KILL, holder)
      rescue Errno::ESRCH
        nil
      end
      collector.join(1) || collector.kill.join
      output << "\n[run_child: dopo #{grace} s un processo discendente tiene aperto l'output]\n"
      timed_out = true
    end
    [output.force_encoding(reader.external_encoding), done.last, timed_out]
  ensure
    reader&.close
  end

  # Pid degli altri processi che tengono aperta la pipe di io. Un discendente
  # rimasto orfano non si trova più dal ppid, ma tiene ancora la pipe. Solo
  # Linux (/proc); su macOS restituisce [] e l'orfano resta vivo.
  def pipe_holders(io)
    pipe = File.readlink("/proc/self/fd/#{io.fileno}")
    holders = Dir.glob('/proc/[0-9]*/fd/*').filter_map do |fd|
      fd.split('/')[2].to_i if File.readlink(fd) == pipe
    rescue SystemCallError # processo uscito o di un altro utente
      nil
    end
    holders.uniq - [Process.pid]
  rescue SystemCallError
    []
  end

  # Uccide con SIGKILL pid e tutti i suoi discendenti, trovati con ps prima del
  # primo kill: dopo la morte del padre un figlio passa a init e non si trova
  # più dal ppid.
  def kill_tree(pid)
    pairs = IO.popen(%w[ps -A -o pid= -o ppid=], &:read).lines.map { |line| line.split.map(&:to_i) }
    children = pairs.group_by(&:last).transform_values { |list| list.map(&:first) }
    tree = [pid]
    tree.each { |p| tree.concat(children.fetch(p, [])) }
    tree.each do |p|
      Process.kill(:KILL, p)
    rescue Errno::ESRCH
      nil
    end
  end

  # Numero dei descrittori aperti del processo, compreso quello con cui Dir
  # legge {FD_DIR}.
  #
  # @return [Integer]
  def open_fd_count
    Dir.children(FD_DIR).size
  end

  # Apre un Context di test. Le opzioni sostituiscono quelle di
  # {CONTEXT_OPTIONS} (per esempio drain_input: false per leggere l'input, che
  # da /dev/null è subito EOF).
  #
  # @return [Notcurses::Context] senza blocco; con un blocco, il valore del
  #   blocco (il contesto viene chiuso alla fine)
  def open_context(**opts, &block)
    Notcurses::Context.open(**CONTEXT_OPTIONS, **opts, &block)
  end

  # --- stati difficili per le spec di «piano invariato» (lezione del lotto 8b) ---

  # Un EGC di circa 6 MB (base e 3 milioni di U+0301): tre non entrano nei
  # 16 MiB dell'egcpool di un piano (egcpool.h:36).
  #
  # @param base [String] carattere di base, diverso per ogni EGC da confrontare
  # @return [String]
  def big_egc(base = 'a') = "#{base}#{"\u0301" * 3_000_000}"

  # Riempie l'egcpool di plane con due EGC da 6 MB, in colonna 0 delle righe
  # ys: dopo, un altro EGC da 6 MB non entra, se non sovrascrive uno di questi.
  #
  # @param plane [Notcurses::Plane] piano largo almeno 1 colonna, con le righe ys
  # @param ys [Array<Integer>] righe da usare
  # @return [void]
  def fill_egcpool(plane, ys: [0, 1])
    ys.each_with_index { |y, i| plane.putstr(big_egc((97 + i).chr), y: y, x: 0) }
  end

  # Mette la riga y in uno stato «occupato»: "X" in colonna 0, il glifo largo
  # "漢" nelle colonne 2-3, stili e colori del piano non di default e il cursore
  # in cursor. Una scrittura che fallisce su quella riga deve lasciarla così:
  # una riga vuota con i colori di default nasconde le celle che il C svuota o
  # ricolora prima di fallire (notcurses.c:1911-1950).
  #
  # @param plane [Notcurses::Plane] piano largo almeno 4 colonne
  # @param y [Integer] riga
  # @param cursor [Array(Integer, Integer)] posizione finale del cursore
  # @return [void]
  def occupy_row(plane, y, cursor: [0, 1])
    plane.putstr('X', y: y, x: 0)
    plane.putstr('漢', y: y, x: 2)
    plane.channels = Notcurses::Channels.rgb(255, 0, 0, 0, 0, 0)
    plane.styles = :bold
    plane.move_cursor(*cursor)
  end

  # Fotografia di plane da confrontare prima e dopo una scrittura che deve
  # fallire senza cambiarlo: per ogni cella EGC, stili, colori e larghezza
  # (Plane#at legge anche con l'egcpool pieno), poi cursore, stili e colori del
  # piano. Un EGC lungo diventa inizio, byte e hash, così un fallimento non
  # stampa megabyte.
  #
  # @param plane [Notcurses::Plane]
  # @return [Array]
  def plane_snapshot(plane)
    rows, cols = plane.dims
    cells = Array.new(rows) do |y|
      Array.new(cols) do |x|
        cell = plane.at(y: y, x: x)
        egc = (cell.egc.bytesize > 32) ? "#{cell.egc[0, 3].inspect}... (#{cell.egc.bytesize} byte, #{cell.egc.hash})" : cell.egc
        [egc, cell.styles, cell.channels.value, cell.width]
      end
    end
    [cells, plane.cursor, plane.styles, plane.channels.value]
  end

  # Esegue il blocco in un thread nuovo, lo ferma al primo ritorno del metodo
  # method_id (dove Ruby consegna le eccezioni asincrone) e gli manda
  # Thread#raise(error, 'interrotto'), poi lo lascia ripartire.
  #
  # @param method_id [Symbol] metodo, per esempio :ncvisual_from_file
  # @param event [Symbol] :c_return per un metodo C, :return per un metodo Ruby
  # @param error [Class] classe dell'eccezione, per esempio Interrupt
  # @return [Array(Object, Array)] il valore del blocco (il messaggio
  #   dell'eccezione di classe error, se la solleva) e il valore restituito dal
  #   metodo (l'indirizzo, per un ::FFI::Pointer)
  def raise_at_c_return(method_id, event: :c_return, error: RuntimeError)
    returned = []
    paused = Queue.new
    resume = Queue.new
    trace = TracePoint.new(event) do |tp|
      next unless tp.method_id == method_id && Thread.current[:raise_at_c_return] && returned.empty?

      value = tp.return_value
      returned << (value.is_a?(::FFI::Pointer) ? value.address : value)
      paused << true
      resume.pop
    end
    trace.enable
    # rubocop:disable ThreadSafety/NewThread -- il thread da interrompere
    thread = Thread.new do
      Thread.current[:raise_at_c_return] = true
      yield
    rescue error => e
      e.message
    ensure
      paused << false # il blocco è finito senza passare dal metodo: niente attesa infinita
    end
    # rubocop:enable ThreadSafety/NewThread
    if paused.pop
      thread.raise(error, 'interrotto')
      resume << true
    end
    [thread.value, returned]
  ensure
    trace&.disable
  end
end

# Gruppo con un Context condiviso: @nc in before(:all), chiuso in after(:all).
# Gli esempi non devono chiudere il contesto né lasciare piani aperti che
# servano ad altri esempi.
RSpec.shared_context 'con un contesto notcurses' do
  before(:all) { @nc = NcHelpers.open_context }
  after(:all) { @nc&.close }

  let(:nc) { @nc }
end
