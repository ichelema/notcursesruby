# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative '../support/nc_helpers'

RSpec.describe Notcurses::Context do
  describe 'ciclo di vita' do
    it 'open con un blocco restituisce il valore del blocco e chiude il contesto' do
      ctx = nil
      result = NcHelpers.open_context do |nc|
        ctx = nc
        expect(Notcurses.active_context).to equal(nc)
        :fatto
      end
      expect(result).to eq(:fatto)
      expect(ctx).to be_closed
      expect(Notcurses.active_context).to be_nil
    end

    it 'open chiude il contesto anche se il blocco solleva' do
      ctx = nil
      expect do
        NcHelpers.open_context do |nc|
          ctx = nc
          raise 'boom'
        end
      end.to raise_error(RuntimeError, 'boom')
      expect(ctx).to be_closed
    end

    it 'rifiuta un secondo contesto e ne accetta uno nuovo dopo la chiusura' do
      first = NcHelpers.open_context
      expect { NcHelpers.open_context }.to raise_error(Notcurses::InitError, /già attivo/)
      first.close
      NcHelpers.open_context { |nc| expect(nc).not_to be_closed }
    end

    it 'un secondo contesto rifiutato non lascia aperto il file di output' do
      NcHelpers.open_context do
        fds = NcHelpers.open_fd_count
        expect { NcHelpers.open_context(output: '/dev/null') }.to raise_error(Notcurses::InitError, /già attivo/)
        expect(NcHelpers.open_fd_count).to eq(fds)
      end
    end

    it 'close è idempotente, stop è un alias, e dopo la chiusura i metodi sollevano ClosedError' do
      nc = NcHelpers.open_context
      plane = nc.stdplane
      expect(nc.close).to be_nil
      expect(nc.stop).to be_nil
      expect(nc).to be_closed
      expect(plane).to be_closed
      expect { nc.render }.to raise_error(Notcurses::ClosedError)
      expect { nc.stdplane }.to raise_error(Notcurses::ClosedError)
      expect { plane.dims }.to raise_error(Notcurses::ClosedError)
      expect(nc.inspect).to include('chiuso').or include('closed')
    end

    it 'con un termtype inesistente solleva InitError e ripristina TERM' do
      before = ENV.fetch('TERM', nil)
      expect { NcHelpers.open_context(termtype: 'terminale-inesistente-xyz') }.to raise_error(Notcurses::InitError)
      expect(ENV.fetch('TERM', nil)).to eq(before)
      expect(Notcurses.active_context).to be_nil
      NcHelpers.open_context { |nc| expect(nc).not_to be_closed }
    end

    it 'valida le opzioni prima di avviare notcurses' do
      expect { NcHelpers.open_context(output: 42) }.to raise_error(TypeError)
      expect { NcHelpers.open_context(output: ::FFI::Pointer::NULL) }.to raise_error(ArgumentError)
      expect { NcHelpers.open_context(output: '/percorso/inesistente/out') }.to raise_error(Notcurses::InitError)
      expect { NcHelpers.open_context(loglevel: :rumoroso) }.to raise_error(ArgumentError)
      expect { NcHelpers.open_context(scrolling: 'si') }.to raise_error(TypeError)
      expect { NcHelpers.open_context(margins: '1,2') }.to raise_error(ArgumentError)
      expect { NcHelpers.open_context(margins: '1', margin_t: 1) }.to raise_error(ArgumentError)
      expect { NcHelpers.open_context(margin_t: -1) }.to raise_error(ArgumentError)
      expect(Notcurses.active_context).to be_nil
    end

    it 'accetta un FILE* del chiamante e non lo chiude' do
      fp = Notcurses::FFI.fopen('/dev/null', 'w')
      NcHelpers.open_context(output: fp, &:render)
      # se il wrapper lo avesse chiuso, questo sarebbe un secondo fclose
      expect(Notcurses::FFI.fclose(fp)).to eq(0)
    end

    it 'applica i margini allo stdplane' do
      NcHelpers.open_context(margins: '1,2,3,4') do |nc|
        expect(nc.stddim).to eq([24 - 1 - 3, 80 - 2 - 4])
        expect(nc.dims).to eq(nc.stddim)
        # refresh e create_pile lavorano sull'area di rendering, non sul terminale
        expect(nc.refresh).to eq(nc.dims)
        root = nc.create_pile(margins: [1, 1, 1, 1])
        expect(root.dims).to eq([18, 72])
        root.close
      end
      # come create_child e create_pile: [alto, destra, basso, sinistra]
      NcHelpers.open_context(margins: [1, 2, 3, 4]) { |nc| expect(nc.stddim).to eq([24 - 1 - 3, 80 - 2 - 4]) }
      expect { NcHelpers.open_context(margins: [1, 2, 3]) }.to raise_error(TypeError, /alto, destra/)
      expect { NcHelpers.open_context(margins: [1, 2, 3, -4]) }.to raise_error(ArgumentError)
      expect { NcHelpers.open_context(margins: [1, 2, 3, 4], margin_l: 1) }.to raise_error(ArgumentError)
      expect { NcHelpers.open_context(margins: 1) }.to raise_error(TypeError)
      expect(Notcurses.active_context).to be_nil
      NcHelpers.open_context(margin_t: 2, margin_l: 5) do |nc|
        expect(nc.stdplane.dims).to eq([22, 75])
      end
    end

    it 'core: true avvia notcurses senza multimedia' do
      NcHelpers.open_context(core: true) { |nc| expect(nc.stdplane.dims).to eq([24, 80]) }
    end

    it 'drain_input? e no_winch_sighandler? riportano le opzioni del contesto' do
      NcHelpers.open_context do |nc|
        expect(nc.drain_input?).to be(true)
        expect(nc.no_winch_sighandler?).to be(true) # default del wrapper
      end
      NcHelpers.open_context(drain_input: false, no_winch_sighandler: false) do |nc|
        expect(nc.drain_input?).to be(false)
        expect(nc.no_winch_sighandler?).to be(false)
        nc.close
        expect { nc.drain_input? }.to raise_error(Notcurses::ClosedError)
        expect { nc.no_winch_sighandler? }.to raise_error(Notcurses::ClosedError)
      end
    end

    # Con il contesto aperto i due metodi toccherebbero il terminale di chi esegue
    # la suite: li prova spec/integration/ui_pty_spec.rb su un pty.
    it 'flow_control_disable, flow_control_enable, linesigs?, isig_enable e isig_disable sollevano ClosedError con il contesto chiuso' do
      NcHelpers.open_context do |nc|
        nc.close
        expect { nc.flow_control_disable }.to raise_error(Notcurses::ClosedError)
        expect { nc.flow_control_enable }.to raise_error(Notcurses::ClosedError)
        expect { nc.linesigs? }.to raise_error(Notcurses::ClosedError)
        expect { nc.isig_enable }.to raise_error(Notcurses::ClosedError)
        expect { nc.isig_disable }.to raise_error(Notcurses::ClosedError)
        expect { nc.linesigs_flag? }.to raise_error(Notcurses::ClosedError)
        expect { nc.held_signal_keys }.to raise_error(Notcurses::ClosedError)
        expect { nc.input_reader_start({}) { false } }.to raise_error(Notcurses::ClosedError)
        expect(nc.input_reader_stop(-> {})).to be_nil # anche chiuso: run lo chiama nel suo ensure
      end
    end
  end

  describe 'con un contesto aperto' do
    include_context 'con un contesto notcurses'

    it 'stdplane è sempre lo stesso oggetto, non posseduto' do
      expect(nc.stdplane).to equal(nc.stdplane)
      expect(nc.stdplane).to be_stdplane
      expect(nc.stdplane).not_to be_owned
      expect(nc.stdplane.close).to be_nil
      expect(nc.stdplane).not_to be_closed
    end

    it 'top e bottom navigano la pila dello stdplane' do
      expect(nc.top).to eq(nc.stdplane)
      expect(nc.bottom).to eq(nc.stdplane)
      nc.stdplane.create_child(rows: 1, cols: 1) do |child|
        expect(nc.top).to equal(child)
        expect(nc.bottom).to eq(nc.stdplane)
      end
    end

    it 'dims e stddim danno le dimensioni dell\'area di rendering' do
      expect(nc.dims).to eq([24, 80])
      expect(nc.stddim).to eq([24, 80])
    end

    it 'render restituisce self, refresh le dimensioni' do
      expect(nc.render).to equal(nc)
      expect(nc.refresh).to eq([24, 80])
    end

    it 'at legge l\'ultimo frame scritto, nil fuori dal frame' do
      Notcurses::FFI.ncplane_putstr_yx(nc.stdplane.to_ptr, 0, 0, 'Ab')
      nc.render
      cell = nc.at(0, 1)
      expect(cell).to be_a(Notcurses::Cell)
      expect(cell.egc).to eq('b')
      expect(cell.egc.encoding).to eq(Encoding::UTF_8)
      expect(nc.at(500, 0)).to be_nil
      expect { nc.at(-1, 0) }.to raise_error(ArgumentError)
      Notcurses::FFI.ncplane_erase(nc.stdplane.to_ptr)
    end

    it 'cursor_enable controlla i limiti; cursor_disable è idempotente' do
      expect(nc.cursor_disable).to equal(nc)
      expect { nc.cursor_enable(y: 24, x: 0) }.to raise_error(ArgumentError)
      expect { nc.cursor_enable(y: 0, x: 80) }.to raise_error(ArgumentError)
      expect(nc.cursor_enable(y: 1, x: 2)).to equal(nc)
      # senza un tty il C non riesce a nascondere il cursore
      expect { nc.cursor_disable }.to raise_error(Notcurses::ContextError)
    end

    it 'cursor_yx restituisce la posizione del rasterizzatore' do
      nc.render
      pos = nc.cursor_yx
      expect(pos).to be_nil.or(match([an_instance_of(Integer), an_instance_of(Integer)]))
    end

    it 'senza tty lo schermo alternativo e il mouse non sono disponibili' do
      expect { nc.enter_alternate_screen }.to raise_error(Notcurses::ContextError)
      expect { nc.leave_alternate_screen }.to raise_error(Notcurses::ContextError)
      expect { nc.mice_enable }.to raise_error(Notcurses::ContextError)
      expect { nc.mice_enable(events: :clic) }.to raise_error(ArgumentError)
      expect(nc.mice_disable).to equal(nc)
    end

    it 'linesigs_disable e linesigs_enable restituiscono self' do
      expect(nc.linesigs_disable).to equal(nc)
      expect(nc.linesigs_enable).to equal(nc)
    end

    it 'isig_enable restituisce self; senza ISIG noto solleva ContextError' do
      expect(nc.isig_enable).to equal(nc)
      stub_const('Notcurses::FFI::ISIG', nil)
      expect { nc.isig_enable }.to raise_error(Notcurses::ContextError, /ISIG non noto/)
    end

    it 'isig_disable restituisce self; senza ISIG noto solleva ContextError' do
      allow(nc).to receive(:input_tty).and_return(false) # niente terminale: non tocca quello di chi esegue i test
      expect(nc.isig_disable).to equal(nc)
      stub_const('Notcurses::FFI::ISIG', nil)
      expect { nc.isig_disable }.to raise_error(Notcurses::ContextError, /ISIG non noto/)
    end

    # Con stdin su /dev/null legge ISIG da /dev/tty; senza terminale di
    # controllo (CI, shell senza tty) restituisce false invece di sollevare.
    it 'linesigs? senza tty su stdin restituisce un Boolean' do
      expect([true, false]).to include(nc.linesigs?)
    end

    it 'linesigs? con STDIN chiuso non solleva IOError: legge /dev/tty, se c\'è' do
      allow(STDIN).to receive(:closed?).and_return(true)
      allow(STDIN).to receive(:tty?).and_raise(IOError, 'closed stream')
      expect([true, false]).to include(nc.linesigs?)
    end

    it 'con drain_input l\'input solleva InputError' do
      expect { nc.get(timeout: 0) }.to raise_error(Notcurses::InputError)
      expect { nc.getvec(2, timeout: 0) }.to raise_error(Notcurses::InputError)
      expect { nc.getvec(0) }.to raise_error(ArgumentError)
      expect { nc.get(timeout: -1) }.to raise_error(ArgumentError)
      # oltre il massimo: ArgumentError prima di ogni attesa (IO#wait_readable solleverebbe RangeError)
      expect { nc.get(timeout: 1e19) }.to raise_error(ArgumentError, /0\.0\.\.2147483647\.0/)
      expect { nc.get(timeout: Float::MAX) }.to raise_error(ArgumentError)
      expect { nc.getvec(2, timeout: 1e19) }.to raise_error(ArgumentError)
      expect(nc.inputready_fd).to be >= 0
    end

    it 'getvec legge più blocchi da 8192 slot finché un blocco non è pieno o count è raggiunto' do
      counts = []
      allow(Notcurses::FFI).to receive(:notcurses_getvec) do |_nc, _deadline, _buf, count|
        counts << count
        counts.size == 1 ? count : 5 # il primo blocco torna pieno, il secondo no: coda vuota
      end
      expect(nc.getvec(10_000, timeout: 0).size).to eq(8197)
      expect(counts).to eq([8192, 1808])
      counts.clear
      expect(nc.getvec(8192, timeout: 0).size).to eq(8192) # count raggiunto: nessun altro blocco
      expect(counts).to eq([8192])
    end

    it 'getvec non chiama il C su un contesto chiuso tra due blocchi (close da un gestore trap)' do
      counts = []
      allow(Notcurses::FFI).to receive(:notcurses_getvec) do |_nc, _deadline, _buf, count|
        counts << count
        count # blocco pieno: getvec ne chiede un altro
      end
      reads = 0
      allow(nc).to receive(:to_ptr).and_wrap_original do |original|
        raise Notcurses::ClosedError, 'contesto chiuso' if (reads += 1) > 1

        original.call
      end
      expect { nc.getvec(10_000, timeout: 0) }.to raise_error(Notcurses::ClosedError)
      expect(counts).to eq([8192])
    end

    it 'espone le capacità del terminale' do
      %i[can_truecolor? can_change_color? can_fade? can_utf8? can_halfblock? can_quadrant? can_sextant?
         can_octant? can_braille? can_pixel? can_open_images? can_open_videos?].each do |m|
        expect(nc.public_send(m)).to be(true).or be(false)
      end
      expect(nc.can_truecolor?).to be(true)
      expect(nc.supported_styles).to include(:bold, :italic)
      expect(nc.palette_size).to eq(256)
      expect(nc.detected_terminal).to be_a(String)
      expect(nc.pixel_support).to eq(:none)
      expect(nc.default_foreground).to be_nil
      expect(nc.default_background).to be_nil
    end

    it 'capabilities è un value object congelato' do
      caps = nc.capabilities
      expect(caps).to be_frozen
      expect(caps.colors).to eq(256)
      expect(caps.rgb?).to be(true)
      %i[utf8? can_change_colors? can_change_color? halfblocks? quadrants? sextants? octants? braille?].each do |m|
        expect(caps.public_send(m)).to be(true).or be(false)
      end
    end

    it 'palette, stats, reset_stats e debug' do
      pal = nc.palette
      expect(pal).to be_a(Notcurses::Palette)
      pal.close
      nc.render
      stats = nc.stats
      expect(stats).to be_a(Notcurses::Stats)
      expect(stats.renders).to be >= 1
      before = nc.reset_stats
      expect(before.renders).to eq(stats.renders)
      expect(nc.stats.renders).to eq(0)
      expect(nc.stats.render_min_ns).to be_nil
      expect(nc.debug).to include('std')
    end

    it 'create_pile crea la radice di una nuova pila' do
      nc.create_pile(rows: 2, cols: 3, y: 1, x: 1, name: 'pila') do |root|
        expect(root).to be_root
        expect(root.dims).to eq([2, 3])
        expect(root.name).to eq('pila')
        expect(root.pile_top).to equal(root)
        expect(nc.top).not_to eq(root)
      end
      expect { nc.create_pile(rows: 1, cols: 1, x: :center) }.to raise_error(ArgumentError)
      expect { nc.create_pile(rows: 0, cols: 1) }.to raise_error(ArgumentError)
      root = nc.create_pile(margins: [1, 2, 3, 4])
      expect(root.dims).to eq([20, 74])
      expect(root.yx).to eq([1, 4])
      root.close
    end

    it 'drop_planes distrugge tutti i piani tranne lo stdplane, anche le pile di più piani' do
      child = nc.stdplane.create_child(rows: 1, cols: 1)
      root = nc.create_pile(rows: 3, cols: 3)
      grandchild = root.create_child(rows: 1, cols: 1)
      borrowed = nc.top
      expect(nc.drop_planes).to equal(nc)
      expect([child, root, grandchild, borrowed]).to all(be_closed)
      expect(nc.stdplane).not_to be_closed
      expect(nc.top).to eq(nc.stdplane)
      # una seconda chiamata e lo stop non devono fare double free (bug di 3.0.17)
      nc.drop_planes
      nc.render
    end

    # un close nel callback invece è rinviato alla fine dell'operazione (spec/integration/close_guard_spec.rb)
    it 'un callback di resize non può distruggere piani' do
      parent = nc.stdplane.create_child(rows: 4, cols: 4)
      victim = parent.create_child(rows: 1, cols: 1)
      parent.create_child(rows: 1, cols: 1, resize: ->(_p) { nc.drop_planes })
      expect { parent.resize(6, 6) }.to raise_error(Notcurses::ContextError, /callback/)
      expect(victim).not_to be_closed
      parent.family_destroy
    end
  end

  describe 'input da stdin chiuso' do
    before(:all) { @nc = NcHelpers.open_context(drain_input: false) }
    after(:all) { @nc&.close }

    it 'get restituisce un evento EOF e getvec si ferma al primo EOF' do
      ev = @nc.get(timeout: 2)
      expect(ev).to be_a(Notcurses::Input)
      expect(ev.id).to eq(Notcurses::Key::EOF)
      evs = @nc.getvec(5, timeout: 2)
      expect(evs.size).to eq(1)
      expect(evs.first.id).to eq(Notcurses::Key::EOF)
      expect(@nc.get(timeout: (2**31) - 1).id).to eq(Notcurses::Key::EOF) # il timeout massimo è valido
    end

    it 'getvec passa al C al massimo 8192 slot, la dimensione della coda di notcurses' do
      # L'EOF arriva in coda dal thread di input di notcurses. Se l'esempio è il primo del gruppo, la coda
      # può essere ancora vuota: il primo notcurses_getvec restituisce 0 e il wrapper ripete la chiamata.
      expect(@nc.get(timeout: 2).id).to eq(Notcurses::Key::EOF)
      allow(Notcurses::FFI).to receive(:notcurses_getvec).and_call_original
      expect(@nc.getvec(1_000_000, timeout: 1).map(&:id)).to eq([Notcurses::Key::EOF])
      expect(Notcurses::FFI).to have_received(:notcurses_getvec).with(anything, anything, anything, 8192)
      expect(@nc.getvec(5, timeout: 1).size).to eq(1)
      expect(Notcurses::FFI).to have_received(:notcurses_getvec).with(anything, anything, anything, 5)
      # senza il limite il buffer sarebbe di 104 GiB (NoMemoryError)
      expect(@nc.getvec((2**31) - 1, timeout: 1).map(&:id)).to eq([Notcurses::Key::EOF])
      expect(Notcurses::FFI).not_to have_received(:notcurses_getvec).with(anything, anything, anything, be > 8192)
    end
  end

  describe '.align' do
    it 'calcola l\'offset di allineamento' do
      expect(Notcurses.align(10, :left, 4)).to eq(0)
      expect(Notcurses.align(10, :center, 4)).to eq(3)
      expect(Notcurses.align(10, :right, 4)).to eq(6)
      expect(Notcurses.align(10, :bottom, 4)).to eq(6)
      expect(Notcurses.align(4, :right, 10)).to eq(-6)
      expect { Notcurses.align(10, :unaligned, 4) }.to raise_error(ArgumentError)
      expect { Notcurses.align(10, :middle, 4) }.to raise_error(ArgumentError)
      expect { Notcurses.align(2**31, :left, 4) }.to raise_error(ArgumentError)
    end
  end
end
