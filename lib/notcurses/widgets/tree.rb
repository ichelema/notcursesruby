# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Albero di voci navigabile (+struct nctree*+): voci annidate, una delle
  # quali ha il fuoco; il blocco dato a {#initialize} disegna le voci visibili.
  #
  # Voci. +items+ è un Array: ogni elemento è una foglia (un oggetto qualsiasi
  # che non sia un Array o un Hash) oppure un Hash, in cui ogni coppia
  # +valore => figli+ è una voce con i suoi figli (un Array o un Hash dello
  # stesso formato, anche vuoti). Una voce si indica con il suo percorso: un
  # Array di indici, uno per livello ([1, 0] è il primo figlio della seconda
  # voce).
  #
  # @example
  #   items = ['README', { 'lib' => ['notcurses.rb', { 'widgets' => ['tree.rb'] }] }]
  #   tree = Notcurses::Tree.new(plane, items: items, indent: 2) do |item_plane, value, distance|
  #     next 0 unless item_plane # voce uscita dallo schermo
  #     item_plane.putstr(distance.zero? ? "> #{value}" : value.to_s, y: 0, x: 0)
  #     1
  #   end
  #   tree.next
  #   tree.redraw
  #
  # Disegno. Il blocco riceve +(plane, value, distance)+: il piano della voce,
  # vuoto, largo quanto l'albero meno l'indentazione e alto quanto lo spazio
  # rimasto nella direzione di disegno; il valore della voce; la distanza
  # dalla voce con il fuoco (0 = il fuoco, negativa per le voci sopra,
  # positiva per quelle sotto). Il blocco restituisce le righe usate (Integer,
  # ridotto a 1..righe del piano) e il piano viene ridotto a quelle righe. Per
  # una voce sopra il fuoco che non entra, il blocco può scegliere la parte
  # finale del suo contenuto. Una voce spinta fuori dallo schermo riceve plane
  # nil (notcurses ha appena distrutto il suo piano) e il ritorno non conta.
  # Il piano vale solo durante il blocco. Dentro il blocco non si possono
  # chiamare i metodi dell'albero, creare widget né distruggere piani
  # (WidgetError). break, return e throw non possono uscire dal blocco
  # attraverso il C: diventano una LocalJumpError, che esce come
  # un'eccezione del blocco.
  #
  # Ridisegno: come in notcurses, disegnano solo {#initialize} e {#redraw};
  # gli altri metodi cambiano lo stato e lasciano il ridisegno al chiamante.
  #
  # Ciclo di vita: l'albero prende possesso del piano e lo distrugge con
  # {#close} (i figli del piano passano al suo genitore). Nel C non è legato
  # al piano: il {Context} lo chiude prima di +notcurses_stop+ e di
  # {Context#drop_planes}.
  #
  # Bug di 3.0.17 aggirati dal wrapper:
  # - +nctree_del+ legge +spec[-1]+ come ultimo indice (tree.c:253): il
  #   wrapper mette l'ultimo indice davanti al vettore;
  # - dopo +nctree_add+ (realloc, tree.c:182-186) e +nctree_del+ il fuoco del
  #   C punta a memoria liberata: il wrapper riporta il fuoco sulla stessa
  #   voce (HOME più +nctree_next+), o sulla voce che prende il posto di
  #   quella cancellata;
  # - +nctree_focused+, +nctree_next+, +nctree_prev+ e +nctree_offer_input+
  #   su un albero vuoto dereferenziano NULL (tree.c:351,398,607): il wrapper
  #   non chiama il C;
  # - +nctree_del+ con il percorso vuoto causa un double free (tree.c:250):
  #   rifiutato;
  # - +nctree_goto+ è uno stub (tree.c:610-616): {#goto} è scritto in Ruby;
  # - le voci di più righe sopra il fuoco si sovrapponevano e i piani già
  #   creati non cambiavano altezza né larghezza (tree.c:419-456): il wrapper
  #   impila le voci da sé e le adatta alla larghezza corrente dell'albero;
  # - un'indentazione più larga del piano crea piani di larghezza negativa
  #   (tree.c:444): rifiutata.
  class Tree
    include Widget
    extend Resource::ClassMethods

    # Terminatore dei percorsi del C.
    UINT_MAX = 0xffff_ffff
    private_constant :UINT_MAX

    # Voce interna: id (il curry passato al C), valore dell'utente, figli.
    Node = Struct.new(:id, :value, :children)
    private_constant :Node

    # Crea l'albero sul piano (+nctree_create+) e lo disegna una prima volta.
    #
    # @param plane [Plane] piano dell'albero, posseduto dal wrapper; diventa
    #   dell'albero (non lo stdplane, non il piano di un altro widget)
    # @param items [Array, Hash] voci (vedi la descrizione della classe)
    # @param indent [Integer] colonne di indentazione per livello, 0..INT_MAX;
    #   l'indentazione della voce più profonda deve stare nel piano
    # @param draw [#call, nil] alternativa al blocco, utile con +open+:
    #   +call(plane, value, distance)+
    # @yieldparam plane [Plane, nil] piano della voce, nil se la voce esce dallo schermo
    # @yieldparam value [Object] valore della voce
    # @yieldparam distance [Integer] distanza dalla voce con il fuoco
    # @yieldreturn [Integer] righe usate
    # @raise [ArgumentError] senza blocco né draw: (o con entrambi), con voci o
    #   indent non validi, o con un'indentazione che non entra nel piano
    # @raise [TypeError] se plane non è un Plane, le voci non sono Array/Hash o
    #   draw: non risponde a call
    # @raise [WidgetError] se il piano non si può dare all'albero (stdplane,
    #   piano di un widget, piano preso in prestito); dentro un callback
    #   chiamato da notcurses (piano intatto); se +nctree_create+ fallisce (in
    #   quel caso notcurses ha distrutto il piano)
    # @raise [Exception] l'eccezione del blocco durante il primo disegno: in
    #   quel caso l'albero viene distrutto, con il piano
    # @raise [ClosedError] se il piano è chiuso
    def initialize(plane, items: [], indent: 0, draw: nil, &block)
      raise ArgumentError, 'passa il blocco di disegno oppure draw:, non entrambi' if draw && block

      draw ||= block
      raise ArgumentError, 'Tree.new richiede un blocco che disegna le voci (oppure draw:)' if draw.nil?
      raise TypeError, "draw: deve rispondere a call, non #{draw.class}" unless draw.respond_to?(:call)

      claim_plane!(plane)
      plane.context.check_not_in_callback!('Tree.new', WidgetError)
      Util.integer!(indent, 'indent', Util::NONNEG_INT)
      @context = plane.context
      @tree_plane = plane
      @draw = draw
      @indent = indent
      @drawing = false
      @next_id = 0
      @nodes = {}
      @roots = build_nodes(items, 'items')
      check_indent!(max_depth(@roots), plane.dim_x, ArgumentError)
      fn = ::FFI::Function.new(:int, %i[pointer pointer int]) { |pl, curry, dist| draw_item(pl, curry, dist) }
      @callbacks = [fn]
      keep = []
      opts = FFI::NcTreeOptions.new
      opts[:items] = item_array(@roots, keep)
      opts[:count] = @roots.size
      opts[:nctreecb] = fn
      opts[:indentcols] = indent
      ptr = FFI.nctree_create(plane.to_ptr, opts)
      if ptr.null?
        plane_destroyed_on_failure!(plane)
        raise WidgetError, 'nctree_create ha restituito NULL'
      end

      attach!(ptr, plane, owns_plane: true)
      return if @context.callback_errors.empty?

      close
      @context.raise_callback_errors!
    end

    # Ridisegna le voci visibili (+nctree_redraw+), chiamando il blocco per
    # ognuna. Se il piano è stato rimpicciolito e la riga del fuoco ne è
    # uscita, il wrapper riporta il fuoco dentro il piano e riprova.
    #
    # @return [self]
    # @raise [WidgetError] se +nctree_redraw+ fallisce, se il piano è troppo
    #   stretto per l'indentazione della voce più profonda, o dentro il blocco
    # @raise [Exception] l'eccezione sollevata dal blocco (il disegno si ferma
    #   lì; l'albero resta utilizzabile)
    # @raise [ClosedError] se l'albero è chiuso
    def redraw
      ptr = idle!
      check_indent!(max_depth(@roots), @plane.dim_x, WidgetError)
      rc = native_redraw(ptr)
      unless rc.zero? || @nodes.empty?
        # la riga del fuoco (activerow) può essere oltre il piano dopo un resize
        refocus(ptr, focused_node(ptr).id)
        rc = native_redraw(ptr)
      end
      Util.check!(rc, WidgetError, 'nctree_redraw')
      self
    end

    # Passa un evento all'albero (+nctree_offer_input+): frecce su e giù,
    # PgUp e PgDn (una voce), Home (prima voce), End (ultima). Non ridisegna:
    # chiama {#redraw}.
    #
    # @param input [Input] evento
    # @return [Boolean] true se l'evento è stato consumato; false per gli
    #   altri eventi, per i rilasci di tasto e su un albero vuoto
    # @raise [TypeError] se input non è un Input
    # @raise [WidgetError] dentro il blocco di disegno
    # @raise [ClosedError] se l'albero è chiuso
    def offer_input(input)
      raise TypeError, "input deve essere Notcurses::Input, non #{input.class}" unless input.is_a?(Input)

      ptr = idle!
      return false if @nodes.empty?

      FFI.nctree_offer_input(ptr, input.to_ffi)
    end

    # Valore della voce con il fuoco (+nctree_focused+).
    #
    # @return [Object, nil] nil se l'albero è vuoto
    # @raise [WidgetError] dentro il blocco di disegno
    # @raise [ClosedError] se l'albero è chiuso
    def focused
      ptr = idle!
      @nodes.empty? ? nil : focused_node(ptr).value
    end

    # Percorso della voce con il fuoco.
    #
    # @return [Array<Integer>, nil] nil se l'albero è vuoto
    # @raise [WidgetError] dentro il blocco di disegno
    # @raise [ClosedError] se l'albero è chiuso
    def focused_path
      ptr = idle!
      @nodes.empty? ? nil : path_of(focused_node(ptr).id)
    end

    # Sposta il fuoco sulla voce successiva in pre-ordine: il primo figlio, poi
    # il fratello, poi il fratello di un antenato (+nctree_next+). All'ultima
    # voce il fuoco non cambia. Non ridisegna.
    #
    # @return [Object, nil] valore della voce con il fuoco; nil se l'albero è vuoto
    # @raise [WidgetError] dentro il blocco di disegno
    # @raise [ClosedError] se l'albero è chiuso
    def next
      ptr = idle!
      @nodes.empty? ? nil : @nodes.fetch(FFI.nctree_next(ptr).address).value
    end

    # Sposta il fuoco sulla voce precedente in pre-ordine (+nctree_prev+).
    # Alla prima voce il fuoco non cambia. Non ridisegna.
    #
    # @return [Object, nil] valore della voce con il fuoco; nil se l'albero è vuoto
    # @raise [WidgetError] dentro il blocco di disegno
    # @raise [ClosedError] se l'albero è chiuso
    def prev
      ptr = idle!
      @nodes.empty? ? nil : @nodes.fetch(FFI.nctree_prev(ptr).address).value
    end

    # Sposta il fuoco sulla voce del percorso. Scritto in Ruby: +nctree_goto+
    # di 3.0.17 è uno stub che non sposta il fuoco (tree.c:610-616). Il
    # wrapper porta il fuoco sulla prima voce e poi lo avanza con
    # +nctree_next+. Non ridisegna.
    #
    # @param path [Array<Integer>] percorso di una voce esistente
    # @return [Object] valore della voce
    # @raise [ArgumentError, TypeError] se il percorso non è valido
    # @raise [WidgetError] dentro il blocco di disegno
    # @raise [ClosedError] se l'albero è chiuso
    def goto(path)
      ptr = idle!
      node = node_at(path!(path))
      refocus(ptr, node.id)
      node.value
    end

    # Aggiunge una voce senza figli nella posizione del percorso
    # (+nctree_add+): l'ultimo indice va da 0 al numero dei fratelli (in fondo).
    # Il fuoco resta sulla voce che lo aveva; in un albero vuoto passa alla
    # nuova voce. Non ridisegna.
    #
    # @param path [Array<Integer>] posizione della nuova voce
    # @param value [Object] valore della voce
    # @return [self]
    # @raise [ArgumentError, TypeError] se il percorso non è valido, o se
    #   l'indentazione del nuovo livello non entra nel piano
    # @raise [WidgetError] se +nctree_add+ fallisce, o dentro il blocco di disegno
    # @raise [ClosedError] se l'albero è chiuso
    def add(path, value)
      ptr = idle!
      path!(path, insert: true)
      check_indent!(path.size, @plane.dim_x, ArgumentError)
      focus_id = @nodes.empty? ? nil : focused_node(ptr).id
      node = new_node(value, [])
      item = FFI::NcTreeItem.new
      item[:curry] = ::FFI::Pointer.new(node.id)
      item[:subs] = ::FFI::Pointer::NULL
      item[:subcount] = 0
      spec = ::FFI::MemoryPointer.new(:uint, path.size + 1)
      spec.write_array_of_uint(path + [UINT_MAX])
      rc = FFI.nctree_add(ptr, spec, item)
      if rc.negative?
        @nodes.delete(node.id)
        raise WidgetError, "nctree_add fallita (#{rc})"
      end

      level(path[0...-1]).insert(path.last, node)
      refocus(ptr, focus_id || node.id)
      self
    end

    # Cancella la voce del percorso e tutti i suoi discendenti (+nctree_del+),
    # con i loro piani. Se il fuoco era dentro la parte cancellata passa alla
    # voce che prende il suo posto in pre-ordine (o all'ultima). Non ridisegna.
    #
    # @param path [Array<Integer>] percorso di una voce esistente, non vuoto
    # @return [self]
    # @raise [ArgumentError, TypeError] se il percorso non è valido (anche
    #   vuoto: in 3.0.17 porta a un double free)
    # @raise [WidgetError] se +nctree_del+ fallisce, o dentro il blocco di disegno
    # @raise [ClosedError] se l'albero è chiuso
    def delete(path)
      ptr = idle!
      victim = node_at(path!(path))
      gone = preorder([victim]).map(&:id)
      focus_id = focused_node(ptr).id
      index = preorder(@roots).index(victim)
      # nctree_del legge spec[-1] come ultimo indice (tree.c:253): l'ultimo indice va anche davanti
      buf = ::FFI::MemoryPointer.new(:uint, path.size + 2)
      buf.write_array_of_uint([path.last] + path + [UINT_MAX])
      rc = FFI.nctree_del(ptr, buf + ::FFI.type_size(:uint))
      @context.planes_destroyed!
      Util.check!(rc, WidgetError, 'nctree_del')
      level(path[0...-1]).delete_at(path.last)
      gone.each { |id| @nodes.delete(id) }
      return self if @roots.empty?

      if gone.include?(focus_id)
        order = preorder(@roots)
        focus_id = order[[index, order.size - 1].min].id
      end
      refocus(ptr, focus_id)
      self
    end

    # @return [Integer] numero di voci, a tutti i livelli
    # @raise [ClosedError] se l'albero è chiuso
    def count
      to_ptr
      @nodes.size
    end
    alias size count

    # @return [Boolean] true se l'albero non ha voci
    # @raise [ClosedError] se l'albero è chiuso
    def empty? = count.zero?

    # Piano dell'albero (+nctree_plane+): quello dato a {#initialize}.
    #
    # @return [Plane]
    # @raise [ClosedError] se l'albero è chiuso
    def plane = @context.plane_for(FFI.nctree_plane(to_ptr))

    private

    def destroy_native
      FFI.nctree_destroy(@ptr)
    end

    # Puntatore dell'albero, fuori dal blocco di disegno.
    def idle!
      raise WidgetError, 'Notcurses::Tree: metodo non permesso dentro il blocco di disegno' if @drawing

      to_ptr
    end

    def native_redraw(ptr)
      rc = FFI.nctree_redraw(ptr)
      @context.planes_destroyed!
      @context.raise_callback_errors!
      rc
    end

    # Trampolino di nctreecb. Il wrapper decide da sé la posizione delle voci:
    # il C mette le voci sopra il fuoco a partire dalla loro prima riga e non
    # cambia l'altezza dei piani già creati. Le frontiere seguono quelle del C,
    # che le ricalcola dalla posizione finale dei piani.
    def draw_item(plane_ptr, curry, distance)
      Util.guard(@context.callback_errors, -1) do
        @context.planes_destroyed! if plane_ptr.null? # il C ha appena distrutto il piano della voce
        node = @nodes.fetch(curry.address)
        avail = prepare_item(plane_ptr, distance) unless plane_ptr.null?
        @drawing = true
        rows = begin
          @context.callback_scope { @draw.call(@context.plane_for(plane_ptr), node.value, distance) }
        ensure
          @drawing = false
        end
        place_item(plane_ptr, rows, distance, avail) unless plane_ptr.null?
        0
      end
    end

    # Piano vuoto alto quanto lo spazio libero nella direzione di disegno. Il
    # fuoco (distance 0) arriva per primo, nella riga attiva del C.
    # @return [Integer] righe disponibili
    def prepare_item(ptr, distance)
      if distance.zero?
        @frontier_bottom = FFI.ncplane_y(ptr)
        @frontier_top = @frontier_bottom - 1
      end
      avail = distance.negative? ? @frontier_top + 1 : FFI.ncplane_dim_y(@tree_plane.address_ptr) - @frontier_bottom
      raise WidgetError, "nctree: nessuna riga libera per la voce (distance #{distance})" unless avail.positive?

      resize_item(ptr, avail)
      FFI.ncplane_erase(ptr)
      avail
    end

    # Riduce il piano alle righe usate e lo mette contro la sua frontiera.
    def place_item(ptr, rows, distance, avail)
      raise TypeError, "il blocco del Tree deve restituire le righe usate (Integer), non #{rows.class}" unless rows.is_a?(Integer)

      rows = rows.clamp(1, avail)
      resize_item(ptr, rows)
      y = distance.negative? ? @frontier_top - rows + 1 : @frontier_bottom
      Util.check!(FFI.ncplane_move_yx(ptr, y, FFI.ncplane_x(ptr)), WidgetError, 'ncplane_move_yx')
      @frontier_top = y - 1 if distance <= 0
      @frontier_bottom = y + rows if distance >= 0
    end

    # Anche la larghezza: il C la fissa solo alla creazione del piano (tree.c:456).
    # Almeno 1 colonna: il blocco può aver spostato il piano oltre il bordo destro.
    def resize_item(ptr, rows)
      cols = [FFI.ncplane_dim_x(@tree_plane.address_ptr) - FFI.ncplane_x(ptr), 1].max
      return if FFI.ncplane_dim_y(ptr) == rows && FFI.ncplane_dim_x(ptr) == cols

      rc = FFI.ncplane_resize_simple(ptr, rows, cols)
      Util.check!(rc, WidgetError, 'ncplane_resize_simple')
    end

    # Voci Ruby dalle voci dell'utente.
    # @return [Array<Node>]
    def build_nodes(items, name)
      items = [items] if items.is_a?(Hash)
      raise TypeError, "#{name} deve essere un Array o un Hash, non #{items.class}" unless items.is_a?(Array)

      items.each_with_index.flat_map do |entry, i|
        case entry
        when Hash then entry.map { |value, subs| new_node(value, build_nodes(subs, "i figli di #{value.inspect}")) }
        when Array then raise TypeError, "#{name}[#{i}] è un Array: per una voce con figli usa un Hash { valore => [figli] }"
        else [new_node(entry, [])]
        end
      end
    end

    def new_node(value, children)
      @next_id += 1 # curry non nullo e univoco (goto_last_item si ferma su un curry ripetuto)
      @nodes[@next_id] = Node.new(@next_id, value, children)
    end

    # Vettore C di nctree_item per un livello; keep tiene vivi i vettori annidati.
    def item_array(nodes, keep)
      return ::FFI::Pointer::NULL if nodes.empty?

      buf = ::FFI::MemoryPointer.new(FFI::NcTreeItem, nodes.size)
      keep << buf
      nodes.each_with_index do |node, i|
        item = FFI::NcTreeItem.new(buf + (i * FFI::NcTreeItem.size))
        item[:curry] = ::FFI::Pointer.new(node.id)
        item[:subs] = item_array(node.children, keep)
        item[:subcount] = node.children.size
      end
      buf
    end

    def max_depth(nodes)
      nodes.map { |node| 1 + max_depth(node.children) }.max || 0
    end

    # La voce più profonda deve avere almeno una colonna (tree.c:444).
    def check_indent!(depth, cols, error)
      return if depth.zero? || ((depth - 1) * @indent) < cols

      raise error, "indent #{@indent} al livello #{depth} non entra nel piano largo #{cols}"
    end

    # @return [Array<Integer>] path, validato
    def path!(path, insert: false)
      raise TypeError, "path deve essere un Array di Integer, non #{path.class}" unless path.is_a?(Array)
      raise ArgumentError, 'path vuoto: indica almeno un indice' if path.empty?

      nodes = @roots
      path.each_with_index do |idx, depth|
        last = depth == path.size - 1
        limit = last && insert ? nodes.size : nodes.size - 1
        Util.integer!(idx, "path[#{depth}]", 0..[limit, 0].max)
        raise ArgumentError, "path #{path.inspect}: al livello #{depth} non c'è la voce #{idx}" if idx > limit

        nodes = nodes[idx].children unless last
      end
      path
    end

    def node_at(path) = level(path[0...-1])[path.last]

    # Figli della voce del percorso ([] = le voci di primo livello).
    def level(path) = path.reduce(@roots) { |nodes, idx| nodes[idx].children }

    def preorder(nodes, out = [])
      nodes.each do |node|
        out << node
        preorder(node.children, out)
      end
      out
    end

    def path_of(id, nodes = @roots, prefix = [])
      nodes.each_with_index do |node, i|
        return prefix + [i] if node.id == id

        found = path_of(id, node.children, prefix + [i])
        return found if found
      end
      nil
    end

    def focused_node(ptr) = @nodes.fetch(FFI.nctree_focused(ptr).address)

    # Fuoco sulla voce id: HOME (goto_first_item ricalcola curitem e percorso,
    # tree.c:113-124), poi nctree_next fino alla voce. Solo su un albero non vuoto.
    def refocus(ptr, id)
      ni = FFI::NcInput.new
      ni[:id] = FFI::NCKEY_HOME
      ni[:evtype] = FFI::NCTYPE_PRESS
      FFI.nctree_offer_input(ptr, ni)
      steps = preorder(@roots).index { |node| node.id == id }
      steps.times { FFI.nctree_next(ptr) }
    end
  end
end
