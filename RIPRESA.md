# RIPRESA — prompt per la prossima sessione

> Avvio: incolla questo file nella nuova sessione di Claude Code, oppure scrivi «Leggi RIPRESA.md ed esegui il
> prompt». Scritto il 2026-10-27, con il repository su `707e9e8` (fine della Fase 4).

## Contesto

- **Progetto:** binding Ruby completo per notcurses 3.0.17, in `/mnt/data/Sviluppo/Progetti/notcursesruby`.
  Repository **privato** https://github.com/ichelema/notcursesruby, branch `master`. Gem `notcursesruby` 0.1.0
  (Apache-2.0), `require 'notcurses'`; non pubblicata su rubygems.org.
- **Fase 1** (layer FFI raw, `lib/notcurses/ffi.rb` e `lib/notcurses/ffi/`): completa, `465418f`; cambiata solo per
  ICH-229 (`afb91c8`).
- **Fase 2** (wrapper Ruby idiomatico): completa, `7e033bd`; review e Ruby 3.1 `553aa1d`, `fe7e420`, `5dbf71e`.
- **Fase 3** (`Notcurses::UI`): completa, `e710a92`…`92fc27d`. **ICH-229** (PR #1, merge `4906a35`): `run` accetta
  `no_flow_control:` e `no_linesigs:`.
- **Fase 4** (pacchetto, YARD, coverage, CI): completa, `015633a`…`707e9e8`. Gemspec, `README.md`, `LICENSE`,
  `NOTICE`, `CHANGELOG.md`, `.yardopts`, `spec/gemspec_spec.rb`, `spec/support/coverage.rb`,
  `.github/workflows/ci.yml`. Dettagli nella sezione "Fase 4" di `RICONSEGNA.md` e in `memory/fase4-pacchetto-ci.md`.
- **Stato:** 922 esempi, 0 fallimenti su Ruby 4.0.7 e 3.1.7 in locale (anche con `rand:1234`, `rand:4242`, `rand:7`) e
  in CI su 3.1.7, 3.2.11, 3.3.13, 3.4.12, 4.0.9 (run verde
  https://github.com/ichelema/notcursesruby/actions/runs/40450186267). `ruby -w` senza warning. `yard doc
  --fail-on-warning` 0 warning, `yard stats --list-undoc` 100 %. Coverage 98,32 % in locale, 98,23 % in CI (soglie: 98 %
  totale, 90 % per file, layer FFI escluso). `gem build` senza warning.
- **CI:** container `archlinux:base` fissato per digest, pacchetti dello snapshot `2026/10/26` dell'Arch Linux Archive
  (`notcurses 3.0.17-3`, `ffmpeg 2:9.0.2-2`, gli stessi della macchina di sviluppo), Ruby da mise. Circa 11 minuti
  fatturati per push. I commit di sola documentazione usano `[skip ci]` nel messaggio.
- **notcurses sulla macchina di sviluppo:** pacchetto Arch `notcurses 3.0.17-3`. Il submodule `notcurses/` è su
  `v3.0.17-22-gb26048eeb`: usa `notcurses/src/` per la semantica del C, non `libnotcurses-sys/`.
- **Macchina di sviluppo:** Arch Linux x86_64; Ruby 4.0.7 (mise, globale); Ruby 3.1.7 (mise, compilato con
  `RUBY_CFLAGS='-std=gnu17'`). `sudo` chiede la password: i pacchetti di sistema li installa l'utente.
- **Bug di notcurses 3.0.17:** documentati nelle tabelle di `RICONSEGNA.md` (Fase 2 e Fase 3). Per uno nuovo vale la
  regola 11.

### Punti aperti dalla Fase 4

1. **Codecov:** lo step di upload si avvia solo se il secret `CODECOV_TOKEN` esiste. Controlla con
   `gh secret list --repo ichelema/notcursesruby`; se esiste, controlla il primo upload nel log del job 4.0.9.
2. **`Util.timespec`** (`lib/notcurses/util.rb:340`): codice morto senza chiamanti. Chiedi all'utente se rimuoverlo;
   rimuoverlo è un cambio di `lib/` approvato dall'utente, non della regola 11.
3. **Docker o Podman in locale:** se l'utente li ha installati, prova i job della CI in locale prima del push (comandi
   in "Comandi").

### Albero del progetto

```
notcursesruby/
  notcursesruby.gemspec  # gem notcursesruby, file da Dir.glob                  [F4]
  README.md, CHANGELOG.md, LICENSE, NOTICE, .yardopts                          [F4]
  Gemfile                # ffi; :development yard; :test rspec, simplecov     [F4]
  Gemfile.lock           # BUNDLED WITH 4.0.22: Bundler 4 richiede Ruby >= 3.2
  .github/workflows/ci.yml                                                     [F4]
  lib/notcurses.rb, lib/notcurses/           # ffi.rb e ffi/ [F1], wrapper [F2], ui.rb e ui/ [F3]
  examples/demo.rb       # prova manuale su un terminale vero                  [F3]
  spec/
    support/             # nc_helpers.rb [F2], nc_oracle.rb [F1], coverage.rb [F4]
    fixtures/visual/     # rgbw.png, frames.mkv (serve notcurses con ffmpeg)
    ffi_sanity_spec.rb, inline_reimpl_spec.rb, coverage_spec.rb, gemspec_spec.rb
    notcurses/, notcurses/ui/, integration/  # lifecycle, visual, pty, ui_pty
  memory/                # design e log delle fasi 1-4
  RICONSEGNA.md          # documentazione interna
  RIPRESA.md             # questo prompt
  notcurses/             # submodule: sorgenti C; notcurses/data serve alle spec delle immagini
  libnotcurses-sys/      # submodule: binding Rust, non usarlo come riferimento
```

## Obiettivo

La Fase 5 prova i blitter grafici su un terminale vero, senza display fisico: sixel, kitty, e il rilevamento di
quadranti, sestanti e ottanti. Oggi le spec girano su `/dev/null` o su un pty finto, e i blitter a pixel non sono
provati (punto 1 di "Cosa serve alla fase successiva" della Fase 4). La fase non aggiunge funzionalità al binding.

1. **Parte 1:** ricerca, design e approvazione dell'utente.
2. **Parte 2:** harness e spec grafiche in locale.
3. **Parte 3:** job della CI.
4. **Parte 4:** controlli finali e documentazione.

Fuori scope, salvo una richiesta esplicita dell'utente: nuove funzionalità o widget, cambi all'API pubblica,
pubblicazione della gem, macOS.

## Prima di iniziare

1. Fai il recall in Hindsight, bank `notcursesruby`, via REST (comando in "Comandi").
2. Leggi `RICONSEGNA.md`: "Come eseguire i test" (Fase 1), "Test" della Fase 2, la sezione "Fase 4" (soprattutto CI e
   "Cosa serve alla fase successiva") e `memory/fase4-design.md` (sezione 6, analisi dei test grafici).
3. Leggi `spec/integration/pty_spec.rb` (blitter `:pixel` con `Direct` su un pty finto) e
   `spec/integration/ui_pty_spec.rb` (pty come terminale di controllo, `setsid` e `TIOCSCTTY`).
4. Controlla `git status` e `git log --oneline -3`: working tree pulito (a parte i file `CLAUDE_*.md` non tracciati
   dell'utente), su `707e9e8` o dopo.
5. Controlla Ruby 3.1.7: `MISE_EXEC_AUTO_INSTALL=false mise exec ruby@3.1.7 -- ruby -v`.
6. Controlla gli strumenti locali: `command -v Xvfb xterm kitty foot podman docker act`. Se mancano, chiedi
   all'utente di installarli (`sudo` chiede la password).
7. Controlla i punti aperti della Fase 4 (sezione sopra).

## Regole vincolanti

Le regole 1–14 vengono dalle fasi precedenti. Le regole 15–17 sono nuove per la Fase 5.

1. Non cambiare la Fase 1 (`lib/notcurses/ffi/`, `lib/notcurses/ffi.rb`). Se un cambio serve, fermati e chiedi
   all'utente.
2. Ogni puntatore opaco ha un distruttore (`close` o `destroy`). Il pattern `owned:` copre i puntatori non posseduti.
3. notcurses non è thread-safe. Il wrapper lo documenta e non aggiunge lock interni.
4. I metodi restituiscono `self` dove il chaining ha senso.
5. Nomi Ruby: `snake_case`, suffisso `?` per i predicati, nessun prefisso `nc` o `notcurses_`.
6. Ogni ritorno C che indica un errore (-1 o NULL) diventa un'eccezione con un messaggio chiaro.
7. Le opzioni con un default sono keyword arguments. `spec/notcurses/api_spec.rb` controlla le regole 5 e 7.
8. `define_method` e `method_missing` sono vietati.
9. Ogni metodo pubblico ha un commento YARD con `@param`, `@return` e `@raise`.
10. Dipendenze runtime: solo la gem `ffi`. Ruby >= 3.1.
11. La fase non cambia il comportamento della libreria. Un cambio in `lib/` serve solo per un bug trovato dai test
    nuovi: prima una spec che fallisce, poi il fix, poi la suite completa.
12. Una dipendenza di sviluppo nuova entra nel design e richiede l'approvazione dell'utente. Va in un gruppo del
    `Gemfile`. Elenca ogni cambio a `Gemfile` e `Gemfile.lock` in `RICONSEGNA.md`.
13. Le azioni esterne o difficili da annullare richiedono la conferma esplicita dell'utente: pubblicazione, tag,
    release, impostazioni del repository, secret, GitHub Pages. Il push su `origin/master` resta autorizzato.
14. Una scelta con due letture valide spetta all'utente: chiedi con AskUserQuestion. Se hai dubbi, fermati e chiarisci
    con l'utente (richiesta esplicita dell'utente nella Fase 4).
15. Le spec grafiche non devono rompere la suite normale: senza `Xvfb` o senza l'emulatore vanno in skip con un
    messaggio chiaro, e non entrano nella suite di default se l'utente lo decide nel design.
16. Ogni emulatore gira in un processo figlio con `timeout -k 5 -s KILL`; nessun processo X o emulatore resta vivo
    dopo la spec (controlla con `pgrep`).
17. La CI resta verde su tutta la matrice, con le soglie di coverage invariate. I minuti costano: un job grafico nuovo
    va stimato nel design.

## Parte 1 — ricerca e design

Scrivi `memory/fase5-design.md` prima del codice. Il design copre:

1. **Emulatori senza display fisico.** Prova in locale e scegli, con motivi:
   - xterm (Arch: `xterm` 411) su Xvfb (`xorg-server-xvfb`) con `-ti vt340` e le risorse `decTerminalID`,
     `numColorRegisters`, `sixelScrolling`: sixel;
   - kitty (Arch: `kitty` 0.49) su Xvfb con OpenGL software (Mesa llvmpipe, `LIBGL_ALWAYS_SOFTWARE=1`): protocollo
     grafico kitty;
   - foot (Arch: `foot` 1.28) con un compositor Wayland headless (per esempio `cage` o `sway` con
     `WLR_BACKENDS=headless`): sixel su Wayland;
   - controlla nel C come notcurses rileva il blitter (`termdesc.c`, `query_sixel`, risposta DA1, `XTGETTCAP`,
     variabili come `TERM`, `TERM_PROGRAM`, `KITTY_WINDOW_ID`).
2. **Cosa si controlla.** Per ogni emulatore: `Context#can_pixel?`, `Capabilities` (implementazione dei pixel),
   `can_quadrant?`, `can_sextant?`, `can_octant?`, `Plane#pixel_geom`; un blit con `blitter: :pixel` di
   `spec/fixtures/visual/rgbw.png`; `Direct` con `render_image(..., blitter: :pixel)`. Decidi se basta l'esito del C
   (nessuna eccezione, valori sensati) o se serve uno screenshot (`xwd`, ImageMagick `import`) con il controllo del
   colore in punti noti.
3. **Harness.** Lo script Ruby gira dentro l'emulatore (`xterm -e ruby ...`), scrive i risultati in un file JSON e
   termina; la spec avvia Xvfb e l'emulatore, aspetta con un timeout e legge il file. Display libero (`Xvfb
   -displayfd`), cartella temporanea, pulizia dei processi.
4. **Integrazione nella suite.** Tag RSpec (per esempio `:graphics`) e skip senza strumenti; se escluse di default,
   come si avviano (variabile d'ambiente o `--tag graphics`).
5. **CI.** Un job nuovo nel container Arch (pacchetti aggiuntivi nello stesso snapshot) o uno step nella voce 4.0.9;
   stima dei minuti; cache.
6. **Dipendenze:** nessuna gem nuova se possibile (regola 12).

Poi chiedi all'utente, con AskUserQuestion, le scelte con due letture valide (per esempio: quali emulatori, screenshot
sì o no, spec grafiche nella suite di default o con un tag, job separato o step).

Non scrivere codice della Parte 2 prima dell'approvazione.

## Parte 2 — harness e spec

- Prima in locale, con gli strumenti installati dall'utente. Ogni file nuovo ha l'intestazione di due righe
  (`# Generated from notcurses 3.0.17` e `# Source: ...`).
- Se un test grafico trova un bug del wrapper, vale la regola 11; un bug di notcurses va nelle tabelle di
  `RICONSEGNA.md`.
- Suite completa dopo ogni cambio: le spec esistenti non cambiano comportamento.

## Parte 3 — CI

- Scrivi il job come approvato, controlla con `actionlint`, fai il push e segui il run con
  `gh run watch <id> --exit-status`; correggi fino a una matrice verde. Un fallimento solo in CI è un problema da
  capire, non da saltare.
- Se Podman o Docker sono installati, prova il container in locale prima del push.

## Consegne

1. Harness, spec grafiche, cambi al workflow.
2. `memory/fase5-design.md` (design approvato) e il log `memory/fase5-<argomento>.md`.
3. `RICONSEGNA.md`: sezione "Fase 5" con data, file, come avviare le spec grafiche in locale e in CI, emulatori e
   versioni, risultati per blitter, problemi trovati, cambi a `Gemfile`/`Gemfile.lock` (se ci sono), "Cosa serve alla
   fase successiva".
4. Hindsight, bank `notcursesruby`: decisioni e cause radice.
5. Commit separati per area, Conventional Commits con scope in italiano, push su `origin/master`; `[skip ci]` per i
   commit di sola documentazione.
6. Alla fine proponi il passo successivo e chiedi all'utente se scrivere in `RIPRESA.md` il prompt della fase dopo.

## Controlli finali

- Suite completa in locale su Ruby 4.0.7 e 3.1.7: 0 fallimenti, anche con `rand:1234`, `rand:4242` e `rand:7`.
- Spec grafiche verdi in locale e in CI con gli emulatori scelti; in skip pulito senza strumenti.
- CI verde su tutta la matrice; coverage >= 98 % e >= 90 % per file.
- `ruby -w -Ilib -e 'require "notcurses"'` senza warning; `yard doc --fail-on-warning` e `yard stats --list-undoc` al
  100 %; `gem build` senza warning.
- `git diff 707e9e8 -- lib/notcurses/ffi lib/notcurses/ffi.rb` vuoto.
- Nessun processo Xvfb o emulatore rimasto vivo (`pgrep -a 'Xvfb|xterm|kitty|foot'`).

## Comandi

`S` è il percorso assoluto dello scratchpad della sessione, scritto nel prompt di sistema: assegnalo a mano. Non
esiste una variabile `$SCRATCHPAD`.

```sh
S=/percorso/dello/scratchpad   # dal prompt di sistema della sessione

# suite completa su Ruby 4.0.7 (dalla radice del progetto); COLORTERM serve alle 10 spec dei colori RGB
TERM=xterm-256color COLORTERM=truecolor timeout -k 5 -s KILL 600 bundle exec rspec < /dev/null
TERM=xterm-256color COLORTERM=truecolor timeout -k 5 -s KILL 600 bundle exec rspec --order rand:1234 < /dev/null
# coverage (report in coverage/; con una sola spec fallisce per la soglia)
TERM=xterm-256color COLORTERM=truecolor timeout -k 5 -s KILL 600 \
  bundle exec rspec --require ./spec/support/coverage.rb < /dev/null

# Ruby 3.1.7: Gemfile copiato fuori dal progetto, senza lockfile
mkdir -p "$S/gemfile31" && cp Gemfile "$S/gemfile31/Gemfile"
MISE_EXEC_AUTO_INSTALL=false BUNDLE_GEMFILE="$S/gemfile31/Gemfile" mise exec ruby@3.1.7 -- bundle install --quiet
MISE_EXEC_AUTO_INSTALL=false BUNDLE_GEMFILE="$S/gemfile31/Gemfile" TERM=xterm-256color COLORTERM=truecolor \
  mise exec ruby@3.1.7 -- timeout -k 5 -s KILL 600 bundle exec rspec --order rand:1234 < /dev/null

# YARD e gem (RUBYOPT=-W0 nasconde i warning di rdoc dell'installazione locale, non della gem)
bundle exec yard doc --fail-on-warning
bundle exec yard stats --list-undoc
RUBYOPT=-W0 gem build notcursesruby.gemspec

# workflow: controllo prima del push
mise x aqua:rhysd/actionlint@1.7.12 -- actionlint -ignore SC2016 .github/workflows/ci.yml

# GitHub
gh run list --limit 5
gh run watch <id> --exit-status --interval 30
gh run view <id> --log-failed
gh secret list --repo ichelema/notcursesruby

# CI in locale con Podman (se installato): stesso container della CI
podman run --rm -it -v "$PWD":/w:Z -w /w \
  docker.io/library/archlinux:base@sha256:52dfbd5afb23a220d5ee92dafcb4c788d96c026ed04179890c23adef4c897fa0 bash
# dentro il container: gli stessi comandi degli step di .github/workflows/ci.yml (mirrorlist, pacman, mise, bundle)

# recall dal bank notcursesruby
curl -s -m 30 -X POST http://127.0.0.1:8888/v1/default/banks/notcursesruby/memories/recall \
  -H 'Content-Type: application/json' \
  -d '{"query":"Fase 4 CI container Arch, COLORTERM, blitter pixel sixel kitty, pty e terminale, test grafici","budget":"high","max_tokens":6000}'

# retain nel bank notcursesruby: il JSON sta in un file dello scratchpad
curl -s -m 30 -X POST http://127.0.0.1:8888/v1/default/banks/notcursesruby/memories \
  -H 'Content-Type: application/json' --data @"$S/retain.json"
```

In zsh una variabile non si divide in parole: scrivi `--order "rand:$seed"`, non `$opts` con `--order rand:N`
dentro.

Formato di `retain.json`:

```json
{"async": true, "items": [{"content": "fatto autosufficiente, con comandi e percorsi alla lettera",
  "context": "una riga che descrive il dominio", "tags": ["claude-code", "repo:notcursesruby"]}]}
```
