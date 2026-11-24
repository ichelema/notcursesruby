# Punti aperti

Difetti sospetti e spec instabili che non sono issue. Quando un punto diventa una issue o si chiude, rimuovi la sua
voce.

- **Blocco raro in `Context#close` su macOS.** I dettagli sono nel log della Fase 5
  ([fase5-terminali-macos.md](fase5-terminali-macos.md), «Punti aperti»). L'utente ha scelto il 2026-11-15 di non
  aprire una issue: resta fuori dalla fase «Issue in Backlog».
- **Esempio instabile di `getvec` in `spec/integration/pty_spec.rb`**: «get attende senza GVL, getvec legge più
  eventi, il timeout scade con nil e un Interrupt esce da get» (riga 433 al 2026-11-23, prima riga 173). La causa è
  una gara di tempi: `getvec` si sveglia dopo il primo di 4 tasti. Se fallisce, ripeti la suite con lo stesso seme
  prima di cercare una regressione.
- **Blocco non riprodotto in `spec/notcurses/ui/event_loop_spec.rb:716`** (lotto 3, `Thread#kill` durante la pulizia
  di `run`). Alla chiusura del lotto 7 la prima suite su `master` si è fermata lì una volta, con un `F` iniziale in
  `spec/ci_workflow_spec.rb:8` senza messaggio (rspec fermato prima del riepilogo). L'esempio passa da solo 5 volte su
  5 e la suite in ordine definito passa. Lo script di verifica ora ha un timeout per suite.
- **Blocco non spiegato della suite locale del 2026-11-23** (`--order rand:4242`, Ruby 4.0.7, 886 esempi finiti).
  Il lotto 9 lo attribuiva a `spec/integration/pty_spec.rb:744`. Il lotto 9b non ha ritrovato quella mappa: sugli
  alberi dei 4 commit della PR #35 il 887° esempio è `./spec/inline_reimpl_spec.rb[3:5:6]`
  (`ncplane_rounded_box_sized`), che chiama notcurses nel processo di rspec, e `:744` è in posizione 1044–1045.
  Non si è riprodotto in 200 corse di `:744` con la CPU occupata, né in due suite con `rand:4242` sotto carico (sul
  branch del lotto e su `2831f61`). Dettagli nel commento di ICH-593 su Linear. `NcHelpers.run_child` ora ferma i
  blocchi nei processi figli; un blocco nel processo di rspec non ha un timeout per esempio e ferma la suite fino al
  `timeout -k 5 -s KILL 600`.
