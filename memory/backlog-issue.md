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
