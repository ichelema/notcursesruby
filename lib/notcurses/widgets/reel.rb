# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Reel: una colonna di tablet di altezza variabile fra cui ci si sposta con
  # il fuoco, come +struct ncreel*+ di notcurses.
  #
  # Scritto in Ruby sopra {Plane}: in 3.0.17 ncreel corrompe l'heap durante la
  # navigazione normale (+trim_reel_overhang+ distrugge il piano di un tablet
  # ancora legato al widget e poi lo legge, reel.c:494-544), quindi il wrapper
  # non chiama nessuna funzione +ncreel_*+ o +nctablet_*+. Ogni tablet visibile
  # ha un piano bordo (figlio del piano del reel) e un piano dati (figlio del
  # bordo), ricreati a ogni ridisegno; il bordo è arrotondato, come nel C.
  #
  # @example
  #   reel = Notcurses::Reel.new(plane, focused_channels: Notcurses::Channels.rgb(255, 255, 0, 0, 0, 0))
  #   3.times do |i|
  #     reel.add do |tablet, _draw_from_top|
  #       tablet.plane.putstr("tablet #{i}", y: 0, x: 0)
  #       1
  #     end
  #   end
  #   reel.next
  #
  # Disegno. Il blocco di un tablet riceve +(tablet, draw_from_top)+ e
  # disegna in {Tablet#plane} a partire dalla prima riga; il piano è alto
  # quanto lo spazio dati del reel. Restituisce le righe usate (Integer,
  # ridotto a 0..righe del piano; 0 = il tablet non ha piano dati). Il tablet
  # con il fuoco è disegnato per primo e ha tutta l'altezza; draw_from_top è
  # false per i tablet sopra il fuoco: se il reel li taglia, resta visibile la
  # loro parte bassa (mettila in fondo), mentre ai tablet sotto il fuoco resta
  # la parte alta. Dentro il blocco non si possono chiamare i metodi che
  # cambiano il reel né distruggere piani (WidgetError).
  #
  # Disposizione: il tablet con il fuoco resta dove era, se possibile; uno
  # che arriva da sotto (o da sopra) si appoggia al bordo inferiore (o
  # superiore); fra due tablet c'è una riga vuota; lo spazio vuoto resta in
  # basso; un tablet al bordo che non entra viene tagliato e il suo bordo dal
  # lato del taglio non viene disegnato.
  #
  # Differenze da ncreel di 3.0.17:
  # - infinite_scroll: e circular: funzionano come promette l'header; il C li
  #   valida e poi li ignora (reel.c:774-781): la sua lista è sempre circolare,
  #   nella navigazione e nel disegno (come infinite_scroll: true,
  #   circular: true);
  # - senza after: e before: {#add} mette il tablet in fondo alla lista (il C
  #   lo mette subito prima di quello con il fuoco);
  # - se si cancella il tablet con il fuoco, il fuoco passa al successivo o,
  #   se era l'ultimo, al precedente (il C passa sempre al successivo nella
  #   lista circolare);
  # - a ogni ridisegno il piano del reel viene cancellato (resta la cella base);
  # - un tablet sopra il fuoco può essere tagliato in alto e uno sotto in basso,
  #   ma il blocco viene chiamato una volta sola per ridisegno anche per i
  #   tablet che poi non entrano;
  # - PgUp, PgDn e i clic, come in 3.0.17, non sono gestiti da {#offer_input}.
  #
  # Ciclo di vita: come gli altri widget (vedi {Widget}): il reel prende
  # possesso del piano e lo distrugge con {#close} (i figli creati
  # dall'utente passano al genitore; i piani dei tablet vengono distrutti).
  # Non c'è un oggetto C: {#to_ptr} restituisce il +ncplane*+ del reel.
  class Reel
    include Widget
    extend Resource::ClassMethods

    # Lati delle maschere (+NCBOXMASK_*+): un lato nella maschera non viene disegnato.
    SIDES = {
      top: FFI::NCBOXMASK_TOP, right: FFI::NCBOXMASK_RIGHT, bottom: FFI::NCBOXMASK_BOTTOM, left: FFI::NCBOXMASK_LEFT
    }.freeze

    # Spazio del reel per i tablet (righe e colonne del piano del reel) e
    # bordi dei tablet (1 = lato disegnato).
    Geometry = Struct.new(:top, :bottom, :left, :width, :tb_top, :tb_bottom, :tb_left, :tb_right) do
      # @return [Integer] righe dei bordi orizzontali di un tablet (0..2)
      def tbv = tb_top + tb_bottom
      # @return [Integer] righe disponibili per i dati di un tablet
      def data_rows = bottom - top + 1 - tbv
      # @return [Integer] colonne disponibili per i dati di un tablet
      def data_cols = width - tb_left - tb_right
    end
    private_constant :Geometry

    # Posto di un tablet nella disposizione: riga, righe visibili, lato tagliato.
    Slot = Struct.new(:tablet, :y, :rows, :cut)
    private_constant :Slot

    # Crea il reel sul piano e disegna il bordo.
    #
    # @param plane [Plane] piano del reel, posseduto dal wrapper; diventa del
    #   reel (non lo stdplane, non il piano di un altro widget)
    # @param border_mask [Integer, Array<Symbol>] lati del bordo del reel da
    #   non disegnare: maschera NCBOXMASK_* (0..15) o Array di :top, :right,
    #   :bottom, :left
    # @param border_channels [Channels, Integer] colori del bordo del reel
    # @param tablet_mask [Integer, Array<Symbol>] lati del bordo dei tablet da
    #   non disegnare, come border_mask
    # @param tablet_channels [Channels, Integer] colori del bordo dei tablet
    # @param focused_channels [Channels, Integer] colori del bordo del tablet
    #   con il fuoco
    # @param infinite_scroll [Boolean] NCREEL_OPTION_INFINITESCROLL: la
    #   navigazione non si ferma alle estremità (dall'ultimo tablet si passa
    #   al primo e viceversa)
    # @param circular [Boolean] NCREEL_OPTION_CIRCULAR, richiede
    #   infinite_scroll: anche il disegno è circolare: sopra il primo tablet
    #   compaiono gli ultimi e sotto l'ultimo i primi, anche quando lo spazio
    #   basterebbe a mostrarli in ordine
    # @raise [ArgumentError] con una maschera fuori da 0..15 o con un lato
    #   sconosciuto, o con circular: true senza infinite_scroll: true
    # @raise [TypeError] se un argomento ha il tipo sbagliato
    # @raise [WidgetError] se il piano non si può dare al reel (stdplane,
    #   piano di un widget, piano preso in prestito)
    # @raise [ClosedError] se il piano è chiuso
    def initialize(plane, border_mask: 0, border_channels: 0, tablet_mask: 0, tablet_channels: 0,
                   focused_channels: 0, infinite_scroll: false, circular: false)
      claim_plane!(plane)
      @border_mask = mask!(border_mask, 'border_mask')
      @tablet_mask = mask!(tablet_mask, 'tablet_mask')
      @border_channels = Util.channels_value(border_channels, 'border_channels')
      @tablet_channels = Util.channels_value(tablet_channels, 'tablet_channels')
      @focused_channels = Util.channels_value(focused_channels, 'focused_channels')
      @infinite_scroll = Util.bool!(infinite_scroll, 'infinite_scroll')
      @circular = Util.bool!(circular, 'circular')
      raise ArgumentError, 'circular: true richiede infinite_scroll: true' if @circular && !@infinite_scroll

      @tablets = []
      @focused = nil
      @direction = :down
      @drawing = false
      attach!(plane.to_ptr, plane, owns_plane: true)
      layout_redraw
    end

    # Distrugge i piani dei tablet e il piano del reel (i figli creati
    # dall'utente passano al genitore). Idempotente.
    #
    # @return [nil]
    # @raise [WidgetError] dentro il blocco di un tablet o un altro callback, o
    #   se un piano di un tablet ospita un altro widget aperto (chiudi prima
    #   quel widget)
    def close
      return nil if closed?

      @context.check_not_in_callback!('Notcurses::Reel#close', WidgetError)
      check_hosted_widgets!(@tablets)
      super
      @tablets.each(&:invalidate!)
      @tablets = []
      @focused = nil
      nil
    end
    alias destroy close

    # Aggiunge un tablet e ridisegna. Il primo tablet di un reel vuoto prende
    # il fuoco.
    #
    # @param after [Tablet, nil] il nuovo tablet va subito dopo questo
    # @param before [Tablet, nil] il nuovo tablet va subito prima di questo;
    #   con entrambi, before deve seguire after (anche l'ultimo e il primo,
    #   come nella lista circolare del C); senza nessuno dei due, in fondo
    # @yieldparam tablet [Tablet] il tablet da disegnare
    # @yieldparam draw_from_top [Boolean] false per i tablet sopra il fuoco
    # @yieldreturn [Integer] righe usate
    # @return [Tablet]
    # @raise [ArgumentError] senza blocco, se after o before non sono tablet
    #   aperti di questo reel o non sono adiacenti
    # @raise [TypeError] se after o before non sono Tablet
    # @raise [WidgetError] dentro il blocco di un tablet
    # @raise [Exception] l'eccezione di un blocco durante il ridisegno (il
    #   tablet resta aggiunto; nessun tablet resta disegnato)
    # @raise [ClosedError] se il reel è chiuso
    def add(after: nil, before: nil, &block)
      idle!
      raise ArgumentError, 'add richiede un blocco che disegna il tablet' unless block

      ai = after.nil? ? nil : index_of(after, 'after')
      bi = before.nil? ? nil : index_of(before, 'before')
      if ai && bi && bi != (ai + 1) % @tablets.size
        raise ArgumentError, 'add: before deve essere il tablet subito dopo after'
      end

      tablet = Tablet.new(self, block)
      @tablets.insert(ai ? ai + 1 : bi || @tablets.size, tablet)
      @focused ||= tablet
      layout_redraw
      tablet
    end

    # Cancella un tablet, con i suoi piani, e ridisegna. Se aveva il fuoco, il
    # fuoco passa al successivo o, se era l'ultimo, al precedente.
    #
    # @param tablet [Tablet] tablet aperto di questo reel
    # @return [self]
    # @raise [ArgumentError] se tablet non è un tablet aperto di questo reel
    # @raise [TypeError] se tablet non è un Tablet
    # @raise [WidgetError] dentro il blocco di un tablet, o se un piano del
    #   tablet ospita un altro widget aperto
    # @raise [Exception] l'eccezione di un blocco durante il ridisegno (il
    #   tablet resta cancellato)
    # @raise [ClosedError] se il reel è chiuso
    def delete(tablet)
      idle!
      i = index_of(tablet, 'tablet')
      check_hosted_widgets!([tablet])
      wipe(tablet)
      @tablets.delete_at(i)
      tablet.invalidate!
      if @focused.equal?(tablet)
        @focused = @tablets[i] || @tablets[i - 1]
        @direction = :down
      end
      layout_redraw
      self
    end

    # Ridisegna il reel: bordo e tablet visibili, chiamando i loro blocchi.
    # I piani dei tablet del ridisegno precedente vengono distrutti.
    #
    # @return [self]
    # @raise [WidgetError] dentro il blocco di un tablet, o se un piano di un
    #   tablet ospita un altro widget aperto
    # @raise [TypeError] se un blocco non restituisce un Integer
    # @raise [Exception] l'eccezione di un blocco (nessun tablet resta
    #   disegnato; il reel resta utilizzabile)
    # @raise [ClosedError] se il reel è chiuso
    def redraw
      idle!
      layout_redraw
      self
    end

    # Sposta il fuoco sul tablet successivo e ridisegna. All'ultimo tablet il
    # fuoco resta lì, oppure passa al primo con infinite_scroll: true.
    #
    # @return [Tablet, nil] il tablet con il fuoco, nil se il reel è vuoto
    # @raise [WidgetError] dentro il blocco di un tablet
    # @raise [Exception] l'eccezione di un blocco durante il ridisegno
    # @raise [ClosedError] se il reel è chiuso
    def next
      move_focus(1)
    end

    # Sposta il fuoco sul tablet precedente e ridisegna. Al primo tablet il
    # fuoco resta lì, oppure passa all'ultimo con infinite_scroll: true.
    #
    # @return [Tablet, nil] il tablet con il fuoco, nil se il reel è vuoto
    # @raise [WidgetError] dentro il blocco di un tablet
    # @raise [Exception] l'eccezione di un blocco durante il ridisegno
    # @raise [ClosedError] se il reel è chiuso
    def prev
      move_focus(-1)
    end

    # Passa un evento al reel, come +ncreel_offer_input+: freccia su e
    # rotella in su chiamano {#prev}, freccia giù e rotella in giù {#next}.
    #
    # @param input [Input] evento
    # @return [Boolean] true se l'evento è stato consumato (anche con il reel
    #   vuoto); false per i rilasci e per gli altri eventi
    # @raise [TypeError] se input non è un Input
    # @raise [WidgetError] dentro il blocco di un tablet
    # @raise [Exception] l'eccezione di un blocco durante il ridisegno
    # @raise [ClosedError] se il reel è chiuso
    def offer_input(input)
      raise TypeError, "input deve essere Notcurses::Input, non #{input.class}" unless input.is_a?(Input)

      idle!
      return false if input.release?

      case input.id
      when Key::UP, Key::SCROLL_UP then prev
      when Key::DOWN, Key::SCROLL_DOWN then self.next
      else return false
      end
      true
    end

    # @return [Tablet, nil] tablet con il fuoco, nil se il reel è vuoto
    # @raise [ClosedError] se il reel è chiuso
    def focused
      to_ptr
      @focused
    end

    # @return [Array<Tablet>] tablet in ordine
    # @raise [ClosedError] se il reel è chiuso
    def tablets
      to_ptr
      @tablets.dup
    end

    # @return [Integer] numero di tablet
    # @raise [ClosedError] se il reel è chiuso
    def tablet_count
      to_ptr
      @tablets.size
    end
    alias size tablet_count

    private

    def destroy_native
      @tablets.each { |tablet| wipe(tablet) }
      FFI.ncplane_destroy(@ptr)
    end

    # Puntatore del piano del reel, fuori dai blocchi dei tablet.
    def idle!
      raise WidgetError, 'Notcurses::Reel: metodo non permesso dentro il blocco di un tablet' if @drawing

      to_ptr
    end

    # @return [Integer] maschera 0..15
    def mask!(value, name)
      case value
      when Integer then Util.integer!(value, name, 0..0xf)
      when Array
        value.reduce(0) do |mask, side|
          mask | SIDES.fetch(side) { raise ArgumentError, "#{name}: lato #{side.inspect} non valido: usa :top, :right, :bottom o :left" }
        end
      else raise TypeError, "#{name} deve essere Integer o Array di Symbol, non #{value.class}"
      end
    end

    # @return [Integer] indice di un tablet aperto di questo reel
    def index_of(tablet, name)
      raise TypeError, "#{name} deve essere Notcurses::Tablet, non #{tablet.class}" unless tablet.is_a?(Tablet)

      i = tablet.closed? ? nil : @tablets.index { |t| t.equal?(tablet) }
      raise ArgumentError, "#{name} non è un tablet aperto di questo Reel" unless i

      i
    end

    def move_focus(step)
      idle!
      return nil if @tablets.empty?

      i = @tablets.index(@focused) + step
      i = @infinite_scroll ? i % @tablets.size : i.clamp(0, @tablets.size - 1)
      @focused = @tablets[i]
      @direction = step.positive? ? :down : :up
      layout_redraw
      @focused
    end

    def layout_redraw
      @drawing = true
      begin
        layout!
      ensure
        @drawing = false
      end
    end

    def layout!
      check_hosted_widgets!(@tablets)
      @tablets.each { |tablet| wipe(tablet) }
      @plane.erase
      draw_border(@plane, @border_mask, @border_channels)
      geo = geometry
      if @focused.nil? || geo.data_rows < 1 || geo.data_cols < 1
        @tablets.each { |tablet| tablet.y = nil }
        return
      end

      @heights = {}
      done = false
      begin
        apply(arrange_all(geo), geo)
        done = true
      ensure
        unless done
          @tablets.each do |tablet|
            wipe(tablet)
            tablet.y = nil
          end
        end
      end
    end

    def geometry
      rows, cols = @plane.dims
      top = side?(@border_mask, :top)
      left = side?(@border_mask, :left)
      Geometry.new(top, rows - 1 - side?(@border_mask, :bottom), left, cols - left - side?(@border_mask, :right),
                   side?(@tablet_mask, :top), side?(@tablet_mask, :bottom), side?(@tablet_mask, :left),
                   side?(@tablet_mask, :right))
    end

    # @return [Integer] 1 se il lato è disegnato, 0 se è nella maschera
    def side?(mask, side) = (mask & SIDES.fetch(side)).zero? ? 1 : 0

    # Disposizione finale: il fuoco al suo posto, poi niente spazio vuoto in
    # alto e, se in basso resta spazio, i tablet di sopra che non entravano.
    def arrange_all(geo)
      ups, downs = sequences
      focus_rows = measure(@focused, true, geo) + geo.tbv
      want = @focused.y || (@direction == :up ? geo.top : geo.bottom - focus_rows + 1)
      top = want.clamp(geo.top, geo.bottom - focus_rows + 1)
      plan = arrange(top, focus_rows, geo, ups, downs)
      top -= top_gap(plan, geo)
      plan = arrange(top, focus_rows, geo, ups, downs)
      last = plan[:slots].last
      bottom_gap = geo.bottom - (last.y + last.rows - 1)
      if bottom_gap.positive? && plan[:down_done] && !plan[:up_done]
        top += bottom_gap
        plan = arrange(top, focus_rows, geo, ups, downs)
        top -= top_gap(plan, geo)
        plan = arrange(top, focus_rows, geo, ups, downs)
      end
      plan[:slots]
    end

    # Righe vuote sopra il tablet più in alto.
    def top_gap(plan, geo) = plan[:slots].first.y - geo.top

    # Tablet sopra il fuoco (dal più vicino) e sotto. Nel disegno circolare
    # ogni tablet va dal lato più vicino al fuoco nella lista circolare.
    def sequences
      f = @tablets.index(@focused)
      n = @tablets.size
      return [@tablets[0...f].reverse, @tablets[(f + 1)..]] unless @circular

      above = (n - 1) / 2
      [(1..above).map { |k| @tablets[(f - k) % n] }, (1..(n - 1 - above)).map { |k| @tablets[(f + k) % n] }]
    end

    # Posti dei tablet con il fuoco in top: verso l'alto, poi verso il basso.
    # @return [Hash] :slots dall'alto, :up_done/:down_done = lato esaurito
    def arrange(top, focus_rows, geo, ups, downs)
      slots = [Slot.new(@focused, top, focus_rows, nil)]
      up_done = true
      frontier = top - 2 # ultima riga libera sopra (una riga vuota fra i tablet)
      ups.each do |tablet|
        space = frontier - geo.top + 1
        up_done = false
        break if space < geo.tb_bottom + 1

        rows = measure(tablet, false, geo) + geo.tbv
        if rows > space
          slots.unshift(Slot.new(tablet, geo.top, space, :top))
          break
        end
        slots.unshift(Slot.new(tablet, frontier - rows + 1, rows, nil))
        frontier -= rows + 1
        up_done = true
      end
      down_done = true
      frontier = top + focus_rows + 1 # prima riga libera sotto
      downs.each do |tablet|
        space = geo.bottom - frontier + 1
        down_done = false
        break if space < geo.tb_top + 1

        rows = measure(tablet, true, geo) + geo.tbv
        if rows > space
          slots.push(Slot.new(tablet, frontier, space, :bottom))
          break
        end
        slots.push(Slot.new(tablet, frontier, rows, nil))
        frontier += rows + 1
        down_done = true
      end
      { slots: slots, up_done: up_done, down_done: down_done }
    end

    # Crea i piani del tablet alti quanto tutto lo spazio dati e chiama il
    # blocco una volta per ridisegno.
    # @return [Integer] righe dati usate
    def measure(tablet, from_top, geo)
      @heights.fetch(tablet) do
        border = @plane.create_child(rows: geo.data_rows + geo.tbv, cols: geo.width, y: geo.top, x: geo.left, name: 'tab')
        border.transfer_to(self)
        data = border.create_child(rows: geo.data_rows, cols: geo.data_cols, y: geo.tb_top, x: geo.tb_left, name: 'tdat')
        data.transfer_to(self)
        tablet.planes = [border, data]
        rows = @context.callback_scope { tablet.callback.call(tablet, from_top) }
        raise TypeError, "il blocco del tablet deve restituire le righe usate (Integer), non #{rows.class}" unless rows.is_a?(Integer)

        @heights[tablet] = rows.clamp(0, [geo.data_rows, data.dim_y].min)
      end
    end

    # Porta i piani dei tablet al loro posto e disegna i bordi.
    def apply(slots, geo)
      placed = slots.to_h { |slot| [slot.tablet, slot] }
      @tablets.each do |tablet|
        slot = placed[tablet]
        if slot
          place(tablet, slot, geo)
        else
          wipe(tablet)
        end
        tablet.y = slot&.y
      end
    end

    def place(tablet, slot, geo)
      border, data = tablet.planes
      mask = @tablet_mask | (slot.cut ? SIDES.fetch(slot.cut) : 0)
      shown_top = side?(mask, :top)
      visible = slot.rows - shown_top - side?(mask, :bottom)
      used = @heights.fetch(tablet)
      if used.zero? || visible < 1
        destroy_family(data)
        tablet.planes = [border]
      else
        if slot.cut == :top && visible < used
          # tagliato in alto: restano le ultime righe del contenuto
          data.resize_region(rows: visible, cols: geo.data_cols, keep_y: used - visible, keep_rows: visible,
                             keep_cols: [data.dim_x, geo.data_cols].min)
        else
          data.resize([visible, used].min, geo.data_cols)
        end
        data.move(shown_top, geo.tb_left)
      end
      border.resize(slot.rows, geo.width) unless border.dim_y == slot.rows
      border.move(slot.y, geo.left)
      draw_border(border, mask, @focused.equal?(tablet) ? @focused_channels : @tablet_channels)
    end

    # Bordo arrotondato; dove un lato manca, gli angoli diventano linee.
    def draw_border(plane, mask, channels)
      return if mask == 0xf || plane.dim_y < 2 || plane.dim_x < 2

      top, right, bottom, left = %i[top right bottom left].map { |side| side?(mask, side) == 1 }
      ul, ur, ll, lr, hl, vl = @context.can_utf8? ? %w[╭ ╮ ╰ ╯ ─ │] : %w[+ + + + - |]
      glyphs = [corner(top, left, ul, hl, vl), corner(top, right, ur, hl, vl), corner(bottom, left, ll, hl, vl),
                corner(bottom, right, lr, hl, vl), hl, vl].join
      hide = SIDES.select { |_side, bit| (mask & bit).nonzero? }.keys
      plane.perimeter(set: glyphs, channels: channels, hide: hide, corners: 1)
    end

    def corner(horizontal, vertical, glyph, hl, vl)
      return glyph if horizontal && vertical

      horizontal ? hl : vl
    end

    # Distrugge i piani del tablet e marca chiusi i loro wrapper.
    def wipe(tablet)
      return unless tablet.planes

      destroy_family(tablet.planes.first)
      tablet.planes = nil
    end

    def destroy_family(plane)
      victims = descendants(plane)
      FFI.ncplane_family_destroy(plane.address_ptr)
      victims.each(&:invalidate!)
      plane.invalidate!
      @context.planes_destroyed!
    end

    def descendants(plane)
      ptr = plane.address_ptr
      @context.tracked_planes.select do |other|
        !other.equal?(plane) && FFI.ncplane_descendant_p(other.address_ptr, ptr) != 0
      end
    end

    # I piani dei tablet si distruggono con i discendenti: un widget aperto su
    # uno di essi resterebbe con un piano liberato.
    def check_hosted_widgets!(tablets)
      tablets.each do |tablet|
        own = tablet.planes
        next if own.nil?
        next unless descendants(own.first).any? { |plane| plane.widget_plane? && own.none? { |o| o.equal?(plane) } }

        raise WidgetError, 'un piano di un tablet ospita un widget aperto: chiudi prima quel widget'
      end
    end
  end

  # Tablet di un {Reel}: un elemento della colonna, disegnato dal suo blocco.
  # Si ottiene da {Reel#add}; resta valido fino a {Reel#delete} o alla
  # chiusura del reel (poi ClosedError).
  class Tablet
    # @return [#call] blocco che disegna il tablet
    # @api private
    attr_reader :callback

    # @return [Array<Plane>, nil] [bordo, dati] o [bordo]; nil se non disegnato
    # @api private
    attr_accessor :planes

    # @return [Integer, nil] riga del bordo nell'ultimo ridisegno, nil se non visibile
    # @api private
    attr_accessor :y

    # @api private
    def initialize(reel, callback)
      @reel = reel
      @callback = callback
      @closed = false
      @planes = nil
      @y = nil
    end

    # Piano dati del tablet: vale fino al prossimo ridisegno del reel (poi
    # il wrapper lo distrugge e ne crea un altro).
    #
    # @return [Plane, nil] nil se il tablet non è visibile o il suo blocco ha
    #   restituito 0
    # @raise [ClosedError] se il tablet è chiuso
    def plane
      raise ClosedError, 'Notcurses::Tablet: oggetto già chiuso' if closed?

      @planes && @planes.size == 2 ? @planes.last : nil
    end

    # @return [Boolean] true dopo {Reel#delete} o la chiusura del reel
    def closed? = @closed || @reel.closed?

    # @api private
    def invalidate!
      @closed = true
      @planes = nil
      @callback = nil
    end

    # @return [String]
    def inspect = closed? ? '#<Notcurses::Tablet (chiuso)>' : "#<Notcurses::Tablet y=#{@y.inspect}>"
  end
end
