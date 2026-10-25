# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

# Suite differenziale delle reimplementazioni Ruby delle 236 static inline e delle
# 12 macro funzione di notcurses 3.0.17 (lib/notcurses/ffi/inline_reimpl.rb).
#
# Ogni inline è confrontata con la stessa funzione C compilata in libnotcurses-ffi.so
# (NcOracle, spec/support/nc_oracle.rb). Il blocco di ogni caso gira due volte, con
# m = Notcurses::FFI e con m = NcOracle, su buffer, struct e piani separati ma
# costruiti allo stesso modo; si confrontano il valore restituito (con il tipo Ruby),
# la classe dell'eventuale eccezione, la memoria scritta e lo stato completo dei piani.
# Le macro non hanno oracolo: i valori attesi vengono da un programma C compilato con
# gcc sugli header di notcurses 3.0.17 (locale it_IT.UTF-8) e sono copiati qui.
#
# Uso: bundle exec rspec < /dev/null      (seme dei casi casuali: NC_SPEC_SEED)

require 'zlib'
require 'notcurses/ffi'
require_relative 'support/nc_oracle'

module InlineReimplSpec
  F = Notcurses::FFI
  O = NcOracle
  SEED = Integer(ENV.fetch('NC_SPEC_SEED', '20261025'))
  NRAND = 1000 # casi casuali per ogni funzione pura, oltre ai bordi
  NPLANE = 1000 # casi per le funzioni con contesto notcurses
  NDIRECT = 400 # casi per le funzioni ncdirect
  M32 = 0xffff_ffff
  M64 = 0xffff_ffff_ffff_ffff
  SKIP = O::AVAILABLE ? {} : { skip: "oracolo libnotcurses-ffi non disponibile (#{O::LOAD_ERROR})" }

  # Le 236 static inline (gli stessi simboli esportati da libnotcurses-ffi.so).
  INLINE_NAMES = %i[
    ncbprefix nccapability_canchangecolor nccell_bchannel nccell_bg_alpha nccell_bg_default_p
    nccell_bg_palindex nccell_bg_palindex_p nccell_bg_rgb nccell_bg_rgb8 nccell_channels nccellcmp nccell_cols
    nccell_double_wide_p nccell_extract nccell_fchannel nccell_fg_alpha nccell_fg_default_p nccell_fg_palindex
    nccell_fg_palindex_p nccell_fg_rgb nccell_fg_rgb8 nccell_init nccell_load_char nccell_load_egc32
    nccell_load_ucs32 nccell_off_styles nccell_on_styles nccell_prime nccells_ascii_box nccells_double_box
    nccell_set_bchannel nccell_set_bg_alpha nccell_set_bg_default nccell_set_bg_palindex nccell_set_bg_rgb
    nccell_set_bg_rgb8 nccell_set_bg_rgb8_clipped nccell_set_channels nccell_set_fchannel nccell_set_fg_alpha
    nccell_set_fg_default nccell_set_fg_palindex nccell_set_fg_rgb nccell_set_fg_rgb8
    nccell_set_fg_rgb8_clipped nccell_set_styles nccells_heavy_box nccells_light_box nccells_load_box
    nccells_rounded_box nccell_strdup nccell_styles nccell_wide_left_p nccell_wide_right_p ncchannel_alpha
    ncchannel_b ncchannel_default_p ncchannel_g ncchannel_palindex ncchannel_palindex_p ncchannel_r
    ncchannel_rgb ncchannel_rgb8 ncchannel_rgb_p ncchannels_bchannel ncchannels_bg_alpha
    ncchannels_bg_default_p ncchannels_bg_palindex ncchannels_bg_palindex_p ncchannels_bg_rgb
    ncchannels_bg_rgb8 ncchannels_bg_rgb_p ncchannels_channels ncchannels_combine ncchannel_set
    ncchannel_set_alpha ncchannel_set_default ncchannel_set_palindex ncchannel_set_rgb8
    ncchannel_set_rgb8_clipped ncchannels_fchannel ncchannels_fg_alpha ncchannels_fg_default_p
    ncchannels_fg_palindex ncchannels_fg_palindex_p ncchannels_fg_rgb ncchannels_fg_rgb8 ncchannels_fg_rgb_p
    ncchannels_reverse ncchannels_set_bchannel ncchannels_set_bg_alpha ncchannels_set_bg_default
    ncchannels_set_bg_palindex ncchannels_set_bg_rgb ncchannels_set_bg_rgb8 ncchannels_set_bg_rgb8_clipped
    ncchannels_set_channels ncchannels_set_fchannel ncchannels_set_fg_alpha ncchannels_set_fg_default
    ncchannels_set_fg_palindex ncchannels_set_fg_rgb ncchannels_set_fg_rgb8 ncchannels_set_fg_rgb8_clipped
    ncdirect_ascii_box ncdirect_canbraille ncdirect_canchangecolor ncdirect_canfade ncdirect_canhalfblock
    ncdirect_canoctant ncdirect_canopen_images ncdirect_canopen_videos ncdirect_canquadrant ncdirect_cansextant
    ncdirect_cantruecolor ncdirect_get_blocking ncdirect_get_nblock ncdirect_heavy_box ncdirect_light_box
    ncdirect_set_bg_rgb8 ncdirect_set_fg_rgb8 ncinput_alt_p ncinput_capslock_p ncinput_ctrl_p ncinput_equal_p
    ncinput_hyper_p ncinput_meta_p ncinput_nomod_p ncinput_numlock_p ncinput_shift_p ncinput_super_p nciprefix
    nckey_mouse_p nckey_pua_p nckey_supppuaa_p nckey_supppuab_p nckey_synthesized_p ncpalette_get
    ncpalette_get_rgb8 ncpalette_set ncpalette_set_rgb8 ncpixel ncpixel_a ncpixel_b ncpixel_g ncpixel_r
    ncpixel_set_a ncpixel_set_b ncpixel_set_g ncpixel_set_r ncpixel_set_rgb8 ncplane_ascii_box ncplane_bchannel
    ncplane_bg_alpha ncplane_bg_default_p ncplane_bg_rgb ncplane_bg_rgb8 ncplane_box_sized ncplane_cursor_x
    ncplane_cursor_y ncplane_descendant_p ncplane_dim_x ncplane_dim_y ncplane_double_box
    ncplane_double_box_sized ncplane_fchannel ncplane_fg_alpha ncplane_fg_default_p ncplane_fg_rgb
    ncplane_fg_rgb8 ncplane_halign ncplane_hline ncplane_move_bottom ncplane_move_family_bottom
    ncplane_move_family_top ncplane_move_rel ncplane_move_top ncplane_perimeter ncplane_perimeter_double
    ncplane_perimeter_rounded ncplane_printf ncplane_printf_aligned ncplane_printf_stained ncplane_printf_yx
    ncplane_putc ncplane_putchar ncplane_putchar_yx ncplane_putegc ncplane_putnstr ncplane_putnstr_yx
    ncplane_putstr ncplane_putstr_aligned ncplane_putstr_stained ncplane_putstr_yx ncplane_pututf32_yx
    ncplane_putwc ncplane_putwc_stained ncplane_putwc_utf32 ncplane_putwc_yx ncplane_putwegc ncplane_putwegc_yx
    ncplane_putwstr ncplane_putwstr_aligned ncplane_putwstr_yx ncplane_resize_simple ncplane_rounded_box
    ncplane_rounded_box_sized ncplane_valign ncplane_vline ncplane_vprintf ncqprefix nctabbed_hdrchan
    nctabbed_selchan nctabbed_sepchan ncvisualplane_create ncwcsrtombs notcurses_align notcurses_bottom
    notcurses_canbraille notcurses_canchangecolor notcurses_canfade notcurses_canhalfblock notcurses_canoctant
    notcurses_canpixel notcurses_canquadrant notcurses_cansextant notcurses_cantruecolor notcurses_canutf8
    notcurses_get_blocking notcurses_get_nblock notcurses_mice_disable notcurses_render notcurses_stddim_yx
    notcurses_stddim_yx_const notcurses_term_dim_yx notcurses_top
  ].freeze

  MACRO_NAMES = %i[
    preterunicode NCCHANNEL_INITIALIZER NCCHANNELS_INITIALIZER NCCELL_INITIALIZER NCCELL_CHAR_INITIALIZER
    NCCELL_TRIVIAL_INITIALIZER NCMETRICFWIDTH NCPREFIXFMT NCIPREFIXFMT NCBPREFIXFMT htole
    NOTCURSES_VERSION_COMPARABLE
  ].freeze

  # Il va_list di System V x86_64 si costruisce a mano (Helpers#va_list).
  VA_LIST_SYSV = ::FFI::Platform::ARCH == 'x86_64' && !::FFI::Platform.windows?

  # Inline non confrontabili con l'oracolo su questa piattaforma, con il motivo.
  NOT_COMPARABLE = (VA_LIST_SYSV ? {} : { ncplane_vprintf: "va_list costruibile da Ruby solo con l'ABI System V x86_64" }).freeze

  # Confronti con l'oracolo ristretti, con il motivo (il resto della funzione è confrontato).
  PARTIAL = {
    nccell_load_ucs32: 'con UTF-8 < 4 byte il C copia utf8[4] non inizializzato (UB): lì il riferimento è ' \
                       'NcOracle.nccell_load_egc32 sullo stesso UTF-8 completato con zeri; oracolo diretto per ' \
                       'le sequenze di 4 byte e gli errori'
  }.freeze

  COVERED = {} # nome => gruppi che lo confrontano; lo riempie DSL#diff al caricamento del file

  # Bug di notcurses 3.0.17 che colpiscono allo stesso modo oracolo e reimplementazione
  # (crash o UB): i generatori dei casi non li esercitano.
  # - glifo largo o TAB scritto all'ultima colonna (x == lenx-1): ncplane_put scrive la
  #   cella successiva fuori riga (sull'ultima riga fuori dal framebuffer, heap corrotto).
  #   Sui piani scorrevoli niente x esplicita == lenx-1 e niente TAB; altrove i TAB solo
  #   a inizio riga (x <= 1) su piani larghi almeno 12 colonne.
  # - ncplane_putegc_stained con il cursore a x == lenx sull'ultima riga: legge fuori dal
  #   framebuffer. Le *_stained girano su piani non scorrevoli col cursore sopra l'ultima riga.
  # - ncplane_vline_interp/ncplane_vline con len == 0xffffffff: SIGFPE (divisione per zero).
  # - free() sul buffer di ncpile_render_to_buffer; ncpile_render_to_file seguita da
  #   notcurses_stop (double free): mai usate qui.
  # - ncdirect_core_init con un contesto notcurses attivo fallisce: i gruppi ncdirect hanno
  #   un proprio contesto che non si sovrappone mai a quello notcurses.
  # - ncplane_resize con area > INT_MAX (calcolo int in overflow, buffer troppo piccolo): solo
  #   dimensioni piccole, o (unsigned)-1 per una sola dimensione (malloc fallisce).
  # - limiti di durata: ncplane_hline su piano scorrevole e ncdirect_box/hline/vline con
  #   lunghezze enormi non terminano in tempi utili; lunghezze limitate.
  # - celle incoerenti scritte con ncplane_putc (e quindi da hline/vline/box): EGC vuoto con
  #   width >= 2 (ncplane_put la prende per la metà destra di un glifo largo e risale oltre
  #   x == 0); width > lenx su piano scorrevole (scroll_down non ricontrolla, poi scrive fuori
  #   da fb); EGC di più byte che inizia con '\n' (sfugge al filtro dei controlli, il cursore
  #   non avanza: hline con len enorme gira ~2^32 volte). Trovate con ASan, i generatori le evitano.

  # --- valori di bordo (requisito: 0, 1, 255, 256, 0xffffff, 0x1000000, 0x7fffffff, 0xffffffff, maschere, negativi)
  B32 = [0, 1, 255, 256, 0xffffff, 0x100_0000, 0x7fff_ffff, 0x8000_0000, M32,
         F::NC_BGDEFAULT_MASK, F::NC_BG_RGB_MASK, F::NC_BG_PALETTE, F::NC_BG_ALPHA_MASK,
         F::NCALPHA_BLEND, F::NCALPHA_TRANSPARENT, F::NCALPHA_HIGHCONTRAST,
         F::NC_BGDEFAULT_MASK | F::NC_BG_PALETTE | 0x2a, F::NC_BGDEFAULT_MASK | 0x12_3456,
         -1, -2, -255, -256, -0x8000_0000].freeze
  B64 = (B32 + [0x1_0000_0000, 0xffff_ffff_0000_0000, 0x7fff_ffff_ffff_ffff, 0x8000_0000_0000_0000, M64,
                F::NC_NOBACKGROUND_MASK, F::NC_BGDEFAULT_MASK * 0x1_0000_0001,
                (F::NC_BGDEFAULT_MASK | F::NC_BG_PALETTE | 7) * 0x1_0000_0001,
                (F::NCALPHA_HIGHCONTRAST << 32) | F::NCALPHA_TRANSPARENT, -0x8000_0000_0000_0000]).freeze
  BINT = [0, 1, -1, 2, -2, 255, 256, -255, -256, 300, -300, 0xffffff, 0x7fff_ffff, -0x8000_0000].freeze
  ALPHAS = [F::NCALPHA_OPAQUE, F::NCALPHA_BLEND, F::NCALPHA_TRANSPARENT, F::NCALPHA_HIGHCONTRAST].freeze
  KEY_RANGES = [[F::PRETERUNICODEBASE, F::NCKEY_EOF], [0xe000, 0xf8ff], [0xf0000, 0xffffd],
                [0x10_0000, 0x10_fffd], [F::NCKEY_MOTION, F::NCKEY_BUTTON11]].freeze
  BOUNDS = {
    u32: B32, chan32: B32, chan64: B64, int: BINT, clip: BINT,
    alpha: B32 + ALPHAS + [0x3000_0001, 0x4000_0000], idx: B32 + [254, 257], c8: B32 + [254],
    rgb24: B32 + [0xfffffe, 0x100_0001], styles: B32 + [0x1_0000, 0x1f, F::NCSTYLE_MASK],
    key: KEY_RANGES.flat_map { |a, b| [a - 1, a, a + 1, b - 1, b, b + 1] } + B32,
    align: [0, 1, 2, 3, -1, 4, 0x7fff_ffff, -0x8000_0000],
    pidx: [-1, -2, 0, 1, 255, 256, 257, 0x7fff_ffff, -0x8000_0000],
    umax: [0, 1, 9, 10, 999, 1000, 1023, 1024, 1025, 999_999, 10**18, 2**63, M64 - 1023, M64, -1],
    dec: [0, 1, 10, 100, 1000, 1024, M64 / 10, M64 / 10 + 1, M64, -1],
    omit: [0, 1, -1]
  }.freeze

  # [gcluster, gcluster_backstop, width, stylemask, channels] di celle di bordo
  CELL_BOUNDS = [
    [0, 0, 0, 0, 0], [0, 0, 1, 0, 0], [0, 0, 2, 0, 0], [0x41, 0, 2, 0, 0], [0x41, 0, 1, 0xffff, M64],
    [0x41, 0, 255, 0, F::NC_NOBACKGROUND_MASK], [M32, 0, 3, 0x1f, F::NC_BGDEFAULT_MASK * 0x1_0000_0001],
    [0x100_0000, 0, 1, 0, (F::NC_BG_PALETTE | F::NC_BGDEFAULT_MASK | 5) * 0x1_0000_0001]
  ].map { |a| a.pack('VCCvQ<') }.freeze

  U32P = %i[uint32 chan32].freeze # uint32_t* inizializzato con un canale
  U64P = %i[uint64 chan64].freeze # uint64_t* inizializzato con una coppia di canali
  PIXP = %i[uint32 u32].freeze    # uint32_t* con un pixel

  # Funzioni pure: tipo semantico di ogni parametro (vedi Helpers#gen e #tmpl).
  PURE = {
    nckey_synthesized_p: [:key], nckey_pua_p: [:key], nckey_supppuaa_p: [:key], nckey_supppuab_p: [:key],
    nckey_mouse_p: [:key],
    ncchannel_alpha: [:chan32], ncchannel_set_alpha: [U32P, :alpha], ncchannel_default_p: [:chan32],
    ncchannel_set_default: [U32P], ncchannel_palindex_p: [:chan32], ncchannel_palindex: [:chan32],
    ncchannel_set_palindex: [U32P, :idx], ncchannel_rgb_p: [:chan32], ncchannel_r: [:chan32],
    ncchannel_g: [:chan32], ncchannel_b: [:chan32], ncchannel_rgb: [:chan32],
    ncchannel_rgb8: %i[chan32 out out out], ncchannel_set_rgb8: [U32P, :c8, :c8, :c8],
    ncchannel_set: [U32P, :rgb24], ncchannel_set_rgb8_clipped: [U32P, :clip, :clip, :clip],
    ncchannels_bchannel: [:chan64], ncchannels_fchannel: [:chan64], ncchannels_channels: [:chan64],
    ncchannels_bg_rgb_p: [:chan64], ncchannels_fg_rgb_p: [:chan64], ncchannels_bg_alpha: [:chan64],
    ncchannels_set_bchannel: [U64P, :chan32], ncchannels_set_fchannel: [U64P, :chan32],
    ncchannels_set_channels: [U64P, :chan64], ncchannels_set_bg_alpha: [U64P, :alpha],
    ncchannels_fg_alpha: [:chan64], ncchannels_set_fg_alpha: [U64P, :alpha], ncchannels_reverse: [:chan64],
    ncchannels_combine: %i[chan32 chan32], ncchannels_fg_palindex: [:chan64], ncchannels_bg_palindex: [:chan64],
    ncchannels_fg_rgb: [:chan64], ncchannels_bg_rgb: [:chan64], ncchannels_fg_rgb8: %i[chan64 out out out],
    ncchannels_bg_rgb8: %i[chan64 out out out], ncchannels_set_fg_rgb8: [U64P, :c8, :c8, :c8],
    ncchannels_set_fg_rgb8_clipped: [U64P, :clip, :clip, :clip], ncchannels_set_fg_palindex: [U64P, :idx],
    ncchannels_set_fg_rgb: [U64P, :rgb24], ncchannels_set_bg_rgb8: [U64P, :c8, :c8, :c8],
    ncchannels_set_bg_rgb8_clipped: [U64P, :clip, :clip, :clip], ncchannels_set_bg_palindex: [U64P, :idx],
    ncchannels_set_bg_rgb: [U64P, :rgb24], ncchannels_fg_default_p: [:chan64],
    ncchannels_fg_palindex_p: [:chan64], ncchannels_bg_default_p: [:chan64], ncchannels_bg_palindex_p: [:chan64],
    ncchannels_set_fg_default: [U64P], ncchannels_set_bg_default: [U64P],
    nccell_init: [:cell], nccell_set_styles: %i[cell styles], nccell_styles: [:cell],
    nccell_on_styles: %i[cell styles], nccell_off_styles: %i[cell styles], nccell_set_fg_default: [:cell],
    nccell_set_bg_default: [:cell], nccell_set_fg_alpha: %i[cell alpha], nccell_set_bg_alpha: %i[cell alpha],
    nccell_set_bchannel: %i[cell chan32], nccell_set_fchannel: %i[cell chan32],
    nccell_set_channels: %i[cell chan64], nccell_double_wide_p: [:cell], nccell_wide_right_p: [:cell],
    nccell_wide_left_p: [:cell], nccell_channels: [:cell], nccell_bchannel: [:cell], nccell_fchannel: [:cell],
    nccell_cols: [:cell], nccell_fg_rgb: [:cell], nccell_bg_rgb: [:cell], nccell_fg_alpha: [:cell],
    nccell_bg_alpha: [:cell], nccell_fg_rgb8: %i[cell out out out], nccell_bg_rgb8: %i[cell out out out],
    nccell_set_fg_rgb8: %i[cell c8 c8 c8], nccell_set_fg_rgb8_clipped: %i[cell clip clip clip],
    nccell_set_fg_rgb: %i[cell rgb24], nccell_set_fg_palindex: %i[cell idx], nccell_fg_palindex: [:cell],
    nccell_set_bg_rgb8: %i[cell c8 c8 c8], nccell_set_bg_rgb8_clipped: %i[cell clip clip clip],
    nccell_set_bg_rgb: %i[cell rgb24], nccell_set_bg_palindex: %i[cell idx], nccell_bg_palindex: [:cell],
    nccell_fg_default_p: [:cell], nccell_fg_palindex_p: [:cell], nccell_bg_default_p: [:cell],
    nccell_bg_palindex_p: [:cell],
    ncinput_shift_p: [:input], ncinput_ctrl_p: [:input], ncinput_alt_p: [:input], ncinput_meta_p: [:input],
    ncinput_super_p: [:input], ncinput_hyper_p: [:input], ncinput_capslock_p: [:input],
    ncinput_numlock_p: [:input], ncinput_equal_p: %i[input input_like], ncinput_nomod_p: [:input],
    ncpalette_set_rgb8: %i[pal pidx c8 c8 c8], ncpalette_set: %i[pal pidx rgb24],
    ncpalette_get: [:pal, :pidx, %i[uint32 u32]], ncpalette_get_rgb8: %i[pal pidx out out out],
    nccapability_canchangecolor: [:caps], notcurses_align: %i[int align int],
    ncpixel_a: [:u32], ncpixel_r: [:u32], ncpixel_g: [:u32], ncpixel_b: [:u32],
    ncpixel_set_a: [PIXP, :c8], ncpixel_set_r: [PIXP, :c8], ncpixel_set_g: [PIXP, :c8],
    ncpixel_set_b: [PIXP, :c8], ncpixel: %i[c8 c8 c8], ncpixel_set_rgb8: [PIXP, :c8, :c8, :c8],
    ncqprefix: %i[umax dec buf omit], nciprefix: %i[umax dec buf omit], ncbprefix: %i[umax dec buf omit]
  }.freeze

  # --- testo per put*/printf*/box*: ASCII, multibyte, emoji, combinanti, NUL interno,
  # più lungo del piano, UTF-8 non valido, controlli, newline
  FAMILY = "\u{1f468}\u{200d}\u{1f469}\u{200d}\u{1f467}" # EGC di 18 byte: va nell'egcpool
  TEXTS = ['', 'a', 'Hello', 'àèìòù ñ', 'Ελλάδα', "e\u{301}a\u{308}\u{323}", '日本語', "\u{1f600}",
           "\u{1f44d}\u{1f3fd}", FAMILY, "\u{1f1ee}\u{1f1f9}", "\u{2764}\u{fe0f}", "1\u{fe0f}\u{20e3}",
           "a日b\u{1f600}c", 'x' * 40, '日' * 20, "riga1\nriga2", "\u{200b}z", "\u{ad}w", "ctl\u0001x",
           "del\u007f", "bad\xffbyte".b, "tronco\xc3".b, "a\0b", 'a b c d e f g h i j k l m n o p'].freeze
  TAB_TEXTS = ["a\tb", "\tz"].freeze
  WIDE = ['日', "\u{1f600}", FAMILY].freeze
  FILL_GLYPHS = ['a', 'Z', 'é', '日', "\u{1f600}", "e\u{301}", FAMILY, ' ', '─', 'ß'].freeze
  CELL_EGCS = ['a', 'é', '日', "\u{1f600}", "e\u{301}", FAMILY, "\u{1f44d}\u{1f3fd}", ' ', '─', 'ß',
               "\u{200b}", "\n"].freeze
  PRIME_STRS = (CELL_EGCS + ['', 'abc', 'ab日', "\xff".b, "a\0b", "\u0001", "\t", '日本語', "#{FAMILY}x",
                             "\u{1f1ee}\u{1f1f9}"]).freeze
  BOX_STRS = [F::NCBOXLIGHT, F::NCBOXHEAVY, F::NCBOXROUND, F::NCBOXDOUBLE, F::NCBOXASCII, F::NCBOXOUTER,
              'abcdef', 'ab', '', '日本語テキスト', "#{FAMILY}abcde", "a\0bcdef", "\xffabcde".b, "abcde\u0001",
              'abcde', "\u{1f600}" * 6, "e\u{301}" * 6].freeze
  # code point per putwc*/pututf32: validi, larghi, combinanti, controlli, surrogati, oltre Unicode
  WCHARS = [0x41, 0x7a, 0xe9, 0x3b1, 0x4e00, 0x1f600, 0x301, 0x200b, 0xad, 0, 0x0a, 0x01, 0x7f, 0xd800,
            0xdfff, 0xfffd, 0x10_ffff, 0x11_0000, 0x1f_ffff, 0x20_0000, 0x7fff_ffff, -1, -0x8000_0000].freeze
  # vettori wchar_t speciali (oltre a quelli ricavati da TEXTS); niente code point >= 0x200000
  # per putwstr: glibc li codifica in 5-6 byte e il buffer C da 4 byte per carattere resta senza NUL
  WSPECIAL = [[0xd800, 0x41], [0x11_0000], [0x10_ffff, 0x41], [], [0x4e00, 0x301], [-1], [0x41, 0xdfff]].freeze
  CHARS = [65, 97, 0x20, 0, 1, 10, 0x7f, 0x80, 0xc3, 0xe9, 0xff, -1, -61, -128, 127, 256 + 65,
           0x7fff_ffff, -0x8000_0000].freeze
  ALIGNS = [F::NCALIGN_UNALIGNED, F::NCALIGN_LEFT, F::NCALIGN_CENTER, F::NCALIGN_RIGHT, -1, 7].freeze
  # formato + varargs ruby-ffi (coppie tipo/valore)
  PRINTF = [
    ['%d-%s', :int, 42, :string, 'x'],
    ['%s', :string, "Hello 日本 \u{1f600}"],
    ['%5.2f|%c|%%', :double, 3.14159, :int, 65],
    ['%c', :int, 0],
    ['%x %X %o', :uint, 0xdead_beef, :uint, 255, :uint, 8],
    ['%lu %ld', :ulong, M64, :long, -5],
    ['%9000d', :int, 7], # oltre BUFSIZ: il C rialloca e ripete vsprintf
    ['%-12s|', :string, 'àè'],
    ['senza argomenti'],
    ['%s %s %s %s %s %s %s %s', *%w[a b c d e f g h].flat_map { |s| [:string, s] }], # oltre i registri
    [(['%.1f'] * 9).join(' '), *(1..9).flat_map { |i| [:double, i / 3.0] }],
    ["riga\n%d", :int, 1],
    ['%s', :string, "a\0b"], # NUL interno in un argomento :string: ArgumentError da ruby-ffi
    ["fmt\0nul"],            # NUL interno nel formato
    ['%s', :string, "bad\xffbyte".b],
    ['%s', :string, 'x' * 50],
    ['%s', :string, '日' * 12]
  ].freeze

  # Valori attesi delle macro: output di macros.c (gcc -O0 macros.c -lnotcurses-core, LANG=it_IT.UTF-8).
  module Expected
    PRETERUNICODE = [
      [[0], 1115000], [[1], 1115001], [[2], 1115002], [[12], 1115012], [[20], 1115020], [[200], 1115200],
      [[211], 1115211], [[500], 1115500], [[1000], 1116000], [[-1], 1114999], [[-1115000], 0],
      [[-2147483648], -2146368648], [[2146368647], 2147483647]
    ].freeze
    CHANNEL_INIT = [
      [[0, 0, 0], 1073741824], [[255, 255, 255], 1090519039], [[1, 2, 3], 1073807875],
      [[18, 52, 86], 1074934870], [[256, 0, 0], 1090519040], [[0, 256, 0], 1073807360],
      [[0, 0, 256], 1073742080], [[65535, 0, 0], 5368643584], [[-1, -1, -1], 5368643327],
      [[65536, 0, 0], 1073741824], [[2147483647, 2147483647, 2147483647], 3221159679],
      [[0, 0, -1], 5368709119]
    ].freeze
    CHANNELS_INIT = [
      [[0, 0, 0, 0, 0, 0], 4611686019501129728], [[255, 255, 255, 255, 255, 255], 4683743609260867583],
      [[1, 2, 3, 4, 5, 6], 4611969706386261254], [[255, 128, 0, 16, 32, 48], 4683602876051759152],
      [[-1, -1, -1, -1, -1, -1], 4611403445012725503], [[65535, 0, 0, 0, 0, 0], 4611404544524419072],
      [[4660, 86, 120, 154, 188, 222], 5923454484378991838], [[0, 0, 0, 65535, 255, 255], 4611686023796097023]
    ].freeze
    # [argomenti, [gcluster, gcluster_backstop, width, stylemask, channels]]
    CELL_INIT = [
      [[65, 0, 0], [65, 0, 1, 0, 0]], [[0, 0, 0], [0, 0, 1, 0, 0]],
      [[122, 31, 4611686019501129728], [122, 0, 1, 31, 4611686019501129728]],
      [[127, 1, 1], [127, 0, 1, 1, 1]],
      [[7, 65535, 18446744073709551615], [7, 0, 1, 65535, 18446744073709551615]],
      [[233, 65536, 1311768467463790320], [233, 0, 1, 0, 1311768467463790320]],
      [[19968, 74565, 0], [19968, 0, 2, 9029, 0]], [[128512, 2, 4294967295], [128512, 0, 2, 2, 4294967295]],
      [[769, 0, 0], [769, 0, 0, 0, 0]], [[8203, 0, 0], [8203, 0, 0, 0, 0]], [[55296, 0, 0], [55296, 0, 1, 0, 0]],
      [[4294967295, 4294967295, 0], [4294967295, 0, 1, 65535, 0]],
      [[2147483648, 0, 0], [2147483648, 0, 1, 0, 0]], [[1114112, 0, 0], [1114112, 0, 1, 0, 0]],
      [[-1, 0, 0], [4294967295, 0, 1, 0, 0]]
    ].freeze
    CELL_CHAR_INIT = [
      [[65], [65, 0, 1, 0, 0]], [[0], [0, 0, 1, 0, 0]], [[19968], [19968, 0, 2, 0, 0]], [[769], [769, 0, 0, 0, 0]],
      [[7], [7, 0, 1, 0, 0]], [[4294967295], [4294967295, 0, 1, 0, 0]], [[128512], [128512, 0, 2, 0, 0]],
      [[233], [233, 0, 1, 0, 0]], [[8203], [8203, 0, 0, 0, 0]]
    ].freeze
    CELL_TRIVIAL = [0, 0, 1, 0, 0].freeze
    # [x, cols, NCMETRICFWIDTH(x, cols)]
    METRICFWIDTH = [
      ['', 0, 0], ['', 7, 7], ['', 8, 8], ['', 9, 9], ['', -1, -1], ['', 2147483647, 2147483647],
      ['', -2147483648, -2147483648],
      ['abc', 0, 0], ['abc', 7, 7], ['abc', 8, 8], ['abc', 9, 9], ['abc', -1, -1], ['abc', 2147483647, 2147483647],
      ['abc', -2147483648, -2147483648],
      ['1.00K', 0, 0], ['1.00K', 7, 7], ['1.00K', 8, 8], ['1.00K', 9, 9], ['1.00K', -1, -1],
      ['1.00K', 2147483647, 2147483647], ['1.00K', -2147483648, -2147483648],
      ['999', 0, 0], ['999', 7, 7], ['999', 8, 8], ['999', 9, 9], ['999', -1, -1], ['999', 2147483647, 2147483647],
      ['999', -2147483648, -2147483648],
      ['1.50Mi', 0, 0], ['1.50Mi', 7, 7], ['1.50Mi', 8, 8], ['1.50Mi', 9, 9], ['1.50Mi', -1, -1],
      ['1.50Mi', 2147483647, 2147483647], ['1.50Mi', -2147483648, -2147483648],
      ["12.3\xc2\xb5", 0, 1], ["12.3\xc2\xb5", 7, 8], ["12.3\xc2\xb5", 8, 9], ["12.3\xc2\xb5", 9, 10],
      ["12.3\xc2\xb5", -1, 0], ["12.3\xc2\xb5", 2147483647, -2147483648], ["12.3\xc2\xb5", -2147483648, -2147483647],
      ["\xe6\x97\xa5\xe6\x9c\xac", 0, 2], ["\xe6\x97\xa5\xe6\x9c\xac", 7, 9], ["\xe6\x97\xa5\xe6\x9c\xac", 8, 10],
      ["\xe6\x97\xa5\xe6\x9c\xac", 9, 11], ["\xe6\x97\xa5\xe6\x9c\xac", -1, 1],
      ["\xe6\x97\xa5\xe6\x9c\xac", 2147483647, -2147483647], ["\xe6\x97\xa5\xe6\x9c\xac", -2147483648, -2147483646],
      ["\xff", 0, 2], ["\xff", 7, 9], ["\xff", 8, 10], ["\xff", 9, 11], ["\xff", -1, 1],
      ["\xff", 2147483647, -2147483647], ["\xff", -2147483648, -2147483646],
      ["a\xffb", 0, 4], ["a\xffb", 7, 11], ["a\xffb", 8, 12], ["a\xffb", 9, 13], ["a\xffb", -1, 3],
      ["a\xffb", 2147483647, -2147483645], ["a\xffb", -2147483648, -2147483644],
      ["\xf0\x9f\x98\x80x", 0, 2], ["\xf0\x9f\x98\x80x", 7, 9], ["\xf0\x9f\x98\x80x", 8, 10],
      ["\xf0\x9f\x98\x80x", 9, 11], ["\xf0\x9f\x98\x80x", -1, 1], ["\xf0\x9f\x98\x80x", 2147483647, -2147483647],
      ["\xf0\x9f\x98\x80x", -2147483648, -2147483646]
    ].freeze
    # [x, primo argomento printf, il secondo è x stesso?, snprintf("%*s|", NC*PREFIXFMT(x))]
    PREFIXFMT = [
      ['1.00K', 7, true, '  1.00K|'], ["12.3\xc2\xb5", 8, true, "  12.3\xc2\xb5|"], ['', 7, true, '       |'],
      ["\xe6\x97\xa5\xe6\x9c\xac", 9, true, "   \xe6\x97\xa5\xe6\x9c\xac|"], ['1023.99Ki', 7, true, '1023.99Ki|'],
      ["\xff", 9, true, "        \xff|"]
    ].freeze
    IPREFIXFMT = [
      ['1.00K', 8, true, '   1.00K|'], ["12.3\xc2\xb5", 9, true, "   12.3\xc2\xb5|"], ['', 8, true, '        |'],
      ["\xe6\x97\xa5\xe6\x9c\xac", 10, true, "    \xe6\x97\xa5\xe6\x9c\xac|"], ['1023.99Ki', 8, true, '1023.99Ki|'],
      ["\xff", 10, true, "         \xff|"]
    ].freeze
    BPREFIXFMT = [
      ['1.00K', 9, true, '    1.00K|'], ["12.3\xc2\xb5", 10, true, "    12.3\xc2\xb5|"], ['', 9, true, '         |'],
      ["\xe6\x97\xa5\xe6\x9c\xac", 11, true, "     \xe6\x97\xa5\xe6\x9c\xac|"], ['1023.99Ki', 9, true, '1023.99Ki|'],
      ["\xff", 11, true, "          \xff|"]
    ].freeze
    HTOLE = [[0, 0], [1, 1], [305419896, 305419896], [4294967295, 4294967295], [2147483648, 2147483648],
             [255, 255], [4294967297, 1], [-1, 4294967295]].freeze
    VERSION_COMPARABLE = [
      [[3, 0, 17], 196625], [[0, 0, 0], 0], [[1, 2, 3], 66051], [[255, 255, 255], 16777215],
      [[32767, 255, 255], 2147483647], [[0, 0, -1], -1], [[0, 256, 0], 65536], [[1, 0, -1], 65535]
    ].freeze
  end

  # Vettore C di `type` con contenuto iniziale `values`: ogni lato ne riceve una copia nuova.
  Mem = Struct.new(:type, :values) do
    def build
      ::FFI::MemoryPointer.new(type, values.size).tap { |p| p.public_send(:"put_array_of_#{type}", 0, values) }
    end

    def dump(ptr) = ptr.get_bytes(0, ptr.size).unpack1('H*')
    def inspect = "#{type}[#{values.join(',')}]"
  end

  # Struct C dai byte `bytes`; `size` > klass.size alloca un buffer più grande (palette, vedi tmpl).
  Raw = Struct.new(:klass, :bytes, :size) do
    def build
      mp = ::FFI::MemoryPointer.new(:uint8, size || klass.size)
      mp.put_bytes(0, bytes)
      klass.new(mp)
    end

    def dump(obj) = obj.pointer.get_bytes(0, size || klass.size).unpack1('H*')
    def inspect = "#{klass.name.split('::').last}(#{bytes.unpack1('H*')})"
  end

  # Ricetta di un piano: dimensioni, scrolling, canali/stili, contenuto iniziale, cursore (cx :end = x == lenx).
  PlaneSpec = Struct.new(:rows, :cols, :scroll, :chans, :styles, :fill, :cy, :cx) do
    def inspect = "#{rows}x#{cols}#{' scroll' if scroll} fill=#{fill.size} cur=#{cy},#{cx} ch=#{chans} st=#{styles}"
  end
  CELL_PLANE = PlaneSpec.new(2, 4, false, 0, 0, [], 0, 0).freeze # piano (egcpool) per le nccell_*

  module LibcIO
    extend ::FFI::Library
    ffi_lib ::FFI::Library::LIBC
    attach_function :fdopen, %i[int string], :pointer
  end

  def self.quiet_stdout
    $stdout.flush
    saved = $stdout.dup
    $stdout.reopen(File::NULL, 'w')
    yield
  ensure
    if saved
      $stdout.reopen(saved)
      saved.close
    end
  end

  # Unico contesto notcurses della suite, su /dev/null.
  module Ctx
    FLAGS = F::NCOPTION_SUPPRESS_BANNERS | F::NCOPTION_NO_QUIT_SIGHANDLERS |
            F::NCOPTION_NO_WINCH_SIGHANDLER | F::NCOPTION_DRAIN_INPUT
    # terminfo fisso: con TERM assente o dumb (CI) notcurses_init restituirebbe NULL
    TERMTYPE = 'xterm-256color'

    class << self
      attr_reader :nc

      def start
        return @nc if @nc
        @fp = F.fopen('/dev/null', 'w')
        opts = F::NotcursesOptions.new
        opts[:flags] = FLAGS
        @tt = ::FFI::MemoryPointer.from_string(TERMTYPE) # resta vivo quanto il contesto
        opts[:termtype] = @tt
        nc = F.notcurses_init(opts, @fp)
        raise 'notcurses_init su /dev/null fallita' if nc.null?
        @nc = nc
        at_exit { stop } unless @hooked
        @hooked = true
        @nc
      end

      def stop
        return unless @nc
        F.notcurses_stop(@nc)
        F.fclose(@fp)
        @nc = nil
      end
    end
  end

  # Contesto ncdirect: :null (fopen('/dev/null','w')) o :pipe (FILE* su una pipe, per leggere l'output).
  module Direct
    FLAGS = F::NCDIRECT_OPTION_NO_QUIT_SIGHANDLERS | F::NCDIRECT_OPTION_DRAIN_INPUT

    class << self
      attr_reader :d

      def start(out)
        raise 'contesto notcurses attivo: ncdirect_core_init fallirebbe' if Ctx.nc
        if out == :pipe
          @rd, wr = IO.pipe
          wr.autoclose = false # il descrittore passa al FILE*, lo chiude fclose
          @fp = LibcIO.fdopen(wr.fileno, 'w')
        else
          @fp = F.fopen('/dev/null', 'w')
        end
        d = F.ncdirect_core_init(Ctx::TERMTYPE, @fp, FLAGS)
        raise 'ncdirect_core_init fallita' if d.null?
        @d = d
        at_exit { stop } unless @hooked
        @hooked = true
        @d
      end

      # byte scritti sul FILE* dall'ultima chiamata (solo :pipe)
      def output
        F.ncdirect_flush(@d)
        out = +''
        loop do
          s = @rd.read_nonblock(65_536, exception: false)
          break unless s.is_a?(String)
          out << s
        end
        out.b
      end

      def stop
        return unless @d
        InlineReimplSpec.quiet_stdout { F.ncdirect_stop(@d) } # scrive il reset dei colori su stdout
        F.fclose(@fp)
        @rd&.close
        @d = @rd = nil
      end
    end
  end

  # Registra un esempio di confronto per un'inline o una macro.
  module DSL
    def diff(name, min: 1, &body)
      raise ArgumentError, "#{name}: né inline né macro" unless INLINE_NAMES.include?(name) || MACRO_NAMES.include?(name)
      (COVERED[name] ||= []) << description
      it(name.to_s) do
        @ncase = 0
        @rng = Random.new(SEED ^ Zlib.crc32(name.to_s))
        instance_exec(name, &body)
        expect(@ncase).to be >= min
      end
    end
  end

  module Helpers
    def nc = Ctx.nc
    def std = F.notcurses_stdplane(Ctx.nc)
    def dd = Direct.d
    def pick(arr) = arr[@rng.rand(arr.size)]

    # --- confronto

    # Esegue il caso con m = reimplementazione e m = oracolo; confronta i risultati normalizzati.
    def twin(name, desc)
      r = yield F
      o = yield O
      @ncase += 1
      return if r == o
      d = desc.respond_to?(:call) ? desc.call : desc
      expect(r).to eq(o), "#{name}(#{d})\n  reimpl: #{r.inspect[0, 1200]}\n  oracle: #{o.inspect[0, 1200]}\n  " \
                          "#{first_diff(r, o)}"
    end

    # Macro: confronto con il valore atteso calcolato in C.
    def const_case(name, desc, got, exp)
      @ncase += 1
      expect(got).to eq(exp), "#{name}(#{desc}): ottenuto #{got.inspect}, atteso (C) #{exp.inspect}"
    end

    def first_diff(a, b, path = [])
      if a.instance_of?(b.class) && a.is_a?(Array) && a.size == b.size
        i = a.each_index.find { |k| a[k] != b[k] }
        return first_diff(a[i], b[i], path + [i]) if i
      elsif a.instance_of?(b.class) && a.is_a?(Hash) && a.keys == b.keys
        k = a.keys.find { |key| a[key] != b[key] }
        return first_diff(a[k], b[k], path + [k]) if k
      end
      "prima differenza in /#{path.join('/')}: #{a.inspect[0, 300]} != #{b.inspect[0, 300]}"
    end

    # Valore restituito (o classe dell'eccezione) in forma confrontabile, tipo Ruby compreso.
    def call
      norm(yield)
    rescue StandardError => e
      [:raise, e.class.name]
    end

    def norm(val)
      case val
      when ::FFI::Pointer then [:ptr, val.address]
      when String then [:str, val.encoding.name, val.b]
      when Array then val.map { |x| norm(x) }
      when Integer, true, false, nil then val
      else [:other, val.class.name]
      end
    end

    # char* restituito con ALLOC: contenuto, poi free()
    def heap(val)
      return val unless val.is_a?(::FFI::Pointer) && !val.null?
      s = val.read_string.b
      F.free(val)
      [:heap, s]
    end

    # --- generatori (requisito: bordi, negativi anche per i senza segno, casuali)

    def r32
      case @rng.rand(10)
      when 0 then -@rng.rand(1..0x8000_0000) # negativo: FFI lo converte in complemento a 2
      when 1 then pick(B32)
      else @rng.rand(2**32)
      end
    end

    def r64
      case @rng.rand(10)
      when 0 then -@rng.rand(1..2**63)
      when 1 then pick(B64)
      when 2 then (@rng.rand(2**32) << 32) | (pick(B32) & M32)
      else @rng.rand(2**64)
      end
    end

    def rint = @rng.rand(4).zero? ? pick(BINT) : @rng.rand(-2**31...2**31)

    def gen(type)
      case type
      when :u32, :chan32 then r32
      when :chan64 then r64
      when :int then rint
      when :clip then @rng.rand(3).zero? ? rint : @rng.rand(-300..300)
      when :alpha then @rng.rand(4).zero? ? r32 : pick(ALPHAS)
      when :idx then @rng.rand(4).zero? ? r32 : @rng.rand(-2..300)
      when :c8 then @rng.rand(4).zero? ? r32 : @rng.rand(-2..260)
      when :rgb24 then @rng.rand(4).zero? ? r32 : @rng.rand(0..0x100_0010)
      when :styles then @rng.rand(3).zero? ? r32 : @rng.rand(0..0x3f)
      when :key
        a, b = pick(KEY_RANGES)
        @rng.rand(3).zero? ? r32 : @rng.rand(a - 3..b + 3)
      when :align then @rng.rand(3).zero? ? rint : @rng.rand(0..3)
      when :pidx then @rng.rand(3).zero? ? rint : @rng.rand(-2..258)
      when :umax then @rng.rand(3).zero? ? r64 : @rng.rand(1..999) * 10**@rng.rand(0..16)
      when :dec then @rng.rand(3).zero? ? r64 : pick([1, 10, 100, 1000, 1024])
      when :omit then @rng.rand(4).zero? ? rint : @rng.rand(0..1)
      else raise ArgumentError, type.inspect
      end
    end

    # Argomento di un caso puro: valore, oppure modello (Mem/Raw) da cui ogni lato costruisce la sua copia.
    def tmpl(type, bound = nil)
      case type
      when Array then Mem.new(type[0], [bound.nil? ? gen(type[1]) : bound])
      when :out then Mem.new(:uint, [@rng.rand(2**32)]) # unsigned* di uscita, contenuto iniziale casuale
      when :buf then Mem.new(:uint8, Array.new(64) { @rng.rand(256) })
      when :cell then Raw.new(F::NcCell, bound || rcell)
      when :input then Raw.new(F::NcInput, bound || rinput)
      when :caps then Raw.new(F::NcCapabilities, bound || rcaps)
      # chans[256] (idx == NCPALETTESIZE, accettato dal C) cade dentro il buffer allargato
      when :pal then Raw.new(F::NcPalette, @rng.bytes(F::NcPalette.size + 4), F::NcPalette.size + 8)
      else bound.nil? ? gen(type) : bound
      end
    end

    def bounds(type)
      case type
      when Array then BOUNDS.fetch(type[1])
      when :out, :buf, :pal, :input_like then []
      when :cell then CELL_BOUNDS
      when :input then input_bounds
      when :caps then caps_bounds
      else BOUNDS.fetch(type)
      end
    end

    def rcell
      gc = case @rng.rand(4)
           when 0 then 0
           when 1 then @rng.rand(0x20..0x7e)
           else @rng.rand(2**32)
           end
      w = @rng.rand(3).zero? ? @rng.rand(256) : @rng.rand(0..2)
      [gc, 0, w, @rng.rand(2**16), r64 & M64].pack('VCCvQ<')
    end

    def struct_bytes(klass, **fields)
      s = klass.new
      fields.each { |k, v| s[k] = v }
      yield s if block_given?
      s.pointer.get_bytes(0, klass.size)
    end

    def rinput
      struct_bytes(F::NcInput,
                   id: pick([r32 & M32, @rng.rand(0x11_0000), F::NCKEY_UP, F::NCKEY_BUTTON1, F::NCKEY_EOF]),
                   y: rint, x: rint, alt: @rng.rand(2) == 1, shift: @rng.rand(2) == 1, ctrl: @rng.rand(2) == 1,
                   evtype: @rng.rand(3).zero? ? rint : @rng.rand(0..3),
                   modifiers: @rng.rand(3).zero? ? r32 & M32 : @rng.rand(0..255),
                   ypx: @rng.rand(2).zero? ? -1 : rint, xpx: @rng.rand(2).zero? ? -1 : rint) do |s|
        s.pointer.put_bytes(F::NcInput.offset_of(:utf8), @rng.bytes(5))
        s.pointer.put_array_of_uint32(F::NcInput.offset_of(:eff_text), Array.new(4) { @rng.rand(2**32) })
      end
    end

    def input_bounds
      [struct_bytes(F::NcInput), struct_bytes(F::NcInput, modifiers: M32),
       struct_bytes(F::NcInput, modifiers: F::NCKEY_MOD_CAPSLOCK | F::NCKEY_MOD_NUMLOCK),
       struct_bytes(F::NcInput, id: F::NCKEY_BUTTON1, evtype: F::NCTYPE_RELEASE, modifiers: 0x3f)]
    end

    # secondo ncinput di ncinput_equal_p: copia del primo con una sola modifica (spesso ininfluente)
    def perturb_input(bytes)
      struct_bytes(F::NcInput) do |s|
        s.pointer.put_bytes(0, bytes)
        case @rng.rand(12)
        when 0 then nil
        when 1 then s[:id] = (s[:id] + 1) & M32
        when 2 then s[:y] = s[:y] == 0x7fff_ffff ? 0 : s[:y] + 1
        when 3 then s[:x] ^= 1
        when 4 then s[:modifiers] ^= pick([F::NCKEY_MOD_CAPSLOCK, F::NCKEY_MOD_NUMLOCK, 0xc0])
        when 5 then s[:modifiers] ^= 1 << @rng.rand(32)
        when 6 then s[:evtype] = pick([F::NCTYPE_UNKNOWN, F::NCTYPE_PRESS, F::NCTYPE_REPEAT, F::NCTYPE_RELEASE, rint])
        when 7 then s[:ypx] = rint
        when 8 then s[:xpx] = rint
        when 9 then s.pointer.put_bytes(F::NcInput.offset_of(:utf8), @rng.bytes(5))
        when 10 then s[:alt] = !s[:alt]
        else s.pointer.put_array_of_uint32(F::NcInput.offset_of(:eff_text), Array.new(4) { @rng.rand(2**32) })
        end
      end
    end

    CAPS_BOOLS = %i[utf8 rgb can_change_colors halfblocks quadrants sextants octants braille].freeze

    def rcaps
      struct_bytes(F::NcCapabilities, colors: pick([0, 1, 8, 16, 88, 255, 256, 257, 0x7fff_ffff, M32,
                                                    @rng.rand(2**32), @rng.rand(512)])) do |s|
        CAPS_BOOLS.each { |f| s[f] = @rng.rand(2) == 1 }
      end
    end

    def caps_bounds
      [255, 256, 257, 0, M32].product([true, false]).map do |colors, ccc|
        struct_bytes(F::NcCapabilities, colors: colors, can_change_colors: ccc)
      end
    end

    # --- funzioni pure

    def mkcase(types)
      prev = nil
      types.each_with_index.map do |t, j|
        b = yield(t, j) if block_given?
        prev = t == :input_like ? Raw.new(F::NcInput, perturb_input(prev.bytes)) : tmpl(t, b)
      end
    end

    # Bordi parametro per parametro, 40 casi con tutti i parametri ai bordi, NRAND casi casuali.
    def pure(name, types)
      cases = []
      types.each_with_index do |t, i|
        bounds(t).each { |b| cases << mkcase(types) { |_, j| b if j == i } }
      end
      40.times { cases << mkcase(types) { |t, _| (bs = bounds(t)).empty? ? nil : pick(bs) } }
      NRAND.times { cases << mkcase(types) }
      cases.each do |tm|
        twin(name, -> { tm.map(&:inspect).join(', ') }) do |m|
          args = tm.map { |a| a.respond_to?(:build) ? a.build : a }
          [call { m.public_send(name, *args) }, tm.zip(args).filter_map { |a, o| a.dump(o) if a.respond_to?(:dump) }]
        end
      end
    end

    # --- piani

    def rplane(scroll: @rng.rand(2).zero?, rows: nil, cols: nil, fill: true)
      rows ||= pick([1, 2, 3, 5])
      cols ||= pick(scroll ? [6, 10, 16] : [1, 4, 10, 16])
      fills = fill ? Array.new(@rng.rand(0..(rows * cols / 2))) { rfill(rows, cols) } : []
      cx = @rng.rand(8).zero? ? :end : @rng.rand(cols)
      styles = @rng.rand(2).zero? ? @rng.rand(0x20) : @rng.rand(0x1_0000)
      PlaneSpec.new(rows, cols, scroll, r64 & M64, styles, fills, @rng.rand(rows), cx)
    end

    # piano per le *_stained: non scorrevole, cursore sopra l'ultima riga (vedi bug noti)
    def rplane_stained
      ps = rplane(scroll: false, rows: pick([2, 3, 5]))
      ps.cy = @rng.rand(ps.rows - 1)
      ps
    end

    def rfill(rows, cols)
      x = @rng.rand(cols)
      g = pick(FILL_GLYPHS)
      g = 'w' if WIDE.include?(g) && x > cols - 3
      [@rng.rand(rows), x, g, r64 & M64, @rng.rand(0x20)]
    end

    def mkplane(ps, parent = nil)
      o = F::NcPlaneOptions.new
      o[:rows] = ps.rows
      o[:cols] = ps.cols
      pl = F.ncplane_create(parent || std, o)
      raise 'ncplane_create fallita' if pl.null?
      ps.fill.each do |y, x, g, ch, st|
        F.ncplane_set_channels(pl, ch)
        F.ncplane_set_styles(pl, st)
        F.ncplane_putegc_yx(pl, y, x, g, nil)
      end
      F.ncplane_set_channels(pl, ps.chans)
      F.ncplane_set_styles(pl, ps.styles)
      if ps.cx == :end
        F.ncplane_putegc_yx(pl, ps.cy, ps.cols - 1, '.', nil) # lascia il cursore a x == lenx
      else
        F.ncplane_cursor_move_yx(pl, ps.cy, ps.cx)
      end
      F.ncplane_set_scrolling(pl, ps.scroll ? 1 : 0)
      pl
    end

    def with_plane(ps)
      pl = mkplane(ps)
      yield pl
    ensure
      F.ncplane_destroy(pl) if pl
    end

    def dims(pl)
      dy = ::FFI::MemoryPointer.new(:uint)
      dx = ::FFI::MemoryPointer.new(:uint)
      F.ncplane_dim_yx(pl, dy, dx)
      [dy.read_uint, dx.read_uint]
    end

    def pos(pl)
      y = ::FFI::MemoryPointer.new(:int)
      x = ::FFI::MemoryPointer.new(:int)
      F.ncplane_yx(pl, y, x)
      ay = ::FFI::MemoryPointer.new(:int)
      ax = ::FFI::MemoryPointer.new(:int)
      F.ncplane_abs_yx(pl, ay, ax)
      [y.read_int, x.read_int, ay.read_int, ax.read_int]
    end

    # Stato completo del piano: ogni cella (ncplane_at_yx: egc, stylemask, channels), cursore,
    # dimensioni, posizione, canali, stili e scrolling del piano.
    def snap(pl)
      rows, cols = dims(pl)
      sm = ::FFI::MemoryPointer.new(:uint16)
      ch = ::FFI::MemoryPointer.new(:uint64)
      cells = Array.new(rows * cols) do |i|
        sm.write_uint16(0)
        ch.write_uint64(0)
        p = F.ncplane_at_yx(pl, i / cols, i % cols, sm, ch)
        egc = nil
        unless p.null?
          egc = p.read_string.b
          F.free(p)
        end
        [egc, sm.read_uint16, ch.read_uint64]
      end
      cy = ::FFI::MemoryPointer.new(:uint)
      cx = ::FFI::MemoryPointer.new(:uint)
      F.ncplane_cursor_yx(pl, cy, cx)
      { dims: [rows, cols], cursor: [cy.read_uint, cx.read_uint], pos: pos(pl), channels: F.ncplane_channels(pl),
        styles: F.ncplane_styles(pl), scrolling: F.ncplane_scrolling_p(pl), cells: cells }
    end

    # coordinate per le *_yx: dentro, sui bordi e fuori dal piano; mai x == lenx-1 se il piano scorre
    def rcoord(ps)
      x = pick([-1, -1, 0, ps.cols - 1, ps.cols, ps.cols + 3, -2, @rng.rand(ps.cols)])
      x = -1 if ps.scroll && x == ps.cols - 1
      [pick([-1, -1, 0, ps.rows - 1, ps.rows, -2, @rng.rand(ps.rows)]), x]
    end

    # un TAB non può cadere a lenx-1: piano non scorrevole, largo, scrittura che parte a x <= 1
    def tab_ok?(ps, x)
      sx = x == -1 ? ps.cx : x
      !ps.scroll && ps.cols >= 12 && sx.is_a?(Integer) && sx.between?(0, 1)
    end

    def rtext(ps, x = -1, tabs: true)
      return pick(TAB_TEXTS) if tabs && @rng.rand(8).zero? && tab_ok?(ps, x)
      pick(TEXTS)
    end

    def wvec(cps) = Mem.new(:int32, cps + [0])

    # vettore wchar_t terminato da 0, da un testo valido o da WSPECIAL
    def rwide(ps, x = -1, tabs: true)
      return wvec(pick(WSPECIAL)) if @rng.rand(6).zero?
      t = rtext(ps, x, tabs: tabs)
      t.valid_encoding? ? wvec(t.codepoints) : wvec(pick(WSPECIAL))
    end

    def rwchar(ps, x = -1)
      return 0x09 if @rng.rand(12).zero? && tab_ok?(ps, x)
      @rng.rand(4).zero? ? @rng.rand(0x11_0000) : pick(WCHARS)
    end

    def rchar(ps, x = -1)
      c = @rng.rand(3).zero? ? @rng.rand(-128..255) : pick(CHARS)
      c = 0x41 if (c & 0xff) == 0x09 && !tab_ok?(ps, x)
      c
    end

    # cella su un piano: [:trivial] | [:raw, byte] (EGC semplice) | [:load, egc, stylemask, channels]
    def rcellspec
      case @rng.rand(5)
      when 0 then [:trivial]
      when 1
        g = @rng.rand(2**32)
        g ^= 0x100_0000 if (g >> 24) == 1 # mai "estesa": l'indice nell'egcpool sarebbe inventato
        g = (g & ~0xff) | 0x41 if [0x09, 0x0a].include?(g & 0xff) # niente TAB né '\n' iniziale (bug noti)
        w = (g & 0xff).zero? ? @rng.rand(0..1) : @rng.rand(0..3) # EGC vuoto: mai width >= 2 (bug noti)
        [:raw, [g, 0, w, @rng.rand(2**16), r64 & M64].pack('VCCvQ<')]
      else [:load, pick(CELL_EGCS), @rng.rand(2**16), r64 & M64]
      end
    end

    def mkcell(pl, spec)
      c = F::NcCell.new
      case spec[0]
      when :trivial then c[:width] = 1
      when :raw then c.pointer.put_bytes(0, spec[1])
      else
        F.nccell_load(pl, c, spec[1])
        c[:stylemask] = spec[2]
        c[:channels] = spec[3]
      end
      c
    end

    # byte della cella e, se estesa, l'EGC nell'egcpool del piano
    def celldump(pl, c)
      ext = (c[:gcluster] >> 24) == 1 ? F.nccell_extended_gcluster(pl, c)&.b : nil
      [c.pointer.get_bytes(0, F::NcCell.size).unpack1('H*'), ext]
    end

    def rctl = pick([0, F::NCBOXMASK_TOP, F::NCBOXMASK_LEFT, 0x0f, 0xf0, 0x100, 0x200, 0x300, 0x3f0,
                     @rng.rand(0x400), @rng.rand(0x400), M32, -1])

    def rstyles = @rng.rand(3).zero? ? r32 : @rng.rand(0..0x1f)

    # va_list System V x86_64 { gp_offset, fp_offset, overflow_arg_area, reg_save_area }: con
    # gp_offset = 48 e fp_offset = 176 (registri esauriti) va_arg legge tutto dall'area di overflow,
    # un argomento ogni 8 byte.
    def va_list(varargs)
      pairs = varargs.each_slice(2).to_a
      area = ::FFI::MemoryPointer.new(:uint64, [pairs.size, 1].max)
      keep = [area]
      pairs.each_with_index do |(t, v), i|
        case t
        when :double then area.put_double(8 * i, v)
        when :string then area.put_pointer(8 * i, (keep << ::FFI::MemoryPointer.from_string(v)).last)
        when :int, :long then area.put_int64(8 * i, v)
        else area.put_uint64(8 * i, v)
        end
      end
      ap = ::FFI::MemoryPointer.new(:uint8, 24)
      ap.put_uint32(0, 48)
      ap.put_uint32(4, 176)
      ap.put_pointer(8, area)
      ap.put_pointer(16, ::FFI::Pointer::NULL)
      [ap, keep]
    end

    # stato del va_list dopo la chiamata: offset e avanzamento nell'area di overflow
    def va_state(ap, keep) = [ap.get_uint32(0), ap.get_uint32(4), ap.get_pointer(8).address - keep.first.address]

    # pila separata per i test di z-order: R con figli A, B, C; A con A1, A2; B con B1
    def zpile
      o = F::NcPlaneOptions.new
      o[:rows] = 2
      o[:cols] = 2
      root = F.ncpile_create(nc, o)
      a = F.ncplane_create(root, o)
      b = F.ncplane_create(root, o)
      [root, [root, a, b, F.ncplane_create(a, o), F.ncplane_create(a, o), F.ncplane_create(b, o),
              F.ncplane_create(root, o)]]
    end

    def zorder(root, planes)
      idx = planes.each_with_index.to_h { |p, i| [p.address, i] }
      out = []
      p = F.ncpile_top(root)
      until p.null?
        out << idx.fetch(p.address, -1)
        p = F.ncplane_below(p)
      end
      out
    end

    def stats
      st = F.notcurses_stats_alloc(nc)
      F.notcurses_stats(nc, st)
      v = [st[:renders], st[:failed_renders]]
      F.free(st.pointer)
      v
    end

    def utf8_locale? = F.wcwidth(0x4e00) == 2

    # azzera colori e stili dell'ncdirect, scarta l'output fin qui
    def dreset
      F.ncdirect_set_fg_default(dd)
      F.ncdirect_set_bg_default(dd)
      F.ncdirect_set_styles(dd, 0)
      Direct.output
    end

    # *_capabilities() restituisce il puntatore interno al contesto: riscriverne i byte per la durata del blocco
    # esercita i rami (colors < 256, niente UTF-8, ...) che il terminale di test non raggiunge.
    def with_caps(caps, bytes)
      ptr = caps.pointer
      saved = ptr.get_bytes(0, F::NcCapabilities.size)
      ptr.put_bytes(0, bytes)
      yield
    ensure
      ptr.put_bytes(0, saved) if saved
    end

    def caps_cases(caps) = [caps.pointer.get_bytes(0, F::NcCapabilities.size)] + caps_bounds + Array.new(64) { rcaps }

    def with_utf8(flag, &)
      caps = F.notcurses_capabilities(nc)
      b = caps.pointer.get_bytes(0, F::NcCapabilities.size)
      b.setbyte(F::NcCapabilities.offset_of(:utf8), flag ? 1 : 0)
      with_caps(caps, b, &)
    end
  end

  # ═══════════════════════════════════════
  # Copertura
  # ═══════════════════════════════════════
  RSpec.describe 'Notcurses::FFI inline: copertura', **SKIP do
    it 'confronta tutte le 236 inline e le 12 macro: nessuna esclusa in silenzio' do
      all = (INLINE_NAMES + MACRO_NAMES).sort
      expect(INLINE_NAMES.size).to eq(236)
      expect(INLINE_NAMES.uniq.size).to eq(236)
      expect(INLINE_NAMES.sort).to eq(O.attached_functions.keys.sort)
      expect(PURE.keys - INLINE_NAMES).to be_empty
      # le reimplementazioni sono i metodi del modulo che non vengono da attach_function
      expect((F.singleton_methods(false) - F.attached_functions.keys).sort).to eq(all)
      expect((COVERED.keys + NOT_COMPARABLE.keys).sort).to eq(all)
      expect(COVERED.keys & NOT_COMPARABLE.keys).to be_empty
      (NOT_COMPARABLE.merge(PARTIAL)).each_value { |why| expect(why).to be_a(String).and(match(/\S{3}/)) }
    end
  end

  # ═══════════════════════════════════════
  # Funzioni pure: nessun contesto
  # ═══════════════════════════════════════
  RSpec.describe 'Notcurses::FFI inline: funzioni pure', **SKIP do
    extend DSL
    include Helpers

    PURE.each do |fn, types|
      diff(fn, min: NRAND) { |name| pure(name, types) }
    end
  end

  # ═══════════════════════════════════════
  # Funzioni con piano/contesto: un solo notcurses_init su /dev/null
  # ═══════════════════════════════════════
  RSpec.describe 'Notcurses::FFI inline: con contesto notcurses', **SKIP do
    extend DSL
    include Helpers

    before(:all) { Ctx.start }
    after(:all) { Ctx.stop }

    describe 'Notcurses lifecycle' do
      # Funzioni sulla pila standard condivisa: stesso nc per i due lati.
      def std_pile_rounds(rounds)
        planes = Array.new(4) { mkplane(PlaneSpec.new(2, 3, false, 0, 0, [], 0, 0)) }
        yield
        rounds.times do
          a = pick(planes)
          b = pick(planes + [std, nil])
          b = nil if b == a
          @rng.rand(2).zero? ? F.ncplane_move_above(a, b) : F.ncplane_move_below(a, b)
          yield
        end
      ensure
        planes&.each { |p| F.ncplane_destroy(p) }
      end

      %i[notcurses_top notcurses_bottom].each do |fn|
        diff(fn, min: 20) do |name|
          std_pile_rounds(25) { twin(name, 'pila standard') { |m| [call { m.public_send(name, nc) }] } }
        end
      end

      %i[notcurses_stddim_yx notcurses_stddim_yx_const notcurses_term_dim_yx].each do |fn|
        diff(fn, min: 12) do |name|
          [true, false].product([true, false]).each do |wy, wx|
            3.times do
              ty = wy ? Mem.new(:uint, [@rng.rand(2**32)]) : nil
              tx = wx ? Mem.new(:uint, [@rng.rand(2**32)]) : nil
              twin(name, -> { "y=#{ty.inspect} x=#{tx.inspect}" }) do |m|
                y = ty&.build
                x = tx&.build
                [call { m.public_send(name, nc, y, x) }, ty&.dump(y), tx&.dump(x)]
              end
            end
          end
        end
      end

      diff(:notcurses_render, min: 8) do |name|
        8.times do |i|
          F.ncplane_putegc_yx(std, @rng.rand(3), @rng.rand(10), pick(FILL_GLYPHS), nil)
          twin(name, "giro #{i}") do |m|
            r0, f0 = stats
            ret = call { m.notcurses_render(nc) }
            r1, f1 = stats
            [ret, r1 - r0, f1 - f0]
          end
        end
      ensure
        F.ncplane_erase(std)
      end

      %i[notcurses_cantruecolor notcurses_canchangecolor notcurses_canfade notcurses_canutf8
         notcurses_canhalfblock notcurses_canquadrant notcurses_cansextant notcurses_canoctant
         notcurses_canbraille notcurses_canpixel].each do |fn|
        diff(fn, min: 75) do |name|
          caps = F.notcurses_capabilities(nc)
          caps_cases(caps).each do |b|
            with_caps(caps, b) { twin(name, -> { "caps=#{b.unpack('VC8')}" }) { |m| [call { m.public_send(name, nc) }] } }
          end
        end
      end
    end

    describe 'Input' do
      # con NCOPTION_DRAIN_INPUT (e stdin /dev/null) tornano subito: -1 e ncinput azzerato con id -1
      %i[notcurses_get_nblock notcurses_get_blocking].each do |fn|
        diff(fn, min: 20) do |name|
          25.times do |i|
            t = i.zero? ? nil : Raw.new(F::NcInput, rinput)
            twin(name, t.inspect) { |m| ni = t&.build; [call { m.public_send(name, nc, ni) }, t&.dump(ni)] }
          end
        end
      end

      diff(:notcurses_mice_disable, min: 3) do |name|
        3.times { twin(name, 'nc') { |m| [call { m.notcurses_mice_disable(nc) }] } }
      end
    end

    describe 'NcPlane' do
      diff(:ncplane_resize_simple, min: NPLANE) do |name|
        NPLANE.times do
          ps = rplane
          small = ->(v) { v.clamp(0, 60) }
          ylen, xlen = case @rng.rand(8)
                       when 0 then [-1, @rng.rand(1..9)] # (unsigned)-1 x k: area int negativa, malloc fallisce
                       when 1 then [@rng.rand(1..9), -1]
                       else [small.(pick([0, 1, 2, ps.rows - 1, ps.rows, ps.rows + 1, 7, 40])),
                             small.(pick([0, 1, 2, ps.cols - 1, ps.cols, ps.cols + 1, 9, 50]))]
                       end
          twin(name, -> { "#{ps.inspect} #{ylen}x#{xlen}" }) do |m|
            with_plane(ps) { |pl| [call { m.ncplane_resize_simple(pl, ylen, xlen) }, snap(pl)] }
          end
        end
        twin(name, 'stdplane') { |m| [call { m.ncplane_resize_simple(std, 5, 5) }, dims(std)] }
      end

      diff(:ncplane_move_rel, min: NPLANE) do |name|
        NPLANE.times do
          oy, ox, cy, cx = Array.new(4) { @rng.rand(3).zero? ? rint : @rng.rand(-50..50) }
          dy, dx = Array.new(2) { @rng.rand(2).zero? ? rint : @rng.rand(-20..20) }
          twin(name, -> { "da #{oy},#{ox} figlio #{cy},#{cx} di #{dy},#{dx}" }) do |m|
            parent = mkplane(PlaneSpec.new(2, 2, false, 0, 0, [], 0, 0))
            child = mkplane(PlaneSpec.new(1, 1, false, 0, 0, [], 0, 0), parent)
            F.ncplane_move_yx(parent, oy, ox)
            F.ncplane_move_yx(child, cy, cx)
            [call { m.ncplane_move_rel(parent, dy, dx) }, pos(parent), pos(child)]
          ensure
            F.ncplane_destroy(child) if child
            F.ncplane_destroy(parent) if parent
          end
        end
        twin(name, 'stdplane') { |m| [call { m.ncplane_move_rel(std, 1, 1) }, pos(std)] }
      end

      diff(:ncplane_descendant_p, min: 56) do |name|
        sp = PlaneSpec.new(1, 1, false, 0, 0, [], 0, 0)
        a = mkplane(sp)
        b = mkplane(sp, a)
        c = mkplane(sp, b)
        d = mkplane(sp)
        root, = zpile
        q = F.ncplane_create(root, F::NcPlaneOptions.new.tap { |o| o[:rows] = o[:cols] = 1 })
        nodes = { std: std, a: a, b: b, c: c, d: d, root: root, q: q }
        nodes.each do |nn, n|
          nodes.merge(nil: nil).each do |an, anc|
            twin(name, "#{nn} discende da #{an}?") { |m| [call { m.ncplane_descendant_p(n, anc) }] }
          end
        end
      ensure
        [c, b, a, d].each { |p| F.ncplane_destroy(p) if p }
        F.ncplane_family_destroy(root) if root
      end

      # z-order su pile separate e identiche, una per lato
      %i[ncplane_move_top ncplane_move_bottom ncplane_move_family_top ncplane_move_family_bottom].each do |fn|
        diff(fn, min: NPLANE) do |name|
          NPLANE.times do
            moves = Array.new(@rng.rand(0..6)) { [@rng.rand(2), @rng.rand(7), @rng.rand(8)] }
            target = @rng.rand(7)
            twin(name, -> { "mosse #{moves.inspect} piano #{target}" }) do |m|
              root, planes = zpile
              moves.each do |dir, ai, bi|
                next if ai == bi
                other = planes[bi] # bi == 7: NULL
                dir.zero? ? F.ncplane_move_above(planes[ai], other) : F.ncplane_move_below(planes[ai], other)
              end
              [call { m.public_send(name, planes[target]) }, zorder(root, planes)]
            ensure
              F.ncplane_family_destroy(root) if root
            end
          end
        end
      end

      %i[ncplane_dim_y ncplane_dim_x].each do |fn|
        diff(fn, min: NPLANE) do |name|
          NPLANE.times do
            ps = rplane(scroll: false, rows: pick([1, 2, 7, 33]), cols: pick([1, 3, 80, 133]), fill: false)
            twin(name, ps.inspect) { |m| with_plane(ps) { |pl| [call { m.public_send(name, pl) }, dims(pl)] } }
          end
          twin(name, 'stdplane') { |m| [call { m.public_send(name, std) }] }
        end
      end

      %i[ncplane_halign ncplane_valign].each do |fn|
        diff(fn, min: NPLANE) do |name|
          NPLANE.times do
            ps = rplane(rows: pick([1, 2, 5, 11]), cols: pick([1, 4, 10, 17]), fill: false)
            a = gen(:align)
            c = gen(:int)
            twin(name, -> { "#{ps.inspect} align=#{a} c=#{c}" }) do |m|
              with_plane(ps) { |pl| [call { m.public_send(name, pl, a, c) }, snap(pl)] }
            end
          end
        end
      end

      %i[ncplane_cursor_y ncplane_cursor_x].each do |fn|
        diff(fn, min: NPLANE) do |name|
          NPLANE.times do
            ps = rplane
            twin(name, ps.inspect) { |m| with_plane(ps) { |pl| [call { m.public_send(name, pl) }, snap(pl)] } }
          end
        end
      end
    end

    describe 'NcPlane output' do
      diff(:ncplane_putc, min: NPLANE) do |name|
        NPLANE.times do
          ps = rplane
          cs = rcellspec
          twin(name, -> { "#{ps.inspect} cella=#{cs.inspect}" }) do |m|
            with_plane(ps) do |pl|
              c = mkcell(pl, cs)
              [call { m.ncplane_putc(pl, c) }, celldump(pl, c), snap(pl)]
            end
          end
        end
      end

      diff(:ncplane_putchar_yx, min: NPLANE) do |name|
        NPLANE.times do
          ps = rplane
          y, x = rcoord(ps)
          c = rchar(ps, x)
          twin(name, -> { "#{ps.inspect} y=#{y} x=#{x} c=#{c}" }) do |m|
            with_plane(ps) { |pl| [call { m.ncplane_putchar_yx(pl, y, x, c) }, snap(pl)] }
          end
        end
      end

      diff(:ncplane_putchar, min: NPLANE) do |name|
        NPLANE.times do
          ps = rplane
          c = rchar(ps)
          twin(name, -> { "#{ps.inspect} c=#{c}" }) do |m|
            with_plane(ps) { |pl| [call { m.ncplane_putchar(pl, c) }, snap(pl)] }
          end
        end
      end

      diff(:ncplane_putegc, min: NPLANE) do |name|
        NPLANE.times do
          ps = rplane
          s = rtext(ps)
          tb = @rng.rand(3).zero? ? nil : Mem.new(:uint64, [@rng.rand(2**64)])
          twin(name, -> { "#{ps.inspect} #{s.inspect} sbytes=#{tb.inspect}" }) do |m|
            with_plane(ps) do |pl|
              sb = tb&.build
              [call { m.ncplane_putegc(pl, s, sb) }, tb&.dump(sb), snap(pl)]
            end
          end
        end
      end

      diff(:ncwcsrtombs, min: NPLANE) do |name|
        vecs = TEXTS.select(&:valid_encoding?).map(&:codepoints) + WSPECIAL + [[0x7fff_ffff], [0x20_0000, 0x41]]
        vecs.each do |cps|
          twin(name, cps.inspect) { |m| w = wvec(cps).build; [call { heap(m.ncwcsrtombs(w)) }] }
        end
        NPLANE.times do
          cps = Array.new(@rng.rand(0..6)) { @rng.rand(3).zero? ? @rng.rand(0x11_0000) : pick(WCHARS) }
          twin(name, cps.inspect) { |m| w = wvec(cps).build; [call { heap(m.ncwcsrtombs(w)) }] }
        end
      end

      diff(:ncplane_putwegc, min: NPLANE) do |name|
        NPLANE.times do
          ps = rplane
          tw = rwide(ps)
          tb = @rng.rand(3).zero? ? nil : Mem.new(:uint64, [@rng.rand(2**64)])
          twin(name, -> { "#{ps.inspect} #{tw.inspect} sbytes=#{tb.inspect}" }) do |m|
            with_plane(ps) do |pl|
              sb = tb&.build
              [call { m.ncplane_putwegc(pl, tw.build, sb) }, tb&.dump(sb), snap(pl)]
            end
          end
        end
      end

      diff(:ncplane_putwegc_yx, min: NPLANE) do |name|
        NPLANE.times do
          ps = rplane
          y, x = rcoord(ps)
          tw = rwide(ps, x)
          tb = @rng.rand(3).zero? ? nil : Mem.new(:uint64, [@rng.rand(2**64)])
          twin(name, -> { "#{ps.inspect} y=#{y} x=#{x} #{tw.inspect}" }) do |m|
            with_plane(ps) do |pl|
              sb = tb&.build
              [call { m.ncplane_putwegc_yx(pl, y, x, tw.build, sb) }, tb&.dump(sb), snap(pl)]
            end
          end
        end
      end

      diff(:ncplane_putstr_yx, min: NPLANE) do |name|
        NPLANE.times do
          ps = rplane
          y, x = rcoord(ps)
          s = rtext(ps, x)
          twin(name, -> { "#{ps.inspect} y=#{y} x=#{x} #{s.inspect}" }) do |m|
            with_plane(ps) { |pl| [call { m.ncplane_putstr_yx(pl, y, x, s) }, snap(pl)] }
          end
        end
      end

      diff(:ncplane_putstr, min: NPLANE) do |name|
        NPLANE.times do
          ps = rplane
          s = rtext(ps)
          twin(name, -> { "#{ps.inspect} #{s.inspect}" }) do |m|
            with_plane(ps) { |pl| [call { m.ncplane_putstr(pl, s) }, snap(pl)] }
          end
        end
      end

      diff(:ncplane_putstr_aligned, min: NPLANE) do |name|
        NPLANE.times do
          ps = rplane
          y = pick([-1, 0, ps.rows - 1, ps.rows, -2])
          a = pick(ALIGNS)
          s = rtext(ps, tabs: false)
          twin(name, -> { "#{ps.inspect} y=#{y} align=#{a} #{s.inspect}" }) do |m|
            with_plane(ps) { |pl| [call { m.ncplane_putstr_aligned(pl, y, a, s) }, snap(pl)] }
          end
        end
      end

      diff(:ncplane_putstr_stained, min: NPLANE) do |name|
        NPLANE.times do
          ps = rplane_stained
          s = rtext(ps)
          twin(name, -> { "#{ps.inspect} #{s.inspect}" }) do |m|
            with_plane(ps) { |pl| [call { m.ncplane_putstr_stained(pl, s) }, snap(pl)] }
          end
        end
      end

      %i[ncplane_putnstr_yx ncplane_putnstr].each do |fn|
        diff(fn, min: NPLANE) do |name|
          NPLANE.times do
            ps = rplane
            y, x = fn == :ncplane_putnstr ? [-1, -1] : rcoord(ps)
            s = rtext(ps, x)
            n = pick([0, 1, 2, 3, s.bytesize - 1, s.bytesize, s.bytesize + 1, M64, -1, @rng.rand(0..s.bytesize + 2)])
            n = 0 if n.negative? && n != -1
            args = fn == :ncplane_putnstr ? [n, s] : [y, x, n, s]
            twin(name, -> { "#{ps.inspect} #{args.inspect}" }) do |m|
              with_plane(ps) { |pl| [call { m.public_send(name, pl, *args) }, snap(pl)] }
            end
          end
          # gclusters NULL con s == 0: il C restituisce 0 senza leggere la stringa
          ps = rplane
          args = fn == :ncplane_putnstr ? [0, nil] : [-1, -1, 0, nil]
          twin(name, -> { "#{ps.inspect} #{args.inspect}" }) do |m|
            with_plane(ps) { |pl| [call { m.public_send(name, pl, *args) }, snap(pl)] }
          end
        end
      end

      %i[ncplane_putwstr_yx ncplane_putwstr_aligned ncplane_putwstr].each do |fn|
        diff(fn, min: NPLANE) do |name|
          NPLANE.times do
            ps = rplane
            args = case fn
                   when :ncplane_putwstr_yx then rcoord(ps)
                   when :ncplane_putwstr_aligned then [pick([-1, 0, ps.rows - 1, ps.rows, -2]), pick(ALIGNS)]
                   else []
                   end
            tw = rwide(ps, fn == :ncplane_putwstr_yx ? args[1] : -1, tabs: fn != :ncplane_putwstr_aligned)
            twin(name, -> { "#{ps.inspect} #{args.inspect} #{tw.inspect}" }) do |m|
              with_plane(ps) { |pl| [call { m.public_send(name, pl, *args, tw.build) }, snap(pl)] }
            end
          end
        end
      end

      diff(:ncplane_pututf32_yx, min: NPLANE) do |name|
        NPLANE.times do
          ps = rplane
          y, x = rcoord(ps)
          u = @rng.rand(10).zero? ? pick([0x8000_0000, M32, 0x8000_0041]) : rwchar(ps, x)
          twin(name, -> { "#{ps.inspect} y=#{y} x=#{x} u=#{u}" }) do |m|
            with_plane(ps) { |pl| [call { m.ncplane_pututf32_yx(pl, y, x, u) }, snap(pl)] }
          end
        end
      end

      diff(:ncplane_putwc_yx, min: NPLANE) do |name|
        NPLANE.times do
          ps = rplane
          y, x = rcoord(ps)
          w = rwchar(ps, x)
          twin(name, -> { "#{ps.inspect} y=#{y} x=#{x} w=#{w}" }) do |m|
            with_plane(ps) { |pl| [call { m.ncplane_putwc_yx(pl, y, x, w) }, snap(pl)] }
          end
        end
      end

      diff(:ncplane_putwc, min: NPLANE) do |name|
        NPLANE.times do
          ps = rplane
          w = rwchar(ps)
          twin(name, -> { "#{ps.inspect} w=#{w}" }) do |m|
            with_plane(ps) { |pl| [call { m.ncplane_putwc(pl, w) }, snap(pl)] }
          end
        end
      end

      diff(:ncplane_putwc_utf32, min: NPLANE) do |name|
        pairs = [[0xd83d, 0xde00], [0xd800, 0xdc00], [0xdbff, 0xdfff], [0xd000, 0xdc00], [0xd7ff, 0x41],
                 [0xd800, 0x41], [0xdbff, 0xe000], [0x41, 0], [0x4e00, 0], [0xdc00, 0], [-1, 0], [0, 0x41]]
        NPLANE.times do |i|
          ps = rplane
          w0, w1 = i < pairs.size ? pairs[i] : [pick([rwchar(ps), @rng.rand(0xd000..0xdbff)]), @rng.rand(0xdb00..0xe100)]
          tw = Mem.new(:int32, [w0, w1, 0])
          tn = Mem.new(:uint, [@rng.rand(2**32)])
          twin(name, -> { "#{ps.inspect} w=#{[w0, w1].inspect}" }) do |m|
            with_plane(ps) do |pl|
              wn = tn.build
              [call { m.ncplane_putwc_utf32(pl, tw.build, wn) }, tn.dump(wn), snap(pl)]
            end
          end
        end
      end

      diff(:ncplane_putwc_stained, min: NPLANE) do |name|
        NPLANE.times do
          ps = rplane_stained
          w = rwchar(ps)
          twin(name, -> { "#{ps.inspect} w=#{w}" }) do |m|
            with_plane(ps) { |pl| [call { m.ncplane_putwc_stained(pl, w) }, snap(pl)] }
          end
        end
      end

      if VA_LIST_SYSV
        diff(:ncplane_vprintf, min: NPLANE) do |name|
          # nel va_list un char* con NUL interno è solo una stringa C più corta: non serve
          fmts = PRINTF.reject { |_, *va| va.each_slice(2).any? { |t, v| t == :string && v.include?("\0") } }
          NPLANE.times do
            ps = rplane
            fmt, *va = pick(fmts)
            twin(name, -> { "#{ps.inspect} #{[fmt, *va].inspect}" }) do |m|
              with_plane(ps) do |pl|
                ap, keep = va_list(va)
                [call { m.ncplane_vprintf(pl, fmt, ap) }, va_state(ap, keep), snap(pl)]
              end
            end
          end
        end
      else
        it("ncplane_vprintf: #{NOT_COMPARABLE[:ncplane_vprintf]}") { skip NOT_COMPARABLE[:ncplane_vprintf] }
      end

      diff(:ncplane_printf, min: NPLANE) do |name|
        NPLANE.times do
          ps = rplane
          fa = pick(PRINTF)
          twin(name, -> { "#{ps.inspect} #{fa.inspect}" }) do |m|
            with_plane(ps) { |pl| [call { m.ncplane_printf(pl, *fa) }, snap(pl)] }
          end
        end
      end

      diff(:ncplane_printf_yx, min: NPLANE) do |name|
        NPLANE.times do
          ps = rplane
          y, x = rcoord(ps)
          fa = pick(PRINTF)
          twin(name, -> { "#{ps.inspect} y=#{y} x=#{x} #{fa.inspect}" }) do |m|
            with_plane(ps) { |pl| [call { m.ncplane_printf_yx(pl, y, x, *fa) }, snap(pl)] }
          end
        end
      end

      diff(:ncplane_printf_aligned, min: NPLANE) do |name|
        NPLANE.times do
          ps = rplane
          y = pick([-1, 0, ps.rows - 1, ps.rows, -2])
          a = pick(ALIGNS)
          fa = pick(PRINTF)
          twin(name, -> { "#{ps.inspect} y=#{y} align=#{a} #{fa.inspect}" }) do |m|
            with_plane(ps) { |pl| [call { m.ncplane_printf_aligned(pl, y, a, *fa) }, snap(pl)] }
          end
        end
      end

      diff(:ncplane_printf_stained, min: NPLANE) do |name|
        NPLANE.times do
          ps = rplane_stained
          fa = pick(PRINTF)
          twin(name, -> { "#{ps.inspect} #{fa.inspect}" }) do |m|
            with_plane(ps) { |pl| [call { m.ncplane_printf_stained(pl, *fa) }, snap(pl)] }
          end
        end
      end
    end

    describe 'NcPlane linee e box' do
      diff(:ncplane_hline, min: NPLANE) do |name|
        NPLANE.times do
          ps = rplane
          cs = rcellspec
          len = if ps.scroll then pick([0, 1, 2, ps.cols - 1, ps.cols, ps.cols + 1, 3 * ps.cols])
                else pick([0, 1, 2, ps.cols, ps.cols + 1, 100, 0x7fff_ffff, 0x8000_0000, 0xffff_fffe, M32, -1])
                end
          twin(name, -> { "#{ps.inspect} cella=#{cs.inspect} len=#{len}" }) do |m|
            with_plane(ps) do |pl|
              c = mkcell(pl, cs)
              [call { m.ncplane_hline(pl, c, len) }, celldump(pl, c), snap(pl)]
            end
          end
        end
      end

      diff(:ncplane_vline, min: NPLANE) do |name|
        NPLANE.times do
          ps = rplane
          cs = rcellspec
          len = pick([0, 1, 2, ps.rows - 1, ps.rows, ps.rows + 1, 100, 0x7fff_ffff, 0x8000_0000, 0xffff_fffe])
          twin(name, -> { "#{ps.inspect} cella=#{cs.inspect} len=#{len}" }) do |m|
            with_plane(ps) do |pl|
              c = mkcell(pl, cs)
              [call { m.ncplane_vline(pl, c, len) }, celldump(pl, c), snap(pl)]
            end
          end
        end
      end

      %i[ncplane_box_sized ncplane_perimeter].each do |fn|
        diff(fn, min: NPLANE) do |name|
          NPLANE.times do
            # celle larghe fino a 3: su un piano che scorre, più strette del piano (scroll_down non ricontrolla)
            sc = @rng.rand(2).zero?
            ps = rplane(scroll: sc, rows: pick([1, 2, 3, 5, 6]), cols: pick(sc ? [6, 10] : [1, 2, 6, 10]))
            specs = Array.new(6) { rcellspec }
            tail = if fn == :ncplane_box_sized
                     cy = ps.cy
                     cx = ps.cx == :end ? ps.cols : ps.cx
                     [pick([0, 1, 2, 3, ps.rows - cy, ps.rows, M32, 0x8000_0000]),
                      pick([0, 1, 2, 3, ps.cols - cx, ps.cols, M32, -1]), rctl]
                   else [rctl]
                   end
            twin(name, -> { "#{ps.inspect} celle=#{specs.inspect} #{tail.inspect}" }) do |m|
              with_plane(ps) do |pl|
                cells = specs.map { |s| mkcell(pl, s) }
                [call { m.public_send(name, pl, *cells, *tail) }, cells.map { |c| celldump(pl, c) }, snap(pl)]
              end
            end
          end
        end
      end

      # (n, styles, channels, ystop/ylen, xstop/xlen, ctlword) e perimetri (n, styles, channels, ctlword)
      %i[ncplane_rounded_box ncplane_rounded_box_sized ncplane_double_box ncplane_ascii_box
         ncplane_double_box_sized ncplane_perimeter_rounded ncplane_perimeter_double].each do |fn|
        diff(fn, min: NPLANE) do |name|
          NPLANE.times do
            ps = rplane(rows: pick([1, 2, 3, 5, 6]), cols: pick([1, 2, 6, 10]))
            sizes = fn.to_s.include?('perimeter') ? [] : Array.new(2) { pick([0, 1, 2, 3, 4, 5, 9, M32, -1]) }
            args = [rstyles, r64, *sizes, rctl]
            u8 = @rng.rand(2).zero? # senza UTF-8 rounded/double ricadono sul box ASCII
            with_utf8(u8) do
              twin(name, -> { "#{ps.inspect} #{args.inspect} utf8=#{u8}" }) do |m|
                with_plane(ps) { |pl| [call { m.public_send(name, pl, *args) }, snap(pl)] }
              end
            end
          end
        end
      end
    end

    describe 'Channels / Colors del piano' do
      %i[ncplane_bchannel ncplane_fchannel ncplane_fg_rgb ncplane_bg_rgb ncplane_fg_alpha ncplane_fg_default_p
         ncplane_bg_alpha ncplane_bg_default_p ncplane_fg_rgb8 ncplane_bg_rgb8].each do |fn|
        diff(fn, min: NPLANE) do |name|
          (B64 + Array.new(NPLANE) { r64 }).each do |ch|
            outs = fn.to_s.end_with?('rgb8') ? Array.new(3) { Mem.new(:uint, [@rng.rand(2**32)]) } : []
            twin(name, -> { "channels=#{ch}" }) do |m|
              with_plane(PlaneSpec.new(1, 2, false, ch & M64, 0, [], 0, 0)) do |pl|
                bufs = outs.map(&:build)
                [call { m.public_send(name, pl, *bufs) }, outs.zip(bufs).map { |t, b| t.dump(b) }, snap(pl)]
              end
            end
          end
        end
      end
    end

    describe 'nccell con egcpool del piano' do
      diff(:nccell_prime, min: NPLANE) do |name|
        NPLANE.times do
          cs = rcellspec
          g = pick(PRIME_STRS)
          st = rstyles
          ch = r64
          twin(name, -> { "cella=#{cs.inspect} #{g.inspect} st=#{st} ch=#{ch}" }) do |m|
            with_plane(CELL_PLANE) do |pl|
              c = mkcell(pl, cs)
              [call { m.nccell_prime(pl, c, g, st, ch) }, celldump(pl, c)]
            end
          end
        end
      end

      diff(:nccell_load_char, min: NPLANE) do |name|
        (CHARS + [9, 10, 256 + 9] + Array.new(NPLANE) { @rng.rand(3).zero? ? rint : @rng.rand(-128..255) }).each do |ch|
          cs = rcellspec
          twin(name, -> { "cella=#{cs.inspect} ch=#{ch}" }) do |m|
            with_plane(CELL_PLANE) do |pl|
              c = mkcell(pl, cs)
              [call { m.nccell_load_char(pl, c, ch) }, celldump(pl, c)]
            end
          end
        end
      end

      diff(:nccell_load_egc32, min: NPLANE) do |name|
        packed = (CELL_EGCS + ['ab', 'abcd', "\xc3".b, "\xff\xfe".b]).filter_map do |g|
          g.b.ljust(4, "\0").unpack1('V') if g.bytesize <= 4
        end
        (packed + [0, M32, -1, 0x8000_0000] + Array.new(NPLANE) { @rng.rand(2).zero? ? r32 : @rng.rand(0x20..0x7e) }).each do |e|
          cs = rcellspec
          twin(name, -> { "cella=#{cs.inspect} egc=#{e}" }) do |m|
            with_plane(CELL_PLANE) do |pl|
              c = mkcell(pl, cs)
              [call { m.nccell_load_egc32(pl, c, e) }, celldump(pl, c)]
            end
          end
        end
      end

      # vedi PARTIAL: per UTF-8 < 4 byte il riferimento è nccell_load_egc32 sul buffer azzerato
      diff(:nccell_load_ucs32, min: NPLANE) do |name|
        cps = [0x41, 0, 0x7f, 0x01, 0xe9, 0x7ff, 0x800, 0x4e00, 0xffff, 0x1_0000, 0x1f600, 0x10_ffff, 0x11_0000,
               0xd800, 0xdfff, 0x7fff_ffff, M32, -1]
        (cps + Array.new(NPLANE) { @rng.rand(3).zero? ? r32 : @rng.rand(0x11_0000) }).each do |u|
          uu = u & M32
          short = uu <= 0x10_ffff && !(0xd800..0xdfff).cover?(uu) && [uu].pack('U').bytesize < 4
          padded = short ? [uu].pack('U').b.ljust(4, "\0").unpack1('V') : nil
          cs = rcellspec
          twin(name, -> { "cella=#{cs.inspect} u=#{u}" }) do |m|
            with_plane(CELL_PLANE) do |pl|
              c = mkcell(pl, cs)
              ret = if m == O && short then call { O.nccell_load_egc32(pl, c, padded) }
                    else call { m.nccell_load_ucs32(pl, c, u) }
                    end
              [ret, celldump(pl, c)]
            end
          end
        end
      end

      diff(:nccell_strdup, min: NPLANE) do |name|
        NPLANE.times do
          cs = rcellspec
          twin(name, -> { "cella=#{cs.inspect}" }) do |m|
            with_plane(CELL_PLANE) do |pl|
              c = mkcell(pl, cs)
              [call { heap(m.nccell_strdup(pl, c)) }, celldump(pl, c)]
            end
          end
        end
      end

      diff(:nccell_extract, min: NPLANE) do |name|
        NPLANE.times do
          cs = rcellspec
          tsm = @rng.rand(4).zero? ? nil : Mem.new(:uint16, [@rng.rand(2**16)])
          tch = @rng.rand(4).zero? ? nil : Mem.new(:uint64, [@rng.rand(2**64)])
          twin(name, -> { "cella=#{cs.inspect} #{tsm.inspect} #{tch.inspect}" }) do |m|
            with_plane(CELL_PLANE) do |pl|
              c = mkcell(pl, cs)
              sm = tsm&.build
              ch = tch&.build
              [call { heap(m.nccell_extract(pl, c, sm, ch)) }, tsm&.dump(sm), tch&.dump(ch), celldump(pl, c)]
            end
          end
        end
      end

      diff(:nccellcmp, min: NPLANE) do |name|
        NPLANE.times do
          c1 = rcellspec
          c2 = case @rng.rand(4)
               when 0 then c1
               when 1 then c1[0] == :load ? [:load, c1[1], c1[2], c1[3] ^ 1] : rcellspec
               when 2 then c1[0] == :load ? [:load, c1[1], c1[2] ^ 1, c1[3]] : rcellspec
               else rcellspec
               end
          same = @rng.rand(2).zero?
          twin(name, -> { "#{c1.inspect} vs #{c2.inspect} stesso piano=#{same}" }) do |m|
            with_plane(CELL_PLANE) do |p1|
              with_plane(CELL_PLANE) do |p2|
                q = same ? p1 : p2
                a = mkcell(p1, c1)
                b = mkcell(q, c2)
                [call { m.nccellcmp(p1, a, q, b) }, celldump(p1, a), celldump(q, b)]
              end
            end
          end
        end
      end

      diff(:nccells_load_box, min: NPLANE) do |name|
        NPLANE.times do
          specs = Array.new(6) { rcellspec }
          st = rstyles
          ch = r64
          g = pick(BOX_STRS)
          twin(name, -> { "celle=#{specs.inspect} st=#{st} ch=#{ch} #{g.inspect}" }) do |m|
            with_plane(CELL_PLANE) do |pl|
              cells = specs.map { |s| mkcell(pl, s) }
              [call { m.nccells_load_box(pl, st, ch, *cells, g) }, cells.map { |c| celldump(pl, c) }]
            end
          end
        end
      end

      %i[nccells_ascii_box nccells_double_box nccells_rounded_box nccells_light_box nccells_heavy_box].each do |fn|
        diff(fn, min: NPLANE) do |name|
          NPLANE.times do
            specs = Array.new(6) { rcellspec }
            st = rstyles
            ch = r64
            u8 = @rng.rand(2).zero?
            with_utf8(u8) do
              twin(name, -> { "celle=#{specs.inspect} st=#{st} ch=#{ch} utf8=#{u8}" }) do |m|
                with_plane(CELL_PLANE) do |pl|
                  cells = specs.map { |s| mkcell(pl, s) }
                  [call { m.public_send(name, pl, st, ch, *cells) }, cells.map { |c| celldump(pl, c) }]
                end
              end
            end
          end
        end
      end
    end

    describe 'NcVisual' do
      diff(:ncvisualplane_create, min: NPLANE) do |name|
        NPLANE.times do
          vr = @rng.rand(1..6)
          vc = @rng.rand(1..6)
          data = @rng.bytes(vr * vc * 4)
          prows = @rng.rand(10).zero? ? 0 : @rng.rand(1..4) # 0 righe: ncpile_create/ncplane_create falliscono
          pcols = @rng.rand(1..8)
          kind = pick(%i[nil zero child childplane pixel])
          scaling = pick([F::NCSCALE_NONE, F::NCSCALE_SCALE, F::NCSCALE_STRETCH])
          blitter = pick([F::NCBLIT_DEFAULT, F::NCBLIT_1x1, F::NCBLIT_2x1, F::NCBLIT_2x2, F::NCBLIT_3x2,
                          F::NCBLIT_4x2, F::NCBLIT_BRAILLE])
          twin(name, -> { "visual #{vr}x#{vc} piano #{prows}x#{pcols} vopts=#{kind} scale=#{scaling} blit=#{blitter}" }) do |m|
            mp = ::FFI::MemoryPointer.new(:uint8, data.bytesize).put_bytes(0, data)
            ncv = F.ncvisual_from_rgba(mp, vr, vc * 4, vc)
            parent = mkplane(PlaneSpec.new(3, 5, false, 0, 0, [], 0, 0))
            opts = F::NcPlaneOptions.new
            opts[:rows] = prows
            opts[:cols] = pcols
            vopts = nil
            unless kind == :nil
              vopts = F::NcVisualOptions.new
              vopts[:scaling] = scaling
              vopts[:blitter] = kind == :pixel ? F::NCBLIT_PIXEL : blitter
              vopts[:flags] = kind == :pixel ? F::NCVISUAL_OPTION_NODEGRADE : 0
              vopts[:n] = parent if %i[child childplane].include?(kind)
              vopts[:flags] |= F::NCVISUAL_OPTION_CHILDPLANE if kind == :childplane
            end
            ret = begin
              m.ncvisualplane_create(nc, opts, ncv, vopts)
            rescue StandardError => e
              e
            end
            newp = ret.is_a?(::FFI::Pointer) && !ret.null? ? ret : nil
            # piano nuovo: indirizzi diversi fra i lati, si confrontano contenuto e genitore
            res = if ret.is_a?(StandardError) then [:raise, ret.class.name]
                  elsif newp.nil? then norm(ret)
                  else
                    up = F.ncplane_parent(newp).address
                    [:plane, snap(newp), { parent.address => :parent, newp.address => :root }.fetch(up, :other)]
                  end
            # vopts->n viene riscritto: NULL, il piano restituito, il genitore o altro
            vstate = vopts && [vopts.pointer.get_bytes(8, F::NcVisualOptions.size - 8).unpack1('H*'),
                               { 0 => :null, newp&.address => :ret, parent.address => :parent }
                                 .fetch(vopts[:n].address, :other)]
            F.ncplane_destroy(newp) if newp
            [res, vstate]
          ensure
            F.ncplane_destroy(parent) if parent
            F.ncvisual_destroy(ncv) if ncv && !ncv.null?
          end
        end
      end
    end

    describe 'Widgets (nctabbed)' do
      %i[nctabbed_hdrchan nctabbed_selchan nctabbed_sepchan].each do |fn|
        diff(fn, min: NPLANE) do |name|
          o = F::NcPlaneOptions.new
          o[:rows] = 3
          o[:cols] = 20
          topts = F::NcTabbedOptions.new
          topts[:selchan] = r64 & M64
          topts[:hdrchan] = r64 & M64
          topts[:sepchan] = r64 & M64
          nt = F.nctabbed_create(F.ncplane_create(std, o), topts)
          raise 'nctabbed_create fallita' if nt.null?
          chans = lambda do
            p = Array.new(3) { ::FFI::MemoryPointer.new(:uint64) }
            F.nctabbed_channels(nt, *p)
            p.map(&:read_uint64)
          end
          (B64 + Array.new(NPLANE) { r64 }).each do |v|
            F.public_send(:"#{name.to_s.sub('nctabbed_', 'nctabbed_set_')}", nt, v & M64)
            twin(name, -> { "canale #{v & M64}" }) { |m| [call { m.public_send(name, nt) }, chans.call] }
          end
        ensure
          F.nctabbed_destroy(nt) if nt && !nt.null?
        end
      end
    end

    # Macro: nessun oracolo, valori attesi da macros.c. Qui perché wcwidth/ncstrwidth dipendono
    # dalla locale, che notcurses_init imposta dall'ambiente.
    describe 'Macro' do
      diff(:preterunicode, min: 13) do |name|
        Expected::PRETERUNICODE.each { |args, exp| const_case(name, args, F.preterunicode(*args), exp) }
      end

      diff(:NCCHANNEL_INITIALIZER, min: 12) do |name|
        Expected::CHANNEL_INIT.each { |args, exp| const_case(name, args, F.NCCHANNEL_INITIALIZER(*args), exp) }
      end

      diff(:NCCHANNELS_INITIALIZER, min: 8) do |name|
        Expected::CHANNELS_INIT.each { |args, exp| const_case(name, args, F.NCCHANNELS_INITIALIZER(*args), exp) }
      end

      cellv = ->(c) { [c.class, c[:gcluster], c[:gcluster_backstop], c[:width], c[:stylemask], c[:channels]] }

      diff(:NCCELL_INITIALIZER, min: 15) do |name|
        skip 'locale non UTF-8: i valori attesi sono calcolati con LANG=it_IT.UTF-8' unless utf8_locale?
        Expected::CELL_INIT.each do |args, exp|
          const_case(name, args, cellv.(F.NCCELL_INITIALIZER(*args)), [F::NcCell, *exp])
        end
      end

      diff(:NCCELL_CHAR_INITIALIZER, min: 9) do |name|
        skip 'locale non UTF-8: i valori attesi sono calcolati con LANG=it_IT.UTF-8' unless utf8_locale?
        Expected::CELL_CHAR_INIT.each do |args, exp|
          const_case(name, args, cellv.(F.NCCELL_CHAR_INITIALIZER(*args)), [F::NcCell, *exp])
        end
      end

      diff(:NCCELL_TRIVIAL_INITIALIZER, min: 2) do |name|
        a = F.NCCELL_TRIVIAL_INITIALIZER
        b = F.NCCELL_TRIVIAL_INITIALIZER
        const_case(name, 'valore', cellv.(a), [F::NcCell, *Expected::CELL_TRIVIAL])
        const_case(name, 'nuova cella a ogni chiamata', a.pointer.address == b.pointer.address, false)
      end

      diff(:NCMETRICFWIDTH, min: 70) do |name|
        skip 'locale non UTF-8: i valori attesi sono calcolati con LANG=it_IT.UTF-8' unless utf8_locale?
        Expected::METRICFWIDTH.each do |x, cols, exp|
          const_case(name, [x.b, cols].inspect, F.NCMETRICFWIDTH(x.b, cols), exp)
        end
      end

      { NCPREFIXFMT: Expected::PREFIXFMT, NCIPREFIXFMT: Expected::IPREFIXFMT,
        NCBPREFIXFMT: Expected::BPREFIXFMT }.each do |fn, rows|
        diff(fn, min: 18) do |name|
          skip 'locale non UTF-8: i valori attesi sono calcolati con LANG=it_IT.UTF-8' unless utf8_locale?
          rows.each do |x, w, same, out|
            x = x.b
            got = F.public_send(name, x)
            const_case(name, x.inspect, [got.class, got.size, got[0]], [Array, 2, w])
            const_case(name, "#{x.inspect} secondo argomento", got[1].equal?(x), same)
            buf = ::FFI::MemoryPointer.new(:char, 64)
            F.snprintf(buf, 64, '%*s|', :int, got[0], :string, got[1])
            const_case(name, "#{x.inspect} snprintf", buf.read_string.b, out.b)
          end
        end
      end

      diff(:htole, min: 8) do |name|
        skip 'valori attesi calcolati su host little-endian' unless ::FFI::Platform::BYTE_ORDER == ::FFI::Platform::LITTLE_ENDIAN
        Expected::HTOLE.each { |x, exp| const_case(name, x, F.htole(x), exp) }
      end

      diff(:NOTCURSES_VERSION_COMPARABLE, min: 9) do |name|
        Expected::VERSION_COMPARABLE.each do |args, exp|
          const_case(name, args, F.NOTCURSES_VERSION_COMPARABLE(*args), exp)
        end
        vers = [F::NOTCURSES_VERNUM_MAJOR, F::NOTCURSES_VERNUM_MINOR, F::NOTCURSES_VERNUM_PATCH]
        const_case(name, vers, F.NOTCURSES_VERSION_COMPARABLE(*vers), 196_625)
      end
    end
  end

  # ═══════════════════════════════════════
  # NcDirect (direct.h): contesto proprio, mai insieme a quello notcurses
  # ═══════════════════════════════════════
  RSpec.describe 'Notcurses::FFI inline: NcDirect (ncdirect_core_init su /dev/null)', **SKIP do
    extend DSL
    include Helpers

    before(:all) { Direct.start(:null) }
    after(:all) { Direct.stop }

    %i[ncdirect_set_bg_rgb8 ncdirect_set_fg_rgb8].each do |fn|
      diff(fn, min: NRAND) do |name|
        cases = BOUNDS[:c8].map { |b| [b, gen(:c8), gen(:c8)] } + BOUNDS[:c8].map { |b| [gen(:c8), gen(:c8), b] } +
                Array.new(NRAND) { Array.new(3) { gen(:c8) } }
        cases.each { |rgb| twin(name, rgb.inspect) { |m| [call { m.public_send(name, dd, *rgb) }] } }
      end
    end

    %i[ncdirect_light_box ncdirect_heavy_box ncdirect_ascii_box].each do |fn|
      diff(fn, min: NDIRECT) do |name|
        NDIRECT.times do
          args = [*Array.new(4) { r64 }, pick([0, 1, 2, 3, 6, 12]), pick([0, 1, 2, 3, 8, 40]), rctl]
          twin(name, args.inspect) { |m| [call { m.public_send(name, dd, *args) }] }
        end
      end
    end

    %i[ncdirect_get_nblock ncdirect_get_blocking].each do |fn|
      diff(fn, min: 20) do |name|
        25.times do |i|
          t = i.zero? ? nil : Raw.new(F::NcInput, rinput)
          twin(name, t.inspect) { |m| ni = t&.build; [call { m.public_send(name, dd, ni) }, t&.dump(ni)] }
        end
      end
    end

    %i[ncdirect_cantruecolor ncdirect_canchangecolor ncdirect_canfade ncdirect_canopen_images
       ncdirect_canopen_videos ncdirect_canhalfblock ncdirect_canquadrant ncdirect_cansextant ncdirect_canoctant
       ncdirect_canbraille].each do |fn|
      diff(fn, min: 75) do |name|
        caps = F.ncdirect_capabilities(dd)
        caps_cases(caps).each do |b|
          with_caps(caps, b) { twin(name, -> { "caps=#{b.unpack('VC8')}" }) { |m| [call { m.public_send(name, dd) }] } }
        end
      end
    end
  end

  # Stesse funzioni che scrivono sul terminale, con il FILE* su una pipe: confronto dei byte emessi.
  RSpec.describe 'Notcurses::FFI inline: NcDirect, output su pipe', **SKIP do
    extend DSL
    include Helpers

    before(:all) { Direct.start(:pipe) }
    after(:all) { Direct.stop }

    %i[ncdirect_set_bg_rgb8 ncdirect_set_fg_rgb8].each do |fn|
      diff(fn, min: NDIRECT) do |name|
        NDIRECT.times do
          rgb = Array.new(3) { gen(:c8) }
          twin(name, rgb.inspect) { |m| dreset; [call { m.public_send(name, dd, *rgb) }, Direct.output] }
        end
      end
    end

    %i[ncdirect_light_box ncdirect_heavy_box ncdirect_ascii_box].each do |fn|
      diff(fn, min: NDIRECT) do |name|
        NDIRECT.times do
          args = [*Array.new(4) { r64 }, pick([0, 1, 2, 3, 4, 6]), pick([0, 1, 2, 3, 5, 12]), rctl]
          twin(name, args.inspect) { |m| dreset; [call { m.public_send(name, dd, *args) }, Direct.output] }
        end
      end
    end
  end
end
