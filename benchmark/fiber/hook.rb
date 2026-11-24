# Generated from notcurses 3.0.17
# Source: notcurses/src/lib/notcurses.c
# frozen_string_literal: true

# Studio ICH-600: l'hook Fiber::Scheduler#blocking_operation_wait (Ruby 3.4+)
# sposta fuori dal ciclo dei Fiber le chiamate FFI con blocking: true?
#
# Uso, dalla radice del repository (serve solo la gem ffi, non notcurses):
#
#   ruby benchmark/fiber/hook.rb
#
# Un Fiber conta un tick ogni TICK_MS ms; un altro Fiber fa un'operazione che
# dura circa 100 ms. Se lo scheduler riceve l'operazione dall'hook, la
# esegue in un thread e il Fiber che conta va avanti (circa 100 / TICK_MS
# tick); altrimenti l'operazione ferma il thread del ciclo e i tick sono 0.
# Le operazioni: usleep della libc con e senza blocking: true (dichiarato qui,
# non nel layer FFI del progetto) e, come controllo, operazioni di Ruby che
# rilasciano il GVL.

require "ffi"
require "zlib"
require_relative "scheduler"

TICK_MS = 5

# usleep della libc, con e senza il rilascio del GVL.
module LibC
  extend FFI::Library

  ffi_lib FFI::Library::LIBC
  attach_function :usleep_blocking, :usleep, [:uint], :int, blocking: true
  attach_function :usleep_plain, :usleep, [:uint], :int
end

# ProtoScheduler con l'hook: conta le operazioni ricevute e le esegue in un
# thread, con il Fiber chiamante sospeso.
class HookScheduler < ProtoScheduler
  attr_reader :offloaded

  def initialize(...)
    super
    @offloaded = 0
  end

  def blocking_operation_wait(work)
    @offloaded += 1
    fiber = Fiber.current
    thread = Thread.new do # rubocop:disable ThreadSafety/NewThread -- il worker dell'operazione
      work.call
    ensure
      unblock(nil, fiber)
    end
    block(nil)
    thread.value
  end
end

def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

def probe(name)
  scheduler = HookScheduler.new
  Fiber.set_scheduler(scheduler)
  ticks = 0
  done = false
  elapsed = nil
  Fiber.schedule do
    until done
      sleep TICK_MS / 1000.0
      ticks += 1
    end
  end
  Fiber.schedule do
    sleep 0.02 # il contatore parte prima
    ticks = 0
    t0 = now
    yield
    elapsed = now - t0
    done = true
  end
  scheduler.run { done }
  Fiber.set_scheduler(nil)
  format("| %s | %d | %d | %.0f |", name, scheduler.offloaded, ticks, elapsed * 1000)
end

big = Random.new(1).bytes(64 * 1_048_576)
probes = {
  "usleep FFI blocking: true" => -> { LibC.usleep_blocking(100_000) },
  "usleep FFI senza blocking" => -> { LibC.usleep_plain(100_000) },
  "Zlib.deflate di 64 MB" => -> { Zlib.deflate(big) },
  "IO::Buffer#copy di 64 MB" => lambda {
    Warning[:experimental] = false
    dst = IO::Buffer.new(big.bytesize)
    dst.copy(IO::Buffer.for(big))
  }
}

puts "Ruby #{RUBY_VERSION}, ffi #{FFI::VERSION}", ""
puts "| Operazione | Chiamate all'hook | Tick durante l'operazione | ms |"
puts "| --- | --- | --- | --- |"
probes.each { |name, op| puts probe(name, &op) }
