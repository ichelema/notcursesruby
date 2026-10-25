# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

# Reimplementazioni Ruby delle funzioni static inline e delle macro funzione:
# non esistono nelle librerie condivise, quindi non si possono collegare con
# attach_function. Fonti: notcurses.h, direct.h, nckeys.h, ncport.h, version.h.
#
# Contratto: ogni metodo si comporta come un attach_function sulla stessa
# funzione C compilata (libnotcurses-ffi.so), con i tipi della tabella di
# mappatura: stessi parametri, stessi valori restituiti (interi nel range del
# tipo C, true/false per bool, ::FFI::Pointer::NULL per NULL), stesse
# scritture attraverso i puntatori. Il C originale precede ogni metodo.
# Fuori contratto: argomenti che FFI rifiuterebbe. Gli interi fuori dal range
# del tipo C vengono troncati con una maschera (nessun RangeError). Float o nil
# al posto di un intero, e un oggetto non String diverso da nil al posto di una
# :string, danno un'eccezione di classe diversa da quella di FFI (spesso
# NoMethodError).

module Notcurses
  module FFI
    # ═══════════════════════════════════════
    # Notcurses lifecycle
    # ═══════════════════════════════════════

    # --- version ---

    # C: #define NOTCURSES_VERSION_COMPARABLE(major, minor, patch) \
    #      (((major) << 16u) + ((minor) << 8u) + (patch))
    # NOTE: macro: argomenti int come i letterali C; dove il C andrebbe in overflow (UB) Ruby non tronca
    def self.NOTCURSES_VERSION_COMPARABLE(major, minor, patch)
      (major << 16) + (minor << 8) + patch
    end

    # --- stdplane ---

    # C: static inline struct ncplane*
    #    notcurses_top(struct notcurses* n){
    #      return ncpile_top(notcurses_stdplane(n));
    #    }
    def self.notcurses_top(n)
      ncpile_top(notcurses_stdplane(n))
    end

    # C: static inline struct ncplane*
    #    notcurses_bottom(struct notcurses* n){
    #      return ncpile_bottom(notcurses_stdplane(n));
    #    }
    def self.notcurses_bottom(n)
      ncpile_bottom(notcurses_stdplane(n))
    end

    # C: static inline struct ncplane*
    #    notcurses_stddim_yx(struct notcurses* nc, unsigned* RESTRICT y, unsigned* RESTRICT x){
    #      struct ncplane* s = notcurses_stdplane(nc); // can't fail
    #      ncplane_dim_yx(s, y, x); // accepts NULL
    #      return s;
    #    }
    def self.notcurses_stddim_yx(nc, y, x)
      s = notcurses_stdplane(nc)
      ncplane_dim_yx(s, y, x)
      s
    end

    # C: static inline const struct ncplane*
    #    notcurses_stddim_yx_const(const struct notcurses* nc, unsigned* RESTRICT y, unsigned* RESTRICT x){
    #      const struct ncplane* s = notcurses_stdplane_const(nc); // can't fail
    #      ncplane_dim_yx(s, y, x); // accepts NULL
    #      return s;
    #    }
    def self.notcurses_stddim_yx_const(nc, y, x)
      s = notcurses_stdplane_const(nc)
      ncplane_dim_yx(s, y, x)
      s
    end

    # C: static inline void
    #    notcurses_term_dim_yx(const struct notcurses* n, unsigned* RESTRICT rows, unsigned* RESTRICT cols){
    #      ncplane_dim_yx(notcurses_stdplane_const(n), rows, cols);
    #    }
    def self.notcurses_term_dim_yx(n, rows, cols)
      ncplane_dim_yx(notcurses_stdplane_const(n), rows, cols)
      nil
    end

    # --- rendering ---

    # C: static inline int
    #    notcurses_render(struct notcurses* nc){
    #      struct ncplane* stdn = notcurses_stdplane(nc);
    #      if(ncpile_render(stdn)){
    #        return -1;
    #      }
    #      return ncpile_rasterize(stdn);
    #    }
    def self.notcurses_render(nc)
      stdn = notcurses_stdplane(nc)
      return -1 if ncpile_render(stdn) != 0
      ncpile_rasterize(stdn)
    end

    # --- capabilities ---

    # C: __attribute__ ((nonnull (1))) __attribute__ ((pure)) static inline bool
    #    nccapability_canchangecolor(const nccapabilities* caps){
    #      if(!caps->can_change_colors){
    #        return false;
    #      }
    #      ncpalette* p;
    #      if(caps->colors < sizeof(p->chans) / sizeof(*p->chans)){
    #        return false;
    #      }
    #      return true;
    #    }
    def self.nccapability_canchangecolor(caps)
      return false unless caps[:can_change_colors]
      return false if caps[:colors] < NCPALETTESIZE
      true
    end

    # C: __attribute__ ((nonnull (1))) __attribute__ ((pure)) static inline bool
    #    notcurses_cantruecolor(const struct notcurses* nc){
    #      return notcurses_capabilities(nc)->rgb;
    #    }
    def self.notcurses_cantruecolor(nc)
      notcurses_capabilities(nc)[:rgb]
    end

    # C: __attribute__ ((nonnull (1))) __attribute__ ((pure)) static inline bool
    #    notcurses_canchangecolor(const struct notcurses* nc){
    #      return nccapability_canchangecolor(notcurses_capabilities(nc));
    #    }
    def self.notcurses_canchangecolor(nc)
      nccapability_canchangecolor(notcurses_capabilities(nc))
    end

    # C: __attribute__ ((nonnull (1))) __attribute__ ((pure)) static inline bool
    #    notcurses_canfade(const struct notcurses* n){
    #      return notcurses_canchangecolor(n) || notcurses_cantruecolor(n);
    #    }
    def self.notcurses_canfade(n)
      notcurses_canchangecolor(n) || notcurses_cantruecolor(n)
    end

    # C: __attribute__ ((nonnull (1))) __attribute__ ((pure)) static inline bool
    #    notcurses_canutf8(const struct notcurses* nc){
    #      return notcurses_capabilities(nc)->utf8;
    #    }
    def self.notcurses_canutf8(nc)
      notcurses_capabilities(nc)[:utf8]
    end

    # C: __attribute__ ((nonnull (1))) __attribute__ ((pure)) static inline bool
    #    notcurses_canhalfblock(const struct notcurses* nc){
    #      return notcurses_canutf8(nc);
    #    }
    def self.notcurses_canhalfblock(nc)
      notcurses_canutf8(nc)
    end

    # C: __attribute__ ((nonnull (1))) __attribute__ ((pure)) static inline bool
    #    notcurses_canquadrant(const struct notcurses* nc){
    #      return notcurses_canutf8(nc) && notcurses_capabilities(nc)->quadrants;
    #    }
    def self.notcurses_canquadrant(nc)
      notcurses_canutf8(nc) && notcurses_capabilities(nc)[:quadrants]
    end

    # C: __attribute__ ((nonnull (1))) __attribute__ ((pure)) static inline bool
    #    notcurses_cansextant(const struct notcurses* nc){
    #      return notcurses_canutf8(nc) && notcurses_capabilities(nc)->sextants;
    #    }
    def self.notcurses_cansextant(nc)
      notcurses_canutf8(nc) && notcurses_capabilities(nc)[:sextants]
    end

    # C: __attribute__ ((nonnull (1))) __attribute__ ((pure)) static inline bool
    #    notcurses_canoctant(const struct notcurses* nc){
    #      return notcurses_canutf8(nc) && notcurses_capabilities(nc)->octants;
    #    }
    def self.notcurses_canoctant(nc)
      notcurses_canutf8(nc) && notcurses_capabilities(nc)[:octants]
    end

    # C: __attribute__ ((nonnull (1))) __attribute__ ((pure)) static inline bool
    #    notcurses_canbraille(const struct notcurses* nc){
    #      return notcurses_canutf8(nc) && notcurses_capabilities(nc)->braille;
    #    }
    def self.notcurses_canbraille(nc)
      notcurses_canutf8(nc) && notcurses_capabilities(nc)[:braille]
    end

    # C: __attribute__ ((nonnull (1))) __attribute__ ((pure)) static inline bool
    #    notcurses_canpixel(const struct notcurses* nc){
    #      return notcurses_check_pixel_support(nc) != NCPIXEL_NONE;
    #    }
    def self.notcurses_canpixel(nc)
      notcurses_check_pixel_support(nc) != NCPIXEL_NONE
    end

    # --- utilità ---

    # C: static inline int
    #    notcurses_align(int availu, ncalign_e align, int u){
    #      if(align == NCALIGN_LEFT || align == NCALIGN_TOP){
    #        return 0;
    #      }
    #      if(align == NCALIGN_CENTER){
    #        return (availu - u) / 2;
    #      }
    #      if(align == NCALIGN_RIGHT || align == NCALIGN_BOTTOM){
    #        return availu - u;
    #      }
    #      return -INT_MAX; // invalid |align|
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    # NOTE: availu - u in overflow è UB in C: qui complemento a 2 su 32 bit, come il codice di gcc
    def self.notcurses_align(availu, align, u)
      return 0 if align == NCALIGN_LEFT || align == NCALIGN_TOP
      d = ((availu - u + 0x8000_0000) & 0xffff_ffff) - 0x8000_0000
      if align == NCALIGN_CENTER
        return d.negative? ? -(-d / 2) : d / 2 # la divisione C tronca verso zero
      end
      return d if align == NCALIGN_RIGHT || align == NCALIGN_BOTTOM
      -0x7fff_ffff # -INT_MAX
    end

    # ═══════════════════════════════════════
    # NcPlane
    # ═══════════════════════════════════════

    # --- creazione ---

    # C: static inline int
    #    ncplane_resize_simple(struct ncplane* n, unsigned ylen, unsigned xlen){
    #      unsigned oldy, oldx;
    #      ncplane_dim_yx(n, &oldy, &oldx); // current dimensions of 'n'
    #      unsigned keepleny = oldy > ylen ? ylen : oldy;
    #      unsigned keeplenx = oldx > xlen ? xlen : oldx;
    #      return ncplane_resize(n, 0, 0, keepleny, keeplenx, 0, 0, ylen, xlen);
    #    }
    def self.ncplane_resize_simple(n, ylen, xlen)
      ylen &= 0xffff_ffff
      xlen &= 0xffff_ffff
      oldy = ::FFI::MemoryPointer.new(:uint)
      oldx = ::FFI::MemoryPointer.new(:uint)
      ncplane_dim_yx(n, oldy, oldx) # dimensioni attuali di n
      keepleny = oldy.read_uint > ylen ? ylen : oldy.read_uint
      keeplenx = oldx.read_uint > xlen ? xlen : oldx.read_uint
      ncplane_resize(n, 0, 0, keepleny, keeplenx, 0, 0, ylen, xlen)
    end

    # --- relazioni ---

    # C: static inline int
    #    ncplane_descendant_p(const struct ncplane* n, const struct ncplane* ancestor){
    #      for(const struct ncplane* parent = ncplane_parent_const(n) ; parent != ancestor ; parent = ncplane_parent_const(parent)){
    #        if(ncplane_parent_const(parent) == parent){ // reached a root plane
    #          return 0;
    #        }
    #      }
    #      return 1;
    #    }
    def self.ncplane_descendant_p(n, ancestor)
      anc = ancestor.nil? ? 0 : ancestor.address
      parent = ncplane_parent_const(n)
      while parent.address != anc
        return 0 if ncplane_parent_const(parent).address == parent.address # raggiunto un piano radice
        parent = ncplane_parent_const(parent)
      end
      1
    end

    # --- geometria ---

    # C: static inline unsigned
    #    ncplane_dim_y(const struct ncplane* n){
    #      unsigned dimy;
    #      ncplane_dim_yx(n, &dimy, NULL);
    #      return dimy;
    #    }
    def self.ncplane_dim_y(n)
      dimy = ::FFI::MemoryPointer.new(:uint)
      ncplane_dim_yx(n, dimy, nil)
      dimy.read_uint
    end

    # C: static inline unsigned
    #    ncplane_dim_x(const struct ncplane* n){
    #      unsigned dimx;
    #      ncplane_dim_yx(n, NULL, &dimx);
    #      return dimx;
    #    }
    def self.ncplane_dim_x(n)
      dimx = ::FFI::MemoryPointer.new(:uint)
      ncplane_dim_yx(n, nil, dimx)
      dimx.read_uint
    end

    # C: static inline int
    #    ncplane_halign(const struct ncplane* n, ncalign_e align, int c){
    #      return notcurses_align((int)ncplane_dim_x(n), align, c);
    #    }
    def self.ncplane_halign(n, align, c)
      notcurses_align(((ncplane_dim_x(n) + 0x8000_0000) & 0xffff_ffff) - 0x8000_0000, align, c) # (int)
    end

    # C: static inline int
    #    ncplane_valign(const struct ncplane* n, ncalign_e align, int r){
    #      return notcurses_align((int)ncplane_dim_y(n), align, r);
    #    }
    def self.ncplane_valign(n, align, r)
      notcurses_align(((ncplane_dim_y(n) + 0x8000_0000) & 0xffff_ffff) - 0x8000_0000, align, r) # (int)
    end

    # --- z-order ---

    # C: __attribute__ ((nonnull (1))) static inline int
    #    ncplane_move_rel(struct ncplane* n, int y, int x){
    #      int oy, ox;
    #      ncplane_yx(n, &oy, &ox);
    #      return ncplane_move_yx(n, oy + y, ox + x);
    #    }
    # NOTE: oy + y in overflow è UB in C: qui complemento a 2 su 32 bit, come il codice di gcc
    def self.ncplane_move_rel(n, y, x)
      oy = ::FFI::MemoryPointer.new(:int)
      ox = ::FFI::MemoryPointer.new(:int)
      ncplane_yx(n, oy, ox)
      ncplane_move_yx(n, ((oy.read_int + y + 0x8000_0000) & 0xffff_ffff) - 0x8000_0000,
                      ((ox.read_int + x + 0x8000_0000) & 0xffff_ffff) - 0x8000_0000)
    end

    # C: __attribute__ ((nonnull (1)))
    #    static inline void
    #    ncplane_move_top(struct ncplane* n){
    #      ncplane_move_below(n, NULL);
    #    }
    def self.ncplane_move_top(n)
      ncplane_move_below(n, nil)
      nil
    end

    # C: __attribute__ ((nonnull (1)))
    #    static inline void
    #    ncplane_move_bottom(struct ncplane* n){
    #      ncplane_move_above(n, NULL);
    #    }
    def self.ncplane_move_bottom(n)
      ncplane_move_above(n, nil)
      nil
    end

    # C: __attribute__ ((nonnull (1)))
    #    static inline void
    #    ncplane_move_family_top(struct ncplane* n){
    #      ncplane_move_family_below(n, NULL);
    #    }
    def self.ncplane_move_family_top(n)
      ncplane_move_family_below(n, nil)
      nil
    end

    # C: __attribute__ ((nonnull (1)))
    #    static inline void
    #    ncplane_move_family_bottom(struct ncplane* n){
    #      ncplane_move_family_above(n, NULL);
    #    }
    def self.ncplane_move_family_bottom(n)
      ncplane_move_family_above(n, nil)
      nil
    end

    # --- cursore ---

    # C: static inline unsigned
    #    ncplane_cursor_y(const struct ncplane* n){
    #      unsigned y;
    #      ncplane_cursor_yx(n, &y, NULL);
    #      return y;
    #    }
    def self.ncplane_cursor_y(n)
      y = ::FFI::MemoryPointer.new(:uint)
      ncplane_cursor_yx(n, y, nil)
      y.read_uint
    end

    # C: static inline unsigned
    #    ncplane_cursor_x(const struct ncplane* n){
    #      unsigned x;
    #      ncplane_cursor_yx(n, NULL, &x);
    #      return x;
    #    }
    def self.ncplane_cursor_x(n)
      x = ::FFI::MemoryPointer.new(:uint)
      ncplane_cursor_yx(n, nil, x)
      x.read_uint
    end

    # --- output ---

    # C: static inline int
    #    ncplane_putc(struct ncplane* n, const nccell* c){
    #      return ncplane_putc_yx(n, -1, -1, c);
    #    }
    def self.ncplane_putc(n, c)
      ncplane_putc_yx(n, -1, -1, c)
    end

    # C: static inline int
    #    ncplane_putchar_yx(struct ncplane* n, int y, int x, char c){
    #      nccell ce = NCCELL_INITIALIZER((uint32_t)c, ncplane_styles(n), ncplane_channels(n));
    #      return ncplane_putc_yx(n, y, x, &ce);
    #    }
    def self.ncplane_putchar_yx(n, y, x, c)
      c = ((c & 0xff) ^ 0x80) - 0x80 # char con segno, come la conversione FFI di :char
      ce = NCCELL_INITIALIZER(c & 0xffff_ffff, ncplane_styles(n), ncplane_channels(n))
      ncplane_putc_yx(n, y, x, ce)
    end

    # C: static inline int
    #    ncplane_putchar(struct ncplane* n, char c){
    #      return ncplane_putchar_yx(n, -1, -1, c);
    #    }
    def self.ncplane_putchar(n, c)
      ncplane_putchar_yx(n, -1, -1, c)
    end

    # C: static inline int
    #    ncplane_putegc(struct ncplane* n, const char* gclust, size_t* sbytes){
    #      return ncplane_putegc_yx(n, -1, -1, gclust, sbytes);
    #    }
    def self.ncplane_putegc(n, gclust, sbytes)
      ncplane_putegc_yx(n, -1, -1, gclust, sbytes)
    end

    # C: ALLOC static inline char*
    #    ncwcsrtombs(const wchar_t* src){
    #      mbstate_t ps;
    #      memset(&ps, 0, sizeof(ps));
    #      size_t mbytes = wcsrtombs(NULL, &src, 0, &ps);
    #      if(mbytes == (size_t)-1){
    #        return NULL;
    #      }
    #      ++mbytes;
    #      char* mbstr = (char*)malloc(mbytes); // need cast for c++ callers
    #      if(mbstr == NULL){
    #        return NULL;
    #      }
    #      size_t s = wcsrtombs(mbstr, &src, mbytes, &ps);
    #      if(s == (size_t)-1){
    #        free(mbstr);
    #        return NULL;
    #      }
    #      return mbstr;
    #    }
    # NOTE: potrebbe appartenere a Notcurses lifecycle (utilità stringhe)
    # NOTE: conversione in un buffer temporaneo, risultato allocato con strdup (liberare con free)
    def self.ncwcsrtombs(src)
      ps = ::FFI::MemoryPointer.new(:uint8, 128) # mbstate_t azzerato
      srcp = ::FFI::MemoryPointer.new(:pointer).write_pointer(src)
      mbytes = wcsrtombs(nil, srcp, 0, ps)
      return ::FFI::Pointer::NULL if mbytes == 0xffff_ffff_ffff_ffff # (size_t)-1
      mbytes += 1
      mbstr = ::FFI::MemoryPointer.new(:char, mbytes)
      return ::FFI::Pointer::NULL if wcsrtombs(mbstr, srcp, mbytes, ps) == 0xffff_ffff_ffff_ffff
      strdup(mbstr.read_string)
    end

    # C: static inline int
    #    ncplane_putwegc(struct ncplane* n, const wchar_t* gclust, size_t* sbytes){
    #      char* mbstr = ncwcsrtombs(gclust);
    #      if(mbstr == NULL){
    #        return -1;
    #      }
    #      int ret = ncplane_putegc(n, mbstr, sbytes);
    #      free(mbstr);
    #      return ret;
    #    }
    def self.ncplane_putwegc(n, gclust, sbytes)
      mbstr = ncwcsrtombs(gclust)
      return -1 if mbstr.null?
      ret = ncplane_putegc(n, mbstr.read_string, sbytes)
      free(mbstr)
      ret
    end

    # C: static inline int
    #    ncplane_putwegc_yx(struct ncplane* n, int y, int x, const wchar_t* gclust,
    #                       size_t* sbytes){
    #      if(ncplane_cursor_move_yx(n, y, x)){
    #        return -1;
    #      }
    #      return ncplane_putwegc(n, gclust, sbytes);
    #    }
    def self.ncplane_putwegc_yx(n, y, x, gclust, sbytes)
      return -1 if ncplane_cursor_move_yx(n, y, x) != 0
      ncplane_putwegc(n, gclust, sbytes)
    end

    # C: static inline int
    #    ncplane_putstr_yx(struct ncplane* n, int y, int x, const char* gclusters){
    #      int ret = 0;
    #      while(*gclusters){
    #        size_t wcs;
    #        int cols = ncplane_putegc_yx(n, y, x, gclusters, &wcs);
    #    //fprintf(stderr, "wrote %.*s %d cols %zu bytes\n", (int)wcs, gclusters, cols, wcs);
    #        if(cols < 0){
    #          return -ret;
    #        }
    #        if(wcs == 0){
    #          break;
    #        }
    #        // after the first iteration, just let the cursor code control where we
    #        // print, so that scrolling is taken into account
    #        y = -1;
    #        x = -1;
    #        gclusters += wcs;
    #        ret += cols;
    #      }
    #      return ret;
    #    }
    # NOTE: NUL interno: la prima ncplane_putegc_yx riceve tutta la stringa, FFI solleva ArgumentError prima di scrivere
    def self.ncplane_putstr_yx(n, y, x, gclusters)
      gclusters = gclusters.b
      ret = 0
      off = 0
      wcs = ::FFI::MemoryPointer.new(:size_t)
      while off < gclusters.bytesize
        cols = ncplane_putegc_yx(n, y, x, gclusters.byteslice(off..), wcs)
        return -ret if cols < 0
        break if wcs.read(:size_t).zero?
        # dopo la prima iterazione decide il cursore, così lo scrolling è considerato
        y = -1
        x = -1
        off += wcs.read(:size_t)
        ret += cols
      end
      ret
    end

    # C: static inline int
    #    ncplane_putstr(struct ncplane* n, const char* gclustarr){
    #      return ncplane_putstr_yx(n, -1, -1, gclustarr);
    #    }
    def self.ncplane_putstr(n, gclustarr)
      ncplane_putstr_yx(n, -1, -1, gclustarr)
    end

    # C: static inline int
    #    ncplane_putstr_aligned(struct ncplane* n, int y, ncalign_e align, const char* s){
    #      int validbytes, validwidth;
    #      // we'll want to do the partial write if there's an error somewhere within
    #      ncstrwidth(s, &validbytes, &validwidth);
    #      int xpos = ncplane_halign(n, align, validwidth);
    #      if(xpos < 0){
    #        xpos = 0;
    #      }
    #      return ncplane_putstr_yx(n, y, xpos, s);
    #    }
    def self.ncplane_putstr_aligned(n, y, align, s)
      validbytes = ::FFI::MemoryPointer.new(:int)
      validwidth = ::FFI::MemoryPointer.new(:int)
      ncstrwidth(s, validbytes, validwidth) # con un errore a metà vale la larghezza parziale
      xpos = ncplane_halign(n, align, validwidth.read_int)
      xpos = 0 if xpos < 0
      ncplane_putstr_yx(n, y, xpos, s)
    end

    # C: static inline int
    #    ncplane_putstr_stained(struct ncplane* n, const char* gclusters){
    #      int ret = 0;
    #      while(*gclusters){
    #        size_t wcs;
    #        int cols = ncplane_putegc_stained(n, gclusters, &wcs);
    #        if(cols < 0){
    #          return -ret;
    #        }
    #        if(wcs == 0){
    #          break;
    #        }
    #        gclusters += wcs;
    #        ret += cols;
    #      }
    #      return ret;
    #    }
    # NOTE: NUL interno: la prima ncplane_putegc_stained riceve tutta la stringa, FFI solleva ArgumentError prima di scrivere
    def self.ncplane_putstr_stained(n, gclusters)
      gclusters = gclusters.b
      ret = 0
      off = 0
      wcs = ::FFI::MemoryPointer.new(:size_t)
      while off < gclusters.bytesize
        cols = ncplane_putegc_stained(n, gclusters.byteslice(off..), wcs)
        return -ret if cols < 0
        break if wcs.read(:size_t).zero?
        off += wcs.read(:size_t)
        ret += cols
      end
      ret
    end

    # C: static inline int
    #    ncplane_putnstr_yx(struct ncplane* n, int y, int x, size_t s, const char* gclusters){
    #      int ret = 0;
    #      size_t offset = 0;
    #    //fprintf(stderr, "PUT %zu at %d/%d [%.*s]\n", s, y, x, (int)s, gclusters);
    #      while(offset < s && gclusters[offset]){
    #        size_t wcs;
    #        int cols = ncplane_putegc_yx(n, y, x, gclusters + offset, &wcs);
    #        if(cols < 0){
    #          return -ret;
    #        }
    #        if(wcs == 0){
    #          break;
    #        }
    #        // after the first iteration, just let the cursor code control where we
    #        // print, so that scrolling is taken into account
    #        y = -1;
    #        x = -1;
    #        offset += wcs;
    #        ret += cols;
    #      }
    #      return ret;
    #    }
    # NOTE: NUL interno: ArgumentError prima di scrivere come FFI su un parametro :string (con s == 0 non c'è chiamata FFI)
    # NOTE: comportamento C replicato: ncplane_putegc_yx riceve il resto della stringa, l'ultimo EGC può superare s byte
    def self.ncplane_putnstr_yx(n, y, x, s, gclusters)
      s &= 0xffff_ffff_ffff_ffff
      # NULL con s == 0: il C non legge la stringa e restituisce 0
      gclusters = gclusters&.b
      raise ArgumentError, 'string contains null byte' if gclusters&.include?("\0")
      ret = 0
      offset = 0
      wcs = ::FFI::MemoryPointer.new(:size_t)
      while offset < s && offset < gclusters.bytesize
        cols = ncplane_putegc_yx(n, y, x, gclusters.byteslice(offset..), wcs)
        return -ret if cols < 0
        break if wcs.read(:size_t).zero?
        # dopo la prima iterazione decide il cursore, così lo scrolling è considerato
        y = -1
        x = -1
        offset += wcs.read(:size_t)
        ret += cols
      end
      ret
    end

    # C: static inline int
    #    ncplane_putnstr(struct ncplane* n, size_t s, const char* gclustarr){
    #      return ncplane_putnstr_yx(n, -1, -1, s, gclustarr);
    #    }
    def self.ncplane_putnstr(n, s, gclustarr)
      ncplane_putnstr_yx(n, -1, -1, s, gclustarr)
    end

    # C: static inline int
    #    ncplane_putwstr_yx(struct ncplane* n, int y, int x, const wchar_t* gclustarr){
    #      // maximum of six UTF8-encoded bytes per wchar_t
    #      const size_t mbytes = (wcslen(gclustarr) * WCHAR_MAX_UTF8BYTES) + 1;
    #      char* mbstr = (char*)malloc(mbytes); // need cast for c++ callers
    #      if(mbstr == NULL){
    #        return -1;
    #      }
    #      mbstate_t ps;
    #      memset(&ps, 0, sizeof(ps));
    #      const wchar_t** gend = &gclustarr;
    #      size_t s = wcsrtombs(mbstr, gend, mbytes, &ps);
    #      if(s == (size_t)-1){
    #        free(mbstr);
    #        return -1;
    #      }
    #      int ret = ncplane_putstr_yx(n, y, x, mbstr);
    #      free(mbstr);
    #      return ret;
    #    }
    # NOTE: glibc codifica i wchar_t >= 0x200000 con 5-6 byte: il buffer da WCHAR_MAX_UTF8BYTES per carattere
    # NOTE: può restare senza NUL (in C lettura oltre il buffer, UB); qui read_string si ferma a fine buffer
    def self.ncplane_putwstr_yx(n, y, x, gclustarr)
      mbytes = wcslen(gclustarr) * WCHAR_MAX_UTF8BYTES + 1
      mbstr = ::FFI::MemoryPointer.new(:char, mbytes)
      ps = ::FFI::MemoryPointer.new(:uint8, 128) # mbstate_t azzerato
      gend = ::FFI::MemoryPointer.new(:pointer).write_pointer(gclustarr)
      return -1 if wcsrtombs(mbstr, gend, mbytes, ps) == 0xffff_ffff_ffff_ffff # (size_t)-1
      ncplane_putstr_yx(n, y, x, mbstr.read_string)
    end

    # C: static inline int
    #    ncplane_putwstr_aligned(struct ncplane* n, int y, ncalign_e align,
    #                            const wchar_t* gclustarr){
    #      int width = wcswidth(gclustarr, INT_MAX);
    #      int xpos = ncplane_halign(n, align, width);
    #      if(xpos < 0){
    #        xpos = 0;
    #      }
    #      return ncplane_putwstr_yx(n, y, xpos, gclustarr);
    #    }
    def self.ncplane_putwstr_aligned(n, y, align, gclustarr)
      width = wcswidth(gclustarr, 0x7fff_ffff) # INT_MAX
      xpos = ncplane_halign(n, align, width)
      xpos = 0 if xpos < 0
      ncplane_putwstr_yx(n, y, xpos, gclustarr)
    end

    # C: static inline int
    #    ncplane_putwstr(struct ncplane* n, const wchar_t* gclustarr){
    #      return ncplane_putwstr_yx(n, -1, -1, gclustarr);
    #    }
    def self.ncplane_putwstr(n, gclustarr)
      ncplane_putwstr_yx(n, -1, -1, gclustarr)
    end

    # C: static inline int
    #    ncplane_pututf32_yx(struct ncplane* n, int y, int x, uint32_t u){
    #      if(u > WCHAR_MAX){
    #        return -1;
    #      }
    #      // we use MB_LEN_MAX (and potentially "waste" a few stack bytes to avoid
    #      // the greater sin of a VLA (and to be locale-independent).
    #      char utf8c[MB_LEN_MAX + 1];
    #      mbstate_t ps;
    #      memset(&ps, 0, sizeof(ps));
    #      // this isn't going to be valid for reconstructued surrogate pairs...
    #      // we need our own, or to use unistring or something.
    #      size_t s = wcrtomb(utf8c, (wchar_t)u, &ps);
    #      if(s == (size_t)-1){
    #        return -1;
    #      }
    #      utf8c[s] = '\0';
    #      return ncplane_putegc_yx(n, y, x, utf8c, NULL);
    #    }
    def self.ncplane_pututf32_yx(n, y, x, u)
      u &= 0xffff_ffff
      return -1 if u > 0x7fff_ffff # WCHAR_MAX
      utf8c = ::FFI::MemoryPointer.new(:char, 16 + 1) # MB_LEN_MAX + 1, azzerato: utf8c[s] = '\0' già presente
      ps = ::FFI::MemoryPointer.new(:uint8, 128) # mbstate_t azzerato
      s = wcrtomb(utf8c, u, ps)
      return -1 if s == 0xffff_ffff_ffff_ffff # (size_t)-1
      ncplane_putegc_yx(n, y, x, utf8c.read_string, nil) # la stringa C finisce al primo NUL (u == 0)
    end

    # C: static inline int
    #    ncplane_putwc_yx(struct ncplane* n, int y, int x, wchar_t w){
    #      return ncplane_pututf32_yx(n, y, x, (uint32_t)w);
    #    }
    def self.ncplane_putwc_yx(n, y, x, w)
      ncplane_pututf32_yx(n, y, x, w & 0xffff_ffff)
    end

    # C: static inline int
    #    ncplane_putwc(struct ncplane* n, wchar_t w){
    #      return ncplane_putwc_yx(n, -1, -1, w);
    #    }
    def self.ncplane_putwc(n, w)
      ncplane_putwc_yx(n, -1, -1, w)
    end

    # C: static inline int
    #    ncplane_putwc_utf32(struct ncplane* n, const wchar_t* w, unsigned* wchars){
    #      uint32_t utf32;
    #      if(*w >= 0xd000 && *w <= 0xdbff){
    #        *wchars = 2;
    #        if(w[1] < 0xdc00 || w[1] > 0xdfff){
    #          return -1; // invalid surrogate pairing
    #        }
    #        utf32 = (w[0] & 0x3fflu) << 10lu;
    #        utf32 += (w[1] & 0x3fflu);
    #      }else{
    #        *wchars = 1;
    #        utf32 = (uint32_t)*w;
    #      }
    #      return ncplane_pututf32_yx(n, -1, -1, utf32);
    #    }
    # NOTE: comportamento C replicato: surrogato alto riconosciuto da 0xd000 (non 0xd800), coppia ricomposta senza + 0x10000
    def self.ncplane_putwc_utf32(n, w, wchars)
      w0 = w.get_int32(0)
      if w0 >= 0xd000 && w0 <= 0xdbff
        wchars.write_uint(2)
        w1 = w.get_int32(4)
        return -1 if w1 < 0xdc00 || w1 > 0xdfff # coppia di surrogati non valida
        utf32 = ((w0 & 0x3ff) << 10) + (w1 & 0x3ff)
      else
        wchars.write_uint(1)
        utf32 = w0 & 0xffff_ffff
      end
      ncplane_pututf32_yx(n, -1, -1, utf32)
    end

    # C: static inline int
    #    ncplane_putwc_stained(struct ncplane* n, wchar_t w){
    #      wchar_t warr[2] = { w, L'\0' };
    #      return ncplane_putwstr_stained(n, warr);
    #    }
    def self.ncplane_putwc_stained(n, w)
      warr = ::FFI::MemoryPointer.new(:wchar_t, 2).put_array_of_int32(0, [w, 0])
      ncplane_putwstr_stained(n, warr)
    end

    # C: static inline int
    #    ncplane_vprintf(struct ncplane* n, const char* format, va_list ap){
    #      return ncplane_vprintf_yx(n, -1, -1, format, ap);
    #    }
    # REVIEW: va_list non costruibile da Ruby (ap deve essere un va_list C già pronto, passato invariato); da Ruby usare ncplane_printf
    def self.ncplane_vprintf(n, format, ap)
      ncplane_vprintf_yx(n, -1, -1, format, ap)
    end

    # C: static inline int
    #    ncplane_printf(struct ncplane* n, const char* format, ...){
    #      va_list va;
    #      va_start(va, format);
    #      int ret = ncplane_vprintf(n, format, va);
    #      va_end(va);
    #      return ret;
    #    }
    # NOTE: varargs ruby-ffi: snprintf in un buffer, poi ncplane_putstr_yx come ncplane_vprintf_yx
    def self.ncplane_printf(n, format, *varargs)
      len = snprintf(nil, 0, format, *varargs)
      return -1 if len < 0
      buf = ::FFI::MemoryPointer.new(:char, len + 1)
      snprintf(buf, len + 1, format, *varargs)
      ncplane_putstr_yx(n, -1, -1, buf.read_string)
    end

    # C: static inline int
    #    ncplane_printf_yx(struct ncplane* n, int y, int x, const char* format, ...){
    #      va_list va;
    #      va_start(va, format);
    #      int ret = ncplane_vprintf_yx(n, y, x, format, va);
    #      va_end(va);
    #      return ret;
    #    }
    # NOTE: varargs ruby-ffi: snprintf in un buffer, poi ncplane_putstr_yx come ncplane_vprintf_yx
    def self.ncplane_printf_yx(n, y, x, format, *varargs)
      len = snprintf(nil, 0, format, *varargs)
      return -1 if len < 0
      buf = ::FFI::MemoryPointer.new(:char, len + 1)
      snprintf(buf, len + 1, format, *varargs)
      ncplane_putstr_yx(n, y, x, buf.read_string)
    end

    # C: static inline int
    #    ncplane_printf_aligned(struct ncplane* n, int y, ncalign_e align, const char* format, ...){
    #      va_list va;
    #      va_start(va, format);
    #      int ret = ncplane_vprintf_aligned(n, y, align, format, va);
    #      va_end(va);
    #      return ret;
    #    }
    # NOTE: varargs ruby-ffi: snprintf in un buffer, poi ncplane_putstr_aligned come ncplane_vprintf_aligned
    def self.ncplane_printf_aligned(n, y, align, format, *varargs)
      len = snprintf(nil, 0, format, *varargs)
      return -1 if len < 0
      buf = ::FFI::MemoryPointer.new(:char, len + 1)
      snprintf(buf, len + 1, format, *varargs)
      ncplane_putstr_aligned(n, y, align, buf.read_string)
    end

    # C: static inline int
    #    ncplane_printf_stained(struct ncplane* n, const char* format, ...){
    #      va_list va;
    #      va_start(va, format);
    #      int ret = ncplane_vprintf_stained(n, format, va);
    #      va_end(va);
    #      return ret;
    #    }
    # NOTE: varargs ruby-ffi: snprintf in un buffer, poi ncplane_putstr_stained come ncplane_vprintf_stained
    def self.ncplane_printf_stained(n, format, *varargs)
      len = snprintf(nil, 0, format, *varargs)
      return -1 if len < 0
      buf = ::FFI::MemoryPointer.new(:char, len + 1)
      snprintf(buf, len + 1, format, *varargs)
      ncplane_putstr_stained(n, buf.read_string)
    end

    # --- linee e box ---

    # C: __attribute__ ((nonnull (1, 2))) static inline int
    #    ncplane_hline(struct ncplane* n, const nccell* c, unsigned len){
    #      return ncplane_hline_interp(n, c, len, c->channels, c->channels);
    #    }
    def self.ncplane_hline(n, c, len)
      ncplane_hline_interp(n, c, len, c[:channels], c[:channels])
    end

    # C: __attribute__ ((nonnull (1, 2))) static inline int
    #    ncplane_vline(struct ncplane* n, const nccell* c, unsigned len){
    #      return ncplane_vline_interp(n, c, len, c->channels, c->channels);
    #    }
    def self.ncplane_vline(n, c, len)
      ncplane_vline_interp(n, c, len, c[:channels], c[:channels])
    end

    # C: static inline int
    #    ncplane_box_sized(struct ncplane* n, const nccell* ul, const nccell* ur,
    #                      const nccell* ll, const nccell* lr, const nccell* hline,
    #                      const nccell* vline, unsigned ystop, unsigned xstop,
    #                      unsigned ctlword){
    #      unsigned y, x;
    #      ncplane_cursor_yx(n, &y, &x);
    #      return ncplane_box(n, ul, ur, ll, lr, hline, vline, y + ystop - 1,
    #                         x + xstop - 1, ctlword);
    #    }
    def self.ncplane_box_sized(n, ul, ur, ll, lr, hline, vline, ystop, xstop, ctlword)
      y = ::FFI::MemoryPointer.new(:uint)
      x = ::FFI::MemoryPointer.new(:uint)
      ncplane_cursor_yx(n, y, x)
      ncplane_box(n, ul, ur, ll, lr, hline, vline, (y.read_uint + ystop - 1) & 0xffff_ffff,
                  (x.read_uint + xstop - 1) & 0xffff_ffff, ctlword)
    end

    # C: static inline int
    #    ncplane_perimeter(struct ncplane* n, const nccell* ul, const nccell* ur,
    #                      const nccell* ll, const nccell* lr, const nccell* hline,
    #                      const nccell* vline, unsigned ctlword){
    #      if(ncplane_cursor_move_yx(n, 0, 0)){
    #        return -1;
    #      }
    #      unsigned dimy, dimx;
    #      ncplane_dim_yx(n, &dimy, &dimx);
    #      return ncplane_box_sized(n, ul, ur, ll, lr, hline, vline, dimy, dimx, ctlword);
    #    }
    def self.ncplane_perimeter(n, ul, ur, ll, lr, hline, vline, ctlword)
      return -1 if ncplane_cursor_move_yx(n, 0, 0) != 0
      dimy = ::FFI::MemoryPointer.new(:uint)
      dimx = ::FFI::MemoryPointer.new(:uint)
      ncplane_dim_yx(n, dimy, dimx)
      ncplane_box_sized(n, ul, ur, ll, lr, hline, vline, dimy.read_uint, dimx.read_uint, ctlword)
    end

    # C: static inline int
    #    ncplane_rounded_box(struct ncplane* n, uint16_t styles, uint64_t channels,
    #                        unsigned ystop, unsigned xstop, unsigned ctlword){
    #      int ret = 0;
    #      nccell ul = NCCELL_TRIVIAL_INITIALIZER, ur = NCCELL_TRIVIAL_INITIALIZER;
    #      nccell ll = NCCELL_TRIVIAL_INITIALIZER, lr = NCCELL_TRIVIAL_INITIALIZER;
    #      nccell hl = NCCELL_TRIVIAL_INITIALIZER, vl = NCCELL_TRIVIAL_INITIALIZER;
    #      if((ret = nccells_rounded_box(n, styles, channels, &ul, &ur, &ll, &lr, &hl, &vl)) == 0){
    #        ret = ncplane_box(n, &ul, &ur, &ll, &lr, &hl, &vl, ystop, xstop, ctlword);
    #      }
    #      nccell_release(n, &ul); nccell_release(n, &ur);
    #      nccell_release(n, &ll); nccell_release(n, &lr);
    #      nccell_release(n, &hl); nccell_release(n, &vl);
    #      return ret;
    #    }
    def self.ncplane_rounded_box(n, styles, channels, ystop, xstop, ctlword)
      ul, ur, ll, lr, hl, vl = Array.new(6) { NCCELL_TRIVIAL_INITIALIZER() }
      if (ret = nccells_rounded_box(n, styles, channels, ul, ur, ll, lr, hl, vl)).zero?
        ret = ncplane_box(n, ul, ur, ll, lr, hl, vl, ystop, xstop, ctlword)
      end
      [ul, ur, ll, lr, hl, vl].each { |c| nccell_release(n, c) }
      ret
    end

    # C: static inline int
    #    ncplane_perimeter_rounded(struct ncplane* n, uint16_t stylemask,
    #                              uint64_t channels, unsigned ctlword){
    #      if(ncplane_cursor_move_yx(n, 0, 0)){
    #        return -1;
    #      }
    #      unsigned dimy, dimx;
    #      ncplane_dim_yx(n, &dimy, &dimx);
    #      nccell ul = NCCELL_TRIVIAL_INITIALIZER;
    #      nccell ur = NCCELL_TRIVIAL_INITIALIZER;
    #      nccell ll = NCCELL_TRIVIAL_INITIALIZER;
    #      nccell lr = NCCELL_TRIVIAL_INITIALIZER;
    #      nccell vl = NCCELL_TRIVIAL_INITIALIZER;
    #      nccell hl = NCCELL_TRIVIAL_INITIALIZER;
    #      if(nccells_rounded_box(n, stylemask, channels, &ul, &ur, &ll, &lr, &hl, &vl)){
    #        return -1;
    #      }
    #      int r = ncplane_box_sized(n, &ul, &ur, &ll, &lr, &hl, &vl, dimy, dimx, ctlword);
    #      nccell_release(n, &ul); nccell_release(n, &ur);
    #      nccell_release(n, &ll); nccell_release(n, &lr);
    #      nccell_release(n, &hl); nccell_release(n, &vl);
    #      return r;
    #    }
    def self.ncplane_perimeter_rounded(n, stylemask, channels, ctlword)
      return -1 if ncplane_cursor_move_yx(n, 0, 0) != 0
      dimy = ::FFI::MemoryPointer.new(:uint)
      dimx = ::FFI::MemoryPointer.new(:uint)
      ncplane_dim_yx(n, dimy, dimx)
      ul, ur, ll, lr, hl, vl = Array.new(6) { NCCELL_TRIVIAL_INITIALIZER() }
      return -1 if nccells_rounded_box(n, stylemask, channels, ul, ur, ll, lr, hl, vl) != 0
      r = ncplane_box_sized(n, ul, ur, ll, lr, hl, vl, dimy.read_uint, dimx.read_uint, ctlword)
      [ul, ur, ll, lr, hl, vl].each { |c| nccell_release(n, c) }
      r
    end

    # C: static inline int
    #    ncplane_rounded_box_sized(struct ncplane* n, uint16_t styles, uint64_t channels,
    #                              unsigned ylen, unsigned xlen, unsigned ctlword){
    #      unsigned y, x;
    #      ncplane_cursor_yx(n, &y, &x);
    #      return ncplane_rounded_box(n, styles, channels, y + ylen - 1,
    #                                 x + xlen - 1, ctlword);
    #    }
    def self.ncplane_rounded_box_sized(n, styles, channels, ylen, xlen, ctlword)
      y = ::FFI::MemoryPointer.new(:uint)
      x = ::FFI::MemoryPointer.new(:uint)
      ncplane_cursor_yx(n, y, x)
      ncplane_rounded_box(n, styles, channels, (y.read_uint + ylen - 1) & 0xffff_ffff,
                          (x.read_uint + xlen - 1) & 0xffff_ffff, ctlword)
    end

    # C: static inline int
    #    ncplane_double_box(struct ncplane* n, uint16_t styles, uint64_t channels,
    #                       unsigned ylen, unsigned xlen, unsigned ctlword){
    #      int ret = 0;
    #      nccell ul = NCCELL_TRIVIAL_INITIALIZER, ur = NCCELL_TRIVIAL_INITIALIZER;
    #      nccell ll = NCCELL_TRIVIAL_INITIALIZER, lr = NCCELL_TRIVIAL_INITIALIZER;
    #      nccell hl = NCCELL_TRIVIAL_INITIALIZER, vl = NCCELL_TRIVIAL_INITIALIZER;
    #      if((ret = nccells_double_box(n, styles, channels, &ul, &ur, &ll, &lr, &hl, &vl)) == 0){
    #        ret = ncplane_box(n, &ul, &ur, &ll, &lr, &hl, &vl, ylen, xlen, ctlword);
    #      }
    #      nccell_release(n, &ul); nccell_release(n, &ur);
    #      nccell_release(n, &ll); nccell_release(n, &lr);
    #      nccell_release(n, &hl); nccell_release(n, &vl);
    #      return ret;
    #    }
    def self.ncplane_double_box(n, styles, channels, ylen, xlen, ctlword)
      ul, ur, ll, lr, hl, vl = Array.new(6) { NCCELL_TRIVIAL_INITIALIZER() }
      if (ret = nccells_double_box(n, styles, channels, ul, ur, ll, lr, hl, vl)).zero?
        ret = ncplane_box(n, ul, ur, ll, lr, hl, vl, ylen, xlen, ctlword)
      end
      [ul, ur, ll, lr, hl, vl].each { |c| nccell_release(n, c) }
      ret
    end

    # C: static inline int
    #    ncplane_ascii_box(struct ncplane* n, uint16_t styles, uint64_t channels,
    #                      unsigned ylen, unsigned xlen, unsigned ctlword){
    #      int ret = 0;
    #      nccell ul = NCCELL_TRIVIAL_INITIALIZER, ur = NCCELL_TRIVIAL_INITIALIZER;
    #      nccell ll = NCCELL_TRIVIAL_INITIALIZER, lr = NCCELL_TRIVIAL_INITIALIZER;
    #      nccell hl = NCCELL_TRIVIAL_INITIALIZER, vl = NCCELL_TRIVIAL_INITIALIZER;
    #      if((ret = nccells_ascii_box(n, styles, channels, &ul, &ur, &ll, &lr, &hl, &vl)) == 0){
    #        ret = ncplane_box(n, &ul, &ur, &ll, &lr, &hl, &vl, ylen, xlen, ctlword);
    #      }
    #      nccell_release(n, &ul); nccell_release(n, &ur);
    #      nccell_release(n, &ll); nccell_release(n, &lr);
    #      nccell_release(n, &hl); nccell_release(n, &vl);
    #      return ret;
    #    }
    def self.ncplane_ascii_box(n, styles, channels, ylen, xlen, ctlword)
      ul, ur, ll, lr, hl, vl = Array.new(6) { NCCELL_TRIVIAL_INITIALIZER() }
      if (ret = nccells_ascii_box(n, styles, channels, ul, ur, ll, lr, hl, vl)).zero?
        ret = ncplane_box(n, ul, ur, ll, lr, hl, vl, ylen, xlen, ctlword)
      end
      [ul, ur, ll, lr, hl, vl].each { |c| nccell_release(n, c) }
      ret
    end

    # C: static inline int
    #    ncplane_perimeter_double(struct ncplane* n, uint16_t stylemask,
    #                             uint64_t channels, unsigned ctlword){
    #      if(ncplane_cursor_move_yx(n, 0, 0)){
    #        return -1;
    #      }
    #      unsigned dimy, dimx;
    #      ncplane_dim_yx(n, &dimy, &dimx);
    #      nccell ul = NCCELL_TRIVIAL_INITIALIZER;
    #      nccell ur = NCCELL_TRIVIAL_INITIALIZER;
    #      nccell ll = NCCELL_TRIVIAL_INITIALIZER;
    #      nccell lr = NCCELL_TRIVIAL_INITIALIZER;
    #      nccell vl = NCCELL_TRIVIAL_INITIALIZER;
    #      nccell hl = NCCELL_TRIVIAL_INITIALIZER;
    #      if(nccells_double_box(n, stylemask, channels, &ul, &ur, &ll, &lr, &hl, &vl)){
    #        return -1;
    #      }
    #      int r = ncplane_box_sized(n, &ul, &ur, &ll, &lr, &hl, &vl, dimy, dimx, ctlword);
    #      nccell_release(n, &ul); nccell_release(n, &ur);
    #      nccell_release(n, &ll); nccell_release(n, &lr);
    #      nccell_release(n, &hl); nccell_release(n, &vl);
    #      return r;
    #    }
    def self.ncplane_perimeter_double(n, stylemask, channels, ctlword)
      return -1 if ncplane_cursor_move_yx(n, 0, 0) != 0
      dimy = ::FFI::MemoryPointer.new(:uint)
      dimx = ::FFI::MemoryPointer.new(:uint)
      ncplane_dim_yx(n, dimy, dimx)
      ul, ur, ll, lr, hl, vl = Array.new(6) { NCCELL_TRIVIAL_INITIALIZER() }
      return -1 if nccells_double_box(n, stylemask, channels, ul, ur, ll, lr, hl, vl) != 0
      r = ncplane_box_sized(n, ul, ur, ll, lr, hl, vl, dimy.read_uint, dimx.read_uint, ctlword)
      [ul, ur, ll, lr, hl, vl].each { |c| nccell_release(n, c) }
      r
    end

    # C: static inline int
    #    ncplane_double_box_sized(struct ncplane* n, uint16_t styles, uint64_t channels,
    #                             unsigned ylen, unsigned xlen, unsigned ctlword){
    #      unsigned y, x;
    #      ncplane_cursor_yx(n, &y, &x);
    #      return ncplane_double_box(n, styles, channels, y + ylen - 1,
    #                                x + xlen - 1, ctlword);
    #    }
    def self.ncplane_double_box_sized(n, styles, channels, ylen, xlen, ctlword)
      y = ::FFI::MemoryPointer.new(:uint)
      x = ::FFI::MemoryPointer.new(:uint)
      ncplane_cursor_yx(n, y, x)
      ncplane_double_box(n, styles, channels, (y.read_uint + ylen - 1) & 0xffff_ffff,
                         (x.read_uint + xlen - 1) & 0xffff_ffff, ctlword)
    end

    # --- nccell (contenuto e stile) ---

    # C: #define NCCELL_INITIALIZER(c, s, chan) { .gcluster = (htole(c)), .gcluster_backstop = 0,\
    #      .width = (uint8_t)((wcwidth(c) < 0 || !c) ? 1 : wcwidth(c)), .stylemask = (s), .channels = (chan), }
    # NOTE: macro: c intero come nel C (gcluster = htole(c), larghezza da wcwidth((wchar_t)c)); restituisce un nuovo NcCell
    def self.NCCELL_INITIALIZER(c, s, chan)
      wc = ((c & 0xffff_ffff) ^ 0x8000_0000) - 0x8000_0000 # (wchar_t)c
      cell = NcCell.new
      cell[:gcluster] = htole(c)
      cell[:gcluster_backstop] = 0
      cell[:width] = (wcwidth(wc) < 0 || c.zero? ? 1 : wcwidth(wc)) & 0xff
      cell[:stylemask] = s & 0xffff
      cell[:channels] = chan & 0xffff_ffff_ffff_ffff
      cell
    end

    # C: #define NCCELL_CHAR_INITIALIZER(c) { .gcluster = (htole(c)), .gcluster_backstop = 0,\
    #      .width = (uint8_t)((wcwidth(c) < 0 || !c) ? 1 : wcwidth(c)), .stylemask = 0, .channels = 0, }
    # NOTE: macro: stessa espansione di NCCELL_INITIALIZER con stylemask 0 e channels 0; restituisce un nuovo NcCell
    def self.NCCELL_CHAR_INITIALIZER(c)
      NCCELL_INITIALIZER(c, 0, 0)
    end

    # C: #define NCCELL_TRIVIAL_INITIALIZER { .gcluster = 0, .gcluster_backstop = 0,\
    #                                         .width = 1, .stylemask = 0, .channels = 0, }
    # NOTE: macro oggetto: metodo senza argomenti, chiamarlo con le parentesi; restituisce un nuovo NcCell
    def self.NCCELL_TRIVIAL_INITIALIZER
      cell = NcCell.new # azzerata: gcluster, gcluster_backstop, stylemask e channels a 0
      cell[:width] = 1
      cell
    end

    # C: static inline void
    #    nccell_init(nccell* c){
    #      memset(c, 0, sizeof(*c));
    #    }
    def self.nccell_init(c)
      c.pointer.put_bytes(0, "\0" * NcCell.size)
      nil
    end

    # C: static inline int
    #    nccell_prime(struct ncplane* n, nccell* c, const char* gcluster,
    #                 uint16_t stylemask, uint64_t channels){
    #      c->stylemask = stylemask;
    #      c->channels = channels;
    #      int ret = nccell_load(n, c, gcluster);
    #      return ret;
    #    }
    # NOTE: gcluster con NUL interno: ArgumentError prima di scrivere la cella, come FFI su un parametro :string
    def self.nccell_prime(n, c, gcluster, stylemask, channels)
      raise ArgumentError, 'string contains null byte' if gcluster&.include?("\0")
      c[:stylemask] = stylemask & 0xffff
      c[:channels] = channels & 0xffff_ffff_ffff_ffff
      nccell_load(n, c, gcluster)
    end

    # C: static inline void
    #    nccell_set_styles(nccell* c, unsigned stylebits){
    #      c->stylemask = stylebits & NCSTYLE_MASK;
    #    }
    def self.nccell_set_styles(c, stylebits)
      c[:stylemask] = stylebits & NCSTYLE_MASK
      nil
    end

    # C: static inline uint16_t
    #    nccell_styles(const nccell* c){
    #      return c->stylemask;
    #    }
    def self.nccell_styles(c)
      c[:stylemask]
    end

    # C: static inline void
    #    nccell_on_styles(nccell* c, unsigned stylebits){
    #      c->stylemask |= (uint16_t)(stylebits & NCSTYLE_MASK);
    #    }
    def self.nccell_on_styles(c, stylebits)
      c[:stylemask] |= stylebits & NCSTYLE_MASK
      nil
    end

    # C: static inline void
    #    nccell_off_styles(nccell* c, unsigned stylebits){
    #      c->stylemask &= (uint16_t)~(stylebits & NCSTYLE_MASK);
    #    }
    def self.nccell_off_styles(c, stylebits)
      c[:stylemask] &= ~(stylebits & NCSTYLE_MASK)
      nil
    end

    # C: static inline bool
    #    nccell_double_wide_p(const nccell* c){
    #      return (c->width >= 2);
    #    }
    def self.nccell_double_wide_p(c)
      c[:width] >= 2
    end

    # C: static inline bool
    #    nccell_wide_right_p(const nccell* c){
    #      return nccell_double_wide_p(c) && c->gcluster == 0;
    #    }
    def self.nccell_wide_right_p(c)
      nccell_double_wide_p(c) && c[:gcluster] == 0
    end

    # C: static inline bool
    #    nccell_wide_left_p(const nccell* c){
    #      return nccell_double_wide_p(c) && c->gcluster;
    #    }
    def self.nccell_wide_left_p(c)
      nccell_double_wide_p(c) && c[:gcluster] != 0
    end

    # C: static inline unsigned
    #    nccell_cols(const nccell* c){
    #      return c->width ? c->width : 1;
    #    }
    def self.nccell_cols(c)
      c[:width] != 0 ? c[:width] : 1
    end

    # C: ALLOC static inline char*
    #    nccell_strdup(const struct ncplane* n, const nccell* c){
    #      return strdup(nccell_extended_gcluster(n, c));
    #    }
    # NOTE: risultato allocato con strdup (liberare con free)
    def self.nccell_strdup(n, c)
      strdup(nccell_extended_gcluster(n, c))
    end

    # C: static inline char*
    #    nccell_extract(const struct ncplane* n, const nccell* c,
    #                   uint16_t* stylemask, uint64_t* channels){
    #      if(stylemask){
    #        *stylemask = c->stylemask;
    #      }
    #      if(channels){
    #        *channels = c->channels;
    #      }
    #      return nccell_strdup(n, c);
    #    }
    # NOTE: risultato allocato con strdup (liberare con free)
    def self.nccell_extract(n, c, stylemask, channels)
      stylemask.write_uint16(c[:stylemask]) if stylemask && !stylemask.null?
      channels.write_uint64(c[:channels]) if channels && !channels.null?
      nccell_strdup(n, c)
    end

    # C: static inline bool
    #    nccellcmp(const struct ncplane* n1, const nccell* RESTRICT c1,
    #              const struct ncplane* n2, const nccell* RESTRICT c2){
    #      if(c1->stylemask != c2->stylemask){
    #        return true;
    #      }
    #      if(c1->channels != c2->channels){
    #        return true;
    #      }
    #      return strcmp(nccell_extended_gcluster(n1, c1), nccell_extended_gcluster(n2, c2));
    #    }
    def self.nccellcmp(n1, c1, n2, c2)
      return true if c1[:stylemask] != c2[:stylemask]
      return true if c1[:channels] != c2[:channels]
      nccell_extended_gcluster(n1, c1) != nccell_extended_gcluster(n2, c2)
    end

    # C: static inline int
    #    nccell_load_char(struct ncplane* n, nccell* c, char ch){
    #      char gcluster[2];
    #      gcluster[0] = ch;
    #      gcluster[1] = '\0';
    #      return nccell_load(n, c, gcluster);
    #    }
    def self.nccell_load_char(n, c, ch)
      byte = ch & 0xff
      nccell_load(n, c, byte.zero? ? '' : byte.chr) # la stringa C finisce al NUL
    end

    # C: static inline int
    #    nccell_load_egc32(struct ncplane* n, nccell* c, uint32_t egc){
    #      char gcluster[sizeof(egc) + 1];
    #      egc = htole(egc);
    #      memcpy(gcluster, &egc, sizeof(egc));
    #      gcluster[4] = '\0';
    #      return nccell_load(n, c, gcluster);
    #    }
    # NOTE: htole + memcpy resi con pack('V') (byte little-endian su ogni host), senza chiamare la macro htole
    def self.nccell_load_egc32(n, c, egc)
      gcluster = [egc & 0xffff_ffff].pack('V')
      i = gcluster.index("\0")
      gcluster = gcluster.byteslice(0, i) if i
      nccell_load(n, c, gcluster)
    end

    # C: static inline int
    #    nccell_load_ucs32(struct ncplane* n, nccell* c, uint32_t u){
    #      unsigned char utf8[WCHAR_MAX_UTF8BYTES];
    #      if(notcurses_ucs32_to_utf8(&u, 1, utf8, sizeof(utf8)) < 0){
    #        return -1;
    #      }
    #      uint32_t utf8asegc;
    #      _Static_assert(WCHAR_MAX_UTF8BYTES == sizeof(utf8asegc),
    #                     "WCHAR_MAX_UTF8BYTES didn't equal sizeof(uint32_t)");
    #      memcpy(&utf8asegc, utf8, sizeof(utf8));
    #      return nccell_load_egc32(n, c, utf8asegc);
    #    }
    # NOTE: il C non inizializza utf8[] oltre i byte scritti (UB con sequenze < 4 byte): qui il buffer è azzerato
    def self.nccell_load_ucs32(n, c, u)
      ucs = ::FFI::MemoryPointer.new(:uint32).write_uint32(u & 0xffff_ffff)
      utf8 = ::FFI::MemoryPointer.new(:uchar, WCHAR_MAX_UTF8BYTES)
      return -1 if notcurses_ucs32_to_utf8(ucs, 1, utf8, WCHAR_MAX_UTF8BYTES) < 0
      nccell_load_egc32(n, c, utf8.read_uint32)
    end

    # C: static inline int
    #    nccells_load_box(struct ncplane* n, uint16_t styles, uint64_t channels,
    #                     nccell* ul, nccell* ur, nccell* ll, nccell* lr,
    #                     nccell* hl, nccell* vl, const char* gclusters){
    #      int ulen;
    #      if((ulen = nccell_prime(n, ul, gclusters, styles, channels)) > 0){
    #        if((ulen = nccell_prime(n, ur, gclusters += ulen, styles, channels)) > 0){
    #          if((ulen = nccell_prime(n, ll, gclusters += ulen, styles, channels)) > 0){
    #            if((ulen = nccell_prime(n, lr, gclusters += ulen, styles, channels)) > 0){
    #              if((ulen = nccell_prime(n, hl, gclusters += ulen, styles, channels)) > 0){
    #                if(nccell_prime(n, vl, gclusters + ulen, styles, channels) > 0){
    #                  return 0;
    #                }
    #                nccell_release(n, hl);
    #              }
    #              nccell_release(n, lr);
    #            }
    #            nccell_release(n, ll);
    #          }
    #          nccell_release(n, ur);
    #        }
    #        nccell_release(n, ul);
    #      }
    #      return -1;
    #    }
    # NOTE: gclusters nil: nel C è UB (utf8_egc_len(NULL) legge wc non inizializzato: width casuale su ul, raro NULL deref); qui NoMethodError prima di toccare le celle
    def self.nccells_load_box(n, styles, channels, ul, ur, ll, lr, hl, vl, gclusters)
      # le nccell_prime annidate del C: al primo fallimento rilascia le celle già caricate, in ordine inverso
      cells = [ul, ur, ll, lr, hl, vl]
      off = 0
      cells.each_with_index do |cell, i|
        ulen = nccell_prime(n, cell, gclusters.byteslice(off..), styles, channels)
        if ulen <= 0
          cells[0, i].reverse_each { |loaded| nccell_release(n, loaded) }
          return -1
        end
        off += ulen
      end
      0
    end

    # C: static inline int
    #    nccells_ascii_box(struct ncplane* n, uint16_t attr, uint64_t channels,
    #                      nccell* ul, nccell* ur, nccell* ll, nccell* lr, nccell* hl, nccell* vl){
    #      return nccells_load_box(n, attr, channels, ul, ur, ll, lr, hl, vl, NCBOXASCII);
    #    }
    def self.nccells_ascii_box(n, attr, channels, ul, ur, ll, lr, hl, vl)
      nccells_load_box(n, attr, channels, ul, ur, ll, lr, hl, vl, NCBOXASCII)
    end

    # C: static inline int
    #    nccells_double_box(struct ncplane* n, uint16_t attr, uint64_t channels,
    #                       nccell* ul, nccell* ur, nccell* ll, nccell* lr, nccell* hl, nccell* vl){
    #      if(notcurses_canutf8(ncplane_notcurses(n))){
    #        return nccells_load_box(n, attr, channels, ul, ur, ll, lr, hl, vl, NCBOXDOUBLE);
    #      }
    #      return nccells_ascii_box(n, attr, channels, ul, ur, ll, lr, hl, vl);
    #    }
    def self.nccells_double_box(n, attr, channels, ul, ur, ll, lr, hl, vl)
      if notcurses_canutf8(ncplane_notcurses(n))
        return nccells_load_box(n, attr, channels, ul, ur, ll, lr, hl, vl, NCBOXDOUBLE)
      end
      nccells_ascii_box(n, attr, channels, ul, ur, ll, lr, hl, vl)
    end

    # C: static inline int
    #    nccells_rounded_box(struct ncplane* n, uint16_t attr, uint64_t channels,
    #                        nccell* ul, nccell* ur, nccell* ll, nccell* lr, nccell* hl, nccell* vl){
    #      if(notcurses_canutf8(ncplane_notcurses(n))){
    #        return nccells_load_box(n, attr, channels, ul, ur, ll, lr, hl, vl, NCBOXROUND);
    #      }
    #      return nccells_ascii_box(n, attr, channels, ul, ur, ll, lr, hl, vl);
    #    }
    def self.nccells_rounded_box(n, attr, channels, ul, ur, ll, lr, hl, vl)
      if notcurses_canutf8(ncplane_notcurses(n))
        return nccells_load_box(n, attr, channels, ul, ur, ll, lr, hl, vl, NCBOXROUND)
      end
      nccells_ascii_box(n, attr, channels, ul, ur, ll, lr, hl, vl)
    end

    # C: static inline int
    #    nccells_light_box(struct ncplane* n, uint16_t attr, uint64_t channels,
    #                      nccell* ul, nccell* ur, nccell* ll, nccell* lr, nccell* hl, nccell* vl){
    #      if(notcurses_canutf8(ncplane_notcurses(n))){
    #        return nccells_load_box(n, attr, channels, ul, ur, ll, lr, hl, vl, NCBOXLIGHT);
    #      }
    #      return nccells_ascii_box(n, attr, channels, ul, ur, ll, lr, hl, vl);
    #    }
    def self.nccells_light_box(n, attr, channels, ul, ur, ll, lr, hl, vl)
      if notcurses_canutf8(ncplane_notcurses(n))
        return nccells_load_box(n, attr, channels, ul, ur, ll, lr, hl, vl, NCBOXLIGHT)
      end
      nccells_ascii_box(n, attr, channels, ul, ur, ll, lr, hl, vl)
    end

    # C: static inline int
    #    nccells_heavy_box(struct ncplane* n, uint16_t attr, uint64_t channels,
    #                      nccell* ul, nccell* ur, nccell* ll, nccell* lr, nccell* hl, nccell* vl){
    #      if(notcurses_canutf8(ncplane_notcurses(n))){
    #        return nccells_load_box(n, attr, channels, ul, ur, ll, lr, hl, vl, NCBOXHEAVY);
    #      }
    #      return nccells_ascii_box(n, attr, channels, ul, ur, ll, lr, hl, vl);
    #    }
    def self.nccells_heavy_box(n, attr, channels, ul, ur, ll, lr, hl, vl)
      if notcurses_canutf8(ncplane_notcurses(n))
        return nccells_load_box(n, attr, channels, ul, ur, ll, lr, hl, vl, NCBOXHEAVY)
      end
      nccells_ascii_box(n, attr, channels, ul, ur, ll, lr, hl, vl)
    end

    # ═══════════════════════════════════════
    # Input
    # ═══════════════════════════════════════

    # --- nckey ---

    # C: #define preterunicode(w) ((w) + PRETERUNICODEBASE)
    # NOTE: macro: argomento int come i letterali C; dove il C andrebbe in overflow (UB) Ruby non tronca
    def self.preterunicode(w)
      w + PRETERUNICODEBASE
    end

    # C: static inline bool
    #    nckey_synthesized_p(uint32_t w){
    #      return w >= PRETERUNICODEBASE && w <= NCKEY_EOF;
    #    }
    def self.nckey_synthesized_p(w)
      (w & 0xffff_ffff).between?(PRETERUNICODEBASE, NCKEY_EOF)
    end

    # C: static inline bool
    #    nckey_pua_p(uint32_t w){
    #      return w >= 0xe000 && w <= 0xf8ff; // 6,400 codepoints
    #    }
    def self.nckey_pua_p(w)
      (w & 0xffff_ffff).between?(0xe000, 0xf8ff)
    end

    # C: static inline bool
    #    nckey_supppuaa_p(uint32_t w){
    #      return w >= 0xf0000 && w <= 0xffffd; // 65,534 codepoints
    #    }
    def self.nckey_supppuaa_p(w)
      (w & 0xffff_ffff).between?(0xf0000, 0xffffd)
    end

    # C: static inline bool
    #    nckey_supppuab_p(uint32_t w){
    #      return w >= 0x100000 && w <= 0x10fffd; // 65,534 codepoints
    #    }
    def self.nckey_supppuab_p(w)
      (w & 0xffff_ffff).between?(0x100000, 0x10fffd)
    end

    # C: static inline bool
    #    nckey_mouse_p(uint32_t r){
    #      return r >= NCKEY_MOTION && r <= NCKEY_BUTTON11;
    #    }
    def self.nckey_mouse_p(r)
      (r & 0xffff_ffff).between?(NCKEY_MOTION, NCKEY_BUTTON11)
    end

    # --- ncinput ---

    # C: static inline bool
    #    ncinput_shift_p(const ncinput* n){
    #      return (n->modifiers & NCKEY_MOD_SHIFT);
    #    }
    def self.ncinput_shift_p(n)
      (n[:modifiers] & NCKEY_MOD_SHIFT) != 0
    end

    # C: static inline bool
    #    ncinput_ctrl_p(const ncinput* n){
    #      return (n->modifiers & NCKEY_MOD_CTRL);
    #    }
    def self.ncinput_ctrl_p(n)
      (n[:modifiers] & NCKEY_MOD_CTRL) != 0
    end

    # C: static inline bool
    #    ncinput_alt_p(const ncinput* n){
    #      return (n->modifiers & NCKEY_MOD_ALT);
    #    }
    def self.ncinput_alt_p(n)
      (n[:modifiers] & NCKEY_MOD_ALT) != 0
    end

    # C: static inline bool
    #    ncinput_meta_p(const ncinput* n){
    #      return (n->modifiers & NCKEY_MOD_META);
    #    }
    def self.ncinput_meta_p(n)
      (n[:modifiers] & NCKEY_MOD_META) != 0
    end

    # C: static inline bool
    #    ncinput_super_p(const ncinput* n){
    #      return (n->modifiers & NCKEY_MOD_SUPER);
    #    }
    def self.ncinput_super_p(n)
      (n[:modifiers] & NCKEY_MOD_SUPER) != 0
    end

    # C: static inline bool
    #    ncinput_hyper_p(const ncinput* n){
    #      return (n->modifiers & NCKEY_MOD_HYPER);
    #    }
    def self.ncinput_hyper_p(n)
      (n[:modifiers] & NCKEY_MOD_HYPER) != 0
    end

    # C: static inline bool
    #    ncinput_capslock_p(const ncinput* n){
    #      return (n->modifiers & NCKEY_MOD_CAPSLOCK);
    #    }
    def self.ncinput_capslock_p(n)
      (n[:modifiers] & NCKEY_MOD_CAPSLOCK) != 0
    end

    # C: static inline bool
    #    ncinput_numlock_p(const ncinput* n){
    #      return (n->modifiers & NCKEY_MOD_NUMLOCK);
    #    }
    def self.ncinput_numlock_p(n)
      (n[:modifiers] & NCKEY_MOD_NUMLOCK) != 0
    end

    # C: static inline bool
    #    ncinput_equal_p(const ncinput* n1, const ncinput* n2){
    #      // don't need to check ->utf8; it's derived from id
    #      if(n1->id != n2->id){
    #        return false;
    #      }
    #      if(n1->y != n2->y || n1->x != n2->x){
    #        return false;
    #      }
    #      // don't need to check deprecated alt, ctrl, shift
    #      if((n1->modifiers & ~(unsigned)(NCKEY_MOD_CAPSLOCK | NCKEY_MOD_NUMLOCK))
    #          != (n2->modifiers & ~(unsigned)(NCKEY_MOD_CAPSLOCK | NCKEY_MOD_NUMLOCK))){
    #        return false;
    #      }
    #      if(n1->evtype != n2->evtype){
    #        if((n1->evtype != NCTYPE_UNKNOWN && n1->evtype != NCTYPE_PRESS) ||
    #           (n2->evtype != NCTYPE_UNKNOWN && n2->evtype != NCTYPE_PRESS)){
    #          return false;
    #        }
    #      }
    #      if(n1->ypx != n2->ypx || n1->xpx != n2->xpx){
    #        return false;
    #      }
    #      return true;
    #    }
    def self.ncinput_equal_p(n1, n2)
      return false if n1[:id] != n2[:id]
      return false if n1[:y] != n2[:y] || n1[:x] != n2[:x]
      lockmask = ~(NCKEY_MOD_CAPSLOCK | NCKEY_MOD_NUMLOCK)
      return false if (n1[:modifiers] & lockmask) != (n2[:modifiers] & lockmask)
      if n1[:evtype] != n2[:evtype]
        if (n1[:evtype] != NCTYPE_UNKNOWN && n1[:evtype] != NCTYPE_PRESS) ||
           (n2[:evtype] != NCTYPE_UNKNOWN && n2[:evtype] != NCTYPE_PRESS)
          return false
        end
      end
      return false if n1[:ypx] != n2[:ypx] || n1[:xpx] != n2[:xpx]
      true
    end

    # C: static inline bool
    #    ncinput_nomod_p(const ncinput* ni){
    #      return !(ni->modifiers);
    #    }
    def self.ncinput_nomod_p(ni)
      ni[:modifiers] == 0
    end

    # --- lettura ---

    # C: static inline uint32_t
    #    notcurses_get_nblock(struct notcurses* n, ncinput* ni){
    #      struct timespec ts = { .tv_sec = 0, .tv_nsec = 0 };
    #      return notcurses_get(n, &ts, ni);
    #    }
    def self.notcurses_get_nblock(n, ni)
      notcurses_get(n, Timespec.new, ni) # Timespec.new = { .tv_sec = 0, .tv_nsec = 0 }
    end

    # C: static inline uint32_t
    #    notcurses_get_blocking(struct notcurses* n, ncinput* ni){
    #      return notcurses_get(n, NULL, ni);
    #    }
    def self.notcurses_get_blocking(n, ni)
      notcurses_get(n, nil, ni)
    end

    # --- mouse e segnali ---

    # C: __attribute__ ((nonnull (1))) static inline int
    #    notcurses_mice_disable(struct notcurses* n){
    #      return notcurses_mice_enable(n, NCMICE_NO_EVENTS);
    #    }
    def self.notcurses_mice_disable(n)
      notcurses_mice_enable(n, NCMICE_NO_EVENTS)
    end

    # ═══════════════════════════════════════
    # Channels / Colors
    # ═══════════════════════════════════════

    # --- ncchannel ---

    # C: #define NCCHANNEL_INITIALIZER(r, g, b) \
    #      (((uint32_t)(r) << 16u) + ((uint32_t)(g) << 8u) + (b) + NC_BGDEFAULT_MASK)
    # NOTE: macro: argomenti int come i letterali C
    # NOTE: comportamento C replicato: somma troncata a 32 bit, poi + NC_BGDEFAULT_MASK (ull): può superare 0xffffffff
    def self.NCCHANNEL_INITIALIZER(r, g, b)
      (((r << 16) + (g << 8) + b) & 0xffff_ffff) + NC_BGDEFAULT_MASK
    end

    # C: static inline uint32_t
    #    ncchannel_alpha(uint32_t channel){
    #      return channel & NC_BG_ALPHA_MASK;
    #    }
    def self.ncchannel_alpha(channel)
      channel & NC_BG_ALPHA_MASK
    end

    # C: static inline int
    #    ncchannel_set_alpha(uint32_t* channel, unsigned alpha){
    #      if(alpha & ~NC_BG_ALPHA_MASK){
    #        return -1;
    #      }
    #      *channel = (uint32_t)alpha | (*channel & (uint32_t)~NC_BG_ALPHA_MASK);
    #      if(alpha != NCALPHA_OPAQUE){
    #        *channel |= NC_BGDEFAULT_MASK;
    #      }
    #      return 0;
    #    }
    def self.ncchannel_set_alpha(channel, alpha)
      alpha &= 0xffff_ffff
      return -1 if (alpha & ~NC_BG_ALPHA_MASK) != 0
      channel.write_uint32(alpha | (channel.read_uint32 & ~NC_BG_ALPHA_MASK))
      channel.write_uint32(channel.read_uint32 | NC_BGDEFAULT_MASK) if alpha != NCALPHA_OPAQUE
      0
    end

    # C: static inline bool
    #    ncchannel_default_p(uint32_t channel){
    #      return !(channel & NC_BGDEFAULT_MASK);
    #    }
    def self.ncchannel_default_p(channel)
      (channel & NC_BGDEFAULT_MASK) == 0
    end

    # C: static inline uint32_t
    #    ncchannel_set_default(uint32_t* channel){
    #      *channel &= (uint32_t)~NC_BGDEFAULT_MASK; // turn off not-default bit
    #      ncchannel_set_alpha(channel, NCALPHA_OPAQUE);
    #      return *channel;
    #    }
    def self.ncchannel_set_default(channel)
      channel.write_uint32(channel.read_uint32 & ~NC_BGDEFAULT_MASK)
      ncchannel_set_alpha(channel, NCALPHA_OPAQUE)
      channel.read_uint32
    end

    # C: static inline bool
    #    ncchannel_palindex_p(uint32_t channel){
    #      return !ncchannel_default_p(channel) && (channel & NC_BG_PALETTE);
    #    }
    def self.ncchannel_palindex_p(channel)
      !ncchannel_default_p(channel) && (channel & NC_BG_PALETTE) != 0
    end

    # C: static inline unsigned
    #    ncchannel_palindex(uint32_t channel){
    #      return channel & 0xff;
    #    }
    def self.ncchannel_palindex(channel)
      channel & 0xff
    end

    # C: static inline int
    #    ncchannel_set_palindex(uint32_t* channel, unsigned idx){
    #      if(idx >= NCPALETTESIZE){
    #        return -1;
    #      }
    #      ncchannel_set_alpha(channel, NCALPHA_OPAQUE);
    #      *channel &= 0xff000000ull;
    #      *channel |= NC_BGDEFAULT_MASK | NC_BG_PALETTE | idx;
    #      return 0;
    #    }
    def self.ncchannel_set_palindex(channel, idx)
      idx &= 0xffff_ffff
      return -1 if idx >= NCPALETTESIZE
      ncchannel_set_alpha(channel, NCALPHA_OPAQUE)
      channel.write_uint32(channel.read_uint32 & 0xff00_0000)
      channel.write_uint32(channel.read_uint32 | NC_BGDEFAULT_MASK | NC_BG_PALETTE | idx)
      0
    end

    # C: static inline bool
    #    ncchannel_rgb_p(uint32_t channel){
    #      return !(ncchannel_default_p(channel) || ncchannel_palindex_p(channel));
    #    }
    def self.ncchannel_rgb_p(channel)
      !(ncchannel_default_p(channel) || ncchannel_palindex_p(channel))
    end

    # C: static inline unsigned
    #    ncchannel_r(uint32_t channel){
    #      return (channel & 0xff0000u) >> 16u;
    #    }
    def self.ncchannel_r(channel)
      (channel & 0xff0000) >> 16
    end

    # C: static inline unsigned
    #    ncchannel_g(uint32_t channel){
    #      return (channel & 0x00ff00u) >> 8u;
    #    }
    def self.ncchannel_g(channel)
      (channel & 0x00ff00) >> 8
    end

    # C: static inline unsigned
    #    ncchannel_b(uint32_t channel){
    #      return (channel & 0x0000ffu);
    #    }
    def self.ncchannel_b(channel)
      channel & 0x0000ff
    end

    # C: static inline uint32_t
    #    ncchannel_rgb(uint32_t channel){
    #      return channel & NC_BG_RGB_MASK;
    #    }
    def self.ncchannel_rgb(channel)
      channel & NC_BG_RGB_MASK
    end

    # C: static inline uint32_t
    #    ncchannel_rgb8(uint32_t channel, unsigned* RESTRICT r, unsigned* RESTRICT g,
    #                   unsigned* RESTRICT b){
    #      *r = ncchannel_r(channel);
    #      *g = ncchannel_g(channel);
    #      *b = ncchannel_b(channel);
    #      return channel;
    #    }
    def self.ncchannel_rgb8(channel, r, g, b)
      r.write_uint(ncchannel_r(channel))
      g.write_uint(ncchannel_g(channel))
      b.write_uint(ncchannel_b(channel))
      channel & 0xffff_ffff
    end

    # C: static inline int
    #    ncchannel_set_rgb8(uint32_t* channel, unsigned r, unsigned g, unsigned b){
    #      if(r >= 256 || g >= 256 || b >= 256){
    #        return -1;
    #      }
    #      uint32_t c = (r << 16u) | (g << 8u) | b;
    #      // clear the existing rgb bits, clear the palette index indicator, set
    #      // the not-default bit, and or in the new rgb.
    #      *channel = (uint32_t)((*channel & ~(NC_BG_RGB_MASK | NC_BG_PALETTE)) | NC_BGDEFAULT_MASK | c);
    #      return 0;
    #    }
    def self.ncchannel_set_rgb8(channel, r, g, b)
      r &= 0xffff_ffff
      g &= 0xffff_ffff
      b &= 0xffff_ffff
      return -1 if r >= 256 || g >= 256 || b >= 256
      c = (r << 16) | (g << 8) | b
      channel.write_uint32((channel.read_uint32 & ~(NC_BG_RGB_MASK | NC_BG_PALETTE)) | NC_BGDEFAULT_MASK | c)
      0
    end

    # C: static inline int
    #    ncchannel_set(uint32_t* channel, uint32_t rgb){
    #      if(rgb > 0xffffffu){
    #        return -1;
    #      }
    #      *channel = (uint32_t)((*channel & ~(NC_BG_RGB_MASK | NC_BG_PALETTE)) | NC_BGDEFAULT_MASK | rgb);
    #      return 0;
    #    }
    def self.ncchannel_set(channel, rgb)
      rgb &= 0xffff_ffff
      return -1 if rgb > 0xffffff
      channel.write_uint32((channel.read_uint32 & ~(NC_BG_RGB_MASK | NC_BG_PALETTE)) | NC_BGDEFAULT_MASK | rgb)
      0
    end

    # C: static inline void
    #    ncchannel_set_rgb8_clipped(uint32_t* channel, int r, int g, int b){
    #      if(r >= 256){
    #        r = 255;
    #      }
    #      if(g >= 256){
    #        g = 255;
    #      }
    #      if(b >= 256){
    #        b = 255;
    #      }
    #      if(r <= -1){
    #        r = 0;
    #      }
    #      if(g <= -1){
    #        g = 0;
    #      }
    #      if(b <= -1){
    #        b = 0;
    #      }
    #      uint32_t c = (uint32_t)((r << 16u) | (g << 8u) | b);
    #      *channel = (uint32_t)((*channel & ~(NC_BG_RGB_MASK | NC_BG_PALETTE)) | NC_BGDEFAULT_MASK | c);
    #    }
    def self.ncchannel_set_rgb8_clipped(channel, r, g, b)
      c = (r.clamp(0, 255) << 16) | (g.clamp(0, 255) << 8) | b.clamp(0, 255)
      channel.write_uint32((channel.read_uint32 & ~(NC_BG_RGB_MASK | NC_BG_PALETTE)) | NC_BGDEFAULT_MASK | c)
      nil
    end

    # --- ncchannels ---

    # C: #define NCCHANNELS_INITIALIZER(fr, fg, fb, br, bg, bb) \
    #      ((NCCHANNEL_INITIALIZER((fr), (fg), (fb)) << 32ull) + \
    #       (NCCHANNEL_INITIALIZER((br), (bg), (bb))))
    def self.NCCHANNELS_INITIALIZER(fr, fg, fb, br, bg, bb)
      ((NCCHANNEL_INITIALIZER(fr, fg, fb) << 32) + NCCHANNEL_INITIALIZER(br, bg, bb)) & 0xffff_ffff_ffff_ffff
    end

    # C: static inline uint32_t
    #    ncchannels_bchannel(uint64_t channels){
    #      return channels & (NC_BG_RGB_MASK | NC_BG_PALETTE |
    #                         NC_BGDEFAULT_MASK | NC_BG_ALPHA_MASK);
    #    }
    def self.ncchannels_bchannel(channels)
      channels & (NC_BG_RGB_MASK | NC_BG_PALETTE | NC_BGDEFAULT_MASK | NC_BG_ALPHA_MASK)
    end

    # C: static inline uint32_t
    #    ncchannels_fchannel(uint64_t channels){
    #      return ncchannels_bchannel(channels >> 32u);
    #    }
    def self.ncchannels_fchannel(channels)
      ncchannels_bchannel((channels & 0xffff_ffff_ffff_ffff) >> 32)
    end

    # C: static inline uint64_t
    #    ncchannels_channels(uint64_t channels){
    #      return ncchannels_bchannel(channels) |
    #             ((uint64_t)ncchannels_fchannel(channels) << 32u);
    #    }
    def self.ncchannels_channels(channels)
      ncchannels_bchannel(channels) | (ncchannels_fchannel(channels) << 32)
    end

    # C: static inline bool
    #    ncchannels_bg_rgb_p(uint64_t channels){
    #      return ncchannel_rgb_p(ncchannels_bchannel(channels));
    #    }
    def self.ncchannels_bg_rgb_p(channels)
      ncchannel_rgb_p(ncchannels_bchannel(channels))
    end

    # C: static inline bool
    #    ncchannels_fg_rgb_p(uint64_t channels){
    #      return ncchannel_rgb_p(ncchannels_fchannel(channels));
    #    }
    def self.ncchannels_fg_rgb_p(channels)
      ncchannel_rgb_p(ncchannels_fchannel(channels))
    end

    # C: static inline unsigned
    #    ncchannels_bg_alpha(uint64_t channels){
    #      return ncchannel_alpha(ncchannels_bchannel(channels));
    #    }
    def self.ncchannels_bg_alpha(channels)
      ncchannel_alpha(ncchannels_bchannel(channels))
    end

    # C: static inline uint64_t
    #    ncchannels_set_bchannel(uint64_t* channels, uint32_t channel){
    #      // drop the background color and alpha bit
    #      *channels &= ((0xffffffffllu << 32u) | NC_NOBACKGROUND_MASK);
    #      *channels |= (uint32_t)(channel & ~NC_NOBACKGROUND_MASK);
    #      return *channels;
    #    }
    def self.ncchannels_set_bchannel(channels, channel)
      channel &= 0xffff_ffff
      channels.write_uint64(channels.read_uint64 & ((0xffff_ffff << 32) | NC_NOBACKGROUND_MASK))
      channels.write_uint64(channels.read_uint64 | (channel & ~NC_NOBACKGROUND_MASK))
      channels.read_uint64
    end

    # C: static inline uint64_t
    #    ncchannels_set_fchannel(uint64_t* channels, uint32_t channel){
    #      // drop the foreground color and alpha bit
    #      *channels &= (0xffffffffllu | ((uint64_t)NC_NOBACKGROUND_MASK << 32u));
    #      *channels |= (uint64_t)(channel & ~NC_NOBACKGROUND_MASK) << 32u;
    #      return *channels;
    #    }
    # NOTE: comportamento C replicato: (uint64_t)NC_NOBACKGROUND_MASK << 32u vale 0, bit NOBACKGROUND non conservati
    def self.ncchannels_set_fchannel(channels, channel)
      channel &= 0xffff_ffff
      keep = 0xffff_ffff | ((NC_NOBACKGROUND_MASK << 32) & 0xffff_ffff_ffff_ffff)
      channels.write_uint64(channels.read_uint64 & keep)
      channels.write_uint64(channels.read_uint64 | ((channel & ~NC_NOBACKGROUND_MASK) << 32))
      channels.read_uint64
    end

    # C: static inline uint64_t
    #    ncchannels_set_channels(uint64_t* dst, uint64_t channels){
    #      ncchannels_set_bchannel(dst, channels & 0xffffffffull);
    #      ncchannels_set_fchannel(dst, (uint32_t)((channels >> 32u) & 0xffffffffull));
    #      return *dst;
    #    }
    def self.ncchannels_set_channels(dst, channels)
      channels &= 0xffff_ffff_ffff_ffff
      ncchannels_set_bchannel(dst, channels & 0xffff_ffff)
      ncchannels_set_fchannel(dst, (channels >> 32) & 0xffff_ffff)
      dst.read_uint64
    end

    # C: static inline int
    #    ncchannels_set_bg_alpha(uint64_t* channels, unsigned alpha){
    #      if(alpha == NCALPHA_HIGHCONTRAST){ // forbidden for background alpha
    #        return -1;
    #      }
    #      uint32_t channel = ncchannels_bchannel(*channels);
    #      if(ncchannel_set_alpha(&channel, alpha) < 0){
    #        return -1;
    #      }
    #      ncchannels_set_bchannel(channels, channel);
    #      return 0;
    #    }
    def self.ncchannels_set_bg_alpha(channels, alpha)
      return -1 if (alpha & 0xffff_ffff) == NCALPHA_HIGHCONTRAST
      channel = ::FFI::MemoryPointer.new(:uint32).write_uint32(ncchannels_bchannel(channels.read_uint64))
      return -1 if ncchannel_set_alpha(channel, alpha) < 0
      ncchannels_set_bchannel(channels, channel.read_uint32)
      0
    end

    # C: static inline unsigned
    #    ncchannels_fg_alpha(uint64_t channels){
    #      return ncchannel_alpha(ncchannels_fchannel(channels));
    #    }
    def self.ncchannels_fg_alpha(channels)
      ncchannel_alpha(ncchannels_fchannel(channels))
    end

    # C: static inline int
    #    ncchannels_set_fg_alpha(uint64_t* channels, unsigned alpha){
    #      uint32_t channel = ncchannels_fchannel(*channels);
    #      if(ncchannel_set_alpha(&channel, alpha) < 0){
    #        return -1;
    #      }
    #      *channels = ((uint64_t)channel << 32llu) | (*channels & 0xffffffffllu);
    #      return 0;
    #    }
    def self.ncchannels_set_fg_alpha(channels, alpha)
      channel = ::FFI::MemoryPointer.new(:uint32).write_uint32(ncchannels_fchannel(channels.read_uint64))
      return -1 if ncchannel_set_alpha(channel, alpha) < 0
      channels.write_uint64((channel.read_uint32 << 32) | (channels.read_uint64 & 0xffff_ffff))
      0
    end

    # C: static inline uint64_t
    #    ncchannels_reverse(uint64_t channels){
    #      const uint64_t raw = ((uint64_t)ncchannels_bchannel(channels) << 32u) +
    #                           ncchannels_fchannel(channels);
    #      const uint64_t statemask = ((NC_NOBACKGROUND_MASK | NC_BG_ALPHA_MASK) << 32u) |
    #                                 NC_NOBACKGROUND_MASK | NC_BG_ALPHA_MASK;
    #      uint64_t ret = raw & ~statemask;
    #      ret |= channels & statemask;
    #      if(ncchannels_bg_alpha(ret) != NCALPHA_OPAQUE){
    #        if(!ncchannels_bg_rgb_p(ret)){
    #          ncchannels_set_bg_alpha(&ret, NCALPHA_OPAQUE);
    #        }
    #      }
    #      if(ncchannels_fg_alpha(ret) != NCALPHA_OPAQUE){
    #        if(!ncchannels_fg_rgb_p(ret)){
    #          ncchannels_set_fg_alpha(&ret, NCALPHA_OPAQUE);
    #        }
    #      }
    #      return ret;
    #    }
    def self.ncchannels_reverse(channels)
      raw = (ncchannels_bchannel(channels) << 32) + ncchannels_fchannel(channels)
      statemask = (((NC_NOBACKGROUND_MASK | NC_BG_ALPHA_MASK) << 32) & 0xffff_ffff_ffff_ffff) |
                  NC_NOBACKGROUND_MASK | NC_BG_ALPHA_MASK
      ret = ::FFI::MemoryPointer.new(:uint64).write_uint64((raw & ~statemask) | (channels & statemask))
      if ncchannels_bg_alpha(ret.read_uint64) != NCALPHA_OPAQUE && !ncchannels_bg_rgb_p(ret.read_uint64)
        ncchannels_set_bg_alpha(ret, NCALPHA_OPAQUE)
      end
      if ncchannels_fg_alpha(ret.read_uint64) != NCALPHA_OPAQUE && !ncchannels_fg_rgb_p(ret.read_uint64)
        ncchannels_set_fg_alpha(ret, NCALPHA_OPAQUE)
      end
      ret.read_uint64
    end

    # C: static inline uint64_t
    #    ncchannels_combine(uint32_t fchan, uint32_t bchan){
    #      uint64_t channels = 0;
    #      ncchannels_set_fchannel(&channels, fchan);
    #      ncchannels_set_bchannel(&channels, bchan);
    #      return channels;
    #    }
    def self.ncchannels_combine(fchan, bchan)
      channels = ::FFI::MemoryPointer.new(:uint64)
      ncchannels_set_fchannel(channels, fchan)
      ncchannels_set_bchannel(channels, bchan)
      channels.read_uint64
    end

    # C: static inline unsigned
    #    ncchannels_fg_palindex(uint64_t channels){
    #      return ncchannel_palindex(ncchannels_fchannel(channels));
    #    }
    def self.ncchannels_fg_palindex(channels)
      ncchannel_palindex(ncchannels_fchannel(channels))
    end

    # C: static inline unsigned
    #    ncchannels_bg_palindex(uint64_t channels){
    #      return ncchannel_palindex(ncchannels_bchannel(channels));
    #    }
    def self.ncchannels_bg_palindex(channels)
      ncchannel_palindex(ncchannels_bchannel(channels))
    end

    # C: static inline uint32_t
    #    ncchannels_fg_rgb(uint64_t channels){
    #      return ncchannel_rgb(ncchannels_fchannel(channels));
    #    }
    def self.ncchannels_fg_rgb(channels)
      ncchannel_rgb(ncchannels_fchannel(channels))
    end

    # C: static inline uint32_t
    #    ncchannels_bg_rgb(uint64_t channels){
    #      return ncchannel_rgb(ncchannels_bchannel(channels));
    #    }
    def self.ncchannels_bg_rgb(channels)
      ncchannel_rgb(ncchannels_bchannel(channels))
    end

    # C: static inline uint32_t
    #    ncchannels_fg_rgb8(uint64_t channels, unsigned* r, unsigned* g, unsigned* b){
    #      return ncchannel_rgb8(ncchannels_fchannel(channels), r, g, b);
    #    }
    def self.ncchannels_fg_rgb8(channels, r, g, b)
      ncchannel_rgb8(ncchannels_fchannel(channels), r, g, b)
    end

    # C: static inline uint32_t
    #    ncchannels_bg_rgb8(uint64_t channels, unsigned* r, unsigned* g, unsigned* b){
    #      return ncchannel_rgb8(ncchannels_bchannel(channels), r, g, b);
    #    }
    def self.ncchannels_bg_rgb8(channels, r, g, b)
      ncchannel_rgb8(ncchannels_bchannel(channels), r, g, b)
    end

    # C: static inline int
    #    ncchannels_set_fg_rgb8(uint64_t* channels, unsigned r, unsigned g, unsigned b){
    #      uint32_t channel = ncchannels_fchannel(*channels);
    #      if(ncchannel_set_rgb8(&channel, r, g, b) < 0){
    #        return -1;
    #      }
    #      *channels = ((uint64_t)channel << 32llu) | (*channels & 0xffffffffllu);
    #      return 0;
    #    }
    def self.ncchannels_set_fg_rgb8(channels, r, g, b)
      channel = ::FFI::MemoryPointer.new(:uint32).write_uint32(ncchannels_fchannel(channels.read_uint64))
      return -1 if ncchannel_set_rgb8(channel, r, g, b) < 0
      channels.write_uint64((channel.read_uint32 << 32) | (channels.read_uint64 & 0xffff_ffff))
      0
    end

    # C: static inline void
    #    ncchannels_set_fg_rgb8_clipped(uint64_t* channels, int r, int g, int b){
    #      uint32_t channel = ncchannels_fchannel(*channels);
    #      ncchannel_set_rgb8_clipped(&channel, r, g, b);
    #      *channels = ((uint64_t)channel << 32llu) | (*channels & 0xffffffffllu);
    #    }
    def self.ncchannels_set_fg_rgb8_clipped(channels, r, g, b)
      channel = ::FFI::MemoryPointer.new(:uint32).write_uint32(ncchannels_fchannel(channels.read_uint64))
      ncchannel_set_rgb8_clipped(channel, r, g, b)
      channels.write_uint64((channel.read_uint32 << 32) | (channels.read_uint64 & 0xffff_ffff))
      nil
    end

    # C: static inline int
    #    ncchannels_set_fg_palindex(uint64_t* channels, unsigned idx){
    #      uint32_t channel = ncchannels_fchannel(*channels);
    #      if(ncchannel_set_palindex(&channel, idx) < 0){
    #        return -1;
    #      }
    #      *channels = ((uint64_t)channel << 32llu) | (*channels & 0xffffffffllu);
    #      return 0;
    #    }
    def self.ncchannels_set_fg_palindex(channels, idx)
      channel = ::FFI::MemoryPointer.new(:uint32).write_uint32(ncchannels_fchannel(channels.read_uint64))
      return -1 if ncchannel_set_palindex(channel, idx) < 0
      channels.write_uint64((channel.read_uint32 << 32) | (channels.read_uint64 & 0xffff_ffff))
      0
    end

    # C: static inline int
    #    ncchannels_set_fg_rgb(uint64_t* channels, unsigned rgb){
    #      uint32_t channel = ncchannels_fchannel(*channels);
    #      if(ncchannel_set(&channel, rgb) < 0){
    #        return -1;
    #      }
    #      *channels = ((uint64_t)channel << 32llu) | (*channels & 0xffffffffllu);
    #      return 0;
    #    }
    def self.ncchannels_set_fg_rgb(channels, rgb)
      channel = ::FFI::MemoryPointer.new(:uint32).write_uint32(ncchannels_fchannel(channels.read_uint64))
      return -1 if ncchannel_set(channel, rgb) < 0
      channels.write_uint64((channel.read_uint32 << 32) | (channels.read_uint64 & 0xffff_ffff))
      0
    end

    # C: static inline int
    #    ncchannels_set_bg_rgb8(uint64_t* channels, unsigned r, unsigned g, unsigned b){
    #      uint32_t channel = ncchannels_bchannel(*channels);
    #      if(ncchannel_set_rgb8(&channel, r, g, b) < 0){
    #        return -1;
    #      }
    #      ncchannels_set_bchannel(channels, channel);
    #      return 0;
    #    }
    def self.ncchannels_set_bg_rgb8(channels, r, g, b)
      channel = ::FFI::MemoryPointer.new(:uint32).write_uint32(ncchannels_bchannel(channels.read_uint64))
      return -1 if ncchannel_set_rgb8(channel, r, g, b) < 0
      ncchannels_set_bchannel(channels, channel.read_uint32)
      0
    end

    # C: static inline void
    #    ncchannels_set_bg_rgb8_clipped(uint64_t* channels, int r, int g, int b){
    #      uint32_t channel = ncchannels_bchannel(*channels);
    #      ncchannel_set_rgb8_clipped(&channel, r, g, b);
    #      ncchannels_set_bchannel(channels, channel);
    #    }
    def self.ncchannels_set_bg_rgb8_clipped(channels, r, g, b)
      channel = ::FFI::MemoryPointer.new(:uint32).write_uint32(ncchannels_bchannel(channels.read_uint64))
      ncchannel_set_rgb8_clipped(channel, r, g, b)
      ncchannels_set_bchannel(channels, channel.read_uint32)
      nil
    end

    # C: static inline int
    #    ncchannels_set_bg_palindex(uint64_t* channels, unsigned idx){
    #      uint32_t channel = ncchannels_bchannel(*channels);
    #      if(ncchannel_set_palindex(&channel, idx) < 0){
    #        return -1;
    #      }
    #      ncchannels_set_bchannel(channels, channel);
    #      return 0;
    #    }
    def self.ncchannels_set_bg_palindex(channels, idx)
      channel = ::FFI::MemoryPointer.new(:uint32).write_uint32(ncchannels_bchannel(channels.read_uint64))
      return -1 if ncchannel_set_palindex(channel, idx) < 0
      ncchannels_set_bchannel(channels, channel.read_uint32)
      0
    end

    # C: static inline int
    #    ncchannels_set_bg_rgb(uint64_t* channels, unsigned rgb){
    #      uint32_t channel = ncchannels_bchannel(*channels);
    #      if(ncchannel_set(&channel, rgb) < 0){
    #        return -1;
    #      }
    #      ncchannels_set_bchannel(channels, channel);
    #      return 0;
    #    }
    def self.ncchannels_set_bg_rgb(channels, rgb)
      channel = ::FFI::MemoryPointer.new(:uint32).write_uint32(ncchannels_bchannel(channels.read_uint64))
      return -1 if ncchannel_set(channel, rgb) < 0
      ncchannels_set_bchannel(channels, channel.read_uint32)
      0
    end

    # C: static inline bool
    #    ncchannels_fg_default_p(uint64_t channels){
    #      return ncchannel_default_p(ncchannels_fchannel(channels));
    #    }
    def self.ncchannels_fg_default_p(channels)
      ncchannel_default_p(ncchannels_fchannel(channels))
    end

    # C: static inline bool
    #    ncchannels_fg_palindex_p(uint64_t channels){
    #      return ncchannel_palindex_p(ncchannels_fchannel(channels));
    #    }
    def self.ncchannels_fg_palindex_p(channels)
      ncchannel_palindex_p(ncchannels_fchannel(channels))
    end

    # C: static inline bool
    #    ncchannels_bg_default_p(uint64_t channels){
    #      return ncchannel_default_p(ncchannels_bchannel(channels));
    #    }
    def self.ncchannels_bg_default_p(channels)
      ncchannel_default_p(ncchannels_bchannel(channels))
    end

    # C: static inline bool
    #    ncchannels_bg_palindex_p(uint64_t channels){
    #      return ncchannel_palindex_p(ncchannels_bchannel(channels));
    #    }
    def self.ncchannels_bg_palindex_p(channels)
      ncchannel_palindex_p(ncchannels_bchannel(channels))
    end

    # C: static inline uint64_t
    #    ncchannels_set_fg_default(uint64_t* channels){
    #      uint32_t channel = ncchannels_fchannel(*channels);
    #      ncchannel_set_default(&channel);
    #      ncchannels_set_fchannel(channels, channel);
    #      return *channels;
    #    }
    def self.ncchannels_set_fg_default(channels)
      channel = ::FFI::MemoryPointer.new(:uint32).write_uint32(ncchannels_fchannel(channels.read_uint64))
      ncchannel_set_default(channel)
      ncchannels_set_fchannel(channels, channel.read_uint32)
      channels.read_uint64
    end

    # C: static inline uint64_t
    #    ncchannels_set_bg_default(uint64_t* channels){
    #      uint32_t channel = ncchannels_bchannel(*channels);
    #      ncchannel_set_default(&channel);
    #      ncchannels_set_bchannel(channels, channel);
    #      return *channels;
    #    }
    def self.ncchannels_set_bg_default(channels)
      channel = ::FFI::MemoryPointer.new(:uint32).write_uint32(ncchannels_bchannel(channels.read_uint64))
      ncchannel_set_default(channel)
      ncchannels_set_bchannel(channels, channel.read_uint32)
      channels.read_uint64
    end

    # --- colori del piano ---

    # C: static inline uint32_t
    #    ncplane_bchannel(const struct ncplane* n){
    #      return ncchannels_bchannel(ncplane_channels(n));
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.ncplane_bchannel(n)
      ncchannels_bchannel(ncplane_channels(n))
    end

    # C: static inline uint32_t
    #    ncplane_fchannel(const struct ncplane* n){
    #      return ncchannels_fchannel(ncplane_channels(n));
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.ncplane_fchannel(n)
      ncchannels_fchannel(ncplane_channels(n))
    end

    # C: static inline uint32_t
    #    ncplane_fg_rgb(const struct ncplane* n){
    #      return ncchannels_fg_rgb(ncplane_channels(n));
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.ncplane_fg_rgb(n)
      ncchannels_fg_rgb(ncplane_channels(n))
    end

    # C: static inline uint32_t
    #    ncplane_bg_rgb(const struct ncplane* n){
    #      return ncchannels_bg_rgb(ncplane_channels(n));
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.ncplane_bg_rgb(n)
      ncchannels_bg_rgb(ncplane_channels(n))
    end

    # C: static inline uint32_t
    #    ncplane_fg_alpha(const struct ncplane* n){
    #      return ncchannels_fg_alpha(ncplane_channels(n));
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.ncplane_fg_alpha(n)
      ncchannels_fg_alpha(ncplane_channels(n))
    end

    # C: static inline bool
    #    ncplane_fg_default_p(const struct ncplane* n){
    #      return ncchannels_fg_default_p(ncplane_channels(n));
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.ncplane_fg_default_p(n)
      ncchannels_fg_default_p(ncplane_channels(n))
    end

    # C: static inline uint32_t
    #    ncplane_bg_alpha(const struct ncplane* n){
    #      return ncchannels_bg_alpha(ncplane_channels(n));
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.ncplane_bg_alpha(n)
      ncchannels_bg_alpha(ncplane_channels(n))
    end

    # C: static inline bool
    #    ncplane_bg_default_p(const struct ncplane* n){
    #      return ncchannels_bg_default_p(ncplane_channels(n));
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.ncplane_bg_default_p(n)
      ncchannels_bg_default_p(ncplane_channels(n))
    end

    # C: static inline uint32_t
    #    ncplane_fg_rgb8(const struct ncplane* n, unsigned* r, unsigned* g, unsigned* b){
    #      return ncchannels_fg_rgb8(ncplane_channels(n), r, g, b);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.ncplane_fg_rgb8(n, r, g, b)
      ncchannels_fg_rgb8(ncplane_channels(n), r, g, b)
    end

    # C: static inline uint32_t
    #    ncplane_bg_rgb8(const struct ncplane* n, unsigned* r, unsigned* g, unsigned* b){
    #      return ncchannels_bg_rgb8(ncplane_channels(n), r, g, b);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.ncplane_bg_rgb8(n, r, g, b)
      ncchannels_bg_rgb8(ncplane_channels(n), r, g, b)
    end

    # --- colori della cella ---

    # C: static inline void
    #    nccell_set_fg_default(nccell* c){
    #      ncchannels_set_fg_default(&c->channels);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_set_fg_default(c)
      ncchannels_set_fg_default(c.pointer + NcCell.offset_of(:channels))
      nil
    end

    # C: static inline void
    #    nccell_set_bg_default(nccell* c){
    #      ncchannels_set_bg_default(&c->channels);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_set_bg_default(c)
      ncchannels_set_bg_default(c.pointer + NcCell.offset_of(:channels))
      nil
    end

    # C: static inline int
    #    nccell_set_fg_alpha(nccell* c, unsigned alpha){
    #      return ncchannels_set_fg_alpha(&c->channels, alpha);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_set_fg_alpha(c, alpha)
      ncchannels_set_fg_alpha(c.pointer + NcCell.offset_of(:channels), alpha)
    end

    # C: static inline int
    #    nccell_set_bg_alpha(nccell* c, unsigned alpha){
    #      return ncchannels_set_bg_alpha(&c->channels, alpha);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_set_bg_alpha(c, alpha)
      ncchannels_set_bg_alpha(c.pointer + NcCell.offset_of(:channels), alpha)
    end

    # C: static inline uint64_t
    #    nccell_set_bchannel(nccell* c, uint32_t channel){
    #      return ncchannels_set_bchannel(&c->channels, channel);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_set_bchannel(c, channel)
      ncchannels_set_bchannel(c.pointer + NcCell.offset_of(:channels), channel)
    end

    # C: static inline uint64_t
    #    nccell_set_fchannel(nccell* c, uint32_t channel){
    #      return ncchannels_set_fchannel(&c->channels, channel);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_set_fchannel(c, channel)
      ncchannels_set_fchannel(c.pointer + NcCell.offset_of(:channels), channel)
    end

    # C: static inline uint64_t
    #    nccell_set_channels(nccell* c, uint64_t channels){
    #      return ncchannels_set_channels(&c->channels, channels);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_set_channels(c, channels)
      ncchannels_set_channels(c.pointer + NcCell.offset_of(:channels), channels)
    end

    # C: static inline uint64_t
    #    nccell_channels(const nccell* c){
    #      return ncchannels_channels(c->channels);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_channels(c)
      ncchannels_channels(c[:channels])
    end

    # C: static inline uint32_t
    #    nccell_bchannel(const nccell* cl){
    #      return ncchannels_bchannel(cl->channels);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_bchannel(cl)
      ncchannels_bchannel(cl[:channels])
    end

    # C: static inline uint32_t
    #    nccell_fchannel(const nccell* cl){
    #      return ncchannels_fchannel(cl->channels);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_fchannel(cl)
      ncchannels_fchannel(cl[:channels])
    end

    # C: static inline uint32_t
    #    nccell_fg_rgb(const nccell* cl){
    #      return ncchannels_fg_rgb(cl->channels);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_fg_rgb(cl)
      ncchannels_fg_rgb(cl[:channels])
    end

    # C: static inline uint32_t
    #    nccell_bg_rgb(const nccell* cl){
    #      return ncchannels_bg_rgb(cl->channels);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_bg_rgb(cl)
      ncchannels_bg_rgb(cl[:channels])
    end

    # C: static inline uint32_t
    #    nccell_fg_alpha(const nccell* cl){
    #      return ncchannels_fg_alpha(cl->channels);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_fg_alpha(cl)
      ncchannels_fg_alpha(cl[:channels])
    end

    # C: static inline uint32_t
    #    nccell_bg_alpha(const nccell* cl){
    #      return ncchannels_bg_alpha(cl->channels);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_bg_alpha(cl)
      ncchannels_bg_alpha(cl[:channels])
    end

    # C: static inline uint32_t
    #    nccell_fg_rgb8(const nccell* cl, unsigned* r, unsigned* g, unsigned* b){
    #      return ncchannels_fg_rgb8(cl->channels, r, g, b);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_fg_rgb8(cl, r, g, b)
      ncchannels_fg_rgb8(cl[:channels], r, g, b)
    end

    # C: static inline uint32_t
    #    nccell_bg_rgb8(const nccell* cl, unsigned* r, unsigned* g, unsigned* b){
    #      return ncchannels_bg_rgb8(cl->channels, r, g, b);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_bg_rgb8(cl, r, g, b)
      ncchannels_bg_rgb8(cl[:channels], r, g, b)
    end

    # C: static inline int
    #    nccell_set_fg_rgb8(nccell* cl, unsigned r, unsigned g, unsigned b){
    #      return ncchannels_set_fg_rgb8(&cl->channels, r, g, b);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_set_fg_rgb8(cl, r, g, b)
      ncchannels_set_fg_rgb8(cl.pointer + NcCell.offset_of(:channels), r, g, b)
    end

    # C: static inline void
    #    nccell_set_fg_rgb8_clipped(nccell* cl, int r, int g, int b){
    #      ncchannels_set_fg_rgb8_clipped(&cl->channels, r, g, b);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_set_fg_rgb8_clipped(cl, r, g, b)
      ncchannels_set_fg_rgb8_clipped(cl.pointer + NcCell.offset_of(:channels), r, g, b)
      nil
    end

    # C: static inline int
    #    nccell_set_fg_rgb(nccell* c, uint32_t channel){
    #      return ncchannels_set_fg_rgb(&c->channels, channel);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_set_fg_rgb(c, channel)
      ncchannels_set_fg_rgb(c.pointer + NcCell.offset_of(:channels), channel)
    end

    # C: static inline int
    #    nccell_set_fg_palindex(nccell* cl, unsigned idx){
    #      return ncchannels_set_fg_palindex(&cl->channels, idx);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_set_fg_palindex(cl, idx)
      ncchannels_set_fg_palindex(cl.pointer + NcCell.offset_of(:channels), idx)
    end

    # C: static inline uint32_t
    #    nccell_fg_palindex(const nccell* cl){
    #      return ncchannels_fg_palindex(cl->channels);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_fg_palindex(cl)
      ncchannels_fg_palindex(cl[:channels])
    end

    # C: static inline int
    #    nccell_set_bg_rgb8(nccell* cl, unsigned r, unsigned g, unsigned b){
    #      return ncchannels_set_bg_rgb8(&cl->channels, r, g, b);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_set_bg_rgb8(cl, r, g, b)
      ncchannels_set_bg_rgb8(cl.pointer + NcCell.offset_of(:channels), r, g, b)
    end

    # C: static inline void
    #    nccell_set_bg_rgb8_clipped(nccell* cl, int r, int g, int b){
    #      ncchannels_set_bg_rgb8_clipped(&cl->channels, r, g, b);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_set_bg_rgb8_clipped(cl, r, g, b)
      ncchannels_set_bg_rgb8_clipped(cl.pointer + NcCell.offset_of(:channels), r, g, b)
      nil
    end

    # C: static inline int
    #    nccell_set_bg_rgb(nccell* c, uint32_t channel){
    #      return ncchannels_set_bg_rgb(&c->channels, channel);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_set_bg_rgb(c, channel)
      ncchannels_set_bg_rgb(c.pointer + NcCell.offset_of(:channels), channel)
    end

    # C: static inline int
    #    nccell_set_bg_palindex(nccell* cl, unsigned idx){
    #      return ncchannels_set_bg_palindex(&cl->channels, idx);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_set_bg_palindex(cl, idx)
      ncchannels_set_bg_palindex(cl.pointer + NcCell.offset_of(:channels), idx)
    end

    # C: static inline uint32_t
    #    nccell_bg_palindex(const nccell* cl){
    #      return ncchannels_bg_palindex(cl->channels);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_bg_palindex(cl)
      ncchannels_bg_palindex(cl[:channels])
    end

    # C: static inline bool
    #    nccell_fg_default_p(const nccell* cl){
    #      return ncchannels_fg_default_p(cl->channels);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_fg_default_p(cl)
      ncchannels_fg_default_p(cl[:channels])
    end

    # C: static inline bool
    #    nccell_fg_palindex_p(const nccell* cl){
    #      return ncchannels_fg_palindex_p(cl->channels);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_fg_palindex_p(cl)
      ncchannels_fg_palindex_p(cl[:channels])
    end

    # C: static inline bool
    #    nccell_bg_default_p(const nccell* cl){
    #      return ncchannels_bg_default_p(cl->channels);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_bg_default_p(cl)
      ncchannels_bg_default_p(cl[:channels])
    end

    # C: static inline bool
    #    nccell_bg_palindex_p(const nccell* cl){
    #      return ncchannels_bg_palindex_p(cl->channels);
    #    }
    # NOTE: potrebbe appartenere a NcPlane
    def self.nccell_bg_palindex_p(cl)
      ncchannels_bg_palindex_p(cl[:channels])
    end

    # --- palette ---

    # C: static inline int
    #    ncpalette_set_rgb8(ncpalette* p, int idx, unsigned r, unsigned g, unsigned b){
    #      if(idx < 0 || (size_t)idx > sizeof(p->chans) / sizeof(*p->chans)){
    #        return -1;
    #      }
    #      return ncchannel_set_rgb8(&p->chans[idx], r, g, b);
    #    }
    # NOTE: comportamento C replicato: accetta idx == NCPALETTESIZE (scrive oltre chans, UB: IndexError se FFI la vede)
    def self.ncpalette_set_rgb8(p, idx, r, g, b)
      return -1 if idx < 0 || idx > NCPALETTESIZE
      ncchannel_set_rgb8(p.pointer + NcPalette.offset_of(:chans) + idx * 4, r, g, b)
    end

    # C: static inline int
    #    ncpalette_set(ncpalette* p, int idx, unsigned rgb){
    #      if(idx < 0 || (size_t)idx > sizeof(p->chans) / sizeof(*p->chans)){
    #        return -1;
    #      }
    #      return ncchannel_set(&p->chans[idx], rgb);
    #    }
    # NOTE: comportamento C replicato: accetta idx == NCPALETTESIZE (scrive oltre chans, UB: IndexError se FFI la vede)
    def self.ncpalette_set(p, idx, rgb)
      return -1 if idx < 0 || idx > NCPALETTESIZE
      ncchannel_set(p.pointer + NcPalette.offset_of(:chans) + idx * 4, rgb)
    end

    # C: static inline int
    #    ncpalette_get(const ncpalette* p, int idx, uint32_t* palent){
    #      if(idx < 0 || (size_t)idx > sizeof(p->chans) / sizeof(*p->chans)){
    #        return -1;
    #      }
    #      *palent = ncchannel_rgb(p->chans[idx]);
    #      return 0;
    #    }
    # NOTE: comportamento C replicato: accetta idx == NCPALETTESIZE (legge oltre chans, UB: IndexError se FFI la vede)
    def self.ncpalette_get(p, idx, palent)
      return -1 if idx < 0 || idx > NCPALETTESIZE
      palent.write_uint32(ncchannel_rgb(p.pointer.get_uint32(NcPalette.offset_of(:chans) + idx * 4)))
      0
    end

    # C: static inline int
    #    ncpalette_get_rgb8(const ncpalette* p, int idx, unsigned* RESTRICT r, unsigned* RESTRICT g, unsigned* RESTRICT b){
    #      if(idx < 0 || (size_t)idx > sizeof(p->chans) / sizeof(*p->chans)){
    #        return -1;
    #      }
    #      return (int)ncchannel_rgb8(p->chans[idx], r, g, b);
    #    }
    # NOTE: comportamento C replicato: accetta idx == NCPALETTESIZE (legge oltre chans, UB: IndexError se FFI la vede)
    # NOTE: comportamento C replicato: restituisce (int) dell'intero canale, non solo dell'RGB (negativo con il bit 31)
    def self.ncpalette_get_rgb8(p, idx, r, g, b)
      return -1 if idx < 0 || idx > NCPALETTESIZE
      chan = ncchannel_rgb8(p.pointer.get_uint32(NcPalette.offset_of(:chans) + idx * 4), r, g, b)
      chan >= 0x8000_0000 ? chan - 0x1_0000_0000 : chan
    end

    # ═══════════════════════════════════════
    # NcVisual
    # ═══════════════════════════════════════

    # --- ncvisual ---

    # C: __attribute__ ((nonnull (1, 2, 3))) static inline struct ncplane*
    #    ncvisualplane_create(struct notcurses* nc, const struct ncplane_options* opts,
    #                         struct ncvisual* ncv, struct ncvisual_options* vopts){
    #      struct ncplane* newn;
    #      if(vopts && vopts->n){
    #        if(vopts->flags & NCVISUAL_OPTION_CHILDPLANE){
    #          return NULL; // the whole point is to create a new plane
    #        }
    #        newn = ncplane_create(vopts->n, opts);
    #      }else{
    #        newn = ncpile_create(nc, opts);
    #      }
    #      if(newn == NULL){
    #        return NULL;
    #      }
    #      struct ncvisual_options v;
    #      if(!vopts){
    #        vopts = &v;
    #        memset(vopts, 0, sizeof(*vopts));
    #      }
    #      vopts->n = newn;
    #      if(ncvisual_blit(nc, ncv, vopts) == NULL){
    #        ncplane_destroy(newn);
    #        vopts->n = NULL;
    #        return NULL;
    #      }
    #      return newn;
    #    }
    def self.ncvisualplane_create(nc, opts, ncv, vopts)
      if vopts && !vopts[:n].null?
        return ::FFI::Pointer::NULL if (vopts[:flags] & NCVISUAL_OPTION_CHILDPLANE) != 0
        newn = ncplane_create(vopts[:n], opts)
      else
        newn = ncpile_create(nc, opts)
      end
      return ::FFI::Pointer::NULL if newn.null?
      vopts ||= NcVisualOptions.new # la struct locale v azzerata del C
      vopts[:n] = newn
      if ncvisual_blit(nc, ncv, vopts).null?
        ncplane_destroy(newn)
        vopts[:n] = nil
        return ::FFI::Pointer::NULL
      end
      newn
    end

    # --- ncpixel ---

    # C: #define htole(x) (__bswap_32(htonl(x)))
    # NOTE: potrebbe appartenere a Channels / Colors
    # NOTE: macro di ncport.h: htonl tronca a uint32_t; identità su little-endian, byte invertiti su big-endian
    def self.htole(x)
      x &= 0xffff_ffff
      ::FFI::Platform::BYTE_ORDER == ::FFI::Platform::LITTLE_ENDIAN ? x : [x].pack('N').unpack1('V')
    end

    # C: static inline unsigned
    #    ncpixel_a(uint32_t pixel){
    #      return (htole(pixel) & 0xff000000u) >> 24u;
    #    }
    # NOTE: potrebbe appartenere a Channels / Colors
    def self.ncpixel_a(pixel)
      (htole(pixel) & 0xff00_0000) >> 24
    end

    # C: static inline unsigned
    #    ncpixel_r(uint32_t pixel){
    #      return (htole(pixel) & 0x000000ffu);
    #    }
    # NOTE: potrebbe appartenere a Channels / Colors
    def self.ncpixel_r(pixel)
      htole(pixel) & 0x0000_00ff
    end

    # C: static inline unsigned
    #    ncpixel_g(uint32_t pixel){
    #      return (htole(pixel) & 0x0000ff00u) >> 8u;
    #    }
    # NOTE: potrebbe appartenere a Channels / Colors
    def self.ncpixel_g(pixel)
      (htole(pixel) & 0x0000_ff00) >> 8
    end

    # C: static inline unsigned
    #    ncpixel_b(uint32_t pixel){
    #      return (htole(pixel) & 0x00ff0000u) >> 16u;
    #    }
    # NOTE: potrebbe appartenere a Channels / Colors
    def self.ncpixel_b(pixel)
      (htole(pixel) & 0x00ff_0000) >> 16
    end

    # C: static inline int
    #    ncpixel_set_a(uint32_t* pixel, unsigned a){
    #      if(a > 255){
    #        return -1;
    #      }
    #      *pixel = htole((htole(*pixel) & 0x00ffffffu) | (a << 24u));
    #      return 0;
    #    }
    # NOTE: potrebbe appartenere a Channels / Colors
    def self.ncpixel_set_a(pixel, a)
      a &= 0xffff_ffff
      return -1 if a > 255
      pixel.write_uint32(htole((htole(pixel.read_uint32) & 0x00ff_ffff) | (a << 24)))
      0
    end

    # C: static inline int
    #    ncpixel_set_r(uint32_t* pixel, unsigned r){
    #      if(r > 255){
    #        return -1;
    #      }
    #      *pixel = htole((htole(*pixel) & 0xffffff00u) | r);
    #      return 0;
    #    }
    # NOTE: potrebbe appartenere a Channels / Colors
    def self.ncpixel_set_r(pixel, r)
      r &= 0xffff_ffff
      return -1 if r > 255
      pixel.write_uint32(htole((htole(pixel.read_uint32) & 0xffff_ff00) | r))
      0
    end

    # C: static inline int
    #    ncpixel_set_g(uint32_t* pixel, unsigned g){
    #      if(g > 255){
    #        return -1;
    #      }
    #      *pixel = htole((htole(*pixel) & 0xffff00ffu) | (g << 8u));
    #      return 0;
    #    }
    # NOTE: potrebbe appartenere a Channels / Colors
    def self.ncpixel_set_g(pixel, g)
      g &= 0xffff_ffff
      return -1 if g > 255
      pixel.write_uint32(htole((htole(pixel.read_uint32) & 0xffff_00ff) | (g << 8)))
      0
    end

    # C: static inline int
    #    ncpixel_set_b(uint32_t* pixel, unsigned b){
    #      if(b > 255){
    #        return -1;
    #      }
    #      *pixel = htole((htole(*pixel) & 0xff00ffffu) | (b << 16u));
    #      return 0;
    #    }
    # NOTE: potrebbe appartenere a Channels / Colors
    def self.ncpixel_set_b(pixel, b)
      b &= 0xffff_ffff
      return -1 if b > 255
      pixel.write_uint32(htole((htole(pixel.read_uint32) & 0xff00_ffff) | (b << 16)))
      0
    end

    # C: static inline uint32_t
    #    ncpixel(unsigned r, unsigned g, unsigned b){
    #      uint32_t pixel = 0;
    #      ncpixel_set_a(&pixel, 0xff);
    #      if(r > 255) r = 255;
    #      ncpixel_set_r(&pixel, r);
    #      if(g > 255) g = 255;
    #      ncpixel_set_g(&pixel, g);
    #      if(b > 255) b = 255;
    #      ncpixel_set_b(&pixel, b);
    #      return pixel;
    #    }
    # NOTE: potrebbe appartenere a Channels / Colors
    def self.ncpixel(r, g, b)
      pixel = ::FFI::MemoryPointer.new(:uint32)
      ncpixel_set_a(pixel, 0xff)
      ncpixel_set_r(pixel, [r & 0xffff_ffff, 255].min)
      ncpixel_set_g(pixel, [g & 0xffff_ffff, 255].min)
      ncpixel_set_b(pixel, [b & 0xffff_ffff, 255].min)
      pixel.read_uint32
    end

    # C: static inline int
    #    ncpixel_set_rgb8(uint32_t* pixel, unsigned r, unsigned g, unsigned b){
    #      if(ncpixel_set_r(pixel, r) || ncpixel_set_g(pixel, g) || ncpixel_set_b(pixel, b)){
    #        return -1;
    #      }
    #      return 0;
    #    }
    # NOTE: potrebbe appartenere a Channels / Colors
    def self.ncpixel_set_rgb8(pixel, r, g, b)
      return -1 if ncpixel_set_r(pixel, r) != 0 || ncpixel_set_g(pixel, g) != 0 || ncpixel_set_b(pixel, b) != 0
      0
    end

    # ═══════════════════════════════════════
    # Widgets (selector, menu, reader, reel, tabbed, tree, plot, progbar)
    # ═══════════════════════════════════════

    # --- nctabbed ---

    # C: static inline uint64_t
    #    nctabbed_hdrchan(struct nctabbed* nt){
    #      uint64_t ch;
    #      nctabbed_channels(nt, &ch, NULL, NULL);
    #      return ch;
    #    }
    def self.nctabbed_hdrchan(nt)
      ch = ::FFI::MemoryPointer.new(:uint64)
      nctabbed_channels(nt, ch, nil, nil)
      ch.read_uint64
    end

    # C: static inline uint64_t
    #    nctabbed_selchan(struct nctabbed* nt){
    #      uint64_t ch;
    #      nctabbed_channels(nt, NULL, &ch, NULL);
    #      return ch;
    #    }
    def self.nctabbed_selchan(nt)
      ch = ::FFI::MemoryPointer.new(:uint64)
      nctabbed_channels(nt, nil, ch, nil)
      ch.read_uint64
    end

    # C: static inline uint64_t
    #    nctabbed_sepchan(struct nctabbed* nt){
    #      uint64_t ch;
    #      nctabbed_channels(nt, NULL, NULL, &ch);
    #      return ch;
    #    }
    def self.nctabbed_sepchan(nt)
      ch = ::FFI::MemoryPointer.new(:uint64)
      nctabbed_channels(nt, nil, nil, ch)
      ch.read_uint64
    end

    # ═══════════════════════════════════════
    # Stats / Debug
    # ═══════════════════════════════════════

    # --- metric ---

    # C: #define NCMETRICFWIDTH(x, cols) \
    #        ((int)(strlen(x) - ncstrwidth(x, NULL, NULL) + (cols)))
    # NOTE: potrebbe appartenere a Notcurses lifecycle (formattazione numerica)
    # NOTE: macro: x è la String del const char*, letta fino al primo NUL (strlen, ncstrwidth); risultato (int) a 32 bit
    def self.NCMETRICFWIDTH(x, cols)
      s = x.b
      i = s.index("\0")
      s = s.byteslice(0, i) if i
      w = s.bytesize - ncstrwidth(s, nil, nil) + cols
      ((w + 0x8000_0000) & 0xffff_ffff) - 0x8000_0000
    end

    # C: #define NCPREFIXFMT(x) NCMETRICFWIDTH((x), NCPREFIXCOLUMNS), (x)
    # NOTE: potrebbe appartenere a Notcurses lifecycle (formattazione numerica)
    # NOTE: macro: si espande in due argomenti printf, restituiti come [larghezza, x]
    def self.NCPREFIXFMT(x)
      [NCMETRICFWIDTH(x, NCPREFIXCOLUMNS), x]
    end

    # C: #define NCIPREFIXFMT(x) NCMETRICFWIDTH((x), NCIPREFIXCOLUMNS), (x)
    # NOTE: potrebbe appartenere a Notcurses lifecycle (formattazione numerica)
    # NOTE: macro: si espande in due argomenti printf, restituiti come [larghezza, x]
    def self.NCIPREFIXFMT(x)
      [NCMETRICFWIDTH(x, NCIPREFIXCOLUMNS), x]
    end

    # C: #define NCBPREFIXFMT(x) NCMETRICFWIDTH((x), NCBPREFIXCOLUMNS), (x)
    # NOTE: potrebbe appartenere a Notcurses lifecycle (formattazione numerica)
    # NOTE: macro: si espande in due argomenti printf, restituiti come [larghezza, x]
    def self.NCBPREFIXFMT(x)
      [NCMETRICFWIDTH(x, NCBPREFIXCOLUMNS), x]
    end

    # C: static inline const char*
    #    ncqprefix(uintmax_t val, uintmax_t decimal, char* buf, int omitdec){
    #      return ncnmetric(val, NCPREFIXSTRLEN + 1, decimal, buf, omitdec, 1000, '\0');
    #    }
    # NOTE: potrebbe appartenere a Notcurses lifecycle (formattazione numerica)
    def self.ncqprefix(val, decimal, buf, omitdec)
      ncnmetric(val, NCPREFIXSTRLEN + 1, decimal, buf, omitdec, 1000, 0)
    end

    # C: static inline const char*
    #    nciprefix(uintmax_t val, uintmax_t decimal, char* buf, int omitdec){
    #      return ncnmetric(val, NCIPREFIXSTRLEN + 1, decimal, buf, omitdec, 1024, '\0');
    #    }
    # NOTE: potrebbe appartenere a Notcurses lifecycle (formattazione numerica)
    def self.nciprefix(val, decimal, buf, omitdec)
      ncnmetric(val, NCIPREFIXSTRLEN + 1, decimal, buf, omitdec, 1024, 0)
    end

    # C: static inline const char*
    #    ncbprefix(uintmax_t val, uintmax_t decimal, char* buf, int omitdec){
    #      return ncnmetric(val, NCBPREFIXSTRLEN + 1, decimal, buf, omitdec, 1024, 'i');
    #    }
    # NOTE: potrebbe appartenere a Notcurses lifecycle (formattazione numerica)
    def self.ncbprefix(val, decimal, buf, omitdec)
      ncnmetric(val, NCBPREFIXSTRLEN + 1, decimal, buf, omitdec, 1024, 'i'.ord)
    end

    # ═══════════════════════════════════════
    # NcDirect (direct.h)
    # ═══════════════════════════════════════

    # --- colori ---

    # C: static inline int
    #    ncdirect_set_bg_rgb8(struct ncdirect* nc, unsigned r, unsigned g, unsigned b){
    #      if(r > 255 || g > 255 || b > 255){
    #        return -1;
    #      }
    #      return ncdirect_set_bg_rgb(nc, (r << 16u) + (g << 8u) + b);
    #    }
    def self.ncdirect_set_bg_rgb8(nc, r, g, b)
      r &= 0xffff_ffff
      g &= 0xffff_ffff
      b &= 0xffff_ffff
      return -1 if r > 255 || g > 255 || b > 255
      ncdirect_set_bg_rgb(nc, (r << 16) + (g << 8) + b)
    end

    # C: static inline int
    #    ncdirect_set_fg_rgb8(struct ncdirect* nc, unsigned r, unsigned g, unsigned b){
    #      if(r > 255 || g > 255 || b > 255){
    #        return -1;
    #      }
    #      return ncdirect_set_fg_rgb(nc, (r << 16u) + (g << 8u) + b);
    #    }
    def self.ncdirect_set_fg_rgb8(nc, r, g, b)
      r &= 0xffff_ffff
      g &= 0xffff_ffff
      b &= 0xffff_ffff
      return -1 if r > 255 || g > 255 || b > 255
      ncdirect_set_fg_rgb(nc, (r << 16) + (g << 8) + b)
    end

    # --- linee e box ---

    # C: __attribute__ ((nonnull (1))) static inline int
    #    ncdirect_light_box(struct ncdirect* n, uint64_t ul, uint64_t ur,
    #                       uint64_t ll, uint64_t lr,
    #                       unsigned ylen, unsigned xlen, unsigned ctlword){
    #      return ncdirect_box(n, ul, ur, ll, lr, NCBOXLIGHTW, ylen, xlen, ctlword);
    #    }
    def self.ncdirect_light_box(n, ul, ur, ll, lr, ylen, xlen, ctlword)
      wchars = NCBOXLIGHTW.codepoints << 0 # L"..." come vettore wchar_t terminato da 0
      ncdirect_box(n, ul, ur, ll, lr, ::FFI::MemoryPointer.new(:wchar_t, wchars.size).put_array_of_int32(0, wchars),
                   ylen, xlen, ctlword)
    end

    # C: __attribute__ ((nonnull (1))) static inline int
    #    ncdirect_heavy_box(struct ncdirect* n, uint64_t ul, uint64_t ur,
    #                       uint64_t ll, uint64_t lr,
    #                       unsigned ylen, unsigned xlen, unsigned ctlword){
    #      return ncdirect_box(n, ul, ur, ll, lr, NCBOXHEAVYW, ylen, xlen, ctlword);
    #    }
    def self.ncdirect_heavy_box(n, ul, ur, ll, lr, ylen, xlen, ctlword)
      wchars = NCBOXHEAVYW.codepoints << 0 # L"..." come vettore wchar_t terminato da 0
      ncdirect_box(n, ul, ur, ll, lr, ::FFI::MemoryPointer.new(:wchar_t, wchars.size).put_array_of_int32(0, wchars),
                   ylen, xlen, ctlword)
    end

    # C: __attribute__ ((nonnull (1))) static inline int
    #    ncdirect_ascii_box(struct ncdirect* n, uint64_t ul, uint64_t ur,
    #                       uint64_t ll, uint64_t lr,
    #                       unsigned ylen, unsigned xlen, unsigned ctlword){
    #      return ncdirect_box(n, ul, ur, ll, lr, NCBOXASCIIW, ylen, xlen, ctlword);
    #    }
    def self.ncdirect_ascii_box(n, ul, ur, ll, lr, ylen, xlen, ctlword)
      wchars = NCBOXASCIIW.codepoints << 0 # L"..." come vettore wchar_t terminato da 0
      ncdirect_box(n, ul, ur, ll, lr, ::FFI::MemoryPointer.new(:wchar_t, wchars.size).put_array_of_int32(0, wchars),
                   ylen, xlen, ctlword)
    end

    # --- input ---

    # C: static inline uint32_t
    #    ncdirect_get_nblock(struct ncdirect* n, ncinput* ni){
    #      struct timespec ts = { .tv_sec = 0, .tv_nsec = 0 };
    #      return ncdirect_get(n, &ts, ni);
    #    }
    def self.ncdirect_get_nblock(n, ni)
      ncdirect_get(n, Timespec.new, ni) # Timespec.new = { .tv_sec = 0, .tv_nsec = 0 }
    end

    # C: static inline uint32_t
    #    ncdirect_get_blocking(struct ncdirect* n, ncinput* ni){
    #      return ncdirect_get(n, NULL, ni);
    #    }
    def self.ncdirect_get_blocking(n, ni)
      ncdirect_get(n, nil, ni)
    end

    # --- capabilities ---

    # C: static inline bool
    #    ncdirect_cantruecolor(const struct ncdirect* n){
    #      return ncdirect_capabilities(n)->rgb;
    #    }
    def self.ncdirect_cantruecolor(n)
      ncdirect_capabilities(n)[:rgb]
    end

    # C: static inline bool
    #    ncdirect_canchangecolor(const struct ncdirect* n){
    #      return nccapability_canchangecolor(ncdirect_capabilities(n));
    #    }
    def self.ncdirect_canchangecolor(n)
      nccapability_canchangecolor(ncdirect_capabilities(n))
    end

    # C: static inline bool
    #    ncdirect_canfade(const struct ncdirect* n){
    #      return ncdirect_canchangecolor(n) || ncdirect_cantruecolor(n);
    #    }
    def self.ncdirect_canfade(n)
      ncdirect_canchangecolor(n) || ncdirect_cantruecolor(n)
    end

    # C: static inline bool
    #    ncdirect_canopen_images(const struct ncdirect* n __attribute__ ((unused))){
    #      return notcurses_canopen_images(NULL);
    #    }
    def self.ncdirect_canopen_images(n)
      notcurses_canopen_images(nil)
    end

    # C: static inline bool
    #    ncdirect_canopen_videos(const struct ncdirect* n __attribute__ ((unused))){
    #      return notcurses_canopen_videos(NULL);
    #    }
    def self.ncdirect_canopen_videos(n)
      notcurses_canopen_videos(nil)
    end

    # C: static inline bool
    #    ncdirect_canhalfblock(const struct ncdirect* nc){
    #      return ncdirect_canutf8(nc);
    #    }
    def self.ncdirect_canhalfblock(nc)
      ncdirect_canutf8(nc)
    end

    # C: static inline bool
    #    ncdirect_canquadrant(const struct ncdirect* nc){
    #      return ncdirect_canutf8(nc) && ncdirect_capabilities(nc)->quadrants;
    #    }
    def self.ncdirect_canquadrant(nc)
      ncdirect_canutf8(nc) && ncdirect_capabilities(nc)[:quadrants]
    end

    # C: static inline bool
    #    ncdirect_cansextant(const struct ncdirect* nc){
    #      return ncdirect_canutf8(nc) && ncdirect_capabilities(nc)->sextants;
    #    }
    def self.ncdirect_cansextant(nc)
      ncdirect_canutf8(nc) && ncdirect_capabilities(nc)[:sextants]
    end

    # C: static inline bool
    #    ncdirect_canoctant(const struct ncdirect* nc){
    #      return ncdirect_canutf8(nc) && ncdirect_capabilities(nc)->octants;
    #    }
    def self.ncdirect_canoctant(nc)
      ncdirect_canutf8(nc) && ncdirect_capabilities(nc)[:octants]
    end

    # C: static inline bool
    #    ncdirect_canbraille(const struct ncdirect* nc){
    #      return ncdirect_canutf8(nc) && ncdirect_capabilities(nc)->braille;
    #    }
    def self.ncdirect_canbraille(nc)
      ncdirect_canutf8(nc) && ncdirect_capabilities(nc)[:braille]
    end
  end
end
