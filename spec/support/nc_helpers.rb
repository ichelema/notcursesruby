# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require 'notcurses'
require 'open3'
require_relative 'guard_audit'

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

  # Comando timeout di coreutils per i processi figli: "timeout", altrimenti
  # "gtimeout", il nome con il prefisso g di coreutils di Homebrew (brew
  # install coreutils; la 9.12 installa anche "timeout", che macOS non ha).
  # Senza nessuno dei due resta "timeout", e la spec fallisce con Errno::ENOENT.
  TIMEOUT = %w[timeout gtimeout].find do |cmd|
    ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, cmd)) }
  end || 'timeout'

  # Allocatore di debug di glibc: con MALLOC_CHECK_=3 termina il processo alla
  # prima free sbagliata o su un heap corrotto.
  MALLOC_DEBUG = '/usr/lib/libc_malloc_debug.so.0'

  module_function

  # Esegue script in un processo Ruby figlio sotto {MALLOC_DEBUG}, con lib/ nel
  # load path e stdin vuoto. Chi lo chiama salta l'esempio se {MALLOC_DEBUG}
  # manca.
  #
  # @return [Array(Integer, String)] stato di uscita e output (stdout e stderr)
  def heap_check(script, timeout: 30)
    env = {'TERM' => 'xterm-256color', 'LD_PRELOAD' => MALLOC_DEBUG, 'MALLOC_CHECK_' => '3'}
    lib = File.expand_path('../../lib', __dir__)
    out, status = Open3.capture2e(env, TIMEOUT, '-k', '5', '-s', 'KILL', timeout.to_s, RbConfig.ruby, '-I', lib, '-e',
      script, stdin_data: '')
    [status.exitstatus, out]
  end

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

  # Esegue il blocco in un thread nuovo, lo ferma al primo ritorno del metodo
  # method_id (dove Ruby consegna le eccezioni asincrone) e gli manda
  # Thread#raise(RuntimeError, 'interrotto'), poi lo lascia ripartire.
  #
  # @param method_id [Symbol] metodo, per esempio :ncvisual_from_file
  # @param event [Symbol] :c_return per un metodo C, :return per un metodo Ruby
  # @return [Array(Object, Array)] il valore del blocco (il messaggio del
  #   RuntimeError, se lo solleva) e il valore restituito dal metodo
  #   (l'indirizzo, per un ::FFI::Pointer)
  def raise_at_c_return(method_id, event: :c_return)
    returned = []
    paused = Queue.new
    resume = Queue.new
    trace = TracePoint.new(event) do |tp|
      next unless tp.method_id == method_id && Thread.current[:raise_at_c_return] && returned.empty?

      value = tp.return_value
      returned << (value.is_a?(::FFI::Pointer) ? value.address : value)
      paused << true
      resume.pop
    end
    trace.enable
    # rubocop:disable ThreadSafety/NewThread -- il thread da interrompere
    thread = Thread.new do
      Thread.current[:raise_at_c_return] = true
      yield
    rescue RuntimeError => e
      e.message
    end
    # rubocop:enable ThreadSafety/NewThread
    paused.pop
    thread.raise(RuntimeError, 'interrotto')
    resume << true
    [thread.value, returned]
  ensure
    trace&.disable
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
