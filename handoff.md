# Handoff — prossima sessione

Aggiornato il 2026-11-23. Questo file dice solo cosa fare nella prossima sessione. Le regole di lavoro sono in
[CLAUDE.md](CLAUDE.md), la memoria del progetto in [memory/indice.md](memory/indice.md).

## Stato

- Ultimo merge su `master`: PR #34 (lotto 8d: ICH-582, ICH-586), commit `964bbf8`, il 2026-11-23. Dopo il merge
  `master` ha solo commit di documentazione con `[skip ci]`: il codice è quello di `964bbf8`.
- **Lotto 9 in corso** (ICH-230, «Bound the unfinished line in LogView#append by bytes»): branch `bug/ICH-230-opus`,
  worktree `.claude/worktrees/bug+ICH-230-opus` (con il link `notcurses/data`), PR
  [#35](https://github.com/ichelema/notcursesruby/pull/35), ultimo commit `2831f61`. Fatti: `2_work-issue`,
  `2_work-simplify`, `2_work-verify` (PASS su `5fbf6d5`), review e review mirata `soft` con i fix dei due finding LOW
  (`5fbf6d5`, `2831f61`). ICH-230 è In Progress su Linear.
- Ultimo gate su `2831f61`: suite con la coverage 1330 esempi, 0 fallimenti, 1 pending, coverage 98,11 % di righe e
  90,11 % di rami; semi 1234 e 7 verdi; il seme 4242 si è fermato una volta in `spec/integration/pty_spec.rb:744` e
  ripetuto è verde; RuboCop 0 offense; YARD 100 %; `spec31` verde. CI verde su `2831f61` dopo il rilancio del job
  Ruby 3.2.11, fermo in `pty_spec.rb:845` (run `45237791816`).
- ICH-593 (nuova, Medium, Backlog): i blocchi della suite in `pty_spec.rb:744` e `:845`. È il lotto 9b, prima degli
  altri lotti per scelta dell'utente ([memory/piano.md](memory/piano.md)).
- Le scritture su Linear dalla sessione passano dalla regola `Allow` per
  `Bash(mise x python -- python scripts/linear.py mutation:*)` in `.claude/settings.local.json`: senza, il
  classificatore dei permessi le blocca.

## Prossimo passo

1. Se non li hai già fatti, esegui i passi 1–5 di «Come riprendere il lavoro» in [CLAUDE.md](CLAUDE.md).
2. Il fix `2831f61` della review mirata cambia quello che si vede in un caso limite: per la regola «Merge» di
   [CLAUDE.md](CLAUDE.md) rilancia il verify sull'ultimo commit. Proponi il comando e fermati: lo lancia l'utente.

   ```text
   /trinity:workflow:2_work-verify ICH-230 opus
   ```

3. Con il verify PASS, la CI verde sull'ultimo commit e nessun finding BLOCKER o HIGH aperto, chiedi all'utente il
   merge: `gh pr merge 35 --merge`.
4. Dopo il merge proponi `/trinity:workflow:5_remove-worktree bug+ICH-230-opus`, che esegue «Chiusura dopo il
   merge».
5. Poi il **lotto 9b** (ICH-593): passo 0 del workflow e `/trinity:workflow:1_create-worktree master ICH-593 opus`.

## Decisioni che servono all'utente

- Una riga finita molto lunga che arriva in un solo blocco resta intera in memoria in `LogView` (fuori scope di
  ICH-230 per scelta dell'utente). Aprire una issue o no.
- Il lotto delle 13 issue aperte senza lotto, fra cui ICH-542 (High) e quattro Medium: elenco e note in
  [memory/piano.md](memory/piano.md), «Issue senza lotto». ICH-591 e ICH-592 toccano lo stesso codice di `plane.rb` e
  possono stare in un lotto. La scelta non blocca i lotti 9 e 9b.
- Lingua delle issue su Linear: le issue dal lotto 8d in poi sono in italiano (regola 15, scelta dell'utente del
  2026-11-23); le issue più vecchie sono in inglese. Tradurle o no.
