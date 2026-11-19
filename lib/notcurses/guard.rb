# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Operazioni del wrapper in corso nel processo e chiusure fisiche in attesa.
  #
  # Un close di {Context} o {Direct} chiamato mentre un'operazione del
  # wrapper usa i puntatori C (da un gestore +trap+ che poi torna al codice
  # interrotto, o da un altro thread durante una chiamata C senza GVL) segna
  # subito la radice chiusa per le chiamate nuove, ma rinvia lo stop: lo
  # esegue l'ultima operazione che esce, nel suo thread. Lo stesso vale per
  # +ncvisual_destroy+ di un {Visual#close} chiamato dentro un'operazione del
  # thread corrente (un gestore +trap+, vedi {running_here?}). Il contatore è
  # unico per il processo perché notcurses ammette un solo contesto.
  #
  # Un oggetto può essere in coda più volte (un close ripetuto, o l'hook
  # at_exit, rimette in coda una chiusura che un'eccezione asincrona ha tolto
  # dalla coda): +release_native!+ esegue la chiusura una volta sola.
  #
  # Nessun lock. Ogni aggiornamento è una sola chiamata C (+<<+ e +pop+ di un
  # Array per le operazioni in corso, +<<+ e +shift+ per la coda), che né un
  # gestore trap né un cambio di thread interrompono a metà: con un intero e
  # <tt>+= 1</tt>, su Ruby 3.1 un aggiornamento si perdeva fra il thread
  # principale e il lettore di un {Subprocess} fermato con Thread#kill. Chi
  # chiude scrive lo stato di chiusura e la coda prima di leggere le
  # operazioni in corso; chi esce toglie la sua prima di leggere la coda:
  # almeno uno dei due vede l'altro, e +shift+ dà la coda a uno solo.
  #
  # @api private
  module Guard
    # rubocop:disable ThreadSafety/ClassInstanceVariable, ThreadSafety/MutableClassInstanceVariable -- stato del
    # processo, aggiornato senza punti di interruzione
    @ops = [] # un elemento per operazione in corso
    @pending = []

    class << self
      # @return [Integer] operazioni del wrapper in corso
      def busy = @ops.size

      # Esegue il blocco come operazione in corso: una chiusura richiesta
      # durante il blocco avviene alla sua uscita (o a quella dell'ultima
      # operazione ancora in corso).
      #
      # @return [Object] il valore del blocco
      # @raise [Exception] l'eccezione del blocco, oppure l'errore della
      #   chiusura rinviata eseguita all'uscita
      def run
        @ops << true
        counted = true
        begin
          yield
        rescue Exception => e # rubocop:disable Lint/RescueException
          failed = e
          raise
        ensure
          if counted # una sola volta per chiamata, anche se l'ensure gira di nuovo
            counted = false # rubocop:disable Lint/UselessAssignment -- letto da un ensure rieseguito
            @ops.pop
            settle(failed) if @ops.empty? && !@pending.empty?
          end
        end
      end

      # Mette in coda la chiusura fisica di obj (+release_native!+). Il
      # chiamante ha già segnato obj chiuso per le chiamate nuove.
      #
      # @param obj [Context, Direct, Visual]
      # @return [nil]
      def defer(obj)
        @pending << obj
        nil
      end

      # true se il thread corrente è dentro un'operazione del wrapper: per
      # esempio un gestore +trap+ che ha interrotto {run}. Legge la pila del
      # thread, quindi costa solo a chi lo chiama ({Visual#close}).
      #
      # @return [Boolean]
      def running_here?
        !@ops.empty? && caller_locations.any? { |l| l.path == __FILE__ && l.base_label == "run" }
      end

      # Esegue le chiusure in coda se nessuna operazione è in corso.
      #
      # @return [nil]
      # @raise [Exception] l'errore di una chiusura
      def settle_if_idle
        settle(nil) if @ops.empty? && !@pending.empty?
        nil
      end

      private

      # Con failed (un'eccezione già in volo dal blocco) l'errore di una
      # chiusura diventa un avviso: non sostituisce quella eccezione.
      def settle(failed)
        while @ops.empty? && (obj = @pending.shift) # shift: una sola esecuzione per oggetto
          begin
            obj.release_native!
          rescue Exception => e # rubocop:disable Lint/RescueException
            raise unless failed

            warn "notcurses: chiusura rinviata fallita: #{e.message} (#{e.class})"
            break
          end
        end
      end
    end
    # rubocop:enable ThreadSafety/ClassInstanceVariable, ThreadSafety/MutableClassInstanceVariable
  end
end
