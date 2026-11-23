# Generated from notcurses 3.0.17
# Source: notcurses/src/lib/termdesc.c
# frozen_string_literal: true

require "notcurses"
require "fcntl"
require "io/console"
require "pty"

# ICH-576: le parti dell'uscita con un init fermo nel C che girano nel processo
# di rspec. La spec di integrazione (spec/integration/pty_spec.rb) le prova in un
# processo figlio, che SimpleCov non conta.
RSpec.describe "Uscita con un init fermo nel C (ICH-576)" do
  let(:util) { Notcurses::Util }

  describe "save_init_tty e restore_init_tty" do
    it "salvano il termios del tty dell'output e lo rimettono, dopo le sequenze" do
      master, slave = PTY.open
      tty = util.save_init_tty(slave.path, "\e[<u")
      expect(tty).not_to be_nil
      slave.raw! # come cbreak_mode dell'init: niente echo, modo non canonico
      expect(slave.echo?).to be(false)
      util.restore_init_tty(tty)
      expect(slave.echo?).to be(true)
      master.wait_readable(1)
      expect(master.read_nonblock(64)).to eq("\e[<u")
    ensure
      util.close_init_tty(tty)
      [master, slave].each { |io| io&.close }
    end

    it "senza un tty restituisce nil, e restore_init_tty e close_init_tty non fanno nulla" do
      allow(File).to receive(:open).and_call_original
      allow(File).to receive(:open).with("/dev/tty", any_args).and_raise(Errno::ENXIO)
      tty = util.save_init_tty(File::NULL, "")
      expect(tty).to be_nil
      expect { util.restore_init_tty(tty) }.not_to raise_error
      expect { util.close_init_tty(tty) }.not_to raise_error
    end
  end

  # rubocop:disable ThreadSafety/NewThread -- thread di init finti
  describe "watch_init" do
    it "con un init già finito non avvia il thread di controllo" do
      pending_init = util::PendingInit.new(Thread.new {}.tap(&:join))
      expect(util.watch_init(pending_init, nil)).to be_nil
      expect(util.watch_init(nil, nil)).to be_nil
    end

    it "con l'init ancora fermo dopo la scadenza ripristina il terminale e chiude il processo con l'errore" do
      stuck = Queue.new
      init = Thread.new { stuck.pop }
      pending_init = util::PendingInit.new(init, util.monotonic - 2, :tty)
      error = Interrupt.new
      expect(util).to receive(:restore_init_tty).with(:tty)
      expect(util).to receive(:force_exit).with(error)
      util.watch_init(pending_init, error).join(5)
    ensure
      stuck << true
      init&.join
    end

    it "se l'init finisce prima della scadenza non chiude il processo" do
      stuck = Queue.new
      init = Thread.new { stuck.pop }
      pending_init = util::PendingInit.new(init, util.monotonic + 5, nil)
      expect(util).not_to receive(:force_exit)
      watcher = util.watch_init(pending_init, nil)
      stuck << true
      expect(watcher.join(5)).to equal(watcher)
    end
  end
  # rubocop:enable ThreadSafety/NewThread

  describe "force_exit" do
    before do
      allow(Process).to receive(:exit!) { |status| throw :exited, status }
      allow(Process).to receive(:kill)
      allow(Signal).to receive(:trap)
      allow(util).to receive(:sleep)
    end

    def exit_status(error) = catch(:exited) { util.force_exit(error) }

    it "senza errore esce con 0, con una SystemExit con il suo stato" do
      expect([exit_status(nil), exit_status(SystemExit.new(3))]).to eq([0, 3])
    end

    it "con una SignalException rimette il default del segnale e lo manda al processo; Interrupt va su stderr" do
      status = nil
      expect { status = exit_status(Interrupt.new) }.to output(/Interrupt/).to_stderr
      expect(Signal).to have_received(:trap).with(Signal.list["INT"], "SYSTEM_DEFAULT")
      expect(Process).to have_received(:kill).with(Signal.list["INT"], Process.pid)
      expect(status).to eq(128 + Signal.list["INT"]) # se il default del segnale non chiude il processo
      expect { exit_status(SignalException.new("TERM")) }.not_to output.to_stderr
    end

    it "con un'altra eccezione scrive il messaggio su stderr ed esce con 1" do
      status = nil
      expect { status = exit_status(RuntimeError.new("boom")) }.to output(/boom/).to_stderr
      expect(status).to eq(1)
    end
  end
end
