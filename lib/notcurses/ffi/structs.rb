# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  module FFI
    # Nomi delle classi: nome C in CamelCase, prefisso "nc" -> "Nc"
    # (nccell -> NcCell, ncplane_options -> NcPlaneOptions).
    # I campi hanno gli stessi nomi e lo stesso ordine del C.
    # I campi "const char*" sono :pointer: FFI non permette di scrivere
    # campi :string (usare ::FFI::MemoryPointer.from_string e tenerne il riferimento).
    # Nessuna struct pubblica contiene union.

    # C: struct timespec { time_t tv_sec; long tv_nsec; };  (libc, <time.h>)
    class Timespec < ::FFI::Struct
      layout :tv_sec,  :time_t,
             :tv_nsec, :long
    end

    # C: typedef struct nccell { ... } nccell;  (16 byte)
    class NcCell < ::FFI::Struct
      layout :gcluster,          :uint32, # EGC little-endian, o 0x01XXXXXX = indice egcpool
             :gcluster_backstop, :uint8,  # sempre 0
             :width,             :uint8,  # colonne dell'EGC
             :stylemask,         :uint16, # NCSTYLE_*
             :channels,          :uint64  # coppia di canali fg/bg
    end

    # C: typedef struct notcurses_options { ... } notcurses_options;
    class NotcursesOptions < ::FFI::Struct
      layout :termtype, :pointer, # const char*
             :loglevel, :ncloglevel_e,
             :margin_t, :uint,
             :margin_r, :uint,
             :margin_b, :uint,
             :margin_l, :uint,
             :flags,    :uint64   # NCOPTION_*
    end

    # C: typedef struct ncinput { ... } ncinput;
    class NcInput < ::FFI::Struct
      layout :id,        :uint32,     # codepoint Unicode o NCKEY_*
             :y,         :int,
             :x,         :int,
             :utf8,      [:char, 5],
             :alt,       :bool,       # DEPRECATED, rimosso in 4.0
             :shift,     :bool,       # DEPRECATED, rimosso in 4.0
             :ctrl,      :bool,       # DEPRECATED, rimosso in 4.0
             :evtype,    :ncintype_e,
             :modifiers, :uint,       # NCKEY_MOD_*
             :ypx,       :int,
             :xpx,       :int,
             :eff_text,  [:uint32, NCINPUT_MAX_EFF_TEXT_CODEPOINTS]
    end

    # C: typedef struct ncplane_options { ... } ncplane_options;
    class NcPlaneOptions < ::FFI::Struct
      layout :y,        :int,
             :x,        :int,
             :rows,     :uint,
             :cols,     :uint,
             :userptr,  :pointer, # void*
             :name,     :pointer, # const char*
             # callback: int (*resizecb)(struct ncplane*)
             :resizecb, :pointer,
             :flags,    :uint64,  # NCPLANE_OPTION_*
             :margin_b, :uint,
             :margin_r, :uint
    end

    # C: typedef struct ncpalette { uint32_t chans[NCPALETTESIZE]; } ncpalette;
    class NcPalette < ::FFI::Struct
      layout :chans, [:uint32, NCPALETTESIZE]
    end

    # C: typedef struct nccapabilities { ... } nccapabilities;
    class NcCapabilities < ::FFI::Struct
      layout :colors,            :uint,
             :utf8,              :bool,
             :rgb,               :bool,
             :can_change_colors, :bool,
             :halfblocks,        :bool,
             :quadrants,         :bool,
             :sextants,          :bool,
             :octants,           :bool,
             :braille,           :bool
    end

    # C: typedef struct ncstats { ... } ncstats;
    # Allocare con notcurses_stats_alloc(): versioni future possono allargarla.
    class NcStats < ::FFI::Struct
      layout :renders,           :uint64,
             :writeouts,         :uint64,
             :failed_renders,    :uint64,
             :failed_writeouts,  :uint64,
             :raster_bytes,      :uint64,
             :raster_max_bytes,  :int64,
             :raster_min_bytes,  :int64,
             :render_ns,         :uint64,
             :render_max_ns,     :int64,
             :render_min_ns,     :int64,
             :raster_ns,         :uint64,
             :raster_max_ns,     :int64,
             :raster_min_ns,     :int64,
             :writeout_ns,       :uint64,
             :writeout_max_ns,   :int64,
             :writeout_min_ns,   :int64,
             :cellelisions,      :uint64,
             :cellemissions,     :uint64,
             :fgelisions,        :uint64,
             :fgemissions,       :uint64,
             :bgelisions,        :uint64,
             :bgemissions,       :uint64,
             :defaultelisions,   :uint64,
             :defaultemissions,  :uint64,
             :refreshes,         :uint64,
             :sprixelemissions,  :uint64,
             :sprixelelisions,   :uint64,
             :sprixelbytes,      :uint64,
             :appsync_updates,   :uint64,
             :input_errors,      :uint64,
             :input_events,      :uint64,
             :hpa_gratuitous,    :uint64,
             :cell_geo_changes,  :uint64,
             :pixel_geo_changes, :uint64,
             :fbbytes,           :uint64,
             :planes,            :uint
    end

    # C: struct ncvisual_options { ... };
    class NcVisualOptions < ::FFI::Struct
      layout :n,          :pointer, # struct ncplane*
             :scaling,    :ncscale_e,
             :y,          :int,
             :x,          :int,
             :begy,       :uint,
             :begx,       :uint,
             :leny,       :uint,
             :lenx,       :uint,
             :blitter,    :ncblitter_e,
             :flags,      :uint64,  # NCVISUAL_OPTION_*
             :transcolor, :uint32,
             :pxoffy,     :uint,
             :pxoffx,     :uint
    end

    # C: typedef struct ncvgeom { ... } ncvgeom;
    class NcVgeom < ::FFI::Struct
      layout :pixy,      :uint,
             :pixx,      :uint,
             :cdimy,     :uint,
             :cdimx,     :uint,
             :rpixy,     :uint,
             :rpixx,     :uint,
             :rcelly,    :uint,
             :rcellx,    :uint,
             :scaley,    :uint,
             :scalex,    :uint,
             :begy,      :uint,
             :begx,      :uint,
             :leny,      :uint,
             :lenx,      :uint,
             :maxpixely, :uint,
             :maxpixelx, :uint,
             :blitter,   :ncblitter_e
    end

    # C: typedef struct ncreel_options { ... } ncreel_options;
    class NcReelOptions < ::FFI::Struct
      layout :bordermask,  :uint,
             :borderchan,  :uint64,
             :tabletmask,  :uint,
             :tabletchan,  :uint64,
             :focusedchan, :uint64,
             :flags,       :uint64 # NCREEL_OPTION_*
    end

    # C: struct ncselector_item { const char* option; const char* desc; };
    class NcSelectorItem < ::FFI::Struct
      layout :option, :pointer, # const char*
             :desc,   :pointer  # const char*
    end

    # C: typedef struct ncselector_options { ... } ncselector_options;
    class NcSelectorOptions < ::FFI::Struct
      layout :title,         :pointer, # const char*
             :secondary,     :pointer, # const char*
             :footer,        :pointer, # const char*
             :items,         :pointer, # const struct ncselector_item* (vettore)
             :defidx,        :uint,
             :maxdisplay,    :uint,
             :opchannels,    :uint64,
             :descchannels,  :uint64,
             :titlechannels, :uint64,
             :footchannels,  :uint64,
             :boxchannels,   :uint64,
             :flags,         :uint64
    end

    # C: struct ncmselector_item { const char* option; const char* desc; bool selected; };
    class NcMselectorItem < ::FFI::Struct
      layout :option,   :pointer, # const char*
             :desc,     :pointer, # const char*
             :selected, :bool
    end

    # C: typedef struct ncmultiselector_options { ... } ncmultiselector_options;
    class NcMultiselectorOptions < ::FFI::Struct
      layout :title,         :pointer, # const char*
             :secondary,     :pointer, # const char*
             :footer,        :pointer, # const char*
             :items,         :pointer, # const struct ncmselector_item* (vettore)
             :maxdisplay,    :uint,
             :opchannels,    :uint64,
             :descchannels,  :uint64,
             :titlechannels, :uint64,
             :footchannels,  :uint64,
             :boxchannels,   :uint64,
             :flags,         :uint64
    end

    # C: struct nctree_item { void* curry; struct nctree_item* subs; unsigned subcount; };
    class NcTreeItem < ::FFI::Struct
      layout :curry,    :pointer,
             :subs,     :pointer, # struct nctree_item* (vettore di subcount elementi)
             :subcount, :uint
    end

    # C: typedef struct nctree_options { ... } nctree_options;
    class NcTreeOptions < ::FFI::Struct
      layout :items,      :pointer, # const struct nctree_item* (vettore di count elementi)
             :count,      :uint,
             # callback: int (*nctreecb)(struct ncplane*, void*, int)
             :nctreecb,   :pointer,
             :indentcols, :int,
             :flags,      :uint64
    end

    # C: struct ncmenu_item { const char* desc; ncinput shortcut; };
    class NcMenuItem < ::FFI::Struct
      layout :desc,     :pointer, # const char*, NULL = separatore orizzontale
             :shortcut, NcInput   # struct annidata per valore
    end

    # C: struct ncmenu_section { const char* name; int itemcount;
    #                            struct ncmenu_item* items; ncinput shortcut; };
    class NcMenuSection < ::FFI::Struct
      layout :name,      :pointer, # const char*
             :itemcount, :int,
             :items,     :pointer, # struct ncmenu_item* (vettore di itemcount elementi)
             :shortcut,  NcInput   # struct annidata per valore
    end

    # C: typedef struct ncmenu_options { ... } ncmenu_options;
    class NcMenuOptions < ::FFI::Struct
      layout :sections,        :pointer, # struct ncmenu_section* (vettore di sectioncount elementi)
             :sectioncount,    :int,
             :headerchannels,  :uint64,
             :sectionchannels, :uint64,
             :flags,           :uint64 # NCMENU_OPTION_*
    end

    # C: typedef struct ncprogbar_options { ... } ncprogbar_options;
    class NcProgbarOptions < ::FFI::Struct
      layout :ulchannel, :uint32,
             :urchannel, :uint32,
             :blchannel, :uint32,
             :brchannel, :uint32,
             :flags,     :uint64 # NCPROGBAR_OPTION_*
    end

    # C: typedef struct nctabbed_options { ... } nctabbed_options;
    class NcTabbedOptions < ::FFI::Struct
      layout :selchan,   :uint64,
             :hdrchan,   :uint64,
             :sepchan,   :uint64,
             :separator, :pointer, # const char* (copiata da nctabbed_create)
             :flags,     :uint64   # NCTABBED_OPTION_*
    end

    # C: typedef struct ncplot_options { ... } ncplot_options;
    class NcPlotOptions < ::FFI::Struct
      layout :maxchannels, :uint64,
             :minchannels, :uint64,
             :legendstyle, :uint16,
             :gridtype,    :ncblitter_e,
             :rangex,      :int,
             :title,       :pointer, # const char*
             :flags,       :uint64   # NCPLOT_OPTION_*
    end

    # C: typedef struct ncfdplane_options { void* curry; bool follow; uint64_t flags; } ncfdplane_options;
    class NcFdplaneOptions < ::FFI::Struct
      layout :curry,  :pointer,
             :follow, :bool,
             :flags,  :uint64
    end

    # C: typedef struct ncsubproc_options { ... } ncsubproc_options;
    class NcSubprocOptions < ::FFI::Struct
      layout :curry,          :pointer,
             :restart_period, :uint64,
             :flags,          :uint64
    end

    # C: typedef struct ncreader_options { ... } ncreader_options;
    class NcReaderOptions < ::FFI::Struct
      layout :tchannels, :uint64,
             :tattrword, :uint32,
             :flags,     :uint64 # NCREADER_OPTION_*
    end
  end
end
