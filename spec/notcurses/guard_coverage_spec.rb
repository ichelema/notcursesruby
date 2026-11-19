# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

# Controllo statico di Notcurses::Guard (ICH-464): nei file del wrapper che
# chiamano il C, ogni metodo che legge direttamente un puntatore (to_ptr, @ptr,
# Util.ptr_of) gira dentro un'operazione protetta, così un close da un gestore
# trap o da un altro thread non libera il puntatore prima dell'ultimo uso.
# L'audit a runtime (spec/support/guard_audit.rb) controlla i chiamanti.
RSpec.describe "Notcurses::Guard nei metodi del wrapper" do
  before(:all) do
    require "prism"
  rescue LoadError
    skip "serve la gem prism (in Gemfile.lock tramite rubocop)"
  end

  def lib_dir = File.expand_path("../../lib/notcurses", __dir__)

  def files
    %w[context.rb direct.rb visual.rb plane.rb palette.rb stats.rb].map { |f| File.join(lib_dir, f) } +
      Dir[File.join(lib_dir, "widgets", "*.rb")]
  end

  # "file:metodo" che leggono un puntatore fuori dalla guardia, con il motivo.
  def exceptions = {
    "context.rb:release_native!" => "chiusura fisica: la esegue Guard con nessuna operazione in corso",
    "direct.rb:release_native!" => "chiusura fisica: la esegue Guard con nessuna operazione in corso",
    "direct.rb:get" => "la guardia copre la lettura C, non l'attesa dell'input",
    "context.rb:wait_input" => "to_ptr nel rescue: controllo di chiusura dopo un errore del descrittore",
    "direct.rb:wait_input" => "to_ptr nel rescue: controllo di chiusura dopo un errore del descrittore",
    "direct.rb:_fork" => "la guardia copre solo il flush, non il fork",
    "visual.rb:release_native!" => "ncvisual_destroy: la esegue close o l'ultima operazione sul visual",
    "visual.rb:self.from_file" => "variante C: la lettura non usa il contesto; la guardia copre l'adozione",
    "plane.rb:address" => "legge l'indirizzo, non dereferenzia il puntatore",
    "plane.rb:address_ptr" => "restituisce il puntatore grezzo (@api private), non chiama il C"
  }

  def guarded = /\A(?:Guard\.run|visual_guard|created = Guard\.run)\b/

  # Metodi che leggono direttamente un puntatore, con l'inizio del corpo.
  def pointer_methods(path)
    finder = Class.new(Prism::Visitor) do
      attr_reader :hits

      def initialize
        @hits = []
        @stack = []
        super
      end

      def visit_def_node(node)
        @stack.push(node)
        super
        @stack.pop
      end

      def visit_call_node(node)
        mark if %i[to_ptr ptr_of].include?(node.name)
        super
      end

      def visit_instance_variable_read_node(node)
        mark if node.name == :@ptr
        super
      end

      def mark
        d = @stack.last
        @hits << d if d && !@hits.include?(d)
      end
    end.new
    Prism.parse_file(path).value.accept(finder)
    finder.hits.map { |d| ["#{"self." if d.receiver}#{d.name}", d.body&.slice.to_s.lstrip, d.location.start_line] }
  end

  it "ogni metodo che legge un puntatore inizia con la guardia, salvo le eccezioni motivate" do
    missing = []
    seen = []
    files.each do |path|
      rel = path.delete_prefix("#{lib_dir}/")
      pointer_methods(path).each do |name, body, line|
        key = "#{rel}:#{name}"
        next seen << key if exceptions.key?(key)

        missing << "#{key} (riga #{line})" unless body.match?(guarded)
      end
    end
    expect(missing).to be_empty, "metodi senza Guard.run: #{missing.join(", ")}"
    expect(exceptions.keys - seen).to be_empty, "eccezioni non più usate: #{(exceptions.keys - seen).join(", ")}"
  end
end
