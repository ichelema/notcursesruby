# Fase 2 — review indipendente: log di lavoro

- Data: 2026-10-26
- Base: commit `b2d873a` (Fase 2 `7e033bd`, più `5c4c35b`). Fix nel commit `553aa1d`.
- Esito: 6 finder, 27 finding, 22 dopo l'unione dei doppioni. Verdetti: 21 CONFERMATI (4 alta, 6 media, 11
  bassa), 1 SMENTITO, nessun PLAUSIBILE come finding intero (tre parti di A6-02 e A6-03 restano PLAUSIBILI, vedi
  "Aperti"). Tutti i confermati sono corretti; la suite passa da 802 a 826 esempi, 0 fallimenti.
- Ruby 3.1.7: build con `-std=gnu17`. La suite con il seme `4242` ha trovato una corsa della Fase 2 in
  `FdPlane#close` (R31-01, sezione "Ruby 3.1"), corretta: 827 esempi, 0 fallimenti su 3.1.7 e 4.0.7.

## Metodo

- **Agenti (12).** 6 finder `trinity:reviewer`, in sola lettura, uno per area; 6 agenti di controllo
  `trinity:deep-reasoner`, uno per area, con script e spec nello scratchpad. Gli script che potevano andare in crash
  giravano in un processo figlio con `timeout -k 5 -s KILL` e lo stdin da `/dev/null`.
- **Aree.** 1 nucleo e valori (`context.rb`, `resource.rb`, `error.rb`, `version.rb`, `input.rb`, `stats.rb`,
  `channel.rb`, `format.rb`, `util.rb`, `lib/notcurses.rb`); 2 piani (`plane.rb`, `cell.rb`); 3 Direct e Visual
  (`direct.rb`, `visual.rb`, `pixel.rb`, `palette.rb`); 4 Selector, MultiSelector, Menu, Reader, ProgBar, Plot; 5
  Reel, Tree, Tabbed, FdPlane, Subprocess; 6 API pubblica di tutte le classi (coerenza fra classi).
- **Criteri (tutti per ogni area).** Memoria e ciclo di vita; errori ai confini; callback ed eccezioni (anche
  `break`, `throw`, `return`); thread, GVL e segnali; convenzioni (le 10 regole vincolanti, YARD fedele); test.
  Severità: alta = crash, corruzione della memoria, blocco, perdita di dati; media = eccezione sbagliata o assente,
  comportamento diverso dal YARD, perdita di risorse; bassa = convenzione, nome, YARD.
- **Indipendenza.** I finder non hanno ricevuto `memory/fase2-wrapper-idiomatico.md` né conclusioni: solo le regole,
  i criteri, i file dell'area e le spec.
- **Doppioni.** R1 = A1-02 + A5-02 (uscite non locali dai blocchi chiamati dal C); R2 = A1-01 + A3-01 (eccezione
  asincrona durante l'init); R3 = A6-01 + A2-06 + A1-04 + A3-03 (regola 7).
- **Decisioni note.** Confronto con la memoria della Fase 2: A6-02 contesta `Plane#move_cursor(-1, ...)` contro la
  decisione "nil al posto del -1 del C" e trova la decisione "`set_styles` diventa `styles=`" non applicata a
  `Direct`; A3-04 contesta `Direct#readline`, documentato; A4-01 è diverso dal bug noto "Backspace non cancella la
  colonna 0". Ogni contestazione è passata al controllo con il motivo della decisione.
- **Controllo avversario.** Ogni agente di controllo ha provato a smentire i finding della sua area con uno script,
  una spec o le righe del C. Verdetti CONFERMATO, PLAUSIBILE, SMENTITO; nel dubbio PLAUSIBILE.
- **Scelte dell'utente** (AskUserQuestion): regola 7 "tutto keyword"; rinomine A6-02/03/04/06/07 "rinomina, nomi
  vecchi via"; A6-05 `PlaneError` (e `WidgetError` per i widget); cursore "`move_cursor` in entrambe"; A3-02 "sì,
  `blocking: true`" (unico cambio della Fase 1).
- **Fix.** Uno alla volta. Per ognuno prima una spec, fallita sul codice di allora, poi il fix, poi la suite completa.
  I tre finding di soli test (A1-05, A2-07, A5-03) aggiungono spec che passano subito.

## Finding

| Id | `file:riga` (prima dei fix) | Sev. | Criterio | Verdetto | Fix o motivo |
| --- | --- | --- | --- | --- | --- |
| R2 (A1-01, A3-01) | `context.rb:262`, `direct.rb:219` | alta | memoria | CONFERMATO | L'init gira in un thread interno e `initialize` legge il puntatore con `init.value`: il `rescue Exception` ha sempre il puntatore, ferma il contesto (`notcurses_stop`, `ncdirect_stop`), ripristina `TERM`, libera il registro e il `FILE*`, poi rilancia. Lo stato si imposta per ultimo; fino ad allora `@closed` è true. |
| R1 (A1-02, A5-02) | `util.rb:485`, `widgets/tree.rb:358` | alta | callback | CONFERMATO | `Util.guard`: un `ensure` ferma `break`, `return` e `throw` prima dei frame C, salva una `LocalJumpError` e restituisce il valore di ripiego al C. `Thread#kill` passa (stato `aborting`): FdPlane e Subprocess fermano così il thread di lettura. |
| A2-01 | `plane.rb:103` | alta | memoria | CONFERMATO | `Plane.new` solleva `ArgumentError` se il piano ha già un wrapper aperto e il nuovo è tracciato o posseduto: prima sfrattava il wrapper vivo e il trampolino del resize finiva al GC (SIGSEGV al resize del genitore). Un secondo wrapper si crea con `owned: false, tracked: false`. |
| A4-01 | `widgets/reader.rb:128` | alta | memoria | CONFERMATO | `Reader#offer_input` svuota la vista (`ncplane_erase`, poi il cursore) prima di Backspace e, senza `no_cmd_keys` e fuori dalla colonna 0, prima di Ctrl+U e Ctrl+W. Il C cancella solo nella copia nascosta e `cellcmp_and_dupfar` non confronta la width (`internal.h:1512-1519`): la metà destra di un glifo largo restava nella vista con width 2, e il glifo largo successivo in penultima colonna scriveva oltre il framebuffer (`notcurses.c:1957-1961`, abort al `free`). |
| A2-02 | `plane.rb:380` | media | callback | CONFERMATO | `raise_callback_errors!` dentro un callback rilancia solo le eccezioni salvate dopo l'ingresso di quel callback (`@callback_errors_seen`, salvato e ripristinato da `callback_scope`): l'eccezione di un fratello non interrompe più a metà il resize `:marginalized`. |
| A2-03 | `plane.rb:1184` | media | errori | CONFERMATO | `set_base` usa `Cell.egc!` e rifiuta TAB e `"\n"` come `Cell.new` (il TAB usciva crudo verso il terminale). `Util.egc!` rimosso. |
| A2-04 | `plane.rb:2601` | media | errori | CONFERMATO | `Plane#==`: due wrapper aperti con lo stesso indirizzo sono uguali; con un wrapper chiuso serve anche la stessa generazione di nascita (`@born`), perché glibc riusa subito l'indirizzo di un piano distrutto. `hash` invariato. |
| A3-02 | `direct.rb:1204` | media | thread | CONFERMATO | Fase 1, autorizzato: `blocking: true` su `ncdirect_render_image` e `ncdirect_raster_frame`. Con il blitter `:pixel`, o un allineamento senza `hpa`, chiedono la posizione del cursore (`direct.c:225`, `439`) e prima bloccavano per sempre un terminale servito da un thread Ruby. YARD di `Direct`, `render_image`, `Frame#raster`, `stream`. |
| A5-01 | `widgets/reel.rb:518` | media | errori | CONFERMATO | `rows_of`: un tablet senza bordi orizzontali con 0 righe usate occupa una riga vuota (prima `ArgumentError` da `Plane#resize` a ogni ridisegno, e tutti i tablet perdevano il piano). `@raise [TypeError]` aggiunto dove un blocco può restituire un non Integer. |
| A6-05 | `plane.rb:1284` | media | errori | CONFERMATO | `merge_down` con `dst` uguale al piano o in un'altra pila solleva `PlaneError`, come `move_above`/`move_below`; `Tabbed.new` con meno di 2 righe e `Plot.new(label_ticks: true)` con 7 colonne o meno sollevano `WidgetError`, come `MultiSelector` e `Plot#add_sample`. |
| A1-03 | `util.rb:228` | bassa | errori | CONFERMATO | `Util.string!` trasforma `EncodingError` (byte non validi, codifica senza convertitore come UTF-7) in `ArgumentError`, come promettono il suo YARD ed `error.rb`. |
| A2-05 | `plane.rb:1436` | bassa | errori | CONFERMATO | `ncplane_put` lascia la cella `"\n"` sotto il cursore dopo un a capo (`notcurses.c:1903-1906`). `Cell.from_c` la legge come cella vuota (EGC `""`, width 0) per `Plane#at` e `Context#at`; `Plane#contents` la salta. Il C la disegna come uno spazio (`render.c:619`). |
| R3 (A6-01, A2-06, A1-04, A3-03) | `plane.rb:1142` e altri 13 metodi | bassa | convenzioni | CONFERMATO | Regola 7, "tutto keyword": i 14 metodi pubblici con un posizionale opzionale (4 di `Plane`, 2 di `Context`, 4 di `Direct`, `new` di `Cell`, `Channel`, `Channels` e `Pixel`) diventano keyword (vedi "Cambi dell'API"). `spec/notcurses/api_spec.rb` lo controlla per riflessione. |
| A6-02 | `direct.rb:424` | bassa | convenzioni | CONFERMATO | `Direct#styles=` (via `set_styles`), `on_styles`/`off_styles(*styles)` (`Util.styles_mask`, spostato da `Plane`), `box(set:, hide:)`, `move_cursor(y:, x:)`; `Plane#move_cursor` con `nil` e non `-1`; `Plane#cursor_yx`. Smentite dal C: i ritorni di `Direct#putstr`/`putegc`, `ul:`/`ur:`/`ll:`/`lr:` di `Direct#box`, `hline`/`vline` di Direct senza `y:`/`x:`. |
| A6-03 | `context.rb:231` | bassa | convenzioni | CONFERMATO | `Context.new(margins:)` accetta `[alto, destra, basso, sinistra]`; `Plot.new(blitter:)`; in `Visual` `no_degrade:` e `no_interpolate:`; `Plane#as_rgba(y: nil, x: nil, rows: nil, cols: nil)`. Non difetti: `erase_region(y, x, rows, cols)` (obbligatori, regola 7 rispettata), `resize(rows, cols)`. |
| A6-04 | `widgets/selector.rb:62` | bassa | convenzioni | CONFERMATO | Regola 5: 11 keyword dei colori in snake_case (`op_channels:`, `desc_channels:`, `title_channels:`, `foot_channels:`, `box_channels:`, `header_channels:`, `section_channels:`, `ul_channel:`, `ur_channel:`, `bl_channel:`, `br_channel:`). `foot_channels:` è lo snake_case diretto di `footchannels`. |
| A6-06 | `widgets/tabbed.rb:218` | bassa | convenzioni | CONFERMATO | `Tabbed#next`/`#prev` (prima `select_next`/`select_prev`, come `Reel` e `Tree`) e `alias size tab_count`. |
| A6-07 | `direct.rb:1154` | bassa | convenzioni | CONFERMATO | `Direct::Image#geometry` restituisce `Visual::Geometry`, come `Visual#geometry` (prima `#geom` con un Hash); costante `GEOM_FIELDS` rimossa. |
| A1-05 | `spec/notcurses/context_spec.rb:262` | bassa | test | CONFERMATO | `spec/integration/pty_spec.rb`: `get` attende senza tenere il GVL, `getvec` legge più eventi, il timeout scade con nil, un `Interrupt` esce da `get`. |
| A2-07 | `spec/notcurses/plane_spec.rb:377` | bassa | test | CONFERMATO | Ordine esatto dello z-order dopo `move_family_top`/`move_family_bottom` (prima le asserzioni accettavano qualunque piano); esempi per `merge_down`, `erase_region`, `greyscale`, `as_rgba`, `qrcode`. |
| A5-03 | `spec/notcurses/reel_spec.rb:174` | bassa | test | CONFERMATO | Tablet alto 0 senza bordi: spec di A5-01; `break`/`throw` nei blocchi di Tree e Tabbed: spec di R1; `Tree#delete([1, 0])` a profondità 2: `tree_spec.rb`. |
| A3-04 | `direct.rb:890` | bassa | errori | SMENTITO | `Direct#readline` restituisce nil a fine input o se la lettura fallisce, come dice il YARD. Il wrapper non può distinguere i due casi: NULL non porta `errno` e `n->eof` è privato di `struct ncdirect`. |

Spec scritte prima dei fix e fallite sul codice di allora: R2 (pty: Ctrl-C durante l'init), R1 (3 esempi), A2-01,
A2-02, A2-03, A2-04 (piano nuovo `==` al vecchio), A5-01 (`ArgumentError`), A3-02 (processo figlio bloccato), A6-05
(3), A1-03 (`InvalidByteSequenceError`), A2-05 (`"a\nb"`), R3 (45 e la riflessione), A6-02 (45), A6-03 (12), A6-04
(riflessione), A6-06 (6), A6-07 (3), A4-01 (metà destra orfana; nel processo figlio con `libc_malloc_debug`
`free(): invalid pointer` per Backspace, Ctrl+U e Ctrl+W).

## Decisioni

1. **R2, thread di init.** `Thread.handle_interrupt` non differisce il SIGINT predefinito su Ruby 3.1.7 né i `trap`
   dell'utente, e un `rescue` da solo non ha il puntatore, perso nel frame FFI quando Ruby consegna l'eccezione al
   ritorno della chiamata bloccante. Il thread interno conserva il risultato dell'init. Effetto collaterale,
   documentato nel YARD di `Context` e `Direct`: notcurses blocca SIGWINCH e SIGCONT nel thread interno, non nei
   thread del chiamante (provato: con `no_winch_sighandler: false` il thread principale non li ha bloccati).
2. **R1, `ensure` con ritorno.** `rb_rescue2` di ruby-ffi 1.17.4 intercetta solo `raise`: `throw`, `break` e
   `return` saltavano i frame C con il `pilelock` di notcurses tenuto (`notcurses_stop` falliva poi con 16).
   L'`ensure` di `Util.guard` vede il blocco non finito e restituisce il valore di ripiego; la `LocalJumpError`
   esce dal metodo Ruby che ha chiamato il C, come le altre eccezioni dei callback.
3. **A2-04, generazione di nascita.** Usa l'invariante già richiesto dai piani presi in prestito: ogni distruzione
   di piani nota al wrapper chiama `Context#planes_destroyed!`. Nella stessa generazione un indirizzo identifica un
   solo piano C, quindi `==` non dà mai un falso positivo; un falso negativo è possibile solo fra wrapper chiusi.
4. **A4-01, vista svuotata.** Alternativa scartata: rifiutare i glifi larghi nel Reader (toglie una funzione). Lo
   svuotamento è sicuro perché il C ridisegna sempre dopo quei tasti: `do_backspace` sempre, Ctrl+W con il cursore
   oltre la colonna 0 passa da `ncreader_move_left`, che ridisegna. Dopo il ridisegno le metà destre nella vista
   possono avere width 0 invece di 2: render e `contents` restano identici.
5. **A2-05, cella vuota e non cella base.** Il C disegna la cella `"\n"` come uno spazio, non come la cella base:
   `Plane#at` restituisce `""` anche quando la base ha un EGC.
6. **Rinomine.** Vince la forma della regola vincolante o della maggioranza; i nomi vecchi spariscono (la gem non
   ha utenti), senza alias di compatibilità.

## Cambi dell'API pubblica

| Prima | Dopo | Finding |
| --- | --- | --- |
| `Plane#at(y = nil, x = nil)` | `at(y: nil, x: nil)` | R3 |
| `Plane#set_base(egc = ' ', styles:, channels:)` | `set_base(egc: ' ', styles:, channels:)`; TAB e `"\n"` rifiutati | R3, A2-03 |
| `Plane#scrollup(lines = 1)` | `scrollup(lines: 1)` | R3 |
| `Plane#set_resize_callback(callback = nil, &block)` | `set_resize_callback(callback: nil, &block)` | R3 |
| `Cell.new(egc = ' ', ...)` | `Cell.new(egc: ' ', ...)` | R3 |
| `Channel.new(value = 0)`, `Channels.new(value = 0)`, `Pixel.new(value = 0)` | `new(value: 0)` | R3 |
| `Context#cursor_enable(y = 0, x = 0)` | `cursor_enable(y: 0, x: 0)` | R3 |
| `Context#mice_enable(events = :all)` | `mice_enable(events: :all)` | R3 |
| `Direct#cursor_up/down/left/right(count = 1)` | `cursor_*(count: 1)` | R3 |
| `Direct#set_styles(styles)` | `Direct#styles=(styles)` | A6-02 |
| `Direct#on_styles(styles)`, `off_styles(styles)` | `on_styles(*styles)`, `off_styles(*styles)` | A6-02 |
| `Direct#box(..., style:, omit:)` | `box(..., set:, hide:)` | A6-02 |
| `Direct#cursor_move(y: nil, x: nil)` | `Direct#move_cursor(y: nil, x: nil)` | A6-02 |
| `Plane#move_cursor(y, x)` con `-1` = asse invariato | `nil` = asse invariato; `-1` solleva `PlaneError` | A6-02 |
| — | `Plane#cursor_yx` (alias di `cursor`) | A6-02 |
| `Context.new(margins: String)` | anche `margins: [alto, destra, basso, sinistra]` | A6-03 |
| `Plot.new(grid:)` | `Plot.new(blitter:)` | A6-03 |
| `Visual` (`blit`, `geometry`, `blit_*`, `create_plane`, ...) `nodegrade:`, `nointerpolate:` | `no_degrade:`, `no_interpolate:` | A6-03 |
| `Plane#as_rgba(y: -1, x: -1, rows: 0, cols: 0)` | `as_rgba(y: nil, x: nil, rows: nil, cols: nil)`; `-1` e `0` sollevano `ArgumentError` | A6-03 |
| `Selector`, `MultiSelector`: `opchannels:`, `descchannels:`, `titlechannels:`, `footchannels:`, `boxchannels:` | `op_channels:`, `desc_channels:`, `title_channels:`, `foot_channels:`, `box_channels:` | A6-04 |
| `Menu`: `headerchannels:`, `sectionchannels:` | `header_channels:`, `section_channels:` | A6-04 |
| `ProgBar`: `ulchannel:`, `urchannel:`, `blchannel:`, `brchannel:` | `ul_channel:`, `ur_channel:`, `bl_channel:`, `br_channel:` | A6-04 |
| `Tabbed#select_next`, `#select_prev` | `Tabbed#next`, `#prev`; nuovo `Tabbed#size` | A6-06 |
| `Direct::Image#geom` → `Hash`, `Direct::Image::GEOM_FIELDS` | `Direct::Image#geometry` → `Visual::Geometry` | A6-07 |
| `Plane#merge_down`: `ArgumentError` per `dst` stesso o in un'altra pila | `PlaneError` | A6-05 |
| `Tabbed.new` (meno di 2 righe), `Plot.new(label_ticks: true)` (7 colonne o meno): `ArgumentError` | `WidgetError` | A6-05 |
| `Plane.new` su un piano con un wrapper aperto, tracciato o posseduto | `ArgumentError` | A2-01 |
| `String` non convertibile in UTF-8: `EncodingError` | `ArgumentError` | A1-03 |

## Aperti

- **PLAUSIBILI** (parti di finding confermati, due letture valide, non applicate): `Plane#hline(from:)` (colori
  della prima cella della sfumatura) contro `Direct#hline(channels:)` (il nome di tutto `Direct` per i colori di
  scrittura); `Direct#print_aligned` contro `Plane#putstr(align:)` (`Direct#putstr` rispecchia `ncdirect_putstr`,
  senza allineamento); in `Visual` `rowstride:` (5 `from_*`) contro `linesize:` (4 `blit_*`), che seguono i nomi C.
- **Decisioni dell'utente sugli aperti (2026-10-26, Parte 0 della Fase 3 in `RIPRESA.md`):** `from_plane` e
  `as_rgba` con `y:`, `x:`, `rows:`, `cols:` e default `y: 0, x: 0` (`nil` = cursore o fino al bordo; `-1` e `0`
  rifiutati); `rowstride:` anche nei `blit_*`; `empty?` in `Reel` e `Tabbed`; `Direct` invariato.
- **Emersi dal controllo, fuori dall'elenco approvato:** `Visual.from_plane(begy:, begx:, leny:, lenx:)` ha ancora i
  valori speciali del C (`-1` = cursore, `0` = fino al bordo) e nomi diversi da `as_rgba(y:, x:, rows:, cols:)`
  (stessa correzione di `as_rgba`); `empty?` esiste in `Tree` ma non in `Reel` e `Tabbed`.
- **Residui di R2:** un secondo Ctrl-C mentre il `rescue` attende un terminale che non risponde mai esce dal
  `rescue` e lascia il registro occupato (oggetto chiuso, nessun crash); `Thread#kill` del chiamante durante l'init
  non passa dal `rescue`; `report_on_exception` del thread di init non è disattivato (il thread non solleva).
- **Note dei verificatori:** su un piano che scorre un testo largo quanto la riga seguito da `"\n"` lascia il cursore
  due righe sotto (`notcurses.c:1888-1890` e `1903-1904`), contro il YARD di `putstr`; la causa radice di A4-01
  (`cellcmp_and_dupfar` senza width) potrebbe toccare altre copie fra piani: nessuna trovata, da controllare.

## Ruby 3.1

- **Build.** mise 2026.10.17 compila Ruby 3.1.7 con ruby-build (nessun binario precompilato) e gcc 16.2.1. Ipotesi
  confermata: da gcc 15 lo standard C di default è C23, dove `f()` vale `f(void)`. `enc/jis/props.h:72` dichiara
  `onig_jis_property()` senza parametri, mentre la definizione generata da gperf (`enc/jis/props.kwd:146`) ha
  `(const char *, size_t)`. Con `RUBY_CFLAGS='-std=gnu17'` il build riesce in 196 s, e
  `RbConfig::CONFIG['CFLAGS']` del Ruby installato vale ` -std=gnu17 -fPIC`.
- **Versioni.** `ruby 3.1.7p261 (2025-03-26 revision 0a3704f218) [x86_64-linux]`, RubyGems 3.3.27, Bundler 2.3.27,
  ffi 1.17.4 (`x86_64-linux-gnu`), rspec 3.13.2 (rspec-core 3.13.6, rspec-expectations 3.13.5, rspec-mocks 3.13.8,
  rspec-support 3.13.7), diff-lcs 1.6.2. Il `Gemfile` è una copia fuori dal progetto: `Gemfile` e `Gemfile.lock`
  del progetto non cambiano.
- **Risultato.** Nessuna incompatibilità di sintassi o di API. Prima dei fix della review (`b2d873a`): 802 esempi,
  0 fallimenti (29 s), anche con i semi `1234`, `4242` e `7`. Dopo i fix (`553aa1d`): 826 esempi, 0 fallimenti
  (35 s) in ordine normale, ma 1 fallimento con il seme `4242` (R31-01). Dopo il fix di R31-01: 827 esempi, 0
  fallimenti, anche con i tre semi, su 3.1.7 e 4.0.7. `ruby -w -Ilib -e 'require "notcurses"'`: nessun warning.
- **R31-01** (media, errori e thread, CONFERMATO, corretto). `lib/notcurses/fd_plane.rb:134` (prima del fix):
  `FdPlane#close` impostava `@closed = true` e poi aspettava il thread di lettura. Il blocco in corso riceveva
  `ClosedError` da `f.plane`, `Util.guard` la salvava e `close` la rilanciava (da `Context#close` dopo
  `notcurses_stop`). Il YARD di `close` dice invece che `close` aspetta la fine del blocco. Bug della Fase 2
  (`fd_plane.rb` e la spec non sono cambiati da `7e033bd`): l'esempio "Context#close chiude un FdPlane in lettura
  prima di notcurses_stop" falliva 2 volte su 40 da solo su 3.1.7, 0 su 40 su 4.0.7. Fix: `@stopping` ferma il ciclo
  di lettura e `on_done:` (anche in `Subprocess#finish`); `@closed` diventa true dopo lo `join`, in un `ensure`.
  Spec nuova "close aspetta il blocco in corso, che può ancora usare l'FdPlane": il blocco aspetta con
  `Thread.pass until Thread.pending_interrupt?` il `kill` di `close` (inviato dopo il flag), poi chiama `f.plane`;
  sul codice vecchio fallisce sempre (3 su 3 su 3.1.7 e 4.0.7), dopo il fix passa 10 su 10. L'esempio originale
  dopo il fix: 80 su 80 su 3.1.7.
- **Differenza di Ruby 3.1 trovata con R31-01.** Su 3.1.7 `String#grapheme_clusters` e `each_grapheme_cluster`
  consegnano le interruzioni rimandate da `Thread.handle_interrupt(Object => :on_blocking)`, su 4.0.7 no; nelle
  prove `scan` e `match?` non le consegnano in nessuna delle due. Effetto: su 3.1 il `kill` di `close` può fermare
  il blocco di un `FdPlane` dentro un metodo di testo del wrapper (`Plane#putstr` chiama `grapheme_clusters` prima
  di scrivere; `puttext`, `Reader`, `Cell.egc!`, `box` li usano). Nessun uso sta fra una creazione C e la sua
  registrazione: il rischio è un testo scritto a metà. Documentato nel YARD di classe di `FdPlane`; la spec nuova
  non usa `putstr` per questo motivo.

Comandi esatti, dalla radice del progetto. `S` è una cartella temporanea fuori dal progetto (in questa sessione lo
scratchpad di Claude Code).

```sh
S=/percorso/assoluto/dello/scratchpad
mkdir -p "$S/ruby-build-tmp" "$S/gemfile31" && cp Gemfile "$S/gemfile31/Gemfile"
# build, circa 3 minuti; ruby-build scrive in TMPDIR circa 340 MB
TMPDIR="$S/ruby-build-tmp" RUBY_CFLAGS='-std=gnu17' mise install ruby@3.1.7 > "$S/ruby31-install.log" 2>&1; echo "exit $?"
# gem e suite su 3.1.7
MISE_EXEC_AUTO_INSTALL=false BUNDLE_GEMFILE="$S/gemfile31/Gemfile" mise exec ruby@3.1.7 -- bundle install --quiet
MISE_EXEC_AUTO_INSTALL=false BUNDLE_GEMFILE="$S/gemfile31/Gemfile" TERM=xterm-256color \
  mise exec ruby@3.1.7 -- timeout -k 5 -s KILL 600 bundle exec rspec < /dev/null
# in ordine casuale
for seed in 1234 4242 7; do MISE_EXEC_AUTO_INSTALL=false BUNDLE_GEMFILE="$S/gemfile31/Gemfile" TERM=xterm-256color \
  mise exec ruby@3.1.7 -- timeout -k 5 -s KILL 600 bundle exec rspec --order rand:$seed < /dev/null; done
# warning
MISE_EXEC_AUTO_INSTALL=false mise exec ruby@3.1.7 -- ruby -w -Ilib -e 'require "notcurses"'
```

`MISE_EXEC_AUTO_INSTALL=false` serve in ogni `mise exec`: con `exec_auto_install = true` mise riavvia il build se la
versione non è installata. La versione globale di Ruby (4.0.7 in `~/.config/mise/config.toml`) non cambia.

## Controlli eseguiti

Stato finale, dopo i fix della review e di R31-01:

- Suite completa su Ruby 4.0.7: 827 esempi, 0 fallimenti (15 s), anche con `--order rand:1234`, `rand:4242`,
  `rand:7`. Sullo stato di `553aa1d`: 826 esempi, 0 fallimenti, anche con i tre semi.
- Suite completa su Ruby 3.1.7: 827 esempi, 0 fallimenti (35 s), anche con i tre semi.
- `ruby -w -Ilib -e 'require "notcurses"'`: nessun warning, su Ruby 4.0.7 e 3.1.7.
- `spec/coverage_spec.rb` passa (parte della suite): nessuna funzione FFI nuova o tolta.
- YARD con gli script euristici della sessione precedente: `yard_check.rb` 0 problemi; `yard_raise_check.rb` 605
  metodi, 1 falso positivo noto (`input.rb:300 to_ffi`).
- Diff della Fase 1: solo `blocking: true` su `ncdirect_render_image` e `ncdirect_raster_frame` e il commento in testa
  a `lib/notcurses/ffi/functions.rb`.
