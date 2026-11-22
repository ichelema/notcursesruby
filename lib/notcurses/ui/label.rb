# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  module UI
    # Testo statico: una riga del piano per ogni riga del testo ("\n"),
    # tagliata alla larghezza; le righe in più non si vedono. Non prende il
    # focus.
    #
    # @example
    #   Notcurses::UI::Label.new(app.root, text: "Riga 1\nRiga 2", align: :center, size: 2)
    class Label
      include Component

      # @return [Array<Symbol>] allineamenti ammessi
      ALIGNS = %i[left center right].freeze

      # @return [String] testo
      attr_reader :text

      # @return [Symbol] :left, :center o :right
      attr_reader :align

      # @param parent [Container] contenitore
      # @param text [String] testo; "\n" separa le righe. Non ammessi: TAB,
      #   altri caratteri di controllo, U+2028, U+2029, caratteri di
      #   larghezza zero isolati (le regole di {Plane#putstr})
      # @param align [Symbol] :left, :center o :right
      # @param styles [Integer, Symbol, Array<Symbol>] stili del testo
      # @param channels [Channels, Integer] colori del testo e dello sfondo
      # @param size [Integer, nil] dimensione fissa nel contenitore, >= 1
      # @param weight [Integer, nil] quota dello spazio restante, >= 1 (default 1)
      # @raise [ArgumentError] con un testo o un allineamento non ammessi, con
      #   size e weight insieme, se channels ha lo sfondo con alpha
      #   :highcontrast
      # @raise [TypeError] se un argomento ha il tipo sbagliato
      # @raise [ClosedError] se il contenitore è chiuso
      def initialize(parent, text: '', align: :left, styles: [], channels: 0, size: nil, weight: nil)
        @text = Text.check!(text, 'text', Text.host(parent), newlines: true)
        raise ArgumentError, "align = #{align.inspect} non valido: usa :left, :center o :right" unless ALIGNS.include?(align)

        @align = align
        @styles = Util.styles_value(styles)
        @channels = Util.plane_channels_value(channels, 'channels')
        attach_component!(parent, size: size, weight: weight)
      end

      # Cambia il testo e ridisegna.
      #
      # @param text [String] come in {#initialize}
      # @raise [ArgumentError, TypeError] se il testo non è ammesso
      # @raise [ClosedError] se il componente è chiuso
      def text=(text)
        to_ptr
        @text = Text.check!(text, 'text', @plane, newlines: true)
        redraw
      end

      private

      def draw
        @plane.set_base(egc: ' ', channels: @channels)
        @plane.styles = @styles
        @plane.channels = @channels
        @text.split("\n").first(@plane.dim_y).each_with_index { |line, y| put_text(y, line, align: @align) }
      end
    end
  end
end
