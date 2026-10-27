# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Versione della gem (del binding Ruby, non della libreria C).
  VERSION = '0.1.0'

  # Versione degli header C da cui è stato generato il layer FFI.
  HEADER_VERSION = [FFI::NOTCURSES_VERSION_MAJOR, FFI::NOTCURSES_VERSION_MINOR,
                    FFI::NOTCURSES_VERSION_PATCH].join('.').freeze

  # Versione della libreria notcurses caricata a runtime (+notcurses_version+).
  #
  # @return [String] per esempio "3.0.17", in UTF-8
  def self.lib_version
    FFI.notcurses_version.force_encoding(Encoding::UTF_8)
  end

  # Componenti numerici della versione caricata a runtime
  # (+notcurses_version_components+).
  #
  # @return [Array(Integer, Integer, Integer, Integer)] major, minor, patch, tweak
  def self.lib_version_components
    ptrs = Array.new(4) { ::FFI::MemoryPointer.new(:int) }
    FFI.notcurses_version_components(*ptrs)
    ptrs.map(&:read_int)
  end

  # Numero di versione confrontabile (+NOTCURSES_VERSION_COMPARABLE+).
  #
  # @param major [Integer] 0..255
  # @param minor [Integer] 0..255
  # @param patch [Integer] 0..255
  # @return [Integer] +(major << 16) + (minor << 8) + patch+
  # @raise [TypeError] se un argomento non è Integer
  # @raise [ArgumentError] se un argomento è fuori da 0..255
  def self.version_comparable(major, minor, patch)
    Util.uint8!(major, 'major')
    Util.uint8!(minor, 'minor')
    Util.uint8!(patch, 'patch')
    FFI.NOTCURSES_VERSION_COMPARABLE(major, minor, patch)
  end
end
