# Generated from notcurses 3.0.17
# Source: notcurses/src/lib/notcurses.c
# frozen_string_literal: true

# Misura le scritture di Notcurses::Plane contro la FFI diretta (ICH-594) e
# stampa una tabella markdown: tempo del wrapper, tempo della FFI, rapporto e
# obiettivo.
#
# Uso, dalla radice del repository:
#
#   TERM=xterm-256color ruby -Ilib benchmark/plane_writes.rb < /dev/null
#
# Per misurare un altro albero (per esempio master, per i numeri «prima») usa
# il suo lib/: ruby -I/percorso/di/master/lib benchmark/plane_writes.rb
#
# Le scritture vanno su un piano 60x200 di un contesto con l'output su
# /dev/null: non toccano il terminale, quindi il tempo è solo quello del
# wrapper e del C. Ogni riga è la mediana di REPS ripetizioni; la riga
# dell'EGC da 6 MB ne fa meno, perché ogni ripetizione dura da 0,1 a 1 s.

require "notcurses"

ROWS = 60
COLS = 200
REPS = 15
BIG_REPS = 5

# Un EGC di circa 6 MB: base e 3 milioni di U+0301.
BIG_EGC = "a#{"́" * 3_000_000}".freeze

NC_FFI = Notcurses::FFI

def median(values)
  sorted = values.sort
  sorted[sorted.size / 2]
end

# Tempo in millisecondi del blocco, mediana di reps ripetizioni. Il piano si
# svuota prima di ogni ripetizione, fuori dal tempo misurato.
def measure(plane, reps: REPS)
  samples = Array.new(reps + 1) do
    plane.erase
    GC.start
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000.0
  end
  median(samples.drop(1)) # la prima ripetizione scalda il codice
end

# Ogni cella dello schermo, una chiamata per cella; step è la larghezza del carattere.
def each_cell(step: 1)
  ROWS.times { |y| (0...COLS).step(step) { |x| yield y, x } }
end

# Cella C con l'EGC dato, caricata sull'egcpool del piano.
def with_nccell(ptr, egc)
  nc = NC_FFI::NcCell.new
  raise "nccell_load fallita" unless NC_FFI.nccell_load(ptr, nc, egc).positive?

  yield nc
ensure
  NC_FFI.nccell_release(ptr, nc) if nc
end

# @return [Array(String, Float, Float, String)] nome, ms wrapper, ms FFI, obiettivo
def cases(plane)
  ptr = plane.to_ptr
  ascii_line = "x" * COLS
  cjk_line = "漢" * (COLS / 2)
  accent_line = "é" * COLS
  cell = Notcurses::Cell.new(egc: "x")

  [
    ["`putegc(\"x\")`, una cella per chiamata", "≤ 15x",
      -> { measure(plane) { each_cell { |y, x| plane.putegc("x", y: y, x: x) } } },
      -> { measure(plane) { each_cell { |y, x| NC_FFI.ncplane_putegc_yx(ptr, y, x, "x", nil) } } }],
    ["`putegc(\"é\")`", "≤ 15x",
      -> { measure(plane) { each_cell { |y, x| plane.putegc("é", y: y, x: x) } } },
      -> { measure(plane) { each_cell { |y, x| NC_FFI.ncplane_putegc_yx(ptr, y, x, "é", nil) } } }],
    ["`putegc(\"漢\")`", "≤ 15x",
      -> { measure(plane) { each_cell(step: 2) { |y, x| plane.putegc("漢", y: y, x: x) } } },
      -> { measure(plane) { each_cell(step: 2) { |y, x| NC_FFI.ncplane_putegc_yx(ptr, y, x, "漢", nil) } } }],
    ["`putc` con una `Cell` \"x\"", "≤ 15x",
      -> { measure(plane) { each_cell { |y, x| plane.putc(cell, y: y, x: x) } } },
      lambda do
        with_nccell(ptr, "x") do |nc|
          measure(plane) { each_cell { |y, x| NC_FFI.ncplane_putc_yx(ptr, y, x, nc) } }
        end
      end],
    ["`putstr`, 200 caratteri ASCII per riga", "≤ 2x",
      -> { measure(plane) { ROWS.times { |y| plane.putstr(ascii_line, y: y, x: 0) } } },
      -> { measure(plane) { ROWS.times { |y| NC_FFI.ncplane_putstr_yx(ptr, y, 0, ascii_line) } } }],
    ["`putstr`, 100 glifi CJK per riga", "≤ 2x",
      -> { measure(plane) { ROWS.times { |y| plane.putstr(cjk_line, y: y, x: 0) } } },
      -> { measure(plane) { ROWS.times { |y| NC_FFI.ncplane_putstr_yx(ptr, y, 0, cjk_line) } } }],
    ["`putstr`, 200 \"e\" + accento combinante per riga", "≤ 3x",
      -> { measure(plane) { ROWS.times { |y| plane.putstr(accent_line, y: y, x: 0) } } },
      -> { measure(plane) { ROWS.times { |y| NC_FFI.ncplane_putstr_yx(ptr, y, 0, accent_line) } } }],
    ["`hline`, una per riga", "≤ 3x",
      -> { measure(plane) { ROWS.times { |y| plane.hline("-", COLS, y: y, x: 0) } } },
      lambda do
        with_nccell(ptr, "-") do |nc|
          measure(plane) do
            ROWS.times do |y|
              NC_FFI.ncplane_cursor_move_yx(ptr, y, 0)
              NC_FFI.ncplane_hline_interp(ptr, nc, COLS, 0, 0)
            end
          end
        end
      end],
    ["`vline`, una per colonna", "≤ 3x",
      -> { measure(plane) { COLS.times { |x| plane.vline("|", ROWS, y: 0, x: x) } } },
      lambda do
        with_nccell(ptr, "|") do |nc|
          measure(plane) do
            COLS.times do |x|
              NC_FFI.ncplane_cursor_move_yx(ptr, 0, x)
              NC_FFI.ncplane_vline_interp(ptr, nc, ROWS, 0, 0)
            end
          end
        end
      end],
    ["`putstr`, un EGC da 6 MB", "≤ 5x",
      -> { measure(plane, reps: BIG_REPS) { plane.putstr(BIG_EGC, y: 0, x: 0) } },
      -> { measure(plane, reps: BIG_REPS) { NC_FFI.ncplane_putstr_yx(ptr, 0, 0, BIG_EGC) } }]
  ]
end

def print_table(rows)
  puts "| Scrittura | Wrapper | FFI diretta | Rapporto | Obiettivo |"
  puts "| -- | -- | -- | -- | -- |"
  rows.each do |name, target, wrapper_ms, ffi_ms|
    puts format("| %s | %.1f ms | %.2f ms | %.1fx | %s |", name, wrapper_ms, ffi_ms, wrapper_ms / ffi_ms, target)
  end
end

options = {output: "/dev/null", termtype: "xterm-256color", suppress_banners: true, drain_input: true}
Notcurses::Context.open(**options) do |nc|
  plane = nc.stdplane.create_child(rows: ROWS, cols: COLS, y: 0, x: 0)
  puts "Ruby #{RUBY_VERSION}, notcurses #{Notcurses.lib_version}, piano #{ROWS}x#{COLS}, mediana di #{REPS} ripetizioni " \
       "(#{BIG_REPS} per l'EGC da 6 MB)"
  puts
  results = cases(plane).map do |name, target, wrapper, ffi|
    [name, target, wrapper.call, ffi.call]
  end
  print_table(results)
ensure
  plane&.family_destroy
end
