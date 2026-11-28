# Generated from notcurses 3.0.17
# Source: notcurses/src/lib/visual.c
# frozen_string_literal: true

# Studio ICH-601: carichi di calcolo in Ruby puro per i Ractor, senza
# notcurses. Ogni carico è un modulo con self.call: un modulo è condivisibile
# (Ractor.shareable?), quindi passa a Ractor.new su Ruby 3.1-4.0, mentre una
# lambda scritta nel programma principale non passa (il suo self, main, non è
# condivisibile). Gli input sono stringhe frozen: passano a un Ractor senza
# copia.
#
# - Segment: conta i grapheme di un testo (come Notcurses.strwidth prima di
#   scrivere una riga lunga).
# - PlotData: legge un CSV di numeri e calcola la media mobile, i campioni di
#   un Plot.
# - Pixels: porta un'immagine RGBA in scala di grigi e la dimezza, i byte per
#   Visual.from_rgba o Visual.blit_rgba. Decodificare con notcurses
#   (ncvisual_from_file) in un altro Ractor non si può: il motore delle
#   immagini lo installa notcurses_init (media/shim.c:7), cioè un contesto
#   aperto nel Ractor principale, e la regola 3 vuole notcurses in un solo
#   thread alla volta.
module Jobs
  # Conta i grapheme del testo.
  module Segment
    def self.call(text) = text.each_grapheme_cluster.count
  end

  # Media mobile su window valori di un CSV di numeri, una riga per numero.
  module PlotData
    def self.call(csv, window = 50)
      values = csv.each_line.map(&:to_f)
      sum = 0.0
      values.each_with_index.map do |v, i|
        sum += v
        sum -= values[i - window] if i >= window
        sum / [i + 1, window].min
      end
    end
  end

  # Scala di grigi e metà delle dimensioni: restituisce [byte RGBA, rows, cols].
  module Pixels
    def self.call(rgba, rows, cols)
      out_rows = rows / 2
      out_cols = cols / 2
      src = rgba.unpack("C*")
      out = Array.new(out_rows * out_cols * 4)
      out_rows.times do |y|
        out_cols.times do |x|
          i = (((y * 2) * cols) + (x * 2)) * 4
          grey = ((src[i] * 299) + (src[i + 1] * 587) + (src[i + 2] * 114)) / 1000
          o = ((y * out_cols) + x) * 4
          out[o] = out[o + 1] = out[o + 2] = grey
          out[o + 3] = src[i + 3]
        end
      end
      [out.pack("C*"), out_rows, out_cols]
    end
  end

  # Un job che solleva, per il percorso d'errore.
  module Fail
    def self.call(*) = raise(ArgumentError, "job fallito")
  end

  # Un job lungo che controlla la cancellazione (ProtoBackground.cancelled?).
  module Spin
    def self.call(seconds)
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      n = 0
      until Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0 > seconds
        n += 1
        return [:cancelled, n] if (n % 1000).zero? && ProtoBackground.cancelled?
      end
      [:done, n]
    end
  end

  # Input deterministici e frozen, di dimensione scale: con 1 ogni job dura
  # circa 140-210 ms su un core (Ruby 3.1.7, 3.4.12 e 4.0.7, compute.rb).
  def self.inputs(scale = 1)
    {
      Segment => [((("é漢a" * 50) + "\n") * (6_000 * scale)).freeze],
      PlotData => [(Array.new(900_000 * scale) { |i| ((i * 7919) % 1000).to_s }.join("\n") + "\n").freeze],
      Pixels => [Array.new(960 * scale * 1280 * 4) { |i| (i * 31) & 0xff }.pack("C*").freeze, 960 * scale, 1280]
    }
  end
end
