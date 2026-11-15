# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

# Processo figlio delle spec grafiche (spec/graphics/terminal_spec.rb): apre un
# solo contesto sul terminale vero, scrive l'esito in OUT (JSON) e segnala con
# i file OUT.ready.<n> i momenti in cui aspetta i tasti del padre.
#
# Uso: ruby -I lib spec/graphics/probe.rb context|direct|stream|signals|wide OUT
# NC_GRAPHICS_HOLD=<secondi> tiene a schermo ogni immagine per il controllo a vista.

require "notcurses"
require "json"

mode, out = ARGV.fetch(0), ARGV.fetch(1)
fixtures = File.expand_path("../fixtures/visual", __dir__)
hold = Float(ENV.fetch("NC_GRAPHICS_HOLD", "0"))
res = {mode: mode}
ready = ->(n) { File.write("#{out}.ready.#{n}", "") }

# @return [String] "ok", oppure la classe e il messaggio dell'eccezione
def attempt
  yield
  "ok"
rescue => e
  "#{e.class}: #{e.message}"
end

begin
  case mode
  when "context"
    Notcurses::Context.open(suppress_banners: true) do |nc|
      caps = nc.capabilities
      std = nc.stdplane
      res[:detected_terminal] = nc.detected_terminal
      res[:pixel_support] = nc.pixel_support
      res[:caps] = {quadrants: caps.quadrants?, sextants: caps.sextants?, octants: caps.octants?,
                    braille: caps.braille?, halfblocks: caps.halfblocks?}
      res[:pixel_geom] = std.pixel_geom
      res[:blits] = {}
      Notcurses::Visual.from_file(File.join(fixtures, "rgbw.png")) do |visual|
        %i[pixel quad sextant octant braille half ascii].each do |blitter|
          std.erase
          std.putstr("blitter :#{blitter}", y: 0, x: 0)
          plane = std.create_child(rows: 8, cols: 16, y: 2, x: 2)
          res[:blits][blitter] = attempt do
            visual.blit(plane: plane, blitter: blitter, scale: :stretch, no_degrade: true)
            nc.render
            sleep hold
          end
          plane.close
          nc.render
        end
      end
    end
  when "direct"
    Notcurses::Direct.open do |d|
      res[:detected_terminal] = d.detected_terminal
      res[:can_pixel] = d.can_pixel?
      d.putstr("Direct#render_image :pixel\n")
      res[:render_image] = attempt { d.render_image(File.join(fixtures, "rgbw.png"), blitter: :pixel) }
      d.flush
      sleep hold
    end
  when "stream"
    # ICH-284: ogni frame parte dalla riga del precedente, quindi il cursore
    # resta sotto un solo frame. Frame piccoli, lontano dall'ultima riga (ICH-458).
    Notcurses::Direct.open do |d|
      d.clear
      res[:runs] = {}
      %i[half quad pixel].each do |blitter|
        d.putstr("Direct#stream :#{blitter}\n")
        before = d.cursor_yx
        after = []
        d.stream(File.join(fixtures, "frames.mkv"), blitter: blitter, scale: :none) do
          after << d.cursor_yx
          sleep hold / 4
        end
        res[:runs][blitter] = {before: before, after: after}
      end
    end
  when "signals"
    # ICH-280: il padre manda Ctrl+C con CapsLock, con NumLock e da solo, uno per run.
    Notcurses::Context.open(suppress_banners: true) do |nc|
      ev = Notcurses::UI::EventLoop.new(nc)
      seen = []
      ev.on_key("c", ctrl: true) { |input| seen << input.modifier_list }
      res[:runs] = Array.new(3) do |n|
        seen.clear
        ev.after(0.3) { ready.call(n + 1) }
        timer = ev.after(10) { ev.stop }
        reason = ev.run
        timer.cancel
        {reason: reason, on_key: seen.dup}
      end
    end
  when "wide"
    # ICH-281: il padre manda Freccia sinistra (cursore sul glifo largo), legge
    # lo schermo e manda Ctrl+X per uscire.
    Notcurses::Context.open(suppress_banners: true) do |nc|
      app = Notcurses::UI::App.new(nc)
      field = Notcurses::UI::TextInput.new(app.root, size: 1)
      app.on_key("x", ctrl: true) { app.stop }
      app.after(0.1) do
        res[:cols] = field.plane.dim_x
        field.text = "#{"a" * (res[:cols] - 1)}漢"
        app.after(0.3) { ready.call(1) }
      end
      app.after(15) { app.stop }
      res[:reason] = app.run
      res[:position] = field.position
      res[:cursor] = field.cursor
    end
  else
    raise ArgumentError, "modo sconosciuto: #{mode}"
  end
rescue Exception => e # rubocop:disable Lint/RescueException
  res[:error] = "#{e.class}: #{e.message}"
  res[:backtrace] = e.backtrace&.first(5)
ensure
  File.write(out, JSON.generate(res))
end
