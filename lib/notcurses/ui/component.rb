# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  module UI
    # Colori dei componenti con il focus (e della voce scelta di un
    # {ListView} con il focus): bianco su blu, leggibili su un terminale
    # chiaro e su uno scuro.
    FOCUSED_CHANNELS = Channels.rgb(0xff, 0xff, 0xff, 0x00, 0x5f, 0xaf)

    # Colori di un {TextInput} senza il focus: nero su grigio chiaro, così il
    # campo si vede anche vuoto.
    FIELD_CHANNELS = Channels.rgb(0x00, 0x00, 0x00, 0xbc, 0xbc, 0xbc)

    # Testo dei componenti: controllo, taglio, a capo e pulizia.
    # @api private
    module Text
      # Gli stessi candidati di Plane#putstr: caratteri che notcurses può
      # scrivere come EGC di larghezza zero.
      ZERO_WIDTH = /[\p{Mn}\p{Me}\p{Cf}ᅠ-ᇿힰ-퟿]/

      module_function

      # Controlla il testo di un componente con le regole di {Plane#putstr}
      # che Ruby vede da solo, così un errore esce alla creazione e non a un
      # layout successivo.
      #
      # @param text [String] testo
      # @param name [String] nome usato nel messaggio d'errore
      # @param newlines [Boolean] true = "\n" ammesso (separa le righe)
      # @return [String] copia UTF-8 frozen
      # @raise [TypeError] se text non è String
      # @raise [ArgumentError] se text non è UTF-8 valido o contiene NUL, TAB,
      #   "\n" (senza newlines), un altro carattere di controllo, U+2028,
      #   U+2029 o un carattere di larghezza zero isolato
      def check!(text, name, newlines: false)
        str = Util.string!(text, name)
        raise ArgumentError, "#{name} contiene un TAB: espandilo prima (per esempio con String#gsub)" if str.include?("\t")
        raise ArgumentError, "#{name} contiene un a capo" if !newlines && str.include?("\n")
        raise ArgumentError, "#{name} contiene un carattere di controllo" if str.match?(/(?!\n)\p{Cc}/)
        raise ArgumentError, "#{name} contiene U+2028 o U+2029, che notcurses tronca a un byte" if str.match?(/[  ]/)
        if str.match?(ZERO_WIDTH) && str.each_grapheme_cluster.any? { |g| zero_width?(g) }
          raise ArgumentError, "#{name} contiene un carattere di larghezza zero isolato"
        end

        -str
      end

      # @param grapheme [String] un grapheme cluster
      # @return [Boolean] true se notcurses lo misura largo 0 colonne
      def zero_width?(grapheme) = grapheme.match?(ZERO_WIDTH) && Notcurses.strwidth(grapheme).zero?

      # Il prefisso più lungo di str che entra in cols colonne, senza
      # spezzare un grapheme cluster.
      #
      # @param str [String] testo senza caratteri di controllo
      # @param cols [Integer] colonne disponibili
      # @return [String]
      def truncate(str, cols)
        return '' unless cols.positive?
        return str[0, cols] if str.ascii_only?
        return str if Notcurses.strwidth(str) <= cols

        width = 0
        out = +''
        str.each_grapheme_cluster do |g|
          width += Notcurses.strwidth(g)
          break if width > cols

          out << g
        end
        out
      end

      # Righe del testo a capo sulle parole per cols colonne: "\n" chiude un
      # paragrafo, gli spazi fra le parole diventano uno, una parola più larga
      # di cols va a capo dove serve.
      #
      # @param str [String] testo senza caratteri di controllo, tranne "\n"
      # @param cols [Integer] colonne, >= 1
      # @return [Array<String>]
      def wrap(str, cols)
        str.split("\n", -1).flat_map do |paragraph|
          lines = [+'']
          width = 0
          paragraph.split(' ').each do |word|
            wlen = Notcurses.strwidth(word)
            if width.positive? && width + 1 + wlen <= cols
              lines.last << ' ' << word
              width += 1 + wlen
              next
            end
            lines << +'' if width.positive?
            width = 0
            word.each_grapheme_cluster do |g|
              gw = Notcurses.strwidth(g)
              if width.positive? && width + gw > cols
                lines << +''
                width = 0
              end
              lines.last << g
              width += gw
            end
          end
          lines
        end
      end

      # Una riga di byte qualsiasi resa scrivibile: UTF-8 non valido,
      # caratteri di controllo, U+2028, U+2029 e caratteri di larghezza zero
      # isolati diventano "?"; TAB diventa spazi fino alla colonna multipla
      # di 8.
      #
      # @param bytes [String] riga senza "\n", in qualsiasi codifica
      # @return [String] UTF-8
      def clean(bytes)
        str = bytes.dup.force_encoding(Encoding::UTF_8).scrub('?')
        str.gsub!(/(?!\t)[\p{Cc}  ]/, '?')
        str = expand_tabs(str) if str.include?("\t")
        return str unless str.match?(ZERO_WIDTH)

        str.each_grapheme_cluster.map { |g| zero_width?(g) ? '?' : g }.join
      end

      # @param str [String] testo senza caratteri di controllo tranne TAB
      # @return [String] str con i TAB espansi (tabulazioni ogni 8 colonne)
      def expand_tabs(str)
        col = 0
        str.split(/(\t)/).map do |part|
          if part == "\t"
            n = 8 - (col % 8)
            col += n
            ' ' * n
          else
            col += Notcurses.strwidth(part)
            part
          end
        end.join
      end
    end
    private_constant :Text

    # Protocollo dei componenti di un'{App}: i widget composti ({Container},
    # {Label}, {Button}, {TextInput}, {ListView}, {LogView}, {Dialog}) e i
    # componenti scritti dall'utente.
    #
    # Ogni componente ha un piano proprio, figlio del piano del contenitore
    # (dello stdplane per {App#root} e per un {Dialog}). Il contenitore decide
    # posizione e dimensioni con {#layout}; a ogni layout il componente
    # ridisegna tutto dal proprio stato ({#redraw}), così non dipende dal
    # contenuto del piano dopo un resize. Con 0 righe o 0 colonne il
    # componente è nascosto: il piano diventa 1x1 fuori dallo schermo, e Tab e
    # mouse lo saltano.
    #
    # Ciclo di vita: {#close} chiude i figli, toglie il componente dal
    # contenitore (che rifà il layout) e dall'App, poi chiude il piano.
    # {App#close} (anche da {Context#close}) chiude tutti i componenti.
    #
    # Thread: come {App}, solo dal thread del ciclo.
    #
    # Per scrivere un componente: la classe include il modulo, alla fine di
    # +initialize+ chiama +attach_component!(parent, size:, weight:)+ e
    # implementa il metodo privato +draw+, che disegna su {#plane} (già
    # cancellato). Se +draw+ solleva durante la creazione, il componente si
    # chiude e +new+ propaga l'eccezione. Un componente focusabile
    # ridefinisce {#focusable?} e {#offer_input}, e disegna lo stato del
    # focus da {#focused?}.
    #
    # @example Un orologio
    #   class Clock
    #     include Notcurses::UI::Component
    #
    #     def initialize(parent, size: 1)
    #       attach_component!(parent, size: size, weight: nil)
    #     end
    #
    #     private
    #
    #     def draw = plane.putstr(Time.now.strftime('%T')[0, plane.dim_x], y: 0, x: 0)
    #   end
    #   clock = Clock.new(app.root)
    #   app.every(1) { clock.redraw }
    module Component
      include Resource

      # Posizione dei piani nascosti, fuori dallo schermo.
      OFFSCREEN = -65_536
      private_constant :OFFSCREEN

      # @return [App]
      attr_reader :app

      # @return [Container, nil] contenitore; nil per {App#root} e {Dialog}
      attr_reader :parent

      # @return [Integer, nil] dimensione fissa lungo l'asse del contenitore,
      #   o nil (si usa il peso)
      # @api private
      attr_reader :layout_size

      # @return [Integer] quota dello spazio che resta dopo le dimensioni fisse
      # @api private
      attr_reader :layout_weight

      # @return [Context]
      def context = @app.context

      # @return [Plane] piano del componente
      # @raise [ClosedError] se il componente è chiuso
      def plane
        to_ptr
        @plane
      end

      # Gestisce un evento. {App} lo offre al componente con il focus (al
      # componente sotto il mouse per il mouse), poi ai contenitori sopra di
      # lui, fino a quando uno lo consuma. I rilasci dei tasti non arrivano ai
      # componenti; quelli del mouse sì.
      #
      # @param input [Input] l'evento
      # @return [Boolean] true se il componente consuma l'evento (default false)
      def offer_input(input) # rubocop:disable Lint/UnusedMethodArgument
        false
      end

      # @return [Boolean] true se il componente può avere il focus (default false)
      def focusable? = false

      # @return [Boolean] true se il componente ha il focus
      def focused? = !closed? && @app.focused.equal?(self)

      # Chiede il focus ad {App#focus}.
      #
      # @return [self]
      # @raise [ArgumentError] come {App#focus}
      # @raise [ClosedError] se il componente è chiuso
      def focus
        @app.focus(self)
        self
      end

      # @return [Boolean] false se il componente è chiuso, o se il contenitore
      #   (o un suo antenato) non gli ha dato spazio
      def visible?
        return false if closed? || !@visible

        @parent.nil? || @parent.visible?
      end

      # Dà al componente le sue dimensioni e lo ridisegna. Lo chiama il
      # contenitore, che prima sposta il piano. Con 0 righe o 0 colonne
      # nasconde il componente (e il focus passa al successivo).
      #
      # @param rows [Integer] righe, >= 0
      # @param cols [Integer] colonne, >= 0
      # @return [self]
      # @raise [TypeError, ArgumentError] se rows o cols non sono interi >= 0
      # @raise [ClosedError] se il componente è chiuso
      # @raise [Exception] l'eccezione del disegno
      def layout(rows, cols)
        to_ptr
        Util.nonneg_int!(rows, 'rows')
        Util.nonneg_int!(cols, 'cols')
        if rows.zero? || cols.zero?
          @visible = false
          @plane.resize(1, 1) unless @plane.dims == [1, 1]
          @plane.move(OFFSCREEN, OFFSCREEN)
          @app.release_focus(self)
        else
          @visible = true
          @plane.resize(rows, cols) unless @plane.dims == [rows, cols]
          redraw
        end
        self
      end

      # Cancella il piano e lo ridisegna dallo stato del componente. Su un
      # componente nascosto non fa nulla.
      #
      # @return [self]
      # @raise [ClosedError] se il componente è chiuso
      # @raise [Exception] l'eccezione del disegno
      def redraw
        to_ptr
        return self unless @visible

        @plane.erase
        draw
        self
      end

      # Posizione del cursore del terminale quando il componente ha il focus.
      #
      # @return [Array(Integer, Integer), nil] [riga, colonna] nel piano del
      #   componente, o nil (cursore nascosto; default)
      def cursor = nil

      # Chiude il componente: i figli, poi il piano. Il focus passa al
      # componente successivo; il contenitore rifà il layout. Idempotente.
      #
      # @return [nil]
      # @raise [PlaneError] se notcurses segnala un errore alla distruzione
      #   del piano (il componente risulta comunque chiuso)
      def close
        return nil if @closed

        begin
          @app.release_focus(self)
          close_parts
          @parent&.remove_child(self)
          @app.unregister(self)
        ensure
          @closed = true
          @plane.close
        end
        nil
      end

      private

      # Crea il piano del componente e lo aggiunge al contenitore, che rifà
      # il layout. Va chiamato alla fine di initialize.
      #
      # @param parent [Container, App] contenitore; un'App solo per
      #   {App#root} e per un {Dialog}
      # @param size [Integer, nil] dimensione fissa lungo l'asse del
      #   contenitore (righe in un contenitore verticale, colonne in uno
      #   orizzontale), >= 1
      # @param weight [Integer, nil] quota dello spazio restante, >= 1
      #   (default 1)
      # @return [void]
      # @raise [ArgumentError] con size e weight insieme, o con un'App che ha
      #   già la radice per un componente che non è un Dialog
      # @raise [TypeError] se parent non è un Container o un'App
      # @raise [ClosedError] se il contenitore o l'App sono chiusi
      # @raise [Exception] l'eccezione del disegno: il componente è già chiuso
      def attach_component!(parent, size:, weight:)
        raise ArgumentError, 'usa size: oppure weight:, non entrambi' if size && weight

        @layout_size = size && Util.integer!(size, 'size', 1..Util::NONNEG_INT.max)
        @layout_weight = weight.nil? ? 1 : Util.integer!(weight, 'weight', 1..Util::NONNEG_INT.max)
        case parent
        when Container
          host = parent.plane
          @app = parent.app
          @parent = parent
        when App
          raise ClosedError, 'Notcurses::UI::App: applicazione già chiusa' if parent.closed?
          unless parent.root.nil? || is_a?(Dialog)
            raise ArgumentError, "#{self.class.name}: sopra l'App stanno solo root e i Dialog (usa app.root)"
          end

          host = parent.context.stdplane
          @app = parent
          @parent = nil
        else raise TypeError, "parent deve essere Notcurses::UI::Container o App, non #{parent.class}"
        end
        @plane = host.create_child(rows: 1, cols: 1, y: OFFSCREEN, x: OFFSCREEN)
        @plane.set_base(egc: ' ') # opaco: un Dialog copre quello che sta sotto
        @ptr = @plane.to_ptr
        @closed = false
        @visible = false
        close_on_error do
          @parent&.add_child(self)
          @app.attached(self)
        end
      end

      # Esegue il blocco; se il blocco solleva, chiude il componente (che
      # esce dal contenitore e dall'App) e propaga l'eccezione originale,
      # anche se la chiusura fallisce.
      # @return [void]
      def close_on_error
        yield
      rescue Exception => e # rubocop:disable Lint/RescueException
        begin
          close
        rescue StandardError
          nil # conta l'errore della creazione, non quello della pulizia
        end
        raise e
      end

      # Disegno del componente sul piano già cancellato.
      # @return [void]
      def draw; end

      # Chiude le parti del componente prima del piano (i figli di un Container).
      # @return [void]
      def close_parts; end

      # Scrive str nella riga y, dalla colonna x, tagliato a cols colonne e
      # allineato in quello spazio, con stile e colori attuali del piano.
      def put_text(y, str, x: 0, cols: @plane.dim_x - x, align: :left)
        line = Text.truncate(str, cols)
        return if line.empty?

        unless align == :left
          gap = cols - Notcurses.strwidth(line)
          x += align == :center ? gap / 2 : gap
        end
        @plane.putstr(line, y: y, x: x)
      rescue ArgumentError
        raise if line.nil? || line.ascii_only?

        # ponytail: i grapheme che notcurses 3.0.17 divide diversamente da Ruby (il keycap "1️⃣") diventano "?";
        # controllo esatto alla creazione se Plane esporrà il suo
        @plane.move_cursor(y, x)
        line.each_grapheme_cluster do |g|
          @plane.putstr(g)
        rescue ArgumentError
          @plane.putstr('?' * Notcurses.strwidth(g))
        end
      end
    end
  end
end
