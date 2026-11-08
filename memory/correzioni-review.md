# Correzioni della revisione del 2026-11-06 — log

Decisioni, problemi e soluzioni, lotto per lotto. Ordine dei lotti e regole in `RIPRESA.md`; esito in
`RICONSEGNA.md`, sezione "Correzioni della revisione del 2026-11-06".

## Decisioni iniziali (2026-11-08)

- Modello dei comandi del workflow: `opus`. Il modello serve solo al nome del branch e del worktree: il lavoro gira
  nella sessione.
- Issue correlate (ICH-214…ICH-232): fuori dai lotti.
- Lotto 17 (Fase 1, ICH-312 e ICH-313): decisione rimandata a dopo il lotto 16.
- `--force` per `git worktree remove`: approvato per i worktree del lotto 1 che hanno in più solo il submodule
  `notcurses` e `git status` vuoto. `git worktree remove` rifiuta i worktree con un submodule inizializzato. Il
  2026-11-08, prima del lotto 2, l'utente ha esteso l'approvazione a tutti i lotti, con le stesse condizioni.

## Lotto 1 — ICH-268, ICH-269, ICH-270 (PR #2, merge `e22a117`)

### Fix

- **ICH-268 (Ctrl-C durante lo stop).** `close` segna l'oggetto chiuso prima di `notcurses_stop`/`ncdirect_stop` e fa
  il resto in un `ensure` (metodo privato `mark_closed!(fclose:)`). `drop_planes` invalida ogni wrapper prima del suo
  `ncplane_destroy` e il resto prima di `notcurses_drop_planes`; `generation` cresce in un `ensure`. Il reviewer
  Fable ha controllato con un SIGINT vero (output su una pipe piena) che Ruby consegna l'Interrupt nel frame della
  funzione FFI, come la simulazione con `prepend` delle spec.
- **ICH-269 (fork).** Con `@pid != Process.pid`, `close` fa solo `mark_closed!(fclose: false)`: niente `fclose`, che
  chiuderebbe il FILE* copiato dal padre.
- **ICH-270 (trap).** `release_context` prende il Mutex; in un gestore trap `Mutex#lock` solleva `ThreadError`, e il
  `rescue` assegna direttamente, solo se l'oggetto è il contesto attivo.
- **ICH-433 (nata dalla review).** Il figlio di un fork ereditava il buffer stdio di `Direct` (`putstr` usa `fputs`
  su `ttyfp`), e la libc lo scriveva all'uscita del figlio: testo duplicato. Prima scelta: documentare il limite.
  Scelta finale dell'utente: un hook `Process._fork` (modulo privato `DirectForkFlush`, anteposto a
  `Process.singleton_class`) che chiama `ncdirect_flush` sul `Direct` aperto prima di ogni fork. Il round 3 ha trovato
  il fork annidato: il controllo `ctx.pid == Process.pid` saltava il flush nel figlio; tolto (fflush tocca solo la
  libc).

### Review (3 round)

- Round 1: buffer di Direct nel figlio (Fable LOW, GPT MEDIUM); spec mancante per l'eccezione al ritorno di
  `notcurses_drop_planes`. Scartato: `run_child` duplicato (preferenza; una terza copia è in `ui_pty_spec.rb`).
- Round 2: GPT ripropone il buffer di Direct come violazione dell'AC di ICH-269; l'utente sceglie il fix completo.
  Fable: limite di 1 s non controllato nella spec del fork (corretto).
- Round 3: fork annidato e commento sbagliato sul lock di fflush (GPT MEDIUM, corretti senza nuovo round);
  `Process.daemon` (GPT MEDIUM, ICH-441); figlio che non può aprire un nuovo contesto, CHANGELOG, contatori delle
  chiamate C nel nipote (Fable, corretti).

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| Job Ruby 3.1.7 rosso prima delle spec | cache scaduta; mise 2026.10.19 non passa `RUBY_CFLAGS` a ruby-build, gcc 16 compila in C23 | `CFLAGS: -std=gnu17` in `ci.yml`; causa trovata riproducendo il container con Podman |
| `codecov/patch` e `codecov/project` rossi | i rami nuovi girano solo nei processi figli delle spec | `codecov.yml` con status informativi (scelta dell'utente) |
| `git worktree remove` rifiuta i worktree di review | submodule `notcurses` inizializzato per la suite | `--force` dopo `git status` vuoto (approvato dall'utente) |
| Figlio di fork: nuovo `Context.open` fallisce | notcurses registra i segnali in una variabile globale, che il figlio copia (`already registered for signals`) | documentato nel YARD di `close`: il figlio può solo uscire o fare `exec` |

### Verifica finale

- `master` su `e22a117`: 933 esempi, 0 fallimenti, in ordine normale e con i semi 1234, 4242 e 7 (Ruby 4.0.7); la
  stessa suite su Ruby 3.1.7 in locale e in CI.
- `git diff ab75226 -- lib/notcurses/ffi lib/notcurses/ffi.rb`: vuoto.

## Lotto 2 — ICH-271 (PR #3, merge `d4970c4`)

### Fix

- **Design (scelta dell'utente, ibrido).** `clear_cut_glyphs!` svuota con `ncplane_erase_region` le metà orfane sui
  bordi di ogni riga: la metà sinistra (larga 2) nell'ultima colonna, la metà destra in colonna 0, la metà destra
  nell'ultima colonna senza la sua metà sinistra. Le tre `resize*` la chiamano subito (forzata, prima di
  `raise_callback_errors!`: il resize resta applicato anche in errore); `text_target!`, `line_start!` e ogni segmento
  di `putstr` la chiamano solo se le colonne sono cambiate dall'ultimo controllo. Copre i resize fatti dal C
  (stdplane nel render, figli `:maximize`) e i callback Ruby che scrivono durante la cascata.
- **Render dentro `ncplane_put`.** Su uno stdplane che scorre ogni a capo (`"\n"` o a capo automatico, anche fuori
  dall'ultima riga: `scroll_down` fa solo `++y`) fa un `notcurses_render`, che restringe lo stdplane a metà della
  chiamata C. `putstr` e `hline` chiamano prima `ncpile_render` (`render.c:1579`) se la scrittura può andare a capo.
- **`merge_down`** porta glifi larghi senza passare dalle scritture: azzera la cache del piano di destinazione (metodo
  `protected` `forget_cut_glyphs!`; `&:sym` non chiama un metodo protected, serve il blocco esplicito).
- **Prestazioni.** La cache confronta solo le colonne: con le dimensioni intere un piano `scrolling + autogrow`
  rileggeva tutti i bordi a ogni a capo (3000 scritture: da 0,05 s a 4,9 s).

### Review (3 round + review singola, solo Fable)

- Round 1: HIGH render dentro `ncplane_put` (fix più largo del report: vale anche per l'a capo automatico); LOW YARD
  di `resize_region`; scartato l'ordine della pulizia prima di `raise_callback_errors!` (voluto).
- Round 2: MEDIUM `merge_down` + resize che riportano le colonne controllate; test mancante di `hline`.
- Round 3: HIGH metà destra orfana nell'ultima colonna (`resize_region` con `x_off < 0`): PR in draft, poi fix
  (scelta dell'utente: fix e review singola fuori dal loop); MEDIUM stato per wrapper → ICH-448.
- Review singola: MEDIUM scritture quadratiche con autogrow (regressione della PR); LOW commento sbagliato
  sull'origine delle metà orfane.
- Bug già presenti su `master`, issue aperte su richiesta dell'utente: ICH-449, ICH-450.

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| Secondo parere GPT senza report (0 tool call, 2 volte) | limite di utilizzo di GPT | solo Fable per il lotto 2 (scelta dell'utente) |
| `Refs ICH-215` nella PR ha portato ICH-215 a In Progress | l'automazione GitHub → Linear tratta anche i link non chiudenti | riga tolta, ICH-215 riportata a Backlog; nei lotti non collegare issue fuori dal lotto |
| Worktree di review non rimovibile | la sessione era dentro il worktree (`/cd` dell'utente) | `/cd` alla root prima della rimozione |
| Spec pty con heredoc interpolato | escape della regex rovinati | heredoc letterale con costanti in testa allo script |
| Il double free di ICH-449 non si riproduce con 20 iterazioni | intermittente | 200 iterazioni con `libc_malloc_debug` |

### Verifica finale

- `master` su `d4970c4`: 956 esempi, 0 fallimenti; CI verde su tutta la matrice sull'ultimo commit della PR.
- `git diff ab75226 -- lib/notcurses/ffi lib/notcurses/ffi.rb`: vuoto.

## Lotto 3 — ICH-272 (PR #4, merge `29f5a41`)

### Fix

- **Tabella unica.** `Util::IMAGE_BLITTERS` (`Util::BLITTERS` senza `:four_by_one` e `:eight_by_one`) e
  `Util.image_blitter_value`. La usano `Visual.from_plane`, `Plane#as_rgba` e `Visual::Internal.options`, che serve
  `#blit`, `#geometry`, `#create_plane`, `#stream` e i quattro `blit_*`: un solo cambio copre otto metodi.
  `Direct::Args::BLITTERS` è rimossa, `Direct::Args.blitter` usa lo stesso helper. `Plot`, `parse_blitter`,
  `blitter_name` e `Visual::Geometry#blitter` restano su `Util::BLITTERS`.
- **Spec del crash.** Processo figlio con `termtype: 'rxvt-256color'`, che accende i quadranti anche su `/dev/null`;
  su `master` il figlio va in core dump. Un commit solo (`d7eaf4f`).

### Review (1 round, Fable e GPT)

- Fable: nessun finding; crash riprodotto su `master` (exit 139) e assente sul branch.
- GPT: nessun finding; probe con i quadranti su tutte le API delle immagini, con i simboli e le costanti intere.

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| Reviewer GPT senza report (0 tool call, poi report perso dopo 46–50 tool call) | il tunnel SSH verso LiteLLM (porta 4000, host `litellm-vps`) cadeva dopo pochi minuti: `ssh` usciva con il codice 144, senza errori; non era il limite di utilizzo | l'utente ha riavviato LiteLLM; `SendMessage` all'agente dopo la caduta ha recuperato il report |
| `/cd` della sessione nei worktree (implementazione, review GPT) e in Trinity, non chiesti da nessuno | funzione "Follow work" della mod filetree 0.8.2: dopo qualche minuto di letture e scritture in un altro repo git (un worktree conta come repo) esegue `/cd` da sola | `Follow work: off` in `/config` (sezione filetree); dopo un `/cd` la root resta fuori dalle directory di lavoro e il `cd` del tool Bash non ci torna |
| `bundle install` su Ruby 3.1.7 fallisce in `rubygems/resolver/conflict.rb` | in Ruby 3.1.7 è installato anche Bundler 4.0.22, che `bundle` sceglie e che richiede Ruby >= 3.2 | `bundle _2.3.27_` con il `Gemfile` copiato fuori dal progetto (`BUNDLE_GEMFILE`, procedura di `RICONSEGNA.md`) |

### Verifica finale

- Branch: 958 esempi, 0 fallimenti, in ordine normale e con i semi 1234, 4242 e 7 (Ruby 4.0.7) e su Ruby 3.1.7;
  coverage 98,19 % righe; CI verde su tutta la matrice.
- `git diff ab75226 -- lib/notcurses/ffi lib/notcurses/ffi.rb`: vuoto.
- `master` su `29f5a41`: 958 esempi, 0 fallimenti.
