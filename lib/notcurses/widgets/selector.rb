# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Selettore (+ncselector+): elenco di opzioni, ciascuna con una descrizione,
  # da cui se ne sceglie una con le frecce, PagSu/PagGiù, la rotella o un clic.
  #
  # Il selettore prende possesso del piano ricevuto (vedi {Widget}): lo
  # ridimensiona alle righe e colonne che servono (le righe non superano quelle
  # del genitore; per una radice, quelle del piano stesso), lo ridisegna a ogni
  # cambiamento e lo distrugge alla chiusura (i figli del piano passano al suo
  # genitore). I metodi ridisegnano senza fare render: chiama {Context#render}.
  # Lo scorrimento è circolare: dopo l'ultima voce viene la prima.
  #
  # Non c'è un metodo per cancellare voci: +ncselector_delitem+ di 3.0.17
  # lascia la selezione e la finestra visibile fuori dal vettore delle voci
  # (letture fuori limite, crash, double free alla distruzione). Per cambiare
  # l'elenco chiudi il selettore e creane un altro.
  #
  # @example
  #   plane = nc.stdplane.create_child(rows: 1, cols: 1, y: 1, x: 1)
  #   sel = Notcurses::Selector.new(plane, items: [%w[rosso caldo], %w[blu freddo]], title: 'Colore')
  #   nc.render
  #   until (ev = nc.get).id == Notcurses::Key::ENTER
  #     nc.render if sel.offer_input(ev)
  #   end
  #   colore = sel.selected
  #   sel.close
  class Selector
    include Widget
    extend Resource::ClassMethods

    # Crea il selettore sul piano (+ncselector_create+) e lo disegna.
    #
    # @param plane [Plane] piano posseduto dal wrapper, non lo stdplane e non
    #   già di un widget: passa al selettore
    # @param items [Array<String, Array(String, String)>, Hash{String => String}]
    #   voci: una String (opzione senza descrizione), una coppia [opzione,
    #   descrizione] (descrizione nil = vuota), oppure un Hash opzione =>
    #   descrizione
    # @param title [String, nil] titolo, in un riquadro sopra il corpo
    # @param secondary [String, nil] testo sul bordo superiore del corpo
    # @param footer [String, nil] testo sul bordo inferiore del corpo
    # @param default [Integer] indice della voce selezionata all'inizio,
    #   0...items.size (0 se non ci sono voci)
    # @param max_display [Integer] voci visibili al massimo, 0..UINT_MAX (0 = tutte)
    # @param opchannels [Channels, Integer] colori delle opzioni (la voce
    #   selezionata li inverte)
    # @param descchannels [Channels, Integer] colori delle descrizioni
    # @param titlechannels [Channels, Integer] colori del titolo
    # @param footchannels [Channels, Integer] colori di secondary e footer
    # @param boxchannels [Channels, Integer] colori dei bordi
    # @raise [WidgetError] se +ncselector_create+ fallisce (il piano risulta
    #   distrutto); se il piano è lo stdplane, è già di un widget o non è
    #   posseduto; dentro un callback chiamato da notcurses
    # @raise [TypeError, ArgumentError] se un'opzione non è valida (anche un
    #   testo con caratteri di controllo, che il C non controlla sempre)
    # @raise [ClosedError] se il piano è chiuso
    # @raise [Exception] l'eccezione di un callback Ruby di resize di un figlio
    #   del piano: il resize fallito fa fallire la creazione
    def initialize(plane, items: [], title: nil, secondary: nil, footer: nil, default: 0, max_display: 0,
                   opchannels: 0, descchannels: 0, titlechannels: 0, footchannels: 0, boxchannels: 0)
      claim_plane!(plane)
      ctx = plane.context
      ctx.check_not_in_callback!('Selector.new', WidgetError)
      pairs = item_pairs(items)
      keep = [] # MemoryPointer delle stringhe: il C le copia durante la chiamata
      opts = FFI::NcSelectorOptions.new
      opts[:title] = c_text(title.nil? ? nil : text!(title, 'title'), keep)
      opts[:secondary] = c_text(secondary.nil? ? nil : text!(secondary, 'secondary'), keep)
      opts[:footer] = c_text(footer.nil? ? nil : text!(footer, 'footer'), keep)
      # una voce azzerata in più (option NULL) termina il vettore
      vec = ::FFI::MemoryPointer.new(FFI::NcSelectorItem, pairs.size + 1)
      pairs.each_with_index do |(option, desc), i|
        item = FFI::NcSelectorItem.new(vec + (i * FFI::NcSelectorItem.size))
        item[:option] = c_text(option, keep)
        item[:desc] = c_text(desc, keep)
      end
      opts[:items] = vec
      opts[:defidx] = Util.integer!(default, 'default', 0..[pairs.size - 1, 0].max)
      opts[:maxdisplay] = Util.uint!(max_display, 'max_display')
      opts[:opchannels] = Util.channels_value(opchannels, 'opchannels')
      opts[:descchannels] = Util.channels_value(descchannels, 'descchannels')
      opts[:titlechannels] = Util.channels_value(titlechannels, 'titlechannels')
      opts[:footchannels] = Util.channels_value(footchannels, 'footchannels')
      opts[:boxchannels] = Util.channels_value(boxchannels, 'boxchannels')
      ptr = FFI.ncselector_create(plane.to_ptr, opts)
      if ptr.null?
        plane_destroyed_on_failure!(plane)
        ctx.raise_callback_errors!
        raise WidgetError, 'ncselector_create ha restituito NULL (il piano è stato distrutto)'
      end
      attach!(ptr, plane)
    end

    # Piano del selettore (+ncselector_plane+): lo stesso Plane passato a
    # {#initialize}.
    #
    # @return [Plane]
    # @raise [ClosedError] se il selettore è chiuso
    def plane = @context.plane_for(FFI.ncselector_plane(to_ptr))

    # Aggiunge una voce in fondo (+ncselector_additem+), fa crescere il piano
    # se serve e ridisegna. La selezione non cambia. Le opzioni uguali sono
    # ammesse, ma {#selected} non le distingue.
    #
    # @param option [String] testo dell'opzione
    # @param desc [String, nil] descrizione (nil = vuota)
    # @return [self]
    # @raise [WidgetError] se +ncselector_additem+ fallisce
    # @raise [TypeError, ArgumentError] se un testo non è valido
    # @raise [Exception] l'eccezione di un callback Ruby di resize di un figlio
    #   del piano
    # @raise [ClosedError] se il selettore è chiuso
    def add_item(option, desc: nil)
      ptr = to_ptr
      keep = []
      item = FFI::NcSelectorItem.new
      item[:option] = c_text(text!(option, 'option'), keep)
      item[:desc] = c_text(desc.nil? ? nil : text!(desc, 'desc'), keep)
      rc = FFI.ncselector_additem(ptr, item)
      @context.raise_callback_errors!
      Util.check!(rc, WidgetError, 'ncselector_additem')
      self
    end

    # Opzione selezionata (+ncselector_selected+).
    #
    # @return [String, nil] nil se il selettore non ha voci
    # @raise [ClosedError] se il selettore è chiuso
    def selected = Util.utf8(FFI.ncselector_selected(to_ptr))

    # Seleziona la voce successiva, dopo l'ultima la prima
    # (+ncselector_nextitem+), e ridisegna.
    #
    # @return [String, nil] l'opzione selezionata; nil se il selettore non ha voci
    # @raise [ClosedError] se il selettore è chiuso
    def next_item = Util.utf8(FFI.ncselector_nextitem(to_ptr))

    # Seleziona la voce precedente, prima della prima l'ultima
    # (+ncselector_previtem+), e ridisegna.
    #
    # @return [String, nil] l'opzione selezionata; nil se il selettore non ha voci
    # @raise [ClosedError] se il selettore è chiuso
    def prev_item = Util.utf8(FFI.ncselector_previtem(to_ptr))

    # Passa un evento al selettore (+ncselector_offer_input+): frecce su e
    # giù e rotella spostano la selezione di una voce, PagSu e PagGiù di una
    # pagina, un clic (rilascio del tasto 1) sulle frecce di scorrimento o su
    # una voce la seleziona. I rilasci dei tasti, Invio ed Esc non sono
    # consumati. Ridisegna il piano, senza render.
    #
    # @param input [Input] evento, per esempio da {Context#get}
    # @return [Boolean] true se il selettore ha consumato l'evento; false anche
    #   per un evento vuoto (id 0 o 0xffffffff)
    # @raise [TypeError] se input non è un Input
    # @raise [ClosedError] se il selettore è chiuso
    def offer_input(input)
      ptr = to_ptr
      ni = input_struct(input)
      return false if ni.nil?

      FFI.ncselector_offer_input(ptr, ni)
    end

    private

    # +ncselector_destroy+ con NULL al posto del char** dell'opzione
    # selezionata: con un selettore senza voci il C la leggerebbe da un
    # vettore NULL (selector.c:273). L'opzione si legge prima con {#selected}.
    def destroy_native = FFI.ncselector_destroy(to_ptr, nil)

    # @return [Array<Array(String, String)>] coppie validate [opzione,
    #   descrizione o nil]
    def item_pairs(items)
      items = items.to_a if items.is_a?(Hash)
      raise TypeError, "items deve essere un Array o un Hash, non #{items.class}" unless items.is_a?(Array)

      items.each_with_index.map do |item, i|
        item = [item] if item.is_a?(String)
        unless item.is_a?(Array) && item.size.between?(1, 2)
          raise TypeError, "items[#{i}] deve essere una String o [opzione, descrizione], non #{item.inspect}"
        end

        option, desc = item
        [text!(option, "items[#{i}] (opzione)"), desc.nil? ? nil : text!(desc, "items[#{i}] (descrizione)")]
      end
    end
  end
end
