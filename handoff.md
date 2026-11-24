# Handoff — prossima sessione

Aggiornato il 2026-11-24. Questo file dice solo cosa fare nella prossima sessione. Le regole di lavoro sono in
[CLAUDE.md](CLAUDE.md), la memoria del progetto in [memory/indice.md](memory/indice.md).

## Stato

- Ultimo merge su `master`: PR #37 (lotto 9c: ICH-594), commit `dc17aa2`. Dopo il merge `master` ha solo commit di
  documentazione con `[skip ci]`: il codice è quello di `dc17aa2`.
- Nessun lotto in corso: nessun worktree, nessuna PR aperta.
- Ultima suite su `master` (`dc17aa2`): 1357 esempi, 0 fallimenti, 1 pending, con la coverage (98,1 % righe, 90,2 %
  rami) e con il seme 42889. CI di `master` verde (run `45419175222`, tentativo 2: il primo ha avuto un timeout di
  `archive.archlinux.org`).
- Fase «Issue in Backlog»: lotti 1–9c fatti. Il prossimo lavoro sono i 3 studi di design, nell'ordine ICH-600 (Fiber
  al posto dei thread di `Notcurses::UI`), ICH-601 (Ractor), ICH-602 (GVL del rasterize); poi i gruppi A, B, C, i
  lotti 10–14, i gruppi D–G e il lotto 15 ([memory/piano.md](memory/piano.md)). ICH-603, nata nel lotto 9c, è in
  Backlog senza gruppo. ICH-463 resta in Blocked, in attesa di un rilascio di notcurses con il fix.

## Prossimo passo

1. Esegui i passi 1–5 di «Come riprendere il lavoro» in [CLAUDE.md](CLAUDE.md).
2. Prepara lo studio ICH-600: leggi la issue su Linear, [memory/prestazioni.md](memory/prestazioni.md) (sezione
   «Concorrenza in Ruby») e [memory/fase3-design.md](memory/fase3-design.md). Uno studio produce un design approvato
   dall'utente, un prototipo misurato e le issue di implementazione ([memory/piano.md](memory/piano.md), «Studi di
   design»). Il workflow dei lotti non copre gli studi: proponi all'utente come condurlo (dove sta il prototipo,
   quali misure, dove va il design) e aspetta la sua scelta prima di scrivere codice.

## Decisioni che servono all'utente

- Come condurre gli studi di design ICH-600…ICH-602: worktree e branch per il prototipo, forma e posto del design.
- Gruppo e momento di ICH-603. Prima del fix serve una prova su Ghostty e Kitty con un display: su `ncvt` lo schermo
  perde l'allineamento con lo stdplane che scorre, ma il difetto può essere di `ncvt`.
- Permessi Linear: il classificatore lascia passare `issueCreate` e blocca `issueUpdate` («External System Writes»).
  Per cambiare una issue serve una regola di permesso, oppure l'utente lancia la mutation che la skill prepara.
