# Handoff — prossima sessione

Aggiornato il 2026-11-28. Questo file dice solo cosa fare nella prossima sessione. Le regole di lavoro sono in
[CLAUDE.md](CLAUDE.md), la memoria del progetto in [memory/indice.md](memory/indice.md).

## Stato

- Ultimo merge su `master`: PR #45 (studio ICH-601, calcolo in Ractor), commit `5be7b06`. Prima: PR #44 (le due suite
  della CI in job paralleli), commit `0ac533d`. Dopo `5be7b06` `master` ha solo commit di documentazione con
  `[skip ci]`.
- Nessun lotto in corso: nessun worktree, nessuna PR aperta. ICH-601 è Done; la sua issue di implementazione ICH-608
  è in Backlog, nel gruppo J di [memory/piano.md](memory/piano.md).
- Ultima suite: la CI di `master` su `5be7b06` è verde, 10 job su 10 (run `46113670551`).
- Fase «Issue in Backlog»: lotti 1–9c, studi ICH-600 e ICH-601 e lotti 16–18 fatti; 32 issue aperte. Ordine scelto
  dall'utente ([memory/piano.md](memory/piano.md)): studio ICH-602, gruppo I (ICH-605), poi gruppi A, B, C, lotti
  10–14, gruppi D, E, F, G, lotto 15. ICH-603 e ICH-608 (gruppo J) non hanno ancora un posto nell'ordine. ICH-463
  resta in Blocked.
- `CLAUDE.md` nel checkout principale ha una modifica non committata che non viene dalla chiusura dello studio: la
  regola «Memoria nel piano» del workflow e una riga nella sezione «Hindsight».

## Prossimo passo

1. Esegui i passi 1–5 di «Come riprendere il lavoro» in [CLAUDE.md](CLAUDE.md). Prima del `git pull --ff-only`
   chiedi all'utente che cosa fare della modifica non committata di `CLAUDE.md` (sezione «Stato»).
2. Lotto successivo: lo studio di design ICH-602 (rilascio del GVL durante il rasterize: su un terminale lento il
   render ferma tutti i thread Ruby). Leggi la issue su Linear con il commento del 2026-11-24, la sezione «Studi di
   design» di [memory/fase-backlog.md](memory/fase-backlog.md), [memory/prestazioni.md](memory/prestazioni.md)
   (render a 100 KB/s) e il punto 9 della sezione 4 di [memory/studio-fiber.md](memory/studio-fiber.md). Lo studio
   tocca la Fase 1 (regola 1: serve l'approvazione dell'utente) e la regola 3. Gli studi ICH-600 e ICH-601 sono il
   modello: design, prototipo misurato in `benchmark/`, issue di implementazione, nessun cambio in `lib/`, e ogni
   fatto del documento provato da uno script committato ([memory/lezioni.md](memory/lezioni.md), sezione «Review»).
3. Esegui il passo 0 del workflow: spiega all'utente il problema, la domanda dello studio, i dati già misurati e le
   scelte aperte di ICH-602. Poi proponi il comando:

   ```text
   /trinity:workflow:1_create-worktree master ICH-602 opus
   ```

4. Nel worktree il gate si lancia con `.claude/scripts/gate`, che crea anche il link `notcurses/data`
   ([memory/comandi.md](memory/comandi.md)).

## Decisioni che servono all'utente

- La modifica non committata di `CLAUDE.md` (regola «Memoria nel piano»): committarla o scartarla.
- Il posto di ICH-608 (gruppo J, `app.background`) nell'ordine dei lavori. Prima del fix servono due scelte: il nome
  del metodo con cui il job controlla la cancellazione e il meccanismo di cancellazione, perché il thread interno del
  prototipo costa circa 1 s e `kill` più `join` si blocca su Ruby 3.4.12 ([memory/studio-ractor.md](memory/studio-ractor.md),
  punto 4).
- Gruppo e momento di ICH-603. Prima del fix serve una prova su Ghostty e Kitty con un display: su `ncvt` lo schermo
  perde l'allineamento con lo stdplane che scorre, ma il difetto può essere di `ncvt`.
