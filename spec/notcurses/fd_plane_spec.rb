# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require 'tempfile'
require 'timeout'
require_relative '../support/nc_helpers'

RSpec.describe Notcurses::FdPlane do
  # ogni esempio usa thread: un blocco del wrapper non deve fermare la suite
  around { |example| Timeout.timeout(20) { example.run } }

  def open_fds = NcHelpers.open_fd_count

  def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  # Queue#pop con un limite (Queue#pop(timeout:) richiede Ruby 3.2).
  def pop(queue, seconds = 5) = Timeout.timeout(seconds) { queue.pop }

  # Attende che il blocco restituisca un valore vero.
  def wait_until(seconds = 5)
    deadline = now + seconds
    until yield
      raise 'condizione non raggiunta in tempo' if now > deadline

      sleep 0.01
    end
  end

  describe 'con un contesto condiviso' do
    include_context 'con un contesto notcurses'

    let(:plane) { nc.stdplane.create_child(rows: 5, cols: 40) }

    after { plane.close }

    it 'passa i byte al blocco nel thread di lettura e chiama on_done: a fine file' do
      reader, writer = IO.pipe
      events = Queue.new
      done = ->(f, error) { events << [:done, f, error] }
      fdp = described_class.new(plane, reader, on_done: done) do |f, bytes|
        events << [:data, f, bytes, Thread.current == Thread.main]
        f.plane.putstr(bytes)
      end
      expect(plane).to be_scrolling
      expect(fdp.plane).to equal(plane)
      expect(fdp.context).to equal(nc)
      expect(fdp.to_ptr.address).to eq(plane.address)
      writer.write('abc')
      kind, obj, bytes, main = pop(events)
      expect([kind, obj, bytes, bytes.encoding, main]).to eq([:data, fdp, 'abc', Encoding::BINARY, false])
      writer.write("def\n")
      expect(pop(events)[2]).to eq("def\n")
      expect(fdp).not_to be_done
      writer.close
      expect(pop(events)).to eq([:done, fdp, nil])
      wait_until { fdp.done? }
      expect(plane.contents(rows: 1)).to start_with('abcdef')
      expect(fdp.close).to be_nil
      expect(reader).to be_closed # l'IO passa all'FdPlane, come il fd in ncfdplane_destroy
    end

    it 'accetta on_data: al posto del blocco e lo usa con open' do
      reader, writer = IO.pipe
      seen = Queue.new
      kept = nil
      result = described_class.open(plane, reader, on_data: ->(_f, bytes) { seen << bytes }) do |fdp|
        kept = fdp
        writer.write('x')
        pop(seen)
      end
      expect(result).to eq('x')
      expect(kept).to be_closed
      expect(reader).to be_closed
      writer.close
    end

    it 'valida gli argomenti prima di avviare il thread' do
      reader, writer = IO.pipe
      noop = ->(*) {}
      expect { described_class.new(plane, reader) }.to raise_error(ArgumentError, /blocco/)
      expect { described_class.new(plane, reader, on_data: noop) { nil } }.to raise_error(ArgumentError, /non entrambi/)
      expect { described_class.new(plane, reader, on_data: 42) }.to raise_error(TypeError)
      expect { described_class.new(plane, reader, on_done: 'fine') { nil } }.to raise_error(TypeError)
      expect { described_class.new(plane, 0) { nil } }.to raise_error(TypeError)
      expect { described_class.new(plane, reader, follow: 'sì') { nil } }.to raise_error(TypeError)
      expect { described_class.new(:piano, reader) { nil } }.to raise_error(TypeError)
      closed = plane.create_child(rows: 1, cols: 1)
      closed.close
      expect { described_class.new(closed, reader) { nil } }.to raise_error(Notcurses::ClosedError)
      writer.close
      reader.close
      expect { described_class.new(plane, reader) { nil } }.to raise_error(ArgumentError, /chiuso/)
    end

    it 'con follow: rilegge dopo la fine del file senza consumare CPU' do
      file = Tempfile.new('fdplane')
      file.write('a')
      file.flush
      seen = Queue.new
      dones = Queue.new
      on_done = ->(*) { dones << :done }
      source = File.open(file.path)
      fdp = described_class.new(plane, source, follow: true, on_done: on_done) { |_f, bytes| seen << bytes }
      expect(pop(seen)).to eq('a')
      cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
      sleep 0.5
      expect(Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - cpu).to be < 0.2 # il C: 100% di CPU
      file.write('b')
      file.flush
      expect(pop(seen)).to eq('b')
      expect(dones).to be_empty
      expect(fdp).not_to be_done
      started = now
      fdp.close
      expect(now - started).to be < 1
    ensure
      file&.close!
    end

    it 'un errore di lettura arriva a on_done: e termina la lettura' do
      reader, writer = IO.pipe
      done = Queue.new
      fdp = described_class.new(plane, writer, on_done: ->(_f, error) { done << error }) { nil } # IO solo in scrittura
      expect(pop(done)).to be_a(IOError)
      wait_until { fdp.done? }
      fdp.close
      expect(writer).to be_closed
      reader.close
    end

    it 'close ferma subito un thread che aspetta dati e chiude tutti i fd' do
      before = open_fds
      reader, writer = IO.pipe
      fdp = described_class.new(plane, reader) { nil }
      sleep 0.1
      started = now
      expect(fdp.close).to be_nil
      expect(now - started).to be < 1
      writer.close
      expect(open_fds).to eq(before)
    end

    it 'close interrompe un blocco che aspetta' do
      reader, writer = IO.pipe
      inside = Queue.new
      fdp = described_class.new(plane, reader) do |_f, _bytes|
        inside << true
        sleep 30
      end
      writer.write('x')
      pop(inside)
      started = now
      fdp.close
      expect(now - started).to be < 1
      writer.close
    end

    it 'close non interrompe il blocco a metà di un calcolo (solo alle sue attese)' do
      reader, writer = IO.pipe
      inside = Queue.new
      finished = Queue.new
      fdp = described_class.new(plane, reader) do |_f, _bytes|
        inside << true
        t = now
        nil while now - t < 0.3 # come una sequenza di chiamate del wrapper: niente attese
        finished << true
      end
      writer.write('x')
      pop(inside)
      fdp.close
      expect(finished.size).to eq(1)
      writer.close
    end

    it 'close aspetta il blocco in corso, che può ancora usare l\'FdPlane' do
      reader, writer = IO.pipe
      inside = Queue.new
      seen = []
      fdp = described_class.new(plane, reader) do |f, _bytes|
        inside << true
        deadline = now + 5
        # il kill di close resta in attesa fino alla prima attesa del blocco: Thread.pass non lo consegna
        # (su Ruby 3.1 lo consegna anche String#grapheme_clusters, che Plane#putstr usa)
        Thread.pass until Thread.pending_interrupt? || now > deadline
        seen << f.plane
      end
      writer.write('x')
      pop(inside)
      expect { fdp.close }.not_to raise_error
      expect(seen).to eq([plane])
      expect(fdp).to be_closed
    ensure
      writer&.close
    end

    it 'close dal blocco non aspetta se stesso e lascia chiuso l\'oggetto' do
      reader, writer = IO.pipe
      events = Queue.new
      fdp = described_class.new(plane, reader) do |f, _bytes|
        events << f.close
        events << (begin; f.plane; rescue Notcurses::ClosedError => e; e; end)
      end
      writer.write('x')
      expect(pop(events)).to be_nil
      expect(pop(events)).to be_a(Notcurses::ClosedError)
      expect(fdp).to be_closed
      expect(reader).to be_closed
      writer.close
    end

    it 'un\'eccezione nel blocco ferma la lettura e viene rilanciata da close, una volta' do
      reader, writer = IO.pipe
      dones = Queue.new
      fdp = described_class.new(plane, reader, on_done: ->(*) { dones << :done }) do |_f, bytes|
        raise ArgumentError, "boom #{bytes}"
      end
      writer.write('z')
      wait_until { fdp.done? }
      writer.close
      expect { fdp.close }.to raise_error(ArgumentError, 'boom z')
      expect(fdp).to be_closed
      expect(fdp.close).to be_nil
      expect(dones).to be_empty
      expect(reader).to be_closed
    end

    it 'un\'eccezione in on_done: viene rilanciata da close' do
      reader, writer = IO.pipe
      fdp = described_class.new(plane, reader, on_done: ->(*) { raise 'fine rotta' }) { nil }
      writer.close
      wait_until { fdp.done? }
      expect { fdp.close }.to raise_error(RuntimeError, 'fine rotta')
    end

    it 'un piano chiuso mentre il thread gira dà ClosedError al blocco, senza use-after-free' do
      own = nc.stdplane.create_child(rows: 3, cols: 10)
      reader, writer = IO.pipe
      fdp = described_class.new(own, reader) { |f, bytes| f.plane.putstr(bytes) }
      own.close
      writer.write('x')
      wait_until { fdp.done? }
      writer.close
      expect { fdp.close }.to raise_error(Notcurses::ClosedError)
    end

    it 'close è idempotente, destroy è un alias, e dopo la chiusura i metodi sollevano ClosedError' do
      reader, writer = IO.pipe
      fdp = described_class.new(plane, reader) { nil }
      expect(fdp.destroy).to be_nil
      expect(fdp.close).to be_nil
      expect(fdp).to be_closed
      expect(fdp.inspect).to include('chiuso')
      expect { fdp.plane }.to raise_error(Notcurses::ClosedError)
      expect { fdp.done? }.to raise_error(Notcurses::ClosedError)
      expect { fdp.to_ptr }.to raise_error(Notcurses::ClosedError)
      expect(plane).not_to be_closed # il piano non è dell'FdPlane
      writer.close
    end

    it 'drop_planes lo chiude prima di distruggere i piani, senza blocchi' do
      reader, writer = IO.pipe
      fdp = described_class.new(plane, reader) { nil }
      sleep 0.05
      started = now
      nc.drop_planes
      expect(now - started).to be < 1
      expect(fdp).to be_closed
      expect(reader).to be_closed
      writer.close
    end
  end

  describe 'chiusura del contesto' do
    it 'Context#close chiude un FdPlane in lettura prima di notcurses_stop' do
      reader, writer = IO.pipe
      fdp = nil
      started = nil
      NcHelpers.open_context do |ctx|
        pl = ctx.stdplane.create_child(rows: 3, cols: 10)
        fdp = described_class.new(pl, reader) { |f, bytes| f.plane.putstr(bytes) }
        writer.write('x')
        started = now
      end
      expect(now - started).to be < 1
      expect(fdp).to be_closed
      expect(reader).to be_closed
      writer.close
    end

    it 'Context#close rilancia l\'eccezione del blocco dopo notcurses_stop' do
      reader, writer = IO.pipe
      ctx = NcHelpers.open_context
      fdp = described_class.new(ctx.stdplane, reader) { raise IndexError, 'nel blocco' }
      writer.write('x')
      wait_until { fdp.done? }
      expect { ctx.close }.to raise_error(IndexError, 'nel blocco')
      expect(ctx).to be_closed
      expect(Notcurses.active_context).to be_nil
      writer.close
    end
  end
end
