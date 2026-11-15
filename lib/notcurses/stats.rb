# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Statistiche di un contesto (+ncstats+), copiate in un oggetto immutabile.
  #
  # La struct C viene allocata con +notcurses_stats_alloc+ e liberata con
  # +free+ subito dopo la copia: Stats non tiene memoria C.
  #
  # @example
  #   s = nc.stats
  #   puts "#{s.renders} render, #{s.failed_renders} falliti"
  class Stats
    # Valore che notcurses mette nei minimi finché non ha un campione.
    MIN_SENTINEL = 1 << 62
    private_constant :MIN_SENTINEL

    # Nomi dei campi, nell'ordine della struct C.
    FIELDS = %i[
      renders writeouts failed_renders failed_writeouts raster_bytes raster_max_bytes raster_min_bytes
      render_ns render_max_ns render_min_ns raster_ns raster_max_ns raster_min_ns writeout_ns
      writeout_max_ns writeout_min_ns cellelisions cellemissions fgelisions fgemissions bgelisions
      bgemissions defaultelisions defaultemissions refreshes sprixelemissions sprixelelisions sprixelbytes
      appsync_updates input_errors input_events hpa_gratuitous cell_geo_changes pixel_geo_changes fbbytes
      planes
    ].freeze

    # @return [Integer] render riusciti
    attr_reader :renders
    # @return [Integer] scritture sul terminale riuscite
    attr_reader :writeouts
    # @return [Integer] render falliti
    attr_reader :failed_renders
    # @return [Integer] scritture fallite
    attr_reader :failed_writeouts
    # @return [Integer] byte emessi dalla rasterizzazione
    attr_reader :raster_bytes
    # @return [Integer] massimo di byte in una rasterizzazione
    attr_reader :raster_max_bytes
    # @return [Integer, nil] minimo di byte in una rasterizzazione (nil senza campioni)
    attr_reader :raster_min_bytes
    # @return [Integer] nanosecondi totali di render
    attr_reader :render_ns
    # @return [Integer] massimo di nanosecondi in un render
    attr_reader :render_max_ns
    # @return [Integer, nil] minimo di nanosecondi in un render (nil senza campioni)
    attr_reader :render_min_ns
    # @return [Integer] nanosecondi totali di rasterizzazione
    attr_reader :raster_ns
    # @return [Integer] massimo di nanosecondi in una rasterizzazione
    attr_reader :raster_max_ns
    # @return [Integer, nil] minimo di nanosecondi in una rasterizzazione (nil senza campioni)
    attr_reader :raster_min_ns
    # @return [Integer] nanosecondi totali di scrittura
    attr_reader :writeout_ns
    # @return [Integer] massimo di nanosecondi in una scrittura
    attr_reader :writeout_max_ns
    # @return [Integer, nil] minimo di nanosecondi in una scrittura (nil senza campioni)
    attr_reader :writeout_min_ns
    # @return [Integer] celle non riemesse perché invariate
    attr_reader :cellelisions
    # @return [Integer] celle emesse
    attr_reader :cellemissions
    # @return [Integer] cambi di colore di primo piano evitati
    attr_reader :fgelisions
    # @return [Integer] cambi di colore di primo piano emessi
    attr_reader :fgemissions
    # @return [Integer] cambi di colore di sfondo evitati
    attr_reader :bgelisions
    # @return [Integer] cambi di colore di sfondo emessi
    attr_reader :bgemissions
    # @return [Integer] ritorni al colore di default evitati
    attr_reader :defaultelisions
    # @return [Integer] ritorni al colore di default emessi
    attr_reader :defaultemissions
    # @return [Integer] refresh completi del terminale
    attr_reader :refreshes
    # @return [Integer] sprixel emessi
    attr_reader :sprixelemissions
    # @return [Integer] sprixel non riemessi
    attr_reader :sprixelelisions
    # @return [Integer] byte di sprixel emessi
    attr_reader :sprixelbytes
    # @return [Integer] aggiornamenti sincronizzati dell'applicazione
    attr_reader :appsync_updates
    # @return [Integer] errori di input
    attr_reader :input_errors
    # @return [Integer] eventi di input
    attr_reader :input_events
    # @return [Integer] spostamenti orizzontali del cursore non necessari
    attr_reader :hpa_gratuitous
    # @return [Integer] cambi della geometria in celle
    attr_reader :cell_geo_changes
    # @return [Integer] cambi della geometria in pixel
    attr_reader :pixel_geo_changes
    # @return [Integer] byte del framebuffer (valore istantaneo)
    attr_reader :fbbytes
    # @return [Integer] piani esistenti (valore istantaneo)
    attr_reader :planes

    # Legge le statistiche di un contesto.
    #
    # @api private
    # @param context [Context]
    # @param reset [Boolean] true = +notcurses_stats_reset+ (copia, poi azzera
    #   i contatori cumulativi), false = +notcurses_stats+
    # @return [Stats]
    # @raise [ContextError] se +notcurses_stats_alloc+ restituisce NULL
    # @raise [ClosedError] se il contesto è chiuso
    def self.collect(context, reset:)
      ptr = context.to_ptr
      st = FFI.notcurses_stats_alloc(ptr)
      raise ContextError, 'notcurses_stats_alloc ha restituito NULL' if st.null?

      begin
        reset ? FFI.notcurses_stats_reset(ptr, st) : FFI.notcurses_stats(ptr, st)
        new(st)
      ensure
        Util.free(st.to_ptr)
      end
    end

    # Copia i campi di una struct ncstats.
    #
    # @param st [FFI::NcStats]
    # @raise [TypeError] se st non è un FFI::NcStats
    def initialize(st)
      raise TypeError, "st deve essere Notcurses::FFI::NcStats, non #{st.class}" unless st.is_a?(FFI::NcStats)

      @renders = st[:renders]
      @writeouts = st[:writeouts]
      @failed_renders = st[:failed_renders]
      @failed_writeouts = st[:failed_writeouts]
      @raster_bytes = st[:raster_bytes]
      @raster_max_bytes = st[:raster_max_bytes]
      @raster_min_bytes = minimum(st[:raster_min_bytes])
      @render_ns = st[:render_ns]
      @render_max_ns = st[:render_max_ns]
      @render_min_ns = minimum(st[:render_min_ns])
      @raster_ns = st[:raster_ns]
      @raster_max_ns = st[:raster_max_ns]
      @raster_min_ns = minimum(st[:raster_min_ns])
      @writeout_ns = st[:writeout_ns]
      @writeout_max_ns = st[:writeout_max_ns]
      @writeout_min_ns = minimum(st[:writeout_min_ns])
      @cellelisions = st[:cellelisions]
      @cellemissions = st[:cellemissions]
      @fgelisions = st[:fgelisions]
      @fgemissions = st[:fgemissions]
      @bgelisions = st[:bgelisions]
      @bgemissions = st[:bgemissions]
      @defaultelisions = st[:defaultelisions]
      @defaultemissions = st[:defaultemissions]
      @refreshes = st[:refreshes]
      @sprixelemissions = st[:sprixelemissions]
      @sprixelelisions = st[:sprixelelisions]
      @sprixelbytes = st[:sprixelbytes]
      @appsync_updates = st[:appsync_updates]
      @input_errors = st[:input_errors]
      @input_events = st[:input_events]
      @hpa_gratuitous = st[:hpa_gratuitous]
      @cell_geo_changes = st[:cell_geo_changes]
      @pixel_geo_changes = st[:pixel_geo_changes]
      @fbbytes = st[:fbbytes]
      @planes = st[:planes]
      freeze
    end

    # @return [Hash{Symbol => Integer, nil}] i campi, nell'ordine di {FIELDS}
    def to_h
      {
        renders: @renders, writeouts: @writeouts, failed_renders: @failed_renders,
        failed_writeouts: @failed_writeouts, raster_bytes: @raster_bytes, raster_max_bytes: @raster_max_bytes,
        raster_min_bytes: @raster_min_bytes, render_ns: @render_ns, render_max_ns: @render_max_ns,
        render_min_ns: @render_min_ns, raster_ns: @raster_ns, raster_max_ns: @raster_max_ns,
        raster_min_ns: @raster_min_ns, writeout_ns: @writeout_ns, writeout_max_ns: @writeout_max_ns,
        writeout_min_ns: @writeout_min_ns, cellelisions: @cellelisions, cellemissions: @cellemissions,
        fgelisions: @fgelisions, fgemissions: @fgemissions, bgelisions: @bgelisions, bgemissions: @bgemissions,
        defaultelisions: @defaultelisions, defaultemissions: @defaultemissions, refreshes: @refreshes,
        sprixelemissions: @sprixelemissions, sprixelelisions: @sprixelelisions, sprixelbytes: @sprixelbytes,
        appsync_updates: @appsync_updates, input_errors: @input_errors, input_events: @input_events,
        hpa_gratuitous: @hpa_gratuitous, cell_geo_changes: @cell_geo_changes,
        pixel_geo_changes: @pixel_geo_changes, fbbytes: @fbbytes, planes: @planes
      }
    end

    # @param other [Object] oggetto da confrontare
    # @return [Boolean]
    def ==(other) = other.is_a?(Stats) && other.to_h == to_h
    alias eql? ==

    # @return [Integer]
    def hash = [Stats, to_h].hash

    # @return [String]
    def inspect = "#<Notcurses::Stats renders=#{@renders} writeouts=#{@writeouts} planes=#{@planes}>"

    private

    def minimum(value) = value == MIN_SENTINEL ? nil : value
  end

  class << self
    # Nome dell'utente (+notcurses_accountname+): +LOGNAME+ o il nome nel
    # database degli utenti. Il nome originale, byte per byte, resta in
    # +ENV['LOGNAME']+.
    # @return [String, nil] i byte che non sono UTF-8 valido diventano U+FFFD
    def accountname = Util.take_string(FFI.notcurses_accountname)

    # Nome dell'host (+notcurses_hostname+).
    # @return [String, nil] i byte che non sono UTF-8 valido diventano U+FFFD
    def hostname = Util.take_string(FFI.notcurses_hostname)

    # Descrizione del sistema operativo (+notcurses_osversion+).
    # @return [String, nil] i byte che non sono UTF-8 valido diventano U+FFFD
    def osversion = Util.take_string(FFI.notcurses_osversion)
  end
end
