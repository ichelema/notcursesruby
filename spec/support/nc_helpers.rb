# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require 'notcurses'

# Helper delle spec del wrapper: contesti su /dev/null, mai su un TTY. Le spec
# vanno eseguite con stdin su /dev/null (il thread di input di notcurses legge
# fd 0).
#
# Un solo contesto (Context o Direct) per processo: ogni gruppo apre il suo in
# before(:all) e lo chiude in after(:all), oppure usa il blocco di open_context.
module NcHelpers
  # Opzioni di un Context di test: output su /dev/null, terminfo fisso (con TERM
  # assente o "dumb" l'init fallirebbe), niente banner, input scartato.
  CONTEXT_OPTIONS = {
    output: '/dev/null', termtype: 'xterm-256color', suppress_banners: true, drain_input: true
  }.freeze

  # Cartella dei descrittori aperti del processo: /proc/self/fd su Linux,
  # /dev/fd su macOS, che non ha /proc.
  FD_DIR = File.directory?('/proc/self/fd') ? '/proc/self/fd' : '/dev/fd'

  module_function

  # Numero dei descrittori aperti del processo, compreso quello con cui Dir
  # legge {FD_DIR}.
  #
  # @return [Integer]
  def open_fd_count
    Dir.children(FD_DIR).size
  end

  # Apre un Context di test. Le opzioni sostituiscono quelle di
  # {CONTEXT_OPTIONS} (per esempio drain_input: false per leggere l'input, che
  # da /dev/null è subito EOF).
  #
  # @return [Notcurses::Context] senza blocco; con un blocco, il valore del
  #   blocco (il contesto viene chiuso alla fine)
  def open_context(**opts, &block)
    Notcurses::Context.open(**CONTEXT_OPTIONS, **opts, &block)
  end
end

# Gruppo con un Context condiviso: @nc in before(:all), chiuso in after(:all).
# Gli esempi non devono chiudere il contesto né lasciare piani aperti che
# servano ad altri esempi.
RSpec.shared_context 'con un contesto notcurses' do
  before(:all) { @nc = NcHelpers.open_context }
  after(:all) { @nc&.close }

  let(:nc) { @nc }
end
