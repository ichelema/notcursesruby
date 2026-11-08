# Correzioni della revisione del 2026-11-06 — log

Decisioni, problemi e soluzioni, lotto per lotto. Ordine dei lotti e regole in `RIPRESA.md`; esito in
`RICONSEGNA.md`, sezione "Correzioni della revisione del 2026-11-06".

## Decisioni iniziali (2026-11-08)

- Modello dei comandi del workflow: `opus`. Il modello serve solo al nome del branch e del worktree: il lavoro gira
  nella sessione.
- Issue correlate (ICH-214…ICH-232): fuori dai lotti.
- Lotto 17 (Fase 1, ICH-312 e ICH-313): decisione rimandata a dopo il lotto 16.
- `--force` per `git worktree remove`: approvato per i worktree del lotto 1 che hanno in più solo il submodule
  `notcurses` e `git status` vuoto. `git worktree remove` rifiuta i worktree con un submodule inizializzato.

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
