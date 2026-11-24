# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative "../support/nc_helpers"

# ICH-604: sotto un Fiber scheduler i callback chiamati da notcurses girano in
# un contesto bloccante, così non si sospendono a metà della chiamata C.
RSpec.describe "Callback di notcurses sotto un Fiber scheduler" do
  include_context "con un contesto notcurses"

  # Scheduler minimo: conta le chiamate agli hook e non sospende mai, così
  # Fiber.schedule esegue il blocco fino in fondo.
  let(:scheduler_class) do
    Class.new do
      attr_reader :calls

      def initialize
        @calls = Hash.new(0)
      end

      def kernel_sleep(*)
        @calls[:kernel_sleep] += 1
        true
      end

      def io_wait(_io, events, _timeout)
        @calls[:io_wait] += 1
        events
      end

      def block(*)
        @calls[:block] += 1
        true
      end

      def unblock(*) = nil

      def fiber_interrupt(*) = nil

      def close = nil

      def fiber(&)
        Fiber.new(blocking: false, &).tap(&:resume)
      end
    end
  end

  # Fiber#blocking? è false in un Fiber non bloccante; Fiber.blocking esiste da Ruby 3.2.
  let(:fiber_blocking_api) { Fiber.respond_to?(:blocking) }

  # Esegue il blocco in un Fiber non bloccante sotto lo scheduler di prova.
  # @return lo scheduler, con le chiamate contate
  def under_scheduler(&)
    scheduler = scheduler_class.new
    Fiber.set_scheduler(scheduler)
    Fiber.schedule(&)
    scheduler
  ensure
    Fiber.set_scheduler(nil)
  end

  # Figlio dello stdplane; alla fine distrugge l'intera famiglia.
  def with_parent
    parent = nc.stdplane.create_child(rows: 10, cols: 20)
    yield parent
  ensure
    parent.family_destroy if parent && !parent.closed?
  end

  it "lo scheduler di prova riceve sleep da un Fiber non bloccante" do
    blocking = nil
    scheduler = under_scheduler do
      blocking = Fiber.current.blocking?
      sleep 0
    end
    expect(blocking).to be(false)
    expect(scheduler.calls[:kernel_sleep]).to eq(1)
  end

  it "un callback di resize che chiama sleep non passa dallo scheduler" do
    with_parent do |p|
      p.create_child(rows: 2, cols: 2, resize: ->(_) { sleep 0 })
      scheduler = under_scheduler { p.resize(11, 21) }
      expect(scheduler.calls[:kernel_sleep]).to eq(0)
    end
  end

  it "Util.guard esegue il blocco in un contesto bloccante" do
    blocking = nil
    scheduler = under_scheduler do
      Notcurses::Util.guard([], nil) do
        blocking = Fiber.current.blocking?
        sleep 0
      end
    end
    expect(blocking).to be_truthy
    expect(scheduler.calls[:kernel_sleep]).to eq(0)
  end

  it "throw nel callback resta un errore del callback: LocalJumpError, UncaughtThrowError su Ruby 3.1" do
    error = nil
    with_parent do |p|
      p.create_child(rows: 2, cols: 2, resize: ->(_) { throw :fuori })
      under_scheduler do
        catch(:fuori) { p.resize(11, 21) }
      rescue => e
        error = e
      end
    end
    expect(error).to be_a(fiber_blocking_api ? LocalJumpError : UncaughtThrowError)
    expect(nc.callback_errors).to be_empty
  end

  it "il callback vede Fiber.current e i valori locali al Fiber del chiamante, non su Ruby 3.1" do
    seen = []
    outer = nil
    with_parent do |p|
      p.create_child(rows: 2, cols: 2, resize: ->(_) { seen.push(Fiber.current, Thread.current[:ich604]) })
      under_scheduler do
        outer = Fiber.current
        Thread.current[:ich604] = :chiamante
        p.resize(11, 21)
      end
    end
    if fiber_blocking_api
      expect(seen).to eq([outer, :chiamante])
    else
      expect(seen.first).not_to equal(outer)
      expect(seen.last).to be_nil
    end
  end

  it "senza scheduler il callback gira nel Fiber del chiamante, come prima" do
    seen = []
    with_parent do |p|
      Thread.current[:ich604] = :chiamante
      p.create_child(rows: 2, cols: 2, resize: ->(_) { seen.push(Fiber.current, Thread.current[:ich604]) })
      p.resize(11, 21)
    ensure
      Thread.current[:ich604] = nil
    end
    expect(seen).to eq([Fiber.current, :chiamante])
  end
end
