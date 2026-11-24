# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

# Binding Ruby di notcurses 3.0.17.
#
# - Notcurses::FFI (lib/notcurses/ffi): layer FFI raw, mappatura 1:1 dell'API C (Fase 1).
# - Il resto del modulo: wrapper idiomatico (Fase 2) con classi, blocchi,
#   eccezioni e gestione della memoria.
#
# Thread safety: notcurses non è thread-safe. Il wrapper non aggiunge lock
# attorno alle chiamate C: un contesto e tutti i suoi oggetti vanno usati da un
# solo thread alla volta. Unica eccezione: durante {Notcurses::UI::EventLoop#run}
# un thread di input del contesto legge i tasti con +notcurses_getvec+, che
# notcurses permette in parallelo al render. L'unico lock interno protegge il
# registro del contesto attivo (notcurses ammette un solo contesto per processo).
#
# Fiber scheduler: i blocchi che notcurses chiama dentro una chiamata C (il
# resize di un piano, {Notcurses::Visual#stream}, {Notcurses::Tree},
# {Notcurses::Tabbed}) girano in un contesto bloccante. Dentro questi blocchi
# sleep e l'I/O fermano il thread e non passano dallo scheduler, così nessun
# altro Fiber rientra in notcurses a metà della chiamata. Su Ruby 3.1, che non
# ha Fiber.blocking, il blocco gira in un Fiber bloccante nuovo: Fiber.current
# è un altro Fiber, i valori locali al Fiber (Thread.current[:chiave]) del
# chiamante non si vedono, e un throw verso fuori dal blocco diventa
# UncaughtThrowError al posto di LocalJumpError.
#
# @example
#   require 'notcurses'
#   Notcurses::Context.open do |nc|
#     nc.stdplane.putstr('ciao', y: 0, x: 0)
#     nc.render
#   end
module Notcurses
end

require_relative 'notcurses/ffi'
require_relative 'notcurses/error'
require_relative 'notcurses/util'
require_relative 'notcurses/version'
require_relative 'notcurses/format'
require_relative 'notcurses/resource'
require_relative 'notcurses/guard'
require_relative 'notcurses/channel'
require_relative 'notcurses/pixel'
require_relative 'notcurses/input'
require_relative 'notcurses/stats'
require_relative 'notcurses/cell'
require_relative 'notcurses/plane'
require_relative 'notcurses/input_reader'
require_relative 'notcurses/context'
require_relative 'notcurses/palette'
require_relative 'notcurses/direct'
require_relative 'notcurses/visual'
require_relative 'notcurses/widgets/widget'
require_relative 'notcurses/widgets/selector'
require_relative 'notcurses/widgets/multiselector'
require_relative 'notcurses/widgets/menu'
require_relative 'notcurses/widgets/reader'
require_relative 'notcurses/widgets/reel'
require_relative 'notcurses/widgets/tabbed'
require_relative 'notcurses/widgets/tree'
require_relative 'notcurses/widgets/plot'
require_relative 'notcurses/widgets/progbar'
require_relative 'notcurses/fd_plane'
require_relative 'notcurses/subprocess'
require_relative 'notcurses/ui'
