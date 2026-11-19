# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require "notcurses"

RSpec.describe Notcurses::Guard do
  # Radice finta: registra le chiusure fisiche; error la fa fallire.
  let(:root_class) do
    Class.new do
      attr_reader :releases
      attr_accessor :error

      def initialize
        @releases = 0
      end

      def release_native!
        @releases += 1
        raise error if error

        nil
      end
    end
  end
  let(:root) { root_class.new }

  it "conta le operazioni in corso, anche annidate, e restituisce il valore del blocco" do
    expect(described_class.busy).to eq(0)
    value = described_class.run do
      described_class.run { expect(described_class.busy).to eq(2) }
      expect(described_class.busy).to eq(1)
      :done
    end
    expect(value).to eq(:done)
    expect(described_class.busy).to eq(0)
  end

  it "esegue una chiusura in coda all'uscita dell'ultima operazione, una sola volta" do
    described_class.run do
      described_class.run do
        described_class.defer(root)
        described_class.settle_if_idle
      end
      expect(root.releases).to eq(0)
    end
    expect(root.releases).to eq(1)
    described_class.settle_if_idle
    expect(root.releases).to eq(1)
  end

  it "senza operazioni in corso settle_if_idle esegue subito la chiusura" do
    described_class.defer(root)
    described_class.settle_if_idle
    expect(root.releases).to eq(1)
  end

  it "l'errore della chiusura rinviata esce dall'operazione che la esegue" do
    root.error = Notcurses::ContextError.new("stop fallito")
    expect do
      described_class.run { described_class.defer(root) }
    end.to raise_error(Notcurses::ContextError, "stop fallito")
    expect(described_class.busy).to eq(0)
  end

  it "con un'eccezione già in volo l'errore della chiusura diventa un avviso" do
    root.error = Notcurses::ContextError.new("stop fallito")
    expect do
      described_class.run do
        described_class.defer(root)
        raise ArgumentError, "dal blocco"
      end
    end.to raise_error(ArgumentError, "dal blocco")
      .and output(/chiusura rinviata fallita: stop fallito/).to_stderr
    expect(root.releases).to eq(1)
  end

  it "un'eccezione del blocco non lascia il contatore alto" do
    expect { described_class.run { raise "boom" } }.to raise_error(RuntimeError, "boom")
    expect(described_class.busy).to eq(0)
  end
end
