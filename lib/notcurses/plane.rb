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

    # Spazi tra le parole per {#puttext} (senza gli spazi non separabili).
    WORD_SPACES = /[\p{Zs}&&[^   ]]+/
    private_constant :WORD_SPACES

    CORNERS = %w[ul ur ll lr].freeze
    private_constant :CORNERS

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
    # @return [nil]
    # @raise [PlaneError] dentro un callback chiamato da notcurses, o se
    #   notcurses segnala un errore nel riaggancio dei figli (in questo caso il
    #   piano risulta comunque distrutto)
    def close
      return nil if closed? || !@owned

      ctx = @context
      ctx.check_not_in_callback!('Plane#close', PlaneError)
      rc = FFI.ncplane_destroy(@ptr)
      invalidate!
      ctx.planes_destroyed!
      Util.check!(rc, PlaneError, 'ncplane_destroy')
      nil
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
      opts, keep = Plane.build_options(context: @context, parent_dims: dims, rows: rows, cols: cols, y: y, x: x,
                                       margins: margins, name: name, fixed: fixed, autogrow: autogrow,
                                       vscroll: vscroll, resize: resize)
      ptr = FFI.ncplane_create(to_ptr, opts)
      Util.check_ptr!(ptr, PlaneError, 'ncplane_create')
      child = Plane.new(ptr, owned: true, context: @context)
      child.adopt_options!(keep)
      Util.with_resource(child, &block)
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
    # contesto e il C riceve -1.
    # @api private
    # @return [::FFI::Function]
    def self.ruby_resize_function(context, callable)
      box = context.callback_errors
      ::FFI::Function.new(:int, [:pointer]) do |plane_ptr|
        Util.guard(box, -1) do
          context.callback_scope { callable.call(context.plane_for(plane_ptr)) }
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
    # autogrow; il wrapper sposta la copia e ripristina i due flag. Non si
    # possono ripristinare il flag fixed e l'allineamento verticale (per
    # {#resize_realign}). Un callback di resize interno di un widget non viene
    # copiato (con il C la copia andrebbe in crash al primo resize).
    #
    # @return [Plane] il duplicato; con un blocco, il valore del blocco (il
    #   duplicato viene distrutto alla fine)
    # @raise [PlaneError] se +ncplane_dup+ fallisce
    # @raise [ClosedError] se il piano è chiuso
    def duplicate(&block)
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
      Util.with_resource(copy, &block)
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
    # resize: :maximize; lì la cella si svuota alla prima scrittura sul piano.
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
      Util.integer!(rows, 'rows', 1..Util::UINT32.max)
      Util.integer!(cols, 'cols', 1..Util::UINT32.max)
      ptr = to_ptr
      rc = FFI.ncplane_resize_simple(ptr, rows, cols)
      clear_cut_glyphs!(ptr, force: true)
      @context.raise_callback_errors!
      Util.check!(rc, PlaneError, 'ncplane_resize_simple')
      self
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
    # conservata (il C sposta l'origine ma non il contenuto). Bug non
    # aggirato: con keep_x > 0 gli EGC di più di 4 byte nella regione
    # conservata possono risultare corrotti.
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
      rc = FFI.ncplane_resize(ptr, keep_y, keep_x, keep_rows, keep_cols, y_off, x_off, rows, cols)
      clear_cut_glyphs!(ptr, force: true) # con keep_x > 0 il contenuto si sposta anche a dimensioni invariate
      @context.raise_callback_errors!
      Util.check!(rc, PlaneError, 'ncplane_resize')
      self
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
      ptr = to_ptr
      rc = FFI.ncplane_resize_maximize(ptr)
      clear_cut_glyphs!(ptr, force: true)
      @context.raise_callback_errors!
      Util.check!(rc, PlaneError, 'ncplane_resize_maximize')
      self
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
      ptr = to_ptr
      raise PlaneError, 'resize_marginalized: il piano non è stato creato con margins:' unless @margins

      parent_ptr = FFI.ncplane_parent(ptr)
      area = parent_ptr.address == address ? @context.dims : [FFI.ncplane_dim_y(parent_ptr), FFI.ncplane_dim_x(parent_ptr)]
      rows, cols = Plane.marginalized_dims(area, @margins)
      resize(rows, cols) unless [rows, cols] == dims
      move(@margins[0], @margins[3])
    end

    # Riallinea il piano al genitore secondo gli allineamenti di creazione
    # (y:/x: simbolici) (+ncplane_resize_realign+).
    #
    # @return [self]
    # @raise [PlaneError] se il piano è una radice o non è allineato
    # @raise [ClosedError] se il piano è chiuso
    def resize_realign
      ptr = to_ptr
      raise PlaneError, 'resize_realign: una radice non ha un genitore a cui allinearsi' if root?

      Util.check!(FFI.ncplane_resize_realign(ptr), PlaneError, 'ncplane_resize_realign')
      self
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

    # Callback di resize corrente (+ncplane_resizecb+).
    #
    # @return [Symbol, #call, ::FFI::Pointer, nil] uno dei {RESIZE_CALLBACKS},
    #   l'oggetto Ruby impostato dal wrapper, un puntatore a una funzione C che
    #   il wrapper non conosce (per esempio di un widget), o nil
    # @raise [ClosedError] se il piano è chiuso
    def resize_callback
      fn = FFI.ncplane_resizecb(to_ptr)
      return nil if fn.null?
      return @resize if own_resize_function?(fn)

      native_resize_symbol(fn) || fn
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

    # --- nome, genitore, contesto ---

    # Nome del piano (+ncplane_name+).
    # @return [String, nil]
    # @raise [ClosedError] se il piano è chiuso
    def name = Util.take_string(FFI.ncplane_name(to_ptr))

    # Cambia il nome del piano (+ncplane_set_name+).
    #
    # @param name [String, nil] nuovo nome, nil per toglierlo
    # @raise [PlaneError] se la copia del nome fallisce
    # @raise [TypeError, ArgumentError] se name non è una String valida
    # @raise [ClosedError] se il piano è chiuso
    def name=(name)
      Util.check!(FFI.ncplane_set_name(to_ptr, Util.string_or_nil!(name, 'name')), PlaneError, 'ncplane_set_name')
    end

    # Piano a cui questo è legato (+ncplane_parent+).
    # @return [Plane, nil] nil se il piano è la radice di una pila
    # @raise [ClosedError] se il piano è chiuso
    def parent
      ptr = FFI.ncplane_parent(to_ptr)
      ptr.address == address ? nil : @context.plane_for(ptr)
    end

    # @return [Boolean] true se il piano è la radice di una pila
    # @raise [ClosedError] se il piano è chiuso
    def root? = FFI.ncplane_parent(to_ptr).address == address

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
      target = same_context_plane!(new_parent, 'new_parent')
      @context.check_not_in_callback!('Plane#reparent', PlaneError)
      Util.check_ptr!(FFI.ncplane_reparent(to_ptr, target), PlaneError, 'ncplane_reparent')
      self
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
      target = same_context_plane!(new_parent, 'new_parent')
      @context.check_not_in_callback!('Plane#reparent_family', PlaneError)
      Util.check_ptr!(FFI.ncplane_reparent_family(to_ptr, target), PlaneError, 'ncplane_reparent_family')
      self
    end

    # @param ancestor [Plane]
    # @return [Boolean] true se il piano discende da ancestor (+ncplane_descendant_p+)
    # @raise [TypeError] se ancestor non è un Plane
    # @raise [ClosedError] se uno dei piani è chiuso
    def descendant_of?(ancestor)
      FFI.ncplane_descendant_p(to_ptr, same_context_plane!(ancestor, 'ancestor')) != 0
    end

    # --- pila e render ---

    # @return [Plane] piano in cima alla pila di questo piano (+ncpile_top+)
    # @raise [ClosedError] se il piano è chiuso
    def pile_top = @context.plane_for(FFI.ncpile_top(to_ptr))

    # @return [Plane] piano in fondo alla pila di questo piano (+ncpile_bottom+)
    # @raise [ClosedError] se il piano è chiuso
    def pile_bottom = @context.plane_for(FFI.ncpile_bottom(to_ptr))

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

    # --- geometria ---

    # @return [Integer] righe (+ncplane_dim_y+)
    # @raise [ClosedError] se il piano è chiuso
    def dim_y = FFI.ncplane_dim_y(to_ptr)

    # @return [Integer] colonne (+ncplane_dim_x+)
    # @raise [ClosedError] se il piano è chiuso
    def dim_x = FFI.ncplane_dim_x(to_ptr)

    # @return [Array(Integer, Integer)] [righe, colonne] (+ncplane_dim_yx+)
    # @raise [ClosedError] se il piano è chiuso
    def dims
      rows = ::FFI::MemoryPointer.new(:uint)
      cols = ::FFI::MemoryPointer.new(:uint)
      FFI.ncplane_dim_yx(to_ptr, rows, cols)
      [rows.read_uint, cols.read_uint]
    end

    # Geometria in pixel (+ncplane_pixel_geom+).
    #
    # @return [Hash{Symbol => Integer}] :pixel_y e :pixel_x (area di
    #   visualizzazione), :cell_pixel_y e :cell_pixel_x (una cella),
    #   :max_bitmap_y e :max_bitmap_x (bitmap massima, 0 = nessun limite o
    #   bitmap non supportate)
    # @raise [ClosedError] se il piano è chiuso
    def pixel_geom
      ptrs = Array.new(6) { ::FFI::MemoryPointer.new(:uint) }
      FFI.ncplane_pixel_geom(to_ptr, *ptrs)
      y, x, cy, cx, my, mx = ptrs.map(&:read_uint)
      { pixel_y: y, pixel_x: x, cell_pixel_y: cy, cell_pixel_x: cx, max_bitmap_y: my, max_bitmap_x: mx }.freeze
    end

    # @return [Array(Integer, Integer)] origine rispetto al genitore (o alla
    #   pila, per una radice) (+ncplane_yx+)
    # @raise [ClosedError] se il piano è chiuso
    def yx
      y = ::FFI::MemoryPointer.new(:int)
      x = ::FFI::MemoryPointer.new(:int)
      FFI.ncplane_yx(to_ptr, y, x)
      [y.read_int, x.read_int]
    end

    # @return [Integer] riga dell'origine rispetto al genitore (+ncplane_y+)
    # @raise [ClosedError] se il piano è chiuso
    def y = FFI.ncplane_y(to_ptr)

    # @return [Integer] colonna dell'origine rispetto al genitore (+ncplane_x+)
    # @raise [ClosedError] se il piano è chiuso
    def x = FFI.ncplane_x(to_ptr)

    # @return [Array(Integer, Integer)] origine rispetto alla pila (+ncplane_abs_yx+)
    # @raise [ClosedError] se il piano è chiuso
    def abs_yx
      y = ::FFI::MemoryPointer.new(:int)
      x = ::FFI::MemoryPointer.new(:int)
      FFI.ncplane_abs_yx(to_ptr, y, x)
      [y.read_int, x.read_int]
    end

    # @return [Integer] riga dell'origine rispetto alla pila (+ncplane_abs_y+)
    # @raise [ClosedError] se il piano è chiuso
    def abs_y = FFI.ncplane_abs_y(to_ptr)

    # @return [Integer] colonna dell'origine rispetto alla pila (+ncplane_abs_x+)
    # @raise [ClosedError] se il piano è chiuso
    def abs_x = FFI.ncplane_abs_x(to_ptr)

    # Centro del piano, in coordinate assolute (+ncplane_center_abs+); con un
    # numero pari di righe o colonne preferisce l'alto/sinistra.
    # @return [Array(Integer, Integer)] [y, x]
    # @raise [ClosedError] se il piano è chiuso
    def center_abs
      y = ::FFI::MemoryPointer.new(:int)
      x = ::FFI::MemoryPointer.new(:int)
      FFI.ncplane_center_abs(to_ptr, y, x)
      [y.read_int, x.read_int]
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
      target = dst.nil? ? ::FFI::Pointer::NULL : same_context_plane!(dst, 'dst')
      yp = ::FFI::MemoryPointer.new(:int)
      xp = ::FFI::MemoryPointer.new(:int)
      yp.write_int(Util.int!(y, 'y'))
      xp.write_int(Util.int!(x, 'x'))
      FFI.ncplane_translate(to_ptr, target, yp, xp)
      [yp.read_int, xp.read_int]
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
      yp = ::FFI::MemoryPointer.new(:int)
      xp = ::FFI::MemoryPointer.new(:int)
      yp.write_int(Util.int!(y, 'y'))
      xp.write_int(Util.int!(x, 'x'))
      inside = FFI.ncplane_translate_abs(to_ptr, yp, xp)
      [yp.read_int, xp.read_int, inside]
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
      Util.integer!(cols, 'cols', Util::NONNEG_INT)
      FFI.ncplane_halign(to_ptr, Util.placement_align_value(align), cols)
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
      Util.integer!(rows, 'rows', Util::NONNEG_INT)
      FFI.ncplane_valign(to_ptr, Util.placement_align_value(align), rows)
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
      Util.check!(FFI.ncplane_move_yx(to_ptr, Util.int!(y, 'y'), Util.int!(x, 'x')), PlaneError, 'ncplane_move_yx')
      self
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
      Util.check!(FFI.ncplane_move_rel(to_ptr, Util.int!(dy, 'dy'), Util.int!(dx, 'dx')), PlaneError, 'ncplane_move_rel')
      self
    end

    # Porta il piano in cima alla pila (+ncplane_move_top+).
    # @return [self]
    # @raise [ClosedError] se il piano è chiuso
    def move_top
      FFI.ncplane_move_top(to_ptr)
      self
    end

    # Porta il piano in fondo alla pila (+ncplane_move_bottom+).
    # @return [self]
    # @raise [ClosedError] se il piano è chiuso
    def move_bottom
      FFI.ncplane_move_bottom(to_ptr)
      self
    end

    # Porta il piano e i suoi figli in cima alla pila (+ncplane_move_family_top+).
    # @return [self]
    # @raise [ClosedError] se il piano è chiuso
    def move_family_top
      FFI.ncplane_move_family_top(to_ptr)
      self
    end

    # Porta il piano e i suoi figli in fondo alla pila (+ncplane_move_family_bottom+).
    # @return [self]
    # @raise [ClosedError] se il piano è chiuso
    def move_family_bottom
      FFI.ncplane_move_family_bottom(to_ptr)
      self
    end

    # Mette il piano subito sopra other (+ncplane_move_above+).
    #
    # @param other [Plane, nil] piano della stessa pila; nil = in fondo alla pila
    # @return [self]
    # @raise [PlaneError] se other è il piano stesso o è in un'altra pila
    # @raise [TypeError] se other non è un Plane
    # @raise [ClosedError] se uno dei piani è chiuso
    def move_above(other)
      target = other.nil? ? ::FFI::Pointer::NULL : same_context_plane!(other, 'other')
      Util.check!(FFI.ncplane_move_above(to_ptr, target), PlaneError, 'ncplane_move_above')
      self
    end

    # Mette il piano subito sotto other (+ncplane_move_below+).
    #
    # @param other [Plane, nil] piano della stessa pila; nil = in cima alla pila
    # @return [self]
    # @raise [PlaneError] se other è il piano stesso o è in un'altra pila
    # @raise [TypeError] se other non è un Plane
    # @raise [ClosedError] se uno dei piani è chiuso
    def move_below(other)
      target = other.nil? ? ::FFI::Pointer::NULL : same_context_plane!(other, 'other')
      Util.check!(FFI.ncplane_move_below(to_ptr, target), PlaneError, 'ncplane_move_below')
      self
    end

    # Come {#move_above}, con i figli del piano (+ncplane_move_family_above+).
    #
    # @param other [Plane, nil] piano della stessa pila; nil = in fondo alla pila
    # @return [self]
    # @raise [PlaneError] se lo spostamento fallisce
    # @raise [TypeError] se other non è un Plane
    # @raise [ClosedError] se uno dei piani è chiuso
    def move_family_above(other)
      target = other.nil? ? ::FFI::Pointer::NULL : same_context_plane!(other, 'other')
      Util.check!(FFI.ncplane_move_family_above(to_ptr, target), PlaneError, 'ncplane_move_family_above')
      self
    end

    # Come {#move_below}, con i figli del piano (+ncplane_move_family_below+).
    #
    # @param other [Plane, nil] piano della stessa pila; nil = in cima alla pila
    # @return [self]
    # @raise [PlaneError] se lo spostamento fallisce
    # @raise [TypeError] se other non è un Plane
    # @raise [ClosedError] se uno dei piani è chiuso
    def move_family_below(other)
      target = other.nil? ? ::FFI::Pointer::NULL : same_context_plane!(other, 'other')
      Util.check!(FFI.ncplane_move_family_below(to_ptr, target), PlaneError, 'ncplane_move_family_below')
      self
    end

    # @return [Plane, nil] piano subito sotto nello z-order (+ncplane_below+)
    # @raise [ClosedError] se il piano è chiuso
    def below = @context.plane_for(FFI.ncplane_below(to_ptr))

    # @return [Plane, nil] piano subito sopra nello z-order (+ncplane_above+)
    # @raise [ClosedError] se il piano è chiuso
    def above = @context.plane_for(FFI.ncplane_above(to_ptr))

    # --- scrolling ---

    # Abilita o disabilita lo scrolling (+ncplane_set_scrolling+).
    #
    # @param enabled [Boolean]
    # @raise [TypeError] se enabled non è true o false
    # @raise [ClosedError] se il piano è chiuso
    def scrolling=(enabled)
      FFI.ncplane_set_scrolling(to_ptr, Util.c_bool(enabled, 'enabled'))
    end

    # @return [Boolean] true se il piano scorre (+ncplane_scrolling_p+)
    # @raise [ClosedError] se il piano è chiuso
    def scrolling? = FFI.ncplane_scrolling_p(to_ptr)

    # Abilita o disabilita la crescita automatica (+ncplane_set_autogrow+):
    # l'output oltre il bordo fa crescere il piano (in basso se il piano
    # scorre, a destra altrimenti) invece di fallire o scorrere.
    #
    # @param enabled [Boolean]
    # @raise [PlaneError] sullo stdplane (il C ignora la richiesta)
    # @raise [TypeError] se enabled non è true o false
    # @raise [ClosedError] se il piano è chiuso
    def autogrow=(enabled)
      ptr = to_ptr
      value = Util.c_bool(enabled, 'enabled')
      raise PlaneError, "l'autogrow dello stdplane non si può cambiare" if stdplane?

      FFI.ncplane_set_autogrow(ptr, value)
    end

    # @return [Boolean] true se il piano cresce da solo (+ncplane_autogrow_p+)
    # @raise [ClosedError] se il piano è chiuso
    def autogrow? = FFI.ncplane_autogrow_p(to_ptr)

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
      ptr = to_ptr
      Util.integer!(lines, 'lines', 1..Util::INT32.max)
      raise PlaneError, 'scrollup: il piano non ha lo scrolling attivo' unless scrolling?

      FFI.ncplane_cursor_move_yx(ptr, dim_y - 1, 0)
      rc = FFI.ncplane_scrollup(ptr, lines)
      @context.raise_callback_errors!
      Util.check!(rc, PlaneError, 'ncplane_scrollup')
      self
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
      rc = FFI.ncplane_scrollup_child(to_ptr, same_context_plane!(child, 'child'))
      @context.raise_callback_errors!
      Util.check!(rc, PlaneError, 'ncplane_scrollup_child')
      self
    end

    # Ruota il piano di 90° in senso orario (+ncplane_rotate_cw+): le righe
    # diventano colonne/2 e le colonne righe*2, l'origine non cambia. Servono
    # un numero pari di colonne e celle con soli "", " ", "▀", "▄" o "█"; la
    # rotazione perde informazione (cw e poi ccw non restituisce l'originale).
    #
    # @return [self]
    # @raise [PlaneError] se la rotazione non è possibile (anche sullo
    #   stdplane) o se fallisce un callback nativo di un figlio (il piano resta
    #   ridimensionato e vuoto)
    # @raise [ClosedError] se il piano è chiuso
    def rotate_cw
      rc = FFI.ncplane_rotate_cw(to_ptr)
      @context.raise_callback_errors!
      Util.check!(rc, PlaneError, 'ncplane_rotate_cw')
      self
    end

    # Ruota il piano di 90° in senso antiorario (+ncplane_rotate_ccw+), con le
    # stesse regole di {#rotate_cw}.
    #
    # @return [self]
    # @raise [PlaneError] se la rotazione non è possibile
    # @raise [ClosedError] se il piano è chiuso
    def rotate_ccw
      rc = FFI.ncplane_rotate_ccw(to_ptr)
      @context.raise_callback_errors!
      Util.check!(rc, PlaneError, 'ncplane_rotate_ccw')
      self
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
      ptr = to_ptr
      cy, cx = cursor
      y = y.nil? ? cy : Util.int!(y, 'y')
      x = x.nil? ? cx : Util.int!(x, 'x')
      cursor_target!(y, x)
      Util.check!(FFI.ncplane_cursor_move_yx(ptr, y, x), PlaneError, "ncplane_cursor_move_yx(#{y}, #{x})")
      self
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
      ptr = to_ptr
      Util.int!(dy, 'dy')
      Util.int!(dx, 'dx')
      cy, cx = cursor
      cursor_target!(cy + dy, cx + dx)
      Util.check!(FFI.ncplane_cursor_move_rel(ptr, dy, dx), PlaneError, "ncplane_cursor_move_rel(#{dy}, #{dx})")
      self
    end

    # Porta il cursore in (0, 0) (+ncplane_home+).
    # @return [self]
    # @raise [ClosedError] se il piano è chiuso
    def home
      FFI.ncplane_home(to_ptr)
      self
    end

    # @return [Array(Integer, Integer)] posizione del cursore [y, x] (+ncplane_cursor_yx+)
    # @raise [ClosedError] se il piano è chiuso
    def cursor
      y = ::FFI::MemoryPointer.new(:uint)
      x = ::FFI::MemoryPointer.new(:uint)
      FFI.ncplane_cursor_yx(to_ptr, y, x)
      [y.read_uint, x.read_uint]
    end
    alias cursor_yx cursor

    # @return [Integer] riga del cursore (+ncplane_cursor_y+)
    # @raise [ClosedError] se il piano è chiuso
    def cursor_y = FFI.ncplane_cursor_y(to_ptr)

    # @return [Integer] colonna del cursore (+ncplane_cursor_x+)
    # @raise [ClosedError] se il piano è chiuso
    def cursor_x = FFI.ncplane_cursor_x(to_ptr)

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
    # @param y [Integer, nil] riga; nil = riga del cursore
    # @param x [Integer, nil] colonna; nil = colonna del cursore
    # @return [Cell]
    # @raise [ArgumentError, TypeError] se le coordinate sono fuori dal piano
    #   o non sono Integer
    # @raise [PlaneError] se il cursore è oltre l'ultima colonna, o se la
    #   lettura fallisce
    # @raise [ClosedError] se il piano è chiuso
    def at(y: nil, x: nil)
      ptr = to_ptr
      y, x = cell_coords!(y, x)
      x -= 1 while x.positive? && wide_right?(ptr, y, x)
      return base if wide_right?(ptr, y, x)

      styles = ::FFI::MemoryPointer.new(:uint16)
      channels = ::FFI::MemoryPointer.new(:uint64)
      egc = FFI.ncplane_at_yx(ptr, y, x, styles, channels)
      Util.check_ptr!(egc, PlaneError, "ncplane_at_yx(#{y}, #{x})")
      Cell.from_c(Util.take_string(egc), styles.read_uint16, channels.read_uint64)
    end

    # Cella base (+ncplane_base+): il contenuto mostrato dove il piano non ha
    # scritto nulla.
    #
    # @return [Cell]
    # @raise [PlaneError] se la lettura fallisce
    # @raise [ClosedError] se il piano è chiuso
    def base
      ptr = to_ptr
      cell = FFI::NcCell.new
      begin
        Util.check!(FFI.ncplane_base(ptr, cell), PlaneError, 'ncplane_base')
        cell_content(ptr, cell)
      ensure
        FFI.nccell_release(ptr, cell)
      end
    end

    # Imposta la cella base (+ncplane_set_base+).
    #
    # @param egc [String] un solo grapheme cluster ("" = nessun carattere)
    # @param styles [Integer, Symbol, Array<Symbol>] stili
    # @param channels [Channels, Integer] colori
    # @return [self]
    # @raise [PlaneError] se notcurses rifiuta l'EGC
    # @raise [TypeError, ArgumentError] se un argomento non è valido (più di un
    #   grapheme cluster, caratteri di controllo, ...)
    # @raise [ClosedError] se il piano è chiuso
    def set_base(egc: ' ', styles: 0, channels: 0)
      ptr = to_ptr
      text = Cell.egc!(egc)
      mask = Util.styles_value(styles)
      chans = Util.channels_value(channels)
      Util.check!(FFI.ncplane_set_base(ptr, text, mask, chans), PlaneError, 'ncplane_set_base')
      self
    end

    # Testo del piano in una regione, riga dopo riga, senza separatori di riga
    # e senza le celle vuote; un glifo largo compare una volta (come
    # +ncplane_contents+). Salta anche la cella "\n" che notcurses 3.0.17
    # lascia sotto il cursore dopo un a capo (vedi {#at}).
    #
    # Bug di 3.0.17 aggirato: +ncplane_contents+ lascia nell'egcpool del piano
    # una copia di ogni EGC di più di 4 byte a ogni chiamata (il pool cresce
    # fino al limite di 16 MiB): il wrapper legge le celle una per una con
    # +ncplane_at_yx_cell+ e le rilascia.
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
            raise PlaneError, "ncplane_at_yx_cell(#{yy}, #{xx}) fallita" if len.negative?

            egc = FFI.nccell_extended_gcluster(ptr, cell)
            out << egc if len.positive? && egc != "\n" # la cella che ncplane_put lascia dopo un a capo
          end
        end
      ensure
        FFI.nccell_release(ptr, cell)
      end
      out.force_encoding(Encoding::UTF_8)
    end

    # Cancella tutto il piano (+ncplane_erase+): celle vuote, cursore in
    # (0, 0). Restano la cella base, lo stile e i colori del piano.
    #
    # @return [self]
    # @raise [ClosedError] se il piano è chiuso
    def erase
      FFI.ncplane_erase(to_ptr)
      self
    end

    # Cancella un rettangolo di celle (+ncplane_erase_region+), dalla cella
    # (y, x) compresa verso destra e verso il basso, tagliato al bordo. Le
    # celle tornano vuote con stile e colori di default. Cancellare metà di un
    # glifo largo lascia l'altra metà orfana.
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
      ptr = to_ptr
      prows, pcols = dims
      Util.integer!(y, 'y', 0...prows)
      Util.integer!(x, 'x', 0...pcols)
      Util.integer!(rows, 'rows', 1..Util::INT32.max)
      Util.integer!(cols, 'cols', 1..Util::INT32.max)
      Util.check!(FFI.ncplane_erase_region(ptr, y, x, rows, cols), PlaneError, 'ncplane_erase_region')
      self
    end

    # Fonde questo piano sopra dst (+ncplane_mergedown_simple+): dst prende il
    # risultato del render dei due piani nelle loro posizioni (alpha, cella
    # base, ...); questo piano non cambia.
    #
    # Bug di 3.0.17: +ncplane_mergedown+ ignora la regione che riceve, quindi
    # il wrapper offre solo la fusione completa.
    #
    # @param dst [Plane] piano di destinazione, della stessa pila
    # @return [self]
    # @raise [PlaneError] se dst è il piano stesso o sta in un'altra pila, o se
    #   la fusione fallisce (per esempio con un bitmap)
    # @raise [TypeError] se dst non è un Plane
    # @raise [ClosedError] se uno dei piani è chiuso
    def merge_down(dst)
      ptr = to_ptr
      target = same_context_plane!(dst, 'dst')
      raise PlaneError, 'merge_down: dst è il piano stesso' if target.address == ptr.address
      raise PlaneError, "merge_down: dst è in un'altra pila" unless FFI.ncpile_top(ptr).address == FFI.ncpile_top(target).address

      Util.check!(FFI.ncplane_mergedown_simple(ptr, target), PlaneError, 'ncplane_mergedown_simple')
      # glifi larghi nuovi senza le scritture: un resize del C li può tagliare a dimensioni già controllate
      [dst, @context.tracked_plane(target.address)].compact.each { |plane| plane.forget_cut_glyphs! }
      self
    end

    # Converte in grigio i colori delle celle (+ncplane_greyscale+). I colori
    # di default e di palette diventano RGB espliciti (un default diventa
    # nero); la cella base e i colori del piano non cambiano.
    #
    # @return [self]
    # @raise [ClosedError] se il piano è chiuso
    def greyscale
      FFI.ncplane_greyscale(to_ptr)
      self
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
        FFI.free(buf)
      end
    end

    # Disegna un codice QR dal cursore in poi (+ncplane_qrcode+), in un'area
    # di al massimo rows x cols celle.
    #
    # La build di notcurses senza qrcodegen (per esempio quella di Arch Linux)
    # ha solo uno stub che fallisce: in quel caso il metodo solleva sempre
    # PlaneError.
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
      version = FFI.ncplane_qrcode(ptr, ymax, xmax, buf, bytes.bytesize)
      Util.check!(version, PlaneError, 'ncplane_qrcode (notcurses compilato senza qrcodegen?)')
      [version, ymax.read_uint, xmax.read_uint]
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
    #   un byte).
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
    # @raise [PlaneError] se il testo non entra nel piano, o se notcurses
    #   rifiuta la scrittura (per esempio su un piano con un bitmap)
    # @raise [RenderError] su uno stdplane che scorre, se fallisce il render
    #   che prima della scrittura lo porta alle dimensioni del terminale
    # @raise [Exception] l'eccezione di un callback Ruby di resize (crescita
    #   per autogrow, render dello stdplane che scorre)
    # @raise [ClosedError] se il piano è chiuso
    def putstr(text, y: nil, x: nil, align: nil, stained: false)
      ptr = to_ptr
      str = output_text!(ptr, text, 'text')
      raise ArgumentError, 'putstr: usa x: oppure align:, non entrambi' if x && align

      Util.bool!(stained, 'stained')
      return 0 if str.empty?

      if dim_x == 1 && str.each_grapheme_cluster.any? { |g| Notcurses.strwidth(g) > 1 }
        raise PlaneError, 'un carattere largo 2 colonne non entra in un piano largo 1'
      end

      segments = Util.zwj_segments(str).flat_map { |seg| seg.split(/(?=\n)/) }
      widths = segments.map { |seg| Notcurses.strwidth(seg) }
      first = Notcurses.strwidth(str.grapheme_clusters.first)
      sync_scrolling_stdplane!(ptr, str.include?("\n") || widths.sum > dim_x - (x.is_a?(Integer) ? x : cursor_x))
      ty, tx = text_target!(str, widths.sum, first, y: y, x: x, align: align, stained: stained)
      written = 0
      segments.each_with_index do |seg, i|
        # lo scroll dello stdplane fa un render, che può restringerlo a metà testo
        clear_cut_glyphs!(ptr) if i.positive?
        # "\n" con il cursore oltre l'ultima colonna: due a capo nel C (vedi il YARD)
        if seg.start_with?("\n") && (i.positive? || tx == -1) && cursor_x == dim_x
          Util.check!(FFI.ncplane_cursor_move_yx(ptr, i.zero? ? ty : -1, dim_x - 1), PlaneError, 'ncplane_cursor_move_yx')
        end
        rc = if stained then FFI.ncplane_putstr_stained(ptr, seg)
             elsif i.zero? then FFI.ncplane_putstr_yx(ptr, ty, tx, seg)
             else FFI.ncplane_putstr(ptr, seg)
             end
        @context.raise_callback_errors!
        written += rc.abs
        raise PlaneError, "putstr: notcurses ha scritto #{written} colonne su #{widths.sum}" unless rc == widths[i]
      end
      written
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
    # @raise [PlaneError] se il carattere non entra nel piano, o se notcurses
    #   rifiuta la scrittura
    # @raise [Exception] l'eccezione di un callback Ruby di resize
    # @raise [ClosedError] se il piano è chiuso
    def putegc(egc, y: nil, x: nil, stained: false)
      ptr = to_ptr
      text = Cell.egc!(egc)
      raise ArgumentError, 'egc vuoto: serve un carattere' if text.empty?

      output_text!(ptr, text, 'egc')
      Util.bool!(stained, 'stained')
      single_egc!(ptr, text)
      cols = Notcurses.strwidth(text)
      ty, tx = text_target!(text, cols, cols, y: y, x: x, align: nil, stained: stained)
      rc = stained ? FFI.ncplane_putegc_stained(ptr, text, nil) : FFI.ncplane_putegc_yx(ptr, ty, tx, text, nil)
      @context.raise_callback_errors!
      Util.check!(rc, PlaneError, "ncplane_putegc_yx(#{text.inspect})")
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
    # @raise [PlaneError] se la cella non entra nel piano, o se notcurses
    #   rifiuta la scrittura
    # @raise [Exception] l'eccezione di un callback Ruby di resize
    # @raise [ClosedError] se il piano è chiuso
    def putc(cell, y: nil, x: nil)
      ptr = to_ptr
      raise TypeError, "cell deve essere Notcurses::Cell, non #{cell.class}" unless cell.is_a?(Cell)

      cols = [cell.width, 1].max
      ty, tx = text_target!(cell.egc, cols, cols, y: y, x: x, align: nil, stained: false)
      rc = with_nccells(ptr, [cell]) { |nc| FFI.ncplane_putc_yx(ptr, ty, tx, nc) }
      @context.raise_callback_errors!
      Util.check!(rc, PlaneError, "ncplane_putc_yx(#{cell.egc.inspect})")
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
    # @raise [PlaneError] se il testo non entra nel piano (prima di scrivere)
    # @raise [Exception] l'eccezione di un callback Ruby di resize
    # @raise [ClosedError] se il piano è chiuso
    def puttext(text, y: nil, align: :left)
      ptr = to_ptr
      str = output_text!(ptr, text, 'text')
      raise ArgumentError, "align = #{align.inspect} non valido: usa :left, :center o :right" unless TEXT_ALIGNS.include?(align)

      rows, cols = dims
      row = y.nil? ? cursor_y : Util.integer!(y, 'y', 0...rows)
      lines = wrap_lines(str, cols)
      unless scrolling? || row + lines.size <= rows
        raise PlaneError, "puttext: il testo occupa #{lines.size} righe, dalla riga #{row} ne restano #{rows - row}"
      end

      written = 0
      lines.each do |line|
        if row >= dim_y
          scrollup(lines: 1)
          row = dim_y - 1
        end
        written += putstr(line, y: row, align: align) unless line.empty?
        row += 1
      end
      written
    end

    # --- stile e colori dell'output ---

    # @return [Array<Symbol>] stili delle scritture successive (+ncplane_styles+)
    # @raise [ClosedError] se il piano è chiuso
    def styles = Util.styles_symbols(FFI.ncplane_styles(to_ptr))

    # Imposta gli stili delle scritture successive (+ncplane_set_styles+). Il
    # terminale può non supportarli tutti (vedi {Context#supported_styles}).
    #
    # @param styles [Integer, Symbol, Array<Symbol>]
    # @raise [TypeError, ArgumentError] se uno stile non è valido
    # @raise [ClosedError] se il piano è chiuso
    def styles=(styles)
      FFI.ncplane_set_styles(to_ptr, Util.styles_value(styles))
    end

    # Accende alcuni stili, lasciando gli altri come sono (+ncplane_on_styles+).
    #
    # @param styles [Array<Integer, Symbol, Array<Symbol>>]
    # @return [self]
    # @raise [TypeError, ArgumentError] se uno stile non è valido
    # @raise [ClosedError] se il piano è chiuso
    def on_styles(*styles)
      FFI.ncplane_on_styles(to_ptr, Util.styles_mask(styles))
      self
    end

    # Spegne alcuni stili (+ncplane_off_styles+).
    #
    # @param styles [Array<Integer, Symbol, Array<Symbol>>]
    # @return [self]
    # @raise [TypeError, ArgumentError] se uno stile non è valido
    # @raise [ClosedError] se il piano è chiuso
    def off_styles(*styles)
      FFI.ncplane_off_styles(to_ptr, Util.styles_mask(styles))
      self
    end

    # @return [Channels] colori delle scritture successive (+ncplane_channels+)
    # @raise [ClosedError] se il piano è chiuso
    def channels = Channels.new(value: FFI.ncplane_channels(to_ptr))

    # Imposta i colori delle scritture successive (+ncplane_set_channels+).
    #
    # @param channels [Channels, Integer]
    # @raise [ArgumentError] se lo sfondo ha alpha :highcontrast (non ammesso
    #   da notcurses)
    # @raise [TypeError] se channels non è Channels o Integer
    # @raise [ClosedError] se il piano è chiuso
    def channels=(channels)
      FFI.ncplane_set_channels(to_ptr, Util.plane_channels_value(channels))
    end

    # @return [Channel] colore di primo piano (+ncplane_fchannel+)
    # @raise [ClosedError] se il piano è chiuso
    def fchannel = Channel.new(value: FFI.ncplane_fchannel(to_ptr))

    # @return [Channel] colore di sfondo (+ncplane_bchannel+)
    # @raise [ClosedError] se il piano è chiuso
    def bchannel = Channel.new(value: FFI.ncplane_bchannel(to_ptr))

    # Imposta il colore di primo piano (+ncplane_set_fchannel+).
    # @param channel [Channel, Integer]
    # @raise [TypeError, ArgumentError] se channel non è valido
    # @raise [ClosedError] se il piano è chiuso
    def fchannel=(channel)
      FFI.ncplane_set_fchannel(to_ptr, Util.channel_value(channel))
    end

    # Imposta il colore di sfondo (+ncplane_set_bchannel+).
    # @param channel [Channel, Integer]
    # @raise [ArgumentError] se channel ha alpha :highcontrast
    # @raise [TypeError] se channel non è Channel o Integer
    # @raise [ClosedError] se il piano è chiuso
    def bchannel=(channel)
      value = Util.channel_value(channel)
      raise ArgumentError, "l'alpha :highcontrast non è ammessa per lo sfondo" if Channel.new(value: value).alpha == :highcontrast

      FFI.ncplane_set_bchannel(to_ptr, value)
    end

    # Componenti RGB del primo piano (+ncplane_fg_rgb8+). Hanno senso solo con
    # un colore RGB: con un colore di palette il blu è l'indice, con il
    # default restano i vecchi bit RGB.
    # @return [Array(Integer, Integer, Integer)] [r, g, b]
    # @raise [ClosedError] se il piano è chiuso
    def fg_rgb = rgb8_of { |r, g, b| FFI.ncplane_fg_rgb8(to_ptr, r, g, b) }

    # Componenti RGB dello sfondo (+ncplane_bg_rgb8+), come {#fg_rgb}.
    # @return [Array(Integer, Integer, Integer)] [r, g, b]
    # @raise [ClosedError] se il piano è chiuso
    def bg_rgb = rgb8_of { |r, g, b| FFI.ncplane_bg_rgb8(to_ptr, r, g, b) }

    # Colore RGB del primo piano come 0xRRGGBB (+ncplane_fg_rgb+), con i
    # limiti di {#fg_rgb}.
    # @return [Integer]
    # @raise [ClosedError] se il piano è chiuso
    def fg_rgb24 = FFI.ncplane_fg_rgb(to_ptr)

    # Colore RGB dello sfondo come 0xRRGGBB (+ncplane_bg_rgb+), con i limiti
    # di {#fg_rgb}.
    # @return [Integer]
    # @raise [ClosedError] se il piano è chiuso
    def bg_rgb24 = FFI.ncplane_bg_rgb(to_ptr)

    # @return [Symbol] alpha del primo piano (+ncplane_fg_alpha+): :opaque,
    #   :blend, :transparent o :highcontrast
    # @raise [ClosedError] se il piano è chiuso
    def fg_alpha = Util.alpha_symbol(FFI.ncplane_fg_alpha(to_ptr))

    # @return [Symbol] alpha dello sfondo (+ncplane_bg_alpha+)
    # @raise [ClosedError] se il piano è chiuso
    def bg_alpha = Util.alpha_symbol(FFI.ncplane_bg_alpha(to_ptr))

    # @return [Boolean] true se il primo piano usa il colore di default del
    #   terminale (+ncplane_fg_default_p+)
    # @raise [ClosedError] se il piano è chiuso
    def fg_default? = FFI.ncplane_fg_default_p(to_ptr)

    # @return [Boolean] true se lo sfondo usa il colore di default del
    #   terminale (+ncplane_bg_default_p+)
    # @raise [ClosedError] se il piano è chiuso
    def bg_default? = FFI.ncplane_bg_default_p(to_ptr)

    # Primo piano RGB (+ncplane_set_fg_rgb8+). L'alpha non cambia.
    #
    # @param r [Integer] rosso, 0..255
    # @param g [Integer] verde, 0..255
    # @param b [Integer] blu, 0..255
    # @return [self]
    # @raise [TypeError, ArgumentError] se un componente non è un Integer in 0..255
    # @raise [ClosedError] se il piano è chiuso
    def set_fg_rgb(r, g, b)
      rc = FFI.ncplane_set_fg_rgb8(to_ptr, Util.uint8!(r, 'r'), Util.uint8!(g, 'g'), Util.uint8!(b, 'b'))
      Util.check!(rc, PlaneError, 'ncplane_set_fg_rgb8')
      self
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
      rc = FFI.ncplane_set_bg_rgb8(to_ptr, Util.uint8!(r, 'r'), Util.uint8!(g, 'g'), Util.uint8!(b, 'b'))
      Util.check!(rc, PlaneError, 'ncplane_set_bg_rgb8')
      self
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
      FFI.ncplane_set_fg_rgb8_clipped(to_ptr, Util.int!(r, 'r'), Util.int!(g, 'g'), Util.int!(b, 'b'))
      self
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
      FFI.ncplane_set_bg_rgb8_clipped(to_ptr, Util.int!(r, 'r'), Util.int!(g, 'g'), Util.int!(b, 'b'))
      self
    end

    # Primo piano RGB da 0xRRGGBB (+ncplane_set_fg_rgb+).
    # @param rgb [Integer] 0..0xffffff
    # @return [self]
    # @raise [TypeError, ArgumentError] se rgb non è valido
    # @raise [ClosedError] se il piano è chiuso
    def set_fg_rgb24(rgb)
      Util.check!(FFI.ncplane_set_fg_rgb(to_ptr, Util.integer!(rgb, 'rgb', 0..0xff_ffff)), PlaneError, 'ncplane_set_fg_rgb')
      self
    end

    # Sfondo RGB da 0xRRGGBB (+ncplane_set_bg_rgb+).
    # @param rgb [Integer] 0..0xffffff
    # @return [self]
    # @raise [TypeError, ArgumentError] se rgb non è valido
    # @raise [ClosedError] se il piano è chiuso
    def set_bg_rgb24(rgb)
      Util.check!(FFI.ncplane_set_bg_rgb(to_ptr, Util.integer!(rgb, 'rgb', 0..0xff_ffff)), PlaneError, 'ncplane_set_bg_rgb')
      self
    end

    # Primo piano da un indice della palette del terminale
    # (+ncplane_set_fg_palindex+); l'alpha diventa :opaque. Linee, box e fade
    # convertono il colore di palette in RGB (0, 0, indice).
    # @param index [Integer] 0..255
    # @return [self]
    # @raise [TypeError, ArgumentError] se index non è valido
    # @raise [ClosedError] se il piano è chiuso
    def set_fg_palindex(index)
      Util.check!(FFI.ncplane_set_fg_palindex(to_ptr, Util.uint8!(index, 'index')), PlaneError, 'ncplane_set_fg_palindex')
      self
    end

    # Sfondo da un indice della palette (+ncplane_set_bg_palindex+), come
    # {#set_fg_palindex}.
    # @param index [Integer] 0..255
    # @return [self]
    # @raise [TypeError, ArgumentError] se index non è valido
    # @raise [ClosedError] se il piano è chiuso
    def set_bg_palindex(index)
      Util.check!(FFI.ncplane_set_bg_palindex(to_ptr, Util.uint8!(index, 'index')), PlaneError, 'ncplane_set_bg_palindex')
      self
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
      Util.check!(FFI.ncplane_set_fg_alpha(to_ptr, Util.alpha_value(alpha)), PlaneError, 'ncplane_set_fg_alpha')
      self
    end

    # Alpha dello sfondo (+ncplane_set_bg_alpha+), come {#set_fg_alpha}.
    # @param alpha [Symbol, Integer] :opaque, :blend o :transparent
    # @return [self]
    # @raise [ArgumentError] se alpha non è valido o è :highcontrast
    # @raise [ClosedError] se il piano è chiuso
    def set_bg_alpha(alpha)
      value = Util.alpha_value(alpha)
      raise ArgumentError, "l'alpha :highcontrast non è ammessa per lo sfondo" if value == FFI::NCALPHA_HIGHCONTRAST

      Util.check!(FFI.ncplane_set_bg_alpha(to_ptr, value), PlaneError, 'ncplane_set_bg_alpha')
      self
    end

    # Primo piano con il colore di default del terminale
    # (+ncplane_set_fg_default+). I vecchi bit RGB o di palette restano: un
    # {#set_fg_alpha} successivo diverso da :opaque li fa riapparire.
    # @return [self]
    # @raise [ClosedError] se il piano è chiuso
    def set_fg_default
      FFI.ncplane_set_fg_default(to_ptr)
      self
    end

    # Sfondo con il colore di default del terminale (+ncplane_set_bg_default+),
    # come {#set_fg_default}.
    # @return [self]
    # @raise [ClosedError] se il piano è chiuso
    def set_bg_default
      FFI.ncplane_set_bg_default(to_ptr)
      self
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
    # @raise [PlaneError] se il cursore è oltre il bordo, o se notcurses
    #   rifiuta la scrittura (la linea può restare disegnata in parte)
    # @raise [RenderError] su uno stdplane che scorre, come in {#putstr}
    # @raise [Exception] l'eccezione di un callback Ruby di resize
    # @raise [ClosedError] se il piano è chiuso
    def hline(cell, len, y: nil, x: nil, from: nil, to: nil)
      ptr = to_ptr
      line = line_cell!(cell)
      top, left = line_start!(y, x)
      rows, cols = dims
      max = scrolling? || autogrow? ? rows * cols : cols - left
      Util.integer!(len, 'len', 1..max)
      c1, c2 = interp_channels!(from, to)
      sync_scrolling_stdplane!(ptr, len > cols - left)
      move_cursor(top, left)
      rc = with_nccells(ptr, [line]) do |nc|
        c1.nil? ? FFI.ncplane_hline(ptr, nc, len) : FFI.ncplane_hline_interp(ptr, nc, len, c1, c2)
      end
      @context.raise_callback_errors!
      Util.check!(rc, PlaneError, 'ncplane_hline_interp')
      self
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
    # @raise [PlaneError] se il cursore è oltre il bordo, o se notcurses
    #   rifiuta la scrittura
    # @raise [ClosedError] se il piano è chiuso
    def vline(cell, len, y: nil, x: nil, from: nil, to: nil)
      ptr = to_ptr
      line = line_cell!(cell)
      top, left = line_start!(y, x)
      Util.integer!(len, 'len', 1..(dim_y - top))
      c1, c2 = interp_channels!(from, to)
      move_cursor(top, left)
      rc = with_nccells(ptr, [line]) do |nc|
        c1.nil? ? FFI.ncplane_vline(ptr, nc, len) : FFI.ncplane_vline_interp(ptr, nc, len, c1, c2)
      end
      Util.check!(rc, PlaneError, 'ncplane_vline_interp')
      self
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
    # @raise [PlaneError] se notcurses rifiuta il disegno (il box può restare
    #   disegnato in parte)
    # @raise [ClosedError] se il piano è chiuso
    def box(rows, cols, y: nil, x: nil, set: :light, styles: 0, channels: 0, hide: [], gradient: [], corners: 0)
      ptr = to_ptr
      top, left = line_start!(y, x)
      prows, pcols = dims
      Util.integer!(rows, 'rows', 2..[prows - top, 2].max)
      Util.integer!(cols, 'cols', 2..[pcols - left, 2].max)
      raise ArgumentError, "il box #{rows}x#{cols} in (#{top}, #{left}) esce dal piano #{prows}x#{pcols}" if top + rows > prows || left + cols > pcols

      ctl = box_ctlword(hide, gradient, corners)
      move_cursor(top, left)
      rc = with_box_cells(ptr, set, styles, channels) do |ul, ur, ll, lr, hl, vl|
        FFI.ncplane_box(ptr, ul, ur, ll, lr, hl, vl, top + rows - 1, left + cols - 1, ctl)
      end
      Util.check!(rc, PlaneError, 'ncplane_box')
      self
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
    # vuote sovrascrive anche le metà destre dei glifi larghi. Il cursore non
    # si sposta.
    #
    # @param cell [Cell, String] carattere largo 1 colonna; una String usa
    #   stile e colori del piano
    # @param y [Integer, nil] riga di partenza; nil = riga del cursore
    # @param x [Integer, nil] colonna di partenza; nil = colonna del cursore
    # @return [Integer] celle riempite (0 se la cella di partenza ha già l'EGC di cell)
    # @raise [ArgumentError, TypeError] se un argomento non è valido
    # @raise [CellError] se notcurses non accetta il carattere
    # @raise [PlaneError] se il riempimento fallisce
    # @raise [ClosedError] se il piano è chiuso
    def polyfill(cell, y: nil, x: nil)
      ptr = to_ptr
      fill = line_cell!(cell)
      top, left = line_start!(y, x)
      rc = with_nccells(ptr, [fill]) { |nc| FFI.ncplane_polyfill_yx(ptr, top, left, nc) }
      Util.check!(rc, PlaneError, 'ncplane_polyfill_yx')
    end

    # Riempie un rettangolo con egc e colori sfumati tra i quattro angoli
    # (+ncplane_gradient+). Il contenuto precedente si perde; il cursore non
    # si sposta. Il wrapper controlla i vincoli del C prima della chiamata (il
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
    # @raise [PlaneError] se il riempimento fallisce
    # @raise [ClosedError] se il piano è chiuso
    def gradient(egc, ul, ur, ll, lr, y: 0, x: 0, rows: nil, cols: nil, styles: 0)
      ptr = to_ptr
      text = Cell.egc!(egc)
      unless text.empty?
        raise ArgumentError, "gradient: egc #{text.inspect} deve essere largo 1 colonna" unless Notcurses.strwidth(text) == 1

        single_egc!(ptr, text)
      end
      corners = corner_values([ul, ur, ll, lr], 64)
      top, left, height, width = region!(y, x, rows, cols)
      corners_shape!(corners, height, width, rows_rule: true)
      Util.check!(FFI.ncplane_gradient(ptr, top, left, height, width, text, Util.styles_value(styles), *corners),
                  PlaneError, 'ncplane_gradient')
    end

    # Riempie un rettangolo con mezzi blocchi "▀" a doppia risoluzione
    # verticale (+ncplane_gradient2x1+): ogni cella ha due righe di colore,
    # sfumate tra i quattro angoli; lo stile delle celle resta. Con un angolo
    # di default primo piano e sfondo diventano di default. Vincoli come in
    # {#gradient}, su canali singoli; con una colonna servono ul == ur e
    # ll == lr. Serve un terminale UTF-8.
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
      ptr = to_ptr
      corners = corner_values([ul, ur, ll, lr], 32)
      top, left, height, width = region!(y, x, rows, cols)
      corners_shape!(corners, height, width, rows_rule: false)
      raise PlaneError, 'gradient2x1 richiede un terminale UTF-8' unless @context.can_utf8?

      Util.check!(FFI.ncplane_gradient2x1(ptr, top, left, height, width, *corners), PlaneError, 'ncplane_gradient2x1')
    end

    # Sfuma i colori di un rettangolo tra i quattro angoli lasciando EGC e
    # stili (+ncplane_stain+). Le celle vuote e le metà destre dei glifi larghi
    # non cambiano. Vincoli sui colori come in {#gradient}, senza quelli sulla
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
      ptr = to_ptr
      corners = corner_values([ul, ur, ll, lr], 64)
      top, left, height, width = region!(y, x, rows, cols)
      Util.check!(FFI.ncplane_stain(ptr, top, left, height, width, *corners), PlaneError, 'ncplane_stain')
    end

    # Imposta gli stili di un rettangolo lasciando EGC e colori
    # (+ncplane_format+; il nome evita di nascondere Kernel#format).
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
      ptr = to_ptr
      mask = Util.styles_value(styles)
      top, left, height, width = region!(y, x, rows, cols)
      Util.check!(FFI.ncplane_format(ptr, top, left, height, width, mask), PlaneError, 'ncplane_format')
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

    private

    # Puntatore di un altro piano dello stesso contesto.
    def same_context_plane!(plane, name)
      raise TypeError, "#{name} deve essere Notcurses::Plane, non #{plane.class}" unless plane.is_a?(Plane)
      raise ArgumentError, "#{name} appartiene a un altro contesto" unless plane.context.equal?(@context)

      plane.to_ptr
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
    def cell_coords!(y, x)
      rows, cols = dims
      cy, cx = cursor
      if y.nil? || x.nil?
        # dopo un output che riempie la riga il cursore resta a x == colonne
        raise PlaneError, "il cursore (#{cy}, #{cx}) è oltre il bordo del piano" unless cy < rows && cx < cols
      end
      y = y.nil? ? cy : Util.integer!(y, 'y', 0...rows)
      x = x.nil? ? cx : Util.integer!(x, 'x', 0...cols)
      [y, x]
    end

    # true se la cella (y, x) è la metà destra di un glifo largo.
    def wide_right?(ptr, y, x)
      cell = FFI::NcCell.new
      return false if FFI.ncplane_at_yx_cell(ptr, y, x, cell).negative?

      FFI.nccell_wide_right_p(cell)
    ensure
      FFI.nccell_release(ptr, cell)
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
    # Non le vede quando nascono senza resize: erase_region, gradient e
    # polyfill su una sola metà di un glifo largo (ICH-450).
    def clear_cut_glyphs!(ptr, force: false)
      rows, cols = dims
      return if !force && @cut_glyphs_cols == cols

      cell = FFI::NcCell.new
      rows.times do |y|
        [0, cols - 1].uniq.each do |x|
          next if FFI.ncplane_at_yx_cell(ptr, y, x, cell).negative?

          right = FFI.nccell_wide_right_p(cell)
          orphan = (x.zero? && right) ||
                   (x == cols - 1 && (FFI.nccell_wide_left_p(cell) || (right && !wide_left?(ptr, y, x - 1))))
          FFI.nccell_release(ptr, cell)
          Util.check!(FFI.ncplane_erase_region(ptr, y, x, 1, 1), PlaneError, 'ncplane_erase_region') if orphan
        end
      end
      @cut_glyphs_cols = cols
    end

    # Su uno stdplane che scorre ogni a capo ("\n" o a capo automatico) fa un
    # render dentro ncplane_put (notcurses.c:1978-1981), che lo restringe se il
    # terminale si è ristretto: il resto della stessa chiamata C scriverebbe su
    # una metà orfana. Con wraps (la scrittura può andare a capo) ncpile_render
    # porta prima lo stdplane alle dimensioni del terminale (render.c:1579).
    def sync_scrolling_stdplane!(ptr, wraps)
      return unless wraps && scrolling? && address == @context.stdplane.address

      rc = FFI.ncpile_render(ptr)
      @context.raise_callback_errors!
      Util.check!(rc, RenderError, 'ncpile_render')
      clear_cut_glyphs!(ptr)
    end

    # true se la cella (y, x) è la metà sinistra di un glifo largo.
    def wide_left?(ptr, y, x)
      cell = FFI::NcCell.new
      return false if FFI.ncplane_at_yx_cell(ptr, y, x, cell).negative?

      FFI.nccell_wide_left_p(cell)
    ensure
      FFI.nccell_release(ptr, cell)
    end

    # Cell con il contenuto di una nccell legata all'egcpool del piano ptr.
    def cell_content(ptr, cell)
      Cell.from_c(FFI.nccell_extended_gcluster(ptr, cell) || +'', cell[:stylemask], cell[:channels], cell[:width])
    end

    # --- helper dell'output ---

    # Testo da scrivere: String UTF-8 senza i caratteri che notcurses 3.0.17
    # scrive male (vedi {#putstr}).
    def output_text!(ptr, text, name)
      str = Util.string!(text, name)
      raise ArgumentError, "#{name} contiene un TAB: espandilo prima (per esempio con String#gsub)" if str.include?("\t")
      raise ArgumentError, "#{name} contiene un carattere di controllo" if str.match?(/(?!\n)\p{Cc}/)
      raise ArgumentError, "#{name} contiene U+2028 o U+2029, che notcurses tronca a un byte" if str.match?(/[  ]/)

      zero_width_egc!(ptr, str, name) if str.match?(ZERO_WIDTH_CANDIDATES)
      str
    end

    # Rifiuta i caratteri che notcurses scrive come EGC di larghezza zero: il
    # C li mette in una cella propria e, con il cursore a fine riga
    # (x == colonne), scrive fuori dalla riga (sull'ultima riga fuori dal
    # framebuffer). La segmentazione è quella di notcurses (+nccell_load+),
    # che può dividere un grapheme di Ruby.
    def zero_width_egc!(ptr, str, name)
      cell = FFI::NcCell.new
      str.each_grapheme_cluster do |g|
        next unless g.match?(ZERO_WIDTH_CANDIDATES)

        off = 0
        while off < g.bytesize
          len = FFI.nccell_load(ptr, cell, g.byteslice(off..))
          raise ArgumentError, "#{name}: notcurses non accetta #{g.inspect}" unless len.positive?
          if cell[:width].zero?
            raise ArgumentError, "#{name}: notcurses 3.0.17 scrive #{g.byteslice(off, len).inspect} (in #{g.inspect}) " \
                                 'come un carattere di larghezza zero, in una cella propria'
          end

          off += len
        end
      end
    ensure
      FFI.nccell_release(ptr, cell) if cell
    end

    # Controlla dove scrivere un testo di total colonne, con il primo
    # carattere largo first, e restituisce [y, x] per il C (-1 = cursore). Con
    # stained porta il cursore nella posizione di partenza.
    def text_target!(str, total, first, y:, x:, align:, stained:)
      clear_cut_glyphs!(to_ptr)
      rows, cols = dims
      cy, cx = cursor
      newline = str.include?("\n")
      row = y.nil? ? cy : Util.integer!(y, 'y', 0...rows)
      col = if align
              raise ArgumentError, "align = #{align.inspect} non valido: usa :left, :center o :right" unless TEXT_ALIGNS.include?(align)
              raise ArgumentError, 'align: non ammette "\n"' if newline
              raise PlaneError, "il testo (#{total} colonne) è più largo del piano (#{cols})" if total > cols

              halign(align, total)
            else
              x.nil? ? cx : Util.integer!(x, 'x', 0...cols)
            end
      raise PlaneError, '"\n" richiede un piano che scorre (scrolling = true)' if newline && !scrolling?
      raise PlaneError, "un carattere largo #{first} non entra nel piano largo #{cols}" if first > cols

      explicit_x = !(x.nil? && align.nil?)
      raise PlaneError, "il carattere largo #{first} non entra nella riga dalla colonna #{col}" if explicit_x && col + first > cols
      if (stained || !(scrolling? || autogrow?)) && (col >= cols || col + total > cols)
        raise PlaneError, "il testo (#{total} colonne) non entra nella riga dalla colonna #{col} (piano largo #{cols})"
      end
      return [y.nil? ? -1 : row, explicit_x ? col : -1] unless stained

      raise ArgumentError, 'stained: non ammette "\n"' if newline

      move_cursor(row, col) unless row == cy && col == cx
      [-1, -1]
    end

    # Controlla che notcurses legga text come un solo EGC (+nccell_load+).
    def single_egc!(ptr, text)
      probe = FFI::NcCell.new
      len = FFI.nccell_load(ptr, probe, text)
      raise CellError, "notcurses divide #{text.inspect} in più caratteri" unless len == text.bytesize
    ensure
      FFI.nccell_release(ptr, probe) if probe
    end

    # Copia le Cell in nccell temporanee del piano, esegue il blocco e le
    # rilascia: una nccell non deve sopravvivere all'operazione.
    def with_nccells(ptr, cells)
      ncs = cells.map { FFI::NcCell.new }
      cells.each_with_index { |cell, i| cell.load_into(ptr, ncs[i]) }
      yield(*ncs)
    ensure
      ncs&.each { |nc| FFI.nccell_release(ptr, nc) }
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
    def line_cell!(cell)
      cell = Cell.new(egc: cell, styles: styles, channels: channels) if cell.is_a?(String)
      raise TypeError, "cell deve essere Notcurses::Cell o String, non #{cell.class}" unless cell.is_a?(Cell)
      raise ArgumentError, "il carattere #{cell.egc.inspect} deve essere largo 1 colonna" unless cell.width == 1

      cell
    end

    # Posizione di partenza di linee, box e riempimenti (nil = cursore).
    def line_start!(y, x)
      clear_cut_glyphs!(to_ptr)
      cell_coords!(y, x)
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

    # Le 6 nccell temporanee di un box (ul ur ll lr hl vl).
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

    def box_cells(ptr, cells, &block)
      wide = cells.find { |c| c.width != 1 }
      raise ArgumentError, "i glifi del box devono essere larghi 1 colonna: #{wide.egc.inspect}" if wide

      with_nccells(ptr, cells, &block)
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

      yield(*ncs)
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

    # La prossima scrittura controlla di nuovo i bordi (vedi clear_cut_glyphs!).
    # @return [nil]
    def forget_cut_glyphs! = (@cut_glyphs_cols = nil)
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
      raise TypeError, "plane deve essere Notcurses::Plane, non #{plane.class}" unless plane.is_a?(Plane)

      raw = FFI.ncfadectx_setup(plane.to_ptr)
      raise PlaneError, 'ncfadectx_setup ha restituito NULL: il terminale non permette le dissolvenze' if raw.null?

      @ptr = ::FFI::AutoPointer.new(raw, RELEASER)
      @plane = plane
      @iterations = FFI.ncfadectx_iterations(@ptr)
      @closed = false
      @owner = nil
    end

    # Libera la fotografia (+ncfadectx_free+). Idempotente.
    # @return [nil]
    def close
      return nil if @closed

      @closed = true
      @ptr.free
      nil
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
      rc = FFI.ncplane_fadeout_iteration(@plane.to_ptr, to_ptr, iteration!(iteration), NOOP_FADER, nil)
      Util.check!(rc, PlaneError, 'ncplane_fadeout_iteration')
      self
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
      rc = FFI.ncplane_fadein_iteration(@plane.to_ptr, to_ptr, iteration!(iteration), NOOP_FADER, nil)
      Util.check!(rc, PlaneError, 'ncplane_fadein_iteration')
      self
    end

    private

    # fuori da 0..iterations il C schiarisce oltre l'originale o non cambia nulla
    def iteration!(value) = Util.integer!(value, 'iteration', 0..@iterations)
  end
end
