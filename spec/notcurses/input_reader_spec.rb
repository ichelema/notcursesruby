# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative "../support/nc_helpers"

# Il thread di input di EventLoop#run, con una sorgente finta al posto di
# notcurses: un pipe come descrittore di prontezza e un getvec che scrive nel
# buffer gli id in coda (un'eccezione in coda la solleva getvec).
RSpec.describe "Notcurses::InputReader" do
  let(:reader_class) { Notcurses.const_get(:InputReader) }
  let(:size) { Notcurses::FFI::NcInput.size }
  let(:pipe) { IO.pipe }
  let(:queue) { [] }
  let(:pulls) { [] }
  let(:getvec) do
    lambda do |buf, slots|
      pipe.first.read_nonblock(4096, exception: false) # notcurses svuota il pipe a ogni lettura
      raise queue.shift if queue.first.is_a?(Exception)

      batch = []
      batch << queue.shift while batch.size < slots && queue.first.is_a?(Integer)
      pipe.last.write("x") unless queue.empty? # resta altro (un errore): il pipe torna leggibile
      pulls << [slots, batch.size]
      batch.each_with_index do |id, i|
        s = Notcurses::FFI::NcInput.new(buf + (i * size))
        s.clear # il buffer non è azzerato: notcurses scrive ogni struct per intero
        s[:id] = id
      end
      batch.size
    end
  end
  let(:reader) { reader_class.new(-> { pipe.first.fileno }, getvec) }
  let(:seen) { [] }
  let(:ids) { {"C".ord => true, "Z".ord => true} }
  # scarta C, lascia passare Z
  let(:filter) { ->(input) { (seen << input.id) && input.id == "C".ord } }

  after do
    # stop chiude i pipe anche dopo un halt o un errore, che lasciano il thread fermo ma i pipe aperti
    reader.stop(filter)
    pipe.each { |io| io.close unless io.closed? }
  end

  def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  def feed(*keys)
    queue.concat(keys.map { |k| k.is_a?(String) ? k.ord : k })
    pipe.last.write("x")
  end

  # Prende eventi come fa il ciclo: attende su ready_io, poi take fino a nil.
  def take_ids(count, timeout: 2)
    ids = []
    deadline = clock + timeout
    while ids.size < count && clock < deadline
      reader.ready_io.wait_readable(0.05)
      while (event = reader.take)
        ids << event.id
        return ids if event.id == Notcurses::Key::EOF # EOF resta nel buffer: take lo ridarebbe
      end
    end
    ids
  end

  def wait_until(timeout: 2)
    deadline = clock + timeout
    sleep 0.01 until yield || clock > deadline
    yield
  end

  it "passa al filtro solo gli id scelti e mette gli altri nel buffer, nell'ordine di arrivo" do
    expect(reader.start(filter, ids)).to be_a(IO)
    expect(reader).to be_active
    feed("a", "C", "b", "Z", "c")
    expect(take_ids(4)).to eq(%w[a b Z c].map(&:ord))
    expect(seen).to eq(%w[C Z].map(&:ord))
    expect(reader.take).to be_nil
  end

  it "legge la coda prima di attendere: gli eventi già in coda all'avvio arrivano senza un byte sul pipe" do
    queue.concat(%w[a b].map(&:ord))
    reader.start(filter, ids)
    expect(take_ids(2)).to eq(%w[a b].map(&:ord))
  end

  it "legge a blocchi di 256 eventi, e take_many si ferma a count" do
    reader.start(filter, ids)
    feed(*Array.new(600, "a"))
    expect(wait_until { pulls.sum(&:last) == 600 }).to be(true)
    expect(pulls.first(3)).to eq([[256, 256], [256, 256], [256, 88]])
    expect(reader.take_many(500).size).to eq(500)
    expect(reader.take_many(500).size).to eq(100)
    expect(reader.take_many(5)).to eq([])
  end

  it "dopo Key::EOF non legge più la coda" do
    reader.start(filter, ids)
    feed("a", Notcurses::Key::EOF, "b")
    expect(take_ids(2)).to eq(["a".ord, Notcurses::Key::EOF]) # come il C, niente dopo EOF nello stesso blocco
    calls = pulls.size
    feed("c")
    sleep 0.1
    expect(pulls.size).to eq(calls)
    expect(reader).to be_active
  end

  it "Key::EOF resta nel buffer: take e take_many lo ridanno a ogni lettore, anche dopo stop e un altro start" do
    reader.start(filter, ids)
    feed("a", Notcurses::Key::EOF)
    expect(take_ids(2)).to eq(["a".ord, Notcurses::Key::EOF])
    expect(reader.take.id).to eq(Notcurses::Key::EOF)
    expect(reader.take_many(5).map(&:id)).to eq([Notcurses::Key::EOF])
    expect(reader).to be_pending
    reader.stop(filter)
    expect(reader.take.id).to eq(Notcurses::Key::EOF)
    io = reader.start(filter, ids)
    feed(Notcurses::Key::EOF) # un run dopo rilegge EOF da notcurses: nel buffer resta uno solo
    expect(io.wait_readable(1)).to be_truthy
    expect(wait_until { queue.empty? }).to be(true)
    expect(reader.take_many(5).map(&:id)).to eq([Notcurses::Key::EOF])
    expect(reader.instance_variable_get(:@pending).size).to eq(1)
  end

  it "un thread finito per un errore viene riavviato dal run dopo" do
    reader.start(filter, ids)
    feed(Notcurses::InputError.new("lettura fallita"))
    expect(wait_until { !reader.active? }).to be(true)
    expect { reader.take }.to raise_error(Notcurses::InputError)
    inner = ->(_input) { false }
    reader.start(inner, ids) # un run annidato con il thread morto lo riavvia
    expect(reader).to be_active
    feed("a")
    expect(take_ids(1)).to eq(["a".ord])
    reader.stop(inner)
  end

  it "un'eccezione asincrona durante stop arriva dopo: filtro tolto, thread fermo, pipe chiusi" do
    reader.start(filter, ids)
    main = Thread.current
    slow = ->(_input) { (sleep 0.4) && false } # il thread di input resta nel filtro
    reader.start(slow, ids)
    reader.stop(filter) # restano solo i run annidati: il thread continua
    feed("C")
    sleep 0.1
    Thread.new { (sleep 0.1) && main.raise(Interrupt) } # rubocop:disable ThreadSafety/NewThread
    expect { reader.stop(slow) }.to raise_error(Interrupt)
    expect(reader).not_to be_active
    expect(reader.ready_io).to be_nil
    reader.start(filter, ids)
    expect(reader).to be_active
  end

  it "un errore di lettura arriva dopo gli eventi letti prima e ferma il thread" do
    reader.start(filter, ids)
    feed("a", "b", Notcurses::InputError.new("lettura fallita"))
    expect(wait_until { !reader.active? }).to be(true)
    expect(reader).to be_pending
    expect(reader.take_many(5).map(&:id)).to eq(%w[a b].map(&:ord)) # si ferma prima dell'errore
    expect { reader.take_many(5) }.to raise_error(Notcurses::InputError, "lettura fallita")
    expect(reader).not_to be_pending
  end

  it "take solleva l'errore al suo posto nella sequenza" do
    reader.start(filter, ids)
    feed("a", Notcurses::InputError.new("lettura fallita"))
    expect(wait_until { !reader.active? }).to be(true)
    expect(reader.take.id).to eq("a".ord)
    expect { reader.take }.to raise_error(Notcurses::InputError)
    expect(reader.take).to be_nil
  end

  it "stop chiude i pipe e tiene il buffer; il run dopo trova subito gli eventi rimasti" do
    reader.start(filter, ids)
    feed("a", "b")
    expect(wait_until { reader.ready_io.wait_readable(0) }).to be_truthy
    reader.stop(filter)
    expect(reader).not_to be_active
    expect(reader.ready_io).to be_nil
    expect(reader.take.id).to eq("a".ord) # fuori da run, senza pipe
    io = reader.start(filter, ids)
    expect(io.wait_readable(1)).to be_truthy # un byte per l'evento rimasto
    expect(reader.take.id).to eq("b".ord)
  end

  it "run annidati: vale il filtro del più interno, e il thread si ferma all'ultimo stop" do
    inner = []
    inner_filter = ->(input) { (inner << input.id) && true }
    reader.start(filter, ids)
    reader.start(inner_filter, ids)
    feed("Z")
    expect(wait_until { inner.size == 1 }).to be(true)
    reader.stop(->(_input) { true }) # un filtro mai registrato: niente cambia
    expect(reader).to be_active
    reader.stop(inner_filter)
    expect(reader).to be_active
    feed("Z")
    expect(take_ids(1)).to eq(["Z".ord])
    expect(seen).to eq(["Z".ord])
    reader.stop(filter)
    expect(reader).not_to be_active
  end

  it "un run annidato che parte durante un blocco filtra gli eventi seguenti dello stesso blocco" do
    inner = []
    inner_filter = ->(input) { (inner << input.id) && true }
    outer_filter = lambda do |input|
      seen << input.id
      reader.start(inner_filter, ids) if input.id == "Z".ord # come un run annidato che parte adesso
      false
    end
    reader.start(outer_filter, ids)
    feed("Z", "C", "a")
    expect(take_ids(2)).to eq(%w[Z a].map(&:ord))
    expect(seen).to eq(["Z".ord])
    expect(inner).to eq(["C".ord]) # il C dello stesso blocco va al filtro del run interno
    reader.stop(inner_filter)
    reader.stop(outer_filter)
    expect(reader).not_to be_active
  end

  it "se l'avvio fallisce il filtro non resta nella pila" do
    calls = 0
    fd = lambda do
      raise Notcurses::InputError, "descrittore non disponibile" if (calls += 1) == 1

      pipe.first.fileno
    end
    failing = reader_class.new(fd, getvec)
    expect { failing.start(filter, ids) }.to raise_error(Notcurses::InputError)
    expect(failing).not_to be_active
    failing.start(filter, ids)
    failing.stop(filter) # con un filtro rimasto dal primo start il thread resterebbe acceso
    expect(failing).not_to be_active
  end

  it "halt è idempotente e sveglia chi aspetta su ready_io" do
    io = reader.start(filter, ids)
    waiter = Thread.new { io.wait_readable(5) } # rubocop:disable ThreadSafety/NewThread
    sleep 0.05
    start = clock
    expect(reader.halt).to be_nil
    expect(waiter.value).to be_truthy
    expect(clock - start).to be < 1
    expect(reader).not_to be_active
    expect(reader.halt).to be_nil
    reader.stop(filter)
    expect(reader.ready_io).to be_nil
  end

  it "halt da un gestore trap, mentre il thread gira, lo ferma prima di tornare" do
    reader.start(filter, ids)
    stopped = nil
    old = Signal.trap("USR1") do
      reader.halt
      stopped = !reader.active?
    end
    Process.kill("USR1", Process.pid)
    expect(wait_until { !stopped.nil? }).to be(true)
    expect(stopped).to be(true)
  ensure
    Signal.trap("USR1", old || "DEFAULT")
  end
end
