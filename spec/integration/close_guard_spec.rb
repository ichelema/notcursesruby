# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require "rbconfig"

# Chiusura di Context, Direct e Visual mentre un'operazione del wrapper è in
# corso: da un altro thread durante una chiamata C senza GVL (ICH-475). Ogni scenario gira
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
    end)
    OPTS = { output: '/dev/null', termtype: 'xterm-256color' }.freeze
    CTX_OPTS = { **OPTS, suppress_banners: true, drain_input: true }.freeze
    MKV = #{mkv_path.inspect}
  RUBY

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
