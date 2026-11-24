# Handoff — prossima sessione

Aggiornato il 2026-11-24. Questo file dice solo cosa fare nella prossima sessione. Le regole di lavoro sono in
[CLAUDE.md](CLAUDE.md), la memoria del progetto in [memory/indice.md](memory/indice.md).

## Stato

- Ultimo merge su `master`: PR #36 (lotto 9b: ICH-593, ICH-595), commit `31370a6`. Dopo il merge `master` ha solo
  commit di documentazione con `[skip ci]`: il codice è quello di `31370a6`.
- Lotto 9c in corso, ICH-594 (In Progress): branch `improvments/ICH-594-opus`, worktree
  `.claude/worktrees/improvments+ICH-594-opus`, PR [#37](https://github.com/ichelema/notcursesruby/pull/37) con due
  commit: `6eaf4c0` (il codice) e `6aa6e7a` (il target di `vline` nel benchmark). Il passo 2 del workflow
  (`2_work-issue`) è fatto. Nel worktree c'è il link `notcurses/data` ([memory/ambiente.md](memory/ambiente.md)): senza
  il link 12 spec delle immagini falliscono. La sessione è uscita dal worktree con `ExitWorktree(keep)`.
- CI della PR: la run `45331648868` sul commit `6aa6e7a` era in corso e non verificata. Il commit `6eaf4c0` era verde
  (run `45328491441`).
- Ultima suite sul branch (`6eaf4c0`; `6aa6e7a` cambia solo una stringa del benchmark): 1356 esempi, 0 fallimenti,
  1 pending, con la coverage (98,1 % righe, 90,13 % rami) e in ordine casuale (seme 43544). RuboCop 0 offense, YARD
  100 %, `spec31` 291 esempi senza fallimenti. Le misure prima e dopo sono nel corpo della PR #37 e nel `CHANGELOG.md`.
- Decisioni dell'utente del 2026-11-24 su ICH-594, già scritte su Linear: criterio 1 riscritto (stato letto una volta
  prima della prima scrittura C, riletture solo dopo una scrittura che il C può cambiare), `vline` ≤ 5x, e la memoria
  `Context#checked_egcs` di `putegc` resta (vale se la locale non cambia a contesto aperto).
- Le trappole del lotto sono in Hindsight (retain del 2026-11-24): scrivile in `memory/lezioni.md` alla chiusura.
- Fase «Issue in Backlog»: lotti 1–9b fatti, il 9c è alla PR. Restano i lotti 10–15, 14 issue senza lotto e 3 studi di
  design (ICH-600, ICH-601, ICH-602) ([memory/piano.md](memory/piano.md)). ICH-463 resta in Blocked, in attesa di un
  rilascio di notcurses con il fix.

## Prossimo passo

1. Se non li hai già fatti, esegui i passi 1–5 di «Come riprendere il lavoro» in [CLAUDE.md](CLAUDE.md). Il lotto 9c è
   già al passo 2: al passo 6 il prossimo passo è il 3 della tabella dei comandi.
2. Controlla la CI della PR con `gh pr checks 37` (exit 0 verde, 8 in corso, altro rosso). Se è rossa, fermati e
   mostrala. Poi proponi il comando qui sotto e fermati: lo lancia l'utente.

   ```text
   /trinity:workflow:2_work-simplify ICH-594 opus
   ```

3. Dopo la semplificazione: `2_work-verify` (passo 4), `3_independent-review ... soft` (passo 5), merge dell'utente
   (passo 7), poi `5_remove-worktree improvments+ICH-594-opus` (passo 8).
4. Per il verify con `ncvt`: prova sullo schermo le scritture che le spec contano ma non guardano: `putstr` con "\n" su
   un piano che scorre e sullo stdplane che scorre (il render a metà testo), `putstr` e `putegc` con `stained: true`,
   `puttext` con `align:` su più righe, glifi larghi sul bordo destro, `hline` e `vline` con una stringa e con una
   `Cell`.
5. Per la review (regole 23 e 24), punti nuovi da provare: lo stato di `WriteState` dopo una scrittura che cambia il
   piano (resize callback, autogrow, scroll dello stdplane), il calcolo del cursore su un piano fermo (`advance!`), la
   larghezza del primo carattere calcolata solo se il testo non entra, la scansione dei byte di `TEXT_SUSPECTS`, e la
   memoria `Context#checked_egcs` (errori mai ricordati, 4096 voci). Limite noto, scritto anche nella PR: `puttext` su
   più righe con caratteri composti segmenta ancora ogni riga una volta, oltre al controllo del testo intero.
6. Alla chiusura dopo il merge, oltre ai passi di CLAUDE.md: aggiorna `memory/prestazioni.md` con le misure «dopo» e
   aggiungi `benchmark/plane_writes.rb` ai comandi in `memory/comandi.md`.

## Decisioni che servono all'utente

Nessuna su ICH-594. Restano aperte due decisioni di prima:

- Permesso `issueCreate`: l'utente prova la regola `Bash(mise x python -- python scripts/linear.py mutation:*)` in
  `~/.claude/settings.json`, cioè in `.chezmoitemplates/claude-settings.json` del sorgente chezmoi (lista `allow`),
  poi `chezmoi apply`. Il classificatore ha bloccato la modifica del modello («Self-Modification»). Al primo bisogno
  di una issue nuova prova `issueCreate`: se il classificatore blocca ancora, torna agli script dell'utente.
- Traduzione delle issue inglesi: fatta il 2026-11-24 per 24 issue, con un controllo con script. L'utente non ha ancora
  riletto un campione: se trova errori nei criteri di accettazione, gli originali inglesi sono nella cronologia delle
  issue su Linear. I titoli in `memory/piano.md` sono ancora in inglese.
