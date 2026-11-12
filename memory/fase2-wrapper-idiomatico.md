# Fase 2 — wrapper Ruby idiomatico: log di lavoro

- Data: 2026-10-25
- Base: layer FFI raw della Fase 1 (`lib/notcurses/ffi.rb`, `lib/notcurses/ffi/`), non modificato durante la Fase 2.
  Il 2026-10-26, su richiesta, `functions.rb` ha ricevuto `blocking: true` su 8 funzioni (vedi "Thread e GVL").
- Ambiente di prova: Arch Linux, pacchetto `notcurses 3.0.17-3` (con ffmpeg), Ruby 4.0.7 (mise), gem `ffi` 1.17.4,
  `rspec` 3.13.2. Nessuna dipendenza nuova: solo `ffi`, codice compatibile con Ruby >= 3.1.
- File in più rispetto alla struttura del prompt:
  - `lib/notcurses/resource.rb`: modulo `Resource` (`closed?`, `to_ptr`, `inspect`) e `Resource::ClassMethods#open`;
  - `lib/notcurses/util.rb`: validazione degli argomenti, conversioni, trampolino dei callback;
  - `lib/notcurses/format.rb`: `Notcurses.metric`, i prefissi SI/IEC, `Notcurses.strwidth`, le conversioni UCS-32;
  - `lib/notcurses/widgets/widget.rb`: modulo `Widget`, comune a widget, `FdPlane` e `Subprocess`;
  - `spec/coverage_spec.rb`: controllo della copertura delle 631 funzioni FFI;
  - `spec/support/nc_helpers.rb`: contesto di test su `/dev/null`;
  - `spec/fixtures/visual/`: `rgbw.png` e `frames.mkv` per i test dei visual.

## Metodo

1. **Ricerca della semantica C, per area.** Otto fogli di lavoro (contesto, piani, output dei piani, celle, visual,
   direct, widget A, widget B) con ritorni, ownership, callback, thread e bug di ogni funzione. Ogni fatto critico è
   stato provato con un esperimento; i casi che vanno in crash girano in processi separati.
2. **Documento di design comune.** Regole vincolanti, helper di `Util`, convenzioni dell'API, ciclo di vita,
   callback, protezioni dai bug, test e copertura.
3. **Implementazione per area.** Contesto, piani, output, celle e helper nel thread principale; Visual, Direct e i
   widget da implementatori in parallelo, ognuno con i propri file e il divieto di toccare i file condivisi. Le
   modifiche ai file condivisi richieste dagli implementatori sono state integrate alla fine.
4. **Integrazione.** Spec di copertura, spec di integrazione, controllo dei tag YARD con uno script, suite completa.

## Decisioni di design

### Ciclo di vita e ownership

- **`Notcurses::Resource`** è il modulo comune: `@ptr`, `@closed`, `@owner`. `closed?` vale true anche quando il
  proprietario è chiuso (un piano dopo `Context#close`). `to_ptr` solleva `ClosedError` e ogni chiamata FFI passa da
  `to_ptr`. `Classe.open(...) { |obj| ... }` chiude l'oggetto in `ensure` e restituisce il valore del blocco; senza
  blocco restituisce l'oggetto. Ogni `close` è idempotente e chiama il distruttore C una sola volta; dove il C parla
  di destroy c'è `alias destroy close`.
- **Il GC non distrugge mai un oggetto legato al contesto** (piani, widget, visual). Un finalizer che chiama
  `ncplane_destroy` farebbe un double free dopo `notcurses_stop`, dopo `notcurses_drop_planes` o dopo il distruttore
  di un widget, che liberano i piani da soli. La vita di questi oggetti la governa il registro del `Context`:
  - i piani creati dal wrapper sono "tracciati" e restano nel registro finché esiste il piano C. Così i
    `::FFI::Function` che il piano tiene (callback di resize) vivono quanto il piano C;
  - le funzioni C che restituiscono un piano esistente (navigazione, piano di un widget, argomento di un callback)
    passano da `Context#plane_for`: restituisce il `Plane` tracciato con quell'indirizzo, oppure un piano "preso in
    prestito" (`owned: false`), valido fino alla prossima distruzione di piani (contatore `generation`). Su un piano
    preso in prestito `close` non fa nulla;
  - widget, visual, `FdPlane` e `Subprocess` si registrano con `Context#adopt`. `Context#close` e
    `Context#drop_planes` li chiudono in ordine inverso di creazione **prima** di `notcurses_stop` e del drop: con un
    `ncreader` vivo lo stop fa un double free;
  - un piano passato a un widget che lo distrugge con sé passa al widget (`transfer_to`): `Plane#close` non fa più
    nulla, e `family_destroy` di un antenato solleva `PlaneError` finché il widget è aperto.
- Il pattern `owned:` del prompt è mantenuto: lo stdplane e i piani presi in prestito hanno `owned: false`.
- **Le risorse fatte solo di memoria** usano `::FFI::AutoPointer`: `Palette` (`ncpalette_free`) e `FadeContext`
  (`ncfadectx_free`). Il releaser è una costante che non cattura l'oggetto Ruby; si liberano con `close` o dal GC.
- **`Stats`** è un valore: `notcurses_stats_alloc`, copia dei campi, `free` in `ensure`.
- **Un solo contesto per processo** (Context o Direct): il C registra un solo contesto per i segnali
  (`setup_signals`, CAS su un atomico, `unixsig.c:199-203`), anche con i flag che disattivano i gestori.
  `Notcurses.acquire_context`/`release_context` tengono il registro con un Mutex; un secondo contesto solleva
  `InitError` prima della chiamata C, qualunque sia il tipo del primo.
- **`at_exit`** chiude il contesto rimasto aperto, solo nel processo che l'ha creato (un figlio di `fork` eredita gli
  hook ma non il thread di input). Uscire senza `notcurses_stop` lascia il terminale in modalità raw e, con il thread
  di input vivo, ha prodotto un SIGSEGV durante la chiusura della VM.

### Callback

- Ogni callback è un `::FFI::Function` con la firma C dei commenti `# callback:` della Fase 1. Il blocco passa da
  `Util.guard(ctx.callback_errors, valore_sicuro) { ctx.callback_scope { ... } }`.
- **Un'eccezione Ruby non attraversa mai i frame C** (salterebbe il rilascio di `pilelock` in `notcurses_refresh`):
  `Util.guard` la salva, al C torna un valore che interrompe l'operazione, e `ctx.raise_callback_errors!` la rilancia
  dopo la chiamata C esterna. Anche l'output su un piano può chiamare callback: l'autogrow ridimensiona i figli, e
  ogni scroll dello stdplane esegue un render.
- **Dentro un callback chiamato dal C non si distruggono né si riparentano piani**: il C sta percorrendo le sue liste
  e leggerebbe memoria liberata. `Plane#close`, `#family_destroy`, `#reparent*`, `Context#close`, `#drop_planes` e il
  `close` dei widget sollevano un'eccezione (`check_not_in_callback!`).
- Il riferimento al `::FFI::Function` vive quanto il C lo può chiamare: una variabile locale per i callback sincroni,
  il piano tracciato o il widget adottato per quelli chiamati più tardi.

### Valori e convenzioni dell'API

- **Valori immutabili** (frozen, con `==`, `eql?`, `hash`): `Channel`, `Channels`, `Cell`, `Input`, `Pixel`, `Stats`,
  `Capabilities`, `Visual::Geometry`, `Menu::Item`. `Channel` e `Channels` contengono un solo Integer: i metodi
  `with_*` restituiscono un valore nuovo, perché le inline della Fase 1 lavorano su un puntatore e il valore Ruby
  deve restare costante.
- **`Cell` è un valore Ruby** (EGC, stili, canali, larghezza) e non un wrapper di `nccell`. Una `nccell` vive
  nell'egcpool del piano (gli EGC di più di 4 byte): diventa pendente dopo `erase`, un resize, `rotate` o la
  distruzione del piano, e una cella di un piano usata su un altro corrompe il pool. Per ogni chiamata C il wrapper
  carica la `Cell` in una `FFI::NcCell` temporanea con `nccell_prime` sul piano di destinazione e la rilascia in
  `ensure`. `Cell.new` controlla l'EGC con le regole di Ruby (un solo grapheme cluster, niente caratteri di
  controllo); `load_into` solleva `CellError` se notcurses legge l'EGC in modo diverso.
- **Coordinate e dimensioni**: prima `y`, poi `x`; `rows`/`cols`; `nil` = posizione del cursore (al posto del -1 del C).
- **Colori**: `set_fg_rgb(r, g, b)`, `set_fg_rgb24(0xRRGGBB)`, `set_fg_rgb_clipped(r, g, b)`, `set_fg_palindex(i)`,
  `set_fg_alpha(:blend)`, `set_fg_default` (tutti restituiscono `self`); getter `fg_rgb` → `[r, g, b]`, `fg_rgb24` →
  Integer, `fg_alpha` → Symbol, `fg_default?`. Lo stesso per lo sfondo (`bg_*`), per `Channel`/`Channels` e per
  `Direct`.
- **Stili ed enum come Symbol** (`:bold`, `[:bold, :italic]`, `:center`, `:braille`, ...); i metodi accettano anche la
  costante C. Le opzioni sono keyword con default; gli argomenti posizionali sono solo quelli obbligatori.
- **I canali passati al C sono mascherati** (`Util::CHANNELS_MASK` = `0x78ffffff78ffffff`): i bit di servizio come
  `NC_NOBACKGROUND_MASK` (`0x87000000` in ogni canale) spengono lo sfondo nel rasterizzatore, e alcuni setter C li
  copiano dove non devono.
- **Stringhe**: in ingresso String UTF-8 valida e senza NUL (`TypeError`/`ArgumentError`), in uscita sempre UTF-8;
  NULL diventa `nil`. La memoria allocata dal C (`# ALLOC`) si legge e si libera subito con `Util.take_string`.
- **Errori**: `ArgumentError` e `TypeError` per gli argomenti, controllati prima della chiamata C. Per i fallimenti
  del C e per lo stato, la classe dell'area: `InitError`, `ClosedError`, `RenderError`, `PlaneError`, `CellError`,
  `VisualError`, `InputError`, `WidgetError`, `DirectError`, `ContextError`, tutte sotto `Notcurses::Error`. Ogni
  metodo interpreta il proprio ritorno: molte funzioni non seguono "-1 o NULL = errore" (byte scritti, OR dei
  callback, 1 = fine dello stream, valore precedente di un flag).
- **Niente metaprogrammazione**: nessun `define_method`, `method_missing`, `send` dinamico; ogni metodo è scritto per
  esteso e si trova con grep.

### Thread e GVL

- **Nessun lock interno** (regola 3 del prompt): notcurses non è thread-safe, e la documentazione di `Context`,
  `Plane` e `Direct` dice che un contesto e i suoi oggetti si usano da un solo thread alla volta. Il foglio di ricerca
  proponeva un Mutex per il render e uno per l'input: scartato per la regola 3.
- **Le `attach_function` della Fase 1 tengono il GVL**: durante `notcurses_get` con 1 s di attesa un altro thread
  Ruby non ha fatto nessun passo. Per questo le attese lunghe sono in Ruby: `Context#get`/`Direct#get` aspettano con
  `IO#wait_readable` sul fd di `inputready_fd` e poi leggono con `get_nblock`; le dissolvenze e gli stream dormono
  con `sleep` tra un passo e l'altro.
- **Eccezione, dal 2026-10-26: `blocking: true`** su 8 funzioni che il wrapper chiama e che aspettano il terminale o
  il tempo dentro il C: `notcurses_init`, `notcurses_core_init`, `ncdirect_init`, `ncdirect_core_init` (attendono la
  risposta a DA1 senza timeout, `termdesc.c:1217`, `in.c:2921-2926`), `ncdirect_cursor_yx`,
  `ncdirect_cursor_move_yx` (con una coordinata -1 chiede la posizione al terminale), `ncdirect_readline` e
  `ncvisual_stream` (decodifica, disegno e attese tra i frame). Prima, con il GVL tenuto, un terminale finto in un
  thread Ruby dello stesso processo (per esempio un pty nei test) non poteva rispondere: stallo già all'init.
  - ruby-ffi 1.17.4 gestisce i callback durante una chiamata senza GVL: `callback_invoke` riprende il GVL con
    `rb_thread_call_with_gvl` e cattura le eccezioni con `rb_rescue2`, poi le rilancia dopo il ritorno
    (`Function.c:616-622`, `805`, `Call.c:371-415`). Il trampolino di `Visual#stream` funziona quindi come prima.
  - Conseguenza: durante quelle attese gli altri thread Ruby girano e possono chiamare notcurses insieme al C. Il
    YARD lo dice (non usare lo stesso contesto, né ENV durante l'init: con `termtype:` notcurses chiama `setenv`).
  - Le altre funzioni tengono il GVL apposta: le scritture e i render sono brevi, e rilasciare il GVL su di loro
    renderebbe molto più probabili le sovrapposizioni tra thread.
  - `notcurses_get` e `ncdirect_get` restano senza `blocking: true`: il wrapper li chiama solo attraverso le inline
    `*_get_nblock`, dopo l'attesa in Ruby.
- I callback di resize, dei widget e degli stream sono chiamati in modo sincrono dal thread Ruby che ha fatto la
  chiamata C: nessun thread di notcurses chiama codice Ruby.

### Segnali

- `Context.new` passa `NCOPTION_NO_QUIT_SIGHANDLERS` per default (keyword `no_quit_sighandlers: true`): con i gestori
  di notcurses Ctrl-C termina Ruby subito (`fatal_handler` con `SA_RESETHAND`, `unixsig.c:252-262`), senza `ensure`
  né `at_exit`.
- `Context.new` passa `NCOPTION_NO_WINCH_SIGHANDLER` per default: il gestore di notcurses blocca SIGWINCH e SIGCONT
  nel thread dell'init per sempre (`unixsig.c:220`), e `NCKEY_RESIZE` arriva solo con l'input successivo. Per reagire
  subito al resize: `trap('WINCH')` e `Context#refresh`.

### Reimplementazioni in Ruby

Dove la funzione C di 3.0.17 è rotta e un'alternativa corta e sicura esiste, il wrapper la scrive in Ruby sopra
funzioni C che funzionano:

- `Plane#resize_marginalized`, `#resize_placewithin`, i margini di `create_child(margins:)`;
- `Plane#contents` (lettura cella per cella con `ncplane_at_yx_cell`);
- `Plane#puttext` (a capo sulle parole, sopra `putstr`);
- `Plane#putstr(align:)` (colonna da `ncplane_halign`, scrittura con `ncplane_putstr_yx`);
- `Plane#fadeout`, `#fadein`, `#pulse` (sopra `FadeContext`, cioè `ncfadectx` con un fader no-op);
- `Direct#stream` (frame per frame con `ncvisual_decode` e `ncdirect_raster_frame`);
- `Reel` e `Tablet` (al posto di `ncreel`), `FdPlane` (al posto di `ncfdplane`), `Subprocess` (al posto di
  `ncsubproc`): vedi la sezione dei widget B.

## Bug di notcurses 3.0.17 aggirati

Regola: un bug che corrompe la memoria o va in crash si previene **prima** della chiamata C, con un'eccezione chiara.
Un bug di semantica si aggira in Ruby se il workaround è corto e sicuro; altrimenti si documenta nel YARD ("Bug di
3.0.17 ...") e qui. Una funzione che non funziona affatto non si espone e va nell'elenco `excluded` della spec di
copertura.

### Contesto e input

| Bug | Workaround |
| --- | --- |
| Un secondo contesto (notcurses o direct) fallisce, anche con i gestori di segnale disattivati (`unixsig.c:199-203`) | `acquire_context`: `InitError` prima del C |
| `termtype:` scrive `ENV['TERM']` anche se l'init fallisce; l'init successivo fallisce (`termdesc.c:1661-1681`) | il wrapper ripristina `TERM` dopo un init fallito |
| `notcurses_stop`/`drop_planes` con un `ncreader` vivo: double free (`reader.c:12`; stesso schema in `plot.c:608`) | widget adottati chiusi prima, in ordine inverso |
| `drop_planes` lascia una pila non standard di 2 o più piani con puntatori pendenti (`notcurses.c:467-480`, `1413-1435`) | il wrapper distrugge prima, piano per piano, le pile con piani conosciuti |
| `ncpile_rasterize` su una pila mai renderizzata: SIGSEGV | solo `render_pile(rasterize: true)`, che fa render e rasterize |
| `notcurses_stop` restituisce l'OR di più ritorni | errore solo se diverso da 0 |
| `cursor_disable` e `mice_disable` non sono idempotenti (-1 se già spenti) | stato in Ruby; dopo un `Reader` lo stato è "sconosciuto" e il -1 è tollerato |
| `notcurses_get`/`get_blocking`: GVL tenuto, nessun timeout | attesa in Ruby su `inputready_fd`, poi `get_nblock` |
| Alt segnalato solo nel campo deprecato `alt` (prefisso ESC) | `Input#modifiers` aggiunge `NCKEY_MOD_ALT` |
| `ncpalette_set*` accetta l'indice 256 (heap overflow) | indice controllato in 0..255 |
| `ncpile_render_to_buffer`/`render_to_file`: nessun output, double free nel secondo | non esposte |

### Piani

| Bug | Workaround |
| --- | --- |
| `ncplane_resize_marginalized`/`placewithin` spostano il piano fuori dal genitore | scritte in Ruby |
| `NCPLANE_OPTION_MARGINALIZED` ignora i margini alto e sinistro | `create_child(margins:)` calcola posizione e dimensioni in Ruby |
| `ncplane_dup` posiziona la copia con le coordinate assolute come relative, la mette in cima e azzera scrolling e autogrow | `Plane#duplicate` sposta la copia e ripristina i flag; non copia il callback di resize interno di un widget (crash al primo resize) |
| `ncplane_resize`: offset positivi, regione che non entra (con `x_off < 0` scrive oltre il buffer), resize ignorato, `y_off` con larghezza intera | casi rifiutati con `ArgumentError` |
| `ncplane_cursor_move_yx` cambia x anche quando poi rifiuta y | posizione controllata prima |
| `ncplane_scrollup` tratta ogni riga come un "a capo" dal cursore | il cursore va prima sull'ultima riga |
| `ncplane_at_yx` con la metà destra di un glifo largo isolata in colonna 0 può non tornare più | il wrapper cerca la metà sinistra; altrimenti restituisce la cella base |
| Un resize che taglia un glifo largo lascia la metà sinistra (larga 2) nell'ultima colonna, o la metà destra in colonna 0 con `keep_x > 0` (`notcurses.c:991`), oppure nell'ultima colonna senza la metà sinistra con `x_off < 0`; la scrittura successiva su quella cella cancella una cella della riga vicina, o scrive fuori dal framebuffer (`notcurses.c:1917-1927`). Succede anche nei resize del C: lo stdplane quando il terminale si restringe (`render.c:108`), i figli con `:maximize` (ICH-271) | le tre `resize*` svuotano le metà orfane sui bordi; prima di ogni scrittura il wrapper fa lo stesso se le colonne del piano sono cambiate dall'ultima volta o se un `merge_down` lo ha toccato; su uno stdplane che scorre, prima di una scrittura che va a capo, `ncpile_render` lo porta alle dimensioni del terminale (il render dentro `ncplane_put` lo restringerebbe a metà chiamata) |
| `ncplane_contents` lascia nell'egcpool una copia di ogni EGC lungo, a ogni chiamata (fino a 16 MiB) | `Plane#contents` legge le celle una per una e le rilascia |
| `ncplane_mergedown` ignora la regione | solo `merge_down` completo (`ncplane_mergedown_simple`) |
| `ncplane_puttext`: ciclo infinito, -1 dopo una scrittura completa, allineamento sbagliato | `Plane#puttext` in Ruby |
| `ncplane_putstr_aligned` e scritture con `x:` su un piano che scorre: il primo carattere va fuori dalla riga | controllo prima della chiamata |
| TAB nell'ultima colonna: il ciclo di espansione scrive la cella `x == lenx`, cioè la riga successiva o oltre il framebuffer (`notcurses.c:1936-1957`) | TAB rifiutati in `putstr`/`putegc`/`Cell`; il `Reader` scrive uno spazio |
| EGC che notcurses segmenta come larghezza zero (U+200B, segno combinante isolato, keycap U+20E3, jamo hangul): con il cursore a `x == dim_x` scrive fuori dalla riga (`notcurses.c:1873-1893`) | rifiutati prima della scrittura |
| Dopo uno ZWJ (U+200D) il C unisce tutto il resto del testo in un solo EGC (`egcpool.h:126-128`) | testo spezzato dopo ogni grapheme con ZWJ (`Util.zwj_segments`); `Notcurses.strwidth` misura i segmenti, così anche `puttext` e la UI (ICH-285, ICH-286) |
| U+2028 e U+2029 troncati a un byte | rifiutati |
| `ncplane_fadeout`/`fadein`: render della pila standard, `nanosleep` con il GVL, con un callback lento non arrivano in fondo | `Plane#fadeout`/`#fadein` in Ruby sopra `FadeContext` |
| `ncplane_pulse` resta nero dopo il primo ciclo e senza callback non ritorna | `Plane#pulse` in Ruby, blocco obbligatorio |
| Bit di servizio dei canali (`0x87000000`) copiati dai setter | canali mascherati |
| Eccezione Ruby in un callback di resize: attraversa il C, `pilelock` resta acquisito | trampolino con `Util.guard` |
| Limiti dello stdplane (non si distrugge, sposta, ridimensiona con `resize`, riparenta; niente autogrow) | rifiutati prima della chiamata |

### Celle

| Bug | Workaround |
| --- | --- |
| `NCCELL_INITIALIZER` e `NCCELL_CHAR_INITIALIZER` con caratteri non ASCII: EGC non valido o finta cella larga | non esposte: `Cell.new` passa da `nccell_load` |
| `nccell_duplicate` svuota la cella se sorgente e destinazione coincidono, e non copia tra piani | una `Cell` si copia come valore |
| `nccells_load_box`: carica 6 celle senza controllare la segmentazione dei glifi | `Plane#box` carica le celle una per una con il controllo |

### Direct

| Bug | Workaround |
| --- | --- |
| `ncdirect_stop` scrive il proprio reset (`\e[39;49m\e(B\e[m`) sullo stdout del processo anche quando l'output è un file (`direct.c:841`) | documentato |
| `ncdirect_vline` con `UINT_MAX` va in SIGFPE; oltre `INT_MAX` le linee fanno fino a 2^32 iterazioni con colori sbagliati (`direct.c:1351`) | lunghezza massima `INT_MAX - 1` |
| `ncdirect_vline` torna indietro di una colonna dopo ogni carattere (`direct.c:1389`) | un solo EGC largo una colonna |
| Dopo uno ZWJ (U+200D) `ncdirect_putegc` e `ncstrwidth` uniscono tutto il resto del testo in un solo EGC (`egcpool.h:126-128`) | `putegc` passa al C solo il primo segmento di `Util.zwj_segments`; `print_aligned` misura con `Notcurses.strwidth`, che somma i segmenti (ICH-285) |
| `hline`/`vline`/`box` interpolano i bit RGB anche dei canali a palette: l'indice finisce nel blu (`direct.c:1285-1292`) | `ArgumentError` per i canali a palette |
| `ncdirect_cursor_move_yx` per conservare la colonna legge la posizione dal terminale (condizione invertita, `direct.c:233`) | con `x: nil` serve `can_get_cursor?`, altrimenti `DirectError` (il C andrebbe alla colonna 0) |
| `ncdirect_align` con un allineamento non valido restituisce `INT_MAX` e il C scrive una sequenza spazzatura (`direct.c:411-426`) | solo `:left`, `:center`, `:right` |
| `ncdirect_printf_aligned` scrive su stdout invece che sull'output e aggiunge "\n" (`direct.c:818`) | `Direct#print_aligned` in Ruby: colonna come `ncdirect_align`, poi `ncdirect_putstr` |
| Il render direct legge solo blitter e scaling (`direct.c:635-737`); blitter fuori tabella (`blit.c:1375`) | opzioni ridotte a blitter e scaling; `:four_by_one` e `:eight_by_one` (solo per i plot) rifiutati |
| `ncdirect_raster_frame` libera il piano su tutti i percorsi, anche di errore (`direct.c:631`) | il `Frame` risulta chiuso prima della chiamata: un secondo `raster` non arriva al C |
| `ncdirect_putstr` con NULL: `fputs(NULL)` (`direct.c:46`, `52`) | `nil` rifiutato |
| Dopo la fine dell'input ogni lettura restituisce EOF (`in.c:2798`) | documentato in `Direct#get` |
| `readline` e `cursor_yx` attendono la risposta del terminale senza timeout (`in.c:2820`) | `DirectError` senza `can_get_cursor?`; con un terminale vero l'attesa resta (documentata), ma dal 2026-10-26 rilascia il GVL |
| `termtype:` scrive `ENV['TERM']` anche se l'init fallisce (`termdesc.c:1672`) | `TERM` ripristinato dopo un init fallito |
| `ncdirect_stream` ignora il ritorno del callback (`direct.c:1588`), va in SIGSEGV con `vopts` NULL e tiene il GVL per tutto il video | `Direct#stream` in Ruby: `break` nel blocco ferma lo stream. Il riposizionamento del C (`direct.c:1550-1559`) sale di `rows - 1` righe, ma il raster lascia il cursore sotto il frame (`direct.c:558`): dal 2026-11-11 `stream` sale di `rows` righe, senza CUB (ICH-284) |

### Visual

| Bug | Workaround |
| --- | --- |
| Un `ncvisual` creato senza un contesto attivo va in crash alla distruzione (`details` NULL, `ffmpeg.c:735`) | serve un contesto aperto; `Context#close` e `#drop_planes` chiudono i visual adottati |
| `ncvisual_from_rgba` accetta `rowstride < cols * 4` lasciando pixel non inizializzati (`visual.c:784`); senza ffmpeg, con `rowstride > cols * 4` scrive oltre il buffer (`visual.c:768`, `801`) | `rowstride` controllato, al C passano righe compatte |
| `ncvisual_from_rgb_loose` con `rowstride` maggiore dello stride interno copia righe oltre il buffer (`visual.c:884`) | al C passano righe compatte |
| `ncblit_rgb_packed` legge i pixel con passo di 1 byte invece di 3 (`visual.c:494`) | `Visual.blit_rgb_packed` usa `ncvisual_from_rgb_packed` e `ncvisual_blit` |
| `ncvisual_stream` su un visual non creato da file, o con `vopts` NULL: crash (`ffmpeg.c:501`, `508`) | `VisualError` per un visual non da file; opzioni sempre passate |
| Stream con `child: true` (`NCVISUAL_OPTION_CHILDPLANE`): un piano nuovo a ogni frame, tutti lasciati tranne l'ultimo (`ffmpeg.c:528`) | `child:` e regioni non ammessi in `stream` |
| Blit di una regione diversa dall'immagine intera: il C ridimensiona dall'inizio dei dati ignorando `begy`/`begx`, poi legge oltre il buffer (`ffmpeg.c:586`); con `nointerpolate` o senza ffmpeg la regione è ignorata | la regione viene copiata pixel per pixel in un visual temporaneo, che viene disegnato |
| Il decoder di `ncvisual_from_sixel` scrive o legge fuori dai buffer con indici di colore >= 65535, definizioni troncate, "!" senza cifre, righe dell'ultima banda oltre `rows` (`sixel.h:131`, `167`, `180`) | sequenza controllata prima della chiamata: passa solo ciò che il decoder legge in sicurezza |
| `ncvisual_resize_noninterpolative` con 0 righe o colonne | dimensioni controllate |
| `ncvisual_simple_streamer` va in crash con `vopts->n` NULL | non esposta: è già lo streamer predefinito di `Visual#stream` |
| I blitset dei plot `NCBLIT_4x1` e `NCBLIT_8x1` hanno `egcs` NULL (`blit.c:1279`, `1282`), e `lookup_blitset` li restituisce con i quadranti (Kitty, Ghostty, rxvt, Konsole; `blit.c:1329-1345`). `ncplane_as_rgba` e `ncvisual_from_plane` passano quel NULL a `wcsrchr` (`notcurses.c:3114`, `3175`): SIGSEGV. I blit li disegnano con `tria_blit` (2 righe di pixel per cella) su un piano calcolato per 4 o 8: l'immagine resta tagliata | `Util::IMAGE_BLITTERS` (senza `:four_by_one` e `:eight_by_one`) per `Visual`, `Plane#as_rgba` e `Direct`: `ArgumentError` prima del C; `Plot` usa ancora `Util::BLITTERS` (ICH-272) |

### Widget A (Selector, MultiSelector, Menu, Reader, ProgBar)

| Bug | Workaround |
| --- | --- |
| `ncselector_delitem`: selezione fuori limite, `startdisp` mai aggiornato, segfault nel ridisegno, double free nel destroy (`selector.c:436-441`) | non esposta: `Selector` non cancella voci |
| `ncselector_destroy(&item)` su un selettore vuoto legge da NULL (`selector.c:273`) | il wrapper passa sempre NULL; la voce si legge con `selected` |
| Testi con caratteri di controllo (`ncstrwidth` = -1) rompono il layout (`selector.c:308`, `413`, `909-913`) | rifiutati |
| `ncmultiselector_selected` non scrive mai la voce 0 (`selector.c:1006`) | stato ricavato in Ruby |
| `desc` NULL nel multiselector: segfault (`selector.c:942`, `951`) | `nil` diventa `""` |
| Multiselector con 0 voci: segfault sullo spazio (`selector.c:818`) | `ArgumentError` |
| Genitore troppo piccolo: il C distrugge il piano del selettore (`selector.c:865-880`) | controllo prima, `WidgetError`, piano intatto |
| Piano del multiselector di 1 riga: `ncmultiselector_draw` confronta `yoff` unsigned con `dimy - 2` (`selector.c:696`) e gira circa 2^32 volte, con il GVL tenuto | `offer_input` legge le righe a ogni chiamata e sotto 2 solleva `WidgetError` prima del C (lotto 5, ICH-277) |
| Scorciatoia di una voce di menu da U+0800: scrittura oltre il buffer; da U+10000: abort (`menu.c:103-124`) | rifiutata |
| `ncmenu_item_set_status`: `strcmp` su NULL (divisori, separatori), logica invertita (`menu.c:788-791`) | rifiuto, e doppia chiamata solo quando lo stato cambia |
| `ncmenu_nextitem`/`previtem` leggono `sections[-1]` se la sezione 0 non si apre (`menu.c:599`, `620`) | il wrapper apre prima un'altra sezione |
| `ncmenu_nextsection`/`prevsection`: ciclo infinito senza sezioni apribili (`menu.c:566-589`) | false senza chiamare il C |
| Un clic su una voce la seleziona ma restituisce false (`menu.c:721-726`) | `offer_input` restituisce true |
| Un evento con id 0 apre la prima sezione senza scorciatoia (`menu.c:746`) | in tutti i widget gli eventi con id 0 e `0xffffffff` non vanno al C |
| `ncreader_offer_input` con 4 codepoint legge oltre `eff_text` (`reader.c:404-410`) | il testo dell'evento lo scrive il wrapper, come farebbe il C |
| Backspace a inizio riga sposta solo la copia nascosta, poi abort (`reader.c:265`, `90`) | il wrapper riallinea vista e cursore del terminale |
| `NCREADER_OPTION_HORSCROLL` con glifi larghi: abort (`reader.c:90`, `222-246`) | opzione non offerta |
| Cursore, dimensioni o scrolling della vista cambiati dall'esterno: letture fuori dal piano (`reader.c:134-136`) | cursore riallineato prima di ogni operazione, altrimenti `WidgetError` |
| EGC di larghezza zero sull'ultima colonna: vista e copia nascosta a x == colonne (`reader.c:240-246`, clamp con cols 0); poi ogni scrittura fallisce e Backspace + freccia sinistra fa abort (`reader.c:90`) | scartato in `put_egc`; il ritorno di `ncplane_cursor_move_yx` diventa `WidgetError` (lotto 4, ICH-273) |
| `ncreader_write_egc` scrive solo il primo EGC della stringa e restituisce 0 (`reader.c:233-238`) | `write` passa i pezzi di `nccell_load` uno alla volta (lotto 4, ICH-274) |
| `nccell_load` di U+2028 restituisce 1 byte e taglia il codepoint (`utf8_egc_len`, `egcpool.h`) | un pezzo non UTF-8 valido non si usa: il resto del grapheme va al C, che lo rifiuta (lotto 4) |
| `ncreader_contents` è `ncplane_contents` sulla vista: una copia nell'egcpool per ogni EGC di più di 4 byte a ogni chiamata (`reader.c:413-415`) | `Reader#contents` usa `Plane#contents` (lotto 4, ICH-275) |
| `ncprogbar_progress` non inizializzato prima del primo set (`progbar.c:18-23`) | 0.0 |
| NaN supera il controllo di `ncprogbar_set_progress` (`progbar.c:178`) | rifiutato |
| Con `-freciprocal-math` l'indice del glifo di bordo arriva a 8 per alcuni valori: -1 e barra a metà (`progbar.c:124`) | `p` abbassato di qualche ulp (0 fallimenti su 9922 valori) |

### Reel, Tree, Tabbed

| Bug | Workaround |
| --- | --- |
| `ncreel`: heap corrotto in `trim_reel_overhang` con una sequenza di add/del/next (`reel.c:494-544`); `infinite_scroll` e `circular` validati e poi ignorati (`reel.c:774-781`) | `Reel` e `Tablet` in Ruby sopra `Plane` (vedi sotto) |
| `nctree_del` legge `spec[-1]` (`tree.c:253`) | l'ultimo indice viene ripetuto davanti al vettore |
| Il `realloc` di `nctree_add` e `nctree_del` lascia `curitem` pendente (`tree.c:182-186`) | fuoco riportato con HOME e N × `nctree_next` |
| `nctree_prev`/`next`/`focused`/`offer_input` su un albero vuoto dereferenziano NULL (`tree.c:351`, `398`, `607`) | il C non viene chiamato |
| `nctree_del` con un percorso vuoto: double free (`tree.c:250`) | `ArgumentError` |
| Le voci di più righe sopra il fuoco si sovrappongono e i loro piani non cambiano mai altezza (`tree.c:419-448`) | il callback del wrapper impila le voci |
| Indentazione più larga del piano: piani di larghezza negativa (`tree.c:444`) | rifiutata |
| Dopo un resize più piccolo la riga attiva resta fuori dal piano e `nctree_redraw` fallisce (`tree.c:522`) | fuoco riposizionato e nuovo tentativo |
| `nctree_goto` è uno stub (`tree.c:609-616`) | `Tree#goto` in Ruby |
| `nctabbed_rotate`, `nctab_move_left`/`right` senza tab: crash (`tabbed.c:335-363`) | `rotate` senza tab non fa nulla; gli altri due non si possono chiamare (il `Tab` è chiuso) |
| Nome di un tab o separatore NULL: crash (`tabbed.c:247`, `457`, `480`) | `TypeError`/`ArgumentError`; rifiutati anche i caratteri di controllo |
| `nctab_move` con `after` e `before` ha il controllo di adiacenza invertito (`tabbed.c:305`) | si accetta solo uno dei due |
| `nctab_move` non aggiorna `leftmost` (`tabbed.c:303-332`) | corretto con `nctabbed_rotate` |
| Nessuna funzione di `tabbed.c` controlla che un tab appartenga al widget | controllo in Ruby (`ArgumentError`) |

Il `Reel` in Ruby segue l'header di `ncreel` dove il C non lo fa: `infinite_scroll:` e `circular:` funzionano (il C è
sempre circolare). Differenze volute: `add` senza `after:`/`before:` mette il tablet in fondo (il C lo mette prima del
fuoco); cancellando il tablet con il fuoco il fuoco va al successivo, o al precedente se era l'ultimo; a ogni
ridisegno il piano del reel viene cancellato e il blocco di ogni tablet è chiamato una sola volta; `Tablet#plane` vale
fino al ridisegno successivo. Bordi arrotondati, ASCII senza UTF-8; niente PgUp/PgDn, come nel C. `Reel` include
`Widget` con il proprio piano (`to_ptr` restituisce il `ncplane*` del reel).

### Plot, FdPlane, Subprocess

| Bug | Workaround |
| --- | --- |
| Indici dei campioni: `ncuplot_add_sample`/`set_sample` e il ridisegno calcolano lo slot in due modi diversi (`plot.c:595`, `616`, `635` contro `657`) | il wrapper trasla le x passate al C, così ogni salto finisce su un multiplo di `slotcount`: `sample` e il dominio sono corretti |
| `set_sample` con x dietro la finestra (`plot.c:657`, `701`) | false senza chiamare il C; prima di ogni scrittura una lettura di controllo con `ncuplot_sample` |
| x >= 2^63 (`plot.c:595`, `616`) | con la traslazione il C non lo riceve mai; l'utente può passare x fino a 2^64-1 |
| `label_ticks:` su un piano di 7 colonne o meno (`plot.c:290`) | `ArgumentError` alla creazione, `WidgetError` a ogni campione (il piano si può ridimensionare dopo) |
| Blitter fuori tabella (`blit.c:1374`) | blitter controllato; la degradazione di `lookup_blitset` è replicata in Ruby e il C riceve sempre `NODEGRADE`, così il numero di slot calcolato in Ruby è quello del C |
| -1 sia per un campione fuori dal dominio fisso sia per un ridisegno fallito (`plot.c:583`, `706`) | il primo restituisce false (il valore resta leggibile), il secondo solleva `WidgetError` |
| Somma dei campioni oltre 2^64-1, o non finita per i double (`plot.c:661`, `673`) | `ArgumentError` |
| Plot in pixel con una cella di 0 pixel: `x % 0`, SIGFPE (`notcurses.c:382` non azzera `pixel_draw_late`; rischio teorico) | blitter pixel usato solo con celle di dimensione maggiore di 0 |
| `ncfdplane_destroy` durante o dentro il callback blocca l'interprete (`fd.c:136-148`); con `follow` busy loop a fine file (`fd.c:50-70`); il ritorno del callback non ferma il thread | `FdPlane` in Ruby: Thread Ruby con `IO#readpartial`, `follow:` ritenta ogni 0,1 s |
| `ncsubproc_destroy` in deadlock con il figlio vivo (`fd.c:432-436`); 3 fd lasciati aperti (`fd.c:231-234`, `438`); il figlio eredita lo stdin (`fd.c:196`); exec fallito non segnalato (`fd.c:207`); SIGKILL a un PID forse riciclato (`fd.c:411`); `restart_period` ignorato | `Subprocess` in Ruby (sottoclasse di `FdPlane`): stdin da `/dev/null`, `close_others`, exec fallito → `Errno::*` subito, kill solo se `Process.detach` non ha ancora raccolto il figlio |

## Bug noti non aggirati (documentati nel YARD)

- **`logrow` dopo il primo scroll** (`notcurses.c:615`, `1777`): `Plane#duplicate`, i resize (anche la crescita per
  autogrow), `rotate_cw`/`rotate_ccw`, il merge sul piano di destinazione e `FadeContext` permutano o perdono righe.
  Un workaround servirebbe un flag "ha fatto scroll" impostato da ogni output: non fatto.
- `Plane#resize` con `keep_x > 0`: gli EGC di più di 4 byte nella regione conservata possono risultare corrotti.
- `Plane#duplicate` non ripristina il flag fixed e l'allineamento verticale.
- `Cell`: notcurses segmenta alcuni grapheme in modo diverso da Ruby (bandiere, sillabe hangul composte, coniugati
  devanagari); scrivere quelle celle solleva `CellError`.
- Reader: Backspace, Ctrl+U e Ctrl+W non cancellano la colonna 0 (`notcurses.c:1883`); `tchannels` e `tattrword` non
  hanno effetto (non offerti); ogni ridisegno accende il cursore del terminale. `ncreader_redraw` copia le celle
  dell'area di testo nella vista con l'offset `xproject` (`reader.c:94-100`): può lasciare la metà destra di un
  glifo largo in colonna 0 della vista senza un resize, e il controllo di ICH-271 (basato sulle dimensioni) non la
  vede in una scrittura su `Reader#plane`.
- Menu: un clic su un separatore può togliere la selezione (`menu.c:722`, flag non inizializzato); `mouse_selected` è
  impreciso per le sezioni allineate a destra.
- Tabbed: l'intestazione non segue il resize del piano (`tabbed.c:35`, `39`); con `bottom: true` sta sulla penultima
  riga (`tabbed.c:37`, `191`).
- Tree: il C calcola la riga attiva con l'altezza della voce che aveva il fuoco prima: con voci di altezze diverse il
  fuoco si sposta di qualche riga.
- Direct: `Frame#close` abbandona il frame senza liberarne la memoria C (3.0.17 non offre un distruttore pubblico);
  `stop` scrive il reset su stdout.
- Visual: `ncvisual_from_palidx` non usa i colori della palette (`visual.c:969`); `ncvisual_rotate` perde la prima
  riga e la prima colonna di pixel a qualsiasi angolo (`visual.c:746`).

## Metodi e funzioni non wrappati

Ogni funzione FFI della Fase 1 (383 `attach_function` + 248 inline e macro) è chiamata dal wrapper oppure compare in
`excluded` di `spec/coverage_spec.rb`, con un motivo da `reasons`. La spec fallisce se una funzione non è né usata né
esclusa, se un'esclusione riguarda una funzione usata o inesistente, o se manca il motivo. Le categorie:

- **Raggruppate in un metodo più generale**: varianti `_const`; `putc`, `putchar*`, `putnstr*`, `putwstr*`,
  `putwc*`, `putwegc*`, `pututf32`, `printf*`, `vprintf*` (in `putstr`/`putegc`/`putc`/`printf`); `*_box`,
  `*_box_sized`, `perimeter_*` (in `box`/`perimeter` con `set:`).
- **Sostituite da un valore Ruby**: le funzioni `nccell_*` di stile, colore e larghezza (`Cell` e `Channels`).
- **wchar_t, va_list, varargs, byte order, formati printf**: non servono da Ruby (`String#encode`, `Kernel#format`,
  `pack`/`unpack`, `String#rjust`).
- **Funzioni libc** di supporto delle inline della Fase 1.
- **Bug di 3.0.17**: elencate nelle tabelle sopra (`ncpile_render_to_*`, `ncplane_contents`, `ncplane_puttext`,
  `ncplane_mergedown`, `ncplane_fadeout`/`fadein`/`pulse`, `ncplane_resize_marginalized`/`placewithin`,
  `ncdirect_stream`, `ncvisual_simple_streamer`, `ncblit_rgb_packed`, `ncselector_delitem`, ...).
- **Attese con il GVL**: `notcurses_get`, `notcurses_get_blocking`, `ncdirect_get_blocking`.
- **`userptr`**: notcurses lo usa per il menu; un indirizzo di oggetto Ruby non è stabile (compattazione del GC).
  Per lo stesso motivo `nctab_userptr`/`nctab_set_userptr` non servono: i dati stanno nel `Tab` e nella closure.
- **Widget e oggetti scritti in Ruby**: `ncreel_*` e `nctablet_*` (13), `ncfdplane_*` (3), `ncsubproc_*` (5),
  `nctree_goto` (stub).

Conteggio finale (spec di copertura verde): 477 funzioni su 631 chiamate direttamente dal wrapper (317
`attach_function` e 160 inline); 154 escluse con un motivo:

| Gruppo | Funzioni |
| --- | ---: |
| raggruppate in un metodo più generale o sostituite da un valore Ruby (`Cell`, `Channels`, `putstr`, `box`, ...) | 97 |
| bug di 3.0.17: reimplementate in Ruby o non offerte | 41 |
| non applicabili da Ruby (libc, `wchar_t`, macro di formato e di byte order, `userptr`) | 14 |
| attesa con il GVL tenuto (`notcurses_get_blocking`, `ncdirect_get_blocking`) | 2 |

## Differenze dai pattern del prompt

| Pattern del prompt | Scelta | Motivo |
| --- | --- | --- |
| `Context#initialize(opts = {}, output: nil)` con hash | keyword per ogni opzione, con default | regola 7; ogni flag `NCOPTION_*` ha il suo nome e il suo controllo |
| `close`: `@closed = true` e poi `notcurses_stop` | prima i widget adottati e i piani, poi lo stop | con un reader vivo lo stop fa un double free |
| `stdplane` con `Plane.new(..., owned: false)` | registro del contesto, piani tracciati e presi in prestito | lo stesso indirizzo deve dare lo stesso oggetto; i piani distrutti dal C devono risultare chiusi |
| `acquire_context(type)`: errore solo se il tipo è diverso | un solo contesto, di qualsiasi tipo; `InitError` | il C rifiuta anche un secondo contesto dello stesso tipo |
| Selector/Reader: `destroy` con `char**` e `free` | `destroy` con NULL; il testo si legge prima (`selected`, `contents`) | `ncselector_destroy(&item)` legge da NULL su un selettore vuoto |
| `Cell` come wrapper di `nccell` | `Cell` valore Ruby, `nccell` temporanea per ogni chiamata | una `nccell` dipende dall'egcpool di un piano (vedi sopra) |
| `Plane#fadeout(duration) { }` sopra `ncplane_fadeout` con il callback | `fadeout(seconds)` in Ruby sopra `FadeContext`; blocco facoltativo chiamato a ogni passo | `ncplane_fadeout` tiene il GVL e renderizza solo la pila standard |
| `Context#get(timeout:)` con `notcurses_get_blocking`/`notcurses_get` | attesa in Ruby su `inputready_fd`, poi `get_nblock` | le funzioni C tengono il GVL |
| `Context#cursor_disable` che chiama sempre il C | idempotente: stato in Ruby (acceso, spento o sconosciuto dopo un `Reader`) | il C restituisce -1 se il cursore è già spento; il ridisegno del `Reader` accende il cursore da sé |
| `putstr(str, y: -1, x: -1)` | `y: nil, x: nil` = cursore; anche `align:` e `stained:` | -1 è un dettaglio del C |
| `putchar(ch, y:, x:)` | `putegc(egc, y:, x:)`, che accetta anche un codepoint Integer | un carattere a schermo è un EGC; un alias sarebbe un doppione |
| `set_styles(styles)` | `styles = [...]`, `on_styles`, `off_styles` | setter Ruby; stili come Symbol |
| `hline(cell, len)` con `len = [len, dim_x].min` | `ArgumentError` se la linea non entra | un clamp silenzioso nasconde l'errore del chiamante |
| `putc_yx`: rifiuta celle più larghe del piano | la `Cell` passa da `nccell_prime` e `load_into` controlla la segmentazione; la posizione è controllata come in `putstr` | protezione più generale |
| `Plot` (u64) con `nculog_create`, `Plot` (double) a parte | una classe `Plot.new(plane, type: :uint64)` o `type: :double`, sopra `ncuplot_*`/`ncdplot_*` | `nculog_create` non esiste in 3.0.17; le due varianti hanno le stesse opzioni e cambiano solo nel tipo dei campioni |
| `Reel` sopra `ncreel_*` | `Reel` e `Tablet` in Ruby | heap corrotto in `trim_reel_overhang` (`reel.c:494-544`); `infinite_scroll` e `circular` ignorati (`reel.c:774-781`) |
| `Tree` con il callback di disegno | `Tree.new(plane, items: [], indent: 0, draw: nil, &block)`; le voci con la keyword `items:`, come in `Selector` | `draw:` sostituisce il blocco, come `on_data:` di `FdPlane`: con `Tree.open` il blocco è già quello di `open` |
| `FdPlane`/`Subprocess` sopra `ncfdplane_*`/`ncsubproc_*` | in Ruby; `FdPlane.new(plane, io)` riceve un IO, `Subprocess.new(plane, program, *args, env:, path:)` | il destroy C blocca l'interprete o va in deadlock (vedi le tabelle); un IO Ruby è più naturale di un fd. Come nel C, `close` chiude l'IO ricevuto (`ncfdplane_destroy` chiude il fd) e il piano resta del chiamante |
| Gerarchia di eccezioni del prompt | in più `CellError`, `ContextError`, `DirectError` | errori di aree che il prompt non separa |

## Integrazione: modifiche ai file condivisi

Gli implementatori hanno lasciato richieste sui file condivisi. Applicate:

- **Cursore e `Reader`**: il ridisegno di `ncreader` accende il cursore del terminale e la chiusura (con `cursor:
  true`) lo spegne, senza passare dal `Context`; `Context#cursor_disable` restava senza effetto. Ora il `Reader` segna
  lo stato come sconosciuto (`Context#cursor_state_unknown!`) prima di ogni operazione e dopo la chiusura; in quello
  stato `cursor_disable` chiama il C e tollera un cursore già nascosto.
- **Chiusura dei figli**: `Context#close` e `#drop_planes` chiudono tutti gli oggetti adottati anche se un `close`
  solleva, poi rilanciano la prima eccezione. Prima `close` intercettava solo `StandardError`: un `SystemExit` salvato
  dal blocco di un `FdPlane` saltava `notcurses_stop`, e i figli rimasti (per esempio un reader) avrebbero fatto un
  double free allo stop successivo.
- **Helper dei widget**: `text!`, `c_text` e `input_struct` erano ripetuti in quattro widget; ora sono metodi privati
  del modulo `Widget`.
- **`io/wait`**: `require 'io/wait'` solo se `IO#wait_readable` manca (Ruby 3.1); su Ruby 4.0 il require stampa un
  avviso di deprecazione.
- **Spec di copertura**: le esclusioni dei widget, con i motivi.

Valutate e non applicate:

- **Rifiutare su `Plane` le operazioni sui piani dei widget** (resize, scrolling, erase, scritture): il rischio noto
  riguarda il `Reader`, che controlla la vista prima di ogni chiamata C e solleva `WidgetError`. La copia nascosta del
  reader si raggiunge navigando la pila e non è protetta: è documentato nel YARD.
- **`callback_errors` per thread**: senza un lock dell'utente due thread non possono comunque usare notcurses insieme;
  con il lock l'eccezione di un callback viene rilanciata nello stesso metodo, prima che l'altro thread entri.
- **TAB nell'ultima colonna in `putstr`/`putegc`**: già rifiutato da `output_text!` e da `Cell.egc!`.

## Verifiche eseguite

- Suite completa, con il comando ufficiale
  `TERM=xterm-256color timeout -k 5 -s KILL 600 bundle exec rspec < /dev/null`: 800 esempi, 0 fallimenti, circa 8 s
  (543 esempi della Fase 2, 257 della Fase 1). Stesso risultato con 5 ordini casuali (`--order rand:1234`, `4242`, `1`,
  `31337`, `2026`). Dopo la modifica del 2026-10-26: 802 esempi, 0 fallimenti, anche con i semi `1234`, `4242`, `7`.
- Un ordine casuale ha mostrato una dipendenza tra gli esempi della spec dei piani: l'helper `with_parent` chiudeva
  solo il genitore, e i figli creati dall'esempio restavano agganciati allo stdplane (in fondo allo z-order dopo
  `move_family_bottom`). Ora l'helper distrugge la famiglia; la spec passa in 8 ordini casuali.
- Spec di copertura: ogni funzione delle 631 è chiamata o esclusa con un motivo.
- YARD: uno script euristico (nello scratchpad, non nel progetto) controlla che ogni metodo pubblico abbia commento,
  `@return` e un `@param` per parametro: 0 problemi su tutti i file di `lib`. Un secondo script segnala i metodi che
  possono sollevare (chiamano `to_ptr`, `raise`, `check!` o un validatore) senza `@raise`: 19 trovati e completati,
  resta un falso positivo (`Input#to_ffi`).
- `ruby -w -Ilib -e 'require "notcurses"'`: nessun warning.
- Ruby 3.1: tutti i file di `lib` passano il parser `Parser::Ruby31` (gem `parser`, installata nello scratchpad) e un
  grep non trova API successive alla 3.1 (`Data`, `Set` senza require, parametri anonimi `*`/`**`, `it`, ...).
  L'esecuzione su 3.1 non è provata: su questa macchina il build di Ruby 3.1.7 con mise fallisce (gcc 16.2:
  `conflicting types for 'onig_jis_property'` in `enc/jis/props.kwd`).
- Ogni implementatore ha eseguito le proprie spec anche in ordine casuale. Gli esempi che possono restare appesi hanno
  un timeout interno; i casi che vanno in crash girano in processi figli; `FdPlane` e `Subprocess` contano i fd in
  `/proc/self/fd` prima e dopo ogni esempio.
- `blocking: true` (2026-10-26), con due esempi scritti prima della modifica e falliti con il codice vecchio:
  - `spec/integration/pty_spec.rb`: un processo figlio crea un pty e un thread Ruby che risponde a DA1 e alla
    posizione del cursore, poi apre `Context` e `Direct` e chiama `cursor_yx`, `cursor_move(y: 2)` e `readline`.
    Prima: stallo all'init di `Context` (timeout di 15 s). Dopo: tutto funziona, e durante `readline` (circa 0,3 s di
    attesa) un altro thread fa una sessantina di passi; stabile in 5 esecuzioni;
  - `spec/notcurses/visual_spec.rb`: durante `Visual#stream` senza blocco un thread che conta i passi faceva 0 passi,
    ora più di 10 (soglia del test).
