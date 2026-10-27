# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

# Altre fonti: direct.h, nckeys.h, ncseqs.h e version.h
# (/usr/include/notcurses/version.h: CMake lo genera, non è nel repo).
# Le macro funzione (NCCHANNEL_INITIALIZER, preterunicode, ...) sono
# metodi in inline_reimpl.rb.

module Notcurses
  module FFI
    # ═══════════════════════════════════════
    # version.h
    # ═══════════════════════════════════════
    NOTCURSES_VERNUM_MAJOR = 3
    NOTCURSES_VERNUM_MINOR = 0
    NOTCURSES_VERNUM_PATCH = 17
    # NOTCURSES_VERNUM_TWEAK: macro vuota in version.h 3.0.17, non mappata.
    # NOTCURSES_VERSION_COMPARABLE(major, minor, patch)
    NOTCURSES_VERNUM_ORDERED = (NOTCURSES_VERNUM_MAJOR << 16) +
                               (NOTCURSES_VERNUM_MINOR << 8) +
                               NOTCURSES_VERNUM_PATCH
    NOTCURSES_VERSION_MAJOR = '3'
    NOTCURSES_VERSION_MINOR = '0'
    NOTCURSES_VERSION_PATCH = '17'
    NOTCURSES_VERSION_TWEAK = ''

    # ═══════════════════════════════════════
    # notcurses.h
    # ═══════════════════════════════════════

    # --- Alpha (NCALPHA_*) ---
    # background cannot be highcontrast, only foreground
    NCALPHA_HIGHCONTRAST = 0x30000000
    NCALPHA_TRANSPARENT  = 0x20000000
    NCALPHA_BLEND        = 0x10000000
    NCALPHA_OPAQUE       = 0x00000000

    # --- Palette ---
    # we support palette-indexed color up to 8 bits.
    NCPALETTESIZE = 256

    # --- Channel masks ---
    NC_NOBACKGROUND_MASK = 0x8700000000000000
    NC_BGDEFAULT_MASK    = 0x0000000040000000 # set: *not* using the default background
    NC_BG_RGB_MASK       = 0x0000000000ffffff
    NC_BG_PALETTE        = 0x0000000008000000 # with NC_BGDEFAULT_MASK: palette-indexed
    NC_BG_ALPHA_MASK     = 0x30000000

    # --- UTF-8 ---
    # 0x0--0x10ffff can be UTF-8-encoded with only 4 bytes
    WCHAR_MAX_UTF8BYTES = 4

    # --- Styles (NCSTYLE_*) ---
    NCSTYLE_MASK      = 0xffff
    NCSTYLE_ITALIC    = 0x0010
    NCSTYLE_UNDERLINE = 0x0008
    NCSTYLE_UNDERCURL = 0x0004
    NCSTYLE_BOLD      = 0x0002
    NCSTYLE_STRUCK    = 0x0001
    NCSTYLE_NONE      = 0

    # --- Option flags (notcurses_options.flags) ---
    NCOPTION_INHIBIT_SETLOCALE   = 0x0001
    NCOPTION_NO_CLEAR_BITMAPS    = 0x0002
    NCOPTION_NO_WINCH_SIGHANDLER = 0x0004
    NCOPTION_NO_QUIT_SIGHANDLERS = 0x0008
    NCOPTION_PRESERVE_CURSOR     = 0x0010
    NCOPTION_SUPPRESS_BANNERS    = 0x0020
    NCOPTION_NO_ALTERNATE_SCREEN = 0x0040
    NCOPTION_NO_FONT_CHANGES     = 0x0080
    NCOPTION_DRAIN_INPUT         = 0x0100
    NCOPTION_SCROLLING           = 0x0200
    # "CLI mode" is just setting these four options.
    NCOPTION_CLI_MODE = NCOPTION_NO_ALTERNATE_SCREEN |
                        NCOPTION_NO_CLEAR_BITMAPS |
                        NCOPTION_PRESERVE_CURSOR |
                        NCOPTION_SCROLLING

    # --- Input ---
    NCINPUT_MAX_EFF_TEXT_CODEPOINTS = 4

    # --- Mice (notcurses_mice_enable eventmask) ---
    NCMICE_NO_EVENTS    = 0
    NCMICE_MOVE_EVENT   = 0x1
    NCMICE_BUTTON_EVENT = 0x2
    NCMICE_DRAG_EVENT   = 0x4
    NCMICE_ALL_EVENTS   = 0x7

    # --- Plane options (ncplane_options.flags) ---
    NCPLANE_OPTION_HORALIGNED   = 0x0001
    NCPLANE_OPTION_VERALIGNED   = 0x0002
    NCPLANE_OPTION_MARGINALIZED = 0x0004
    NCPLANE_OPTION_FIXED        = 0x0008
    NCPLANE_OPTION_AUTOGROW     = 0x0010
    NCPLANE_OPTION_VSCROLL      = 0x0020

    # --- Alignment aliases (ncalign_e) ---
    NCALIGN_TOP    = NCALIGN_LEFT
    NCALIGN_BOTTOM = NCALIGN_RIGHT

    # --- Box (ncplane_box ctlword) ---
    NCBOXMASK_TOP     = 0x0001
    NCBOXMASK_RIGHT   = 0x0002
    NCBOXMASK_BOTTOM  = 0x0004
    NCBOXMASK_LEFT    = 0x0008
    NCBOXGRAD_TOP     = 0x0010
    NCBOXGRAD_RIGHT   = 0x0020
    NCBOXGRAD_BOTTOM  = 0x0040
    NCBOXGRAD_LEFT    = 0x0080
    NCBOXCORNER_MASK  = 0x0300
    NCBOXCORNER_SHIFT = 8

    # --- Visual options (ncvisual_options.flags) ---
    NCVISUAL_OPTION_NODEGRADE     = 0x0001 # fail rather than degrade
    NCVISUAL_OPTION_BLEND         = 0x0002 # use NCALPHA_BLEND with visual
    NCVISUAL_OPTION_HORALIGNED    = 0x0004 # x is an alignment, not absolute
    NCVISUAL_OPTION_VERALIGNED    = 0x0008 # y is an alignment, not absolute
    NCVISUAL_OPTION_ADDALPHA      = 0x0010 # transcolor is in effect
    NCVISUAL_OPTION_CHILDPLANE    = 0x0020 # interpret n as parent
    NCVISUAL_OPTION_NOINTERPOLATE = 0x0040 # non-interpolative scaling

    # --- Reel options (ncreel_options.flags) ---
    NCREEL_OPTION_INFINITESCROLL = 0x0001
    NCREEL_OPTION_CIRCULAR       = 0x0002

    # --- Metric (ncnmetric) ---
    NCPREFIXCOLUMNS  = 7
    NCIPREFIXCOLUMNS = 8
    NCBPREFIXCOLUMNS = 9
    NCPREFIXSTRLEN   = NCPREFIXCOLUMNS + 1  # Does not include a '\0' (xxx.xxU)
    NCIPREFIXSTRLEN  = NCIPREFIXCOLUMNS + 1 # Does not include a '\0' (xxxx.xxU)
    NCBPREFIXSTRLEN  = NCBPREFIXCOLUMNS + 1 # Does not include a '\0' (xxxx.xxUi), i == prefix

    # --- Menu options (ncmenu_options.flags) ---
    NCMENU_OPTION_BOTTOM = 0x0001 # bottom row (as opposed to top row)
    NCMENU_OPTION_HIDING = 0x0002 # hide the menu when not unrolled

    # --- Progbar options (ncprogbar_options.flags) ---
    NCPROGBAR_OPTION_RETROGRADE = 0x0001 # proceed left/down

    # --- Tabbed options (nctabbed_options.flags) ---
    NCTABBED_OPTION_BOTTOM = 0x0001

    # --- Plot options (ncplot_options.flags) ---
    NCPLOT_OPTION_LABELTICKSD   = 0x0001 # show labels for dependent axis
    NCPLOT_OPTION_EXPONENTIALD  = 0x0002 # exponential dependent axis
    NCPLOT_OPTION_VERTICALI     = 0x0004 # independent axis is vertical
    NCPLOT_OPTION_NODEGRADE     = 0x0008 # fail rather than degrade blitter
    NCPLOT_OPTION_DETECTMAXONLY = 0x0010 # use domain detection only for max
    NCPLOT_OPTION_PRINTSAMPLE   = 0x0020 # print the most recent sample

    # --- Reader options (ncreader_options.flags) ---
    NCREADER_OPTION_HORSCROLL = 0x0001
    NCREADER_OPTION_VERSCROLL = 0x0002
    NCREADER_OPTION_NOCMDKEYS = 0x0004
    NCREADER_OPTION_CURSOR    = 0x0008

    # ═══════════════════════════════════════
    # direct.h
    # ═══════════════════════════════════════
    NCDIRECT_OPTION_INHIBIT_SETLOCALE   = 0x0001
    NCDIRECT_OPTION_INHIBIT_CBREAK      = 0x0002
    NCDIRECT_OPTION_DRAIN_INPUT         = 0x0004
    NCDIRECT_OPTION_NO_QUIT_SIGHANDLERS = 0x0008
    NCDIRECT_OPTION_VERBOSE             = 0x0010
    NCDIRECT_OPTION_VERY_VERBOSE        = 0x0020

    # ═══════════════════════════════════════
    # nckeys.h
    # ═══════════════════════════════════════
    # Synthesized input events: area oltre i 17 piani Unicode (1114112).
    PRETERUNICODEBASE = 1115000
    # NCKEY_X = preterunicode(n) = PRETERUNICODEBASE + n
    NCKEY_INVALID      = PRETERUNICODEBASE + 0
    NCKEY_RESIZE       = PRETERUNICODEBASE + 1 # we received SIGWINCH
    NCKEY_UP           = PRETERUNICODEBASE + 2
    NCKEY_RIGHT        = PRETERUNICODEBASE + 3
    NCKEY_DOWN         = PRETERUNICODEBASE + 4
    NCKEY_LEFT         = PRETERUNICODEBASE + 5
    NCKEY_INS          = PRETERUNICODEBASE + 6
    NCKEY_DEL          = PRETERUNICODEBASE + 7
    NCKEY_BACKSPACE    = PRETERUNICODEBASE + 8 # backspace (sometimes)
    NCKEY_PGDOWN       = PRETERUNICODEBASE + 9
    NCKEY_PGUP         = PRETERUNICODEBASE + 10
    NCKEY_HOME         = PRETERUNICODEBASE + 11
    NCKEY_END          = PRETERUNICODEBASE + 12
    NCKEY_F00          = PRETERUNICODEBASE + 20
    NCKEY_F01          = PRETERUNICODEBASE + 21
    NCKEY_F02          = PRETERUNICODEBASE + 22
    NCKEY_F03          = PRETERUNICODEBASE + 23
    NCKEY_F04          = PRETERUNICODEBASE + 24
    NCKEY_F05          = PRETERUNICODEBASE + 25
    NCKEY_F06          = PRETERUNICODEBASE + 26
    NCKEY_F07          = PRETERUNICODEBASE + 27
    NCKEY_F08          = PRETERUNICODEBASE + 28
    NCKEY_F09          = PRETERUNICODEBASE + 29
    NCKEY_F10          = PRETERUNICODEBASE + 30
    NCKEY_F11          = PRETERUNICODEBASE + 31
    NCKEY_F12          = PRETERUNICODEBASE + 32
    NCKEY_F13          = PRETERUNICODEBASE + 33
    NCKEY_F14          = PRETERUNICODEBASE + 34
    NCKEY_F15          = PRETERUNICODEBASE + 35
    NCKEY_F16          = PRETERUNICODEBASE + 36
    NCKEY_F17          = PRETERUNICODEBASE + 37
    NCKEY_F18          = PRETERUNICODEBASE + 38
    NCKEY_F19          = PRETERUNICODEBASE + 39
    NCKEY_F20          = PRETERUNICODEBASE + 40
    NCKEY_F21          = PRETERUNICODEBASE + 41
    NCKEY_F22          = PRETERUNICODEBASE + 42
    NCKEY_F23          = PRETERUNICODEBASE + 43
    NCKEY_F24          = PRETERUNICODEBASE + 44
    NCKEY_F25          = PRETERUNICODEBASE + 45
    NCKEY_F26          = PRETERUNICODEBASE + 46
    NCKEY_F27          = PRETERUNICODEBASE + 47
    NCKEY_F28          = PRETERUNICODEBASE + 48
    NCKEY_F29          = PRETERUNICODEBASE + 49
    NCKEY_F30          = PRETERUNICODEBASE + 50
    NCKEY_F31          = PRETERUNICODEBASE + 51
    NCKEY_F32          = PRETERUNICODEBASE + 52
    NCKEY_F33          = PRETERUNICODEBASE + 53
    NCKEY_F34          = PRETERUNICODEBASE + 54
    NCKEY_F35          = PRETERUNICODEBASE + 55
    NCKEY_F36          = PRETERUNICODEBASE + 56
    NCKEY_F37          = PRETERUNICODEBASE + 57
    NCKEY_F38          = PRETERUNICODEBASE + 58
    NCKEY_F39          = PRETERUNICODEBASE + 59
    NCKEY_F40          = PRETERUNICODEBASE + 60
    NCKEY_F41          = PRETERUNICODEBASE + 61
    NCKEY_F42          = PRETERUNICODEBASE + 62
    NCKEY_F43          = PRETERUNICODEBASE + 63
    NCKEY_F44          = PRETERUNICODEBASE + 64
    NCKEY_F45          = PRETERUNICODEBASE + 65
    NCKEY_F46          = PRETERUNICODEBASE + 66
    NCKEY_F47          = PRETERUNICODEBASE + 67
    NCKEY_F48          = PRETERUNICODEBASE + 68
    NCKEY_F49          = PRETERUNICODEBASE + 69
    NCKEY_F50          = PRETERUNICODEBASE + 70
    NCKEY_F51          = PRETERUNICODEBASE + 71
    NCKEY_F52          = PRETERUNICODEBASE + 72
    NCKEY_F53          = PRETERUNICODEBASE + 73
    NCKEY_F54          = PRETERUNICODEBASE + 74
    NCKEY_F55          = PRETERUNICODEBASE + 75
    NCKEY_F56          = PRETERUNICODEBASE + 76
    NCKEY_F57          = PRETERUNICODEBASE + 77
    NCKEY_F58          = PRETERUNICODEBASE + 78
    NCKEY_F59          = PRETERUNICODEBASE + 79
    NCKEY_F60          = PRETERUNICODEBASE + 80
    # ... leave room for up to 100 function keys, egads
    NCKEY_ENTER        = PRETERUNICODEBASE + 121
    NCKEY_CLS          = PRETERUNICODEBASE + 122 # "clear-screen or erase"
    NCKEY_DLEFT        = PRETERUNICODEBASE + 123 # down + left on keypad
    NCKEY_DRIGHT       = PRETERUNICODEBASE + 124
    NCKEY_ULEFT        = PRETERUNICODEBASE + 125 # up + left on keypad
    NCKEY_URIGHT       = PRETERUNICODEBASE + 126
    NCKEY_CENTER       = PRETERUNICODEBASE + 127 # the most truly neutral of keypresses
    NCKEY_BEGIN        = PRETERUNICODEBASE + 128
    NCKEY_CANCEL       = PRETERUNICODEBASE + 129
    NCKEY_CLOSE        = PRETERUNICODEBASE + 130
    NCKEY_COMMAND      = PRETERUNICODEBASE + 131
    NCKEY_COPY         = PRETERUNICODEBASE + 132
    NCKEY_EXIT         = PRETERUNICODEBASE + 133
    NCKEY_PRINT        = PRETERUNICODEBASE + 134
    NCKEY_REFRESH      = PRETERUNICODEBASE + 135
    NCKEY_SEPARATOR    = PRETERUNICODEBASE + 136
    # these keys aren't generally available outside of the kitty protocol
    NCKEY_CAPS_LOCK    = PRETERUNICODEBASE + 150
    NCKEY_SCROLL_LOCK  = PRETERUNICODEBASE + 151
    NCKEY_NUM_LOCK     = PRETERUNICODEBASE + 152
    NCKEY_PRINT_SCREEN = PRETERUNICODEBASE + 153
    NCKEY_PAUSE        = PRETERUNICODEBASE + 154
    NCKEY_MENU         = PRETERUNICODEBASE + 155
    # media keys, similarly only available through kitty's protocol
    NCKEY_MEDIA_PLAY   = PRETERUNICODEBASE + 158
    NCKEY_MEDIA_PAUSE  = PRETERUNICODEBASE + 159
    NCKEY_MEDIA_PPAUSE = PRETERUNICODEBASE + 160
    NCKEY_MEDIA_REV    = PRETERUNICODEBASE + 161
    NCKEY_MEDIA_STOP   = PRETERUNICODEBASE + 162
    NCKEY_MEDIA_FF     = PRETERUNICODEBASE + 163
    NCKEY_MEDIA_REWIND = PRETERUNICODEBASE + 164
    NCKEY_MEDIA_NEXT   = PRETERUNICODEBASE + 165
    NCKEY_MEDIA_PREV   = PRETERUNICODEBASE + 166
    NCKEY_MEDIA_RECORD = PRETERUNICODEBASE + 167
    NCKEY_MEDIA_LVOL   = PRETERUNICODEBASE + 168
    NCKEY_MEDIA_RVOL   = PRETERUNICODEBASE + 169
    NCKEY_MEDIA_MUTE   = PRETERUNICODEBASE + 170
    # modifiers when pressed by themselves. this ordering comes from the Kitty
    # keyboard protocol, and mustn't be changed without updating handlers.
    NCKEY_LSHIFT       = PRETERUNICODEBASE + 171
    NCKEY_LCTRL        = PRETERUNICODEBASE + 172
    NCKEY_LALT         = PRETERUNICODEBASE + 173
    NCKEY_LSUPER       = PRETERUNICODEBASE + 174
    NCKEY_LHYPER       = PRETERUNICODEBASE + 175
    NCKEY_LMETA        = PRETERUNICODEBASE + 176
    NCKEY_RSHIFT       = PRETERUNICODEBASE + 177
    NCKEY_RCTRL        = PRETERUNICODEBASE + 178
    NCKEY_RALT         = PRETERUNICODEBASE + 179
    NCKEY_RSUPER       = PRETERUNICODEBASE + 180
    NCKEY_RHYPER       = PRETERUNICODEBASE + 181
    NCKEY_RMETA        = PRETERUNICODEBASE + 182
    NCKEY_L3SHIFT      = PRETERUNICODEBASE + 183
    NCKEY_L5SHIFT      = PRETERUNICODEBASE + 184
    # mouse events. We encode which button was pressed into the char32_t,
    # but position information is embedded in the larger ncinput event.
    NCKEY_MOTION       = PRETERUNICODEBASE + 200 # no buttons pressed
    NCKEY_BUTTON1      = PRETERUNICODEBASE + 201
    NCKEY_BUTTON2      = PRETERUNICODEBASE + 202
    NCKEY_BUTTON3      = PRETERUNICODEBASE + 203
    NCKEY_BUTTON4      = PRETERUNICODEBASE + 204 # scrollwheel up
    NCKEY_BUTTON5      = PRETERUNICODEBASE + 205 # scrollwheel down
    NCKEY_BUTTON6      = PRETERUNICODEBASE + 206
    NCKEY_BUTTON7      = PRETERUNICODEBASE + 207
    NCKEY_BUTTON8      = PRETERUNICODEBASE + 208
    NCKEY_BUTTON9      = PRETERUNICODEBASE + 209
    NCKEY_BUTTON10     = PRETERUNICODEBASE + 210
    NCKEY_BUTTON11     = PRETERUNICODEBASE + 211
    # we received SIGCONT
    NCKEY_SIGNAL       = PRETERUNICODEBASE + 400
    # indicates that we have reached the end of input. any further calls
    # will continute to return this immediately.
    NCKEY_EOF          = PRETERUNICODEBASE + 500
    # Synonyms and aliases (so far as we're concerned)
    NCKEY_SCROLL_UP    = NCKEY_BUTTON4
    NCKEY_SCROLL_DOWN  = NCKEY_BUTTON5
    NCKEY_RETURN       = NCKEY_ENTER
    NCKEY_TAB          = 0x09
    NCKEY_ESC          = 0x1b
    NCKEY_SPACE        = 0x20
    # used with the modifiers bitmask. definitions come straight from the kitty
    # keyboard protocol.
    NCKEY_MOD_SHIFT    = 1
    NCKEY_MOD_ALT      = 2
    NCKEY_MOD_CTRL     = 4
    NCKEY_MOD_SUPER    = 8
    NCKEY_MOD_HYPER    = 16
    NCKEY_MOD_META     = 32
    NCKEY_MOD_CAPSLOCK = 64
    NCKEY_MOD_NUMLOCK  = 128

    # ═══════════════════════════════════════
    # ncseqs.h
    # ═══════════════════════════════════════
    # Le varianti W (L"..." in C, wchar_t*) sono qui stringhe UTF-8: per le
    # API wchar_t* convertirle in un vettore :wchar_t terminato da 0.
    # unicode box-drawing characters
    NCBOXLIGHTW = "┌┐└┘─│"
    NCBOXHEAVYW = "┏┓┗┛━┃"
    NCBOXROUNDW = "╭╮╰╯─│"
    NCBOXDOUBLEW = "╔╗╚╝═║"
    NCBOXASCIIW = "/\\\\/-|"
    NCBOXOUTERW = "🭽🭾🭼🭿▁🭵🭶🭰"

    # 4-cycles around an interior core
    NCWHITESQUARESW = "◲◱◳◰"
    NCWHITECIRCLESW = "◶◵◷◴"
    NCCIRCULARARCSW = "◜◝◟◞"
    NCWHITETRIANGLESW = "◿◺◹◸"
    NCBLACKTRIANGLESW = "◢◣◥◤"
    NCSHADETRIANGLESW = "🮞🮟🮝🮜"

    # 4-cycles around an exterior core
    NCBLACKARROWHEADSW = "⮝⮟⮜⮞"
    NCLIGHTARROWHEADSW = "⮙⮛⮘⮚"
    NCARROWDOUBLEW = "⮅⮇⮄⮆"
    NCARROWDASHEDW = "⭫⭭⭪⭬"
    NCARROWCIRCLEDW = "⮉⮋⮈⮊"
    NCARROWANTICLOCKW = "⮏⮍⮎⮌"
    NCBOXDRAWW = "╵╷╴╶"
    NCBOXDRAWHEAVYW = "╹╻╸╺"

    # 8-cycles around an exterior core
    NCARROWW = "⭡⭣⭠⭢⭧⭩⭦⭨"
    NCDIAGONALSW = "🮣🮠🮡🮢🮤🮥🮦🮧"

    # superscript and subscript digits
    NCDIGITSSUPERW = "⁰¹²³⁴⁵⁶⁷⁸⁹"
    NCDIGITSSUBW = "₀₁₂₃₄₅₆₇₈₉"

    # unicode fucking loves asterisks
    NCASTERISKS5 = "🞯🞰🞱🞲🞳🞴"
    NCASTERISKS6 = "🞵🞶🞷🞸🞹🞺"
    NCASTERISKS8 = "🞻🞼✳🞽🞾🞿"

    # symbols for legacy computing
    NCANGLESBR = "🭁🭂🭃🭄🭅🭆🭇🭈🭉🭊🭋"
    NCANGLESTR = "🭒🭓🭔🭕🭖🭧🭢🭣🭤🭥🭦"
    NCANGLESBL = "🭌🭍🭎🭏🭐🭑🬼🬽🬾🬿🭀"
    NCANGLESTL = "🭝🭞🭟🭠🭡🭜🭗🭘🭙🭚🭛"
    NCEIGHTHSB = " ▁▂▃▄▅▆▇█"
    NCEIGHTHST = " ▔🮂🮃▀🮄🮅🮆█"
    NCEIGHTHSL = "▏▎▍▌▋▊▉█"
    NCEIGHTHSR = "▕🮇🮈▐🮉🮊🮋█"
    NCHALFBLOCKS = " ▀▄█"
    NCQUADBLOCKS = " ▘▝▀▖▌▞▛▗▚▐▜▄▙▟█"
    NCSEXBLOCKS = " 🬀🬁🬂🬃🬄🬅🬆🬇🬈🬊🬋🬌🬍🬎🬏🬐🬑🬒🬓▌🬔🬕🬖🬗🬘🬙🬚🬛🬜🬝🬞🬟🬠🬡🬢🬣🬤🬥🬦🬧▐🬨🬩🬪🬫🬬🬭🬮🬯🬰🬱🬲🬳🬴🬵🬶🬷🬸🬹🬺🬻█"
    NCOCTBLOCKS = " \u{1CEA8}\u{1CEAB}\u{1FB82}\u{1CD00}\u{2598}\u{1CD01}\u{1CD02}" \
      "\u{1CD03}\u{1CD04}\u{259D}\u{1CD05}\u{1CD06}\u{1CD07}\u{1CD08}\u{2580}" \
      "\u{1CD09}\u{1CD0A}\u{1CD0B}\u{1CD0C}\u{1FBE6}\u{1CD0D}\u{1CD0E}\u{1CD0F}" \
      "\u{1CD10}\u{1CD11}\u{1CD12}\u{1CD13}\u{1CD14}\u{1CD15}\u{1CD16}\u{1CD17}" \
      "\u{1CD18}\u{1CD19}\u{1CD1A}\u{1CD1B}\u{1CD1C}\u{1CD1D}\u{1CD1E}\u{1CD1F}" \
      "\u{1FBE7}\u{1CD20}\u{1CD21}\u{1CD22}\u{1CD23}\u{1CD24}\u{1CD25}\u{1CD26}" \
      "\u{1CD27}\u{1CD28}\u{1CD29}\u{1CD2A}\u{1CD2B}\u{1CD2C}\u{1CD2D}\u{1CD2E}" \
      "\u{1CD2F}\u{1CD30}\u{1CD31}\u{1CD32}\u{1CD33}\u{1CD34}\u{1CD35}\u{1FB85}" \
      "\u{1CEA3}\u{1CD36}\u{1CD37}\u{1CD38}\u{1CD39}\u{1CD3A}\u{1CD3B}\u{1CD3C}" \
      "\u{1CD3D}\u{1CD3E}\u{1CD3F}\u{1CD40}\u{1CD41}\u{1CD42}\u{1CD43}\u{1CD44}" \
      "\u{2596}\u{1CD45}\u{1CD46}\u{1CD47}\u{1CD48}\u{258C}\u{1CD49}\u{1CD4A}" \
      "\u{1CD4B}\u{1CD4C}\u{259E}\u{1CD4D}\u{1CD4E}\u{1CD4F}\u{1CD50}\u{259B}" \
      "\u{1CD51}\u{1CD52}\u{1CD53}\u{1CD54}\u{1CD55}\u{1CD56}\u{1CD57}\u{1CD58}" \
      "\u{1CD59}\u{1CD5A}\u{1CD5B}\u{1CD5C}\u{1CD5D}\u{1CD5E}\u{1CD5F}\u{1CD60}" \
      "\u{1CD61}\u{1CD62}\u{1CD63}\u{1CD64}\u{1CD65}\u{1CD66}\u{1CD67}\u{1CD68}" \
      "\u{1CD69}\u{1CD6A}\u{1CD6B}\u{1CD6C}\u{1CD6D}\u{1CD6E}\u{1CD6F}\u{1CD70}" \
      "\u{1CEA0}\u{1CD71}\u{1CD72}\u{1CD73}\u{1CD74}\u{1CD75}\u{1CD76}\u{1CD77}" \
      "\u{1CD78}\u{1CD79}\u{1CD7A}\u{1CD7B}\u{1CD7C}\u{1CD7D}\u{1CD7E}\u{1CD7F}" \
      "\u{1CD80}\u{1CD81}\u{1CD82}\u{1CD83}\u{1CD84}\u{1CD85}\u{1CD86}\u{1CD87}" \
      "\u{1CD88}\u{1CD89}\u{1CD8A}\u{1CD8B}\u{1CD8C}\u{1CD8D}\u{1CD8E}\u{1CD8F}" \
      "\u{2597}\u{1CD90}\u{1CD91}\u{1CD92}\u{1CD93}\u{259A}\u{1CD94}\u{1CD95}" \
      "\u{1CD96}\u{1CD97}\u{2590}\u{1CD98}\u{1CD99}\u{1CD9A}\u{1CD9B}\u{259C}" \
      "\u{1CD9C}\u{1CD9D}\u{1CD9E}\u{1CD9F}\u{1CDA0}\u{1CDA1}\u{1CDA2}\u{1CDA3}" \
      "\u{1CDA4}\u{1CDA5}\u{1CDA6}\u{1CDA7}\u{1CDA8}\u{1CDA9}\u{1CDAA}\u{1CDAB}" \
      "\u{2582}\u{1CDAC}\u{1CDAD}\u{1CDAE}\u{1CDAF}\u{1CDB0}\u{1CDB1}\u{1CDB2}" \
      "\u{1CDB3}\u{1CDB4}\u{1CDB5}\u{1CDB6}\u{1CDB7}\u{1CDB8}\u{1CDB9}\u{1CDBA}" \
      "\u{1CDBB}\u{1CDBC}\u{1CDBD}\u{1CDBE}\u{1CDBF}\u{1CDC0}\u{1CDC1}\u{1CDC2}" \
      "\u{1CDC3}\u{1CDC4}\u{1CDC5}\u{1CDC6}\u{1CDC7}\u{1CDC8}\u{1CDC9}\u{1CDCA}" \
      "\u{1CDCB}\u{1CDCC}\u{1CDCD}\u{1CDCE}\u{1CDCF}\u{1CDD0}\u{1CDD1}\u{1CDD2}" \
      "\u{1CDD3}\u{1CDD4}\u{1CDD5}\u{1CDD6}\u{1CDD7}\u{1CDD8}\u{1CDD9}\u{1CDDA}" \
      "\u{2584}\u{1CDDB}\u{1CDDC}\u{1CDDD}\u{1CDDE}\u{2599}\u{1CDDF}\u{1CDE0}" \
      "\u{1CDE1}\u{1CDE2}\u{259F}\u{1CDE3}\u{2586}\u{1CDE4}\u{1CDE5}\u{2588}"
    NCBRAILLEEGCS = "\u2800\u2801\u2808\u2809\u2802\u2803\u280a\u280b\u2810\u2811\u2818\u2819\u2812\u2813\u281a\u281b" \
      "\u2804\u2805\u280c\u280d\u2806\u2807\u280e\u280f\u2814\u2815\u281c\u281d\u2816\u2817\u281e\u281f" \
      "\u2820\u2821\u2828\u2829\u2822\u2823\u282a\u282b\u2830\u2831\u2838\u2839\u2832\u2833\u283a\u283b" \
      "\u2824\u2825\u282c\u282d\u2826\u2827\u282e\u282f\u2834\u2835\u283c\u283d\u2836\u2837\u283e\u283f" \
      "\u2840\u2841\u2848\u2849\u2842\u2843\u284a\u284b\u2850\u2851\u2858\u2859\u2852\u2853\u285a\u285b" \
      "\u2844\u2845\u284c\u284d\u2846\u2847\u284e\u284f\u2854\u2855\u285c\u285d\u2856\u2857\u285e\u285f" \
      "\u2860\u2861\u2868\u2869\u2862\u2863\u286a\u286b\u2870\u2871\u2878\u2879\u2872\u2873\u287a\u287b" \
      "\u2864\u2865\u286c\u286d\u2866\u2867\u286e\u286f\u2874\u2875\u287c\u287d\u2876\u2877\u287e\u287f" \
      "\u2880\u2881\u2888\u2889\u2882\u2883\u288a\u288b\u2890\u2891\u2898\u2899\u2892\u2893\u289a\u289b" \
      "\u2884\u2885\u288c\u288d\u2886\u2887\u288e\u288f\u2894\u2895\u289c\u289d\u2896\u2897\u289e\u289f" \
      "\u28a0\u28a1\u28a8\u28a9\u28a2\u28a3\u28aa\u28ab\u28b0\u28b1\u28b8\u28b9\u28b2\u28b3\u28ba\u28bb" \
      "\u28a4\u28a5\u28ac\u28ad\u28a6\u28a7\u28ae\u28af\u28b4\u28b5\u28bc\u28bd\u28b6\u28b7\u28be\u28bf" \
      "\u28c0\u28c1\u28c8\u28c9\u28c2\u28c3\u28ca\u28cb\u28d0\u28d1\u28d8\u28d9\u28d2\u28d3\u28da\u28db" \
      "\u28c4\u28c5\u28cc\u28cd\u28c6\u28c7\u28ce\u28cf\u28d4\u28d5\u28dc\u28dd\u28d6\u28d7\u28de\u28df" \
      "\u28e0\u28e1\u28e8\u28e9\u28e2\u28e3\u28ea\u28eb\u28f0\u28f1\u28f8\u28f9\u28f2\u28f3\u28fa\u28fb" \
      "\u28e4\u28e5\u28ec\u28ed\u28e6\u28e7\u28ee\u28ef\u28f4\u28f5\u28fc\u28fd\u28f6\u28f7\u28fe\u28ff"
    NCSEGDIGITS = "\u{1FBF0}\u{1FBF1}\u{1FBF2}\u{1FBF3}\u{1FBF4}" \
      "\u{1FBF5}\u{1FBF6}\u{1FBF7}\u{1FBF8}\u{1FBF9}"
    NCSUITSBLACK = "\u2660\u2663\u2665\u2666" # ♠♣♥♦
    NCSUITSWHITE = "\u2661\u2662\u2664\u2667" # ♡♢♤♧
    NCCHESSBLACK = "\u265f\u265c\u265e\u265d\u265b\u265a" # ♟♜♞♝♛♚
    NCCHESSWHITE = "\u2659\u2656\u2658\u2657\u2655\u2654" # ♙♖♘♗♕♔
    NCDICE = "\u2680\u2681\u2682\u2683\u2684\u2685" # ⚀⚁⚂⚃⚄⚅
    NCMUSICSYM = "\u2669\u266A\u266B\u266C\u266D\u266E\u266F" # ♩♪♫♬♭♮♯

    # argh
    NCBOXLIGHT = "┌┐└┘─│"
    NCBOXHEAVY = "┏┓┗┛━┃"
    NCBOXROUND = "╭╮╰╯─│"
    NCBOXDOUBLE = "╔╗╚╝═║"
    NCBOXASCII = "/\\\\/-|"
    NCBOXOUTER = "🭽🭾🭼🭿▁🭵🭶🭰"

    # ═══════════════════════════════════════
    # libc <termios.h>
    # ═══════════════════════════════════════
    # IXON (c_iflag): 0x200 su macOS, BSD e Linux powerpc/alpha, 0o2000 sugli
    # altri Linux (asm-generic/termbits.h); nil dove non è noto (Windows non
    # ha termios). Provato solo su Linux x86_64.
    IXON = if ::FFI::Platform::IS_MAC || ::FFI::Platform::IS_BSD then 0x200
           elsif ::FFI::Platform::IS_LINUX then ::FFI::Platform::ARCH.match?(/\A(powerpc|alpha)/) ? 0x200 : 0o2000
           end
    TCSANOW = 0
  end
end
