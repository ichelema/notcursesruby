# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  module FFI
    # ffi_lib è caricata in ffi.rb (libnotcurses, libnotcurses-core, libc)
    # Ritorno Classe.by_ref: NULL diventa un'istanza con .null? == true, non nil.
    # blocking: true (la chiamata rilascia il GVL) solo per le funzioni che
    # aspettano il terminale o il tempo: gli init (risposta a DA1, senza timeout
    # con un tty), ncdirect_cursor_yx, ncdirect_cursor_move_yx, ncdirect_readline,
    # ncvisual_stream, ncdirect_render_image e ncdirect_raster_frame (con un
    # blitter pixel, o con un allineamento su un terminale senza hpa, chiedono
    # la posizione del cursore: direct.c:225 e 439). Anche ncvisual_from_file,
    # ncvisual_decode, ncvisual_decode_loop, ncdirect_render_frame e
    # ncdirectf_from_file: aprono o leggono il file con ffmpeg, un I/O senza
    # limite di tempo (FIFO, URL, file system lento). Solo su macOS anche
    # notcurses_stop: tcsetattr(TCSAFLUSH) (notcurses.c:147) aspetta che il
    # terminale legga l'output in coda, mentre su Linux un pty non aspetta. Le
    # altre tengono il GVL durante la chiamata.

    # ═══════════════════════════════════════
    # Notcurses lifecycle
    # ═══════════════════════════════════════

    # --- version ---
    attach_function :notcurses_version, [], :string
    attach_function :notcurses_version_components, [:pointer, :pointer, :pointer, :pointer], :void

    # --- init/stop ---
    attach_function :notcurses_init, [NotcursesOptions.by_ref, :pointer], :pointer, blocking: true
    attach_function :notcurses_core_init, [NotcursesOptions.by_ref, :pointer], :pointer, blocking: true
    attach_function :notcurses_stop, [:pointer], :int, blocking: ::FFI::Platform.mac?

    # --- opzioni ---
    attach_function :notcurses_lex_margins, [:string, NotcursesOptions.by_ref], :int
    attach_function :notcurses_lex_blitter, [:string, :pointer], :int
    attach_function :notcurses_str_blitter, [:ncblitter_e], :string
    attach_function :notcurses_lex_scalemode, [:string, :pointer], :int
    attach_function :notcurses_str_scalemode, [:ncscale_e], :string

    # --- schermo ---
    attach_function :notcurses_enter_alternate_screen, [:pointer], :int
    attach_function :notcurses_leave_alternate_screen, [:pointer], :int
    attach_function :notcurses_refresh, [:pointer, :pointer, :pointer], :int

    # --- stdplane ---
    attach_function :notcurses_stdplane, [:pointer], :pointer
    attach_function :notcurses_stdplane_const, [:pointer], :pointer
    attach_function :notcurses_drop_planes, [:pointer], :void

    # --- rendering ---
    attach_function :ncpile_render, [:pointer], :int
    attach_function :ncpile_rasterize, [:pointer], :int
    # REVIEW: bug di 3.0.17 (src/lib/render.c): senza postpaint il testo non viene emesso (*buflen 0); *buf è il buffer interno di notcurses (mmap su Linux, malloc altrove): non chiamare free() benché l'header lo chieda
    attach_function :ncpile_render_to_buffer, [:pointer, :pointer, :pointer], :int
    # REVIEW: bug di 3.0.17 (src/lib/render.c): non scrive nulla su fp (raster_and_write usa nc->rstate.f) e libera pile->crender senza azzerarlo (double free in notcurses_stop)
    attach_function :ncpile_render_to_file, [:pointer, :pointer], :int
    # ALLOC: restituisce memoria da liberare con free()
    attach_function :notcurses_at_yx, [:pointer, :uint, :uint, :pointer, :pointer], :pointer

    # --- cursore ---
    attach_function :notcurses_cursor_enable, [:pointer, :int, :int], :int
    attach_function :notcurses_cursor_disable, [:pointer], :int
    attach_function :notcurses_cursor_yx, [:pointer, :pointer, :pointer], :int

    # --- capabilities ---
    attach_function :notcurses_supported_styles, [:pointer], :uint16
    attach_function :notcurses_palette_size, [:pointer], :uint
    # ALLOC: restituisce memoria da liberare con free()
    attach_function :notcurses_detected_terminal, [:pointer], :pointer
    attach_function :notcurses_capabilities, [:pointer], NcCapabilities.by_ref
    attach_function :notcurses_check_pixel_support, [:pointer], :ncpixelimpl_e
    attach_function :notcurses_canopen_images, [:pointer], :bool
    attach_function :notcurses_canopen_videos, [:pointer], :bool

    # ═══════════════════════════════════════
    # NcPlane
    # ═══════════════════════════════════════

    # --- pile ---
    attach_function :ncpile_top, [:pointer], :pointer
    attach_function :ncpile_bottom, [:pointer], :pointer
    attach_function :ncpile_create, [:pointer, NcPlaneOptions.by_ref], :pointer

    # --- creazione ---
    attach_function :ncplane_create, [:pointer, NcPlaneOptions.by_ref], :pointer
    attach_function :ncplane_resize_maximize, [:pointer], :int
    attach_function :ncplane_resize_marginalized, [:pointer], :int
    attach_function :ncplane_resize_realign, [:pointer], :int
    attach_function :ncplane_resize_placewithin, [:pointer], :int
    # callback: int(*resizecb)(struct ncplane*)
    attach_function :ncplane_set_resizecb, [:pointer, :pointer], :void
    # callback: int (*)(struct ncplane*)
    attach_function :ncplane_resizecb, [:pointer], :pointer
    attach_function :ncplane_set_name, [:pointer, :string], :int
    # ALLOC: restituisce memoria da liberare con free()
    attach_function :ncplane_name, [:pointer], :pointer
    attach_function :ncplane_dup, [:pointer, :pointer], :pointer
    attach_function :ncplane_resize, [:pointer, :int, :int, :uint, :uint, :int, :int, :uint, :uint], :int
    attach_function :ncplane_destroy, [:pointer], :int
    attach_function :ncplane_family_destroy, [:pointer], :int

    # --- relazioni ---
    attach_function :ncplane_notcurses, [:pointer], :pointer
    attach_function :ncplane_notcurses_const, [:pointer], :pointer
    attach_function :ncplane_reparent, [:pointer, :pointer], :pointer
    attach_function :ncplane_reparent_family, [:pointer, :pointer], :pointer
    attach_function :ncplane_parent, [:pointer], :pointer
    attach_function :ncplane_parent_const, [:pointer], :pointer

    # --- geometria ---
    attach_function :ncplane_dim_yx, [:pointer, :pointer, :pointer], :void
    attach_function :ncplane_pixel_geom, [:pointer, :pointer, :pointer, :pointer, :pointer, :pointer, :pointer], :void
    attach_function :ncplane_translate, [:pointer, :pointer, :pointer, :pointer], :void
    attach_function :ncplane_translate_abs, [:pointer, :pointer, :pointer], :bool
    attach_function :ncplane_yx, [:pointer, :pointer, :pointer], :void
    attach_function :ncplane_y, [:pointer], :int
    attach_function :ncplane_x, [:pointer], :int
    attach_function :ncplane_abs_yx, [:pointer, :pointer, :pointer], :void
    attach_function :ncplane_abs_y, [:pointer], :int
    attach_function :ncplane_abs_x, [:pointer], :int
    attach_function :ncplane_center_abs, [:pointer, :pointer, :pointer], :void

    # --- z-order ---
    attach_function :ncplane_move_yx, [:pointer, :int, :int], :int
    attach_function :ncplane_move_above, [:pointer, :pointer], :int
    attach_function :ncplane_move_below, [:pointer, :pointer], :int
    attach_function :ncplane_move_family_above, [:pointer, :pointer], :int
    attach_function :ncplane_move_family_below, [:pointer, :pointer], :int
    attach_function :ncplane_below, [:pointer], :pointer
    attach_function :ncplane_above, [:pointer], :pointer

    # --- scrolling ---
    attach_function :ncplane_set_scrolling, [:pointer, :uint], :bool
    attach_function :ncplane_scrolling_p, [:pointer], :bool
    attach_function :ncplane_set_autogrow, [:pointer, :uint], :bool
    attach_function :ncplane_autogrow_p, [:pointer], :bool
    attach_function :ncplane_scrollup, [:pointer, :int], :int
    attach_function :ncplane_scrollup_child, [:pointer, :pointer], :int
    attach_function :ncplane_rotate_cw, [:pointer], :int
    attach_function :ncplane_rotate_ccw, [:pointer], :int

    # --- cursore ---
    attach_function :ncplane_cursor_move_yx, [:pointer, :int, :int], :int
    attach_function :ncplane_cursor_move_rel, [:pointer, :int, :int], :int
    attach_function :ncplane_home, [:pointer], :void
    attach_function :ncplane_cursor_yx, [:pointer, :pointer, :pointer], :void

    # --- contenuto ---
    attach_function :ncplane_set_base_cell, [:pointer, NcCell.by_ref], :int
    attach_function :ncplane_set_base, [:pointer, :string, :uint16, :uint64], :int
    attach_function :ncplane_base, [:pointer, NcCell.by_ref], :int
    # ALLOC: restituisce memoria da liberare con free()
    attach_function :ncplane_at_cursor, [:pointer, :pointer, :pointer], :pointer
    attach_function :ncplane_at_cursor_cell, [:pointer, NcCell.by_ref], :int
    # ALLOC: restituisce memoria da liberare con free()
    attach_function :ncplane_at_yx, [:pointer, :int, :int, :pointer, :pointer], :pointer
    attach_function :ncplane_at_yx_cell, [:pointer, :int, :int, NcCell.by_ref], :int
    # ALLOC: restituisce memoria da liberare con free()
    attach_function :ncplane_contents, [:pointer, :int, :int, :uint, :uint], :pointer
    attach_function :ncplane_set_userptr, [:pointer, :pointer], :pointer
    attach_function :ncplane_userptr, [:pointer], :pointer
    # NOTE: potrebbe appartenere a NcVisual
    # ALLOC: restituisce memoria da liberare con free()
    attach_function :ncplane_as_rgba, [:pointer, :ncblitter_e, :int, :int, :uint, :uint, :pointer, :pointer], :pointer
    attach_function :ncplane_mergedown_simple, [:pointer, :pointer], :int
    attach_function :ncplane_mergedown, [:pointer, :pointer, :int, :int, :uint, :uint, :int, :int], :int
    attach_function :ncplane_erase, [:pointer], :void
    attach_function :ncplane_erase_region, [:pointer, :int, :int, :int, :int], :int
    attach_function :ncplane_greyscale, [:pointer], :void
    # NOTE: potrebbe appartenere a NcVisual
    attach_function :ncplane_qrcode, [:pointer, :pointer, :pointer, :pointer, :size_t], :int

    # --- output ---
    # NOTE: potrebbe appartenere a Notcurses lifecycle (utilità stringhe)
    attach_function :ncstrwidth, [:string, :pointer, :pointer], :int
    attach_function :ncplane_putc_yx, [:pointer, :int, :int, NcCell.by_ref], :int
    attach_function :ncplane_putchar_stained, [:pointer, :char], :int
    attach_function :ncplane_putegc_yx, [:pointer, :int, :int, :string, :pointer], :int
    attach_function :ncplane_putegc_stained, [:pointer, :string, :pointer], :int
    # gclust: const wchar_t*, vettore di :wchar_t terminato da 0
    attach_function :ncplane_putwegc_stained, [:pointer, :pointer, :pointer], :int
    attach_function :ncplane_putnstr_aligned, [:pointer, :int, :ncalign_e, :size_t, :string], :int
    # gclustarr: const wchar_t*, vettore di :wchar_t terminato da 0
    attach_function :ncplane_putwstr_stained, [:pointer, :pointer], :int
    # REVIEW: va_list non costruibile da Ruby; usare le inline ncplane_printf* di inline_reimpl.rb
    attach_function :ncplane_vprintf_aligned, [:pointer, :int, :ncalign_e, :string, :pointer], :int
    # REVIEW: va_list non costruibile da Ruby; usare le inline ncplane_printf* di inline_reimpl.rb
    attach_function :ncplane_vprintf_yx, [:pointer, :int, :int, :string, :pointer], :int
    # REVIEW: va_list non costruibile da Ruby; usare le inline ncplane_printf* di inline_reimpl.rb
    attach_function :ncplane_vprintf_stained, [:pointer, :string, :pointer], :int
    attach_function :ncplane_puttext, [:pointer, :int, :ncalign_e, :string, :pointer], :int

    # --- stili ---
    attach_function :ncplane_styles, [:pointer], :uint16
    attach_function :ncplane_format, [:pointer, :int, :int, :uint, :uint, :uint16], :int
    attach_function :ncplane_set_styles, [:pointer, :uint], :void
    attach_function :ncplane_on_styles, [:pointer, :uint], :void
    attach_function :ncplane_off_styles, [:pointer, :uint], :void

    # --- linee e box ---
    attach_function :ncplane_hline_interp, [:pointer, NcCell.by_ref, :uint, :uint64, :uint64], :int
    attach_function :ncplane_vline_interp, [:pointer, NcCell.by_ref, :uint, :uint64, :uint64], :int
    attach_function :ncplane_box, [:pointer, NcCell.by_ref, NcCell.by_ref, NcCell.by_ref, NcCell.by_ref, NcCell.by_ref, NcCell.by_ref, :uint, :uint, :uint], :int
    attach_function :ncplane_polyfill_yx, [:pointer, :int, :int, NcCell.by_ref], :int
    attach_function :ncplane_gradient, [:pointer, :int, :int, :uint, :uint, :string, :uint16, :uint64, :uint64, :uint64, :uint64], :int
    attach_function :ncplane_gradient2x1, [:pointer, :int, :int, :uint, :uint, :uint32, :uint32, :uint32, :uint32], :int
    attach_function :ncplane_stain, [:pointer, :int, :int, :uint, :uint, :uint64, :uint64, :uint64, :uint64], :int

    # --- nccell (contenuto e stile) ---
    attach_function :nccell_load, [:pointer, NcCell.by_ref, :string], :int
    attach_function :nccell_duplicate, [:pointer, NcCell.by_ref, NcCell.by_ref], :int
    attach_function :nccell_release, [:pointer, NcCell.by_ref], :void
    attach_function :nccell_extended_gcluster, [:pointer, NcCell.by_ref], :string

    # ═══════════════════════════════════════
    # Input
    # ═══════════════════════════════════════

    # --- lettura ---
    attach_function :notcurses_get, [:pointer, Timespec.by_ref, NcInput.by_ref], :uint32
    # ni: vettore di vcount NcInput (es. ::FFI::MemoryPointer.new(NcInput, vcount))
    attach_function :notcurses_getvec, [:pointer, Timespec.by_ref, :pointer, :int], :int
    attach_function :notcurses_inputready_fd, [:pointer], :int

    # --- mouse e segnali ---
    attach_function :notcurses_mice_enable, [:pointer, :uint], :int
    attach_function :notcurses_linesigs_disable, [:pointer], :int
    attach_function :notcurses_linesigs_enable, [:pointer], :int

    # --- ucs32 ---
    # NOTE: potrebbe appartenere a Notcurses lifecycle (utilità UTF-8)
    # ucs32: vettore di ucs32count uint32_t; resultbuf: buffer di buflen byte
    attach_function :notcurses_ucs32_to_utf8, [:pointer, :uint, :pointer, :size_t], :int

    # ═══════════════════════════════════════
    # Channels / Colors
    # ═══════════════════════════════════════

    # --- colori del piano ---
    # NOTE: potrebbe appartenere a NcPlane
    attach_function :ncplane_channels, [:pointer], :uint64
    # NOTE: potrebbe appartenere a NcPlane
    attach_function :ncplane_set_channels, [:pointer, :uint64], :void
    # NOTE: potrebbe appartenere a NcPlane
    attach_function :ncplane_set_bchannel, [:pointer, :uint32], :uint64
    # NOTE: potrebbe appartenere a NcPlane
    attach_function :ncplane_set_fchannel, [:pointer, :uint32], :uint64
    # NOTE: potrebbe appartenere a NcPlane
    attach_function :ncplane_set_fg_rgb8, [:pointer, :uint, :uint, :uint], :int
    # NOTE: potrebbe appartenere a NcPlane
    attach_function :ncplane_set_bg_rgb8, [:pointer, :uint, :uint, :uint], :int
    # NOTE: potrebbe appartenere a NcPlane
    attach_function :ncplane_set_bg_rgb8_clipped, [:pointer, :int, :int, :int], :void
    # NOTE: potrebbe appartenere a NcPlane
    attach_function :ncplane_set_fg_rgb8_clipped, [:pointer, :int, :int, :int], :void
    # NOTE: potrebbe appartenere a NcPlane
    attach_function :ncplane_set_fg_rgb, [:pointer, :uint32], :int
    # NOTE: potrebbe appartenere a NcPlane
    attach_function :ncplane_set_bg_rgb, [:pointer, :uint32], :int
    # NOTE: potrebbe appartenere a NcPlane
    attach_function :ncplane_set_fg_default, [:pointer], :void
    # NOTE: potrebbe appartenere a NcPlane
    attach_function :ncplane_set_bg_default, [:pointer], :void
    # NOTE: potrebbe appartenere a NcPlane
    attach_function :ncplane_set_fg_palindex, [:pointer, :uint], :int
    # NOTE: potrebbe appartenere a NcPlane
    attach_function :ncplane_set_bg_palindex, [:pointer, :uint], :int
    # NOTE: potrebbe appartenere a NcPlane
    attach_function :ncplane_set_fg_alpha, [:pointer, :int], :int
    # NOTE: potrebbe appartenere a NcPlane
    attach_function :ncplane_set_bg_alpha, [:pointer, :int], :int

    # --- palette ---
    attach_function :ncpalette_new, [:pointer], NcPalette.by_ref
    attach_function :ncpalette_use, [:pointer, NcPalette.by_ref], :int
    attach_function :ncpalette_free, [NcPalette.by_ref], :void

    # --- default ---
    attach_function :notcurses_default_foreground, [:pointer, :pointer], :int
    attach_function :notcurses_default_background, [:pointer, :pointer], :int

    # ═══════════════════════════════════════
    # NcVisual
    # ═══════════════════════════════════════

    # --- ncvisual ---
    attach_function :ncvisual_from_file, [:string], :pointer, blocking: true
    attach_function :ncvisual_from_rgba, [:pointer, :int, :int, :int], :pointer
    attach_function :ncvisual_from_rgb_packed, [:pointer, :int, :int, :int, :int], :pointer
    attach_function :ncvisual_from_rgb_loose, [:pointer, :int, :int, :int, :int], :pointer
    attach_function :ncvisual_from_bgra, [:pointer, :int, :int, :int], :pointer
    # palette: vettore di almeno palsize canali uint32_t
    attach_function :ncvisual_from_palidx, [:pointer, :int, :int, :int, :int, :int, :pointer], :pointer
    attach_function :ncvisual_from_plane, [:pointer, :ncblitter_e, :int, :int, :uint, :uint], :pointer
    attach_function :ncvisual_from_sixel, [:string, :uint, :uint], :pointer
    attach_function :ncvisual_geom, [:pointer, :pointer, NcVisualOptions.by_ref, NcVgeom.by_ref], :int
    attach_function :ncvisual_destroy, [:pointer], :void
    attach_function :ncvisual_decode, [:pointer], :int, blocking: true
    attach_function :ncvisual_decode_loop, [:pointer], :int, blocking: true
    attach_function :ncvisual_rotate, [:pointer, :double], :int
    attach_function :ncvisual_resize, [:pointer, :int, :int], :int
    attach_function :ncvisual_resize_noninterpolative, [:pointer, :int, :int], :int
    attach_function :ncvisual_polyfill_yx, [:pointer, :uint, :uint, :uint32], :int
    attach_function :ncvisual_at_yx, [:pointer, :uint, :uint, :pointer], :int
    attach_function :ncvisual_set_yx, [:pointer, :uint, :uint, :uint32], :int
    attach_function :ncvisual_blit, [:pointer, :pointer, NcVisualOptions.by_ref], :pointer
    attach_function :ncvisual_subtitle_plane, [:pointer, :pointer], :pointer
    attach_function :ncvisual_media_defblitter, [:pointer, :ncscale_e], :ncblitter_e
    attach_function :ncvisual_simple_streamer, [:pointer, NcVisualOptions.by_ref, Timespec.by_ref, :pointer], :int
    # callback: int (*ncstreamcb)(struct ncvisual*, struct ncvisual_options*, const struct timespec*, void*)
    attach_function :ncvisual_stream, [:pointer, :pointer, :float, :pointer, NcVisualOptions.by_ref, :pointer], :int,
                    blocking: true

    # --- ncblit ---
    attach_function :ncblit_rgba, [:pointer, :int, NcVisualOptions.by_ref], :int
    attach_function :ncblit_bgrx, [:pointer, :int, NcVisualOptions.by_ref], :int
    attach_function :ncblit_rgb_packed, [:pointer, :int, NcVisualOptions.by_ref, :int], :int
    attach_function :ncblit_rgb_loose, [:pointer, :int, NcVisualOptions.by_ref, :int], :int

    # ═══════════════════════════════════════
    # Widgets (selector, menu, reader, reel, tabbed, tree, plot, progbar)
    # ═══════════════════════════════════════

    # --- ncreel ---
    attach_function :ncreel_create, [:pointer, NcReelOptions.by_ref], :pointer
    attach_function :ncreel_plane, [:pointer], :pointer
    # callback: int (*tabletcb)(struct nctablet* t, bool drawfromtop)
    attach_function :ncreel_add, [:pointer, :pointer, :pointer, :pointer, :pointer], :pointer
    attach_function :ncreel_tabletcount, [:pointer], :int
    attach_function :ncreel_del, [:pointer, :pointer], :int
    attach_function :ncreel_redraw, [:pointer], :int
    attach_function :ncreel_offer_input, [:pointer, NcInput.by_ref], :bool
    attach_function :ncreel_focused, [:pointer], :pointer
    attach_function :ncreel_next, [:pointer], :pointer
    attach_function :ncreel_prev, [:pointer], :pointer
    attach_function :ncreel_destroy, [:pointer], :void
    attach_function :nctablet_userptr, [:pointer], :pointer
    attach_function :nctablet_plane, [:pointer], :pointer

    # --- ncselector ---
    attach_function :ncselector_create, [:pointer, NcSelectorOptions.by_ref], :pointer
    attach_function :ncselector_additem, [:pointer, NcSelectorItem.by_ref], :int
    attach_function :ncselector_delitem, [:pointer, :string], :int
    attach_function :ncselector_selected, [:pointer], :string
    attach_function :ncselector_plane, [:pointer], :pointer
    attach_function :ncselector_previtem, [:pointer], :string
    attach_function :ncselector_nextitem, [:pointer], :string
    attach_function :ncselector_offer_input, [:pointer, NcInput.by_ref], :bool
    # ALLOC: la stringa scritta in *item (char**) va liberata con free()
    attach_function :ncselector_destroy, [:pointer, :pointer], :void

    # --- ncmultiselector ---
    attach_function :ncmultiselector_create, [:pointer, NcMultiselectorOptions.by_ref], :pointer
    # selected: vettore di count bool (es. ::FFI::MemoryPointer.new(:bool, count))
    attach_function :ncmultiselector_selected, [:pointer, :pointer, :uint], :int
    attach_function :ncmultiselector_plane, [:pointer], :pointer
    attach_function :ncmultiselector_offer_input, [:pointer, NcInput.by_ref], :bool
    attach_function :ncmultiselector_destroy, [:pointer], :void

    # --- nctree ---
    attach_function :nctree_create, [:pointer, NcTreeOptions.by_ref], :pointer
    attach_function :nctree_plane, [:pointer], :pointer
    attach_function :nctree_redraw, [:pointer], :int
    attach_function :nctree_offer_input, [:pointer, NcInput.by_ref], :bool
    attach_function :nctree_focused, [:pointer], :pointer
    attach_function :nctree_next, [:pointer], :pointer
    attach_function :nctree_prev, [:pointer], :pointer
    # spec: vettore di unsigned terminato da UINT_MAX (es. ::FFI::MemoryPointer.new(:uint, n + 1))
    attach_function :nctree_goto, [:pointer, :pointer, :pointer], :pointer
    # spec: vettore di unsigned terminato da UINT_MAX (es. ::FFI::MemoryPointer.new(:uint, n + 1))
    attach_function :nctree_add, [:pointer, :pointer, NcTreeItem.by_ref], :int
    # spec: vettore di unsigned terminato da UINT_MAX (es. ::FFI::MemoryPointer.new(:uint, n + 1))
    attach_function :nctree_del, [:pointer, :pointer], :int
    attach_function :nctree_destroy, [:pointer], :void

    # --- ncmenu ---
    attach_function :ncmenu_create, [:pointer, NcMenuOptions.by_ref], :pointer
    attach_function :ncmenu_unroll, [:pointer, :int], :int
    attach_function :ncmenu_rollup, [:pointer], :int
    attach_function :ncmenu_nextsection, [:pointer], :int
    attach_function :ncmenu_prevsection, [:pointer], :int
    attach_function :ncmenu_nextitem, [:pointer], :int
    attach_function :ncmenu_previtem, [:pointer], :int
    attach_function :ncmenu_item_set_status, [:pointer, :string, :string, :bool], :int
    attach_function :ncmenu_selected, [:pointer, NcInput.by_ref], :string
    attach_function :ncmenu_mouse_selected, [:pointer, NcInput.by_ref, NcInput.by_ref], :string
    attach_function :ncmenu_plane, [:pointer], :pointer
    attach_function :ncmenu_offer_input, [:pointer, NcInput.by_ref], :bool
    attach_function :ncmenu_destroy, [:pointer], :void

    # --- ncprogbar ---
    attach_function :ncprogbar_create, [:pointer, NcProgbarOptions.by_ref], :pointer
    attach_function :ncprogbar_plane, [:pointer], :pointer
    attach_function :ncprogbar_set_progress, [:pointer, :double], :int
    attach_function :ncprogbar_progress, [:pointer], :double
    attach_function :ncprogbar_destroy, [:pointer], :void

    # --- nctabbed ---
    attach_function :nctabbed_create, [:pointer, NcTabbedOptions.by_ref], :pointer
    attach_function :nctabbed_destroy, [:pointer], :void
    attach_function :nctabbed_redraw, [:pointer], :void
    attach_function :nctabbed_ensure_selected_header_visible, [:pointer], :void
    attach_function :nctabbed_selected, [:pointer], :pointer
    attach_function :nctabbed_leftmost, [:pointer], :pointer
    attach_function :nctabbed_tabcount, [:pointer], :int
    attach_function :nctabbed_plane, [:pointer], :pointer
    attach_function :nctabbed_content_plane, [:pointer], :pointer
    # callback: void (*tabcb)(struct nctab* t, struct ncplane* ncp, void* curry)
    attach_function :nctab_cb, [:pointer], :pointer
    attach_function :nctab_name, [:pointer], :string
    attach_function :nctab_name_width, [:pointer], :int
    attach_function :nctab_userptr, [:pointer], :pointer
    attach_function :nctab_next, [:pointer], :pointer
    attach_function :nctab_prev, [:pointer], :pointer
    # callback: void (*tabcb)(struct nctab* t, struct ncplane* ncp, void* curry)
    attach_function :nctabbed_add, [:pointer, :pointer, :pointer, :pointer, :string, :pointer], :pointer
    attach_function :nctabbed_del, [:pointer, :pointer], :int
    attach_function :nctab_move, [:pointer, :pointer, :pointer, :pointer], :int
    attach_function :nctab_move_right, [:pointer, :pointer], :void
    attach_function :nctab_move_left, [:pointer, :pointer], :void
    attach_function :nctabbed_rotate, [:pointer, :int], :void
    attach_function :nctabbed_next, [:pointer], :pointer
    attach_function :nctabbed_prev, [:pointer], :pointer
    attach_function :nctabbed_select, [:pointer, :pointer], :pointer
    attach_function :nctabbed_channels, [:pointer, :pointer, :pointer, :pointer], :void
    attach_function :nctabbed_separator, [:pointer], :string
    attach_function :nctabbed_separator_width, [:pointer], :int
    attach_function :nctabbed_set_hdrchan, [:pointer, :uint64], :void
    attach_function :nctabbed_set_selchan, [:pointer, :uint64], :void
    attach_function :nctabbed_set_sepchan, [:pointer, :uint64], :void
    # callback (parametro newcb e ritorno): void (*tabcb)(struct nctab* t, struct ncplane* ncp, void* curry)
    attach_function :nctab_set_cb, [:pointer, :pointer], :pointer
    attach_function :nctab_set_name, [:pointer, :string], :int
    attach_function :nctab_set_userptr, [:pointer, :pointer], :pointer
    attach_function :nctabbed_set_separator, [:pointer, :string], :int

    # --- ncplot ---
    attach_function :ncuplot_create, [:pointer, NcPlotOptions.by_ref, :uint64, :uint64], :pointer
    attach_function :ncdplot_create, [:pointer, NcPlotOptions.by_ref, :double, :double], :pointer
    attach_function :ncuplot_plane, [:pointer], :pointer
    attach_function :ncdplot_plane, [:pointer], :pointer
    attach_function :ncuplot_add_sample, [:pointer, :uint64, :uint64], :int
    attach_function :ncdplot_add_sample, [:pointer, :uint64, :double], :int
    attach_function :ncuplot_set_sample, [:pointer, :uint64, :uint64], :int
    attach_function :ncdplot_set_sample, [:pointer, :uint64, :double], :int
    attach_function :ncuplot_sample, [:pointer, :uint64, :pointer], :int
    attach_function :ncdplot_sample, [:pointer, :uint64, :pointer], :int
    attach_function :ncuplot_destroy, [:pointer], :void
    attach_function :ncdplot_destroy, [:pointer], :void

    # --- ncreader ---
    attach_function :ncreader_create, [:pointer, NcReaderOptions.by_ref], :pointer
    attach_function :ncreader_clear, [:pointer], :int
    attach_function :ncreader_plane, [:pointer], :pointer
    attach_function :ncreader_offer_input, [:pointer, NcInput.by_ref], :bool
    attach_function :ncreader_move_left, [:pointer], :int
    attach_function :ncreader_move_right, [:pointer], :int
    attach_function :ncreader_move_up, [:pointer], :int
    attach_function :ncreader_move_down, [:pointer], :int
    attach_function :ncreader_write_egc, [:pointer, :string], :int
    # ALLOC: restituisce memoria da liberare con free()
    attach_function :ncreader_contents, [:pointer], :pointer
    # ALLOC: la stringa scritta in *contents (char**) va liberata con free()
    attach_function :ncreader_destroy, [:pointer, :pointer], :void

    # --- ncfdplane ---
    # NOTE: potrebbe appartenere a Input (wrapper di I/O, non widget)
    # callback: int(*ncfdplane_callback)(struct ncfdplane* n, const void* buf, size_t s, void* curry)
    # callback: int(*ncfdplane_done_cb)(struct ncfdplane* n, int fderrno, void* curry)
    attach_function :ncfdplane_create, [:pointer, NcFdplaneOptions.by_ref, :int, :pointer, :pointer], :pointer
    # NOTE: potrebbe appartenere a Input (wrapper di I/O, non widget)
    attach_function :ncfdplane_plane, [:pointer], :pointer
    # NOTE: potrebbe appartenere a Input (wrapper di I/O, non widget)
    attach_function :ncfdplane_destroy, [:pointer], :int

    # --- ncsubproc ---
    # NOTE: potrebbe appartenere a Input (wrapper di I/O, non widget)
    # arg: vettore di char* terminato da NULL (es. ::FFI::MemoryPointer.new(:pointer, n + 1))
    # callback: int(*ncfdplane_callback)(struct ncfdplane* n, const void* buf, size_t s, void* curry)
    # callback: int(*ncfdplane_done_cb)(struct ncfdplane* n, int fderrno, void* curry)
    attach_function :ncsubproc_createv, [:pointer, NcSubprocOptions.by_ref, :string, :pointer, :pointer, :pointer], :pointer
    # NOTE: potrebbe appartenere a Input (wrapper di I/O, non widget)
    # arg: vettore di char* terminato da NULL (es. ::FFI::MemoryPointer.new(:pointer, n + 1))
    # callback: int(*ncfdplane_callback)(struct ncfdplane* n, const void* buf, size_t s, void* curry)
    # callback: int(*ncfdplane_done_cb)(struct ncfdplane* n, int fderrno, void* curry)
    attach_function :ncsubproc_createvp, [:pointer, NcSubprocOptions.by_ref, :string, :pointer, :pointer, :pointer], :pointer
    # NOTE: potrebbe appartenere a Input (wrapper di I/O, non widget)
    # arg, env: vettori di char* terminati da NULL (es. ::FFI::MemoryPointer.new(:pointer, n + 1))
    # callback: int(*ncfdplane_callback)(struct ncfdplane* n, const void* buf, size_t s, void* curry)
    # callback: int(*ncfdplane_done_cb)(struct ncfdplane* n, int fderrno, void* curry)
    attach_function :ncsubproc_createvpe, [:pointer, NcSubprocOptions.by_ref, :string, :pointer, :pointer, :pointer, :pointer], :pointer
    # NOTE: potrebbe appartenere a Input (wrapper di I/O, non widget)
    attach_function :ncsubproc_plane, [:pointer], :pointer
    # NOTE: potrebbe appartenere a Input (wrapper di I/O, non widget)
    attach_function :ncsubproc_destroy, [:pointer], :int

    # ═══════════════════════════════════════
    # Fade / Animation
    # ═══════════════════════════════════════

    # --- fade ---
    # callback: int (*fadecb)(struct notcurses* nc, struct ncplane* n, const struct timespec*, void* curry)
    attach_function :ncplane_fadeout, [:pointer, Timespec.by_ref, :pointer, :pointer], :int
    # callback: int (*fadecb)(struct notcurses* nc, struct ncplane* n, const struct timespec*, void* curry)
    attach_function :ncplane_fadein, [:pointer, Timespec.by_ref, :pointer, :pointer], :int
    attach_function :ncfadectx_setup, [:pointer], :pointer
    attach_function :ncfadectx_iterations, [:pointer], :int
    # callback: int (*fadecb)(struct notcurses* nc, struct ncplane* n, const struct timespec*, void* curry)
    attach_function :ncplane_fadeout_iteration, [:pointer, :pointer, :int, :pointer, :pointer], :int
    # callback: int (*fadecb)(struct notcurses* nc, struct ncplane* n, const struct timespec*, void* curry)
    attach_function :ncplane_fadein_iteration, [:pointer, :pointer, :int, :pointer, :pointer], :int
    # callback: int (*fadecb)(struct notcurses* nc, struct ncplane* n, const struct timespec*, void* curry)
    attach_function :ncplane_pulse, [:pointer, Timespec.by_ref, :pointer, :pointer], :int
    attach_function :ncfadectx_free, [:pointer], :void

    # ═══════════════════════════════════════
    # Stats / Debug
    # ═══════════════════════════════════════

    # --- stats ---
    # ALLOC: restituisce memoria da liberare con free() (st.to_ptr)
    attach_function :notcurses_stats_alloc, [:pointer], NcStats.by_ref
    attach_function :notcurses_stats, [:pointer, NcStats.by_ref], :void
    attach_function :notcurses_stats_reset, [:pointer, NcStats.by_ref], :void

    # --- debug ---
    # NOTE: potrebbe appartenere a Notcurses lifecycle (informazioni di sistema)
    # ALLOC: restituisce memoria da liberare con free()
    attach_function :notcurses_accountname, [], :pointer
    # NOTE: potrebbe appartenere a Notcurses lifecycle (informazioni di sistema)
    # ALLOC: restituisce memoria da liberare con free()
    attach_function :notcurses_hostname, [], :pointer
    # NOTE: potrebbe appartenere a Notcurses lifecycle (informazioni di sistema)
    # ALLOC: restituisce memoria da liberare con free()
    attach_function :notcurses_osversion, [], :pointer
    attach_function :notcurses_debug, [:pointer, :pointer], :void

    # --- metric ---
    # NOTE: potrebbe appartenere a Notcurses lifecycle (formattazione numerica)
    # REVIEW: il C restituisce buf (memoria del chiamante) o NULL; :string ne dà una copia (nil se NULL)
    attach_function :ncnmetric, [:uintmax_t, :size_t, :uintmax_t, :pointer, :int, :uintmax_t, :int], :string

    # ═══════════════════════════════════════
    # NcDirect (direct.h)
    # ═══════════════════════════════════════

    # --- init/stop ---
    attach_function :ncdirect_init, [:string, :pointer, :uint64], :pointer, blocking: true
    attach_function :ncdirect_core_init, [:string, :pointer, :uint64], :pointer, blocking: true
    attach_function :ncdirect_stop, [:pointer], :int

    # --- colori ---
    attach_function :ncdirect_set_fg_rgb, [:pointer, :uint], :int
    attach_function :ncdirect_set_bg_rgb, [:pointer, :uint], :int
    attach_function :ncdirect_set_fg_palindex, [:pointer, :int], :int
    attach_function :ncdirect_set_bg_palindex, [:pointer, :int], :int
    attach_function :ncdirect_palette_size, [:pointer], :uint
    attach_function :ncdirect_set_fg_default, [:pointer], :int
    attach_function :ncdirect_set_bg_default, [:pointer], :int

    # --- stili ---
    attach_function :ncdirect_supported_styles, [:pointer], :uint16
    attach_function :ncdirect_set_styles, [:pointer, :uint], :int
    attach_function :ncdirect_on_styles, [:pointer, :uint], :int
    attach_function :ncdirect_off_styles, [:pointer, :uint], :int
    attach_function :ncdirect_styles, [:pointer], :uint16

    # --- output ---
    attach_function :ncdirect_putstr, [:pointer, :uint64, :string], :int
    attach_function :ncdirect_putegc, [:pointer, :uint64, :string, :pointer], :int
    # varargs ruby-ffi: coppie tipo/valore dopo fmt (es. :int, 5, :string, 'x')
    # NOTE: bug di 3.0.17 (src/lib/direct.c:818): scrive con puts() su stdout, non sul FILE* di ncdirect_init, e aggiunge "\n"; restituisce il valore di puts(), non le colonne
    attach_function :ncdirect_printf_aligned, [:pointer, :int, :ncalign_e, :string, :varargs], :int
    attach_function :ncdirect_flush, [:pointer], :int

    # --- schermo ---
    attach_function :ncdirect_dim_x, [:pointer], :uint
    attach_function :ncdirect_dim_y, [:pointer], :uint
    attach_function :ncdirect_clear, [:pointer], :int

    # --- cursore ---
    attach_function :ncdirect_cursor_move_yx, [:pointer, :int, :int], :int, blocking: true
    attach_function :ncdirect_cursor_enable, [:pointer], :int
    attach_function :ncdirect_cursor_disable, [:pointer], :int
    attach_function :ncdirect_cursor_up, [:pointer, :int], :int
    attach_function :ncdirect_cursor_left, [:pointer, :int], :int
    attach_function :ncdirect_cursor_right, [:pointer, :int], :int
    attach_function :ncdirect_cursor_down, [:pointer, :int], :int
    attach_function :ncdirect_cursor_yx, [:pointer, :pointer, :pointer], :int, blocking: true
    attach_function :ncdirect_cursor_push, [:pointer], :int
    attach_function :ncdirect_cursor_pop, [:pointer], :int

    # --- linee e box ---
    attach_function :ncdirect_hline_interp, [:pointer, :string, :uint, :uint64, :uint64], :int
    attach_function :ncdirect_vline_interp, [:pointer, :string, :uint, :uint64, :uint64], :int
    # wchars: const wchar_t*, vettore di 6 :wchar_t (UL, UR, LL, LR, HL, VL)
    attach_function :ncdirect_box, [:pointer, :uint64, :uint64, :uint64, :uint64, :pointer, :uint, :uint, :uint], :int
    attach_function :ncdirect_rounded_box, [:pointer, :uint64, :uint64, :uint64, :uint64, :uint, :uint, :uint], :int
    attach_function :ncdirect_double_box, [:pointer, :uint64, :uint64, :uint64, :uint64, :uint, :uint, :uint], :int

    # --- input ---
    # ALLOC: restituisce memoria da liberare con free()
    attach_function :ncdirect_readline, [:pointer, :string], :pointer, blocking: true
    attach_function :ncdirect_get, [:pointer, Timespec.by_ref, NcInput.by_ref], :uint32
    attach_function :ncdirect_inputready_fd, [:pointer], :int

    # --- immagini ---
    attach_function :ncdirect_render_image, [:pointer, :string, :ncalign_e, :ncblitter_e, :ncscale_e], :int, blocking: true
    attach_function :ncdirect_render_frame, [:pointer, :string, :ncblitter_e, :ncscale_e, :int, :int], :pointer, blocking: true
    attach_function :ncdirect_raster_frame, [:pointer, :pointer, :ncalign_e], :int, blocking: true
    attach_function :ncdirectf_from_file, [:pointer, :string], :pointer, blocking: true
    attach_function :ncdirectf_free, [:pointer], :void
    attach_function :ncdirectf_render, [:pointer, :pointer, NcVisualOptions.by_ref], :pointer
    attach_function :ncdirectf_geom, [:pointer, :pointer, NcVisualOptions.by_ref, NcVgeom.by_ref], :int
    # callback: int (*ncstreamcb)(struct ncvisual*, struct ncvisual_options*, const struct timespec*, void*)
    attach_function :ncdirect_stream, [:pointer, :string, :pointer, NcVisualOptions.by_ref, :pointer], :int

    # --- capabilities ---
    attach_function :ncdirect_capabilities, [:pointer], NcCapabilities.by_ref
    # ALLOC: restituisce memoria da liberare con free()
    attach_function :ncdirect_detected_terminal, [:pointer], :pointer
    attach_function :ncdirect_canutf8, [:pointer], :bool
    attach_function :ncdirect_check_pixel_support, [:pointer], :int
    attach_function :ncdirect_canget_cursor, [:pointer], :bool

    # ═══════════════════════════════════════
    # libc
    # ═══════════════════════════════════════
    # fopen/fclose servono per il FILE* di notcurses_init/ncdirect_init, free per la
    # memoria ALLOC, tcgetattr/tcsetattr per il controllo di flusso (IXON), che
    # notcurses non tocca, e per leggere ISIG, le altre per le reimplementazioni
    # inline.

    # --- stdio ---
    attach_function :fopen, [:string, :string], :pointer
    attach_function :fclose, [:pointer], :int

    # --- memoria ---
    attach_function :free, [:pointer], :void
    # ALLOC: restituisce memoria da liberare con free()
    attach_function :strdup, [:string], :pointer

    # --- stringhe e caratteri estesi ---
    attach_function :snprintf, [:pointer, :size_t, :string, :varargs], :int
    attach_function :wcwidth, [:wchar_t], :int
    attach_function :wcswidth, [:pointer, :size_t], :int
    attach_function :wcslen, [:pointer], :size_t
    attach_function :wcsrtombs, [:pointer, :pointer, :size_t, :pointer], :size_t
    attach_function :wcrtomb, [:pointer, :wchar_t, :pointer], :size_t

    # --- terminale (<termios.h>) ---
    # termios: struct Termios di structs.rb; IXON, ISIG e TCSANOW in constants.rb
    attach_function :tcgetattr, [:int, :pointer], :int
    attach_function :tcsetattr, [:int, :int, :pointer], :int
  end
end
