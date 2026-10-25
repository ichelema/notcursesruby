# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require 'notcurses'

RSpec.describe Notcurses::Error do
  it 'è la radice di tutte le eccezioni del wrapper' do
    expect(described_class.superclass).to eq(StandardError)
    [Notcurses::InitError, Notcurses::ClosedError, Notcurses::RenderError, Notcurses::ContextError,
     Notcurses::PlaneError, Notcurses::CellError, Notcurses::VisualError, Notcurses::InputError,
     Notcurses::WidgetError, Notcurses::DirectError].each do |klass|
      expect(klass.superclass).to eq(described_class)
      expect { raise klass, 'messaggio' }.to raise_error(described_class, 'messaggio')
    end
  end
end
