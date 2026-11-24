# Generated from notcurses 3.0.17
# Source: notcurses/src/lib/in.c
# frozen_string_literal: true

require "io/nonblock"
require_relative "scheduler"

# Prototipo dello studio ICH-600: Notcurses::UI::App con un Fiber scheduler al
# posto dei thread. Cambia solo run: consegna degli eventi (dispatch, focus,
# on_key, on_input), post, LogView e render restano quelli di App, così la
# misura confronta solo l'attesa e il passaggio dei dati.
#
# - Input: un Fiber chiama Context#get senza timeout. get attende con
#   IO#wait_readable sul descrittore di notcurses_inputready_fd, che sotto lo
#   scheduler diventa l'hook io_wait: niente thread di input (InputReader).
# - post: un Fiber attende sul pipe di risveglio di EventLoop ed esegue i
#   blocchi in coda (run_posted di EventLoop). post resta usabile da altri
#   thread e dai trap.
# - #async: un Fiber dell'applicazione, per esempio la lettura di un pipe al
#   posto di un FdPlane.
# - Render: una volta prima di ogni attesa del ciclo, se un Fiber è
#   ripartito; con un Fiber ancora pronto (#pass) al massimo ogni FRAME_S.
#
# Segnali di linea (Ctrl+C, Ctrl+Z, Ctrl+\ di kitty): con linesigs: :ruby,
# come EventLoop#run, il wrapper toglie il compito a notcurses e il Fiber di
# input li alza (EventLoop#line_signal) quando legge il tasto, quindi dopo la
# fine dell'handler in corso; con linesigs: :native li alza notcurses dal suo
# thread C, subito, ma anche per ripetizioni e rilasci (ICH-456).
#
# Escluso dal prototipo: timer (after, every), resize (trap WINCH e CONT),
# IXON e ISIG con no_flow_control e no_linesigs, ripristino dei flag dopo run.
class FiberApp < Notcurses::UI::App
  # Intervallo minimo fra due render quando un Fiber è ancora pronto.
  FRAME_S = 1.0 / 60

  def initialize(context)
    super
    @tasks = []
    @scheduler = nil
  end

  # Esegue il blocco in un Fiber non bloccante del ciclo. Prima di run il
  # Fiber parte all'avvio di run. Solo dal thread del ciclo.
  def async(&block)
    raise ArgumentError, "async: serve un blocco" unless block

    @scheduler ? Fiber.schedule(&block) : @tasks << block
    self
  end

  # Cede il ciclo agli altri Fiber e al render (ProtoScheduler#pass). Solo
  # da un Fiber di #async, durante run.
  def pass = @scheduler.pass

  def run(linesigs: :ruby)
    raise Notcurses::Error, "FiberApp#run: il ciclo è già in esecuzione" if @running

    @running = true
    @stop_requested = false
    @reason = :stop
    @line_signals = take_line_signals(linesigs)
    wake_r, @wake_w = IO.pipe
    @dims = @context.dims
    render_frame
    last_render = clock
    @scheduler = ProtoScheduler.new(idle: lambda { |will_wait|
      next if @context.closed?
      # un Fiber ancora pronto (pass): al massimo un render per frame, come i blocchi di post raggruppati in un giro
      next unless will_wait || clock - last_render >= FRAME_S

      render_frame
      last_render = clock
    })
    Fiber.set_scheduler(@scheduler)
    Fiber.schedule { read_input }
    Fiber.schedule { run_posted_blocks(wake_r) }
    @tasks.each { |task| Fiber.schedule(&task) }
    @tasks.clear
    @scheduler.run { @stop_requested || @context.closed? }
    @reason
  rescue Interrupt
    :interrupt
  ensure
    Fiber.set_scheduler(nil) if @scheduler # close: Stop ai Fiber in attesa
    @scheduler = nil
    @wake_w&.close
    @wake_w = nil
    wake_r&.close
    @running = false
    @stop_requested = false
  end

  private

  def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  # Come l'avvio di EventLoop#run: con :ruby spegne il flag di notcurses e
  # rimette ISIG com'era. @return [Boolean] true se il Fiber di input alza i
  # segnali
  def take_line_signals(linesigs)
    return false unless linesigs == :ruby && @context.linesigs_flag?

    isig = @context.linesigs?
    @context.linesigs_disable
    @context.isig_enable if isig
    isig
  end

  def read_input
    while live? && (input = @context.get)
      case input.id
      when Notcurses::Key::EOF
        @reason = :eof
        @stop_requested = true
      when Notcurses::Key::RESIZE then handle_resize(refresh: true)
      else
        next if @line_signals && line_signal(input)

        dispatch(input)
      end
    end
  end

  # Il primo giro esegue i blocchi di post arrivati prima di run.
  def run_posted_blocks(wake_r)
    loop do
      run_posted
      wake_r.wait_readable
      drain(wake_r)
    end
  end
end
