# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

# Copertura della Fase 1: ogni funzione FFI (383 attach_function e 248
# reimplementazioni inline) è chiamata dal wrapper idiomatico oppure è esclusa
# qui, con il motivo.
RSpec.describe 'Copertura delle funzioni FFI' do
  root = File.expand_path('..', __dir__)
  ffi_dir = File.join(root, 'lib/notcurses/ffi')
  attached = File.read(File.join(ffi_dir, 'functions.rb')).scan(/^\s*attach_function :(\w+)/).flatten
  inline = File.read(File.join(ffi_dir, 'inline_reimpl.rb')).scan(/^\s*def self\.(\w+)/).flatten
  sources = Dir[File.join(root, 'lib/notcurses/**/*.rb')].reject { |f| f.start_with?(ffi_dir) }
  used = sources.flat_map { |f| File.read(f).scan(/\bFFI\.(\w+)/).flatten }.uniq

  reasons = {
    const: 'variante const, identica a quella senza const',
    libc: 'funzione libc di supporto delle reimplementazioni inline della Fase 1',
    text: 'raggruppata in Plane#putstr/#putegc/#putc/#printf (wchar_t, varargs e va_list non servono da Ruby)',
    wchar: 'conversione wchar_t: in Ruby si usa String#encode',
    box: 'raggruppata in Plane#box/#perimeter (set: :rounded, :double, :ascii, ...)',
    cell_value: 'Cell è un valore Ruby: EGC, stili e larghezza in Ruby, colori con Channels (ncchannels_*); nessuna nccell C conservata',
    cell_macro: 'macro con bug sui caratteri non ASCII (EGC non valido o finta cella larga): Cell.new passa da nccell_load',
    cell_alloc: 'alloca con strdup: Cell legge l\'EGC con nccell_extended_gcluster',
    cell_dup: 'svuota la cella se sorgente e destinazione coincidono e non copia tra piani: una Cell si copia come valore',
    cell_load: 'Cell.new accetta una String o un codepoint e si carica con nccell_prime',
    load_box: 'Plane#box carica le 6 celle una per una, controllando che notcurses legga ogni glifo come un solo EGC',
    render_buffer: 'bug di 3.0.17: render_to_file fa un double free, il buffer di render_to_buffer è memoria interna',
    ruby_resize: 'bug di 3.0.17 (sposta il piano fuori dal genitore): reimplementata in Ruby, Plane#resize_marginalized/#resize_placewithin',
    context: 'Plane#context restituisce il Context Ruby',
    at_cursor: 'Plane#at senza coordinate legge la cella del cursore',
    set_base_cell: 'Plane#set_base(egc:, styles:, channels:) usa ncplane_set_base',
    contents: 'bug di 3.0.17 (ogni chiamata lascia copie nell\'egcpool): Plane#contents è scritto in Ruby',
    userptr: 'userptr è usato da notcurses per i widget (il menu): in Ruby si associa un oggetto al Plane con le strutture Ruby',
    mergedown: 'bug di 3.0.17 (ignora la regione): Plane#merge_down usa ncplane_mergedown_simple',
    puttext: 'bug di 3.0.17 (ciclo infinito, -1 dopo una scrittura completa, allineamento): Plane#puttext è scritto in Ruby',
    fade: 'renderizza la pila standard, dorme tenendo il GVL, con un callback lento non arriva in fondo: Plane#fadeout/#fadein usano FadeContext',
    pulse: 'bug di 3.0.17 (resta nero dopo il primo ciclo, senza callback non ritorna): Plane#pulse è scritto in Ruby',
    aligned: 'Plane#putstr(align:) calcola la colonna con ncplane_halign e scrive con ncplane_putstr_yx',
    get_blocking: 'attende tenendo il GVL e senza timeout: Context#get/Direct#get attendono in Ruby su inputready_fd',
    get: 'Context#get usa notcurses_get_nblock dopo l\'attesa in Ruby',
    direct_printf: 'scrive su stdout e aggiunge "\n", varargs: Direct#print_aligned',
    direct_stream: 'ignora il ritorno del callback, SIGSEGV con vopts NULL, GVL per tutto il video: Direct#stream è scritto in Ruby',
    direct_get: 'chiamata attraverso l\'inline ncdirect_get_nblock',
    simple_streamer: 'va in crash con vopts->n NULL; è già lo streamer predefinito di Visual#stream senza blocco',
    blit_rgb_packed: 'bug di 3.0.17 (passo di 1 byte invece di 3): Visual.blit_rgb_packed usa ncvisual_from_rgb_packed e ncvisual_blit',
    byte_order: 'macro di byte order: in Ruby i pixel si leggono e scrivono con pack/unpack',
    printf_format: 'macro di larghezza per i formati printf: Notcurses.metric e i *_prefix restituiscono String (si allineano con String#rjust)',
    delitem: 'bug di 3.0.17 (selector.c:436-441: selezione fuori limite, startdisp mai aggiornato, segfault nel ridisegno, double free nel destroy): Selector non cancella voci',
    fdplane: 'bug di 3.0.17 (destroy durante o dentro il callback blocca l\'interprete, fd.c:136-148; busy loop con follow a fine file, fd.c:50-70; il ritorno del callback non ferma il thread): FdPlane è scritto in Ruby',
    subproc: 'bug di 3.0.17 (destroy in deadlock con il figlio vivo, fd.c:432-436; 3 fd lasciati aperti, fd.c:231-234 e 438; stdin ereditato, fd.c:196; exec fallito non segnalato, fd.c:207; SIGKILL a un PID riciclato, fd.c:411): Subprocess è scritto in Ruby',
    reel: 'bug di 3.0.17 (heap corrotto in trim_reel_overhang, reel.c:494-544; infinite_scroll e circular validati e poi ignorati, reel.c:774-781): Reel e Tablet sono scritti in Ruby',
    tree_goto: 'stub in 3.0.17 (tree.c:609-616): Tree#goto è scritto in Ruby con nctree_next/nctree_prev',
    tab_cb: 'restituisce il puntatore C del trampolino: Tab#callback restituisce il Proc Ruby',
    tab_userptr: 'il curry passato al C è sempre NULL: i dati dell\'utente stanno nel Tab e nella closure del blocco',
    tabbed_channels: 'chiamata attraverso le inline nctabbed_hdrchan, nctabbed_selchan e nctabbed_sepchan'
  }.freeze

  excluded = {
    'notcurses_stdplane_const' => :const, 'ncplane_notcurses_const' => :const, 'ncplane_parent_const' => :const,
    'notcurses_stddim_yx_const' => :const,
    'strdup' => :libc, 'snprintf' => :libc, 'wcswidth' => :libc, 'wcslen' => :libc, 'wcsrtombs' => :libc,
    'wcrtomb' => :libc,
    'ncpile_render_to_buffer' => :render_buffer, 'ncpile_render_to_file' => :render_buffer,
    'ncplane_resize_marginalized' => :ruby_resize, 'ncplane_resize_placewithin' => :ruby_resize,
    'ncplane_notcurses' => :context, 'ncplane_at_cursor' => :at_cursor, 'ncplane_at_cursor_cell' => :at_cursor,
    'ncplane_set_base_cell' => :set_base_cell, 'ncplane_contents' => :contents, 'ncreader_contents' => :contents,
    'ncplane_set_userptr' => :userptr, 'ncplane_userptr' => :userptr, 'ncplane_mergedown' => :mergedown,
    'ncplane_puttext' => :puttext, 'ncplane_fadeout' => :fade, 'ncplane_fadein' => :fade, 'ncplane_pulse' => :pulse,
    'ncplane_putstr_aligned' => :aligned, 'ncplane_putnstr_aligned' => :aligned,
    'ncplane_putc' => :text, 'ncplane_putchar_yx' => :text, 'ncplane_putchar' => :text, 'ncplane_putegc' => :text,
    'ncplane_putchar_stained' => :text, 'ncplane_putnstr_yx' => :text, 'ncplane_putnstr' => :text,
    'ncplane_putwegc' => :text, 'ncplane_putwegc_yx' => :text, 'ncplane_putwegc_stained' => :text,
    'ncplane_putwstr_yx' => :text, 'ncplane_putwstr_aligned' => :text, 'ncplane_putwstr' => :text,
    'ncplane_putwstr_stained' => :text, 'ncplane_pututf32_yx' => :text, 'ncplane_putwc_yx' => :text,
    'ncplane_putwc' => :text, 'ncplane_putwc_utf32' => :text, 'ncplane_putwc_stained' => :text,
    'ncplane_vprintf' => :text, 'ncplane_vprintf_yx' => :text, 'ncplane_vprintf_aligned' => :text,
    'ncplane_vprintf_stained' => :text, 'ncplane_printf' => :text, 'ncplane_printf_yx' => :text,
    'ncplane_printf_aligned' => :text, 'ncplane_printf_stained' => :text,
    'ncwcsrtombs' => :wchar,
    'ncplane_box_sized' => :box, 'ncplane_perimeter' => :box, 'ncplane_rounded_box' => :box,
    'ncplane_perimeter_rounded' => :box, 'ncplane_rounded_box_sized' => :box, 'ncplane_double_box' => :box,
    'ncplane_ascii_box' => :box, 'ncplane_perimeter_double' => :box, 'ncplane_double_box_sized' => :box,
    'nccells_load_box' => :load_box,
    'NCCELL_INITIALIZER' => :cell_macro, 'NCCELL_CHAR_INITIALIZER' => :cell_macro,
    'NCCELL_TRIVIAL_INITIALIZER' => :cell_macro,
    'nccell_duplicate' => :cell_dup, 'nccell_strdup' => :cell_alloc, 'nccell_extract' => :cell_alloc,
    'nccell_load_char' => :cell_load, 'nccell_load_egc32' => :cell_load, 'nccell_load_ucs32' => :cell_load,
    'notcurses_get' => :get, 'notcurses_get_blocking' => :get_blocking, 'ncdirect_get_blocking' => :get_blocking,
    'ncdirect_printf_aligned' => :direct_printf, 'ncdirect_stream' => :direct_stream, 'ncdirect_get' => :direct_get,
    'ncvisual_simple_streamer' => :simple_streamer, 'ncblit_rgb_packed' => :blit_rgb_packed,
    'htole' => :byte_order,
    'NCMETRICFWIDTH' => :printf_format, 'NCPREFIXFMT' => :printf_format, 'NCIPREFIXFMT' => :printf_format,
    'NCBPREFIXFMT' => :printf_format,
    'ncselector_delitem' => :delitem,
    'ncfdplane_create' => :fdplane, 'ncfdplane_plane' => :fdplane, 'ncfdplane_destroy' => :fdplane,
    'ncsubproc_createv' => :subproc, 'ncsubproc_createvp' => :subproc, 'ncsubproc_createvpe' => :subproc,
    'ncsubproc_plane' => :subproc, 'ncsubproc_destroy' => :subproc,
    'nctree_goto' => :tree_goto, 'nctab_cb' => :tab_cb, 'nctab_userptr' => :tab_userptr,
    'nctab_set_userptr' => :tab_userptr, 'nctabbed_channels' => :tabbed_channels
  }
  %w[ncreel_create ncreel_plane ncreel_add ncreel_tabletcount ncreel_del ncreel_redraw ncreel_offer_input
     ncreel_focused ncreel_next ncreel_prev ncreel_destroy nctablet_plane nctablet_userptr].each do |name|
    excluded[name] = :reel
  end
  %w[nccell_init nccell_set_styles nccell_styles nccell_on_styles nccell_off_styles nccell_double_wide_p
     nccell_cols nccellcmp nccell_set_fg_default nccell_set_bg_default nccell_set_fg_alpha
     nccell_set_bg_alpha nccell_set_bchannel nccell_set_fchannel nccell_set_channels nccell_channels nccell_bchannel
     nccell_fchannel nccell_fg_rgb nccell_bg_rgb nccell_fg_alpha nccell_bg_alpha nccell_fg_rgb8 nccell_bg_rgb8
     nccell_set_fg_rgb8 nccell_set_fg_rgb8_clipped nccell_set_fg_rgb nccell_set_fg_palindex nccell_fg_palindex
     nccell_set_bg_rgb8 nccell_set_bg_rgb8_clipped nccell_set_bg_rgb nccell_set_bg_palindex nccell_bg_palindex
     nccell_fg_default_p nccell_fg_palindex_p nccell_bg_default_p nccell_bg_palindex_p].each do |name|
    excluded[name] = :cell_value
  end
  excluded.freeze

  it 'ogni funzione FFI è chiamata dal wrapper o esclusa con un motivo' do
    missing = (attached + inline) - used - excluded.keys
    expect(missing).to be_empty, "funzioni né usate né escluse: #{missing.join(', ')}"
  end

  it 'le esclusioni riguardano solo funzioni esistenti e non usate, ognuna con un motivo' do
    expect(excluded.keys - (attached + inline)).to be_empty
    expect(excluded.keys & used).to be_empty
    expect(excluded.values - reasons.keys).to be_empty
  end

  it 'conta 633 funzioni, senza nomi doppi' do
    expect(attached.size).to eq(385)
    expect(inline.size).to eq(248)
    expect((attached + inline).uniq.size).to eq(633)
  end
end
