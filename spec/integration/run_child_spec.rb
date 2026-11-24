# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require "tmpdir"
require_relative "../support/nc_helpers"

# ICH-593: un processo nipote che eredita la pipe dell'output di
# NcHelpers.run_child e resta fermo non deve fermare la suite. Il nipote resta
# fermo in File.open(fifo, "w") finché nessuno apre la FIFO in lettura. Ogni
# esempio chiama run_child in un thread con un limite: se run_child non torna,
# l'esempio fallisce senza fermare la suite.
RSpec.describe "NcHelpers.run_child (integrazione)" do
  def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  # Script del figlio: avvia il nipote fermo, scrive il suo pid e poi esegue rest.
  def script(rest)
    <<~RUBY
      $stdout.sync = true
      nipote = spawn(RbConfig.ruby, "-e", "File.open(ARGV[0], 'w') { }", #{@fifo.dump})
      File.write(#{@pid_file.dump}, nipote.to_s)
      puts "nipote avviato"
      #{rest}
    RUBY
  end

  # @return [Array(Array, Float)] il risultato di run_child (nil se non torna entro 15 s) e i secondi passati
  def bounded_run(rest, **opts)
    start = now
    # rubocop:disable ThreadSafety/NewThread -- un run_child fermo non deve fermare l'esempio
    result = Thread.new { NcHelpers.run_child(script(rest), **opts) }.join(15)&.value
    # rubocop:enable ThreadSafety/NewThread
    [result, now - start]
  end

  # true se il processo non esiste più o è uno zombie che aspetta il wait del padre
  def gone?(pid)
    state = IO.popen(["ps", "-o", "stat=", "-p", pid.to_s], err: File::NULL, &:read).strip
    state.empty? || state.start_with?("Z")
  end

  around do |example|
    Dir.mktmpdir do |dir|
      @fifo = File.join(dir, "fifo")
      @pid_file = File.join(dir, "pid")
      File.mkfifo(@fifo)
      example.run
    ensure
      # il nipote rimasto vivo tiene aperta la pipe e fermo il thread di run_child
      pid = File.exist?(@pid_file) ? File.read(@pid_file).to_i : 0
      begin
        Process.kill(:KILL, pid) if pid.positive?
      rescue Errno::ESRCH
        nil
      end
    end
  end

  it "al timeout ferma anche il nipote che tiene aperto l'output e restituisce l'output del figlio" do
    result, elapsed = bounded_run("sleep", timeout: 2)
    expect(result).not_to be_nil, "run_child non è tornato entro 15 s: il nipote tiene aperta la pipe"
    out, status, timed_out = result
    expect(timed_out).to be(true)
    expect(status.termsig).to eq(Signal.list.fetch("KILL")), status.inspect
    expect(out).to include("nipote avviato")
    expect(elapsed).to be < 6
    expect(gone?(File.read(@pid_file).to_i)).to be(true)
  end

  it "se il figlio esce e un nipote tiene aperto l'output, torna dopo grace secondi con timed_out vero" do
    result, elapsed = bounded_run("", timeout: 10, grace: 1)
    expect(result).not_to be_nil, "run_child non è tornato entro 15 s: il nipote tiene aperta la pipe"
    out, status, timed_out = result
    expect(status.exitstatus).to eq(0), out
    expect(timed_out).to be(true)
    expect(out).to include("nipote avviato", "un processo discendente tiene aperto l'output")
    expect(elapsed).to be < 5
  end

  it "se il figlio esce e un nipote tiene aperto l'output, dopo grace secondi ferma anche il nipote orfano" do
    skip "i processi che tengono la pipe si trovano in /proc: solo Linux" unless File.directory?("/proc/self/fd")

    result, = bounded_run("", timeout: 10, grace: 1)
    expect(result).not_to be_nil, "run_child non è tornato entro 15 s: il nipote tiene aperta la pipe"
    expect(gone?(File.read(@pid_file).to_i)).to be(true)
  end
end
