# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Thread Ruby che, durante {UI::EventLoop#run}, legge i tasti di un
  # {Context}: aspetta su +notcurses_inputready_fd+ senza il GVL e svuota la
  # coda di notcurses a blocchi con +notcurses_getvec+. Gli eventi con un id
  # del filtro del run più interno (i tasti di segnale) diventano subito
  # {Input} e passano dal filtro, che li può scartare; gli altri restano nel
  # buffer come blocchi grezzi, e {Context#get} e {Context#getvec} ne fanno
  # {Input} quando li prendono. Il pipe {#ready_io} diventa leggibile quando il
  # buffer riceve eventi. Così il filtro alza il segnale di Ctrl+C, Ctrl+Z e
  # Ctrl+\ appena il tasto arriva, anche con il ciclo occupato in un handler,
  # e il thread svuota la coda di notcurses (8192 eventi) più in fretta di
  # quanto il thread C la riempie: costruire un {Input} costa circa 60 volte
  # leggere l'id.
  #
  # notcurses permette +notcurses_get+ in parallelo a +notcurses_render+, con
  # un solo thread alla volta nello stack di input (notcurses_input.3): mentre
  # il thread gira, {Context#get} legge solo il buffer. +notcurses_getvec+ non
  # rilascia il GVL, quindi una lettura non si sovrappone al codice Ruby degli
  # altri thread; {Context#close} ferma il thread prima di +notcurses_stop+
  # ({#halt}). Gli eventi rimasti nel buffer dopo run arrivano al
  # {Context#get} o al run successivo.
  #
  # Il buffer e i pipe usano solo operazioni atomiche sotto il GVL, senza
  # Mutex: {#halt} si può chiamare da un gestore +trap+. Il thread aggiunge in
  # fondo al buffer; solo il thread che prende gli eventi toglie dalla testa.
  #
  # @api private
  class InputReader
    # Eventi per chiamata C.
    BLOCK = 256
    # Byte di un evento (sizeof(ncinput)) e posizione del campo id.
    EVENT_BYTES = FFI::NcInput.size
    ID_OFFSET = FFI::NcInput.offset_of(:id)
    private_constant :BLOCK, :EVENT_BYTES, :ID_OFFSET

    # @param inputready_fd [Proc] restituisce il descrittore di
    #   +notcurses_inputready_fd+
    # @param getvec [Proc] chiamato con (buffer, slot): scrive nel buffer gli
    #   eventi in coda senza attendere (+notcurses_getvec+) e restituisce
    #   quanti sono, 0 con la coda vuota; può sollevare InputError
    def initialize(inputready_fd, getvec)
      @inputready_fd = inputready_fd
      @getvec = getvec
      @pending = []
      @filters = []
      @thread = nil
      @stop = false
      @ready_r = @ready_w = @stop_r = @stop_w = nil
    end

    # Aggiunge il filtro di un run e, se il thread non gira, lo avvia.
    #
    # @param filter [Proc] chiamato nel thread con l'{Input} di ogni evento
    #   letto che ha un id in ids; un valore vero scarta l'evento
    # @param ids [Hash{Integer => Object}] id degli eventi da filtrare
    # @return [IO] il pipe {#ready_io}
    def start(filter, ids)
      # un'eccezione asincrona (il SIGINT di un Ctrl+C già in coda) arriva dopo: filtro e thread sono già
      # registrati, e lo stop del chiamante li trova
      Thread.handle_interrupt(Object => :never) do
        # il filtro prima del thread: il primo evento letto deve già passare dal filtro
        @filters.push([filter, ids])
        start_thread unless @thread&.alive? # un thread morto (errore di lettura) non serve più
      end
      @ready_r
    end

    # Toglie il filtro di un run, se c'è (un'eccezione può arrivare prima che
    # {#start} lo registri). Senza altri run ferma il thread e chiude i pipe;
    # il buffer resta.
    #
    # @param filter [Proc] il filtro passato a {#start}
    # @return [nil]
    def stop(filter)
      # tutto o niente: un'eccezione asincrona a metà lascerebbe filtri, thread e pipe del run finito
      Thread.handle_interrupt(Object => :never) do
        index = @filters.rindex { |registered, _| registered.equal?(filter) }
        next if index.nil?

        # halt prima di togliere l'ultimo filtro: il thread non deve leggere tasti senza filtro
        halt if @filters.size == 1
        @filters.delete_at(index)
        next unless @filters.empty?

        [@ready_r, @ready_w, @stop_r, @stop_w].each { |io| io&.close }
        @ready_r = @ready_w = @stop_r = @stop_w = nil
      end
      nil
    end

    # Ferma il thread e lo aspetta: dopo il ritorno il thread non chiama più
    # notcurses. Sveglia chi aspetta su {#ready_io} (un {Context#get} in un
    # handler), che torna a leggere: con il contesto chiuso solleva
    # ClosedError. Idempotente; si può chiamare da un gestore +trap+, anche
    # mentre un altro halt aspetta lo stesso thread.
    #
    # @return [nil]
    def halt
      thread = @thread
      return nil unless thread

      @stop = true
      @stop_w.write_nonblock("\0", exception: false)
      # un'eccezione asincrona lascerebbe il thread vivo (il contesto potrebbe chiudersi sotto di lui) o
      # @thread impostato su un thread finito: arriva dopo
      Thread.handle_interrupt(Object => :never) do
        thread.join
        @thread = nil if @thread.equal?(thread)
        @ready_w&.write_nonblock("\0", exception: false)
      end
      nil
    end

    # @return [Boolean] true se il thread gira: gli eventi arrivano solo dal
    #   buffer
    def active? = !@thread.nil? && @thread.alive?

    # @return [Boolean] true se il buffer ha eventi (o un errore) da prendere
    def pending? = !@pending.empty?

    # @return [IO, nil] pipe che diventa leggibile quando il thread mette
    #   eventi nel buffer; nil fuori da run
    def ready_io = @ready_r

    # Prende il primo evento del buffer. Svuota prima il pipe {#ready_io}:
    # chi aspetta su {#ready_io} deve chiamare take finché restituisce nil.
    #
    # @return [Input, nil] nil con il buffer vuoto
    # @raise [InputError] l'errore di lettura del thread, al suo posto nella
    #   sequenza degli eventi
    def take
      drain(@ready_r)
      item = @pending.first
      return nil if item.nil?
      return take_raw(item) if item.is_a?(Array)

      @pending.shift
      raise item if item.is_a?(Exception)

      item
    end

    # Prende fino a count eventi del buffer, fermandosi prima di un errore.
    #
    # @param count [Integer] massimo, >= 1
    # @return [Array<Input>] gli eventi presi, anche vuoto
    # @raise [InputError] l'errore del thread, se è il primo del buffer
    def take_many(count)
      drain(@ready_r)
      events = []
      while events.size < count && (item = @pending.first)
        if item.is_a?(Exception)
          raise @pending.shift if events.empty?

          break
        end
        events << (item.is_a?(Array) ? take_raw(item) : @pending.shift)
      end
      events
    end

    private

    def start_thread
      begin
        input = IO.for_fd(@inputready_fd.call, autoclose: false) # il descrittore è di notcurses
        @ready_r, @ready_w = IO.pipe if @ready_r.nil?
        @stop_r, @stop_w = IO.pipe if @stop_r.nil?
      rescue Exception # rubocop:disable Lint/RescueException
        @filters.pop
        raise
      end
      drain(@stop_r)
      @stop = false
      @ready_w.write_nonblock("\0", exception: false) unless @pending.empty? # eventi del run precedente
      @thread = Thread.new { pump(input) } # rubocop:disable ThreadSafety/NewThread -- è lo scopo della classe
      @thread.name = "notcurses-input"
    end

    # Corpo del thread: un errore di lettura va nel buffer, al posto
    # dell'evento, e chiude il thread. Legge la coda prima di attendere:
    # notcurses svuota il pipe di prontezza a ogni lettura, anche con altri
    # eventi in coda (letti prima di run o lasciati da un halt). Dopo Key::EOF
    # notcurses non ha altro da dare: il thread aspetta solo halt.
    def pump(input)
      scratch = ::FFI::MemoryPointer.new(EVENT_BYTES, BLOCK, false)
      watched = [input, @stop_r]
      until @stop
        read = false
        until @stop || watched.size == 1
          count = @getvec.call(scratch, BLOCK)
          break if count.zero?

          read = true
          block = ::FFI::MemoryPointer.new(EVENT_BYTES, count, false)
          block.put_bytes(0, scratch.get_bytes(0, count * EVENT_BYTES))
          watched = [@stop_r] if scan(block, count)
          break if count < BLOCK # blocco non pieno: la coda è vuota
        end
        @ready_w.write_nonblock("\0", exception: false) if read
        IO.select(watched) unless @stop
      end
    rescue Exception => e # rubocop:disable Lint/RescueException
      @pending << e
      @ready_w.write_nonblock("\0", exception: false)
    end

    # Mette nel buffer i count eventi di block: a tratti grezzi, tranne quelli
    # con un id del filtro, che diventano Input e passano dal filtro. Si ferma
    # dopo Key::EOF (il C riempie di EOF il resto del blocco).
    # @return [Boolean] true se ha trovato Key::EOF
    def scan(block, count)
      filter, ids = @filters.last
      from = 0
      count.times do |i|
        id = block.get_uint32((i * EVENT_BYTES) + ID_OFFSET)
        if id == Key::EOF
          push_raw(block, from, i + 1)
          return true
        end
        next unless ids&.key?(id)

        push_raw(block, from, i)
        from = i + 1
        event = input_at(block, i)
        @pending << event unless filter.call(event)
      end
      push_raw(block, from, count)
      false
    end

    # Un tratto grezzo è [blocco, primo evento da prendere, fine esclusa].
    def push_raw(block, from, to)
      @pending << [block, from, to] if to > from
    end

    def take_raw(item)
      block, index, to = item
      if index + 1 == to
        @pending.shift
      else
        item[1] = index + 1
      end
      input_at(block, index)
    end

    def input_at(block, index) = Input.new(FFI::NcInput.new(block + (index * EVENT_BYTES)))

    def drain(reader)
      return if reader.nil?

      loop do
        data = reader.read_nonblock(4096, exception: false)
        break if data.nil? || data == :wait_readable
      end
    end
  end
  private_constant :InputReader
end
