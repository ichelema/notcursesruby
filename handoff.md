# Handoff — prossima sessione

Aggiornato il 2026-11-28. Questo file dice solo cosa fare nella prossima sessione. Le regole di lavoro sono in
[CLAUDE.md](CLAUDE.md), la memoria del progetto in [memory/indice.md](memory/indice.md).

## Stato

- Ultimo merge su `master`: PR #42 (cache dei database di pacman nella CI, fuori dai lotti), commit `a37e000`; prima,
  PR #41 (lotto 18, ICH-607, `app.async` e `Task`), commit `84e4cd6`. Dopo `a37e000` `master` ha solo commit di
  documentazione con `[skip ci]`.
- Nessun lotto in corso: nessun worktree, nessuna PR aperta. ICH-607 è Done; il gruppo H è chiuso.
- Ultima suite su `master` (`a37e000`): 1423 esempi, 0 fallimenti, 1 pending, con la coverage (98,12 % righe,
  89,77 % rami) e con il seme 31494. CI di `master` verde (run `46090431364`), che ha salvato la cache
  `pacman-2026/10/26-v2`: dalle run seguenti lo step dei pacchetti non usa `archive.archlinux.org`.
- Fase «Issue in Backlog»: lotti 1–9c, studio ICH-600 e lotti 16–18 fatti; 32 issue aperte. Ordine scelto
  dall'utente ([memory/piano.md](memory/piano.md)): studio ICH-601, studio ICH-602, gruppo I (ICH-605), poi gruppi
  A, B, C, lotti 10–14, gruppi D, E, F, G, lotto 15. ICH-603 è in Backlog senza gruppo. ICH-463 resta in Blocked.

## Prossimo passo

1. Esegui i passi 1–5 di «Come riprendere il lavoro» in [CLAUDE.md](CLAUDE.md).
2. Lotto successivo: lo studio di design ICH-601 (calcolo parallelo in Ractor, con il wrapper nel Ractor principale).
   Leggi la issue su Linear con i commenti, la sezione «Studi di design» di
   [memory/fase-backlog.md](memory/fase-backlog.md) e [memory/prestazioni.md](memory/prestazioni.md) (API dei
   Ractor diversa fra Ruby 3.x e 4.0). Lo studio ICH-600 è il modello: design, prototipo misurato in `benchmark/`,
   issue di implementazione, nessun cambio in `lib/` ([memory/studio-fiber.md](memory/studio-fiber.md)).
3. Esegui il passo 0 del workflow: spiega all'utente il problema, la domanda dello studio, i dati già misurati e le
   scelte aperte di ICH-601. Poi proponi il comando:

   ```text
   /trinity:workflow:1_create-worktree master ICH-601 opus
   ```

4. Nel worktree crea il link `notcurses/data` prima del primo gate ([memory/comandi.md](memory/comandi.md)).

## Decisioni che servono all'utente

- Gruppo e momento di ICH-603. Prima del fix serve una prova su Ghostty e Kitty con un display: su `ncvt` lo schermo
  perde l'allineamento con lo stdplane che scorre, ma il difetto può essere di `ncvt`.
- Permessi Linear: il 2026-11-27 il classificatore ha bloccato due volte `issueUpdate` di ICH-607 («External System
  Writes»), anche dopo il «procedi» dell'utente; l'automazione GitHub → Linear ha spostato la issue all'apertura
  della PR. `commentCreate` passa. Per il passaggio a In Progress di `2_work-issue` serve una regola di permesso, o
  l'utente sposta la issue a mano.
