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

## Bug di notcurses 3.0.17

Dal 2026-11-23 la regola per gestirli, le tabelle dei bug aggirati e i bug noti non aggirati sono in
[bug-notcurses.md](bug-notcurses.md), il registro che i lotti aggiornano.

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
