# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative '../support/nc_helpers'

RSpec.describe Notcurses::Stats do
  include_context 'con un contesto notcurses'

  it 'copia tutti i campi in un oggetto congelato' do
    nc.render
    stats = nc.stats
    expect(stats).to be_frozen
    expect(stats.to_h.keys).to eq(described_class::FIELDS)
    expect(stats.renders).to be >= 1
    expect(stats.planes).to be >= 1
    expect(stats.render_min_ns).to be_a(Integer)
    expect(stats).to eq(described_class.new(stats_struct(stats)))
    expect(stats.hash).to eq(described_class.new(stats_struct(stats)).hash)
    expect(stats.inspect).to include('renders=')
  end

  it 'reset_stats restituisce i valori precedenti e azzera i cumulativi' do
    nc.render
    before = nc.reset_stats
    after = nc.stats
    expect(before.renders).to be >= 1
    expect(after.renders).to eq(0)
    # finché non ci sono campioni il C mette 1 << 62 nei minimi: il wrapper restituisce nil
    expect(after.render_min_ns).to be_nil
    expect(after.raster_min_bytes).to be_nil
    expect(after.raster_min_ns).to be_nil
    expect(after.writeout_min_ns).to be_nil
    expect(after.planes).to eq(before.planes)
  end

  it 'rifiuta una struct di tipo sbagliato' do
    expect { described_class.new(:x) }.to raise_error(TypeError)
  end

  it 'accountname, hostname e osversion restituiscono stringhe UTF-8' do
    %i[accountname hostname osversion].each do |m|
      value = Notcurses.public_send(m)
      expect(value).to be_a(String).or be_nil
      expect(value.encoding).to eq(Encoding::UTF_8) if value
    end
    expect(Notcurses.osversion).to start_with('Linux')
  end

  it 'accountname sostituisce con U+FFFD i byte di LOGNAME che non sono UTF-8' do
    old = ENV.fetch('LOGNAME', nil)
    ENV['LOGNAME'] = "Jos\xE9".b # nome Latin-1
    name = Notcurses.accountname
    expect(name).to eq('Jos�')
    expect(name).to be_valid_encoding
  ensure
    ENV['LOGNAME'] = old
  end

  it 'take_string sostituisce i byte non UTF-8 e lascia invariato il testo valido' do
    expect(Notcurses::Util.take_string(Notcurses::FFI.strdup("a\xFFb".b))).to eq('a�b')
    expect(Notcurses::Util.take_string(Notcurses::FFI.strdup('kitty 0.35.2'))).to eq('kitty 0.35.2')
  end

  # Struct ncstats con i valori di stats (per provare il costruttore).
  def stats_struct(stats)
    st = Notcurses::FFI::NcStats.new
    stats.to_h.each { |k, v| st[k] = v.nil? ? 1 << 62 : v }
    st
  end
end
