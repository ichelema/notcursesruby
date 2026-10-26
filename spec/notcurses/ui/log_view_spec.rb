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
    view.append("x\u0001y z\e[0m\n")
    view.append("́solo\n")
    expect(lines(view)).to eq(["a       b", 'x?y?z?[0m', '?solo'])
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

  it 'il layout ridisegna dalle righe in memoria: un piano più basso mostra le ultime' do
    view = log(4)
    view.append("1\n2\n3\n4\n")
    view.layout(2, 12)
    expect(lines(view)).to eq(%w[3 4])
    view.layout(4, 12)
    expect(lines(view)).to eq(%w[1 2 3 4])
  end

  it 'valida gli argomenti; chiuso solleva ClosedError' do
    view = log(1)
    expect { view.append(:x) }.to raise_error(TypeError)
    expect { described_class.new(app.root, max_lines: 0) }.to raise_error(ArgumentError)
    view.close
    expect { view.append('x') }.to raise_error(Notcurses::ClosedError)
    expect { view.clear }.to raise_error(Notcurses::ClosedError)
  end
end
