# Comandi

Esegui i comandi dalla radice del checkout o del worktree. `S` è il percorso assoluto dello scratchpad della sessione,
scritto nel prompt di sistema: assegnalo a mano. Non esiste una variabile `$SCRATCHPAD`.

## Suite e coverage

```sh
S=/percorso/dello/scratchpad   # dal prompt di sistema della sessione

# suite completa; COLORTERM serve alle 10 spec dei colori RGB, TERM fisso anche dentro Kitty o Ghostty
TERM=xterm-256color COLORTERM=truecolor LANG=C.UTF-8 LC_ALL=C.UTF-8 timeout -k 5 -s KILL 600 bundle exec rspec < /dev/null
# con un seme: ripeti con 1234, 4242 e 7
TERM=xterm-256color COLORTERM=truecolor LANG=C.UTF-8 LC_ALL=C.UTF-8 timeout -k 5 -s KILL 600 \
  bundle exec rspec --order rand:1234 < /dev/null
# coverage (report in coverage/; con una sola spec fallisce per la soglia); se si blocca, il log dice quale spec
TERM=xterm-256color COLORTERM=truecolor LANG=C.UTF-8 LC_ALL=C.UTF-8 timeout -k 5 -s KILL 600 \
  bundle exec rspec --require ./spec/support/coverage.rb --format documentation --out "$S/coverage.log" < /dev/null
# il diff tocca grapheme o Unicode? Se sì, esegui le spec cambiate anche con Ruby 3.1.7 (regola 21)
git diff origin/master...HEAD | grep -E 'grapheme|\\X|\\p\{|unicode_normalize|strwidth|\\u[0-9A-Fa-f{]'
.claude/scripts/spec31 spec/...
```

- Non eseguire due suite in parallelo: il carico della CPU rende instabili le spec dei pty.
- Prima di una suite lunga controlla `free -h` ([ambiente.md](ambiente.md)).
- Non lanciare `rspec` con cwd in un checkout per provare il codice di un altro: `rspec` mette il `lib/` del cwd nel
  load path prima di `-I`. Nei worktree esegui la suite dalla radice del worktree. Senza `cd`, usa
  `mise -C <checkout> x -- bundle exec rspec ...`: il comando gira con cwd in `<checkout>` e carica il suo `lib/`
  (prova del 2026-11-23).
- In zsh un comando in una variabile non si divide in parole: usa un array (`E=(env ...)`, `"${E[@]}"`) e scrivi
  `--order "rand:$seed"`. In zsh `echo ====` fallisce: usa `echo '----'`.
- Le spec instabili note sono in [punti-aperti.md](punti-aperti.md).

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

## Terminale vero (Kitty)

Solo in una sessione dentro Kitty ([ambiente.md](ambiente.md)). Per una prova a vista chiedi all'utente di confermare
quello che vede. Dopo la prova il terminale deve tornare pulito (una regola della Fase 5). `kitty @ send-key` non
manda il testo associato ai tasti.

```sh
# finestra nuova di Kitty, con il PATH del Ruby di mise; --foreground evita SIGTTOU
kitty @ launch --type=os-window --cwd="$PWD" --env PATH="$(dirname "$(command -v ruby)"):$PATH" -- \
  bash -c "timeout --foreground -k 5 -s KILL 60 ruby -Ilib $S/prova.rb; echo \$? > $S/prova.exit"
# spec grafiche (Fase 5), dalla finestra di Kitty
NC_GRAPHICS=1 bundle exec rspec spec/graphics --format documentation --out "$S/graphics.log"
```

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

## CI e GitHub

```sh
# workflow: controllo prima del push
mise x aqua:rhysd/actionlint@1.7.12 -- actionlint -ignore SC2016 .github/workflows/ci.yml
# dopo l'apertura della PR o un push: aspetta la run del commit appena spinto, al massimo 10 minuti, poi seguila
sha=$(git -C <checkout> rev-parse HEAD)
timeout 600 bash -c "until gh run list --commit $sha --limit 1 | grep -q .; do sleep 15; done" || echo "nessuna run per $sha"
gh pr checks <n> --watch
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
