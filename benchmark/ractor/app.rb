# Generated from notcurses 3.0.17
# Source: notcurses/src/lib/in.c
# frozen_string_literal: true

# Applicazione di benchmark/ractor/run.rb (studio ICH-601), in un processo
# figlio: la avvia run.rb, non si esegue a mano.
#
#   ruby -Ilib benchmark/ractor/app.rb MODELLO CARICO TTY
#
# Il tasto g avvia JOBS job del CARICO (Segment, PlotData, Pixels di
# jobs.rb). MODELLO: inline (i job girano nell'handler, come oggi), thread
# (un Thread per job, il risultato al ciclo con post) o ractor
# (ProtoBackground di background.rb). Ogni risultato aggiorna lo schermo: una
# riga di testo e, con Pixels, l'immagine con Visual.blit_rgba. Il tasto a
# registra l'ora d'arrivo (latenza dei tasti durante il calcolo), q ferma.
# Il processo diventa leader di sessione e prende TTY come terminale di
# controllo. fd 3: righe per run.rb ("ready", "go T", "done", "result
# JSON"). stderr: lo legge run.rb, che conta i byte scritti (sullo schermo,
# in un'applicazione vera).

require "json"
require "notcurses"
require_relative "jobs"
require_relative "background"

model, load, tty_path = ARGV

TIOCSCTTY = 0x540E # Linux
JOBS = Integer(ENV.fetch("JOBS"))

def now = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)

Process.setsid
tty = File.open(tty_path, File::RDWR)
tty.ioctl(TIOCSCTTY, 0)
$stdin.reopen(tty)
results = IO.new(3, "w")
results.sync = true

job = Jobs.const_get(load)
args = Jobs.inputs.fetch(job)

Notcurses::Context.open(output: tty_path, termtype: "xterm-256color", suppress_banners: true) do |nc|
  app = Notcurses::UI::App.new(nc)
  background = ProtoBackground.new(app)
  image = nc.stdplane.create_child(rows: 20, cols: 40, y: 2, x: 0)
  keys = []
  out = {}
  done = 0
  renders0 = nil

  show = lambda do |value|
    done += 1
    text = case job.name
    when "Jobs::Pixels"
      data, rows, cols = value
      Notcurses::Visual.blit_rgba(data, plane: image, rows: rows, cols: cols, scale: :stretch)
      "#{cols}x#{rows} px"
    when "Jobs::PlotData" then "#{value.size} campioni, ultimo #{value.last.round(2)}"
    else "#{value} grapheme"
    end
    nc.stdplane.putstr("#{done}/#{JOBS} #{text}".ljust(60), y: 0, x: 0)
    next unless done == JOBS

    out[:t_done] = now
    out[:renders] = nc.stats.renders - renders0
    results.puts "done"
  end

  app.on_input do |input|
    case input.id
    when 103 # g
      t = now
      out[:t_go] = t
      renders0 = nc.stats.renders
      results.puts "go #{t}"
      case model
      when "inline"
        JOBS.times { show.call(job.call(*args)) }
      when "thread"
        JOBS.times do
          Thread.new do # rubocop:disable ThreadSafety/NewThread -- il modello misurato
            value = job.call(*args)
            app.post { show.call(value) }
          end
        end
      when "ractor"
        JOBS.times { background.start(job, *args, &show) }
      end
    when 97 # a
      keys << now
    when 113 # q
      app.stop
    end
  end
  app.post { results.puts "ready" }
  out[:reason] = app.run
  background.cancel_all # i job ancora al lavoro: il risultato si scarta, run non li attende
  out[:keys] = keys
  results.puts "result #{JSON.generate(out)}"
end
