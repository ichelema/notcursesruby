# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  module UI
    # Elenco con una voce scelta e lo scorrimento, scritto in Ruby (non
    # sopra {Selector}): frecce, PgUp, PgDn, Home, Fine, rotella del mouse,
    # clic con BUTTON1 su una voce. Invio chiama il blocco, se c'è. Con il
    # focus la voce scelta usa focused_channels su tutta la riga, senza il
    # focus è in grassetto. Una voce per riga, tagliata alla larghezza.
    #
    # @example
    #   list = Notcurses::UI::ListView.new(app.root, items: %w[uno due tre]) { |l| open(l.selected_item) }
    class ListView
      include Component

      # @return [Array<String>] voci (frozen)
      attr_reader :items

      # @return [Integer, nil] indice della voce scelta; nil con l'elenco vuoto
      attr_reader :selected

      # @param parent [Container] contenitore
      # @param items [Array<String>] voci, una riga ciascuna (le regole di {Label})
      # @param channels [Channels, Integer] colori delle voci
      # @param focused_channels [Channels, Integer] colori della voce scelta
      #   con il focus
      # @param size [Integer, nil] dimensione fissa nel contenitore, >= 1
      # @param weight [Integer, nil] quota dello spazio restante, >= 1 (default 1)
      # @yieldparam list [ListView] l'elenco, quando arriva Invio
      # @raise [ArgumentError] con una voce non ammessa, con size e weight insieme,
      #   se channels o focused_channels hanno lo sfondo con alpha :highcontrast
      # @raise [TypeError] se items non è un Array di String, o un argomento
      #   ha il tipo sbagliato
      # @raise [ClosedError] se il contenitore è chiuso
      def initialize(parent, items: [], channels: 0, focused_channels: FOCUSED_CHANNELS, size: nil, weight: nil, &block)
        @items = items!(items, Text.host(parent))
        @selected = @items.empty? ? nil : 0
        @top = 0
        @channels = Util.plane_channels_value(channels, 'channels')
        @focused_channels = Util.plane_channels_value(focused_channels, 'focused_channels')
        @block = block
        attach_component!(parent, size: size, weight: weight)
      end

      # Cambia le voci e ridisegna. La voce scelta resta allo stesso indice
      # (l'ultima, se l'elenco si accorcia).
      #
      # @param items [Array<String>] come in {#initialize}
      # @raise [ArgumentError, TypeError] se le voci non sono ammesse
      # @raise [ClosedError] se il componente è chiuso
      def items=(items)
        to_ptr
        @items = items!(items, @plane)
        @selected = @items.empty? ? nil : [@selected || 0, @items.size - 1].min
        redraw
      end

      # Sceglie una voce e ridisegna (l'elenco scorre fino alla voce).
      #
      # @param index [Integer] indice, 0...items.size
      # @raise [TypeError, ArgumentError] se index non è un indice dell'elenco
      # @raise [ClosedError] se il componente è chiuso
      def selected=(index)
        to_ptr
        @selected = Util.integer!(index, 'index', 0...@items.size)
        redraw
      end

      # @return [String, nil] la voce scelta
      def selected_item = @selected && @items[@selected]

      # @return [Boolean] true
      def focusable? = true

      # Sposta la scelta, o chiama il blocco con Invio.
      #
      # @param input [Input] l'evento
      # @return [Boolean] true se l'evento è consumato
      # @raise [Exception] l'eccezione del blocco
      def offer_input(input)
        return false if input.release? || input.ctrl? || input.alt? || @items.empty?

        if input.id == Key::ENTER
          return false unless @block

          @block.call(self)
          return true
        end
        index = target_index(input)
        return false if index.nil?

        @selected = index.clamp(0, @items.size - 1)
        redraw
        true
      end

      private

      # @param host [Plane, nil] piano per il controllo di notcurses (vedi {Text.check!})
      # @raise [TypeError, ArgumentError] se le voci non sono ammesse
      def items!(items, host)
        raise TypeError, "items deve essere Array, non #{items.class}" unless items.is_a?(Array)

        items.each_with_index.map { |item, i| Text.check!(item, "items[#{i}]", host) }.freeze
      end

      def target_index(input)
        page = [@plane.dim_y - 1, 1].max
        case input.id
        when Key::UP, Key::SCROLL_UP then @selected - 1
        when Key::DOWN, Key::SCROLL_DOWN then @selected + 1
        when Key::PGUP then @selected - page
        when Key::PGDOWN then @selected + page
        when Key::HOME then 0
        when Key::END_KEY then @items.size - 1
        when Key::BUTTON1
          index = @top + input.y - @plane.abs_y
          index if index < @items.size
        end
      end

      def draw
        rows, cols = @plane.dims
        @plane.set_base(egc: ' ', channels: @channels)
        return if @items.empty?

        @top = @selected if @selected < @top
        @top = @selected - rows + 1 if @selected >= @top + rows
        @top = @top.clamp(0, [@items.size - rows, 0].max)
        @items[@top, rows].each_with_index do |item, row|
          chosen = @top + row == @selected
          highlight = chosen && focused?
          @plane.channels = highlight ? @focused_channels : @channels
          @plane.styles = chosen && !highlight ? :bold : 0
          line = Text.truncate(item, cols)
          line += ' ' * (cols - Notcurses.strwidth(line)) if highlight
          put_text(row, line)
        end
      end
    end
  end
end
