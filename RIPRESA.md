# RIPRESA — prompt per la prossima sessione

> Avvio: incolla questo file nella nuova sessione di Claude Code, oppure scrivi «Leggi RIPRESA.md ed esegui il
> prompt». Scritto il 2026-11-15 su Linux, dopo la chiusura della Fase 5 (`ad0315b`). Il lavoro da fare è la
> **fase delle issue in Backlog** (scelta dell'utente del 2026-11-15): le 35 issue aperte del progetto, a lotti, con
> il workflow di Trinity, come le "Correzioni della revisione del 2026-11-06". Il prompt della Fase 5 resta in
> `git show ad0315b:RIPRESA.md`; quello dei lotti della revisione in `git show 8a4b5f7:RIPRESA.md`.

## Stato e prossimo step (aggiornato il 2026-11-17, dopo il lotto 2b)

- Lotto 1 fatto: PR #22, merge `74deb80`. Lotto 2 fatto: PR #23, merge `cb90c4f`. Lotto 2b fatto: PR #24, merge
  `6374e41` (ICH-529, ICH-530, ICH-489, ICH-493, ICH-490 a Done). Log in `memory/backlog-issue.md`, esito in
  `RICONSEGNA.md`. `master` su `6374e41`: 1124 esempi, 0 fallimenti (ordine normale, semi 1234, 4242, 7); coverage
  98,25 %; RuboCop 0; YARD 100 %; layer FFI invariato; CI verde.
- **Prossimo step: lotto 2c** (ICH-531, ICH-532: le issue nate dal lotto 2b, entrambe in `lib/notcurses/plane.rb`;
  scelta dell'utente del 2026-11-17), poi il lotto 3 (ICH-454, ICH-456, ICH-455). Procedura da
  `/trinity:workflow:1_create-worktree master ICH-531 ICH-532 opus` (branch `bug/ICH-531-532-opus`). Il worktree del
  lotto 2b è già rimosso.
- Nel lotto 2c, nate dal lotto 2b: ICH-531 (il ripristino della base dopo un resize o una
  rotazione richiede spazio nel pool) e ICH-532 (scelta dell'utente su ICH-530, opzione 3: dopo una metà sinistra
  orfana `merge_down` deve lasciare in `dst` uno spazio e il glifo di `src`, non il glifo largo che lo copre). Nel round 2 Fable non ha
  fatto la review (limite d'uso, si azzera il 2026-11-20): se serve, rilancia la review di Fable su `f209900`.
- **ICH-214 in Backlog**, tolta dal lotto 2: ruotare il framebuffer da Ruby non si rende sicuro (un gestore `trap` o
  un altro thread può fare un resize fra la copia e la scrittura). Serve un lock o codice C: va riprogettata in un
  lotto suo, forse con un helper approvato nel layer FFI (regola 1). Il lotto 2 azzera già `logrow` nel resize in due
  passi di `resize_region`.
- Gestori `trap` (decisione dell'utente nel lotto 2): un trap gira anche al ritorno dei metodi C e dentro i blocchi, e
  `Thread.handle_interrupt` non lo rinvia. I workaround che leggono i campi privati restringono le finestre e lo YARD
  lo dice; non rincorrere ogni finestra in review. Nei filtri non usare `nonzero?` (guardia di ricorsione: `NameError`
  con un trap che lo chiama), ma `!= 0`.
- Note dai lotti 1 e 2: le letture di `ncplane_at_yx_cell` restano tolleranti (egcpool pieno, piani con bitmap); i
  reviewer provano l'egcpool pieno (EGC da 6 MB), i piani con bitmap su un pty finto (sixel e Kitty:
  `bitmap_plane_script` in `spec/integration/pty_spec.rb`), i piani che hanno fatto scroll, le metà sinistre orfane, i
  callback di resize che cambiano il piano e i gestori `trap`. I reviewer non usano `rm`; i worktree di review si
  rimuovono con `--force` quando `git status` è vuoto (solo il submodule), altrimenti con la conferma dell'utente.
- Il merge di una PR lo blocca il classificatore dei permessi ("Merge Without Review") anche con il sì dell'utente:
  chiedi all'utente di eseguire `gh pr merge <n> --merge`, poi chiudi il lotto (passo 7).

## Contesto

- **Progetto:** binding Ruby completo per notcurses 3.0.17. Repository **privato**
  https://github.com/ichelema/notcursesruby, branch `master`. Gem `notcursesruby` 0.1.0 (Apache-2.0),
  `require 'notcurses'`; non pubblicata su rubygems.org.
- **Macchina:** checkout in `/Dati/Sviluppo/Progetti/Personali/20261027_notcursesruby` (CachyOS, Linux x86_64),
  notcurses 3.0.17 di sistema con `libnotcurses-ffi.so.3`, Ruby 4.0.7 da mise. Su Ruby 3.1.7:
  `mise exec ruby@3.1.7 -- rspec` dalla radice del progetto, senza `bundle`.
- **Fasi 1–5:** complete. Fase 1 layer FFI, Fase 2 wrapper idiomatico, Fase 3 `Notcurses::UI`, Fase 4 pacchetto e
  CI, Fase 5 blitter su Kitty e Ghostty e porting su macOS (PR #20 e #21). Correzioni della revisione del
  2026-11-06: 17 lotti, PR #2…#19. Dettagli nelle sezioni omonime di `RICONSEGNA.md`.
- **Stato al `ad0315b`:** 1048 esempi, 0 fallimenti su Linux, in ordine normale e con i semi 1234, 4242 (3 volte)
  e 7; coverage righe 98,46 %, file più basso `lib/notcurses/context.rb` 93,32 %; `bundle exec rubocop` 0 offense
  (99 file); YARD al 100 %. Log della verifica: `memory/fase5-terminali-macos.md`, sezione "Parte 4".
- **CI:** container `archlinux:base` fissato per digest, snapshot `2026/10/26` dell'Arch Linux Archive, Ruby da
  mise, matrice 3.1.7, 3.2.11, 3.3.13, 3.4.12, 4.0.9. RuboCop solo nel job 4.0.9. Soglie di coverage: 98 % totale,
  90 % per file, layer FFI escluso. I commit di sola documentazione usano `[skip ci]`.
- **Linear:** progetto `notcursesruby` del team Ichelema (`ICH`). Le issue sono in inglese (label di progetto
  `lang:en`). Le issue della revisione (ICH-441…ICH-475) hanno `Problem`, `Acceptance criteria` e `Required
  tests`; per ICH-214…ICH-232 il formato non è controllato.
- **Punto aperto senza issue:** blocco raro in `Context#close` su macOS (log della Fase 5, "Punti aperti"). L'utente
  ha scelto il 2026-11-15 di non aprire una issue: resta fuori da questa fase.

## Obiettivo

Correggi le issue aperte in Backlog del progetto, nell'ordine dei lotti di "Ordine di lavoro". Ogni lotto è un
worktree, un branch e una PR, con i comandi del workflow di Trinity. La fase cambia il comportamento della libreria
solo per correggere i difetti descritti nelle issue.

Fuori scope, salvo una richiesta esplicita dell'utente: nuove funzionalità o widget non descritti da una issue, la
causa del blocco raro su macOS, la pubblicazione della gem, job macOS in CI, Windows.

## Prima di iniziare

1. Fai il recall in Hindsight, bank `notcursesruby` (comando in "Comandi"), se il server risponde. Se non risponde,
   prosegui e dillo in una riga.
2. Leggi in `RICONSEGNA.md`: "Correzioni della revisione del 2026-11-06" (soprattutto "Issue aperte nate dai
   lotti"), le tabelle dei bug di notcurses 3.0.17 (Fase 2 e Fase 3) e la sezione "Fase 5". Leggi in
   `memory/correzioni-review.md` le "Decisioni iniziali" e il log dei lotti 2, 7, 9, 12, 13 e 17, da cui nascono
   molte issue di questa fase.
3. Controlla `git status` (working tree pulito) e `git log --oneline -3` (su `ad0315b` o dopo). Se manca
   `notcurses/data`: `git submodule update --init --depth 1 notcurses`.
4. Esegui `bundle install`, la suite completa e `bundle exec rubocop` (comandi in "Comandi"): 1048 esempi, 0
   fallimenti; 0 offense.
5. Leggi da Linear tutte le issue aperte (query in "Comandi"): descrizione, acceptance criteria, relazioni, label.
   Per ogni issue scrivi nel log quali file tocca. Con questi dati controlla la proposta di "Ordine di lavoro" e
   cambiala se due lotti toccano lo stesso codice o se una issue è già risolta.
6. Chiedi all'utente, con AskUserQuestion:
   - l'approvazione dei lotti (la tabella, con i cambi del passo 5);
   - il modello di implementazione da passare ai comandi del workflow (i lotti della revisione hanno usato `opus`);
   - se tenere nella fase ICH-231 e ICH-457, che sono funzionalità nuove (label `Improvement`);
   - come trattare ICH-225, che è uno spike (label `spike`): solo un audit con issue nuove, oppure anche i fix.
7. Una issue di ICH-214…ICH-232 senza `Acceptance criteria`: proponi il testo all'utente e, dopo la conferma,
   scrivilo nella issue su Linear prima del fix.

Crea il log `memory/backlog-issue.md` all'inizio: decisioni iniziali, file per issue, poi un capitolo per lotto con
lo stesso formato di `memory/correzioni-review.md` (Fix, Decisioni, Review, Problemi e soluzioni, Verifica finale).

## Regole vincolanti

Le regole 1–10 vengono dalle fasi precedenti, le regole 11–17 dai lotti della revisione, le regole 18–19 dai lotti
successivi.

1. Non cambiare la Fase 1 (`lib/notcurses/ffi/`, `lib/notcurses/ffi.rb`) senza l'approvazione dell'utente. Se un
   fix lo richiede, fermati e chiedi.
2. Ogni puntatore opaco ha un distruttore (`close` o `destroy`). Il pattern `owned:` copre i puntatori non posseduti.
3. notcurses non è thread-safe. Il wrapper lo documenta e non aggiunge lock interni.
4. I metodi restituiscono `self` dove il chaining ha senso.
5. Nomi Ruby: `snake_case`, suffisso `?` per i predicati, nessun prefisso `nc` o `notcurses_`.
6. Ogni ritorno C che indica un errore (-1 o NULL) diventa un'eccezione con un messaggio chiaro.
7. Le opzioni con un default sono keyword arguments. `spec/notcurses/api_spec.rb` controlla le regole 5 e 7.
8. `define_method` e `method_missing` sono vietati.
9. Ogni metodo pubblico ha un commento YARD con `@param`, `@return` e `@raise`.
10. Dipendenze runtime: solo la gem `ffi`. Ruby >= 3.1.
11. Ogni fix parte da una spec che fallisce sul codice attuale: prima la spec, poi il fix, poi la suite completa.
    Una spec di un crash (SIGSEGV, abort, double free) o di un blocco esegue il caso in un processo figlio con un
    timeout e controlla lo stato di uscita, così la suite sopravvive anche prima del fix. Un bug di notcurses nuovo
    va nelle tabelle di `RICONSEGNA.md`. Ogni fix ha una voce in "Corretto" di `[Non rilasciato]` in
    `CHANGELOG.md`.
12. Una dipendenza di sviluppo nuova richiede l'approvazione dell'utente e va in un gruppo del `Gemfile`. Elenca ogni
    cambio a `Gemfile` e `Gemfile.lock` in `RICONSEGNA.md`. Dopo un cambio del lockfile controlla il job Ruby 3.2.11
    della CI (`parallel < 2`).
13. Le azioni esterne o difficili da annullare richiedono la conferma esplicita dell'utente: merge di una PR, tag,
    release, impostazioni del repository, secret, GitHub Pages. Il push dei branch dei lotti, l'apertura delle PR e
    il push su `origin/master` dei commit di sola documentazione sono autorizzati.
14. Una scelta con due letture valide spetta all'utente: chiedi con AskUserQuestion. Se hai dubbi, fermati e
    chiarisci con l'utente.
15. Lingua: commit, titolo e corpo delle PR e commenti su Linear in inglese (`lang:en`, per esempio
    `fix(plane): ...`). `RICONSEGNA.md`, `RIPRESA.md` e `memory/` restano in italiano.
16. Un lotto tocca solo il codice delle sue issue. Se un fix richiede un cambio che appartiene a un altro lotto o a
    un'altra issue, fermati e chiedi all'utente. Un difetto nuovo trovato in review diventa una issue nuova in
    Backlog, con la conferma dell'utente.
17. Prima del merge di ogni PR: CI verde su tutta la matrice e soglie di coverage invariate.
18. RuboCop: `bundle exec rubocop` esce con 0 prima di ogni PR. Un file nuovo passa da ogni cop di Standard (stringhe
    con le virgolette doppie); `.rubocop_todo.yml` non va rigenerato per far passare codice nuovo (fino al lotto di
    ICH-469).
19. Ogni file nuovo ha l'intestazione di due righe (`# Generated from notcurses 3.0.17` e `# Source: ...`).

## Ordine di lavoro

Proposta del 2026-11-15, controllata con le descrizioni di Linear e approvata dall'utente con 4 cambi: ICH-225 nel
lotto 1, ICH-214 nel lotto 2, ICH-464 nel lotto 5, ICH-474 nel lotto 7 (motivi in `memory/backlog-issue.md`).
Le issue nate dai lotti 1, 2 e 2b sono state aggiunte dopo (lotti 2, 2b, 2c, 6, 8 e 14). Criteri:

1. prima la priorità di Linear (High, poi Medium, poi Low);
2. le issue che toccano lo stesso codice stanno nello stesso lotto;
3. un lotto contiene solo issue dello stesso tipo: `/trinity:workflow:1_create-worktree` ricava un solo prefisso di
   branch, `bug` dalla label `Bug` e `improvments` dalla label `Improvement`;
4. il lotto di RuboCop (ICH-469, ICH-470, lotto 15) chiude la lista: cambia le virgolette in quasi tutti i file e andrebbe in
   conflitto con ogni altro lotto.

| Lotto | Prefisso | Issue | Priorità | Titolo |
| --- | --- | --- | --- | --- |
| 1 | `bug` | ICH-449 | High | Fix the double free after merge_down with wide glyphs followed by Plane#at |
| 1 | `bug` | ICH-450 | High | Keep polyfill, gradient and erase_region from leaving an orphan half of a wide glyph |
| 1 | `bug` | ICH-448 | Medium | Keep the cut-glyph check state per C plane, not per Plane wrapper |
| 1 | `bug` | ICH-225 | Medium | Audit cross-plane cell copies for the wide-glyph width mismatch (spike) |
| 2 | `bug` | ICH-214 | Medium | Work around row reordering after scroll (notcurses logrow bug) |
| 2 | `bug` | ICH-485 | Medium | Restore wide-glyph right halves after Plane#merge_down when the egcpool is full (nata dal lotto 1) |
| 2 | `bug` | ICH-215 | Low | Prevent long-EGC corruption in Plane#resize_region with keep_x > 0 |
| 2 | `bug` | ICH-216 | Low | Restore the fixed flag and vertical alignment in Plane#duplicate |
| 2 | `bug` | ICH-482 | Low | Release the destination egcpool in Plane#merge_down (nata dal lotto 1) |
| 2 | `bug` | ICH-487 | Low | Clear the orphan half of a cut wide glyph that notcurses cannot read on resize (egcpool full) (nata dal lotto 1) |
| 2b | `bug` | ICH-529 | Medium | Re-check dst right before undo_merge! writes the old framebuffer in Plane#merge_down (nata dal lotto 2) |
| 2b | `bug` | ICH-530 | Medium | Keep Plane#merge_down from leaving a broken cell after an orphan wide-glyph left half on the last row of src (nata dal lotto 2) |
| 2b | `bug` | ICH-489 | Medium | Keep the base cell valid after a resize that keeps nothing (egcpool dump) (nata dal lotto 2) |
| 2b | `bug` | ICH-493 | Medium | Keep Plane#at from crashing on a Kitty bitmap plane after a render (nata dal lotto 2) |
| 2b | `bug` | ICH-490 | Low | Make Plane#contents read EGCs when the egcpool has no room for a copy (nata dal lotto 2) |
| 2c | `bug` | ICH-531 | Medium | Keep the base cell when the egcpool fills up during a resize or rotation that keeps nothing (nata dal lotto 2b) |
| 2c | `bug` | ICH-532 | Low | Keep Plane#merge_down from covering the glyph after an orphan wide-glyph left half on the last row of src (nata dal lotto 2b) |
| 3 | `bug` | ICH-454 | Medium | Keep notcurses' internal line-signal flag in sync with ISIG in EventLoop#run |
| 3 | `bug` | ICH-456 | Medium | Raise one line signal per kitty Ctrl+C press, not on its repeat and release |
| 3 | `bug` | ICH-455 | Low | Do not deliver the queued Ctrl+C of an interrupted run to a following run(no_linesigs: true) |
| 4 | `bug` | ICH-463 | Medium | Stop notcurses from blocking when a UTF-8 character is split across the 8192-byte input read |
| 5 | `bug` | ICH-475 | Medium | Closing the context or the visual while another thread is inside Visual#decode is a use-after-free |
| 5 | `bug` | ICH-464 | Low | Close the window between to_ptr and the C call for a close from a trap handler |
| 6 | `bug` | ICH-458 | Medium | Make Direct#stream redraw :pixel frames in place when they end on the last screen row |
| 6 | `bug` | ICH-486 | Medium | Keep Visual blits from leaving an orphan half of a wide glyph (nata dal lotto 1) |
| 6 | `bug` | ICH-222 | Low | Free Direct::Frame memory on close and keep the Direct#stop reset off stdout |
| 6 | `bug` | ICH-223 | Low | Fix Visual.from_palidx palette colors and Visual#rotate pixel loss |
| 6 | `bug` | ICH-488 | Low | Check Plane#qrcode over one half of a wide glyph (nata dal lotto 1) |
| 7 | `bug` | ICH-441 | Medium | Handle Process.daemon with an open Context or Direct without leaving the terminal altered |
| 7 | `bug` | ICH-226 | Low | Harden Context and Direct init against a second Ctrl-C and Thread#kill |
| 7 | `bug` | ICH-474 | Low | Keep the C resource when an async exception arrives during Visual.from_file, Direct#load_image or Direct#render_frame |
| 8 | `bug` | ICH-218 | Medium | Make Reader delete the character in column 0 |
| 8 | `bug` | ICH-217 | Low | Handle graphemes that notcurses segments differently from Ruby |
| 8 | `bug` | ICH-232 | Low | Reject graphemes that notcurses splits differently in UI widget text checks |
| 8 | `bug` | ICH-484 | Low | Keep the width of wide-glyph right halves in the Reader view after Backspace, Ctrl+U and Ctrl+W (nata dal lotto 1) |
| 9 | `bug` | ICH-230 | Medium | Bound the unfinished line in LogView#append by bytes |
| 10 | `bug` | ICH-220 | Medium | Make the Tabbed header follow plane resizes |
| 10 | `bug` | ICH-221 | Medium | Fix Tree focus drift with items of different heights |
| 10 | `bug` | ICH-219 | Low | Fix Menu selection loss on separator click and mouse_selected for right-aligned sections |
| 11 | `bug` | ICH-459 | Low | Close every child of a UI container when a child close or the focus change raises |
| 11 | `bug` | ICH-460 | Low | Keep every Dialog button visible on a very narrow area |
| 11 | `bug` | ICH-461 | Low | Give the focus to a component that becomes visible when nothing has the focus |
| 11 | `bug` | ICH-473 | Low | Print the result after Context.open in the YARD example of Notcurses::UI::App |
| 12 | `improvments` | ICH-227 | Low | Keep FdPlane close interruptions out of wrapper text methods on Ruby 3.1 |
| 13 | `improvments` | ICH-231 | Low | Add an optional queue limit and a non-blocking post to EventLoop (funzionalità nuova: scelta dell'utente) |
| 13 | `improvments` | ICH-457 | Low | Deliver mouse drag motion to the component where the drag started (funzionalità nuova: scelta dell'utente) |
| 14 | `bug` | ICH-483 | Low | Free ncplane_putwegc strings with the allocator notcurses used (FFI layer) (nata dal lotto 1; Fase 1: approvazione dell'utente prima del fix, regola 1) |
| 15 | `improvments` | ICH-469 | Low | Apply the safe RuboCop autocorrections and switch to double quotes |
| 15 | `improvments` | ICH-470 | Low | Remove the redundant rubocop:disable comment in ui/component.rb |

Ogni lotto parte da `master` aggiornato, dopo il merge del lotto precedente: i lotti non vanno lavorati in parallelo.
ICH-224, ICH-228 e ICH-229 sono già a Done.

### Scelte aperte (regola 14)

- ICH-464 e ICH-475: la descrizione segnala una scelta con due letture valide. Chiedi all'utente prima del fix.
- ICH-225: spike; scelta dell'utente: audit e fix nello stesso lotto dei casi confermati.
- ICH-231 e ICH-457: funzionalità nuove; scelta dell'utente: restano nella fase, lotto 13.

### Note sulle issue

- ICH-454, ICH-455, ICH-456 (protocollo di tastiera kitty) e ICH-458 (`:pixel`): la prova sul terminale vero
  serve Kitty o Ghostty. La sessione di Claude Code gira in Kitty: per una prova a vista apri una finestra nuova con
  `kitty @ launch` (comando in "Comandi") e chiedi all'utente di confermare (regola 16 della Fase 5: il terminale
  torna pulito dopo la prova). `kitty @ send-key` non manda il testo associato ai tasti.
- ICH-463 e ICH-449 riguardano blocchi o crash: la spec gira in un processo figlio con un timeout (regola 11).
- ICH-214 cita un bug di notcurses (logrow): se il fix è un workaround, aggiorna le tabelle dei bug di notcurses in
  `RICONSEGNA.md`.

## Procedura per ogni lotto

`<model>` è il modello scelto dall'utente; `<ID...>` sono gli ID delle issue del lotto, nell'ordine della tabella.

```text
/trinity:workflow:1_create-worktree master <ID...> <model>
/trinity:workflow:2_work-issue <ID...> <model>
/trinity:workflow:3_independent-review <ID...> <model>
/trinity:workflow:4_review-fix-loop <ID...> <model>
/trinity:workflow:5_remove-worktree <prefisso>+<ID-numeri>-<model>
```

1. `1_create-worktree` crea il branch `<prefisso>/<ID-numeri>-<model>` (per esempio `bug/ICH-449-450-448-opus`) e
   il worktree in `.claude/worktrees/` del repository.
2. `2_work-issue` porta le issue a In Progress, scrive il piano e implementa. Per ogni issue: la spec che fallisce,
   il fix, la suite completa (regola 11). Commit separati per issue, Conventional Commits in inglese con scope.
   Apre la PR con le magic words, senza merge.
3. `3_independent-review` fa una review indipendente in sola lettura del changeset rispetto agli acceptance
   criteria.
4. `4_review-fix-loop` serve solo se la review trova problemi.
5. Controlla la CI della PR (`gh pr checks <n> --watch`). Con la CI verde chiedi all'utente il merge (regola 13).
   Dopo il merge Linear porta le issue a Done.
6. `5_remove-worktree` rimuove worktree e branch, anche quello remoto. `git worktree remove` rifiuta un worktree con
   il submodule inizializzato: `--force` è approvato solo se il worktree ha in più il submodule `notcurses` e
   `git status` è vuoto (decisione dell'utente del 2026-11-08, `memory/correzioni-review.md`). Chiedi conferma se
   la condizione non vale.
7. **Dopo ogni merge chiudi il lotto subito**, senza aspettare che l'utente lo chieda:
   1. `git pull` su `master`, poi la suite completa con i semi 1234, 4242 e 7, `bundle exec rubocop`, `gem build`,
      `git diff ad0315b -- lib/notcurses/ffi lib/notcurses/ffi.rb` e la CI della PR e di `master`.
   2. Riga del lotto in una tabella "Lotti" di una sezione nuova "Issue in Backlog" di `RICONSEGNA.md` (lotto, PR,
      merge, issue, bug di notcurses nuovi), più cambi dell'API e issue nuove nate dal lotto.
   3. Log del lotto in `memory/backlog-issue.md`.
   4. Commit `docs(riconsegna): lotto <n> ... [skip ci]` dei due file.
   5. Retain in Hindsight, bank `notcursesruby`, con cause radice e decisioni.
   6. Aggiorna "Stato e prossimo step" di questo file e committalo con `docs(ripresa): stato dopo il lotto <n>,
      prossimo step lotto <n+1> (...) [skip ci]`; poi `git push`.

Se un acceptance criterion si rivela sbagliato o impossibile, non cambiarlo da solo: proponi il testo nuovo
all'utente e, dopo la conferma, aggiorna la issue su Linear.

## Consegne

1. Una PR per lotto, con la CI verde e il merge confermato dall'utente.
2. Ogni issue della fase a Done, oppure chiusa o lasciata in Backlog con un motivo scritto nella issue.
3. `RICONSEGNA.md`: sezione "Issue in Backlog" con data, tabella dei lotti, cambi dell'API pubblica, bug di notcurses
   nuovi nelle tabelle esistenti, cambi a `Gemfile` e `Gemfile.lock` (se ci sono), "Cosa serve alla fase
   successiva". Aggiorna anche "Issue aperte nate dai lotti" della sezione delle correzioni.
4. Il log `memory/backlog-issue.md`.
5. Hindsight, bank `notcursesruby`, se il server risponde: decisioni e cause radice.
6. Alla fine proponi il passo successivo e chiedi all'utente se scrivere qui il prompt della fase dopo. Candidate:
   la pubblicazione della gem, la causa del blocco raro su macOS.

## Controlli finali

- Suite completa: 0 fallimenti, in ordine normale e con i semi 1234, 4242 e 7.
- `ruby -w -Ilib -e 'require "notcurses"'` senza warning; `bundle exec rubocop` 0 offense.
- `yard doc --fail-on-warning` 0 warning, `yard stats --list-undoc` 100 %; `gem build` senza warning.
- Coverage >= 98 % totale e >= 90 % per file; `spec/coverage_spec.rb` e `spec/notcurses/api_spec.rb` passano.
- CI verde su tutta la matrice sull'ultimo commit di `master`.
- `git diff ad0315b -- lib/notcurses/ffi lib/notcurses/ffi.rb` vuoto, salvo cambi approvati dall'utente.
- Se un lotto cambia codice usato solo su macOS (per esempio `Context#stop_notcurses`), scrivilo nella PR: la CI
  gira solo su Linux.

## Note pratiche

- `spec/integration/pty_spec.rb:173` è instabile per una gara di tempi (`getvec` si sveglia dopo il primo di 4
  tasti). Se fallisce, ripeti la suite prima di cercare una regressione. Non ha una issue.
- Non eseguire due suite in parallelo: il carico della CPU rende instabili le spec dei pty.
- In zsh un comando in una variabile non si divide in parole: usa un array (`E=(env ...)`, `"${E[@]}"`) e scrivi
  `--order "rand:$seed"`. In zsh `echo ====` fallisce: usa `echo '----'`.
- Nei comandi non mettere `rm` né `rm -rf`: un hook li mette in coda per la conferma dell'utente. `doc`, `.yardoc` e
  `coverage` sono già in `.gitignore`. Per `gem build` usa `--output` con un file nello scratchpad.
- Non lanciare `rspec` con cwd in un checkout per provare il codice di un altro: `rspec` mette il `lib/` del cwd nel
  load path prima di `-I`. Nei worktree esegui la suite dalla radice del worktree.
- Dopo l'apertura della PR la CI può partire con qualche minuto di ritardo: aspetta con
  `until gh run list --branch <branch> --limit 1 | grep -q .; do sleep 15; done`, poi `gh pr checks <n> --watch`.
- `gem build` può stampare warning di rdoc dell'installazione locale, non del gemspec: conta che la gem si costruisca
  e che la CI sia verde.

## Comandi

`S` è il percorso assoluto dello scratchpad della sessione, scritto nel prompt di sistema: assegnalo a mano. Non
esiste una variabile `$SCRATCHPAD`.

```sh
S=/percorso/dello/scratchpad   # dal prompt di sistema della sessione
cd /Dati/Sviluppo/Progetti/Personali/20261027_notcursesruby

# suite completa; COLORTERM serve alle 10 spec dei colori RGB, TERM fisso anche dentro Kitty o Ghostty
TERM=xterm-256color COLORTERM=truecolor LANG=C.UTF-8 LC_ALL=C.UTF-8 timeout -k 5 -s KILL 600 bundle exec rspec < /dev/null
TERM=xterm-256color COLORTERM=truecolor LANG=C.UTF-8 LC_ALL=C.UTF-8 timeout -k 5 -s KILL 600 \
  bundle exec rspec --order rand:1234 < /dev/null
# coverage (report in coverage/; con una sola spec fallisce per la soglia)
TERM=xterm-256color COLORTERM=truecolor LANG=C.UTF-8 LC_ALL=C.UTF-8 timeout -k 5 -s KILL 600 \
  bundle exec rspec --require ./spec/support/coverage.rb < /dev/null
# script di prova contro notcurses: un solo contesto per processo, output su /dev/null
TERM=xterm-256color COLORTERM=truecolor LANG=C.UTF-8 LC_ALL=C.UTF-8 timeout -k 5 -s KILL 60 ruby -Ilib "$S/prova.rb" < /dev/null
# prova sul terminale vero: finestra nuova di Kitty, con il PATH del Ruby di mise; --foreground evita SIGTTOU
kitty @ launch --type=os-window --cwd="$PWD" --env PATH="$(dirname "$(command -v ruby)"):$PATH" -- \
  bash -c "timeout --foreground -k 5 -s KILL 60 ruby -Ilib $S/prova.rb; echo \$? > $S/prova.exit"
# spec grafiche (Fase 5), dalla finestra di Kitty
NC_GRAPHICS=1 bundle exec rspec spec/graphics --format documentation --out "$S/graphics.log"

# RuboCop, YARD e gem
bundle exec rubocop
bundle exec yard doc --fail-on-warning
bundle exec yard stats --list-undoc
RUBYOPT=-W0 gem build notcursesruby.gemspec --output "$S/notcursesruby.gem"

# workflow: controllo prima del push
mise x aqua:rhysd/actionlint@1.7.12 -- actionlint -ignore SC2016 .github/workflows/ci.yml

# GitHub
gh pr checks <n> --watch
gh run list --limit 5
gh run view <id> --log-failed
```

Linear, con la skill `linear` di Trinity (`LINEAR_API_KEY` è nell'ambiente):

```sh
lq() { (cd /Dati/AI/Claude/Trinity/skills/linear && mise x python -- python scripts/linear.py "$@"); }

# una issue, con stato e relazioni
lq query 'query($id: String!) { issue(id: $id) { identifier title state { name } priority estimate
  labels { nodes { name } } relations { nodes { type relatedIssue { identifier state { name } } } } description } }' \
  --variables '{"id": "ICH-449"}'

# issue aperte del progetto
lq query 'query { issues(first: 100, filter: { project: { name: { eq: "notcursesruby" } },
  state: { type: { nin: ["completed", "canceled"] } } }) { nodes { identifier title priority state { name }
  labels { nodes { name } } } } }'
```

```sh
# recall dal bank notcursesruby
curl -s -m 30 -X POST http://127.0.0.1:8888/v1/default/banks/notcursesruby/memories/recall \
  -H 'Content-Type: application/json' \
  -d '{"query":"issue in Backlog, glifi larghi merge_down polyfill, linesigs kitty Ctrl+C, Visual decode use-after-free, lotti","budget":"high","max_tokens":6000}'

# retain nel bank notcursesruby: il JSON sta in un file dello scratchpad
curl -s -m 30 -X POST http://127.0.0.1:8888/v1/default/banks/notcursesruby/memories \
  -H 'Content-Type: application/json' --data @"$S/retain.json"
```

Formato di `retain.json`:

```json
{"async": true, "items": [{"content": "fatto autosufficiente, con comandi e percorsi alla lettera",
  "context": "una riga che descrive il dominio", "tags": ["claude-code", "repo:notcursesruby"]}]}
```
