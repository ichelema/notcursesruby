# Handoff — prossima sessione

Aggiornato il 2026-11-24. Questo file dice solo cosa fare nella prossima sessione. Le regole di lavoro sono in
[CLAUDE.md](CLAUDE.md), la memoria del progetto in [memory/indice.md](memory/indice.md).

## Stato

- Ultimo merge su `master`: PR #38 (studio ICH-600, Fiber al posto dei thread), commit `e90c5d3`. Dopo il merge
  `master` ha solo commit di documentazione con `[skip ci]`: il codice è quello di `e90c5d3`.
- Nessun lotto in corso: nessun worktree, nessuna PR aperta.
- Il 2026-11-24 la memoria è stata riorganizzata: i log dei lotti non sono più in `memory/` e si leggono con `git show`
  ([memory/indice.md](memory/indice.md), «Fuori da `memory/`»). La coda dei lavori è [memory/piano.md](memory/piano.md).
- Ultima suite su `master` (`e90c5d3`): 1357 esempi, 0 fallimenti, 1 pending, con la coverage (98,1 % righe, 90,2 %
  rami) e con il seme 3680. CI di `master` verde (run `45459613886`).
- Fase «Issue in Backlog»: lotti 1–9c e studio ICH-600 fatti. Ordine scelto dall'utente dopo lo studio
  ([memory/piano.md](memory/piano.md)): gruppo H, una issue per lotto (ICH-604, poi ICH-606, poi ICH-607), studio
  ICH-601, studio ICH-602, gruppo I (ICH-605), poi gruppi A, B, C, lotti 10–14, gruppi D, E, F, G, lotto 15. ICH-603
  è in Backlog senza gruppo. ICH-463 resta in Blocked, in attesa di un rilascio di notcurses con il fix.

## Prossimo passo

1. Esegui i passi 1–5 di «Come riprendere il lavoro» in [CLAUDE.md](CLAUDE.md).
2. Lotto 16, gruppo H: ICH-604 (guardia «blocking» dei callback C sotto un Fiber scheduler). Leggi la issue su
   Linear con il suo commento (i trampolini che passano da `Util.guard` sono quattro, non tre) e
   [memory/studio-fiber.md](memory/studio-fiber.md), fatto 7 della sezione 3 e punto 5 della sezione 4.
3. Esegui il passo 0 del workflow: spiega all'utente il problema, la causa, i dati misurati e le scelte aperte di
   ICH-604. Poi proponi il comando:

   ```text
   /trinity:workflow:1_create-worktree master ICH-604 opus
   ```

## Decisioni che servono all'utente

- Gruppo e momento di ICH-603. Prima del fix serve una prova su Ghostty e Kitty con un display: su `ncvt` lo schermo
  perde l'allineamento con lo stdplane che scorre, ma il difetto può essere di `ncvt`.
- Permessi Linear: il classificatore lascia passare `issueCreate`, `issueRelationCreate` e `commentCreate`, e blocca
  `issueUpdate` («External System Writes»). Per cambiare una issue serve una regola di permesso, oppure l'utente
  lancia la mutation che la skill prepara.
