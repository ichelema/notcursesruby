# Handoff — prossima sessione

Aggiornato il 2026-11-27. Questo file dice solo cosa fare nella prossima sessione. Le regole di lavoro sono in
[CLAUDE.md](CLAUDE.md), la memoria del progetto in [memory/indice.md](memory/indice.md).

## Stato

- Ultimo merge su `master`: PR #40 (lotto 17, ICH-606, Fiber scheduler di `Notcurses::UI::EventLoop`), commit
  `e524c00`. Dopo il merge `master` ha solo commit di documentazione con `[skip ci]`: il codice è quello di `e524c00`.
- Nessun lotto in corso: nessun worktree, nessuna PR aperta. ICH-606 è Done.
- Ultima suite su `master` (`e524c00`): 1396 esempi, 0 fallimenti, 1 pending, con la coverage (98,03 % righe,
  89,59 % rami) e con il seme 49479. CI di `master` verde (run `45978539296`).
- Fase «Issue in Backlog»: lotti 1–9c, studio ICH-600 e lotti 16–17 fatti. Ordine scelto dall'utente
  ([memory/piano.md](memory/piano.md)): gruppo H (ICH-607), studio ICH-601, studio ICH-602, gruppo I (ICH-605), poi
  gruppi A, B, C, lotti 10–14, gruppi D, E, F, G, lotto 15. ICH-603 è in Backlog senza gruppo. ICH-463 resta in
  Blocked, in attesa di un rilascio di notcurses con il fix.

## Prossimo passo

1. Esegui i passi 1–5 di «Come riprendere il lavoro» in [CLAUDE.md](CLAUDE.md).
2. Lotto 18, gruppo H: ICH-607 (`app.async` e `Task`). Leggi la issue su Linear con i commenti e
   [memory/studio-fiber.md](memory/studio-fiber.md): punto 4 della sezione 4, decisioni D2, D3 e D7 della sezione 6,
   fatti 9–14 della sezione 3. Lo scheduler di ICH-606 è `Notcurses::UI::Scheduler` in
   `lib/notcurses/ui/scheduler.rb` (classe privata): oggi un task si crea solo con `Fiber.schedule` dentro `run`, e
   all'uscita di `run` i task in attesa ricevono `Scheduler::Stop`. La issue chiede anche un esempio in
   `examples/demo.rb`.
3. Esegui il passo 0 del workflow: spiega all'utente il problema, la causa, i dati misurati e le scelte aperte di
   ICH-607. Poi proponi il comando:

   ```text
   /trinity:workflow:1_create-worktree master ICH-607 opus
   ```

## Decisioni che servono all'utente

- Gruppo e momento di ICH-603. Prima del fix serve una prova su Ghostty e Kitty con un display: su `ncvt` lo schermo
  perde l'allineamento con lo stdplane che scorre, ma il difetto può essere di `ncvt`.
- Permessi Linear: il 2026-11-27 il classificatore ha bloccato `issueUpdate` («External System Writes»), che è
  passato solo dopo un'autorizzazione esplicita dell'utente in chat; `commentCreate` è passato. Per le modifiche alle
  issue serve di nuovo l'autorizzazione, oppure una regola di permesso.
