# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Piano di disegno (+struct ncplane*+): una matrice di celle con posizione,
  # z-order, cursore, stili e colori. I piani formano pile; ogni piano è legato a
  # un genitore (la radice di una pila è legata a se stessa).
  #
  # Ciclo di vita. Un piano appartiene al suo {Context}: diventa inutilizzabile
  # (ClosedError) dopo {#close}, dopo la chiusura del contesto o dopo
  # {Context#drop_planes}. Tre stati:
  # - posseduto (creato con {#create_child}, {#duplicate}, {Context#create_pile}, ...):
  #   {#close} lo distrugge;
  # - conosciuto ma non posseduto (lo stdplane, il piano di un widget): {#close}
  #   non fa nulla, il proprietario lo distrugge;
  # - preso in prestito (un piano ottenuto per navigazione, per esempio con
  #   {#above}, che il wrapper non ha creato): resta valido finché nel contesto
  #   non viene distrutto un piano; dopo va riottenuto.
  #
  # Il GC non distrugge mai un piano: il piano vive finché lo distruggi o finché
  # il contesto si chiude, come nel C. Due wrapper dello stesso piano sono {#==};
  # un wrapper chiuso è uguale solo ai wrapper creati senza distruzioni di piani
  # fra le due creazioni (il C riusa gli indirizzi dei piani distrutti).
  #
  # @example
  #   child = nc.stdplane.create_child(rows: 5, cols: 20, y: 2, x: :center)
  #   child.putstr('ciao', y: 0, x: 0)
  #   child.close
  #
  # Callback. Dentro un callback chiamato da notcurses (resize:, widget) non si
  # possono distruggere o riparentare piani: il C sta ancora percorrendo le sue
  # liste (use-after-free). Il wrapper lo impedisce con un'eccezione.
  #
  # Bug noto di 3.0.17 non aggirato: dopo il primo scroll, {#duplicate}, i
  # resize (anche la crescita per autogrow), {#rotate_cw}/{#rotate_ccw} e il
  # merge sul piano di destinazione permutano o perdono righe.
  #
  # Campi privati. Alcuni workaround ({#duplicate}, {#merge_down}, {#at},
  # {#contents}, {#resize_region}, il controllo dei glifi larghi tagliati)
  # leggono o scrivono campi privati del piano C: lo fanno solo con la
  # libreria 3.0.17 e se quei campi coincidono con i valori dell'API pubblica;
  # altrimenti non fanno nulla e il bug resta.
  class Plane
    include Resource

    # Simboli accettati da resize: e da {#set_resize_callback}. :maximize e
    # :realign usano le funzioni C; :marginalized e :placewithin usano
    # {#resize_marginalized} e {#resize_placewithin}, scritti in Ruby perché
    # le versioni C di 3.0.17 spostano il piano fuori dal genitore.
    RESIZE_CALLBACKS = %i[maximize realign marginalized placewithin].freeze

    # Funzioni C dei callback nativi.
    NATIVE_RESIZE_CALLBACKS = { maximize: 'ncplane_resize_maximize', realign: 'ncplane_resize_realign' }.freeze
    private_constant :NATIVE_RESIZE_CALLBACKS

    # Allineamenti del testo in {#putstr} e {#puttext}.
    TEXT_ALIGNS = %i[left center right].freeze

    # Set di glifi con un nome per {#box} e {#perimeter}.
    BOX_SETS = %i[light heavy rounded double ascii].freeze

    # Lati di un box: [bit NCBOXMASK_* per hide:, bit NCBOXGRAD_* per gradient:].
    BOX_SIDES = {
      top: [FFI::NCBOXMASK_TOP, FFI::NCBOXGRAD_TOP],
      right: [FFI::NCBOXMASK_RIGHT, FFI::NCBOXGRAD_RIGHT],
      bottom: [FFI::NCBOXMASK_BOTTOM, FFI::NCBOXGRAD_BOTTOM],
      left: [FFI::NCBOXMASK_LEFT, FFI::NCBOXGRAD_LEFT]
    }.freeze
    private_constant :BOX_SIDES

    # Caratteri con wcwidth 0, da cui notcurses può ricavare un EGC di
    # larghezza zero.
    ZERO_WIDTH_CANDIDATES = /[\p{Mn}\p{Me}\p{Cf}ᅠ-ᇿힰ-퟿]/
    private_constant :ZERO_WIDTH_CANDIDATES

    # Caratteri che si legano al carattere vicino nello stesso grapheme
    # cluster (UAX #29). Un EGC di più di 4 byte, che notcurses copia
    # nell'egcpool, ha più di un codepoint e quindi ne contiene almeno uno:
    # un testo senza questi caratteri non ha EGC da scrivere a parte (vedi
    # {#with_glyph_kept}).
    GRAPHEME_JOINERS = /\p{Grapheme_Cluster_Break=Extend} | \p{Grapheme_Cluster_Break=ZWJ}
                       | \p{Grapheme_Cluster_Break=SpacingMark} | \p{Grapheme_Cluster_Break=Prepend}
                       | \p{Grapheme_Cluster_Break=Regional_Indicator} | \p{Grapheme_Cluster_Break=L}
                       | \p{Grapheme_Cluster_Break=V} | \p{Grapheme_Cluster_Break=T}
                       | \p{Grapheme_Cluster_Break=LV} | \p{Grapheme_Cluster_Break=LVT}/x
    private_constant :GRAPHEME_JOINERS

    # Spazi tra le parole per {#puttext} (senza gli spazi non separabili).
    WORD_SPACES = /[\p{Zs}&&[^   ]]+/
    private_constant :WORD_SPACES

    # Caratteri che output_text! controlla uno per uno: controlli (tranne
    # "\n"), U+2028, U+2029 e indicatori regionali. Una sola scansione del
    # testo dice se serve guardare oltre. Cerca i byte UTF-8 di quei caratteri
    # (C2 80..9F, E2 80 A8..A9, F0 9F 87 A6..BF) in un testo UTF-8 valido, dove
    # non possono comparire a metà di un altro carattere: su un EGC da 6 MB
    # costa 5 ms, contro 210 ms della stessa ricerca con le proprietà Unicode.
    TEXT_SUSPECTS = /\xC2[\x80-\x9F]|[\x00-\x09\x0B-\x1F\x7F]|\xE2\x80[\xA8\xA9]|\xF0\x9F\x87[\xA6-\xBF]/n
    private_constant :TEXT_SUSPECTS

    # Un solo carattere ASCII stampabile: larghezza 1, un solo EGC e niente da
    # controllare (putegc salta nccell_load e ncstrwidth).
    PRINTABLE_ASCII_CHAR = /\A[ -~]\z/
    private_constant :PRINTABLE_ASCII_CHAR

    # Stato di un piano letto per una scrittura (ICH-594). Ogni lettura è una
    # chiamata FFI con due MemoryPointer: dimensioni, cursore, scrolling e
    # autogrow si leggono la prima volta che servono, e poi si ricordano finché
    # il C non può averli cambiati. Una scrittura C sposta il cursore di una
    # larghezza nota; su un piano che scorre o cresce cambia anche le
    # dimensioni e il cursore in modo non noto (notcurses.c:1873-1904:
    # scroll_down o ncplane_resize_simple a fine riga; 1978-1981: render dello
    # stdplane che scorre). {#advance!} calcola il cursore sul primo caso e
    # dimentica lo stato nel secondo: la lettura dopo lo rilegge. Lo crea un
    # metodo del piano dentro Guard.run, con il puntatore già controllato.
    class WriteState
      # @return [::FFI::Pointer] ncplane* del piano
      attr_reader :ptr

      # @param ptr [::FFI::Pointer] ncplane* del piano
      def initialize(ptr)
        @ptr = ptr
      end

      # @return [Array(Integer, Integer)] righe e colonne (+ncplane_dim_yx+)
      def dims
        @dims ||= begin
          rows = ::FFI::MemoryPointer.new(:uint)
          cols = ::FFI::MemoryPointer.new(:uint)
          FFI.ncplane_dim_yx(ptr, rows, cols)
          [rows.read_uint, cols.read_uint]
        end
      end

      # @return [Integer] righe
      def rows = dims[0]

      # @return [Integer] colonne
      def cols = dims[1]

      # @return [Array(Integer, Integer)] riga e colonna del cursore (+ncplane_cursor_yx+)
      def cursor
        @cursor ||= begin
          y = ::FFI::MemoryPointer.new(:uint)
          x = ::FFI::MemoryPointer.new(:uint)
          FFI.ncplane_cursor_yx(ptr, y, x)
          [y.read_uint, x.read_uint]
        end
      end

      # @return [Boolean] lo scrolling del piano (+ncplane_scrolling_p+)
      def scrolling?
        @scrolling = FFI.ncplane_scrolling_p(ptr) if @scrolling.nil?
        @scrolling
      end

      # @return [Boolean] l'autogrow del piano (+ncplane_autogrow_p+)
      def autogrow?
        @autogrow = FFI.ncplane_autogrow_p(ptr) if @autogrow.nil?
        @autogrow
      end

      # @return [Boolean] true se una scrittura C non fa scorrere né crescere il piano
      def fixed? = !(scrolling? || autogrow?)

      # Il cursore è in (y, x): il chiamante lo ha appena spostato con il C.
      def move_to(y, x)
        @cursor = [y, x]
      end

      # Dopo una scrittura C riuscita di width colonne in (y, x), con -1 per
      # "dal cursore". Se il cursore non è noto resta da leggere: la lettura dopo
      # una scrittura dà la posizione giusta.
      def advance!(y, x, width)
        at = @cursor
        if fixed? && (at || (y >= 0 && x >= 0))
          @cursor = [y.negative? ? at[0] : y, (x.negative? ? at[1] : x) + width]
        else
          forget!
        end
      end

      # La prossima lettura del cursore rilegge dal C.
      def forget_cursor!
        @cursor = nil
      end

      # La prossima lettura di dimensioni e cursore rilegge dal C.
      def forget!
        @dims = @cursor = nil
      end
    end
    private_constant :WriteState

    CORNERS = %w[ul ur ll lr].freeze
    private_constant :CORNERS

    # Campi privati di +struct ncplane+ fino ad autogrow (notcurses 3.0.17,
    # src/lib/internal.h:76-125): l'API pubblica non lascia leggere o scrivere
    # fb, egcpool, cella base, sprite, valign e fixedbound. I workaround li
    # usano solo attraverso internals, che controlla la versione della libreria
    # e i campi.
    #
    # @api private
    class Internals < ::FFI::Struct
      layout :fb, :pointer, :logrow, :int, :x, :uint, :y, :uint, :absx, :int, :absy, :int,
             :lenx, :uint, :leny, :uint,
             :pool, :pointer, :poolsize, :int, :poolused, :int, :poolwrite, :int, # egcpool
             :channels, :uint64, :pile, :pointer, :above, :pointer, :below, :pointer,
             :bnext, :pointer, :bprev, :pointer, :blist, :pointer, :boundto, :pointer,
             :sprite, :pointer, :tam, :pointer, :userptr, :pointer, :resizecb, :pointer,
             :basecell, FFI::NcCell, :name, :pointer, :halign, :int, :valign, :int,
             :stylemask, :uint16, :margin_b, :int, :margin_r, :int,
             :scrolling, :bool, :fixedbound, :bool, :autogrow, :bool
    end
    private_constant :Internals

    # Byte di una cella (sizeof(nccell)).
    CELL_BYTES = FFI::NcCell.size
    private_constant :CELL_BYTES

    # @return [Context] contesto a cui appartiene il piano
    attr_reader :context

    # Avvolge un puntatore ncplane* esistente. Di solito non serve chiamarlo: i
    # piani si ottengono da {Context#stdplane}, {#create_child} e dagli altri
    # metodi che restituiscono piani.
    #
    # @param ptr [::FFI::Pointer] ncplane* non NULL
    # @param owned [Boolean] true se {#close} deve distruggere il piano
    # @param context [Context, nil] contesto del piano; nil = il contesto attivo
    # @param owner [Resource, nil] proprietario la cui chiusura invalida il piano
    #   (default: il contesto)
    # @param tracked [Boolean] false = piano preso in prestito (vedi la classe)
    # @raise [PlaneError] se ptr è NULL
    # @raise [ArgumentError] se il piano ha già un wrapper aperto e il nuovo è
    #   tracciato o posseduto (un secondo wrapper si crea con owned: false,
    #   tracked: false)
    # @raise [ClosedError] se non c'è un Context attivo
    def initialize(ptr, owned: true, context: nil, owner: nil, tracked: true)
      Util.check_ptr!(ptr, PlaneError, 'ncplane*')
      ctx = context || Notcurses.active_context
      raise ClosedError, 'nessun Notcurses::Context attivo per il piano' unless ctx.is_a?(Context)
      # tracciato sfratterebbe il wrapper esistente e i suoi callback (il C chiamerebbe un
      # trampolino raccolto dal GC); posseduto distruggerebbe il piano sotto il wrapper esistente
      if (tracked || owned) && ctx.tracked_plane(ptr.address)
        raise ArgumentError, 'il piano ha già un Plane aperto: usa quello (o owned: false, tracked: false)'
      end

      @ptr = ptr
      @context = ctx
      @owner = owner || ctx
      @owned = owned
      @closed = false
      @callbacks = []
      @margins = nil
      @born = ctx.generation
      if tracked
        @generation = nil
        ctx.track_plane(self)
      else
        @generation = ctx.generation
      end
    end

    # @return [Boolean] true se il piano è chiuso, se il suo proprietario è
    #   chiuso, o se è preso in prestito e nel frattempo è stato distrutto un piano
    def closed?
      return true if super
      return false if @generation.nil?

      @generation != @context.generation
    end

    # @return [Boolean] true se {#close} distrugge il piano
    def owned? = @owned && !closed?

    # @return [Boolean] true per lo stdplane del contesto
    def stdplane? = !closed? && @context.stdplane.equal?(self)

    # Distrugge il piano (+ncplane_destroy+). I figli legati al piano passano al
    # suo genitore (o diventano radici di nuove pile, se il piano era una
    # radice). No-op se il piano è già chiuso o non è posseduto.
    #
    # Da un gestore +trap+ che poi torna al codice interrotto, la distruzione
    # non è rinviata come in {Context#close}: se il segnale ha interrotto
    # un'operazione sullo stesso piano, il C usa un piano già liberato. Da un
    # gestore +trap+ non chiudere un piano in uso (ICH-540).
    #
    # @return [nil]
    # @raise [PlaneError] dentro un callback chiamato da notcurses, o se
    #   notcurses segnala un errore nel riaggancio dei figli (in questo caso il
    #   piano risulta comunque distrutto)
    def close
      Guard.run do
        return nil if closed? || !@owned

        ctx = @context
        ctx.check_not_in_callback!('Plane#close', PlaneError)
        rc = FFI.ncplane_destroy(@ptr)
        invalidate!
        ctx.planes_destroyed!
        Util.check!(rc, PlaneError, 'ncplane_destroy')
        nil
      end
    end
    alias destroy close

    # Distrugge il piano e tutti i suoi discendenti (+ncplane_family_destroy+).
    # I wrapper dei discendenti diventano chiusi.
    #
    # @return [nil]
    # @raise [PlaneError] se un discendente è il piano di un widget aperto
    #   (chiudi prima il widget), se il piano non è posseduto, dentro un
    #   callback chiamato da notcurses, o se notcurses segnala un errore
    # @raise [ClosedError] se il piano è chiuso
    def family_destroy
      Guard.run do
        ptr = to_ptr
        raise PlaneError, 'family_destroy: il piano non è posseduto dal wrapper' unless @owned

        @context.check_not_in_callback!('Plane#family_destroy', PlaneError)
        victims = @context.tracked_planes.select do |plane|
          !plane.equal?(self) && FFI.ncplane_descendant_p(plane.address_ptr, ptr) != 0
        end
        if victims.any?(&:widget_plane?)
          raise PlaneError, 'family_destroy: un discendente è il piano di un widget aperto (chiudi prima il widget)'
        end

        ctx = @context
        rc = FFI.ncplane_family_destroy(ptr)
        victims.each(&:invalidate!)
        invalidate!
        ctx.planes_destroyed!
        Util.check!(rc, PlaneError, 'ncplane_family_destroy')
        nil
      end
    end

    # --- creazione ---

    # Crea un piano figlio legato a questo (+ncplane_create+). Il figlio è del
    # chiamante: va chiuso con {#close} (o usa il blocco).
    #
    # @param rows [Integer, nil] righe, >= 1 (omesso se margins: è dato)
    # @param cols [Integer, nil] colonne, >= 1 (omesso se margins: è dato)
    # @param y [Integer, Symbol] riga relativa al genitore, oppure :top, :center,
    #   :bottom (allineamento verticale, NCPLANE_OPTION_VERALIGNED)
    # @param x [Integer, Symbol] colonna relativa al genitore, oppure :left,
    #   :center, :right (allineamento orizzontale, NCPLANE_OPTION_HORALIGNED)
    # @param margins [Array(Integer, Integer, Integer, Integer), nil] margini
    #   [alto, destra, basso, sinistra] rispetto al genitore: il piano occupa lo
    #   spazio rimanente (almeno 1x1); esclude rows, cols, y e x. Il wrapper
    #   calcola posizione e dimensioni in Ruby invece di usare
    #   NCPLANE_OPTION_MARGINALIZED, che in 3.0.17 ignora i margini alto e
    #   sinistro
    # @param name [String, nil] nome (per il debug)
    # @param fixed [Boolean] NCPLANE_OPTION_FIXED: non scorre con un genitore che scorre
    # @param autogrow [Boolean] NCPLANE_OPTION_AUTOGROW: cresce per contenere l'output
    # @param vscroll [Boolean] NCPLANE_OPTION_VSCROLL: scorre verticalmente
    # @param resize [Symbol, #call, nil] callback quando il genitore cambia
    #   dimensione: :maximize, :realign, :marginalized (solo con margins:),
    #   :placewithin (vedi {RESIZE_CALLBACKS}) o un oggetto con +call(plane)+
    # @return [Plane] il figlio; con un blocco, il valore del blocco (il figlio
    #   viene distrutto alla fine)
    # @raise [PlaneError] se +ncplane_create+ fallisce
    # @raise [TypeError, ArgumentError] se un'opzione non è valida
    # @raise [ClosedError] se il piano è chiuso
    def create_child(rows: nil, cols: nil, y: 0, x: 0, margins: nil, name: nil, fixed: false,
                     autogrow: false, vscroll: false, resize: nil, &block)
      created = Guard.run do
        opts, keep = Plane.build_options(context: @context, parent_dims: dims, rows: rows, cols: cols, y: y, x: x,
                                         margins: margins, name: name, fixed: fixed, autogrow: autogrow,
                                         vscroll: vscroll, resize: resize)
        ptr = FFI.ncplane_create(to_ptr, opts)
        Util.check_ptr!(ptr, PlaneError, 'ncplane_create')
        child = Plane.new(ptr, owned: true, context: @context)
        child.adopt_options!(keep)
        child
      end
      Util.with_resource(created, &block)
    end

    # Opzioni C di un nuovo piano (+ncplane_options+).
    #
    # @api private
    # @param parent_dims [Array(Integer, Integer)] dimensioni del genitore (o
    #   del terminale, per una pila), per margins:
    # @return [Array(FFI::NcPlaneOptions, Hash)] la struct e gli oggetti da tenere vivi
    def self.build_options(context:, parent_dims:, rows:, cols:, y:, x:, margins: nil, name: nil, fixed: false,
                           autogrow: false, vscroll: false, resize: nil)
      opts = FFI::NcPlaneOptions.new
      opts[:flags] = Util.flag(fixed, FFI::NCPLANE_OPTION_FIXED, 'fixed') |
                     Util.flag(autogrow, FFI::NCPLANE_OPTION_AUTOGROW, 'autogrow') |
                     Util.flag(vscroll, FFI::NCPLANE_OPTION_VSCROLL, 'vscroll')
      if margins.nil?
        raise ArgumentError, 'resize: :marginalized richiede margins:' if resize == :marginalized

        opts[:rows] = Util.integer!(rows, 'rows', 1..Util::UINT32.max)
        opts[:cols] = Util.integer!(cols, 'cols', 1..Util::UINT32.max)
        opts[:y], vflag = position(y, 'y', %i[top center bottom], FFI::NCPLANE_OPTION_VERALIGNED)
        opts[:x], hflag = position(x, 'x', %i[left center right], FFI::NCPLANE_OPTION_HORALIGNED)
        opts[:flags] |= vflag | hflag
      else
        unless rows.nil? && cols.nil? && y == 0 && x == 0
          raise ArgumentError, 'margins: esclude rows:, cols:, y: e x: (il piano occupa lo spazio del genitore)'
        end

        margins = margins!(margins)
        opts[:rows], opts[:cols] = marginalized_dims(parent_dims, margins)
        opts[:y] = margins[0]
        opts[:x] = margins[3]
      end
      keep = { margins: margins }
      keep[:name] = Util.c_string(name, 'name')
      opts[:name] = keep[:name] || ::FFI::Pointer::NULL
      fn, callable = resize_function(context, resize)
      opts[:resizecb] = fn || ::FFI::Pointer::NULL
      keep[:resizecb] = fn
      keep[:resize] = callable
      [opts, keep]
    end

    # Margini validati, congelati.
    # @api private
    # @return [Array(Integer, Integer, Integer, Integer)]
    def self.margins!(margins)
      raise TypeError, 'margins deve essere [alto, destra, basso, sinistra]' unless margins.is_a?(Array) && margins.size == 4

      margins.each_with_index.map { |v, i| Util.integer!(v, "margins[#{i}]", Util::NONNEG_INT) }.freeze
    end

    # Dimensioni di un piano con margini dentro un'area: almeno 1x1.
    # @api private
    # @return [Array(Integer, Integer)] [righe, colonne]
    def self.marginalized_dims(area_dims, margins)
      top, right, bottom, left = margins
      [[area_dims[0] - top - bottom, 1].max, [area_dims[1] - left - right, 1].max]
    end

    # Coordinata intera o simbolo di allineamento.
    # @api private
    def self.position(value, name, aligns, flag)
      if value.is_a?(Symbol)
        raise ArgumentError, "#{name} = #{value.inspect} non valido: usa un Integer o #{aligns.map(&:inspect).join(', ')}" unless aligns.include?(value)

        [Util.align_value(value), flag]
      else
        [Util.int!(value, name), 0]
      end
    end

    # Puntatore a funzione C per resize: (simbolo nativo o callable Ruby).
    # @api private
    # @return [Array(::FFI::Pointer, Object)] [puntatore o nil, valore Ruby da restituire con {#resize_callback}]
    def self.resize_function(context, resize)
      case resize
      when nil then [nil, nil]
      when :maximize, :realign then [native_function(NATIVE_RESIZE_CALLBACKS.fetch(resize)), resize]
      when :marginalized then [ruby_resize_function(context, ->(plane) { plane.resize_marginalized }), resize]
      when :placewithin then [ruby_resize_function(context, ->(plane) { plane.resize_placewithin }), resize]
      when Symbol
        raise ArgumentError,
              "resize = #{resize.inspect} non valido: usa #{RESIZE_CALLBACKS.map(&:inspect).join(', ')} o un oggetto con call"
      else
        raise TypeError, "resize deve essere un Symbol o rispondere a call, non #{resize.class}" unless resize.respond_to?(:call)

        [ruby_resize_function(context, resize), resize]
      end
    end

    # Trampolino C → Ruby per un callback di resize: le eccezioni restano nel
    # contesto e il C riceve -1. Prima del callback rimette la cella base dei
    # piani che il C ha appena ridimensionato senza conservare niente
    # (keeping_base_cell): il callback può riempire l'egcpool (ICH-531).
    # @api private
    # @return [::FFI::Function]
    def self.ruby_resize_function(context, callable)
      box = context.callback_errors
      ::FFI::Function.new(:int, [:pointer]) do |plane_ptr|
        Util.guard(box, -1) do
          context.callback_scope do
            context.base_restores.each { |restore| restore.call(false) }
            callable.call(context.plane_for(plane_ptr))
          end
          0
        end
      end
    end

    # Indirizzo di una funzione esportata da libnotcurses-core.
    # @api private
    def self.native_function(name)
      FFI.ffi_libraries.each do |lib|
        sym = lib.find_function(name)
        return sym if sym
      end
      raise PlaneError, "funzione nativa #{name} non trovata"
    end

    # Duplica il piano: stessa geometria, contenuto, cursore, stile, canali,
    # cella base, nome e callback di resize; nessun figlio (+ncplane_dup+). Il
    # duplicato è del chiamante, sta subito sopra l'originale nello z-order e
    # nella stessa posizione sullo schermo, legato allo stesso genitore (o
    # all'originale, se questo è una radice). Non si chiama +dup+ per non
    # ridefinire Object#dup.
    #
    # Bug di 3.0.17 aggirati: il C posiziona la copia usando le coordinate
    # assolute come relative, la mette in cima alla pila e azzera scrolling e
    # autogrow; il wrapper sposta la copia e ripristina i due flag. Il C non
    # copia nemmeno il flag fixed e l'allineamento verticale (per
    # {#resize_realign}): il wrapper li scrive nei campi privati della copia
    # (vedi "Campi privati" nella classe). Un callback di resize interno di un
    # widget non viene copiato (con il C la copia andrebbe in crash al primo
    # resize).
    #
    # @return [Plane] il duplicato; con un blocco, il valore del blocco (il
    #   duplicato viene distrutto alla fine)
    # @raise [PlaneError] se +ncplane_dup+ fallisce
    # @raise [ClosedError] se il piano è chiuso
    def duplicate(&block)
      created = Guard.run do
        src = to_ptr
        ptr = FFI.ncplane_dup(src, ::FFI::Pointer::NULL)
        Util.check_ptr!(ptr, PlaneError, 'ncplane_dup')
        copy = Plane.new(ptr, owned: true, context: @context)
        # il resizecb copiato dal C: un trampolino Ruby deve restare vivo anche per la copia
        copy.adopt_options!(margins: @margins, resizecb: @resize_fn, resize: @resize)
        fn = FFI.ncplane_resizecb(src)
        FFI.ncplane_set_resizecb(ptr, ::FFI::Pointer::NULL) unless fn.null? || own_resize_function?(fn) || native_resize_symbol(fn)
        root? ? copy.move(0, 0) : copy.move(*yx)
        copy.move_above(self)
        copy.scrolling = true if scrolling?
        copy.autogrow = true if autogrow?
        # ncplane_dup crea la copia con flags = 0 e copia solo halign (notcurses.c:776, 793) (ICH-216)
        if (from = internals(src)) && (to = internals(ptr))
          to[:fixedbound] = from[:fixedbound]
          to[:valign] = from[:valign]
        end
        copy
      end
      Util.with_resource(created, &block)
    end

    # --- resize ---

    # Ridimensiona il piano tenendo l'origine e il contenuto che ci sta
    # (+ncplane_resize_simple+). Chiama i callback di resize dei figli.
    #
    # Un glifo largo tagliato dal nuovo bordo destro diventa una cella vuota:
    # notcurses 3.0.17 ne lascia la metà sinistra nell'ultima colonna, e la
    # scrittura successiva su quella cella andrebbe oltre la riga (oltre il
    # framebuffer, sull'ultima riga). Lo stesso vale per i resize che fa il C:
    # lo stdplane quando il terminale si restringe e i figli con
    # resize: :maximize; lì la cella si svuota alla prima scrittura sul piano,
    # se le colonne sono cambiate dall'ultimo controllo. Lo stato del controllo
    # vale per il piano C: lo tiene il Plane tracciato del piano, e i Plane presi
    # in prestito (tracked: false) usano il suo; senza un Plane tracciato aperto
    # ogni scrittura controlla i bordi.
    #
    # Il controllo legge le celle dei bordi con +ncplane_at_yx_cell+, che copia
    # l'EGC nell'egcpool del piano e fallisce se il pool è pieno (16 MiB; solo
    # per gli EGC di più di 4 byte). Quelle celle il wrapper le legge con
    # +ncplane_at_yx+, che non usa il pool, e ne misura la larghezza: anche un
    # glifo largo che notcurses non riesce a rileggere, se viene tagliato,
    # diventa una cella vuota. Questa lettura usa i campi privati del piano
    # per riconoscere un piano con un bitmap (vedi "Campi privati" nella
    # classe): senza, quelle celle non contano come glifi.
    #
    # @param rows [Integer] nuove righe, >= 1
    # @param cols [Integer] nuove colonne, >= 1
    # @return [self]
    # @raise [PlaneError] se il resize fallisce (per esempio sullo stdplane) o
    #   se fallisce un callback nativo di un figlio (il resize resta applicato)
    # @raise [Exception] l'eccezione di un callback Ruby di resize di un figlio
    # @raise [TypeError, ArgumentError] se rows o cols non sono validi
    # @raise [ClosedError] se il piano è chiuso
    def resize(rows, cols)
      Guard.run do
        Util.integer!(rows, 'rows', 1..Util::UINT32.max)
        Util.integer!(cols, 'cols', 1..Util::UINT32.max)
        ptr = to_ptr
        rc = FFI.ncplane_resize_simple(ptr, rows, cols)
        clear_cut_glyphs!(ptr, force: true)
        @context.raise_callback_errors!
        Util.check!(rc, PlaneError, 'ncplane_resize_simple')
        self
      end
    end

    # Ridimensiona il piano conservando una regione (+ncplane_resize+). La
    # regione (keep_y, keep_x, keep_rows, keep_cols) resta ferma sullo schermo
    # e nel nuovo piano finisce in (-y_off, -x_off): l'origine del piano si
    # sposta di (keep_y + y_off, keep_x + x_off). Il resto del piano è vuoto.
    #
    # Il wrapper rifiuta i casi in cui notcurses 3.0.17 sbaglia: offset
    # positivi, una regione che non entra nel nuovo piano (con x_off < 0 il C
    # scrive oltre il buffer), un resize che il C ignora (stesse dimensioni e
    # regione da (0, 0)) e y_off diverso da 0 con la larghezza intera
    # conservata (il C sposta l'origine ma non il contenuto).
    #
    # Bug di 3.0.17 aggirato: con keep_x > 0 il C rilascia per errore gli EGC
    # di più di 4 byte di una parte della regione conservata, e quelle celle
    # restano vuote o mostrano l'EGC di un'altra cella. Il wrapper fa allora il
    # resize in due passi: prima con qualche riga vuota in più in alto, poi le
    # toglie. In quel caso, cioè quando keep_x + x_off > -y_off * cols, i
    # callback di resize dei figli vengono chiamati due volte: la prima con il
    # piano più alto e spostato in su rispetto al risultato. Su un piano che ha
    # già fatto scroll il resize in due passi conserva anche l'ordine delle
    # righe, che negli altri resize cambia (bug noto, nella descrizione della
    # classe). Un callback che nel primo passo ridimensiona il piano lavora
    # sul piano intermedio: ne può togliere le righe conservate invece di
    # quelle vuote in più, e il secondo passo allora fallisce (PlaneError).
    # Il resize in due passi costa di più: circa 2 ms invece di 0,2 su un
    # piano 50x200.
    #
    # Bug di 3.0.17 aggirato: un resize che non conserva niente (keep_rows 0)
    # svuota l'egcpool, e la cella base con un EGC di più di 4 byte finiva su
    # un pool liberato (SIGSEGV in {#base}). Il wrapper rimette la cella base
    # dopo il resize, o prima del primo callback Ruby di resize di un figlio:
    # il callback vede la base com'era, e se riempie l'egcpool (16 MiB) sono le
    # sue scritture a fallire, non la base. Se il callback cambia la base, il
    # wrapper lascia la sua. Se il resize fallisce senza cambiare il piano, la
    # base resta com'era.
    #
    # Un glifo largo tagliato che resta sul bordo del piano diventa una cella
    # vuota, come in {#resize}: con keep_x dentro un glifo largo ne resterebbe
    # la metà destra in colonna 0, e la scrittura successiva andrebbe nella riga
    # sopra (prima del framebuffer, sulla riga 0). Con x_off < 0 la metà destra
    # può finire nell'ultima colonna, e anche lì diventa una cella vuota; dentro
    # il piano resta finché una scrittura non la copre: lì il C non scrive fuori
    # dalla riga.
    #
    # @param rows [Integer] righe dopo il resize, >= 1
    # @param cols [Integer] colonne dopo il resize, >= 1
    # @param keep_y [Integer] riga della regione da conservare, >= 0
    # @param keep_x [Integer] colonna della regione da conservare, >= 0
    # @param keep_rows [Integer] righe da conservare (0 = niente: anche
    #   keep_cols deve essere 0)
    # @param keep_cols [Integer] colonne da conservare
    # @param y_off [Integer] <= 0
    # @param x_off [Integer] <= 0
    # @return [self]
    # @raise [PlaneError] se il resize fallisce (stdplane, regione fuori dal
    #   piano) o se fallisce un callback nativo di un figlio
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ClosedError] se il piano è chiuso
    def resize_region(rows:, cols:, keep_y: 0, keep_x: 0, keep_rows: 0, keep_cols: 0, y_off: 0, x_off: 0)
      Guard.run do
        cur_rows, cur_cols = dims
        Util.integer!(rows, 'rows', 1..Util::UINT32.max)
        Util.integer!(cols, 'cols', 1..Util::UINT32.max)
        Util.integer!(keep_y, 'keep_y', Util::NONNEG_INT)
        Util.integer!(keep_x, 'keep_x', Util::NONNEG_INT)
        Util.integer!(keep_rows, 'keep_rows', Util::NONNEG_INT)
        Util.integer!(keep_cols, 'keep_cols', Util::NONNEG_INT)
        Util.integer!(y_off, 'y_off', Util::INT32.min..0)
        Util.integer!(x_off, 'x_off', Util::INT32.min..0)
        if keep_rows.zero? != keep_cols.zero?
          raise ArgumentError, 'keep_rows e keep_cols devono essere entrambi 0 o entrambi > 0'
        end
        if keep_rows - y_off > rows || keep_cols - x_off > cols
          raise ArgumentError, 'la regione conservata non entra nel nuovo piano (serve keep_rows - y_off <= rows ' \
                               'e keep_cols - x_off <= cols)'
        end
        if keep_y.zero? && keep_x.zero? && [rows, cols] == [cur_rows, cur_cols] && [keep_rows, keep_cols] != [rows, cols]
          raise ArgumentError, 'notcurses 3.0.17 ignora un resize con le stesse dimensioni e la regione in (0, 0)'
        end
        if keep_rows.positive? && keep_y.zero? && keep_cols == cur_cols && cols == cur_cols && !y_off.zero?
          raise ArgumentError, 'con la larghezza intera conservata da (0, 0) notcurses 3.0.17 non sposta il contenuto: ' \
                               'y_off deve essere 0'
        end

        ptr = to_ptr
        # Il ciclo che rilascia gli EGC delle celle perse (notcurses.c:995-997) parte dall'indice nel
        # framebuffer nuovo, riga di destinazione * cols - x_off + keep_cols, usato come colonna di quello
        # vecchio: finché è minore di keep_x + keep_cols rilascia EGC della regione conservata (ICH-215).
        # extra righe vuote in più in alto portano la prima riga copiata oltre quel punto; il secondo resize
        # le toglie (con keep_x == 0 il ciclo non tocca la regione).
        extra = keep_rows.zero? ? 0 : [((keep_x + x_off + cols - 1) / cols) + y_off, 0].max
        # il C rifiuta senza toccare il piano lo stdplane e una regione fuori dal piano (notcurses.c:842-849,
        # 1013), controllati qui, e una malloc fallita (notcurses.c:918), controllata dopo il primo passo: negli
        # altri casi il primo resize è applicato e va completato, anche quando ha restituito il -1 del callback di
        # un figlio (che può anche aver spostato il piano)
        two_steps = extra.positive? && address != @context.stdplane.address &&
                    keep_y + keep_rows <= cur_rows && keep_x + keep_cols <= cur_cols
        st = two_steps && internals(ptr)
        old = st && fb_bytes(st)
        fb = st && st[:fb].address
        rc = keeping_base_cell(keep_rows.zero?) do
          FFI.ncplane_resize(ptr, keep_y, keep_x, keep_rows, keep_cols, y_off - extra, x_off, rows + extra, cols)
        end
        st = two_steps && internals(ptr)
        # con la malloc fallita (notcurses.c:918) il primo passo non ha toccato il piano (fb uguale): niente secondo
        if two_steps && !(fb && st && st[:fb].address == fb)
          # il C scrive il framebuffer nuovo in ordine logico ma lascia logrow (bug di ICH-214): su un piano che
          # ha già fatto scroll il secondo passo leggerebbe le righe sbagliate e ne perderebbe una
          st[:logrow] = 0 if st
          rc |= FFI.ncplane_resize(ptr, extra, 0, rows, cols, 0, 0, rows, cols)
        end
        release_unused!(ptr, pooled(old)) if old
        clear_cut_glyphs!(ptr, force: true) # con keep_x > 0 il contenuto si sposta anche a dimensioni invariate
        @context.raise_callback_errors!
        Util.check!(rc, PlaneError, 'ncplane_resize')
        self
      end
    end

    # Ridimensiona il piano alle dimensioni della pila, cioè del terminale
    # (+ncplane_resize_maximize+), tenendo l'origine. Anche per un figlio la
    # misura è la pila, non il genitore. Un glifo largo tagliato dal nuovo bordo
    # diventa una cella vuota, come in {#resize}.
    #
    # @return [self]
    # @raise [PlaneError] se il resize fallisce o se fallisce un callback
    #   nativo di un figlio
    # @raise [ClosedError] se il piano è chiuso
    def resize_maximize
      Guard.run do
        ptr = to_ptr
        rc = FFI.ncplane_resize_maximize(ptr)
        clear_cut_glyphs!(ptr, force: true)
        @context.raise_callback_errors!
        Util.check!(rc, PlaneError, 'ncplane_resize_maximize')
        self
      end
    end

    # Ridimensiona e riposiziona il piano secondo i margini dati alla creazione
    # (margins:): il piano torna in (alto, sinistra) e occupa il genitore (o il
    # terminale, per una radice) meno i margini, almeno 1x1. Scritto in Ruby:
    # +ncplane_resize_marginalized+ di 3.0.17 sposta il piano fuori dal genitore.
    #
    # @return [self]
    # @raise [PlaneError] se il piano non è stato creato con margins:, o se il
    #   resize fallisce
    # @raise [ClosedError] se il piano è chiuso
    def resize_marginalized
      Guard.run do
        ptr = to_ptr
        raise PlaneError, 'resize_marginalized: il piano non è stato creato con margins:' unless @margins

        parent_ptr = FFI.ncplane_parent(ptr)
        area = parent_ptr.address == address ? @context.dims : [FFI.ncplane_dim_y(parent_ptr), FFI.ncplane_dim_x(parent_ptr)]
        rows, cols = Plane.marginalized_dims(area, @margins)
        resize(rows, cols) unless [rows, cols] == dims
        move(@margins[0], @margins[3])
      end
    end

    # Riallinea il piano al genitore secondo gli allineamenti di creazione
    # (y:/x: simbolici) (+ncplane_resize_realign+).
    #
    # @return [self]
    # @raise [PlaneError] se il piano è una radice o non è allineato
    # @raise [ClosedError] se il piano è chiuso
    def resize_realign
      Guard.run do
        ptr = to_ptr
        raise PlaneError, 'resize_realign: una radice non ha un genitore a cui allinearsi' if root?

        Util.check!(FFI.ncplane_resize_realign(ptr), PlaneError, 'ncplane_resize_realign')
        self
      end
    end

    # Sposta il piano, senza ridimensionarlo, in modo che stia dentro il
    # genitore; se è più grande del genitore preferisce l'angolo in alto a
    # sinistra. No-op per una radice. Scritto in Ruby:
    # +ncplane_resize_placewithin+ di 3.0.17 confronta coordinate assolute con
    # le dimensioni del genitore.
    #
    # @return [self]
    # @raise [ClosedError] se il piano è chiuso
    def resize_placewithin
      Guard.run do
        ptr = to_ptr
        parent_ptr = FFI.ncplane_parent(ptr)
        return self if parent_ptr.address == address

        prows = FFI.ncplane_dim_y(parent_ptr)
        pcols = FFI.ncplane_dim_x(parent_ptr)
        rows, cols = dims
        y, x = yx
        ny = (y + rows > prows ? prows - rows : y).clamp(0..)
        nx = (x + cols > pcols ? pcols - cols : x).clamp(0..)
        [ny, nx] == [y, x] ? self : move(ny, nx)
      end
    end

    # Callback di resize corrente (+ncplane_resizecb+).
    #
    # @return [Symbol, #call, ::FFI::Pointer, nil] uno dei {RESIZE_CALLBACKS},
    #   l'oggetto Ruby impostato dal wrapper, un puntatore a una funzione C che
    #   il wrapper non conosce (per esempio di un widget), o nil
    # @raise [ClosedError] se il piano è chiuso
    def resize_callback
      Guard.run do
        fn = FFI.ncplane_resizecb(to_ptr)
        return nil if fn.null?
        return @resize if own_resize_function?(fn)

        native_resize_symbol(fn) || fn
      end
    end

    # Imposta il callback chiamato quando il genitore cambia dimensione
    # (+ncplane_set_resizecb+). Un callback Ruby riceve questo piano; se
    # solleva un'eccezione, il C riceve -1 e l'eccezione esce dal metodo che ha
    # causato il resize ({Context#render}, {#resize}, l'output che fa crescere
    # un piano con autogrow, ...). Il callback non può distruggere o
    # riparentare piani. break, return e throw non possono uscire attraverso il
    # C: diventano una LocalJumpError, che esce come un'eccezione.
    #
    # @param callback [Symbol, #call, nil] uno dei {RESIZE_CALLBACKS}, un
    #   oggetto con +call(plane)+, o nil per toglierlo
    # @yieldparam plane [Plane] in alternativa a callback
    # @return [self]
    # @raise [PlaneError] sullo stdplane (l'header lo vieta), sul piano di un
    #   widget aperto (il widget può usarlo), con :marginalized
    #   su un piano creato senza margins:, o per un callback scritto in Ruby su
    #   un piano preso in prestito (il wrapper non saprebbe per quanto tenerlo
    #   vivo)
    # @raise [ArgumentError] se si passano sia callback sia un blocco
    # @raise [TypeError, ArgumentError] se callback non è valido
    # @raise [ClosedError] se il piano è chiuso
    def set_resize_callback(callback: nil, &block)
      Guard.run do
        ptr = to_ptr
        raise ArgumentError, 'passa un callback o un blocco, non entrambi' if callback && block
        raise PlaneError, 'il resizecb dello stdplane non si può cambiare' if stdplane?
        # alcuni widget (ncmenu) usano il resizecb del loro piano
        raise PlaneError, 'il resizecb del piano di un widget non si può cambiare' if widget_plane?

        callback ||= block
        raise PlaneError, 'resize :marginalized: il piano non è stato creato con margins:' if callback == :marginalized && @margins.nil?

        fn, value = Plane.resize_function(@context, callback)
        if fn.is_a?(::FFI::Function) && !@generation.nil?
          raise PlaneError, 'callback scritto in Ruby su un piano preso in prestito: ottieni il piano dal suo creatore'
        end

        FFI.ncplane_set_resizecb(ptr, fn || ::FFI::Pointer::NULL)
        @callbacks.delete(@resize_fn) if @resize_fn
        @resize_fn = fn.is_a?(::FFI::Function) ? fn : nil
        @callbacks << @resize_fn if @resize_fn
        @resize = value
        self
      end
    end

    # --- nome, genitore, contesto ---

    # Nome del piano (+ncplane_name+).
    # @return [String, nil]
    # @raise [ClosedError] se il piano è chiuso
    def name = Guard.run { Util.take_string(FFI.ncplane_name(to_ptr)) }

    # Cambia il nome del piano (+ncplane_set_name+).
    #
    # @param name [String, nil] nuovo nome, nil per toglierlo
    # @raise [PlaneError] se la copia del nome fallisce
    # @raise [TypeError, ArgumentError] se name non è una String valida
    # @raise [ClosedError] se il piano è chiuso
    def name=(name)
      Guard.run do
        Util.check!(FFI.ncplane_set_name(to_ptr, Util.string_or_nil!(name, 'name')), PlaneError, 'ncplane_set_name')
      end
    end

    # Piano a cui questo è legato (+ncplane_parent+).
    # @return [Plane, nil] nil se il piano è la radice di una pila
    # @raise [ClosedError] se il piano è chiuso
    def parent
      Guard.run do
        ptr = FFI.ncplane_parent(to_ptr)
        ptr.address == address ? nil : @context.plane_for(ptr)
      end
    end

    # @return [Boolean] true se il piano è la radice di una pila
    # @raise [ClosedError] se il piano è chiuso
    def root? = Guard.run { FFI.ncplane_parent(to_ptr).address == address }

    # Lega il piano a un nuovo genitore (+ncplane_reparent+). I figli del piano
    # passano al vecchio genitore. Con new_parent uguale al piano stesso, il
    # piano diventa la radice di una nuova pila.
    #
    # La posizione assoluta non cambia. Se il piano passa a un'altra pila va
    # subito sopra new_parent; una pila diversa da quella dello stdplane non
    # viene disegnata da {Context#render}.
    #
    # @param new_parent [Plane] nuovo genitore (dello stesso contesto), o self
    # @return [self]
    # @raise [PlaneError] sullo stdplane, dentro un callback chiamato da
    #   notcurses, o se +ncplane_reparent+ fallisce
    # @raise [TypeError] se new_parent non è un Plane
    # @raise [ClosedError] se uno dei piani è chiuso
    def reparent(new_parent)
      Guard.run do
        target = same_context_plane!(new_parent, 'new_parent')
        @context.check_not_in_callback!('Plane#reparent', PlaneError)
        Util.check_ptr!(FFI.ncplane_reparent(to_ptr, target), PlaneError, 'ncplane_reparent')
        self
      end
    end

    # Come {#reparent}, ma i figli seguono il piano (+ncplane_reparent_family+).
    # Se la famiglia cambia pila, il suo ordine interno nello z-order viene
    # ricostruito dall'ordine di creazione (il figlio più recente in alto).
    #
    # @param new_parent [Plane] nuovo genitore, o self
    # @return [self]
    # @raise [PlaneError] se new_parent è un discendente del piano, sullo
    #   stdplane, dentro un callback chiamato da notcurses, o se la chiamata
    #   fallisce
    # @raise [TypeError] se new_parent non è un Plane
    # @raise [ClosedError] se uno dei piani è chiuso
    def reparent_family(new_parent)
      Guard.run do
        target = same_context_plane!(new_parent, 'new_parent')
        @context.check_not_in_callback!('Plane#reparent_family', PlaneError)
        Util.check_ptr!(FFI.ncplane_reparent_family(to_ptr, target), PlaneError, 'ncplane_reparent_family')
        self
      end
    end

    # @param ancestor [Plane]
    # @return [Boolean] true se il piano discende da ancestor (+ncplane_descendant_p+)
    # @raise [TypeError] se ancestor non è un Plane
    # @raise [ClosedError] se uno dei piani è chiuso
    def descendant_of?(ancestor)
      Guard.run do
        FFI.ncplane_descendant_p(to_ptr, same_context_plane!(ancestor, 'ancestor')) != 0
      end
    end

    # --- pila e render ---

    # @return [Plane] piano in cima alla pila di questo piano (+ncpile_top+)
    # @raise [ClosedError] se il piano è chiuso
    def pile_top = Guard.run { @context.plane_for(FFI.ncpile_top(to_ptr)) }

    # @return [Plane] piano in fondo alla pila di questo piano (+ncpile_bottom+)
    # @raise [ClosedError] se il piano è chiuso
    def pile_bottom = Guard.run { @context.plane_for(FFI.ncpile_bottom(to_ptr)) }

    # Disegna la pila di questo piano (+ncpile_render+) e, con rasterize: true,
    # la scrive sul terminale (+ncpile_rasterize+). Serve per le pile diverse
    # da quella dello stdplane, che {Context#render} non disegna. Il terminale
    # mostra una pila alla volta.
    #
    # Il wrapper non offre il solo rasterize: in 3.0.17 +ncpile_rasterize+ su
    # una pila mai renderizzata va in crash (SIGSEGV).
    #
    # @param rasterize [Boolean] false = calcola il frame senza scriverlo
    # @return [self]
    # @raise [RenderError] se il render o la scrittura falliscono
    # @raise [Exception] l'eccezione di un callback Ruby di resize
    # @raise [TypeError] se rasterize non è true o false
    # @raise [ClosedError] se il piano è chiuso
    def render_pile(rasterize: true)
      Guard.run do
        ptr = to_ptr
        Util.bool!(rasterize, 'rasterize')
        rc = FFI.ncpile_render(ptr)
        @context.raise_callback_errors!
        Util.check!(rc, RenderError, 'ncpile_render')
        return self unless rasterize

        rc = FFI.ncpile_rasterize(ptr)
        @context.raise_callback_errors!
        Util.check!(rc, RenderError, 'ncpile_rasterize')
        self
      end
    end

    # --- geometria ---

    # @return [Integer] righe (+ncplane_dim_y+)
    # @raise [ClosedError] se il piano è chiuso
    def dim_y = Guard.run { FFI.ncplane_dim_y(to_ptr) }

    # @return [Integer] colonne (+ncplane_dim_x+)
    # @raise [ClosedError] se il piano è chiuso
    def dim_x = Guard.run { FFI.ncplane_dim_x(to_ptr) }

    # @return [Array(Integer, Integer)] [righe, colonne] (+ncplane_dim_yx+)
    # @raise [ClosedError] se il piano è chiuso
    def dims = Guard.run { WriteState.new(to_ptr).dims }

    # Geometria in pixel (+ncplane_pixel_geom+).
    #
    # @return [Hash{Symbol => Integer}] :pixel_y e :pixel_x (area di
    #   visualizzazione), :cell_pixel_y e :cell_pixel_x (una cella),
    #   :max_bitmap_y e :max_bitmap_x (bitmap massima, 0 = nessun limite o
    #   bitmap non supportate)
    # @raise [ClosedError] se il piano è chiuso
    def pixel_geom
      Guard.run do
        ptrs = Array.new(6) { ::FFI::MemoryPointer.new(:uint) }
        FFI.ncplane_pixel_geom(to_ptr, *ptrs)
        y, x, cy, cx, my, mx = ptrs.map(&:read_uint)
        { pixel_y: y, pixel_x: x, cell_pixel_y: cy, cell_pixel_x: cx, max_bitmap_y: my, max_bitmap_x: mx }.freeze
      end
    end

    # @return [Array(Integer, Integer)] origine rispetto al genitore (o alla
    #   pila, per una radice) (+ncplane_yx+)
    # @raise [ClosedError] se il piano è chiuso
    def yx
      Guard.run do
        y = ::FFI::MemoryPointer.new(:int)
        x = ::FFI::MemoryPointer.new(:int)
        FFI.ncplane_yx(to_ptr, y, x)
        [y.read_int, x.read_int]
      end
    end

    # @return [Integer] riga dell'origine rispetto al genitore (+ncplane_y+)
    # @raise [ClosedError] se il piano è chiuso
    def y = Guard.run { FFI.ncplane_y(to_ptr) }

    # @return [Integer] colonna dell'origine rispetto al genitore (+ncplane_x+)
    # @raise [ClosedError] se il piano è chiuso
    def x = Guard.run { FFI.ncplane_x(to_ptr) }

    # @return [Array(Integer, Integer)] origine rispetto alla pila (+ncplane_abs_yx+)
    # @raise [ClosedError] se il piano è chiuso
    def abs_yx
      Guard.run do
        y = ::FFI::MemoryPointer.new(:int)
        x = ::FFI::MemoryPointer.new(:int)
        FFI.ncplane_abs_yx(to_ptr, y, x)
        [y.read_int, x.read_int]
      end
    end

    # @return [Integer] riga dell'origine rispetto alla pila (+ncplane_abs_y+)
    # @raise [ClosedError] se il piano è chiuso
    def abs_y = Guard.run { FFI.ncplane_abs_y(to_ptr) }

    # @return [Integer] colonna dell'origine rispetto alla pila (+ncplane_abs_x+)
    # @raise [ClosedError] se il piano è chiuso
    def abs_x = Guard.run { FFI.ncplane_abs_x(to_ptr) }

    # Centro del piano, in coordinate assolute (+ncplane_center_abs+); con un
    # numero pari di righe o colonne preferisce l'alto/sinistra.
    # @return [Array(Integer, Integer)] [y, x]
    # @raise [ClosedError] se il piano è chiuso
    def center_abs
      Guard.run do
        y = ::FFI::MemoryPointer.new(:int)
        x = ::FFI::MemoryPointer.new(:int)
        FFI.ncplane_center_abs(to_ptr, y, x)
        [y.read_int, x.read_int]
      end
    end

    # Converte una coordinata relativa a questo piano in una relativa a dst
    # (+ncplane_translate+).
    #
    # @param y [Integer] riga relativa a questo piano
    # @param x [Integer] colonna relativa a questo piano
    # @param dst [Plane, nil] piano di destinazione; nil = lo stdplane
    # @return [Array(Integer, Integer)] [y, x] relativi a dst
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ClosedError] se uno dei piani è chiuso
    def translate(y, x, dst: nil)
      Guard.run do
        target = dst.nil? ? ::FFI::Pointer::NULL : same_context_plane!(dst, 'dst')
        yp = ::FFI::MemoryPointer.new(:int)
        xp = ::FFI::MemoryPointer.new(:int)
        yp.write_int(Util.int!(y, 'y'))
        xp.write_int(Util.int!(x, 'x'))
        FFI.ncplane_translate(to_ptr, target, yp, xp)
        [yp.read_int, xp.read_int]
      end
    end

    # Converte coordinate assolute in coordinate relative al piano
    # (+ncplane_translate_abs+).
    #
    # @param y [Integer] riga assoluta
    # @param x [Integer] colonna assoluta
    # @return [Array(Integer, Integer, Boolean)] [y, x, true se il punto è nel piano]
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ClosedError] se il piano è chiuso
    def translate_abs(y, x)
      Guard.run do
        yp = ::FFI::MemoryPointer.new(:int)
        xp = ::FFI::MemoryPointer.new(:int)
        yp.write_int(Util.int!(y, 'y'))
        xp.write_int(Util.int!(x, 'x'))
        inside = FFI.ncplane_translate_abs(to_ptr, yp, xp)
        [yp.read_int, xp.read_int, inside]
      end
    end

    # Colonna a cui deve iniziare un oggetto largo cols per essere allineato
    # nel piano (+ncplane_halign+).
    #
    # @param align [Symbol] :left, :center, :right
    # @param cols [Integer] larghezza dell'oggetto, >= 0
    # @return [Integer]
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ClosedError] se il piano è chiuso
    def halign(align, cols)
      Guard.run do
        Util.integer!(cols, 'cols', Util::NONNEG_INT)
        FFI.ncplane_halign(to_ptr, Util.placement_align_value(align), cols)
      end
    end

    # Riga a cui deve iniziare un oggetto alto rows per essere allineato nel
    # piano (+ncplane_valign+).
    #
    # @param align [Symbol] :top, :center, :bottom
    # @param rows [Integer] altezza dell'oggetto, >= 0
    # @return [Integer]
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ClosedError] se il piano è chiuso
    def valign(align, rows)
      Guard.run do
        Util.integer!(rows, 'rows', Util::NONNEG_INT)
        FFI.ncplane_valign(to_ptr, Util.placement_align_value(align), rows)
      end
    end

    # --- posizione e z-order ---

    # Sposta il piano rispetto al genitore (+ncplane_move_yx+).
    #
    # @param y [Integer] riga
    # @param x [Integer] colonna
    # @return [self]
    # @raise [PlaneError] se lo spostamento fallisce (per esempio sullo stdplane)
    # @raise [TypeError, ArgumentError] se un argomento non è un int del C
    # @raise [ClosedError] se il piano è chiuso
    def move(y, x)
      Guard.run do
        Util.check!(FFI.ncplane_move_yx(to_ptr, Util.int!(y, 'y'), Util.int!(x, 'x')), PlaneError, 'ncplane_move_yx')
        self
      end
    end

    # Sposta il piano rispetto alla posizione attuale (+ncplane_move_rel+).
    #
    # @param dy [Integer] righe (negativo = in alto)
    # @param dx [Integer] colonne (negativo = a sinistra)
    # @return [self]
    # @raise [PlaneError] se lo spostamento fallisce
    # @raise [TypeError, ArgumentError] se un argomento non è un int del C
    # @raise [ClosedError] se il piano è chiuso
    def move_rel(dy, dx)
      Guard.run do
        Util.check!(FFI.ncplane_move_rel(to_ptr, Util.int!(dy, 'dy'), Util.int!(dx, 'dx')), PlaneError, 'ncplane_move_rel')
        self
      end
    end

    # Porta il piano in cima alla pila (+ncplane_move_top+).
    # @return [self]
    # @raise [ClosedError] se il piano è chiuso
    def move_top
      Guard.run do
        FFI.ncplane_move_top(to_ptr)
        self
      end
    end

    # Porta il piano in fondo alla pila (+ncplane_move_bottom+).
    # @return [self]
    # @raise [ClosedError] se il piano è chiuso
    def move_bottom
      Guard.run do
        FFI.ncplane_move_bottom(to_ptr)
        self
      end
    end

    # Porta il piano e i suoi figli in cima alla pila (+ncplane_move_family_top+).
    # @return [self]
    # @raise [ClosedError] se il piano è chiuso
    def move_family_top
      Guard.run do
        FFI.ncplane_move_family_top(to_ptr)
        self
      end
    end

    # Porta il piano e i suoi figli in fondo alla pila (+ncplane_move_family_bottom+).
    # @return [self]
    # @raise [ClosedError] se il piano è chiuso
    def move_family_bottom
      Guard.run do
        FFI.ncplane_move_family_bottom(to_ptr)
        self
      end
    end

    # Mette il piano subito sopra other (+ncplane_move_above+).
    #
    # @param other [Plane, nil] piano della stessa pila; nil = in fondo alla pila
    # @return [self]
    # @raise [PlaneError] se other è il piano stesso o è in un'altra pila
    # @raise [TypeError] se other non è un Plane
    # @raise [ClosedError] se uno dei piani è chiuso
    def move_above(other)
      Guard.run do
        target = other.nil? ? ::FFI::Pointer::NULL : same_context_plane!(other, 'other')
        Util.check!(FFI.ncplane_move_above(to_ptr, target), PlaneError, 'ncplane_move_above')
        self
      end
    end

    # Mette il piano subito sotto other (+ncplane_move_below+).
    #
    # @param other [Plane, nil] piano della stessa pila; nil = in cima alla pila
    # @return [self]
    # @raise [PlaneError] se other è il piano stesso o è in un'altra pila
    # @raise [TypeError] se other non è un Plane
    # @raise [ClosedError] se uno dei piani è chiuso
    def move_below(other)
      Guard.run do
        target = other.nil? ? ::FFI::Pointer::NULL : same_context_plane!(other, 'other')
        Util.check!(FFI.ncplane_move_below(to_ptr, target), PlaneError, 'ncplane_move_below')
        self
      end
    end

    # Come {#move_above}, con i figli del piano (+ncplane_move_family_above+).
    #
    # @param other [Plane, nil] piano della stessa pila; nil = in fondo alla pila
    # @return [self]
    # @raise [PlaneError] se lo spostamento fallisce
    # @raise [TypeError] se other non è un Plane
    # @raise [ClosedError] se uno dei piani è chiuso
    def move_family_above(other)
      Guard.run do
        target = other.nil? ? ::FFI::Pointer::NULL : same_context_plane!(other, 'other')
        Util.check!(FFI.ncplane_move_family_above(to_ptr, target), PlaneError, 'ncplane_move_family_above')
        self
      end
    end

    # Come {#move_below}, con i figli del piano (+ncplane_move_family_below+).
    #
    # @param other [Plane, nil] piano della stessa pila; nil = in cima alla pila
    # @return [self]
    # @raise [PlaneError] se lo spostamento fallisce
    # @raise [TypeError] se other non è un Plane
    # @raise [ClosedError] se uno dei piani è chiuso
    def move_family_below(other)
      Guard.run do
        target = other.nil? ? ::FFI::Pointer::NULL : same_context_plane!(other, 'other')
        Util.check!(FFI.ncplane_move_family_below(to_ptr, target), PlaneError, 'ncplane_move_family_below')
        self
      end
    end

    # @return [Plane, nil] piano subito sotto nello z-order (+ncplane_below+)
    # @raise [ClosedError] se il piano è chiuso
    def below = Guard.run { @context.plane_for(FFI.ncplane_below(to_ptr)) }

    # @return [Plane, nil] piano subito sopra nello z-order (+ncplane_above+)
    # @raise [ClosedError] se il piano è chiuso
    def above = Guard.run { @context.plane_for(FFI.ncplane_above(to_ptr)) }

    # --- scrolling ---

    # Abilita o disabilita lo scrolling (+ncplane_set_scrolling+).
    #
    # @param enabled [Boolean]
    # @raise [TypeError] se enabled non è true o false
    # @raise [ClosedError] se il piano è chiuso
    def scrolling=(enabled)
      Guard.run do
        FFI.ncplane_set_scrolling(to_ptr, Util.c_bool(enabled, 'enabled'))
      end
    end

    # @return [Boolean] true se il piano scorre (+ncplane_scrolling_p+)
    # @raise [ClosedError] se il piano è chiuso
    def scrolling? = Guard.run { FFI.ncplane_scrolling_p(to_ptr) }

    # Abilita o disabilita la crescita automatica (+ncplane_set_autogrow+):
    # l'output oltre il bordo fa crescere il piano (in basso se il piano
    # scorre, a destra altrimenti) invece di fallire o scorrere.
    #
    # @param enabled [Boolean]
    # @raise [PlaneError] sullo stdplane (il C ignora la richiesta)
    # @raise [TypeError] se enabled non è true o false
    # @raise [ClosedError] se il piano è chiuso
    def autogrow=(enabled)
      Guard.run do
        ptr = to_ptr
        value = Util.c_bool(enabled, 'enabled')
        raise PlaneError, "l'autogrow dello stdplane non si può cambiare" if stdplane?

        FFI.ncplane_set_autogrow(ptr, value)
      end
    end

    # @return [Boolean] true se il piano cresce da solo (+ncplane_autogrow_p+)
    # @raise [ClosedError] se il piano è chiuso
    def autogrow? = Guard.run { FFI.ncplane_autogrow_p(to_ptr) }

    # Fa scorrere il contenuto del piano di lines righe verso l'alto
    # (+ncplane_scrollup+): le righe nuove in basso sono vuote, i figli non
    # fissi che intersecano il piano salgono con il contenuto. Con l'autogrow
    # il piano cresce invece di scorrere. Il cursore finisce all'inizio
    # dell'ultima riga. Sullo stdplane notcurses esegue anche un render.
    #
    # Il C di 3.0.17 tratta ogni riga come un "a capo" dal cursore (con il
    # cursore sopra l'ultima riga sposta solo il cursore): il wrapper porta
    # prima il cursore sull'ultima riga.
    #
    # @param lines [Integer] righe, >= 1
    # @return [self]
    # @raise [PlaneError] se il piano non ha lo scrolling attivo
    # @raise [Exception] l'eccezione di un callback Ruby di resize (render dello
    #   stdplane, crescita per autogrow)
    # @raise [TypeError, ArgumentError] se lines non è un intero >= 1
    # @raise [ClosedError] se il piano è chiuso
    def scrollup(lines: 1)
      Guard.run do
        ptr = to_ptr
        Util.integer!(lines, 'lines', 1..Util::INT32.max)
        raise PlaneError, 'scrollup: il piano non ha lo scrolling attivo' unless scrolling?

        FFI.ncplane_cursor_move_yx(ptr, dim_y - 1, 0)
        rc = FFI.ncplane_scrollup(ptr, lines)
        @context.raise_callback_errors!
        Util.check!(rc, PlaneError, 'ncplane_scrollup')
        self
      end
    end

    # Fa scorrere il piano quanto basta perché il bordo inferiore di child non
    # superi il suo (+ncplane_scrollup_child+). Il cursore finisce all'inizio
    # dell'ultima riga.
    #
    # @param child [Plane] discendente non fisso di questo piano
    # @return [self]
    # @raise [PlaneError] se child non è un discendente, se è fisso o se il
    #   piano non ha lo scrolling attivo
    # @raise [TypeError] se child non è un Plane
    # @raise [ClosedError] se uno dei piani è chiuso
    def scrollup_child(child)
      Guard.run do
        rc = FFI.ncplane_scrollup_child(to_ptr, same_context_plane!(child, 'child'))
        @context.raise_callback_errors!
        Util.check!(rc, PlaneError, 'ncplane_scrollup_child')
        self
      end
    end

    # Ruota il piano di 90° in senso orario (+ncplane_rotate_cw+): le righe
    # diventano colonne/2 e le colonne righe*2, l'origine non cambia. Servono
    # un numero pari di colonne e celle con soli "", " ", "▀", "▄" o "█"; la
    # rotazione perde informazione (cw e poi ccw non restituisce l'originale).
    # La cella base resta com'era (vedi {#resize_region}, resize che non
    # conserva niente).
    #
    # @return [self]
    # @raise [PlaneError] se la rotazione non è possibile (anche sullo
    #   stdplane) o se fallisce un callback nativo di un figlio (il piano resta
    #   ridimensionato e vuoto)
    # @raise [ClosedError] se il piano è chiuso
    def rotate_cw
      Guard.run do
        rc = keeping_base_cell { FFI.ncplane_rotate_cw(to_ptr) }
        @context.raise_callback_errors!
        Util.check!(rc, PlaneError, 'ncplane_rotate_cw')
        self
      end
    end

    # Ruota il piano di 90° in senso antiorario (+ncplane_rotate_ccw+), con le
    # stesse regole di {#rotate_cw}.
    #
    # @return [self]
    # @raise [PlaneError] se la rotazione non è possibile
    # @raise [ClosedError] se il piano è chiuso
    def rotate_ccw
      Guard.run do
        rc = keeping_base_cell { FFI.ncplane_rotate_ccw(to_ptr) }
        @context.raise_callback_errors!
        Util.check!(rc, PlaneError, 'ncplane_rotate_ccw')
        self
      end
    end

    # --- cursore ---

    # Sposta il cursore del piano (+ncplane_cursor_move_yx+). Il wrapper
    # controlla la posizione prima della chiamata: il C di 3.0.17 cambia x anche
    # quando poi rifiuta y.
    #
    # @param y [Integer, nil] riga; nil = non cambiarla
    # @param x [Integer, nil] colonna; nil = non cambiarla
    # @return [self]
    # @raise [PlaneError] se la posizione risultante è fuori dal piano
    # @raise [TypeError, ArgumentError] se un argomento non è un int del C né nil
    # @raise [ClosedError] se il piano è chiuso
    def move_cursor(y, x)
      Guard.run do
        ptr = to_ptr
        cy, cx = cursor
        y = y.nil? ? cy : Util.int!(y, 'y')
        x = x.nil? ? cx : Util.int!(x, 'x')
        cursor_target!(y, x)
        Util.check!(FFI.ncplane_cursor_move_yx(ptr, y, x), PlaneError, "ncplane_cursor_move_yx(#{y}, #{x})")
        self
      end
    end

    # Sposta il cursore rispetto alla posizione attuale
    # (+ncplane_cursor_move_rel+), con lo stesso controllo di {#move_cursor}.
    #
    # @param dy [Integer] righe
    # @param dx [Integer] colonne
    # @return [self]
    # @raise [PlaneError] se la posizione finale è fuori dal piano
    # @raise [TypeError, ArgumentError] se un argomento non è un int del C
    # @raise [ClosedError] se il piano è chiuso
    def move_cursor_rel(dy, dx)
      Guard.run do
        ptr = to_ptr
        Util.int!(dy, 'dy')
        Util.int!(dx, 'dx')
        cy, cx = cursor
        cursor_target!(cy + dy, cx + dx)
        Util.check!(FFI.ncplane_cursor_move_rel(ptr, dy, dx), PlaneError, "ncplane_cursor_move_rel(#{dy}, #{dx})")
        self
      end
    end

    # Porta il cursore in (0, 0) (+ncplane_home+).
    # @return [self]
    # @raise [ClosedError] se il piano è chiuso
    def home
      Guard.run do
        FFI.ncplane_home(to_ptr)
        self
      end
    end

    # @return [Array(Integer, Integer)] posizione del cursore [y, x] (+ncplane_cursor_yx+)
    # @raise [ClosedError] se il piano è chiuso
    def cursor = Guard.run { WriteState.new(to_ptr).cursor }
    alias cursor_yx cursor

    # @return [Integer] riga del cursore (+ncplane_cursor_y+)
    # @raise [ClosedError] se il piano è chiuso
    def cursor_y = Guard.run { FFI.ncplane_cursor_y(to_ptr) }

    # @return [Integer] colonna del cursore (+ncplane_cursor_x+)
    # @raise [ClosedError] se il piano è chiuso
    def cursor_x = Guard.run { FFI.ncplane_cursor_x(to_ptr) }

    # --- contenuto ---

    # Contenuto della cella (y, x) (+ncplane_at_yx+). Sulla metà destra di un
    # glifo largo restituisce il glifo (con stili e canali della metà
    # sinistra); su una cella vuota l'EGC e gli stili della cella base, con i
    # canali della cella. Sulla cella "\n" che notcurses 3.0.17 lascia sotto il
    # cursore dopo un a capo (putstr su un piano che scorre) restituisce l'EGC
    # "": il C la disegna come uno spazio, non come la cella base.
    #
    # Bug di 3.0.17 aggirato: con la metà destra di un glifo largo rimasta da
    # sola in colonna 0 (dopo un resize o una cancellazione parziale)
    # +ncplane_at_yx+ può non tornare più; il wrapper cerca da sé la metà
    # sinistra e, in quel caso, restituisce la cella base.
    #
    # Su un piano con un bitmap (sixel o Kitty) solleva PlaneError, come
    # {#contents}: +ncplane_at_yx+ restituisce lì la sequenza di escape dello
    # sprixel, che con Kitty il C libera dopo il disegno (+strdup(NULL)+,
    # SIGSEGV). Il wrapper riconosce il bitmap dai campi privati del piano (vedi
    # "Campi privati" nella classe): senza, la chiamata va al C.
    #
    # @param y [Integer, nil] riga; nil = riga del cursore
    # @param x [Integer, nil] colonna; nil = colonna del cursore
    # @return [Cell]
    # @raise [ArgumentError, TypeError] se le coordinate sono fuori dal piano
    #   o non sono Integer
    # @raise [PlaneError] se il cursore è oltre l'ultima colonna, se il piano
    #   ha un bitmap o se la lettura fallisce
    # @raise [ClosedError] se il piano è chiuso
    def at(y: nil, x: nil)
      Guard.run do
        ptr = to_ptr
        y, x = cell_coords!(y, x, WriteState.new(ptr))
        st = internals(ptr)
        raise PlaneError, "at(#{y}, #{x}): il piano ha un bitmap e notcurses non ne legge le celle" if st && !st[:sprite].null?

        x -= 1 while x.positive? && wide_right?(ptr, y, x)
        return base if wide_right?(ptr, y, x)

        styles = ::FFI::MemoryPointer.new(:uint16)
        channels = ::FFI::MemoryPointer.new(:uint64)
        egc = FFI.ncplane_at_yx(ptr, y, x, styles, channels)
        Util.check_ptr!(egc, PlaneError, "ncplane_at_yx(#{y}, #{x})")
        Cell.from_c(Util.take_string(egc), styles.read_uint16, channels.read_uint64)
      end
    end

    # Cella base (+ncplane_base+): il contenuto mostrato dove il piano non ha
    # scritto nulla.
    #
    # @return [Cell]
    # @raise [PlaneError] se la lettura fallisce
    # @raise [ClosedError] se il piano è chiuso
    def base
      Guard.run do
        ptr = to_ptr
        cell = FFI::NcCell.new
        begin
          Util.check!(FFI.ncplane_base(ptr, cell), PlaneError, 'ncplane_base')
          cell_content(ptr, cell)
        ensure
          FFI.nccell_release(ptr, cell)
        end
      end
    end

    # Imposta la cella base (+ncplane_set_base+).
    #
    # @param egc [String] un solo grapheme cluster ("" = nessun carattere)
    # @param styles [Integer, Symbol, Array<Symbol>] stili
    # @param channels [Channels, Integer] colori
    # @return [self]
    # @raise [PlaneError] se l'egcpool del piano (16 MiB) non ha spazio per
    #   l'EGC (il messaggio nomina l'egcpool; la base resta com'era), o se
    #   notcurses rifiuta l'EGC
    # @raise [CellError] se notcurses divide il grapheme in più caratteri (vedi
    #   {Cell}): il C terrebbe solo il primo
    # @raise [TypeError, ArgumentError] se un argomento non è valido (più di un
    #   grapheme cluster, caratteri di controllo, ...)
    # @raise [ClosedError] se il piano è chiuso
    def set_base(egc: ' ', styles: 0, channels: 0)
      Guard.run do
        ptr = to_ptr
        text = Cell.egc!(egc)
        mask = Util.styles_value(styles)
        chans = Util.channels_value(channels)
        # ncplane_set_base tiene il primo pezzo di un grapheme diviso, senza errore (ICH-217); single_egc! divide
        # anche con l'egcpool pieno
        single_egc!(ptr, text) unless text.ascii_only?
        # con il pool pieno il C ha già scritto stili e canali e rilasciato l'EGC vecchio (notcurses.h:754-756,
        # internal.h:1449, 1464)
        rehearse!(ptr, text) { |copy| FFI.ncplane_set_base(copy, text, mask, chans) }
        Util.check!(FFI.ncplane_set_base(ptr, text, mask, chans), PlaneError, 'ncplane_set_base')
        self
      end
    end

    # Testo del piano in una regione, riga dopo riga, senza separatori di riga
    # e senza le celle vuote; un glifo largo compare una volta (come
    # +ncplane_contents+). Salta anche la cella "\n" che notcurses 3.0.17
    # lascia sotto il cursore dopo un a capo (vedi {#at}).
    #
    # Bug di 3.0.17 aggirato: +ncplane_contents+ lascia nell'egcpool del piano
    # una copia di ogni EGC di più di 4 byte a ogni chiamata (il pool cresce
    # fino al limite di 16 MiB): il wrapper legge le celle una per una con
    # +ncplane_at_yx_cell+ e le rilascia. Con il pool pieno quella lettura
    # fallisce sugli EGC di più di 4 byte: il wrapper li legge con
    # +ncplane_at_yx+, che non usa il pool, come {#at}.
    #
    # @param y [Integer] prima riga, 0...righe
    # @param x [Integer] prima colonna, 0...colonne
    # @param rows [Integer, nil] righe; nil = fino al bordo
    # @param cols [Integer, nil] colonne; nil = fino al bordo
    # @return [String] testo UTF-8
    # @raise [ArgumentError, TypeError] se la regione esce dal piano
    # @raise [PlaneError] se la lettura fallisce (per esempio su un piano con
    #   un bitmap)
    # @raise [ClosedError] se il piano è chiuso
    def contents(y: 0, x: 0, rows: nil, cols: nil)
      Guard.run do
        ptr = to_ptr
        prows, pcols = dims
        Util.integer!(y, 'y', 0...prows)
        Util.integer!(x, 'x', 0...pcols)
        rows = rows.nil? ? prows - y : Util.integer!(rows, 'rows', 1..(prows - y))
        cols = cols.nil? ? pcols - x : Util.integer!(cols, 'cols', 1..(pcols - x))
        out = String.new(encoding: Encoding::BINARY)
        cell = FFI::NcCell.new
        begin
          y.upto(y + rows - 1) do |yy|
            x.upto(x + cols - 1) do |xx|
              # la cella viene riusata: ncplane_at_yx_cell rilascia prima il contenuto precedente
              len = FFI.ncplane_at_yx_cell(ptr, yy, xx, cell)
              if len.negative?
                out << unpooled_egc(ptr, yy, xx)
                next
              end

              egc = FFI.nccell_extended_gcluster(ptr, cell)
              out << egc if len.positive? && egc != "\n" # la cella che ncplane_put lascia dopo un a capo
            end
          end
        ensure
          FFI.nccell_release(ptr, cell)
        end
        out.force_encoding(Encoding::UTF_8)
      end
    end

    # Cancella tutto il piano (+ncplane_erase+): celle vuote, cursore in
    # (0, 0). Restano la cella base, lo stile e i colori del piano.
    #
    # @return [self]
    # @raise [ClosedError] se il piano è chiuso
    def erase
      Guard.run do
        FFI.ncplane_erase(to_ptr)
        self
      end
    end

    # Cancella un rettangolo di celle (+ncplane_erase_region+), dalla cella
    # (y, x) compresa verso destra e verso il basso, tagliato al bordo. Le
    # celle tornano vuote con stile e colori di default. Se la regione copre
    # solo metà di un glifo largo, anche l'altra metà diventa una cella vuota.
    #
    # @param y [Integer] riga di partenza, 0...righe
    # @param x [Integer] colonna di partenza, 0...colonne
    # @param rows [Integer] righe da cancellare, >= 1
    # @param cols [Integer] colonne da cancellare, >= 1
    # @return [self]
    # @raise [ArgumentError, TypeError] se un argomento non è valido
    # @raise [PlaneError] se la cancellazione fallisce
    # @raise [ClosedError] se il piano è chiuso
    def erase_region(y, x, rows, cols)
      Guard.run do
        ptr = to_ptr
        prows, pcols = dims
        Util.integer!(y, 'y', 0...prows)
        Util.integer!(x, 'x', 0...pcols)
        Util.integer!(rows, 'rows', 1..Util::INT32.max)
        Util.integer!(cols, 'cols', 1..Util::INT32.max)
        keep_glyphs_whole(ptr, y, x, [rows, prows - y].min, [cols, pcols - x].min) do
          Util.check!(FFI.ncplane_erase_region(ptr, y, x, rows, cols), PlaneError, 'ncplane_erase_region')
        end
        self
      end
    end

    # Fonde questo piano sopra dst (+ncplane_mergedown_simple+): dst prende il
    # risultato del render dei due piani nelle loro posizioni (alpha, cella
    # base, ...); questo piano non cambia.
    #
    # Bug di 3.0.17: +ncplane_mergedown+ ignora la regione che riceve, quindi
    # il wrapper offre solo la fusione completa; lascia anche la metà destra
    # dei glifi larghi di dst con larghezza 0, e il wrapper riscrive quei glifi
    # (il cursore di dst non cambia). Per trovarli legge ogni cella di dst: su
    # un piano grande (per esempio 50x200) la fusione costa qualche
    # millisecondo invece di una frazione. La lettura (+ncplane_at_yx_cell+)
    # copia l'EGC nell'egcpool di dst e fallisce se il pool è pieno (16 MiB;
    # solo per gli EGC di più di 4 byte): quei glifi il wrapper li riscrive
    # leggendo l'EGC con +ncplane_at_yx+, che non usa il pool, con gli stili e
    # i colori della cella. Se nemmeno questa riscrittura riesce, le due metà
    # del glifo diventano celle vuote.
    #
    # Una metà sinistra orfana di src (un glifo largo tagliato da un resize)
    # seguita da un glifo: notcurses disegnerebbe il glifo largo intero, sopra
    # il glifo dopo. Durante la fusione il wrapper la cambia in uno spazio con
    # gli stessi stili e colori (src torna com'era dopo): dst mostra lo spazio
    # e il glifo, con i colori composti come nelle altre celle. Senza i campi
    # privati il glifo largo resta intero.
    #
    # +ncplane_mergedown+ copia anche ogni EGC di più di 4 byte nell'egcpool di
    # dst senza rilasciare le copie vecchie: il pool cresceva a ogni fusione e,
    # al limite di 16 MiB, le celle di dst restavano vuote senza errore. Il
    # wrapper rilascia le copie vecchie, che legge dai campi privati di dst con
    # le condizioni di "Campi privati" nella classe (altrimenti il pool cresce
    # come prima). Durante la fusione le copie vecchie e quelle nuove stanno
    # insieme nel pool: se le nuove non entrano (EGC di dst per più di circa
    # 8 MiB), il wrapper annulla la fusione e solleva PlaneError. Questi
    # controlli raddoppiano circa il costo: su un piano 50x200 la fusione
    # passa da circa 5 a circa 11 ms, e la ricerca delle metà sinistre orfane
    # di src la porta a circa 15 ms.
    #
    # Un gestore +trap+ non deve cambiare dst né src durante merge_down (notcurses
    # non è rientrante). Il wrapper rilegge dst prima di rilasciare o
    # ripristinare, ma questo restringe le finestre, non le chiude: un trap
    # gira anche al ritorno dei metodi C. La fusione può restare a metà
    # (copie vecchie nel pool, PlaneError anche con spazio nel pool) e il
    # processo può andare in crash.
    #
    # @param dst [Plane] piano di destinazione, della stessa pila
    # @return [self]
    # @raise [PlaneError] se dst è il piano stesso o sta in un'altra pila, se
    #   la fusione fallisce (per esempio con un bitmap), o se l'egcpool di dst
    #   non ha spazio per copiare i suoi EGC (dst non cambia; se un gestore
    #   trap ha cambiato dst durante la fusione, alcune celle restano vuote)
    # @raise [TypeError] se dst non è un Plane
    # @raise [ClosedError] se uno dei piani è chiuso
    def merge_down(dst)
      Guard.run do
        ptr = to_ptr
        target = same_context_plane!(dst, 'dst')
        raise PlaneError, 'merge_down: dst è il piano stesso' if target.address == ptr.address
        raise PlaneError, "merge_down: dst è in un'altra pila" unless FFI.ncpile_top(ptr).address == FFI.ncpile_top(target).address

        # un'eccezione asincrona fra il rilascio e il ripristino lascerebbe celle con EGC già rilasciati; i gestori
        # trap girano comunque: i controlli di release_unused! e undo_merge! rileggono dst prima di toccarlo
        lost = Thread.handle_interrupt(Object => :never) do
          old = (st = internals(target)) && fb_bytes(st)
          blanked = blank_orphan_lefts!(ptr)
          begin
            Util.check!(FFI.ncplane_mergedown_simple(ptr, target), PlaneError, 'ncplane_mergedown_simple')
          ensure
            blanked.each { |cell, bytes| cell.write_bytes(bytes) }
          end
          # il C ha copiato ogni EGC nel framebuffer nuovo e ha liberato quello vecchio senza rilasciarli (ICH-482)
          st = old && internals(target)
          fresh = st && fb_bytes(st)
          if fresh && lost_egc?(fresh, st[:lenx])
            undo_merge!(target, st, old, fresh) ? :undone : :lost
          else
            release_unused!(target, pooled(old)) if fresh
            nil
          end
        end
        raise PlaneError, "merge_down: l'egcpool di dst non ha spazio per copiare i suoi EGC (dst non è cambiato)" if lost == :undone

        restore_wide_glyphs!(target)
        # glifi larghi nuovi senza le scritture: un resize del C li può tagliare a dimensioni già controllate
        @context.tracked_plane(target.address)&.cut_glyphs_cols = nil
        raise PlaneError, "merge_down: l'egcpool di dst non ha spazio per copiare i suoi EGC (celle di dst vuote)" if lost
        self
      end
    end

    # Converte in grigio i colori delle celle (+ncplane_greyscale+). I colori
    # di default e di palette diventano RGB espliciti (un default diventa
    # nero); la cella base e i colori del piano non cambiano.
    #
    # @return [self]
    # @raise [ClosedError] se il piano è chiuso
    def greyscale
      Guard.run do
        FFI.ncplane_greyscale(to_ptr)
        self
      end
    end

    # --- immagini ---

    # Converte una regione del piano in pixel RGBA (+ncplane_as_rgba+),
    # leggendo ogni cella come un glifo del blitter: ogni cella deve contenere
    # uno spazio o un blocco del blitter (un altro carattere, o una cella mai
    # scritta con la base vuota, fanno fallire la conversione). Le celle con
    # alpha non opaco danno pixel trasparenti (0). Senza argomenti converte
    # tutto il piano; le regole della regione sono quelle di {Visual.from_plane}.
    #
    # @param blitter [Symbol, Integer] blitter di lettura (non :pixel né :default;
    #   :four_by_one e :eight_by_one, solo per i plot, sollevano ArgumentError)
    # @param y [Integer, nil] riga di partenza, >= 0; nil = riga del cursore
    # @param x [Integer, nil] colonna di partenza, >= 0; nil = colonna del cursore
    # @param rows [Integer, nil] righe, >= 1; nil = fino al bordo
    # @param cols [Integer, nil] colonne, >= 1; nil = fino al bordo
    # @return [Array(String, Integer, Integer)] [pixel RGBA (BINARY, 4 byte per
    #   pixel, riga dopo riga), altezza in pixel, larghezza in pixel]
    # @raise [PlaneError] se la conversione fallisce
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ClosedError] se il piano è chiuso
    def as_rgba(blitter, y: 0, x: 0, rows: nil, cols: nil)
      Guard.run do
        ptr = to_ptr
        blit = Util.image_blitter_value(blitter)
        if [FFI::NCBLIT_PIXEL, FFI::NCBLIT_DEFAULT].include?(blit)
          raise ArgumentError, 'as_rgba: i blitter :pixel e :default non sono ammessi'
        end

        begy, begx, leny, lenx = Util.c_region(y, x, rows, cols)
        pxy = ::FFI::MemoryPointer.new(:uint)
        pxx = ::FFI::MemoryPointer.new(:uint)
        buf = FFI.ncplane_as_rgba(ptr, blit, begy, begx, leny, lenx, pxy, pxx)
        Util.check_ptr!(buf, PlaneError, 'ncplane_as_rgba')
        begin
          height = pxy.read_uint
          width = pxx.read_uint
          [buf.read_bytes(height * width * 4), height, width]
        ensure
          Util.free(buf)
        end
      end
    end

    # Disegna un codice QR dal cursore in poi (+ncplane_qrcode+), in un'area
    # di al massimo rows x cols celle.
    #
    # La build di notcurses senza qrcodegen (per esempio quella di Arch Linux)
    # ha solo uno stub che fallisce: in quel caso il metodo solleva sempre
    # PlaneError.
    #
    # Glifi larghi (ICH-488): il C disegna il codice con il blitter :half, che
    # scrive ogni cella da sola, e su una metà di un glifo largo lascerebbe
    # l'altra metà orfana. Il wrapper svuota l'altra metà, che diventa una
    # cella vuota, come {Visual.blit_rgba}. Il controllo legge i glifi larghi
    # nelle rows x cols celle da (0, 0): il costo è proporzionale a quell'area.
    #
    # Bug di 3.0.17 non aggirato: con il cursore fuori da (0, 0) il C scrive
    # fuori dal proprio buffer di pixel (fill.c:612-616) e corrompe la heap.
    # Muovi il cursore in (0, 0) prima della chiamata, e per un codice in
    # un'altra posizione usa un piano figlio.
    #
    # @param data [String] byte da codificare, non vuoto
    # @param rows [Integer] righe disponibili, >= 1
    # @param cols [Integer] colonne disponibili, >= 1
    # @return [Array(Integer, Integer, Integer)] [versione del QR, righe e
    #   colonne usate]
    # @raise [PlaneError] se il codice non entra nell'area, o senza qrcodegen
    # @raise [TypeError, ArgumentError] se un argomento non è valido
    # @raise [ClosedError] se il piano è chiuso
    def qrcode(data, rows:, cols:)
      Guard.run do
        ptr = to_ptr
        raise TypeError, "data deve essere String, non #{data.class}" unless data.is_a?(String)
        raise ArgumentError, 'data non può essere vuoto' if data.empty?

        ymax = ::FFI::MemoryPointer.new(:uint)
        xmax = ::FFI::MemoryPointer.new(:uint)
        ymax.write_uint(Util.integer!(rows, 'rows', 1..Util::INT32.max))
        xmax.write_uint(Util.integer!(cols, 'cols', 1..Util::INT32.max))
        bytes = data.b
        buf = ::FFI::MemoryPointer.new(:uchar, bytes.bytesize)
        buf.put_bytes(0, bytes)
        # il C disegna il codice da (0, 0) (fill.c:625-629), in al massimo rows x cols celle; il codice può
        # essere più piccolo: il controllo copre anche l'interno
        version = keeping_glyphs_whole(0, 0, rows, cols, all: true) do
          FFI.ncplane_qrcode(ptr, ymax, xmax, buf, bytes.bytesize)
        end
        Util.check!(version, PlaneError, 'ncplane_qrcode (notcurses compilato senza qrcodegen?)')
        [version, ymax.read_uint, xmax.read_uint]
      end
    end

    # --- testo ---

    # Scrive un testo dal cursore, o da (y, x), con lo stile e i colori del
    # piano (+ncplane_putstr_yx+, +ncplane_putstr+, +ncplane_putstr_stained+).
    # Il cursore avanza dopo il testo. Sui piani che scorrono il testo va a capo
    # e "\n" passa alla riga successiva (sullo stdplane ogni scroll esegue anche
    # un render); con l'autogrow il piano cresce.
    #
    # Il wrapper controlla il testo prima della chiamata, così il piano non
    # resta scritto a metà:
    # - su un piano che non scorre e non cresce il testo deve entrare nella
    #   riga, dalla colonna di partenza;
    # - con x: o align: il primo carattere deve entrare nella riga (su un piano
    #   che scorre il C di 3.0.17 scriverebbe fuori dalla riga);
    # - TAB rifiutati: con un TAB nell'ultima colonna il C scrive fuori dalla
    #   riga (espandili prima, per esempio con String#gsub);
    # - caratteri rifiutati se notcurses li scrive come un EGC di larghezza zero
    #   (U+200B, un segno combinante isolato, il keycap U+20E3 di "1️⃣", le
    #   vocali hangul separate): il C li mette in una cella propria e, con il
    #   cursore a fine riga, fuori dalla riga; U+2028 e U+2029 (il C li tronca a
    #   un byte);
    # - un indicatore regionale da solo: notcurses lo conta largo 1 colonna,
    #   Ghostty 1.4 e Kitty 0.51 lo disegnano largo 2, e il testo dopo si
    #   sposta sullo schermo. Una bandiera (due indicatori) si scrive in due
    #   celle larghe 1: Ghostty e Kitty la disegnano larga 2, un terminale che
    #   non raggruppa i grapheme (libghostty-vt senza il modo 2027) larga 4.
    #
    # Bug di 3.0.17 aggirati:
    # - dopo uno ZWJ (U+200D) il C unisce tutto il resto del testo allo stesso
    #   carattere; il wrapper spezza il testo dopo ogni grapheme cluster con
    #   uno ZWJ;
    # - dopo una riga piena il cursore resta oltre l'ultima colonna, e lì il C
    #   esegue "\n" con due a capo (notcurses.c:1888 e 1903), lasciando una
    #   riga vuota; il wrapper porta prima il cursore sull'ultima colonna, così
    #   "\n" passa sempre alla riga successiva.
    #
    # @param text [String] testo UTF-8 senza caratteri di controllo, tranne
    #   "\n" sui piani che scorrono
    # @param y [Integer, nil] riga; nil = riga del cursore
    # @param x [Integer, nil] colonna; nil = colonna del cursore
    # @param align [Symbol, nil] :left, :center o :right: allinea il testo
    #   nella riga, al posto di x: (senza "\n")
    # @param stained [Boolean] true = ogni carattere prende stile e colori
    #   della cella che sostituisce (senza "\n"; il testo deve entrare nella
    #   riga)
    # @return [Integer] colonne scritte ("\n" vale 1)
    # @raise [ArgumentError, TypeError] se un argomento non è valido (caratteri
    #   rifiutati, coordinate fuori dal piano, x: insieme ad align:)
    # @raise [PlaneError] se il testo non entra nel piano, se l'egcpool del
    #   piano (16 MiB) non ha spazio per un EGC di più di 4 byte del testo (il
    #   C scrive gli EGC prima e si ferma lì; il glifo dove si ferma e il
    #   cursore restano com'erano; il messaggio nomina l'egcpool e l'EGC), o
    #   se notcurses rifiuta la scrittura (per esempio su un piano con un
    #   bitmap)
    # @raise [RenderError] su uno stdplane che scorre, se fallisce il render
    #   che prima della scrittura lo porta alle dimensioni del terminale
    # @raise [Exception] l'eccezione di un callback Ruby di resize (crescita
    #   per autogrow, render dello stdplane che scorre)
    # @raise [ClosedError] se il piano è chiuso
    def putstr(text, y: nil, x: nil, align: nil, stained: false)
      Guard.run do
        ptr = to_ptr
        str, graphemes, columns = output_text!(ptr, text, 'text')
        raise ArgumentError, 'putstr: usa x: oppure align:, non entrambi' if x && align

        Util.bool!(stained, 'stained')
        return 0 if str.empty?

        write_text!(ptr, str, graphemes, columns, WriteState.new(ptr), y: y, x: x, align: align, stained: stained)
      end
    end

    # Scrive un testo formattato con Kernel#format (il printf del C non si
    # chiama da Ruby: niente formati C né va_list). Stessi controlli di
    # {#putstr}.
    #
    # @param fmt [String] formato di Kernel#format
    # @param args [Array] argomenti del formato
    # @param y [Integer, nil] riga; nil = riga del cursore
    # @param x [Integer, nil] colonna; nil = colonna del cursore
    # @param align [Symbol, nil] :left, :center o :right, al posto di x:
    # @param stained [Boolean] come in {#putstr}
    # @return [Integer] colonne scritte
    # @raise [ArgumentError, TypeError] se il formato o un argomento non sono
    #   validi
    # @raise [PlaneError] come {#putstr}
    # @raise [ClosedError] se il piano è chiuso
    def printf(fmt, *args, y: nil, x: nil, align: nil, stained: false)
      putstr(Kernel.format(fmt, *args), y: y, x: x, align: align, stained: stained)
    end

    # Scrive un solo carattere (grapheme cluster) dal cursore, o da (y, x),
    # con lo stile e i colori del piano (+ncplane_putegc_yx+,
    # +ncplane_putegc_stained+). Stessi controlli di {#putstr}; per andare a
    # capo usa putstr("\n").
    #
    # @param egc [String, Integer] un grapheme cluster, o un codepoint Unicode
    # @param y [Integer, nil] riga; nil = riga del cursore
    # @param x [Integer, nil] colonna; nil = colonna del cursore
    # @param stained [Boolean] true = prende stile e colori della cella che
    #   sostituisce
    # @return [Integer] colonne scritte
    # @raise [ArgumentError, TypeError, RangeError] se egc non è un solo
    #   grapheme cluster stampabile, o se le coordinate sono fuori dal piano
    # @raise [CellError] se notcurses divide il grapheme in più caratteri (per
    #   esempio una bandiera)
    # @raise [PlaneError] se il carattere non entra nel piano, se l'egcpool
    #   del piano (16 MiB) non ha spazio per l'EGC (il piano non cambia), o se
    #   notcurses rifiuta la scrittura
    # @raise [Exception] l'eccezione di un callback Ruby di resize
    # @raise [ClosedError] se il piano è chiuso
    def putegc(egc, y: nil, x: nil, stained: false)
      Guard.run do
        ptr = to_ptr
        text, cols = egc_to_write!(ptr, egc, stained)
        state = WriteState.new(ptr)
        ty, tx = text_target!(text, cols, state, y: y, x: x, align: nil, stained: stained) { cols }
        rc = with_glyph_kept(ptr, text, ty, tx, state, width: cols, single: true) do
          stained ? FFI.ncplane_putegc_stained(ptr, text, nil) : FFI.ncplane_putegc_yx(ptr, ty, tx, text, nil)
        end
        @context.raise_callback_errors!
        raise PlaneError, "ncplane_putegc_yx(#{Util.egc_label(text)}) fallita (#{rc})#{egcpool_hint(ptr, text)}" if rc.negative?

        rc
      end
    end

    # Scrive una cella dal cursore, o da (y, x), con lo stile e i colori della
    # cella (+ncplane_putc_yx+). Una cella vuota ("") lascia una cella
    # trasparente. Stessi controlli di posizione di {#putstr}.
    #
    # @param cell [Cell]
    # @param y [Integer, nil] riga; nil = riga del cursore
    # @param x [Integer, nil] colonna; nil = colonna del cursore
    # @return [Integer] colonne occupate (1 per una cella vuota)
    # @raise [TypeError] se cell non è una Cell
    # @raise [ArgumentError] se le coordinate sono fuori dal piano
    # @raise [CellError] se notcurses non accetta l'EGC della cella
    # @raise [PlaneError] se la cella non entra nel piano, se l'egcpool del
    #   piano (16 MiB) non ha spazio per l'EGC (una scrittura con una Cell ne
    #   tiene nel pool anche una copia temporanea; il piano resta com'era, il
    #   messaggio nomina l'egcpool), o se notcurses rifiuta la scrittura
    # @raise [Exception] l'eccezione di un callback Ruby di resize
    # @raise [ClosedError] se il piano è chiuso
    def putc(cell, y: nil, x: nil)
      Guard.run do
        ptr = to_ptr
        raise TypeError, "cell deve essere Notcurses::Cell, non #{cell.class}" unless cell.is_a?(Cell)

        cols = [cell.width, 1].max
        state = WriteState.new(ptr)
        ty, tx = text_target!(cell.egc, cols, state, y: y, x: x, align: nil, stained: false) { cols }
        rc = with_nccell(ptr, cell) do |nc|
          rehearse!(ptr, cell.egc, state: state) { |copy| FFI.ncplane_putc_yx(copy, ty, tx, nc) } if cell.egc.bytesize > 4
          FFI.ncplane_putc_yx(ptr, ty, tx, nc)
        end
        @context.raise_callback_errors!
        Util.check!(rc, PlaneError, "ncplane_putc_yx(#{Util.egc_label(cell.egc)})")
      end
    end

    # Scrive un testo a capo sulle parole, una riga del piano dopo l'altra,
    # dalla riga y. Ogni riga è allineata in tutta la larghezza del piano;
    # "\n" chiude un paragrafo; gli spazi tra le parole si riducono a uno; una
    # parola più larga del piano va a capo dove serve. Sui piani che scorrono
    # il testo fa scorrere il piano (con l'autogrow il piano cresce); sugli
    # altri deve entrare nelle righe rimaste.
    #
    # Scritto in Ruby sopra {#putstr}: +ncplane_puttext+ di 3.0.17 può andare
    # in ciclo infinito (parole con caratteri larghi su piani che scorrono),
    # restituisce errore anche dopo una scrittura completa, allinea a destra
    # lasciando vuota l'ultima colonna e parte dalla colonna del cursore.
    #
    # @param text [String] testo, con le regole di {#putstr} ("\n" ammesso
    #   anche sui piani che non scorrono)
    # @param y [Integer, nil] prima riga; nil = riga del cursore
    # @param align [Symbol] :left, :center o :right
    # @return [Integer] colonne scritte
    # @raise [ArgumentError, TypeError] se un argomento non è valido
    # @raise [PlaneError] se il testo non entra nel piano (prima di scrivere),
    #   o se l'egcpool del piano (16 MiB) non ha spazio per un EGC di più di 4
    #   byte del testo (le righe e gli EGC prima restano scritti, il glifo
    #   dove notcurses si ferma resta com'era; il messaggio nomina l'egcpool)
    # @raise [Exception] l'eccezione di un callback Ruby di resize
    # @raise [ClosedError] se il piano è chiuso
    def puttext(text, y: nil, align: :left)
      Guard.run do
        ptr = to_ptr
        str, graphemes, columns = output_text!(ptr, text, 'text')
        raise ArgumentError, "align = #{align.inspect} non valido: usa :left, :center o :right" unless TEXT_ALIGNS.include?(align)

        state = WriteState.new(ptr)
        rows, cols = state.dims
        row = y.nil? ? state.cursor[0] : Util.integer!(y, 'y', 0...rows)
        lines = wrap_lines(str, cols)
        unless row + lines.size <= rows || state.scrolling?
          raise PlaneError, "puttext: il testo occupa #{lines.size} righe, dalla riga #{row} ne restano #{rows - row}"
        end

        written = 0
        lines.each do |line|
          if row >= state.rows
            scrollup(lines: 1)
            state.forget!
            row = state.rows - 1
          end
          unless line.empty?
            # le righe sono pezzi del testo già controllato: una riga che è tutto il testo ne riusa i grapheme
            line_graphemes = graphemes if line == str
            written += write_text!(ptr, line, line_graphemes, columns, state, y: row, x: nil, align: align, stained: false)
            state.fixed? ? state.forget_cursor! : state.forget!
          end
          row += 1
        end
        written
      end
    end

    # Controlla un testo con le regole di {#putstr}, senza scriverlo.
    # Notcurses::UI lo usa per rifiutare il testo di un componente alla
    # creazione: le regole che dipendono da notcurses (per esempio il keycap
    # "1️⃣", che notcurses 3.0.17 divide con un pezzo largo 0) Ruby non le vede
    # da solo (ICH-232).
    # @api private
    # @param text [String] testo
    # @param name [String] nome usato nel messaggio d'errore
    # @return [String] il testo, UTF-8
    # @raise [ArgumentError, TypeError] se {#putstr} rifiuterebbe il testo
    #   (caratteri rifiutati); lo spazio nell'egcpool non è controllato
    # @raise [ClosedError] se il piano è chiuso
    def check_text!(text, name) = Guard.run { output_text!(to_ptr, text, name).first }

    # --- stile e colori dell'output ---

    # @return [Array<Symbol>] stili delle scritture successive (+ncplane_styles+)
    # @raise [ClosedError] se il piano è chiuso
    def styles = Guard.run { Util.styles_symbols(FFI.ncplane_styles(to_ptr)) }

    # Imposta gli stili delle scritture successive (+ncplane_set_styles+). Il
    # terminale può non supportarli tutti (vedi {Context#supported_styles}).
    #
    # @param styles [Integer, Symbol, Array<Symbol>]
    # @raise [TypeError, ArgumentError] se uno stile non è valido
    # @raise [ClosedError] se il piano è chiuso
    def styles=(styles)
      Guard.run do
        FFI.ncplane_set_styles(to_ptr, Util.styles_value(styles))
      end
    end

    # Accende alcuni stili, lasciando gli altri come sono (+ncplane_on_styles+).
    #
    # @param styles [Array<Integer, Symbol, Array<Symbol>>]
    # @return [self]
    # @raise [TypeError, ArgumentError] se uno stile non è valido
    # @raise [ClosedError] se il piano è chiuso
    def on_styles(*styles)
      Guard.run do
        FFI.ncplane_on_styles(to_ptr, Util.styles_mask(styles))
        self
      end
    end

    # Spegne alcuni stili (+ncplane_off_styles+).
    #
    # @param styles [Array<Integer, Symbol, Array<Symbol>>]
    # @return [self]
    # @raise [TypeError, ArgumentError] se uno stile non è valido
    # @raise [ClosedError] se il piano è chiuso
    def off_styles(*styles)
      Guard.run do
        FFI.ncplane_off_styles(to_ptr, Util.styles_mask(styles))
        self
      end
    end

    # @return [Channels] colori delle scritture successive (+ncplane_channels+)
    # @raise [ClosedError] se il piano è chiuso
    def channels = Guard.run { Channels.new(value: FFI.ncplane_channels(to_ptr)) }

    # Imposta i colori delle scritture successive (+ncplane_set_channels+).
    #
    # @param channels [Channels, Integer]
    # @raise [ArgumentError] se lo sfondo ha alpha :highcontrast (non ammesso
    #   da notcurses)
    # @raise [TypeError] se channels non è Channels o Integer
    # @raise [ClosedError] se il piano è chiuso
    def channels=(channels)
      Guard.run do
        FFI.ncplane_set_channels(to_ptr, Util.plane_channels_value(channels))
      end
    end

    # @return [Channel] colore di primo piano (+ncplane_fchannel+)
    # @raise [ClosedError] se il piano è chiuso
    def fchannel = Guard.run { Channel.new(value: FFI.ncplane_fchannel(to_ptr)) }

    # @return [Channel] colore di sfondo (+ncplane_bchannel+)
    # @raise [ClosedError] se il piano è chiuso
    def bchannel = Guard.run { Channel.new(value: FFI.ncplane_bchannel(to_ptr)) }

    # Imposta il colore di primo piano (+ncplane_set_fchannel+).
    # @param channel [Channel, Integer]
    # @raise [TypeError, ArgumentError] se channel non è valido
    # @raise [ClosedError] se il piano è chiuso
    def fchannel=(channel)
      Guard.run do
        FFI.ncplane_set_fchannel(to_ptr, Util.channel_value(channel))
      end
    end

    # Imposta il colore di sfondo (+ncplane_set_bchannel+).
    # @param channel [Channel, Integer]
    # @raise [ArgumentError] se channel ha alpha :highcontrast
    # @raise [TypeError] se channel non è Channel o Integer
    # @raise [ClosedError] se il piano è chiuso
    def bchannel=(channel)
      Guard.run do
        value = Util.channel_value(channel)
        raise ArgumentError, "l'alpha :highcontrast non è ammessa per lo sfondo" if Channel.new(value: value).alpha == :highcontrast

        FFI.ncplane_set_bchannel(to_ptr, value)
      end
    end

    # Componenti RGB del primo piano (+ncplane_fg_rgb8+). Hanno senso solo con
    # un colore RGB: con un colore di palette il blu è l'indice, con il
    # default restano i vecchi bit RGB.
    # @return [Array(Integer, Integer, Integer)] [r, g, b]
    # @raise [ClosedError] se il piano è chiuso
    def fg_rgb = Guard.run { rgb8_of { |r, g, b| FFI.ncplane_fg_rgb8(to_ptr, r, g, b) } }

    # Componenti RGB dello sfondo (+ncplane_bg_rgb8+), come {#fg_rgb}.
    # @return [Array(Integer, Integer, Integer)] [r, g, b]
    # @raise [ClosedError] se il piano è chiuso
    def bg_rgb = Guard.run { rgb8_of { |r, g, b| FFI.ncplane_bg_rgb8(to_ptr, r, g, b) } }

    # Colore RGB del primo piano come 0xRRGGBB (+ncplane_fg_rgb+), con i
    # limiti di {#fg_rgb}.
    # @return [Integer]
    # @raise [ClosedError] se il piano è chiuso
    def fg_rgb24 = Guard.run { FFI.ncplane_fg_rgb(to_ptr) }

    # Colore RGB dello sfondo come 0xRRGGBB (+ncplane_bg_rgb+), con i limiti
    # di {#fg_rgb}.
    # @return [Integer]
    # @raise [ClosedError] se il piano è chiuso
    def bg_rgb24 = Guard.run { FFI.ncplane_bg_rgb(to_ptr) }

    # @return [Symbol] alpha del primo piano (+ncplane_fg_alpha+): :opaque,
    #   :blend, :transparent o :highcontrast
    # @raise [ClosedError] se il piano è chiuso
    def fg_alpha = Guard.run { Util.alpha_symbol(FFI.ncplane_fg_alpha(to_ptr)) }

    # @return [Symbol] alpha dello sfondo (+ncplane_bg_alpha+)
    # @raise [ClosedError] se il piano è chiuso
    def bg_alpha = Guard.run { Util.alpha_symbol(FFI.ncplane_bg_alpha(to_ptr)) }

    # @return [Boolean] true se il primo piano usa il colore di default del
    #   terminale (+ncplane_fg_default_p+)
    # @raise [ClosedError] se il piano è chiuso
    def fg_default? = Guard.run { FFI.ncplane_fg_default_p(to_ptr) }

    # @return [Boolean] true se lo sfondo usa il colore di default del
    #   terminale (+ncplane_bg_default_p+)
    # @raise [ClosedError] se il piano è chiuso
    def bg_default? = Guard.run { FFI.ncplane_bg_default_p(to_ptr) }

    # Primo piano RGB (+ncplane_set_fg_rgb8+). L'alpha non cambia.
    #
    # @param r [Integer] rosso, 0..255
    # @param g [Integer] verde, 0..255
    # @param b [Integer] blu, 0..255
    # @return [self]
    # @raise [TypeError, ArgumentError] se un componente non è un Integer in 0..255
    # @raise [ClosedError] se il piano è chiuso
    def set_fg_rgb(r, g, b)
      Guard.run do
        rc = FFI.ncplane_set_fg_rgb8(to_ptr, Util.uint8!(r, 'r'), Util.uint8!(g, 'g'), Util.uint8!(b, 'b'))
        Util.check!(rc, PlaneError, 'ncplane_set_fg_rgb8')
        self
      end
    end

    # Sfondo RGB (+ncplane_set_bg_rgb8+). L'alpha non cambia.
    #
    # @param r [Integer] rosso, 0..255
    # @param g [Integer] verde, 0..255
    # @param b [Integer] blu, 0..255
    # @return [self]
    # @raise [TypeError, ArgumentError] se un componente non è un Integer in 0..255
    # @raise [ClosedError] se il piano è chiuso
    def set_bg_rgb(r, g, b)
      Guard.run do
        rc = FFI.ncplane_set_bg_rgb8(to_ptr, Util.uint8!(r, 'r'), Util.uint8!(g, 'g'), Util.uint8!(b, 'b'))
        Util.check!(rc, PlaneError, 'ncplane_set_bg_rgb8')
        self
      end
    end

    # Primo piano RGB con le componenti portate in 0..255
    # (+ncplane_set_fg_rgb8_clipped+): -5 diventa 0, 300 diventa 255.
    #
    # @param r [Integer] rosso, int del C
    # @param g [Integer] verde, int del C
    # @param b [Integer] blu, int del C
    # @return [self]
    # @raise [TypeError, ArgumentError] se un componente non è un int del C
    # @raise [ClosedError] se il piano è chiuso
    def set_fg_rgb_clipped(r, g, b)
      Guard.run do
        FFI.ncplane_set_fg_rgb8_clipped(to_ptr, Util.int!(r, 'r'), Util.int!(g, 'g'), Util.int!(b, 'b'))
        self
      end
    end

    # Sfondo RGB con le componenti portate in 0..255
    # (+ncplane_set_bg_rgb8_clipped+), come {#set_fg_rgb_clipped}.
    #
    # @param r [Integer] rosso, int del C
    # @param g [Integer] verde, int del C
    # @param b [Integer] blu, int del C
    # @return [self]
    # @raise [TypeError, ArgumentError] se un componente non è un int del C
    # @raise [ClosedError] se il piano è chiuso
    def set_bg_rgb_clipped(r, g, b)
      Guard.run do
        FFI.ncplane_set_bg_rgb8_clipped(to_ptr, Util.int!(r, 'r'), Util.int!(g, 'g'), Util.int!(b, 'b'))
        self
      end
    end

    # Primo piano RGB da 0xRRGGBB (+ncplane_set_fg_rgb+).
    # @param rgb [Integer] 0..0xffffff
    # @return [self]
    # @raise [TypeError, ArgumentError] se rgb non è valido
    # @raise [ClosedError] se il piano è chiuso
    def set_fg_rgb24(rgb)
      Guard.run do
        Util.check!(FFI.ncplane_set_fg_rgb(to_ptr, Util.integer!(rgb, 'rgb', 0..0xff_ffff)), PlaneError, 'ncplane_set_fg_rgb')
        self
      end
    end

    # Sfondo RGB da 0xRRGGBB (+ncplane_set_bg_rgb+).
    # @param rgb [Integer] 0..0xffffff
    # @return [self]
    # @raise [TypeError, ArgumentError] se rgb non è valido
    # @raise [ClosedError] se il piano è chiuso
    def set_bg_rgb24(rgb)
      Guard.run do
        Util.check!(FFI.ncplane_set_bg_rgb(to_ptr, Util.integer!(rgb, 'rgb', 0..0xff_ffff)), PlaneError, 'ncplane_set_bg_rgb')
        self
      end
    end

    # Primo piano da un indice della palette del terminale
    # (+ncplane_set_fg_palindex+); l'alpha diventa :opaque. Linee, box e fade
    # convertono il colore di palette in RGB (0, 0, indice).
    # @param index [Integer] 0..255
    # @return [self]
    # @raise [TypeError, ArgumentError] se index non è valido
    # @raise [ClosedError] se il piano è chiuso
    def set_fg_palindex(index)
      Guard.run do
        Util.check!(FFI.ncplane_set_fg_palindex(to_ptr, Util.uint8!(index, 'index')), PlaneError, 'ncplane_set_fg_palindex')
        self
      end
    end

    # Sfondo da un indice della palette (+ncplane_set_bg_palindex+), come
    # {#set_fg_palindex}.
    # @param index [Integer] 0..255
    # @return [self]
    # @raise [TypeError, ArgumentError] se index non è valido
    # @raise [ClosedError] se il piano è chiuso
    def set_bg_palindex(index)
      Guard.run do
        Util.check!(FFI.ncplane_set_bg_palindex(to_ptr, Util.uint8!(index, 'index')), PlaneError, 'ncplane_set_bg_palindex')
        self
      end
    end

    # Alpha del primo piano (+ncplane_set_fg_alpha+). Un alpha diverso da
    # :opaque su un colore di default lo rende un colore esplicito (i vecchi
    # bit RGB o di palette, oppure il nero).
    # @param alpha [Symbol, Integer] :opaque, :blend, :transparent,
    #   :highcontrast, o una costante NCALPHA_*
    # @return [self]
    # @raise [ArgumentError] se alpha non è valido
    # @raise [ClosedError] se il piano è chiuso
    def set_fg_alpha(alpha)
      Guard.run do
        Util.check!(FFI.ncplane_set_fg_alpha(to_ptr, Util.alpha_value(alpha)), PlaneError, 'ncplane_set_fg_alpha')
        self
      end
    end

    # Alpha dello sfondo (+ncplane_set_bg_alpha+), come {#set_fg_alpha}.
    # @param alpha [Symbol, Integer] :opaque, :blend o :transparent
    # @return [self]
    # @raise [ArgumentError] se alpha non è valido o è :highcontrast
    # @raise [ClosedError] se il piano è chiuso
    def set_bg_alpha(alpha)
      Guard.run do
        value = Util.alpha_value(alpha)
        raise ArgumentError, "l'alpha :highcontrast non è ammessa per lo sfondo" if value == FFI::NCALPHA_HIGHCONTRAST

        Util.check!(FFI.ncplane_set_bg_alpha(to_ptr, value), PlaneError, 'ncplane_set_bg_alpha')
        self
      end
    end

    # Primo piano con il colore di default del terminale
    # (+ncplane_set_fg_default+). I vecchi bit RGB o di palette restano: un
    # {#set_fg_alpha} successivo diverso da :opaque li fa riapparire.
    # @return [self]
    # @raise [ClosedError] se il piano è chiuso
    def set_fg_default
      Guard.run do
        FFI.ncplane_set_fg_default(to_ptr)
        self
      end
    end

    # Sfondo con il colore di default del terminale (+ncplane_set_bg_default+),
    # come {#set_fg_default}.
    # @return [self]
    # @raise [ClosedError] se il piano è chiuso
    def set_bg_default
      Guard.run do
        FFI.ncplane_set_bg_default(to_ptr)
        self
      end
    end

    # --- linee, box, riempimenti ---

    # Linea orizzontale di len caratteri dal cursore, o da (y, x)
    # (+ncplane_hline+, +ncplane_hline_interp+). Il cursore finisce dopo la
    # linea. Sui piani che scorrono la linea va a capo.
    #
    # Con from: e to: i colori passano da from a to (to non viene mai
    # raggiunto: l'ultima cella vale from + (to - from) * (len - 1) / len).
    # Senza, la linea usa i colori della cella; in entrambi i casi un colore di
    # palette diventa RGB (0, 0, indice).
    #
    # @param cell [Cell, String] carattere largo 1 colonna; una String usa
    #   stile e colori del piano
    # @param len [Integer] caratteri, >= 1: al massimo fino al bordo destro
    #   (righe * colonne sui piani che scorrono o crescono)
    # @param y [Integer, nil] riga; nil = riga del cursore
    # @param x [Integer, nil] colonna; nil = colonna del cursore
    # @param from [Channels, Integer, nil] colori della prima cella
    # @param to [Channels, Integer, nil] colori verso cui sfumare
    # @return [self]
    # @raise [ArgumentError, TypeError] se un argomento non è valido
    # @raise [CellError] se notcurses non accetta il carattere
    # @raise [PlaneError] se il cursore è oltre il bordo, se l'egcpool del
    #   piano (16 MiB) non ha spazio per l'EGC e per le sue copie (il C ne
    #   tiene una per la linea e una per cella; il piano e il cursore restano
    #   com'erano, il messaggio nomina l'egcpool), o se notcurses rifiuta la
    #   scrittura (la linea può restare disegnata in parte)
    # @raise [RenderError] su uno stdplane che scorre, come in {#putstr}
    # @raise [Exception] l'eccezione di un callback Ruby di resize
    # @raise [ClosedError] se il piano è chiuso
    def hline(cell, len, y: nil, x: nil, from: nil, to: nil)
      Guard.run do
        ptr = to_ptr
        line = line_cell!(cell, ptr)
        state = WriteState.new(ptr)
        top, left = line_start!(y, x, state)
        rows, cols = state.dims
        max = cols - left
        # una linea più lunga della riga serve solo su un piano che scorre o cresce
        max = rows * cols if !(len.is_a?(Integer) && len.between?(1, max)) && (state.scrolling? || state.autogrow?)
        Util.integer!(len, 'len', 1..max)
        c1, c2 = interp_channels!(from, to)
        sync_scrolling_stdplane!(ptr, state) { len > cols - left }
        rc = with_nccell(ptr, line) do |nc|
          draw = lambda do |target|
            Util.check!(FFI.ncplane_cursor_move_yx(target, top, left), PlaneError, "ncplane_cursor_move_yx(#{top}, #{left})")
            c1.nil? ? FFI.ncplane_hline(target, nc, len) : FFI.ncplane_hline_interp(target, nc, len, c1, c2)
          end
          rehearse!(ptr, line.egc, state: state, &draw) if line.egc.bytesize > 4
          draw.call(ptr)
        end
        @context.raise_callback_errors!
        Util.check!(rc, PlaneError, 'ncplane_hline_interp')
        self
      end
    end

    # Linea verticale di len caratteri dal cursore, o da (y, x), verso il
    # basso (+ncplane_vline+, +ncplane_vline_interp+). Non fa mai scorrere il
    # piano. Con from: e to: i colori sfumano a passi interi
    # ((to - from) / (len + 1) per cella: con len >= 255 non c'è sfumatura).
    #
    # @param cell [Cell, String] carattere largo 1 colonna; una String usa
    #   stile e colori del piano
    # @param len [Integer] caratteri, 1..(righe sotto il cursore)
    # @param y [Integer, nil] riga; nil = riga del cursore
    # @param x [Integer, nil] colonna; nil = colonna del cursore
    # @param from [Channels, Integer, nil] colori della prima cella
    # @param to [Channels, Integer, nil] colori verso cui sfumare
    # @return [self]
    # @raise [ArgumentError, TypeError] se un argomento non è valido
    # @raise [CellError] se notcurses non accetta il carattere
    # @raise [PlaneError] se il cursore è oltre il bordo, se l'egcpool del
    #   piano (16 MiB) non ha spazio per l'EGC e per le sue copie (come in
    #   {#hline}), o se notcurses rifiuta la scrittura
    # @raise [ClosedError] se il piano è chiuso
    def vline(cell, len, y: nil, x: nil, from: nil, to: nil)
      Guard.run do
        ptr = to_ptr
        line = line_cell!(cell, ptr)
        state = WriteState.new(ptr)
        top, left = line_start!(y, x, state)
        Util.integer!(len, 'len', 1..(state.rows - top))
        c1, c2 = interp_channels!(from, to)
        rc = with_nccell(ptr, line) do |nc|
          draw = lambda do |target|
            Util.check!(FFI.ncplane_cursor_move_yx(target, top, left), PlaneError, "ncplane_cursor_move_yx(#{top}, #{left})")
            c1.nil? ? FFI.ncplane_vline(target, nc, len) : FFI.ncplane_vline_interp(target, nc, len, c1, c2)
          end
          rehearse!(ptr, line.egc, state: state, &draw) if line.egc.bytesize > 4
          draw.call(ptr)
        end
        Util.check!(rc, PlaneError, 'ncplane_vline_interp')
        self
      end
    end

    # Disegna un box di rows x cols celle con l'angolo superiore sinistro nel
    # cursore, o in (y, x) (+ncplane_box+). Il cursore finisce a destra
    # dell'angolo inferiore destro.
    #
    # @param rows [Integer] righe, >= 2, dentro il piano
    # @param cols [Integer] colonne, >= 2, dentro il piano
    # @param y [Integer, nil] riga dell'angolo; nil = riga del cursore
    # @param x [Integer, nil] colonna dell'angolo; nil = colonna del cursore
    # @param set [Symbol, String, Array<Cell>] glifi: :light, :heavy,
    #   :rounded, :double, :ascii (senza UTF-8 notcurses usa :ascii), una
    #   String di 6 caratteri (ul ur ll lr hl vl) o 6 Cell con stile e colori
    #   propri; ogni glifo deve essere largo 1 colonna
    # @param styles [Integer, Symbol, Array<Symbol>] stili (non con 6 Cell)
    # @param channels [Channels, Integer] colori (non con 6 Cell)
    # @param hide [Array<Symbol>] lati da non disegnare: :top, :right,
    #   :bottom, :left
    # @param gradient [Array<Symbol>] lati con i colori sfumati tra i due
    #   angoli (glifo e stile di hl/vl; il secondo angolo non viene raggiunto)
    # @param corners [Integer] 0..3: lati adiacenti disegnati che servono
    #   perché un angolo venga disegnato (0 = sempre, 3 = mai)
    # @return [self]
    # @raise [ArgumentError, TypeError] se un argomento non è valido (anche un
    #   box che non entra nel piano)
    # @raise [CellError] se notcurses non accetta un glifo
    # @raise [PlaneError] se l'egcpool del piano (16 MiB) non ha spazio per i
    #   glifi e per le loro copie (come in {#hline}; il piano e il cursore
    #   restano com'erano, il messaggio nomina l'egcpool), o se notcurses
    #   rifiuta il disegno (il box può restare disegnato in parte)
    # @raise [ClosedError] se il piano è chiuso
    def box(rows, cols, y: nil, x: nil, set: :light, styles: 0, channels: 0, hide: [], gradient: [], corners: 0)
      Guard.run do
        ptr = to_ptr
        top, left = line_start!(y, x)
        prows, pcols = dims
        Util.integer!(rows, 'rows', 2..[prows - top, 2].max)
        Util.integer!(cols, 'cols', 2..[pcols - left, 2].max)
        raise ArgumentError, "il box #{rows}x#{cols} in (#{top}, #{left}) esce dal piano #{prows}x#{pcols}" if top + rows > prows || left + cols > pcols

        ctl = box_ctlword(hide, gradient, corners)
        rc = with_box_cells(ptr, set, styles, channels) do |target, ul, ur, ll, lr, hl, vl|
          Util.check!(FFI.ncplane_cursor_move_yx(target, top, left), PlaneError, "ncplane_cursor_move_yx(#{top}, #{left})")
          FFI.ncplane_box(target, ul, ur, ll, lr, hl, vl, top + rows - 1, left + cols - 1, ctl)
        end
        Util.check!(rc, PlaneError, 'ncplane_box')
        self
      end
    end

    # Box lungo il bordo del piano: {#box} di tutto il piano da (0, 0).
    #
    # @param set [Symbol, String, Array<Cell>] come in {#box}
    # @param styles [Integer, Symbol, Array<Symbol>] come in {#box}
    # @param channels [Channels, Integer] come in {#box}
    # @param hide [Array<Symbol>] come in {#box}
    # @param gradient [Array<Symbol>] come in {#box}
    # @param corners [Integer] come in {#box}
    # @return [self]
    # @raise [ArgumentError] se il piano ha meno di 2 righe o 2 colonne, e come {#box}
    # @raise [ClosedError] se il piano è chiuso
    def perimeter(set: :light, styles: 0, channels: 0, hide: [], gradient: [], corners: 0)
      box(dim_y, dim_x, y: 0, x: 0, set: set, styles: styles, channels: channels, hide: hide, gradient: gradient,
                        corners: corners)
    end

    # Riempimento a macchia d'olio dalla cella (y, x) (+ncplane_polyfill_yx+):
    # sostituisce con cell la regione 4-connessa di celle con lo stesso EGC
    # della cella di partenza (stile e colori non contano). Riempire celle
    # vuote sovrascrive anche le metà destre dei glifi larghi. Se il
    # riempimento copre solo metà di un glifo largo, l'altra metà diventa una
    # cella vuota. Il cursore non si sposta.
    #
    # @param cell [Cell, String] carattere largo 1 colonna; una String usa
    #   stile e colori del piano
    # @param y [Integer, nil] riga di partenza; nil = riga del cursore
    # @param x [Integer, nil] colonna di partenza; nil = colonna del cursore
    # @return [Integer] celle riempite (0 se la cella di partenza ha già l'EGC di cell)
    # @raise [ArgumentError, TypeError] se un argomento non è valido
    # @raise [CellError] se notcurses non accetta il carattere
    # @raise [PlaneError] se l'egcpool del piano (16 MiB) non ha spazio per il
    #   carattere e per le sue copie (una per cella; il piano resta com'era,
    #   il messaggio nomina l'egcpool), o se il riempimento fallisce
    # @raise [ClosedError] se il piano è chiuso
    def polyfill(cell, y: nil, x: nil)
      Guard.run do
        ptr = to_ptr
        fill = line_cell!(cell, ptr)
        top, left = line_start!(y, x)
        with_nccells(ptr, [fill]) do |nc|
          rehearse!(ptr, fill.egc) { |copy| FFI.ncplane_polyfill_yx(copy, top, left, nc) }
          keep_glyphs_whole(ptr, 0, 0, dim_y, dim_x, all: true, long_fill: fill.egc.bytesize > 4) do # regione non nota
            Util.check!(FFI.ncplane_polyfill_yx(ptr, top, left, nc), PlaneError, 'ncplane_polyfill_yx')
          end
        end
      end
    end

    # Riempie un rettangolo con egc e colori sfumati tra i quattro angoli
    # (+ncplane_gradient+). Il contenuto precedente si perde; un glifo largo
    # coperto solo a metà diventa una cella vuota anche nell'altra metà. Il
    # cursore non si sposta. Il wrapper controlla i vincoli del C prima della chiamata (il
    # C fallirebbe dopo aver già cambiato celle): per primo piano e sfondo, o
    # tutti gli angoli hanno il colore di default o nessuno, gli alpha sono
    # uguali, niente colori di palette; con una riga servono ul == ll e
    # ur == lr, con una colonna ul == ur e ll == lr, in un'area 1x1 quattro
    # angoli uguali.
    #
    # @param egc [String] carattere largo 1 colonna, o "" (celle vuote colorate)
    # @param ul [Channels, Integer] colori dell'angolo superiore sinistro
    # @param ur [Channels, Integer] superiore destro
    # @param ll [Channels, Integer] inferiore sinistro
    # @param lr [Channels, Integer] inferiore destro
    # @param y [Integer] prima riga
    # @param x [Integer] prima colonna
    # @param rows [Integer, nil] righe; nil = fino al bordo
    # @param cols [Integer, nil] colonne; nil = fino al bordo
    # @param styles [Integer, Symbol, Array<Symbol>] stili delle celle
    # @return [Integer] celle scritte
    # @raise [ArgumentError, TypeError] se un argomento non è valido
    # @raise [CellError] se notcurses non accetta egc
    # @raise [PlaneError] se l'egcpool del piano (16 MiB) non ha spazio per le
    #   copie di egc (una per cella; il piano resta com'era, il messaggio
    #   nomina l'egcpool), o se il riempimento fallisce
    # @raise [ClosedError] se il piano è chiuso
    def gradient(egc, ul, ur, ll, lr, y: 0, x: 0, rows: nil, cols: nil, styles: 0)
      Guard.run do
        ptr = to_ptr
        text = Cell.egc!(egc)
        unless text.empty?
          raise ArgumentError, "gradient: egc #{Util.egc_label(text)} deve essere largo 1 colonna" unless Notcurses.strwidth(text) == 1

          single_egc!(ptr, text)
        end
        corners = corner_values([ul, ur, ll, lr], 64)
        top, left, height, width = region!(y, x, rows, cols)
        corners_shape!(corners, height, width, rows_rule: true)
        mask = Util.styles_value(styles)
        # con il pool pieno il C ha già scritto le celle prima, e azzerato i canali di quella che fallisce (fill.c:259-263)
        rehearse!(ptr, text) { |copy| FFI.ncplane_gradient(copy, top, left, height, width, text, mask, *corners) }
        keep_glyphs_whole(ptr, top, left, height, width, long_fill: text.bytesize > 4) do
          Util.check!(FFI.ncplane_gradient(ptr, top, left, height, width, text, mask, *corners), PlaneError, 'ncplane_gradient')
        end
      end
    end

    # Riempie un rettangolo con mezzi blocchi "▀" a doppia risoluzione
    # verticale (+ncplane_gradient2x1+): ogni cella ha due righe di colore,
    # sfumate tra i quattro angoli; lo stile delle celle resta. Con un angolo
    # di default primo piano e sfondo diventano di default. Vincoli come in
    # {#gradient}, su canali singoli; con una colonna servono ul == ur e
    # ll == lr. Un glifo largo coperto solo a metà diventa una cella vuota
    # anche nell'altra metà. Serve un terminale UTF-8.
    #
    # @param ul [Channel, Integer] colore dell'angolo superiore sinistro
    # @param ur [Channel, Integer] superiore destro
    # @param ll [Channel, Integer] inferiore sinistro
    # @param lr [Channel, Integer] inferiore destro
    # @param y [Integer] prima riga
    # @param x [Integer] prima colonna
    # @param rows [Integer, nil] righe; nil = fino al bordo
    # @param cols [Integer, nil] colonne; nil = fino al bordo
    # @return [Integer] celle scritte
    # @raise [ArgumentError, TypeError] se un argomento non è valido
    # @raise [PlaneError] senza UTF-8, o se il riempimento fallisce
    # @raise [ClosedError] se il piano è chiuso
    def gradient2x1(ul, ur, ll, lr, y: 0, x: 0, rows: nil, cols: nil)
      Guard.run do
        ptr = to_ptr
        corners = corner_values([ul, ur, ll, lr], 32)
        top, left, height, width = region!(y, x, rows, cols)
        corners_shape!(corners, height, width, rows_rule: false)
        raise PlaneError, 'gradient2x1 richiede un terminale UTF-8' unless @context.can_utf8?

        keep_glyphs_whole(ptr, top, left, height, width) do
          Util.check!(FFI.ncplane_gradient2x1(ptr, top, left, height, width, *corners), PlaneError,
                      'ncplane_gradient2x1')
        end
      end
    end

    # Sfuma i colori di un rettangolo tra i quattro angoli lasciando EGC e
    # stili (+ncplane_stain+). Le celle vuote e le metà destre dei glifi larghi
    # non cambiano. Non tocca gli EGC: su metà di un glifo largo non lascia
    # metà orfane. Vincoli sui colori come in {#gradient}, senza quelli sulla
    # forma.
    #
    # @param ul [Channels, Integer] colori dell'angolo superiore sinistro
    # @param ur [Channels, Integer] superiore destro
    # @param ll [Channels, Integer] inferiore sinistro
    # @param lr [Channels, Integer] inferiore destro
    # @param y [Integer] prima riga
    # @param x [Integer] prima colonna
    # @param rows [Integer, nil] righe; nil = fino al bordo
    # @param cols [Integer, nil] colonne; nil = fino al bordo
    # @return [Integer] celle del rettangolo (anche quelle non cambiate)
    # @raise [ArgumentError, TypeError] se un argomento non è valido
    # @raise [PlaneError] se l'operazione fallisce
    # @raise [ClosedError] se il piano è chiuso
    def stain(ul, ur, ll, lr, y: 0, x: 0, rows: nil, cols: nil)
      Guard.run do
        ptr = to_ptr
        corners = corner_values([ul, ur, ll, lr], 64)
        top, left, height, width = region!(y, x, rows, cols)
        Util.check!(FFI.ncplane_stain(ptr, top, left, height, width, *corners), PlaneError, 'ncplane_stain')
      end
    end

    # Imposta gli stili di un rettangolo lasciando EGC e colori
    # (+ncplane_format+; il nome evita di nascondere Kernel#format). Non tocca
    # gli EGC: su metà di un glifo largo non lascia metà orfane.
    #
    # @param styles [Integer, Symbol, Array<Symbol>]
    # @param y [Integer] prima riga
    # @param x [Integer] prima colonna
    # @param rows [Integer, nil] righe; nil = fino al bordo
    # @param cols [Integer, nil] colonne; nil = fino al bordo
    # @return [Integer] celle del rettangolo
    # @raise [ArgumentError, TypeError] se un argomento non è valido
    # @raise [PlaneError] se l'operazione fallisce
    # @raise [ClosedError] se il piano è chiuso
    def restyle(styles, y: 0, x: 0, rows: nil, cols: nil)
      Guard.run do
        ptr = to_ptr
        mask = Util.styles_value(styles)
        top, left, height, width = region!(y, x, rows, cols)
        Util.check!(FFI.ncplane_format(ptr, top, left, height, width, mask), PlaneError, 'ncplane_format')
      end
    end

    # --- dissolvenze ---

    # Sfuma i colori del piano verso il nero in seconds secondi, cella base
    # compresa; i colori non vengono ripristinati. A ogni passo il wrapper
    # renderizza la pila del piano ({#render_pile}), chiama il blocco (se c'è)
    # e dorme fino al passo successivo; se è in ritardo salta passi, ma esegue
    # sempre l'ultimo. I colori di palette diventano RGB.
    #
    # Scritto in Ruby sopra {FadeContext}: +ncplane_fadeout+ di 3.0.17
    # renderizza la pila standard invece di quella del piano, dorme tenendo il
    # GVL e con un callback lento non arriva al nero.
    #
    # @param seconds [Numeric] durata, > 0
    # @yieldparam plane [Plane] il piano, dopo il render di ogni passo
    # @yieldreturn [Object] :stop per fermare la dissolvenza
    # @return [self]
    # @raise [PlaneError] se il terminale non permette le dissolvenze
    #   ({Context#can_fade?}), o se un render fallisce
    # @raise [TypeError, ArgumentError] se seconds non è valido
    # @raise [ClosedError] se il piano è chiuso
    def fadeout(seconds, &block)
      duration = fade_seconds!(seconds)
      fade_context { |fc| fade_steps(fc, :fadeout, duration, block) }
      self
    end

    # Porta i colori del piano dal nero a quelli attuali in seconds secondi,
    # come {#fadeout} (la cella base non cambia). Al termine il piano ha di
    # nuovo i colori di partenza.
    #
    # @param seconds [Numeric] durata, > 0
    # @yieldparam plane [Plane] il piano, dopo il render di ogni passo
    # @yieldreturn [Object] :stop per fermare la dissolvenza
    # @return [self]
    # @raise [PlaneError] se il terminale non permette le dissolvenze, o se un
    #   render fallisce
    # @raise [TypeError, ArgumentError] se seconds non è valido
    # @raise [ClosedError] se il piano è chiuso
    def fadein(seconds, &block)
      duration = fade_seconds!(seconds)
      fade_context { |fc| fade_steps(fc, :fadein, duration, block) }
      self
    end

    # Pulsa: dissolvenza dal nero ai colori attuali e ritorno al nero, ogni
    # fase in seconds secondi, finché il blocco non restituisce :stop.
    #
    # Scritto in Ruby: +ncplane_pulse+ di 3.0.17 resta nero dopo il primo
    # ciclo e senza callback non ritorna mai.
    #
    # @param seconds [Numeric] durata di ogni fase, > 0
    # @yieldparam plane [Plane] il piano, dopo il render di ogni passo
    # @yieldreturn [Object] :stop per fermare
    # @return [self]
    # @raise [ArgumentError] senza blocco, o se seconds non è valido
    # @raise [PlaneError] se il terminale non permette le dissolvenze, o se un
    #   render fallisce
    # @raise [TypeError] se seconds non è un numero
    # @raise [ClosedError] se il piano è chiuso
    def pulse(seconds, &block)
      raise ArgumentError, 'pulse richiede un blocco (restituisci :stop per fermare)' unless block

      duration = fade_seconds!(seconds)
      fade_context do |fc|
        loop do
          break if fade_steps(fc, :fadein, duration, block) == :stop
          break if fade_steps(fc, :fadeout, duration, block) == :stop
        end
      end
      self
    end

    # Fotografa i colori attuali del piano per una dissolvenza passo per passo
    # (+ncfadectx_setup+), per esempio dentro un ciclo di input.
    #
    # @return [FadeContext] il contesto; con un blocco, il valore del blocco
    #   (il contesto viene liberato alla fine)
    # @raise [PlaneError] se il terminale non permette le dissolvenze
    # @raise [ClosedError] se il piano è chiuso
    def fade_context(&block)
      Util.with_resource(FadeContext.new(self), &block)
    end

    # --- registro interno ---

    # @api private
    # @return [Integer] indirizzo del ncplane*
    def address = @ptr.address

    # Puntatore senza il controllo di chiusura, per confronti interni.
    # @api private
    def address_ptr = @ptr

    # Marca il piano come distrutto dal C (senza chiamare il distruttore).
    # @api private
    def invalidate!
      return if @closed

      @closed = true
      @callbacks.clear
      @context.untrack_plane(self) if @generation.nil?
    end

    # Il piano passa a un nuovo proprietario (un widget): {#close} non lo
    # distrugge più, e il piano si chiude con il proprietario.
    # @api private
    def transfer_to(owner)
      @owned = false
      @owner = owner
      @widget_plane = true
    end

    # @api private
    # @return [Boolean] true se il piano appartiene a un widget
    def widget_plane? = @widget_plane == true

    # Tiene vivo un ::FFI::Function finché il piano esiste.
    # @api private
    def retain_callback(fn)
      @callbacks << fn
    end

    # Applica al nuovo piano le parti delle opzioni da ricordare.
    # @api private
    def adopt_options!(keep)
      @margins = keep[:margins]
      @resize_fn = keep[:resizecb].is_a?(::FFI::Function) ? keep[:resizecb] : nil
      @callbacks << @resize_fn if @resize_fn
      @resize = keep[:resize]
    end

    # Esegue il blocco (un blit C che scrive celle di questo piano nel
    # rettangolo dato) e poi svuota l'altra metà dei glifi larghi che il blit
    # ha coperto solo a metà, come i riempimenti (ICH-450, ICH-486). Il
    # controllo legge solo i glifi a cavallo dei lati del rettangolo (ICH-549):
    # il costo è proporzionale alle sue righe. Con all: true legge anche quelli
    # dentro, per un blit che non scrive ogni cella del rettangolo: il costo è
    # proporzionale alla sua area. La parte del rettangolo fuori dal piano non
    # conta.
    # @api private
    # @param top [Integer] prima riga del rettangolo
    # @param left [Integer] prima colonna del rettangolo
    # @param height [Integer] righe del rettangolo
    # @param width [Integer] colonne del rettangolo
    # @param all [Boolean] true = controlla anche i glifi dentro il rettangolo
    # @yieldreturn [Object] il risultato del blit
    # @return [Object] il valore del blocco
    # @raise [ClosedError] se il piano è chiuso
    def keeping_glyphs_whole(top, left, height, width, all: false, &block)
      Guard.run do
        ptr = to_ptr
        rows, cols = dims
        bottom = [top + height, rows].min
        right = [left + width, cols].min
        top = [top, 0].max
        left = [left, 0].max
        next yield if bottom <= top || right <= left # il blit non scrive celle del piano

        keep_glyphs_whole(ptr, top, left, bottom - top, right - left, all: all, &block)
      end
    end

    private

    # Puntatore di un altro piano dello stesso contesto.
    def same_context_plane!(plane, name)
      Guard.run do
        raise TypeError, "#{name} deve essere Notcurses::Plane, non #{plane.class}" unless plane.is_a?(Plane)
        raise ArgumentError, "#{name} appartiene a un altro contesto" unless plane.context.equal?(@context)

        plane.to_ptr
      end
    end

    # true se fn è il trampolino Ruby impostato dal wrapper su questo piano.
    def own_resize_function?(fn) = !@resize_fn.nil? && @resize_fn.address == fn.address

    # Simbolo del callback nativo con indirizzo fn, o nil.
    def native_resize_symbol(fn)
      NATIVE_RESIZE_CALLBACKS.each { |sym, name| return sym if Plane.native_function(name).address == fn.address }
      nil
    end

    def cursor_target!(y, x)
      rows, cols = dims
      return if y.between?(0, rows - 1) && x.between?(0, cols - 1)

      raise PlaneError, "cursore in (#{y}, #{x}) fuori dal piano #{rows}x#{cols}"
    end

    # Coordinate di una cella: nil = quella del cursore.
    # @return [Array(Integer, Integer)]
    def cell_coords!(y, x, state)
      rows, cols = state.dims
      if y.nil? || x.nil?
        cy, cx = state.cursor
        # dopo un output che riempie la riga il cursore resta a x == colonne
        raise PlaneError, "il cursore (#{cy}, #{cx}) è oltre il bordo del piano" unless cy < rows && cx < cols
      end
      y = y.nil? ? cy : Util.integer!(y, 'y', 0...rows)
      x = x.nil? ? cx : Util.integer!(x, 'x', 0...cols)
      [y, x]
    end

    # Campi privati di ptr; nil (niente workaround) se la libreria non è la 3.0.17 o i campi non coincidono con i getter.
    def internals(ptr)
      return nil unless Notcurses.lib_version_components.first(3) == [3, 0, 17]

      st = Internals.new(ptr)
      st if st[:leny] == FFI.ncplane_dim_y(ptr) && st[:lenx] == FFI.ncplane_dim_x(ptr) &&
            st[:scrolling] == FFI.ncplane_scrolling_p(ptr) && st[:autogrow] == FFI.ncplane_autogrow_p(ptr)
    end

    # Esegue il blocco, che fa un resize del C senza conservare niente (anche la rotazione, che ridimensiona il
    # piano a vuoto): notcurses.c:953-957 svuota l'egcpool, ma la cella base tiene il suo offset e Plane#base va
    # in SIGSEGV (ICH-489). Con un EGC di più di 4 byte, che sta nel pool, la cella base diventa uno spazio
    # durante la chiamata. Il wrapper scrive lo spazio nel campo privato senza rilasciare l'EGC: il C non può
    # usarne lo spazio nel pool, e senza spazio la base non tornerebbe più (ICH-531). Se il C non ha fatto il
    # resize (framebuffer uguale: rotazione rifiutata, malloc fallita) la base torna con i suoi byte; se l'ha
    # fatto, con ncplane_set_base nel pool svuotato, prima del primo callback Ruby di resize
    # (ruby_resize_function), che può riempire il pool, o dopo la chiamata. Una base cambiata nel frattempo da
    # un callback o da un trap vince. Con active falso (un resize che conserva celle, e quindi il pool) o senza
    # internals il blocco gira senza altro.
    def keeping_base_cell(active = true)
      Guard.run do
        ptr = to_ptr
        st = internals(ptr) if active
        return yield unless st && st[:basecell][:gcluster] >> 24 == 1 # EGC nel pool (cell_extended_p)

        cell = st[:basecell]
        saved = cell.to_ptr.read_bytes(CELL_BYTES)
        egc = FFI.nccell_extended_gcluster(ptr, cell)
        fb = st[:fb].address
        # gcluster " " (htole), width 1, stessi stili e canali; preparato prima: una sola scrittura
        temporary = space_bytes(saved)
        # una volta sola: dopo il ripristino un callback può impostare una base uguale allo spazio provvisorio
        restored = false
        restore = lambda do |done|
          next if restored || cell.to_ptr.read_bytes(CELL_BYTES) != temporary

          if st[:fb].address != fb
            Util.check!(FFI.ncplane_set_base(ptr, egc, cell[:stylemask], cell[:channels]), PlaneError, 'ncplane_set_base')
            restored = true
          elsif done
            cell.to_ptr.write_bytes(saved)
          end
        end
        begin
          @context.base_restores << restore
          cell.to_ptr.write_bytes(temporary)
          yield
        ensure
          @context.base_restores.delete(restore)
          restore.call(true) unless closed?
        end
      end
    end

    # Byte di una nccell con uno spazio (htole) largo 1 al posto dell'EGC di bytes, con gli stessi stili e canali.
    def space_bytes(bytes) = " \0\0\0".b + bytes.byteslice(4, 1) + "\x01".b + bytes.byteslice(6..)

    # Metà sinistre orfane di ptr (glifi larghi tagliati da un resize) seguite da un glifo: ncplane_mergedown
    # disegnerebbe il glifo largo intero e lascerebbe la cella dopo senza EGC e con i colori della metà sinistra
    # (render.c:471-485). Per la fusione il wrapper le cambia in uno spazio con gli stessi stili e canali, senza
    # rilasciare l'EGC dal pool (ICH-532): il C compone lo spazio e il glifo dopo come le altre celle. Senza
    # internals non cambia niente.
    # @return [Array<Array(::FFI::Pointer, String)>] celle cambiate con i loro byte di prima, da riscrivere dopo
    def blank_orphan_lefts!(ptr)
      st = internals(ptr)
      return [] if st.nil?

      cols = st[:lenx]
      cells = fb_bytes(st).unpack("LxCx#{CELL_BYTES - 6}" * (st[:leny] * cols)).each_slice(2).to_a
      fb = st[:fb]
      cells.each_index.filter_map do |i|
        gcluster, width = cells[i]
        next if i % cols == cols - 1 || gcluster == 0 || width < 2 || cells[i + 1][0] == 0

        cell = fb + (i * CELL_BYTES)
        bytes = cell.read_bytes(CELL_BYTES)
        cell.write_bytes(space_bytes(bytes))
        [cell, bytes]
      end
    end

    # EGC della cella (y, x) letto con ncplane_at_yx (strdup, senza passare dall'egcpool) quando
    # ncplane_at_yx_cell non riesce a copiarlo nel pool pieno (ICH-490). PlaneError su un piano con un bitmap,
    # dove ncplane_at_yx copierebbe la sequenza dello sprixel (vedi unreadable_half), e senza internals, dove
    # il bitmap non si riconosce.
    def unpooled_egc(ptr, y, x)
      st = internals(ptr)
      egc = FFI.ncplane_at_yx(ptr, y, x, nil, nil) if st && st[:sprite].null?
      raise PlaneError, "ncplane_at_yx_cell(#{y}, #{x}) fallita" if egc.nil? || egc.null?

      Util.take_string(egc).b # contents accumula byte, come nccell_extended_gcluster
    end

    # Byte del framebuffer di st (Internals), in ordine fisico. CELL_BYTES invece di NcCell.size (un metodo
    # Ruby) restringe la finestra fra la lettura di fb e quella dei byte, dove un gestore trap può
    # ridimensionare il piano; non la chiude: un trap gira anche al ritorno dei metodi C.
    def fb_bytes(st) = st[:fb].read_bytes(st[:leny] * st[:lenx] * CELL_BYTES)

    # gcluster delle celle in bytes che tengono l'EGC nell'egcpool (byte alto 0x01, cell_extended_p di
    # egcpool.h:195).
    def pooled(bytes)
      bytes.unpack("Lx#{FFI::NcCell.size - 4}" * (bytes.bytesize / FFI::NcCell.size)).select { |g| g >> 24 == 1 }
    end

    # Rilascia dall'egcpool di ptr gli EGC dei gcluster dati. Prima di ogni rilascio rilegge il pool da st
    # (Internals di ptr): un gestore trap che ha svuotato il piano lo lascia NULL (SIGSEGV in nccell_release).
    # Restringe la finestra, non la chiude: il trap può girare anche fra il controllo e il rilascio.
    def release_gclusters!(ptr, st, gclusters)
      cell = FFI::NcCell.new
      gclusters.each do |gcluster|
        cell[:gcluster] = gcluster
        FFI.nccell_release(ptr, cell) if !st[:pool].null? && (gcluster & 0xffffff) < st[:poolsize]
      end
    end

    # Rilascia gli EGC dei gcluster dati (copie vecchie di merge_down, celle scartate dal resize in due passi
    # di resize_region) che nessuna cella usa più. Salta quelli ancora nel framebuffer e quelli che il C ha
    # già rilasciato (primo byte 0: egcpool_release, egcpool.h:168-176, toglierebbe comunque un byte da
    # poolused); rilascia solo da un inizio di EGC (byte prima 0). I callback di resize dei figli e i gestori
    # trap possono svuotare o riscrivere il pool (Plane#erase, set_base): salta un pool vuoto, gli offset
    # oltre il pool di adesso e la cella base, che non sta nel framebuffer.
    def release_unused!(ptr, gclusters)
      st = internals(ptr)
      return if st.nil?

      unused = gclusters - pooled(fb_bytes(st)) - [st[:basecell][:gcluster]]
      release_gclusters!(ptr, st, unused.select do |g|
        idx = g & 0xffffff
        # pool riletto per ogni cella: un trap lo può liberare. != 0 e non nonzero?, che chiama zero? sotto la
        # guardia di ricorsione di Ruby: un trap che lì chiama nonzero? sullo stesso intero riceve NameError
        pool = st[:pool]
        !pool.null? && idx < st[:poolsize] && pool.get_uint8(idx) != 0 && (idx.zero? || pool.get_uint8(idx - 1) == 0)
      end)
    end

    # Annulla merge_down: rilascia le copie nuove (fresh) e riscrive il framebuffer di prima (old). Se un
    # gestore trap ha cambiato dst dopo la lettura di old, la fusione resta com'è: con dimensioni diverse la
    # scrittura andrebbe oltre il framebuffer, con un pool svuotato le celle punterebbero a EGC liberati.
    # true se ha riscritto il framebuffer di prima. Il controllo prima della scrittura è una sola espressione,
    # senza blocchi né lambda (ICH-529): un trap che gira dopo il suo ultimo metodo non si può escludere.
    def undo_merge!(ptr, st, old, fresh)
      size = old.bytesize
      top = pooled(old).map { |g| g & 0xffffff }.max || -1
      return false unless size == st[:leny] * st[:lenx] * CELL_BYTES && !st[:pool].null? && top < st[:poolsize]

      release_gclusters!(ptr, st, pooled(fresh))
      return false unless size == st[:leny] * st[:lenx] * CELL_BYTES && !st[:pool].null? && top < st[:poolsize]

      st[:fb].write_bytes(old)
      true
    end

    # true se in bytes (righe di cols celle) c'è una cella che ncplane_mergedown non è riuscita a copiare:
    # cell_duplicate_far scrive la larghezza e poi, senza spazio nel pool, lascia gcluster a 0
    # (internal.h:909-922). Salta la cella dopo una metà sinistra: postpaint_cell ne azzera il gcluster e
    # lascia la larghezza (render.c:471-485), anche quando la metà sinistra è orfana e lì c'era un glifo.
    def lost_egc?(bytes, cols)
      cells = bytes.unpack("LxCx#{CELL_BYTES - 6}" * (bytes.bytesize / CELL_BYTES)).each_slice(2).to_a
      cells.each_with_index.any? do |(g, w), i|
        pg, pw = cells[i - 1] unless (i % cols).zero?
        g.zero? && w.positive? && !(pg && pg != 0 && pw >= 2) # != 0: vedi release_unused!
      end
    end

    # true se la cella (y, x) è la metà destra di un glifo largo.
    def wide_right?(ptr, y, x) = half_at(ptr, y, x) == :right

    # Dopo ncplane_mergedown la metà destra di ogni glifo largo di dst ha width
    # 0 (render.c:393-395, 471-485): per notcurses non è più una metà destra, e
    # una scrittura sulla metà sinistra non la cancella; da lì si arriva a una
    # metà destra orfana e a scritture fuori dalla riga (ICH-481). Il wrapper
    # riscrive quei glifi con ncplane_putc_yx, che rimette la metà destra; il
    # cursore di dst torna dov'era. Un glifo che ncplane_at_yx_cell non riesce
    # a leggere (egcpool pieno) lo riscrive rewrite_unreadable! (ICH-485).
    def restore_wide_glyphs!(dst)
      rows = ::FFI::MemoryPointer.new(:uint)
      cols = ::FFI::MemoryPointer.new(:uint)
      FFI.ncplane_dim_yx(dst, rows, cols)
      cy = ::FFI::MemoryPointer.new(:uint)
      cx = ::FFI::MemoryPointer.new(:uint)
      FFI.ncplane_cursor_yx(dst, cy, cx)
      cell = FFI::NcCell.new
      moved = false
      rows.read_uint.times do |y|
        (cols.read_uint - 1).times do |x|
          if FFI.ncplane_at_yx_cell(dst, y, x, cell).negative?
            moved = true if stale_right_half?(dst, y, x + 1) && rewrite_unreadable!(dst, y, x, 2)
            next
          end

          begin
            if FFI.nccell_wide_left_p(cell) && stale_right_half?(dst, y, x + 1)
              Util.check!(FFI.ncplane_putc_yx(dst, y, x, cell), PlaneError, 'ncplane_putc_yx')
              moved = true
            end
          ensure
            FFI.nccell_release(dst, cell)
          end
        end
      end
      restore_cursor!(dst, cy.read_uint, cx.read_uint, cols.read_uint) if moved
    end

    # Rimette il cursore di ptr in (y, x). ncplane_cursor_move_yx rifiuta
    # x == colonne (notcurses.c:729-731), dove resta il cursore dopo una
    # scrittura che riempie la riga: lì il wrapper riscrive con il suo stesso
    # contenuto l'ultima cella della riga (la metà sinistra, se è una metà
    # destra), e ncplane_putc_yx lascia il cursore subito dopo. Se notcurses
    # non riesce a leggere quella cella (egcpool pieno) la riscrive
    # rewrite_unreadable!, con lo stesso effetto sul cursore (ICH-485).
    def restore_cursor!(ptr, y, x, cols)
      return Util.check!(FFI.ncplane_cursor_move_yx(ptr, y, x), PlaneError, 'ncplane_cursor_move_yx') if x < cols

      last = cols > 1 && wide_right?(ptr, y, cols - 1) ? cols - 2 : cols - 1
      cell = FFI::NcCell.new
      return rewrite_unreadable!(ptr, y, last, 0) if FFI.ncplane_at_yx_cell(ptr, y, last, cell).negative?

      begin
        Util.check!(FFI.ncplane_putc_yx(ptr, y, last, cell), PlaneError, 'ncplane_putc_yx')
      ensure
        FFI.nccell_release(ptr, cell)
      end
    end

    # Riscrive la cella (y, x) con il suo stesso contenuto quando ncplane_at_yx_cell non la legge (egcpool
    # pieno): ncplane_at_yx copia l'EGC con strdup, senza passare dal pool, e ncplane_putegc_yx lo rimette
    # con gli stili e i canali della cella al posto di quelli del piano, ripristinati subito dopo.
    # ncplane_put rilascia la vecchia copia prima di salvare la nuova, quindi nel pool lo spazio c'è. Un EGC
    # più stretto di min_width resta com'è. Se la scrittura fallisce svuota la cella e quella dopo, cioè le
    # due metà di un glifo largo.
    # @return [Boolean] true se ha scritto (il cursore finisce dopo il glifo) o svuotato la cella
    def rewrite_unreadable!(ptr, y, x, min_width)
      styles = ::FFI::MemoryPointer.new(:uint16)
      channels = ::FFI::MemoryPointer.new(:uint64)
      egc = Util.take_string(FFI.ncplane_at_yx(ptr, y, x, styles, channels))
      return false if egc.nil? || FFI.ncstrwidth(egc, nil, nil) < min_width

      plane_styles = FFI.ncplane_styles(ptr)
      plane_channels = FFI.ncplane_channels(ptr)
      FFI.ncplane_set_styles(ptr, styles.read_uint16)
      FFI.ncplane_set_channels(ptr, channels.read_uint64)
      rc = FFI.ncplane_putegc_yx(ptr, y, x, egc, nil)
      FFI.ncplane_set_styles(ptr, plane_styles)
      FFI.ncplane_set_channels(ptr, plane_channels)
      FFI.ncplane_erase_region(ptr, y, x, 1, 2) if rc.negative?
      true
    end

    # true se (y, x) è vuota e larga meno di 2: la metà destra lasciata da ncplane_mergedown, con larghezza 0
    # (render.c:393-395) o con quella della cella di src sotto una metà sinistra orfana (render.c:471-485,
    # ICH-530). Una metà destra vera ha larghezza 2 e non conta.
    def stale_right_half?(ptr, y, x)
      cell = FFI::NcCell.new
      return false if FFI.ncplane_at_yx_cell(ptr, y, x, cell).negative?

      cell[:gcluster].zero? && cell[:width] < 2
    ensure
      FFI.nccell_release(ptr, cell)
    end

    # :left o :right se (y, x) è una metà di un glifo largo, :none se no, nil se
    # la cella non si può leggere (piano con un bitmap). ncplane_at_yx_cell
    # duplica l'EGC nell'egcpool, quindi fallisce anche con il pool pieno, ma
    # solo per gli EGC di più di 4 byte, che stanno nel pool: quelle celle le
    # legge unreadable_half.
    def half_at(ptr, y, x)
      cell = FFI::NcCell.new
      return unreadable_half(ptr, y, x) if FFI.ncplane_at_yx_cell(ptr, y, x, cell).negative?

      if FFI.nccell_wide_left_p(cell) then :left
      elsif FFI.nccell_wide_right_p(cell) then :right
      else :none
      end
    ensure
      FFI.nccell_release(ptr, cell)
    end

    # half_at per una cella che ncplane_at_yx_cell non legge (ICH-487). Con l'egcpool pieno è una cella con
    # un EGC di più di 4 byte, quindi mai una metà destra, che non ha un EGC: ncplane_at_yx copia l'EGC con
    # strdup, senza passare dal pool, e la larghezza dice se è una metà sinistra. Su un piano con un bitmap
    # ncplane_at_yx copierebbe invece la sequenza dello sprixel (notcurses.c:236-243), che con Kitty è già
    # stata liberata dopo il disegno (kitty.c:1186-1188: strdup(NULL)): nil, come senza internals.
    def unreadable_half(ptr, y, x)
      st = internals(ptr)
      return nil if st.nil? || !st[:sprite].null?

      egc = FFI.ncplane_at_yx(ptr, y, x, nil, nil)
      return nil if egc.null?

      FFI.ncstrwidth(Util.take_string(egc), nil, nil) > 1 ? :left : :none
    end

    # Cancella le metà orfane che un resize lascia sul bordo tagliando un glifo
    # largo: la metà sinistra (larga 2) nell'ultima colonna, la metà destra in
    # colonna 0 o, senza la sua metà sinistra (resize_region con x_off < 0),
    # nell'ultima colonna. Su quelle celle ncplane_put di 3.0.17 scrive fuori
    # dalla riga (notcurses.c:1917-1927, 1956-1962). Senza force legge le righe
    # solo se le colonne sono cambiate dall'ultima volta: così copre anche i
    # resize fatti dal C (stdplane nel render, callback :maximize). Un cambio di
    # sole righe non sposta le celle di bordo (le righe nuove sono vuote), e
    # un piano che scorre con autogrow cresce di una riga a ogni a capo.
    # Le metà orfane che nascono senza resize (erase_region, gradient,
    # gradient2x1 e polyfill su una sola metà) le svuotano quei metodi.
    # Con size ([righe, colonne] già lette) non rilegge le dimensioni.
    def clear_cut_glyphs!(ptr, force: false, size: nil)
      rows, cols = size || dims
      owner = cut_glyphs_owner
      return if !force && owner&.cut_glyphs_cols == cols

      clear_orphan_halves!(ptr, 0...rows, [0, cols - 1], cols)
      owner&.cut_glyphs_cols = cols
    end

    # Plane che tiene lo stato di clear_cut_glyphs! per il piano C (ICH-448):
    # quello tracciato, l'unico per piano nel registro del contesto. nil se il
    # piano C non ha un Plane tracciato aperto: allora non c'è una cache.
    def cut_glyphs_owner = @generation.nil? ? self : @context.tracked_plane(address)

    # Svuota le metà orfane dei glifi larghi nelle colonne xs delle righe ys
    # (colonne fuori dal piano ignorate). ncplane_put di 3.0.17 scrive fuori
    # dalla riga partendo da una metà destra orfana (notcurses.c:1956-1962).
    def clear_orphan_halves!(ptr, ys, xs, cols = dim_x)
      xs = xs.select { |x| x >= 0 && x < cols }.uniq
      ys.each do |y|
        xs.each do |x|
          next unless orphan_half?(ptr, y, x, cols)

          Util.check!(FFI.ncplane_erase_region(ptr, y, x, 1, 1), PlaneError, 'ncplane_erase_region')
        end
      end
    end

    # true se (y, x) è una metà di glifo largo senza l'altra metà: una metà
    # sinistra nell'ultima colonna, una metà destra in colonna 0 o senza la
    # metà sinistra prima. Una metà sinistra seguita da una cella vuota non
    # conta: una metà destra con width 0 è uguale a una cella vuota, e
    # notcurses ne lascia (ncplane_mergedown, che restore_wide_glyphs!
    # corregge; la vista del Reader, ICH-484).
    def orphan_half?(ptr, y, x, cols)
      case half_at(ptr, y, x)
      when :left then x == cols - 1
      when :right then x.zero? || !wide_left?(ptr, y, x - 1)
      else false
      end
    end

    # Esegue il blocco (un riempimento C che cambia le celle una per una nel
    # rettangolo dato) e poi svuota l'altra metà dei glifi larghi che ha
    # coperto solo a metà. I glifi da controllare si leggono prima della
    # chiamata: quelli a cavallo dei lati del rettangolo, e con all: true anche
    # quelli dentro. Una metà sinistra che half_at non riesce a leggere
    # (nil: da ICH-487 non più per l'egcpool pieno) conta come glifo se la
    # metà destra c'è. Dopo la chiamata la stessa cella illeggibile è ancora
    # quella di prima, salvo con long_fill (il riempimento scrive un EGC di più
    # di 4 byte): allora nel dubbio si svuotano le due metà. La pulizia gira
    # anche se il blocco solleva: il C può fallire dopo aver già cambiato celle
    # (egcpool pieno), e in quel caso cerca anche le metà destre orfane nel
    # rettangolo.
    def keep_glyphs_whole(ptr, top, left, height, width, all: false, long_fill: false)
      ys = top...(top + height)
      xs = all ? ((left - 1)...(left + width)) : [left - 1, left + width - 1]
      glyphs = ys.flat_map { |y| xs.select { |x| glyph_at?(ptr, y, x) }.map { |x| [y, x] } }
      done = false
      rc = yield
      done = true
      rc
    ensure
      rows, cols = dims if glyphs # le dimensioni dopo il blocco
      glyphs&.each do |y, x|
        next if y >= rows || x + 1 >= cols

        left_half = half_at(ptr, y, x) || (long_fill ? nil : :left)
        right_half = half_at(ptr, y, x + 1)
        next if left_half == :left && right_half == :right

        [(x if left_half != :none), (x + 1 if right_half == :right)].compact.each do |cx|
          Util.check!(FFI.ncplane_erase_region(ptr, y, cx, 1, 1), PlaneError, 'ncplane_erase_region')
        end
      end
      clear_orphan_halves!(ptr, ys, left..(left + width)) if glyphs && !done
    end

    # true se (y, x + 1) è una metà destra e (y, x) la sua metà sinistra, o una
    # cella che notcurses non riesce a leggere.
    def glyph_at?(ptr, y, x)
      x >= 0 && x + 1 < dim_x && wide_right?(ptr, y, x + 1) && half_at(ptr, y, x) != :none
    end

    # Su uno stdplane che scorre ogni a capo ("\n" o a capo automatico) fa un
    # render dentro ncplane_put (notcurses.c:1978-1981), che lo restringe se il
    # terminale si è ristretto: il resto della stessa chiamata C scriverebbe su
    # una metà orfana. Se il blocco dà true (la scrittura può andare a capo)
    # ncpile_render porta prima lo stdplane alle dimensioni del terminale
    # (render.c:1579). Il render può cambiare le dimensioni: lo stato si
    # rilegge.
    def sync_scrolling_stdplane!(ptr, state)
      return unless address == @context.stdplane.address && state.scrolling? && yield

      rc = FFI.ncpile_render(ptr)
      @context.raise_callback_errors!
      Util.check!(rc, RenderError, 'ncpile_render')
      state.forget!
      clear_cut_glyphs!(ptr, size: state.dims)
    end

    # true se la cella (y, x) è la metà sinistra di un glifo largo.
    def wide_left?(ptr, y, x) = half_at(ptr, y, x) == :left

    # Cell con il contenuto di una nccell legata all'egcpool del piano ptr.
    def cell_content(ptr, cell)
      Cell.from_c(FFI.nccell_extended_gcluster(ptr, cell) || +'', cell[:stylemask], cell[:channels], cell[:width])
    end

    # --- helper dell'output ---

    # Testo da scrivere: String UTF-8 senza i caratteri che notcurses 3.0.17
    # scrive male (vedi {#putstr}). Il testo si segmenta in grapheme al massimo
    # una volta, solo se serve (indicatori regionali, caratteri di larghezza
    # zero): chi scrive riusa i grapheme (ICH-594). Una sola scansione cerca i
    # caratteri rifiutati; se ne trova uno sospetto, i controlli in ordine
    # dicono quale.
    # @return [Array(String, Array<String>, Hash)] il testo, i suoi grapheme
    #   cluster e le colonne dei grapheme che ha misurato (vedi
    #   {#zero_width_egc!}); nil al posto degli ultimi due se il testo non li ha
    #   richiesti
    def output_text!(ptr, text, name, graphemes = nil)
      str = Util.string!(text, name)
      ascii = str.ascii_only?
      if (ascii ? str : str.b).match?(TEXT_SUSPECTS)
        raise ArgumentError, "#{name} contiene un TAB: espandilo prima (per esempio con String#gsub)" if str.include?("\t")
        raise ArgumentError, "#{name} contiene un carattere di controllo" if str.match?(/(?!\n)\p{Cc}/)
        raise ArgumentError, "#{name} contiene U+2028 o U+2029, che notcurses tronca a un byte" if str.match?(/[\u2028\u2029]/)

        graphemes ||= str.grapheme_clusters if str.match?(Util::REGIONAL_INDICATOR)
        Util.lone_regional_indicator!(str, name, graphemes)
      end
      return [str, graphemes, nil] if ascii || !str.match?(ZERO_WIDTH_CANDIDATES)

      graphemes ||= str.grapheme_clusters
      [str, graphemes, zero_width_egc!(ptr, graphemes, name)]
    end

    # Rifiuta i caratteri che notcurses scrive come EGC di larghezza zero: il
    # C li mette in una cella propria e, con il cursore a fine riga
    # (x == colonne), scrive fuori dalla riga (sull'ultima riga fuori dal
    # framebuffer). La segmentazione è quella di notcurses (+nccell_load+),
    # che può dividere un grapheme di Ruby. Un grapheme corto già controllato
    # nella chiamata non si ricarica (ICH-594).
    # @return [Hash{String => Integer}] le colonne di ogni grapheme controllato,
    #   cioè la somma dei suoi pezzi: ncstrwidth le somma allo stesso modo
    #   (notcurses.c:3311-3333), e chi scrive non rimisura il grapheme
    def zero_width_egc!(ptr, graphemes, name)
      columns = {}
      graphemes.each do |g|
        next unless g.match?(ZERO_WIDTH_CANDIDATES)
        next if g.bytesize <= 32 && columns.key?(g)

        cols = 0
        read = nc_pieces(ptr, g) do |piece, width|
          if width.zero?
            raise ArgumentError, "#{name}: notcurses 3.0.17 scrive #{Util.egc_label(piece)} (in #{Util.egc_label(g)}) " \
                                 'come un carattere di larghezza zero, in una cella propria'
          end

          cols += width
        end
        raise ArgumentError, "#{name}: notcurses non accetta #{Util.egc_label(g)}" if read < g.bytesize

        columns[g] = cols
      end
      columns
    end

    # Passa al blocco i pezzi in cui notcurses divide str (+nccell_load+), con
    # le loro colonne. Un pezzo di più di 4 byte che l'egcpool del piano non ha
    # spazio per caricare si carica su un piano temporaneo con il pool vuoto:
    # la segmentazione non dipende dal pool, e lo spazio per la scrittura lo
    # controlla il C, che prima rilascia gli EGC delle celle che sovrascrive
    # (ICH-533). Il testo arriva UTF-8 valido e senza caratteri di controllo:
    # allora +nccell_load+ fallisce solo in +egcpool_stash+, per un pezzo di
    # più di 4 byte (+pool_blit_direct+, internal.h:1447-1468).
    # @return [Integer] byte letti: meno di str.bytesize se notcurses rifiuta
    #   un pezzo
    def nc_pieces(ptr, str)
      cell = FFI::NcCell.new
      target = ptr # la cella si rilascia sul piano dove è caricata
      off = 0
      while off < str.bytesize
        len = FFI.nccell_load(target, cell, str.byteslice(off..))
        unless len.positive?
          break unless target.equal?(ptr) && str.bytesize - off > 4

          target = spare_plane(ptr) # il caricamento fallito ha già rilasciato la cella
          next
        end
        yield str.byteslice(off, len), cell[:width]
        off += len
      end
      off
    ensure
      FFI.nccell_release(target, cell) if cell
      FFI.ncplane_destroy(target) unless target.nil? || target.equal?(ptr)
    end

    # Piano 1x1 figlio di ptr, con l'egcpool vuoto, per {#nc_pieces}: il
    # chiamante lo distrugge prima che arrivi un render.
    def spare_plane(ptr)
      opts = FFI::NcPlaneOptions.new
      opts[:rows] = 1
      opts[:cols] = 1
      Util.check_ptr!(FFI.ncplane_create(ptr, opts), PlaneError, 'ncplane_create')
    end

    # Scrive str, già controllato da output_text!, come {#putstr}. graphemes
    # sono i suoi grapheme cluster e columns le colonne dei grapheme che ha
    # misurato, se output_text! li ha già (nil = non segmentato). state è lo stato letto del piano: {#puttext} lo passa a ogni
    # riga, e il piano si legge una volta sola (ICH-594). Sui piani che non
    # scorrono e non crescono i segmenti non rileggono niente: il C sposta il
    # cursore della larghezza scritta (notcurses.c:1953-1975) e non cambia le
    # dimensioni. Sugli altri, dopo ogni segmento si rilegge.
    def write_text!(ptr, str, graphemes, columns, state, y:, x:, align:, stained:)
      graphemes ||= str.grapheme_clusters if !str.ascii_only? && str.match?(GRAPHEME_JOINERS)
      if state.cols == 1 && (graphemes || str.grapheme_clusters).any? { |g| Notcurses.strwidth(g) > 1 }
        raise PlaneError, 'un carattere largo 2 colonne non entra in un piano largo 1'
      end

      segments = text_segments(str, graphemes)
      # le colonne di un grapheme già misurato da output_text! non si misurano di nuovo
      widths = segments.map { |seg, single| (single && columns&.[](seg)) || Util.segments_width(seg, [seg]) }
      total = widths.sum
      sync_scrolling_stdplane!(ptr, state) do
        str.include?("\n") || total > state.cols - (x.is_a?(Integer) ? x : state.cursor[1])
      end
      ty, tx = text_target!(str, total, state, y: y, x: x, align: align, stained: stained) do
        Notcurses.strwidth(graphemes ? graphemes.first : str[0])
      end
      written = 0
      last = segments.size - 1
      segments.each_with_index do |(seg, single), i|
        # un piano che scorre o cresce cambia dimensioni e cursore a ogni scrittura, e lo scroll
        # dello stdplane fa un render, che può restringerlo a metà testo
        clear_cut_glyphs!(ptr, size: state.dims) if i.positive? && !state.fixed?
        sy = i.zero? ? ty : -1
        sx = i.zero? ? tx : -1
        # "\n" con il cursore oltre l'ultima colonna: due a capo nel C (vedi il YARD)
        if seg.start_with?("\n") && (i.positive? || tx == -1) && state.cursor[1] == state.cols
          Util.check!(FFI.ncplane_cursor_move_yx(ptr, sy, state.cols - 1), PlaneError, 'ncplane_cursor_move_yx')
          state.forget_cursor!
        end
        rc = with_glyph_kept(ptr, seg, sy, sx, state, width: widths[i], single: single) do
          if stained then FFI.ncplane_putstr_stained(ptr, seg)
          elsif i.zero? then FFI.ncplane_putstr_yx(ptr, ty, tx, seg)
          else FFI.ncplane_putstr(ptr, seg)
          end
        end
        @context.raise_callback_errors!
        written += rc.abs
        if rc != widths[i]
          raise PlaneError, "putstr: notcurses ha scritto #{written} colonne su #{total}#{egcpool_hint(ptr, seg, rc.abs)}"
        end

        state.advance!(sy, sx, widths[i]) if i < last
      end
      written
    end

    # Pezzi in cui putstr divide str per il C: dopo ogni grapheme con uno ZWJ
    # (notcurses 3.0.17 unisce a quel carattere tutto il resto), prima di ogni
    # "\n" e intorno a ogni EGC di più di 4 byte, che passa dal pool e si
    # scrive a parte (vedi {#with_glyph_kept}). Senza grapheme (un testo senza
    # caratteri che si legano) ogni codepoint è un grapheme cluster: si
    # divide solo prima di "\n".
    # @return [Array<Array(String, Boolean)>] [pezzo, true se è un solo grapheme cluster]
    def text_segments(str, graphemes)
      return str.split(/(?=\n)/).map { |seg| [seg, false] } unless graphemes

      segments = []
      seg = +''
      count = 0
      prev_long = false
      graphemes.each do |g|
        long = g.bytesize > 4
        if count.positive? && (g == "\n" || long || prev_long)
          segments << [seg, count == 1]
          seg = +''
          count = 0
        end
        seg << g
        count += 1
        prev_long = long
        next unless g.include?("\u200D")

        segments << [seg, count == 1]
        seg = +''
        count = 0
      end
      segments << [seg, count == 1] if count.positive?
      segments
    end

    # Esegue il blocco, la scrittura C di text in (y, x) (-1 = cursore), e ne
    # restituisce il valore. Con l'egcpool pieno ncplane_put svuota il glifo di
    # arrivo e gli dà gli stili e i colori del piano prima di fallire
    # (notcurses.c:1911-1950): per un solo EGC di più di 4 byte, l'unico che
    # passa dal pool, il wrapper legge prima quel glifo e, se la scrittura
    # fallisce, lo riscrive e rimette il cursore (review di ICH-533). Una
    # scrittura che andrà a capo non tocca la riga di arrivo. single dice se
    # text è un solo grapheme cluster, e width quante colonne occupa: il
    # chiamante li sa già, e il testo non si segmenta né si misura di nuovo
    # (ICH-594). Cursore e colonne vengono dallo stato letto.
    def with_glyph_kept(ptr, text, y, x, state, width:, single:)
      return yield unless single && text.bytesize > 4

      cy, cx = state.cursor
      ty = y.negative? ? cy : y
      tx = x.negative? ? cx : x
      kept = kept_glyph(ptr, ty, tx) if tx + width <= state.cols
      rc = yield
      restore_glyph!(ptr, kept, cy, cx, state.cols) if kept && rc != width
      rc
    end

    # [y, colonna, EGC, stili, canali] del glifo che copre (y, x), letto con
    # ncplane_at_yx (strdup, senza passare dal pool); nil su un piano con un
    # bitmap, dove il C rifiuta la scrittura prima di toccare le celle.
    def kept_glyph(ptr, y, x)
      half = half_at(ptr, y, x)
      return nil if half.nil?

      left = half == :right ? x - 1 : x
      styles = ::FFI::MemoryPointer.new(:uint16)
      channels = ::FFI::MemoryPointer.new(:uint64)
      egc = Util.take_string(FFI.ncplane_at_yx(ptr, y, left, styles, channels))
      egc && [y, left, egc, styles.read_uint16, channels.read_uint64]
    end

    # Riscrive il glifo di kept_glyph e porta il cursore in (cy, cx), su un
    # piano di cols colonne. Il C ha già rilasciato la copia vecchia, quindi
    # nel pool lo spazio c'è.
    def restore_glyph!(ptr, kept, cy, cx, cols)
      y, x, egc, styles, channels = kept
      cell = FFI::NcCell.new
      FFI.ncplane_putc_yx(ptr, y, x, cell) if FFI.nccell_prime(ptr, cell, egc, styles, channels) == egc.bytesize
      restore_cursor!(ptr, cy, cx, cols)
    ensure
      FFI.nccell_release(ptr, cell) if cell
    end

    # Motivo da aggiungere al messaggio di una scrittura di text fallita dopo
    # cols colonne: l'EGC dove il C si è fermato, se è di più di 4 byte e
    # l'egcpool del piano non ha spazio per caricarlo (ICH-533). Gli EGC prima
    # restano scritti.
    def egcpool_hint(ptr, text, cols = 0)
      stop = text.each_grapheme_cluster.find { |g| (cols -= Notcurses.strwidth(g)).negative? }
      return '' unless stop && stop.bytesize > 4

      cell = FFI::NcCell.new
      FFI.nccell_load(ptr, cell, stop).positive? ? '' : ": l'egcpool del piano (16 MiB) non ha spazio per #{Util.egc_label(stop)}"
    ensure
      FFI.nccell_release(ptr, cell) if cell
    end

    # Controlla dove scrivere un testo di total colonne e restituisce [y, x]
    # per il C (-1 = cursore). Il blocco dà la larghezza del primo carattere:
    # serve solo se il testo non entra, e un carattere non è mai più largo del
    # testo che lo contiene. Con stained porta il cursore nella posizione di
    # partenza. Legge lo stato dal state, solo ciò che serve. Lo chiamano
    # metodi che sono già dentro Guard.run.
    def text_target!(str, total, state, y:, x:, align:, stained:)
      ptr = state.ptr
      clear_cut_glyphs!(ptr, size: state.dims)
      rows, cols = state.dims
      newline = str.include?("\n")
      row = y.nil? ? state.cursor[0] : coord!(y, 'y', rows)
      col = if align
              raise ArgumentError, "align = #{align.inspect} non valido: usa :left, :center o :right" unless TEXT_ALIGNS.include?(align)
              raise ArgumentError, 'align: non ammette "\n"' if newline
              raise PlaneError, "il testo (#{total} colonne) è più largo del piano (#{cols})" if total > cols

              FFI.notcurses_align(cols, Util.placement_align_value(align), total) # come halign, senza rileggere le colonne
            else
              x.nil? ? state.cursor[1] : coord!(x, 'x', cols)
            end
      raise PlaneError, '"\n" richiede un piano che scorre (scrolling = true)' if newline && !state.scrolling?

      if total > cols && (width = yield) > cols
        raise PlaneError, "un carattere largo #{width} non entra nel piano largo #{cols}"
      end

      explicit_x = !(x.nil? && align.nil?)
      if explicit_x && col + total > cols && (width = yield) + col > cols
        raise PlaneError, "il carattere largo #{width} non entra nella riga dalla colonna #{col}"
      end
      if (col >= cols || col + total > cols) && (stained || state.fixed?)
        raise PlaneError, "il testo (#{total} colonne) non entra nella riga dalla colonna #{col} (piano largo #{cols})"
      end
      return [y.nil? ? -1 : row, explicit_x ? col : -1] unless stained

      raise ArgumentError, 'stained: non ammette "\n"' if newline

      cy, cx = state.cursor
      unless row == cy && col == cx
        Util.check!(FFI.ncplane_cursor_move_yx(ptr, row, col), PlaneError, "ncplane_cursor_move_yx(#{row}, #{col})")
        state.move_to(row, col)
      end
      [-1, -1]
    end

    # Come Util.integer!(value, name, 0...limit), senza creare l'intervallo
    # quando il valore è valido.
    def coord!(value, name, limit)
      value.is_a?(Integer) && value >= 0 && value < limit ? value : Util.integer!(value, name, 0...limit)
    end

    # Controlla l'EGC di {#putegc} e restituisce il testo UTF-8 e le sue colonne.
    # Un EGC di al massimo 4 byte che ha già passato tutti i controlli si ricorda
    # nel contesto (vedi {Context#checked_egcs}): la volta dopo non si controlla
    # di nuovo. Un EGC che solleva un errore non si ricorda mai.
    # @return [Array(String, Integer)]
    def egc_to_write!(ptr, egc, stained)
      checked = @context.checked_egcs
      if egc.is_a?(String) && (cols = checked[egc])
        Util.bool!(stained, 'stained')
        return [egc, cols]
      end

      text, graphemes = Cell.egc_with_graphemes!(egc, 'egc')
      raise ArgumentError, 'egc vuoto: serve un carattere' if text.empty?

      # un carattere ASCII stampabile: niente da controllare, largo 1 colonna
      ascii = text.match?(PRINTABLE_ASCII_CHAR)
      output_text!(ptr, text, 'egc', graphemes) unless ascii
      Util.bool!(stained, 'stained')
      return [text, 1] if ascii

      cols = single_egc!(ptr, text)
      if text.bytesize <= 4
        checked.clear if checked.size >= 4096
        checked[text] = cols
      end
      [text, cols]
    end

    # Controlla che notcurses legga text come un solo EGC (+nccell_load+), e ne
    # restituisce le colonne: sono quelle che +ncstrwidth+ somma sui pezzi
    # (notcurses.c:3311-3333), senza una seconda chiamata (ICH-594).
    def single_egc!(ptr, text)
      pieces = 0
      cols = 0
      read = nc_pieces(ptr, text) do |_piece, width|
        pieces += 1
        cols += width
      end
      return cols if read == text.bytesize && pieces == 1

      raise Cell.split_error(ptr, text) || CellError.new("notcurses non legge #{Util.egc_label(text)} come un solo carattere")
    end

    # Copia le Cell in nccell temporanee del piano, esegue il blocco e le
    # rilascia: una nccell non deve sopravvivere all'operazione. Una cella che
    # non si carica è divisa da notcurses (CellError, controllo con il pool
    # vuoto di {#nc_pieces}) o non trova spazio nell'egcpool (PlaneError).
    def with_nccells(ptr, cells)
      ncs = cells.map { FFI::NcCell.new }
      cells.each_with_index do |cell, i|
        next if cell.load_into(ptr, ncs[i])

        unloadable_cell!(ptr, cell)
      end
      yield(*ncs)
    ensure
      ncs&.each { |nc| FFI.nccell_release(ptr, nc) }
    end

    # {#with_nccells} per una sola cella: senza gli array (ICH-594).
    def with_nccell(ptr, cell)
      nc = FFI::NcCell.new
      unloadable_cell!(ptr, cell) unless cell.load_into(ptr, nc)
      yield nc
    ensure
      FFI.nccell_release(ptr, nc) if nc
    end

    # Una cella che non si carica è divisa da notcurses (CellError, controllo
    # con il pool vuoto di {#nc_pieces}) o non trova spazio nell'egcpool.
    def unloadable_cell!(ptr, cell)
      single_egc!(ptr, cell.egc)
      raise PlaneError, "l'egcpool del piano (16 MiB) non ha spazio per #{Util.egc_label(cell.egc)}"
    end

    # Prova la scrittura del blocco su una copia del piano e solleva
    # PlaneError se lì fallisce: con un EGC di più di 4 byte una scrittura
    # fallita cambia il piano. Il C rilascia e ricolora la cella di arrivo
    # prima di copiare l'EGC nell'egcpool (notcurses.c:1911-1950), le linee e
    # i box si fermano dopo le prime celle e lasciano nel pool la loro copia
    # di lavoro (notcurses.c:2207-2211, 2268-2272), polyfill e gradient si
    # fermano dopo le prime celle (fill.c:40-42, 259-263), set_base perde la
    # base vecchia (internal.h:1449-1464). Con argomenti già controllati, una
    # scrittura con un EGC lungo fallisce solo in egcpool_stash
    # (egcpool.c:27-99). ncplane_dup copia framebuffer, cursore, cella base e
    # pool byte per byte (notcurses.c:784-798, egcpool.h:215-229), quindi le
    # nccell caricate su ptr valgono anche sulla copia; non copia scrolling,
    # autogrow (flags 0, notcurses.c:776) e logrow, che il wrapper ripristina.
    # Limiti: un callback Ruby di resize che cambia il pool durante la
    # scrittura vera, e lo sprite di un piano con un bitmap (la copia non lo
    # ha, ma il C rifiuta comunque prima di cambiare celle, notcurses.c:1850).
    #
    # @param egcs [Array<String>] EGC della scrittura: senza EGC lunghi niente prova
    # @param state [WriteState, nil] stato già letto del piano: scrolling e
    #   autogrow non si rileggono (ICH-594)
    # @yieldparam copy [::FFI::Pointer] la copia, da usare al posto di ptr
    # @yieldreturn [Integer] il ritorno della funzione C
    def rehearse!(ptr, *egcs, state: nil)
      long = egcs.select { |egc| egc.bytesize > 4 }
      return if long.empty?

      copy = Util.check_ptr!(FFI.ncplane_dup(ptr, ::FFI::Pointer::NULL), PlaneError, 'ncplane_dup')
      begin
        FFI.ncplane_set_resizecb(copy, ::FFI::Pointer::NULL)
        FFI.ncplane_set_scrolling(copy, 1) if state ? state.scrolling? : scrolling?
        FFI.ncplane_set_autogrow(copy, 1) if state ? state.autogrow? : autogrow?
        if (from = internals(ptr)) && (to = internals(copy))
          to[:logrow] = from[:logrow]
        end
        rc = yield copy
      ensure
        FFI.ncplane_destroy(copy)
      end
      return unless rc.negative?

      raise PlaneError, "l'egcpool del piano (16 MiB) non ha spazio per #{long.map { |egc| Util.egc_label(egc) }.join(', ')}"
    end

    # Righe del testo a capo sulle parole, per una larghezza di cols colonne.
    def wrap_lines(str, cols)
      str.split("\n").flat_map do |paragraph|
        lines = [+'']
        width = 0
        paragraph.split(WORD_SPACES).each do |word|
          next if word.empty?

          wlen = Notcurses.strwidth(word)
          if width.positive? && width + 1 + wlen <= cols
            lines.last << ' ' << word
            width += 1 + wlen
          elsif wlen <= cols
            lines << +'' if width.positive?
            lines.last << word
            width = wlen
          else
            lines << +'' if width.positive?
            width = 0
            word.each_grapheme_cluster do |g|
              gw = Notcurses.strwidth(g)
              raise PlaneError, "puttext: #{g.inspect} è più largo del piano (#{cols} colonne)" if gw > cols

              if width + gw > cols
                lines << +''
                width = 0
              end
              lines.last << g
              width += gw
            end
          end
        end
        lines
      end
    end

    def rgb8_of
      ptrs = Array.new(3) { ::FFI::MemoryPointer.new(:uint) }
      yield(*ptrs)
      ptrs.map(&:read_uint)
    end

    # Cella di linee e riempimenti, larga 1 colonna. Una String usa stile e
    # colori del piano.
    def line_cell!(cell, ptr)
      if cell.is_a?(String)
        # come Cell.new con stili e colori del piano, senza convertirli in simboli e di nuovo in numeri (ICH-594)
        # un carattere ASCII stampabile passa i controlli di Cell.egc! ed è largo 1 colonna
        printable = cell.bytesize == 1 && cell.ascii_only? && cell.match?(PRINTABLE_ASCII_CHAR)
        text = printable ? cell : Cell.egc!(cell)
        cols = printable ? 1 : Util.segments_width(text, [text])
        cell = Cell.from_c(text, FFI.ncplane_styles(ptr), FFI.ncplane_channels(ptr), cols)
      end
      raise TypeError, "cell deve essere Notcurses::Cell o String, non #{cell.class}" unless cell.is_a?(Cell)
      raise ArgumentError, "il carattere #{Util.egc_label(cell.egc)} deve essere largo 1 colonna" unless cell.width == 1

      cell
    end

    # Posizione di partenza di linee, box e riempimenti (nil = cursore).
    def line_start!(y, x, state = WriteState.new(to_ptr))
      Guard.run do
        clear_cut_glyphs!(to_ptr, size: state.dims)
        cell_coords!(y, x, state)
      end
    end

    # Canali di una linea sfumata: entrambi o nessuno.
    def interp_channels!(from, to)
      return [nil, nil] if from.nil? && to.nil?
      raise ArgumentError, 'from: e to: vanno dati insieme' if from.nil? || to.nil?

      [Util.channels_value(from, 'from'), Util.channels_value(to, 'to')]
    end

    # Rettangolo delle funzioni d'area dentro il piano: [y, x, righe, colonne].
    def region!(y, x, rows, cols)
      prows, pcols = dims
      Util.integer!(y, 'y', 0...prows)
      Util.integer!(x, 'x', 0...pcols)
      rows = rows.nil? ? prows - y : Util.integer!(rows, 'rows', 1..(prows - y))
      cols = cols.nil? ? pcols - x : Util.integer!(cols, 'cols', 1..(pcols - x))
      [y, x, rows, cols]
    end

    # Valori dei quattro angoli di gradient/stain (canali a 64 o 32 bit), con
    # i vincoli del C sui colori.
    def corner_values(corners, bits)
      values = corners.each_with_index.map do |c, i|
        bits == 64 ? Util.channels_value(c, CORNERS[i]) : Util.channel_value(c, CORNERS[i])
      end
      if bits == 64
        gradient_channels!(values.map { |v| v >> 32 }, 'primo piano')
        gradient_channels!(values.map { |v| v & 0xffff_ffff }, 'sfondo')
      else
        gradient_channels!(values, 'canale')
      end
      values
    end

    def gradient_channels!(values, which)
      chans = values.map { |v| Channel.new(value: v) }
      raise ArgumentError, "#{which}: o tutti gli angoli hanno il colore di default o nessuno" if chans.map(&:default?).uniq.size > 1
      raise ArgumentError, "#{which}: gli angoli devono avere lo stesso alpha" if chans.map(&:alpha).uniq.size > 1
      raise ArgumentError, "#{which}: i colori di palette non si possono sfumare" if chans.any?(&:palindex?)
    end

    # Vincoli del C sugli angoli di un'area di una riga o di una colonna.
    def corners_shape!(corners, rows, cols, rows_rule:)
      ul, ur, ll, lr = corners
      if rows_rule && rows == 1 && cols == 1
        raise ArgumentError, "in un'area 1x1 i quattro angoli devono essere uguali" unless corners.uniq.size == 1
      elsif rows_rule && rows == 1
        raise ArgumentError, 'con una sola riga servono ul == ll e ur == lr' unless ul == ll && ur == lr
      elsif cols == 1
        raise ArgumentError, 'con una sola colonna servono ul == ur e ll == lr' unless ul == ur && ll == lr
      end
    end

    def box_ctlword(hide, gradient, corners)
      ctl = 0
      Array(hide).each { |side| ctl |= box_side!(side, 'hide').first }
      Array(gradient).each { |side| ctl |= box_side!(side, 'gradient').last }
      ctl | (Util.integer!(corners, 'corners', 0..3) << FFI::NCBOXCORNER_SHIFT)
    end

    def box_side!(side, name)
      BOX_SIDES.fetch(side) { raise ArgumentError, "#{name}: lato #{side.inspect} non valido: usa :top, :right, :bottom o :left" }
    end

    # Le 6 nccell temporanee di un box (ul ur ll lr hl vl). Il blocco riceve
    # prima il piano su cui disegnare: una copia per la prova di {#rehearse!},
    # poi ptr.
    def with_box_cells(ptr, set, styles, channels, &block)
      case set
      when Symbol then with_named_box(ptr, set, Util.styles_value(styles), Util.channels_value(channels), &block)
      when String
        glyphs = Util.string!(set, 'set').grapheme_clusters
        raise ArgumentError, "set: servono 6 caratteri (ul ur ll lr hl vl), non #{glyphs.size}" unless glyphs.size == 6

        box_cells(ptr, glyphs.map { |g| Cell.new(egc: g, styles: styles, channels: channels) }, &block)
      when Array
        raise ArgumentError, 'set: servono 6 Notcurses::Cell (ul ur ll lr hl vl)' unless set.size == 6 && set.all?(Cell)
        unless Util.styles_value(styles).zero? && Util.channels_value(channels).zero?
          raise ArgumentError, 'styles: e channels: non si usano con 6 Cell (ogni Cell ha i suoi)'
        end

        box_cells(ptr, set, &block)
      else raise TypeError, "set deve essere Symbol, String o Array di Cell, non #{set.class}"
      end
    end

    def box_cells(ptr, cells)
      wide = cells.find { |c| c.width != 1 }
      raise ArgumentError, "i glifi del box devono essere larghi 1 colonna: #{Util.egc_label(wide.egc)}" if wide

      with_nccells(ptr, cells) do |*ncs|
        rehearse!(ptr, *cells.map(&:egc)) { |copy| yield(copy, *ncs) }
        yield(ptr, *ncs)
      end
    end

    def with_named_box(ptr, set, mask, chans)
      ncs = Array.new(6) { FFI::NcCell.new }
      rc = case set
           when :light then FFI.nccells_light_box(ptr, mask, chans, *ncs)
           when :heavy then FFI.nccells_heavy_box(ptr, mask, chans, *ncs)
           when :rounded then FFI.nccells_rounded_box(ptr, mask, chans, *ncs)
           when :double then FFI.nccells_double_box(ptr, mask, chans, *ncs)
           when :ascii then FFI.nccells_ascii_box(ptr, mask, chans, *ncs)
           else raise ArgumentError, "set = #{set.inspect} non valido: usa #{BOX_SETS.map(&:inspect).join(', ')}, una String o 6 Cell"
           end
      raise CellError, "nccells_#{set}_box fallita" if rc.negative?

      yield(ptr, *ncs) # i glifi dei set hanno al massimo 3 byte: non passano dall'egcpool, niente prova
    ensure
      ncs&.each { |nc| FFI.nccell_release(ptr, nc) }
    end

    def fade_seconds!(seconds)
      value = Util.float!(seconds, 'seconds')
      raise ArgumentError, "seconds = #{seconds} deve essere > 0" unless value.positive?

      value
    end

    # Passi di una dissolvenza da 0 a fc.iterations in duration secondi: a ogni
    # passo render della pila, blocco, attesa; in ritardo salta i passi
    # scaduti, ma esegue sempre l'ultimo.
    # @return [Symbol, nil] :stop se il blocco ha fermato la dissolvenza
    def fade_steps(fc, kind, duration, block)
      max = fc.iterations
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      step = 0
      loop do
        kind == :fadeout ? fc.fadeout(step) : fc.fadein(step)
        render_pile
        return :stop if block && block.call(self) == :stop
        return nil if step >= max

        pause = (duration * (step + 1) / max) - (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start)
        sleep(pause) if pause.positive?
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
        step = [[(elapsed * max / duration).floor, step + 1].max, max].min
      end
    end

    public

    # Un wrapper chiuso è uguale solo ai wrapper nati nella sua stessa
    # generazione: il C può dare l'indirizzo di un piano distrutto a un piano nuovo.
    # @param other [Object] oggetto da confrontare
    # @return [Boolean] stesso piano C (anche con wrapper diversi)
    def ==(other)
      return false unless other.is_a?(Plane) && other.address == address && other.context.equal?(@context)

      (!closed? && !other.closed?) || other.born == @born
    end
    alias eql? ==

    # @return [Integer]
    def hash = [Plane, address].hash

    protected

    # @return [Integer] generazione del contesto alla creazione del wrapper
    attr_reader :born

    # Colonne dell'ultimo controllo dei bordi (vedi clear_cut_glyphs!); nil =
    # la prossima scrittura controlla di nuovo.
    # @return [Integer, nil]
    attr_accessor :cut_glyphs_cols
  end

  # Fotografia dei colori di un piano per una dissolvenza passo per passo
  # (+struct ncfadectx*+), da {Plane#fade_context}.
  #
  # Ogni passo cambia i colori del piano e basta: il render (per esempio
  # {Plane#render_pile}) e l'attesa tra i passi sono del chiamante. La
  # fotografia è solo memoria, non dipende dalla vita del piano o del
  # contesto: {#close} la libera, e se dimentichi di chiuderla la libera il GC.
  #
  # Bug noto di 3.0.17 non aggirato: su un piano che ha già fatto scroll i
  # colori fotografati vengono applicati alle righe sbagliate. Dopo un resize
  # del piano i colori non corrispondono più (senza rischi per la memoria).
  #
  # @example
  #   plane.fade_context do |fc|
  #     0.upto(fc.iterations) do |i|
  #       fc.fadeout(i)
  #       plane.render_pile
  #       sleep 0.01
  #     end
  #   end
  class FadeContext
    include Resource

    RELEASER = ->(ptr) { FFI.ncfadectx_free(ptr) }
    private_constant :RELEASER

    # Callback dei passi: senza callback il C renderizza la pila standard (non
    # quella del piano) e dorme tenendo il GVL.
    NOOP_FADER = ::FFI::Function.new(:int, %i[pointer pointer pointer pointer]) { 0 }
    private_constant :NOOP_FADER

    # @return [Plane] piano fotografato
    attr_reader :plane

    # @return [Integer] numero di passi, 1..255 (la componente di colore più
    #   alta del piano)
    attr_reader :iterations

    # Fotografa i colori del piano (+ncfadectx_setup+).
    #
    # @param plane [Plane]
    # @raise [TypeError] se plane non è un Plane
    # @raise [PlaneError] se il terminale non permette le dissolvenze
    # @raise [ClosedError] se il piano è chiuso
    def initialize(plane)
      Guard.run do
        raise TypeError, "plane deve essere Notcurses::Plane, non #{plane.class}" unless plane.is_a?(Plane)

        raw = FFI.ncfadectx_setup(plane.to_ptr)
        raise PlaneError, 'ncfadectx_setup ha restituito NULL: il terminale non permette le dissolvenze' if raw.null?

        @ptr = ::FFI::AutoPointer.new(raw, RELEASER)
        @plane = plane
        @iterations = FFI.ncfadectx_iterations(@ptr)
        @closed = false
        @owner = nil
      end
    end

    # Libera la fotografia (+ncfadectx_free+). Idempotente.
    # @return [nil]
    def close
      Guard.run do
        return nil if @closed

        @closed = true
        @ptr.free
        nil
      end
    end
    alias free close

    # Colori di un passo verso il nero (+ncplane_fadeout_iteration+): 0 =
    # colori fotografati, {#iterations} = nero. Cambia anche la cella base.
    #
    # @param iteration [Integer] 0..iterations
    # @return [self]
    # @raise [TypeError, ArgumentError] se iteration è fuori intervallo
    # @raise [PlaneError] se notcurses segnala un errore
    # @raise [ClosedError] se la fotografia o il piano sono chiusi
    def fadeout(iteration)
      Guard.run do
        rc = FFI.ncplane_fadeout_iteration(@plane.to_ptr, to_ptr, iteration!(iteration), NOOP_FADER, nil)
        Util.check!(rc, PlaneError, 'ncplane_fadeout_iteration')
        self
      end
    end

    # Colori di un passo dal nero (+ncplane_fadein_iteration+): 0 = nero,
    # {#iterations} = colori fotografati. La cella base non cambia.
    #
    # @param iteration [Integer] 0..iterations
    # @return [self]
    # @raise [TypeError, ArgumentError] se iteration è fuori intervallo
    # @raise [PlaneError] se notcurses segnala un errore
    # @raise [ClosedError] se la fotografia o il piano sono chiusi
    def fadein(iteration)
      Guard.run do
        rc = FFI.ncplane_fadein_iteration(@plane.to_ptr, to_ptr, iteration!(iteration), NOOP_FADER, nil)
        Util.check!(rc, PlaneError, 'ncplane_fadein_iteration')
        self
      end
    end

    private

    # fuori da 0..iterations il C schiarisce oltre l'originale o non cambia nulla
    def iteration!(value) = Util.integer!(value, 'iteration', 0..@iterations)
  end
end
