# RIPRESA — prompt per la prossima sessione

> Avvio: incolla questo file nella nuova sessione di Claude Code, oppure scrivi «Leggi RIPRESA.md ed esegui il
> prompt». Scritto il 2026-10-26, con il repository su `5c4c35b`.

## Contesto

- **Progetto:** binding Ruby completo per notcurses 3.0.17, in `/mnt/data/Sviluppo/Progetti/notcursesruby`.
  Repository privato https://github.com/ichelema/notcursesruby, branch `master`.
- **Fase 1** (layer FFI raw, `lib/notcurses/ffi.rb` e `lib/notcurses/ffi/`): completa, commit `465418f`.
- **Fase 2** (wrapper Ruby idiomatico, gli altri 28 file di `lib/`, 12 482 righe): completa, commit `7e033bd`. Il
  commit `5c4c35b` ha aggiunto `blocking: true` a 8 funzioni della Fase 1, su richiesta dell'utente.
- **Stato su Ruby 4.0.7:** 802 esempi e 0 fallimenti, anche con i semi `1234`, `4242` e `7`; 0 problemi YARD secondo
  due script euristici; `ruby -w` senza warning; il wrapper chiama 477 delle 631 funzioni FFI, e le altre 154 sono
  escluse con un motivo in `spec/coverage_spec.rb`.
- **Ruby 3.1**, la versione minima dichiarata, non è mai stata eseguita: è controllata solo la sintassi.
- `notcurses/` (sorgenti C) e `libnotcurses-sys/` (binding Rust) sono submodule git. Usa `notcurses/src/` per
  controllare la semantica del C. Non usare `libnotcurses-sys/` come riferimento.

## Obiettivo

1. Esegui una review indipendente della Fase 2. Trova i difetti prima che la Fase 3 costruisca sopra questa API.
2. Correggi i difetti confermati, ognuno con un test.
3. Esegui la suite completa su Ruby 3.1.

La Fase 3 (ciclo degli eventi, focus, resize, widget composti) è fuori scope: non iniziarla.

## Prima di iniziare

1. Fai il recall in Hindsight. Il bank `notcursesruby` si legge via REST (comando in "Comandi"). Il fatto sul build di
   Ruby 3.1 con mise è nel bank predefinito: usa `mcp__hindsight__recall`.
2. Leggi `RICONSEGNA.md`, sezioni "Fase 1" e "Fase 2".
3. Leggi `memory/fase2-wrapper-idiomatico.md`. Per il GVL leggi anche la decisione 20 di `memory/fase1-ffi-raw.md`.
4. Controlla `git status` e `git log --oneline -3`. Il working tree deve essere pulito, su `5c4c35b` o dopo.
5. Avvia subito in background il build di Ruby 3.1.7 (Parte 2, passo 1): dura alcuni minuti e non dipende dalla
   review.

## Regole vincolanti

Le regole vengono dal prompt della Fase 2 e valgono per i fix. La review controlla che il codice le rispetti.

1. Non cambiare la Fase 1 (`lib/notcurses/ffi/`, `lib/notcurses/ffi.rb`). Se un finding richiede un cambio nella
   Fase 1, fermati e chiedi all'utente.
2. Ogni puntatore opaco ha un distruttore (`close` o `destroy`). Il pattern `owned:` copre i puntatori non posseduti,
   per esempio lo stdplane.
3. notcurses non è thread-safe. Il wrapper lo documenta e non aggiunge lock interni.
4. I metodi restituiscono `self` dove il chaining ha senso (`render`, `erase`, `move_cursor`, i setter dei colori).
5. Nomi Ruby: `snake_case`, suffisso `?` per i predicati, nessun prefisso `nc` o `notcurses_`.
6. Ogni ritorno C che indica un errore (-1 o NULL) diventa un'eccezione con un messaggio chiaro.
7. Le opzioni con un default sono keyword arguments. Gli argomenti posizionali servono solo per i parametri
   obbligatori.
8. `define_method` e `method_missing` sono vietati: il codice deve essere leggibile e navigabile con grep.
9. Ogni metodo pubblico ha un commento YARD con `@param`, `@return` e `@raise`.
10. Dipendenze: solo la gem `ffi`. Ruby >= 3.1.

Le deviazioni volute dai pattern del prompt della Fase 2 sono nella tabella "Differenze dai pattern del prompt" di
`memory/fase2-wrapper-idiomatico.md`. La review può contestarle, con un motivo.

## Parte 1 — review della Fase 2

### Metodo

Usa un workflow multi-agente (questo prompt lo autorizza) con al massimo 12 agenti: 6 finder (agenti che cercano i
difetti, per esempio `trinity:reviewer`) e 6 agenti di controllo (per esempio `trinity:deep-reasoner`, che può
scrivere script di prova nello scratchpad).

1. **Finder.** Un agente in sola lettura per area (tabella sotto). Ogni finder riceve le regole vincolanti, i
   criteri, i file della sua area e le spec corrispondenti. Non dare ai finder la memoria della Fase 2 né le tue
   conclusioni: la review deve essere indipendente. Il YARD e i commenti nel codice spiegano già le scelte.
2. **Doppioni e decisioni note.** Unisci i finding uguali. Confronta ogni finding con
   `memory/fase2-wrapper-idiomatico.md` (bug aggirati, bug noti, differenze dai pattern). Un finding che contesta una
   decisione documentata passa al controllo insieme al motivo della decisione.
3. **Controllo avversario.** Un agente per area prova a smentire ogni finding. Una prova è uno script o una spec che
   riproduce il difetto, oppure le righe del C che lo dimostrano. Verdetti: CONFERMATO, PLAUSIBILE, SMENTITO. Nel
   dubbio il verdetto è PLAUSIBILE.
4. Gli script che possono andare in crash girano nello scratchpad, in un processo figlio, con
   `timeout -k 5 -s KILL` e lo stdin da `/dev/null`.

### Aree

| Area | File in `lib/notcurses/` | Righe |
| --- | --- | ---: |
| 1. Nucleo e valori | `context.rb`, `resource.rb`, `error.rb`, `version.rb`, `input.rb`, `stats.rb`, `channel.rb`, `format.rb`, `util.rb`, e `lib/notcurses.rb` | 2 980 |
| 2. Piani | `plane.rb`, `cell.rb` | 2 850 |
| 3. Direct e Visual | `direct.rb`, `visual.rb`, `pixel.rb`, `palette.rb` | 2 671 |
| 4. Selector, MultiSelector, Menu, Reader, ProgBar, Plot | `widgets/widget.rb`, `widgets/selector.rb`, `widgets/multiselector.rb`, `widgets/menu.rb`, `widgets/reader.rb`, `widgets/progbar.rb`, `widgets/plot.rb` | 1 867 |
| 5. Reel, Tree, Tabbed e processi | `widgets/reel.rb`, `widgets/tree.rb`, `widgets/tabbed.rb`, `fd_plane.rb`, `subprocess.rb` | 2 114 |
| 6. Trasversale | API pubblica di tutte le classi | — |

Il finder dell'area 6 elenca i metodi pubblici di tutte le classi e controlla la coerenza: lo stesso nome per lo
stesso concetto, le stesse keyword (`y:`/`x:`, `rows:`/`cols:`), `self` o un valore come ritorno, i predicati, la
simmetria di `open`, `new`, `close` e `destroy`, le classi di eccezione per area.

### Criteri (ogni finder li applica tutti alla sua area)

1. **Memoria e ciclo di vita:** puntatori senza distruttore; uso dopo `close` o dopo una distruzione fatta dal C
   (`family_destroy`, destroy dei widget, `drop_planes`, `close` del contesto); double free; buffer che il C conserva
   dopo la chiamata (stringhe, array di opzioni); oggetti `FFI::Function` raccolti dal GC mentre il C li può ancora
   chiamare; registro dei piani del contesto (`plane_for`, `generation`).
2. **Errori ai confini:** ritorni C non controllati; classe di eccezione sbagliata; validazione mancante (interi fuori
   range che il C tronca, `nil`, encoding, coordinate, dimensioni); metodi che dopo `close` non sollevano
   `ClosedError`.
3. **Callback ed eccezioni:** eccezioni Ruby dentro un callback C (`callback_scope`, `raise_callback_errors!`);
   chiamate vietate dentro un callback (`check_not_in_callback!`); `break`, `throw` e `return` dentro i blocchi.
4. **Thread, GVL e segnali:** le 8 funzioni con `blocking: true`; le attese in Ruby (`Context#get`, `FdPlane`,
   `Subprocess`); il YARD sui thread deve descrivere il codice reale.
5. **Convenzioni:** le 10 regole vincolanti; YARD fedele al codice (`@raise` mancanti o impossibili).
6. **Test:** esempi che passano per il motivo sbagliato, percorsi rischiosi senza test, dipendenze dall'ordine degli
   esempi.

Ogni finding riporta `file:riga`, severità, criterio, uno scenario concreto (input o stato → risultato sbagliato o
crash) e la prova proposta.

| Severità | Significato |
| --- | --- |
| alta | crash, corruzione della memoria, blocco dell'interprete, perdita di dati |
| media | eccezione sbagliata o assente, comportamento diverso dal YARD, perdita di risorse |
| bassa | convenzione, nome, YARD |

### Fix

- Correggi solo i finding CONFERMATI. Elenca i PLAUSIBILI in `RICONSEGNA.md`, con il motivo per cui restano aperti.
- Per ogni fix scrivi prima una spec che fallisce con il codice attuale. Poi applica il fix. Poi esegui la suite
  completa.
- Applica i fix uno alla volta, non in parallelo: molti fix toccano file condivisi (`context.rb`, `util.rb`,
  `widgets/widget.rb`).
- Un cambio dell'API pubblica (nome, firma, valore di ritorno) è ammesso se un finding confermato lo richiede, perché
  la gem non ha ancora utenti. Elenca ogni cambio in `RICONSEGNA.md`.
- Una scelta con due letture valide spetta all'utente: chiedi con AskUserQuestion.

## Parte 2 — suite su Ruby 3.1

### Fatti già noti

- Docker e podman non sono installati. `gh` è installato.
- mise 2026.10.17: `mise install ruby@3.1.7` non trova un binario precompilato e compila con ruby-build.
- Il build di Ruby 3.1.7 con gcc 16.2.1 fallisce nella compilazione di `enc/euc_jp.o`:

  ```text
  enc/jis/props.kwd:146:1: error: conflicting types for 'onig_jis_property'; have 'const struct enc_property *(const char *, size_t)'
  ```

- L'impostazione `exec_auto_install` di mise vale `true`: `mise exec ruby@3.1.7 -- ...` su una versione non
  installata riavvia il build da solo. Metti `MISE_EXEC_AUTO_INSTALL=false` in ogni comando `mise exec`.
- ruby-build scrive in `/tmp` log e cartelle di build di circa 340 MB ciascuna. Imposta `TMPDIR` dentro lo scratchpad
  prima del build.
- `Gemfile.lock` ha `BUNDLED WITH 4.0.22`, e Bundler 4.0.22 richiede Ruby >= 3.2.0. Su Ruby 3.1 non usare e non
  cambiare il lockfile del progetto: usa una copia del `Gemfile` nello scratchpad con `BUNDLE_GEMFILE`.
- Non cambiare la versione globale di Ruby (4.0.7 in `~/.config/mise/config.toml`): usa solo `mise exec ruby@3.1.7`.

### Procedura

1. **Build con C17.** Ipotesi da controllare: da gcc 15 lo standard C di default è C23 (`gnu23`), e in C23 una
   dichiarazione `f()` vale `f(void)`. Avvia il build con `-std=gnu17` (comandi sotto). Se il build fallisce, leggi
   nel log la riga `note: previous declaration` prima di scegliere un altro workaround.
2. **Suite.** Se il build riesce, esegui la suite completa su 3.1.7 e correggi le incompatibilità nel codice della
   Fase 2. Ogni fix deve passare anche su 4.0.7.
3. **Piano B.** Se il build fallisce ancora dopo un'analisi breve, fermati e chiedi all'utente quale strada scegliere:
   - `pacman -S podman` e un container con Ruby 3.1 e notcurses 3.0.17 compilato dal submodule `notcurses/`;
   - una matrice GitHub Actions 3.1–4.0 (il repository è privato: la CI usa i minuti Actions dell'account);
   - Ruby >= 3.2 come versione minima (cambia la regola 10).

```sh
S=/percorso/assoluto/dello/scratchpad
mkdir -p "$S/ruby-build-tmp" "$S/gemfile31" && cp Gemfile "$S/gemfile31/Gemfile"
# build (alcuni minuti: avvialo in background)
TMPDIR="$S/ruby-build-tmp" RUBY_CFLAGS='-std=gnu17' mise install ruby@3.1.7 > "$S/ruby31-install.log" 2>&1; echo "exit $?"
# gem e suite su 3.1.7, dalla radice del progetto
MISE_EXEC_AUTO_INSTALL=false BUNDLE_GEMFILE="$S/gemfile31/Gemfile" mise exec ruby@3.1.7 -- bundle install --quiet
MISE_EXEC_AUTO_INSTALL=false BUNDLE_GEMFILE="$S/gemfile31/Gemfile" TERM=xterm-256color \
  mise exec ruby@3.1.7 -- timeout -k 5 -s KILL 600 bundle exec rspec < /dev/null
```

## Consegne

1. `memory/fase2-review.md`: metodo (agenti, aree, criteri), tabella dei finding (id, `file:riga`, severità,
   criterio, verdetto, fix o motivo), cambi dell'API pubblica, comandi esatti per Ruby 3.1, controlli eseguiti.
2. `RICONSEGNA.md`: una sezione nuova "Review della Fase 2 e Ruby 3.1" dopo la sezione "Fase 2", con la data, i
   finding per severità e verdetto, i cambi dell'API, i finding aperti e il risultato su 3.1. Aggiorna anche i numeri
   della sezione "Test" e i punti di "Cosa serve alla Fase 3" che cambiano (almeno il punto 8).
3. Hindsight, bank `notcursesruby`: le decisioni, le cause radice e il workaround per Ruby 3.1 (comando in
   "Comandi").
4. Commit separati per i fix della review e per Ruby 3.1, con Conventional Commits e scope in italiano, poi push su
   `origin/master`.
5. Alla fine proponi il passo successivo e chiedi all'utente se scrivere in `RIPRESA.md` il prompt della Fase 3. Non
   iniziare la Fase 3.

## Controlli finali

- Suite completa su Ruby 4.0.7: 0 fallimenti, anche con `--order rand:1234`, `rand:4242` e `rand:7`.
- Suite completa su Ruby 3.1.7: 0 fallimenti, se la Parte 2 è riuscita.
- `ruby -w -Ilib -e 'require "notcurses"'`: nessun warning.
- `spec/coverage_spec.rb` passa: ogni funzione FFI è chiamata dal wrapper o esclusa con un motivo.
- YARD: 0 problemi con gli script euristici della sessione precedente, se esistono ancora (uso:
  `ruby <script> <file.rb>...`):

  ```text
  /home/ichelema/.claude/tmp/claude-1001/-mnt-data-Sviluppo-Progetti-notcursesruby/881ff4c3-b6e5-46db-b66a-11a45b82ccbf/scratchpad/scripts/yard_check.rb
  /home/ichelema/.claude/tmp/claude-1001/-mnt-data-Sviluppo-Progetti-notcursesruby/881ff4c3-b6e5-46db-b66a-11a45b82ccbf/scratchpad/scripts/yard_raise_check.rb
  ```

## Comandi

```sh
# suite completa su Ruby 4.0.7 (dalla radice del progetto)
TERM=xterm-256color timeout -k 5 -s KILL 600 bundle exec rspec < /dev/null
TERM=xterm-256color timeout -k 5 -s KILL 600 bundle exec rspec --order rand:1234 < /dev/null
# una sola spec
TERM=xterm-256color timeout -k 5 -s KILL 300 bundle exec rspec spec/notcurses/plane_spec.rb < /dev/null

# recall dal bank notcursesruby
curl -s -m 30 -X POST http://127.0.0.1:8888/v1/default/banks/notcursesruby/memories/recall \
  -H 'Content-Type: application/json' \
  -d '{"query":"decisioni Fase 2, ciclo di vita, callback, GVL, Ruby 3.1","budget":"high","max_tokens":6000}'

# retain nel bank notcursesruby: il JSON sta in un file dello scratchpad
curl -s -m 30 -X POST http://127.0.0.1:8888/v1/default/banks/notcursesruby/memories \
  -H 'Content-Type: application/json' --data @"$S/retain.json"
```

Formato di `retain.json`:

```json
{"async": true, "items": [{"content": "fatto autosufficiente, con comandi e percorsi alla lettera",
  "context": "una riga che descrive il dominio", "tags": ["claude-code", "repo:notcursesruby"]}]}
```
