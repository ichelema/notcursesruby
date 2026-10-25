# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require 'notcurses'

RSpec.describe 'Notcurses versione' do
  it 'VERSION è la versione della gem' do
    expect(Notcurses::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  it 'lib_version è la versione caricata, in UTF-8' do
    v = Notcurses.lib_version
    expect(v).to match(/\A\d+\.\d+\.\d+/)
    expect(v.encoding).to eq(Encoding::UTF_8)
  end

  it 'lib_version_components coincide con lib_version' do
    major, minor, patch, _tweak = Notcurses.lib_version_components
    expect(Notcurses.lib_version).to start_with("#{major}.#{minor}.#{patch}")
  end

  it 'HEADER_VERSION è quella del layer FFI' do
    expect(Notcurses::HEADER_VERSION).to eq('3.0.17')
  end

  it 'version_comparable valida e calcola il numero ordinato' do
    expect(Notcurses.version_comparable(3, 0, 17)).to eq(Notcurses::FFI::NOTCURSES_VERNUM_ORDERED)
    expect { Notcurses.version_comparable(256, 0, 0) }.to raise_error(ArgumentError)
    expect { Notcurses.version_comparable('3', 0, 0) }.to raise_error(TypeError)
  end
end
