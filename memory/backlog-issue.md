# Issue in Backlog — log

Decisioni, problemi e soluzioni, lotto per lotto. Ordine dei lotti e regole in `handoff.md`; esito in
`RICONSEGNA.md`, sezione "Issue in Backlog".

## Prima di iniziare (2026-11-15)

- Hindsight, bank `notcursesruby`: il recall risponde (41 memorie, coerenti con `handoff.md`).
- `master` su `06ddb73`, working tree pulito, submodule `notcurses` inizializzato. Il checkout è in
  `/mnt/data/Sviluppo/...`; `/Dati` è un link a `/mnt/data`, quindi i comandi di `handoff.md` valgono.
- Suite completa: 1048 esempi, 0 fallimenti (38,8 s); `bundle exec rubocop`: 99 file, 0 offense.
- Linear: 35 issue aperte, tutte in Backlog, le stesse della tabella di `handoff.md`. ICH-214…ICH-232 hanno già
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

- Lotti: approvati con i 4 cambi sopra (scelta dell'utente). Tabella aggiornata in `handoff.md`.
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
  - "2b" e non una rinumerazione, per non cambiare i numeri dei lotti 3-15 già citati in `handoff.md` e nei log.
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

## Lotto 5 — ICH-475, ICH-464 (PR #28, merge `3d3e0e9`)

Implementazione il 2026-11-18 e 19 in una sessione, semplificazione e review il 2026-11-19 in un'altra. Branch
`bug/ICH-475-464-opus`, worktree `.claude/worktrees/bug+ICH-475-464-opus` ancora presente (lo rimuove l'utente con
`/trinity:workflow:5_remove-worktree bug+ICH-475-464-opus`). ICH-475 e ICH-464 a Done al merge.

### Fix

- `78dfa7a` (ICH-475): `close` rinviato mentre un altro thread è dentro una chiamata C senza GVL; `Notcurses::Guard`
  (`lib/notcurses/guard.rb`, `@api private`) conta le operazioni in corso e tiene la coda delle chiusure fisiche;
  `close` di `Context` e `Direct` in due tempi (`close` + `release_native!`).
- `168f2a0`: motivo nuovo di `ncvisual_simple_streamer` in `spec/coverage_spec.rb` (`Visual#stream` ne fa il lavoro in
  Ruby).
- `fc09a6d` (ICH-464): `Guard.run` in 349 metodi di 16 file (codemod con Prism); controllo statico
  (`spec/notcurses/guard_coverage_spec.rb`) e audit a runtime (`spec/support/guard_audit.rb`).
- `1ffa2d8`: il contatore di `Guard` è un Array (`<<`/`pop`): con un intero e `+= 1` su Ruby 3.1 un aggiornamento si
  perdeva (2 suite su 10).
- `/trinity:workflow:2_work-simplify`: `a149ef9` (`close_thread_children` diventa `close_children(FdPlane)`),
  `659b06e` (`closed?` con `&&`).
- Review round 1: `b32914c` (un `Interrupt` dentro `close` non perde lo stop), `8878982` (`Visual#close` da un gestore
  `trap` durante un'operazione qualsiasi), `50509a5` (limiti nello YARD, ICH-540 e ICH-541, CHANGELOG), `3046124`
  (repro di ICH-475 in 20 processi figli).
- Review round 2: `afb4cee` (lista di richieste al posto del token; `Visual#close` rinvia solo nel thread che ha
  un'operazione in corso; spec con `:c_return`).

### Decisioni

- Dell'utente (regola 14): ICH-475 «rinvio anche per stream» con la variante C (`decode`, `decode_loop` e `from_file`
  occupano solo il visual); ICH-464 «rendere sicuro», non solo documentare; `Context#close` in un callback rinviato
  invece di `ContextError`; l'errore dello stop rinviato esce dall'operazione che lo esegue.
- Dell'utente, review round 1: `Visual#close` rinviato per ogni operazione; il close di piani e widget da un `trap`
  (ICH-540) e il Fiber sospeso (ICH-541) documentati e aperti in Backlog; il repro di ICH-475 ripetuto come spec di
  regressione.
- Dell'utente, review round 2: `Visual#close` rinvia solo se il thread corrente è dentro un'operazione.
- Mie: niente `Thread.handle_interrupt` per il finding 1, perché prima di Ruby 3.4 non rinvia l'`Interrupt` di un
  segnale (provato su 3.1.7, 3.2.11, 3.3.13: SIGINT verso sé stesso e da un altro processo); lo stato diventa
  recuperabile invece. Una lista di richieste (`@claims`, oggetti unici) al posto del token: la lista, non una
  variabile locale, dice all'`ensure` se la chiusura era sua. `Guard.running_here?` legge la pila del thread con
  `caller_locations`: un gestore `trap` vede i frame interrotti (provato su 3.1.7, 3.3.13, 4.0.7) e il percorso caldo
  non costa niente. Le issue nuove con il formato di ICH-539 (Problem, Acceptance criteria, Technical constraints,
  Required tests).

### Review

- Round 1 (`/trinity:workflow:3_independent-review`, eseguita dall'orchestratore Opus; verify di un
  `trinity:reviewer` Sonnet; 4 CONFIRMED e 2 PLAUSIBLE): MEDIUM, un `Interrupt` fra `@open_token.pop` e
  `Guard.defer` faceva perdere lo stop per sempre, anche all'uscita; MEDIUM, `Visual#close` da un `trap` durante
  `Visual#dims` distruggeva il visual prima della chiamata C, contro lo YARD; LOW, close di piani e widget da un `trap`
  (ICH-540); LOW, Enumerator esterno su `Direct#stream` (ICH-541); LOW, contatore intero in `visual_guard`; LOW,
  criterio 3 di ICH-475 coperto solo in modo indiretto.
- Round 2 (stessa forma; 4 CONFIRMED; la review non era indipendente dall'autore dei fix del round 1): MEDIUM, un
  `Interrupt` al ritorno di `Array#pop` in `taken = @native_token.pop` perdeva di nuovo lo stop; LOW, `Visual#close`
  aspettava le operazioni di altri thread; LOW, un visual chiuso mai distrutto dopo un'eccezione al ritorno di `shift`
  o `pop`; LOW, la spec usava solo `TracePoint(:line)`.
- Misure del round 1: repro di ICH-464 200 su 200 con `ClosedError` (anche la baseline 200 su 200: il repro letterale
  è debole, la prova vera è la spec con gli hook); repro di ICH-475 60 su 60 con stato 0 (baseline: 1 SIGSEGV su 60).

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| `Thread.handle_interrupt(Object => :never)` non rinvia il Ctrl+C su Ruby 3.1, 3.2 e 3.3 | l'`Interrupt` del gestore predefinito di SIGINT non passa dalla coda delle interruzioni mascherate prima di 3.4 | ogni passo di `close` lascia uno stato che un `close` ripetuto o l'hook `at_exit` completano |
| Il fix del round 1 perdeva ancora lo stop | Ruby controlla le interruzioni al ritorno dei metodi C: `taken = @native_token.pop` poteva perdere il valore (migliaia di casi con SIGINT reali su 4.0.7 e 3.1.7; mai dopo `<<`, che è l'istruzione `opt_ltlt`) | lista di richieste condivisa; la spec solleva anche a ogni `:c_return` |
| La spec con `TracePoint` falliva in `visual_guard` su punti non reali | con il TracePoint attivo `<<` diventa una chiamata C; l'evento `:line` della prima riga di un `ensure` non è un punto di consegna | in `visual_guard` un oggetto unico aggiunto dentro il `begin`; per quel metodo la spec usa solo `:c_return` |
| Il commit della documentazione del round 1 conteneva la spec sbagliata | gli indici degli hunk cambiano dopo ogni commit | `git reset --soft` del commit locale, prima del push |
| 9 spec di `direct_spec.rb` fallivano nel worktree di review | il submodule `notcurses/data` non è inizializzato nei worktree di review | ignorati: ambiente, non la PR |
| Una prova di `ensure` doppio con `Thread#kill` non terminava su Ruby 3.1.7 e 3.2.11 | il thread non si fermava | fermata; non decideva nessun finding |
| Ruby 3.1.7 senza `rspec` e `ffi` | installazione di mise | `GEM_HOME` nello scratchpad, come scritto in `handoff.md` |

### Verifica finale

- Branch su `afb4cee`: 1209 esempi, 0 fallimenti (ordine normale e semi 1234, 4242, 7); coverage 98,22 %; RuboCop 0
  offense (107 file); YARD 100 %, nessun warning; Ruby 3.1.7: spec del lotto 144 esempi, 0 fallimenti. CI della PR #28
  verde (Ruby 3.1.7, 3.2.11, 3.3.13, 3.4.12, 4.0.9, codecov).
- Punti provati dalla spec delle eccezioni asincrone: 49 per `Context`, 44 per `Direct`, 44 per `Visual`.
- `master` su `3d3e0e9` (merge fatto dall'utente): 1209 esempi, 0 fallimenti, in ordine normale e con i semi 1234,
  4242, 7; coverage 98,22 %; RuboCop 0; gem costruita; YARD senza warning; `ruby -w` senza warning;
  `git diff ad0315b -- lib/notcurses/ffi lib/notcurses/ffi.rb` vuoto; CI di `master` verde.

## Lotto 6 — ICH-458, ICH-486, ICH-222, ICH-223, ICH-488, poi ICH-549..552 (PR #29, merge `0730865`)

Implementazione il 2026-11-19 in una sessione, review e correzioni il 2026-11-20 in un'altra. Branch
`bug/ICH-458-486-222-223-488-opus`, worktree `.claude/worktrees/bug+ICH-458-486-222-223-488-opus`. La PR #29 non
andava mergiata (scelta dell'utente del 2026-11-20) finché ICH-549, ICH-550, ICH-551 e ICH-552, nate dalla review,
non erano fatte sullo stesso branch. Ognuna ha una relazione `blocks` verso la issue di origine. Le 4 issue sono
fatte dal 2026-11-20 (terza sessione, sezione "Terza sessione" qui sotto): manca la review indipendente.

### Fix

- `1aa5d70` (ICH-486): i blit di celle su un piano esistente girano dentro `Plane#keeping_glyphs_whole`
  (`@api private`), che riusa `keep_glyphs_whole` di ICH-450 su tutto il piano.
- `7c9ddcf` (ICH-223): `from_palidx` costruisce i pixel RGBA in Ruby; `rotate` è un porting in Ruby di
  `ncvisual_rotate` con `>=` al posto di `>` (`visual.c:746`).
- `0a8c1b6` e `ad360a4` (ICH-488): `qrcode` dentro `keep_glyphs_whole`; il buffer overflow del C con il cursore fuori
  da (0, 0) è documentato e tracciato in ICH-542 (High, `Refs` nella PR).
- `d1fb09b` (ICH-222): `mute_stdout!` porta il fd 1 su `/dev/null` durante `ncdirect_stop`; la memoria di
  `Direct::Frame` è un won't fix spiegato nello YARD e in un commento sulla issue.
- `43ef5a3` (ICH-458): prima di ogni frame bitmap `stream` fa posto sotto il cursore (VT per riga, poi CUU).
- Review 2026-11-20: `a64cc37` (F1), `57e5668` (F2), `c0da6ac` e `4ee2690` (i LOW delle review mirate).

### Decisioni

- Dell'utente: F7 (`from_palidx` con una voce `Channel.palindex`) solleva `ArgumentError`, non solo documentato; F1 e
  F2 corretti subito, con una review mirata per ciascuno, solo sul commit del fix; F3, F4, F7 e F8 aperti come issue
  (ICH-549..552) e sviluppati in una sessione nuova; la PR #29 resta bloccata fino ad allora; F9 (costo di `rotate`,
  una chiamata C per pixel) è aperto come ICH-554 (Low, Performance, `related` a ICH-223), che non blocca la PR.
- Mie: `RICONSEGNA.md` non si aggiorna nel branch ma su `master` alla chiusura del lotto, come nei lotti precedenti.
  Nella review mirata il changeset è il solo commit del fix, con baseline il suo genitore.

### Review

- Round 1 completo (`/trinity:workflow:3_independent-review`, orchestratore; verify di un `trinity:reviewer`
  Sonnet; 8 CONFIRMED, 1 PLAUSIBLE): BLOCKER F1, `Direct#close` con `output:` e fd 1 su un terminale: segfault in
  `IO#reopen` (Ruby da 3.1 a 4.0), lo stop non parte; HIGH F2, `rotate` perde pixel opachi con bordi trasparenti
  diversi sui lati; MEDIUM F3, ogni blit legge tutto il piano (60x200: 19 ms contro 0,004 ms); MEDIUM F4, un blit
  `:pixel` sopra glifi larghi lascia metà destre orfane; HIGH F5, ICH-542 (esisteva già, fuori dal lotto); LOW F6
  (spec di ICH-222 senza tty), F7, F8 (`qrcode` ripete `keeping_glyphs_whole`), F9.
- Review mirata di `a64cc37` (2 CONFIRMED, LOW): il commento citava solo il terminale, ma il segfault avviene con il
  fd 1 aperto O_RDWR (anche un file `r+`); il messaggio della spec diceva «processo figlio bloccato» quando lo stdout
  non era ripristinato.
- Review mirata di `57e5668` (3 CONFIRMED, LOW): lo YARD diceva che le dimensioni sono quelle del C, ma
  `ncvisual_bounding_box` del C a volte calcola un riquadro più stretto; righe del C troncate; il CHANGELOG riportava
  l'esito dello stato intermedio del branch, non quello rilasciato.
- Le review mirate non erano indipendenti dall'autore del fix (orchestratore); il verify sì.

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| `Direct#close` andava in segfault con lo stdout su un terminale | `IO.for_fd(1).reopen(File::NULL, 'w')` con il fd 1 O_RDWR: Ruby controlla il cambio del modo d'accesso e va in segfault leggendo un path nil (da 3.1.7 a 4.0.7; con un fd in sola scrittura funziona) | `File.open(File::NULL, 'w') { \|null\| stdout.reopen(null) }`; spec con il fd 1 su un pty |
| `rotate` perdeva pixel con bordi asimmetrici | `rotate_bounding_box` ruota il riquadro attorno al suo centro, i pixel attorno al centro dell'immagine (`visual.c:658-705`) | riquadro ruotato in coordinate dell'immagine; prodotti, somme e `round` monotoni: nessun indice fuori |
| La spec di F1 restava nel ciclo d'attesa | il pty scrive `"\r\n"` al posto di `"\n"` (ONLCR) | attesa di `'fine'`, al massimo 5 s |
| Prove nel pty: il figlio restava bloccato dopo la heap corrotta (ICH-542) | dopo l'abort il gestore `[BUG]` di Ruby non esce | ogni prova con `timeout -s KILL 20` |
| 10 spec di `direct_spec.rb` fallivano nel worktree di review | submodule `notcurses/` vuoto nei worktree detached | ignorati: ambiente; la CI copre |
| `require 'benchmark'` falliva su Ruby 4.0.7 | `benchmark` non è più nella libreria standard e non è nel bundle | `Process.clock_gettime` |
| La spec di `qrcode` è sempre saltata in locale e in CI | la build di Arch ha solo lo stub | build 3.0.17 dal submodule con `-DUSE_QRCODEGEN=on` (qrcodegen-cmake 1.8.0) e `LD_LIBRARY_PATH`; l'ultima era nello scratchpad della sessione del 2026-11-19 (`.../597b2d0b-.../scratchpad/ncqr`), che può sparire |

### Bug di notcurses nuovi (da mettere nelle tabelle di `RICONSEGNA.md` alla chiusura del lotto)

- `ncplane_qrcode` con il cursore fuori da (0, 0) scrive fuori dal buffer di pixel (`fill.c:612-616`, ICH-542).
- `rotate_bounding_box` ruota il riquadro attorno al proprio centro, i pixel attorno al centro dell'immagine
  (`visual.c:658-705`): con bordi trasparenti asimmetrici `ncvisual_rotate` perde pixel opachi. Aggirato.
- `ncvisual_bounding_box` (`visual.c:537-628`) a volte calcola un riquadro più stretto di quello vero (due pixel sulla
  diagonale di un 2x2: una colonna). Aggirato: il wrapper calcola il riquadro vero.

### Verifica (branch su `4ee2690`, 2026-11-20)

- 1232 esempi, 0 fallimenti, 1 pending (`qrcode` sulla build con lo stub), solo in ordine normale; RuboCop 0 offense
  (107 file); YARD senza warning, 100 %. CI verde su `a64cc37` e `57e5668`; su `4ee2690` non ancora vista. I semi
  1234, 4242, 7 e la coverage non sono stati rifatti dopo le correzioni della review.

### Terza sessione: ICH-549, ICH-550, ICH-551, ICH-552 (2026-11-20)

Sviluppo dell'orchestratore nel worktree del lotto, con i passi di `2_work-issue` a mano: i command di Trinity
trovano il worktree solo con i 5 ID originali. Un commit per issue, con `Refs`; il corpo della PR #29 ha ora 9 righe
`Fixes`.

#### Fix

- `fbde2d8` (ICH-549): `Plane#keeping_glyphs_whole(top, left, height, width, all: false)` prende il rettangolo del
  blit e lo taglia sul piano. `Visual::Internal.keeping_glyphs_whole` chiede il rettangolo a `ncvisual_geom`, la
  funzione con cui `ncvisual_blit` lo calcola (`visual.c:1155`), e con `y:` o `x:` simbolici ripete
  `visual.c:432-437` (`ncplane_valign(n, y, rpixy / scaley)`, `ncplane_halign(n, x, rpixx / scalex)`). I `blit_*`
  dei buffer creano un ncvisual temporaneo con `ncvisual_from_rgba` solo per la geometria: in 3.0.17 ogni `ncblit_*`
  passa da `ncvisual_from_rgba` e `ncvisual_blit` (`blit.c:1454-1470`). Con `all: true` `keep_glyphs_whole` legge
  ora anche i glifi a cavallo dei lati (`(left - 1)...(left + width)`).
- `6f32e46` (ICH-550): se `ncvisual_geom` risolve il blitter in `NCBLIT_PIXEL`, nessun controllo: come su `master`.
- `e85d79f` (ICH-551): `from_palidx` solleva `ArgumentError` per una voce con `palindex?` vero.
- `4409140` (ICH-552): `qrcode` chiama `keeping_glyphs_whole(0, 0, rows, cols, all: true)`.

#### Decisioni (mie)

- **`:braille` controlla anche l'interno del rettangolo** (`all: true`), contro il testo di ICH-549, che chiede i
  soli lati. `braille_blit` non tocca una cella con soli pixel trasparenti (`blit.c:1203-1206`); `tria_blit_ascii`,
  `tria_blit`, `quadrant_blit` e `hires_blit` la rilasciano con `nccell_release`. Con i soli lati un glifo largo
  dentro il rettangolo, coperto a metà da pixel opachi, resta con una metà orfana (spec nuova, rossa con i soli
  lati). Costo rimasto: un blit `:braille` di tutto un piano 60x200 costa 20 ms (0,19 ms su `master`). L'utente
  ha scelto il 2026-11-20 di aprire una issue: ICH-556 (Backlog, Low, Performance, `related` a ICH-549), che non
  blocca la PR #29.
- Geometria dal C e non ricalcolata in Ruby: `scale_visual` (`:scale`) usa aritmetica `float`, che in Ruby non si
  ripete in modo sicuro.
- ICH-549 prima di ICH-550: nel commit di ICH-549 il blitter `:pixel` tiene il controllo di tutto il piano, così la
  spec di ICH-550 fallisce sul codice precedente al suo fix (regola 11).
- CHANGELOG: nessuna voce nuova. Le voci di ICH-486 e ICH-223, non ancora rilasciate, descrivono il comportamento
  finale e citano ICH-549, ICH-550 e ICH-551. ICH-552 è un refactor senza voce.
- `qrcode`: il C disegna il codice sempre da (0, 0) (`fill.c:625-629`, `vopts` senza `y` e `x`), non dal cursore;
  il cursore serve solo come offset nel buffer (ICH-542). Il rettangolo del controllo è quindi (0, 0), `rows`,
  `cols`.

#### Dati misurati (media di 50 blit, `xterm-256color`, `output: '/dev/null'`)

| Piano | Blit | Prima (dati della issue, `941042a`) | Dopo (`4409140`) | `master` |
| --- | --- | --- | --- | --- |
| 24x80 | `blit_rgba` 1x1 | 3,3 ms | 0,019 ms | 0,005 ms |
| 60x200 | `blit_rgba` 1x1 | 19,1 ms | 0,017 ms | 0,004 ms |
| 60x200 | `Visual#blit` di tutto il piano, `:half` | 19,3 ms | 0,11-0,17 ms | 0,061 ms |
| 100x300 | `blit_rgba` 1x1 | 48,4 ms | 0,019 ms | 0,004 ms |
| 60x200 | `Visual#blit` di tutto il piano, `:braille` | non misurato | 20 ms | 0,19 ms |

Letture di `ncplane_at_yx_cell` per un blit 1x1: 28 su un piano 4x8 e 11940 su un piano 60x200 prima, 1 dopo.

#### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| La spec del rettangolo falliva nel caso `y: :bottom` | errore della spec: `:bottom` disegna sull'ultima riga, il glifo era sulla riga 1 | glifo sull'ultima riga |
| Nello scenario di ICH-550 la riga sotto non si rompeva | una metà destra orfana cancella la cella dopo il glifo scritto (`notcurses.c:1956-1962`): arriva alla riga sotto solo dall'ultima colonna, e lì `clear_cut_glyphs!` la ripara già al resize | la spec controlla le metà della riga 0 e una scrittura larga in colonna 2, che prima cancellava anche la cella 4 |
| 11 fallimenti di `visual_spec.rb` sulla build con qrcodegen | la build nello scratchpad ha `USE_MULTIMEDIA=none`; gli stessi 11 su `master` | ignorati: ambiente |
| Seme 4242: 1 fallimento in `ui_pty_spec.rb:786` (`coda piena: stop 4.0 s`) | perdita rara del Ctrl+C con la coda di input piena sotto carico (nota di ICH-536) | 2 ripetizioni con lo stesso seme: 0 fallimenti |

#### Verifica (branch su `4409140`, 2026-11-20)

- 1237 esempi, 0 fallimenti, 1 pending, in ordine normale e con i semi 1234, 4242 (vedi sopra) e 7; coverage 98,15 %
  di righe; RuboCop 0 offense (107 file); YARD senza warning, 100 %; `ruby -w` pulito; gem costruita;
  `git diff ad0315b -- lib/notcurses/ffi lib/notcurses/ffi.rb` vuoto. CI della PR #29 verde su `4409140`, tutta la
  matrice (da Ruby 3.1.7 a 4.0.9) e Codecov.
- Build con qrcodegen (`.../597b2d0b-c353-44ad-8f58-de12afe02961/scratchpad/ncqr`, ancora presente): le 2 spec di
  `qrcode` passano, quella di ICH-488 gira.
- Review indipendente non ancora fatta: `/trinity:workflow:3_independent-review ICH-458 ICH-486 ICH-222 ICH-223
  ICH-488 opus`.

### Quarta parte: review dell'orchestratore e review-fix loop con GPT (2026-11-20)

- Review dell'orchestratore (`/trinity:workflow:3_independent-review`, verify di un `trinity:reviewer` Sonnet): 7
  candidati, 3 CONFIRMED (spec dell'allineamento orizzontale debole, riferimento a `visual.c` sbagliato, `mute_stdout!`
  con `$stdout` chiuso), 2 PLAUSIBLE, 2 REFUTED (il controllo dell'interno per `:braille` serve; gli altri blitter di
  celle riscrivono o rilasciano ogni cella). Il costo dei blit `:braille` è diventato ICH-556 (scelta dell'utente).
- `/trinity:workflow:4_review-fix-loop`, 3 round, solo `gpt-bridge:reviewer`: il `trinity:reviewer` Sonnet è fallito
  per credito esaurito (billing_error) e l'utente ha scelto di proseguire con GPT. Il round 2 si è fermato due volte
  per `usage_limit_reached` del piano ChatGPT (finestra di 5 ore): ripreso dopo circa 50 minuti con un timer.
  - Round 1 (11 finding): corretti in `f0c55f5`..`d33421f` i casi limite dello stdout in `Direct#close` (`$stdout`
    chiuso o senza `flush`, close concorrente che perdeva il claim, fd 1 riusato da `fopen`, `FD_CLOEXEC`),
    i movimenti falliti di `stream`, la prova di qrcodegen dal C, la spec dell'allineamento, lo YARD di `rotate`.
    Issue: ICH-560 (buffer stdio della libc: serve `fflush`, il layer FFI non lo ha; l'utente ha rifiutato la
    domanda sul layer FFI e ha detto di continuare: nessun cambio della Fase 1), ICH-561, ICH-562. Scartato:
    `Visual.blit_palindex` (non esiste).
  - Round 2 (9 finding): corretti in `dc4453f`..`3df01a7` il `Thread#raise` fra il ripristino dello stdout e
    `mark_closed!` (regressione del fix del round 1), la risalita fallita di `stream` con `:pixel`, `rotate`
    interrotto, la spec del terminale foot (`:quad`, `:sextant`, `:octant` veri), il controllo del fd 1 con `fstat`.
    Documentati come limiti: processo figlio creato durante lo stop, fd 1 non spostabile, frame non liberato dopo un
    movimento fallito. Issue: ICH-567.
  - Round 3 (4 finding): LOW corretto senza review (`361d90e`, YARD di `rotate`); issue ICH-568 e ICH-569; HIGH:
    `Direct#stop` con il fd 1 in sola lettura va in SIGSEGV. PR in draft.
- HIGH corretto su richiesta dell'utente in `7ae8438`: `mute_stdout!` non sposta un fd 1 in sola lettura (`Fcntl`).
  Review mirata di GPT: approvabile con riserve; il LOW (con `vt52` non c'è un reset e `close` riesce) in `4f6af76`.

#### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| La spec del fd 1 chiuso non riproduceva F5 | con il fd 1 chiuso all'exec Ruby lo prende per una pipe interna; `STDOUT.close` non chiude i fd da 0 a 2 | nel figlio `close(1)` della libc via FFI |
| `Direct#stop` in SIGSEGV con il fd 1 `O_RDONLY` | `IO#reopen` fra modi d'accesso diversi va in segfault anche da un IO (Ruby 4.0.7) | non spostare un fd 1 in sola lettura |
| Commit spezzati per fix con un ciclo `for f in $list` | zsh non divide le parole di una variabile; la sintassi `${(@f)...}` la blocca il controllo di sicurezza | lista dei file scritta per esteso a ogni commit |
| `rm -rf` in un comando | errore mio: un hook mette in coda ogni `rm` | nessun `rm`; cartelle nuove nello scratchpad |
| GPT `usage_limit_reached` | limite del piano ChatGPT, finestra di 5 ore | timer in background fino a `resets_at`, poi un reviewer nuovo |

#### Verifica finale (`master` su `0730865`, 2026-11-20)

- 1248 esempi, 0 fallimenti, 1 pending (`qrcode` sullo stub), in ordine normale e con i semi 1234, 4242 e 7; coverage
  98,17 % di righe; RuboCop 0 offense (107 file); YARD senza warning, 100 %; `ruby -w` pulito; gem costruita;
  `git diff ad0315b -- lib/notcurses/ffi lib/notcurses/ffi.rb` vuoto. CI verde sulla PR e su `master`.
- Linear: le 9 issue del lotto a Done; ICH-542 riportata da In Progress a Backlog (automazione). Worktree e branch,
  anche remoto, rimossi.

## Lotto 7 — ICH-569, ICH-568, ICH-226, ICH-474, ICH-441, ICH-539 (PR #30, merge `e6b51e0`)

Due sessioni, il 2026-11-20 e il 2026-11-21. Branch `bug/ICH-441-226-474-539-568-569-opus`, worktree
`.claude/worktrees/bug+ICH-441-226-474-539-568-569-opus`. ICH-568 e ICH-569 aggiunte dall'utente all'inizio del lotto.

### Fix

- `2c9dabd` (ICH-569): in `Visual.blit_buffer` la creazione del `ncvisual` temporaneo è dentro
  `Thread.handle_interrupt(Object => :never)` e dentro il `begin` dell'`ensure` che lo distrugge.
- `6052c6e` (ICH-568): ripristino dello stdout, `TERM`, registro e `fclose` del rollback di `Direct.new` in un solo
  blocco protetto, come `2cbeb95` in `Direct#close`. Superato da `996e65a`.
- `e770f89` (ICH-441): `DaemonGuard` prepended su `Process.singleton_class`: `Process.daemon` solleva `ContextError`
  o `DirectError` con un contesto aperto di questo processo.
- `a47a39e` (ICH-539): solo documentazione (YARD di `run`, `Context#close`, `InputReader#halt`; CHANGELOG).
- `996e65a` (ICH-226): `Util.init_thread`. Il thread di init nasce prima di `acquire_context`, aspetta su una Queue
  `go` ed esegue il rollback se il chiamante non adotta il puntatore; il chiamante scrive la decisione come prima
  istruzione dell'`ensure` (`go << adopted`), poi `init&.join unless adopted`. `report_on_exception = false`; il
  thread rimanda le interruzioni per tutta la vita.
- `c08d17a` (ICH-474): `Util.create_resource` (chiamata C e incapsulamento dentro `:never`, poi
  `sleep 0 if Thread.pending_interrupt?` come punto di consegna per il thread di `FdPlane` in `:on_blocking`) in
  `Visual.from_file`, `Direct#load_image`, `Direct::Image#initialize`, `Direct#render_frame`.
- Simplify: `b8a504b`, `d799c74` (`NcHelpers.raise_at_c_return`). Verify: `065a15f` (ricetta
  `.claude/skills/verify/SKILL.md`).
- Review: `57c34b5` (`@pid` prima di `acquire_context`: la guardia di `Process.daemon` scatta anche durante l'init),
  `df873df` (`open_output` dentro `:never`), `725bc44` (finestra di un'istruzione dopo la consegna, nello YARD),
  `1125323` (`ensure` nell'`undo` di `Context`), `b45fc80` (spec di `render_frame`), `daf8f8d` (spec di `TERM`),
  `8a34478` (YARD di `new`).

### Decisioni

- Dell'utente: ICH-441 con l'errore prima del fork, non lo stop prima del fork (uno stop rinviato non partirebbe
  mai, perché `daemon(3)` chiama `_exit`). ICH-539 chiusa con la sola documentazione. ICH-576 e ICH-577 aperte in
  Backlog. Review `soft` (Sonnet) e review mirata dei due commit sull'init.
- Mie: design di ICH-226 e ICH-474 confrontato fra `trinity:deep-reasoner` e `gpt-bridge:deep-reasoner`; scelto il
  prototipo del primo (registro e `open_output` nel chiamante, maschera `:never` per tutta la vita del thread), già
  provato con uno sweep (0 difetti su 209 punti contro 10 prima). Per ICH-474 scartato il thread interno: il Ctrl-C
  interromperebbe l'attesa del chiamante, non `open()`. Per il finding #3 della review `@pid` assegnato prima del
  registro invece di `pid.nil?` (che solleverebbe a torto in un figlio di `fork` creato durante l'init del padre).

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| Le finestre di ICH-539 esistono anche su Ruby 3.3 | `handle_interrupt(:never)` rinvia SIGINT solo da Ruby 3.4 (misurato su 3.1.7, 3.2.11, 3.3.13, 3.4.12, 4.0.7) | testi corretti in "3.1, 3.2 e 3.3" |
| Nel worktree il submodule `notcurses/` non si clona dalla rete | rete | `git clone --shared --no-checkout <checkout principale>/notcurses notcurses` e checkout di `b26048e` |
| Spec con `TracePoint` in pausa: il secondo `Thread#raise` arrivava al posto sbagliato | un `Thread#raise` non mascherato interrompe subito `resume.pop`, e il `resume << true` dopo resta in coda | due `paused.pop` separati, un solo `resume` |
| Una spec sulla lib vecchia passava | rspec mette `lib/` del worktree in testa al load path | script a parte con `ruby -I<lib di git archive>` |
| `Queue#pop` nel `TracePoint` | metodo C fino a Ruby 3.x, metodo Ruby da 4.0 | evento scelto con `source_location` |
| Con il vecchio `undo` la spec di `Direct` si bloccava invece di fallire | l'helper aspettava per sempre una pausa che non arrivava | `NcHelpers.raise_at_c_return` segnala la fine del blocco |
| tmux non risponde alle query di notcurses; `kill -INT` ignorato | bash avvia i job con `&` con SIGINT ignorato | terminale finto su pty, `set -m` (ricetta di verify) |
| Liste di file in una variabile in zsh | zsh non divide le parole | file scritti per esteso |
| Un `rm` nel comando | un hook mette in coda ogni `rm` | nessun `rm` |
| Il `cd` nello scratchpad ha riportato la sessione nel checkout principale | il `cd` fuori dal worktree | `EnterWorktree` di nuovo |

### Verifica finale

- `master` su `e6b51e0`, 2026-11-21: 1263 esempi, 0 fallimenti, 1 pending (`qrcode` sullo stub), in ordine definito e
  con i semi 1234, 4242 e 7; coverage 98,17 % di righe; RuboCop 0 offense; YARD senza warning, 100 %; `ruby -w`
  pulito; gem costruita; `git diff ad0315b -- lib/notcurses/ffi lib/notcurses/ffi.rb` vuoto. CI verde sulla PR e su
  `master`. Su Ruby 3.1.7 le spec di init (`context_spec`, `direct_spec`, `pty_spec`): 146 esempi, 0 fallimenti.
- La prima corsa su `master` si è bloccata in `spec/notcurses/ui/event_loop_spec.rb:716` (lotto 3), con un `F`
  iniziale in `spec/ci_workflow_spec.rb:8` di cui rspec, fermato, non ha stampato il messaggio. Non riprodotto:
  l'esempio passa da solo 5 volte su 5, la spec della CI passa da sola, e le quattro corse dopo passano. Lo script di
  verifica ora ha `timeout -s KILL 600` per suite.
- Linear: le 6 issue del lotto a Done; ICH-576 e ICH-577 in Backlog. Worktree e branch, anche remoto, rimossi.

## Lotto 8 — ICH-218, ICH-484 (PR #31, merge `ee509e1`)

Una sessione, il 2026-11-21. Branch `bug/ICH-218-484-opus`, worktree `.claude/worktrees/bug+ICH-218-484-opus`. Il
lotto 8 della tabella aveva 5 issue: l'utente l'ha diviso in due per tenere piccolo il contesto di ogni sessione
(lotto 8 `Reader`: ICH-218, ICH-484; lotto 8b grapheme: ICH-217, ICH-232, ICH-533). ICH-576 e ICH-577 sono passate
al lotto 8c.

### Fix

- `298f0fc` (ICH-218): dopo la chiamata C, `Reader#offer_input` svuota la cella (y, 0) nella copia nascosta e nella
  vista con `ncplane_putc_yx` di una cella vuota (una colonna: passa il controllo che fa fallire `""`,
  `notcurses.c:1883`; `ncplane_put` toglie anche le due metà di un glifo largo), solo dove il C ha provato e
  fallito: Backspace dalla colonna 1, Ctrl+U oltre la colonna 0, Ctrl+W arrivato alla colonna 0 senza un
  separatore (categoria Unicode Z, come `iswordbreak`, letto dalla copia nascosta). La copia nascosta viene dal
  campo `textarea` di `struct ncreader` (`Reader::Internals`, privata, solo con la 3.0.17 e se `ncp` coincide con
  `ncreader_plane` e le dimensioni con la vista). Cursore: `Context#cursor_enable` ricorda la posizione;
  `Context#restore_cursor!` (`@api private`) rimette lo stato dell'ultima chiamata dopo ogni ridisegno di un reader
  con `cursor: false` (helper privato `redraw` con `ensure`); con `cursor: true` il reader mostra il cursore nel
  campo. Criterio del cursore aggiornato su Linear con la scelta dell'utente.
- `afc57ec` (ICH-484): durante Backspace, Ctrl+U e Ctrl+W ogni cella della copia nascosta ha il bit di stile
  `0x8000` (`RECOPY_STYLE`, che notcurses 3.0.17 non usa), messo con `ncplane_format`; il C cancella con stile 0,
  quindi ogni ridisegno copia ogni cella cambiata con la sua width; un `ensure` rimette lo stile a 0 nei due piani.
- Simplify: `9fbd5c2` (`text = deletion && text_area(ptr)` prima del ramo). Verify: `9af985b` (ricetta con `ncvt`).

### Decisioni

- Dell'utente: lotto 8 diviso in due (8 e 8b), ICH-576 e ICH-577 nel lotto 8c; criterio del cursore di ICH-218 solo
  con `cursor: false` (con `cursor: true` il reader resta responsabile del cursore, come vuole notcurses); verify con
  un terminale headless in C su libghostty-vt 1.0.1 (`ncvt`) invece di pyghostty, poi rimosso; ricetta e sorgenti di
  `ncvt` nel repository; il FAIL del verify diventa una issue nuova (ICH-580); merge fatto dall'orchestratore senza
  review indipendente, su autorizzazione dell'utente.
- Mie: colonna 0 corretta dopo la chiamata C (prima della chiamata Ctrl+W non si può decidere senza rifare il ciclo
  del C); risultato del C ignorato nel ripristino del cursore, come fa il ridisegno; con `cursor: false` il Backspace
  a inizio riga non sposta più il cursore del terminale (la spec di `reader_spec.rb` passa a `cursor: true`).

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| Primo fix di ICH-484 (stile sulla vista) e spec di A4-01 rosse | Ctrl+U e Ctrl+W ridisegnano più volte: lo stile sulla vista vale solo per il primo ridisegno, poi una metà destra cancellata nella copia nascosta torna uguale a quella della vista | stile sulla copia nascosta, che il C cancella con stile 0 |
| Spec del cursore rosse in ordine casuale | il contesto delle spec è dell'intero file (`before(:all)`) e uno stato del cursore resta da un altro esempio | stato noto all'inizio, reader con `cursor: true` alla fine per uno stato sconosciuto |
| `guard_coverage_spec` rossa | `offer_input` e `write` iniziavano con `redraw`, non con `Guard.run` | `Guard.run` fuori da `redraw` |
| Spec delle immagini rosse nel worktree | submodule `notcurses` non inizializzato (`notcurses/data`) | `git submodule update --init --depth 1 notcurses` |
| Spec del glifo largo: `"漢漢"` al posto di `"漢漢漢"` | dopo il Backspace dalla colonna 2 il C lascia il cursore in colonna 1 | Ctrl+A prima della scrittura |
| `sudo -n pacman` fallisce | nessuna credenziale in cache | `sudo pacman` senza `-n`, su richiesta dell'utente |
| Verify: il cursore con `cursor: true` sembrava spento | lo snapshot era preso dopo la chiusura del reader, che spegne il cursore | snapshot a reader aperto |

### Verify (`ncvt`, 2026-11-21): FAIL su un bordo

- Passano: colonna 0 (Backspace, anche con il cursore a metà di un glifo largo e sulla seconda riga; Ctrl+U; Ctrl+W,
  che lascia uno spazio in colonna 0), metà destre di ICH-484 lette con `Plane#at`, cursore nascosto con
  `cursor: false`, rimesso in (5, 10) dopo `cursor_enable(y: 10, x: 5)`, mostrato nel campo con `cursor: true`.
- FAIL: dopo un reader con `cursor: true`, che segna lo stato come sconosciuto, `restore_cursor!` non fa nulla e i
  reader con `cursor: false` lasciano acceso il cursore anche se l'ultima chiamata è stata `cursor_disable`
  (ICH-580).
- Comportamento del C fuori scope: un Backspace dopo un glifo largo lo cancella intero ma sposta il cursore di una
  sola colonna. Il 2026-11-21, dopo il merge, l'utente ha scelto di aprire una issue: ICH-581 (Low, Backlog,
  `related` a ICH-218). Misura su `master` `cb1a15b`: `"a漢"`, Backspace, `"c"` danno le celle `a`, vuota, `c` e
  `contents == "ac"`; causa in `do_backspace` (`reader.c:252-266`).
- Scelta dell'utente del 2026-11-21, dopo il merge: ICH-580 nel lotto 8c, con ICH-576 e ICH-577 (stesso file
  `context.rb`).

### Verifica finale

- `master` su `ee509e1`, 2026-11-21: 1271 esempi, 0 fallimenti, 1 pending (`qrcode` sullo stub), in ordine definito e
  con i semi 1234, 4242 e 7; coverage 98,18 % di righe; RuboCop 0 offense; YARD senza warning, 100 %; `ruby -w`
  pulito; gem costruita; `git diff ad0315b -- lib/notcurses/ffi lib/notcurses/ffi.rb` vuoto. CI della PR verde su
  tutta la matrice. Su Ruby 3.1.7 (branch) `reader_spec`, `context_spec`, `wide_glyph_copies_spec` e `pty_spec`: 116
  esempi, 0 fallimenti.
- CI di `master` dopo il merge: il job Ruby 3.4.12 è fallito in `spec/integration/ui_pty_spec.rb:786` (ICH-536,
  lotto 3: "coda piena: stop 4.0 s" invece di "coda piena: interrupt", il Ctrl+C perso con la coda di input piena,
  instabilità già nota sotto carico), codice non toccato dal lotto; rilanciato il job, verde al tentativo 2 su
  tutta la matrice (run `44874487684`).
- Linear: ICH-218 e ICH-484 a Done; ICH-580 in Backlog. Worktree e branch non rimossi: `5_remove-worktree` si avvia
  solo a mano (passo per l'utente, scritto in `handoff.md`). Rimossi il 2026-11-21 con
  `/trinity:workflow:5_remove-worktree` (`--force` per il submodule `notcurses`), anche il branch remoto.

## Lotto 8b — ICH-533, ICH-217, ICH-232 (PR #32, merge `67164c7`)

Dal 2026-11-21 al 2026-11-22. Branch `bug/ICH-217-232-533-opus`, worktree `.claude/worktrees/bug+ICH-217-232-533-opus`.

### Fix

- `592846e` (ICH-533): con l'egcpool pieno `putstr`, `putegc` e `puttext` sollevano `PlaneError` che nomina il pool;
  i messaggi mostrano solo l'inizio e i byte di un EGC lungo (`Util.egc_label`).
- `7db4d10` (ICH-217): `Cell.split_error` (`@api private`) divide l'EGC con `nccell_load` e scrive i pezzi e che cosa
  usare (`putstr` per bandiere e coniugati, la forma NFC per gli hangul a jamo); lo usano `Cell#load_into`,
  `single_egc!` (`putegc`, `gradient`) e `set_base`, che prima teneva in silenzio il primo pezzo. `Cell.new` non cambia.
- `7f78ca9` (ICH-232): `Plane#check_text!` (`@api private`, approvato dall'utente) e `Text.check!(text, name, plane)`:
  il piano del widget nei setter, quello del contenitore o lo stdplane dell'App nei costruttori (`Text.host`).
- Simplify: `dcdf76d` (filtro `GRAPHEME_JOINERS` prima del controllo per grapheme), `664cf59` (piano di `Dialog`
  cercato una volta).
- Verify: `2e916f9` (per le bandiere il messaggio avvisa che il terminale le disegna più larghe, invece di consigliare
  `putstr`).
- Review: `d847446` (il controllo non decide più sullo spazio nel pool: lo decide il C, che prima libera le celle che
  sovrascrive; i pezzi larghi 0 si caricano su un piano temporaneo 1x1 con il pool vuoto; `egcpool_hint` nomina l'EGC
  dove il C si ferma), `85f4d74` (review mirata: ogni EGC di più di 4 byte ha una chiamata C sua e `with_glyph_kept`
  rimette il glifo di arrivo e il cursore se la scrittura fallisce; `put_text` ripiega su "?" anche per
  `PlaneError`), `0e0cf11` (spec del coniugato solo quando Ruby lo legge come un grapheme).

### Decisioni

- Dell'utente: cambio dell'API della Fase 2 (`Plane#check_text!`); lettura di ICH-217 per le scritture con `Cell`
  (`putstr` e `Cell.new` restano come sono); ICH-582 (scritture con `Cell` e pool pieno) e ICH-586 (larghezza delle
  bandiere) come issue nuove; per il finding della review mirata, rimettere le celle invece di cambiare il criterio di
  ICH-533; proseguire senza CI mentre `archive.archlinux.org` era giù; merge fatto dall'utente.
- Mie: un solo meccanismo per i tre finding della prima review (lo spazio lo decide il C) invece di tre toppe;
  `GRAPHEME_JOINERS` tolto con quel fix e rimesso nella review mirata, come filtro per la divisione in chiamate C.

### Review

- Review `soft` Sonnet su `2e916f9`: APPROVABILE CON RISERVE, 3 finding (MEDIUM: `PlaneError` falso quando un EGC
  lungo sovrascrive un EGC lungo, regressione rispetto a `master`; LOW: più EGC lunghi in un testo, messaggio senza il
  pool; LOW: `PlaneError` dei widget non documentato), corretti in `d847446`.
- Review mirata `soft` Sonnet su `d847446`: NON APPROVABILE, 2 finding (MEDIUM: con il pool pieno la scrittura
  fallita svuota la cella di arrivo; LOW: `LogView` solleva `PlaneError`), corretti in `85f4d74`.

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| Verify: FAIL sul consiglio di `putstr` per le bandiere | notcurses conta 2 colonne, Ghostty ne disegna 4: il testo dopo si sposta | messaggio cambiato (`2e916f9`), ICH-586 |
| Il controllo nel pool rifiutava sovrascritture che il C accetta | la prova carica l'EGC su una cella nuova, il C rilascia prima la cella di arrivo | lo spazio lo decide il C (`d847446`) |
| Con il pool pieno una scrittura fallita cambia il piano | `ncplane_put` svuota il glifo di arrivo prima di `egcpool_stash` (`notcurses.c:1911-1950`) | `with_glyph_kept` (`85f4d74`) |
| CI rossa in 30 secondi dal 2026-11-21 22:58 | `archive.archlinux.org` non rispondeva (pacman, snapshot 2026/10/26) | attesa; la CI è ripartita da sola il 2026-11-22 |
| CI rossa su Ruby 3.1-3.4, 3 spec di ICH-217 | prima di Unicode 15.1 (regola GB9c) anche Ruby divide "क्ष" | spec condizionate (`0e0cf11`); provate con Ruby 3.1.7 nello scratchpad |
| Suite fermata dal sistema; poi timeout in `ui_pty_spec.rb:732` | memoria quasi esaurita (350 MiB liberi) | memoria liberata dall'utente; la spec passa da sola e il seme al secondo giro |
| `rm` nei comandi messo in coda dal guardiano | regola dell'ambiente | comandi senza `rm`, o conferma dell'utente |

### Verifica finale

- `master` su `67164c7`, 2026-11-22: 1288 esempi, 0 fallimenti, 1 pending (`qrcode` sullo stub), con i semi 1234, 4242
  e 7 e in ordine definito; coverage 98,19 % di righe (6567 / 6688); RuboCop 0 offense; YARD senza warning, 100 %;
  `ruby -w` pulito; gem costruita; `git diff ad0315b -- lib/notcurses/ffi lib/notcurses/ffi.rb` vuoto. CI della PR
  (`0e0cf11`) e di `master` (run `45043002864`) verdi su tutta la matrice. Su Ruby 3.1.7 (branch) le spec del lotto
  in `cell_spec`, `plane_spec` e `ui/`: 48 esempi, 0 fallimenti.
- La prima corsa della coverage su `master` si è bloccata dopo circa 2 minuti e il `timeout` di 600 s l'ha fermata
  (exit 137); non si sa quale spec, perché l'output era `progress`. La seconda corsa, con `--format documentation` in un
  file, è passata in 3 minuti e 38 secondi. Come il blocco del lotto 7 in `event_loop_spec.rb:716`: non riprodotto.
- Linear: ICH-533, ICH-217 e ICH-232 a Done; ICH-582 e ICH-586 in Backlog. Worktree e branch da rimuovere con
  `/trinity:workflow:5_remove-worktree bug+ICH-217-232-533-opus` (si avvia solo a mano). Rimossi il 2026-11-22,
  anche il branch remoto.
