# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  module UI
    # Contenitore: dispone i figli in righe (+direction: :vertical+) o in
    # colonne (+:horizontal+), nell'ordine di creazione, con un bordo e un
    # titolo facoltativi. Ogni figlio occupa tutto lo spazio trasversale.
    #
    # Lungo l'asse, prima i figli con +size:+ ricevono la loro dimensione,
    # nell'ordine di creazione e finché c'è spazio; poi il resto si divide fra
    # gli altri in proporzione a +weight:+ (default 1). Un figlio che resta
    # senza spazio è nascosto ({Component#visible?} false).
    #
    # @example
    #   form = Notcurses::UI::Container.new(app.root, border: true, title: 'Accesso')
    #   Notcurses::UI::Label.new(form, text: 'Nome:', size: 1)
    #   row = Notcurses::UI::Container.new(form, direction: :horizontal, size: 1)
    class Container
      include Component

      # @return [Array<Symbol>] direzioni ammesse
      DIRECTIONS = %i[vertical horizontal].freeze

      # @return [Symbol] :vertical o :horizontal
      attr_reader :direction

      # @return [String, nil] titolo, nel bordo in alto
      attr_reader :title

      # @param parent [Container, App] contenitore (un'App solo per {App#root})
      # @param direction [Symbol] :vertical (figli in righe) o :horizontal
      #   (figli in colonne)
      # @param border [Boolean] true = bordo arrotondato; i figli stanno dentro
      # @param title [String, nil] titolo nel bordo in alto (con border: true),
      #   tagliato alla larghezza
      # @param channels [Channels, Integer] colori del bordo e dello sfondo
      # @param size [Integer, nil] dimensione fissa nel contenitore, >= 1
      # @param weight [Integer, nil] quota dello spazio restante, >= 1 (default 1)
      # @raise [ArgumentError] con una direzione sconosciuta, un titolo con
      #   caratteri non ammessi (come {Label}), size e weight insieme, se
      #   channels ha lo sfondo con alpha :highcontrast, o come {Component}
      # @raise [TypeError] se un argomento ha il tipo sbagliato
      # @raise [ClosedError] se il contenitore o l'App sono chiusi
      def initialize(parent, direction: :vertical, border: false, title: nil, channels: 0, size: nil, weight: nil)
        raise ArgumentError, "direction = #{direction.inspect} non valida: usa :vertical o :horizontal" unless DIRECTIONS.include?(direction)

        @direction = direction
        @border = Util.bool!(border, 'border')
        @title = title.nil? ? nil : Text.check!(title, 'title')
        @channels = Util.plane_channels_value(channels, 'channels')
        @children = []
        @closing = false
        attach_component!(parent, size: size, weight: weight)
      end

      # @return [Boolean] true se il contenitore ha il bordo
      def border? = @border

      # @return [Array<Component>] figli, nell'ordine di creazione
      def children = @children.dup

      # Come {Component#layout}, poi dispone i figli.
      #
      # @param rows [Integer] righe, >= 0
      # @param cols [Integer] colonne, >= 0
      # @return [self]
      # @raise [TypeError, ArgumentError] se rows o cols non sono interi >= 0
      # @raise [ClosedError] se il contenitore è chiuso
      # @raise [Exception] l'eccezione del disegno di un figlio
      def layout(rows, cols)
        super
        layout_children if @visible
        self
      end

      # Aggiunge un figlio e rifà il layout. Lo chiama il figlio alla creazione.
      #
      # @param child [Component]
      # @return [self]
      # @api private
      def add_child(child)
        @children << child
        layout_children if @visible
        self
      end

      # Toglie un figlio e rifà il layout (non durante la chiusura del
      # contenitore). Lo chiama il figlio alla chiusura.
      #
      # @param child [Component]
      # @return [self]
      # @api private
      def remove_child(child)
        @children.delete(child)
        layout_children if @visible && !@closing
        self
      end

      private

      def draw
        rows, cols = @plane.dims
        @plane.set_base(egc: ' ', channels: @channels)
        return unless @border && rows >= 2 && cols >= 2

        @plane.perimeter(set: :rounded, channels: @channels)
        return unless @title

        @plane.channels = @channels
        put_text(0, " #{@title} ", x: 1, cols: cols - 2)
      end

      def close_parts
        @closing = true
        @children.reverse.each(&:close)
      end

      def layout_children
        rows, cols = @plane.dims
        inset = @border ? 1 : 0
        vertical = @direction == :vertical
        along, across = [rows - (2 * inset), cols - (2 * inset)].map { |n| [n, 0].max }
        along, across = across, along unless vertical
        pos = inset
        @children.zip(distribute(along)) do |child, n|
          if n.zero? || across.zero?
            child.layout(0, 0)
            next
          end

          vertical ? child.plane.move(pos, inset) : child.plane.move(inset, pos)
          vertical ? child.layout(n, across) : child.layout(across, n)
          pos += n
        end
      end

      # Spazio lungo l'asse per ogni figlio: le dimensioni fisse
      # nell'ordine, poi il resto per peso, con arrotondamento cumulativo (la
      # somma è esatta).
      def distribute(space)
        left = space
        fixed = @children.map do |child|
          next unless child.layout_size

          n = [child.layout_size, left].min
          left -= n
          n
        end
        weights = @children.map { |child| child.layout_size ? 0 : child.layout_weight }
        total = weights.sum
        acc = 0
        fixed.zip(weights).map do |n, weight|
          next n if n

          start = left * acc / total
          acc += weight
          (left * acc / total) - start
        end
      end
    end
  end
end
