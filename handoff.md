# Handoff — prossima sessione

Aggiornato il 2026-11-23. Questo file dice solo cosa fare nella prossima sessione. Le regole di lavoro sono in
[CLAUDE.md](CLAUDE.md), la memoria del progetto in [memory/indice.md](memory/indice.md).

## Stato

- Ultimo merge su `master`: PR #33 (lotto 8c: ICH-576, ICH-580, ICH-577, ICH-581), commit `38d4a8c`, il
  2026-11-23. Nessun lotto in corso e nessun worktree di lotto aperto.
- Fase «Issue in Backlog»: lotti 1–8c fatti. Restano i lotti 8d–15 e 10 issue senza lotto
  ([memory/piano.md](memory/piano.md)). ICH-463 resta in Blocked, in attesa di un rilascio di notcurses con il fix.
- Ultima suite su `master` (`38d4a8c`): 1315 esempi, 0 fallimenti, 1 pending, in ordine normale e con i semi 1234,
  4242 e 7; coverage 98,16 %; RuboCop 0 offense; YARD 100 %. CI di `master` verde (run `45089245360`).

## Prossimo passo

1. Se non li hai già fatti, esegui i passi 1–5 di «Come riprendere il lavoro» in [CLAUDE.md](CLAUDE.md).
2. Il prossimo lotto è il **lotto 8d** (`bug`), scelto dall'utente il 2026-11-22: ICH-582 e ICH-586, tutte e due Low
   e nate dal lotto 8b. Toccano il codice di grapheme ed egcpool del lotto 8b (`plane.rb`, `cell.rb`). Leggi le due
   issue per intero su Linear: i criteri di accettazione e i test richiesti sono la checklist del lotto.
   - ICH-582: con l'egcpool pieno le scritture con una `Cell` sollevano `CellError` invece di `PlaneError`. La issue
     elenca i metodi (`putc`, `hline`, `vline`, `polyfill`, `box`/`perimeter`, `gradient`) e chiede anche messaggi
     senza l'EGC intero e la misura di `set_base`. Dopo il lotto 8b `gradient` solleva già `PlaneError` dal C:
     controlla ogni metodo per classe, messaggio e piano invariato.
   - ICH-586: notcurses conta 2 colonne per una bandiera, `ncvt` (libghostty-vt 1.0.1) ne disegna 4, quindi il testo
     dopo la bandiera si sposta. La issue chiede di misurare la bandiera e l'indicatore regionale singolo su Ghostty
     (`ncvt`) e su Kitty, e una scelta di comportamento dell'utente prima del fix, anche per il testo di
     `Notcurses::UI`.
3. Spiega le due issue all'utente (passo 0 del workflow). Poi proponi il comando qui sotto e fermati: lo lancia
   l'utente. Il branch atteso è `bug/ICH-582-586-opus`.

   ```text
   /trinity:workflow:1_create-worktree master ICH-582 ICH-586 opus
   ```

4. Dopo il worktree, prima di `2_work-issue`, chiedi all'utente la scelta di comportamento di ICH-586 (regola 14).
   Sulla VPS la sessione non ha un display: lì la misura su Kitty la fa l'utente, oppure proponigli di cambiare il
   criterio.
5. Dopo il lotto 8d continua con l'ordine di [memory/piano.md](memory/piano.md).

## Decisioni che servono all'utente

- Il lotto delle 10 issue aperte senza lotto, fra cui ICH-542 (High) e quattro Medium: elenco e note sono in
  [memory/piano.md](memory/piano.md), «Issue senza lotto». Per il criterio della priorità verrebbero prima dei lotti
  Low. La scelta non blocca il lotto 8d.
