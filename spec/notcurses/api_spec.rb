# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require 'notcurses'

# Convenzioni dell'API pubblica, controllate per riflessione su tutte le classi
# e i moduli del wrapper (FFI e Util esclusi: sono interni).
RSpec.describe 'API pubblica' do
  def api_modules(mod = Notcurses, seen = [])
    return seen if seen.include?(mod) || [Notcurses::FFI, Notcurses::Util].include?(mod)

    seen << mod
    mod.constants(false).each do |name|
      value = mod.const_get(name, false)
      api_modules(value, seen) if value.is_a?(Module) && value.name&.start_with?('Notcurses::')
    end
    seen
  end

  # [nome, parametri] dei metodi pubblici di istanza e di classe, e di new.
  def public_signatures
    api_modules.flat_map do |mod|
      own = mod.public_instance_methods(false).map { |m| ["#{mod}##{m}", mod.instance_method(m).parameters] }
      own += mod.singleton_class.public_instance_methods(false).map { |m| ["#{mod}.#{m}", mod.method(m).parameters] }
      if mod.is_a?(Class) && mod.private_instance_methods(false).include?(:initialize)
        own << ["#{mod}.new", mod.instance_method(:initialize).parameters]
      end
      own
    end
  end

  it 'regola 7: nessun metodo pubblico ha posizionali opzionali (le opzioni con un default sono keyword)' do
    internal = %w[Notcurses::Cell.egc! Notcurses::Cell.from_c] # @api private
    offenders = public_signatures.reject { |name, _| internal.include?(name) }
                                 .select { |_, params| params.any? { |type, _| type == :opt } }
    expect(offenders.map(&:first).sort).to eq([])
  end

  it 'regola 5: le keyword dei colori sono in snake_case (op_channels:, non opchannels:)' do
    glued = public_signatures.flat_map do |name, params|
      params.filter_map { |type, key| "#{name}(#{key}:)" if %i[key keyreq].include?(type) && key.match?(/[a-z]channels?\z/) }
    end
    expect(glued.sort).to eq([])
  end

  it 'i widget con una lista navigabile hanno size, next e prev con lo stesso nome' do
    [Notcurses::Reel, Notcurses::Tabbed, Notcurses::Tree].each do |klass|
      expect(%i[size next prev].reject { |m| klass.method_defined?(m) }).to eq([]), klass.name
    end
  end
end
