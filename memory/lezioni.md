# Lezioni dei lotti

Insidie del codice, dei test e delle review emerse dai lotti, da applicare ai lotti futuri. La storia di ogni lotto è
nei log ([backlog-issue.md](backlog-issue.md), [correzioni-review.md](correzioni-review.md)). Le lezioni diventate
regole sono in [regole.md](regole.md) (regole 20–22).

## Glifi larghi, egcpool e celle

- Le letture di `ncplane_at_yx_cell` restano tolleranti: egcpool pieno, piani con bitmap (lotti 1 e 2).
- I workaround di `keeping_base_cell` (ICH-531) e `blank_orphan_lefts!` (ICH-532) scrivono le celle grezze nei campi
  privati (`Plane::Internals`) e non girano senza (lotto 2c).
- `rotate_2x1_cw` e `rotate_2x1_ccw` di notcurses non rilasciano le copie nel pool quando rifiutano un carattere: il
  bug è in [bug-notcurses.md](bug-notcurses.md), tabella «Piani», non aggirato (lotto 2c).
- Per sapere se una scrittura con un EGC lungo entra nel pool non prevederlo con caricamenti di prova: il C rilascia
  la cella di arrivo prima di copiare, e linee, box e riempimenti fanno più copie. Prova la stessa chiamata C su una
  copia del piano (`Plane#rehearse!`, `ncplane_dup`), che ha lo stesso pool (lotto 8d, ICH-582).
- Una misura delle larghezze su `ncvt` vale per Ghostty solo con il modo 2027 acceso ([ambiente.md](ambiente.md)):
  nel lotto 8b la bandiera larga 4 di `ncvt` sembrava un difetto di Ghostty, e Ghostty 1.4 e Kitty la disegnano
  larga 2 (lotto 8d, ICH-586).
- Le righe di `Plane#wrap_lines` non sono pezzi contigui del testo: lo spazio dove va a capo sparisce, e un segno
  combinante o uno ZWJ che formava un grapheme con quello spazio apre la riga dopo da solo. Un controllo fatto solo
  sul testo intero non vale per le righe: `puttext` ricontrolla il primo grapheme di ogni riga (review del lotto 9c).
  Un carattere `Prepend` (U+0600) staccato a fine riga dà lo stesso risultato di `master`.
- Una regex con proprietà Unicode su un testo enorme costa: `/(?!\n)\p{Cc}/` su un EGC da 6 MB costa 150–210 ms, la
  stessa ricerca sui byte di `str.b` 5 ms (`TEXT_SUSPECTS` in `plane.rb`, lotto 9c).

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
- Lo strumento Edit di Claude Code e il testo dei comandi Bash (anche un heredoc) trasformano `\u0301` e gli altri escape `\uXXXX` del testo nuovo nei caratteri veri;
  la forma con le graffe (`\u{1F1EE}`) resta. `spec/source_chars_spec.rb` lo trova: riscrivi gli escape con uno script
  che costruisce i caratteri dai codici, senza scriverli nel testo (lotto 8d). Vale anche per Write e per il testo da
  cercare: Edit non sostituisce una sequenza letterale backslash-`u200D` con il carattere, perché vede i due testi
  uguali. Nel lotto 9c lo script Ruby ha costruito i due testi con `[92].pack('U')` e `[0x200D].pack('U')`.
- Uno spy su `ncplane_dim_x`, `ncplane_dim_y`, `ncplane_cursor_x` o `ncplane_cursor_y` conta due volte una lettura:
  `inline_reimpl.rb` le reimplementa sopra `ncplane_dim_yx` e `ncplane_cursor_yx`, e `ncplane_halign` chiama
  `ncplane_dim_x`. Una spec che conta le letture conta solo le primitive (`plane_write_cost_spec.rb`, lotto 9c).
- Un rapporto con la FFI diretta oscilla fra un'esecuzione e l'altra del benchmark: con lo stesso codice `vline` ha
  dato da 4,8x a 5,1x. Un obiettivo vicino alla soglia si misura sulla mediana di 5 esecuzioni (criterio 5 di
  ICH-594). Per sapere quale commit cambia un tempo, esporta il `lib/` di ogni commit con `git archive` e alterna lo
  stesso micro-benchmark su tutti, per 3 giri: nel lotto 9c una semplificazione con `slice_when` costava il 17 % su
  `putstr` con gli accenti, e il benchmark completo da solo non distingueva il commit dal rumore.
- Se `gh pr checks --watch` dice "no checks reported" subito dopo un push, aspetta che compaia la run
  (`gh run list --branch`). Nel lotto 8d GitHub non ha creato la run del `pull_request`: dopo 30 minuti un commit
  vuoto (`ci: retrigger CI`, scelta dell'utente) l'ha fatta partire. Un job che fallisce al passo «Pacchetti dello
  snapshot» per un timeout di `archive.archlinux.org` non dipende dal codice: `gh run rerun <id> --failed`.

- Un processo nipote che eredita la pipe dell'output di un figlio tiene la pipe aperta finché vive: chi legge fino
  alla fine della pipe resta fermo anche dopo la morte del figlio. Prima di ICH-593 (lotto 9b) questo fermava
  l'intera suite in `fifo_raise_script`. Per le spec con un processo figlio usa `NcHelpers.run_child`
  (`spec/support/nc_helpers.rb`): al timeout uccide il figlio e tutti i discendenti (`kill_tree`, con `ps`), e dopo
  l'uscita del figlio aspetta l'output al massimo `grace` secondi, poi su Linux uccide chi tiene ancora la pipe
  (`pipe_holders`, da `/proc/*/fd`: un orfano non si trova più dal ppid).
- `spawn(..., pgroup: true)` non serve a fermare i discendenti: nel figlio capo del gruppo `Process.setsid`
  solleva `Errno::EPERM`, e tre script di `spec/integration/ui_pty_spec.rb` lo chiamano per avere un terminale di
  controllo. Inoltre notcurses apre `/dev/tty` quando l'output non è un terminale (`fd.c:469-470`): un figlio in un
  gruppo in background, lanciato da un terminale vero, si fermerebbe su `SIGTTOU` (lotto 9b).
- `rspec file:riga` con una riga calcolata prima di un edit esegue un altro esempio, quello che precede la riga
  nuova: ricalcola la riga dopo ogni edit del file. Nel lotto 9b una misura sbagliata («l'esempio è più rapido di
  1,3 s») è finita nel corpo della PR per questo motivo.

## Review

Le istruzioni per i reviewer sono le regole 23 e 24 di [regole.md](regole.md). Qui restano i casi e i motivi.

- La lista dei casi della regola 23 viene dalle review dei lotti 1 e 2, che hanno provato questi casi.
- `mise -C "<rev-path>"` (regola 24) serve perché rspec carica il `lib/` del cwd ([comandi.md](comandi.md)) e
  `3_independent-review` vieta il `cd` nel worktree di review. `.review-tmp/` è l'unico posto in cui il comando ammette
  file; dal 2026-11-22 la cartella è in `.gitignore`. `rm` resta fuori per Blast Radius ([ambiente.md](ambiente.md)).
- Il controllo con `pgrep` (regola 24) viene dal lotto 8c: gli script di prova del reviewer su terminali muti hanno
  lasciato processi orfani fermi nell'init, fermati con SIGTERM e usciti in meno di 3 s.
- Il verify di una PR che non deve cambiare il comportamento (lotto 9c, prestazioni) lancia lo stesso script con la
  lib di `master` e con quella della PR, e confronta gli output con `diff`: deve cambiare solo il pid. `screen` usa la
  lib del proprio checkout: per il confronto lancia `ncvt` direttamente con `ruby -I<lib> -r<skill>/snap.rb`,
  con le variabili d'ambiente di `screen`.
- `3_independent-review` sceglie solo reviewer Claude (`hard` Fable, `soft` Sonnet). Per un modello GPT o Gemini la
  sessione lancia `gpt-bridge:reviewer` con la riga `[gpt-model: <alias>]` e il prompt che il comando darebbe al suo
  subagente (studio ICH-600, Gemini 4 Neon). Una skill che gira come agente separato, per esempio `trinity:linear`,
  dentro quel reviewer fallisce con 404 `model_not_found`: usa il modello base dell'agente gpt-bridge, senza la riga
  `[gpt-model: ...]`. Nel prompt metti il testo delle issue e indica `linear.py query` per altre letture.
