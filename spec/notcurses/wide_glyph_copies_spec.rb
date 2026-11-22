# Generated from notcurses 3.0.17
# Source: notcurses/src/lib/render.c
# frozen_string_literal: true

require_relative "../support/nc_helpers"

# Audit ICH-225: ogni punto d'ingresso del wrapper che arriva a
# cellcmp_and_dupfar di notcurses (copie di celle tra piani) viene esercitato
# con glifi larghi (anche tagliati dai bordi) ed EGC di più di 4 byte in un
# processo figlio sotto l'allocatore di debug di glibc. Una free sbagliata o un
# heap corrotto fanno abortire il figlio.
RSpec.describe "Copie di celle tra piani con glifi larghi" do
  # Parte comune degli script figli: glifi di 8 byte (larghi) e di 7 byte
  # (stretti) finiscono nell'egcpool; fill lascia buchi.
  common = <<~'RUBY'
    require 'notcurses'
    RNG = Random.new(1)
    WIDE = ["漢", "中", "\u{1F44D}\u{1F3FD}", "\u{1F469}\u{1F3FF}"].freeze
    NARROW = ['a', 'é', "é\u0302\u0303"].freeze
    OPTS = {output: '/dev/null', termtype: 'xterm-256color', suppress_banners: true, drain_input: true}.freeze

    def fill(plane, y)
      x = 0
      while x < plane.dim_x
        case RNG.rand(4)
        when 0 then x += 1
        when 1
          plane.putstr(NARROW.sample(random: RNG), y: y, x: x)
          x += 1
        else
          if x + 2 <= plane.dim_x
            plane.putstr(WIDE.sample(random: RNG), y: y, x: x)
            x += 2
          else
            x += 1
          end
        end
      end
    end
  RUBY

  # Corpo comune dei due esempi di render: MODE è "std" (Context#render) o
  # "pile" (Plane#render_pile su una seconda pila).
  render = <<~RUBY
    ALPHAS = %i[opaque blend transparent highcontrast].freeze
    Notcurses::Context.open(**OPTS) do |nc|
      _trows, tcols = nc.dims
      root = MODE == 'pile' ? nc.create_pile(rows: 5, cols: 30, y: 0, x: tcols - 30) : nc.stdplane
      planes = Array.new(4) do
        root.create_child(rows: RNG.rand(1..3), cols: RNG.rand(2..10), y: RNG.rand(0..2),
          x: (MODE == 'pile' ? 30 : tcols) - RNG.rand(1..12))
      end
      150.times do |i|
        planes.each do |pl|
          case RNG.rand(8)
          when 0 then pl.erase
          when 1, 2 then fill(pl, RNG.rand(pl.dim_y))
          when 3 then pl.move_rel(0, RNG.rand(-1..1))
          when 4 then pl.set_base(egc: ['', ' ', '.', '中'].sample(random: RNG))
          when 5 then RNG.rand(2).zero? ? pl.move_top : pl.move_bottom
          when 6
            pl.set_fg_alpha(ALPHAS.sample(random: RNG))
            pl.set_bg_alpha((ALPHAS - [:highcontrast]).sample(random: RNG))
          when 7
            pl.set_fg_rgb(RNG.rand(256), RNG.rand(256), RNG.rand(256))
            pl.set_bg_rgb(RNG.rand(256), RNG.rand(256), RNG.rand(256))
          end
        rescue Notcurses::Error, ArgumentError
          nil
        end
        if MODE == 'pile'
          root.render_pile
          nc.render if (i % 5).zero?
        else
          nc.render
        end
        3.times { nc.at(RNG.rand(0...4), tcols - 1 - RNG.rand(0...14)) }
      end
    end
    puts 'ok'
  RUBY

  before { skip "serve libc_malloc_debug di glibc" unless File.exist?(NcHelpers::MALLOC_DEBUG) }

  # reader.c:100 (ncreader_redraw)
  it "Reader: scritture e tasti con glifi larghi non corrompono l'heap" do
    script = common + <<~'RUBY'
      K = Notcurses::Key
      EV = ->(id, **o) { Notcurses::Input.synthesize(id, **o) }
      TEXTS = ['漢', '中文', 'a', 'ab ', ' ', "\u{1F44D}\u{1F3FD}", 'é', "e\u0301\u0302\u0303", '漢 字', 'x漢', '漢漢漢漢',
        "\t", "\u200B", "\uFE0F", "\u0301", "漢\t漢"].freeze
      Notcurses::Context.open(**OPTS) do |nc|
        40.times do
          plane = nc.stdplane.create_child(rows: RNG.rand(1..3), cols: RNG.rand(2..8), y: 1, x: 1)
          Notcurses::Reader.open(plane, no_cmd_keys: RNG.rand(6).zero?) do |reader|
            40.times do
              case RNG.rand(16)
              when 0..3 then reader.write(TEXTS.sample(random: RNG))
              when 4 then reader.offer_input(EV.(0x6f22))
              when 5 then reader.offer_input(EV.('a'.ord))
              when 6 then reader.offer_input(EV.(K::BACKSPACE))
              when 7 then reader.offer_input(EV.([K::LEFT, K::RIGHT, K::UP, K::DOWN].sample(random: RNG)))
              when 8 then reader.offer_input(EV.(%w[A E B F U W].sample(random: RNG).ord, modifiers: [:ctrl]))
              when 9 then reader.offer_input(EV.(%w[b f].sample(random: RNG).ord, modifiers: [:alt]))
              when 10 then reader.move_left
              when 11 then reader.move_right
              when 12 then reader.move_up
              when 13 then reader.move_down
              when 14 then reader.contents
              when 15 then nc.render
              end
            rescue Notcurses::Error
              nil
            end
          end
        end
      end
      puts 'ok'
    RUBY
    expect(NcHelpers.heap_check(script, timeout: 60)).to eq([0, "ok\n"])
  end

  # render.c:453 e 482 (ncpile_rasterize, da notcurses_render)
  it "Context#render: piani con glifi larghi tagliati dai bordi non corrompono l'heap" do
    expect(NcHelpers.heap_check("MODE = 'std'\n" + common + render, timeout: 60)).to eq([0, "ok\n"])
  end

  # render.c:453 e 482 (ncpile_rasterize, da ncpile_render)
  it "Plane#render_pile: una seconda pila con glifi larghi non corrompe l'heap" do
    expect(NcHelpers.heap_check("MODE = 'pile'\n" + common + render, timeout: 60)).to eq([0, "ok\n"])
  end

  # render.c:453 e 482 (fade_steps -> ncplane_render_pile)
  it "Plane: fadeout, fadein e pulse con glifi larghi non corrompono l'heap" do
    script = common + <<~RUBY
      Notcurses::Context.open(**OPTS) do |nc|
        std = nc.stdplane
        _rows, cols = std.dims
        std.putstr('漢' * (cols / 2), y: 0, x: 0)
        10.times do |i|
          pl = std.create_child(rows: 2, cols: 9, y: 0, x: cols - 9 + (i % 5) - 1)
          pl.set_fg_rgb(200, 100, 50)
          pl.set_bg_rgb(10, 20, 30)
          2.times { |y| fill(pl, y) }
          pl.fadeout(0.002)
          pl.fadein(0.002)
          n = 0
          pl.pulse(0.002) { (n += 1) >= 6 ? :stop : nil }
          pl.close
        rescue Notcurses::Error, ArgumentError
          nil
        end
      end
      puts 'ok'
    RUBY
    expect(NcHelpers.heap_check(script, timeout: 60)).to eq([0, "ok\n"])
  end

  # notcurses.c:1807-1809 (ncplane_scrollup) e 1978-1981 (ncplane_put)
  it "Plane: scritture sullo stdplane che scorre con glifi larghi non corrompono l'heap" do
    script = common + <<~'RUBY'
      Notcurses::Context.open(**OPTS) do |nc|
        std = nc.stdplane
        std.scrolling = true
        rows, cols = std.dims
        200.times do |i|
          case i % 10
          when 6 then (cols / 2 + 2).times { std.putegc(WIDE.sample(random: RNG)) }
          when 7 then (cols / 2 + 2).times { std.putc(Notcurses::Cell.new(egc: '漢')) }
          when 8 then std.printf('%s%s', '字' * (cols / 2), "\n")
          when 9
            std.putstr('漢' * (cols / 2), y: rows - 1, x: 0)
            std.hline('-', cols + 4, y: rows - 1, x: 1)
          when 0 then std.putstr(('漢' * (cols / 2)) + "\n")
          when 1 then std.putstr('a' + (WIDE.sample(random: RNG) * (cols / 2)))
          when 2 then std.scrollup(lines: RNG.rand(1..3))
          when 3 then std.puttext("中文 é\u0302\u0303 " * 40)
          when 4
            child = std.create_child(rows: 2, cols: 10, y: rows - 1, x: cols - 9)
            child.putstr('漢字漢字漢')
            std.scrollup_child(child)
            child.close
          when 5
            std.putstr("\u{1F44D}\u{1F3FD}" * (cols / 2), y: rows - 1, x: 1)
            std.putstr("\n")
          end
        rescue Notcurses::Error, ArgumentError
          nil
        end
      end
      puts 'ok'
    RUBY
    expect(NcHelpers.heap_check(script, timeout: 60)).to eq([0, "ok\n"])
  end

  # visual.c:1257 (ncvisual_simple_streamer -> notcurses_render)
  it "Visual#stream senza blocco: un piano con glifi larghi sotto il video non corrompe l'heap" do
    fixtures = File.expand_path("../fixtures/visual", __dir__)
    script = "FIX = #{fixtures.inspect}\n" + common + <<~RUBY
      Notcurses::Context.open(**OPTS) do |nc|
        std = nc.stdplane
        _rows, cols = std.dims
        3.times { |y| std.putstr('漢' * (cols / 2), y: y, x: 0) }
        8.times do |i|
          pl = std.create_child(rows: 3, cols: 9, y: 0, x: (i % 2).zero? ? (i % 9) : cols - 5 - (i % 5))
          pl.putstr('中中中中', y: 2, x: 0)
          path = File.join(FIX, (i % 3).zero? ? 'frames.mkv' : 'rgbw.png')
          Notcurses::Visual.open(path) { |v| v.stream(plane: pl, blitter: :ascii, timescale: 0.001) }
          pl.close
        rescue Notcurses::Error, ArgumentError
          nil
        end
      end
      puts 'ok'
    RUBY
    expect(NcHelpers.heap_check(script, timeout: 60)).to eq([0, "ok\n"])
  end

  # render.c:600 (ncplane_mergedown_simple -> postpaint)
  it "Plane#merge_down: glifi larghi tagliati dai bordi di dst non corrompono l'heap" do
    script = common + <<~RUBY
      Notcurses::Context.open(**OPTS) do |nc|
        std = nc.stdplane
        150.times do |i|
          drows = RNG.rand(1..2)
          dcols = RNG.rand(1..6)
          dst = std.create_child(rows: drows, cols: dcols, y: 1, x: 6)
          src = std.create_child(rows: RNG.rand(1..2), cols: RNG.rand(2..9), y: 1 + RNG.rand(-1..1), x: 6 + RNG.rand(-5..4))
          dst.set_base(egc: '.') if RNG.rand(4).zero?
          src.dim_y.times { |y| fill(src, y) }
          drows.times { |y| fill(dst, y) } if dcols > 1 && RNG.rand(2).zero?
          src.merge_down(dst)
          drows.times do |y|
            dcols.times { |x| dst.at(y: y, x: x) }
            dst.contents
            (0...dcols).to_a.shuffle(random: RNG).each do |x|
              egc = RNG.rand(3).zero? && x + 2 <= dcols ? '漢' : 'x'
              begin
                dst.putstr(egc, y: y, x: x)
              rescue Notcurses::Error
                nil
              end
              dst.at(y: y, x: x)
            end
          end
          nc.render if (i % 10).zero?
          src.close
          dst.close
        end
      end
      puts 'ok'
    RUBY
    expect(NcHelpers.heap_check(script, timeout: 60)).to eq([0, "ok\n"])
  end
end
