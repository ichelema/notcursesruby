# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require "ripper"

# Lotto 8b: un segno combinante o un carattere invisibile scritto nel sorgente come carattere non si vede alla lettura
# ("é" può essere "e" + U+0301, U+2028 non si vede affatto), e una modifica del testo non lo ritrova. Nel codice si
# scrivono come escape ("\u0301"); nei commenti restano ammessi, così lo YARD mostra "1️⃣".
RSpec.describe "caratteri invisibili nel sorgente" do
  invisible = /[\p{Mn}\p{Me}\p{Cf}\p{Zl}\p{Zp}]/
  comments = %i[on_comment on_embdoc on_embdoc_beg on_embdoc_end].freeze

  it "lib/ e spec/ scrivono i segni combinanti e i caratteri invisibili come escape fuori dai commenti" do
    root = File.expand_path("..", __dir__)
    found = Dir[File.join(root, "{lib,spec}/**/*.rb")].sort.flat_map do |path|
      Ripper.lex(File.read(path, encoding: Encoding::UTF_8)).filter_map do |(line, _col), type, token, _state|
        next if comments.include?(type) || !token.match?(invisible)

        "#{path.delete_prefix("#{root}/")}:#{line} #{token.scan(invisible).uniq.map { |c| format("\\u%04X", c.ord) }.join(" ")}"
      end
    end
    expect(found).to eq([]), "scrivi questi caratteri come escape (\"\\u0301\"):\n#{found.join("\n")}"
  end
end
