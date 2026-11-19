# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require "rbconfig"

# Chiusura di Context, Direct e Visual mentre un'operazione del wrapper è in
# corso: da un gestore trap che torna al codice interrotto (ICH-464) o da un
# altro thread durante una chiamata C senza GVL (ICH-475). Ogni scenario gira
# in un processo figlio con un timeout. Gli hook sul modulo FFI aprono la
# finestra esatta e controllano l'ordine: una funzione C chiamata con un
# puntatore già passato al suo distruttore fa uscire il figlio con 6, anche
# quando l'use-after-free non andrebbe in crash.
RSpec.describe "Chiusura durante un'operazione in corso (integrazione)" do
  def lib_dir = File.expand_path("../../lib", __dir__)
  def mkv_path = File.expand_path("../fixtures/visual/frames.mkv", __dir__)

  # Esegue script in un processo Ruby figlio e lo uccide dopo timeout secondi.
  # MALLOC_PERTURB_ riempie la memoria liberata: un use-after-free sfuggito
  # agli hook va più spesso in crash.
  # @return [Array(String, Process::Status, Boolean)] output, stato, true se scaduto
  def run_child(script, timeout: 20)
    reader, writer = IO.pipe
    env = {"TERM" => "xterm-256color", "MALLOC_PERTURB_" => "165"}
    pid = spawn(env, RbConfig.ruby, "-I", lib_dir, "-e", script, in: File::NULL, out: writer, err: writer)
    writer.close
    output = Thread.new { reader.read } # rubocop:disable ThreadSafety/NewThread -- legge l'output del figlio
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until (done = Process.wait2(pid, Process::WNOHANG))
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        Process.kill(:KILL, pid)
        return [output.value, Process.wait2(pid).last, true]
      end
      sleep 0.05
    end
    [output.value, done.last, false]
  ensure
    reader&.close
  end

  def expect_exit(script, status: 0, timeout: 20)
    output, st, timed_out = run_child(script, timeout: timeout)
    expect(timed_out).to be(false), "il figlio non è terminato in #{timeout} s:\n#{output}"
    expect(st.signaled?).to be(false), "il figlio è morto per il segnale #{st.termsig}:\n#{output}"
    expect(st.exitstatus).to eq(status), "stato di uscita #{st.exitstatus}:\n#{output}"
    output
  end

  # Inizio comune: $freed segna le radici e i visual passati al distruttore;
  # use! fa uscire subito il figlio con 6 se il puntatore è già stato liberato.
  # $stops conta gli stop delle radici.
  def prelude = <<~RUBY
    require 'notcurses'
    $stdout.sync = true
    $freed = {}
    $stops = 0
    def use!(*ptrs, what)
      ptrs.each do |p|
        next unless p.is_a?(::FFI::Pointer) && $freed[p.address]

        warn "use-after-free: \#{what}"
        exit!(6)
      end
    end
    Notcurses::FFI.singleton_class.prepend(Module.new do
      def notcurses_stop(nc) = ($stops += 1; $freed[nc.address] = true; super)
      def ncdirect_stop(n) = ($stops += 1; $freed[n.address] = true; super)
      def ncvisual_destroy(v) = (use!(v, :ncvisual_destroy); $freed[v.address] = true; super)
      # malloc può riusare l'indirizzo di un oggetto liberato
      def notcurses_init(*) = super.tap { |p| $freed.delete(p.address) }
      def ncdirect_init(*) = super.tap { |p| $freed.delete(p.address) }
      def ncvisual_from_file(*) = super.tap { |p| $freed.delete(p.address) }
    end)
    OPTS = { output: '/dev/null', termtype: 'xterm-256color' }.freeze
    CTX_OPTS = { **OPTS, suppress_banners: true, drain_input: true }.freeze
    MKV = #{mkv_path.inspect}
  RUBY

  describe "gestore trap che chiude e torna al codice interrotto (ICH-464)" do
    it "Context#render: 200 chiusure in tre finestre, sempre ClosedError e nessun uso del contesto liberato" do
      expect_exit(<<~RUBY, timeout: 60)
        #{prelude}
        $armed = nil
        $fired = 0
        def fire(where)
          return unless $armed == where

          $armed = nil
          Process.kill('USR1', Process.pid) # il gestore gira prima del ritorno di kill
        end
        Notcurses::FFI.singleton_class.prepend(Module.new do
          def notcurses_stdplane(nc) = (fire(:before); use!(nc, :notcurses_stdplane); super)
          def ncpile_render(n) = super.tap { fire(:between) }
          def ncpile_rasterize(n) = (use!($nc_ptr, :ncpile_rasterize); super.tap { fire(:after) })
        end)
        nc = nil
        trap('USR1') { $fired += 1; nc.close }
        ok = 0
        200.times do |i|
          nc = Notcurses::Context.new(**CTX_OPTS)
          $nc_ptr = nc.to_ptr
          nc.stdplane.putstr('x')
          $armed = %i[before between after][i % 3]
          begin
            nc.render
            nc.render
          rescue Notcurses::ClosedError
            ok += 1 if nc.closed? && Notcurses.active_context.nil?
          end
        end
        warn "ok=\#{ok} fired=\#{$fired} stops=\#{$stops}"
        exit(ok == 200 && $fired == 200 && $stops == 200 ? 0 : 4)
      RUBY
    end

    it "Direct#putstr: un close fra to_ptr e la chiamata C rinvia lo stop" do
      expect_exit(<<~RUBY)
        #{prelude}
        $armed = true
        Notcurses::FFI.singleton_class.prepend(Module.new do
          def ncdirect_putstr(n, *rest)
            Process.kill('USR1', Process.pid) if $armed
            $armed = false
            use!(n, :ncdirect_putstr)
            super
          end
        end)
        d = Notcurses::Direct.new(**OPTS)
        trap('USR1') { d.close }
        begin
          d.putstr('x')
          d.putstr('y')
          exit 3
        rescue Notcurses::ClosedError
          exit(d.closed? && Notcurses.active_context.nil? && $stops == 1 ? 0 : 4)
        end
      RUBY
    end

    it "Plane#dims: un close fra to_ptr e la chiamata C rinvia lo stop" do
      expect_exit(<<~RUBY)
        #{prelude}
        $armed = false
        Notcurses::FFI.singleton_class.prepend(Module.new do
          def ncplane_dim_yx(n, *rest)
            Process.kill('USR1', Process.pid) if $armed
            $armed = false
            use!($nc_ptr, :ncplane_dim_yx)
            super
          end
        end)
        nc = Notcurses::Context.new(**CTX_OPTS)
        $nc_ptr = nc.to_ptr
        plane = nc.stdplane.create_child(rows: 2, cols: 3)
        trap('USR1') { nc.close }
        $armed = true
        begin
          dims = plane.dims
          plane.dims
          exit 3
        rescue Notcurses::ClosedError
          exit(dims == [2, 3] && plane.closed? && Notcurses.active_context.nil? && $stops == 1 ? 0 : 4)
        end
      RUBY
    end

    %w[get getvec direct_get].each do |mode|
      it "#{mode}: un close durante l'attesa di un tasto dà ClosedError" do
        expect_exit(<<~RUBY)
          #{prelude}
          keep_open, _w = IO.pipe # stdin aperto e vuoto: nessun evento, nessun EOF
          STDIN.reopen(keep_open)
          root = #{(mode == "direct_get") ? "Notcurses::Direct.new(**OPTS)" : "Notcurses::Context.new(**OPTS, suppress_banners: true)"}
          trap('USR1') { root.close }
          Thread.new { sleep 0.3; Process.kill('USR1', Process.pid) }
          begin
            r = #{(mode == "getvec") ? "root.getvec(4, timeout: 5)" : "root.get(timeout: 5)"}
            warn "ritorno: \#{r.inspect}"
            exit 3
          rescue Notcurses::ClosedError
            exit(root.closed? && Notcurses.active_context.nil? ? 0 : 4)
          end
        RUBY
      end
    end

    it "un close dentro il blocco di Visual#stream rinvia lo stop alla fine dello stream" do
      expect_exit(<<~RUBY)
        #{prelude}
        nc = Notcurses::Context.new(**CTX_OPTS)
        trap('USR1') { nc.close }
        v = Notcurses::Visual.from_file(MKV)
        calls = 0
        begin
          v.stream(blitter: :ascii) do |_plane, _at|
            calls += 1
            Process.kill('USR1', Process.pid) if calls == 2 # il gestore gira qui, dentro il callback
            nil
          end
          exit 3
        rescue Notcurses::ClosedError
          warn "calls=\#{calls} stops=\#{$stops}"
          exit(calls == 2 && nc.closed? && Notcurses.active_context.nil? && $stops == 1 ? 0 : 4)
        end
      RUBY
    end

    it "un close dentro un callback di resize rinvia lo stop alla fine dell'operazione" do
      expect_exit(<<~RUBY)
        #{prelude}
        nc = Notcurses::Context.new(**CTX_OPTS)
        trap('USR1') { nc.close }
        parent = nc.stdplane.create_child(rows: 4, cols: 4)
        parent.create_child(rows: 1, cols: 1, resize: ->(_p) { Process.kill('USR1', Process.pid) })
        begin
          parent.resize(5, 5)
          nc.render
          exit 3
        rescue Notcurses::ClosedError
          exit(nc.closed? && Notcurses.active_context.nil? && $stops == 1 ? 0 : 4)
        end
      RUBY
    end

    it "trap { close; exit } durante un'operazione esce con il proprio stato e ferma notcurses una volta" do
      output = expect_exit(<<~RUBY, status: 7)
        #{prelude}
        at_exit { puts "stops=\#{$stops}" } # gira prima dell'at_exit del wrapper
        Notcurses::FFI.singleton_class.prepend(Module.new do
          def ncpile_render(n) = super.tap { Process.kill('USR1', Process.pid) if $armed; $armed = false }
          def ncpile_rasterize(n) = (use!($nc_ptr, :ncpile_rasterize); super)
        end)
        nc = Notcurses::Context.new(**CTX_OPTS)
        $nc_ptr = nc.to_ptr
        trap('USR1') { nc.close; exit 7 }
        $armed = true
        nc.render
        exit 3
      RUBY
      expect(output).to include("stops=1")
    end

    # Un'eccezione asincrona (un secondo Ctrl+C) può arrivare fra due righe
    # qualsiasi della chiusura. Il TracePoint la solleva una volta in ogni riga
    # di close, di Guard e di release_native! fino alla chiamata dello stop
    # esclusa: dopo, un close ripetuto ferma notcurses una sola volta e libera
    # il registro. Le righe vengono da una prima chiusura senza eccezioni.
    {
      "Context" => ["Notcurses::Context.new(**CTX_OPTS)", "stop_notcurses(@ptr)"],
      "Direct" => ["Notcurses::Direct.new(**OPTS)", "FFI.ncdirect_stop(@ptr)"]
    }.each do |name, (create, stop_call)|
      it "#{name}#close: un Interrupt in ogni riga prima dello stop non fa perdere lo stop" do
        expect_exit(<<~RUBY, timeout: 60)
          #{prelude}
          KLASS = Notcurses::#{name}
          file, first = KLASS.instance_method(:release_native!).source_location
          STOP_LINE = File.readlines(file).each_with_index.find do |l, i|
            i + 1 > first && l.include?(#{stop_call.inspect})
          end.last + 1
          GUARD_METHODS = %i[defer settle_if_idle settle].freeze
          def target?(t)
            if t.path.end_with?('/notcurses/guard.rb')
              GUARD_METHODS.include?(t.method_id)
            elsif t.defined_class == KLASS
              t.method_id == :close || (t.method_id == :release_native! && t.lineno < STOP_LINE)
            else
              false
            end
          end
          lines = []
          root = #{create}
          TracePoint.new(:line) { |t| lines << [t.path, t.lineno] if target?(t) }.enable { root.close }
          lines.uniq!
          bad = []
          lines.each do |path, lineno|
            root = #{create}
            stops = $stops
            fired = false
            tp = TracePoint.new(:line) do |t|
              next if fired || t.lineno != lineno || t.path != path || !target?(t)

              fired = true
              raise Interrupt
            end
            begin
              tp.enable { root.close }
            rescue Interrupt
              nil
            end
            root.close
            ok = fired && $stops == stops + 1 && Notcurses.active_context.nil?
            bad << "\#{File.basename(path)}:\#{lineno} (stop: \#{$stops - stops})" unless ok
          rescue Exception => e # rubocop:disable Lint/RescueException
            bad << "\#{File.basename(path)}:\#{lineno} (\#{e.class})"
            break
          end
          warn "righe: \#{lines.size}; senza stop: \#{bad.join(', ')}"
          exit(lines.size > 10 && bad.empty? ? 0 : 4)
        RUBY
      end
    end
  end

  describe "chiusura da un altro thread durante una chiamata C senza GVL (ICH-475)" do
    # Il thread entra nell'operazione e resta nella "chiamata C" (uno sleep con
    # le interruzioni rinviate, come una chiamata FFI blocking) mentre il thread
    # principale chiude; poi l'operazione chiama il C vero.
    # $in_window contiene i puntatori che il thread sta usando nella finestra.
    def thread_prelude = <<~RUBY
      $inside = Queue.new
      def window(*ptrs, what)
        $in_window = ptrs
        $inside << true
        Thread.handle_interrupt(Object => :never) { sleep 0.3 }
        use!(*ptrs, what)
      ensure
        $in_window = nil
      end
    RUBY

    # All'uscita Ruby termina il thread anche dentro la finestra, mentre una
    # chiamata C vera continua: questo at_exit, registrato prima di quello del
    # wrapper, gira subito dopo e controlla che non abbia liberato i puntatori
    # in uso.
    def exit_check = <<~RUBY
      at_exit do
        if $in_window&.any? { |p| $freed[p.address] }
          warn 'at_exit ha liberato un puntatore in uso'
          exit!(6)
        end
      end
    RUBY

    it "Context#close durante Visual#decode_loop ferma subito notcurses e distrugge il visual al ritorno" do
      expect_exit(<<~RUBY)
        #{prelude}
        #{thread_prelude}
        Notcurses::FFI.singleton_class.prepend(Module.new do
          def ncvisual_decode_loop(v) = (window(v, :ncvisual_decode_loop) if $arm; super)
        end)
        nc = Notcurses::Context.new(**CTX_OPTS)
        v = Notcurses::Visual.from_file(MKV)
        $arm = true
        t = Thread.new do
          loop { v.decode_loop }
        rescue Notcurses::ClosedError
          :closed
        end
        $inside.pop
        nc.close
        stopped_now = $stops == 1 && Notcurses.active_context.nil? && v.closed?
        r = t.value
        warn "stopped_now=\#{stopped_now} r=\#{r.inspect} freed=\#{$freed.size}"
        exit(stopped_now && r == :closed && $freed.size == 2 ? 0 : 4)
      RUBY
    end

    it "Visual#close durante Visual#decode rinvia ncvisual_destroy al ritorno della chiamata" do
      expect_exit(<<~RUBY)
        #{prelude}
        #{thread_prelude}
        Notcurses::FFI.singleton_class.prepend(Module.new do
          def ncvisual_decode(v) = (window(v, :ncvisual_decode) if $arm; super)
        end)
        nc = Notcurses::Context.new(**CTX_OPTS)
        v = Notcurses::Visual.from_file(MKV)
        $arm = true
        t = Thread.new do
          loop { v.decode }
        rescue Notcurses::ClosedError
          :closed
        end
        $inside.pop
        v.close
        closed_now = v.closed?
        r = t.value
        exit(closed_now && r == :closed && $freed.size == 1 && !nc.closed? ? 0 : 4)
      RUBY
    end

    it "Context#close durante Visual.from_file distrugge il visual creato e solleva ClosedError" do
      expect_exit(<<~RUBY)
        #{prelude}
        #{thread_prelude}
        $created = []
        Notcurses::FFI.singleton_class.prepend(Module.new do
          def ncvisual_from_file(f) = (window(:ncvisual_from_file) if $arm; super.tap { |p| $created << p.address })
        end)
        nc = Notcurses::Context.new(**CTX_OPTS)
        $arm = true
        t = Thread.new do
          Notcurses::Visual.from_file(MKV)
          :returned
        rescue Notcurses::ClosedError
          :closed
        end
        $inside.pop
        nc.close
        r = t.value
        warn "r=\#{r.inspect} created=\#{$created.size} freed=\#{$freed.keys.size}"
        exit(r == :closed && $created.size == 1 && $freed.key?($created.first) ? 0 : 4)
      RUBY
    end

    it "Context#close durante Visual#stream rinvia lo stop alla fine dello stream" do
      expect_exit(<<~RUBY)
        #{prelude}
        #{thread_prelude}
        Notcurses::FFI.singleton_class.prepend(Module.new do
          def ncvisual_stream(nc, v, *rest) = (window(nc, v, :ncvisual_stream) if $arm; super)
        end)
        nc = Notcurses::Context.new(**CTX_OPTS)
        v = Notcurses::Visual.from_file(MKV)
        $arm = true
        t = Thread.new do
          v.stream(blitter: :ascii, timescale: 0.01)
          :returned
        rescue Notcurses::ClosedError
          :closed
        end
        $inside.pop
        nc.close
        closed_now = nc.closed?
        r = t.value
        warn "closed_now=\#{closed_now} r=\#{r.inspect} stops=\#{$stops}"
        exit(closed_now && r == :closed && $stops == 1 && Notcurses.active_context.nil? ? 0 : 4)
      RUBY
    end

    it "Direct#close durante Direct#render_frame rinvia lo stop al ritorno della chiamata" do
      expect_exit(<<~RUBY)
        #{prelude}
        #{thread_prelude}
        Notcurses::FFI.singleton_class.prepend(Module.new do
          def ncdirect_render_frame(n, *rest) = (window(n, :ncdirect_render_frame) if $arm; super)
        end)
        d = Notcurses::Direct.new(**OPTS)
        $arm = true
        t = Thread.new do
          loop { d.render_frame(MKV).close }
        rescue Notcurses::ClosedError
          :closed
        end
        $inside.pop
        d.close
        closed_now = d.closed?
        r = t.value
        exit(closed_now && r == :closed && $stops == 1 && Notcurses.active_context.nil? ? 0 : 4)
      RUBY
    end

    it "Direct#close durante Direct#stream ferma lo stream al frame successivo" do
      expect_exit(<<~RUBY)
        #{prelude}
        #{thread_prelude}
        Notcurses::FFI.singleton_class.prepend(Module.new do
          def ncdirect_cursor_up(n, *rest) = (window(n, :ncdirect_cursor_up) if $arm; super)
          def ncdirect_raster_frame(n, *rest) = (use!(n, :ncdirect_raster_frame); super)
        end)
        d = Notcurses::Direct.new(**OPTS)
        $arm = true
        t = Thread.new do
          loop { d.stream(MKV) }
        rescue Notcurses::ClosedError
          :closed
        end
        $inside.pop
        d.close
        closed_now = d.closed?
        r = t.value
        exit(closed_now && r == :closed && $stops == 1 && Notcurses.active_context.nil? ? 0 : 4)
      RUBY
    end

    {
      "Visual#decode_loop" => ["ncvisual_decode_loop(v)", "window(v, :ncvisual_decode_loop)",
        "v = Notcurses::Visual.from_file(MKV)", "v.decode_loop"],
      "Visual#stream" => ["ncvisual_stream(nc, v, *rest)", "window(nc, v, :ncvisual_stream)",
        "v = Notcurses::Visual.from_file(MKV)", "v.stream(blitter: :ascii, timescale: 0.01)"],
      "Direct#render_frame" => ["ncdirect_render_frame(n, *rest)", "window(n, :ncdirect_render_frame)",
        nil, "root.render_frame(MKV).close"],
      "Direct#stream" => ["ncdirect_cursor_up(n, *rest)", "window(n, :ncdirect_cursor_up)", nil, "root.stream(MKV)"]
    }.each do |op, (signature, hook, setup, call)|
      it "exit con un thread dentro #{op}: l'hook at_exit non libera la memoria in uso" do
        direct = op.start_with?("Direct")
        expect_exit(<<~RUBY)
          #{exit_check}
          #{prelude}
          #{thread_prelude}
          Notcurses::FFI.singleton_class.prepend(Module.new do
            def #{signature} = (#{hook} if $arm; super)
          end)
          root = #{direct ? "Notcurses::Direct.new(**OPTS)" : "Notcurses::Context.new(**CTX_OPTS)"}
          #{setup}
          $arm = true
          Thread.new do
            loop { #{call} }
          rescue Notcurses::ClosedError
            nil
          end
          $inside.pop
          exit 0
        RUBY
      end
    end
  end
end
