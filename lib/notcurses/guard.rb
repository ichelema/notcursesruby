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
  # esegue l'ultima operazione che esce, nel suo thread. Il contatore è unico
  # per il processo perché notcurses ammette un solo contesto.
  #
  # Nessun lock: gli aggiornamenti del contatore e della coda non hanno punti
  # di interruzione di Ruby fra lettura e scrittura, quindi né un gestore trap
  # né un cambio di thread vi si inseriscono. Chi chiude scrive lo stato di
  # chiusura e la coda prima di leggere il contatore; chi esce decrementa prima
  # di leggere la coda: almeno uno dei due vede l'altro, e +shift+ dà la coda a
  # uno solo.
  #
  # @api private
  module Guard
    # rubocop:disable ThreadSafety/ClassInstanceVariable, ThreadSafety/MutableClassInstanceVariable -- stato del
    # processo, aggiornato senza punti di interruzione
    @busy = 0
    @pending = []

    class << self
      # @return [Integer] operazioni del wrapper in corso
      attr_reader :busy

      # Esegue il blocco come operazione in corso: una chiusura richiesta
      # durante il blocco avviene alla sua uscita (o a quella dell'ultima
      # operazione ancora in corso).
      #
      # @return [Object] il valore del blocco
      # @raise [Exception] l'eccezione del blocco, oppure l'errore della
      #   chiusura rinviata eseguita all'uscita
      def run
        @busy += 1
        begin
          yield
        rescue Exception => e # rubocop:disable Lint/RescueException
          failed = e
          raise
        ensure
          @busy -= 1
          settle(failed) if @busy.zero? && !@pending.empty?
        end
      end

      # Mette in coda la chiusura fisica di obj (+release_native!+). Il
      # chiamante ha già segnato obj chiuso per le chiamate nuove.
      #
      # @param obj [Context, Direct]
      # @return [nil]
      def defer(obj)
        @pending << obj
        nil
      end

      # Esegue le chiusure in coda se nessuna operazione è in corso.
      #
      # @return [nil]
      # @raise [Exception] l'errore di una chiusura
      def settle_if_idle
        settle(nil) if @busy.zero? && !@pending.empty?
        nil
      end

      private

      # Con failed (un'eccezione già in volo dal blocco) l'errore di una
      # chiusura diventa un avviso: non sostituisce quella eccezione.
      def settle(failed)
        while @busy.zero? && (obj = @pending.shift) # shift: una sola esecuzione per oggetto
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
