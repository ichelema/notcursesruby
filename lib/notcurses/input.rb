# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/nckeys.h
# frozen_string_literal: true

module Notcurses
  # Codici dei tasti speciali e del mouse (+NCKEY_*+ di nckeys.h), senza il
  # prefisso. I tasti che producono testo hanno come codice il codepoint
  # Unicode (per esempio +'a'.ord+).
  #
  # +NCKEY_END+ e +NCKEY_BEGIN+ diventano {END_KEY} e {BEGIN_KEY}: +END+ e
  # +BEGIN+ sono parole riservate di Ruby e non possono essere nomi di costante.
  module Key
    # @!group Codici dei tasti
    INVALID        = FFI::NCKEY_INVALID
    RESIZE         = FFI::NCKEY_RESIZE
    UP             = FFI::NCKEY_UP
    RIGHT          = FFI::NCKEY_RIGHT
    DOWN           = FFI::NCKEY_DOWN
    LEFT           = FFI::NCKEY_LEFT
    INS            = FFI::NCKEY_INS
    DEL            = FFI::NCKEY_DEL
    BACKSPACE      = FFI::NCKEY_BACKSPACE
    PGDOWN         = FFI::NCKEY_PGDOWN
    PGUP           = FFI::NCKEY_PGUP
    HOME           = FFI::NCKEY_HOME
    END_KEY        = FFI::NCKEY_END
    F00            = FFI::NCKEY_F00
    F01            = FFI::NCKEY_F01
    F02            = FFI::NCKEY_F02
    F03            = FFI::NCKEY_F03
    F04            = FFI::NCKEY_F04
    F05            = FFI::NCKEY_F05
    F06            = FFI::NCKEY_F06
    F07            = FFI::NCKEY_F07
    F08            = FFI::NCKEY_F08
    F09            = FFI::NCKEY_F09
    F10            = FFI::NCKEY_F10
    F11            = FFI::NCKEY_F11
    F12            = FFI::NCKEY_F12
    F13            = FFI::NCKEY_F13
    F14            = FFI::NCKEY_F14
    F15            = FFI::NCKEY_F15
    F16            = FFI::NCKEY_F16
    F17            = FFI::NCKEY_F17
    F18            = FFI::NCKEY_F18
    F19            = FFI::NCKEY_F19
    F20            = FFI::NCKEY_F20
    F21            = FFI::NCKEY_F21
    F22            = FFI::NCKEY_F22
    F23            = FFI::NCKEY_F23
    F24            = FFI::NCKEY_F24
    F25            = FFI::NCKEY_F25
    F26            = FFI::NCKEY_F26
    F27            = FFI::NCKEY_F27
    F28            = FFI::NCKEY_F28
    F29            = FFI::NCKEY_F29
    F30            = FFI::NCKEY_F30
    F31            = FFI::NCKEY_F31
    F32            = FFI::NCKEY_F32
    F33            = FFI::NCKEY_F33
    F34            = FFI::NCKEY_F34
    F35            = FFI::NCKEY_F35
    F36            = FFI::NCKEY_F36
    F37            = FFI::NCKEY_F37
    F38            = FFI::NCKEY_F38
    F39            = FFI::NCKEY_F39
    F40            = FFI::NCKEY_F40
    F41            = FFI::NCKEY_F41
    F42            = FFI::NCKEY_F42
    F43            = FFI::NCKEY_F43
    F44            = FFI::NCKEY_F44
    F45            = FFI::NCKEY_F45
    F46            = FFI::NCKEY_F46
    F47            = FFI::NCKEY_F47
    F48            = FFI::NCKEY_F48
    F49            = FFI::NCKEY_F49
    F50            = FFI::NCKEY_F50
    F51            = FFI::NCKEY_F51
    F52            = FFI::NCKEY_F52
    F53            = FFI::NCKEY_F53
    F54            = FFI::NCKEY_F54
    F55            = FFI::NCKEY_F55
    F56            = FFI::NCKEY_F56
    F57            = FFI::NCKEY_F57
    F58            = FFI::NCKEY_F58
    F59            = FFI::NCKEY_F59
    F60            = FFI::NCKEY_F60
    ENTER          = FFI::NCKEY_ENTER
    CLS            = FFI::NCKEY_CLS
    DLEFT          = FFI::NCKEY_DLEFT
    DRIGHT         = FFI::NCKEY_DRIGHT
    ULEFT          = FFI::NCKEY_ULEFT
    URIGHT         = FFI::NCKEY_URIGHT
    CENTER         = FFI::NCKEY_CENTER
    BEGIN_KEY      = FFI::NCKEY_BEGIN
    CANCEL         = FFI::NCKEY_CANCEL
    CLOSE          = FFI::NCKEY_CLOSE
    COMMAND        = FFI::NCKEY_COMMAND
    COPY           = FFI::NCKEY_COPY
    EXIT           = FFI::NCKEY_EXIT
    PRINT          = FFI::NCKEY_PRINT
    REFRESH        = FFI::NCKEY_REFRESH
    SEPARATOR      = FFI::NCKEY_SEPARATOR
    CAPS_LOCK      = FFI::NCKEY_CAPS_LOCK
    SCROLL_LOCK    = FFI::NCKEY_SCROLL_LOCK
    NUM_LOCK       = FFI::NCKEY_NUM_LOCK
    PRINT_SCREEN   = FFI::NCKEY_PRINT_SCREEN
    PAUSE          = FFI::NCKEY_PAUSE
    MENU           = FFI::NCKEY_MENU
    MEDIA_PLAY     = FFI::NCKEY_MEDIA_PLAY
    MEDIA_PAUSE    = FFI::NCKEY_MEDIA_PAUSE
    MEDIA_PPAUSE   = FFI::NCKEY_MEDIA_PPAUSE
    MEDIA_REV      = FFI::NCKEY_MEDIA_REV
    MEDIA_STOP     = FFI::NCKEY_MEDIA_STOP
    MEDIA_FF       = FFI::NCKEY_MEDIA_FF
    MEDIA_REWIND   = FFI::NCKEY_MEDIA_REWIND
    MEDIA_NEXT     = FFI::NCKEY_MEDIA_NEXT
    MEDIA_PREV     = FFI::NCKEY_MEDIA_PREV
    MEDIA_RECORD   = FFI::NCKEY_MEDIA_RECORD
    MEDIA_LVOL     = FFI::NCKEY_MEDIA_LVOL
    MEDIA_RVOL     = FFI::NCKEY_MEDIA_RVOL
    MEDIA_MUTE     = FFI::NCKEY_MEDIA_MUTE
    LSHIFT         = FFI::NCKEY_LSHIFT
    LCTRL          = FFI::NCKEY_LCTRL
    LALT           = FFI::NCKEY_LALT
    LSUPER         = FFI::NCKEY_LSUPER
    LHYPER         = FFI::NCKEY_LHYPER
    LMETA          = FFI::NCKEY_LMETA
    RSHIFT         = FFI::NCKEY_RSHIFT
    RCTRL          = FFI::NCKEY_RCTRL
    RALT           = FFI::NCKEY_RALT
    RSUPER         = FFI::NCKEY_RSUPER
    RHYPER         = FFI::NCKEY_RHYPER
    RMETA          = FFI::NCKEY_RMETA
    L3SHIFT        = FFI::NCKEY_L3SHIFT
    L5SHIFT        = FFI::NCKEY_L5SHIFT
    MOTION         = FFI::NCKEY_MOTION
    BUTTON1        = FFI::NCKEY_BUTTON1
    BUTTON2        = FFI::NCKEY_BUTTON2
    BUTTON3        = FFI::NCKEY_BUTTON3
    BUTTON4        = FFI::NCKEY_BUTTON4
    BUTTON5        = FFI::NCKEY_BUTTON5
    BUTTON6        = FFI::NCKEY_BUTTON6
    BUTTON7        = FFI::NCKEY_BUTTON7
    BUTTON8        = FFI::NCKEY_BUTTON8
    BUTTON9        = FFI::NCKEY_BUTTON9
    BUTTON10       = FFI::NCKEY_BUTTON10
    BUTTON11       = FFI::NCKEY_BUTTON11
    SIGNAL         = FFI::NCKEY_SIGNAL
    EOF            = FFI::NCKEY_EOF
    SCROLL_UP      = FFI::NCKEY_SCROLL_UP
    SCROLL_DOWN    = FFI::NCKEY_SCROLL_DOWN
    RETURN         = FFI::NCKEY_RETURN
    TAB            = FFI::NCKEY_TAB
    ESC            = FFI::NCKEY_ESC
    SPACE          = FFI::NCKEY_SPACE
    # @!endgroup

    # Codice di un evento sintetizzato (+preterunicode+): +PRETERUNICODEBASE + w+.
    #
    # @param w [Integer] 0..(0xffffffff - PRETERUNICODEBASE); PRETERUNICODEBASE
    #   è oltre l'ultimo codepoint Unicode, quindi i codici non collidono con il testo
    # @return [Integer]
    # @raise [TypeError, ArgumentError] se w non è un Integer nell'intervallo
    def self.preterunicode(w)
      Util.integer!(w, 'w', 0..(0xffff_ffff - FFI::PRETERUNICODEBASE))
      FFI.preterunicode(w)
    end

    # @param id [Integer] codice di un evento
    # @return [Boolean] true se id è un evento sintetizzato da notcurses (+nckey_synthesized_p+)
    # @raise [TypeError, ArgumentError] se id non è un intero in 0..0xffffffff
    def self.synthesized?(id) = FFI.nckey_synthesized_p(Util.uint32!(id, 'id'))

    # @param id [Integer] codice di un evento
    # @return [Boolean] true se id è nell'area privata BMP U+E000..U+F8FF (+nckey_pua_p+)
    # @raise [TypeError, ArgumentError] se id non è un intero in 0..0xffffffff
    def self.pua?(id) = FFI.nckey_pua_p(Util.uint32!(id, 'id'))

    # @param id [Integer] codice di un evento
    # @return [Boolean] true se id è nell'area privata supplementare A (+nckey_supppuaa_p+)
    # @raise [TypeError, ArgumentError] se id non è un intero in 0..0xffffffff
    def self.supppuaa?(id) = FFI.nckey_supppuaa_p(Util.uint32!(id, 'id'))

    # @param id [Integer] codice di un evento
    # @return [Boolean] true se id è nell'area privata supplementare B (+nckey_supppuab_p+)
    # @raise [TypeError, ArgumentError] se id non è un intero in 0..0xffffffff
    def self.supppuab?(id) = FFI.nckey_supppuab_p(Util.uint32!(id, 'id'))

    # @param id [Integer] codice di un evento
    # @return [Boolean] true se id è un evento del mouse (+nckey_mouse_p+)
    # @raise [TypeError, ArgumentError] se id non è un intero in 0..0xffffffff
    def self.mouse?(id) = FFI.nckey_mouse_p(Util.uint32!(id, 'id'))
  end

  # Evento di input (+ncinput+): tasto, carattere o evento del mouse.
  #
  # Value object immutabile: copia tutti i campi della struct C, quindi non
  # dipende da memoria C. {#to_ffi} ricostruisce la struct per le funzioni che
  # la vogliono (+offer_input+ dei widget, le predicate +ncinput_*_p+).
  #
  # @example
  #   input = ctx.get(timeout: 0.5)
  #   exit if input&.id == Notcurses::Key::ESC
  #   puts input.utf8 if input && !input.utf8.empty?
  class Input
    # Modificatori (+NCKEY_MOD_*+) come simboli.
    MODIFIERS = {
      shift: FFI::NCKEY_MOD_SHIFT,
      alt: FFI::NCKEY_MOD_ALT,
      ctrl: FFI::NCKEY_MOD_CTRL,
      super: FFI::NCKEY_MOD_SUPER,
      hyper: FFI::NCKEY_MOD_HYPER,
      meta: FFI::NCKEY_MOD_META,
      capslock: FFI::NCKEY_MOD_CAPSLOCK,
      numlock: FFI::NCKEY_MOD_NUMLOCK
    }.freeze

    # @return [Integer] codepoint Unicode o codice {Key}
    attr_reader :id
    # @return [Integer] riga dell'evento del mouse, relativa all'area di
    #   rendering; ha senso solo se {#mouse?} (notcurses mette 0 per la tastiera)
    attr_reader :y
    # @return [Integer] colonna dell'evento del mouse (vedi {#y})
    attr_reader :x
    # @return [String] testo UTF-8 del tasto ("" se non produce testo)
    attr_reader :utf8
    # @return [Symbol] :unknown, :press, :repeat o :release
    attr_reader :evtype
    # @return [Integer] maschera dei modificatori (+NCKEY_MOD_*+). Il wrapper
    #   aggiunge NCKEY_MOD_ALT quando notcurses 3.0.17 segnala Alt (prefisso
    #   ESC) solo nel campo deprecato +alt+
    attr_reader :modifiers
    # @return [Integer] offset in pixel della riga, per gli eventi del mouse (-1 se ignoto)
    attr_reader :ypx
    # @return [Integer] offset in pixel della colonna, per gli eventi del mouse (-1 se ignoto)
    attr_reader :xpx
    # @return [String] testo effettivo (con i modificatori applicati), "" se assente
    attr_reader :eff_text

    # @param ncinput [FFI::NcInput] struct compilata da notcurses
    # @raise [TypeError] se ncinput non è un FFI::NcInput
    def initialize(ncinput)
      raise TypeError, "ncinput deve essere Notcurses::FFI::NcInput, non #{ncinput.class}" unless ncinput.is_a?(FFI::NcInput)

      @id = ncinput[:id]
      @y = ncinput[:y]
      @x = ncinput[:x]
      @utf8 = ncinput[:utf8].to_s.force_encoding(Encoding::UTF_8).scrub
      @evtype = Util.enum_symbol(Util::EVTYPES, ncinput[:evtype])
      @modifiers = ncinput[:modifiers]
      @modifiers |= FFI::NCKEY_MOD_ALT if ncinput[:alt]
      @ypx = ncinput[:ypx]
      @xpx = ncinput[:xpx]
      cps = ncinput[:eff_text].to_a.take_while(&:positive?)
      @eff_text = cps.select { |cp| cp <= 0x10ffff && !(0xd800..0xdfff).cover?(cp) }.pack('U*')
      freeze
    end

    # Evento costruito in Ruby, per esempio da passare a +offer_input+ di un
    # widget. I campi seguono quelli degli eventi reali di notcurses 3.0.17:
    # per la tastiera y, x, ypx e xpx valgono 0 (non -1 come dice l'header) e
    # il testo effettivo è il codepoint id (alcuni widget, come il reader,
    # leggono solo quello).
    #
    # @param id [Integer] codepoint o codice {Key}
    # @param utf8 [String, nil] testo del tasto; nil = derivato da id se è un codepoint stampabile
    # @param modifiers [Integer, Array<Symbol>] maschera o simboli di {MODIFIERS}
    # @param evtype [Symbol] :unknown, :press, :repeat o :release
    # @param y [Integer] riga (eventi del mouse, rispetto all'area di rendering)
    # @param x [Integer] colonna (eventi del mouse)
    # @param eff_text [String, nil] testo effettivo (al massimo 4 codepoint);
    #   nil = il codepoint id, se è un carattere
    # @return [Input]
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    def self.synthesize(id, utf8: nil, modifiers: 0, evtype: :press, y: 0, x: 0, eff_text: nil)
      Util.uint32!(id, 'id')
      ni = FFI::NcInput.new
      ni[:id] = id
      ni[:y] = Util.int!(y, 'y')
      ni[:x] = Util.int!(x, 'x')
      text = utf8.nil? ? default_utf8(id) : Util.string!(utf8, 'utf8')
      raise ArgumentError, "utf8 = #{text.inspect} supera 4 byte" if text.bytesize > 4

      ni[:utf8].to_ptr.put_bytes(0, text.b)
      ni[:evtype] = Util.enum_value(Util::EVTYPES, evtype, 'evtype')
      ni[:modifiers] = modifiers_mask(modifiers)
      # il mouse senza coordinate in pixel ha -1, la tastiera 0
      ni[:ypx] = Key.mouse?(id) ? -1 : 0
      ni[:xpx] = Key.mouse?(id) ? -1 : 0
      effective = eff_text.nil? ? default_eff_text(id) : Util.string!(eff_text, 'eff_text').codepoints
      max = FFI::NCINPUT_MAX_EFF_TEXT_CODEPOINTS
      raise ArgumentError, "eff_text supera #{max} codepoint" if effective.size > max

      effective.each_with_index { |cp, i| ni[:eff_text][i] = cp }
      new(ni)
    end

    # @return [FFI::NcInput] nuova struct C con i campi di questo evento
    def to_ffi
      ni = FFI::NcInput.new
      ni[:id] = @id
      ni[:y] = @y
      ni[:x] = @x
      ni[:utf8].to_ptr.put_bytes(0, @utf8.b) unless @utf8.empty?
      ni[:evtype] = Util.enum_value(Util::EVTYPES, @evtype, 'evtype')
      ni[:modifiers] = @modifiers
      ni[:ypx] = @ypx
      ni[:xpx] = @xpx
      @eff_text.codepoints.first(FFI::NCINPUT_MAX_EFF_TEXT_CODEPOINTS).each_with_index { |cp, i| ni[:eff_text][i] = cp }
      ni
    end

    # @return [Boolean] (+ncinput_shift_p+)
    def shift? = FFI.ncinput_shift_p(to_ffi)

    # @return [Boolean] (+ncinput_ctrl_p+)
    def ctrl? = FFI.ncinput_ctrl_p(to_ffi)

    # @return [Boolean] (+ncinput_alt_p+)
    def alt? = FFI.ncinput_alt_p(to_ffi)

    # @return [Boolean] (+ncinput_meta_p+)
    def meta? = FFI.ncinput_meta_p(to_ffi)

    # @return [Boolean] (+ncinput_super_p+)
    def super? = FFI.ncinput_super_p(to_ffi)

    # @return [Boolean] (+ncinput_hyper_p+)
    def hyper? = FFI.ncinput_hyper_p(to_ffi)

    # @return [Boolean] (+ncinput_capslock_p+)
    def capslock? = FFI.ncinput_capslock_p(to_ffi)

    # @return [Boolean] (+ncinput_numlock_p+)
    def numlock? = FFI.ncinput_numlock_p(to_ffi)

    # @return [Boolean] true se nessun modificatore è attivo (+ncinput_nomod_p+)
    def nomod? = FFI.ncinput_nomod_p(to_ffi)

    # @return [Array<Symbol>] modificatori attivi, come chiavi di {MODIFIERS}
    def modifier_list = MODIFIERS.select { |_sym, bit| (@modifiers & bit) != 0 }.keys

    # @return [Boolean] true se è un evento del mouse (+nckey_mouse_p+)
    def mouse? = Key.mouse?(@id)

    # @return [Boolean] true se id è un codice sintetizzato da notcurses (+nckey_synthesized_p+)
    def synthesized? = Key.synthesized?(@id)

    # @return [Boolean] true per :press (e :unknown, che notcurses tratta come press)
    def press? = %i[press unknown].include?(@evtype)

    # @return [Boolean]
    def repeat? = @evtype == :repeat

    # @return [Boolean]
    def release? = @evtype == :release

    # Uguaglianza di notcurses (+ncinput_equal_p+): stesso id, posizione e
    # modificatori (CapsLock e NumLock esclusi); :unknown e :press equivalgono.
    # @param other [Object] oggetto da confrontare
    # @return [Boolean]
    def ==(other) = other.is_a?(Input) && FFI.ncinput_equal_p(to_ffi, other.to_ffi)
    alias eql? ==

    # @return [Integer] coerente con {#==}
    def hash
      lock = FFI::NCKEY_MOD_CAPSLOCK | FFI::NCKEY_MOD_NUMLOCK
      [Input, @id, @y, @x, @modifiers & ~lock, @ypx, @xpx].hash
    end

    # @return [String]
    def inspect
      format('#<Notcurses::Input id=0x%<id>x utf8=%<u>p %<ev>s mods=%<m>p y=%<y>d x=%<x>d>',
             id: @id, u: @utf8, ev: @evtype, m: modifier_list, y: @y, x: @x)
    end

    # @api private
    def self.modifiers_mask(modifiers)
      case modifiers
      when Integer then Util.uint32!(modifiers, 'modifiers')
      when Array then modifiers.reduce(0) { |mask, m| mask | Util.enum_value(MODIFIERS, m, 'modifiers') }
      else raise TypeError, "modifiers deve essere Integer o Array di Symbol, non #{modifiers.class}"
      end
    end

    # @api private
    def self.default_utf8(id)
      return '' if id < 0x20 || id == 0x7f || id > 0x10ffff || (0xd800..0xdfff).cover?(id)
      return '' if Key.synthesized?(id)

      [id].pack('U')
    end

    # Testo effettivo di un evento reale senza testo kitty: il codepoint id.
    # @param id [Integer] codepoint dell'evento
    # @return [Array<Integer>] [id], o [] se id non è un carattere
    def self.default_eff_text(id)
      id > 0x10ffff || (0xd800..0xdfff).cover?(id) || Key.synthesized?(id) ? [] : [id]
    end
    private_class_method :modifiers_mask, :default_utf8, :default_eff_text
  end
end
