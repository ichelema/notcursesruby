# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

# Oracolo per spec/inline_reimpl_spec.rb.
#
# Le static inline di notcurses non esistono in libnotcurses/libnotcurses-core:
# lib/notcurses/ffi/inline_reimpl.rb le reimplementa in Ruby. notcurses compila
# però le stesse 236 inline anche in libnotcurses-ffi.so, pensata per i binding
# FFI: src/libffi/ffi.c (generato da tools/generate_ffi.py) include gli header
# con NOTCURSES_FFI (che ridefinisce "static" come API) e -fkeep-inline-functions,
# quindi ogni inline diventa un simbolo esportato con lo stesso corpo C.
# NcOracle le collega con attach_function usando il contratto FFI della
# mappatura (le firme che la reimplementazione deve rispettare: quelle di
# inline_signatures.tsv / oracle.rb della Fase 1) e fa da riferimento C per i
# test differenziali. Le struct by_ref sono quelle di Notcurses::FFI.
#
# Se libnotcurses-ffi non si carica (o manca un simbolo) AVAILABLE vale false e
# la spec va in skip: nessuna eccezione al require.
require 'ffi'
require 'notcurses/ffi'

module NcOracle
  extend ::FFI::Library

  S = Notcurses::FFI

  begin
    ffi_lib ['libnotcurses-ffi.so.3', 'notcurses-ffi']
    # typedef enum { ... } X_e: l'ABI C li passa come int
    %i[ncblitter_e ncalign_e ncscale_e ncloglevel_e ncintype_e ncpixelimpl_e].each { |t| typedef :int, t }

    attach_function :nckey_synthesized_p, [:uint32], :bool
    attach_function :nckey_pua_p, [:uint32], :bool
    attach_function :nckey_supppuaa_p, [:uint32], :bool
    attach_function :nckey_supppuab_p, [:uint32], :bool
    attach_function :ncchannel_alpha, [:uint32], :uint32
    attach_function :ncchannel_set_alpha, [:pointer, :uint], :int
    attach_function :ncchannel_default_p, [:uint32], :bool
    attach_function :ncchannel_set_default, [:pointer], :uint32
    attach_function :ncchannel_palindex_p, [:uint32], :bool
    attach_function :ncchannel_palindex, [:uint32], :uint
    attach_function :ncchannel_set_palindex, [:pointer, :uint], :int
    attach_function :ncchannel_rgb_p, [:uint32], :bool
    attach_function :ncchannel_r, [:uint32], :uint
    attach_function :ncchannel_g, [:uint32], :uint
    attach_function :ncchannel_b, [:uint32], :uint
    attach_function :ncchannel_rgb, [:uint32], :uint32
    attach_function :ncchannel_rgb8, [:uint32, :pointer, :pointer, :pointer], :uint32
    attach_function :ncchannel_set_rgb8, [:pointer, :uint, :uint, :uint], :int
    attach_function :ncchannel_set, [:pointer, :uint32], :int
    attach_function :ncchannel_set_rgb8_clipped, [:pointer, :int, :int, :int], :void
    attach_function :ncchannels_bchannel, [:uint64], :uint32
    attach_function :ncchannels_fchannel, [:uint64], :uint32
    attach_function :ncchannels_channels, [:uint64], :uint64
    attach_function :ncchannels_bg_rgb_p, [:uint64], :bool
    attach_function :ncchannels_fg_rgb_p, [:uint64], :bool
    attach_function :ncchannels_bg_alpha, [:uint64], :uint
    attach_function :ncchannels_set_bchannel, [:pointer, :uint32], :uint64
    attach_function :ncchannels_set_fchannel, [:pointer, :uint32], :uint64
    attach_function :ncchannels_set_channels, [:pointer, :uint64], :uint64
    attach_function :ncchannels_set_bg_alpha, [:pointer, :uint], :int
    attach_function :ncchannels_fg_alpha, [:uint64], :uint
    attach_function :ncchannels_set_fg_alpha, [:pointer, :uint], :int
    attach_function :ncchannels_reverse, [:uint64], :uint64
    attach_function :ncchannels_combine, [:uint32, :uint32], :uint64
    attach_function :ncchannels_fg_palindex, [:uint64], :uint
    attach_function :ncchannels_bg_palindex, [:uint64], :uint
    attach_function :ncchannels_fg_rgb, [:uint64], :uint32
    attach_function :ncchannels_bg_rgb, [:uint64], :uint32
    attach_function :ncchannels_fg_rgb8, [:uint64, :pointer, :pointer, :pointer], :uint32
    attach_function :ncchannels_bg_rgb8, [:uint64, :pointer, :pointer, :pointer], :uint32
    attach_function :ncchannels_set_fg_rgb8, [:pointer, :uint, :uint, :uint], :int
    attach_function :ncchannels_set_fg_rgb8_clipped, [:pointer, :int, :int, :int], :void
    attach_function :ncchannels_set_fg_palindex, [:pointer, :uint], :int
    attach_function :ncchannels_set_fg_rgb, [:pointer, :uint], :int
    attach_function :ncchannels_set_bg_rgb8, [:pointer, :uint, :uint, :uint], :int
    attach_function :ncchannels_set_bg_rgb8_clipped, [:pointer, :int, :int, :int], :void
    attach_function :ncchannels_set_bg_palindex, [:pointer, :uint], :int
    attach_function :ncchannels_set_bg_rgb, [:pointer, :uint], :int
    attach_function :ncchannels_fg_default_p, [:uint64], :bool
    attach_function :ncchannels_fg_palindex_p, [:uint64], :bool
    attach_function :ncchannels_bg_default_p, [:uint64], :bool
    attach_function :ncchannels_bg_palindex_p, [:uint64], :bool
    attach_function :ncchannels_set_fg_default, [:pointer], :uint64
    attach_function :ncchannels_set_bg_default, [:pointer], :uint64
    attach_function :nccell_init, [S::NcCell.by_ref], :void
    attach_function :nccell_prime, [:pointer, S::NcCell.by_ref, :string, :uint16, :uint64], :int
    attach_function :nccell_set_styles, [S::NcCell.by_ref, :uint], :void
    attach_function :nccell_styles, [S::NcCell.by_ref], :uint16
    attach_function :nccell_on_styles, [S::NcCell.by_ref, :uint], :void
    attach_function :nccell_off_styles, [S::NcCell.by_ref, :uint], :void
    attach_function :nccell_set_fg_default, [S::NcCell.by_ref], :void
    attach_function :nccell_set_bg_default, [S::NcCell.by_ref], :void
    attach_function :nccell_set_fg_alpha, [S::NcCell.by_ref, :uint], :int
    attach_function :nccell_set_bg_alpha, [S::NcCell.by_ref, :uint], :int
    attach_function :nccell_set_bchannel, [S::NcCell.by_ref, :uint32], :uint64
    attach_function :nccell_set_fchannel, [S::NcCell.by_ref, :uint32], :uint64
    attach_function :nccell_set_channels, [S::NcCell.by_ref, :uint64], :uint64
    attach_function :nccell_double_wide_p, [S::NcCell.by_ref], :bool
    attach_function :nccell_wide_right_p, [S::NcCell.by_ref], :bool
    attach_function :nccell_wide_left_p, [S::NcCell.by_ref], :bool
    attach_function :nccell_channels, [S::NcCell.by_ref], :uint64
    attach_function :nccell_bchannel, [S::NcCell.by_ref], :uint32
    attach_function :nccell_fchannel, [S::NcCell.by_ref], :uint32
    attach_function :nccell_cols, [S::NcCell.by_ref], :uint
    attach_function :nccell_strdup, [:pointer, S::NcCell.by_ref], :pointer
    attach_function :nccell_extract, [:pointer, S::NcCell.by_ref, :pointer, :pointer], :pointer
    attach_function :nccellcmp, [:pointer, S::NcCell.by_ref, :pointer, S::NcCell.by_ref], :bool
    attach_function :nccell_load_char, [:pointer, S::NcCell.by_ref, :char], :int
    attach_function :nccell_load_egc32, [:pointer, S::NcCell.by_ref, :uint32], :int
    attach_function :nccell_load_ucs32, [:pointer, S::NcCell.by_ref, :uint32], :int
    attach_function :notcurses_top, [:pointer], :pointer
    attach_function :notcurses_bottom, [:pointer], :pointer
    attach_function :notcurses_render, [:pointer], :int
    attach_function :nckey_mouse_p, [:uint32], :bool
    attach_function :ncinput_shift_p, [S::NcInput.by_ref], :bool
    attach_function :ncinput_ctrl_p, [S::NcInput.by_ref], :bool
    attach_function :ncinput_alt_p, [S::NcInput.by_ref], :bool
    attach_function :ncinput_meta_p, [S::NcInput.by_ref], :bool
    attach_function :ncinput_super_p, [S::NcInput.by_ref], :bool
    attach_function :ncinput_hyper_p, [S::NcInput.by_ref], :bool
    attach_function :ncinput_capslock_p, [S::NcInput.by_ref], :bool
    attach_function :ncinput_numlock_p, [S::NcInput.by_ref], :bool
    attach_function :ncinput_equal_p, [S::NcInput.by_ref, S::NcInput.by_ref], :bool
    attach_function :notcurses_get_nblock, [:pointer, S::NcInput.by_ref], :uint32
    attach_function :notcurses_get_blocking, [:pointer, S::NcInput.by_ref], :uint32
    attach_function :ncinput_nomod_p, [S::NcInput.by_ref], :bool
    attach_function :notcurses_mice_disable, [:pointer], :int
    attach_function :notcurses_stddim_yx, [:pointer, :pointer, :pointer], :pointer
    attach_function :notcurses_stddim_yx_const, [:pointer, :pointer, :pointer], :pointer
    attach_function :ncplane_dim_y, [:pointer], :uint
    attach_function :ncplane_dim_x, [:pointer], :uint
    attach_function :notcurses_term_dim_yx, [:pointer, :pointer, :pointer], :void
    attach_function :ncpalette_set_rgb8, [S::NcPalette.by_ref, :int, :uint, :uint, :uint], :int
    attach_function :ncpalette_set, [S::NcPalette.by_ref, :int, :uint], :int
    attach_function :ncpalette_get, [S::NcPalette.by_ref, :int, :pointer], :int
    attach_function :ncpalette_get_rgb8, [S::NcPalette.by_ref, :int, :pointer, :pointer, :pointer], :int
    attach_function :nccapability_canchangecolor, [S::NcCapabilities.by_ref], :bool
    attach_function :notcurses_cantruecolor, [:pointer], :bool
    attach_function :notcurses_canchangecolor, [:pointer], :bool
    attach_function :notcurses_canfade, [:pointer], :bool
    attach_function :notcurses_canutf8, [:pointer], :bool
    attach_function :notcurses_canhalfblock, [:pointer], :bool
    attach_function :notcurses_canquadrant, [:pointer], :bool
    attach_function :notcurses_cansextant, [:pointer], :bool
    attach_function :notcurses_canoctant, [:pointer], :bool
    attach_function :notcurses_canbraille, [:pointer], :bool
    attach_function :notcurses_canpixel, [:pointer], :bool
    attach_function :ncplane_resize_simple, [:pointer, :uint, :uint], :int
    attach_function :ncplane_move_rel, [:pointer, :int, :int], :int
    attach_function :ncplane_descendant_p, [:pointer, :pointer], :int
    attach_function :ncplane_move_top, [:pointer], :void
    attach_function :ncplane_move_bottom, [:pointer], :void
    attach_function :ncplane_move_family_top, [:pointer], :void
    attach_function :ncplane_move_family_bottom, [:pointer], :void
    attach_function :notcurses_align, [:int, :ncalign_e, :int], :int
    attach_function :ncplane_halign, [:pointer, :ncalign_e, :int], :int
    attach_function :ncplane_valign, [:pointer, :ncalign_e, :int], :int
    attach_function :ncplane_cursor_y, [:pointer], :uint
    attach_function :ncplane_cursor_x, [:pointer], :uint
    attach_function :ncplane_putc, [:pointer, S::NcCell.by_ref], :int
    attach_function :ncplane_putchar_yx, [:pointer, :int, :int, :char], :int
    attach_function :ncplane_putchar, [:pointer, :char], :int
    attach_function :ncplane_putegc, [:pointer, :string, :pointer], :int
    attach_function :ncwcsrtombs, [:pointer], :pointer
    attach_function :ncplane_putwegc, [:pointer, :pointer, :pointer], :int
    attach_function :ncplane_putwegc_yx, [:pointer, :int, :int, :pointer, :pointer], :int
    attach_function :ncplane_putstr_yx, [:pointer, :int, :int, :string], :int
    attach_function :ncplane_putstr, [:pointer, :string], :int
    attach_function :ncplane_putstr_aligned, [:pointer, :int, :ncalign_e, :string], :int
    attach_function :ncplane_putstr_stained, [:pointer, :string], :int
    attach_function :ncplane_putnstr_yx, [:pointer, :int, :int, :size_t, :string], :int
    attach_function :ncplane_putnstr, [:pointer, :size_t, :string], :int
    attach_function :ncplane_putwstr_yx, [:pointer, :int, :int, :pointer], :int
    attach_function :ncplane_putwstr_aligned, [:pointer, :int, :ncalign_e, :pointer], :int
    attach_function :ncplane_putwstr, [:pointer, :pointer], :int
    attach_function :ncplane_pututf32_yx, [:pointer, :int, :int, :uint32], :int
    attach_function :ncplane_putwc_yx, [:pointer, :int, :int, :wchar_t], :int
    attach_function :ncplane_putwc, [:pointer, :wchar_t], :int
    attach_function :ncplane_putwc_utf32, [:pointer, :pointer, :pointer], :int
    attach_function :ncplane_putwc_stained, [:pointer, :wchar_t], :int
    attach_function :ncplane_vprintf, [:pointer, :string, :pointer], :int
    attach_function :ncplane_printf, [:pointer, :string, :varargs], :int
    attach_function :ncplane_printf_yx, [:pointer, :int, :int, :string, :varargs], :int
    attach_function :ncplane_printf_aligned, [:pointer, :int, :ncalign_e, :string, :varargs], :int
    attach_function :ncplane_printf_stained, [:pointer, :string, :varargs], :int
    attach_function :ncplane_hline, [:pointer, S::NcCell.by_ref, :uint], :int
    attach_function :ncplane_vline, [:pointer, S::NcCell.by_ref, :uint], :int
    attach_function :ncplane_box_sized, [:pointer, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, :uint, :uint, :uint], :int
    attach_function :ncplane_perimeter, [:pointer, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, :uint], :int
    attach_function :nccell_fg_rgb, [S::NcCell.by_ref], :uint32
    attach_function :nccell_bg_rgb, [S::NcCell.by_ref], :uint32
    attach_function :nccell_fg_alpha, [S::NcCell.by_ref], :uint32
    attach_function :nccell_bg_alpha, [S::NcCell.by_ref], :uint32
    attach_function :nccell_fg_rgb8, [S::NcCell.by_ref, :pointer, :pointer, :pointer], :uint32
    attach_function :nccell_bg_rgb8, [S::NcCell.by_ref, :pointer, :pointer, :pointer], :uint32
    attach_function :nccell_set_fg_rgb8, [S::NcCell.by_ref, :uint, :uint, :uint], :int
    attach_function :nccell_set_fg_rgb8_clipped, [S::NcCell.by_ref, :int, :int, :int], :void
    attach_function :nccell_set_fg_rgb, [S::NcCell.by_ref, :uint32], :int
    attach_function :nccell_set_fg_palindex, [S::NcCell.by_ref, :uint], :int
    attach_function :nccell_fg_palindex, [S::NcCell.by_ref], :uint32
    attach_function :nccell_set_bg_rgb8, [S::NcCell.by_ref, :uint, :uint, :uint], :int
    attach_function :nccell_set_bg_rgb8_clipped, [S::NcCell.by_ref, :int, :int, :int], :void
    attach_function :nccell_set_bg_rgb, [S::NcCell.by_ref, :uint32], :int
    attach_function :nccell_set_bg_palindex, [S::NcCell.by_ref, :uint], :int
    attach_function :nccell_bg_palindex, [S::NcCell.by_ref], :uint32
    attach_function :nccell_fg_default_p, [S::NcCell.by_ref], :bool
    attach_function :nccell_fg_palindex_p, [S::NcCell.by_ref], :bool
    attach_function :nccell_bg_default_p, [S::NcCell.by_ref], :bool
    attach_function :nccell_bg_palindex_p, [S::NcCell.by_ref], :bool
    attach_function :ncplane_bchannel, [:pointer], :uint32
    attach_function :ncplane_fchannel, [:pointer], :uint32
    attach_function :ncplane_fg_rgb, [:pointer], :uint32
    attach_function :ncplane_bg_rgb, [:pointer], :uint32
    attach_function :ncplane_fg_alpha, [:pointer], :uint32
    attach_function :ncplane_fg_default_p, [:pointer], :bool
    attach_function :ncplane_bg_alpha, [:pointer], :uint32
    attach_function :ncplane_bg_default_p, [:pointer], :bool
    attach_function :ncplane_fg_rgb8, [:pointer, :pointer, :pointer, :pointer], :uint32
    attach_function :ncplane_bg_rgb8, [:pointer, :pointer, :pointer, :pointer], :uint32
    attach_function :nccells_load_box, [:pointer, :uint16, :uint64, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, :string], :int
    attach_function :nccells_ascii_box, [:pointer, :uint16, :uint64, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref], :int
    attach_function :nccells_double_box, [:pointer, :uint16, :uint64, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref], :int
    attach_function :nccells_rounded_box, [:pointer, :uint16, :uint64, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref], :int
    attach_function :nccells_light_box, [:pointer, :uint16, :uint64, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref], :int
    attach_function :nccells_heavy_box, [:pointer, :uint16, :uint64, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref, S::NcCell.by_ref], :int
    attach_function :ncplane_rounded_box, [:pointer, :uint16, :uint64, :uint, :uint, :uint], :int
    attach_function :ncplane_perimeter_rounded, [:pointer, :uint16, :uint64, :uint], :int
    attach_function :ncplane_rounded_box_sized, [:pointer, :uint16, :uint64, :uint, :uint, :uint], :int
    attach_function :ncplane_double_box, [:pointer, :uint16, :uint64, :uint, :uint, :uint], :int
    attach_function :ncplane_ascii_box, [:pointer, :uint16, :uint64, :uint, :uint, :uint], :int
    attach_function :ncplane_perimeter_double, [:pointer, :uint16, :uint64, :uint], :int
    attach_function :ncplane_double_box_sized, [:pointer, :uint16, :uint64, :uint, :uint, :uint], :int
    attach_function :ncvisualplane_create, [:pointer, S::NcPlaneOptions.by_ref, :pointer, S::NcVisualOptions.by_ref], :pointer
    attach_function :ncpixel_a, [:uint32], :uint
    attach_function :ncpixel_r, [:uint32], :uint
    attach_function :ncpixel_g, [:uint32], :uint
    attach_function :ncpixel_b, [:uint32], :uint
    attach_function :ncpixel_set_a, [:pointer, :uint], :int
    attach_function :ncpixel_set_r, [:pointer, :uint], :int
    attach_function :ncpixel_set_g, [:pointer, :uint], :int
    attach_function :ncpixel_set_b, [:pointer, :uint], :int
    attach_function :ncpixel, [:uint, :uint, :uint], :uint32
    attach_function :ncpixel_set_rgb8, [:pointer, :uint, :uint, :uint], :int
    attach_function :ncqprefix, [:uintmax_t, :uintmax_t, :pointer, :int], :string
    attach_function :nciprefix, [:uintmax_t, :uintmax_t, :pointer, :int], :string
    attach_function :ncbprefix, [:uintmax_t, :uintmax_t, :pointer, :int], :string
    attach_function :nctabbed_hdrchan, [:pointer], :uint64
    attach_function :nctabbed_selchan, [:pointer], :uint64
    attach_function :nctabbed_sepchan, [:pointer], :uint64
    attach_function :ncdirect_set_bg_rgb8, [:pointer, :uint, :uint, :uint], :int
    attach_function :ncdirect_set_fg_rgb8, [:pointer, :uint, :uint, :uint], :int
    attach_function :ncdirect_light_box, [:pointer, :uint64, :uint64, :uint64, :uint64, :uint, :uint, :uint], :int
    attach_function :ncdirect_heavy_box, [:pointer, :uint64, :uint64, :uint64, :uint64, :uint, :uint, :uint], :int
    attach_function :ncdirect_ascii_box, [:pointer, :uint64, :uint64, :uint64, :uint64, :uint, :uint, :uint], :int
    attach_function :ncdirect_get_nblock, [:pointer, S::NcInput.by_ref], :uint32
    attach_function :ncdirect_get_blocking, [:pointer, S::NcInput.by_ref], :uint32
    attach_function :ncdirect_cantruecolor, [:pointer], :bool
    attach_function :ncdirect_canchangecolor, [:pointer], :bool
    attach_function :ncdirect_canfade, [:pointer], :bool
    attach_function :ncdirect_canopen_images, [:pointer], :bool
    attach_function :ncdirect_canopen_videos, [:pointer], :bool
    attach_function :ncdirect_canhalfblock, [:pointer], :bool
    attach_function :ncdirect_canquadrant, [:pointer], :bool
    attach_function :ncdirect_cansextant, [:pointer], :bool
    attach_function :ncdirect_canoctant, [:pointer], :bool
    attach_function :ncdirect_canbraille, [:pointer], :bool

    AVAILABLE = true
  rescue LoadError => e # anche FFI::NotFoundError (simbolo mancante) è un LoadError
    AVAILABLE = false
    LOAD_ERROR = e.message
  end
end
