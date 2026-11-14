# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  class << self
    # Numero con il prefisso del sistema metrico (+ncnmetric+): 1500 → "1.50K",
    # 0.002 (2 con decimal: 1000) → "2.00m". Il prefisso micro è "u" finché il
    # processo non ha creato un contesto UTF-8, poi "µ".
    #
    # @param value [Integer] valore, 0..2**64-1, già moltiplicato per decimal
    # @param decimal [Integer] fattore di scala di value (1 = nessuno; 1000 = tre
    #   cifre decimali), 1..(2**64-1)/10
    # @param base [Integer] 1000 (K, M, G, ...) o 1024
    # @param omit_decimal [Boolean] true = niente parte decimale quando è zero
    # @param suffix [String, nil] un carattere ASCII da aggiungere dopo il
    #   prefisso (per esempio "i" per KiB), solo se c'è un prefisso
    # @return [String]
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ArgumentError] se 0 < value < decimal e value * base**k supera
    #   2**64-1 prima di raggiungere decimal (possibile solo con decimal oltre
    #   (2**64-1)/base). Bug di notcurses 3.0.17: +ncnmetric+ non controlla
    #   l'overflow e restituirebbe cifre e prefisso sbagliati
    # @raise [Error] se la formattazione fallisce
    def metric(value, decimal: 1, base: 1000, omit_decimal: false, suffix: nil)
      Util.uint64!(value, 'value')
      Util.integer!(decimal, 'decimal', 1..(Util::UINT64.max / 10))
      # con altre basi i prefissi finiscono prima dei valori e il C scrive un NUL
      raise ArgumentError, "base = #{base.inspect} non valida: usa 1000 o 1024" unless [1000, 1024].include?(base)

      check_metric_overflow!(value, decimal, base)

      omit = Util.c_bool(omit_decimal, 'omit_decimal')
      uprefix = 0
      unless suffix.nil?
        text = Util.string!(suffix, 'suffix')
        raise ArgumentError, 'suffix deve essere un carattere ASCII stampabile' unless text.match?(/\A[[:print:]]\z/) && text.ascii_only?

        uprefix = text.ord
      end
      # 64 byte con s = 63: ncnmetric può scrivere un byte oltre s
      buf = ::FFI::MemoryPointer.new(:char, 64)
      metric_result(FFI.ncnmetric(value, 63, decimal, buf, omit, base, uprefix), 'ncnmetric')
    end

    # Prefisso metrico in base 1000, al massimo +FFI::NCPREFIXCOLUMNS+ colonne
    # (+ncqprefix+).
    #
    # @param value [Integer] 0..2**64-1
    # @param decimal [Integer] come in {.metric}
    # @param omit_decimal [Boolean] come in {.metric}
    # @return [String]
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ArgumentError] se la coppia value/decimal va in overflow in
    #   base 1000 (bug di notcurses 3.0.17, come in {.metric})
    # @raise [Error] se la formattazione fallisce
    def si_prefix(value, decimal: 1, omit_decimal: false)
      buf = prefix_buffer(value, decimal, 1000)
      metric_result(FFI.ncqprefix(value, decimal, buf, Util.c_bool(omit_decimal, 'omit_decimal')), 'ncqprefix')
    end

    # Prefisso in base 1024 senza "i", al massimo +FFI::NCIPREFIXCOLUMNS+
    # colonne (+nciprefix+): 1536 → "1.50K".
    #
    # @param value [Integer] 0..2**64-1
    # @param decimal [Integer] come in {.metric}
    # @param omit_decimal [Boolean] come in {.metric}
    # @return [String]
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ArgumentError] se la coppia value/decimal va in overflow in
    #   base 1024 (bug di notcurses 3.0.17, come in {.metric})
    # @raise [Error] se la formattazione fallisce
    def binary_prefix(value, decimal: 1, omit_decimal: false)
      buf = prefix_buffer(value, decimal, 1024)
      metric_result(FFI.nciprefix(value, decimal, buf, Util.c_bool(omit_decimal, 'omit_decimal')), 'nciprefix')
    end

    # Prefisso in base 1024 con "i", al massimo +FFI::NCBPREFIXCOLUMNS+
    # colonne (+ncbprefix+): 1024 → "1.00Ki".
    #
    # @param value [Integer] 0..2**64-1
    # @param decimal [Integer] come in {.metric}
    # @param omit_decimal [Boolean] come in {.metric}
    # @return [String]
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ArgumentError] se la coppia value/decimal va in overflow in
    #   base 1024 (bug di notcurses 3.0.17, come in {.metric})
    # @raise [Error] se la formattazione fallisce
    def byte_prefix(value, decimal: 1, omit_decimal: false)
      buf = prefix_buffer(value, decimal, 1024)
      metric_result(FFI.ncbprefix(value, decimal, buf, Util.c_bool(omit_decimal, 'omit_decimal')), 'ncbprefix')
    end

    # Blitter dal suo nome C (+notcurses_lex_blitter+), senza distinguere
    # maiuscole e minuscole: "ascii", "half", "quad", "sex", "oct", "braille",
    # "pixel", "fourstep", "eightstep", "default".
    #
    # @param name [String]
    # @return [Symbol] simbolo di blitter: (:ascii, :half, :quad, :sextant,
    #   :octant, :braille, :pixel, :four_by_one, :eight_by_one, :default)
    # @raise [TypeError, ArgumentError] se name non è un nome di blitter
    def parse_blitter(name)
      out = ::FFI::MemoryPointer.new(:int)
      rc = FFI.notcurses_lex_blitter(Util.string!(name, 'name'), out)
      raise ArgumentError, "blitter #{name.inspect} sconosciuto (notcurses_lex_blitter)" if rc.negative?

      Util.enum_symbol(Util::BLITTERS, out.read_int)
    end

    # Nome C di un blitter (+notcurses_str_blitter+).
    #
    # @param blitter [Symbol, Integer] simbolo di blitter: o costante NCBLIT_*
    # @return [String]
    # @raise [ArgumentError] se blitter non è valido
    def blitter_name(blitter)
      name = FFI.notcurses_str_blitter(Util.blitter_value(blitter))
      raise ArgumentError, "blitter #{blitter.inspect} senza nome (notcurses_str_blitter)" if name.nil?

      Util.utf8(name)
    end

    # Modo di scala dal suo nome C (+notcurses_lex_scalemode+), senza
    # distinguere maiuscole e minuscole: "none", "scale", "stretch", "hires",
    # "scalehi" ("inflate", citato dall'header, non è accettato).
    #
    # @param name [String]
    # @return [Symbol] :none, :scale, :stretch, :none_hires, :scale_hires
    # @raise [TypeError, ArgumentError] se name non è un nome di scala
    def parse_scale(name)
      out = ::FFI::MemoryPointer.new(:int)
      rc = FFI.notcurses_lex_scalemode(Util.string!(name, 'name'), out)
      raise ArgumentError, "scala #{name.inspect} sconosciuta (notcurses_lex_scalemode)" if rc.negative?

      Util.enum_symbol(Util::SCALES, out.read_int)
    end

    # Nome C di un modo di scala (+notcurses_str_scalemode+).
    #
    # @param scale [Symbol, Integer] simbolo di scale: o costante NCSCALE_*
    # @return [String]
    # @raise [ArgumentError] se scale non è valido
    def scale_name(scale)
      name = FFI.notcurses_str_scalemode(Util.scale_value(scale))
      raise ArgumentError, "scala #{scale.inspect} senza nome (notcurses_str_scalemode)" if name.nil?

      Util.utf8(name)
    end

    # Converte codepoint UCS-32 in UTF-8 (+notcurses_ucs32_to_utf8+). In Ruby
    # +codepoints.pack('U*')+ fa lo stesso.
    #
    # @param codepoints [Array<Integer>] codepoint Unicode (no surrogati)
    # @return [String] testo UTF-8
    # @raise [TypeError] se codepoints non è un Array di Integer
    # @raise [ArgumentError] se un codepoint non è valido
    def ucs32_to_utf8(codepoints)
      raise TypeError, "codepoints deve essere un Array, non #{codepoints.class}" unless codepoints.is_a?(Array)
      return +'' if codepoints.empty?

      codepoints.each_with_index { |cp, i| Util.integer!(cp, "codepoints[#{i}]", 0..0x10ffff) }
      count = Util.uint!(codepoints.size, 'codepoints.size')
      src = ::FFI::MemoryPointer.new(:uint32, count)
      src.write_array_of_uint32(codepoints)
      # 4 byte per codepoint bastano sempre: con un buffer piccolo il C perderebbe memoria
      buflen = 4 * count
      buf = ::FFI::MemoryPointer.new(:uchar, buflen)
      len = FFI.notcurses_ucs32_to_utf8(src, count, buf, buflen)
      raise ArgumentError, 'codepoints contiene un codepoint non valido (notcurses_ucs32_to_utf8)' if len.negative?

      buf.read_bytes(len).force_encoding(Encoding::UTF_8)
    end

    # Colonne che una stringa occupa sul terminale, con le regole di
    # notcurses (+ncstrwidth+): un EGC vale la larghezza del suo primo
    # carattere che ha una larghezza; "\t" e "\n" valgono 1. Il risultato
    # dipende dalla locale (LC_CTYPE): prima di aprire un contesto è quella del
    # processo.
    #
    # Bug di 3.0.17 aggirato: dopo uno ZWJ (U+200D) +ncstrwidth+ unisce tutto
    # il resto del testo allo stesso EGC e lo conta 0 colonne. Il wrapper
    # misura il testo spezzato dopo ogni grapheme cluster con uno ZWJ, come
    # lo scrive {Plane#putstr}: "👩‍🚀abc" vale 5 colonne, non 2. I grapheme
    # cluster sono quelli di Ruby (String#each_grapheme_cluster), che
    # seguono la versione di Unicode di Ruby: per una sequenza ZWJ che non è
    # un emoji (per esempio una congiunta devanagari) il risultato può
    # cambiare con la versione di Ruby, come la scrittura di {Plane#putstr}.
    #
    # @param text [String]
    # @return [Integer] colonne, >= 0
    # @raise [TypeError] se text non è String
    # @raise [ArgumentError] se text non è UTF-8 valido, contiene NUL o un
    #   carattere che notcurses rifiuta (per esempio un carattere di controllo)
    def strwidth(text)
      str = Util.string!(text, 'text')
      validbytes = ::FFI::MemoryPointer.new(:int)
      offset = 0
      Util.zwj_segments(str).sum do |seg|
        cols = FFI.ncstrwidth(seg, validbytes, nil)
        if cols.negative?
          raise ArgumentError,
                "text = #{text.inspect}: notcurses non riesce a misurare il testo dal byte #{offset + validbytes.read_int}"
        end

        offset += seg.bytesize
        cols
      end
    end

    private

    def prefix_buffer(value, decimal, base)
      Util.uint64!(value, 'value')
      Util.integer!(decimal, 'decimal', 1..(Util::UINT64.max / 10))
      check_metric_overflow!(value, decimal, base)
      ::FFI::MemoryPointer.new(:char, 64)
    end

    # Bug di 3.0.17: con 0 < value < decimal ncnmetric moltiplica value per base
    # fino a decimal senza un controllo di overflow funzionante (metric.c:53-59).
    # Il ciclo qui ripete quello del C con gli Integer di Ruby.
    def check_metric_overflow!(value, decimal, base)
      v = value
      v *= base while v.positive? && v < decimal
      return if v <= Util::UINT64.max

      raise ArgumentError,
            "value = #{value}, decimal = #{decimal}: in base #{base} il calcolo di ncnmetric supera 2**64-1 " \
            '(bug di notcurses 3.0.17)'
    end

    def metric_result(str, what)
      raise Error, "#{what} ha restituito NULL" if str.nil?

      Util.utf8(str)
    end
  end
end
