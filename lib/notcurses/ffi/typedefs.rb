# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  module FFI
    # I tipi di piattaforma usati dall'API vengono dal types.conf della gem ffi:
    # :size_t e :time_t sempre, :wchar_t e :uintmax_t quando ci sono (mancano
    # per esempio su FreeBSD, OpenBSD, NetBSD e Linux i386/ppc64/riscv64/s390x).
    # Dove mancano, qui sotto diventano :int32 (wchar_t è di 32 bit su ogni
    # sistema con termios) e :uint64. Queste typedef valgono solo dentro
    # Notcurses::FFI: ::FFI::MemoryPointer.new usa :int32, non :wchar_t.
    {wchar_t: :int32, uintmax_t: :uint64}.each do |name, type|
      ::FFI.find_type(name)
    rescue TypeError
      typedef type, name
    end

    # Le typedef di struct (nccell, ncplane_options, ...) sono classe
    # ::FFI::Struct in structs.rb. Le struct opache (struct notcurses,
    # struct ncplane, ... e i typedef ncdirectv/ncdirectf di direct.h)
    # si usano solo tramite puntatore: :pointer.

    # --- Enum (typedef enum { ... } X_e;) ---
    # Enum di 4 byte: gcc usa unsigned int se nessun valore è negativo, int per
    # ncloglevel_e; :int ha la stessa dimensione e la stessa classe ABI.
    typedef :int, :ncblitter_e
    typedef :int, :ncalign_e
    typedef :int, :ncscale_e
    typedef :int, :ncloglevel_e
    typedef :int, :ncintype_e
    typedef :int, :ncpixelimpl_e

    # --- Callback (typedef di puntatori a funzione) ---
    # Nelle firme di functions.rb i callback restano :pointer (regola del
    # progetto); questi alias documentano i typedef C per la Fase 2.

    # typedef int (*fadecb)(struct notcurses* nc, struct ncplane* n,
    #                       const struct timespec*, void* curry);
    typedef :pointer, :fadecb
    # typedef int (*ncstreamcb)(struct ncvisual*, struct ncvisual_options*,
    #                           const struct timespec*, void*);
    typedef :pointer, :ncstreamcb
    # typedef int (*tabletcb)(struct nctablet* t, bool drawfromtop);
    typedef :pointer, :tabletcb
    # typedef void (*tabcb)(struct nctab* t, struct ncplane* ncp, void* curry);
    typedef :pointer, :tabcb
    # typedef int(*ncfdplane_callback)(struct ncfdplane* n, const void* buf,
    #                                  size_t s, void* curry);
    typedef :pointer, :ncfdplane_callback
    # typedef int(*ncfdplane_done_cb)(struct ncfdplane* n, int fderrno, void* curry);
    typedef :pointer, :ncfdplane_done_cb

    # --- Alias semantici (NON presenti nell'header C 3.0.17) ---
    # L'header usa uint32_t/uint64_t diretti; libnotcurses-sys li chiama
    # NcChannel/NcChannels. Le firme FFI usano i tipi C reali.
    typedef :uint32, :ncchannel
    typedef :uint64, :ncchannels

    # --- libc (<termios.h>) ---
    # unsigned long su macOS, unsigned int su Linux e BSD
    typedef(::FFI::Platform::IS_MAC ? :ulong : :uint, :tcflag_t)
  end
end
