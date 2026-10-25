# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Radice della gerarchia delle eccezioni del wrapper. Gli errori di argomento
  # (tipo o intervallo sbagliato) sono invece +TypeError+ e +ArgumentError+, e
  # vengono sollevati prima di qualsiasi chiamata C.
  class Error < StandardError; end

  # +notcurses_init+ o +ncdirect_init+ restituiscono NULL, oppure un altro
  # contesto è già attivo nel processo (notcurses ne ammette uno solo).
  class InitError < Error; end

  # Uso di un oggetto dopo +close+/+destroy+, o dopo la chiusura del suo
  # proprietario (per esempio un piano dopo la chiusura del contesto).
  class ClosedError < Error; end

  # +notcurses_render+, +ncpile_render+, +ncpile_rasterize+ o
  # +notcurses_refresh+ restituiscono -1.
  class RenderError < Error; end

  # Operazione su un contesto fallita (cursore, mouse, schermo alternativo,
  # segnali di linea, palette).
  class ContextError < Error; end

  # Operazione su un piano fallita (-1 o NULL dal C).
  class PlaneError < Error; end

  # Operazione su una cella fallita (+nccell_load+, +nccell_duplicate+, ...).
  class CellError < Error; end

  # Operazione +ncvisual_*+ o +ncblit_*+ fallita.
  class VisualError < Error; end

  # Errore di input: +notcurses_get+ o +ncdirect_get+ restituiscono
  # +(uint32_t)-1+.
  class InputError < Error; end

  # Creazione o operazione di un widget fallita.
  class WidgetError < Error; end

  # Operazione +ncdirect_*+ fallita.
  class DirectError < Error; end
end
