# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  module UI
    # Campo di testo a una riga, scritto in Ruby (non sopra {Reader}):
    # inserimento, Backspace, Canc, frecce, Home, Fine; il testo scorre in
    # orizzontale per tenere visibile il cursore, anche con i glifi larghi.
    # Il cursore si muove per grapheme cluster. Invio chiama il blocco, se
    # c'è. I tasti con Ctrl o Alt non vengono consumati (restano per
    # {EventLoop#on_key}). Il testo sta nella prima riga del piano.
    #
    # @example
    #   name = Notcurses::UI::TextInput.new(form, size: 1) { |input| greet(input.text) }
    class TextInput
      include Component

      # @return [String] testo
      attr_reader :text

      # @return [Integer] posizione del cursore: grapheme cluster prima del cursore
      attr_reader :position

      # @param parent [Container] contenitore
      # @param text [String] testo iniziale, una riga (le regole di {Label});
      #   il cursore va in fondo
      # @param channels [Channels, Integer] colori senza il focus
      # @param focused_channels [Channels, Integer] colori con il focus
      # @param size [Integer, nil] dimensione fissa nel contenitore, >= 1
      # @param weight [Integer, nil] quota dello spazio restante, >= 1 (default 1)
      # @yieldparam input [TextInput] il campo, quando arriva Invio
      # @raise [ArgumentError] con un testo non ammesso, con size e weight insieme,
      #   se channels o focused_channels hanno lo sfondo con alpha :highcontrast
      # @raise [TypeError] se un argomento ha il tipo sbagliato
      # @raise [ClosedError] se il contenitore è chiuso
      def initialize(parent, text: '', channels: FIELD_CHANNELS, focused_channels: FOCUSED_CHANNELS, size: nil, weight: nil,
                     &block)
        @text = Text.check!(text, 'text', Text.host(parent))
        @position = @text.grapheme_clusters.size
        @first = 0
        @cursor_col = 0
        @channels = Util.plane_channels_value(channels, 'channels')
        @focused_channels = Util.plane_channels_value(focused_channels, 'focused_channels')
        @block = block
        attach_component!(parent, size: size, weight: weight)
      end

      # Cambia il testo, porta il cursore in fondo e ridisegna.
      #
      # @param text [String] come in {#initialize}
      # @raise [ArgumentError, TypeError] se il testo non è ammesso
      # @raise [ClosedError] se il componente è chiuso
      def text=(text)
        to_ptr
        @text = Text.check!(text, 'text', @plane)
        @position = @text.grapheme_clusters.size
        @first = 0
        redraw
      end

      # @return [Boolean] true
      def focusable? = true

      # @return [Array(Integer, Integer)] [0, colonna del cursore nel piano]
      def cursor = [0, @cursor_col]

      # Modifica il testo con la tastiera. Un carattere che il testo non
      # ammette (per esempio un segno combinante all'inizio) non viene
      # inserito e l'evento non è consumato.
      #
      # @param input [Input] l'evento
      # @return [Boolean] true se l'evento è consumato
      # @raise [Exception] l'eccezione del blocco
      def offer_input(input)
        return false if input.mouse? || input.release? || input.ctrl? || input.alt?

        graphemes = @text.grapheme_clusters
        case input.id
        when Key::LEFT then @position -= 1 if @position.positive?
        when Key::RIGHT then @position += 1 if @position < graphemes.size
        when Key::HOME then @position = 0
        when Key::END_KEY then @position = graphemes.size
        when Key::BACKSPACE
          return true unless @position.positive?

          @position -= 1
          graphemes.delete_at(@position)
          @text = -graphemes.join
        when Key::DEL
          return true if @position >= graphemes.size

          graphemes.delete_at(@position)
          @text = -graphemes.join
        when Key::ENTER
          return false unless @block

          @block.call(self)
          return true
        else
          # eff_text: con il protocollo kitty utf8 è il tasto senza Shift ("1" per "!")
          return false unless insert(graphemes, input.eff_text)
        end
        redraw
        true
      end

      private

      # @return [Boolean] true se il testo ammette il carattere
      def insert(graphemes, str)
        return false if str.empty? || str.match?(/\p{Cc}/)

        before = graphemes[0...@position].join + str
        @text = Text.check!(before + graphemes[@position..].join, 'text', @plane)
        @position = before.grapheme_clusters.size
        true
      rescue ArgumentError
        false
      end

      def draw
        cols = @plane.dim_x
        channels = focused? ? @focused_channels : @channels
        @plane.set_base(egc: ' ', channels: channels)
        @plane.channels = channels
        graphemes = @text.grapheme_clusters
        @position = [@position, graphemes.size].min
        widths = graphemes.map { |g| Notcurses.strwidth(g) }
        # il grapheme sotto il cursore (o una cella dopo l'ultimo carattere) resta dentro il campo
        under = widths[@position] || 1
        @first = @position if @position < @first
        @first += 1 while @first < @position && widths[@first...@position].sum + under > cols
        @first -= 1 while @first.positive? && widths[(@first - 1)...@position].sum + under <= cols
        @cursor_col = widths[@first...@position].sum
        put_text(0, graphemes[@first..].join)
      end
    end
  end
end
