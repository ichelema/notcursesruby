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
  e width minore di 2 (`9a4fb40`). La cella dopo la metà orfana diventa la metà destra del glifo: scelta aperta
  dell'utente (cella vuota o glifo di `src`).
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
