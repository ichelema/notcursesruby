# RIPRESA — prompt per la prossima sessione

> Avvio: incolla questo file nella nuova sessione di Claude Code, oppure scrivi «Leggi RIPRESA.md ed esegui il
> prompt». Scritto il 2026-10-26, con il repository su `92fc27d`.

## Contesto

- **Progetto:** binding Ruby completo per notcurses 3.0.17, in `/mnt/data/Sviluppo/Progetti/notcursesruby`.
  Repository **privato** https://github.com/ichelema/notcursesruby, branch `master`.
- **Fase 1** (layer FFI raw, `lib/notcurses/ffi.rb` e `lib/notcurses/ffi/`): completa, commit `465418f`.
- **Fase 2** (wrapper Ruby idiomatico, 28 file di `lib/`): completa, commit `7e033bd`; review e fix `553aa1d`,
  `fe7e420`; prova su Ruby 3.1 `5dbf71e`.
- **Fase 3** (`Notcurses::UI`: ciclo degli eventi, focus, resize, widget composti; `lib/notcurses/ui.rb` e
  `lib/notcurses/ui/`, 2 107 righe; `examples/demo.rb`): completa, commit `e710a92` (Parte 0), `6c55106`…`692c455`
  (implementazione), `92fc27d` (documentazione).
- **Stato:** 910 esempi e 0 fallimenti su Ruby 4.0.7 e 3.1.7, anche con `--order rand:1234`, `rand:4242`, `rand:7`;
  `ruby -w` senza warning; 0 problemi YARD secondo due script euristici; il wrapper chiama 477 delle 631 funzioni FFI
  (le altre 154 sono escluse con un motivo in `spec/coverage_spec.rb`).
- **Pacchetto:** non esistono ancora gemspec, `README.md`, `LICENSE`, `CHANGELOG.md`, `Rakefile`, `.github/`.
  Esiste `Notcurses::VERSION = '0.2.0'` in `lib/notcurses/version.rb` (versione del binding; `HEADER_VERSION` e
  `lib_version` sono quelle di notcurses).
- **notcurses sulla macchina di sviluppo:** pacchetto Arch `notcurses 3.0.17-3` (`/usr/lib/libnotcurses.so.3`,
  `libnotcurses-core.so.3`, `libnotcurses-ffi.so.3`). Il submodule `notcurses/` è su `v3.0.17-22-gb26048eeb`, cioè
  22 commit dopo il tag: per compilare notcurses in CI usa il tag `v3.0.17`, non lo HEAD del submodule.
- `notcurses/` (sorgenti C) e `libnotcurses-sys/` (binding Rust) sono submodule git. Usa `notcurses/src/` per la
  semantica del C; non usare `libnotcurses-sys/` come riferimento.

## Obiettivo

La Fase 4 rende il progetto installabile e controllato in automatico. Non aggiunge funzionalità al binding.

1. **Parte 1:** scrivi il design e fallo approvare dall'utente.
2. **Parte 2:** gemspec, file del pacchetto e build locale della gem.
3. **Parte 3:** documentazione YARD generata.
4. **Parte 4:** CI su GitHub Actions, con la matrice di Ruby e, se l'utente lo approva, i test grafici su un
   terminale vero.
5. **Parte 5:** controlli finali e documentazione.

Fuori scope, salvo una richiesta esplicita dell'utente: la pubblicazione su rubygems.org, nuove funzionalità o
widget (tra cui un'opzione per togliere IXON e ISIG durante `EventLoop#run`), cambi all'API pubblica.

## Prima di iniziare

1. Fai il recall in Hindsight, bank `notcursesruby`, via REST (comando in "Comandi").
2. Leggi `RICONSEGNA.md`: "Dipendenze di sistema" e "Come eseguire i test" (Fase 1), "Test" della Fase 2, la
   sezione "Review della Fase 2 e Ruby 3.1" (build di Ruby 3.1.7, Bundler 4 e `Gemfile.lock`) e la sezione "Fase 3",
   soprattutto "Cosa serve alla fase successiva".
3. Controlla `git status` e `git log --oneline -3`. Il working tree deve essere pulito, su `92fc27d` o dopo.
4. Controlla che Ruby 3.1.7 sia installato: `MISE_EXEC_AUTO_INSTALL=false mise exec ruby@3.1.7 -- ruby -v`. Se manca,
   avvia in background il build con i comandi della sezione "Ruby 3.1" di `RICONSEGNA.md`.
5. Controlla l'accesso a GitHub, in sola lettura: `gh auth status` e
   `gh api repos/ichelema/notcursesruby/actions/permissions`. Su un repository privato GitHub Actions ha minuti
   limitati: dillo all'utente prima della Parte 4.

## Regole vincolanti

Le regole 1–10 vengono dalle fasi precedenti. Le regole 11–14 sono nuove per la Fase 4.

1. Non cambiare la Fase 1 (`lib/notcurses/ffi/`, `lib/notcurses/ffi.rb`). Se un cambio serve, fermati e chiedi
   all'utente.
2. Ogni puntatore opaco ha un distruttore (`close` o `destroy`). Il pattern `owned:` copre i puntatori non posseduti.
3. notcurses non è thread-safe. Il wrapper lo documenta e non aggiunge lock interni.
4. I metodi restituiscono `self` dove il chaining ha senso.
5. Nomi Ruby: `snake_case`, suffisso `?` per i predicati, nessun prefisso `nc` o `notcurses_`.
6. Ogni ritorno C che indica un errore (-1 o NULL) diventa un'eccezione con un messaggio chiaro.
7. Le opzioni con un default sono keyword arguments. `spec/notcurses/api_spec.rb` controlla le regole 5 e 7 per
   riflessione.
8. `define_method` e `method_missing` sono vietati.
9. Ogni metodo pubblico ha un commento YARD con `@param`, `@return` e `@raise`.
10. Dipendenze runtime: solo la gem `ffi`. Ruby >= 3.1.
11. La Fase 4 non cambia il comportamento della libreria. Un cambio in `lib/` serve solo per un bug trovato dalla CI
    o da YARD: prima una spec che fallisce, poi il fix, poi la suite completa.
12. Una dipendenza di sviluppo nuova (per esempio `yard`) entra nel design e richiede l'approvazione dell'utente. Va in
    un gruppo del `Gemfile`, mai tra le dipendenze runtime del gemspec. Elenca ogni cambio a `Gemfile` e
    `Gemfile.lock` in `RICONSEGNA.md`.
13. Le azioni esterne o difficili da annullare richiedono la conferma esplicita dell'utente: pubblicazione della gem,
    tag e release su GitHub, impostazioni del repository, secret, GitHub Pages. Il push su `origin/master` resta
    autorizzato come nelle fasi precedenti.
14. Una scelta con due letture valide spetta all'utente: chiedi con AskUserQuestion.

## Parte 1 — design

Scrivi `memory/fase4-design.md` prima del codice. Il design copre:

1. **Gemspec.** Nome della gem (controlla su rubygems.org se `notcurses` e `notcursesruby` sono liberi, per esempio
   con `gem search --remote --exact notcurses`), versione (`Notcurses::VERSION`), licenza, `required_ruby_version`,
   la dipendenza `ffi`, `metadata` (`source_code_uri`, `rubygems_mfa_required`), `requirements` (notcurses 3.0.x di
   sistema). File inclusi: solo quelli che servono (`lib/`, `README.md`, `LICENSE`, `CHANGELOG.md`); mai i submodule,
   `spec/`, `memory/`, `RICONSEGNA.md`, `RIPRESA.md`. Il gemspec non deve dipendere da `git ls-files` se la gem si
   costruisce anche fuori da git: scegli e motiva.
2. **File del pacchetto.** `README.md` per gli utenti (dipendenze di sistema, installazione, esempi con `Context.open`
   e con `Notcurses::UI::App`, limiti noti, compatibilità), `LICENSE`, `CHANGELOG.md` (le fasi 1–3 come prima
   versione). `RICONSEGNA.md` resta la documentazione interna.
3. **YARD generato.** `yard` come dipendenza di sviluppo, `.yardopts`, la cartella di uscita (in `.gitignore`), il
   trattamento del layer FFI (383 `attach_function` che YARD non vede, 248 reimplementazioni con il C in commento) e
   dei metodi `@api private`. Obiettivo: `yard stats --list-undoc` senza metodi pubblici non documentati e
   `yard doc` senza warning (tag sconosciuti, riferimenti `{...}` rotti). I controlli sostituiscono gli script
   euristici.
4. **CI.** `.github/workflows/`: trigger, matrice Ruby 3.1–4.0 (controlla quali versioni offre `ruby/setup-ruby`),
   sistema operativo. notcurses 3.0.17: le distribuzioni Ubuntu hanno versioni più vecchie, quindi due strade da
   proporre all'utente: (a) Ubuntu con notcurses compilato dal tag `v3.0.17` con cmake (con ffmpeg per le spec dei
   visual, libunistring, libdeflate, ncurses; cache del prefisso di installazione); (b) un container Arch Linux con
   `pacman -S notcurses` (lo stesso pacchetto della macchina di sviluppo) e Ruby da mise. Vincoli dei test da
   rispettare in CI: `TERM=xterm-256color`, stdin da `/dev/null`, `timeout -k 5 -s KILL`, una locale UTF-8 (spec dei
   tabbed), le fixture video (notcurses con ffmpeg), `libnotcurses-ffi.so.3` per la spec differenziale (altrimenti va
   in skip), un pty e `setsid`/`TIOCSCTTY` per `spec/integration/ui_pty_spec.rb` (solo Linux), il comando `echo`.
   **Bundler e Ruby 3.1:** `Gemfile.lock` ha `BUNDLED WITH 4.0.22` e Bundler 4 richiede Ruby >= 3.2; sulla macchina
   di sviluppo Ruby 3.1 usa una copia del `Gemfile` fuori dal progetto. Decidi con l'utente la politica del lockfile
   (tenerlo, toglierlo come si fa spesso per una gem, o un job 3.1 senza lockfile).
5. **Test grafici su un terminale vero** (punto 7 della Fase 2): blitter a pixel (sixel, kitty), quadranti, sestanti,
   ottanti non si provano su `/dev/null`. Cerca un emulatore che giri senza display fisico (per esempio xterm con
   Xvfb e `-ti vt340` per sixel) e proponi all'utente se farli in questa fase o dopo.

Poi chiedi all'utente, con AskUserQuestion, le scelte con due letture valide: nome della gem, licenza, versione,
strada per notcurses in CI, politica del lockfile, test grafici in questa fase, pubblicazione della documentazione
(per esempio GitHub Pages, azione esterna). Non scrivere i file della Parte 2 prima dell'approvazione.

## Parte 2 — gemspec e build

- Scrivi gemspec, `README.md`, `LICENSE` e `CHANGELOG.md` come da design. Ogni file nuovo del progetto ha
  l'intestazione di due righe usata ovunque (`# Generated from notcurses 3.0.17` e `# Source: ...`) dove la sintassi
  lo permette.
- `gem build` senza warning. Controlla il contenuto del pacchetto (`gem specification <file.gem> files`): niente
  submodule, spec, `memory/`.
- Installa la gem in un `GEM_HOME` nello scratchpad e caricala da fuori del repository, con una prova minima:
  `Notcurses::Context.open(output: '/dev/null', termtype: 'xterm-256color', suppress_banners: true) { }`, in un
  processo figlio con `timeout -k 5 -s KILL` e lo stdin da `/dev/null`.
- Se serve un controllo automatico del pacchetto (per esempio una spec sull'elenco dei file), mettilo nel design.

## Parte 3 — YARD

- `.yardopts` e `yard` nel `Gemfile` come approvato. `bundle exec yard stats --list-undoc` e `bundle exec yard doc`
  senza warning. Un buco di documentazione si chiude nel commento YARD, senza cambiare il codice.
- Verifica che i link `{Classe#metodo}` dei commenti puntino a metodi esistenti.

## Parte 4 — CI

- Scrivi il workflow come approvato e fai il push su `master`. Segui il run con `gh run watch` o
  `gh run view --log-failed`; correggi fino a una matrice verde. Un fallimento solo in CI è un problema da capire, non
  da saltare: se la causa è nel codice, segui la regola 11.
- La suite in CI gira anche con un seme casuale stampato nel log (per riprodurre un fallimento con `--order rand:N`).
- Tieni i tempi bassi: cache di Bundler e, con la strada (a), del build di notcurses.

## Consegne

1. Gemspec, file del pacchetto, `.yardopts`, workflow della CI.
2. `memory/fase4-design.md` (design approvato) e un log di lavoro `memory/fase4-<argomento>.md`: decisioni, problemi e
   soluzioni, differenze fra la macchina di sviluppo e la CI, verifiche.
3. `RICONSEGNA.md`: una sezione "Fase 4" con la data, i file, come installare la gem e generare la documentazione, la
   CI (matrice, tempi, cache, link a un run verde), i cambi a `Gemfile` e `Gemfile.lock`, i problemi trovati e "Cosa
   serve alla fase successiva". Aggiorna "Dipendenze di sistema" e la tabella "Test" se cambiano.
4. Hindsight, bank `notcursesruby`: le decisioni e le cause radice (comando in "Comandi").
5. Commit separati per area (pacchetto, YARD, CI, documentazione). Conventional Commits con scope in italiano, poi
   push su `origin/master`.
6. Alla fine proponi il passo successivo e chiedi all'utente se scrivere in `RIPRESA.md` il prompt della fase
   successiva.

## Controlli finali

- Suite completa in locale su Ruby 4.0.7 e 3.1.7: 0 fallimenti, anche con `--order rand:1234`, `rand:4242` e `rand:7`.
- CI verde su tutta la matrice.
- `ruby -w -Ilib -e 'require "notcurses"'`: nessun warning, su entrambe le versioni locali.
- `spec/coverage_spec.rb` e `spec/notcurses/api_spec.rb` passano.
- `gem build` senza warning; la gem installata si carica da fuori del repository.
- `yard stats --list-undoc` e `yard doc` senza warning.
- `git diff 92fc27d -- lib/notcurses/ffi lib/notcurses/ffi.rb` non mostra cambi; i cambi a `Gemfile` e `Gemfile.lock`
  sono solo quelli approvati.

## Comandi

```sh
# suite completa su Ruby 4.0.7 (dalla radice del progetto)
TERM=xterm-256color timeout -k 5 -s KILL 600 bundle exec rspec < /dev/null
TERM=xterm-256color timeout -k 5 -s KILL 600 bundle exec rspec --order rand:1234 < /dev/null
# una sola spec
TERM=xterm-256color timeout -k 5 -s KILL 300 bundle exec rspec spec/notcurses/plane_spec.rb < /dev/null

# Ruby 3.1.7: Gemfile copiato fuori dal progetto (S = scratchpad della sessione). Non cambiare la versione globale
# di Ruby (4.0.7) e non usare il Gemfile.lock del progetto su 3.1.
mkdir -p "$S/gemfile31" && cp Gemfile "$S/gemfile31/Gemfile"
MISE_EXEC_AUTO_INSTALL=false BUNDLE_GEMFILE="$S/gemfile31/Gemfile" mise exec ruby@3.1.7 -- bundle install --quiet
MISE_EXEC_AUTO_INSTALL=false BUNDLE_GEMFILE="$S/gemfile31/Gemfile" TERM=xterm-256color \
  mise exec ruby@3.1.7 -- timeout -k 5 -s KILL 600 bundle exec rspec --order rand:1234 < /dev/null

# GitHub (sola lettura prima della conferma dell'utente)
gh auth status
gh api repos/ichelema/notcursesruby/actions/permissions
gh run list --limit 5
gh run view <id> --log-failed

# recall dal bank notcursesruby
curl -s -m 30 -X POST http://127.0.0.1:8888/v1/default/banks/notcursesruby/memories/recall \
  -H 'Content-Type: application/json' \
  -d '{"query":"decisioni Fase 3, notcurses 3.0.17 terminale e input, Ruby 3.1 e Bundler, test su pty","budget":"high","max_tokens":6000}'

# retain nel bank notcursesruby: il JSON sta in un file dello scratchpad
curl -s -m 30 -X POST http://127.0.0.1:8888/v1/default/banks/notcursesruby/memories \
  -H 'Content-Type: application/json' --data @"$S/retain.json"
```

In zsh una variabile non si divide in parole: scrivi `--order "rand:$seed"`, non `$opts` con `--order rand:N`
dentro.

Gli script euristici di YARD delle fasi precedenti stavano negli scratchpad delle sessioni (per esempio
`/home/ichelema/.claude/tmp/claude-1001/-mnt-data-Sviluppo-Progetti-notcursesruby/3c9f344a-e514-4332-93c2-fa5285670fb0/scratchpad/scripts/`):
usali solo se esistono ancora; la Parte 3 li sostituisce con `yard stats`.

Formato di `retain.json`:

```json
{"async": true, "items": [{"content": "fatto autosufficiente, con comandi e percorsi alla lettera",
  "context": "una riga che descrive il dominio", "tags": ["claude-code", "repo:notcursesruby"]}]}
```
