# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Parti comuni dei widget di notcurses (Selector, MultiSelector, Menu,
  # Reader, Reel, Tabbed, Tree, Plot, ProgBar) e degli altri oggetti C legati a
  # un piano (FdPlane, Subprocess).
  #
  # Ciclo di vita. Un widget appartiene al suo {Context}, che lo chiude prima di
  # +notcurses_stop+ e prima di {Context#drop_planes} (con alcuni widget vivi il
  # C farebbe un double free). Quasi tutti i widget prendono possesso del piano
  # ricevuto e lo distruggono alla chiusura: da quel momento {Plane#close} su
  # quel piano non fa nulla, il suo callback di resize non si può cambiare e il
  # piano risulta chiuso quando il widget si chiude. Il GC non distrugge mai un
  # widget: chiudilo con {#close}, o usa +open+ con un blocco.
  #
  # Thread: come per il resto di notcurses, usa un widget da un solo thread
  # alla volta.
  #
  # Per chi scrive un widget: la classe include il modulo, estende
  # {Resource::ClassMethods}, implementa il metodo privato +destroy_native+ (il
  # distruttore C, chiamato una sola volta da {#close}), tiene i
  # +::FFI::Function+ in +@callbacks+ e, dopo una creazione riuscita, chiama
  # +attach!+.
  module Widget
    include Resource

    # @return [Context] contesto del widget
    attr_reader :context

    # Piano del widget.
    #
    # @return [Plane]
    # @raise [ClosedError] se il widget è chiuso
    def plane
      Guard.run do
        to_ptr
        @plane
      end
    end

    # Distrugge il widget e, se è suo, il piano. Idempotente.
    #
    # Da un gestore +trap+ che poi torna al codice interrotto, la distruzione
    # non è rinviata come in {Context#close}: se il segnale ha interrotto
    # un'operazione sul widget o sul suo piano, il C usa memoria già liberata.
    # Da un gestore +trap+ non chiudere un widget in uso (ICH-540).
    #
    # @return [nil]
    # @raise [WidgetError] dentro un callback chiamato da notcurses (il C sta
    #   ancora usando il widget)
    def close
      return nil if @closed

      @context.check_not_in_callback!("#{self.class.name}#close", WidgetError)
      begin
        destroy_native
      ensure
        @closed = true
        @plane.invalidate! if @owns_plane
        @context.planes_destroyed!
        @context.disown(self)
        @callbacks = nil
      end
      nil
    end
    alias destroy close

    private

    # Controlla un piano da dare a un widget che ne prende possesso.
    #
    # @return [Plane] plane
    # @raise [TypeError] se plane non è un Plane
    # @raise [WidgetError] se il piano è lo stdplane, appartiene già a un widget
    #   (il C distruggerebbe il piano e l'altro widget) o non è posseduto dal
    #   wrapper (piano preso in prestito)
    # @raise [ClosedError] se il piano è chiuso
    def claim_plane!(plane)
      Guard.run do
        raise TypeError, "plane deve essere Notcurses::Plane, non #{plane.class}" unless plane.is_a?(Plane)

        plane.to_ptr
        raise WidgetError, 'lo stdplane non si può dare a un widget' if plane.stdplane?
        raise WidgetError, 'il piano appartiene già a un widget' if plane.widget_plane?
        raise WidgetError, 'il piano non è posseduto dal wrapper (preso in prestito?)' unless plane.owned?

        plane
      end
    end

    # Completa una creazione riuscita.
    #
    # @param ptr [::FFI::Pointer] puntatore C del widget
    # @param plane [Plane] piano del widget
    # @param owns_plane [Boolean] true se il distruttore C distrugge il piano
    def attach!(ptr, plane, owns_plane: true)
      @ptr = ptr
      @context = plane.context
      @owner = @context
      @closed = false
      @callbacks ||= []
      @plane = plane
      @owns_plane = owns_plane
      plane.transfer_to(self) if owns_plane
      @context.adopt(self)
    end

    # Creazione fallita dopo la quale il C ha distrutto il piano ricevuto.
    def plane_destroyed_on_failure!(plane)
      ctx = plane.context
      plane.invalidate!
      ctx.planes_destroyed!
    end

    # Testo per il C: UTF-8 valido, senza caratteri di controllo. Per questi
    # ncstrwidth restituisce -1, e il C non sempre lo controlla (titoli e
    # descrizioni: larghezza (unsigned)-1 e layout rotto, selector.c:308, 413,
    # 909-913, menu.c:159).
    def text!(value, name)
      text = Util.string!(value, name)
      if text.match?(/\p{Cc}/) || FFI.ncstrwidth(text, nil, nil).negative?
        raise ArgumentError, "#{name} = #{value.inspect} contiene caratteri di controllo o non stampabili"
      end

      text
    end

    # MemoryPointer di un testo già validato (tenuta in keep fino al ritorno
    # del C), NULL per nil.
    def c_text(text, keep)
      return ::FFI::Pointer::NULL if text.nil?

      keep << ::FFI::MemoryPointer.from_string(text)
      keep.last
    end

    # Struct C dell'evento; nil per un evento vuoto (id 0, come allo scadere
    # del timeout di notcurses_get, o (uint32_t)-1), da non offrire al C: per
    # esempio un id 0 apre la prima sezione di un menu (menu.c:746).
    def input_struct(input)
      raise TypeError, "input deve essere Notcurses::Input, non #{input.class}" unless input.is_a?(Input)

      input.to_ffi unless input.id.zero? || input.id == 0xffff_ffff
    end
  end
end
