# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

# La versione si legge dal file: version.rb usa le costanti FFI, e un require
# caricherebbe libnotcurses anche solo per costruire la gem.
version = File.read(File.join(__dir__, 'lib/notcurses/version.rb'))[/^\s*VERSION = '([^']+)'/, 1] or
  raise 'Notcurses::VERSION non trovato in lib/notcurses/version.rb'

Gem::Specification.new do |spec|
  spec.name     = 'notcursesruby'
  spec.version  = version
  spec.authors  = ['Boscolo Michele']
  spec.email    = ['miboscol@gmail.com']
  spec.summary  = 'Binding Ruby completo per notcurses 3.0.17, con un framework UI a eventi'
  spec.description = 'Layer FFI 1:1 dell\'API C di notcurses 3.0.17, wrapper Ruby idiomatico ' \
                     '(Context, Plane, Visual, Direct, widget C) e Notcurses::UI: ciclo degli eventi, ' \
                     'focus, resize e widget composti. Richiede la libreria notcurses di sistema.'
  spec.homepage = 'https://github.com/ichelema/notcursesruby'
  spec.license  = 'Apache-2.0'
  spec.required_ruby_version = '>= 3.1'
  spec.requirements << 'notcurses 3.0.17 (libnotcurses.so.3, libnotcurses-core.so.3)'

  spec.metadata = {
    'source_code_uri' => spec.homepage,
    'changelog_uri' => "#{spec.homepage}/blob/master/CHANGELOG.md",
    'rubygems_mfa_required' => 'true'
  }

  # Elenco esplicito invece di git ls-files: la gem si costruisce anche fuori da
  # git, e restano fuori per costruzione submodule, spec/ e documentazione interna.
  spec.files = Dir.glob(%w[lib/**/*.rb examples/*.rb], base: __dir__).sort +
               %w[README.md LICENSE NOTICE CHANGELOG.md]
  spec.require_paths = ['lib']

  spec.add_dependency 'ffi', '~> 1.15'
end
