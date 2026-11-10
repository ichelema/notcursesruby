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

  def open_fds = Dir.children('/proc/self/fd').size

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

    # Gli stub evitano di toccare il terminale di chi esegue la suite.
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

    it 'senza ISIG noto no_linesigs solleva ContextError, e run senza opzioni gira lo stesso' do
      stub_const('Notcurses::FFI::ISIG', nil)
      ev = new_loop
      expect { ev.run(no_linesigs: true) }.to raise_error(Notcurses::ContextError, /ISIG non noto/)
      ev.post { ev.stop }
      expect(ev.run).to eq(:stop)
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
      expect(log).to eq(%i[bang ctrl_x bang one])
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
  end
end
