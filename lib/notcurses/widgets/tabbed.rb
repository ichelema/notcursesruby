# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Schede (+struct nctabbed*+): una riga di intestazioni con i nomi dei tab e,
  # sotto (o sopra, con bottom: true), il piano del contenuto, che il blocco
  # del tab selezionato disegna a ogni {#redraw}.
  #
  # I tab formano una lista circolare: {#leftmost} è il primo tab mostrato
  # nell'intestazione, {#selected} quello selezionato. Come in notcurses, solo
  # {#redraw} disegna: gli altri metodi cambiano lo stato.
  #
  # @example
  #   tabbed = Notcurses::Tabbed.new(plane, separator: ' | ')
  #   tabbed.add('Uno') { |_tab, content| content.erase.putstr('primo', y: 0, x: 0) }
  #   tabbed.add('Due') { |_tab, content| content.erase.putstr('secondo', y: 0, x: 0) }
  #   tabbed.select_next
  #   tabbed.redraw
  #
  # Ciclo di vita: il Tabbed prende possesso del piano e, alla chiusura,
  # distrugge il piano con tutti i suoi discendenti (+ncplane_family_destroy+),
  # anche i piani figli creati dall'utente, che risultano chiusi. Per questo
  # {#initialize} e {#close} rifiutano un piano che ha fra i discendenti il
  # piano di un altro widget aperto.
  #
  # Bug di 3.0.17 non aggirati: l'intestazione non segue la larghezza del
  # piano dopo un resize (tabbed.c:35,39) e con bottom: true sta sulla
  # penultima riga, sopra l'ultima riga del contenuto (tabbed.c:37,191).
  #
  # Bug di 3.0.17 aggirati: +nctabbed_rotate+, +nctab_move_left+ e
  # +nctab_move_right+ senza tab, e un nome o un separatore NULL, vanno in
  # crash (tabbed.c:335-363,247,457,480); +nctab_move+ con after e before ha il
  # controllo di adiacenza invertito (tabbed.c:305) e non aggiorna il primo tab
  # mostrato; nessuna funzione controlla che un tab appartenga al widget.
  class Tabbed
    include Widget
    extend Resource::ClassMethods

    # Caratteri di controllo (C0, DEL, C1): rifiutati in nomi e separatore.
    CONTROL = /[\u0000-\u001f\u007f-\u009f]/
    private_constant :CONTROL

    # Crea le schede sul piano (+nctabbed_create+): una riga di intestazione e
    # il piano del contenuto con le righe restanti.
    #
    # @param plane [Plane] piano del widget, posseduto dal wrapper, con almeno
    #   2 righe; diventa del Tabbed (non lo stdplane, non il piano di un altro
    #   widget)
    # @param selected_channels [Channels, Integer] colori del nome del tab selezionato
    # @param header_channels [Channels, Integer] colori degli altri nomi
    # @param separator_channels [Channels, Integer] colori del separatore
    # @param separator [String, nil] testo fra i nomi; nil = nessuno
    # @param bottom [Boolean] NCTABBED_OPTION_BOTTOM: intestazione in basso
    #   (in 3.0.17 sulla penultima riga)
    # @raise [ArgumentError] se il piano ha meno di 2 righe, o se il separatore
    #   contiene caratteri di controllo o che notcurses non misura
    # @raise [TypeError] se un argomento ha il tipo sbagliato
    # @raise [WidgetError] se il piano non si può dare al widget (stdplane,
    #   piano di un widget o con un widget fra i discendenti, piano preso in
    #   prestito) o se +nctabbed_create+ fallisce (in quel caso notcurses ha
    #   distrutto il piano e i suoi discendenti)
    # @raise [ClosedError] se il piano è chiuso
    def initialize(plane, selected_channels: 0, header_channels: 0, separator_channels: 0, separator: nil,
                   bottom: false)
      claim_plane!(plane)
      raise ArgumentError, "il piano del Tabbed deve avere almeno 2 righe (ne ha #{plane.dim_y})" if plane.dim_y < 2

      opts = FFI::NcTabbedOptions.new
      opts[:selchan] = Util.channels_value(selected_channels, 'selected_channels')
      opts[:hdrchan] = Util.channels_value(header_channels, 'header_channels')
      opts[:sepchan] = Util.channels_value(separator_channels, 'separator_channels')
      sep = Util.c_string(separator.nil? ? nil : Tabbed.label!(separator, 'separator'), 'separator')
      opts[:separator] = sep || ::FFI::Pointer::NULL
      opts[:flags] = Util.flag(bottom, FFI::NCTABBED_OPTION_BOTTOM, 'bottom')
      victims = Tabbed.descendants(plane)
      ptr = FFI.nctabbed_create(plane.to_ptr, opts)
      if ptr.null?
        victims.each(&:invalidate!)
        plane_destroyed_on_failure!(plane)
        raise WidgetError, 'nctabbed_create ha restituito NULL'
      end

      @tabs = {}
      @drawing = false
      attach!(ptr, plane, owns_plane: true)
      @content_plane = Plane.new(FFI.nctabbed_content_plane(ptr), owned: false, context: @context)
      @content_plane.transfer_to(self)
    end

    # Distrugge il widget, i tab e il piano con tutti i discendenti
    # (+nctabbed_destroy+). Idempotente.
    #
    # @return [nil]
    # @raise [WidgetError] dentro un callback chiamato da notcurses, o se un
    #   discendente del piano è il piano di un altro widget aperto (chiudi
    #   prima quel widget)
    def close
      return nil if closed?

      @context.check_not_in_callback!('Notcurses::Tabbed#close', WidgetError)
      victims = Tabbed.descendants(@plane, except: @content_plane)
      super
      victims.each(&:invalidate!)
      @tabs.each_value(&:invalidate!)
      @tabs.clear
      nil
    end
    alias destroy close

    # Piano del widget (+nctabbed_plane+).
    # @return [Plane]
    # @raise [ClosedError] se il widget è chiuso
    def plane = @context.plane_for(FFI.nctabbed_plane(to_ptr))

    # Piano del contenuto (+nctabbed_content_plane+), figlio del piano del
    # widget: {#redraw} lo ridimensiona e lo passa al blocco del tab
    # selezionato. Appartiene al widget ({Plane#close} non fa nulla).
    #
    # @return [Plane]
    # @raise [ClosedError] se il widget è chiuso
    def content_plane = @context.plane_for(FFI.nctabbed_content_plane(to_ptr))

    # Ridisegna intestazione e contenuto (+nctabbed_redraw+): chiama il blocco
    # del tab selezionato con il piano del contenuto, poi scrive i nomi a
    # partire da {#leftmost}. Senza tab cancella l'intestazione.
    #
    # @return [self]
    # @raise [Exception] l'eccezione sollevata dal blocco del tab (i nomi
    #   vengono scritti lo stesso)
    # @raise [WidgetError] dentro il blocco di un tab
    # @raise [ClosedError] se il widget è chiuso
    def redraw
      ptr = idle!
      @drawing = true
      begin
        FFI.nctabbed_redraw(ptr)
      ensure
        @drawing = false
      end
      @context.raise_callback_errors!
      self
    end

    # Fa scorrere l'intestazione finché il nome del tab selezionato è almeno in
    # parte visibile (+nctabbed_ensure_selected_header_visible+). Usa la
    # larghezza dell'intestazione, che in 3.0.17 non segue i resize del piano.
    #
    # @return [self]
    # @raise [WidgetError] dentro il blocco di un tab
    # @raise [ClosedError] se il widget è chiuso
    def ensure_selected_header_visible
      FFI.nctabbed_ensure_selected_header_visible(idle!)
      self
    end

    # Aggiunge un tab (+nctabbed_add+). Senza after: e before: il tab va
    # subito dopo il selezionato; il primo tab diventa selezionato e primo
    # mostrato. Non seleziona il nuovo tab e non ridisegna.
    #
    # @param name [String] nome, senza caratteri di controllo
    # @param after [Tab, nil] il nuovo tab va subito dopo questo
    # @param before [Tab, nil] il nuovo tab va subito prima di questo; con
    #   entrambi, before deve seguire after
    # @yieldparam tab [Tab] il tab
    # @yieldparam content [Plane] il piano del contenuto
    # @return [Tab]
    # @raise [ArgumentError] se il nome non è valido, se after o before non
    #   sono tab aperti di questo widget, o se non sono adiacenti
    # @raise [TypeError] se un argomento ha il tipo sbagliato
    # @raise [WidgetError] se +nctabbed_add+ fallisce, o dentro il blocco di un tab
    # @raise [ClosedError] se il widget è chiuso
    def add(name, after: nil, before: nil, &block)
      ptr = idle!
      text = Tabbed.label!(name, 'name')
      aptr = member_ptr(after, 'after', nil_ok: true)
      bptr = member_ptr(before, 'before', nil_ok: true)
      if after && before && FFI.nctab_next(aptr).address != bptr.address
        raise ArgumentError, 'add: before deve essere il tab subito dopo after'
      end

      tab = Tab.new(self, block)
      tptr = FFI.nctabbed_add(ptr, aptr, bptr, block ? tab.function : ::FFI::Pointer::NULL, text, ::FFI::Pointer::NULL)
      Util.check_ptr!(tptr, WidgetError, 'nctabbed_add')
      tab.attach!(tptr)
      @tabs[tptr.address] = tab
    end

    # Cancella un tab (+nctabbed_del+). Se era selezionato o primo mostrato, il
    # ruolo passa al tab successivo. Non ridisegna.
    #
    # @param tab [Tab] tab aperto di questo widget
    # @return [self]
    # @raise [ArgumentError] se tab non è un tab aperto di questo widget
    # @raise [TypeError] se tab non è un Tab
    # @raise [WidgetError] se +nctabbed_del+ fallisce, o dentro il blocco di un tab
    # @raise [ClosedError] se il widget è chiuso
    def delete(tab)
      ptr = idle!
      tptr = member_ptr(tab, 'tab')
      Util.check!(FFI.nctabbed_del(ptr, tptr), WidgetError, 'nctabbed_del')
      @tabs.delete(tptr.address)
      tab.invalidate!
      self
    end

    # @return [Tab, nil] tab selezionato (+nctabbed_selected+), nil senza tab
    # @raise [ClosedError] se il widget è chiuso
    def selected = tab_for(FFI.nctabbed_selected(to_ptr))

    # @return [Tab, nil] primo tab mostrato nell'intestazione
    #   (+nctabbed_leftmost+), nil senza tab
    # @raise [ClosedError] se il widget è chiuso
    def leftmost = tab_for(FFI.nctabbed_leftmost(to_ptr))

    # @return [Integer] numero di tab (+nctabbed_tabcount+)
    # @raise [ClosedError] se il widget è chiuso
    def tab_count = FFI.nctabbed_tabcount(to_ptr)

    # Tab nell'ordine dell'intestazione, da {#leftmost}.
    #
    # @return [Array<Tab>]
    # @raise [ClosedError] se il widget è chiuso
    def tabs
      ptr = to_ptr
      tab = FFI.nctabbed_leftmost(ptr)
      Array.new(FFI.nctabbed_tabcount(ptr)) do
        current = tab_for(tab)
        tab = FFI.nctab_next(tab)
        current
      end
    end

    # Seleziona un tab (+nctabbed_select+). Non ridisegna.
    #
    # @param tab [Tab] tab aperto di questo widget
    # @return [Tab, nil] il tab selezionato prima
    # @raise [ArgumentError] se tab non è un tab aperto di questo widget
    # @raise [TypeError] se tab non è un Tab
    # @raise [WidgetError] dentro il blocco di un tab
    # @raise [ClosedError] se il widget è chiuso
    def select(tab)
      ptr = idle!
      tab_for(FFI.nctabbed_select(ptr, member_ptr(tab, 'tab')))
    end

    # Seleziona il tab successivo nella lista circolare (+nctabbed_next+). Non
    # ridisegna.
    #
    # @return [Tab, nil] il nuovo tab selezionato, nil senza tab
    # @raise [WidgetError] dentro il blocco di un tab
    # @raise [ClosedError] se il widget è chiuso
    def select_next = tab_for(FFI.nctabbed_next(idle!))

    # Seleziona il tab precedente (+nctabbed_prev+). Non ridisegna.
    #
    # @return [Tab, nil] il nuovo tab selezionato, nil senza tab
    # @raise [WidgetError] dentro il blocco di un tab
    # @raise [ClosedError] se il widget è chiuso
    def select_prev = tab_for(FFI.nctabbed_prev(idle!))

    # Fa scorrere l'intestazione (+nctabbed_rotate+): con amt > 0 il primo tab
    # mostrato diventa quello amt posti più a sinistra, con amt < 0 quello amt
    # posti più a destra. La selezione non cambia. Senza tab non fa nulla (il
    # C andrebbe in crash); amt è ridotto modulo il numero di tab.
    #
    # @param amt [Integer] posti
    # @return [self]
    # @raise [TypeError] se amt non è un Integer
    # @raise [WidgetError] dentro il blocco di un tab
    # @raise [ClosedError] se il widget è chiuso
    def rotate(amt)
      ptr = idle!
      raise TypeError, "amt deve essere Integer, non #{amt.class}" unless amt.is_a?(Integer)

      count = FFI.nctabbed_tabcount(ptr)
      return self if count.zero?

      steps = amt.remainder(count)
      FFI.nctabbed_rotate(ptr, steps) unless steps.zero?
      self
    end

    # @return [Channels] colori dei nomi non selezionati (+nctabbed_hdrchan+)
    # @raise [ClosedError] se il widget è chiuso
    def header_channels = Channels.new(FFI.nctabbed_hdrchan(to_ptr))

    # @return [Channels] colori del nome selezionato (+nctabbed_selchan+)
    # @raise [ClosedError] se il widget è chiuso
    def selected_channels = Channels.new(FFI.nctabbed_selchan(to_ptr))

    # @return [Channels] colori del separatore (+nctabbed_sepchan+)
    # @raise [ClosedError] se il widget è chiuso
    def separator_channels = Channels.new(FFI.nctabbed_sepchan(to_ptr))

    # Cambia i colori dei nomi non selezionati (+nctabbed_set_hdrchan+), dal
    # prossimo {#redraw}.
    #
    # @param channels [Channels, Integer]
    # @raise [TypeError, ArgumentError] se channels non è valido
    # @raise [WidgetError] dentro il blocco di un tab
    # @raise [ClosedError] se il widget è chiuso
    def header_channels=(channels)
      FFI.nctabbed_set_hdrchan(idle!, Util.channels_value(channels, 'channels'))
    end

    # Cambia i colori del nome selezionato (+nctabbed_set_selchan+).
    #
    # @param channels [Channels, Integer]
    # @raise [TypeError, ArgumentError] se channels non è valido
    # @raise [WidgetError] dentro il blocco di un tab
    # @raise [ClosedError] se il widget è chiuso
    def selected_channels=(channels)
      FFI.nctabbed_set_selchan(idle!, Util.channels_value(channels, 'channels'))
    end

    # Cambia i colori del separatore (+nctabbed_set_sepchan+).
    #
    # @param channels [Channels, Integer]
    # @raise [TypeError, ArgumentError] se channels non è valido
    # @raise [WidgetError] dentro il blocco di un tab
    # @raise [ClosedError] se il widget è chiuso
    def separator_channels=(channels)
      FFI.nctabbed_set_sepchan(idle!, Util.channels_value(channels, 'channels'))
    end

    # @return [String, nil] separatore (+nctabbed_separator+), nil se non c'è
    # @raise [ClosedError] se il widget è chiuso
    def separator = Util.utf8(FFI.nctabbed_separator(to_ptr))

    # Cambia il separatore (+nctabbed_set_separator+). "" = nessun separatore
    # visibile (notcurses non permette di tornare a NULL).
    #
    # @param separator [String] senza caratteri di controllo
    # @raise [ArgumentError] se separator è nil (il C andrebbe in crash) o non
    #   è valido
    # @raise [TypeError] se separator non è una String
    # @raise [WidgetError] se la copia fallisce, o dentro il blocco di un tab
    # @raise [ClosedError] se il widget è chiuso
    def separator=(separator)
      ptr = idle!
      raise ArgumentError, 'separator non può essere nil: usa "" per non mostrarlo' if separator.nil?

      text = Tabbed.label!(separator, 'separator')
      Util.check!(FFI.nctabbed_set_separator(ptr, text), WidgetError, 'nctabbed_set_separator')
    end

    # @return [Integer] colonne del separatore (+nctabbed_separator_width+), 0 senza
    # @raise [ClosedError] se il widget è chiuso
    def separator_width = FFI.nctabbed_separator_width(to_ptr)

    # Puntatore del widget fuori dal blocco di un tab.
    # @api private
    # @raise [WidgetError] dentro il blocco di un tab
    def idle!
      raise WidgetError, 'Notcurses::Tabbed: metodo non permesso dentro il blocco di un tab' if @drawing

      to_ptr
    end

    # Puntatore C di un tab aperto di questo widget.
    # @api private
    # @raise [TypeError, ArgumentError] se tab non è un tab aperto di questo widget
    def member_ptr(tab, name, nil_ok: false)
      return ::FFI::Pointer::NULL if nil_ok && tab.nil?
      raise TypeError, "#{name} deve essere Notcurses::Tab, non #{tab.class}" unless tab.is_a?(Tab)
      raise ArgumentError, "#{name} non è un tab aperto di questo Tabbed" if tab.closed? || !tab.tabbed.equal?(self)

      tab.to_ptr
    end

    # Tab Ruby di un nctab* di questo widget.
    # @api private
    # @return [Tab, nil] nil per NULL
    def tab_for(ptr) = ptr.null? ? nil : @tabs.fetch(ptr.address)

    # Testo valido per nomi e separatore.
    # @api private
    # @return [String]
    # @raise [TypeError, ArgumentError] se il testo non è valido
    def self.label!(value, name)
      text = Util.string!(value, name)
      raise ArgumentError, "#{name} = #{value.inspect} contiene caratteri di controllo" if text.match?(CONTROL)

      Notcurses.strwidth(text)
      text
    end

    # Piani conosciuti che discendono da plane; rifiuta quelli di un widget
    # aperto, che il family destroy del C distruggerebbe sotto il widget.
    # @api private
    # @return [Array<Plane>]
    # @raise [WidgetError] se un discendente è il piano di un altro widget
    def self.descendants(plane, except: nil)
      ptr = plane.to_ptr
      victims = plane.context.tracked_planes.select do |other|
        !other.equal?(plane) && FFI.ncplane_descendant_p(other.address_ptr, ptr) != 0
      end
      if victims.any? { |other| other.widget_plane? && !other.equal?(except) }
        raise WidgetError, 'un discendente del piano è il piano di un widget aperto (chiudi prima quel widget)'
      end

      victims
    end

    private

    def destroy_native
      FFI.nctabbed_destroy(@ptr)
    end
  end

  # Tab di un {Tabbed} (+struct nctab*+). Si ottiene da {Tabbed#add}; resta
  # valido fino a {Tabbed#delete} o alla chiusura del widget (poi
  # ClosedError).
  class Tab
    include Resource

    # @return [Tabbed] widget del tab
    # @api private
    attr_reader :tabbed

    # @return [#call, nil] blocco che disegna il contenuto quando il tab è
    #   selezionato, chiamato con (tab, piano del contenuto)
    attr_reader :callback

    # @api private
    # @return [::FFI::Function] trampolino del tabcb
    attr_reader :function

    # Tab non ancora inserito: {Tabbed#add} lo crea prima della chiamata C.
    # @api private
    def initialize(tabbed, callback)
      @tabbed = tabbed
      @owner = tabbed
      @callback = callback
      @ptr = nil
      @closed = false
      ctx = tabbed.context
      @function = ::FFI::Function.new(:void, %i[pointer pointer pointer]) do |_tab, plane_ptr, _curry|
        Util.guard(ctx.callback_errors, nil) do
          ctx.callback_scope { @callback&.call(self, ctx.plane_for(plane_ptr)) }
        end
      end
    end

    # @api private
    def attach!(ptr)
      @ptr = ptr
    end

    # Tab cancellato dal C: chiuso, trampolino rilasciato.
    # @api private
    def invalidate!
      @closed = true
      @function = nil
      @callback = nil
    end

    # @return [String] nome (+nctab_name+)
    # @raise [ClosedError] se il tab è chiuso
    def name = Util.utf8(FFI.nctab_name(to_ptr))

    # Cambia il nome (+nctab_set_name+), dal prossimo {Tabbed#redraw}.
    #
    # @param name [String] nome, senza caratteri di controllo
    # @raise [ArgumentError, TypeError] se name non è valido (nil compreso: il
    #   C andrebbe in crash)
    # @raise [WidgetError] se la copia fallisce, o dentro il blocco di un tab
    # @raise [ClosedError] se il tab è chiuso
    def name=(name)
      @tabbed.idle!
      ptr = to_ptr
      Util.check!(FFI.nctab_set_name(ptr, Tabbed.label!(name, 'name')), WidgetError, 'nctab_set_name')
    end

    # @return [Integer] colonne del nome (+nctab_name_width+)
    # @raise [ClosedError] se il tab è chiuso
    def name_width = FFI.nctab_name_width(to_ptr)

    # @return [Tab] tab a destra nella lista circolare (+nctab_next+); con un
    #   solo tab, il tab stesso
    # @raise [ClosedError] se il tab è chiuso
    def next = @tabbed.tab_for(FFI.nctab_next(to_ptr))

    # @return [Tab] tab a sinistra nella lista circolare (+nctab_prev+)
    # @raise [ClosedError] se il tab è chiuso
    def prev = @tabbed.tab_for(FFI.nctab_prev(to_ptr))

    # Cambia il blocco del tab (+nctab_set_cb+), dal prossimo {Tabbed#redraw}.
    #
    # @param callback [#call, nil] oggetto con +call(tab, content_plane)+, o
    #   nil per nessun disegno
    # @raise [TypeError] se callback non risponde a call
    # @raise [WidgetError] dentro il blocco di un tab
    # @raise [ClosedError] se il tab è chiuso
    def callback=(callback)
      raise TypeError, "callback deve rispondere a call, o essere nil, non #{callback.class}" unless callback.nil? || callback.respond_to?(:call)

      @tabbed.idle!
      FFI.nctab_set_cb(to_ptr, callback ? @function : ::FFI::Pointer::NULL)
      @callback = callback
    end

    # Sposta il tab subito dopo after, o subito prima di before
    # (+nctab_move+): indica esattamente uno dei due. Il wrapper tiene
    # coerente il primo tab mostrato: se il tab spostato era il primo, il
    # primo diventa quello che lo seguiva; spostato prima del primo, diventa
    # il primo. Non ridisegna.
    #
    # @param after [Tab, nil] tab aperto dello stesso widget
    # @param before [Tab, nil] tab aperto dello stesso widget
    # @return [self]
    # @raise [ArgumentError] senza after: né before:, con entrambi, con un tab
    #   di un altro widget o con il tab stesso
    # @raise [TypeError] se after o before non sono Tab
    # @raise [WidgetError] se +nctab_move+ fallisce, o dentro il blocco di un tab
    # @raise [ClosedError] se il tab o il widget sono chiusi
    def move(after: nil, before: nil)
      nt = @tabbed.idle!
      raise ArgumentError, 'move: indica esattamente uno tra after: e before:' unless after.nil? ^ before.nil?

      target = after || before
      tptr = @tabbed.member_ptr(target, after ? 'after' : 'before')
      raise ArgumentError, 'move: un tab non si sposta accanto a se stesso' if target.equal?(self)

      ptr = to_ptr
      left = FFI.nctabbed_leftmost(nt).address
      follower = FFI.nctab_next(ptr) if left == ptr.address
      rc = after ? FFI.nctab_move(nt, ptr, tptr, ::FFI::Pointer::NULL) : FFI.nctab_move(nt, ptr, ::FFI::Pointer::NULL, tptr)
      Util.check!(rc, WidgetError, 'nctab_move')
      # nctab_move non aggiorna il primo tab mostrato (tabbed.c:303-332)
      if follower
        FFI.nctabbed_rotate(nt, -1) until FFI.nctabbed_leftmost(nt).address == follower.address
      elsif before && left == tptr.address
        FFI.nctabbed_rotate(nt, 1) # il tab è ora subito prima del primo: diventa il primo
      end
      self
    end

    # Scambia il tab con quello alla sua sinistra (+nctab_move_left+); il
    # primo tab mostrato diventa l'ultimo. Non ridisegna.
    #
    # @return [self]
    # @raise [WidgetError] dentro il blocco di un tab
    # @raise [ClosedError] se il tab è chiuso
    def move_left
      nt = @tabbed.idle!
      FFI.nctab_move_left(nt, to_ptr)
      self
    end

    # Scambia il tab con quello alla sua destra (+nctab_move_right+); l'ultimo
    # tab diventa il primo mostrato. Non ridisegna.
    #
    # @return [self]
    # @raise [WidgetError] dentro il blocco di un tab
    # @raise [ClosedError] se il tab è chiuso
    def move_right
      nt = @tabbed.idle!
      FFI.nctab_move_right(nt, to_ptr)
      self
    end
  end
end
