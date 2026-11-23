# Lezioni dei lotti

Insidie del codice, dei test e delle review emerse dai lotti, da applicare ai lotti futuri. La storia di ogni lotto è
nei log ([backlog-issue.md](backlog-issue.md), [correzioni-review.md](correzioni-review.md)). Le lezioni diventate
regole sono in [regole.md](regole.md) (regole 20–22).

## Glifi larghi, egcpool e celle

- Le letture di `ncplane_at_yx_cell` restano tolleranti: egcpool pieno, piani con bitmap (lotti 1 e 2).
- I workaround di `keeping_base_cell` (ICH-531) e `blank_orphan_lefts!` (ICH-532) scrivono le celle grezze nei campi
  privati (`Plane::Internals`) e non girano senza (lotto 2c).
- `rotate_2x1_cw` e `rotate_2x1_ccw` di notcurses non rilasciano le copie nel pool quando rifiutano un carattere: il
  bug è nelle tabelle di `RICONSEGNA.md`, non aggirato (lotto 2c).

## Gestori trap, segnali e thread

- Un gestore `trap` gira anche al ritorno dei metodi C e dentro i blocchi, e `Thread.handle_interrupt` non lo
  rinvia. I workaround che leggono i campi privati restringono le finestre, e lo YARD lo dice: per questo la regola 23
  chiede di non rincorrere ogni finestra in review (decisione dell'utente nel lotto 2).
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

Le istruzioni per i reviewer sono le regole 23 e 24 di [regole.md](regole.md). Qui restano i casi e i motivi.

- La lista dei casi della regola 23 viene dalle review dei lotti 1 e 2, che hanno provato questi casi.
- `mise -C "<rev-path>"` (regola 24) serve perché rspec carica il `lib/` del cwd ([comandi.md](comandi.md)) e
  `3_independent-review` vieta il `cd` nel worktree di review. `.review-tmp/` è l'unico posto in cui il comando ammette
  file; dal 2026-11-22 la cartella è in `.gitignore`. `rm` resta fuori per Blast Radius ([ambiente.md](ambiente.md)).
- Il controllo con `pgrep` (regola 24) viene dal lotto 8c: gli script di prova del reviewer su terminali muti hanno
  lasciato processi orfani fermi nell'init, fermati con SIGTERM e usciti in meno di 3 s.
