# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  module UI
    # Task di {EventLoop#async} (ICH-607): un Fiber dello scheduler di
    # {EventLoop#run}. Quando il blocco attende I/O (un pipe, un socket),
    # +sleep+, una Queue, un Mutex o +Timeout.timeout+, il ciclo continua a
    # consegnare eventi e riprende il task nel giro in cui l'attesa finisce.
    #
    # Il task finisce in tre modi: il blocco restituisce un valore ({#wait} lo
    # restituisce), il task riceve {Stop} ({#stop} o l'uscita di run), oppure
    # il blocco solleva un'eccezione, che esce da {EventLoop#run} come quella
    # di un handler.
    #
    # Un task che legge un flusso sempre pronto (un pipe sempre pieno, un
    # file) non attende mai, e ferma input e render finché non cede il ciclo
    # con {#pass}.
    #
    # Thread: {#stop} e {#wait} dal thread del ciclo, come {EventLoop}; gli
    # altri thread usano {EventLoop#post}.
    #
    # @example
    #   reader = app.async do |task|
    #     loop do
    #       log.append(io.readpartial(4096))
    #       task.pass
    #     end
    #   rescue EOFError
    #     log.append("fine\n")
    #   end
    #   app.on_key('s') { reader.stop }
    class Task
      # Eccezione con cui {Task#stop} e l'uscita di {EventLoop#run} fermano un
      # task, anche uno di +Fiber.schedule+. Non deriva da StandardError: un
      # +rescue => e+ del task non la ferma, e il suo ensure gira.
      class Stop < Exception; end # rubocop:disable Lint/InheritException

      # @param block [Proc] il blocco di {EventLoop#async}
      # @api private
      def initialize(block)
        @block = block
        @thread = Thread.current
        @fiber = nil
        @scheduler = nil # lo scheduler che ha avviato il task
        @state = :pending # :pending (non partito), :started, :stopped (fermato prima di partire)
        @value = nil
        @finished = Thread::Queue.new # chiusa alla fine del task: sveglia chi attende in wait
      end

      # Avvia il task con +Fiber.schedule+, nel thread del ciclo durante run.
      #
      # @return [self]
      # @api private
      def start
        return self if finished? # fermato prima di partire

        @scheduler = Fiber.scheduler
        Fiber.schedule { body }
        self
      end

      # @return [Boolean] true finché il task non è finito (anche prima che
      #   parta)
      def alive? = !finished?

      # Attende la fine del task.
      #
      # @return [Object, nil] il valore del blocco; nil se il task è stato
      #   fermato o è uscito con un'eccezione
      # @raise [Error] se il task non è finito e l'attesa bloccherebbe il
      #   ciclo che lo fa avanzare: da un handler, fuori da run o dal task
      #   stesso
      def wait
        return @value if finished?
        raise Error, "Task#wait: un task non può attendere sé stesso" if Fiber.current.equal?(@fiber)

        unless suspendable?
          raise Error, "Task#wait: il task non è finito, e qui l'attesa fermerebbe il ciclo che lo fa avanzare " \
                       "(un handler, o fuori da run): attendi da un altro task, per esempio app.async { task.wait }"
        end

        @finished.pop
        @value
      end

      # Ferma il task: il task riceve {Stop} nel punto in cui attende, e il
      # suo ensure gira prima che stop ritorni, salvo un ensure che attende di
      # nuovo (il task finisce allora in un giro successivo). Chiamato da un
      # altro task, quel task cede il ciclo e riparte dopo. Un task non ancora
      # partito non parte più; chiamato dal task stesso, solleva {Stop} lì.
      # Un task finito resta com'è.
      #
      # @return [self]
      # @raise [Error] da un thread diverso da quello del ciclo
      # @raise [Stop] chiamato dal task stesso
      def stop
        unless Thread.current.equal?(@thread)
          raise Error, "Task#stop: chiamalo dal thread del ciclo; da un altro thread usa post { task.stop }"
        end
        return self if finished?

        if @state == :pending
          @state = :stopped
          @finished.close
        elsif Fiber.current.equal?(@fiber)
          raise Stop
        else
          @scheduler.stop(@fiber)
        end
        self
      end

      # Cede il ciclo: gli altri task pronti, gli eventi e il render vengono
      # prima che il task corrente riparta. Fuori da un task non fa niente.
      #
      # @return [self]
      def pass
        sleep(0) # sleep(0) chiama l'hook yield dello scheduler
        self
      end

      private

      def finished? = @finished.closed? || abandoned?

      # Un task avviato da un Fiber che un handler riprende con resume parte al
      # giro successivo: se run esce prima, lo scheduler lo scarta.
      def abandoned? = @state == :pending && @scheduler&.closed?

      # wait può sospendere il Fiber corrente: da un altro thread, o da un task
      # che il ciclo ha avviato con transfer.
      def suspendable?
        return true unless Thread.current.equal?(@thread)

        scheduler = Fiber.scheduler
        !Fiber.current.blocking? && scheduler.is_a?(Scheduler) && scheduler.transferring?
      end

      def body
        return unless @state == :pending # fermato prima di partire

        @fiber = Fiber.current
        @state = :started
        @value = @block.call(self)
      rescue Stop
        nil # fermato: wait restituisce nil
      ensure
        @finished.close
      end
    end
  end
end
