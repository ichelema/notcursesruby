# Fase «Issue in Backlog» — obiettivo, criteri e controlli

Si legge quando componi un gruppo o chiudi la fase. La coda dei lavori è in [piano.md](piano.md); lo stato di ogni
issue è in Linear, progetto `notcursesruby`.

## Obiettivo

Correggi le issue aperte in Backlog del progetto, nell'ordine di [piano.md](piano.md). Ogni lotto è un worktree, un
branch e una PR, con i comandi del workflow di Trinity ([CLAUDE.md](../CLAUDE.md), «Workflow di un lotto»). La fase
cambia il comportamento della libreria solo per correggere i difetti descritti nelle issue.

Fuori scope, salvo una richiesta esplicita dell'utente: nuove funzionalità o widget non descritti da una issue, la
causa del blocco raro su macOS ([punti-aperti.md](punti-aperti.md)), la pubblicazione della gem, job macOS in CI,
Windows.

## Avanzamento

- Fasi 1–5 complete: Fase 1 layer FFI, Fase 2 wrapper idiomatico, Fase 3 `Notcurses::UI`, Fase 4 pacchetto e CI,
  Fase 5 blitter su Kitty e Ghostty e porting su macOS (PR #20 e #21). Correzioni della revisione del 2026-11-06: 17
  lotti e ICH-465 fuori dai lotti, PR #2…#19.
- Fase «Issue in Backlog», dal 2026-11-15, base `ad0315b`: lotti 1–9c fatti (PR #22…#37), studio ICH-600 (PR #38,
  merge `e90c5d3`), lotto 16 (ICH-604, PR #39, merge `185cb82`), lotto 17 (ICH-606, PR #40, merge `e524c00`) e
  lotto 18 (ICH-607, PR #41, merge `84e4cd6`): il gruppo H è chiuso. Fuori dai lotti, la PR #42 (merge `a37e000`) ha
  messo in cache i database di pacman della CI, e la PR #43 (merge `d7db438`) ha aggiunto `.claude/scripts/gate`, lo
  stop delle spec senza `notcurses/data`, la regola 24 sulla suite dei reviewer e i «Controlli finali» sulla CI di
  `master` (scelte dell'utente del 2026-11-28); la PR #44 (merge `0ac533d`) ha diviso le due suite della CI in job
  paralleli. Studio ICH-601 (PR #45, merge `5be7b06`). La storia dei lotti sta in git, nelle PR e in Linear. Modello
  passato ai comandi del workflow: `opus`.
- Al 2026-11-28, dopo lo studio ICH-601, restano 32 issue aperte: 13 nei lotti 10–15, 17 senza lotto (con ICH-603 del
  lotto 9c, ICH-605 dello studio ICH-600 e ICH-608 dello studio ICH-601), 1 studio di design (ICH-602), ICH-463 in
  Blocked.

## Criteri dei lotti

Proposta del 2026-11-15, approvata dall'utente con 4 cambi:

1. prima la priorità di Linear (High, poi Medium, poi Low);
2. le issue che toccano lo stesso codice stanno nello stesso lotto;
3. un lotto contiene solo issue dello stesso tipo: `/trinity:workflow:1_create-worktree` ricava un solo prefisso di
   branch, `bug` per un bug e `improvments` per un miglioramento. Il comando guarda prima il tipo della issue, poi la
   label (`Bug`, `Improvement`), e chiede se nessuno dei due è chiaro;
4. il lotto di RuboCop (ICH-469, ICH-470, lotto 15) chiude la lista: cambia le virgolette in quasi tutti i file e
   andrebbe in conflitto con ogni altro lotto.

Una issue nata da un lotto entra in un lotto con la scelta dell'utente. Un lotto diviso prende una lettera (8, 8b,
8c, 8d) e non una rinumerazione: i numeri dei lotti dopo restano quelli citati nei log in git.

## Note delle issue senza lotto

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
| ICH-596 | Low | Bug | Le righe finite di `LogView` non hanno un limite in byte: con `Subprocess` superano `max_partial_bytes` di al massimo un blocco da 8192 byte, con `append` diretto di un blocco solo restano intere | Lotto 9. Prima del fix l'utente sceglie la keyword e quale parte tenere oltre il limite |
| ICH-603 | Low | Bug | Su uno stdplane che scorre, un "\n" che lo fa scorrere lascia sullo schermo una riga vuota prima dell'ultima; il piano è giusto e `Context#refresh` riallinea lo schermo | Lotto 9c. Anche su `master` e con la FFI diretta. Visto solo su `ncvt`: prima del fix serve una prova su Ghostty e Kitty con un display (utente) |
| ICH-604 | Low | Improvement | Eseguire i callback Ruby chiamati da notcurses in un contesto bloccante sotto un Fiber scheduler (`Util.blocking`) | Studio ICH-600, gruppo H. Commento su Linear: i trampolini con `Util.guard` sono quattro, non tre |
| ICH-606 | Low | Improvement | Fiber scheduler di `EventLoop` (hook, `transfer`, `timeout_after`, `max_fps:`, `Error` con uno scheduler già attivo, warning di `IO::Buffer`) | Studio ICH-600, gruppo H. Bloccata da ICH-604 |
| ICH-607 | Low | Improvement | `app.async` e `Task` (`wait`, `stop`, `alive?`, `pass`) | Studio ICH-600, gruppo H. Bloccata da ICH-606 |
| ICH-605 | Low | Performance | `LogView#append` costa circa 450 ms di CPU per MB (2 MB/s) su uno schermo 60x200 | Studio ICH-600, gruppo I. Prima del fix l'utente sceglie l'obiettivo |

- ICH-554 e ICH-556 hanno solo la label `Performance`: `1_create-worktree` può chiedere il prefisso del branch.
  ICH-591 e ICH-592 toccano `plane.rb` e `with_glyph_kept`, cambiati dal lotto 9c.
- ICH-219, ICH-220, ICH-221, ICH-227 e ICH-231 del lotto 10 vengono dal gruppo ICH-214…ICH-232, che non ha un formato
  controllato: se una issue non ha `Acceptance criteria`, proponi il testo all'utente e, dopo la conferma, scrivilo
  nella issue su Linear prima del fix.
- ICH-214: il lotto 2 ha scartato la rotazione del framebuffer da Ruby, che non si rende sicura: un gestore `trap` o un
  altro thread può fare un resize fra la copia e la scrittura, e servirebbe un lock o codice C
  ([lezioni.md](lezioni.md), «Gestori trap, segnali e thread»). La issue ammette un'altra strada: dopo uno scroll,
  `resize`, `duplicate`, `rotate_cw`, `rotate_ccw` e `merge_down` possono sollevare un `PlaneError` chiaro, e
  `FadeContext` deve seguire l'ordine visibile delle righe. La issue vieta i cambi alla Fase 1: un helper nel layer FFI
  chiede prima un cambio del criterio, approvato dall'utente. Il lotto 2 azzera già `logrow` nel resize in due passi di
  `resize_region`.

## Studi di design

Creati il 2026-11-24 su richiesta dell'utente, dopo l'analisi delle prestazioni e della concorrenza
([prestazioni.md](prestazioni.md)). ICH-600 e ICH-601 sono fatti; ICH-602 viene dopo (scelta dell'utente del
2026-11-24). Ogni studio produce un design approvato dall'utente, un prototipo misurato e le issue di implementazione.
Lo studio ICH-600 è il modello: design e misure in [studio-fiber.md](studio-fiber.md).

- ICH-601, fatto (PR #45): calcolo parallelo in Ractor; design, fatti e scelte D1–D5 in
  [studio-ractor.md](studio-ractor.md). Issue di implementazione: ICH-608 (gruppo J di [piano.md](piano.md)). Lezione
  della review: ogni fatto dello studio ha una prova in `benchmark/ractor/facts.rb` ([lezioni.md](lezioni.md)).
- ICH-602: rilasciare il GVL durante il rasterize. Tocca la Fase 1 (regola 1) e la regola 3, ed è collegata a ICH-600:
  l'hook `blocking_operation_wait` non copre le chiamate FFI, quindi un worker pool non serve.

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
4. La coda aggiornata in [piano.md](piano.md), le decisioni in un commento sulla issue e l'esito di review e verify in
   un commento sulla PR.
5. Hindsight, bank `notcursesruby`, se il server risponde: decisioni e cause radice.
6. Alla fine della fase proponi il passo successivo e chiedi all'utente quale fase viene dopo. Candidate: la
   pubblicazione della gem, la causa del blocco raro su macOS.

## Controlli finali

Valgono alla chiusura di ogni lotto e alla fine della fase. I comandi sono in [comandi.md](comandi.md).

- CI verde su tutta la matrice sull'ultimo commit di `master` che ha una CI, di solito il merge del lotto: i commit
  `[skip ci]` dopo di lui cambiano solo documenti o commenti. La CI sostituisce i controlli in locale (scelta
  dell'utente del 2026-11-28): per ogni versione di Ruby un job esegue la suite in ordine normale e un altro quella
  in ordine casuale con un seme nuovo, e tutti e due `ruby -w`; nel job «4.0.9, ordine normale» la suite è quella con
  la coverage (soglie: 98 % totale, 90 % per file, con `spec/coverage_spec.rb` e `spec/notcurses/api_spec.rb`), e lo
  stesso job esegue `gem build`, `yard doc --fail-on-warning` con il 100 % documentato e `rubocop`. Un job saltato o
  rosso per l'infrastruttura va rilanciato prima della chiusura.
- `git diff ad0315b -- lib/notcurses/ffi lib/notcurses/ffi.rb` vuoto, salvo cambi approvati dall'utente.
- Se un lotto cambia codice usato solo su macOS (per esempio `Context#stop_notcurses`), scrivilo nella PR: la CI gira
  solo su Linux.
