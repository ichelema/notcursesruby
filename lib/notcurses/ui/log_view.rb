# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  module UI
    # Ultime righe di un testo che cresce, per esempio l'uscita di un
    # {Subprocess} o di un {FdPlane}. Le righe stanno in Ruby (al massimo
    # max_lines): il piano non scorre mai, quindi un resize ridisegna tutto
    # senza il bug delle righe permutate di notcurses 3.0.17.
    #
    # {#append} accetta anche i byte grezzi del thread di lettura: la riga
    # non finita (anche un carattere UTF-8 spezzato fra due blocchi) resta da
    # parte fino al "\n" successivo, e il testo viene ripulito solo al
    # disegno, solo per le righe visibili (UTF-8 non valido e caratteri di
    # controllo diventano "?", TAB diventa spazi, "\r\n" vale "\n"). Non
    # prende il focus.
    #
    # Thread: {#append} solo dal thread del ciclo; il thread di lettura passa
    # i dati con {EventLoop#post}.
    #
    # @example
    #   log = Notcurses::UI::LogView.new(app.root)
    #   Notcurses::Subprocess.new(log.plane, 'ping', '-c', '3', 'localhost') do |_s, bytes|
    #     app.post { log.append(bytes) unless log.closed? }
    #   end
    class LogView
      include Component

      # @return [Integer] righe tenute in memoria
      attr_reader :max_lines

      # @param parent [Container] contenitore
      # @param max_lines [Integer] righe finite da tenere, >= 1: le più
      #   vecchie escono per prime
      # @param channels [Channels, Integer] colori del testo e dello sfondo
      # @param size [Integer, nil] dimensione fissa nel contenitore, >= 1
      # @param weight [Integer, nil] quota dello spazio restante, >= 1 (default 1)
      # @raise [ArgumentError] se max_lines è minore di 1, con size e weight insieme
      # @raise [TypeError] se un argomento ha il tipo sbagliato
      # @raise [ClosedError] se il contenitore è chiuso
      def initialize(parent, max_lines: 1000, channels: 0, size: nil, weight: nil)
        @max_lines = Util.integer!(max_lines, 'max_lines', 1..Util::NONNEG_INT.max)
        @channels = Util.channels_value(channels, 'channels')
        @lines = []
        @partial = ''.b
        attach_component!(parent, size: size, weight: weight)
      end

      # Aggiunge testo e ridisegna.
      #
      # @param data [String] testo o byte grezzi, anche con righe non finite
      # @return [self]
      # @raise [TypeError] se data non è String
      # @raise [ClosedError] se il componente è chiuso
      def append(data)
        to_ptr
        raise TypeError, "data deve essere String, non #{data.class}" unless data.is_a?(String)

        parts = (@partial + data.b).split("\n", -1)
        @partial = parts.pop || ''.b # "".split("\n", -1) è []
        @lines.concat(parts.map { |line| line.delete_suffix("\r") })
        @lines.shift(@lines.size - @max_lines) if @lines.size > @max_lines
        redraw
      end

      # Toglie tutte le righe e ridisegna.
      #
      # @return [self]
      # @raise [ClosedError] se il componente è chiuso
      def clear
        to_ptr
        @lines.clear
        @partial = ''.b
        redraw
      end

      # @return [Array<String>] righe in memoria, con la riga non finita in
      #   fondo se c'è; UTF-8, con i byte non validi sostituiti da U+FFFD
      def lines
        all = @partial.empty? ? @lines : @lines + [@partial]
        all.map { |line| line.dup.force_encoding(Encoding::UTF_8).scrub }
      end

      private

      def draw
        rows = @plane.dim_y
        @plane.set_base(egc: ' ', channels: @channels)
        @plane.channels = @channels
        shown = @partial.empty? ? @lines.last(rows) : @lines.last(rows - 1) << @partial
        shown.each_with_index { |line, y| put_text(y, Text.clean(line)) }
      end
    end
  end
end
