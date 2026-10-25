# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Legge un IO in un thread e passa i dati a un blocco, che li scrive su un
  # piano: l'equivalente di +ncfdplane+, scritto in Ruby puro.
  #
  # Perché non il C: in 3.0.17 +ncfdplane_destroy+ chiamato mentre un callback
  # Ruby è in corso (o dal callback) blocca l'intero interprete (il pthread
  # viene cancellato dentro il trampolino di ruby-ffi); con follow il thread C
  # gira al 100% di CPU a fine file; il ritorno del callback non ferma la
  # lettura. Qui il thread è un Thread Ruby con +IO#readpartial+: nessuno di
  # questi blocchi è possibile, e {#close} lo ferma anche mentre aspetta dati.
  #
  # Come il C: la creazione attiva lo scrolling del piano; il piano non passa
  # all'FdPlane (resta del chiamante e non viene distrutto); l'IO invece sì,
  # e {#close} lo chiude (+ncfdplane_destroy+ chiude il fd). Il blocco riceve
  # l'FdPlane e i byte letti (al massimo {CHUNK_SIZE}), e scrive sul piano con
  # le API normali: il wrapper non scrive nulla.
  #
  # Thread. Il blocco e on_done: girano nel thread di lettura, non in quello
  # che ha creato l'FdPlane. Le chiamate a notcurses tengono il GVL, quindi
  # due chiamate C non si sovrappongono mai; ma una sequenza di chiamate del
  # thread principale (per esempio putstr seguito da render) può essere
  # interrotta tra una chiamata e l'altra dal blocco. Il wrapper non aggiunge
  # lock: se il blocco e il thread principale usano gli stessi oggetti,
  # sincronizzali tu (per esempio con un Mutex attorno a scrittura e render),
  # oppure passa i dati al thread principale con una Queue. Non chiudere il
  # piano mentre l'FdPlane è aperto: tra un blocco e l'altro il blocco
  # troverebbe un piano chiuso (ClosedError); durante il blocco l'accesso non
  # è protetto. Dentro il blocco le interruzioni asincrone (Thread#kill,
  # Thread#raise, Timeout) arrivano solo alle attese (sleep, IO, Queue, ...),
  # mai a metà di una chiamata del wrapper.
  #
  # Errori del blocco. Un'eccezione nel blocco o in on_done: ferma la lettura
  # (on_done: non viene chiamato) e viene rilanciata da {#close}, dopo aver
  # liberato tutto; {Context#close} la rilancia dopo +notcurses_stop+.
  #
  # Il contesto chiude l'FdPlane prima di +notcurses_stop+ e di
  # {Context#drop_planes}.
  #
  # @example Le righe aggiunte a un log, per 5 secondi
  #   plane = nc.stdplane.create_child(rows: 10, cols: 60)
  #   # putstr rifiuta i caratteri di controllo (tranne "\n") e l'UTF-8 non valido
  #   clean = ->(bytes) { bytes.force_encoding('UTF-8').scrub('?').gsub(/[\x00-\x09\x0b-\x1f\x7f]/, ' ') }
  #   show = ->(f, bytes) { f.plane.putstr(clean.call(bytes)) }
  #   Notcurses::FdPlane.open(plane, File.open('app.log'), follow: true, on_data: show) do
  #     50.times { nc.render; sleep 0.1 }
  #   end
  class FdPlane
    include Widget
    extend Resource::ClassMethods

    # Byte letti al massimo per ogni chiamata del blocco (BUFSIZ di glibc,
    # come il C).
    CHUNK_SIZE = 8192

    # Secondi di attesa tra due tentativi di lettura dopo la fine del file,
    # con follow: true (il C rilegge subito, a ciclo continuo).
    FOLLOW_INTERVAL = 0.1

    # Avvia la lettura di io in un thread (Ruby puro: sostituisce
    # +ncfdplane_create+). Il thread parte subito: il blocco può essere
    # chiamato prima che new ritorni.
    #
    # @param plane [Plane] piano su cui il blocco scrive: resta del chiamante
    #   (non viene distrutto); il wrapper vi attiva lo scrolling
    # @param io [IO] sorgente dei dati (pipe, file, socket, ...): passa
    #   all'FdPlane, che la chiude in {#close}. Se la creazione fallisce resta
    #   del chiamante
    # @param follow [Boolean] true = a fine file continua ad aspettare dati,
    #   come +tail -f+ (ritenta ogni {FOLLOW_INTERVAL} secondi); false = la
    #   fine del file termina la lettura
    # @param on_data [#call, nil] alternativa al blocco, utile con +open+:
    #   +call(fdplane, bytes)+
    # @param on_done [#call, nil] chiamato una volta, nel thread di lettura,
    #   quando la lettura termina da sola: +call(fdplane, errore)+, con errore
    #   nil a fine file (senza follow) oppure l'eccezione di lettura
    #   (IOError o SystemCallError, come il fderrno di +ncfdplane_done_cb+).
    #   Non viene chiamato dopo {#close} né dopo un'eccezione nel blocco
    # @yieldparam fdplane [FdPlane] questo oggetto ({Widget#plane} è il piano)
    # @yieldparam bytes [String] byte letti (String BINARY, 1..{CHUNK_SIZE}):
    #   possono contenere NUL, caratteri di controllo e caratteri UTF-8 spezzati
    #   tra due chiamate; {Plane#putstr} li rifiuta, quindi ripuliscili prima
    #   (vedi l'esempio della classe)
    # @raise [ArgumentError] se manca il blocco dei dati, se ci sono sia il
    #   blocco sia on_data:, se io è chiuso
    # @raise [TypeError] se plane non è un Plane, io non è un IO, follow non è
    #   un Boolean, on_data:/on_done: non rispondono a call
    # @raise [ClosedError] se il piano è chiuso
    # @raise [ThreadError] se il thread non si può creare
    def initialize(plane, io, follow: false, on_data: nil, on_done: nil, &block)
      callbacks = callbacks!(on_data, on_done, block)
      raise TypeError, "io deve essere un IO, non #{io.class}" unless io.is_a?(IO)
      raise ArgumentError, 'io è chiuso' if io.closed?

      start!(plane, io, Util.bool!(follow, 'follow'), callbacks)
    end

    # Puntatore C del piano (+ncplane*+): l'FdPlane è Ruby puro e non ha un
    # oggetto C proprio. Serve al controllo di chiusura.
    #
    # @return [::FFI::Pointer]
    # @raise [ClosedError] se l'FdPlane è chiuso
    def to_ptr = super

    # @return [Boolean] true quando la lettura è terminata da sola: fine file
    #   senza follow, errore di lettura o eccezione nel blocco (in questo caso
    #   {#close} la rilancia)
    # @raise [ClosedError] se l'FdPlane è chiuso
    def done?
      to_ptr
      !@thread.alive?
    end

    # Ferma la lettura e chiude io (Ruby puro: sostituisce
    # +ncfdplane_destroy+). Il thread viene fermato anche se aspetta dati; se
    # è dentro il blocco, il blocco viene interrotto alla sua prima attesa
    # (sleep, IO, Queue, ...) o finisce, e close lo attende: un blocco che
    # calcola senza fine non si ferma, e un +IO#readpartial+/+sysread+ del
    # blocco iniziato dopo la richiesta di chiusura aspetta i suoi dati (limite
    # di Ruby 4.0: usa +wait_readable+). Chiamato dal blocco stesso non attende
    # (il thread esce dopo il blocco). Non distrugge il piano. Idempotente.
    #
    # @return [nil]
    # @raise [Exception] la prima eccezione sollevata dal blocco o da on_done:
    #   (una volta sola: le chiamate successive restituiscono nil)
    def close
      return @result if @closed

      @closed = true
      @result = shutdown
      @context.disown(self)
      Util.reraise!(@errors)
      @result
    end
    alias destroy close

    private

    # Il blocco dei dati (o on_data:) e on_done:, controllati.
    # @return [Array(#call, #call)]
    def callbacks!(on_data, on_done, block)
      raise ArgumentError, 'passa il blocco dei dati oppure on_data:, non entrambi' if on_data && block

      data = on_data || block
      raise ArgumentError, 'serve un blocco per i dati (oppure on_data:)' if data.nil?
      raise TypeError, "on_data: deve rispondere a call, non #{data.class}" unless data.respond_to?(:call)
      unless on_done.nil? || on_done.respond_to?(:call)
        raise TypeError, "on_done: deve rispondere a call, non #{on_done.class}"
      end

      [data, on_done]
    end

    # Registra l'oggetto nel contesto e avvia il thread di lettura.
    def start!(plane, io, follow, (on_data, on_done))
      raise TypeError, "plane deve essere Notcurses::Plane, non #{plane.class}" unless plane.is_a?(Plane)

      plane.scrolling = true # come ncfdplane_create (fd.c:108)
      @io = io
      @follow = follow
      @on_data = on_data
      @on_done = on_done
      @errors = []
      @result = nil
      attach!(plane.to_ptr, plane, owns_plane: false)
      begin
        @thread = Thread.new { run }
      rescue Exception # rubocop:disable Lint/RescueException
        @closed = true
        @context.disown(self)
        raise
      end
      @thread.name = self.class.name
    end

    # Corpo del thread. Il kill di {#close} arriva subito durante le attese
    # del wrapper (:immediate), e dentro il blocco solo alle attese del blocco
    # (:on_blocking): mai a metà di una chiamata del wrapper, che lascerebbe
    # il suo stato incoerente con il C.
    def run
      Thread.handle_interrupt(Object => :on_blocking) do
        Util.guard(@errors, nil) do
          error = read_loop
          finish(error) unless @closed
        end
      end
    end

    # @return [Exception, nil] errore di lettura, o nil a fine file o dopo close
    def read_loop
      until @closed
        data = read_chunk
        case data
        when String
          return nil if @closed

          @on_data.call(self, data)
        when :eof
          return nil unless @follow

          Thread.handle_interrupt(Object => :immediate) { sleep FOLLOW_INTERVAL }
        else
          return data
        end
      end
      nil
    end

    # @return [String, :eof, Exception]
    def read_chunk
      Thread.handle_interrupt(Object => :immediate) { @io.readpartial(CHUNK_SIZE) }
    rescue EOFError
      :eof
    rescue IOError, SystemCallError => e
      e
    end

    # Fine della lettura (nel thread di lettura).
    def finish(error) = @on_done&.call(self, error)

    # Ferma il thread e chiude io.
    # @return [nil] il valore di {#close}
    def shutdown
      stop_reader
      @io.close
      nil
    end

    def stop_reader
      return if Thread.current.equal?(@thread) # close dal blocco: il thread esce dopo il blocco

      @thread.kill
      @thread.join
    end
  end
end
