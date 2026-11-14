# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require "notcurses"
require "open3"
require "shellwords"
require "tmpdir"

# Genera un programma C dalle definizioni Ruby, lo compila contro gli header
# di notcurses installati e confronta il suo output con layout e costanti di
# Notcurses::FFI (sizeof, alignment, offset e dimensione dei campi, valori).
module FfiLayoutSpec
  # Classe Ruby -> tipo C (alcuni tipi non hanno typedef).
  C_TYPES = {
    Timespec: "struct timespec", NcCell: "nccell", NotcursesOptions: "notcurses_options",
    NcInput: "ncinput", NcPlaneOptions: "ncplane_options", NcPalette: "ncpalette",
    NcCapabilities: "nccapabilities", NcStats: "ncstats",
    NcVisualOptions: "struct ncvisual_options", NcVgeom: "ncvgeom",
    NcReelOptions: "ncreel_options", NcSelectorItem: "struct ncselector_item",
    NcSelectorOptions: "ncselector_options", NcMselectorItem: "struct ncmselector_item",
    NcMultiselectorOptions: "ncmultiselector_options", NcTreeItem: "struct nctree_item",
    NcTreeOptions: "nctree_options", NcMenuItem: "struct ncmenu_item",
    NcMenuSection: "struct ncmenu_section", NcMenuOptions: "ncmenu_options",
    NcProgbarOptions: "ncprogbar_options", NcTabbedOptions: "nctabbed_options",
    NcPlotOptions: "ncplot_options", NcFdplaneOptions: "ncfdplane_options",
    NcSubprocOptions: "ncsubproc_options", NcReaderOptions: "ncreader_options",
    Termios: "struct termios"
  }.freeze

  # Termios è opaca e sovradimensionata di proposito: si confrontano solo
  # questi offset e sizeof(struct termios) <= Termios.size.
  TERMIOS_FIELDS = %i[c_iflag c_oflag c_cflag c_lflag].freeze

  PRELUDE = <<~C
    #include <stddef.h>
    #include <stdio.h>
    #include <termios.h>
    #include <time.h>
    #include <wchar.h>
    #include <notcurses/version.h>
    #include <notcurses/notcurses.h>
    #include <notcurses/direct.h>

    #define I(k, e) printf("%s\\t%lld\\n", k, (long long)(e))
    static void ps(const char *k, const char *s) {
      printf("%s\\t", k);
      for (; *s; s++) printf("%02x", (unsigned char)*s);
      puts("");
    }
    /* UTF-8 a mano: nessuna dipendenza dal locale */
    static void pw(const char *k, const wchar_t *s) {
      printf("%s\\t", k);
      for (; *s; s++) {
        unsigned long c = (unsigned long)*s;
        if (c < 0x80) printf("%02lx", c);
        else if (c < 0x800) printf("%02lx%02lx", 0xc0 | c >> 6, 0x80 | (c & 0x3f));
        else if (c < 0x10000) printf("%02lx%02lx%02lx", 0xe0 | c >> 12, 0x80 | (c >> 6 & 0x3f), 0x80 | (c & 0x3f));
        else printf("%02lx%02lx%02lx%02lx", 0xf0 | c >> 18, 0x80 | (c >> 12 & 0x3f), 0x80 | (c >> 6 & 0x3f), 0x80 | (c & 0x3f));
      }
      puts("");
    }
    #define S(k, e) _Generic((e), wchar_t *: pw, default: ps)(k, e)
  C

  Check = Struct.new(:group, :key, :c_expr, :expected)

  # Interi come signed 64 bit (enumeratori negativi, maschere sopra 2**63).
  def self.s64(n)
    n &= 2**64 - 1
    (n >= 2**63) ? n - 2**64 : n
  end

  def self.struct_classes = Notcurses::FFI.constants(false).select { |c| Notcurses::FFI.const_get(c).is_a?(Class) }

  # Integer/String da confrontare; le altre costanti le segnala l'esempio "copertura".
  def self.constant_names
    (Notcurses::FFI.constants(false) - struct_classes)
      .select { |c| [Integer, String].include?(Notcurses::FFI.const_get(c).class) }
  end

  def self.struct_checks
    (struct_classes & C_TYPES.keys).flat_map do |name|
      klass = Notcurses::FFI.const_get(name)
      type = C_TYPES.fetch(name)
      if name == :Termios
        offsets = TERMIOS_FIELDS.map { |f| Check.new(:termios, "#{name}.#{f} offset", "offsetof(#{type}, #{f})", klass.layout[f].offset.to_s) }
        next offsets << Check.new(:termios_size, "#{name} sizeof", "sizeof(#{type})", nil)
      end
      fields = klass.layout.fields.flat_map do |f|
        [Check.new(:struct, "#{name}.#{f.name} offset", "offsetof(#{type}, #{f.name})", f.offset.to_s),
          Check.new(:struct, "#{name}.#{f.name} size", "sizeof(((#{type} *)0)->#{f.name})", f.size.to_s)]
      end
      [Check.new(:struct, "#{name} sizeof", "sizeof(#{type})", klass.size.to_s),
        Check.new(:struct, "#{name} alignof", "_Alignof(#{type})", klass.alignment.to_s)] + fields
    end
  end

  def self.constant_checks
    constant_names.map do |name|
      v = Notcurses::FFI.const_get(name)
      if v.is_a?(Integer)
        Check.new(:integer, name.to_s, name.to_s, s64(v).to_s)
      else
        Check.new(:string, name.to_s, name.to_s, v.encode(Encoding::UTF_8).unpack1("H*"))
      end
    end
  end

  def self.checks = struct_checks + constant_checks

  def self.c_source(checks)
    body = checks.map { |c| "#{(c.group == :string) ? "S" : "I"}(#{c.key.inspect}, #{c.c_expr});" }
    "#{PRELUDE}int main(void) {\n#{body.join("\n")}\nreturn 0;\n}\n"
  end

  def self.compiler
    [ENV.fetch("CC", nil), "cc", "gcc", "clang"].compact.find { |cc| system(cc, "--version", out: File::NULL, err: File::NULL) }
  end

  def self.cflags
    out, st = Open3.capture2e("pkg-config", "--cflags", "notcurses")
    ["-D_GNU_SOURCE", *(st.success? ? out.shellsplit : [])]
  rescue Errno::ENOENT
    ["-D_GNU_SOURCE"]
  end

  # => [motivo dello skip, nil] oppure [nil, {chiave => valore stampato dal C}].
  # Un errore di compilazione del programma generato è un fallimento, non uno skip.
  def self.run(checks)
    cc = compiler
    return ["nessun compilatore C trovato (CC, cc, gcc, clang)", nil] unless cc

    Dir.mktmpdir("ffi_layout") do |dir|
      exe = File.join(dir, "layout")
      probe = File.join(dir, "probe.c")
      File.write(probe, "#include <notcurses/notcurses.h>\nint main(void) { return 0; }\n")
      out, st = Open3.capture2e(cc, *cflags, probe, "-o", exe)
      return ["#include <notcurses/notcurses.h> non compila con #{cc}: #{out}", nil] unless st.success?

      src = File.join(dir, "layout.c")
      File.write(src, c_source(checks))
      out, st = Open3.capture2e(cc, *cflags, src, "-o", exe)
      raise "il programma C generato non compila:\n#{out}" unless st.success?

      out, st = Open3.capture2e(exe)
      raise "il programma C generato è fallito:\n#{out}" unless st.success?

      [nil, out.lines.to_h { |l| l.chomp.split("\t", 2) }]
    end
  end
end

RSpec.describe "Layout FFI contro gli header C" do
  it "ogni classe di structs.rb ha il suo tipo C" do
    expect(FfiLayoutSpec.struct_classes).to match_array(FfiLayoutSpec::C_TYPES.keys)
  end

  # Nessuna costante resta fuori senza che lo spec se ne accorga: una nuova
  # costante Integer/String finisce nel programma C e, senza macro omonima,
  # il programma non compila.
  it "ogni costante è una struct, un Integer o una String" do
    others = Notcurses::FFI.constants(false) - FfiLayoutSpec.struct_classes - FfiLayoutSpec.constant_names
    expect(others).to be_empty
  end

  context "con un compilatore C e gli header di notcurses" do
    before(:all) do
      @checks = FfiLayoutSpec.checks
      reason, @c = FfiLayoutSpec.run(@checks)
      skip reason if reason
    end

    def compare(group)
      checks = @checks.select { |c| c.group == group }
      expect(checks).not_to be_empty
      expect(checks.to_h { |c| [c.key, @c[c.key]] }).to eq(checks.to_h { |c| [c.key, c.expected] })
    end

    it "sizeof, alignment, offset e dimensione dei campi delle struct coincidono" do
      compare(:struct)
    end

    it "Termios: offset dei flag e sizeof(struct termios) <= Termios.size" do
      compare(:termios)
      expect(Integer(@c["Termios sizeof"])).to be <= Notcurses::FFI::Termios.size
    end

    it "le costanti Integer coincidono, come signed 64 bit" do
      compare(:integer)
    end

    it "le costanti String coincidono, in UTF-8" do
      compare(:string)
    end
  end
end
