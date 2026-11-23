# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative '../../support/nc_helpers'

RSpec.describe Notcurses::UI::LogView do
  include_context 'con un contesto notcurses'

  let(:app) { Notcurses::UI::App.new(nc) }

  after { app.close }

  def log(rows, cols: 12, **opts)
    row = Notcurses::UI::Container.new(app.root, direction: :horizontal, size: rows)
    described_class.new(row, size: cols, **opts)
  end

  def lines(component) = Array.new(component.plane.dim_y) { |y| component.plane.contents(y: y, rows: 1) }

  it 'mostra le ultime righe; la riga non finita resta da parte e si vede in fondo' do
    view = log(3)
    expect(view.append("uno\ndue\n")).to equal(view)
    expect(lines(view)).to eq(['uno', 'due', ''])
    view.append("tre\nquat")
    expect(lines(view)).to eq(%w[due tre quat])
    view.append("tro\n")
    expect(lines(view)).to eq(%w[due tre quattro])
    expect(view.lines).to eq(%w[uno due tre quattro])
    expect(view).not_to be_focusable
  end

  it 'byte grezzi: un carattere UTF-8 spezzato fra due blocchi si ricompone; UTF-8 non valido diventa "?"' do
    view = log(2)
    bytes = 'é漢'.b
    view.append(bytes[0, 1])
    view.append(bytes[1..] + "\n")
    view.append("a\xffb\n".b)
    expect(lines(view)).to eq(%W[é漢 a?b])
    expect(view.lines).to eq(%W[é漢 a�b])
  end

  it 'caratteri di controllo e U+2028 diventano "?", TAB diventa spazi, "\r\n" vale "\n"' do
    view = log(3, cols: 20)
    view.append("a\tb\r\n")
    view.append("x\u0001y\u2028z\e[0m\n")
    view.append("\u0301solo\n")
    expect(lines(view)).to eq(["a       b", 'x?y?z?[0m', '?solo'])
  end

  # Review mirata di ICH-232: con l'egcpool pieno putstr solleva PlaneError, che il ripiego di put_text non prendeva.
  it "con l'egcpool pieno un EGC lungo diventa \"?\": append non solleva" do
    view = log(3, cols: 4)
    big = ->(c) { "#{c}#{"\u0301" * 3_000_000}\n" }
    expect { view.append(%w[a b c].map(&big).join) }.not_to raise_error
    expect(lines(view).map(&:bytesize)).to eq([6_000_001, 6_000_001, 1])
    expect(lines(view).last).to eq('?')
  end

  it 'un keycap, che notcurses 3.0.17 divide con un pezzo largo 0, diventa "?": i byte grezzi non sono rifiutati' do
    view = log(1, cols: 12)
    view.append("1\uFE0F\u20E3 ok\n")
    expect([view.lines, lines(view)]).to eq([["1\uFE0F\u20E3 ok"], ['? ok']])
  end

  it 'tiene al massimo max_lines righe finite; clear toglie tutto' do
    view = log(5, max_lines: 3)
    view.append((1..6).map { |i| "r#{i}\n" }.join)
    view.append('parz')
    expect(view.max_lines).to eq(3)
    expect(view.lines).to eq(%w[r4 r5 r6 parz])
    expect(lines(view)).to eq(%w[r4 r5 r6 parz] + [''])
    expect(view.clear).to equal(view)
    expect(view.lines).to eq([])
    expect(lines(view)).to eq([''] * 5)
  end

  it 'append con una stringa vuota non cambia le righe, anche con una riga non finita (ICH-282)' do
    view = log(3)
    expect(view.append('')).to equal(view) # vista nuova
    expect(view.lines).to eq([])
    view.append("x\n")
    expect(view.append('')).to equal(view) # dopo una riga finita
    expect(view.lines).to eq(%w[x])
    view.clear
    expect(view.append('')).to equal(view) # dopo clear
    expect(view.lines).to eq([])
    view.append('par')
    view.append('') # con una riga non finita
    view.append("tial\n")
    expect(view.lines).to eq(%w[partial])
    view.append('')
    view.append("next\n")
    expect(view.lines.last).to eq('next')
    view.parent.layout(3, 12)
    app.root.layout(*nc.dims)
    expect(lines(view)).to eq(['partial', 'next', ''])
  end

  it 'il layout ridisegna dalle righe in memoria: un piano più basso mostra le ultime' do
    view = log(4)
    view.append("1\n2\n3\n4\n")
    view.layout(2, 12)
    expect(lines(view)).to eq(%w[3 4])
    view.layout(4, 12)
    expect(lines(view)).to eq(%w[1 2 3 4])
  end

  # ICH-230: la riga non finita ha un limite in byte e "\r" sostituisce la riga.
  def partial_bytes(view) = view.instance_variable_get(:@partial).bytesize

  it '1 MiB senza "\n" lascia la riga non finita entro max_partial_bytes (default 65 536)' do
    view = log(1)
    expect(view.max_partial_bytes).to eq(65_536)
    256.times { view.append('x' * 4096) }
    expect(partial_bytes(view)).to eq(65_536)
    view.append('y' * 1_048_576) # anche in un solo blocco
    expect(view.lines).to eq(['y' * 65_536])
    expect(lines(view)).to eq(['y' * 12])
  end

  it 'oltre il limite toglie i byte più vecchi senza spezzare un carattere UTF-8' do
    view = log(1, max_partial_bytes: 4)
    view.append('a漢字') # 7 byte: il taglio a 3 cade dentro 漢
    expect(view.lines).to eq(['字'])
    emoji = '😀'.b
    view.append(emoji[0, 2]) # metà di 😀 in coda: il taglio non la tocca
    view.append(emoji[2..])
    expect([view.lines, lines(view)]).to eq([['😀'], ['😀']])
    view.append("\n#{"\x80" * 10}".b) # UTF-8 non valido: salta al massimo 3 byte di continuazione
    expect([view.lines.last, partial_bytes(view)]).to eq(["�", 1])
  end

  it '"\r" senza "\n": la vista mostra il testo più recente e la memoria resta limitata' do
    view = log(2)
    view.append("10%\r20%\r30%")
    expect(lines(view)).to eq(['30%', ''])
    view.append("\r40%\r") # un "\r" in coda non cancella niente
    expect([view.lines, lines(view)]).to eq([['40%'], ['40%', '']])
    1000.times { |i| view.append("\r#{i}%") }
    expect([view.lines, partial_bytes(view)]).to eq([['999%'], 4])
    view.append("\r") # "\r\n" in due blocchi vale "\n"
    view.append("\n")
    expect([view.lines, lines(view)]).to eq([['999%'], ['999%', '']])
  end

  # Review di ICH-230: i "\r" in coda contavano nel limite, e il taglio toglieva il testo.
  it 'i "\r" in coda oltre il limite non cancellano il testo della riga non finita' do
    view = log(1, max_partial_bytes: 4)
    view.append("abc\r\r\r\r\r")
    expect(view.lines).to eq(['abc'])
    view.append("\n")
    expect(view.lines).to eq(['abc'])
    view = log(1)
    view.append('progress 50%')
    100.times { view.append("\r" * 1000) } # 100 000 byte di "\r", oltre il default
    expect([view.lines, partial_bytes(view)]).to eq([['progress 50%'], 13])
    # review mirata: il "\r" in coda non conta nel limite, anche con un testo lungo quanto il limite
    %w[😀 abcd].each do |text|
      view = log(1, max_partial_bytes: 4)
      [text, "\r", "\n"].each { |data| view.append(data) }
      expect(view.lines).to eq([text])
    end
  end

  it '"\r" vale anche nelle righe finite: resta l\'ultimo pezzo non vuoto' do
    view = log(3)
    view.append("10%\r20%\nok\r\r\n\r\n")
    expect([view.lines, lines(view)]).to eq([['20%', 'ok', ''], ['20%', 'ok', '']])
  end

  it 'valida gli argomenti; chiuso solleva ClosedError' do
    view = log(1)
    expect { view.append(:x) }.to raise_error(TypeError)
    expect { described_class.new(app.root, max_lines: 0) }.to raise_error(ArgumentError)
    expect { described_class.new(app.root, max_partial_bytes: 3) }.to raise_error(ArgumentError)
    expect { described_class.new(app.root, max_partial_bytes: '4') }.to raise_error(TypeError)
    view.close
    expect { view.append('x') }.to raise_error(Notcurses::ClosedError)
    expect { view.clear }.to raise_error(Notcurses::ClosedError)
  end
end
