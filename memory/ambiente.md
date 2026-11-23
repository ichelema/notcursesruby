# Ambiente

## Progetto e repository

- notcursesruby è il binding Ruby completo di notcurses 3.0.17, in Ruby puro sulla gem `ffi`. Gem `notcursesruby`
  0.1.0 (Apache-2.0), `require 'notcurses'`; non pubblicata su rubygems.org.
- Repository https://github.com/ichelema/notcursesruby, branch `master`. Il 2026-11-23 `gh api` lo dà pubblico; i
  documenti di prima lo dicevano privato.
- GitHub cancella il branch remoto al merge (`delete_branch_on_merge`, attivo dal 2026-11-22). `5_remove-worktree` lo
  trova assente e non fa il push con `--force-with-lease`, che Blast Radius metterebbe in coda.

## Macchina

- Checkout in `/Dati/Sviluppo/Progetti/Personali/20261027_notcursesruby` (CachyOS, Linux x86_64). `/Dati` è un link a
  `/mnt/data`.
- notcurses 3.0.17 di sistema, con `/usr/lib/libnotcurses-ffi.so.3`. Ruby 4.0.7 da mise.
- Ruby 3.1.7 locale non ha `rspec` né `ffi`, e con Bundler 4 del lockfile `bundle` non parte: usa
  `.claude/scripts/spec31 spec/...` dalla radice del checkout o del worktree. Lo script installa la prima volta
  `rspec` 3.13.2 e `ffi` 1.17.4 in `~/.claude/tmp/gems31`, che resta tra le sessioni, ed esegue rspec senza `bundle`.
- La sessione di Claude Code non ha un display: il 2026-11-23 `DISPLAY`, `WAYLAND_DISPLAY` e `KITTY_WINDOW_ID` sono
  vuoti, anche se `kitty` è installato. Una prova su Kitty la fa l'utente; `kitty @ launch` ([comandi.md](comandi.md))
  funziona solo in una sessione dentro Kitty.
- Con la memoria quasi finita il sistema ferma i comandi in background, e le spec dei pty e la coverage si bloccano
  (lotto 8b): prima di una suite lunga controlla `free -h`.
- Blast Radius mette in coda per la conferma dell'utente ogni comando con `rm` o `rm -rf`, anche sotto
  `~/.claude/tmp` e anche quando lo chiede `2_work-verify` (lotto 8b). Per ripetere una prova usa una cartella nuova
  (`mktemp -d`). `git worktree remove` cancella da solo le cartelle ignorate (`doc`, `.yardoc`, `coverage`,
  `.review-tmp`), senza `--force`: nella pulizia della review salta l'`rm -rf` di `.review-tmp` che chiede la sezione
  «Pulizia» di `3_independent-review`.

## Submodule e build di notcurses

- `notcurses`: sorgenti C di notcurses 3.0.17 (`v3.0.17-22-gb26048eeb`), da leggere per i percorsi C (regola 20).
  `notcurses/data` contiene le immagini delle spec. Nel checkout principale il submodule è inizializzato; se manca
  `notcurses/data`, esegui `git submodule update --init --depth 1 notcurses`. In un worktree crea il link temporaneo
  `ln -s <repo>/notcurses/data <worktree>/notcurses/data`, poi rimuovilo; non inizializzare il submodule.
- `libnotcurses-sys`: binding Rust di notcurses, riferimento della Fase 1.
- La build di notcurses di Arch ha solo lo stub di `ncplane_qrcode`: la spec di `Plane#qrcode` resta pending. ICH-542
  e ICH-552 si provano solo con una build con libqrcodegen (submodule, `-DUSE_QRCODEGEN=on`).

## Terminale headless `ncvt`

- La ricetta è in `.claude/skills/verify/SKILL.md`, con il sorgente `ncvt.c`, l'esempio `verify_reader.rb` e lo script
  `screen` con l'helper `snap.rb` (regola 22). `ncvt` usa libghostty-vt 1.0.1, stabile dalla 1.0.
- La libreria compilata e `ncvt` sono in `~/.claude/tmp/libghostty-vt/` (`prefix` e `harness/ncvt`); se mancano, la
  ricetta li ricostruisce.
- `ncvt -m` simula un terminale muto (ICH-576). `verify_reader.rb` chiede `ncvt -r 24`: lo scenario 7 usa
  `cursor_enable(y: 10, x: 5)`.
- Il file di controllo di `ncvt -s` si crea con un rename, come fanno `snap.rb` e `verify_reader.rb`. Con
  `File.write` a volte `ncvt` lo legge ancora vuoto e stampa "punto di controllo" al posto dell'etichetta.

## CI

- Container `archlinux:base` fissato per digest, snapshot `2026/10/26` dell'Arch Linux Archive, Ruby da mise, matrice
  3.1.7, 3.2.11, 3.3.13, 3.4.12, 4.0.9. RuboCop solo nel job 4.0.9.
- Soglie di coverage: 98 % totale, 90 % per file, layer FFI escluso.
- I commit di sola documentazione usano `[skip ci]`.
- La CI gira solo su Linux.
- Una CI rossa in circa 30 secondi su tutti i job è un guasto dell'infrastruttura, non il codice: per esempio
  `archive.archlinux.org` giù, da controllare con `curl` (lotto 8b).
- Dopo l'apertura della PR la CI può partire con qualche minuto di ritardo: il comando di attesa è in
  [comandi.md](comandi.md).

## Linear

- Progetto `notcursesruby` del team Ichelema (`ICH`). Le issue sono in italiano (label di progetto `lang:it`); quelle
  scritte fino al 2026-11-22 sono in inglese.
- Le issue della revisione (ICH-441…ICH-475) hanno `Problem`, `Acceptance criteria` e `Required tests`; per
  ICH-214…ICH-232 il formato non è controllato.
- L'automazione GitHub → Linear cambia lo stato delle issue citate da una PR. Con un `Refs ICH-<n>` nel corpo una
  issue fuori dal lotto va a In Progress (lotto 2 della revisione; lotto 6 con ICH-542). ICH-463, con l'ID nel nome
  del branch, è andata a In Progress e a Done anche con `Refs` (lotto 4).
