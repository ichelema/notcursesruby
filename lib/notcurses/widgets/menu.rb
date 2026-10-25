# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Menu (+ncmenu+): barra di sezioni in cima (o in fondo) a un piano; ogni
  # sezione si srotola in un riquadro di voci.
  #
  # Il menu crea un proprio piano, figlio di parent, largo quanto parent e
  # alto quanto la sezione più lunga più tre righe, con lo sfondo trasparente;
  # parent resta del chiamante. Il piano del menu segue la larghezza di parent
  # quando parent cambia dimensione (con bottom: true non torna in basso,
  # 3.0.17) e viene distrutto alla chiusura (vedi {Widget}). I metodi
  # ridisegnano senza fare render: chiama {Context#render}.
  #
  # Le voci si possono disabilitare ({#set_item_enabled}): una voce
  # disabilitata è grigia e saltata dalla navigazione; una sezione senza voci
  # abilitate e senza separatori ha l'intestazione grigia e non si srotola.
  #
  # Scorciatoie: quelle delle sezioni le gestisce {#offer_input}, che le
  # confronta con l'evento come +ncinput_equal_p+ (id, modificatori, e y, x
  # in celle e pixel, che per un tasto valgono 0); quelle delle voci il C le
  # mostra accanto alla voce ("Alt+", "Ctrl+") ma non le gestisce: confrontale
  # nell'applicazione con {Item#shortcut} ({Input#==}). Il wrapper scrive le
  # scorciatoie come notcurses produce gli eventi: con Ctrl, Shift o CapsLock
  # una lettera ASCII minuscola diventa maiuscola (Ctrl+q arriva come 'Q' con
  # Ctrl), evtype :press, coordinate 0.
  #
  # NCMENU_OPTION_HIDING non è offerto: in 3.0.17 non è implementato.
  #
  # @example
  #   quit = Notcurses::Input.synthesize('Q'.ord, modifiers: [:ctrl]) # Ctrl+q
  #   menu = Notcurses::Menu.new(nc.stdplane, sections: [
  #     { name: 'File', shortcut: Notcurses::Input.synthesize('f'.ord, modifiers: [:alt]),
  #       items: ['Nuovo', nil, { desc: 'Esci', shortcut: quit }] },
  #     :right,
  #     { name: 'Aiuto', items: ['Informazioni'] }
  #   ])
  #   loop do
  #     ev = nc.get
  #     break if ev == quit || (ev.id == Notcurses::Key::ENTER && menu.selected&.desc == 'Esci')
  #     nc.render if menu.offer_input(ev)
  #   end
  class Menu
    include Widget
    extend Resource::ClassMethods

    # Voce di un menu, come la restituiscono {Menu#selected},
    # {Menu#mouse_selected}, {Menu#next_item} e {Menu#prev_item}. Value object
    # immutabile.
    class Item
      # @return [String] nome della sezione della voce
      attr_reader :section
      # @return [String] descrizione della voce
      attr_reader :desc
      # @return [Input, nil] scorciatoia mostrata accanto alla voce
      attr_reader :shortcut

      # @api private
      def initialize(section, desc, shortcut)
        @section = section
        @desc = desc
        @shortcut = shortcut
        freeze
      end

      # @return [String]
      def inspect = "#<Notcurses::Menu::Item #{@section.inspect} / #{@desc.inspect}>"
    end

    # Crea il menu (+ncmenu_create+) e ne disegna l'intestazione.
    #
    # @param parent [Plane] piano su cui sta il menu (anche lo stdplane): resta
    #   del chiamante
    # @param sections [Array<Hash, Symbol>] sezioni, da sinistra a destra.
    #   Ogni sezione è un Hash +{ name: String, items: Array, shortcut: Input
    #   o nil }+; ogni voce di +items+ è una String (la descrizione), un Hash
    #   +{ desc: String, shortcut: Input o nil }+ o nil (separatore
    #   orizzontale), e serve almeno una voce che non sia un separatore. Il
    #   simbolo +:right+ (al massimo uno, non da solo) allinea a destra le
    #   sezioni che lo seguono. La scorciatoia di una voce deve essere un
    #   carattere stampabile sotto U+0800: da U+0800 il C scrive oltre il
    #   buffer della descrizione, da U+10000 (e per ogni {Key}) il processo
    #   termina (menu.c:103-124)
    # @param bottom [Boolean] NCMENU_OPTION_BOTTOM: barra in fondo a parent
    # @param headerchannels [Channels, Integer] colori della barra e dei bordi
    # @param sectionchannels [Channels, Integer] colori delle voci (la voce
    #   selezionata li inverte)
    # @raise [WidgetError] se +ncmenu_create+ fallisce, o dentro un callback
    #   chiamato da notcurses
    # @raise [TypeError, ArgumentError] se un'opzione non è valida
    # @raise [ClosedError] se parent è chiuso
    def initialize(parent, sections:, bottom: false, headerchannels: 0, sectionchannels: 0)
      raise TypeError, "parent deve essere Notcurses::Plane, non #{parent.class}" unless parent.is_a?(Plane)

      parent_ptr = parent.to_ptr
      ctx = parent.context
      ctx.check_not_in_callback!('Menu.new', WidgetError)
      @sections = mirror_sections(sections)
      keep = [] # MemoryPointer di stringhe e vettori: il C li copia durante la chiamata
      secs = ::FFI::MemoryPointer.new(FFI::NcMenuSection, @sections.size)
      @sections.each_with_index do |sec, si|
        next if sec.nil? # divisore: struct azzerata (name NULL)

        s = FFI::NcMenuSection.new(secs + (si * FFI::NcMenuSection.size))
        s[:name] = c_text(sec[:name], keep)
        s[:itemcount] = sec[:items].size
        s[:items] = c_items(sec[:items], si, keep)
        put_input(s[:shortcut], sec[:shortcut]) if sec[:shortcut]
      end
      opts = FFI::NcMenuOptions.new
      opts[:sections] = secs
      opts[:sectioncount] = @sections.size
      opts[:headerchannels] = Util.channels_value(headerchannels, 'headerchannels')
      opts[:sectionchannels] = Util.channels_value(sectionchannels, 'sectionchannels')
      opts[:flags] = Util.flag(bottom, FFI::NCMENU_OPTION_BOTTOM, 'bottom')
      ptr = Util.check_ptr!(FFI.ncmenu_create(parent_ptr, opts), WidgetError, 'ncmenu_create')
      # il piano del menu lo crea il C e lo distrugge ncmenu_destroy
      attach!(ptr, Plane.new(FFI.ncmenu_plane(ptr), owned: false, context: ctx))
    end

    # Piano del menu (+ncmenu_plane+): figlio di parent, creato dal menu. Non
    # cambiarne lo userptr: il C ci tiene il menu.
    #
    # @return [Plane]
    # @raise [ClosedError] se il menu è chiuso
    def plane = @context.plane_for(FFI.ncmenu_plane(to_ptr))

    # Srotola una sezione (+ncmenu_unroll+), chiudendo quella aperta, e
    # seleziona la sua prima voce abilitata se non ne aveva una selezionata.
    #
    # @param index [Integer] posizione della sezione in sections: (il
    #   divisore conta), 0...sections.size
    # @return [Boolean] true se la sezione è aperta; false, senza cambiare
    #   nulla, per il divisore e per una sezione senza voci abilitate
    # @raise [WidgetError] se il disegno fallisce
    # @raise [TypeError, ArgumentError] se index non è un indice valido
    # @raise [ClosedError] se il menu è chiuso
    def unroll(index)
      ptr = to_ptr
      Util.integer!(index, 'index', 0...@sections.size)
      return false unless unrollable?(index)

      Util.check!(FFI.ncmenu_unroll(ptr, index), WidgetError, 'ncmenu_unroll')
      true
    end

    # Chiude la sezione aperta (+ncmenu_rollup+); senza sezioni aperte non fa
    # nulla.
    #
    # @return [self]
    # @raise [WidgetError] se il disegno dell'intestazione fallisce
    # @raise [ClosedError] se il menu è chiuso
    def rollup
      Util.check!(FFI.ncmenu_rollup(to_ptr), WidgetError, 'ncmenu_rollup')
      self
    end

    # Srotola la sezione successiva che si può aprire, dopo l'ultima la prima
    # (+ncmenu_nextsection+); senza sezioni aperte parte dalla prima.
    #
    # @return [Boolean] true se una sezione è aperta; false, senza chiamare il
    #   C, se nessuna sezione si può aprire (il C resterebbe in un ciclo
    #   infinito, menu.c:566-574)
    # @raise [WidgetError] se il disegno fallisce
    # @raise [ClosedError] se il menu è chiuso
    def next_section
      ptr = to_ptr
      return false unless any_unrollable?

      Util.check!(FFI.ncmenu_nextsection(ptr), WidgetError, 'ncmenu_nextsection')
      true
    end

    # Srotola la sezione precedente che si può aprire, prima della prima
    # l'ultima (+ncmenu_prevsection+); senza sezioni aperte parte dall'ultima.
    #
    # @return [Boolean] true se una sezione è aperta; false, senza chiamare il
    #   C, se nessuna sezione si può aprire (il C resterebbe in un ciclo
    #   infinito, menu.c:581-589)
    # @raise [WidgetError] se il disegno fallisce
    # @raise [ClosedError] se il menu è chiuso
    def prev_section
      ptr = to_ptr
      return false unless any_unrollable?

      Util.check!(FFI.ncmenu_prevsection(ptr), WidgetError, 'ncmenu_prevsection')
      true
    end

    # Seleziona la voce abilitata successiva della sezione aperta, dopo
    # l'ultima la prima (+ncmenu_nextitem+). Senza sezioni aperte srotola la
    # prima sezione e si sposta dalla sua voce selezionata.
    #
    # @return [Item, nil] la voce selezionata (come {#selected}); nil, senza
    #   cambiare nulla, se nessuna sezione si può aprire
    # @raise [WidgetError] se il disegno fallisce
    # @raise [ClosedError] se il menu è chiuso
    def next_item
      ptr = to_ptr
      return nil unless item_move_ready?(ptr)

      Util.check!(FFI.ncmenu_nextitem(ptr), WidgetError, 'ncmenu_nextitem')
      selected
    end

    # Seleziona la voce abilitata precedente della sezione aperta, prima della
    # prima l'ultima (+ncmenu_previtem+). Senza sezioni aperte srotola la
    # prima sezione e si sposta dalla sua voce selezionata.
    #
    # @return [Item, nil] la voce selezionata (come {#selected}); nil, senza
    #   cambiare nulla, se nessuna sezione si può aprire
    # @raise [WidgetError] se il disegno fallisce
    # @raise [ClosedError] se il menu è chiuso
    def prev_item
      ptr = to_ptr
      return nil unless item_move_ready?(ptr)

      Util.check!(FFI.ncmenu_previtem(ptr), WidgetError, 'ncmenu_previtem')
      selected
    end

    # Voce selezionata nella sezione aperta (+ncmenu_selected+).
    #
    # @return [Item, nil] nil se nessuna sezione è aperta, se la sezione non
    #   ha una voce selezionata, o se la voce selezionata è disabilitata (in
    #   3.0.17 disabilitare una voce non sposta la selezione)
    # @raise [ClosedError] se il menu è chiuso
    def selected
      ni = FFI::NcInput.new
      item_at(FFI.ncmenu_selected(to_ptr, ni), ni)
    end

    # Voce sotto un clic (+ncmenu_mouse_selected+), senza cambiare la
    # selezione. Serve per decidere da sé, prima di {#offer_input}, cosa fare
    # di un clic.
    #
    # @param click [Input] evento del mouse: conta solo il rilascio del tasto 1
    #   ({Key::BUTTON1}, evtype :release), con le coordinate dell'area di
    #   rendering, su una voce abilitata della sezione aperta. Il calcolo del
    #   C è impreciso per le sezioni allineate a destra o spostate perché non
    #   entravano
    # @return [Item, nil] la voce, o nil
    # @raise [TypeError] se click non è un Input
    # @raise [ClosedError] se il menu è chiuso
    def mouse_selected(click)
      ptr = to_ptr
      ni = input_struct(click)
      return nil if ni.nil?

      out = FFI::NcInput.new
      item_at(FFI.ncmenu_mouse_selected(ptr, ni, out), out)
    end

    # Passa un evento al menu (+ncmenu_offer_input+). Consuma:
    # - il rilascio del tasto 1 sull'intestazione: srotola la sezione sotto il
    #   clic, o la chiude se è già aperta; altrove sull'intestazione chiude la
    #   sezione aperta;
    # - il rilascio del tasto 1 su una voce abilitata della sezione aperta: la
    #   seleziona (il C di 3.0.17 restituisce false, il wrapper true);
    # - la scorciatoia di una sezione che si può aprire: la srotola;
    # - con una sezione aperta: sinistra e destra cambiano sezione, su, giù e
    #   la rotella cambiano voce, Esc chiude la sezione.
    # I clic fuori dal menu non chiudono la sezione aperta, e le scorciatoie
    # delle voci non sono gestite. Un clic su un separatore può togliere la
    # selezione ({#selected} restituisce nil fino al tasto successivo): il C
    # di 3.0.17 legge il flag non inizializzato del separatore (menu.c:722).
    # Ridisegna il piano, senza render.
    #
    # @param input [Input] evento, per esempio da {Context#get}
    # @return [Boolean] true se il menu ha consumato l'evento; false anche per
    #   un evento vuoto (id 0, che il C confonderebbe con la scorciatoia
    #   vuota di una sezione, o 0xffffffff)
    # @raise [TypeError] se input non è un Input
    # @raise [ClosedError] se il menu è chiuso
    def offer_input(input)
      ptr = to_ptr
      ni = input_struct(input)
      return false if ni.nil?
      return true if FFI.ncmenu_offer_input(ptr, ni)

      # menu.c:721-726: il clic su una voce abilitata la seleziona ma restituisce false
      input.id == Key::BUTTON1 && input.release? && !FFI.ncmenu_mouse_selected(ptr, ni, nil).nil?
    end

    # Abilita o disabilita una voce (+ncmenu_item_set_status+) e ridisegna.
    #
    # Bug di 3.0.17 aggirati. La logica del C è invertita: una chiamata che
    # cambia lo stato aggiorna solo il flag della voce, una seconda con lo
    # stesso valore aggiorna contatore, intestazione e disegno; il wrapper
    # tiene lo stato e chiama il C due volte, solo quando lo stato cambia. Il
    # C confronta con strcmp i nomi delle sezioni e le descrizioni delle voci
    # che precedono quella cercata e va in segfault sul divisore e sui
    # separatori (menu.c:788-791): il wrapper rifiuta le sezioni dopo il
    # divisore e le voci precedute da un separatore. Con nomi ripetuti vale la
    # prima sezione e la prima voce, come nel C.
    #
    # @param section [String] nome della sezione
    # @param item [String] descrizione della voce
    # @param enabled [Boolean]
    # @return [self]
    # @raise [ArgumentError] se la sezione o la voce non esistono
    # @raise [WidgetError] per una sezione dopo il divisore o una voce dopo un
    #   separatore, o se +ncmenu_item_set_status+ fallisce
    # @raise [TypeError] se un argomento non ha il tipo giusto
    # @raise [ClosedError] se il menu è chiuso
    def set_item_enabled(section, item, enabled)
      ptr = to_ptr
      Util.bool!(enabled, 'enabled')
      si, ii = locate!(section, item)
      divider = @sections.index(nil)
      if divider && si > divider
        raise WidgetError, "set_item_enabled: la sezione #{section.inspect} viene dopo il divisore " \
                           '(notcurses 3.0.17 andrebbe in segfault)'
      end
      sec = @sections[si]
      if sec[:items].first(ii).include?(nil)
        raise WidgetError, "set_item_enabled: la voce #{item.inspect} viene dopo un separatore " \
                           '(notcurses 3.0.17 andrebbe in segfault)'
      end
      return self if sec[:enabled][ii] == enabled

      2.times do
        rc = FFI.ncmenu_item_set_status(ptr, sec[:name], sec[:items][ii].desc, enabled)
        Util.check!(rc, WidgetError, 'ncmenu_item_set_status')
      end
      sec[:enabled][ii] = enabled
      self
    end

    # @param section [String] nome della sezione (con nomi ripetuti, la prima)
    # @param item [String] descrizione della voce (con voci ripetute, la prima)
    # @return [Boolean] true se la voce è abilitata (vedi {#set_item_enabled})
    # @raise [ArgumentError] se la sezione o la voce non esistono
    # @raise [TypeError] se un argomento non è una String
    # @raise [ClosedError] se il menu è chiuso
    def item_enabled?(section, item)
      to_ptr
      si, ii = locate!(section, item)
      @sections[si][:enabled][ii]
    end

    private

    def destroy_native = FFI.ncmenu_destroy(to_ptr)

    # Specchio Ruby delle sezioni: nil per il divisore; per le altre
    # { name:, shortcut:, items: [Item o nil], enabled: [Boolean o nil] }.
    def mirror_sections(sections)
      raise TypeError, "sections deve essere un Array, non #{sections.class}" unless sections.is_a?(Array)
      raise ArgumentError, 'sections deve avere almeno una sezione' if sections.empty?
      raise ArgumentError, 'sections ammette al massimo un divisore :right' if sections.count(:right) > 1
      raise ArgumentError, "il divisore :right non può essere l'unica sezione" if sections == [:right]

      sections.each_with_index.map do |sec, si|
        next nil if sec == :right

        where = "sections[#{si}]"
        raise TypeError, "#{where} deve essere un Hash o :right, non #{sec.inspect}" unless sec.is_a?(Hash)

        extra = sec.keys - %i[name items shortcut]
        raise ArgumentError, "#{where}: chiavi sconosciute #{extra.inspect}" unless extra.empty?

        name = text!(sec[:name], "#{where}[:name]")
        items = sec[:items]
        raise TypeError, "#{where}[:items] deve essere un Array, non #{items.class}" unless items.is_a?(Array)
        raise ArgumentError, "#{where} deve avere almeno una voce che non sia un separatore" if items.compact.empty?

        entries = items.each_with_index.map { |it, ii| mirror_item(name, it, "#{where}[:items][#{ii}]") }
        { name: name, shortcut: shortcut!(sec[:shortcut], "#{where}[:shortcut]", item: false),
          items: entries, enabled: entries.map { |entry| entry && true } }
      end
    end

    # @return [Item, nil] nil per un separatore
    def mirror_item(section, item, where)
      case item
      when nil then nil
      when String then Item.new(section, text!(item, where), nil)
      when Hash
        extra = item.keys - %i[desc shortcut]
        raise ArgumentError, "#{where}: chiavi sconosciute #{extra.inspect}" unless extra.empty?

        Item.new(section, text!(item[:desc], "#{where}[:desc]"), shortcut!(item[:shortcut], "#{where}[:shortcut]", item: true))
      else raise TypeError, "#{where} deve essere una String, un Hash o nil (separatore), non #{item.class}"
      end
    end

    # Scorciatoia come notcurses produce l'evento del tasto (in.c:490-498):
    # lettera ASCII minuscola resa maiuscola con Ctrl, Shift o CapsLock,
    # evtype :press, y = x = ypx = xpx = 0 (Input.synthesize).
    def shortcut!(input, where, item:)
      return nil if input.nil?
      raise TypeError, "#{where} deve essere Notcurses::Input o nil, non #{input.class}" unless input.is_a?(Input)

      id = input.id
      raise ArgumentError, "#{where}: un Input con id 0 non è una scorciatoia (usa nil)" if id.zero?
      if item && !(id.between?(0x20, 0x7ff) && !id.between?(0x7f, 0x9f))
        raise ArgumentError, "#{where}: la scorciatoia di una voce deve essere un carattere stampabile sotto U+0800 " \
                             "(notcurses 3.0.17 scrive oltre il buffer della descrizione), non #{format('0x%x', id)}"
      end
      upcase = input.modifiers.anybits?(FFI::NCKEY_MOD_CTRL | FFI::NCKEY_MOD_SHIFT | FFI::NCKEY_MOD_CAPSLOCK)
      id -= 0x20 if upcase && id.between?(0x61, 0x7a)
      Input.synthesize(id, modifiers: input.modifiers)
    end

    # Vettore C delle voci di una sezione. Ogni voce porta in ypx/xpx della
    # sua scorciatoia, campi che il C non usa per le voci, la posizione
    # (sezione, voce): ncmenu_selected e ncmenu_mouse_selected ricopiano la
    # scorciatoia, e il wrapper riconosce la voce anche con descrizioni ripetute.
    def c_items(items, si, keep)
      vec = ::FFI::MemoryPointer.new(FFI::NcMenuItem, items.size)
      keep << vec
      items.each_with_index do |item, ii|
        next if item.nil? # separatore: desc NULL

        entry = FFI::NcMenuItem.new(vec + (ii * FFI::NcMenuItem.size))
        entry[:desc] = c_text(item.desc, keep)
        put_input(entry[:shortcut], item.shortcut) if item.shortcut
        entry[:shortcut][:ypx] = si
        entry[:shortcut][:xpx] = ii
      end
      vec
    end

    # Copia l'evento nella struct ncinput annidata dst.
    def put_input(dst, input)
      dst.to_ptr.put_bytes(0, input.to_ffi.to_ptr.get_bytes(0, FFI::NcInput.size))
    end

    # @return [Item, nil] voce con la posizione copiata dal C in ni; nil se
    #   desc è NULL o la voce è disabilitata
    def item_at(desc, ni)
      return nil if desc.nil?

      sec = ni[:ypx].negative? ? nil : @sections[ni[:ypx]]
      return nil if sec.nil? || ni[:xpx].negative? || !sec[:enabled][ni[:xpx]]

      sec[:items][ni[:xpx]]
    end

    # Il C srotola una sezione solo se ha un nome e il suo contatore (voci
    # abilitate più separatori, menu.c:178) è positivo.
    def unrollable?(index)
      sec = @sections[index]
      !sec.nil? && sec[:enabled].any? { |state| state != false }
    end

    def any_unrollable? = @sections.each_index.any? { |i| unrollable?(i) }

    # ncmenu_nextitem e ncmenu_previtem senza sezioni aperte srotolano la
    # sezione 0; se non si può aprire leggono e scrivono sections[-1]
    # (menu.c:599, 620). Senza una voce selezionata il wrapper apre prima la
    # prima sezione che si può aprire.
    def item_move_ready?(ptr)
      return true if unrollable?(0) || !FFI.ncmenu_selected(ptr, nil).nil?

      first = @sections.each_index.find { |i| unrollable?(i) }
      return false if first.nil?

      Util.check!(FFI.ncmenu_unroll(ptr, first), WidgetError, 'ncmenu_unroll')
      true
    end

    # Posizione della prima sezione con quel nome e della sua prima voce con
    # quella descrizione, come le cerca il C.
    def locate!(section, item)
      name = Util.string!(section, 'section')
      desc = Util.string!(item, 'item')
      si = @sections.index { |sec| sec && sec[:name] == name }
      raise ArgumentError, "sezione #{section.inspect} inesistente" if si.nil?

      ii = @sections[si][:items].index { |entry| entry&.desc == desc }
      raise ArgumentError, "voce #{item.inspect} inesistente nella sezione #{section.inspect}" if ii.nil?

      [si, ii]
    end
  end
end
