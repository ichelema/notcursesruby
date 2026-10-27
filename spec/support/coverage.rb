# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

# Coverage con SimpleCov, caricata solo su richiesta e prima di ogni spec:
#
#   TERM=xterm-256color bundle exec rspec --require ./spec/support/coverage.rb < /dev/null
#
# Report HTML e Cobertura (per Codecov) in coverage/. Il codice eseguito nei
# processi figli delle spec (spawn, Open3 con ruby -e) non viene contato.
require 'simplecov'
require 'simplecov-cobertura'

SimpleCov.root File.expand_path('../..', __dir__)
SimpleCov.start do
  enable_coverage :branch
  add_filter %r{\A/(spec|notcurses|libnotcurses-sys)/}
  # Layer FFI (Fase 1): le sue righe si eseguono al caricamento e gonfierebbero il totale.
  add_filter %r{\A/lib/notcurses/ffi(/|\.rb\z)}
  add_group('Wrapper (Fase 2)') { |src| !src.project_filename.start_with?('/lib/notcurses/ui') }
  add_group 'UI (Fase 3)', '/lib/notcurses/ui'
  formatter SimpleCov::Formatter::MultiFormatter.new([SimpleCov::Formatter::HTMLFormatter,
                                                      SimpleCov::Formatter::CoberturaFormatter])
  minimum_coverage 98
  minimum_coverage_by_file 90
end
