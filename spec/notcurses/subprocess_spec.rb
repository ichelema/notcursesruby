# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require 'timeout'
require_relative '../support/nc_helpers'

RSpec.describe Notcurses::Subprocess do
  # ogni esempio usa processi e thread: un blocco del wrapper non deve fermare la suite
  around { |example| Timeout.timeout(20) { example.run } }

  def open_fds = Dir.children('/proc/self/fd').size

  def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  # Queue#pop con un limite (Queue#pop(timeout:) richiede Ruby 3.2).
  def pop(queue, seconds = 5) = Timeout.timeout(seconds) { queue.pop }

  def wait_until(seconds = 5)
    deadline = now + seconds
    until yield
      raise 'condizione non raggiunta in tempo' if now > deadline

      sleep 0.01
    end
  end

  # true se il processo esiste ancora (anche zombie).
  def process_exists?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  end

  # Output completo e stato di un comando: [output, status].
  def run_command(plane, *argv, **opts)
    out = +''
    done = Queue.new
    sub = described_class.new(plane, *argv, on_done: ->(_s, status) { done << status }, **opts) do |_s, bytes|
      out << bytes
    end
    status = pop(done)
    [out, status, sub]
  end

  describe 'con un contesto condiviso' do
    include_context 'con un contesto notcurses'

    let(:plane) { nc.stdplane.create_child(rows: 5, cols: 40) }

    after { plane.close }

    it 'esegue il programma, passa stdout e stderr al blocco e lo stato a on_done:' do
      before = open_fds
      events = Queue.new
      sub = described_class.new(plane, 'sh', '-c', 'echo ciao; echo errore >&2; exit 3',
                                on_done: ->(s, status) { events << [:done, s, status] }) do |s, bytes|
        events << [:data, s, bytes, Thread.current == Thread.main]
        s.plane.putstr(bytes)
      end
      expect(plane).to be_scrolling
      expect(sub.pid).to be_a(Integer)
      expect(sub.plane).to equal(plane)
      expect(sub).to be_a(Notcurses::FdPlane)
      out = +''
      status = nil
      until status
        kind, obj, payload, main = pop(events)
        expect(obj).to equal(sub)
        if kind == :data
          expect(main).to be(false)
          out << payload
        else
          status = payload
        end
      end
      expect(out).to eq("ciao\nerrore\n")
      expect(status).to be_a(Process::Status)
      expect(status.exitstatus).to eq(3)
      wait_until { sub.done? }
      expect(sub.close).to equal(status)
      expect(sub.close).to equal(status) # idempotente, restituisce ancora lo stato
      expect(open_fds).to eq(before)
      expect(plane.contents(rows: 1)).to start_with('ciao')
    end

    it 'il figlio legge da /dev/null, non dallo stdin del processo, e non eredita altri fd' do
      # le spec girano con stdin su /dev/null: si controllano le opzioni passate a spawn
      allow(Process).to receive(:spawn).and_call_original
      expect(Process).to receive(:spawn)
        .with(['cat', 'cat'], hash_including(in: File::NULL, close_others: true)).and_call_original
      out, status, sub = run_command(plane, 'cat')
      expect(out).to eq('')
      expect(status.exitstatus).to eq(0)
      sub.close
      out, _status, sub = run_command(plane, 'sh', '-c', 'ls /proc/self/fd')
      expect(out.split.map(&:to_i).sort.first(3)).to eq([0, 1, 2])
      expect(out.split.size).to be <= 4 # 0, 1, 2 e il fd con cui ls legge la directory
      sub.close
    end

    it 'path: cerca nel PATH (execvp) oppure usa il percorso (execv)' do
      out, status, sub = run_command(plane, 'echo', 'a b', '$HOME') # nessuna shell
      expect([out, status.exitstatus]).to eq(["a b $HOME\n", 0])
      sub.close
      echo = ENV.fetch('PATH').split(':').map { |dir| File.join(dir, 'echo') }.find { |f| File.executable?(f) }
      out, _status, sub = run_command(plane, echo, 'x', path: false)
      expect(out).to eq("x\n")
      sub.close
      expect { described_class.new(plane, 'echo', path: false) { nil } }.to raise_error(Errno::ENOENT)
    end

    it 'env: è l\'unico ambiente del figlio (come execvpe)' do
      env = ENV.fetch('PATH').split(':').map { |dir| File.join(dir, 'env') }.find { |f| File.executable?(f) }
      out, status, sub = run_command(plane, env, env: { 'V' => '42' })
      expect([out, status.exitstatus]).to eq(["V=42\n", 0])
      sub.close
    end

    it 'un exec fallito solleva subito e non lascia fd aperti' do
      before = open_fds
      expect { described_class.new(plane, '/percorso/inesistente') { nil } }.to raise_error(Errno::ENOENT)
      expect(open_fds).to eq(before)
      expect(plane).not_to be_scrolling # come il C: il piano si tocca solo dopo l'avvio
    end

    it 'valida gli argomenti prima di avviare il processo' do
      expect { described_class.new(plane, 'true') }.to raise_error(ArgumentError, /blocco/)
      expect { described_class.new(plane, '') { nil } }.to raise_error(ArgumentError, /vuoto/)
      expect { described_class.new(plane, :true) { nil } }.to raise_error(TypeError)
      expect { described_class.new(plane, 'echo', 1) { nil } }.to raise_error(TypeError)
      expect { described_class.new(plane, 'echo', "a\0b") { nil } }.to raise_error(ArgumentError)
      expect { described_class.new(plane, 'true', env: ['V=1']) { nil } }.to raise_error(TypeError)
      expect { described_class.new(plane, 'true', env: { 'A=B' => '1' }) { nil } }.to raise_error(ArgumentError)
      expect { described_class.new(plane, 'true', env: { '' => '1' }) { nil } }.to raise_error(ArgumentError)
      expect { described_class.new(plane, 'true', env: { V: '1' }) { nil } }.to raise_error(TypeError)
      expect { described_class.new(plane, 'true', path: 'no') { nil } }.to raise_error(TypeError)
      expect { described_class.new(:piano, 'true') { nil } }.to raise_error(TypeError)
      closed = plane.create_child(rows: 1, cols: 1)
      closed.close
      expect { described_class.new(closed, 'true') { nil } }.to raise_error(Notcurses::ClosedError)
    end

    it 'close con il figlio vivo lo uccide, lo raccoglie e chiude i fd in meno di un secondo' do
      before = open_fds
      sub = described_class.new(plane, 'sleep', '30') { nil }
      pid = sub.pid
      started = now
      status = sub.close
      expect(now - started).to be < 1
      expect(status.termsig).to eq(9) # SIGKILL, come ncsubproc_destroy
      expect(process_exists?(pid)).to be(false)
      expect(open_fds).to eq(before)
    end

    it 'close con yes che scrive sul piano termina in meno di un secondo (il C va in deadlock)' do
      before = open_fds
      chunks = Queue.new
      sub = described_class.new(plane, 'yes') do |s, bytes|
        s.plane.putstr(bytes)
        chunks << true
      end
      pop(chunks)
      started = now
      status = sub.close
      expect(now - started).to be < 1
      expect(status.termsig).to eq(9)
      expect(open_fds).to eq(before)
    end

    it 'close dal blocco restituisce lo stato senza aspettare se stesso' do
      events = Queue.new
      sub = described_class.new(plane, 'yes') { |s, _bytes| events << s.close }
      status = pop(events)
      expect(status.termsig).to eq(9)
      expect(sub).to be_closed
      expect(sub.close).to equal(status)
    end

    it 'un nipote che tiene aperta la pipe non blocca close' do
      lines = Queue.new
      sub = described_class.new(plane, 'sh', '-c', 'sleep 3 & echo partito') { |_s, bytes| lines << bytes }
      expect(pop(lines)).to eq("partito\n")
      sleep 0.2
      expect(sub).not_to be_done # sh è uscito, ma la pipe è ancora aperta
      started = now
      expect(sub.close.exitstatus).to eq(0)
      expect(now - started).to be < 1
    end

    it 'un\'eccezione nel blocco viene rilanciata da close, che uccide comunque il figlio' do
      before = open_fds
      sub = described_class.new(plane, 'yes') { raise KeyError, 'nel blocco' }
      pid = sub.pid
      wait_until { sub.done? }
      expect { sub.close }.to raise_error(KeyError, 'nel blocco')
      expect(process_exists?(pid)).to be(false)
      expect(sub.close.termsig).to eq(9)
      expect(open_fds).to eq(before)
    end

    it 'open con un blocco chiude il sottoprocesso alla fine' do
      kept = nil
      result = described_class.open(plane, 'sleep', '30', on_data: ->(*) {}) do |sub|
        kept = sub
        sub.pid
      end
      expect(result).to be_a(Integer)
      expect(kept).to be_closed
      expect(process_exists?(result)).to be(false)
    end

    it 'close è idempotente, destroy è un alias, e dopo la chiusura i metodi sollevano ClosedError' do
      sub = described_class.new(plane, 'sleep', '30') { nil }
      status = sub.destroy
      expect(status).to be_a(Process::Status)
      expect(sub.close).to equal(status)
      expect(sub).to be_closed
      expect(sub.inspect).to include('chiuso')
      expect { sub.pid }.to raise_error(Notcurses::ClosedError)
      expect { sub.done? }.to raise_error(Notcurses::ClosedError)
      expect { sub.plane }.to raise_error(Notcurses::ClosedError)
      expect { sub.to_ptr }.to raise_error(Notcurses::ClosedError)
      expect(plane).not_to be_closed
    end

    it 'drop_planes lo chiude prima di distruggere i piani, senza blocchi' do
      sub = described_class.new(plane, 'yes') { |s, bytes| s.plane.putstr(bytes) }
      pid = sub.pid
      sleep 0.05
      started = now
      nc.drop_planes
      expect(now - started).to be < 1
      expect(sub).to be_closed
      expect(process_exists?(pid)).to be(false)
    end

    it 'se l\'avvio della lettura fallisce uccide e raccoglie il figlio e rilancia l\'errore' do
      pids = []
      allow_any_instance_of(described_class).to receive(:start!) do |sub, *|
        pids << sub.pid
        raise 'avvio fallito'
      end
      before = open_fds
      expect { described_class.new(plane, 'sleep', '30') { nil } }.to raise_error(RuntimeError, 'avvio fallito')
      expect(pids.size).to eq(1)
      expect(process_exists?(pids.first)).to be(false)
      expect(open_fds).to eq(before)
      expect(plane).not_to be_closed
    end
  end

  describe 'chiusura del contesto' do
    it 'Context#close uccide e raccoglie un figlio vivo prima di notcurses_stop' do
      before = open_fds
      sub = nil
      started = nil
      NcHelpers.open_context do |ctx|
        pl = ctx.stdplane.create_child(rows: 3, cols: 10)
        sub = described_class.new(pl, 'yes') { |s, bytes| s.plane.putstr(bytes) }
        sleep 0.05
        started = now
      end
      expect(now - started).to be < 1
      expect(sub).to be_closed
      expect(process_exists?(sub.close.pid)).to be(false)
      expect(open_fds).to eq(before)
    end
  end
end
