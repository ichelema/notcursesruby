# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Avvia un programma e passa a un blocco il suo output (stdout e stderr
  # insieme), che il blocco scrive su un piano: l'equivalente di +ncsubproc+,
  # scritto in Ruby puro con +Process.spawn+ e il thread di lettura di
  # {FdPlane}.
  #
  # Perché non il C: in 3.0.17 +ncsubproc_destroy+ con il figlio ancora vivo
  # va in deadlock con Ruby (aspetta un thread C che aspetta il GVL), lascia
  # aperti 3 fd per processo, il figlio eredita lo stdin di notcurses, un exec
  # fallito non viene segnalato, il SIGKILL del destroy può colpire un PID
  # riciclato e +restart_period+ è ignorato. Qui:
  # - un exec fallito solleva subito (Errno::ENOENT, Errno::EACCES, ...);
  # - lo stdin del figlio è /dev/null e il figlio non eredita altri fd;
  # - {#close} uccide il figlio solo se non è ancora stato raccolto (SIGKILL,
  #   come il C), lo raccoglie e chiude tutti i fd.
  #
  # Differenze dal C: on_done: arriva quando l'output è finito (EOF della
  # pipe) e il figlio è uscito, con il Process::Status; il C lo chiama
  # all'uscita del figlio, anche con dati ancora da leggere, senza lo stato.
  # Un nipote che tiene aperta la pipe ritarda on_done: fino alla sua uscita
  # (o a {#close}).
  #
  # Thread, piano, errori del blocco: come {FdPlane}.
  #
  # @example
  #   plane = nc.stdplane.create_child(rows: 10, cols: 60)
  #   done = Queue.new
  #   sub = Notcurses::Subprocess.new(plane, 'ls', '-l', on_done: ->(_s, status) { done << status }) do |s, bytes|
  #     s.plane.putstr(bytes.force_encoding('UTF-8').scrub('?').gsub(/[\x00-\x09\x0b-\x1f\x7f]/, ' '))
  #   end
  #   status = done.pop(timeout: 5) # Queue#pop(timeout:) richiede Ruby 3.2
  #   nc.render
  #   sub.close
  class Subprocess < FdPlane
    # Secondi di attesa del figlio dopo il SIGKILL di {#close}: oltre, close
    # restituisce nil (un figlio bloccato nel kernel, stato D).
    KILL_TIMEOUT = 5.0

    # Avvia program con gli argomenti args (Ruby puro: sostituisce
    # +ncsubproc_createv+, +ncsubproc_createvp+ e +ncsubproc_createvpe+) e
    # un thread che legge il suo output. Il programma è eseguito senza shell:
    # gli argomenti non vengono interpretati.
    #
    # @param plane [Plane] piano su cui il blocco scrive: resta del chiamante
    #   (non viene distrutto); il wrapper vi attiva lo scrolling
    # @param program [String] programma da eseguire, non vuoto
    # @param args [Array<String>] argomenti (argv[1..]); argv[0] è program
    # @param env [Hash{String => String}, nil] nil = il figlio eredita
    #   l'ambiente; un Hash = l'unico ambiente del figlio (come +execvpe+). Se
    #   l'Hash contiene PATH, la ricerca di program usa quel PATH (il C usa
    #   quello del processo)
    # @param path [Boolean] true = cerca program nel PATH se non contiene "/"
    #   (+execvp+); false = program è un percorso, relativo alla directory
    #   corrente se non contiene "/" (+execv+)
    # @param on_data [#call, nil] alternativa al blocco, utile con +open+:
    #   +call(subprocess, bytes)+
    # @param on_done [#call, nil] chiamato una volta, nel thread di lettura,
    #   quando l'output è finito e il figlio è uscito: +call(subprocess,
    #   status)+, con status un Process::Status, o nil se il figlio è stato
    #   raccolto da altri (per esempio +Process.wait+ senza pid). Non viene
    #   chiamato dopo {#close} né dopo un'eccezione nel blocco
    # @yieldparam subprocess [Subprocess] questo oggetto
    # @yieldparam bytes [String] byte letti, come in {FdPlane#initialize}
    # @raise [SystemCallError] se il programma non si può eseguire
    #   (Errno::ENOENT, Errno::EACCES, ...)
    # @raise [ArgumentError] se manca il blocco dei dati, se ci sono sia il
    #   blocco sia on_data:, se program è vuoto, se un nome di env è vuoto o
    #   contiene "=", se un testo non è UTF-8 valido o contiene NUL
    # @raise [TypeError] se un argomento non è del tipo giusto
    # @raise [ClosedError] se il piano è chiuso
    # @raise [ThreadError] se il thread non si può creare (il figlio viene
    #   ucciso)
    def initialize(plane, program, *args, env: nil, path: true, on_data: nil, on_done: nil, &block)
      callbacks = callbacks!(on_data, on_done, block)
      raise TypeError, "plane deve essere Notcurses::Plane, non #{plane.class}" unless plane.is_a?(Plane)

      plane.to_ptr
      argv = [Util.string!(program, 'program')] + args.each_with_index.map { |a, i| Util.string!(a, "args[#{i}]") }
      raise ArgumentError, 'program è vuoto' if argv.first.empty?

      # execv: un nome senza "/" è relativo alla directory corrente (fd.c:205)
      command = Util.bool!(path, 'path') || argv.first.include?('/') ? argv.first : "./#{argv.first}"
      environment = env.nil? ? nil : env!(env)
      reader = spawn!(environment, [command, argv.first], argv.drop(1))
      begin
        start!(plane, reader, false, callbacks)
      rescue Exception # rubocop:disable Lint/RescueException
        kill_child
        @waiter.join(KILL_TIMEOUT)
        reader.close
        raise
      end
    end

    # @return [Integer] PID del figlio (per esempio per mandargli un segnale
    #   con +Process.kill+ prima di {#close})
    # @raise [ClosedError] se il sottoprocesso è chiuso
    def pid
      to_ptr
      @pid
    end

    # @return [Boolean] true quando l'output è finito e il figlio è uscito (o
    #   dopo un'eccezione nel blocco)
    # @raise [ClosedError] se il sottoprocesso è chiuso
    def done? = super

    # Ferma la lettura, uccide il figlio con SIGKILL se non è già stato
    # raccolto, lo raccoglie e chiude la pipe (Ruby puro: sostituisce
    # +ncsubproc_destroy+). Per il thread di lettura vale quanto detto in
    # {FdPlane#close}. Non distrugge il piano. Idempotente.
    #
    # @return [Process::Status, nil] stato di uscita del figlio (anche alle
    #   chiamate successive); nil se il figlio è stato raccolto da altri o non
    #   è uscito entro {KILL_TIMEOUT} secondi dal SIGKILL
    # @raise [Exception] la prima eccezione sollevata dal blocco o da on_done:
    #   (una volta sola)
    def close = super
    alias destroy close

    private

    # @return [Hash{String => String}]
    def env!(env)
      raise TypeError, "env deve essere un Hash, non #{env.class}" unless env.is_a?(Hash)

      env.to_h do |key, value|
        name = Util.string!(key, 'nome di env')
        if name.empty? || name.include?('=')
          raise ArgumentError, "nome di env #{key.inspect} non valido (vuoto o con \"=\")"
        end

        [name, Util.string!(value, "env[#{name.inspect}]")]
      end
    end

    # Avvia il figlio con stdout e stderr sulla pipe e stdin da /dev/null.
    # @return [IO] lato di lettura della pipe
    def spawn!(environment, command, args)
      reader, writer = IO.pipe
      begin
        spawn_args = environment ? [environment, command, *args] : [command, *args]
        @pid = Process.spawn(*spawn_args, in: File::NULL, out: writer, err: writer, close_others: true,
                                          unsetenv_others: !environment.nil?)
      rescue Exception # rubocop:disable Lint/RescueException
        reader.close
        raise
      ensure
        writer.close # il figlio ne ha una copia: senza chiuderla qui la pipe non arriverebbe mai a EOF
      end
      @waiter = Process.detach(@pid) # unico a raccogliere il figlio: niente kill a un PID riciclato
      reader
    end

    # Fine dell'output: aspetta l'uscita del figlio e chiama on_done:.
    def finish(_error)
      status = Thread.handle_interrupt(Object => :immediate) { @waiter.value }
      @on_done&.call(self, status) unless @closed
    end

    # @return [Process::Status, nil] il valore di {#close}
    def shutdown
      kill_child
      super
      @waiter.join(KILL_TIMEOUT)&.value
    end

    # SIGKILL solo a un figlio non ancora raccolto: finché il waiter è vivo il
    # PID non può essere riciclato.
    def kill_child
      Process.kill(:KILL, @pid) if @waiter.alive?
    rescue SystemCallError
      nil # uscito nel frattempo (ESRCH) o non più nostro (EPERM)
    end
  end
end
