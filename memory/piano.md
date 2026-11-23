# Piano della fase «Issue in Backlog»

Obiettivo, avanzamento, criteri e ordine dei lotti della fase iniziata il 2026-11-15. Lo stato di ogni issue è in
Linear, progetto `notcursesruby`. Il log dei lotti è in [backlog-issue.md](backlog-issue.md). Il prossimo passo è in
[handoff.md](../handoff.md).

## Obiettivo

Correggi le issue aperte in Backlog del progetto, nell'ordine di «Lotti da fare». Ogni lotto è un worktree, un branch
e una PR, con i comandi del workflow di Trinity ([CLAUDE.md](../CLAUDE.md), «Workflow di un lotto»). La fase cambia il
comportamento della libreria solo per correggere i difetti descritti nelle issue.

Fuori scope, salvo una richiesta esplicita dell'utente: nuove funzionalità o widget non descritti da una issue, la
causa del blocco raro su macOS ([punti-aperti.md](punti-aperti.md)), la pubblicazione della gem, job macOS in CI,
Windows.

## Avanzamento

- Fasi 1–5 complete: Fase 1 layer FFI, Fase 2 wrapper idiomatico, Fase 3 `Notcurses::UI`, Fase 4 pacchetto e CI,
  Fase 5 blitter su Kitty e Ghostty e porting su macOS (PR #20 e #21). Correzioni della revisione del 2026-11-06:
  17 lotti e ICH-465 fuori dai lotti, PR #2…#19. Log nei file `fase*.md` e in
  [correzioni-review.md](correzioni-review.md).
- Fase «Issue in Backlog», dal 2026-11-15, base `ad0315b`: lotti 1–8d fatti, PR #22…#34 (un capitolo per lotto in
  [backlog-issue.md](backlog-issue.md)). Modello passato ai comandi del workflow: `opus`.
- Al 2026-11-23 restano 28 issue aperte: 14 nei lotti 9–15, 13 senza lotto, ICH-463 in Blocked.

## Criteri dei lotti

Proposta del 2026-11-15, approvata dall'utente con 4 cambi (motivi in [backlog-issue.md](backlog-issue.md)):

1. prima la priorità di Linear (High, poi Medium, poi Low);
2. le issue che toccano lo stesso codice stanno nello stesso lotto;
3. un lotto contiene solo issue dello stesso tipo: `/trinity:workflow:1_create-worktree` ricava un solo prefisso di
   branch, `bug` per un bug e `improvments` per un miglioramento. Il comando guarda prima il tipo della issue, poi la
   label (`Bug`, `Improvement`), e chiede se nessuno dei due è chiaro;
4. il lotto di RuboCop (ICH-469, ICH-470, lotto 15) chiude la lista: cambia le virgolette in quasi tutti i file e
   andrebbe in conflitto con ogni altro lotto.

Una issue nata da un lotto entra in un lotto con la scelta dell'utente. Un lotto diviso prende una lettera (8, 8b,
8c, 8d) e non una rinumerazione: i numeri dei lotti dopo restano quelli citati nei log.

## Lotti da fare

| Lotto | Prefisso | Issue | Priorità | Titolo |
| --- | --- | --- | --- | --- |
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
| 13 | `improvments` | ICH-457 | Low | Deliver mouse drag motion to the component where the drag started (pointer capture) (funzionalità nuova: scelta dell'utente) |
| 14 | `bug` | ICH-483 | Low | Free ncplane_putwegc strings with the allocator notcurses used (FFI layer) (nata dal lotto 1; Fase 1: approvazione dell'utente prima del fix, regola 1) |
| 15 | `improvments` | ICH-469 | Low | Apply the safe RuboCop autocorrections and switch to double quotes |
| 15 | `improvments` | ICH-470 | Low | Remove the redundant rubocop:disable comment in ui/component.rb |

- ICH-219, ICH-220, ICH-221, ICH-227, ICH-230 e ICH-231 vengono dal gruppo ICH-214…ICH-232, che non ha un formato
  controllato. Se una issue non ha `Acceptance criteria`, proponi il testo all'utente e, dopo la conferma, scrivilo
  nella issue su Linear prima del fix.

## Issue senza lotto

Ognuna aspetta la scelta dell'utente sul lotto.

| Issue | Priorità | Label | Problema | Note |
| --- | --- | --- | --- | --- |
| ICH-542 | High | Bug | `Plane#qrcode` con il cursore fuori da (0, 0): il C scrive fuori dal buffer di pixel (`fill.c:612-616`) | Lotto 6. Limite nello YARD. Si prova solo con una build di notcurses con libqrcodegen ([ambiente.md](ambiente.md)) |
| ICH-214 | Medium | Bug | Riordino delle righe dopo lo scroll (bug `logrow` di notcurses) | Tolta dal lotto 2, da riprogettare (sotto) |
| ICH-560 | Medium | Bug | `Direct#close` perde il buffer stdio della libc durante lo stop | Lotto 6. Serve `fflush` nel layer FFI (regola 1): nel lotto 6 l'utente non ha approvato il cambio della Fase 1 |
| ICH-561 | Medium | Bug | Un blit `:pixel` che restringe il piano taglia un glifo largo | Lotto 6. Anche su `master` |
| ICH-567 | Medium | Bug | `Direct#stream` con `:pixel` e frame di altezze diverse, uno alto quanto lo schermo | Lotto 6 |
| ICH-540 | Low | Bug | `Plane#close`, `#family_destroy`, `Widget#close` e `Context#drop_planes` da un gestore `trap` che torna al codice interrotto non rinviano la distruzione | Lotto 5. Limite nello YARD |
| ICH-541 | Low | Bug | Un Fiber sospeso dentro un'operazione del wrapper tiene lo stop in attesa per sempre | Lotto 5. Limite nello YARD |
| ICH-554 | Low | Performance | `Visual#rotate` chiama il C una volta per pixel: circa 0,9 s su 1024x1024 | Lotto 6. Accelerarlo può servire un cambio del layer FFI (regola 1) |
| ICH-556 | Low | Performance | Il controllo dei glifi larghi dei blit `:braille` legge tutte le celle del rettangolo: 20 ms su un piano 60x200, contro 0,19 ms prima del lotto 6 | Lotto 6. Nelle celle con soli pixel trasparenti `braille_blit` azzera canali e stile e cambia gli alpha, ma non scrive l'EGC (`blit.c:1193-1215`) |
| ICH-562 | Low | Bug, Performance | Un blit 1x1 di `Visual.blit_rgba` crea due `ncvisual` | Lotto 6 |
| ICH-590 | Low | Bug | Kitty 0.51 disegna il coniugato devanagari "क्ष" largo 1, notcurses e Ghostty lo contano largo 2: su Kitty il testo dopo si sposta | Lotto 8d. La misura su Kitty serve all'utente (display); il comportamento lo sceglie l'utente |
| ICH-591 | Low | Bug | `putstr`/`putegc` di un EGC lungo con il pool quasi pieno: il ripristino del glifo di arrivo (lotto 8b) fallisce e il glifo va perso | Lotto 8d. `Plane#rehearse!` del lotto 8d può sostituire `with_glyph_kept`; tocca `plane.rb` come ICH-592 |
| ICH-592 | Low | Bug | `Plane#base` con una base lunga e il pool pieno solleva `PlaneError` senza motivo (`ncplane_base` duplica nel pool) | Lotto 8d. Come ICH-490; tocca `plane.rb` come ICH-591 |

- ICH-554 e ICH-556 hanno solo la label `Performance`: `1_create-worktree` può chiedere il prefisso del branch.
- ICH-214: il lotto 2 ha scartato la rotazione del framebuffer da Ruby, che non si rende sicura: un gestore `trap` o
  un altro thread può fare un resize fra la copia e la scrittura, e servirebbe un lock o codice C. La issue ammette
  un'altra strada: dopo uno scroll, `resize`, `duplicate`, `rotate_cw`, `rotate_ccw` e `merge_down` possono sollevare
  un `PlaneError` chiaro, e `FadeContext` deve seguire l'ordine visibile delle righe. La issue vieta i cambi alla
  Fase 1: un helper nel layer FFI chiede prima un cambio del criterio, approvato dall'utente. Il lotto 2 azzera già
  `logrow` nel resize in due passi di `resize_region`.

## ICH-463 in Blocked

- Stato del team ICH «Waiting on something outside this repo», scelta dell'utente.
- La correzione è in notcurses (`process_melange`, `in.c:2427`: `consumed < 0` → `<= 0`), proposta con la PR
  [#2954](https://github.com/dankamongmen/notcurses/pull/2954) (issue #2947) dal fork
  `/mnt/data/Sviluppo/Progetti/Fork/20261118_notcurses` (branch `fix/melange-split-utf8`).
- La PR #2954 è nel ramo principale di notcurses dal 2026-11-19 (merge `2cb71b8c`) e la issue #2947 è chiusa. Al
  2026-11-23 l'ultimo rilascio è ancora v3.0.17, e il submodule (`b26048eeb`) ha ancora `consumed < 0`.
- Nessun workaround nel wrapper e nessun aggiornamento del submodule.
- Riprendi la issue quando una versione di notcurses con il fix è usabile dalla gem: ripeti il repro, aggiungi la
  spec (processo figlio con timeout), togli il limite da YARD, README e CHANGELOG, chiudi la issue. Le alternative a
  una versione upstream sono nella PR #27.
- L'automazione di Linear ha portato la issue a In Progress e a Done anche con `Refs` (il nome del branch contiene
  l'ID): dopo ogni evento della PR controlla lo stato.

## Consegne della fase

1. Una PR per lotto, con la CI verde e il merge confermato dall'utente.
2. Ogni issue della fase a Done, oppure chiusa o lasciata in Backlog con un motivo scritto nella issue.
3. I bug di notcurses nuovi in [bug-notcurses.md](bug-notcurses.md) e una voce del `CHANGELOG.md` per ogni fix
   (regola 11).
4. Il log [backlog-issue.md](backlog-issue.md).
5. Hindsight, bank `notcursesruby`, se il server risponde: decisioni e cause radice.
6. Alla fine della fase proponi il passo successivo e chiedi all'utente quale fase viene dopo. Candidate: la
   pubblicazione della gem, la causa del blocco raro su macOS.

## Controlli finali

Valgono alla chiusura di ogni lotto e alla fine della fase. I comandi sono in [comandi.md](comandi.md).

- Suite completa: 0 fallimenti, in ordine normale e con i semi 1234, 4242 e 7.
- `ruby -w -Ilib -e 'require "notcurses"'` senza warning; `bundle exec rubocop` 0 offense.
- `yard doc --fail-on-warning` 0 warning, `yard stats --list-undoc` 100 %; `gem build` senza warning.
- Coverage >= 98 % totale e >= 90 % per file; `spec/coverage_spec.rb` e `spec/notcurses/api_spec.rb` passano.
- CI verde su tutta la matrice sull'ultimo commit di `master` che ha una CI: i commit `[skip ci]` dopo di lui cambiano
  solo documenti o commenti.
- `git diff ad0315b -- lib/notcurses/ffi lib/notcurses/ffi.rb` vuoto, salvo cambi approvati dall'utente.
- Se un lotto cambia codice usato solo su macOS (per esempio `Context#stop_notcurses`), scrivilo nella PR: la CI gira
  solo su Linux.
