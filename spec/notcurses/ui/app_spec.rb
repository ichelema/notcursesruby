# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative '../../support/nc_helpers'

RSpec.describe Notcurses::UI::App do
  def syn(id, **opts) = Notcurses::Input.synthesize(id, **opts)

  # Componente dell'utente per le prove: registra gli eventi offerti e i
  # disegni; consuma gli eventi se consume è true.
  let(:probe_class) do
    Class.new do
      include Notcurses::UI::Component

      attr_reader :log, :draws
      attr_accessor :consume

      def initialize(parent, focusable: true, consume: false, cursor: nil, size: nil, weight: nil)
        @can_focus = focusable
        @consume = consume
        @cursor_pos = cursor
        @log = []
        @draws = 0
        attach_component!(parent, size: size, weight: weight)
      end

      def focusable? = @can_focus

      def offer_input(input)
        @log << input.id
        @consume
      end

      def cursor = @cursor_pos

      private

      def draw = @draws += 1
    end
  end

  def probe(parent = app.root, **opts) = probe_class.new(parent, **opts)

  context 'con un contesto notcurses' do
    include_context 'con un contesto notcurses'

    let(:app) { described_class.new(nc) }

    after { app.close }

    it 'il primo componente focusabile e visibile prende il focus; focus(nil) lo toglie' do
      label = probe(focusable: false, size: 1)
      expect(app.focused).to be_nil
      a = probe(size: 1)
      b = probe(size: 1)
      expect(app.focused).to equal(a)
      expect(a).to be_focused
      expect(b).not_to be_focused
      expect(label).not_to be_focused
      expect(app.focus(nil)).to equal(app)
      expect(app.focused).to be_nil
      expect(b.focus).to equal(b)
      expect(app.focused).to equal(b)
    end

    it 'il cambio di focus ridisegna il componente che lo perde e quello che lo prende' do
      a = probe(size: 1)
      b = probe(size: 1)
      c = probe(size: 1)
      counts = [a, b, c].map(&:draws)
      app.focus(b)
      expect([a, b, c].map(&:draws)).to eq([counts[0] + 1, counts[1] + 1, counts[2]])
      app.focus(b) # nessun cambio, nessun disegno
      expect(b.draws).to eq(counts[1] + 1)
    end

    it 'focus rifiuta i componenti non focusabili, nascosti, chiusi o di un\'altra App' do
      label = probe(focusable: false, size: 1)
      closed = probe(size: 1)
      closed.close
      other = described_class.new(nc)
      foreign = probe(other.root, size: 1)
      hidden = probe(size: 1)
      hidden.layout(0, 0) # per ultimo: il layout successivo del contenitore lo mostrerebbe di nuovo
      expect { app.focus(label) }.to raise_error(ArgumentError, /focus/)
      expect { app.focus(hidden) }.to raise_error(ArgumentError, /visibile/)
      expect { app.focus(closed) }.to raise_error(Notcurses::ClosedError)
      expect { app.focus(foreign) }.to raise_error(ArgumentError, /altra App/)
      expect { app.focus(:x) }.to raise_error(TypeError)
    ensure
      other&.close
    end

    it 'Tab e Shift+Tab seguono l\'albero in profondità, in modo circolare, saltando i nascosti' do
      a = probe(size: 1)
      box = Notcurses::UI::Container.new(app.root, size: 3)
      b = probe(box, size: 1)
      probe(box, focusable: false, size: 1)
      c = probe(box, size: 1)
      d = probe(size: 1)
      hidden = probe(size: 1)
      hidden.layout(0, 0)
      order = Array.new(5) { app.dispatch(syn(Notcurses::Key::TAB)) && app.focused }
      expect(order).to eq([b, c, d, a, b])
      back = Array.new(3) { app.dispatch(syn(Notcurses::Key::TAB, modifiers: [:shift])) && app.focused }
      expect(back).to eq([a, d, c])
      expect(app.focus_next).to equal(d)
      expect(app.focus_prev).to equal(c)
    end

    it 'Tab con Ctrl o Alt non sposta il focus; senza componenti focusabili Tab va a on_input' do
      a = probe(size: 1)
      probe(size: 1)
      seen = []
      app.on_input { |input| seen << input.id }
      expect(app.dispatch(syn(Notcurses::Key::TAB, modifiers: [:ctrl]))).to be(false)
      expect(app.focused).to equal(a)
      app.root.children.each(&:close)
      expect(app.focused).to be_nil
      expect(app.dispatch(syn(Notcurses::Key::TAB))).to be(false)
      expect(app.focus_next).to be_nil
      expect(seen).to eq([Notcurses::Key::TAB, Notcurses::Key::TAB])
    end

    it 'un tasto va al componente con il focus, poi sale ai contenitori, poi on_key, Tab e on_input' do
      log = []
      grabby = Class.new(Notcurses::UI::Container) do
        attr_accessor :grab, :log

        def offer_input(input)
          @log << [:box, input.id]
          @grab
        end
      end
      box = grabby.new(app.root, size: 3)
      box.log = log
      a = probe(box, size: 1)
      app.on_key('x') { log << :on_key_x }
      app.on_input { |input| log << [:on_input, input.id] }
      expect(app.dispatch(syn('x'.ord))).to be(true)
      expect(a.log).to eq(['x'.ord])
      expect(log).to eq([[:box, 'x'.ord], :on_key_x])
      log.clear
      box.grab = true
      expect(app.dispatch(syn('y'.ord))).to be(true)
      expect(log).to eq([[:box, 'y'.ord]])
      log.clear
      a.consume = true
      app.dispatch(syn('x'.ord))
      expect(log).to eq([])
      log.clear
      a.consume = false
      box.grab = false
      expect(app.dispatch(syn('z'.ord))).to be(false)
      expect(log).to eq([[:box, 'z'.ord], [:on_input, 'z'.ord]])
    end

    it 'i rilasci dei tasti non arrivano ai componenti; on_key ha la precedenza su Tab' do
      a = probe(size: 1)
      b = probe(size: 1)
      released = []
      app.on_input { |input| released << input.id if input.release? }
      app.dispatch(syn('q'.ord, evtype: :release))
      expect(a.log).to eq([])
      expect(released).to eq(['q'.ord])
      app.on_key(Notcurses::Key::TAB) { :mio }
      expect(app.dispatch(syn(Notcurses::Key::TAB))).to be(true)
      expect(app.focused).to equal(a)
      expect(b.log).to eq([])
    end

    it 'mouse: component_at trova il componente sotto il punto, anche dai piani figli; il clic dà il focus' do
      a = probe(size: 2)
      label = probe(focusable: false, size: 2)
      b = probe(size: 2)
      extra = label.plane.create_child(rows: 1, cols: 5, y: 1, x: 3) # piano dell'utente dentro label
      loose = nc.stdplane.create_child(rows: 1, cols: 80, y: 4) # piano fuori dai componenti, sopra b
      expect(app.component_at(0, 0)).to equal(a)
      expect(app.component_at(3, 4)).to equal(label)
      expect(app.component_at(4, 10)).to equal(b) # loose non ferma la ricerca
      expect(app.component_at(23, 0)).to equal(app.root)
      expect(app.component_at(-1, 0)).to be_nil
      expect(app.component_at(24, 0)).to be_nil
      expect { app.component_at(:y, 0) }.to raise_error(TypeError)
      expect(app.dispatch(syn(Notcurses::Key::BUTTON1, y: 5, x: 1))).to be(false)
      expect(app.focused).to equal(b)
      expect(b.log).to eq([Notcurses::Key::BUTTON1])
      app.dispatch(syn(Notcurses::Key::BUTTON1, y: 5, x: 1, evtype: :release))
      app.dispatch(syn(Notcurses::Key::BUTTON1, y: 2, x: 1)) # componente non focusabile: il focus resta
      expect(app.focused).to equal(b)
      expect(label.log).to eq([Notcurses::Key::BUTTON1])
      app.dispatch(syn(Notcurses::Key::BUTTON4, y: 0, x: 1)) # rotella: niente focus
      expect(app.focused).to equal(b)
      app.dispatch(syn(Notcurses::Key::BUTTON1, y: 0, x: 1, evtype: :release)) # rilascio: niente focus
      expect(app.focused).to equal(b)
      expect(a.log).to eq([Notcurses::Key::BUTTON4, Notcurses::Key::BUTTON1])
    ensure
      extra&.close
      loose&.close
    end

    it 'mouse: una pressione con lo stesso tasto già premuto è un drag: va solo a on_input, il focus resta (ICH-283)' do
      a = probe(size: 2)
      b = probe(size: 2)
      seen = []
      app.on_input { |input| seen << [input.id, input.y] }
      app.dispatch(syn(Notcurses::Key::BUTTON1, y: 0, x: 1))
      expect(app.dispatch(syn(Notcurses::Key::BUTTON1, y: 2, x: 1))).to be(false) # drag da a su b
      expect(app.focused).to equal(a)
      expect(b.log).to eq([])
      expect(seen.last).to eq([Notcurses::Key::BUTTON1, 2])
      app.dispatch(syn(Notcurses::Key::BUTTON3, y: 2, x: 1)) # un altro tasto non è un drag
      expect(app.focused).to equal(b)
      expect(b.log).to eq([Notcurses::Key::BUTTON3])
      app.dispatch(syn(Notcurses::Key::BUTTON1, y: 2, x: 1, evtype: :release)) # il rilascio arriva ancora
      expect(b.log).to eq([Notcurses::Key::BUTTON3, Notcurses::Key::BUTTON1])
      app.dispatch(syn(Notcurses::Key::BUTTON3, y: 0, x: 1)) # il rilascio di BUTTON1 lascia premuto BUTTON3
      expect(app.focused).to equal(b)
      app.dispatch(syn(Notcurses::Key::BUTTON1, y: 0, x: 1)) # dopo il rilascio è un clic nuovo
      expect(app.focused).to equal(a)
      # un rilascio perso costa al massimo un clic: la pressione seguente è un drag, il suo rilascio pulisce
      app.dispatch(syn(Notcurses::Key::BUTTON1, y: 2, x: 1))
      expect(app.focused).to equal(a)
      app.dispatch(syn(Notcurses::Key::BUTTON1, y: 2, x: 1, evtype: :release))
      app.dispatch(syn(Notcurses::Key::BUTTON1, y: 2, x: 1))
      expect(app.focused).to equal(b)
    end

    it 'mouse: sulla console Linux (gpm, senza rilasci) ogni pressione arriva ai componenti (ICH-283)' do
      # nome e release del kernel (termdesc.c:940); VTE e un nome con byte non UTF-8 non sono la console
      { 'FBcon 6.12.0' => true, 'VT 7.3.3-1-cachyos' => true, 'VTE 7603' => false,
        "XTerm \xFF".dup.force_encoding(Encoding::UTF_8) => false }.each do |name, console_linux|
        allow(nc).to receive(:detected_terminal).and_return(name)
        console = described_class.new(nc)
        a = probe(console.root, size: 2)
        b = probe(console.root, size: 2)
        console.dispatch(syn(Notcurses::Key::BUTTON1, y: 0, x: 1)) # gpm manda solo pressioni
        console.dispatch(syn(Notcurses::Key::BUTTON1, y: 2, x: 1))
        expect(console.focused).to equal(console_linux ? b : a), name.inspect
        expect(b.log).to eq(console_linux ? [Notcurses::Key::BUTTON1] : []), name.inspect
        console.close
      end
    end

    it 'quando il componente con il focus si nasconde o si chiude, il focus passa al successivo' do
      a = probe(size: 1)
      b = probe(size: 1)
      c = probe(size: 1)
      app.focus(c)
      app.root.layout(2, 80) # c resta senza spazio
      expect(c).not_to be_visible
      expect(app.focused).to equal(a)
      app.root.layout(*nc.dims)
      app.focus(b)
      b.close
      expect(app.focused).to equal(c)
      c.close
      expect(app.focused).to equal(a)
      a.close
      expect(app.focused).to be_nil
    end

    it 'chiudere un contenitore con il focus dentro passa il focus fuori dal contenitore' do
      box = Notcurses::UI::Container.new(app.root, size: 2)
      a = probe(box, size: 1)
      probe(box, size: 1)
      c = probe(size: 1)
      expect(app.focused).to equal(a)
      box.close
      expect(app.focused).to equal(c)
    end

    it 'prima del render mette il cursore dove dice il componente con il focus, solo quando cambia' do
      probe(size: 2)
      a = probe(size: 1, cursor: [0, 3])
      b = probe(size: 1)
      app.focus(a)
      calls = []
      allow(nc).to receive(:cursor_enable).and_wrap_original { |m, **kw| calls << [:enable, kw] && m.call(**kw) }
      allow(nc).to receive(:cursor_disable).and_wrap_original { |m| calls << [:disable] && m.call }
      app.post { app.post { app.focus(b) && app.post { app.stop } } }
      expect(app.run).to eq(:stop) # su /dev/null cursor_disable solleva ContextError: l'App lo ignora
      expect(calls).to eq([[:enable, { y: 2, x: 3 }], [:disable]])
    end

    it 'resize: root prende le nuove dimensioni prima degli handler di on_resize' do
      seen = nil
      app.on_resize do |rows, cols|
        seen = [rows, cols, app.root.plane.dims]
        app.stop
      end
      app.after(0.05) do
        allow(nc).to receive(:refresh).and_return([30, 100])
        Process.kill('WINCH', Process.pid)
      end
      app.after(5) { app.stop }
      expect(app.run).to eq(:stop)
      expect(seen).to eq([30, 100, [30, 100]])
    end

    it 'close chiude tutti i componenti ed è idempotente; dopo, run e i componenti nuovi falliscono' do
      a = probe(size: 1)
      box = Notcurses::UI::Container.new(app.root, size: 2)
      b = probe(box, size: 1)
      root = app.root
      expect(app.close).to be_nil
      expect(app.close).to be_nil
      expect(app).to be_closed
      expect([root, a, box, b]).to all(be_closed)
      expect(app.focused).to be_nil
      expect { app.run }.to raise_error(Notcurses::ClosedError)
      expect { probe(size: 1) }.to raise_error(Notcurses::ClosedError)
      expect { described_class.new(:nc) }.to raise_error(TypeError)
    end

    it 'close dentro run ferma il ciclo alla fine del giro' do
      ran = []
      app.post { app.close }
      app.post { ran << :stesso_giro }
      app.after(5) { ran << :timeout }
      expect(app.run).to eq(:stop)
      expect(ran).to eq([]) # stop non consegna altri eventi
      expect(app).to be_closed
    end
  end

  context 'con un contesto proprio' do
    it 'Context#close chiude l\'App e i suoi componenti' do
      app = nil
      component = nil
      NcHelpers.open_context do |c|
        app = described_class.new(c)
        component = probe_class.new(app.root, size: 1)
      end
      expect(app).to be_closed
      expect(component).to be_closed
      expect { described_class.new(app.context) }.to raise_error(Notcurses::ClosedError)
    end
  end
end
