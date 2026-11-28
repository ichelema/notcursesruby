# Generated from notcurses 3.0.17
# Source: notcurses/src/lib/visual.c
# frozen_string_literal: true

# Studio ICH-601: calcolo in Ruby puro in serie, in Thread e in Ractor, senza
# UI e senza notcurses, e costo del trasporto dei dati fra Ractor. Stampa
# tabelle markdown.
#
# Uso, dalla radice del repository (non serve la gem ffi):
#
#   ruby benchmark/ractor/compute.rb
#
# Calcolo: JOBS job uguali per carico (default 4, come i core della macchina
# dello studio), REPS ripetizioni (default 5); la tabella dà mediana, minimo
# e massimo, e i GC della ripetizione mediana. I carichi sono in jobs.rb.
# Ogni misura attende i Ractor da un solo thread: su Ruby 3.1-3.4 due thread
# che attendono insieme si bloccano (background.rb).
#
# Trasporto: latenza di un passaggio, da un'ora presa da chi manda subito
# prima del passaggio a un'ora presa da chi riceve (CLOCK_MONOTONIC è lo
# stesso per tutti i Ractor). Il verso "al Ractor" comprende la creazione del
# Ractor (meno di 0,3 ms).

require "etc"
require_relative "jobs"

JOBS = Integer(ENV.fetch("JOBS", "4"))
REPS = Integer(ENV.fetch("REPS", "5"))

Warning[:experimental] = false # il warning del primo Ractor.new
WAIT = Ractor.method_defined?(:value) ? ->(r) { r.value } : ->(r) { r.take }

def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

def fmt(value, digits = 1) = format("%.#{digits}f", value).tr(".", ",")

# [mediana, minimo, massimo] in ms di REPS esecuzioni, e i GC della mediana.
def measure
  runs = Array.new(REPS) do
    gc = GC.count
    t0 = now
    yield
    [(now - t0) * 1000, GC.count - gc]
  end.sort_by(&:first)
  [runs[REPS / 2][0], runs.first[0], runs.last[0], runs[REPS / 2][1]]
end

# I dati del trasporto, costruiti anche dentro un Ractor.
module Payload
  KINDS = ["String di 16 MB", "Array di 200 000 String corte", "Array di 1 000 000 Float"].freeze

  def self.build(kind)
    case kind
    when 0 then "x" * (16 << 20)
    when 1 then Array.new(200_000) { |i| "valore #{i}" }
    else Array.new(1_000_000) { |i| i * 0.5 }
    end
  end
end

def clock_block = proc { |_| Process.clock_gettime(Process::CLOCK_MONOTONIC) }

# Mediana in ms della latenza di REPS passaggi.
def latency
  Array.new(REPS) { yield * 1000 }.sort[REPS / 2]
end

puts "Ruby #{RUBY_VERSION}, #{Etc.nprocessors} core, #{JOBS} job per carico, #{REPS} ripetizioni", ""
puts "### Calcolo: #{JOBS} job uguali (mediana, tra parentesi minimo e massimo)", ""
puts "| Carico | 1 job ms | 1 job in un Ractor ms | #{JOBS} in serie ms | #{JOBS} Thread ms | #{JOBS} Ractor ms | " \
     "Ractor contro serie | GC in serie / in Ractor |"
puts "| --- | --- | --- | --- | --- | --- | --- | --- |"
Jobs.inputs.each do |job, args|
  one = measure { job.call(*args) }
  one_r = measure { WAIT.call(Ractor.new(job, *args) { |j, *a| j.call(*a) }) }
  serial = measure { JOBS.times { job.call(*args) } }
  threads = measure { Array.new(JOBS) { Thread.new { job.call(*args) } }.each(&:join) } # rubocop:disable ThreadSafety/NewThread -- il modello misurato
  ractors = measure do
    Array.new(JOBS) { Ractor.new(job, *args) { |j, *a| j.call(*a) } }.each { |r| WAIT.call(r) }
  end
  cell = ->(m) { "#{fmt(m[0])} (#{fmt(m[1])}–#{fmt(m[2])})" }
  puts "| #{job.name.delete_prefix("Jobs::")} | #{fmt(one[0])} | #{fmt(one_r[0])} | #{cell.call(serial)} | " \
       "#{cell.call(threads)} | #{cell.call(ractors)} | #{fmt(serial[0] / ractors[0], 2)}x | #{serial[3]} / #{ractors[3]} |"
end
puts

puts "### Trasporto: latenza di un passaggio (mediana)", ""
puts "| Dati | Al Ractor: copia ms | Al Ractor: condivisi ms | Al Ractor: send(move: true) ms | " \
     "Dal Ractor: valore finale ms | Dal Ractor: main.send(move: true) ms | Dal Ractor: main.send con copia ms |"
puts "| --- | --- | --- | --- | --- | --- | --- |"
Payload::KINDS.each_with_index do |label, kind|
  data = Payload.build(kind)
  shared = Ractor.make_shareable(Payload.build(kind))
  cells = [
    latency do
      t0 = now
      WAIT.call(Ractor.new(data, &clock_block)) - t0
    end,
    latency do
      t0 = now
      WAIT.call(Ractor.new(shared, &clock_block)) - t0
    end,
    latency do
      fresh = Payload.build(kind)
      r = Ractor.new { Ractor.receive && Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      t0 = now
      r.send(fresh, move: true)
      WAIT.call(r) - t0
    end,
    latency do
      # l'ora la prende il Ractor dopo aver costruito i dati, subito prima di restituirli
      t1, = WAIT.call(Ractor.new(kind) { |k|
        d = Payload.build(k)
        [Process.clock_gettime(Process::CLOCK_MONOTONIC), d]
      })
      now - t1
    end,
    latency do
      Ractor.new(kind) { |k|
        d = Payload.build(k)
        Ractor.main.send([Process.clock_gettime(Process::CLOCK_MONOTONIC), d], move: true)
      }
      t1, = Ractor.receive
      now - t1
    end,
    latency do
      Ractor.new(kind) { |k|
        d = Payload.build(k)
        Ractor.main.send([Process.clock_gettime(Process::CLOCK_MONOTONIC), d])
      }
      t1, = Ractor.receive
      now - t1
    end
  ]
  puts "| #{label} | #{cells.map { |c| fmt(c, 2) }.join(" | ")} |"
end
puts
