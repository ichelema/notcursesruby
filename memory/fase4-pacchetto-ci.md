# Fase 4 — pacchetto, YARD generato, coverage e CI: log di lavoro

- Data: 2026-10-27.
- Base: commit `f8a23a5` (prompt della Fase 4, dopo ICH-229); suite di partenza 914 esempi, 0 fallimenti.
- Design: `memory/fase4-design.md`, approvato dall'utente (commit `015633a`).

## Parte 1 — design e scelte

Ricerca prima del design:

| Domanda | Risposta trovata | Fonte |
| --- | --- | --- |
| Nome della gem | `notcurses` è occupato (slithernix/notcurses-ruby, 0.0.2, 2024-07-31); `notcursesruby`, `notcurses-ruby`, `ruby-notcurses`, `notcurses-ffi` sono liberi | `gem search --remote --exact`, API di rubygems.org |
| notcurses su Ubuntu | 24.04: 3.0.7; 26.04 LTS: 3.0.17+dfsg-3, ma `debian/rules` usa `-DBUILD_FFI_LIBRARY=off` (niente `libnotcurses-ffi.so.3`) e `-DDFSG_BUILD=on` | Launchpad, `sources.debian.org` |
| Ruby su `ubuntu-26.04` | setup-ruby ha solo CRuby >= 3.2 su 26.04 (il runner è in public preview) | README di `ruby/setup-ruby` |
| notcurses su Arch | `CMAKE_BUILD_TYPE=None` (assert attivi), `BUILD_FFI_LIBRARY` acceso; lo snapshot `2026/10/26` dell'Arch Linux Archive ha `notcurses 3.0.17-3`, `ffmpeg 2:9.0.2-2`, `mise 2026.10.19-1` | PKGBUILD, `extra.db` dello snapshot |
| Ruby con mise | binari `jdx/ruby` per 3.2.11, 3.3.13, 3.4.12, 4.0.9; nessuno per 3.1 (compilato) | API delle release di `jdx/ruby` |
| Homebrew e Fedora | Homebrew 3.0.17; Fedora 44 3.0.17, Fedora 43 3.0.16 | `formulae.brew.sh`, `mdapi.fedoraproject.org` |
| YARD sotto Bundler | la sola gem `yard` rende il README Markdown e il markup rdoc dei commenti senza la gem `rdoc` | prova nello scratchpad |
| `-q` di `yard doc` | nasconde anche i warning: per i controlli non va usato | prova nello scratchpad |

L'utente ha chiesto due volte di fermarsi sui dubbi: le scelte sono nella sezione 0 del design. Durante il design
l'utente ha aggiunto la coverage sul modello di Switchyard (`/Dati/Sviluppo/Progetti/Switchyard/switchyard`:
`simplecov` 0.22, `simplecov-cobertura` 3.0, soglie 98 e 90, Codecov con `CODECOV_TOKEN`). Una risposta era in
conflitto (soglia 98 con l'FFI escluso dal totale, che valeva 97,97 %): chiarito con una seconda domanda (spec nuove).

## Parte 2 — gemspec e file del pacchetto

Commit `9ebad2f`.

- `version` letto con una regex da `version.rb`: `require` del file richiederebbe `Notcurses::FFI`, cioè la libreria
  C, anche per `gem build`.
- `gem build` segnalava `homepage_uri` e `source_code_uri` uguali («Only the first one will be shown»): tolto
  `homepage_uri`, perché `spec.homepage` copre il campo.
- Sulla macchina di sviluppo ogni comando `gem` stampa warning di `rdoc` (`already initialized constant`): Ruby 4.0.7
  ha `rdoc` 7.2.0 e 8.1.0 installate e il plugin di RubyGems le carica entrambe. Non dipendono dalla gem; il controllo
  locale usa `RUBYOPT=-W0 gem build`. In CI l'ambiente è pulito.
- `.yardopts` è entrato in `spec.files` solo nel commit di YARD: `gem build` fallisce per un file che non esiste.
- `LICENSE`: testo canonico da `https://www.apache.org/licenses/LICENSE-2.0.txt` (sha256 `cfc7749b…`). `NOTICE`:
  titolari di `notcurses/COPYRIGHT`; la parte MIT di quel file riguarda solo `src/fetch/ncart.c`, che il binding non
  usa.
- README e CHANGELOG in italiano, come i commenti YARD e la documentazione interna.
- Prova: gem installata in un `GEM_HOME` nello scratchpad, caricata da fuori del repository con `ruby -w`: `OK 0.1.0`,
  nessun warning.

## Parte 3 — YARD

Commit `50aa38d`.

- Stato di partenza con `.yardopts` (FFI escluso, `--hide-api private`): 6 warning, 143 costanti e 1 metodo senza
  commento. Correzioni solo nei commenti:
  - 3 link `{FFI::NC*PREFIXCOLUMNS}` in `format.rb` diventano `+FFI::...+` (ogni link dava 2 warning, uno anche su
    `lib/notcurses.rb:1`);
  - 143 commenti di una riga sulle costanti di `Key`, scritti con uno script (tabella di descrizioni da `nckeys.h`,
    `F00`–`F60` e `BUTTON1`–`BUTTON11` per pattern; lo script si ferma se manca una descrizione);
  - `@api private` sul modulo `Visual::Internal`, che aveva un commento ma appariva nella documentazione pubblica.
- Risultato: `bundle exec yard doc --fail-on-warning` esce con 0, `yard stats --list-undoc` dà `100.00% documented`
  (6 moduli, 51 classi, 164 costanti, 101 attributi, 613 metodi). `Util` e `Visual::Internal` non compaiono.
- `Gemfile.lock`: solo `yard (0.9.45)`.

## Parte 3b — coverage

Commit `b188bfb`.

- Il filtro esclude anche `lib/notcurses/ffi.rb`, oltre a `lib/notcurses/ffi/`: entrambi sono la Fase 1.
- Prima misura con la configurazione del progetto: 98,06 % (5307/5412). Una misura precedente con la stessa base dava
  5302 righe: il risultato varia di qualche riga tra le esecuzioni (thread e tempi), quindi serve un margine.
- Righe scoperte: quasi tutte sono rami d'errore del C (creazione che restituisce NULL) o codice eseguito solo con un
  tty vero, cioè nei processi figli di `pty_spec.rb` e `ui_pty_spec.rb`, che SimpleCov non conta.
- **Codice morto trovato:** `Util.timespec` (`util.rb:340`, 13 righe) non ha chiamanti. Non rimosso (regola 11 e
  regole dell'utente sul dead code) e non coperto con una spec fatta solo per la percentuale.
- Spec nuove (5 esempi): `Timer#inspect`; `run` restituisce `:interrupt` se un blocco di `post` solleva `Interrupt`;
  `Context#linesigs?` senza tty su stdin; `Plane#box` con `set: :heavy` e `TypeError` per un `set` non valido;
  `Subprocess` uccide e raccoglie il figlio se l'avvio della lettura fallisce (stub di `start!`).
- Risultato: 98,32 % delle righe (5321/5412), uguale in 2 esecuzioni; branch 91,26 % (1691/1853). File più bassi:
  `util.rb` 91,2 % (per `Util.timespec`), `context.rb` 93,4 %; `subprocess.rb` da 90,0 % a oltre 95 %.
- La soglia funziona: con una sola spec la coverage è 29,34 % e il comando esce con 2.
- `Gemfile.lock`: `docile 1.4.1`, `rexml 3.4.4`, `simplecov 0.22.0`, `simplecov-cobertura 3.2.0`,
  `simplecov-html 0.13.2`, `simplecov_json_formatter 0.1.4`.

## Parte 4 — CI

Commit `b84aa96` (workflow), poi le correzioni sotto.

- Docker e Podman non sono installati sulla macchina di sviluppo e `sudo` chiede la password: il workflow è stato
  provato solo su GitHub Actions. Prima del push: `actionlint` 1.7.12 (con `mise x aqua:rhysd/actionlint`).
- Un solo tipo di job: la voce 4.0.9 della matrice fa anche coverage, `gem build`, prova della gem installata e YARD.
  Un job `package` separato avrebbe ripetuto il setup (pacchetti, Ruby, gem) e i minuti.

| Run | Problema | Causa | Correzione |
| --- | --- | --- | --- |
| `40448037558` | `git submodule update` esce con 128 in tutti i job | «detected dubious ownership»: il workspace appartiene a un altro utente del container e `actions/checkout` toglie la sua eccezione `safe.directory` alla fine dello step | `git config --global --add safe.directory "$GITHUB_WORKSPACE"` prima del submodule |
| `40448037558` | il riepilogo della coverage gira anche senza la suite (exit 127) | `if: !cancelled()` vale anche dopo un fallimento precedente | `steps.suite.outcome != 'skipped'` |
| `40448354985` | 922 esempi, 10 fallimenti uguali su tutte le versioni: `can_truecolor?`, `Capabilities#rgb?` e le sequenze `\e[38;2;…m` di `Direct` (`context_spec.rb`, `direct_spec.rb`) | notcurses abilita i 24 bit solo se `COLORTERM` vale `truecolor` o `24bit` (`termdesc.c:191`). Il terminale di sviluppo (WezTerm) imposta `COLORTERM=truecolor`, il container no. Riprodotto in locale con `env -u COLORTERM`: stessi 10 fallimenti | `COLORTERM: truecolor` nell'`env` del workflow; vincolo nel README e in `RICONSEGNA.md`. Non è un bug della libreria: nessun cambio a `lib/` |
| `40448354985` | il riepilogo della coverage fallisce (`ENOENT` su `.last_run.json`) | con spec fallite SimpleCov scrive il report HTML ma non `.last_run.json` («Stopped processing SimpleCov as a previous error…») | riepilogo solo con `steps.suite.outcome == 'success'`; l'artifact HTML resta con `!cancelled()` |

Dati del run `40448354985`, prima del fix: coverage in CI 98,3 % (5320/5412), branch 91,42 %, come in locale. Lo step
di `pacman` scarica 338,65 MiB (66 s senza cache). Il job 3.1.7 dura circa 6 minuti per la compilazione di Ruby.

## Controlli

- Ruby 4.0.7, locale: 922 esempi, 0 fallimenti in ordine normale e con `rand:1234`, `rand:4242`, `rand:7`.
- Ruby 3.1.7, locale (copia del `Gemfile` senza lockfile): 922 esempi, 0 fallimenti con `rand:1234`, `rand:4242`,
  `rand:7`.
- `ruby -w -Ilib -e 'require "notcurses"'`: nessun warning su 4.0.7 e 3.1.7.
- `git diff 4906a35 -- lib/notcurses/ffi lib/notcurses/ffi.rb`: vuoto.
- CI, run `40449066107` (commit `1aff846`), primo run verde: le cinque versioni, 922 esempi e 0 fallimenti in ordine
  normale e casuale (semi 42642, 30896, 53508, 49539, 47529), nessun esempio in skip. Coverage 98,23 % (5316/5412),
  branch 90,99 %. `gem build` senza warning, gem installata caricata da `/__w/_temp/gem-test`, YARD al 100 %.
  Artifact `doc` (458 kB) e `coverage` (506 kB). Upload su Codecov saltato: il secret non esiste ancora.
- Nel log di `pacman` compare «journal-nocow.conf: Failed to resolve specifier»: hook di systemd-tmpfiles in un
  container senza systemd, innocuo.
- CI, run `40450186267` (commit `8ec60ad`), con le cache piene: verde; job da 1 min 40 s (3.2.11) a 2 min 47 s (3.1.7),
  `pacman` circa 25 s, Ruby e gem circa 5 s.
