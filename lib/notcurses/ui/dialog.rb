# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  module UI
    # Finestra modale centrata: titolo, testo a capo sulle parole e una riga
    # di pulsanti. Finché è aperta è la radice attiva dell'{App}: focus, Tab
    # e mouse restano dentro il dialogo (i tasti di {EventLoop#on_key}
    # restano attivi). Un pulsante o Esc chiudono il dialogo e poi chiamano il
    # blocco con l'etichetta del pulsante, o nil per Esc. Alla chiusura il
    # focus torna dove era prima.
    #
    # @example
    #   Notcurses::UI::Dialog.new(app, text: 'Uscire?', buttons: %w[Sì No]) do |choice|
    #     app.stop if choice == 'Sì'
    #   end
    class Dialog < Container
      # @return [String] testo
      attr_reader :text

      # @return [Array<String>] etichette dei pulsanti (frozen)
      attr_reader :buttons

      # @param app [App] applicazione
      # @param text [String] testo; "\n" chiude un paragrafo (le regole di {Label})
      # @param title [String, nil] titolo nel bordo
      # @param buttons [Array<String>] etichette dei pulsanti, almeno una
      # @param channels [Channels, Integer] colori del dialogo e dei pulsanti
      #   senza il focus
      # @yieldparam choice [String, nil] l'etichetta del pulsante, nil per Esc
      # @raise [ArgumentError] con un testo o un'etichetta non ammessi, senza
      #   pulsanti, o se channels ha lo sfondo con alpha :highcontrast
      # @raise [TypeError] se app non è un App, buttons non è un Array di
      #   String, o un argomento ha il tipo sbagliato
      # @raise [ClosedError] se l'App è chiusa
      # @raise [Exception] l'eccezione del disegno: il dialogo è già chiuso e
      #   il focus è tornato dove era
      def initialize(app, text:, title: nil, buttons: ['OK'], channels: 0, &block)
        raise TypeError, "app deve essere Notcurses::UI::App, non #{app.class}" unless app.is_a?(App)

        @text = Text.check!(text, 'text', newlines: true)
        raise TypeError, "buttons deve essere Array, non #{buttons.class}" unless buttons.is_a?(Array)
        raise ArgumentError, 'buttons è vuoto: serve almeno un pulsante' if buttons.empty?

        @buttons = buttons.each_with_index.map { |label, i| Text.check!(label, "buttons[#{i}]") }.freeze
        @block = block
        @body = nil
        super(app, border: true, title: title, channels: channels)
        close_on_error do
          @body = Label.new(self, text: '', align: :center, channels: channels)
          row = Container.new(self, direction: :horizontal, size: 1, channels: channels)
          # i pesi sono le larghezze che place somma: ogni etichetta entra intera
          @buttons.each do |label|
            Button.new(row, label, channels: channels, weight: Notcurses.strwidth(label) + 5) { finish(label) }
          end
          place(*app.context.dims)
        end
      end

      # Esc chiude il dialogo e chiama il blocco con nil.
      #
      # @param input [Input] l'evento
      # @return [Boolean] true per Esc
      # @raise [Exception] l'eccezione del blocco
      def offer_input(input)
        return false unless input.id == Key::ESC && !input.release?

        finish(nil)
        true
      end

      # Chiude il dialogo senza chiamare il blocco; il focus torna dove era
      # prima dell'apertura. Idempotente.
      #
      # @return [nil]
      # @raise [PlaneError] come {Component#close}
      def close
        return nil if @closed

        @app.close_modal(self)
        super
      end

      # Dimensioni e posizione al centro dell'area di rendering: largo quanto
      # serve al testo, al titolo e ai pulsanti, entro rows x cols.
      #
      # @param rows [Integer] righe dell'area di rendering
      # @param cols [Integer] colonne dell'area di rendering
      # @return [self]
      # @api private
      def place(rows, cols)
        text = @text.split("\n").map { |line| Notcurses.strwidth(line) }.max || 0
        buttons = @buttons.sum { |label| Notcurses.strwidth(label) + 5 }
        title = @title ? Notcurses.strwidth(@title) + 2 : 0
        width = ([text, buttons, title].max + 4).clamp(1, cols)
        lines = Text.wrap(@text, [width - 4, 1].max)
        height = (lines.size + 4).clamp(1, rows)
        @body&.text = lines.join("\n")
        plane.move((rows - height) / 2, (cols - width) / 2)
        layout(height, width)
      end

      private

      def finish(choice)
        close
        @block&.call(choice)
      end
    end
  end
end
