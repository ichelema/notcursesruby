# Generated from notcurses 3.0.17
# Source: notcurses/src/lib/notcurses.c
# frozen_string_literal: true

require_relative "../support/nc_helpers"

# ICH-594: le scritture di Plane leggono lo stato del piano una volta sola e
# segmentano il testo in grapheme una volta sola. Le spec contano le chiamate,
# senza soglie di tempo: un'esecuzione lenta non le fa fallire.
RSpec.describe Notcurses::Plane, "costo delle scritture" do
  include_context "con un contesto notcurses"

  # Funzioni FFI che leggono lo stato del piano, per tipo di stato. Si contano
  # le funzioni del C: ncplane_dim_x e ncplane_dim_y, ncplane_cursor_x e
  # ncplane_cursor_y sono reimplementate in Ruby sopra ncplane_dim_yx e
  # ncplane_cursor_yx (inline_reimpl.rb), e una lettura varrebbe due volte.
  def state_functions
    {
      dims: %i[ncplane_dim_yx],
      cursor: %i[ncplane_cursor_yx],
      scrolling: %i[ncplane_scrolling_p],
      autogrow: %i[ncplane_autogrow_p],
      width: %i[ncstrwidth],
      load: %i[nccell_load]
    }
  end

  # Esegue il blocco e conta le letture dello stato del piano per tipo, le
  # misure di larghezza del C (ncstrwidth) e le passate di Ruby sul testo in
  # grapheme (each_grapheme_cluster e grapheme_clusters).
  #
  # @return [Hash{Symbol => Integer}] zero per ciò che il blocco non chiama
  def count_work
    counts = Hash.new(0)
    active = true
    state_functions.each do |kind, names|
      names.each do |name|
        allow(Notcurses::FFI).to receive(name).and_wrap_original do |original, *args|
          counts[kind] += 1 if active
          original.call(*args)
        end
      end
    end
    segmenting = %i[each_grapheme_cluster grapheme_clusters]
    trace = TracePoint.new(:c_call) do |tp|
      counts[:graphemes] += 1 if tp.defined_class == String && segmenting.include?(tp.method_id)
    end
    begin
      trace.enable { yield }
    ensure
      active = false
    end
    counts
  end

  # Al massimo una lettura per tipo di stato.
  def expect_single_read(counts)
    %i[dims cursor scrolling autogrow].each do |kind|
      expect(counts[kind]).to be <= 1, "#{kind}: #{counts[kind]} letture invece di una al massimo"
    end
  end

  # Al massimo una passata di Ruby sul testo in grapheme.
  def expect_single_segmentation(counts)
    expect(counts[:graphemes]).to be <= 1, "#{counts[:graphemes]} passate sul testo in grapheme invece di una al massimo"
  end

  # Piano figlio dello stdplane, distrutto con la sua famiglia alla fine.
  def with_plane(rows: 10, cols: 200, **opts)
    plane = nc.stdplane.create_child(rows: rows, cols: cols, y: 0, x: 0, **opts)
    yield plane
  ensure
    plane.family_destroy if plane && !plane.closed?
  end

  describe "una cella" do
    it "putegc con un carattere ASCII e (y, x) legge lo stato una volta" do
      with_plane do |p|
        counts = count_work { p.putegc("x", y: 1, x: 2) }
        expect_single_read(counts)
        expect_single_segmentation(counts)
        expect(counts[:width]).to be <= 1
        expect(p.at(y: 1, x: 2).egc).to eq("x")
      end
    end

    it "putegc dal cursore, con un accento e con un carattere largo, legge lo stato una volta" do
      with_plane do |p|
        ["é", "e\u0301", "漢"].each do |egc|
          counts = count_work { p.putegc(egc) }
          expect_single_read(counts)
          expect_single_segmentation(counts)
          expect(counts[:width]).to be <= 1
        end
      end
    end

    it "putegc non ricontrolla un EGC breve che ha già scritto" do
      with_plane do |p|
        ["é", "漢"].each do |egc|
          p.putegc(egc, y: 1, x: 2)
          counts = count_work { p.putegc(egc, y: 1, x: 4) }
          expect(counts[:load]).to eq(0)
          expect(counts[:width]).to eq(0)
          expect(p.at(y: 1, x: 4).egc).to eq(egc)
        end
      end
    end

    it "putegc non ricorda un EGC rifiutato: lo rifiuta ogni volta" do
      with_plane do |p|
        2.times do
          expect { p.putegc("\u0301", y: 1, x: 2) }.to raise_error(ArgumentError, /larghezza zero/)
          expect { p.putegc("é", y: 1, x: 2, stained: :si) }.to raise_error(TypeError)
        end
        expect(p.putegc("é", y: 1, x: 2)).to eq(1)
      end
    end

    it "putegc con stained legge lo stato una volta" do
      with_plane do |p|
        counts = count_work { p.putegc("x", y: 1, x: 2, stained: true) }
        expect_single_read(counts)
        expect_single_segmentation(counts)
      end
    end

    it "putc legge lo stato una volta" do
      with_plane do |p|
        cell = Notcurses::Cell.new(egc: "x")
        counts = count_work { p.putc(cell, y: 1, x: 2) }
        expect_single_read(counts)
        expect_single_segmentation(counts)
        expect(p.at(y: 1, x: 2).egc).to eq("x")
      end
    end
  end

  describe "linee" do
    it "hline legge lo stato una volta" do
      with_plane do |p|
        counts = count_work { p.hline("-", 10, y: 1, x: 0) }
        expect_single_read(counts)
        expect_single_segmentation(counts)
        expect(p.at(y: 1, x: 9).egc).to eq("-")
      end
    end

    it "hline dal cursore legge lo stato una volta" do
      with_plane do |p|
        counts = count_work { p.hline("-", 10) }
        expect_single_read(counts)
      end
    end

    it "vline legge lo stato una volta" do
      with_plane do |p|
        counts = count_work { p.vline("|", 5, y: 0, x: 3) }
        expect_single_read(counts)
        expect_single_segmentation(counts)
        expect(p.at(y: 4, x: 3).egc).to eq("|")
      end
    end
  end

  describe "testo" do
    {
      "ASCII" => "ciao mondo",
      "caratteri larghi" => "漢字漢字漢字",
      "lettere con un accento combinante" => "e\u0301" * 5
    }.each do |name, text|
      it "putstr con #{name} legge lo stato una volta e misura la larghezza una volta" do
        with_plane do |p|
          counts = count_work { p.putstr(text, y: 1, x: 2) }
          expect_single_read(counts)
          expect_single_segmentation(counts)
          expect(counts[:width]).to be <= 1
          expect(p.cursor).to eq([1, 2 + Notcurses.strwidth(text)])
        end
      end

      it "putstr dal cursore con #{name} legge lo stato una volta" do
        with_plane do |p|
          counts = count_work { p.putstr(text) }
          expect_single_read(counts)
          expect_single_segmentation(counts)
          expect(counts[:width]).to be <= 1
        end
      end
    end

    it "putstr con align: legge lo stato una volta" do
      with_plane do |p|
        counts = count_work { p.putstr("ciao", y: 1, align: :center) }
        expect_single_read(counts)
        expect_single_segmentation(counts)
      end
    end

    it "printf legge lo stato una volta" do
      with_plane do |p|
        counts = count_work { p.printf("%s-%d", "ab", 3, y: 1, x: 0) }
        expect_single_read(counts)
        expect_single_segmentation(counts)
        expect(p.cursor).to eq([1, 4])
      end
    end

    it "puttext su tre righe legge lo stato una volta" do
      with_plane(rows: 5, cols: 12) do |p|
        counts = count_work { p.puttext("uno due tre quattro cinque sei", y: 0) }
        expect_single_read(counts)
        expect_single_segmentation(counts)
        expect(p.at(y: 2, x: 0).egc).to eq("c")
      end
    end

    it "putstr su un piano che non scorre non rilegge lo stato fra due segmenti" do
      long = "\u0301" * 3
      with_plane(rows: 2, cols: 10) do |p|
        counts = count_work { p.putstr("a#{long}b#{long}cde", y: 0, x: 0) }
        expect_single_read(counts)
        expect_single_segmentation(counts)
        expect(p.cursor).to eq([0, 5])
      end
    end

    it "putstr con uno ZWJ spezza il testo e misura i pezzi senza segmentare di nuovo" do
      text = "👩\u200D🚀abc"
      with_plane do |p|
        counts = count_work { p.putstr(text, y: 1, x: 0) }
        expect_single_read(counts)
        expect_single_segmentation(counts)
        expect(p.cursor).to eq([1, Notcurses.strwidth(text)])
      end
    end

    it "putstr con un EGC da 6 MB segmenta il testo e misura la larghezza una volta" do
      with_plane(rows: 2, cols: 10) do |p|
        counts = count_work { p.putstr(NcHelpers.big_egc, y: 0, x: 0) }
        expect_single_read(counts)
        expect_single_segmentation(counts)
        expect(counts[:width]).to be <= 1
        expect(p.cursor).to eq([0, 1])
      end
    end
  end

  describe "su un piano che scorre o cresce" do
    it "putstr di un testo che entra legge lo stato una volta" do
      with_plane(rows: 3, cols: 20, vscroll: true) do |p|
        counts = count_work { p.putstr("ciao", y: 1, x: 2) }
        expect_single_read(counts)
        expect_single_segmentation(counts)
      end
    end

    it "putstr su un piano che cresce a destra scrive tutto il testo anche con più segmenti" do
      long = "\u0301" * 3
      with_plane(rows: 1, cols: 3, autogrow: true) do |p|
        expect(p.putstr("a#{long}b#{long}cde", y: 0, x: 0)).to eq(5)
        expect(p.dims).to eq([1, 5])
        expect(%w[a b c d e].each_with_index.map { |egc, x| p.at(y: 0, x: x).egc[0] == egc }).to all(be(true))
      end
    end
  end
end
