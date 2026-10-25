# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Ciclo di vita comune ai wrapper di puntatori opachi.
  #
  # Ogni classe che include il modulo imposta +@ptr+, +@closed+ e,
  # facoltativamente, +@owner+: la risorsa la cui chiusura invalida anche questa
  # (per esempio il contesto per un piano, il widget per il piano del widget).
  # Ogni classe definisce il proprio +close+, che chiama il distruttore C una
  # sola volta.
  #
  # @api private
  module Resource
    # @return [Boolean] true dopo +close+/+destroy+, o se il proprietario è chiuso
    def closed?
      return true if @closed
      return true if @owner&.closed?

      false
    end

    # Puntatore C, per passare l'oggetto a una funzione FFI.
    #
    # @return [::FFI::Pointer]
    # @raise [ClosedError] se l'oggetto o il suo proprietario sono chiusi
    def to_ptr
      raise ClosedError, "#{self.class.name}: oggetto già chiuso" if closed?

      @ptr
    end

    # @return [String]
    def inspect
      return "#<#{self.class.name} (chiuso)>" if closed?

      format('#<%<cls>s 0x%<addr>x>', cls: self.class.name, addr: @ptr.address)
    end

    # Costruttore con blocco: +Classe.open(...) { |obj| ... }+.
    module ClassMethods
      # Crea l'oggetto con +new+. Senza blocco restituisce l'oggetto; con il
      # blocco lo passa al blocco, lo chiude alla fine (anche in caso di
      # eccezione) e restituisce il valore del blocco.
      #
      # @param args [Array] argomenti posizionali di +new+
      # @param kwargs [Hash] argomenti con nome di +new+
      # @return [Object] l'oggetto, o il valore del blocco
      def open(*args, **kwargs, &block)
        Util.with_resource(new(*args, **kwargs), &block)
      end
    end
  end
end
