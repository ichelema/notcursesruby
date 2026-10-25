# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require 'ffi'

module Notcurses
  # Layer FFI raw: mappatura 1:1 dell'API C di notcurses (Fase 1).
  module FFI
    extend ::FFI::Library

    # libnotcurses esporta solo notcurses_init/ncdirect_init: il resto dell'API
    # vive in libnotcurses-core. libc serve per fopen/fclose/free e per le
    # reimplementazioni delle funzioni static inline.
    ffi_lib ['notcurses', 'libnotcurses.so', 'libnotcurses.dylib',
             'libnotcurses.so.3', 'libnotcurses.3.dylib'],
            ['notcurses-core', 'libnotcurses-core.so', 'libnotcurses-core.dylib',
             'libnotcurses-core.so.3', 'libnotcurses-core.3.dylib'],
            ::FFI::Library::LIBC
  end
end

require_relative 'ffi/typedefs'
require_relative 'ffi/enums'
require_relative 'ffi/constants'
require_relative 'ffi/structs'
require_relative 'ffi/functions'
require_relative 'ffi/inline_reimpl'
