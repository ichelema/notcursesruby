# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Barra di avanzamento (+ncprogbar+) che occupa tutto il piano: orizzontale
  # se il piano ha più colonne che righe (in 3.0.17 senza il fattore 2
  # dell'header), altrimenti verticale. Si riempie da sinistra a destra o dal
  # basso in alto (al contrario con retrograde: true), con un gradiente tra i
  # colori dei quattro angoli e una risoluzione di 1/8 di cella.
  #
  # La barra prende possesso del piano ricevuto (vedi {Widget}) e lo
  # distrugge alla chiusura. Alla creazione non disegna nulla; ogni
  # {#progress=} ridipinge tutto il piano (il contenuto precedente si perde),
  # senza render. Il piano si può ridimensionare: l'orientamento si ricalcola
  # al disegno successivo.
  #
  # I colori dell'esempio, diversi tra sinistra e destra, richiedono un piano
  # largo almeno 2 colonne, e senza UTF-8 anche alto almeno 2 righe: vedi la
  # regola dei colori in {#initialize}.
  #
  # @example
  #   plane = nc.stdplane.create_child(rows: 1, cols: 40, y: 10, x: 2)
  #   bar = Notcurses::ProgBar.new(plane, ul_channel: Notcurses::Channel.rgb(0, 80, 0),
  #                                ur_channel: Notcurses::Channel.rgb(0, 255, 0),
  #                                bl_channel: Notcurses::Channel.rgb(0, 80, 0),
  #                                br_channel: Notcurses::Channel.rgb(0, 255, 0))
  #   bar.progress = 0.25
  #   nc.render
  class ProgBar
    include Widget
    extend Resource::ClassMethods

    # Crea la barra sul piano (+ncprogbar_create+). I quattro colori devono
    # essere coerenti per il gradiente (tutti di default o nessuno, stesso
    # alpha, niente indici di palette), altrimenti {#progress=} fallisce.
    #
    # Regola di 3.0.17 sulle dimensioni del piano (fill.c:192-197,238-255):
    # su un piano largo 1 colonna, e senza UTF-8 ({Context#can_utf8?} falso)
    # anche su un piano alto 1 riga, ul_channel deve essere uguale a
    # ur_channel e bl_channel a br_channel. Senza UTF-8 un piano 1x1 vuole i
    # quattro colori uguali. La regola vale a ogni {#progress=}, sulle
    # dimensioni correnti del piano: una barra può iniziare a fallire dopo un
    # resize.
    #
    # @param plane [Plane] piano posseduto dal wrapper, non lo stdplane e non
    #   già di un widget: passa alla barra
    # @param ul_channel [Channel, Integer] colore dell'angolo in alto a sinistra
    # @param ur_channel [Channel, Integer] colore dell'angolo in alto a destra
    # @param bl_channel [Channel, Integer] colore dell'angolo in basso a sinistra
    # @param br_channel [Channel, Integer] colore dell'angolo in basso a destra
    # @param retrograde [Boolean] NCPROGBAR_OPTION_RETROGRADE: si riempie da
    #   destra a sinistra o dall'alto in basso
    # @raise [WidgetError] se +ncprogbar_create+ fallisce (il piano risulta
    #   distrutto); se il piano è lo stdplane, è già di un widget o non è
    #   posseduto; dentro un callback chiamato da notcurses
    # @raise [TypeError, ArgumentError] se un'opzione non è valida
    # @raise [ClosedError] se il piano è chiuso
    def initialize(plane, ul_channel: 0, ur_channel: 0, bl_channel: 0, br_channel: 0, retrograde: false)
      claim_plane!(plane)
      ctx = plane.context
      ctx.check_not_in_callback!('ProgBar.new', WidgetError)
      opts = FFI::NcProgbarOptions.new
      opts[:ulchannel] = Util.channel_value(ul_channel, 'ul_channel')
      opts[:urchannel] = Util.channel_value(ur_channel, 'ur_channel')
      opts[:blchannel] = Util.channel_value(bl_channel, 'bl_channel')
      opts[:brchannel] = Util.channel_value(br_channel, 'br_channel')
      opts[:flags] = Util.flag(retrograde, FFI::NCPROGBAR_OPTION_RETROGRADE, 'retrograde')
      ptr = FFI.ncprogbar_create(plane.to_ptr, opts)
      if ptr.null?
        plane_destroyed_on_failure!(plane)
        raise WidgetError, 'ncprogbar_create ha restituito NULL (il piano è stato distrutto)'
      end
      attach!(ptr, plane)
      @progress_set = false
    end

    # Piano della barra (+ncprogbar_plane+): lo stesso Plane passato a
    # {#initialize}.
    #
    # @return [Plane]
    # @raise [ClosedError] se la barra è chiusa
    def plane = @context.plane_for(FFI.ncprogbar_plane(to_ptr))

    # Avanzamento corrente (+ncprogbar_progress+).
    #
    # Bug di 3.0.17 aggirato: il C non inizializza il valore alla creazione
    # (progbar.c:18-23); prima del primo {#progress=} il wrapper restituisce 0.0.
    #
    # @return [Float] 0.0..1.0 (può differire di qualche ulp dal valore
    #   impostato, vedi {#progress=})
    # @raise [ClosedError] se la barra è chiusa
    def progress
      ptr = to_ptr
      @progress_set ? FFI.ncprogbar_progress(ptr) : 0.0
    end

    # Imposta l'avanzamento e ridisegna la barra (+ncprogbar_set_progress+),
    # senza render.
    #
    # Bug di 3.0.17 aggirati: NaN supera il controllo del C (comportamento
    # indefinito nel disegno), e il wrapper lo rifiuta; per alcuni valori
    # (per esempio 0.8333333333333333 su 18 celle) l'arrotondamento porta
    # l'indice del glifo di bordo a 8, oltre l'array dei glifi (progbar.c:124:
    # il C restituisce -1 e lascia la barra disegnata a metà): il wrapper
    # abbassa il valore di qualche ulp, quanto basta per restare nell'array.
    #
    # @param value [Numeric] 0.0..1.0
    # @raise [WidgetError] se +ncprogbar_set_progress+ fallisce (per esempio
    #   con colori incoerenti per il gradiente, o diversi tra sinistra e destra
    #   su un piano largo 1 colonna, e senza UTF-8 alto 1 riga: vedi la regola
    #   in {#initialize}): {#progress} restituisce
    #   comunque il nuovo valore, che il C ha memorizzato prima del disegno
    # @raise [TypeError, ArgumentError] se value non è un numero reale finito
    #   in 0..1
    # @raise [ClosedError] se la barra è chiusa
    def progress=(value)
      ptr = to_ptr
      p = edge_safe(Util.float!(value, 'progress', 0.0..1.0))
      rc = FFI.ncprogbar_set_progress(ptr, p)
      @progress_set = true # il C memorizza p anche se poi il disegno fallisce
      Util.check!(rc, WidgetError, 'ncprogbar_set_progress')
    end

    private

    def destroy_native = FFI.ncprogbar_destroy(to_ptr)

    # Aritmetica di progbar_redraw nella build di 3.0.17 (disassemblata:
    # notcurses compila con -freciprocal-math, quindi range * p invece di
    # p / (1 / range)): chunks = trunc(range * p), indice del glifo di bordo =
    # trunc((p - (1 / range) * chunks) * (range * 8)). Con chunks >= range il
    # C non disegna il bordo. Abbassa p finché l'indice è < 8.
    def edge_safe(p)
      view = @plane.to_ptr
      rows = FFI.ncplane_dim_y(view)
      cols = FFI.ncplane_dim_x(view)
      range = cols > rows ? cols : rows
      loop do
        chunks = (range * p).to_i
        return p if chunks >= range || ((p - ((1.0 / range) * chunks)) * (range * 8.0)).to_i < 8

        p = p.prev_float
      end
    end
  end
end
