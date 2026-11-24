# Handoff — prossima sessione

Aggiornato il 2026-11-25. Questo file dice solo cosa fare nella prossima sessione. Le regole di lavoro sono in
[CLAUDE.md](CLAUDE.md), la memoria del progetto in [memory/indice.md](memory/indice.md).

## Stato

- Ultimo merge su `master`: PR #39 (lotto 16, ICH-604, guardia «blocking» dei callback C), commit `185cb82`. Dopo il
  merge `master` ha solo commit di documentazione con `[skip ci]`: il codice è quello di `185cb82`.
- Nessun lotto in corso: nessun worktree, nessuna PR aperta. ICH-604 è Done.
- Ultima suite su `master` (`185cb82`): 1368 esempi, 0 fallimenti, 1 pending, con la coverage (98,09 % righe,
  90,17 % rami) e con il seme 56131. CI di `master` verde (run `45508123290`).
- Fase «Issue in Backlog»: lotti 1–9c, studio ICH-600 e lotto 16 fatti. Ordine scelto dall'utente
  ([memory/piano.md](memory/piano.md)): gruppo H (ICH-606, poi ICH-607), studio ICH-601, studio ICH-602, gruppo I
  (ICH-605), poi gruppi A, B, C, lotti 10–14, gruppi D, E, F, G, lotto 15. ICH-603 è in Backlog senza gruppo. ICH-463
  resta in Blocked, in attesa di un rilascio di notcurses con il fix.

## Prossimo passo

1. Esegui i passi 1–5 di «Come riprendere il lavoro» in [CLAUDE.md](CLAUDE.md).
2. Lotto 17, gruppo H: ICH-606 (Fiber scheduler di `Notcurses::UI::EventLoop`). Leggi la issue su Linear con i
   commenti e [memory/studio-fiber.md](memory/studio-fiber.md): punti 1, 2 e 7 della sezione 4, decisioni D1 e D4–D6
   della sezione 6, sezione 5 («Non provato»). Il prototipo è in `benchmark/fiber/`. La guardia dei callback di
   ICH-604 è già in `Util.blocking` (`lib/notcurses/util.rb`).
3. Esegui il passo 0 del workflow: spiega all'utente il problema, la causa, i dati misurati e le scelte aperte di
   ICH-606. Poi proponi il comando:

   ```text
   /trinity:workflow:1_create-worktree master ICH-606 opus
   ```

## Decisioni che servono all'utente

- Gruppo e momento di ICH-603. Prima del fix serve una prova su Ghostty e Kitty con un display: su `ncvt` lo schermo
  perde l'allineamento con lo stdplane che scorre, ma il difetto può essere di `ncvt`.
- Permessi Linear: il 2026-11-24 `issueUpdate` è passato (ICH-604 portata a In Progress). Prima il classificatore lo
  bloccava («External System Writes»): se torna a bloccarlo, serve una regola di permesso, oppure l'utente lancia la
  mutation che la skill prepara.
