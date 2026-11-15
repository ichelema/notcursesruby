# Fase 5 — blitter su un terminale vero e macOS: log di lavoro

- Data: 2026-11-15.
- Base: commit `667e5bc` (prompt della Fase 5 aggiornato, dopo `b2fed69`); suite di partenza 1046 esempi, 0
  fallimenti in 30 s; `bundle exec rubocop` 0 offense.
- Design: `memory/fase5-design.md`.
- Hindsight: il server `127.0.0.1:8888` risponde; recall dal bank `notcursesruby` fatto all'inizio.

## Ambiente Linux

| Voce | Valore |
| --- | --- |
| Macchina | `browserino`, CachyOS, kernel `7.3.4-1-cachyos`, x86_64 |
| Desktop | Hyprland su Wayland (`WAYLAND_DISPLAY=wayland-1`, XWayland su `:1`) |
| notcurses | 3.0.17 (`pkg-config`), pacchetto `notcurses 3.0.17-3.1` (build `x86_64_v4` di CachyOS); `libnotcurses.so.3`, `libnotcurses-core.so.3`, `libnotcurses-ffi.so.3`, `libnotcurses++.so.3` in `/usr/lib` |
| ffmpeg | `2:9.0.2-3.1` (la CI usa `2:9.0.2-2`) |
| Ruby | 4.0.7 da mise (`~/.local/share/mise/installs/ruby/4.0.7/bin/ruby`) |
| Submodule | `notcurses` su `v3.0.17-22-gb26048eeb`, `libnotcurses-sys` su `v3.11.0-3-g018a8d4` |
| Kitty | 0.50.0, remote control attivo (`kitty @ ls` risponde) |
| Ghostty | 1.4.0-arch1.1 |
| Tastiera | NuPhy Field75 HE, layout `us`; NumLock sempre attivo (`input:numlock_by_default = true`); CapsLock rimappato su Menu (`kb_options` con `caps:menu`): Hyprland lo usa per avviare superwhisper |

La sessione di Claude Code gira in Kitty (`TERM=xterm-kitty`, `KITTY_WINDOW_ID=3`), ma il tool Bash non ha un
terminale di controllo: stdin è `/dev/null`, stdout un file, `/dev/tty` non si apre. Le prove grafiche girano quindi
in una finestra nuova, aperta con `kitty @ launch --type=os-window` o con `ghostty -e`, e scrivono l'esito in un file
JSON dello scratchpad.

## Rilevamento nel C (notcurses 3.0.17)

- notcurses manda XTVERSION (`\e[>0q`) e riconosce il nome nella risposta (`in.c:1550-1559`: `kitty(` →
  `TERMINAL_KITTY`, `ghostty ` → `TERMINAL_GHOSTTY`); anche la risposta XTGETTCAP `TN` con `xterm-kitty` o
  `xterm-ghostty` imposta il terminale (`in.c:1722-1725`). `KITTY_WINDOW_ID` non viene letto. `TERM_PROGRAM` serve
  solo su macOS, per `Apple_Terminal` (`termdesc.c:1124-1133`).
- Kitty (`apply_kitty_heuristics`, `termdesc.c:735-765`): quadranti, sestanti e RGB sempre; pixel
  `NCPIXEL_KITTY_ANIMATED` da 0.20.0 (il ramo SELFREF è commentato: «FIXME we have problems using SELFREF»).
- Ghostty (`apply_ghostty_heuristics`, `termdesc.c:930-934`): solo quadranti e sestanti; nessun backend pixel
  nell'euristica. Il pixel arriva dalla query della grafica kitty (`\e_Gi=1,a=q;\e\\`): una risposta qualsiasi
  imposta `kitty_graphics` (`in.c:1409-1415`), e senza un altro backend notcurses sceglie `NCPIXEL_KITTY_STATIC`
  (`termdesc.c:1527-1535`).
- Ottanti: solo foot da 1.20.0 (`termdesc.c:810-812`). Dopo le euristiche notcurses spegne braille, sestanti e
  ottanti se `wcwidth` della libc non conosce i glifi (`termdesc.c:1065-1075`).

## Risultati delle prove (Linux)

Script `prova.rb` nello scratchpad: `Context` sul terminale vero, blit di `spec/fixtures/visual/rgbw.png` (2×4 pixel)
in un piano 8×16 con `scale: :stretch` e `no_degrade: true`, poi `Direct#render_image(..., blitter: :pixel)` in un
secondo processo.

| Voce | Kitty 0.50.0 | Ghostty 1.4.0 |
| --- | --- | --- |
| `detected_terminal` | `Kitty 0.50.0` | `ghostty 1.4.0-arch1.1` |
| `pixel_support` | `:kitty_animated` | `:kitty_static` |
| quadranti, sestanti, braille, semiblocchi, RGB, UTF-8 | sì | sì |
| ottanti | no | no |
| `pixel_geom` (finestra massimizzata) | 667×2570 px, cella 23×10, bitmap max 667×2570 | 640×2547 px, cella 20×9, bitmap max 620×2547 |
| blit `:pixel`, `:quad`, `:sextant`, `:braille`, `:half`, `:ascii` | riusciti | riusciti |
| blit `:octant` | `VisualError` (atteso con `no_degrade: true`) | `VisualError` (atteso) |
| `Direct#render_image :pixel` | riuscito | riuscito |
| controllo a vista (utente) | 4 bande per ogni blitter, terminale pulito | 4 bande per ogni blitter, terminale pulito |

I valori corrispondono alle previsioni lette nel C. In Ghostty `max_bitmap_y` vale una riga meno di `pixel_y`; in
Kitty i due valori sono uguali. Ghostty scrive nel suo log `ignoring unimplemented CSI S with intermediates: ?` (query
sixel XTSMGRAPHICS) e `erroneous kitty graphics response: EINVAL: dimensions required` (la query kitty senza
dimensioni): notcurses conta anche la risposta d'errore come supporto della grafica kitty.

Sixel: non provato, nessuno dei due terminali lo supporta.

## Controlli dei lotti

| Lotto | Controllo | Kitty | Ghostty |
| --- | --- | --- | --- |
| 3 (ICH-272) | `Visual.from_plane(..., blitter: :four_by_one)` e `Plane#as_rgba(:eight_by_one)` con i quadranti attivi | `ArgumentError`, nessun SIGSEGV | `ArgumentError`, nessun SIGSEGV |
| 7 (ICH-279) | Shift+1 e Shift+2 in un `TextInput`, tastiera vera | testo `"!@"` | testo `"!@"` |
| 7 (ICH-280) | Ctrl+C in `EventLoop#run` | `:interrupt`, niente a `on_key`: con `send-key` per CapsLock (`\e[99;69u`), NumLock (`\e[99;133u`) e Ctrl da solo (`\e[99;5u`); con la tastiera vera 3 volte con NumLock | `:interrupt`, niente a `on_key`: tastiera vera, 3 volte con NumLock |
| 7 (ICH-281) | testo di `cols - 1` lettere più `漢`, Freccia sinistra: il cursore va sul glifo largo | riga che finisce con `漢` intero (`kitty @ get-text`), cursore in colonna 255 su 257 | `漢` nelle ultime due colonne (contenuto del piano), cursore in colonna 281 su 283 |
| 9 (ICH-284) | `Direct#stream` di `frames.mkv` (8×8 px, 4 frame) con `scale: :none` | `:half` e `:quad`: cursore 4 righe sotto l'inizio per tutti e 4 i frame; `:pixel`: 1 riga | uguale a Kitty |

- Il caso CapsLock di ICH-280 con la tastiera vera non è provabile su questa macchina: Hyprland intercetta CapsLock
  (`caps:menu`, superwhisper). In Kitty lo copre `kitty @ send-key ctrl+caps_lock+c`, che manda la stessa sequenza
  di un tasto vero (controllato leggendo i byte grezzi con il protocollo kitty acceso). In Ghostty il caso resta non
  provato.
- Il caso «Ctrl da solo» con la tastiera vera non è provabile: NumLock è sempre attivo. In Kitty lo copre `send-key`.
- Nessun difetto nuovo: nessuna prova ha incontrato ICH-454, ICH-455, ICH-456 o ICH-458. Lo `stream` è stato provato
  con frame piccoli, lontano dall'ultima riga, cioè fuori dal caso di ICH-458.

## Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| Lo script di prova in una finestra di Kitty resta fermo fino al timeout, anche il watchdog Ruby | `timeout` senza `--foreground` mette il comando in un process group in background: al primo `tcsetattr` o alla prima lettura del tty il kernel manda SIGTTOU o SIGTTIN e il processo si ferma (stato `T`, `pgrp` diverso da `tpgid`) | `timeout --foreground`. Il comando `timeout -k 5 -s KILL 60 ruby -Ilib "$S/prova.rb"` di `RIPRESA.md` va bene solo senza terminale |
| La prima sessione manuale in Kitty esce subito con `LoadError: cannot load such file -- ffi` | una finestra aperta con `kitty @ launch` non ha l'ambiente di mise: `command -v ruby` trova il Ruby 3.4 di sistema | percorso assoluto del Ruby di mise nello script |
| `kitty @ send-key shift+1` dà `"1"` e non `"!"` | `send-key` codifica il tasto senza il testo associato (id 49, testo `"1"`); il `TextInput` usa `eff_text`, che con il protocollo kitty viene dal testo associato | Shift+1 solo con la tastiera vera; `send-key` va bene per i modificatori |
| Il rilascio di Ctrl+X del processo precedente arriva al processo successivo | il rilascio arriva dopo la chiusura del primo contesto e resta nel tty | atteso: `on_input` lo vede come `:release`, nessun effetto |

## Parte 2 — spec grafiche (Linux), PR #20

- Branch `test/fase5-linux`, PR [#20](https://github.com/ichelema/notcursesruby/pull/20), merge `4d3430a`
  (confermato dall'utente); branch remoto cancellato.
- Commit: `4a3a053` `refactor(util): rimuovi Util.timespec, senza chiamanti` (punto aperto 1, scelta dell'utente),
  `523353d` `test(grafica): spec su un terminale vero in Kitty e Ghostty, solo con NC_GRAPHICS=1`.
- File: `spec/graphics/terminal_spec.rb` (5 esempi), `spec/graphics/probe.rb` (processo figlio, modi `context`,
  `direct`, `stream`, `signals`, `wide`), `CHANGELOG.md` («Aggiunto», «Rimosso»).
- `kitty @` usa sempre `--to "$KITTY_LISTEN_ON"` con stdin da `/dev/null`: senza socket parlerebbe con Kitty sul tty,
  dove legge anche il figlio di notcurses. Kitty dell'utente: `allow_remote_control yes`,
  `listen_on unix:/tmp/kitty-{kitty_pid}` in `~/.config/kitty/userprefs.conf`.
- L'output di RSpec va in un file con `--out`, così stdout resta il tty (con `> file` gli esempi vanno in skip).

| Controllo | Esito |
| --- | --- |
| `NC_GRAPHICS=1 bundle exec rspec spec/graphics` in Kitty 0.50.0 | 5 esempi, 0 fallimenti, 2,9 s |
| stessa spec in Ghostty 1.4.0 | 3 esempi verdi, 2 in skip («solo in Kitty») |
| stessa spec senza tty (tool Bash) | 5 in skip («serve un terminale») |
| figlio oltre il timeout (`NC_GRAPHICS_HOLD=30`, 60 s) | esempio fallito con «probe.rb context bloccato dopo 60 s»; schermo normale, cursore visibile (`kitty @ get-text --add-cursor`) |
| suite completa, ordine normale, `rand:1234`, `rand:7` | 1046 esempi, 0 fallimenti |
| suite completa, `rand:4242` | 1 fallimento intermittente in `spec/notcurses/context_spec.rb:358`, anche su `master` (vedi sotto) |
| coverage | righe 98,47 %, rami 91,5 %, soglie invariate |
| `bundle exec rubocop` | 0 offense, 99 file |
| `yard doc --fail-on-warning`, `yard stats --list-undoc` | exit 0, 100 % |
| `git diff b2fed69 -- lib/notcurses/ffi lib/notcurses/ffi.rb` | vuoto |
| CI della PR | verde su 3.1.7, 3.2.11, 3.3.13, 3.4.12, 4.0.9 e Codecov; 1046 esempi e nessun pending per job |

### Esempio instabile con il seme 4242

`spec/notcurses/context_spec.rb:358` («getvec passa al C al massimo 8192 slot») fallisce a volte con
`--order rand:4242`: `notcurses_getvec` riceve 2 chiamate con 8192 slot invece di 1. Succede anche su `master`
(`0f347b5`, worktree separato, 2 volte su 2) e sul branch 1 volta su 2: non dipende dalla Fase 5. Causa non cercata:
con stdin chiuso e l'ordine del seme 4242, il primo `getvec` del gruppo probabilmente non trova ancora l'EOF in coda
e il wrapper ripete la chiamata. Se fallisce, ripeti la suite; nessuna issue (la Fase 5 non ha issue Linear).

Causa confermata e spec corretta nella Parte 3 (macOS): vedi "Parte 3 — macOS", "Problemi e soluzioni".

## Parte 3 — macOS (in corso)

- Data: 2026-11-15. Branch `test/fase5-macos` da `master` dopo i commit del log; 4 commit, PR
  [#21](https://github.com/ichelema/notcursesruby/pull/21), CI verde su tutta la matrice e su Codecov (1047 esempi,
  0 fallimenti, nessun pending per job). Merge non ancora fatto.
- Hindsight: il server `127.0.0.1:8888` non risponde su questa macchina (`curl` esce con 7). Fonti: `RICONSEGNA.md`
  e i file `memory/`.

### Ambiente macOS

| Voce | Valore |
| --- | --- |
| Macchina | MacBook Pro, Apple M1 (arm64), macOS 26.5.2 (build `25F84`), Darwin 25.5.0 |
| Checkout | `/Users/sphynx/Sviluppo/Progetti/Personali/20261027_notcursesruby` |
| notcurses | 3.0.17 (`pkg-config`), Homebrew `notcurses 3.0.17_1`; in `/opt/homebrew/lib` anche `libnotcurses-ffi.3.dylib` |
| ffmpeg | Homebrew `9.0.2_1` |
| Ruby | 4.0.9 da frum (`/opt/homebrew/bin/frum`), Bundler 4.0.22, gem ffi 1.17.4 |
| Compilatore | `/usr/bin/gcc` = Apple clang 21.0.0 |
| coreutils | 9.12_1 da Homebrew, installato in questa sessione (`brew install coreutils`): `/opt/homebrew/bin/timeout` (macOS non ha un `timeout`) e `/opt/homebrew/bin/gtimeout`; `gnubin` non serve |
| Ghostty | 1.4.0 (`TERM=xterm-ghostty`, `TERM_PROGRAM=ghostty`, `COLORTERM=truecolor`): la sessione di Claude Code gira qui |
| Kitty | 0.50.0, installato in questa sessione (`brew install --cask kitty`), senza file di configurazione: remote control con le opzioni `-o allow_remote_control=yes -o listen_on=unix:/tmp/kitty-nctest` |
| Tastiera | layout con Shift+1 = `!` e Shift+2 = `@` |

### Caricamento

- `ruby -w -Ilib -e 'require "notcurses"'` funziona senza `DYLD_FALLBACK_LIBRARY_PATH` e senza warning: la gem ffi
  trova `/opt/homebrew/lib/libnotcurses.dylib` e `libnotcurses-core.dylib`. `ffi_lib` non cambia.
- ICH-313: il `types.conf` di ffi 1.17.4 su arm64-darwin ha `wchar_t` e `uintmax_t`.
- Oracolo: `spec/support/nc_oracle.rb:29` trova la libreria con il nome `notcurses-ffi`. `spec/inline_reimpl_spec.rb`:
  253 esempi passati, 1 pending (`va_list` solo con l'ABI System V x86_64).
- `spec/ffi_layout_spec.rb`: 6 esempi passati con Apple clang.

### Suite completa

| Momento | Esito |
| --- | --- |
| `master` (`76cd883`), senza `timeout` | 1046 esempi, 22 fallimenti, 10 pending, 2 min 22 s |
| `master`, con coreutils | 1046 esempi, 16 fallimenti, 10 pending, 1 min 33 s |
| branch, dopo i 3 commit | 1047 esempi, 0 fallimenti, 11 pending, circa 25 s |
| branch, ordine normale, `rand:1234`, `rand:4242`, `rand:7` | 0 fallimenti, 3 esecuzioni per ordine (12 in tutto) |
| branch, `rand:1`, `rand:31337`, `rand:99` | 0 fallimenti |
| branch, `rand:2026` | 0 fallimenti in 61 esecuzioni; 1 blocco in un'altra esecuzione (punto aperto 1) |
| branch, dopo il 4º commit, senza `gnubin` nel `PATH`: ordine normale, `rand:1234`, `rand:4242`, `rand:7` | 0 fallimenti |
| coverage | righe 98,47 %, rami 91,44 %, soglie invariate |
| `bundle exec rubocop` | 0 offense, 99 file |
| `yard doc --fail-on-warning`, `yard stats --list-undoc`, `gem build` | exit 0, 100 %, gem costruita |

Gli 11 pending hanno tutti un motivo scritto: `va_list` (1), `libc_malloc_debug` di glibc (3), `TIOCSCTTY` e `/proc`
in `ui_pty_spec.rb` (6), quadranti di `rxvt-256color` (1, nuovo).

### Cambi sul branch

| Commit | Cambio |
| --- | --- |
| `fix(ffi): su macOS notcurses_stop rilascia il GVL` | `lib/notcurses/ffi/functions.rb`: `notcurses_stop` con `blocking: ::FFI::Platform.mac?` (cambio della Fase 1 approvato dall'utente il 2026-11-15, solo su macOS: su Linux la chiamata non cambia); spec nuova in `spec/integration/pty_spec.rb`; voce in «Corretto» di `CHANGELOG.md` |
| `test(macos): spec portabili su macOS` | `NcHelpers::FD_DIR` e `NcHelpers.open_fd_count` (`/proc/self/fd` su Linux, `/dev/fd` su macOS) in 5 file; `osversion` con il prefisso `macOS`; U+2028 in `Reader#write` con attese per glibc e per macOS; `visual_spec.rb:673` in skip su macOS |
| `test(contesto): aspetta l'EOF prima di contare le chiamate a notcurses_getvec` | `spec/notcurses/context_spec.rb:358` |
| `test(macos): timeout o gtimeout nei processi figli, ls di BSD in subprocess_spec` | `NcHelpers::TIMEOUT` (`timeout`, altrimenti `gtimeout`) in 7 processi figli; `subprocess_spec.rb:88` confronta i descrittori con un `ls` di riferimento |

Le attese delle spec su Linux non cambiano (regola 17). `git diff b2fed69 -- lib/notcurses/ffi lib/notcurses/ffi.rb`
non è più vuoto: contiene solo il cambio del commit `fix(ffi)`.

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| 4 esempi di `pty_spec.rb` (`:386`, `:426`, `:433`, `:442`) bloccati fino al timeout, a volte | `Context#close` → `notcurses_stop` → `tcsetattr(TCSAFLUSH)` (`notcurses.c:147`). Su macOS `TCSAFLUSH` aspetta che il master del pty legga l'output in coda; il master è letto da un thread Ruby dello stesso processo, e `notcurses_stop` teneva il GVL. Su Linux il pty non aspetta. Stack con `sample`: thread principale in `tcsetattr` → `ioctl`, thread del pty in attesa del GVL | `blocking: ::FFI::Platform.mac?` su `notcurses_stop`. Spec deterministica: il thread del pty resta fuori da `read(2)` per 0,3 s dopo l'inizio della chiusura; prima del fix 15 blocchi su 15, dopo 0 su 15 |
| 12 esempi con `Errno::ENOENT` su `/proc/self/fd` | macOS non ha `/proc` | `/dev/fd` su macOS (`NcHelpers.open_fd_count`) |
| `stats_spec.rb:41` | su macOS `notcurses_osversion` restituisce `macOS <versione>` (`util.c:100-108`) | attesa `macOS` su macOS, `Linux` altrove |
| `reader_spec.rb:247`: `write("a\u2028b")` non solleva `WidgetError` | `wcwidth(U+2028)` vale 0 su macOS e -1 su glibc (`egcpool.h:130-137`): su macOS `nccell_load` legge il carattere intero e il C lo scrive | attese diverse per macOS e glibc; nessun cambio in `lib/` |
| `visual_spec.rb:673`: il figlio esce con «niente quadranti» | `unix_early_matches`, che riconosce `rxvt` da `TERM`, sta dentro `#ifndef __APPLE__` (`termdesc.c:1137-1155`): su macOS `rxvt-256color` non attiva i quadranti | skip su macOS con il motivo; le guardie di ICH-272 sollevano `ArgumentError` prima del C e le provano anche le spec normali |
| `context_spec.rb:358` con `rand:4242`: 2 chiamate a `notcurses_getvec` con 8192 slot (anche su `master`, su macOS 4 volte su 4) | con quel seme l'esempio è il primo del gruppo: l'EOF di `/dev/null` non è ancora in coda, il primo `notcurses_getvec` restituisce 0 e il wrapper ripete la chiamata (comportamento corretto) | la spec aspetta l'EOF con `get` prima di contare le chiamate; il controllo sul limite di 8192 slot resta |
| 5 esempi con `Errno::ENOENT` su `timeout` | macOS non ha `timeout` | `brew install coreutils` (la 9.12 installa `timeout` e `gtimeout`); le spec usano `NcHelpers::TIMEOUT`, che prende `gtimeout` se `timeout` manca |
| `subprocess_spec.rb:88`: `ls /dev/fd` elenca 5 descrittori, il limite era 4 | l'`ls` di macOS (BSD, con `fts`) apre 2 descrittori, l'`ls` di GNU 1. Con `gnubin` nel `PATH` la spec usava l'`ls` di GNU e passava | il limite viene da un `ls` di riferimento lanciato con `IO.popen` e `close_others: true`, che deve dare 4 o 5 voci |
| `bundle exec rspec` fallisce con `Bundler::GemNotFound` a metà sessione | la shell è passata dal Ruby 4.0.9 di frum al Ruby 4.0.7 di mise, che non ha le gem del progetto | la cartella `bin` del Ruby di frum all'inizio del `PATH` |
| una finestra di Kitty o Ghostty aperta dal tool Bash non ha l'ambiente della shell | Ghostty con `open -na` parte da launchd; Kitty eredita l'ambiente ma `TERM_PROGRAM=ghostty` resta quello della shell di partenza | negli script `PATH` esplicito (Ruby di frum e `/opt/homebrew/bin`); il terminale atteso della spec viene da `TERM`, che i due terminali impostano |
| Ghostty su macOS non si avvia con `ghostty -e` dal binario | su macOS la CLI di Ghostty non apre finestre | `open -na /Applications/Ghostty.app --args --wait-after-command=true -e <script>` |
| la finestra di Kitty si è chiusa al passo 2 delle prove interattive, senza esito | probabilmente un Ctrl+C al prompt «Premi Invio», scritto sotto le istruzioni della fase A: lo script zsh si ferma e Kitty chiude la finestra | lo script registra INT, QUIT, TSTP e HUP con un `trap` (un gestore, non un ignore, che i figli erediterebbero); finestra con `--hold`; istruzioni più chiare |
| nella prima prova termios con `send-key` `putstr` solleva `PlaneError` (testo di 298 colonne) | difetto dello script di prova: `on_input` scriveva ogni evento in una sola riga; gli eventi erano tasti scritti nella finestra nuova, che prende il focus | lo script registra gli eventi in più nel JSON e a schermo ne mostra il numero |
| l'attesa in background della fine delle prove non finisce mai | `pgrep -f 'interactive.sh kitty'` trova anche la riga di comando del ciclo di attesa | attesa su un file `.done` scritto dallo script |

Comando della suite usato su macOS (dopo `brew install coreutils`):

```sh
TERM=xterm-256color COLORTERM=truecolor LANG=C.UTF-8 LC_ALL=C.UTF-8 timeout -k 5 -s KILL 600 bundle exec rspec < /dev/null
```

### Prove sul terminale vero (macOS)

Le spec grafiche girano in una finestra nuova, perché il tool Bash non ha un tty. Ogni finestra esegue uno script
dello scratchpad che scrive l'esito in un file:

```sh
# Kitty: remote control solo con le opzioni, senza file di configurazione
kitty -o allow_remote_control=yes -o listen_on=unix:/tmp/kitty-nctest -- "$S/graphics.sh" kitty
# Ghostty: su macOS solo con open
open -na /Applications/Ghostty.app --args -e "$S/graphics.sh" ghostty
# graphics.sh: NC_GRAPHICS=1 bundle exec rspec spec/graphics --format documentation --out "$S/graphics.$1.log"
```

| Voce | Kitty 0.50.0 | Ghostty 1.4.0 |
| --- | --- | --- |
| `NC_GRAPHICS=1 bundle exec rspec spec/graphics` | 5 esempi, 0 fallimenti, 3,6 s | 3 esempi verdi, 2 in skip («solo in Kitty»), 1,0 s |
| stessa spec con `NC_GRAPHICS_HOLD=3` | 5 esempi, 0 fallimenti | 3 verdi, 2 in skip |
| `detected_terminal` (`probe.rb context`) | `Kitty 0.50.0` | `ghostty 1.4.0` |
| `pixel_support` | `kitty_animated` | `kitty_static` |
| quadranti, sestanti, braille, semiblocchi | sì | sì |
| ottanti | no | no |
| `pixel_geom` (finestra di default) | 637×390 px, cella 13×7, bitmap max 637×390 | 2008×1045 px, cella 19×8, bitmap max 2008×1026 |
| blit `:pixel`, `:quad`, `:sextant`, `:braille`, `:half`, `:ascii` | riusciti | riusciti |
| blit `:octant` | `VisualError` (atteso con `no_degrade: true`) | `VisualError` (atteso) |
| `Direct#render_image :pixel` (`probe.rb direct`) | riuscito, `can_pixel?` true | riuscito, `can_pixel?` true |
| controllo a vista (utente) | 4 bande per ogni blitter, terminale pulito | 4 bande per ogni blitter, terminale pulito |

- Il rischio scritto nel design (sezione 4) non si è verificato: la libc di macOS conosce U+1FB38 e notcurses lascia
  attivi i sestanti. La tabella delle attese non serve una riga per macOS.
- Come su Linux, in Ghostty `max_bitmap_y` vale una riga meno di `pixel_y`.
- Kitty scrive nel suo log `Unknown terminfo property: RGB` e `CSI code 0x0 has unsupported start modifier`: sono le
  query di notcurses all'avvio, senza effetti sulle prove.
- Sixel: non provato, nessuno dei due terminali lo supporta.

Prove interattive con la tastiera dell'utente (script `interactive.sh`, `termios.rb`, `shift.rb` dello scratchpad):

| Controllo | Kitty 0.50.0 | Ghostty 1.4.0 |
| --- | --- | --- |
| termios, `EventLoop#run` senza opzioni | flag `isig`, `ixon` durante `run`; Ctrl+C → `:interrupt`, `on_key` non riceve niente | uguale a Kitty |
| termios, `run(no_flow_control: true, no_linesigs: true)` | flag `-isig`, `-ixon`; `on_key` riceve Ctrl+C (ICH-455), Ctrl+Q, Ctrl+S, Ctrl+C; `x` → `:stop` | flag `-isig`, `-ixon`; `on_key` riceve Ctrl+Q, Ctrl+S, Ctrl+C; `x` → `:stop` |
| termios, dopo `run` e dopo `Context#close` | flag `isig`, `ixon`; `stty -g` uguale a quello di prima | uguale a Kitty |
| ICH-279, Shift+1 e Shift+2 in un `TextInput` | testo `"!@"` | testo `"!@"` |
| ICH-280, Ctrl+C con CapsLock, NumLock e da solo | spec grafica con `send-key`: `:interrupt` | non provato (solo in Kitty) |
| ICH-281, glifo largo nell'ultima colonna | spec grafica con `get-text`: riga che finisce con `漢` | non provato (solo in Kitty) |

- termios: su macOS `tcflag_t` è `unsigned long` e IXON e ISIG hanno i valori BSD. Il terminale vero mostra i flag
  attesi durante `run` e li ripristina alla fine: i valori di `lib/notcurses/ffi/` sono corretti su macOS.
- ICH-455 (issue aperta in Backlog, non corretta): in Kitty il Ctrl+C della fase A arriva al `run(no_linesigs: true)`
  della fase B, sia con `send-key` sia con la tastiera vera. In Ghostty, nella prova con la tastiera vera, no: il
  caso dipende dai tempi.
- Gli altri eventi che `on_input` riceve con il protocollo kitty sono il tasto Ctrl da solo (id 1115172, pressione e
  rilascio) e i rilasci delle lettere: attesi, senza effetti.
- Nessuna prova ha incontrato ICH-454, ICH-456 o ICH-458.

### Punti aperti

1. **Blocco raro in `Context#close` (macOS, causa non trovata).** Una volta in 62 esecuzioni della suite con
   `--order rand:2026` (sul branch, con `notcurses_stop` senza GVL), rspec si è fermato fino al timeout di 600 s
   (exit 137). Stack con `sample`:
   - thread principale: `rbffi_do_blocking_call` → `rb_nogvl` → `notcurses_stop` → `free_terminfo_cache` →
     `stop_inputlayer` → `pthread_join`;
   - thread di input di notcurses: `input_thread` → `poll`, anche dopo il `pthread_cancel` di `cancel_and_join`
     (`internal.h:1830-1839`, `in.c:2655-2670`);
   - nessun altro thread Ruby attivo: il timer thread in `kevent`, l'FFI Callback Dispatcher in
     `pthread_cond_wait`.

   L'esempio bloccato non è noto: quella esecuzione non aveva la traccia degli esempi. Dopo il blocco, altre 61
   esecuzioni con lo stesso seme non si sono bloccate: 46 con il GVL rilasciato (31 della suite completa, 15 senza
   `pty_spec.rb`) e 15 con il GVL tenuto come su `master` (senza `pty_spec.rb`). Anche 2000 aperture e chiusure di
   `Context` di fila, con e senza `drain_input`, non si bloccano. Il GVL rilasciato probabilmente non è la causa,
   perché nessun thread Ruby gira durante il blocco, ma un solo caso non basta a provarlo.

   Ipotesi da controllare, nessuna provata:
   - su macOS `block_on_input` chiama `poll` senza la maschera dei segnali (`in.c:2556-2558`, «FIXME smask?»); alcune
     spec mandano USR1, USR2, TERM, WINCH e CONT al processo (`lifecycle_spec.rb:397` e `:406`,
     `event_loop_spec.rb:78-80` e `:347-361`, `dialog_spec.rb:127-169`);
   - una gara tra `pthread_cancel` e l'entrata del thread di input in `poll` su Darwin.

   Per riprodurlo: lo script `hunt.sh` della sessione esegue la suite con un seme e la traccia degli esempi
   (`before`/`after` di RSpec su stderr), e al primo blocco campiona il processo con `sample <pid> 2`. Se il blocco
   torna, la traccia dice l'esempio. Un bug di notcurses va nelle tabelle di `RICONSEGNA.md`; un bug del wrapper
   segue la regola 11.
