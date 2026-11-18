# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative '../../support/nc_helpers'

RSpec.describe Notcurses::UI::EventLoop do
  def syn(id, **opts) = Notcurses::Input.synthesize(id, **opts)

  def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  # Ciclo con un timer di sicurezza: un risveglio mancato fa fallire l'esempio
  # (:timeout) invece di bloccare la suite.
  def new_loop(context = nc)
    ev = described_class.new(context)
    ev.after(5) { ev.stop && (@timed_out = true) }
    ev
  end

  def run_loop(ev)
    @timed_out = false
    reason = ev.run
    @timed_out ? :timeout : reason
  end

  def open_fds = NcHelpers.open_fd_count

  context 'con un contesto notcurses' do
    include_context 'con un contesto notcurses'

    it 'new controlla il contesto' do
      expect { described_class.new(:nc) }.to raise_error(TypeError)
      expect(described_class.new(nc).context).to equal(nc)
    end

    it 'run rende all\'avvio e una volta per ogni giro con lavoro; un blocco di post ferma il ciclo' do
      ev = new_loop
      calls = []
      ev.post { calls << 1 }
      ev.post do
        calls << 2
        ev.stop
      end
      renders = nc.stats.renders
      expect(run_loop(ev)).to eq(:stop)
      expect(calls).to eq([1, 2])
      expect(nc.stats.renders - renders).to eq(2) # avvio, poi il giro dei due blocchi
      expect(ev).not_to be_running
    end

    it 'post da un altro thread sveglia il ciclo, e il blocco gira nel thread del ciclo' do
      ev = new_loop
      seen = []
      waker = Thread.new do
        sleep 0.1
        ev.post do
          seen << Thread.current
          ev.stop
        end
      end
      t0 = clock
      expect(run_loop(ev)).to eq(:stop)
      expect(clock - t0).to be < 2
      expect(seen).to eq([Thread.current])
      waker.join
    end

    it 'stop e post funzionano da un altro thread e da un gestore trap' do
      ev = new_loop
      Thread.new { sleep 0.05; ev.stop }
      expect(run_loop(ev)).to eq(:stop)

      log = []
      old1 = Signal.trap('USR1') { ev.post { log << :post } }
      old2 = Signal.trap('USR2') { ev.stop }
      Thread.new do
        sleep 0.05
        Process.kill('USR1', Process.pid)
        sleep 0.1
        Process.kill('USR2', Process.pid)
      end
      expect(run_loop(ev)).to eq(:stop)
      expect(log).to eq([:post])
    ensure
      Signal.trap('USR1', old1 || 'SYSTEM_DEFAULT')
      Signal.trap('USR2', old2 || 'SYSTEM_DEFAULT')
    end

    it 'stop non consegna altri eventi: un blocco arrivato insieme allo stop resta per il run successivo' do
      ev = new_loop
      log = []
      ev.post do
        ev.post { log << :dopo }
        ev.stop
      end
      expect(run_loop(ev)).to eq(:stop)
      expect(log).to eq([])
      ev.post { ev.stop }
      expect(run_loop(ev)).to eq(:stop)
      expect(log).to eq([:dopo])
    end

    it 'un stop chiesto quando run non gira vale per il run successivo' do
      ev = new_loop
      ran = false
      ev.stop
      ev.post { ran = true }
      expect(run_loop(ev)).to eq(:stop)
      expect(ran).to be(false) # esce dopo il render iniziale; il blocco resta in coda
      ev.post { ev.stop }
      expect(run_loop(ev)).to eq(:stop)
      expect(ran).to be(true)
    end

    it 'i timer scattano per scadenza, anche se il ciclo arriva in ritardo' do
      ev = new_loop
      log = []
      ev.after(0.06) { log << :c }
      ev.after(0.02) { log << :a }
      ev.after(0.04) { log << :b }
      ev.after(0.08) { ev.stop }
      sleep 0.1 # al primo giro sono già tutti scaduti
      expect(run_loop(ev)).to eq(:stop)
      expect(log).to eq(%i[a b c])
    end

    it 'every ripete il blocco finché cancel lo ferma; un timer fermato non scatta' do
      ev = new_loop
      log = []
      never = ev.after(0.03) { log << :never }
      never.cancel
      every = ev.every(0.02) do |timer|
        log << :e
        next unless log.size == 3

        timer.cancel
        ev.after(0.05) { ev.stop }
      end
      expect(every.interval).to eq(0.02)
      expect(never.interval).to be_nil
      expect(run_loop(ev)).to eq(:stop)
      expect(log).to eq(%i[e e e])
      expect(every).not_to be_active
      expect(never).not_to be_active
    end

    it 'inspect di un Timer mostra il tipo e se è fermo' do
      ev = new_loop
      once = ev.after(1) { nil }
      every = ev.every(0.5) { nil }
      expect(once.inspect).to eq('#<Notcurses::UI::Timer una volta>')
      expect(every.inspect).to eq('#<Notcurses::UI::Timer ogni 0.5s>')
      every.cancel
      expect(every.inspect).to eq('#<Notcurses::UI::Timer ogni 0.5s (fermo)>')
    end

    it 'run restituisce :interrupt se un blocco solleva Interrupt' do
      ev = new_loop
      ev.post { raise Interrupt }
      expect(run_loop(ev)).to eq(:interrupt)
    end

    it 'un timer di after diventa inattivo prima del blocco; a pari scadenza vale l\'ordine di creazione' do
      ev = new_loop
      log = []
      timer = ev.after(0) { |t| log << [:primo, t.active?] }
      ev.after(0) do
        log << :secondo
        ev.stop
      end
      expect(run_loop(ev)).to eq(:stop)
      expect(log).to eq([[:primo, false], :secondo])
      expect(timer).not_to be_active
    end

    it 'every non recupera le esecuzioni perse dopo un ritardo' do
      ev = new_loop
      times = []
      ev.every(0.01) do |timer|
        times << clock
        sleep 0.08 if times.size == 1 # il ciclo resta fermo per 8 intervalli
        if times.size == 3
          timer.cancel
          ev.stop
        end
      end
      expect(run_loop(ev)).to eq(:stop)
      expect(times[2] - times[1]).to be >= 0.005 # senza recupero: nessuna raffica dopo il ritardo
    end

    it 'un timer every il cui blocco solleva resta programmato per il run successivo' do
      ev = new_loop
      calls = 0
      timer = ev.every(0.01) do
        calls += 1
        raise 'errore temporaneo' if calls == 2
      end
      expect { ev.run }.to raise_error(RuntimeError, 'errore temporaneo')
      expect(calls).to eq(2)
      expect(timer).to be_active
      ev.after(0.1) { ev.stop }
      expect(run_loop(ev)).to eq(:stop)
      expect(calls).to be > 2
      expect(timer).to be_active
    end

    it 'un timer every che si cancella e poi solleva resta fermo; un timer after che solleva non riparte' do
      ev = new_loop
      calls = 0
      timer = ev.every(0.01) do |t|
        calls += 1
        t.cancel
        raise 'errore definitivo'
      end
      expect { ev.run }.to raise_error(RuntimeError, 'errore definitivo')
      expect(timer).not_to be_active
      once = ev.after(0) do
        calls += 10
        raise 'una volta'
      end
      expect { ev.run }.to raise_error(RuntimeError, 'una volta')
      expect(once).not_to be_active
      ev.after(0.05) { ev.stop }
      expect(run_loop(ev)).to eq(:stop)
      expect(calls).to eq(11)
    end

    it 'un ritardo enorme non fa sollevare IO.select: il timer resta attivo e non scatta' do
      [[:after, 1e20], [:after, Float::MAX], [:every, 1e20]].each do |kind, seconds|
        ev = described_class.new(nc) # senza new_loop: il suo timer di 5 s sarebbe la prima scadenza
        fired = false
        timer = ev.public_send(kind, seconds) { fired = true }
        stopper = Thread.new { sleep 0.05; ev.stop }
        expect(ev.run).to eq(:stop)
        stopper.join
        expect(timer).to be_active
        expect(fired).to be(false)
      end
    end

    it 'un blocco che si ripubblica non ferma il ciclo: ogni giro esegue solo i blocchi già in coda' do
      ev = new_loop
      count = 0
      repost = lambda do
        count += 1
        ev.post(&repost)
      end
      ev.post(&repost)
      ev.after(0.05) { ev.stop }
      expect(run_loop(ev)).to eq(:stop)
      expect(count).to be > 1
    end

    it 'valida gli argomenti' do
      ev = described_class.new(nc)
      expect { ev.post }.to raise_error(ArgumentError)
      expect { ev.after(1) }.to raise_error(ArgumentError)
      expect { ev.after(-1) {} }.to raise_error(ArgumentError)
      expect { ev.after('1') {} }.to raise_error(TypeError)
      expect { ev.every(0) {} }.to raise_error(ArgumentError)
      expect { ev.every(Float::INFINITY) {} }.to raise_error(ArgumentError)
      expect { ev.on_key('ab') {} }.to raise_error(ArgumentError)
      expect { ev.on_key(:q) {} }.to raise_error(TypeError)
      expect { ev.on_key('q', ctrl: 1) {} }.to raise_error(TypeError)
      expect { ev.on_key('q') }.to raise_error(ArgumentError)
      expect { ev.on_input }.to raise_error(ArgumentError)
      expect { ev.on_resize }.to raise_error(ArgumentError)
      expect { ev.dispatch(:q) }.to raise_error(TypeError)
      expect { ev.run(no_flow_control: 1) }.to raise_error(TypeError)
      expect { ev.run(no_linesigs: 'true') }.to raise_error(TypeError)
      expect(ev).not_to be_running
    end

    it "un'eccezione di un blocco esce da run, che ripristina i trap e chiude il pipe" do
      mine = { 'WINCH' => proc {}, 'CONT' => proc {} }
      old = mine.to_h { |sig, handler| [sig, Signal.trap(sig, handler)] }
      ev = new_loop
      during = {}
      ev.post do
        mine.each_key do |sig|
          during[sig] = Signal.trap(sig, 'SYSTEM_DEFAULT')
          Signal.trap(sig, during[sig])
        end
        raise ArgumentError, 'boom'
      end
      fds = open_fds
      expect { ev.run }.to raise_error(ArgumentError, 'boom')
      expect(open_fds).to eq(fds)
      mine.each do |sig, handler|
        expect(during[sig]).to be_a(Proc)
        expect(during[sig]).not_to equal(handler) # durante run il gestore è quello del ciclo
        expect(Signal.trap(sig, old[sig] || 'SYSTEM_DEFAULT')).to equal(handler)
      end
      expect(ev).not_to be_running
    end

    # Gli stub evitano di toccare il terminale di chi esegue la suite. Il contesto
    # di questi esempi scarta l'input (drain_input): run non legge i tasti.
    it "un errore del ripristino del terminale non sostituisce l'eccezione di un handler; ISIG si riattiva comunque" do
      allow(nc).to receive_messages(flow_control_disable: true, linesigs?: true, linesigs_disable: nc)
      allow(nc).to receive(:flow_control_enable).and_raise(Notcurses::ContextError, 'tcsetattr fallita')
      expect(nc).to receive(:linesigs_enable).twice.and_return(nc)
      ev = new_loop
      ev.post { raise ArgumentError, 'boom' }
      expect { ev.run(no_flow_control: true, no_linesigs: true) }.to raise_error(ArgumentError, 'boom')
      ev.post { ev.stop }
      expect { ev.run(no_flow_control: true, no_linesigs: true) }.to raise_error(Notcurses::ContextError, 'tcsetattr fallita')
      expect(ev).not_to be_running
    end

    it 'con ISIG già spento prima di run, no_linesigs non lo tocca' do
      allow(nc).to receive(:linesigs?).and_return(false)
      expect(nc).not_to receive(:linesigs_disable)
      expect(nc).not_to receive(:linesigs_enable)
      ev = new_loop
      ev.post { ev.stop }
      expect(ev.run(no_linesigs: true)).to eq(:stop)
    end

    # notcurses scarta i tasti senza metterli in coda: il segnale può alzarlo solo lui.
    it 'con drain_input run lascia a notcurses i segnali dei tasti' do
      allow(nc).to receive(:linesigs?).and_return(true)
      expect(nc).not_to receive(:linesigs_disable)
      expect(nc).not_to receive(:isig_enable)
      ev = new_loop
      ev.post { ev.stop }
      expect(ev.run).to eq(:stop)
    end

    # Il contesto sembra leggere i tasti, ma non ne arriva nessuno.
    def reading_input
      reader, writer = IO.pipe
      allow(nc).to receive_messages(drain_input?: false, inputready_fd: reader.fileno, get: nil)
      yield
    ensure
      reader&.close
      writer&.close
    end

    it 'con un contesto che legge i tasti run toglie i loro segnali a notcurses e rimette ISIG con isig_enable' do
      reading_input do
        # il C non tocca il terminale di chi esegue i test; il wrapper tiene lo stato del flag
        allow(Notcurses::FFI).to receive(:notcurses_linesigs_enable).and_return(0)
        expect(Notcurses::FFI).to receive(:notcurses_linesigs_disable).twice.and_return(0)
        nc.linesigs_enable
        allow(nc).to receive(:linesigs?).and_return(false, true, true, true)
        expect(nc).to receive(:isig_disable).once.and_return(nc) # secondo run: il flag è già spento, basta ISIG
        expect(nc).to receive(:isig_enable).twice.and_return(nc) # alla fine del secondo run, all'avvio del quarto
        ev = new_loop
        2.times do # ICH-454: il primo spegne il flag anche con ISIG già spento
          ev.post { ev.stop }
          expect(ev.run(no_linesigs: true)).to eq(:stop)
        end
        expect(nc.linesigs_flag?).to be(false) # il flag di notcurses resta spento: i segnali li alza run
        ev.post { ev.stop }
        expect(ev.run).to eq(:stop) # ICH-538: flag già spento e ISIG acceso, run non tocca niente
        nc.linesigs_enable
        ev.post { ev.stop }
        expect(ev.run).to eq(:stop) # flag riacceso: run lo spegne di nuovo
      end
    end

    it 'senza no_linesigs run riaccende ISIG subito; se non ci riesce, ritenta alla fine' do
      reading_input do
        allow(nc).to receive_messages(linesigs?: true, linesigs_flag?: true, linesigs_disable: nc)
        calls = 0
        allow(nc).to receive(:isig_enable) do
          calls += 1
          raise Notcurses::ContextError, 'tcsetattr fallita' if calls == 1

          nc
        end
        expect(nc).not_to receive(:linesigs_enable)
        ev = new_loop
        expect { ev.run }.to raise_error(Notcurses::ContextError, 'tcsetattr fallita')
        expect(calls).to eq(2)
        ev.post { ev.stop }
        expect(ev.run).to eq(:stop)
        expect(calls).to eq(3) # solo all'avvio: alla fine ISIG è già com'era
      end
    end

    it 'senza ISIG noto no_linesigs solleva ContextError, e run senza opzioni gira lo stesso' do
      reading_input do
        stub_const('Notcurses::FFI::ISIG', nil)
        expect(nc).not_to receive(:linesigs_disable) # senza ISIG run non potrebbe rimetterlo: i segnali restano a notcurses
        ev = new_loop
        expect { ev.run(no_linesigs: true) }.to raise_error(Notcurses::ContextError, /ISIG non noto/)
        ev.post { ev.stop }
        expect(ev.run).to eq(:stop)
      end
    end

    it 'run dentro run solleva Notcurses::Error' do
      ev = new_loop
      error = nil
      ev.post do
        ev.run
      rescue Notcurses::Error => e
        error = e
        ev.stop
      end
      expect(run_loop(ev)).to eq(:stop)
      expect(error).to be_a(Notcurses::Error)
    end

    it 'SIGWINCH sveglia il ciclo, che chiama refresh e on_resize solo se le dimensioni cambiano' do
      ev = new_loop
      sizes = []
      ev.on_resize do |rows, cols|
        sizes << [rows, cols]
        ev.stop
      end
      ev.post { Process.kill('WINCH', Process.pid) } # su /dev/null refresh dà sempre 24x80
      ev.after(0.2) do
        allow(nc).to receive(:refresh).and_return([30, 100])
        Process.kill('WINCH', Process.pid)
      end
      expect(run_loop(ev)).to eq(:stop)
      expect(sizes).to eq([[30, 100]])
    end

    it 'SIGCONT sveglia il ciclo, che ridisegna con refresh senza on_resize se le dimensioni non cambiano' do
      ev = new_loop
      sizes = []
      ev.on_resize { |rows, cols| sizes << [rows, cols] }
      expect(nc).to receive(:refresh).at_least(:once).and_call_original
      ev.post { Process.kill('CONT', Process.pid) } # quello che manda la shell con fg dopo Ctrl+Z
      ev.after(0.2) { ev.stop }
      expect(run_loop(ev)).to eq(:stop)
      expect(sizes).to be_empty
    end

    it 'con il gestore di SIGWINCH di notcurses non installa trap' do
      allow(nc).to receive(:no_winch_sighandler?).and_return(false)
      expect(Signal).not_to receive(:trap)
      ev = described_class.new(nc)
      ev.post { ev.stop }
      expect(ev.run).to eq(:stop)
    end

    it 'on_key: Ctrl con le maiuscole di notcurses, Shift solo per i codici, niente rilasci; il resto va a on_input' do
      ev = described_class.new(nc)
      log = []
      ev.on_key('c', ctrl: true) { log << :ctrl_c }
      ev.on_key('q') { log << :q }
      ev.on_key(Notcurses::Key::TAB, shift: true) { log << :backtab }
      ev.on_key(Notcurses::Key::TAB) { log << :tab }
      ev.on_key('x', alt: true) { |input| log << [:alt_x, input.id] }
      ev.on_key('q') { log << :secondo_q }
      ev.on_input { |input| log << [:input, input.id] }
      expect(ev.dispatch(syn('C'.ord, modifiers: [:ctrl]))).to be(true) # così notcurses consegna Ctrl+c
      expect(ev.dispatch(syn('Q'.ord, modifiers: [:shift]))).to be(false)
      ev.dispatch(syn('q'.ord))
      ev.dispatch(syn('q'.ord, modifiers: [:capslock]))
      ev.dispatch(syn('q'.ord, evtype: :release))
      ev.dispatch(syn('q'.ord, modifiers: [:meta]))
      ev.dispatch(syn(Notcurses::Key::TAB, modifiers: [:shift]))
      ev.dispatch(syn(Notcurses::Key::TAB))
      ev.dispatch(syn('x'.ord, modifiers: [:alt]))
      ev.dispatch(syn('x'.ord))
      expect(log).to eq([:ctrl_c, [:input, 'Q'.ord], :q, :q, [:input, 'q'.ord], [:input, 'q'.ord], :backtab, :tab,
                         [:alt_x, 'x'.ord], [:input, 'x'.ord]])
    end

    it 'on_key: un carattere corrisponde al testo digitato (eff_text del protocollo kitty), Ctrl resta sul codice' do
      ev = described_class.new(nc)
      log = []
      ev.on_key('!') { log << :bang }
      ev.on_key('1') { log << :one }
      ev.on_key('x', ctrl: true) { log << :ctrl_x }
      ev.dispatch(syn('1'.ord, modifiers: [:shift], eff_text: '!')) # kitty Shift+1: id "1", testo "!"
      ev.dispatch(syn('X'.ord, modifiers: [:ctrl])) # kitty "\e[120;5u" e il byte "\x18": id ed eff_text "X"
      ev.dispatch(syn('!'.ord)) # terminale classico
      ev.dispatch(syn('1'.ord))
      ev.on_input { |input| log << [:input, input.id] }
      expect(ev.dispatch(syn(Notcurses::Key::UP))).to be(false) # eff_text vuoto: vale id
      expect(log).to eq([:bang, :ctrl_x, :bang, :one, [:input, Notcurses::Key::UP]])
    end
  end

  context 'con un contesto proprio' do
    it 'run con il contesto chiuso solleva ClosedError; se un blocco chiude il contesto run esce' do
      ev = nil
      NcHelpers.open_context do |c|
        ev = described_class.new(c)
        ev.post { c.close }
        expect(ev.run).to eq(:stop)
      end
      expect { ev.run }.to raise_error(Notcurses::ClosedError)
      expect { described_class.new(ev.context) }.to raise_error(Notcurses::ClosedError)
    end

    def input_threads = Thread.list.select { |t| t.name == 'notcurses-input' && t.alive? }

    # stdin è /dev/null: notcurses mette in coda Key::EOF, che arriva dal thread di input di run
    it 'con un contesto che legge stdin run esce con :eof, poi get legge da notcurses e il thread non resta' do
      NcHelpers.open_context(drain_input: false) do |c|
        ev = described_class.new(c)
        fds = open_fds
        got = :none
        ev.on_input { got = c.get(timeout: 0) } # durante run get legge il buffer del thread
        expect(ev.run).to eq(:eof)
        expect(got).to eq(:none) # EOF lo gestisce solo run
        expect(input_threads).to be_empty
        expect(open_fds).to eq(fds) # i pipe del thread sono chiusi
        expect(c.get(timeout: 2).id).to eq(Notcurses::Key::EOF)
        expect(ev.run).to eq(:eof) # un altro run riavvia il thread
        expect(c.getvec(3, timeout: 2).map(&:id)).to eq([Notcurses::Key::EOF])
      end
    end

    # Tasti finti per il thread di input di run: getvec_into scrive nel buffer
    # gli eventi in coda, [id, evtype, modificatori, campo ctrl]. Il contesto
    # sembra leggere i tasti con ISIG attivo e il flag di notcurses spento.
    # Un trap('INT') che conta tiene il segnale lontano da RSpec.
    def feeding_input(context)
      reader, writer = IO.pipe
      queue = []
      allow(context).to receive_messages(drain_input?: false, inputready_fd: reader.fileno, linesigs?: true,
        linesigs_flag?: false, isig_disable: context, isig_enable: context)
      allow(context).to receive(:getvec_into) do |buf, slots|
        reader.read_nonblock(4096, exception: false)
        batch = queue.shift(slots)
        batch.each_with_index do |(id, evtype, mods, ctrl), i|
          s = Notcurses::FFI::NcInput.new(buf + (i * Notcurses::FFI::NcInput.size))
          s.clear # il buffer di InputReader non è azzerato: notcurses scrive ogni struct per intero
          s[:id] = id.is_a?(String) ? id.ord : id
          s[:evtype] = evtype
          s[:modifiers] = mods
          s[:ctrl] = ctrl
        end
        batch.size
      end
      type = lambda do |*events|
        queue.concat(events)
        writer.write('x')
      end
      ints = []
      old = Signal.trap('INT') { ints << clock }
      yield type, ints, queue
    ensure
      Signal.trap('INT', old || 'DEFAULT')
      reader&.close
      writer&.close
    end

    ctrl = Notcurses::FFI::NCKEY_MOD_CTRL

    it 'il thread di input alza un segnale per pressione, scarta ripetizione e rilascio e passa gli altri tasti' do
      NcHelpers.open_context do |c|
        feeding_input(c) do |type, ints|
          ev = new_loop(c)
          keys = []
          ev.on_key('c', ctrl: true) { keys << :ctrl_c }
          ev.on_input do |input|
            keys << input.id
            ev.stop if input.id == 'x'.ord
          end
          ev.post do
            type.call(['C', 1, ctrl, true], ['C', 2, ctrl, true], ['C', 3, ctrl, true], ['x', 1, 0, false])
            sleep 1 # il segnale arriva durante il blocco, dal thread di input
          end
          started = clock
          expect(run_loop(ev)).to eq(:stop)
          expect(ints.size).to eq(1)
          expect(ints.first - started).to be < 0.9
          expect(keys).to eq(['x'.ord])
          expect(c.held_signal_keys).to be_empty # il rilascio ha tolto il tasto
        end
      end
    end

    it 'il tasto tenuto resta nel contesto fra i run; get e getvec leggono il buffer durante e dopo run' do
      NcHelpers.open_context do |c|
        feeding_input(c) do |type, ints, queue|
          ev = new_loop(c)
          keys = []
          ev.on_key('c', ctrl: true) { |input| keys << [:c, input.evtype] }
          ev.on_key('\\', ctrl: true) { |input| keys << [:backslash, input.evtype] }
          ev.on_input { |input| keys << [input.id, input.evtype] }
          ev.on_key('y') { ev.stop }
          ev.post { type.call(['C', 1, ctrl, true], ['y', 1, 0, false]) }
          expect(run_loop(ev)).to eq(:stop)
          expect(ints.size).to eq(1)
          expect(c.held_signal_keys).to eq({ 'C'.ord => true })
          waited = :none
          ev.post do
            waited = c.get(timeout: 0.05) # niente nel buffer: attende sul pipe del thread
            type.call(['\\', 1, ctrl, true], ['C', 2, ctrl, true], ['C', 3, ctrl, true], ['y', 1, 0, false])
          end
          expect(ev.run(no_linesigs: true)).to eq(:stop)
          expect(waited).to be_nil
          expect(keys).to eq([[:backslash, :press]]) # ICH-537: il Ctrl+\ nuovo non cancella il Ctrl+C tenuto
          expect(c.held_signal_keys).to be_empty
          # stop prima che il ciclo legga: i tasti restano nel buffer del contesto
          ev.post do
            type.call(['a', 1, 0, false], ['b', 1, 0, false], ['d', 1, 0, false])
            sleep 0.01 until queue.empty?
            sleep 0.05
            ev.stop
          end
          expect(ev.run).to eq(:stop)
          expect(c.get(timeout: 0).id).to eq('a'.ord)
          expect(c.getvec(5, timeout: 0).map(&:id)).to eq(%w[b d].map(&:ord))
          expect(ints.size).to eq(1)
        end
      end
    end

    it 'un Interrupt appena avviato il thread di input (un Ctrl+C già in coda) non lascia il thread acceso' do
      NcHelpers.open_context do |c|
        feeding_input(c) do
          allow(c).to receive(:input_reader_start).and_wrap_original do |original, *args, &filter|
            original.call(*args, &filter)
            raise Interrupt # il segnale arriva al ritorno del metodo, prima che run assegni @input
          end
          fds = open_fds
          ev = described_class.new(c)
          expect(ev.run).to eq(:interrupt)
          expect(input_threads).to be_empty
          expect(open_fds).to eq(fds) # i pipe del thread sono chiusi
          allow(c).to receive(:input_reader_start).and_call_original
          ev.post { ev.stop }
          expect(ev.run).to eq(:stop)
          expect(input_threads).to be_empty
        end
      end
    end

    # In un processo figlio: sul codice di prima il secondo notcurses_stop è un double free.
    it 'un close da un gestore trap mentre close aspetta il thread di input ferma notcurses una volta sola' do
      script = <<~'RUBY'
        require 'notcurses'
        $stdout.sync = true
        $stops = 0
        module CountStops
          def stop_notcurses(ptr)
            $stops += 1
            super
          end
        end
        Notcurses::Context.prepend(CountStops)
        module SlowExit
          def pump(input)
            super
          ensure
            sleep 0.5 # il thread di input finisce tardi: close lo aspetta nel join di halt
          end
        end
        Notcurses.const_get(:InputReader).prepend(SlowExit)
        keep_open, stdin_w = IO.pipe # stdin aperto e vuoto: niente EOF prima del blocco di post
        STDIN.reopen(keep_open)
        opts = { output: '/dev/null', termtype: 'xterm-256color', suppress_banners: true, drain_input: false }
        Notcurses::Context.open(**opts) do |nc|
          trap('USR1') { nc.close }
          ev = Notcurses::UI::EventLoop.new(nc)
          ev.post do
            Thread.new { sleep 0.2; Process.kill('USR1', Process.pid) }
            nc.close
          end
          reason = ev.run
          puts "reason #{reason} stops #{$stops} closed #{nc.closed?}"
        end
        puts 'fine'
      RUBY
      lib = File.expand_path('../../../lib', __dir__)
      out, status = Open3.capture2e({ 'TERM' => 'xterm-256color' }, 'timeout', '-k', '5', '-s', 'KILL', '30',
        RbConfig.ruby, '-I', lib, '-e', script, stdin_data: '')
      expect(status.exitstatus).to eq(0), out
      expect(out).to include("reason stop stops 1 closed true\n")
      expect(out).to end_with("fine\n")
    end

    it 'un Interrupt durante la pulizia di run esce dopo: il contesto resta usabile da un altro ciclo' do
      NcHelpers.open_context do |c|
        feeding_input(c) do |type, ints|
          ev = described_class.new(c)
          allow(ev).to receive(:line_signal).and_wrap_original do |original, input|
            sleep 0.4 # il thread di input resta nel filtro mentre run lo ferma
            original.call(input)
          end
          main = Thread.current
          ev.post do
            type.call(['C', 1, ctrl, true])
            sleep 0.05 # il thread entra nel filtro
            Thread.new { (sleep 0.15) && main.raise(Interrupt) }
            ev.stop
          end
          fds = open_fds
          expect { ev.run }.to raise_error(Interrupt) # dopo la pulizia, non a metà
          expect(ev).not_to be_running
          expect(input_threads).to be_empty
          expect(open_fds).to eq(fds)
          other = described_class.new(c)
          keys = []
          other.on_input do |input|
            keys << [input.id, input_threads.size]
            other.stop if input.id == 'x'.ord
          end
          other.post { type.call(['C', 1, ctrl, true], ['x', 1, 0, false]) }
          started = clock
          expect(other.run).to eq(:stop)
          expect(clock - started).to be < 1
          expect(keys).to eq([['x'.ord, 1]]) # il thread gira durante run, il Ctrl+C è un segnale
          expect(ints.size).to eq(2)
        end
      end
    end

    it 'un blocco che chiude il contesto durante run ferma prima il thread di input' do
      NcHelpers.open_context do |c|
        feeding_input(c) do # niente EOF: il blocco gira di sicuro con il thread acceso
          ev = described_class.new(c)
          threads = nil
          ev.post do
            running = input_threads.size
            c.close
            threads = [running, input_threads.size]
          end
          expect(ev.run).to eq(:stop)
          expect(threads).to eq([1, 0])
          expect(c).to be_closed
        end
      end
    end
  end
end
