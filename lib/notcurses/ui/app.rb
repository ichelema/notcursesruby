# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  module UI
    # Applicazione: un {EventLoop} con i componenti, il focus e le finestre
    # modali.
    #
    # Focus. Un solo componente alla volta, o nessuno. Il primo componente
    # focusabile e visibile che nasce prende il focus se nessuno lo ha.
    # Quando il componente con il focus si chiude o diventa invisibile, il
    # focus passa al successivo. Tab e Shift+Tab seguono l'ordine dell'albero
    # dei componenti (in profondità, nell'ordine di creazione) dalla radice
    # attiva: il {Dialog} in cima, se c'è, altrimenti {#root}.
    #
    # Consegna di un evento ({#dispatch}): un tasto va al componente con il
    # focus, un evento del mouse al componente sotto il puntatore (una
    # pressione di BUTTON1..3 gli dà anche il focus, se è focusabile). Se il
    # componente non lo consuma ({Component#offer_input}), l'evento sale ai
    # contenitori, fino alla radice attiva; poi {#on_key}, Tab e Shift+Tab,
    # infine {#on_input}.
    #
    # Resize: {#root} prende sempre tutta l'area di rendering e i dialoghi si
    # ricentrano, prima degli handler di {#on_resize}.
    #
    # Cursore del terminale: prima di ogni render l'App lo mette dove dice
    # {Component#cursor} del componente con il focus, o lo nasconde.
    #
    # Ciclo di vita: l'App appartiene al contesto, che la chiude con
    # {Context#close}; {#close} chiude i dialoghi e {#root}.
    #
    # Thread: come {EventLoop}, solo dal thread del ciclo (o prima di
    # {#run}); gli altri thread usano {#post}.
    #
    # @example
    #   Notcurses::Context.open do |nc|
    #     app = Notcurses::UI::App.new(nc)
    #     form = Notcurses::UI::Container.new(app.root, border: true, title: 'Accesso')
    #     Notcurses::UI::Label.new(form, text: 'Nome:', size: 1)
    #     name = Notcurses::UI::TextInput.new(form, size: 1)
    #     Notcurses::UI::Button.new(form, 'Entra', size: 3) { app.stop }
    #     app.on_key('x', ctrl: true) { app.stop }
    #     app.run
    #     puts name.text
    #   end
    class App < EventLoop
      MOUSE_FOCUS = [Key::BUTTON1, Key::BUTTON2, Key::BUTTON3].freeze
      private_constant :MOUSE_FOCUS

      # @return [Container] radice dei componenti: un Container verticale
      #   grande quanto l'area di rendering
      attr_reader :root

      # @return [Component, nil] componente con il focus
      attr_reader :focused

      # @param context [Context] contesto aperto
      # @raise [TypeError] se context non è un Context
      # @raise [ClosedError] se il contesto è chiuso
      def initialize(context)
        super
        @components = {} # indirizzo del piano => componente
        @modals = []
        @saved_focus = []
        @focused = nil
        @cursor_at = nil
        @closed = false
        @closing = false
        @root = nil
        context.adopt(self)
        Container.new(self)
      end

      # @return [Boolean] true dopo {#close}, o se il contesto è chiuso
      def closed? = @closed || context.closed?

      # Come {EventLoop#run}, anche per i tasti di controllo.
      #
      # @param no_flow_control [Boolean] disattiva IXON durante run: Ctrl+S e
      #   Ctrl+Q arrivano come tasti
      # @param no_linesigs [Boolean] disattiva ISIG durante run: Ctrl+C,
      #   Ctrl+Z e Ctrl+\ arrivano come tasti
      # @return [Symbol] :stop, :eof o :interrupt
      # @raise [ClosedError] se l'App o il contesto sono chiusi
      # @raise [Error] se il ciclo è già in esecuzione
      # @raise [ContextError] se il terminale rifiuta il cambio di IXON o ISIG
      # @raise [TypeError] se un'opzione non è un Boolean
      # @raise [Exception] l'eccezione di un handler, di un componente, di un
      #   timer o di un blocco di {#post}
      def run(no_flow_control: false, no_linesigs: false)
        raise ClosedError, 'Notcurses::UI::App: applicazione già chiusa' if closed?

        super
      end

      # Chiude i dialoghi aperti e {#root}, con tutti i componenti; durante
      # {#run} ferma anche il ciclo (come {#stop}). Idempotente; la chiama
      # anche {Context#close}.
      #
      # @return [nil]
      # @raise [PlaneError] se notcurses segnala un errore alla distruzione di
      #   un piano (l'App risulta comunque chiusa)
      def close
        return nil if @closed

        stop if running?
        @closing = true
        begin
          @modals.reverse.each(&:close)
          @root&.close
        ensure
          @closed = true
          @focused = nil
          @modals.clear
          @saved_focus.clear
          @components.clear
          context.disown(self)
        end
        nil
      end

      # Dà il focus a un componente (nil = a nessuno) e ridisegna il
      # componente che lo perde e quello che lo prende.
      #
      # @param component [Component, nil]
      # @return [self]
      # @raise [ArgumentError] se il componente è di un'altra App, non è
      #   focusabile, non è visibile o sta fuori dalla finestra modale aperta
      # @raise [TypeError] se component non è un Component né nil
      # @raise [ClosedError] se il componente è chiuso
      def focus(component)
        unless component.nil?
          raise TypeError, "component deve essere Notcurses::UI::Component, non #{component.class}" unless component.is_a?(Component)

          component.to_ptr
          raise ArgumentError, "il componente è di un'altra App" unless component.app.equal?(self)
          raise ArgumentError, "#{component.class.name} non può avere il focus" unless component.focusable?
          raise ArgumentError, 'il componente non è visibile' unless component.visible?
          raise ArgumentError, 'il componente è fuori dalla finestra modale aperta' unless inside?(component, active_root)
        end
        change_focus(component)
        self
      end

      # Passa il focus al componente successivo (Tab), in modo circolare.
      #
      # @return [Component, nil] il componente con il focus; nil se nessun
      #   componente visibile può averlo
      def focus_next = cycle_focus(1)

      # Passa il focus al componente precedente (Shift+Tab), in modo circolare.
      #
      # @return [Component, nil] il componente con il focus; nil se nessun
      #   componente visibile può averlo
      def focus_prev = cycle_focus(-1)

      # Componente sotto un punto: il primo piano dall'alto della pila dello
      # stdplane che contiene il punto e appartiene a un componente visibile
      # della radice attiva (direttamente o con l'antenato più vicino). I
      # piani che non sono di un componente non fermano la ricerca.
      #
      # @param y [Integer] riga dell'area di rendering
      # @param x [Integer] colonna dell'area di rendering
      # @return [Component, nil]
      # @raise [TypeError, ArgumentError] se y o x non sono int del C
      # @raise [ClosedError] se il contesto è chiuso
      def component_at(y, x)
        top = active_root
        plane = context.top
        while plane
          if plane.translate_abs(y, x).last
            component = owner_of(plane)
            return component if component&.visible? && inside?(component, top)
          end
          plane = plane.below
        end
        nil
      end

      # Consegna un evento: al componente con il focus (o sotto il mouse) e
      # ai suoi contenitori, poi {#on_key}, Tab e Shift+Tab, infine
      # {#on_input}.
      #
      # @param input [Input]
      # @return [Boolean] true se un componente, un tasto di {#on_key} o Tab
      #   ha consumato l'evento
      # @raise [TypeError] se input non è un Input
      # @raise [Exception] l'eccezione di un componente o di un handler
      def dispatch(input)
        input!(input)
        return true if offer(input) || key_binding(input) || focus_key(input)

        input_handlers(input)
        false
      end

      # Registra un componente appena creato: la radice, un dialogo o un
      # figlio. Lo chiama {Component} alla creazione.
      #
      # @param component [Component]
      # @return [void]
      # @api private
      def attached(component)
        @components[component.plane.address] = component
        if component.parent
          # un piano nuovo va in cima alla pila: i dialoghi devono restare sopra
          @modals.each { |dialog| dialog.plane.move_family_top } unless @modals.empty? || inside?(component, @modals.last)
        elsif @root.nil?
          @root = component
          component.plane.move(0, 0)
          component.layout(*context.dims)
        else
          @modals << component
          @saved_focus << @focused
          change_focus(nil)
          component.place(*context.dims)
        end
        return unless @focused.nil? && component.focusable? && component.visible? && inside?(component, active_root)

        change_focus(component)
      end

      # Il componente si chiude o si nasconde: se il focus è nel componente
      # (o in un suo discendente), passa al successivo.
      #
      # @param component [Component]
      # @return [void]
      # @api private
      def release_focus(component)
        return unless @focused && inside?(@focused, component)
        return @focused = nil if @closing

        order = focus_candidates(all: true)
        index = order.index(@focused)
        order = order.rotate(index + 1) if index
        change_focus(order.find { |c| c.visible? && !inside?(c, component) })
      end

      # @param component [Component] componente chiuso
      # @return [void]
      # @api private
      def unregister(component)
        @components.delete(component.plane.address)
      end

      # Il dialogo si chiude: il focus torna dove era prima dell'apertura (o
      # al primo componente della nuova radice attiva).
      #
      # @param dialog [Dialog]
      # @return [void]
      # @api private
      def close_modal(dialog)
        index = @modals.index(dialog)
        return unless index

        @modals.delete_at(index)
        saved = @saved_focus.delete_at(index)
        return if @closing || index < @modals.size

        saved = nil unless saved && !saved.closed? && saved.visible? && inside?(saved, active_root)
        change_focus(saved || focus_candidates.first)
      end

      private

      def active_root = @modals.last || @root

      # @return [Boolean] true se component è ancestor o un suo discendente
      def inside?(component, ancestor)
        node = component
        node = node.parent until node.nil? || node.equal?(ancestor)
        !node.nil?
      end

      def owner_of(plane)
        component = nil
        until plane.nil? || (component = @components[plane.address])
          plane = plane.parent
        end
        component
      end

      def change_focus(component)
        return if component.equal?(@focused)

        old = @focused
        @focused = component
        old.redraw if old && !old.closed?
        component&.redraw
      end

      def cycle_focus(step)
        order = focus_candidates
        return nil if order.empty?

        index = order.index(@focused)
        target = if index then order[(index + step) % order.size]
                 else step.positive? ? order.first : order.last
                 end
        change_focus(target)
        target
      end

      # Componenti focusabili della radice attiva, nell'ordine di Tab.
      def focus_candidates(all: false)
        walk(active_root, []).select { |c| c.focusable? && (all || c.visible?) }
      end

      def walk(component, out)
        out << component
        component.children.each { |child| walk(child, out) } if component.is_a?(Container)
        out
      end

      # @return [Boolean] true se un componente ha consumato l'evento
      def offer(input)
        if input.mouse?
          target = component_at(input.y, input.x)
          if target&.focusable? && MOUSE_FOCUS.include?(input.id) && input.press? && !target.equal?(@focused)
            change_focus(target)
          end
        else
          return false if input.release?

          target = @focused
        end
        top = active_root
        while target && !target.closed?
          return true if target.offer_input(input)
          break if target.equal?(top)

          target = target.parent
        end
        false
      end

      # Tab e Shift+Tab, senza Ctrl, Alt e gli altri modificatori.
      def focus_key(input)
        mods = input.modifiers
        return false unless input.id == Key::TAB && !input.release? && mods.nobits?(MOD_CTRL | MOD_ALT | MOD_OTHER)

        !(mods.anybits?(MOD_SHIFT) ? focus_prev : focus_next).nil?
      end

      def resized(rows, cols)
        @root.layout(rows, cols)
        @modals.each { |dialog| dialog.place(rows, cols) }
        super
      end

      def render_frame
        update_cursor
        super
      end

      def update_cursor
        component = @focused
        pos = component&.visible? ? component.cursor : nil
        at = pos && [component.plane.abs_y + pos[0], component.plane.abs_x + pos[1]]
        return if at == @cursor_at

        @cursor_at = at
        at ? context.cursor_enable(y: at[0], x: at[1]) : context.cursor_disable
      rescue ContextError
        nil # senza un tty notcurses non nasconde il cursore (provato su /dev/null)
      end
    end
  end
end
