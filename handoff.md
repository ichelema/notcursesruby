# Handoff — prossima sessione

Aggiornato il 2026-11-23. Questo file dice solo cosa fare nella prossima sessione. Le regole di lavoro sono in
[CLAUDE.md](CLAUDE.md), la memoria del progetto in [memory/indice.md](memory/indice.md).

## Stato

- Ultimo merge su `master`: PR #35 (lotto 9: ICH-230), commit `51aebe3`, il 2026-11-23. Dopo il merge `master` ha
  solo commit di documentazione con `[skip ci]`: il codice è quello di `51aebe3`. Nessun lotto in corso e nessun
  worktree di lotto aperto.
- Fase «Issue in Backlog»: lotti 1–9 fatti. Restano i lotti 9b–15 e 15 issue senza lotto
  ([memory/piano.md](memory/piano.md)). ICH-463 resta in Blocked, in attesa di un rilascio di notcurses con il fix.
- Ultima suite su `master` (`51aebe3`): 1330 esempi, 0 fallimenti, 1 pending, con la coverage e con i semi 1234, 4242
  e 7; coverage 98,11 % di righe e 90,11 % di rami; RuboCop 0 offense; YARD 100 %. CI di `master` verde (run
  `45244125178`, dopo il rilancio del job Ruby 4.0.9 fermato da un timeout di `archive.archlinux.org`).
- Le scritture su Linear dalla sessione passano dalla regola `Allow` per
  `Bash(mise x python -- python scripts/linear.py mutation:*)` in `.claude/settings.local.json`: senza, il
  classificatore dei permessi le blocca.

## Prossimo passo

1. Se non li hai già fatti, esegui i passi 1–5 di «Come riprendere il lavoro» in [CLAUDE.md](CLAUDE.md).
2. Il prossimo lotto è il **lotto 9b** (`bug`): ICH-593 (Medium), «Evitare che un processo fermo nelle spec di
   pty_spec.rb blocchi l'intera suite fino al timeout di 600 s», prima degli altri lotti per scelta dell'utente. La
   issue ha già criteri e test richiesti. La causa del blocco di `pty_spec.rb:845` è trovata; quella di
   `pty_spec.rb:744` no ([memory/lezioni.md](memory/lezioni.md), «Test e coverage»).
3. Spiega la issue all'utente (passo 0 del workflow). Poi proponi il comando qui sotto e fermati: lo lancia
   l'utente. Il branch atteso è `bug/ICH-593-opus`.

   ```text
   /trinity:workflow:1_create-worktree master ICH-593 opus
   ```

4. Dopo il lotto 9b continua con l'ordine di [memory/piano.md](memory/piano.md).

## Decisioni che servono all'utente

- `LogView`: una riga finita che arriva in un solo blocco resta intera, quindi può superare `max_partial_bytes` di al
  massimo un blocco (fuori scope di ICH-230 per scelta dell'utente). Aprire una issue o no.
- Il lotto delle 15 issue aperte senza lotto, fra cui ICH-542 (High) e quattro Medium: elenco e note in
  [memory/piano.md](memory/piano.md), «Issue senza lotto». ICH-591, ICH-592 e ICH-594 toccano lo stesso codice di
  `plane.rb`. La scelta non blocca il lotto 9b.
- Lingua delle issue su Linear: le issue dal lotto 8d in poi sono in italiano (regola 15, scelta dell'utente del
  2026-11-23); le issue più vecchie sono in inglese. Tradurle o no.
