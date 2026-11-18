# Issue in Backlog — log

Decisioni, problemi e soluzioni, lotto per lotto. Ordine dei lotti e regole in `RIPRESA.md`; esito in
`RICONSEGNA.md`, sezione "Issue in Backlog".

## Prima di iniziare (2026-11-15)

- Hindsight, bank `notcursesruby`: il recall risponde (41 memorie, coerenti con `RIPRESA.md`).
- `master` su `06ddb73`, working tree pulito, submodule `notcurses` inizializzato. Il checkout è in
  `/mnt/data/Sviluppo/...`; `/Dati` è un link a `/mnt/data`, quindi i comandi di `RIPRESA.md` valgono.
- Suite completa: 1048 esempi, 0 fallimenti (38,8 s); `bundle exec rubocop`: 99 file, 0 offense.
- Linear: 35 issue aperte, tutte in Backlog, le stesse della tabella di `RIPRESA.md`. ICH-214…ICH-232 hanno già
  `Acceptance criteria`: il passo 7 di "Prima di iniziare" non serve.

### File per issue

Dalle descrizioni su Linear; i file di spec seguono quelli richiesti dalle issue.

| Issue | File di `lib/` | Spec |
| --- | --- | --- |
| ICH-214 | `plane.rb` (`resize*`, `duplicate`, `rotate_*`, `merge_down`, `FadeContext`) | `plane_spec.rb` |
| ICH-215 | `plane.rb` (`resize_region`) | `plane_spec.rb` |
| ICH-216 | `plane.rb` (`duplicate`) | `plane_spec.rb` |
| ICH-217 | `cell.rb`, `plane.rb` (scritture di celle, `putstr`) | `cell_spec.rb`, `plane_spec.rb` |
| ICH-218 | `widgets/reader.rb` | `reader_spec.rb` |
| ICH-219 | `widgets/menu.rb` | `menu_spec.rb` |
| ICH-220 | `widgets/tabbed.rb` | `tabbed_spec.rb` |
| ICH-221 | `widgets/tree.rb` | `tree_spec.rb` |
| ICH-222 | `direct.rb` (`Frame#close`, `stop`) | `direct_spec.rb` |
| ICH-223 | `visual.rb` (`from_palidx`, `rotate`) | `visual_spec.rb` |
| ICH-225 | dipende dall'audit: `cellcmp_and_dupfar` è in `reader.c:100` (Reader, A4-01) e in `postpaint_cell` (`render.c:453`, `482`), chiamata dal render e da `ncplane_mergedown` (`render.c:600`) | spec per ogni punto di ingresso |
| ICH-226 | `context.rb`, `direct.rb` (thread dell'init) | `pty_spec.rb` |
| ICH-227 | `fd_plane.rb`, `subprocess.rb`, metodi di testo di `plane.rb`, `cell.rb`, `widgets/reader.rb` | `fd_plane_spec.rb` |
| ICH-230 | `ui/log_view.rb` | `log_view_spec.rb` |
| ICH-231 | `ui/event_loop.rb`, esempio di `ui/log_view.rb` | `event_loop_spec.rb` |
| ICH-232 | `ui/component.rb` (`Text.check!`), helper `@api private` in `plane.rb` | spec dei widget UI |
| ICH-441 | `context.rb`, `direct.rb` (`close`, fork) | `pty_spec.rb` |
| ICH-448 | `plane.rb` (`clear_cut_glyphs!`, `@cut_glyphs_cols`), forse `context.rb` | `pty_spec.rb` |
| ICH-449 | `plane.rb` (`merge_down`, `at`); causa da trovare nel C | `plane_spec.rb` |
| ICH-450 | `plane.rb` (`polyfill`, `gradient`, `erase_region`, forse `stain`, `format`) | `plane_spec.rb` |
| ICH-454 | `ui/event_loop.rb`, `context.rb` (`linesigs*`) | `ui_pty_spec.rb` |
| ICH-455 | `ui/event_loop.rb` (`line_signal`) | `ui_pty_spec.rb` |
| ICH-456 | `ui/event_loop.rb`, `context.rb` (`linesigs*`) | `ui_pty_spec.rb` |
| ICH-457 | `ui/app.rb`, `ui/component.rb`, `memory/fase3-design.md` | `app_spec.rb`, `ui_pty_spec.rb` |
| ICH-458 | `direct.rb` (`stream`) | `pty_spec.rb`, `direct_spec.rb` |
| ICH-459 | `ui/container.rb` (`close_parts`), `ui/component.rb` (`close`) | `app_spec.rb` o `container_spec.rb` |
| ICH-460 | `ui/dialog.rb`, `ui/container.rb` (`distribute`) | `dialog_spec.rb` |
| ICH-461 | `ui/app.rb` (`attached`, `release_focus`, `resized`, `restore_focus`), `ui/component.rb` (`layout`) | `dialog_spec.rb`, `app_spec.rb` |
| ICH-463 | `context.rb` (`get`, `close`), forse `direct.rb` (`get`) | spec in un processo figlio |
| ICH-464 | `resource.rb` (`to_ptr`), `context.rb`, `direct.rb` (`close`) | spec in un processo figlio |
| ICH-469 | quasi tutti i file, `.rubocop_todo.yml`, `notcursesruby.gemspec`, `.git-blame-ignore-revs` | `gemspec_spec.rb` |
| ICH-470 | `ui/component.rb:223`, `.rubocop_todo.yml` | — |
| ICH-473 | commento YARD di `ui/app.rb:50-60`, `CHANGELOG.md` | nessuna (repro di ICH-304) |
| ICH-474 | `visual.rb` (`from_file`), `direct.rb` (`render_frame`, `Image#initialize`), commento di `fd_plane.rb` | spec in un processo figlio |
| ICH-475 | `context.rb` (`close_children`, `at_exit`), `visual.rb` (`decode`, `decode_loop`, `stream`), `direct.rb` (`close`, `render_frame`, `stream`) | spec in un processo figlio |

### Controllo della proposta di "Ordine di lavoro"

Cambi proposti all'utente (criterio 2: le issue che toccano lo stesso codice stanno nello stesso lotto):

1. **ICH-225 nel lotto 1.** `ncplane_mergedown` chiama `postpaint` sul piano di destinazione (`render.c:600`), e
   `postpaint_cell` usa `cellcmp_and_dupfar` anche per le colonne di destra di un glifo largo, avanzando `crender`,
   `x` e `prevcell` senza un controllo sulla fine della riga (`render.c:470-485`). Il double free di ICH-449
   (`merge_down` con glifi larghi tagliati dai bordi) è quindi probabilmente un caso di ICH-225. Ipotesi, non
   controllata.
2. **ICH-214 nel lotto 2**, con ICH-215 e ICH-216: tutte e tre toccano `resize*` e `duplicate` di `plane.rb`.
   ICH-230 (`ui/log_view.rb`) resta da sola nel lotto 9.
3. **ICH-464 nel lotto 5**, con ICH-475: tutte e due riguardano un `close` mentre una chiamata C è in corso (gestore
   `trap` o altro thread), e tutte e due hanno una scelta della regola 14 che può dare lo stesso meccanismo (stop
   rimandato fino al ritorno della chiamata).
4. **ICH-474 nel lotto 7**, con ICH-441 e ICH-226: ICH-474 chiede di riusare il thread interno dell'init
   (`context.rb:294`, `direct.rb:224`), che ICH-226 cambia.

## Decisioni iniziali (2026-11-15)

- Lotti: approvati con i 4 cambi sopra (scelta dell'utente). Tabella aggiornata in `RIPRESA.md`.
- Modello dei comandi del workflow: `opus`, come nei lotti della revisione.
- ICH-231 e ICH-457 (funzionalità nuove, `Improvement`): restano nella fase, lotto 13.
- ICH-225 (spike): audit e fix nello stesso lotto dei casi confermati, non solo l'audit.
- `--force` per `git worktree remove`: vale l'approvazione del 2026-11-08 (`memory/correzioni-review.md`), con le
  stesse condizioni (in più solo il submodule `notcurses`, `git status` vuoto).

## Lotto 1 — ICH-449, ICH-450, ICH-448, ICH-225, ICH-481 (PR #22, merge `74deb80`)

### Fix

- **ICH-449 (double free dopo `merge_down` e `Plane#at`).** Causa radice nel wrapper, non in notcurses: `FFI.free`
  (`ffi/functions.rb:641`) è risolta dal gem ffi con `dlsym()` sulla libreria, quindi è sempre la `free` di glibc,
  mentre notcurses alloca con l'allocatore messo da `LD_PRELOAD` (`libc_malloc_debug`, jemalloc, tcmalloc). Bastava
  `Plane#at` ripetuto: `merge_down` e i glifi larghi non c'entravano. `Util.free` libera con `ncpalette_free`, che in
  libnotcurses-core è solo `free(p)` (`notcurses.c:2591-2593`); la usano `take_string`, `Stats.collect`,
  `Plane#as_rgba` e un helper di `menu_spec.rb`. Nessun cambio al layer FFI.
- **ICH-450 (metà orfane dopo i riempimenti).** `keep_glyphs_whole` legge prima della chiamata C i glifi larghi
  interi a cavallo dei lati del rettangolo (per `polyfill` tutti quelli del piano), e in un `ensure` svuota l'altra
  metà di quelli coperti a metà; se la chiamata fallisce cerca anche le metà destre orfane nel rettangolo. Incluso
  `gradient2x1` (scelta dell'utente). `stain` e `restyle` non toccano gli EGC.
- **ICH-448 (stato del controllo dei bordi per piano C).** La cache `cut_glyphs_cols` sta nel `Plane` tracciato del
  piano C (il registro del `Context` ne tiene uno solo); i `Plane` presi in prestito la usano, e senza un `Plane`
  tracciato aperto si controlla sempre. Indirizzi riusati: il registro invalida il vecchio wrapper, quindi niente stato
  vecchio (scartata l'alternativa di una tabella nel `Context` per indirizzo).
- **ICH-225 (spike).** Tre chiamanti di `cellcmp_and_dupfar`: `reader.c:100`, `render.c:453`, `482`; sette punti di
  ingresso del wrapper, una spec ciascuno in `spec/notcurses/wide_glyph_copies_spec.rb` (processo figlio sotto
  `libc_malloc_debug`). Tabella dell'audit e correzione nei commenti della issue su Linear.
- **ICH-481 (nel lotto dopo il round 2, scelta dell'utente).** `ncplane_mergedown` lascia le metà destre con width 0
  (`render.c:393-395`, `471-485`); una scrittura stretta e una larga sulla stessa colonna davano una metà destra
  orfana e corrompevano l'heap. `restore_wide_glyphs!` riscrive quei glifi con `ncplane_putc_yx` e rimette il
  cursore di `dst` (a fine riga riscrive l'ultima cella della riga).

### Decisioni

- Lotti approvati con 4 cambi; modello `opus`; ICH-231 e ICH-457 nella fase; ICH-225 con audit e fix.
- Issue nuove dall'audit, su scelta dell'utente: ICH-481, ICH-482, ICH-483, ICH-484.
- Round 2: con il raise di `f2a09f3` il loop avrebbe dovuto fermarsi ("fix a valanga"); l'utente ha scelto il fix
  tollerante e il round 3. ICH-481 portata nel lotto (regola 16, scelta dell'utente).
- Dopo il round 3, su richiesta dell'utente: il HIGH del cursore corretto senza un nuovo round; issue fuori scope
  ICH-486, ICH-487, ICH-488.
- Compromesso documentato: con l'egcpool pieno e un riempimento con un EGC di più di 4 byte, il wrapper nel dubbio
  svuota le due metà del glifo. Scartato: il costo delle scansioni sui piani presi in prestito e dopo `polyfill`
  (ICH-448 ammette "always scans"). Accettato e scritto nel YARD: `merge_down` legge ogni cella di `dst`.
- Nella PR non si citano gli ID delle issue fuori dal lotto nel corpo; citati in un commento, sono rimasti in Backlog.

### Review (3 round, Fable e GPT)

- Round 1 (`cf381f4`): Fable un HIGH (glifi interi cancellati dopo `merge_down`, metà destre a width 0) e un LOW
  (costo, scartato); GPT un HIGH (riempimento fallito a metà senza pulizia). Corretti in `55204c1`.
- Round 2 (`55204c1`): GPT un HIGH (lettura preventiva fallita con l'egcpool pieno), corretto in `f2a09f3` con un
  raise; Fable sul raise un HIGH (pulizia interrotta nell'`ensure`) e un MEDIUM (piani con bitmap), corretti in
  `cfd1e1f` con `half_at` a tre stati; Fable un HIGH già su `master` (`merge_down` e scritture), corretto in `36f7181`
  come ICH-481.
- Round 3 (`36f7181`): entrambi il cursore di `dst` a fine riga (HIGH, regressione della PR) e l'egcpool pieno in
  `restore_wide_glyphs!` (MEDIUM, ICH-485); Fable un LOW di costo e commenti superati. LOW in `cfd7031`, cursore in
  `262e0f6`, entrambi senza review; PR in draft e poi di nuovo pronta.

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| La suite non terminava in 600 s | blocco della VPS, poi riavviata dall'utente | suite rieseguita: 39 s, verde |
| L'ipotesi su `postpaint_cell` (glifo nell'ultima colonna) non reggeva | `paint` cambia già quel glifo in uno spazio (`render.c:375-379`) | causa cercata con un repro C e la build ASan del submodule (agente) |
| Il primo fix del round 2 ha creato due difetti | il raise girava anche nell'`ensure` e sui piani con bitmap | letture tolleranti a tre stati |
| Primo campione dei cursori: 326 differenze su 1000 | errore del campione (`rng.rand` chiamato due volte) | campione corretto: 0 su 1000 |
| Worktree di review con `.review-tmp/` | file dei reviewer non tracciati | `--force` con la conferma dell'utente (round 1 e 2) |

### Verifica finale

- Branch (`262e0f6`): 1084 esempi, 0 fallimenti in ordine normale e con `rand:1234`; line coverage 98,38 %; RuboCop 0
  offense (100 file); YARD 0 warning, 100 %. CI verde su tutta la matrice e Codecov.
- Ogni spec nuova falliva sul codice prima del suo fix (controllato prima di ogni fix).
- `git diff ad0315b -- lib/notcurses/ffi lib/notcurses/ffi.rb`: vuoto.
- Issue ICH-449, ICH-450, ICH-448, ICH-225 e ICH-481 a Done dopo il merge.
- `master` su `74deb80`: 1084 esempi, 0 fallimenti con i semi 1234, 4242 e 7; RuboCop 0 offense; `gem build`
  riuscito; worktree, branch locale e branch remoto rimossi.

## Dopo il lotto 1: issue nuove nei lotti (2026-11-15)

- L'utente ha scelto di mettere nella fase le 7 issue nate dal lotto 1. Assegnazione (criterio 2, stesso codice):
  ICH-485, ICH-482 e ICH-487 nel lotto 2 (`merge_down` e resize di `plane.rb`); ICH-486 e ICH-488 nel lotto 6 (blit di
  celle, come ICH-223); ICH-484 nel lotto 8 (`Reader`); ICH-483 da sola nel lotto 14 nuovo, perché tocca la Fase 1 e
  serve l'approvazione dell'utente (regola 1). Il lotto di RuboCop diventa il 15.

## Lotto 2 — ICH-485, ICH-215, ICH-216, ICH-482, ICH-487 (PR #23, merge `cb90c4f`)

Lavoro in due sessioni: implementazione e primo review-fix loop il 2026-11-15 (fino a `be426b1`), secondo loop il
2026-11-17 (fino a `0d36e29`). ICH-214 era nel lotto e ne è uscita dopo il primo loop.

### Fix

- **ICH-485 (glifi illeggibili dopo `merge_down`).** Con l'egcpool pieno `ncplane_at_yx_cell` non rilegge i glifi di
  più di 4 byte: `rewrite_unreadable!` li legge con `ncplane_at_yx` (`strdup`, niente pool) e li riscrive con stili,
  colori e cursore; se nemmeno così riesce, svuota le due metà (`097ca23`).
- **ICH-215 (`resize_region` con `keep_x > 0`).** Il ciclo di rilascio del C (`notcurses.c:995-997`) usa l'indice del
  framebuffer nuovo come colonna di quello vecchio. Il wrapper fa il resize in due passi: il primo con `extra` righe
  vuote in alto, il secondo le toglie (`a280dd1`). Poi: il secondo passo si decide dalle condizioni di rifiuto del C
  (`4e10631`); `release_unused!` (prima `release_dropped!`) rilascia gli EGC delle celle scartate (`d27b695`,
  `5bb2a4e`); `logrow` azzerato fra i passi (`1971a3c`); niente secondo passo se il primo non ha cambiato `fb`
  (`c362259`).
- **ICH-216 (`duplicate`).** `ncplane_dup` crea la copia con `flags = 0` e copia solo `halign`: il wrapper scrive
  `fixedbound` e `valign` in `Plane::Internals` (`a93badf`).
- **ICH-482 (egcpool di `dst` in `merge_down`).** `ncplane_mergedown` copia gli EGC di più di 4 byte e libera il
  framebuffer vecchio senza rilasciarli (`render.c:602-603`). Il wrapper legge il framebuffer prima della fusione e
  rilascia le copie vecchie (`f96d28e`); se le copie nuove non entrano nel pool, annulla la fusione e solleva
  `PlaneError` (`11e24c5`). Rinforzi contro i gestori `trap` nel secondo loop (`31de83c`, `fd5c9b2`, `0d36e29`) e
  falso positivo di `lost_egc?` dopo una metà sinistra orfana (`ec82f5a`).
- **ICH-487 (metà orfana di un glifo illeggibile tagliato).** `clear_cut_glyphs!` legge con `ncplane_at_yx` le celle
  che `ncplane_at_yx_cell` non legge (`ce766e7`); salta i piani con un bitmap (campo `sprite`), dove `ncplane_at_yx`
  copierebbe la sequenza dello sprixel, già liberata con Kitty (`6927260`).
- **`Plane::Internals`.** Struct privata con il layout di `struct ncplane` 3.0.17 (`internal.h:76-125`) in
  `plane.rb`, non nel layer FFI; `internals` la restituisce solo con la libreria 3.0.17 e con i campi uguali ai getter
  pubblici.

### Decisioni

- Dell'utente, primo loop: `Plane::Internals` in lettura e scrittura; ICH-215 con il resize in due passi (i callback
  dei figli girano due volte); ICH-485 con la riscrittura del glifo illeggibile.
- Dell'utente, dopo il round 3 del primo loop: ICH-214 fuori dal lotto (`be426b1`) e di nuovo in Backlog. Ruotare il
  framebuffer da Ruby non si rende sicuro: un `trap` o un altro thread può fare un resize fra la copia e la scrittura
  (heap overflow). Serve un lock o codice C, forse un helper approvato nel layer FFI (regola 1).
- Dell'utente, secondo loop: `merge_down` e i gestori `trap` "rinforza e documenta" (un fix completo da Ruby non
  esiste); `logrow = 0` fra i due passi di `resize_region`; un callback che ridimensiona il piano nel primo passo
  resta documentato nello YARD.
- Mie: il secondo loop ha usato il branch reale (`bug/ICH-214-485-215-216-482-487-opus`) anche senza ICH-214 negli
  argomenti; un solo commit per i fix dopo l'ultimo round (`0d36e29`), perché fix e testi toccano le stesse righe.

### Review (2 loop da 3 round, Fable e GPT)

- Primo loop (2026-11-15, round 1-3): SIGSEGV di `half_at` su bitmap Kitty (ICH-487), EGC persi in silenzio con il
  pool pieno (ICH-482), secondo passo deciso da `abs_x` e EGC scartati non rilasciati (ICH-215), più i difetti del
  fix di ICH-214. Round 3: due HIGH, heap overflow in `unscroll!` (ICH-214 tolta) e `release_dropped!` dopo i
  callback (`5bb2a4e`, senza review).
- Secondo loop, round 1 (`be426b1`): HIGH per entrambi, `merge_down` con un `trap` che fa `erase` o `resize` su
  `dst` (SIGSEGV, heap corrotto; `31de83c`); Fable un MEDIUM (`resize_region` perde una riga su un piano che ha fatto
  scroll, `1971a3c`) e un LOW (tabella, `c4d2373`).
- Round 2 (`31de83c`): GPT un HIGH (`release_unused!` teneva il puntatore al pool, `fd5c9b2`); Fable un MEDIUM
  (`lost_egc?` e il residuo di `postpaint_cell`, `ec82f5a`) e tre LOW (`c362259`, `154bbeb`).
- Round 3 (`154bbeb`): GPT approva senza finding; Fable approva con riserve. `Numeric#nonzero?` sotto la guardia di
  ricorsione dava `NameError` con un `trap` che fonde altri piani (MEDIUM) e lasciava una finestra fra due
  `get_uint8` (LOW); YARD che prometteva finestre chiuse e costi non scritti (LOW). Tutti in `0d36e29`, senza review.
  Il controllo scaduto di `undo_merge!` (MEDIUM) è ICH-529.

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| Contesto della sessione del 2026-11-15 pieno | lotto lungo, ICH-214 compresa | review dei commit dopo il round 3 in una sessione nuova |
| Ogni round trovava un'altra finestra dei `trap` | un `trap` gira anche al ritorno dei metodi C e dentro i blocchi | finestre ristrette e limite nello YARD (decisione dell'utente) |
| Una spec dei `trap` passava anche sul codice vecchio | il `trap` mandato dall'hook di `TracePoint` gira fuori dalla guardia di `nonzero?` | la spec controlla la causa: nessuna chiamata a `nonzero?` durante `merge_down` |
| `marked('x')` nella spec arrivava a DEL (127) | carattere di controllo rifiutato da `putstr` | `marked('A')` |
| Merge bloccato dal classificatore dei permessi | regola "Merge Without Review" | merge fatto dall'utente con `gh pr merge 23 --merge` |

### Verifica finale

- Branch (`0d36e29`): 1111 esempi, 0 fallimenti in ordine normale e con i semi 1234, 4242 e 7; line coverage
  98,41 %; RuboCop 0 offense (100 file); YARD 0 warning, 100 %; nessun warning con `ruby -w`. CI verde su tutta la
  matrice e Codecov.
- Ogni spec nuova del secondo loop falliva sul codice prima del suo fix.
- `git diff ad0315b -- lib/notcurses/ffi lib/notcurses/ffi.rb`: vuoto.
- ICH-485, ICH-215, ICH-216, ICH-482 e ICH-487 a Done dopo il merge; ICH-214 riportata in Backlog (Linear l'aveva
  messa In Progress per il nome del branch).
- `master` su `cb90c4f`: 1111 esempi, 0 fallimenti in ordine normale e con i semi 1234, 4242 e 7; RuboCop 0 offense;
  `gem build` riuscito; CI verde; worktree, branch locale e branch remoto rimossi.
- Issue nuove: ICH-489, ICH-490, ICH-493 (primo loop), ICH-495 (`Canceled`, nata dal fix di ICH-214), ICH-529 (round
  3), ICH-530 (difetto già su `master`, aperta con la conferma dell'utente).

## Dopo il lotto 2: issue nuove nei lotti (2026-11-17)

- L'utente ha lasciato la scelta a Claude. Le cinque issue nate dal lotto 2 (ICH-529, ICH-530, ICH-489, ICH-493,
  ICH-490) vanno in un lotto 2b nuovo, prima del lotto 3:
  - criterio 2 e 3: tutte `Bug`, tutte in `lib/notcurses/plane.rb` (`merge_down`, resize, `at`, `contents`), e
    nessun lotto rimasto tocca quel codice;
  - criterio 1: quattro Medium e una Low, come i lotti 3-10; a parità di priorità passano prima perché quattro sono
    crash o heap corrotto (il lotto 3 corregge comportamenti dei segnali) e `plane.rb` è appena stato rivisto;
  - "2b" e non una rinumerazione, per non cambiare i numeri dei lotti 3-15 già citati in `RIPRESA.md` e nei log.
- Ordine nel lotto: priorità, poi codice vicino: ICH-529, ICH-530 (`merge_down`), ICH-489 (resize), ICH-493
  (`at`), ICH-490 (`contents`, Low).

## Lotto 2b — ICH-529, ICH-530, ICH-489, ICH-493, ICH-490 (PR #24, merge `6374e41`)

Lavoro in una sessione il 2026-11-17 (implementazione, review-fix loop di 2 round, fino a `f209900`). Branch
`bug/ICH-529-530-489-493-490-opus`; tutte le modifiche in `lib/notcurses/plane.rb`.

### Fix

- **ICH-529 (`undo_merge!`).** Il controllo di `dst` era scaduto quando il codice scriveva il framebuffer vecchio.
  Il wrapper calcola prima l'offset massimo del pool, poi controlla dimensione, pool e offset prima e dopo
  `release_gclusters!`, subito prima di `write_bytes` (`3df83f8`, `f209900`).
- **ICH-530 (metà sinistra orfana sull'ultima riga di `src`).** `stale_right_half?` riconosce la cella con `gcluster` 0
  e width minore di 2 (`9a4fb40`). La cella dopo la metà orfana diventa la metà destra del glifo: l'utente ha scelto
  (2026-11-17) che `dst` mostri uno spazio e il glifo di `src`; è ICH-532.
- **ICH-489 (cella base dopo un resize che non conserva niente).** `ncplane_resize_internal` scarica il pool
  (`notcurses.c:953-957`), la rotazione fa lo stesso (`fill.c:446`). `keeping_base_cell` sostituisce la base con uno
  spazio durante la chiamata C e la ripristina dopo, solo se la base è ancora la copia temporanea (`03c0177`,
  `f209900`). Usato in `resize_region` (con `keep_rows` 0), `rotate_cw` e `rotate_ccw`.
- **ICH-493 (`Plane#at` su un piano con un bitmap).** Opzione A scelta dall'utente: `PlaneError` su ogni piano con un
  bitmap, sixel compreso (`09014f0`).
- **ICH-490 (`Plane#contents` con l'egcpool pieno).** `unpooled_egc` legge con `ncplane_at_yx` (`strdup`) quando
  `ncplane_at_yx_cell` non copia nel pool; salta i piani con un bitmap (`ab80152`).

### Decisioni

- Dell'utente: ICH-493 con l'opzione A (errore su ogni piano con un bitmap).
- Dell'utente, dopo il loop: rimuovere il worktree di review di Fable con `--force`; controllare che le spec non
  falliscano prima di procedere (1124 esempi, 0 fallimenti).
- Dell'utente, dopo la chiusura: ICH-530 con l'opzione 3 (lo spazio e il glifo di `src` in `dst`), in ICH-532.
- Mie: ICH-531 aperta per il ripristino della base che richiede spazio nel pool; finestra `trap` residua di ICH-529
  documentata nello YARD, non rincorsa.

### Review (2 round, Fable e GPT)

- Round 1: finding su ICH-489 (callback che cambia la base, pool senza spazio, `Interrupt`) e su ICH-529 (secondo
  controllo dopo `release_gclusters!`); corretti in `f209900`, con spec che falliscono sul codice di `ab80152`
  (8 esempi, 5 fallimenti).
- Round 2: solo GPT, perché Fable ha finito il limite d'uso (429, si azzera il 2026-11-20 alle 14:00). Nessun
  finding da correggere nel lotto; aperta ICH-531. Minore non corretto: il giro `base` → `set_base` perde i bit di
  stile non definiti.

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| `FFI = Notcurses::FFI` dentro un lambda: `NameError` | la costante cambia il lookup di `Notcurses::FFI::Platform` | tolta l'assegnazione |
| Repro di ICH-530 bloccata sotto l'heap checker | `abort` con il core dump | `Process.setrlimit(:CORE, 0)` |
| Spec di ICH-530 falliva anche con il fix | la cella base di `with_parent` differiva | `std.create_child` e `ensure` per chiudere i piani |
| Review di Fable del round 2 fallita | limite d'uso | round 2 solo con GPT, dichiarato nel commento della PR |
| Merge bloccato dal classificatore dei permessi | regola "Merge Without Review" | merge fatto dall'utente con `gh pr merge 24 --merge` |

### Verifica finale

- Branch (`f209900`): 1124 esempi, 0 fallimenti in ordine normale e con i semi 1234, 4242 e 7; RuboCop 0 offense
  (100 file); YARD 100 %; nessun warning con `ruby -w`; CI verde su tutta la matrice. Ogni spec nuova falliva sul
  codice prima del fix.
- `master` su `6374e41`: 1124 esempi, 0 fallimenti (4 ordini); line coverage 98,25 %, branch 90,29 %; RuboCop 0
  offense; YARD 100 %; `gem build` riuscito; `git diff ad0315b -- lib/notcurses/ffi lib/notcurses/ffi.rb` vuoto; CI di
  `master` verde.
- ICH-529, ICH-530, ICH-489, ICH-493 e ICH-490 a Done. Issue nuova: ICH-531 (Backlog).

## Lotto 2c — ICH-531, ICH-532 (PR #25, merge `d2c5f7c`)

Lavoro in una sessione il 2026-11-17. Branch `bug/ICH-531-532-opus`; codice in `lib/notcurses/plane.rb` e
`lib/notcurses/context.rb`. Commit: `b2e22ff` (ICH-531), `8c95913` (primo fix di ICH-532), `9d07656` (ICH-531, secondo
parere di design), `13294e1` (nuovo fix di ICH-532 dopo la review), `c73e251` (note della review del round 2).

### Fix

- **ICH-531 (`keeping_base_cell`).** Causa: il wrapper sostituiva la base con `set_base(' ')`, che rilascia l'EGC dal
  pool; il C usava quello spazio (rotazione rifiutata: `rotate_2x1_cw` copia la cella nel pool e non la rilascia, poi
  rifiuta il carattere) e dopo la chiamata `set_base` non trovava posto. Ora lo spazio è una scrittura grezza nel campo
  privato della base, senza rilascio. Dopo la chiamata: framebuffer invariato (il C non ha fatto il resize) → i byte
  originali tornano; framebuffer nuovo (pool svuotato, `notcurses.c:957`) → `ncplane_set_base` con stili e canali
  grezzi. Il trampolino `Plane.ruby_resize_function` esegue i ripristini in corso (`Context#base_restores`) prima del
  callback dell'utente: i callback girano dentro la chiamata C dopo lo svuotamento (`notcurses.c:1006`). Il ripristino
  gira una volta sola (`9d07656`): un callback può impostare una base uguale allo spazio provvisorio. Senza
  `internals` niente workaround; `read_base` rimosso.
- **ICH-532 (`merge_down`).** Primo approccio (`8c95913`): dopo la fusione riscrivere il glifo B letto da `src`
  (`split_orphan!`). La review lo ha bocciato (sotto). Approccio finale (`13294e1`): prima di
  `ncplane_mergedown_simple`, `blank_orphan_lefts!` cambia in `src` ogni metà sinistra orfana seguita da un glifo
  (`gcluster` diverso da 0 e width >= 2, cella dopo con `gcluster` diverso da 0) in uno spazio con gli stessi stili e
  canali, con una scrittura grezza; un `ensure` rimette i byte, dentro il blocco `Thread.handle_interrupt` che c'era
  già. Il C compone lo spazio e B come le altre celle e copia B nel pool di `dst`; se B non entra, `lost_egc?` e
  `undo_merge!` annullano la fusione con `PlaneError`. Anche un B largo ora funziona. `split_orphan!` e `put_styled`
  rimossi; `restore_wide_glyphs!` e `rewrite_unreadable!` tornano come prima.

### Decisioni

- Dell'utente: review solo con GPT, perché Fable ha finito i crediti; ICH-533 aperta e messa nel lotto 8 (stesso
  codice di ICH-217 e ICH-232: `zero_width_egc!`); dopo il round 1 fix diretto con il nuovo approccio e nuova review.
- Mie: criterio 2 di ICH-531 letto come "la base non si perde" (base 6 MB + 2 × 6 MB > 16 MiB: una scrittura del
  callback deve fallire), confermato dal secondo parere di GPT; workaround senza fallback quando mancano i campi
  privati, come gli altri del file; il B che non entra nel pool fa fallire la fusione (comportamento che `merge_down`
  aveva già) invece di sparire.

### Review

- Secondo parere di design su ICH-531 (`gpt-bridge:deep-reasoner`, prima del commit): stesso disegno; ha trovato il
  ripristino che sovrascriveva una base del callback uguale allo spazio provvisorio (corretto in `9d07656`).
- Round 1 (`gpt-bridge:reviewer`, `9d07656`): NON APPROVABILE. HIGH: B perso in silenzio sotto pressione del pool (una
  copia della metà sinistra restava nel pool durante la scrittura di B). MEDIUM: B con i canali grezzi di `src`, non
  composti (`:blend`, `:transparent`, `:highcontrast`). Riprodotti tutti e due; corretti in `13294e1`.
- Round 2 (`13294e1`): APPROVABILE, nessun finding. Note applicate in `c73e251`: la spec dell'`Interrupt` di ICH-489
  colpisce il primo `write_bytes` (la base provvisoria non passa più da `ncplane_set_base`); lo YARD di `merge_down` dà
  il costo della scansione (circa 15 ms invece di 11 su 50x200).

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| `/trinity:workflow:1_create-worktree` non si invoca con il tool Skill | `disable-model-invocation` | comandi del workflow lanciati dall'utente |
| Spec del callback di ICH-531: `ArgumentError` invece di `PlaneError` | `zero_width_egc!` carica l'EGC nel pool pieno | la spec accetta tutte e due; difetto aperto come ICH-533 |
| Suite in background e modifiche a `lib/` | le spec `heap_check` caricano `lib/` dal disco | `lib/` cambiato solo a suite finita |
| Commit separati per issue con un solo file di spec | blocchi di ICH-531 e ICH-532 nello stesso file | `git apply --cached` del solo blocco di ICH-531 |
| `.review-tmp` non è in `.gitignore` | il worktree di review con file non tracciati non si rimuove con la regola del `--force` | il revisore esegue gli script da stdin, senza file |
| Merge bloccato dal classificatore dei permessi | regola "Merge Without Review" | merge fatto dall'utente con `gh pr merge 25 --merge` |

### Verifica finale

- Branch (`c73e251`): 1133 esempi, 0 fallimenti in ordine normale e con i semi 4242 e 7; RuboCop 0 offense (100
  file); YARD 100 %; nessun warning con `ruby -w`; CI verde su tutta la matrice. Ogni spec nuova falliva sul codice
  prima del suo fix.
- `master` su `d2c5f7c`: 1133 esempi, 0 fallimenti (ordine normale e semi 1234, 4242, 7); line coverage 98,11 %, branch
  90,33 %; RuboCop 0 offense; YARD 100 %; `gem build` riuscito; `git diff ad0315b -- lib/notcurses/ffi
  lib/notcurses/ffi.rb` vuoto; CI di `master` verde.
- ICH-531 e ICH-532 a Done. Issue nuova: ICH-533 (Backlog, lotto 8).

## Lotto 3 — ICH-454, ICH-456, ICH-455, poi ICH-536, ICH-537, ICH-538 (PR #26, merge `e15b40a`)

Lavoro in una sessione il 2026-11-17 e 18 (implementazione, review-fix loop di 3 round). Branch
`bug/ICH-454-456-455-opus`, worktree `.claude/worktrees/bug+ICH-454-456-455-opus` ancora presente, con il submodule
`notcurses` inizializzato. Codice in `lib/notcurses/ui/event_loop.rb` e `lib/notcurses/context.rb`. Commit: `19d07e9`
(ICH-456, codice comune), `acc117b` (spec di ICH-454), `87526c4` (spec di ICH-455), `cc73e93`, `a80c4ba`, `cdd74de`
(round 1), `7a5e12a`, `bbad936` (round 2), `82953cb` (dopo il round 3).

### Fix

- **Causa comune.** notcurses 3.0.17 alza SIGINT, SIGSTOP e SIGQUIT per Ctrl+C, Ctrl+Z e Ctrl+\ di kitty e di xterm
  con modifyOtherKeys (`modifiers == NCKEY_MOD_CTRL`) nel suo thread di input, da un flag privato (`ictx->linesigs`)
  che `stty` non cambia, per ogni evtype (pressione, ripetizione, rilascio), e mette anche il tasto in coda
  (`in.c:506-552`). Il flag parte da ISIG all'init (`termdesc.c:1400-1404`). Solo `notcurses_linesigs_disable` ed
  `enable` lo cambiano, e scrivono anche ISIG; con `ttyfd < 0` non fanno niente (`in.c:2840-2918`).
- **Presa in carico (ICH-456, e da lì ICH-454 e ICH-455).** All'avvio `run` chiama `Context#linesigs_disable` e
  rimette ISIG com'era con `Context#isig_enable` (nuovo, `@api private`, solo `tcsetattr`; `ixon!` e `isig_enable`
  usano `tty_flag!`). Il ripristino di ISIG è armato prima del cambio. `line_signal` alza il segnale a ogni pressione
  (`:press` o `:unknown`) dopo aver letto il tasto e scarta ripetizioni e rilasci. Dopo `run` il flag resta spento.
- **Round 1 e 2.** Con `drain_input` `run` non legge i tasti e lascia i segnali a notcurses, come su `master`
  (`a80c4ba`). `line_signal` ricorda il tasto che ha alzato il segnale (`@signal_key`) e scarta la sua ripetizione e il
  suo rilascio anche nel `run` dopo (`7a5e12a`).

### Decisioni

- Dell'utente: opzione B, il flag di notcurses resta spento dopo `run` (con A un rilascio dopo `run` alza ancora
  `Interrupt`: criterio di ICH-456); la prova a vista in Kitty la fa l'utente a mano; review con GPT e con Sonnet effort
  max al posto di Fable; il limite "Ctrl+C non interrompe un handler bloccato e si perde con la coda piena" **non è
  accettato**: PR #26 in draft e ICH-536 per una soluzione con un helper FFI approvato, in una sessione nuova.
- Mie: limiti di notcurses scritti nello YARD di `run` (senza terminale, input e output su due terminali, Ctrl+C
  prima della presa in carico alzato due volte o consegnato con `no_linesigs`, 0x03 nell'istante in cui ISIG è spento);
  commit separati per issue con le versioni intermedie messe nell'indice (`git update-index --cacheinfo`); ICH-537 unisce
  due finding del round 3 sullo stesso codice; gli ID delle issue nuove stanno solo nel commento della PR, non nella
  descrizione (l'automazione di Linear le porterebbe a In Progress).

### Review (3 round, GPT e Sonnet effort max)

- Secondo parere di design prima del codice (`gpt-bridge:deep-reasoner`): opzione B; quattro rischi (niente tty,
  terminali diversi, presa in carico non atomica, ripristino da armare prima del cambio), finiti nel piano.
- Round 1: GPT MEDIUM, con `drain_input` nessuno alzava più il segnale (`a80c4ba`); Sonnet LOW, lo spec `stty -isig`
  passava anche senza il fix (`cc73e93`), e LOW, il doppio segnale prima della presa in carico (`cdd74de`).
- Round 2: GPT HIGH e Sonnet MEDIUM, con kitty il segnale nasce quando il ciclo legge il tasto: un handler, un timer o
  un `post` bloccato non si interrompe più (su `master` notcurses lo alzava subito) e con la coda piena (`BUFSIZ`,
  `in.c:522`) il Ctrl+C si perde: residuo, ICH-536. GPT MEDIUM, la ripetizione di un Ctrl+C tenuto arrivava a `on_key`
  del `run(no_linesigs: true)` dopo (`7a5e12a`). Sonnet LOW, YARD (`bbad936`) e descrizione della PR.
- Round 3: GPT MEDIUM, la pressione di un altro tasto di segnale azzera `@signal_key`, e Sonnet LOW, `@signal_key` è
  per `EventLoop` mentre la coda è per `Context`: ICH-537. Sonnet LOW, con `loglevel: :warning` ogni `run` dopo il
  primo scrive "linedisc signals already disabled" (`in.c:2841`): ICH-538. LOW di testo corretti senza review
  (`82953cb`, descrizione della PR).

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| Gli spec di ICH-456 passavano su `master` | il caso 2 di ICH-454 lasciava spento il flag per il resto dello script | `nc.linesigs_enable` prima delle sessioni di ICH-456 |
| Gli spec unitari di `run` non provano la presa in carico | il contesto di `NcHelpers` ha `drain_input: true` | helper `reading_input` (stub di `drain_input?`, `inputready_fd` su un pipe, `get`) |
| RuboCop `Lint/UselessAssignment` su `linesigs = isig` | non vede la lettura in `ensure` | assegnamento condizionale |
| Output del figlio pty troncato da RSpec | il matcher `include` tronca | riga temporanea `File.write(ENV['KITTY_OUT'], out)`, tolta subito |
| Suite completa nel worktree nuovo | submodule `notcurses` assente | `git submodule update --init --depth 1 notcurses` |
| Il reviewer Sonnet ha scritto `/tmp/ncerr.txt` | prova con `loglevel: :warning` | rimosso dall'utente |

### Stato a fine della prima sessione

- Branch su `82953cb` (solo documentazione dopo `bbad936`): 1138 esempi, 0 fallimenti; RuboCop 0 offense; YARD 100 %;
  layer FFI invariato; line coverage 98,09 % misurata prima della review (`87526c4`). CI verde su `bbad936`; su
  `82953cb` in corso alla chiusura.
- ICH-454, ICH-456, ICH-455 In Progress; PR #26 in draft con il commento della review. Issue nuove in Backlog:
  ICH-536 (High), ICH-537 (Medium), ICH-538 (Low), con relazione `related` verso ICH-456 e ICH-455.
- Prova a vista in Kitty non ancora fatta.

### Seconda sessione: ICH-536, ICH-537, ICH-538 (2026-11-18)

Lavoro sul branch e nel worktree della PR #26 (opzione (a), scelta dell'utente), senza i comandi 1 e 2 del workflow.
Commit: `519c918` (ICH-538), `eb2e126` (ICH-537), `57472d5` (ICH-536); round 1: `9505bdf`, `66a39fb`, `8e3d1b7`,
`edeaaeb`; round 2: `bf9523e`, `1c894a9`, `e3f40bc`, `aa07948`, `92ffe55`; round 3: `e78d5cd`.

#### Fix

- **ICH-538.** `Context#linesigs_flag?` (`@api private`) tiene in Ruby lo stato del flag privato di notcurses: ISIG
  all'init, acceso senza terminale (`termdesc.c:1400-1404`), cambiato solo da `linesigs_disable` ed `enable`. `run`
  chiama `linesigs_disable` solo con il flag acceso; con il flag spento `run(no_linesigs: true)` spegne solo ISIG
  (`Context#isig_disable`).
- **ICH-537.** `Context#held_signal_keys` (`@api private`): una voce per tasto di segnale tenuto premuto, tolta dal
  suo rilascio o da una nuova pressione dello stesso tasto. Vale per ogni `EventLoop` e `App` del contesto. Con kitty,
  se l'utente lascia Ctrl prima di C, ripetizione e rilascio arrivano senza Ctrl e con l'id minuscolo (`1c894a9`).
- **ICH-536, disegno B (scelta dell'utente).** Durante `run` un thread Ruby del contesto (`Notcurses::InputReader`,
  costante privata) attende su `notcurses_inputready_fd` senza il GVL e svuota la coda di notcurses a blocchi di 256
  con `notcurses_getvec` (permesso in parallelo al render, un thread alla volta nello stack di input). Legge solo l'id
  (0,04 µs; un `Input` costa 2,6 µs) e passa a `line_signal` solo C, Z e \ (c e z solo mentre il tasto è tenuto,
  `EventLoop::SignalIds`): il segnale parte alla pressione, anche con il ciclo occupato (Sonnet, round 3: 1 ms con un
  handler che dorme, 101 ms con un blocco di `post` che tiene il GVL). Gli altri eventi restano in un buffer del
  contesto come blocchi grezzi; `Context#get` e `#getvec` ne fanno `Input` quando li prendono. Nessun cambio a
  `lib/notcurses/ffi/`. Il disegno A (trap che scarta i segnali delle ripetizioni) è stato scartato: SIGSTOP non si
  intercetta.
- **Ciclo di vita.** Il filtro nasce prima dell'avvio del thread e l'ensure di `run` lo toglie per primo; la pulizia
  rimanda le eccezioni asincrone (`Thread.handle_interrupt(Object => :never)`) e un secondo Ctrl+C esce come
  `Interrupt` dopo la pulizia. Su Ruby 3.1 e 3.2 l'Interrupt di un segnale non si rimanda: la pulizia, fatta di passi
  idempotenti, ricomincia con `retry` (`aa07948`). Un cancello (`Thread::Queue`) impedisce al thread di leggere prima
  di essere registrato (`bf9523e`). `Context#close` ferma il thread prima di `notcurses_stop`. `Key::EOF` resta nel
  buffer per ogni lettore (`8e3d1b7`); il filtro si legge per evento, così un run annidato filtra il resto del blocco
  (`66a39fb`).

#### Decisioni

- Dell'utente: lavoro sul branch della PR #26; disegno B, senza cambi FFI; testo nuovo di ICH-536 (criterio 2 «more
  than 8192 keys» anche con un handler, un timer o un `post` occupato; vincoli tecnici riscritti; limite del GVL);
  dopo il merge un commento su ICH-536 con i limiti misurati invece di riscrivere il criterio; ICH-539 Low in Backlog
  per le finestre residue su Ruby 3.1 e 3.2.
- Mie: durante `run` per attendere un tasto serve `get` con un timeout, non `inputready_fd` (YARD); scarto registrato:
  gli eventi già filtrati da un `run(no_linesigs: true)` mantengono quel modo nel run successivo (la classificazione
  avviene alla lettura, come ISIG nella line discipline); i 4 finding del round 3 corretti dopo il loop, senza un
  altro round (tutti LOW dopo il triage).

#### Review (3 round, GPT e Sonnet effort max)

- Round 1: un Interrupt subito dopo l'avvio lasciava il thread acceso, eccezioni asincrone a metà pulizia, `close` da
  un trap durante l'attesa del thread chiamava due volte `notcurses_stop` (`9505bdf`); filtro letto per blocco
  (`66a39fb`); EOF consumato da un `get` in un handler (`8e3d1b7`); YARD e limiti delle raffiche (`edeaaeb`).
- CI rossa su Ruby 3.1 e 3.2 dopo il round 1 (`EBADF` nel thread di input): un SIGINT prima della registrazione del
  thread (`bf9523e`).
- Round 2: pulizia di `run` non ripetibile su 3.1 e 3.2, `:immediate` in `halt` lasciava `Thread#kill` interrompere
  la pulizia (regressione), thread di input non fermabile con `Thread#kill` (`aa07948`); Ctrl lasciato prima di C
  (`1c894a9`); YARD (`e3f40bc`, `92ffe55`). Il revisore GPT si è fermato tre volte senza consegnare il report: un
  agente nuovo con l'istruzione esplicita di consegnarlo ha funzionato.
- Round 3 (Sonnet: approvabile con riserve): GPT HIGH (Interrupt prima del `begin` protetto dell'ensure, solo con un
  `TracePoint`) e MEDIUM (`stop` azzerava i pipe prima di chiuderli; anche Sonnet, LOW); Sonnet LOW, `c` e `z` sempre
  nel filtro perdevano il Ctrl+C dopo circa 9000 tasti, e `pending = $!` sbagliato con `run` dentro un `rescue`.
  Tutti LOW dopo il triage, corretti in `e78d5cd` con una spec ciascuno; commento sulla PR.

#### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| Raffiche oltre 8192 eventi perse dal thread | un `Input` per ogni evento | lettura a blocchi con `getvec` e blocchi grezzi nel buffer |
| Spec del reader con struct sporche | il buffer di `getvec` non è azzerato | `s.clear` nella sorgente finta |
| Spec instabili fra EOF e `post` | EOF in coda insieme ai tasti | sorgente finta senza EOF; nel figlio stdin su un pipe aperto |
| Eccezione rimandata in un `:never` annidato che non arrivava al `rescue` di `halt` | rimandata fino al blocco esterno | `halt` restituisce l'eccezione, il chiamante la solleva dopo la pulizia |
| RuboCop: lo spazio di `@stdplane =` perso dagli Edit | allineamento | corretto a mano, due volte |
| Esempio pty di ICH-536 (10000 tasti e poi Ctrl+C) fallito 1 volta su 11 corse della suite | notcurses scarta il tasto con la coda piena (`in.c:523`), con un altro processo che occupava una CPU | limite documentato nello YARD, nel CHANGELOG e su ICH-536 |
| Coverage 98,41 % poi 98,33 % | alcune righe dipendono dai tempi dei thread | stessa corsa su `92ffe55`: le stesse 100 righe non coperte |
| File in `/tmp` del revisore Sonnet del round 2 (`_probe_out*.txt`, `_probe_plain.txt`, `_t22_31..36.txt`) | prove scritte su file | rimossi dall'utente |

#### Stato finale

- PR #26 merge `e15b40a` (fatto dall'utente); CI verde su `e78d5cd` (Ruby 3.1.7, 3.2.11, 3.3.13, 3.4.12, 4.0.9,
  codecov). ICH-454, ICH-456, ICH-455, ICH-536, ICH-537, ICH-538 a Done. Issue nuova: ICH-539 (Low, Backlog,
  `related` verso ICH-536).
- Branch: 1177 esempi, 0 fallimenti (ordine normale e semi 1234, 4242, 7); coverage 98,33 %; RuboCop 0; YARD 100 %;
  layer FFI invariato.
- Prova a vista in Kitty fatta dall'utente dopo il merge, su `master`: `NC_GRAPHICS=1 bundle exec rspec
  spec/graphics/terminal_spec.rb -e 'Ctrl+C con CapsLock'`, 1 esempio, 0 fallimenti.

## Lotto 4 — ICH-463 (PR #27, merge `494ffe0`; issue in Blocked)

Lavoro il 2026-11-18. Branch `bug/ICH-463-opus`, worktree `.claude/worktrees/bug+ICH-463-opus` ancora presente, con il
submodule `notcurses` inizializzato. Un solo commit di documentazione: `fd9441c`. Il comando
`/trinity:workflow:2_work-issue` si è fermato al piano: l'utente ha scelto la correzione upstream.

### Causa (controllata)

- `process_input` restituisce 0 quando il buffer finisce a metà di un carattere UTF-8 di più byte: servono altri
  byte (`in.c:2335-2338`). `process_melange` esce dal ciclo solo con `consumed < 0` (`in.c:2427`): con 0 `bufused` e
  `offset` restano fermi e il thread di input gira per sempre sugli stessi byte. Non legge più, quindi `get` non riceve
  niente; `notcurses_stop` resta in `pthread_join` (`in.c:2662`), perché il ciclo non ha punti di cancellazione.
- Prove: con `loglevel: :warning` circa 475.000 righe `utf8 character (3B) broken across read` in circa 3 s (con il
  log ogni giro ha un punto di cancellazione e `close` ritorna). Da `/proc/<pid>/task`: il thread di input sempre in
  stato R con `wchan` 0, il thread principale in `futex_do_wait`. gdb non si aggancia (`ptrace_scope` 1) e in modo
  batch esce al SIGINT senza backtrace.
- `process_melange` gira quando notcurses non ha un terminale separato (`termfd < 0`): stdin sul terminale, oppure
  rediretto senza `/dev/tty`. Con stdin rediretto e `/dev/tty` notcurses usa `process_bulk`, che esce già su `<= 0`
  (letto nel codice; la prova con `PTY.spawn` si è fermata prima, perché la lettura di `/dev/tty` dava sempre EOF).

| Caso | Prima della correzione | Con la correzione upstream |
| --- | --- | --- |
| Repro della issue (pipe, senza `/dev/tty`), `Context#get` | 2730 su 2731, `close` bloccato (exit 137) | 2731, exit 0 |
| Stesso input, `Direct#get` | 2730 su 2731, `close` bloccato (exit 137) | 2731, exit 0 |
| Stesso input, `EventLoop#run` (`InputReader`) | `on_input` 2730, `run` → `:stop`, `close` bloccato | non provato |
| 2731 × U+65E5 su un pty usato come stdin (un incolla) | 682 caratteri, poi blocco (exit 137) | 2731, exit 0 |

### Decisioni

- Dell'utente: correzione proposta a notcurses upstream, nessun workaround nel wrapper, nessun aggiornamento del
  submodule; ICH-463 resta aperta in attesa di una versione corretta di notcurses (non va a Done al merge della PR
  upstream); fork in `/mnt/data/Sviluppo/Progetti/Fork/20261118_notcurses` (l'utente ha scritto `/VPS_DATA/mnt/data/...`,
  che su questa macchina non esiste); descrizione della PR upstream breve e in inglese, senza la sezione «Merge
  Danger» del modello `trinity:pr`; poi il limite documentato nel wrapper, con il motivo del blocco e le alternative
  nella PR #27.
- Mie: lo stato Blocked del team ICH esiste già («Waiting on something outside this repo…»): niente stato nuovo;
  PR #27 con `Refs ICH-463`; la issue upstream #2947 esisteva già senza PR, quindi la PR upstream la chiude e non è un
  duplicato; il commit upstream usa l'identità git globale, come gli altri fork (l'email non è `noreply`).

### Upstream

- Fork `ichelema/notcurses`, clone con `origin` sul fork e `upstream` su `dankamongmen/notcurses`, branch
  `fix/melange-split-utf8`, commit `9cd90df56` (stile `[input] ... #2947`). PR
  [#2954](https://github.com/dankamongmen/notcurses/pull/2954), aperta il 2026-11-18, chiude la issue #2947; i check
  di upstream aspettano l'approvazione del maintainer.
- Patch: `if(consumed < 0)` → `if(consumed <= 0)` dopo `process_ncinput` (non il ramo delle escape). Test nuovo:
  `input-utf8-split` in `CMakeLists.txt`, 4096 × U+65E5 in un pipe verso `notcurses-input`, `TIMEOUT 60`. doctest non
  va bene: i simboli di `in.c` sono nascosti (`CMAKE_C_VISIBILITY_PRESET hidden`).
- Build: `cmake -DUSE_PANDOC=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo`, doctest 2.4.12 installato nello scratchpad
  (`CMAKE_PREFIX_PATH` e `-isystem` in `CMAKE_CXX_FLAGS`: CMake di notcurses non aggiunge il suo include), GCC 16.2.1.
  `input-utf8-split`: Timeout a 60 s prima, Passed dopo; `ctest` completo 11/11 con `notcurses-tester`.
- Stato di upstream il 2026-11-18: un solo maintainer, merge a ondate (2026-11-10 e 16, prima maggio 2026), ultimo
  rilascio v3.0.17 del 2025-10-28, 33 PR e 305 issue aperte; altre PR sull'input aspettano da 3 a 11 mesi.

### Review

Nessuna: la PR #27 cambia solo la documentazione.

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| Il Ruby di mise carica `/usr/lib/libnotcurses*` anche con `LD_LIBRARY_PATH` | il binario ha un `RPATH` (`/./lib`), che il loader cerca prima di `LD_LIBRARY_PATH` | `unshare --map-root-user --mount` e `mount --bind` delle librerie della build sopra quelle di sistema; inode controllati in `/proc/self/maps` |
| `notcurses-tester` non compila | doctest non installato | doctest in un prefisso nello scratchpad |
| ICH-463 portata in In Progress all'apertura della PR #27 e a Done al merge, anche con `Refs` | automazione GitHub → Linear (il nome del branch contiene l'ID) | rimessa in Blocked a mano tutte e due le volte |
| La skill `trinity:linear` è partita in background senza una richiesta | forked execution | ha fatto solo letture |

### Verifica finale

- Branch su `fd9441c`: 1177 esempi, 0 fallimenti; coverage 98,33 %; RuboCop 0 offense (102 file); YARD 100 %;
  `ruby -w` senza warning. CI della PR #27 verde (Ruby 3.1.7, 3.2.11, 3.3.13, 3.4.12, 4.0.9, codecov).
- `master` su `494ffe0` (merge fatto dall'utente): semi 1234, 4242, 7 con 1177 esempi e 0 fallimenti; RuboCop 0; gem
  costruita; `git diff ad0315b -- lib/notcurses/ffi lib/notcurses/ffi.rb` vuoto; CI verde.
- ICH-463 in Blocked, con il commento della causa e dei test; PR upstream #2954 aperta.
