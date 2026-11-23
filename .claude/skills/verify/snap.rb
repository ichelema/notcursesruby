# Helper degli script di prova di `screen` (regola 22 di memory/regole.md): lo carica `screen` con -r, non serve un require.
#
#   Screen.open do |nc|
#     pl = nc.stdplane.create_child(rows: 1, cols: 10, y: 2, x: 4)
#     pl.putstr("A🇮🇹B", y: 0, x: 0)
#     Screen.snap(nc, "bandiera scritta: #{pl.contents.inspect}")
#   end
require "notcurses"

module Screen
  # File di controllo di ncvt (-s): lo passa `screen` nell'ambiente.
  CONTROL = ENV.fetch("SCREEN_CONTROL") { abort "snap.rb: lancia lo script con .claude/skills/verify/screen" }

  module_function

  # Context come lo vuole ncvt: terminfo fisso, niente banner, output sul terminale di ncvt (non /dev/null).
  # @return il valore del blocco; il contesto si chiude alla fine
  def open(**opts, &block) = Notcurses::Context.open(termtype: "xterm-256color", suppress_banners: true, **opts, &block)

  # Fa il render di nc e chiede a ncvt lo snapshot dello schermo, con label nella riga "=== snapshot" (al massimo
  # 255 byte); torna quando ncvt lo ha stampato. ncvt non mostra la larghezza delle celle: per i glifi larghi metti
  # Plane#at nell'etichetta. Il file compare con un rename: ncvt lo legge appena esiste, e con File.write a volte lo
  # trovava ancora vuoto ("punto di controllo" al posto dell'etichetta).
  # @return [void]
  def snap(nc, label)
    nc.render
    File.write("#{CONTROL}.tmp", label.to_s.tr("\n", " "))
    File.rename("#{CONTROL}.tmp", CONTROL)
    sleep 0.02 until File.exist?("#{CONTROL}.done")
    File.delete("#{CONTROL}.done")
  end
end
