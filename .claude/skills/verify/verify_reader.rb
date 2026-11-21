# Verify di ICH-218 e ICH-484 dall'API pubblica, con ncvt (libghostty-vt) come terminale.
# Uso: ncvt -s FILE -- ruby -I<lib> verify_reader.rb FILE
require "notcurses"

CONTROL = ARGV.fetch(0)
K = Notcurses::Key
BS = Notcurses::Input.synthesize(K::BACKSPACE)
def ctrl(l) = Notcurses::Input.synthesize(l.ord, modifiers: [:ctrl])

def checkpoint(label)
  File.write(CONTROL, label)
  sleep 0.02 until File.exist?("#{CONTROL}.done")
  File.delete("#{CONTROL}.done")
end

# Esegue un caso con un reader nuovo in (3, 2), fa il render e chiede lo snapshot a reader aperto.
def scenario(nc, name, rows: 1, cols: 10, **opts)
  Notcurses::Reader.open(nc.stdplane.create_child(rows: rows, cols: cols, y: 3, x: 2), **opts) do |r|
    detail = yield(r)
    nc.render
    checkpoint("#{name}: contents=#{r.contents.inspect} #{detail}")
  end
  nc.render # il reader chiuso libera le righe
rescue => e
  checkpoint("#{name}: ERRORE #{e.class}: #{e.message}")
end

Notcurses::Context.open(termtype: "xterm-256color", suppress_banners: true) do |nc|
  scenario(nc, "1 bs_ascii") { |r|
    r.write("ab")
    2.times { r.offer_input(BS) }
    ""
  }
  scenario(nc, "2 bs_largo_meta") { |r|
    r.write("漢")
    r.move_left
    r.offer_input(BS)
    ""
  }
  scenario(nc, "3 bs_riga1", rows: 2) do |r|
    r.write("c")
    r.move_down
    r.offer_input(ctrl("A"))
    r.write("d")
    r.offer_input(BS)
    "cursor=#{r.plane.cursor}"
  end
  scenario(nc, "4 ctrl_u") { |r|
    r.write("abc")
    r.move_left
    r.offer_input(ctrl("U"))
    ""
  }
  scenario(nc, "5a ctrl_w") { |r|
    r.write("ab cd")
    3.times { r.move_left }
    r.offer_input(ctrl("W"))
    ""
  }
  scenario(nc, "5b ctrl_w_spazio") { |r|
    r.write(" ab")
    r.offer_input(ctrl("W"))
    "cursor=#{r.plane.cursor}"
  }
  [["6a ich484_bs", BS], ["6b ich484_ctrl_u", ctrl("U")], ["6c ich484_ctrl_w", ctrl("W")]].each do |name, key|
    scenario(nc, name, cols: 8) do |r|
      r.write("漢漢漢")
      2.times { r.move_left }
      r.offer_input(key)
      "at(x:1)=#{r.plane.at(y: 0, x: 1).egc.inspect} at(x:5)=#{r.plane.at(y: 0, x: 5).egc.inspect}"
    end
  end
  nc.cursor_enable(y: 10, x: 5)
  scenario(nc, "7 cursor_enable(10,5)") { |r|
    r.write("x")
    r.move_left
    ""
  }
  nc.cursor_disable
  scenario(nc, "8 cursor_true", cursor: true) { |r|
    r.write("q")
    ""
  }
  scenario(nc, "9a raffica_bs") { |r|
    r.write("a")
    20.times { r.offer_input(BS) }
    "cursor=#{r.plane.cursor}"
  }
  scenario(nc, "9b riga_larga") { |r|
    r.write("漢")
    r.move_left
    r.offer_input(BS)
    r.offer_input(ctrl("A"))
    r.write("漢漢漢漢漢")
    ""
  }
  begin
    nc.cursor_disable
    checkpoint("10 cursor_disable dopo cursor: true: ok")
  rescue => e
    checkpoint("10 cursor_disable dopo cursor: true: ERRORE #{e.class}: #{e.message}")
  end
end
