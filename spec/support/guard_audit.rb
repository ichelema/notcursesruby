# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require "notcurses"

# Audit di Notcurses::Guard (ICH-464): un to_ptr chiamato da lib/notcurses
# senza operazioni protette in corso (Guard.busy zero) fa fallire l'esempio.
# Fanno eccezione ALLOWED_FILES e ALLOWED, che non passano il puntatore al C
# fuori da una guardia. Con GUARD_AUDIT=record l'audit non
# fa fallire niente e alla fine stampa i punti trovati.
module GuardAudit
  LIB = "#{File.expand_path("../../lib/notcurses", __dir__)}/".freeze

  # File di lib/notcurses senza chiamate FFI: usano to_ptr solo come controllo
  # di chiusura e passano dai metodi pubblici, già protetti.
  ALLOWED_FILES = %w[ui/ fd_plane.rb subprocess.rb].freeze

  # "file:metodo" relativi a lib/notcurses, con il motivo.
  ALLOWED = {
    "direct.rb:get" => "controllo all'ingresso; la lettura C è protetta, l'attesa no",
    "context.rb:wait_input" => "to_ptr nel rescue: controllo di chiusura dopo un errore del descrittore",
    "direct.rb:wait_input" => "to_ptr nel rescue: controllo di chiusura dopo un errore del descrittore",
    "visual.rb:decode" => "variante C: occupa solo il visual (visual_guard)",
    "visual.rb:decode_loop" => "variante C: occupa solo il visual (visual_guard)"
  }.freeze

  @found = Hash.new(0)

  class << self
    attr_reader :found

    # @param locations [Array<Thread::Backtrace::Location>] chiamanti di to_ptr
    def check(locations)
      loc = locations.find { |l| !l.label.to_s.end_with?("to_ptr") }
      return unless loc&.path&.start_with?(LIB)

      file = loc.path.delete_prefix(LIB)
      return if ALLOWED_FILES.any? { |f| file.start_with?(f) }

      key = "#{file}:#{loc.base_label.to_s.sub(/\A.*[#.]/, "")}"
      @found["#{key} (riga #{loc.lineno})"] += 1 unless ALLOWED.key?(key) # rubocop:disable ThreadSafety/ClassInstanceVariable
    end

    def record? = ENV["GUARD_AUDIT"] == "record"
  end

  # Intercetta Resource#to_ptr (anche il super di FdPlane#to_ptr).
  module ToPtr
    def to_ptr
      GuardAudit.check(caller_locations(1, 4)) if Notcurses::Guard.busy.zero?
      super
    end
  end
  Notcurses::Resource.prepend(ToPtr)
end

RSpec.configure do |config|
  config.after do
    raise "Notcurses::Guard.busy negativo: #{Notcurses::Guard.busy}" if Notcurses::Guard.busy.negative?
    next if GuardAudit.record? || GuardAudit.found.empty?

    found = GuardAudit.found.keys
    GuardAudit.found.clear
    raise "to_ptr fuori da Notcurses::Guard.run: #{found.join(", ")}"
  end
  config.after(:suite) do
    next unless GuardAudit.record?

    GuardAudit.found.sort_by { |_, n| -n }.each { |k, n| warn format("guard-audit %6d %s", n, k) }
  end
end
