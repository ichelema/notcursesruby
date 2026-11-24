# Fase 4 — design: pacchetto, YARD generato, coverage e CI

Data: 2026-10-27. Base: `f8a23a5` (dopo ICH-229, merge `4906a35`). Stato: **approvato dall'utente il 2026-10-27**.

La Fase 4 rende il progetto installabile e controllato in automatico. Non aggiunge funzionalità al binding. Le scelte
segnate con «utente» sono state decise dall'utente con AskUserQuestion il 2026-10-27.

## 0. Scelte dell'utente

| Scelta | Decisione |
| --- | --- |
| Nome e versione della gem | `notcursesruby` 0.1.0 (il require resta `notcurses`) |
| Licenza | Apache-2.0, come notcurses |
| notcurses in CI | container Arch Linux con snapshot fissato dell'Arch Linux Archive |
| Lockfile | `Gemfile.lock` resta nel repository per Ruby 3.2–4.0; il job 3.1 usa una copia del `Gemfile` senza lock |
| Test grafici su un terminale vero | in una fase successiva |
| Documentazione YARD | artifact della CI, nessuna pubblicazione |
| `examples/` nella gem | sì |
| Coverage (richiesta aggiunta dall'utente) | SimpleCov come in Switchyard; report come artifact, riepilogo del job e Codecov |
| Layer FFI nella coverage | escluso dal totale |
| Soglie della coverage | come Switchyard: righe 98 %, ogni file 90 %; spec nuove per superare 98 % |
| Codecov | l'utente attiva il repository su Codecov e crea il secret `CODECOV_TOKEN`; il workflow ha solo lo step |

## 1. Gemspec

File `notcursesruby.gemspec`, con l'intestazione di due righe del progetto.

| Campo | Valore | Motivo |
| --- | --- | --- |
| `name` | `notcursesruby` | `notcurses` è occupato su rubygems.org (slithernix, 0.0.2, 2024); `notcursesruby` è libero |
| `version` | `Notcurses::VERSION`, letto con una regex da `lib/notcurses/version.rb` | `version.rb` usa `FFI::NOTCURSES_VERSION_*`: un `require` richiederebbe la libreria C anche per `gem build` |
| `authors`, `email` | Boscolo Michele, miboscol@gmail.com | come in Switchyard |
| `license` | `Apache-2.0` | utente; `inline_reimpl.rb` contiene il C di notcurses nei commenti |
| `required_ruby_version` | `>= 3.1` | regola 10 |
| dipendenze runtime | solo `ffi`, `~> 1.15` | regola 10, stessa versione del `Gemfile` |
| `requirements` | `notcurses 3.0.17 (libnotcurses.so.3, libnotcurses-core.so.3)` | il layer FFI chiama `attach_function` al caricamento: con una 3.0.x più vecchia un simbolo può mancare e il `require` fallisce |
| `metadata` | `source_code_uri`, `changelog_uri`, `rubygems_mfa_required = 'true'` | `homepage_uri` coincide con `source_code_uri` e RubyGems avvisa che mostrerà solo il primo, quindi è omesso e `spec.homepage` copre il campo; niente `documentation_uri` (nessuna pubblicazione) |
| `files` | `Dir.glob` con `base: __dir__`: `lib/**/*.rb`, `examples/*.rb`, `README.md`, `LICENSE`, `NOTICE`, `CHANGELOG.md`, `.yardopts` | vedi sotto |

**Perché `Dir.glob` e non `git ls-files`:** la gem si costruisce anche da un tarball o da una copia senza `.git`, e
`git ls-files` includerebbe anche file tracciati che non servono. Un pattern esplicito esclude per costruzione i
submodule, `spec/`, `memory/`, `RICONSEGNA.md`, `handoff.md` e i file `CLAUDE_*.md`.

**`examples/demo.rb` (58 righe):** incluso (utente). Il README lo cita con `gem contents notcursesruby`.

**`.yardopts` nella gem:** incluso, così `yard doc` e `yard server --gems` sulla gem installata usano la stessa
configurazione del repository.

**`Notcurses::VERSION`:** cambia da `'0.2.0'` a `'0.1.0'` in `lib/notcurses/version.rb`. È l'unico cambio di
comportamento in `lib/`, approvato dall'utente con la scelta della versione. Nessuna spec confronta la stringa
`0.2.0`; `handoff.md` e `RICONSEGNA.md` la citano e vanno aggiornati.

### Controllo automatico del pacchetto

Spec nuova `spec/gemspec_spec.rb`, con `Gem::Specification.load`:

1. `files` contiene ogni `lib/**/*.rb` e nessun file sotto `spec/`, `memory/`, `notcurses/`, `libnotcurses-sys/`, né
   `RICONSEGNA.md` o `handoff.md`;
2. le dipendenze runtime sono solo `ffi ~> 1.15`, uguale al `Gemfile`, e `required_ruby_version` è `>= 3.1`;
3. `version` è uguale a `Notcurses::VERSION` e alla prima versione di `CHANGELOG.md`.

## 2. File del pacchetto

| File | Contenuto |
| --- | --- |
| `README.md` | per gli utenti: dipendenze di sistema, installazione, due esempi (`Context.open` e `Notcurses::UI::App`), limiti noti, compatibilità, come generare la documentazione e la coverage |
| `LICENSE` | testo completo di Apache-2.0 |
| `NOTICE` | attribuzione a notcurses (titolari da `notcurses/COPYRIGHT`, Apache-2.0) per il layer FFI generato dagli header e per il C nei commenti; notcurses non ha un proprio NOTICE |
| `CHANGELOG.md` | formato Keep a Changelog; prima versione 0.1.0 con le Fasi 1–3 e ICH-229 |

- Intestazione di due righe: nei file Markdown come commento HTML (`<!-- ... -->`), invisibile nel rendering; nel
  workflow YAML con `#`. `LICENSE`, `NOTICE` e `.yardopts` non hanno una sintassi per i commenti: nessuna
  intestazione.
- **Dipendenze di sistema nel README:**
  - Arch Linux: `pacman -S notcurses` (provato, 3.0.17-3);
  - Debian e Ubuntu: `libnotcurses3` e `libnotcurses-core3` solo dove la versione è 3.0.17 (Ubuntu 26.04 LTS); Ubuntu
    24.04 ha 3.0.7, non supportata; il pacchetto Debian non contiene `libnotcurses-ffi.so.3`, che serve solo alla
    spec differenziale;
  - Fedora e macOS (Homebrew): nomi dei pacchetti da controllare nella Parte 2, segnati come non provati;
  - Windows: non supportato (nomi `.dll` assenti in `ffi_lib`).
- `RICONSEGNA.md` resta la documentazione interna; il README non la sostituisce.

## 3. YARD generato

- **Dipendenza:** `yard ~> 0.9` nel gruppo `:development` del `Gemfile` (regola 12). Provato: `bundle exec yard doc`
  con la sola gem `yard` rende il README Markdown e il markup rdoc dei commenti (`+codice+`) senza la gem `rdoc`.
- **`.yardopts`:**

  ```
  --no-progress
  --readme README.md
  --hide-api private
  --exclude lib/notcurses/ffi/
  --output-dir doc
  lib/**/*.rb
  -
  CHANGELOG.md
  LICENSE
  NOTICE
  ```

- **Uscita:** `doc/` e `.yardoc/` in `.gitignore`.
- **Layer FFI:** i file `lib/notcurses/ffi/` restano fuori dalla documentazione (`--exclude`). YARD non vede i 385
  `attach_function`, e le 251 costanti generate non hanno commento; la regola 1 vieta di aggiungerlo. Il modulo
  `Notcurses::FFI` resta documentato da `lib/notcurses/ffi.rb` come «layer raw, mappatura 1:1 dell'API C»: per la
  semantica valgono le man page di notcurses.
- **`@api private`:** nascosti con `--hide-api private` (78 tag in 17 file, tra cui `Util` e i metodi interni di
  `Context`). Così spariscono anche 5 dei 6 metodi oggi senza commento.
- **Stato misurato con questa configurazione:** 6 warning e 144 oggetti senza commento. Correzioni, solo nei commenti:
  1. 3 link `{FFI::NCPREFIXCOLUMNS}`, `{FFI::NCIPREFIXCOLUMNS}`, `{FFI::NCBPREFIXCOLUMNS}` in `format.rb` (6 warning)
     diventano `+FFI::...+`;
  2. le 143 costanti di `Notcurses::Key` (`input.rb`) ricevono un commento di una riga ciascuna;
  3. `Visual::Internal.pixel_value` riceve il commento, oppure `@api private` come il resto di `Internal`.
- **Controlli, che sostituiscono gli script euristici:** `bundle exec yard doc --fail-on-warning` e
  `bundle exec yard stats --list-undoc` con «100.00% documented». YARD segnala come warning anche i link `{...}` a
  metodi inesistenti.

## 4. Coverage

Richiesta dell'utente, sul modello di Switchyard (`simplecov` 0.22, `simplecov-cobertura` 3.0, Codecov).

- **Dipendenze:** `simplecov ~> 0.22` e `simplecov-cobertura ~> 3.0` nel gruppo `:test` del `Gemfile` (regola 12).
- **Avvio:** file nuovo `spec/support/coverage.rb`, caricato solo con `bundle exec rspec --require
  ./spec/support/coverage.rb`. Il progetto non ha `spec_helper.rb` né `.rspec`: le altre spec non cambiano.
- **Configurazione:** branch coverage attiva; filtri per `spec/`, `notcurses/`, `libnotcurses-sys/`, `lib/notcurses/ffi/`
  e `lib/notcurses/ffi.rb` (`spec/support/coverage.rb`); gruppi «Wrapper (Fase 2)» e «UI (Fase 3)»; formatter HTML e Cobertura
  (`coverage/coverage.xml` per Codecov).
- **Soglie (utente):** `minimum_coverage 98` sulle righe e `minimum_coverage_by_file 90`. I branch sono solo nel
  report.
- **Misura del 2026-10-27** (914 esempi, Ruby 4.0.7, configurazione provata nello scratchpad):

  | Gruppo | Righe | Note |
  | --- | --- | --- |
  | FFI (Fase 1) | 100,00 % (1695/1695) | si esegue al caricamento; escluso dal totale |
  | Wrapper (Fase 2) | 97,90 % (4435/4530) | |
  | UI (Fase 3) | 98,30 % (867/882) | |
  | Totale senza FFI | 97,97 % (5302/5412) | sotto la soglia 98 |
  | Branch (con FFI) | 90,35 % (1864/2063) | solo nel report |

  File più bassi: `subprocess.rb` 90,0 %, `context.rb` 90,8 %, `util.rb` 91,2 %, `ui/event_loop.rb` 93,8 %.
- **Spec nuove (utente):** spec per righe scoperte del wrapper, scelte tra `context.rb`, `util.rb`, `subprocess.rb` e
  `event_loop.rb`, fino a circa 98,3 % (margine sopra 98) e con `subprocess.rb` sopra 90 %. Cambiano solo file in
  `spec/`. Se una riga scoperta rivela un bug, vale la regola 11.
- **Limite:** le spec che avviano processi figli con `spawn` o `Open3` e `ruby -e` (`pty_spec.rb`, `ui_pty_spec.rb`,
  `lifecycle_spec.rb`, `direct_spec.rb`, `reader_spec.rb`) non contano: SimpleCov misura solo il processo di rspec.
  Per esempio `EventLoop#run` su un pty vero non entra nel conto.
- **Il gruppo FFI non compare nel report:** SimpleCov non esclude un gruppo dal totale senza filtrarlo.
- **Codecov:** step `codecov/codecov-action` con `token: ${{ secrets.CODECOV_TOKEN }}`, eseguito solo se il secret
  esiste. L'utente attiva il repository su Codecov e crea il secret; il workflow non crea niente.

## 5. CI

File `.github/workflows/ci.yml`.

### Trigger e impostazioni

- `push` su `master` e `pull_request`.
- `concurrency` per ref con `cancel-in-progress: true`: un push nuovo ferma il run vecchio e risparmia minuti.
- `fail-fast: false` nella matrice; `timeout-minutes` per ogni job.
- `permissions: contents: read`.

### Ambiente: container Arch Linux

| Punto | Scelta | Motivo |
| --- | --- | --- |
| Runner | `ubuntu-24.04` con `container: archlinux:base` fissato per digest | setup-ruby non gira su Arch; il container dà lo stesso ambiente della macchina di sviluppo |
| Pacchetti | `pacman.conf` sullo snapshot `https://archive.archlinux.org/repos/2026/10/26/`, poi `pacman -Syuu` | lo snapshot contiene `notcurses 3.0.17-3` e `ffmpeg 2:9.0.2-2`, gli stessi della macchina di sviluppo; `-Syuu` porta l'immagine alla data dello snapshot |
| notcurses | `pacman -S notcurses` | contiene `libnotcurses-ffi.so.3`; assert attivi (`CMAKE_BUILD_TYPE=None`) come in locale |
| Altri pacchetti | `git`, `mise`, `base-devel` (per Ruby 3.1), `libyaml`, `ncurses` (terminfo `xterm-256color`), `coreutils` (`timeout`, `echo`) | elenco esatto da fissare nella Parte 4 |
| Ruby 3.2–4.0 | `mise install ruby@X` con i binari precompilati `jdx/ruby`: 3.2.11, 3.3.13, 3.4.12, 4.0.9 | versioni esatte per chiavi di cache stabili; in locale c'è 4.0.7 |
| Ruby 3.1 | `mise install ruby@3.1.7` compilato con `RUBY_CFLAGS='-std=gnu17'` | `jdx/ruby` non ha 3.1; stesso build della macchina di sviluppo |
| `notcurses/data` | `git submodule update --init --depth 1 notcurses` | servono `notcurses/data/*.png` a `direct_spec.rb` e `pty_spec.rb`; `libnotcurses-sys` non serve |

**Strada scartata (Ubuntu):** su Ubuntu 26.04 il pacchetto ha 3.0.17 ma `-DBUILD_FFI_LIBRARY=off` (la spec
differenziale andrebbe in skip) e setup-ruby non ha Ruby 3.1; su Ubuntu 24.04 serve il build di notcurses da sorgente.

### Cache

| Cache | Percorso | Chiave |
| --- | --- | --- |
| pacchetti | `/var/cache/pacman/pkg` | data dello snapshot |
| Ruby | `~/.local/share/mise/installs/ruby/<versione>` | versione di Ruby e data dello snapshot (soprattutto per 3.1.7, circa 3–4 min di build) |
| gem | `vendor/bundle` (`BUNDLE_PATH`) | versione di Ruby e hash di `Gemfile.lock` (per 3.1 hash del `Gemfile`) |

### Job

1. **`test`**, matrice Ruby 3.1.7, 3.2.11, 3.3.13, 3.4.12, 4.0.9:
   - `ruby -w -Ilib -e 'require "notcurses"'` senza output su stderr;
   - suite in ordine normale;
   - suite con `--order rand`: rspec stampa «Randomized with seed N» nel log, per riprodurre con `--order rand:N`;
   - sulla voce 4.0.9 la suite in ordine normale gira con la coverage (`--require ./spec/support/coverage.rb`):
     soglie, artifact HTML, riepilogo nel job summary da `coverage/.last_run.json`, upload su Codecov se il secret
     esiste. Un job in meno rispetto a un job di coverage separato.
   - Ruby 3.1.7: `BUNDLE_GEMFILE` su una copia del `Gemfile` in `$RUNNER_TEMP`, come in locale.
2. **`package`**, nella voce Ruby 4.0.9 della matrice e non in un job separato, che ripeterebbe il setup di pacchetti,
   Ruby e gem (`ci.yml` crea cinque job):
   - `gem build notcursesruby.gemspec` senza warning;
   - `gem install` in un `GEM_HOME` temporaneo e prova di caricamento da fuori del repository con
     `Context.open(output: '/dev/null', termtype: 'xterm-256color', suppress_banners: true) { }`;
   - `bundle exec yard doc --fail-on-warning` e `yard stats --list-undoc` con 100 %;
   - artifact `doc/` (utente).

Ogni esecuzione di rspec: `TERM=xterm-256color`, `LANG=C.UTF-8`, `timeout -k 5 -s KILL 600`, stdin da `/dev/null`.
Il pty di `ui_pty_spec.rb` (`setsid`, `TIOCSCTTY`) funziona in un container Docker; il container gira come root, e
nessuna spec dipende dall'utente non root (controllato con una ricerca nelle spec).

### Minuti di GitHub Actions

Il repository è privato: i minuti sono limitati dal piano (2000 al mese con GitHub Free). Il token di `gh` non ha lo
scope `user`, quindi il piano non è controllato. Stima con le cache piene: circa 2–3 minuti per job, 6 job, quindi
circa 15 minuti per push. Il primo run costa di più (download dei pacchetti, build di Ruby 3.1.7).

## 6. Test grafici su un terminale vero

Rimandati a una fase successiva (utente). Analisi per quella fase: xterm su Xvfb con `-ti vt340` annuncia sixel nella
risposta DA1; uno script Ruby dentro xterm può controllare `pixel_impl` e un blit `:pixel`. kitty richiede OpenGL
(con Xvfb serve Mesa llvmpipe), esito incerto. Quadranti, sestanti e ottanti si controllano già come celle, senza
emulatore. Va in "Cosa serve alla fase successiva" di `RICONSEGNA.md`.

## 7. Cambi a `Gemfile` e `Gemfile.lock`

`Gemfile` dopo la Fase 4:

```ruby
# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
source 'https://rubygems.org'
gem 'ffi', '~> 1.15'

group :development do
  gem 'yard', '~> 0.9'
end

group :test do
  gem 'rspec', '~> 3.12'
  gem 'simplecov', '~> 0.22'
  gem 'simplecov-cobertura', '~> 3.0'
end
```

- Il `Gemfile` non usa `gemspec`: la copia per Ruby 3.1 in una cartella temporanea non troverebbe il gemspec, e il
  lockfile non cambia a ogni versione della gem. `spec/gemspec_spec.rb` controlla che il vincolo di `ffi` sia uguale
  nei due file.
- `Gemfile.lock`: entrano `yard`, `simplecov`, `simplecov-html`, `simplecov_json_formatter`, `simplecov-cobertura` e
  le loro dipendenze; `ffi`, `rspec` e `BUNDLED WITH 4.0.22` non cambiano. L'elenco esatto va in `RICONSEGNA.md`.
- `.gitignore`: più `/doc/`, `/.yardoc/`, `/coverage/`, `/*.gem`.

## 8. Ordine di lavoro e commit

| Parte | Lavoro | Commit (Conventional Commits, scope in italiano) |
| --- | --- | --- |
| 2 | gemspec, `README.md`, `LICENSE`, `NOTICE`, `CHANGELOG.md`, `VERSION` 0.1.0, `spec/gemspec_spec.rb`, `.gitignore` | `build(pacchetto): ...` |
| 3 | `.yardopts`, `yard` nel `Gemfile`, commenti di `format.rb`, `Key`, `Visual::Internal` | `docs(yard): ...` |
| 3b | `simplecov` nel `Gemfile`, `spec/support/coverage.rb`, spec nuove per la soglia 98 | `test(coverage): ...` |
| 4 | `.github/workflows/ci.yml`, run fino a una matrice verde | `ci(actions): ...` |
| 5 | controlli finali, `RICONSEGNA.md`, Hindsight | `docs(riconsegna): ...` |

## 9. Controlli di accettazione

- Suite completa in locale su Ruby 4.0.7 e 3.1.7: 0 fallimenti, anche con `--order rand:1234`, `rand:4242` e `rand:7`.
- CI verde su tutta la matrice, con un link a un run verde in `RICONSEGNA.md`.
- `ruby -w -Ilib -e 'require "notcurses"'` senza warning su Ruby 4.0.7 e 3.1.7.
- `spec/coverage_spec.rb`, `spec/notcurses/api_spec.rb` e `spec/gemspec_spec.rb` passano.
- `gem build` senza warning; la gem installata si carica da fuori del repository.
- `yard doc --fail-on-warning` e `yard stats --list-undoc` al 100 %.
- Coverage: righe >= 98 % senza FFI, ogni file >= 90 %.
- `git diff 4906a35 -- lib/notcurses/ffi lib/notcurses/ffi.rb` vuoto; in `lib/` cambiano solo `version.rb` (versione)
  e i commenti YARD.
