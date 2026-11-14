# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require 'notcurses'

# Contenuto e metadati della gem: solo i file che servono, una sola dipendenza
# runtime (regola 10), versione allineata a Notcurses::VERSION e al changelog.
RSpec.describe 'notcursesruby.gemspec' do
  root = File.expand_path('..', __dir__)
  spec = Gem::Specification.load(File.join(root, 'notcursesruby.gemspec'))

  it 'contiene ogni file di lib/ e nessun file interno' do
    lib = Dir.glob('lib/**/*.rb', base: root)
    expect(spec.files).to include(*lib)
    expect(spec.files).to include('README.md', 'LICENSE', 'NOTICE', 'CHANGELOG.md', '.yardopts', 'examples/demo.rb')
    internal = spec.files.grep(%r{\A(spec|memory|notcurses|libnotcurses-sys|\.github)/|\A(RICONSEGNA|RIPRESA|CLAUDE)})
    expect(internal).to be_empty
    expect(spec.files.reject { |f| File.file?(File.join(root, f)) }).to be_empty
  end

  it 'dipende solo da ffi, con lo stesso vincolo del Gemfile' do
    expect(spec.runtime_dependencies.map { |d| [d.name, d.requirement.to_s] }).to eq([['ffi', '~> 1.16']])
    expect(File.read(File.join(root, 'Gemfile'))).to match(/^gem 'ffi', '~> 1\.16'$/)
    expect(spec.required_ruby_version.to_s).to eq('>= 3.1')
  end

  it 'ha la versione di Notcurses::VERSION e della prima voce del changelog' do
    expect(spec.version.to_s).to eq(Notcurses::VERSION)
    changelog = File.read(File.join(root, 'CHANGELOG.md'))
    expect(changelog[/^## \[(\d+\.\d+\.\d+)\]/, 1]).to eq(Notcurses::VERSION)
  end
end
