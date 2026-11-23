# CLAUDE.md — notcursesruby

notcursesruby è il binding Ruby completo di notcurses 3.0.17, in Ruby puro sulla gem `ffi`: layer FFI raw, wrapper
idiomatico e framework `Notcurses::UI`. Questo file contiene le regole di lavoro; le regole vincolanti sono in
[memory/regole.md](memory/regole.md). Il prossimo passo è in [handoff.md](handoff.md), i fatti del progetto sono in
[memory/indice.md](memory/indice.md).

## Struttura delle cartelle

| Percorso | Contenuto |
|---|---|
| `lib/notcurses/ffi/`, `lib/notcurses/ffi.rb` | Fase 1, layer FFI raw (`Notcurses::FFI`): cambialo solo con l'approvazione dell'utente (regola 1) |
| `lib/notcurses/` | Fase 2, wrapper idiomatico: `Context`, `Plane`, `Visual`, `Direct`, `Cell`, `Guard`, `Util` e gli altri |
| `lib/notcurses/widgets/` | Widget di notcurses: `Reader`, `Menu`, `Tree`, `Tabbed`, `Plot` e gli altri |
| `lib/notcurses/ui/` | Fase 3, framework `Notcurses::UI`: `EventLoop`, `App`, contenitori, `Dialog`, `TextInput` e gli altri componenti |
| `spec/` | Suite RSpec: unità in `spec/notcurses/`, pty in `spec/integration/`, prove grafiche in `spec/graphics/` (`NC_GRAPHICS=1`), helper in `spec/support/` |
| `examples/` | `demo.rb`, nel pacchetto della gem |
| `notcurses/` | Submodule: sorgenti C di notcurses 3.0.17, per leggere i percorsi C (regola 20) |
| `libnotcurses-sys/` | Submodule: binding Rust di notcurses, riferimento della Fase 1 |
| `.github/workflows/ci.yml` | CI: matrice Ruby 3.1–4.0 in un container Arch Linux |
| `handoff.md` | Cosa fare nella prossima sessione |
| `memory/` | Memoria del progetto, con l'indice in `memory/indice.md` |
| `CHANGELOG.md` | Una voce per ogni fix in `[Non rilasciato]` (regola 11) |
| `hindsight.config.json` | Missioni e pagine del bank Hindsight del progetto |
| `.claude/skills/` | Skill del progetto: `notcurses-man` (man page e header di notcurses), `verify` (terminale headless `ncvt` e script `screen`), `context7-mcp` |
| `.claude/scripts/spec31` | Spec con Ruby 3.1.7 (regola 21) |
| `.claude/rules/context7.md` | Quando usare Context7 |
| `.claude/worktrees/` | Worktree dei lotti, creati da `1_create-worktree` |

## Come riprendere il lavoro

Quando l'utente chiede di riprendere o di continuare (per esempio: riprendi, continua, vai):

1. Controlla di essere nel checkout principale su `master`. Se la sessione è aperta nel worktree di un lotto in corso
   (`2_work-issue` prevede questo caso), salta il passo 2 e ai passi 3 e 6 usa `handoff.md` del checkout principale.
   Se sei su un altro branch, fermati e chiedi all'utente.
2. Porta `master` in pari con `git pull --ff-only origin master`.
3. Leggi [handoff.md](handoff.md) per intero. Confronta lo stato che descrive con git, la CI e Linear: se non
   coincide, vale lo stato reale; dillo all'utente in una riga.
4. Fai il recall in Hindsight sul lavoro del prossimo passo (sezione «Hindsight»).
5. Leggi [memory/indice.md](memory/indice.md) e apri solo i file che servono al passo. Per un lotto servono sempre
   [memory/regole.md](memory/regole.md) e [memory/piano.md](memory/piano.md).
6. Esegui il prossimo passo dello stato reale. Di solito è il «Prossimo passo» di `handoff.md`. Se al passo 3 lo stato
   non coincide, ricavalo dallo stato reale: per esempio, con il worktree del lotto già creato, il passo del workflow
   che segue.

## Workflow di un lotto

Un lotto è un gruppo di issue corrette in un worktree, un branch e una PR. Le issue sono nel progetto Linear
`notcursesruby` (team `ICH`): per leggerle e cambiarle usa la skill `trinity:linear`. L'ordine dei lotti, i criteri
per comporli e le issue senza lotto sono in [memory/piano.md](memory/piano.md). Le regole vincolanti sono in
[memory/regole.md](memory/regole.md): leggile per intero prima di `2_work-issue`. Valgono come regole di questo file,
anche per le review. I comandi di suite, coverage e prove sono in [memory/comandi.md](memory/comandi.md).

### Comandi

L'utente lancia i comandi della tabella: il modello non può invocarli. Proponi il comando con i suoi argomenti in un
blocco di codice e fermati. `<ID...>` sono gli ID delle issue del lotto, nell'ordine di `memory/piano.md`.
`<modello>` è il suffisso scelto al passo 1 (finora sempre `opus`): i comandi successivi lo usano per trovare il
worktree, quindi resta lo stesso anche se la sessione usa un altro modello.

| Passo | Comando | Cosa fa |
|---|---|---|
| 0 | — | Spiega all'utente le issue del lotto (regola «Passo 0»), poi proponi il passo 1 |
| 1 | `/trinity:workflow:1_create-worktree master <ID...> <modello>` | Crea il branch `<prefisso>/<ID-numeri>-<modello>` (per esempio `bug/ICH-582-586-opus`) e il worktree in `.claude/worktrees/` |
| 2 | `/trinity:workflow:2_work-issue <ID...> <modello>` | Porta le issue a In Progress, scrive il piano, implementa e apre la PR, senza merge |
| 3 | `/trinity:workflow:2_work-simplify <ID...> <modello>` | Semplifica il codice della PR |
| 4 | `/trinity:workflow:2_work-verify <ID...> <modello>` | Prova la PR su un terminale headless con `ncvt` (skill `.claude/skills/verify/`) |
| 5 | `/trinity:workflow:3_independent-review <ID...> <modello> soft` | Review avversaria in sola lettura con Sonnet. Con dei finding, correggi quelli che sceglie l'utente, poi lancia una review mirata con lo stesso comando |
| 6 | `/trinity:workflow:4_review-fix-loop <ID...> <modello>` | Al posto della review mirata, se l'utente lo sceglie: due review in parallelo e fix in al massimo 3 round |
| 7 | Merge della PR | Lo fa l'utente, alle condizioni della regola «Merge» |
| 8 | `/trinity:workflow:5_remove-worktree <prefisso>+<ID-numeri>-<modello>` | Rimuove worktree e branch ed esegue «Chiusura dopo il merge» |

I passi 3–5 sono la catena dei lotti 7, 8b e 8c. Il lotto 8 ha saltato la review: l'utente era assente e ha
autorizzato il merge.

### Regole

- **Passo 0** (scelta dell'utente del 2026-11-18): prima del worktree, per ogni issue spiega in modo chiaro il
  problema, la causa, i dati misurati e le scelte aperte. Aggiungi un esempio (codice, sequenza di eventi o figura)
  quando l'esempio rende la spiegazione più chiara. Le domande della regola 14 vengono dopo il worktree, prima di
  `2_work-issue`.
- **Un lotto alla volta**: ogni lotto parte da `master` aggiornato, dopo il merge del lotto precedente.
- **Commit**: un commit per issue, Conventional Commits in inglese con scope (regola 15). Per ogni issue la spec che
  fallisce, il fix e la suite completa (regola 11).
- **Prima della PR e dopo ogni round di fix della review**: suite completa in ordine normale e con i semi 1234, 4242
  e 7, coverage e `bundle exec rubocop`. Nel lotto 8c la prima CI è fallita per una spec che dipendeva dall'ordine e
  per la coverage, provate prima solo in ordine normale. Se il diff tocca grapheme o Unicode, esegui le spec cambiate
  anche con `.claude/scripts/spec31` (regola 21). Prova sulla superficie ogni consiglio nuovo nei messaggi d'errore,
  nello YARD o nel `CHANGELOG` (regola 22): il piano di `2_work-issue` elenca i consigli e come provarli.
- **PR**: nel corpo scrivi `Fixes ICH-<n>` per ogni issue che la PR risolve, ognuno sulla sua riga. Per una issue del
  lotto che la PR non risolve usa `Refs ICH-<n>` (lotto 4: ICH-463). Non citare issue fuori dal lotto, neanche con
  `Refs`: l'automazione GitHub → Linear le sposta a In Progress. Dopo ogni evento della PR controlla lo stato delle
  issue in Linear.
- **CI**: dopo l'apertura della PR, e prima della review, segui la CI con `gh pr checks <n> --watch` (ICH-465: un job
  rosso è emerso solo nella review). Ripeti il controllo dopo ogni push di fix.
- **Merge**: chiedi il merge all'utente (regola 13) solo quando valgono tre condizioni: CI verde sull'ultimo commit
  della PR (regola 17), nessun `FAIL` o `BLOCKED` aperto del verify, nessun finding BLOCKER o HIGH aperto della
  review. Se un fix arrivato dopo il verify cambia quello che si vede (schermo, messaggi, consigli della regola 22),
  rilancia prima `2_work-verify` sull'ultimo commit. Il classificatore dei permessi blocca il merge fatto dal modello
  («Merge Without Review») anche con il sì dell'utente: chiedi all'utente di eseguire `gh pr merge <n> --merge`. Dopo
  il merge Linear porta le issue a Done.
- **Acceptance criteria**: se un criterio si rivela sbagliato o impossibile, non cambiarlo da solo. Proponi il testo
  nuovo all'utente e, dopo la conferma, aggiorna la issue su Linear.
- **Review**: `4_review-fix-loop` lancia una review con `gpt-bridge:reviewer` e una con `trinity:reviewer` su Fable.
  Per la seconda passa `model: sonnet` ed `effort: max` al posto di Fable (scelta dell'utente del 2026-11-18). Il
  comando crea le issue dei finding residui senza chiedere: in questo progetto chiedi prima la conferma all'utente
  (regola 16). Le istruzioni per i reviewer sono le regole 23 e 24 di [memory/regole.md](memory/regole.md).
- **Worktree**: `git worktree remove` rifiuta un worktree con il submodule inizializzato. In un worktree di lotto usa
  `--force` solo se il worktree ha in più il submodule `notcurses` e `git status` è vuoto (scelta dell'utente del
  2026-11-08); negli altri casi chiedi conferma all'utente. Con il link di `notcurses/data`
  ([memory/ambiente.md](memory/ambiente.md)) il submodule nei worktree non serve. Nei worktree di review vale la
  «Pulizia» di `3_independent-review`, che vieta `--force`.

### Chiusura dopo il merge

`5_remove-worktree` esegue questa procedura dopo il merge, per intero e in ordine, senza aspettare che l'utente la
chieda. La chiusura si può eseguire anche da sola, senza `5_remove-worktree`, da una sessione nel checkout principale:
in questo caso porta prima `master` in pari con `git pull --ff-only origin master`. Prima dei controlli e prima di
scrivere, controlla che il checkout principale sia su `master`, allineato a `origin/master`, e che `git status` sia
vuoto: così i controlli provano il codice di `origin/master`. Se una condizione manca, non scrivere e non committare:
segnala all'utente che la chiusura resta da fare.

1. Esegui su `master` i «Controlli finali» di [memory/piano.md](memory/piano.md), compresa la CI della PR e di
   `master`. Controlla in Linear che le issue del lotto siano a Done, oppure nello stato scelto con l'utente (lotto 4:
   ICH-463 in Blocked).
2. In `memory/bug-notcurses.md` i bug di notcurses nuovi del lotto, nella tabella della loro area (regola 11).
3. In `memory/backlog-issue.md` il capitolo del lotto: Fix, Decisioni, Review, Problemi e soluzioni, cambi a `Gemfile`
   e `Gemfile.lock` (regola 12), Verifica finale.
4. In `memory/piano.md` togli il lotto da «Lotti da fare», aggiorna «Avanzamento» e metti le issue nuove in «Issue
   senza lotto». Le lezioni durevoli del lotto vanno nel file del tema in `memory/`.
5. Committa i file dei passi 2–4 con `docs(memory): lotto <n> ... [skip ci]`.
6. Fai il retain in Hindsight (sezione «Hindsight»).
7. Riscrivi [handoff.md](handoff.md) (sezione «Come scrivere handoff.md»).

### Come scrivere handoff.md

[handoff.md](handoff.md) dice solo cosa fare nella prossima sessione. Riscrivilo per intero quando l'utente chiude la
sessione e alla fine di «Chiusura dopo il merge». Scrivilo nel checkout principale, su `master`: la sessione nuova
legge quel file. Committalo da solo con `docs(handoff): <stato in breve> [skip ci]` e fai il push. Se la sessione è
in un worktree e non può scrivere nel checkout principale, mostra all'utente il testo nuovo e chiedigli di salvarlo da
una sessione nel checkout principale. Tre sezioni:

- **Stato**: data, ultimo merge su `master` (PR e commit), lotto, branch, worktree e PR in corso, ultima suite.
- **Prossimo passo**: passi numerati, con il comando da proporre all'utente. Il primo passo rimanda ai passi 1–5 di
  «Come riprendere il lavoro».
- **Decisioni che servono all'utente**: le domande aperte, oppure «Nessuna».

Non scrivere in `handoff.md` la storia del lavoro (è in git, in Linear e in `memory/backlog-issue.md`) né i fatti
durevoli (vanno in `memory/`).

## Memoria del progetto

- [memory/indice.md](memory/indice.md) è l'indice: un tema per file, una riga per file. Leggi l'indice e apri solo i
  file che servono.
- La memoria è un consiglio, non la fonte di verità: controlla ogni fatto mutabile su codice, test, git, CI e Linear.
  Fa eccezione [memory/regole.md](memory/regole.md): le sue regole sono vincolanti.
- Scrivi solo fatti durevoli e controllati sul codice o con un test.
- Aggiorna il file del tema e non creare duplicati. Per un tema nuovo crea un file e aggiungi la sua riga all'indice.
- Quando un fatto cambia, correggi la riga: la storia resta in git.
- I log delle fasi e dei lotti (`backlog-issue.md`, `correzioni-review.md`, `review-2026-11-06.md`, `fase*.md`) sono
  storia: aggiungi solo il capitolo di un lotto nuovo.
- Non scrivere in `memory/` il prossimo passo (va in `handoff.md`), le regole di lavoro (vanno in questo file) e i
  segreti. Le regole vincolanti stanno solo in `memory/regole.md`.
- Bug nuovi e lavoro futuro vanno in Linear, con la conferma dell'utente (regola 16). In
  [memory/punti-aperti.md](memory/punti-aperti.md) stanno solo i difetti sospetti che non sono ancora issue: quando
  un punto diventa una issue o si chiude, rimuovi la sua voce.

## Hindsight

Hindsight è la memoria a lungo termine tra le sessioni: tiene cause radice, decisioni, approcci scartati e trappole
che non stanno nel repository. Per il formato completo carica la skill `trinity:hindsight`.

- Il bank è `notcursesruby`: lo shim MCP lo ricava dal remote `origin`. Usa i tool `mcp__hindsight__*`, non comandi
  shell. L'unica eccezione è la lettura completa di un periodo con `curl` in GET, descritta nella skill.
- Recall e retain automatici sono spenti: li chiami tu. All'avvio un hook mostra le pagine di conoscenza del bank:
  sono un consiglio, come il recall.
- **Recall** (`mcp__hindsight__recall`) alla ripresa e all'inizio di ogni lotto, con una query sulle issue, sul
  codice e sui componenti del lotto:

  ```json
  {"query": "<issue, file e componenti del lotto>", "budget": "high", "tags": ["claude-code", "repo:notcursesruby"], "tags_match": "any"}
  ```

- **Retain** (`mcp__hindsight__retain`) al passo 6 della chiusura e alla fine di ogni task significativo fuori dai
  lotti: cause radice, correzioni (file e metodo), decisioni dell'utente con la motivazione, approcci scartati e
  trappole delle spec. Il retain è asincrono: restituisce un `operation_id`, e i fatti diventano cercabili quando
  l'estrazione finisce.
  - `context`: una sola riga, che inizia con `Claude Code riferisce il proprio lavoro:` e nomina il dominio, per
    esempio `Claude Code riferisce il proprio lavoro: notcursesruby, lotto 8c delle issue in Backlog (init con un
    terminale muto)`.
  - `content`: testo ricco e concreto, in italiano, in forma attiva, con soggetto `Claude Code`. Comandi, path, nomi
    di metodi e di funzioni C, hash e numeri di issue restano alla lettera.
  - `tags`: `["claude-code", "repo:notcursesruby"]`. Aggiungi `branch:<nome>` solo per un fatto valido su un solo
    branch; per un fatto valido in tutti i progetti usa solo `claude-code`. Nessun altro tag.
- Non salvare segreti, stato della sessione, output grezzo dei tool, fatti già nel codice o nella storia git, o
  regole già scritte in questo file o in `memory/regole.md`.
- Per una sintesi su lavoro e decisioni passate usa `mcp__hindsight__reflect`.
- I subagenti non leggono Hindsight: copia nel loro prompt i fatti utili, con la data o la fonte.
- Se il server non risponde, prosegui e dillo in una riga.
