# RIPRESA — prompt per la prossima sessione

> Avvio: incolla questo file nella nuova sessione di Claude Code, oppure scrivi «Leggi RIPRESA.md ed esegui il
> prompt». Scritto il 2026-10-27, con il repository su `fb53f07` (fine della Fase 4), per una sessione sulla
> macchina dell'utente (Linux e macOS, terminali Kitty e Ghostty).

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
- **VPS delle fasi 1–4:** Arch Linux x86_64; Ruby 4.0.7 (mise, globale); Ruby 3.1.7 (mise, compilato con
  `RUBY_CFLAGS='-std=gnu17'`); Podman 6.1.4 rootless. `sudo` chiede la password: i pacchetti li installa
  l'utente. La Fase 5 gira invece sulla macchina dell'utente (sezione "Dove gira questa fase").
- **Bug di notcurses 3.0.17:** documentati nelle tabelle di `RICONSEGNA.md` (Fase 2 e Fase 3). Per uno nuovo vale la
  regola 11.

### Punti aperti dalla Fase 4

1. **Codecov:** attivo dal 2026-10-27 (GitHub App installata, secret `CODECOV_TOKEN`, primo upload riuscito nel run
   `40450186267`). Controlla solo che gli upload continuino nel job 4.0.9.
2. **`Util.timespec`** (`lib/notcurses/util.rb:340`): codice morto senza chiamanti. Chiedi all'utente se rimuoverlo;
   rimuoverlo è un cambio di `lib/` approvato dall'utente, non della regola 11.
3. **Podman sul VPS:** installato dall'utente il 2026-10-27 (6.1.4, rootless, `crun`, `netavark`, socket utente
   attivo; anche `act` 0.2.89). Provato: i passi del job 4.0.9 nel container della CI danno 922 esempi, 0 fallimenti
   (anche le spec del pty). Sul VPS serve a provare i job prima del push (comandi in "Comandi"); sulla macchina
   dell'utente potrebbe mancare, e la Fase 5 non cambia la CI.
   `archive.archlinux.org` è lento: un download può fermarsi con «Operation too slow»; ripeti, la cache montata tiene i
   pacchetti già scaricati.

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

## Dove gira questa fase

Le fasi 1–4 sono state fatte su un **VPS** Arch Linux (`/mnt/data/Sviluppo/Progetti/notcursesruby`), senza terminale
grafico. La Fase 5 gira sulla **macchina dell'utente**, in una sessione di Claude Code avviata dal suo terminale:

| Sistema | Terminali | Protocollo grafico |
| --- | --- | --- |
| Linux | Kitty, Ghostty | kitty graphics (Kitty e Ghostty); niente sixel |
| macOS | Kitty, Ghostty | kitty graphics; niente sixel |

- Il percorso del checkout, la distribuzione Linux, la versione di macOS e l'architettura (Apple Silicon o Intel) non
  sono noti: controllali all'inizio e scrivili nel log.
- Sixel resta non provato (nessuno dei due terminali lo supporta): scrivilo nei risultati.
- Il server Hindsight (`127.0.0.1:8888`) e lo scratchpad del VPS potrebbero non esistere sulla macchina dell'utente: se
  il recall non risponde, prosegui con `RICONSEGNA.md` e i file `memory/`, e dillo in una riga.
- La CI non cambia (scelta dell'utente): niente job grafico headless.

## Obiettivo

La Fase 5 prova i blitter grafici su un terminale vero e porta il binding su macOS. Oggi le spec girano su `/dev/null`
o su un pty finto, i blitter a pixel non sono provati e macOS non è mai stato provato. La fase non aggiunge funzionalità
al binding.

1. **Parte 1 (Linux):** ambiente, prove grafiche in Kitty e Ghostty, design, approvazione dell'utente.
2. **Parte 2 (Linux):** script e spec grafiche.
3. **Parte 3 (macOS):** caricamento della gem e prove grafiche, poi la suite completa.
4. **Parte 4:** controlli finali e documentazione.

Fuori scope, salvo una richiesta esplicita dell'utente: nuove funzionalità o widget, cambi all'API pubblica,
pubblicazione della gem, job grafici in CI, Windows.

## Prima di iniziare

1. Fai il recall in Hindsight, bank `notcursesruby` (comando in "Comandi"), se il server risponde.
2. Leggi `RICONSEGNA.md`: "Dipendenze di sistema" e "Come eseguire i test" (Fase 1), "Test" della Fase 2, la sezione
   "Fase 4" (soprattutto "Cosa serve alla fase successiva") e `memory/fase4-design.md` (sezione 6).
3. Leggi `spec/integration/pty_spec.rb` (blitter `:pixel` con `Direct` su un pty finto) e
   `spec/integration/ui_pty_spec.rb` (pty come terminale di controllo).
4. Controlla `git status` e `git log --oneline -3`: working tree pulito, su `fb53f07` o dopo. Il repository è privato:
   serve l'accesso a GitHub per `git pull`.
5. Controlla l'ambiente e scrivilo nel log: `uname -a`, `echo $TERM $TERM_PROGRAM $COLORTERM`, versione di notcurses
   (`pkg-config --modversion notcurses` o il pacchetto), Ruby (`ruby -v`), dove sono le librerie
   (`ldconfig -p | grep notcurses` su Linux, `ls "$(brew --prefix)/lib" | grep notcurses` su macOS).
6. Il submodule `notcurses/` serve alle spec delle immagini: `git submodule update --init --depth 1 notcurses`.
7. Controlla i punti aperti della Fase 4 (sezione sopra).

## Regole vincolanti

Le regole 1–14 vengono dalle fasi precedenti. Le regole 15–18 sono nuove per la Fase 5.

1. Non cambiare la Fase 1 (`lib/notcurses/ffi/`, `lib/notcurses/ffi.rb`). Se un cambio serve, fermati e chiedi
   all'utente. Vale anche per macOS: per esempio aggiungere percorsi di Homebrew alla ricerca di `ffi_lib`.
2. Ogni puntatore opaco ha un distruttore (`close` o `destroy`). Il pattern `owned:` copre i puntatori non posseduti.
3. notcurses non è thread-safe. Il wrapper lo documenta e non aggiunge lock interni.
4. I metodi restituiscono `self` dove il chaining ha senso.
5. Nomi Ruby: `snake_case`, suffisso `?` per i predicati, nessun prefisso `nc` o `notcurses_`.
6. Ogni ritorno C che indica un errore (-1 o NULL) diventa un'eccezione con un messaggio chiaro.
7. Le opzioni con un default sono keyword arguments. `spec/notcurses/api_spec.rb` controlla le regole 5 e 7.
8. `define_method` e `method_missing` sono vietati.
9. Ogni metodo pubblico ha un commento YARD con `@param`, `@return` e `@raise`.
10. Dipendenze runtime: solo la gem `ffi`. Ruby >= 3.1.
11. La fase non cambia il comportamento della libreria. Un cambio in `lib/` serve solo per un bug trovato dalle prove:
    prima una spec che fallisce, poi il fix, poi la suite completa.
12. Una dipendenza di sviluppo nuova entra nel design e richiede l'approvazione dell'utente. Va in un gruppo del
    `Gemfile`. Elenca ogni cambio a `Gemfile` e `Gemfile.lock` in `RICONSEGNA.md`.
13. Le azioni esterne o difficili da annullare richiedono la conferma esplicita dell'utente: pubblicazione, tag,
    release, impostazioni del repository, secret, GitHub Pages. Il push su `origin/master` resta autorizzato.
14. Una scelta con due letture valide spetta all'utente: chiedi con AskUserQuestion. Se hai dubbi, fermati e chiarisci
    con l'utente (richiesta esplicita dell'utente).
15. Le spec grafiche non rompono la suite normale né la CI: richiedono un terminale grafico vero, quindi stanno dietro
    un tag RSpec o una variabile d'ambiente e vanno in skip con un messaggio chiaro fuori da un terminale adatto.
16. Le prove grafiche scrivono sul terminale dell'utente: dopo ogni prova il terminale torna pulito (schermo
    alternativo chiuso, immagini cancellate, cursore visibile). Chiedi all'utente di confermare a vista quando l'esito
    del C non basta.
17. Su macOS una spec legata a Linux (per esempio `/proc/self/fd`, `TIOCSCTTY`, `osversion` che inizia con `Linux`)
    va in skip con il motivo, oppure diventa portabile se il cambio è piccolo; non indebolire i controlli su Linux.
18. La CI resta verde su tutta la matrice, con le soglie di coverage invariate.

## Parte 1 — ambiente, prove grafiche su Linux e design

1. Su Linux, in Kitty e poi in Ghostty, esegui uno script di prova (prima nello scratchpad, poi nel repository se
   approvato) che apre un `Context` sul terminale vero e scrive in un file JSON:
   - `can_pixel?`, l'implementazione dei pixel in `Capabilities`, `can_quadrant?`, `can_sextant?`, `can_octant?`,
     `Plane#pixel_geom`, `detected_terminal`;
   - l'esito di un blit di `spec/fixtures/visual/rgbw.png` con `blitter: :pixel`, `:quadrant`, `:sextant`, `:octant`,
     `:braille`, `:half`, `:ascii`;
   - `Direct#render_image(..., blitter: :pixel)`.
   Lo script avvia con `timeout` e chiude sempre il contesto.
2. Controlla nel C come notcurses 3.0.17 rileva il terminale e il protocollo grafico (`termdesc.c`, risposta DA1,
   `XTGETTCAP`, `TERM`, `TERM_PROGRAM`, `KITTY_WINDOW_ID`) e confronta con quello che vedi in Kitty e Ghostty.
3. Scrivi `memory/fase5-design.md`: risultati delle prove, come si controlla l'esito (solo il C, oppure anche un
   controllo a vista dell'utente o una lettura del terminale), dove stanno script e spec grafiche, tag RSpec, piano
   per macOS.
4. Chiedi all'utente, con AskUserQuestion, le scelte con due letture valide (per esempio: script in `examples/` o
   spec con un tag; quali blitter controllare; come trattare un rilevamento sbagliato di notcurses).

Non scrivere codice della Parte 2 nel repository prima dell'approvazione.

## Parte 2 — script e spec grafiche (Linux)

- Ogni file nuovo ha l'intestazione di due righe (`# Generated from notcurses 3.0.17` e `# Source: ...`).
- Se una prova trova un bug del wrapper, vale la regola 11; un bug di notcurses va nelle tabelle di `RICONSEGNA.md`.
- Suite completa dopo ogni cambio, in ordine normale e con i semi.

## Parte 3 — macOS

1. **notcurses:** `brew install notcurses` (Homebrew ha 3.0.17). Controlla se Homebrew installa anche
   `libnotcurses-ffi` (serve solo alla spec differenziale) e con quale nome: l'oracolo `spec/support/nc_oracle.rb`
   cerca `libnotcurses-ffi.so.3` e `notcurses-ffi`.
2. **Caricamento:** `ruby -Ilib -e 'require "notcurses"'`. Su Apple Silicon Homebrew sta in `/opt/homebrew/lib`, che
   `dlopen` potrebbe non cercare: prova prima `DYLD_FALLBACK_LIBRARY_PATH="$(brew --prefix)/lib"`. Un cambio di
   `ffi_lib` tocca la Fase 1: chiedi all'utente (regola 1).
3. **termios:** su macOS `tcflag_t` è `unsigned long` e `IXON`/`ISIG` hanno i valori BSD: finora controllati solo
   sugli header. Prova `EventLoop#run(no_flow_control: true, no_linesigs: true)` nel terminale vero.
4. **Prove grafiche:** le stesse della Parte 1 in Kitty e Ghostty su macOS.
5. **Suite completa:** punti già noti che dipendono da Linux:

   | Punto | Dove |
   | --- | --- |
   | `Dir.children('/proc/self/fd')` per contare i descrittori | `spec/notcurses/ui/event_loop_spec.rb:26`, `spec/notcurses/subprocess_spec.rb` |
   | `osversion` che inizia con `Linux` | `spec/notcurses/stats_spec.rb:47` |
   | comando `timeout` di coreutils (`gtimeout` con `brew install coreutils`) | `spec/notcurses/reader_spec.rb:195` e i comandi di test |
   | `TIOCSCTTY` (`0x540E`), già in skip fuori da Linux | `spec/integration/ui_pty_spec.rb` |
   | nome della libreria dell'oracolo | `spec/support/nc_oracle.rb:29` |

   Cerca gli altri con la suite. Su macOS lo stdin di `/dev/null`, `fopen("/dev/null")` e i pty si comportano in modo
   simile, ma non è provato.

## Consegne

1. Script e spec grafiche, cambi alle spec per macOS.
2. `memory/fase5-design.md` (design approvato) e il log `memory/fase5-<argomento>.md`: ambiente delle due macchine,
   risultati per terminale e blitter, problemi e soluzioni.
3. `RICONSEGNA.md`: sezione "Fase 5" con data, file, come avviare le prove grafiche, risultati per sistema, terminale e
   blitter, stato di macOS (cosa passa, cosa è in skip e perché), problemi trovati, cambi a `Gemfile`/`Gemfile.lock`
   (se ci sono), "Cosa serve alla fase successiva". Aggiorna "Dipendenze di sistema" (macOS provato) e il README
   (tabella di installazione, limiti).
4. Hindsight, bank `notcursesruby`, se il server risponde: decisioni e cause radice.
5. Commit separati per area, Conventional Commits con scope in italiano, push su `origin/master`; `[skip ci]` per i
   commit di sola documentazione.
6. Alla fine proponi il passo successivo e chiedi all'utente se scrivere in `RIPRESA.md` il prompt della fase dopo.

## Controlli finali

- Suite completa su Linux (macchina dell'utente): 0 fallimenti, anche con `rand:1234`, `rand:4242` e `rand:7`.
- Suite completa su macOS: 0 fallimenti; gli skip hanno un motivo scritto.
- Prove grafiche in Kitty e Ghostty, su Linux e su macOS, con i risultati nel log.
- CI verde su tutta la matrice; coverage >= 98 % e >= 90 % per file.
- `ruby -w -Ilib -e 'require "notcurses"'` senza warning; `yard doc --fail-on-warning` e `yard stats --list-undoc` al
  100 %; `gem build` senza warning.
- `git diff fb53f07 -- lib/notcurses/ffi lib/notcurses/ffi.rb` vuoto, salvo cambi approvati dall'utente.

## Comandi

`S` è il percorso assoluto dello scratchpad della sessione, scritto nel prompt di sistema: assegnalo a mano. Non
esiste una variabile `$SCRATCHPAD`.

```sh
S=/percorso/dello/scratchpad   # dal prompt di sistema della sessione

# suite completa su Ruby 4.0.7 (dalla radice del progetto); COLORTERM serve alle 10 spec dei colori RGB
TERM=xterm-256color COLORTERM=truecolor timeout -k 5 -s KILL 600 bundle exec rspec < /dev/null
TERM=xterm-256color COLORTERM=truecolor timeout -k 5 -s KILL 600 bundle exec rspec --order rand:1234 < /dev/null
# La suite non grafica forza TERM=xterm-256color anche dentro Kitty o Ghostty (TERM=xterm-kitty, xterm-ghostty):
# i valori attesi delle spec sono calcolati per xterm-256color. Le prove grafiche usano invece il TERM del terminale.
# macOS: timeout viene da coreutils di Homebrew (brew install coreutils) come gtimeout, oppure aggiungi
# "$(brew --prefix)/opt/coreutils/libexec/gnubin" al PATH; libreria: DYLD_FALLBACK_LIBRARY_PATH="$(brew --prefix)/lib".
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

# CI in locale con Podman: passi del job 4.0.9 nel container della CI (provato il 2026-10-27, 922 esempi).
# P = cartella delle cache, fuori dal progetto; ci-local.sh = lo script sotto, salvato nello scratchpad.
P="$S/podman-cache"; mkdir -p "$P/pacman" "$P/mise" "$P/bundle"
podman run --rm -v "$PWD":/w:ro -w /w -v "$S/ci-local.sh":/ci-local.sh:ro \
  -v "$P/pacman":/var/cache/pacman/pkg -v "$P/mise":/opt/mise -v "$P/bundle":/opt/bundle \
  -e ARCH_SNAPSHOT=2026/10/26 -e RUBY=4.0.9 -e MISE_DATA_DIR=/opt/mise -e BUNDLE_PATH=/opt/bundle \
  -e TERM=xterm-256color -e COLORTERM=truecolor -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 -e MISE_GITHUB_TOKEN="$(gh auth token)" \
  docker.io/library/archlinux:base@sha256:52dfbd5afb23a220d5ee92dafcb4c788d96c026ed04179890c23adef4c897fa0 /ci-local.sh
# ci-local.sh (chmod +x):
#   #!/usr/bin/env bash
#   set -euo pipefail
#   echo "Server = https://archive.archlinux.org/repos/${ARCH_SNAPSHOT}/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist
#   pacman-key --init > /dev/null; pacman-key --populate archlinux > /dev/null
#   pacman -Syuu --noconfirm --needed notcurses git mise base-devel libyaml openssl zlib libffi > /tmp/pacman.log 2>&1 \
#     || { tail -20 /tmp/pacman.log; exit 1; }
#   mise install "ruby@${RUBY}" > /tmp/mise.log 2>&1 || { tail -20 /tmp/mise.log; exit 1; }
#   export PATH="$(mise where "ruby@${RUBY}")/bin:$PATH"
#   gem install --no-document bundler -v "$(tail -n 1 Gemfile.lock | tr -d ' ')" > /dev/null
#   BUNDLE_FROZEN=true bundle install --jobs 4 --quiet
#   BUNDLE_FROZEN=true timeout -k 5 -s KILL 600 bundle exec rspec --order rand < /dev/null
# Per Ruby 3.1.7 servono RUBY_CFLAGS=-std=gnu17 e una copia del Gemfile senza lockfile, come nel workflow.

# recall dal bank notcursesruby
curl -s -m 30 -X POST http://127.0.0.1:8888/v1/default/banks/notcursesruby/memories/recall \
  -H 'Content-Type: application/json' \
  -d '{"query":"Fase 4 CI container Arch, COLORTERM, blitter pixel kitty, pty e terminale, macOS e termios, test grafici","budget":"high","max_tokens":6000}'

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
