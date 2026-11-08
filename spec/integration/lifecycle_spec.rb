# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require_relative '../support/nc_helpers'

# Ciclo di vita degli oggetti del wrapper insieme: contesto, piani, pile,
# visual, fotografie dei fade, GC, contesti esclusivi, uscita del processo.
RSpec.describe 'Ciclo di vita (integrazione)' do
  LIB = File.expand_path('../../lib', __dir__)

  # Piani della pila di plane, contati con la navigazione dello z-order.
  def pile_count(plane)
    count = 0
    cur = plane.pile_top
    while cur
      count += 1
      cur = cur.below
    end
    count
  end

  def rgba_visual
    Notcurses::Visual.from_rgba(([255, 0, 0, 255] * 4).pack('C*'), rows: 2, cols: 2)
  end

  # Esegue script in un processo Ruby figlio e lo uccide dopo timeout secondi:
  # un crash (SIGSEGV, abort) o un blocco non fermano la suite.
  # @return [Array(String, Process::Status, Boolean)] output, stato, true se scaduto
  def run_child(script, timeout:)
    reader, writer = IO.pipe
    pid = spawn({ 'TERM' => 'xterm-256color' }, RbConfig.ruby, '-I', LIB, '-e', script,
                in: File::NULL, out: writer, err: writer)
    writer.close
    output = Thread.new { reader.read }
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

  # Inizio comune degli script figli: name è la funzione FFI che solleva
  # Interrupt al ritorno, come Ruby consegna un SIGINT arrivato durante la
  # chiamata C, quando $interrupt contiene :raise.
  def interrupt_prelude(name) = <<~RUBY
    at_exit { puts "calls at exit=\#{$calls}" } # gira dopo l'at_exit del wrapper
    require 'notcurses'
    $stdout.sync = true
    $calls = 0
    $interrupt = []
    Notcurses::FFI.singleton_class.prepend(Module.new do
      def #{name}(ptr) = super.tap { $calls += 1; raise Interrupt if $interrupt.delete(:raise) }
    end)
    OPTS = { output: '/dev/null', termtype: 'xterm-256color', drain_input: true }.freeze
  RUBY

  it 'Context.open con un blocco chiude il contesto e invalida piani, pile e visual, anche dopo un\'eccezione' do
    kept = {}
    expect do
      NcHelpers.open_context do |nc|
        kept[:child] = nc.stdplane.create_child(rows: 2, cols: 2)
        kept[:grandchild] = kept[:child].create_child(rows: 1, cols: 1)
        kept[:pile] = nc.create_pile(rows: 2, cols: 2)
        kept[:borrowed] = kept[:grandchild].pile_top
        kept[:visual] = rgba_visual
        kept[:std] = nc.stdplane
        raise 'boom'
      end
    end.to raise_error(RuntimeError, 'boom')
    kept.each do |name, obj|
      expect(obj).to be_closed, "#{name} dovrebbe essere chiuso"
    end
    expect { kept[:child].dims }.to raise_error(Notcurses::ClosedError)
    expect(Notcurses.active_context).to be_nil
  end

  it 'drop_planes distrugge i piani di tutte le pile tranne lo stdplane' do
    NcHelpers.open_context do |nc|
      std = nc.stdplane
      before = pile_count(std)
      a = std.create_child(rows: 1, cols: 1)
      b = a.create_child(rows: 1, cols: 1)
      pile = nc.create_pile(rows: 1, cols: 1)
      pile.create_child(rows: 1, cols: 1)
      expect(pile_count(std)).to eq(before + 2)
      expect(nc.drop_planes).to equal(nc)
      expect([a, b, pile]).to all(be_closed)
      expect(std).not_to be_closed
      expect(pile_count(std)).to eq(1)
      expect(std.create_child(rows: 1, cols: 1)).not_to be_closed
    end
  end

  it 'drop_planes e close chiudono tutti i figli anche se un close solleva, poi rilanciano l\'eccezione' do
    failing = Struct.new(:ctx) do
      def close
        ctx.disown(self)
        raise SystemExit, 'uscita salvata dal blocco di un figlio'
      end
    end
    NcHelpers.open_context do |nc|
      bar = Notcurses::ProgBar.new(nc.stdplane.create_child(rows: 1, cols: 10))
      nc.adopt(failing.new(nc)) # adottato dopo: si chiude per primo
      expect { nc.drop_planes }.to raise_error(SystemExit)
      expect(bar).to be_closed
      bar = Notcurses::ProgBar.new(nc.stdplane.create_child(rows: 1, cols: 10))
      nc.adopt(failing.new(nc))
      expect { nc.close }.to raise_error(SystemExit)
      expect(bar).to be_closed
      expect(nc).to be_closed
      expect(Notcurses.active_context).to be_nil
    end
  end

  it 'il GC non distrugge i piani: restano nel C finché li distrugge il contesto' do
    NcHelpers.open_context do |nc|
      std = nc.stdplane
      before = pile_count(std)
      10.times { std.create_child(rows: 1, cols: 1) }
      GC.start(full_mark: true, immediate_sweep: true)
      expect(pile_count(std)).to eq(before + 10)
      nc.drop_planes
      expect(pile_count(std)).to eq(1)
    end
  end

  it 'Context e Direct si escludono a vicenda' do
    NcHelpers.open_context do
      expect { Notcurses::Direct.new(output: '/dev/null', termtype: 'xterm-256color') }
        .to raise_error(Notcurses::InitError, /già attivo/)
    end
    Notcurses::Direct.open(output: '/dev/null', termtype: 'xterm-256color', drain_input: true) do
      expect { NcHelpers.open_context }.to raise_error(Notcurses::InitError, /già attivo/)
    end
    NcHelpers.open_context { |nc| expect(nc).not_to be_closed }
  end

  it 'le risorse chiuse sollevano ClosedError e close è idempotente' do
    NcHelpers.open_context do |nc|
      plane = nc.stdplane.create_child(rows: 1, cols: 3)
      plane.putstr('abc', y: 0, x: 0)
      resources = [plane.fade_context, rgba_visual, nc.palette, plane]
      resources.each do |res|
        expect(res.close).to be_nil
        expect(res.close).to be_nil
        expect(res).to be_closed
        expect { res.to_ptr }.to raise_error(Notcurses::ClosedError)
      end
    end
  end

  it 'dentro un callback di resize non si distruggono piani: l\'errore esce dal resize' do
    NcHelpers.open_context do |nc|
      parent = nc.stdplane.create_child(rows: 4, cols: 4)
      victim = parent.create_child(rows: 1, cols: 1)
      child = parent.create_child(rows: 2, cols: 2, resize: ->(_plane) { victim.close })
      expect { parent.resize(5, 5) }.to raise_error(Notcurses::PlaneError, /callback/)
      expect(victim).not_to be_closed
      expect(child).not_to be_closed
      victim.close
      expect(victim).to be_closed
    end
  end

  it 'un contesto lasciato aperto viene chiuso all\'uscita del processo' do
    # gli hook at_exit girano in ordine inverso: questo, registrato prima del
    # require, gira dopo quello del wrapper
    script = <<~RUBY
      at_exit { warn($nc.closed? ? 'chiuso' : 'aperto') }
      require 'notcurses'
      $nc = Notcurses::Context.new(output: '/dev/null', termtype: 'xterm-256color', suppress_banners: true)
      $nc.stdplane.create_child(rows: 1, cols: 1)
    RUBY
    out, status = Open3.capture2e({ 'TERM' => 'xterm-256color' }, RbConfig.ruby, '-I', LIB, '-e', script, stdin_data: '')
    expect(status).to be_success
    expect(out).to include('chiuso')
  end

  it 'Context#close interrotto al ritorno di notcurses_stop lascia il contesto chiuso e il registro libero' do
    script = interrupt_prelude('notcurses_stop') + <<~'RUBY'
      nc = Notcurses::Context.new(**OPTS, suppress_banners: true)
      plane = nc.stdplane.create_child(rows: 1, cols: 1)
      $interrupt << :raise
      begin
        nc.close
        puts 'nessuna Interrupt'
      rescue Interrupt
        puts "closed=#{nc.closed?} active=#{Notcurses.active_context.inspect}"
      end
      [-> { nc.stdplane }, -> { plane.dims }].each do |use|
        use.call
        puts 'usabile'
      rescue Notcurses::ClosedError
        puts 'ClosedError'
      end
      nc.close
      puts "calls after close=#{$calls}"
      Notcurses::Context.open(**OPTS, suppress_banners: true) { puts 'riaperto' }
    RUBY
    out, status, timed_out = run_child(script, timeout: 30)
    expect(timed_out).to be(false), out
    expect(out).to include('closed=true active=nil', 'calls after close=1', 'riaperto', 'calls at exit=2')
    expect(out.scan('ClosedError').size).to eq(2), out
    expect(status).to be_success, out
  end

  it 'Direct#close interrotto al ritorno di ncdirect_stop lascia il contesto chiuso e il registro libero' do
    script = interrupt_prelude('ncdirect_stop') + <<~'RUBY'
      d = Notcurses::Direct.new(**OPTS)
      $interrupt << :raise
      begin
        d.close
        puts 'nessuna Interrupt'
      rescue Interrupt
        puts "closed=#{d.closed?} active=#{Notcurses.active_context.inspect}"
      end
      begin
        d.dims
        puts 'usabile'
      rescue Notcurses::ClosedError
        puts 'ClosedError'
      end
      d.close
      puts "calls after close=#{$calls}"
      Notcurses::Direct.open(**OPTS) { puts 'riaperto' }
    RUBY
    out, status, timed_out = run_child(script, timeout: 30)
    expect(timed_out).to be(false), out
    expect(out).to include('closed=true active=nil', 'ClosedError', 'calls after close=1', 'riaperto',
                           'calls at exit=2')
    expect(status).to be_success, out
  end

  it 'drop_planes interrotto dopo un ncplane_destroy invalida solo i piani distrutti' do
    script = interrupt_prelude('ncplane_destroy') + <<~'RUBY'
      nc = Notcurses::Context.new(**OPTS, suppress_banners: true)
      planes = Array.new(3) { nc.stdplane.create_child(rows: 1, cols: 1) }
      generation = nc.generation
      $interrupt << :raise
      begin
        nc.drop_planes
        puts 'nessuna Interrupt'
      rescue Interrupt
        puts "closed=#{planes.map(&:closed?).join(',')} generation grown=#{nc.generation > generation}"
      end
      planes.last.close # il piano distrutto: senza invalidazione è un double free
      planes.first.dims
      puts 'ancora usabile'
      nc.drop_planes
      puts "after drop closed=#{planes.map(&:closed?).join(',')}"
      nc.close
      puts 'chiuso'
    RUBY
    out, status, timed_out = run_child(script, timeout: 30)
    expect(timed_out).to be(false), out
    expect(out).to include('closed=false,false,true generation grown=true', 'ancora usabile',
                           'after drop closed=true,true,true', 'chiuso')
    expect(status).to be_success, out
  end

  it 'drop_planes interrotto al ritorno di notcurses_drop_planes considera distrutti tutti i piani' do
    script = interrupt_prelude('notcurses_drop_planes') + <<~'RUBY'
      nc = Notcurses::Context.new(**OPTS, suppress_banners: true)
      planes = Array.new(3) { nc.stdplane.create_child(rows: 1, cols: 1) }
      generation = nc.generation
      $interrupt << :raise
      begin
        nc.drop_planes
        puts 'nessuna Interrupt'
      rescue Interrupt
        puts "closed=#{planes.map(&:closed?).join(',')} generation grown=#{nc.generation > generation}"
      end
      nc.stdplane.dims
      nc.drop_planes
      nc.close
      puts 'chiuso'
    RUBY
    out, status, timed_out = run_child(script, timeout: 30)
    expect(timed_out).to be(false), out
    expect(out).to include('closed=true,true,true generation grown=true', 'chiuso')
    expect(status).to be_success, out
  end

  it 'in un figlio di fork Context#close e Direct#close non chiamano notcurses e non si bloccano' do
    script = <<~'RUBY'
      $parent = Process.pid
      at_exit { puts "nipote active=#{Notcurses.active_context.inspect} calls=#{$calls}" unless Process.pid == $parent }
      require 'notcurses'
      $stdout.sync = true
      # chiamate C che il close del nipote non deve fare
      $calls = Hash.new(0)
      Notcurses::FFI.singleton_class.prepend(Module.new do
        def notcurses_stop(ptr) = super.tap { $calls[:notcurses_stop] += 1 }
        def ncdirect_stop(ptr) = super.tap { $calls[:ncdirect_stop] += 1 }
        def ncdirect_flush(ptr) = super.tap { $calls[:ncdirect_flush] += 1 }
        def ncdirect_set_fg_default(ptr) = super.tap { $calls[:ncdirect_set_fg_default] += 1 }
        def ncdirect_set_bg_default(ptr) = super.tap { $calls[:ncdirect_set_bg_default] += 1 }
        def ncdirect_set_styles(ptr, styles) = super.tap { $calls[:ncdirect_set_styles] += 1 }
      end)
      opts = { output: '/dev/null', termtype: 'xterm-256color', drain_input: true }
      [[Notcurses::Context, { suppress_banners: true }], [Notcurses::Direct, {}]].each do |klass, extra|
        klass.open(**opts, **extra) do
          t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          pid = fork
          $calls.clear if pid.nil? # i conteggi copiati dal padre non contano
          raise 'errore nel nipote' if pid.nil? # il nipote esce da open con il suo ensure, cioè close
          deadline = t0 + 3
          until (done = Process.wait2(pid, Process::WNOHANG))
            break if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
            sleep 0.05
          end
          if done
            elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
            puts "#{klass}: nipote uscito con #{done.last.exitstatus} #{elapsed < 1 ? 'entro 1 s' : "in #{elapsed.round(1)} s"}"
          else
            puts "#{klass}: nipote bloccato"
            Process.kill(:KILL, pid)
            Process.wait(pid)
          end
        end
      end
      puts 'fine'
    RUBY
    out, status, timed_out = run_child(script, timeout: 30)
    expect(timed_out).to be(false), out
    expect(out).to include('Notcurses::Context: nipote uscito con 1 entro 1 s', 'Notcurses::Direct: nipote uscito con 1 entro 1 s',
                           'fine')
    expect(out.scan('nipote active=nil calls={}').size).to eq(2), out
    expect(status).to be_success, out
  end

  it 'con output nil il testo di Direct non svuotato prima di un fork esce una volta sola su stdout' do
    script = <<~'RUBY'
      require 'notcurses'
      Notcurses::Direct.open(termtype: 'xterm-256color', drain_input: true) do |d|
        d.flush
        d.putstr('PENDING_TOKEN')
        pid = fork
        raise 'errore nel nipote' if pid.nil? # il nipote esce da open con il suo ensure, cioè close
        Process.wait(pid)
      end
      puts 'fine'
    RUBY
    out, status, timed_out = run_child(script, timeout: 30)
    expect(timed_out).to be(false), out
    expect(out.scan('PENDING_TOKEN').size).to eq(1), out
    expect(out).to include('fine')
    expect(status).to be_success, out
  end

  it 'con fork annidati il testo di Direct scritto dal figlio intermedio esce una volta sola' do
    script = <<~'RUBY'
      require 'notcurses'
      require 'tempfile'
      path = Tempfile.create('direct') { |f| f.path }
      Notcurses::Direct.open(output: path, termtype: 'xterm-256color', drain_input: true) do |d|
        d.flush
        d.putstr('FROM_ORIGINAL')
        pid = fork
        if pid.nil?
          d.putstr('FROM_INTERMEDIATE')
          inner = fork # il nipote e il figlio intermedio chiudono il Direct ereditato ed escono normalmente
          d.close
          Process.wait(inner) if inner
          exit 0
        end
        Process.wait(pid)
      end
      text = File.read(path)
      File.delete(path)
      puts "FROM_ORIGINAL=#{text.scan('FROM_ORIGINAL').size} FROM_INTERMEDIATE=#{text.scan('FROM_INTERMEDIATE').size}"
    RUBY
    out, status, timed_out = run_child(script, timeout: 30)
    expect(timed_out).to be(false), out
    expect(out).to include('FROM_ORIGINAL=1 FROM_INTERMEDIATE=1')
    expect(status).to be_success, out
  end

  # Ruby vieta Mutex#lock in un gestore trap: close deve liberare il registro lo stesso.
  { 'Notcurses::Context' => '**OPTS, suppress_banners: true', 'Notcurses::Direct' => '**OPTS' }.each do |klass, args|
    it "#{klass}#close funziona dentro un gestore trap e libera il registro" do
      script = <<~RUBY
        require 'notcurses'
        $stdout.sync = true
        OPTS = { output: '/dev/null', termtype: 'xterm-256color', drain_input: true }.freeze
        first = #{klass}.new(#{args})
        trap('USR1') { first.close }
        Process.kill(:USR1, Process.pid)
        sleep 0.3
        puts "dopo USR1 closed=\#{first.closed?} active=\#{Notcurses.active_context.inspect}"
        second = #{klass}.new(#{args})
        trap('TERM') do
          second.close
          puts "active=\#{Notcurses.active_context.inspect}"
          exit 0
        end
        Process.kill(:TERM, Process.pid)
        sleep 5
        puts 'il gestore non è uscito'
      RUBY
      out, status, timed_out = run_child(script, timeout: 30)
      expect(timed_out).to be(false), out
      expect(out).to include('dopo USR1 closed=true active=nil', 'active=nil')
      expect(out).not_to include('il gestore non è uscito')
      expect(status).to be_success, out
    end
  end
end
