# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
require 'rspec'
require 'notcurses/ffi'

RSpec.describe Notcurses::FFI do
  it 'loads the library without error' do
    expect { Notcurses::FFI }.not_to raise_error
  end

  it 'returns a version string' do
    version = Notcurses::FFI.notcurses_version
    expect(version).to be_a(String)
    expect(version).to match(/\d+\.\d+\.\d+/)
  end

  it 'can init and stop without crash' do
    # usa /dev/null come output per evitare di prendere il terminale
    opts = Notcurses::FFI::NotcursesOptions.new
    fp = Notcurses::FFI.fopen("/dev/null", "w")
    nc = Notcurses::FFI.notcurses_init(opts, fp)
    expect(nc).not_to be_null
    result = Notcurses::FFI.notcurses_stop(nc)
    expect(result).to eq(0)
    Notcurses::FFI.fclose(fp)
  end
end
