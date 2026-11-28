# Comandi

Esegui i comandi dalla radice del checkout o del worktree. `S` è il percorso assoluto dello scratchpad della sessione,
scritto nel prompt di sistema: assegnalo a mano. Non esiste una variabile `$SCRATCHPAD`.

## Suite e coverage

```sh
S=/percorso/dello/scratchpad   # dal prompt di sistema della sessione

# gate prima della PR (CLAUDE.md): la suite con la coverage e una suite in ordine casuale, 2 esecuzioni, lanciate
# in parallelo (nota sotto)
# Gate leggero (fine di 2_work-simplify, fix di review senza cambio di comportamento): solo la suite con la coverage
# COLORTERM serve alle 10 spec dei colori RGB, TERM fisso anche dentro Kitty o Ghostty

# suite con la coverage, in ordine normale (report in coverage/). Eseguita su un solo file di spec fallisce per la
# soglia. Con --out il terminale non mostra l'esito delle spec: leggi il riepilogo con
# grep -E '^[0-9]+ examples?, ' "$S/coverage.log"; se la suite si blocca, il log dice quale spec. Exit 1: spec
# fallite, soglia non controllata. Exit 2: coverage sotto la soglia. Se una spec fallisce, anche quella instabile di
# punti-aperti.md, ripeti questo comando, con la coverage: la suite senza coverage non controlla la soglia
TERM=xterm-256color COLORTERM=truecolor LANG=C.UTF-8 LC_ALL=C.UTF-8 timeout -k 5 -s KILL 600 \
  bundle exec rspec --require ./spec/support/coverage.rb --format documentation --out "$S/coverage.log" < /dev/null
# in ordine casuale con un seme nuovo, come la CI. rspec stampa "Randomized with seed N" all'inizio e alla fine
# dell'output, anche se timeout ferma la suite: non filtrare l'output. Se una spec fallisce, ripeti con
# --order rand:N (stesso ordine), non con un seme nuovo
TERM=xterm-256color COLORTERM=truecolor LANG=C.UTF-8 LC_ALL=C.UTF-8 timeout -k 5 -s KILL 600 \
  bundle exec rspec --order rand < /dev/null

# fuori dal gate: suite completa senza coverage, dopo un fix seguito da altro codice prima del gate (regola 11).
# Se il gate segue subito il fix, la suite della regola 11 è quella con la coverage del gate
TERM=xterm-256color COLORTERM=truecolor LANG=C.UTF-8 LC_ALL=C.UTF-8 timeout -k 5 -s KILL 600 bundle exec rspec < /dev/null

# il diff tocca grapheme o Unicode? Se sì, esegui le spec cambiate anche con Ruby 3.1.7 (regola 21)
git diff origin/master...HEAD | grep -E 'grapheme|\\X|\\p\{|unicode_normalize|strwidth|\\u[0-9A-Fa-f{]'
.claude/scripts/spec31 spec/...

# Ruby 3.4.12 in locale, senza bundle (gem ffi e rspec in ~/.claude/tmp/gems34): per un comportamento di Ruby che
# cambia fra 3.1 e 4.0, per esempio i Fiber (lotto 17: un difetto visibile solo su 3.4.12)
G=$HOME/.claude/tmp/gems34
env GEM_HOME=$G GEM_PATH=$G PATH="$(mise where ruby@3.4.12)/bin:$PATH" TERM=xterm-256color LANG=C.UTF-8 \
  LC_ALL=C.UTF-8 timeout -k 5 -s KILL 300 $G/bin/rspec -I lib spec/... < /dev/null
```

- Il gate esegue la suite con la coverage e la suite casuale **in parallelo** (scelta dell'utente del 2026-11-24):
  ~5 minuti invece di ~10. La prova del 2026-11-23 su `master` aveva dato 1 coppia su 4 rossa in
  `spec/integration/ui_pty_spec.rb:786` (caso «coda piena», limite di 4 s); dopo il fix di ICH-595 (lotto 9b) 10
  coppie su 10 sono verdi. Se una delle due suite fallisce, ripetila da sola, in serie, con lo stesso seme
  (`--order rand:N`) prima di dichiarare un fallimento vero: un falso rosso per carico passa da solo. Altri tipi di
  suite (spec instabili, `spec31`) restano in serie. Il vincolo vale fra sessioni diverse: prima di una suite
  controlla con `pgrep -af rspec` che non giri la suite di un'altra sessione, per esempio quella del worktree di un
  lotto.
- Prima di una suite lunga controlla `free -h` ([ambiente.md](ambiente.md)).
- In un worktree di lotto, prima del primo gate, crea il link `notcurses/data` di [ambiente.md](ambiente.md) e
  controllalo con `test -L`: senza, 11 spec di immagini falliscono (`spec/notcurses/direct_spec.rb` e
  `spec/integration/pty_spec.rb:461`) e il gate va ripetuto (lotto 18).
- Non lanciare `rspec` con cwd in un checkout per provare il codice di un altro: `rspec` mette il `lib/` del cwd nel
  load path prima di `-I`. Nei worktree esegui la suite dalla radice del worktree. Senza `cd`, usa
  `mise -C <checkout> x -- bundle exec rspec ...`: il comando gira con cwd in `<checkout>` e carica il suo `lib/`
  (prova del 2026-11-23).
- In zsh un comando in una variabile non si divide in parole: usa un array (`E=(env ...)`, `"${E[@]}"`) e scrivi
  `--order "rand:$seed"`. In zsh `echo ====` fallisce: usa `echo '----'`.
- Le spec instabili note sono in [punti-aperti.md](punti-aperti.md).
- Suite ferma fino al timeout: l'esempio fermo è il successivo all'ultimo carattere del formatter `progress`, che
  scrive con `sync = true` (`rspec-core` 3.13.6, `formatters/base_formatter.rb:57`), anche nel log della CI. Conta
  `.`, `*` e `F` delle righe di avanzamento e trova l'esempio con
  `rspec --dry-run [--order rand:N] --format json`, nel checkout della corsa (il numero di esempi cambia fra
  branch) e con le stesse variabili d'ambiente. Prova del 2026-11-23 (ICH-593). Con `--order rand:N` l'ordine
  cambia molto con il numero dei gruppi: con un file di spec in più `pty_spec.rb:744` è passato dalla posizione 1045
  alla 1268. Per un albero diverso da quello della corsa, esporta il commit con `git archive` in una cartella dello
  scratchpad e fai lì il dry-run (lotto 9b).

## Script di prova

```sh
# un solo contesto per processo, output su /dev/null
TERM=xterm-256color COLORTERM=truecolor LANG=C.UTF-8 LC_ALL=C.UTF-8 timeout -k 5 -s KILL 60 ruby -Ilib "$S/prova.rb" < /dev/null
```

- Nello script apri il contesto con le opzioni di `CONTEXT_OPTIONS` (`spec/support/nc_helpers.rb`), copiate qui:
  `nc_helpers.rb` non si carica fuori da RSpec. Non scriverle a memoria (lotto 8b: `flags: [...]` è la forma del C e
  solleva "unknown keyword: :flags").

  ```ruby
  Notcurses::Context.open(output: '/dev/null', termtype: 'xterm-256color', suppress_banners: true, drain_input: true)
  ```

- Le prove di un crash o di una heap corrotta girano con `timeout -s KILL 20`: dopo l'abort il gestore `[BUG]` di Ruby
  non esce (lotto 6).
- Non cambiare `lib/` mentre gira una suite in background: i figli avviati da `heap_check` caricano i sorgenti quando
  partono, e una sola corsa può provare due versioni (lotto 2c).
- Per provare l'input di notcurses 3.0.17 usa l'eseguibile `notcurses-input` alimentato da una pipe, con il timeout di
  CTest: i simboli interni di `in.c` non sono esportati a `notcurses-tester`. Con doctest in un prefisso privato
  aggiungi `-isystem <prefisso>/include` a `CMAKE_CXX_FLAGS`, perché `CMAKE_PREFIX_PATH` copre il pacchetto ma non
  l'header.

## Benchmark delle scritture

```sh
# scritture di Plane contro la FFI diretta (ICH-594): tabella markdown con tempo, rapporto e obiettivo, circa 1 minuto
TERM=xterm-256color ruby -Ilib benchmark/plane_writes.rb < /dev/null
# un altro albero (per esempio master, per i numeri «prima»): git archive del suo lib/ nello scratchpad, poi
TERM=xterm-256color ruby -I"$S/old/lib" benchmark/plane_writes.rb < /dev/null
```

- Il criterio 5 di ICH-594 usa la mediana di 5 esecuzioni per riga: il rapporto di `vline` oscilla fra 4,8x e 5,1x
  con lo stesso codice. Esegui il benchmark con la macchina scarica (`uptime`), senza suite in parallelo.
- `benchmark/` non entra nella gem.
- Su Ruby 4.0 la gem `benchmark` non è più predefinita e non è nel bundle: per cronometrare usa
  `Process.clock_gettime(Process::CLOCK_MONOTONIC)`.

## Terminale vero (Kitty)

Solo in una sessione dentro Kitty ([ambiente.md](ambiente.md)). Per una prova a vista chiedi all'utente di confermare
quello che vede. Dopo la prova il terminale torna pulito (regola 25 di [regole.md](regole.md)). `kitty @ send-key`
non manda il testo associato ai tasti. Su Linux il Kitty dell'utente ha già `allow_remote_control yes` e
`listen_on unix:/tmp/kitty-{kitty_pid}` in `~/.config/kitty/userprefs.conf` (Fase 5; il file c'è anche sulla VPS il
2026-11-24): `kitty @` trova il socket in `KITTY_LISTEN_ON`.

```sh
# finestra nuova di Kitty, con il PATH del Ruby di mise; --foreground evita SIGTTOU
kitty @ launch --type=os-window --cwd="$PWD" --env PATH="$(dirname "$(command -v ruby)"):$PATH" -- \
  bash -c "timeout --foreground -k 5 -s KILL 60 ruby -Ilib $S/prova.rb; echo \$? > $S/prova.exit"
# spec grafiche (Fase 5), dalla finestra di Kitty
NC_GRAPHICS=1 bundle exec rspec spec/graphics --format documentation --out "$S/graphics.log"
```

- Su macOS `ghostty -e` non apre la finestra. La forma verificata è
  `open -na /Applications/Ghostty.app --args -e <script>`; la finestra aperta da launchd vuole un `PATH` esplicito per
  il Ruby di mise e per le gem. Kitty parte con `-o allow_remote_control=yes -o listen_on=unix:<socket>` senza toccare
  la configurazione, e su Kitty prevale `TERM=xterm-kitty` anche quando eredita `TERM_PROGRAM=ghostty`.

## RuboCop, YARD e gem

```sh
bundle exec rubocop
bundle exec yard doc --fail-on-warning
bundle exec yard stats --list-undoc
ruby -w -Ilib -e 'require "notcurses"'
RUBYOPT=-W0 gem build notcursesruby.gemspec --output "$S/notcursesruby.gem"
# layer FFI invariato dalla base della fase (regola 1)
git diff ad0315b -- lib/notcurses/ffi lib/notcurses/ffi.rb
```

- `gem build` può stampare warning di rdoc dell'installazione locale, non del gemspec: conta che la gem si costruisca
  e che la CI sia verde. Usa `--output` con un file nello scratchpad.
- Non aggiungere `-q` a `yard doc`. In YARD 0.9.45 `--quiet` alza il livello a `ERROR` e il logger scarta il warning
  prima di impostare `warned`, che è la variabile controllata da `--fail-on-warning`.
- Inventario della Fase 1: confronta gli insiemi di nomi, non i conteggi. `gcc -aux-info` dà i prototipi degli header,
  `nm -D --defined-only` dà i simboli (`T` di core e multimedia per gli `attach_function`, `T` di `libnotcurses-ffi`
  per le inline). `spec/coverage_spec.rb` parte dai nomi già in Ruby e non vede una funzione mancante all'origine.

## CI e GitHub

```sh
# workflow: controllo prima del push
mise x aqua:rhysd/actionlint@1.7.12 -- actionlint -ignore SC2016 .github/workflows/ci.yml
# prima della review o del merge (regola «CI» di CLAUDE.md): aspetta la run dell'ultimo commit spinto, al massimo
# 10 minuti, poi seguila
sha=$(git -C <checkout> rev-parse HEAD)
timeout 600 bash -c "until gh run list --commit $sha --limit 1 | grep -q .; do sleep 15; done" || echo "nessuna run per $sha"
gh pr checks <n> --watch
# senza aspettare (fine di 2_work-issue, inizio di 2_work-simplify e prima del suo push): exit 0 verde, 8 in corso
gh pr checks <n>
gh run list --limit 5
gh run view <id> --log-failed
```

## Linear

Per leggere e cambiare le issue usa la skill `trinity:linear` (`LINEAR_API_KEY` è nell'ambiente). Da shell usa lo
script della skill. La forma con `mise -C` funziona anche in una sessione entrata in un worktree. Lo script scrive
su stderr una riga di rate limit: per leggere il JSON con un altro programma usa `2>/dev/null`.

```sh
lq() { mise -C /Dati/AI/Claude/Trinity/skills/linear x python -- python scripts/linear.py "$@"; }

# una issue, con stato e relazioni
lq query 'query($id: String!) { issue(id: $id) { identifier title state { name } priority estimate
  labels { nodes { name } } relations { nodes { type relatedIssue { identifier state { name } } } } description } }' \
  --variables '{"id": "ICH-582"}'

# issue aperte del progetto
lq query 'query { issues(first: 100, filter: { project: { name: { eq: "notcursesruby" } },
  state: { type: { nin: ["completed", "canceled"] } } }) { nodes { identifier title priority state { name }
  labels { nodes { name } } } } }'
```

## Editor, caratteri speciali e worktree

- Edit non trova il testo con segni combinanti o con U+2028 e U+2029 scritti come caratteri: usa come ancora le righe
  ASCII vicine.
- Nel codice di `lib/` e `spec/` scrivi questi caratteri come escape (`"\u0301"`), mai come carattere:
  `spec/source_chars_spec.rb` fallisce e indica file e riga. Nei commenti restano ammessi. Nelle regex delle spec usa
  `Regexp.escape` del valore calcolato.
- In una sessione entrata in un worktree il controllo rifiuta un heredoc che crea un file, un `cd` in una subshell e
  `git -C` verso il checkout principale (lotto 8c). Crea i file con Write e usa comandi semplici, come `lq` qui sopra.
- Per un commit per issue quando un file contiene cambi di più issue: `git diff -U0`, poi
  `git apply --cached --unidiff-zero`. Con `-U1` due cambi vicini formano un hunk solo e finiscono entrambi in stage.
