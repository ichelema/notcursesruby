# Handoff — prossima sessione

Aggiornato il 2026-11-23. Questo file dice solo cosa fare nella prossima sessione. Le regole di lavoro sono in
[CLAUDE.md](CLAUDE.md), la memoria del progetto in [memory/indice.md](memory/indice.md).

## Stato

- Ultimo merge su `master`: PR #34 (lotto 8d: ICH-582, ICH-586), commit `964bbf8`, il 2026-11-23. Nessun lotto in
  corso e nessun worktree di lotto aperto.
- Dopo il merge `master` ha solo commit di documentazione con `[skip ci]`: il codice è quello di `964bbf8`.
- Fase «Issue in Backlog»: lotti 1–8d fatti. Restano i lotti 9–15 e 13 issue senza lotto
  ([memory/piano.md](memory/piano.md)), fra cui le tre nuove del lotto 8d (ICH-590, ICH-591, ICH-592). ICH-463 resta
  in Blocked, in attesa di un rilascio di notcurses con il fix.
- Ultima suite su `master` (`964bbf8`): 1325 esempi, 0 fallimenti, 1 pending, in ordine normale e con i semi 1234,
  4242 e 7; coverage 98,11 % di righe e 90,07 % di rami; RuboCop 0 offense; YARD 100 %. CI di `master` verde (run
  `45132296796`).
- Le scritture su Linear dalla sessione passano dalla regola `Allow` per
  `Bash(mise x python -- python scripts/linear.py mutation:*)` in `.claude/settings.local.json`: senza, il
  classificatore dei permessi le blocca.

## Prossimo passo

1. Se non li hai già fatti, esegui i passi 1–5 di «Come riprendere il lavoro» in [CLAUDE.md](CLAUDE.md).
2. Il prossimo lotto in ordine è il **lotto 9** (`bug`): ICH-230 (Medium), «Bound the unfinished line in
   LogView#append by bytes». ICH-230 viene dal gruppo ICH-214…ICH-232: se non ha `Acceptance criteria`, proponi il
   testo all'utente e, dopo la conferma, scrivilo nella issue su Linear prima del fix ([memory/piano.md](memory/piano.md)).
3. Spiega la issue all'utente (passo 0 del workflow). Poi proponi il comando qui sotto e fermati: lo lancia
   l'utente. Il branch atteso è `bug/ICH-230-opus`.

   ```text
   /trinity:workflow:1_create-worktree master ICH-230 opus
   ```

4. Dopo il lotto 9 continua con l'ordine di [memory/piano.md](memory/piano.md).

## Decisioni che servono all'utente

- Il lotto delle 13 issue aperte senza lotto, fra cui ICH-542 (High) e quattro Medium: elenco e note in
  [memory/piano.md](memory/piano.md), «Issue senza lotto». Per il criterio della priorità ICH-542 e le Medium
  verrebbero prima dei lotti Low. ICH-591 e ICH-592 toccano lo stesso codice di `plane.rb` e possono stare in un lotto.
  La scelta non blocca il lotto 9.
- Lingua delle issue su Linear: le issue del lotto 8d e le tre nuove sono in italiano (regola 15, scelta dell'utente
  del 2026-11-23); le issue più vecchie sono in inglese. Tradurle o no.
