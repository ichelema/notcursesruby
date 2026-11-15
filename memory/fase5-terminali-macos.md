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
