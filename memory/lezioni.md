# Lezioni dei lotti

Insidie del codice, dei test e delle review emerse dai lotti, da applicare ai lotti futuri. La storia di ogni lotto è
nei log ([backlog-issue.md](backlog-issue.md), [correzioni-review.md](correzioni-review.md)). Le lezioni diventate
regole sono in [CLAUDE.md](../CLAUDE.md), sezione «Regole vincolanti» (regole 20–22).

## Glifi larghi, egcpool e celle

- Le letture di `ncplane_at_yx_cell` restano tolleranti: egcpool pieno, piani con bitmap (lotti 1 e 2).
- I workaround di `keeping_base_cell` (ICH-531) e `blank_orphan_lefts!` (ICH-532) scrivono le celle grezze nei campi
  privati (`Plane::Internals`) e non girano senza (lotto 2c).
- `rotate_2x1_cw` e `rotate_2x1_ccw` di notcurses non rilasciano le copie nel pool quando rifiutano un carattere: il
  bug è nelle tabelle di `RICONSEGNA.md`, non aggirato (lotto 2c).

## Gestori trap, segnali e thread

- Un gestore `trap` gira anche al ritorno dei metodi C e dentro i blocchi, e `Thread.handle_interrupt` non lo
  rinvia. I workaround che leggono i campi privati restringono le finestre e lo YARD lo dice: non rincorrere ogni
  finestra in review (decisione dell'utente nel lotto 2).
- Nei filtri non usare `nonzero?` (guardia di ricorsione: `NameError` con un trap che lo chiama), ma `!= 0`.
- `Notcurses::Guard` (`lib/notcurses/guard.rb`) conta le operazioni del wrapper in corso. Ogni metodo nuovo che legge
  un puntatore C (`to_ptr`, `@ptr`, `Util.ptr_of`) inizia con `Guard.run`, altrimenti falliscono
  `spec/notcurses/guard_coverage_spec.rb` (statico) e l'audit `spec/support/guard_audit.rb` (lotto 5).
- Prima di Ruby 3.4 `Thread.handle_interrupt` non rinvia l'`Interrupt` di SIGINT, e Ruby consegna le interruzioni al
  ritorno dei metodi C. Per un'operazione che deve sopravvivere a un secondo Ctrl+C serve uno stato condiviso
  recuperabile, non una variabile locale (schema `@claims` di `release_native!`) (lotto 5).
- Con kitty `run` spegne il flag dei segnali di notcurses e lo lascia spento dopo `run` (scelta dell'utente, lotto 3).
- Con la coda di input piena (8192 eventi) notcurses scarta il tasto nuovo (`in.c:523`). Sotto carico della CPU anche
  il Ctrl+C dopo 10000 tasti si è perso, di rado (commento su ICH-536, lotto 3).

## Test e coverage

- Il codice che gira solo nei processi figli delle spec pty non conta per SimpleCov: coprilo anche con spec nel
  processo di rspec (stub di `Process.exit!`, `Process.kill`, `Signal.trap`), come
  `spec/notcurses/init_exit_spec.rb` (lotto 8c).
- La coverage varia di qualche centesimo fra una corsa e l'altra (da 98,33 a 98,41 % nel lotto 3): alcune righe
  dipendono dai tempi dei thread.

## Review

- I reviewer provano l'egcpool pieno (EGC da 6 MB), i piani con bitmap su un pty finto (sixel e Kitty:
  `bitmap_plane_script` in `spec/integration/pty_spec.rb`), i piani che hanno fatto scroll, le metà sinistre orfane,
  i callback di resize che cambiano il piano e i gestori `trap` (lotti 1 e 2).
- I reviewer eseguono gli script da stdin, senza file e senza `.review-tmp`. `3_independent-review` vieta il `cd`
  nel worktree di review, ma rspec carica il `lib/` del cwd ([comandi.md](comandi.md)): per rspec usa una subshell
  `( cd <worktree di review> && ... )`, che non sposta la sessione. I reviewer non usano `rm` (Blast Radius,
  [ambiente.md](ambiente.md)).
- Dopo una review con script su terminali muti controlla con `pgrep` i processi orfani fermi nell'init, prima di
  rimuovere il worktree di review (lotto 8c: fermati con SIGTERM, usciti in meno di 3 s).
