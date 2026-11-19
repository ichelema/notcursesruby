# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Grafico a barre di una serie di campioni (+ncuplot+ con valori uint64_t,
  # +ncdplot+ con valori double: una sola classe, scelta con +type:+).
  #
  # Il grafico tiene una finestra di {#slot_count} campioni consecutivi: x è
  # l'indice del campione (per esempio un istante), y il suo valore. Un x oltre
  # la finestra la fa avanzare: i campioni più vecchi si perdono e le colonne
  # nuove partono da 0. Il numero di slot si decide alla creazione (colonne del
  # piano per la larghezza del blitter, oppure range_x:) e non cambia con il
  # piano. Ogni campione ridisegna il piano, senza render: chiama
  # {Context#render}.
  #
  # Il grafico prende possesso del piano ricevuto (vedi {Widget}), anche se la
  # creazione C fallisce, e lo distrugge alla chiusura (i figli del piano
  # passano al suo genitore).
  #
  # Dominio. Con min == max == 0 (il default) il dominio si adatta ai campioni;
  # con min < max è fisso: i valori fuori vengono memorizzati ma disegnati al
  # bordo, e {#add_sample}/{#set_sample} restituiscono false.
  #
  # Bug di 3.0.17 aggirati:
  # - dopo un salto della finestra di almeno slot_count (anche il primo
  #   campione con x grande) +ncuplot_sample+ e il controllo del dominio
  #   leggono lo slot sbagliato (+x % slotcount+ contro l'indice circolare,
  #   plot.c:595,616,635 contro 657): il wrapper trasla le x passate al C in
  #   modo che ogni salto finisca su un multiplo di slot_count, e i due indici
  #   coincidono sempre;
  # - +ncuplot_set_sample+ con x dietro la finestra scrive fuori dal buffer
  #   (plot.c:657,701): il wrapper non lo chiama;
  # - x >= 2^63 diventa un indice negativo (plot.c:595,616): con la traslazione
  #   il C riceve x piccole;
  # - con label_ticks: su un piano di 7 colonne o meno il C scrive fuori dal
  #   piano (plot.c:290): rifiutato alla creazione e a ogni campione (il piano
  #   può essere stato ridimensionato);
  # - un blitter fuori enum fa abortire il processo (blit.c:1374): il wrapper
  #   accetta solo i simboli di {Util::BLITTERS}.
  #
  # Limiti noti di 3.0.17: il titolo senza label_ticks è scritto alla colonna
  # 7 meno la sua lunghezza in byte (visibile solo fino a 8 byte, dopo non
  # compare); print_sample: stampa uno slot vicino al più recente, non sempre
  # l'ultimo; con valori double negativi e label_ticks: le etichette sono
  # sbagliate (conversione C da double negativo a intero senza segno); con
  # label_ticks: da circa 1,84e17 (2^64/100) in su, con :uint64 e con
  # :double, le etichette sono sbagliate, mentre i campioni mantengono il loro
  # valore. Il C converte il valore per 100 in un intero a 64 bit senza segno
  # (plot.c:298-306): fuori intervallo il risultato dipende dalla build di
  # notcurses ("184.47P" su x86-64-v4, "0.00" su x86-64 generico). Con
  # exponential: e :uint64 la riga più alta moltiplica interi: il valore per
  # 100 riparte da 0 oltre 2^64 (2e17 dà "15.53P").
  #
  # @example
  #   plane = nc.stdplane.create_child(rows: 5, cols: 40)
  #   plot = Notcurses::Plot.new(plane, type: :double, blitter: :braille, label_ticks: true, title: 'CPU')
  #   plot.add_sample(0, 12.5)
  #   plot.add_sample(1, 40.0)
  #   nc.render
  #   plot.close
  class Plot
    include Widget
    extend Resource::ClassMethods

    # Tipi dei valori.
    TYPES = %i[uint64 double].freeze

    # Colonne in larghezza di una cella per i blitter a celle (blit.c:1230):
    # il pixel usa i pixel di una cella.
    BLITTER_WIDTHS = {
      FFI::NCBLIT_1x1 => 1, FFI::NCBLIT_2x1 => 1, FFI::NCBLIT_2x2 => 2, FFI::NCBLIT_3x2 => 2,
      FFI::NCBLIT_4x2 => 2, FFI::NCBLIT_BRAILLE => 2, FFI::NCBLIT_4x1 => 1, FFI::NCBLIT_8x1 => 1
    }.freeze
    private_constant :BLITTER_WIDTHS

    # Crea il grafico sul piano (+ncuplot_create+ o +ncdplot_create+) e lo
    # disegna vuoto.
    #
    # Il blitter si sceglie in Ruby con la stessa catena di ripieghi del C
    # (braille, poi ottanti, sestanti, quadranti, mezzi blocchi, ASCII; 8x1 e
    # 4x1 richiedono i quadranti; pixel richiede il supporto ai pixel) e il C
    # riceve il blitter già scelto: così il numero di slot calcolato dal
    # wrapper è quello del C.
    #
    # @param plane [Plane] piano posseduto dal wrapper, non lo stdplane e non
    #   già di un widget: passa al grafico
    # @param type [Symbol] :uint64 (valori interi 0..2^64-1) o :double (Float
    #   finiti)
    # @param min [Integer, Float] minimo del dominio fisso (0 con max 0 = dominio
    #   automatico)
    # @param max [Integer, Float] massimo del dominio fisso, >= min
    # @param blitter [Symbol, Integer] blitter (vedi {Util::BLITTERS}): :default
    #   (8x1 con UTF-8, altrimenti ASCII), :ascii, :half, :quad, :sextant,
    #   :octant, :braille, :pixel, :four_by_one, :eight_by_one
    # @param range_x [Integer] slot richiesti, 0..INT_MAX: 0, o più delle
    #   colonne del piano, = colonne per la larghezza del blitter
    # @param title [String, nil] titolo (copiato dal C), senza caratteri di
    #   controllo
    # @param max_channels [Channels, Integer] colori della riga più alta (il
    #   C sfuma le righe da min_channels a max_channels)
    # @param min_channels [Channels, Integer] colori della riga più bassa
    # @param legend_style [Integer, Symbol, Array<Symbol>] stili di etichette,
    #   titolo e campione stampato
    # @param label_ticks [Boolean] NCPLOT_OPTION_LABELTICKSD: etichette dei
    #   valori a sinistra (7 colonne; il piano deve averne almeno 8). Da
    #   circa 1,84e17 in su le etichette sono sbagliate (limite di 3.0.17,
    #   vedi la classe)
    # @param exponential [Boolean] NCPLOT_OPTION_EXPONENTIALD: asse dei
    #   valori esponenziale
    # @param no_degrade [Boolean] NCPLOT_OPTION_NODEGRADE: errore invece di
    #   un blitter di ripiego
    # @param detect_max_only [Boolean] NCPLOT_OPTION_DETECTMAXONLY: con il
    #   dominio automatico adatta solo il massimo (il minimo resta 0)
    # @param print_sample [Boolean] NCPLOT_OPTION_PRINTSAMPLE: stampa un
    #   campione recente in alto a destra
    # @raise [WidgetError] se il blitter non è disponibile con no_degrade
    #   (piano intatto); con label_ticks su un piano di 7 colonne o meno
    #   (piano intatto); se il C restituisce NULL (il piano risulta
    #   distrutto); se il piano è lo stdplane, è già di un widget o non è
    #   posseduto; dentro un callback chiamato da notcurses
    # @raise [TypeError, ArgumentError] se un'opzione non è valida: type,
    #   valori del dominio (min == max diverso da 0, max < min,
    #   detect_max_only con il dominio fisso), blitter
    # @raise [ClosedError] se il piano è chiuso
    # @raise [Exception] l'eccezione di un callback Ruby di resize di un figlio
    #   del piano
    def initialize(plane, type: :uint64, min: 0, max: 0, blitter: :default, range_x: 0, title: nil,
                   max_channels: 0, min_channels: 0, legend_style: 0, label_ticks: false,
                   exponential: false, no_degrade: false, detect_max_only: false, print_sample: false)
      Guard.run do
        raise ArgumentError, "type = #{type.inspect} non valido: usa :uint64 o :double" unless TYPES.include?(type)

        @double = type == :double
        @min = value!(min, 'min')
        @max = value!(max, 'max')
        check_domain!(detect_max_only)
        @label_ticks = Util.bool!(label_ticks, 'label_ticks')
        opts = FFI::NcPlotOptions.new
        opts[:maxchannels] = Util.channels_value(max_channels, 'max_channels')
        opts[:minchannels] = Util.channels_value(min_channels, 'min_channels')
        opts[:legendstyle] = Util.styles_value(legend_style)
        opts[:rangex] = Util.nonneg_int!(range_x, 'range_x')
        title_ptr = Util.c_string(title.nil? ? nil : title!(title), 'title') # il C lo copia (strdup)
        opts[:title] = title_ptr || ::FFI::Pointer::NULL
        flags = Util.flag(@label_ticks, FFI::NCPLOT_OPTION_LABELTICKSD, 'label_ticks') |
                Util.flag(exponential, FFI::NCPLOT_OPTION_EXPONENTIALD, 'exponential') |
                Util.flag(detect_max_only, FFI::NCPLOT_OPTION_DETECTMAXONLY, 'detect_max_only') |
                Util.flag(print_sample, FFI::NCPLOT_OPTION_PRINTSAMPLE, 'print_sample')
        requested = Util.blitter_value(blitter)
        Util.bool!(no_degrade, 'no_degrade')
        claim_plane!(plane)
        ctx = plane.context
        ctx.check_not_in_callback!('Plot.new', WidgetError)
        cols = plane.dim_x
        if @label_ticks && cols <= FFI::NCPREFIXCOLUMNS
          raise WidgetError,
                "label_ticks: richiede un piano di almeno #{FFI::NCPREFIXCOLUMNS + 1} colonne (ne ha #{cols})"
        end

        @blitter = resolve_blitter(ctx, plane, requested, no_degrade)
        width = @blitter == FFI::NCBLIT_PIXEL ? plane.pixel_geom[:cell_pixel_x] : BLITTER_WIDTHS.fetch(@blitter)
        @slot_count = slot_count_for(cols, width, opts[:rangex])
        opts[:gridtype] = @blitter
        # il blitter è già scelto: con NODEGRADE il C non può sceglierne un altro (e un altro numero di slot)
        opts[:flags] = flags | FFI::NCPLOT_OPTION_NODEGRADE
        ptr = if @double
                FFI.ncdplot_create(plane.to_ptr, opts, @min, @max)
              else
                FFI.ncuplot_create(plane.to_ptr, opts, @min, @max)
              end
        if ptr.null?
          plane_destroyed_on_failure!(plane) # "takes ownership of n on all paths" (plot.c:677)
          ctx.raise_callback_errors!
          what = @double ? 'ncdplot_create' : 'ncuplot_create'
          raise WidgetError, "#{what} ha restituito NULL (il piano è stato distrutto)"
        end

        # finestra in coordinate utente (newest) e del C (newest_c): x utente = x C + base
        @newest = 0
        @newest_c = 0
        @base = 0
        attach!(ptr, plane)
        ctx.raise_callback_errors!
      end
    end

    # Piano del grafico (+ncuplot_plane+, +ncdplot_plane+): lo stesso Plane
    # passato a {#initialize}.
    #
    # @return [Plane]
    # @raise [ClosedError] se il grafico è chiuso
    def plane = Guard.run { @context.plane_for(@double ? FFI.ncdplot_plane(to_ptr) : FFI.ncuplot_plane(to_ptr)) }

    # @return [Symbol] :uint64 o :double
    # @raise [ClosedError] se il grafico è chiuso
    def type
      Guard.run do
        to_ptr
        @double ? :double : :uint64
      end
    end

    # Blitter usato davvero, dopo gli eventuali ripieghi.
    #
    # @return [Symbol] uno dei simboli di {Util::BLITTERS} (mai :default)
    # @raise [ClosedError] se il grafico è chiuso
    def blitter
      Guard.run do
        to_ptr
        Util.enum_symbol(Util::BLITTERS, @blitter)
      end
    end

    # Numero di campioni della finestra, fisso dalla creazione (il C non ha
    # una funzione per leggerlo: il wrapper lo calcola come +create_*+).
    #
    # @return [Integer]
    # @raise [ClosedError] se il grafico è chiuso
    def slot_count
      Guard.run do
        to_ptr
        @slot_count
      end
    end

    # Valori di x accettati da {#sample} e, senza far avanzare la finestra, da
    # {#add_sample}/{#set_sample}: gli ultimi {#slot_count}, fino al più alto
    # visto (0 prima del primo campione).
    #
    # @return [Range<Integer>]
    # @raise [ClosedError] se il grafico è chiuso
    def window
      Guard.run do
        to_ptr
        [@newest - @slot_count + 1, 0].max..@newest
      end
    end

    # Somma y al campione x (+ncuplot_add_sample+, +ncdplot_add_sample+) e
    # ridisegna. Un x oltre la finestra la fa avanzare fino a x.
    #
    # @param x [Integer] indice del campione, 0..2^64-1
    # @param y [Integer, Float] valore da sommare: Integer 0..2^64-1 per
    #   :uint64, numero finito per :double
    # @return [Boolean] true se il campione è stato sommato e il grafico
    #   ridisegnato; false se x è dietro la finestra (campione scartato, come
    #   nel C) o se, con il dominio fisso, il nuovo valore è fuori da [min,
    #   max] (il valore è memorizzato, ma il grafico verrà ridisegnato solo al
    #   prossimo campione)
    # @raise [TypeError, ArgumentError] se x o y non sono validi, o se la somma
    #   esce dal tipo (oltre 2^64-1 per :uint64, non finita per :double: il C
    #   la troncherebbe senza dirlo)
    # @raise [WidgetError] se il ridisegno fallisce, o se con label_ticks il
    #   piano è stato ridotto a 7 colonne o meno (il C scriverebbe fuori dal
    #   piano)
    # @raise [Exception] l'eccezione di un callback Ruby di resize
    # @raise [ClosedError] se il grafico è chiuso
    def add_sample(x, y)
      Guard.run do
        ptr = to_ptr
        check_width!
        value = value!(y, 'y')
        xc, base = c_coordinate(Util.uint64!(x, 'x'))
        return false if xc.nil?

        if x <= @newest
          total = read_sample(ptr, xc) + value
          raise ArgumentError, "add_sample: la somma #{total} esce dal tipo #{type}" unless valid_value?(total)
        end
        rc = @double ? FFI.ncdplot_add_sample(ptr, xc, value) : FFI.ncuplot_add_sample(ptr, xc, value)
        advance!(x, xc, base)
        @context.raise_callback_errors!
        sample_result(ptr, xc, rc, 'add_sample')
      end
    end

    # Sostituisce il valore del campione x (+ncuplot_set_sample+,
    # +ncdplot_set_sample+) e ridisegna. Un x oltre la finestra la fa
    # avanzare fino a x.
    #
    # Bug di 3.0.17 aggirato: con x dietro la finestra il C scrive fuori dal
    # buffer dei campioni; il wrapper restituisce false senza chiamarlo.
    #
    # @param x [Integer] indice del campione, 0..2^64-1
    # @param y [Integer, Float] nuovo valore: Integer 0..2^64-1 per :uint64,
    #   numero finito per :double
    # @return [Boolean] come {#add_sample}
    # @raise [TypeError, ArgumentError] se x o y non sono validi
    # @raise [WidgetError] come {#add_sample}
    # @raise [Exception] l'eccezione di un callback Ruby di resize
    # @raise [ClosedError] se il grafico è chiuso
    def set_sample(x, y)
      Guard.run do
        ptr = to_ptr
        check_width!
        value = value!(y, 'y')
        xc, base = c_coordinate(Util.uint64!(x, 'x'))
        return false if xc.nil?

        # rete di sicurezza per la scrittura fuori buffer: read_sample solleva se il C vede xc fuori finestra
        read_sample(ptr, xc) if x <= @newest
        rc = @double ? FFI.ncdplot_set_sample(ptr, xc, value) : FFI.ncuplot_set_sample(ptr, xc, value)
        advance!(x, xc, base)
        @context.raise_callback_errors!
        sample_result(ptr, xc, rc, 'set_sample')
      end
    end

    # Valore del campione x (+ncuplot_sample+, +ncdplot_sample+).
    #
    # @param x [Integer] indice del campione, 0..2^64-1
    # @return [Integer, Float, nil] il valore (0 per un campione mai scritto
    #   nella finestra); nil se x è fuori dalla finestra ({#window})
    # @raise [TypeError, ArgumentError] se x non è un intero 0..2^64-1
    # @raise [ClosedError] se il grafico è chiuso
    def sample(x)
      Guard.run do
        ptr = to_ptr
        Util.uint64!(x, 'x')
        return nil unless window.cover?(x)

        read_sample(ptr, x - @base)
      end
    end

    private

    # +ncuplot_destroy+ / +ncdplot_destroy+: distruggono anche il piano.
    def destroy_native = Guard.run { @double ? FFI.ncdplot_destroy(to_ptr) : FFI.ncuplot_destroy(to_ptr) }

    # Valore del tipo del grafico (Integer uint64 o Float finito).
    def value!(value, name) = @double ? Util.float!(value, name) : Util.uint64!(value, name)

    def valid_value?(value) = @double ? value.finite? : Util::UINT64.cover?(value)

    # Regole di +create_*+ (plot.c:447-462), controllate prima di toccare il piano.
    def check_domain!(detect_max_only)
      if @min == @max && !@min.zero?
        raise ArgumentError, "min == max (#{@min}) vale solo per 0, il dominio automatico"
      end
      raise ArgumentError, "max (#{@max}) < min (#{@min})" if @max < @min
      if Util.bool!(detect_max_only, 'detect_max_only') && @min != @max
        raise ArgumentError, 'detect_max_only: richiede il dominio automatico (min: 0, max: 0)'
      end

      @fixed = @min != @max
    end

    # Titolo senza caratteri di controllo (il C lo scrive con printf).
    def title!(title)
      text = Util.string!(title, 'title')
      raise ArgumentError, "title = #{title.inspect} contiene caratteri di controllo" if text.match?(/\p{Cc}/)

      text
    end

    # Blitter scelto da +lookup_blitset+ (blit.c:1297-1375) per le capacità
    # del terminale; DEFAULT è +ncplot_defblitter+ (blitset.h:51).
    def resolve_blitter(ctx, plane, requested, no_degrade)
      caps = ctx.capabilities
      id = if requested == FFI::NCBLIT_DEFAULT
             caps.utf8? ? FFI::NCBLIT_8x1 : FFI::NCBLIT_1x1
           else
             requested
           end
      loop do
        available, fallback = blitter_support(ctx, caps, plane, id)
        return id if available

        if no_degrade
          raise WidgetError, "blitter #{Util.enum_symbol(Util::BLITTERS, id).inspect} non disponibile " \
                             'su questo terminale (no_degrade: true)'
        end

        id = fallback
      end
    end

    # @return [Array(Boolean, Integer)] [disponibile, ripiego]
    def blitter_support(ctx, caps, plane, id)
      case id
      when FFI::NCBLIT_BRAILLE then [caps.braille?, FFI::NCBLIT_4x2]
      when FFI::NCBLIT_4x2 then [caps.octants?, FFI::NCBLIT_3x2]
      when FFI::NCBLIT_PIXEL then [pixel_plot?(ctx, plane), FFI::NCBLIT_3x2]
      when FFI::NCBLIT_8x1 then [caps.quadrants?, FFI::NCBLIT_4x1]
      when FFI::NCBLIT_4x1 then [caps.quadrants?, FFI::NCBLIT_2x1]
      when FFI::NCBLIT_3x2 then [caps.sextants?, FFI::NCBLIT_2x2]
      when FFI::NCBLIT_2x2 then [caps.quadrants?, FFI::NCBLIT_2x1]
      when FFI::NCBLIT_2x1 then [caps.halfblocks?, FFI::NCBLIT_1x1]
      else [true, nil] # NCBLIT_1x1
      end
    end

    # Pixel solo con le dimensioni in pixel della cella: con 0 il numero di
    # slot sarebbe 0 e il C dividerebbe per zero (x % slotcount).
    def pixel_plot?(ctx, plane)
      geom = plane.pixel_geom
      ctx.pixel_support != :none && geom[:cell_pixel_x].positive? && geom[:cell_pixel_y].positive?
    end

    # Numero di slot di +create_*+ (plot.c:483-498).
    def slot_count_for(cols, width, range_x)
      scaled = cols * width
      prefix = FFI::NCPREFIXCOLUMNS * width
      count = range_x.zero? || cols < range_x ? scaled : range_x
      count = scaled - prefix if @label_ticks && count + prefix > scaled && scaled > prefix
      count
    end

    # Con label_ticks e 7 colonne o meno +finalx+ va in underflow (plot.c:290)
    # e il ridisegno scrive fuori dal piano.
    def check_width!
      return unless @label_ticks

      cols = @plane.dim_x
      return if cols > FFI::NCPREFIXCOLUMNS

      raise WidgetError, "il piano del grafico ha #{cols} colonne: con label_ticks ne servono almeno " \
                         "#{FFI::NCPREFIXCOLUMNS + 1} (il C scriverebbe fuori dal piano)"
    end

    # Coordinata C di x: [xc, base], oppure nil se x è dietro la finestra. Un
    # salto di almeno slot_count azzera la finestra e il C riparte dallo slot 0:
    # il wrapper sceglie allora un xc multiplo di slot_count, così l'indice
    # +x % slotcount+ usato da sample e dal controllo del dominio resta uguale
    # a quello circolare della scrittura (bug di 3.0.17, plot.c:595 contro 657).
    def c_coordinate(x)
      if x > @newest
        if x - @newest >= @slot_count
          xc = ((@newest_c + (2 * @slot_count) - 1) / @slot_count) * @slot_count
          base = x - xc
        else
          base = @base
          xc = x - base
        end
        raise ArgumentError, "x = #{x}: la finestra del grafico non può avanzare oltre" if xc > Util::INT64.max

        [xc, base]
      elsif x > @newest - @slot_count
        [x - @base, @base]
      end
    end

    # Registra l'avanzamento della finestra fatto dal C (window_slide non
    # fallisce mai).
    def advance!(x, xc, base)
      return unless x > @newest

      @newest = x
      @newest_c = xc
      @base = base
    end

    # Valore dello slot C xc (in finestra).
    def read_sample(ptr, xc)
      if @double
        buf = ::FFI::MemoryPointer.new(:double)
        rc = FFI.ncdplot_sample(ptr, xc, buf)
      else
        buf = ::FFI::MemoryPointer.new(:uint64)
        rc = FFI.ncuplot_sample(ptr, xc, buf)
      end
      raise WidgetError, "finestra del grafico non coerente con il C (x C = #{xc})" unless rc.zero?

      @double ? buf.read_double : buf.read_uint64
    end

    # -1 da add/set: con il dominio fisso il campione è memorizzato ma fuori
    # da [min, max] (plot.c:583-586, 706-708); altrimenti è fallito il ridisegno.
    def sample_result(ptr, xc, rc, what)
      return true if rc.zero?

      value = read_sample(ptr, xc)
      return false if @fixed && (value < @min || value > @max)

      raise WidgetError, "#{what}: ridisegno del grafico fallito (#{rc})"
    end
  end
end
