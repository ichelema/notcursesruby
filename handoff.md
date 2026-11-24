# Handoff — prossima sessione

Aggiornato il 2026-11-24. Questo file dice solo cosa fare nella prossima sessione. Le regole di lavoro sono in
[CLAUDE.md](CLAUDE.md), la memoria del progetto in [memory/indice.md](memory/indice.md).

## Stato

- Ultimo merge su `master`: PR #36 (lotto 9b: ICH-593, ICH-595), commit `31370a6`, il 2026-11-24. Dopo il merge
  `master` ha solo commit di documentazione con `[skip ci]`: il codice è quello di `31370a6`. Nessun lotto in corso e
  nessun worktree di lotto aperto.
- Fase «Issue in Backlog»: lotti 1–9b fatti. Restano i lotti 9c e 10–15, 14 issue senza lotto e 3 studi di design
  (ICH-600, ICH-601, ICH-602) ([memory/piano.md](memory/piano.md)). ICH-463 resta in Blocked, in attesa di un rilascio
  di notcurses con il fix.
- Il 2026-11-24 ICH-594 è passata da `Plane#putstr` alle scritture di `Plane`, con criteri e obiettivi nuovi approvati
  dall'utente (testo e commento su Linear). Le misure sono in [memory/prestazioni.md](memory/prestazioni.md).
- Ultima suite su `master` (`31370a6`): 1333 esempi, 0 fallimenti, 1 pending, con la coverage e con il seme 17887;
  coverage 98,11 % di righe e 90,19 % di rami; RuboCop 0 offense; YARD 100 %. CI di `master` verde (run
  `45304171970`).
- Scritture su Linear: la regola `Allow` per `Bash(mise x python -- python scripts/linear.py mutation:*)` in
  `.claude/settings.local.json` copre la skill `trinity:linear`, con la cartella della skill come directory di lavoro.
  Il 2026-11-24 l'aggiornamento di ICH-594 e il commento sono passati, ma il classificatore dei permessi ha bloccato
  `issueCreate`, dalla skill e dalla sessione. L'utente ha creato ICH-600–602 con uno script eseguito da lui.

## Prossimo passo

1. Se non li hai già fatti, esegui i passi 1–5 di «Come riprendere il lavoro» in [CLAUDE.md](CLAUDE.md).
2. Il prossimo lotto è il **lotto 9c** (`improvments`): ICH-594 (Low), «Accelerare le scritture di Plane, che ripetono
   controlli e letture dello stato prima della chiamata C». Il passo 0 è fatto: il 2026-11-24 l'utente ha visto la
   spiegazione e ha approvato il testo nuovo. Proponi il comando qui sotto e fermati: lo lancia l'utente. Il branch
   atteso è `improvments/ICH-594-opus`; ICH-594 ha solo la label `Performance`, quindi `1_create-worktree` può
   chiedere il prefisso: la risposta è `improvments`.

   ```text
   /trinity:workflow:1_create-worktree master ICH-594 opus
   ```

3. Dopo il worktree e prima di `2_work-issue`, le domande della regola 14. Aperta, per esempio: dove sta nel
   repository lo script di misura del criterio 4.
4. Dopo il lotto 9c l'ordine è quello di [memory/piano.md](memory/piano.md): studi ICH-600, ICH-601, ICH-602, poi i
   gruppi A e B, poi i lotti 10–14 (sezioni «Studi di design» e «Issue senza lotto»).

## Decisioni che servono all'utente

Il 2026-11-24 l'utente ha deciso: ordine degli studi (subito dopo il 9c), gruppi A–G delle issue senza lotto (piano.md),
gate con le due suite in parallelo ([memory/comandi.md](memory/comandi.md)), blocco della suite del 2026-11-23 lasciato
in [memory/punti-aperti.md](memory/punti-aperti.md), traduzione in italiano di tutte le issue aperte in inglese.

- Permesso `issueCreate`: l'utente prova la regola `Bash(mise x python -- python scripts/linear.py mutation:*)` in
  `~/.claude/settings.json`, cioè in `.chezmoitemplates/claude-settings.json` del sorgente chezmoi (lista `allow`),
  poi `chezmoi apply`. Il classificatore ha bloccato la modifica del modello («Self-Modification»). Al primo bisogno
  di una issue nuova prova `issueCreate`: se il classificatore blocca ancora, torna agli script dell'utente.
- Traduzione delle issue inglesi: fatta il 2026-11-24 per 24 issue (ICH-214, 219–221, 227, 231, 457, 459–461, 463,
  469, 470, 473, 483, 540–542, 554, 556, 560–562, 567), titolo e descrizione, con 4 agenti `trinity:bulk-worker` e
  un controllo con script (backtick, blocchi di codice, checkbox, numeri, intestazioni). Linear coincide con i file
  tradotti. L'utente non ha ancora riletto un campione: se trova errori nei criteri di accettazione, gli originali
  inglesi sono nella cronologia delle issue su Linear. I titoli in `memory/piano.md` sono ancora in inglese.
