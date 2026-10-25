# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  module FFI
    # --- NcBlitter (ncblitter_e) ---
    NCBLIT_DEFAULT = 0 # let the ncvisual pick
    NCBLIT_1x1     = 1 # space, compatible with ASCII
    NCBLIT_2x1     = 2 # halves + 1x1 (space)
    NCBLIT_2x2     = 3 # quadrants + 2x1
    NCBLIT_3x2     = 4 # sextants + 2x1
    NCBLIT_4x2     = 5 # octants + 2x2
    NCBLIT_BRAILLE = 6 # 4 rows, 2 cols (braille)
    NCBLIT_PIXEL   = 7 # pixel graphics
    NCBLIT_4x1     = 8 # four vertical levels (solo plot)
    NCBLIT_8x1     = 9 # eight vertical levels (solo plot)

    # --- NcAlign (ncalign_e) ---
    NCALIGN_UNALIGNED = 0
    NCALIGN_LEFT      = 1
    NCALIGN_CENTER    = 2
    NCALIGN_RIGHT     = 3

    # --- NcScale (ncscale_e) ---
    NCSCALE_NONE        = 0
    NCSCALE_SCALE       = 1
    NCSCALE_STRETCH     = 2
    NCSCALE_NONE_HIRES  = 3
    NCSCALE_SCALE_HIRES = 4

    # --- NcLogLevel (ncloglevel_e) ---
    NCLOGLEVEL_SILENT  = -1
    NCLOGLEVEL_PANIC   = 0
    NCLOGLEVEL_FATAL   = 1
    NCLOGLEVEL_ERROR   = 2
    NCLOGLEVEL_WARNING = 3
    NCLOGLEVEL_INFO    = 4
    NCLOGLEVEL_VERBOSE = 5
    NCLOGLEVEL_DEBUG   = 6
    NCLOGLEVEL_TRACE   = 7

    # --- NcInType (ncintype_e) ---
    NCTYPE_UNKNOWN = 0
    NCTYPE_PRESS   = 1
    NCTYPE_REPEAT  = 2
    NCTYPE_RELEASE = 3

    # --- NcPixelImpl (ncpixelimpl_e) ---
    NCPIXEL_NONE           = 0
    NCPIXEL_SIXEL          = 1
    NCPIXEL_LINUXFB        = 2
    NCPIXEL_ITERM2         = 3
    NCPIXEL_KITTY_STATIC   = 4
    NCPIXEL_KITTY_ANIMATED = 5
    NCPIXEL_KITTY_SELFREF  = 6
  end
end
