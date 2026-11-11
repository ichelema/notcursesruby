# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  module UI
    # Pulsante: l'etichetta dentro un bordo (con almeno 3 righe e 4 colonne)
    # o fra parentesi, "[ etichetta ]". Invio, Spazio (senza Ctrl e Alt) o un
    # clic con BUTTON1 chiamano il blocco; un drag non ripete il clic (vedi
    # {App}). Con il focus usa focused_channels.
    #
    # @example
    #   Notcurses::UI::Button.new(app.root, 'Esci', size: 3) { app.stop }
    class Button
      include Component

      # @return [String] etichetta
      attr_reader :label

      # @param parent [Container] contenitore
      # @param label [String] etichetta, una riga (le regole di {Label})
      # @param channels [Channels, Integer] colori senza il focus
      # @param focused_channels [Channels, Integer] colori con il focus
      # @param size [Integer, nil] dimensione fissa nel contenitore, >= 1
      # @param weight [Integer, nil] quota dello spazio restante, >= 1 (default 1)
      # @yieldparam button [Button] il pulsante
      # @raise [ArgumentError] senza blocco, con un'etichetta non ammessa, con
      #   size e weight insieme
      # @raise [TypeError] se un argomento ha il tipo sbagliato
      # @raise [ClosedError] se il contenitore è chiuso
      def initialize(parent, label, channels: 0, focused_channels: FOCUSED_CHANNELS, size: nil, weight: nil, &block)
        raise ArgumentError, 'Button: serve un blocco' unless block

        @label = Text.check!(label, 'label')
        @channels = Util.channels_value(channels, 'channels')
        @focused_channels = Util.channels_value(focused_channels, 'focused_channels')
        @block = block
        attach_component!(parent, size: size, weight: weight)
      end

      # Cambia l'etichetta e ridisegna.
      #
      # @param label [String] come in {#initialize}
      # @raise [ArgumentError, TypeError] se l'etichetta non è ammessa
      # @raise [ClosedError] se il componente è chiuso
      def label=(label)
        to_ptr
        @label = Text.check!(label, 'label')
        redraw
      end

      # @return [Boolean] true
      def focusable? = true

      # Invio, Spazio o un clic con BUTTON1 chiamano il blocco. Durante un
      # drag {App} non offre le pressioni ripetute: il blocco scatta una volta.
      #
      # @param input [Input] l'evento
      # @return [Boolean] true se l'evento attiva il pulsante
      # @raise [Exception] l'eccezione del blocco
      def offer_input(input)
        return false if input.release?

        hit = if input.mouse?
                input.id == Key::BUTTON1 && input.press?
              else
                [Key::ENTER, Key::SPACE].include?(input.id) && !input.ctrl? && !input.alt?
              end
        return false unless hit

        @block.call(self)
        true
      end

      private

      def draw
        rows, cols = @plane.dims
        channels = focused? ? @focused_channels : @channels
        @plane.set_base(egc: ' ', channels: channels)
        @plane.channels = channels
        if rows >= 3 && cols >= 4
          @plane.perimeter(set: :rounded, channels: channels)
          put_text(rows / 2, @label, x: 1, cols: cols - 2, align: :center)
        else
          put_text(rows / 2, "[ #{@label} ]", align: :center)
        end
      end
    end
  end
end
