# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Selettore multiplo (+ncmultiselector+): elenco di opzioni con una casella
  # ciascuna; lo spazio commuta la voce corrente, frecce, PagSu/PagGiù, rotella
  # e clic spostano la voce corrente. L'elenco è fisso: il C non permette di
  # aggiungere o togliere voci.
  #
  # Il widget prende possesso del piano ricevuto (vedi {Widget}): lo
  # ridimensiona alle righe e colonne che servono, lo ridisegna a ogni
  # cambiamento e lo distrugge alla chiusura (i figli del piano passano al suo
  # genitore). I metodi ridisegnano senza fare render: chiama {Context#render}.
  # Caselle, frecce e bordi sono disegnati in UTF-8 anche su un terminale che
  # non lo supporta (3.0.17).
  #
  # @example
  #   plane = nc.stdplane.create_child(rows: 1, cols: 1, y: 1, x: 1)
  #   ms = Notcurses::MultiSelector.new(plane, items: [['pane', '1 €', true], ['latte', '2 €']])
  #   ms.offer_input(Notcurses::Input.synthesize(' '.ord))
  #   ms.selected #=> [false, false]
  class MultiSelector
    include Widget
    extend Resource::ClassMethods

    # Crea il selettore multiplo sul piano (+ncmultiselector_create+) e lo
    # disegna.
    #
    # @param plane [Plane] piano posseduto dal wrapper, non lo stdplane e non
    #   già di un widget: passa al widget. Il suo genitore (per una radice, il
    #   piano stesso) deve avere almeno 5 righe (7 con title) e le colonne che
    #   servono: il wrapper lo controlla prima, perché il C distruggerebbe il piano
    # @param items [Array<String, Array>, Hash{String => String}] voci, almeno
    #   una: una String (opzione), un Array [opzione, descrizione = "",
    #   selezionata = false] (descrizione nil = vuota), oppure un Hash opzione
    #   => descrizione
    # @param title [String, nil] titolo, in un riquadro sopra il corpo
    # @param secondary [String, nil] testo sul bordo superiore del corpo
    # @param footer [String, nil] testo sul bordo inferiore del corpo
    # @param max_display [Integer] voci visibili al massimo, 0..UINT_MAX (0 = tutte)
    # @param opchannels [Channels, Integer] colori delle opzioni (la voce
    #   corrente li inverte)
    # @param descchannels [Channels, Integer] colori delle descrizioni e delle caselle
    # @param titlechannels [Channels, Integer] colori del titolo
    # @param footchannels [Channels, Integer] colori di secondary e footer
    # @param boxchannels [Channels, Integer] colori dei bordi
    # @raise [WidgetError] se il genitore è troppo piccolo; se
    #   +ncmultiselector_create+ fallisce (il piano risulta distrutto); se il
    #   piano è lo stdplane, è già di un widget o non è posseduto; dentro un
    #   callback chiamato da notcurses
    # @raise [TypeError, ArgumentError] se un'opzione non è valida (anche items
    #   vuoto: con 0 voci lo spazio va in segfault, selector.c:818)
    # @raise [ClosedError] se il piano è chiuso
    # @raise [Exception] l'eccezione di un callback Ruby di resize di un figlio
    #   del piano: il resize fallito fa fallire la creazione
    def initialize(plane, items:, title: nil, secondary: nil, footer: nil, max_display: 0,
                   opchannels: 0, descchannels: 0, titlechannels: 0, footchannels: 0, boxchannels: 0)
      claim_plane!(plane)
      ctx = plane.context
      ctx.check_not_in_callback!('MultiSelector.new', WidgetError)
      entries = item_entries(items)
      title = text!(title, 'title') unless title.nil?
      secondary = text!(secondary, 'secondary') unless secondary.nil?
      footer = text!(footer, 'footer') unless footer.nil?
      keep = [] # MemoryPointer delle stringhe: il C le copia durante la chiamata
      opts = FFI::NcMultiselectorOptions.new
      opts[:title] = c_text(title, keep)
      opts[:secondary] = c_text(secondary, keep)
      opts[:footer] = c_text(footer, keep)
      # una voce azzerata in più (option NULL) termina il vettore
      vec = ::FFI::MemoryPointer.new(FFI::NcMselectorItem, entries.size + 1)
      entries.each_with_index do |(option, desc, on), i|
        item = FFI::NcMselectorItem.new(vec + (i * FFI::NcMselectorItem.size))
        item[:option] = c_text(option, keep)
        item[:desc] = c_text(desc, keep)
        item[:selected] = on
      end
      opts[:items] = vec
      opts[:maxdisplay] = Util.uint!(max_display, 'max_display')
      opts[:opchannels] = Util.channels_value(opchannels, 'opchannels')
      opts[:descchannels] = Util.channels_value(descchannels, 'descchannels')
      opts[:titlechannels] = Util.channels_value(titlechannels, 'titlechannels')
      opts[:footchannels] = Util.channels_value(footchannels, 'footchannels')
      opts[:boxchannels] = Util.channels_value(boxchannels, 'boxchannels')
      check_room!(plane, entries, title, secondary, footer)
      ptr = FFI.ncmultiselector_create(plane.to_ptr, opts)
      if ptr.null?
        plane_destroyed_on_failure!(plane)
        ctx.raise_callback_errors!
        raise WidgetError, 'ncmultiselector_create ha restituito NULL (il piano è stato distrutto)'
      end
      attach!(ptr, plane)
      @count = entries.size
      @first = entries[0][2] # stato della voce 0: il C non lo restituisce (vedi #selected)
    end

    # Piano del widget (+ncmultiselector_plane+): lo stesso Plane passato a
    # {#initialize}.
    #
    # @return [Plane]
    # @raise [ClosedError] se il widget è chiuso
    def plane = @context.plane_for(FFI.ncmultiselector_plane(to_ptr))

    # Stato delle caselle (+ncmultiselector_selected+), nell'ordine delle voci.
    #
    # Bug di 3.0.17 aggirato: il C non scrive mai lo stato della voce 0
    # (+while(--count)+, selector.c:1006). Il wrapper lo ricava da
    # {#offer_input}: lo spazio commuta solo la voce corrente, quindi se le
    # altre voci non cambiano ha commutato la voce 0.
    #
    # @return [Array<Boolean>] un elemento per voce
    # @raise [WidgetError] se +ncmultiselector_selected+ fallisce
    # @raise [ClosedError] se il widget è chiuso
    def selected = [@first, *rest_flags(to_ptr)]

    # Passa un evento al widget (+ncmultiselector_offer_input+): lo spazio
    # commuta la voce corrente; frecce su e giù e rotella spostano la voce
    # corrente di una, PagSu e PagGiù di una pagina; un clic (rilascio del
    # tasto 1) sulle frecce di scorrimento o su una voce la rende corrente. I
    # rilasci dei tasti e Invio non sono consumati. Ridisegna il piano, senza
    # render.
    #
    # @param input [Input] evento, per esempio da {Context#get}
    # @return [Boolean] true se il widget ha consumato l'evento; false anche
    #   per un evento vuoto (id 0 o 0xffffffff)
    # @raise [TypeError] se input non è un Input
    # @raise [WidgetError] se la lettura dello stato fallisce
    # @raise [ClosedError] se il widget è chiuso
    def offer_input(input)
      ptr = to_ptr
      ni = input_struct(input)
      return false if ni.nil?

      toggle = input.id == 0x20 && !input.release? # il C commuta con ' ', qualunque modificatore
      before = rest_flags(ptr) if toggle
      consumed = FFI.ncmultiselector_offer_input(ptr, ni)
      @first = !@first if toggle && consumed && rest_flags(ptr) == before
      consumed
    end

    private

    def destroy_native = FFI.ncmultiselector_destroy(to_ptr)

    # Stato delle voci 1..n-1 (l'unico che il C scrive).
    def rest_flags(ptr)
      buf = ::FFI::MemoryPointer.new(:bool, @count)
      Util.check!(FFI.ncmultiselector_selected(ptr, buf, @count), WidgetError, 'ncmultiselector_selected')
      buf.get_array_of_uint8(0, @count).drop(1).map { |b| b != 0 }
    end

    # @return [Array<Array(String, String, Boolean)>] terne validate [opzione,
    #   descrizione, selezionata]; la descrizione nil diventa "" (con NULL il
    #   create va in segfault, selector.c:942, 951)
    def item_entries(items)
      items = items.to_a if items.is_a?(Hash)
      raise TypeError, "items deve essere un Array o un Hash, non #{items.class}" unless items.is_a?(Array)
      raise ArgumentError, 'items deve avere almeno una voce (con 0 voci lo spazio va in segfault in 3.0.17)' if items.empty?

      items.each_with_index.map do |item, i|
        item = [item] if item.is_a?(String)
        unless item.is_a?(Array) && item.size.between?(1, 3)
          raise TypeError, "items[#{i}] deve essere una String o [opzione, descrizione, selezionata], non #{item.inspect}"
        end

        option, desc, on = item
        [text!(option, "items[#{i}] (opzione)"), text!(desc || '', "items[#{i}] (descrizione)"),
         Util.bool!(on.nil? ? false : on, "items[#{i}] (selezionata)")]
      end
    end

    # +ncmultiselector_create+ fallisce, e distrugge il piano, se il genitore
    # non ha le righe o le colonne che servono (selector.c:865-880).
    def check_room!(plane, entries, title, secondary, footer)
      parent = FFI.ncplane_parent(plane.to_ptr)
      rows = FFI.ncplane_dim_y(parent)
      cols = FFI.ncplane_dim_x(parent)
      need_rows = title.nil? ? 5 : 7
      longest = entries.map { |option, desc, _| width(option) + width(desc) }.max
      need_cols = [longest + 7, width(secondary) + 2, width(footer) + 2, width(title) + 4].max
      return if rows >= need_rows && cols >= need_cols

      raise WidgetError, "il genitore del piano (#{rows}x#{cols}) è troppo piccolo per il selettore multiplo " \
                         "(servono #{need_rows} righe e #{need_cols} colonne)"
    end

    # Colonne di un testo già validato, 0 per nil.
    def width(text) = text.nil? ? 0 : FFI.ncstrwidth(text, nil, nil)
  end
end
