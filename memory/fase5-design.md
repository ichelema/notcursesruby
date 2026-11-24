# Fase 5 — design: blitter su un terminale vero e macOS

Data: 2026-11-15. Base: `667e5bc`. Stato: **approvato dall'utente il 2026-11-15**.

La Fase 5 prova i blitter grafici su un terminale vero e porta il binding su macOS. Non aggiunge funzionalità al
binding. Risultati delle prove della Parte 1, ambiente e problemi: [ambiente.md](ambiente.md), [comandi.md](comandi.md)
e [punti-aperti.md](punti-aperti.md). Le scelte segnate
con «utente» sono state decise dall'utente con AskUserQuestion il 2026-11-15.

## 0. Scelte dell'utente

| Scelta | Decisione |
| --- | --- |
| Forma delle prove grafiche | spec in `spec/graphics/`, gruppo con `if: ENV["NC_GRAPHICS"] == "1"`: senza la variabile RSpec esclude il gruppo in silenzio (nessun pending nella suite normale e in CI) |
| Cosa controllano | blitter e capacità; `Direct#render_image :pixel` e `Direct#stream`; tasti del lotto 7 con `kitty @ send-key` (solo Kitty); pausa facoltativa per il controllo a vista |
| Attese | tabella esatta per terminale (valori di notcurses 3.0.17); un rilevamento diverso fa fallire l'esempio; un terminale che non è Kitty né Ghostty va in skip |
| `Util.timespec` (punto aperto 1) | rimosso nella PR della Parte 2, con una voce in `CHANGELOG.md` |
| Flusso di lavoro (dal prompt) | branch `test/fase5-linux` e `test/fase5-macos`, una PR per parte; merge confermato dall'utente |

## 1. Come si controlla l'esito

- **Il C:** il valore di ritorno di ogni chiamata (`blit` con `no_degrade: true` solleva `VisualError` se il blitter
  manca), le capacità e `pixel_support`, la posizione del cursore di `Direct` (`cursor_yx`, che interroga il
  terminale).
- **Il terminale, solo in Kitty:** `kitty @ get-text` legge il testo dello schermo (per esempio il glifo largo
  nell'ultima colonna). Ghostty non ha un comando equivalente: lì basta il contenuto del piano.
- **A vista:** fatto una volta nella Parte 1, in tutti e due i terminali, con la conferma dell'utente. Nelle spec
  resta facoltativo: con `NC_GRAPHICS_HOLD=<secondi>` ogni blit resta a schermo per quel tempo.
- Le immagini disegnate non si possono rileggere dal terminale: che l'immagine compaia davvero lo dice solo il
  controllo a vista.

## 2. File della Parte 2

| File | Contenuto |
| --- | --- |
| `spec/graphics/terminal_spec.rb` | le spec grafiche, gruppo con `if: ENV["NC_GRAPHICS"] == "1"` |
| `spec/graphics/probe.rb` | script dei processi figli: modi `context`, `direct`, `stream`, `keys`; scrive l'esito in un file JSON |
| `lib/notcurses/util.rb` | rimozione di `Util.timespec` |
| `CHANGELOG.md` | `[Non rilasciato]`: sezione «Rimosso» per `Util.timespec`, sezione «Aggiunto» per le spec grafiche |

Regole per i file nuovi: intestazione di due righe (regola 20), stile di Standard con le virgolette doppie (regola 19),
nessun cambio a `.rubocop_todo.yml`. Nessuna dipendenza nuova: niente cambi a `Gemfile` e `Gemfile.lock`.

### 2.1 Gating

1. Senza `NC_GRAPHICS=1` il gruppo non gira (metadato `if:`, filtro di esclusione predefinito di RSpec).
2. Con `NC_GRAPHICS=1`, ogni esempio va in skip con il motivo se stdin o stdout non sono un tty, oppure se il
   terminale atteso non è Kitty né Ghostty. Il terminale atteso viene dall'ambiente: `TERM=xterm-kitty` → Kitty;
   `TERM=xterm-ghostty` o `TERM_PROGRAM=ghostty` → Ghostty.
3. Gli esempi dei tasti vanno in skip fuori da Kitty, o se `kitty @ ls` non risponde (remote control spento).
4. `TERM` sceglie l'atteso della spec, non è il rilevamento di notcurses: per Kitty e Ghostty notcurses legge le
   risposte XTVERSION o XTGETTCAP `TN`, non `KITTY_WINDOW_ID`. In Ghostty 1.4 la risposta `EINVAL: dimensions
   required` alla query della grafica kitty conta come risposta, perché `kittygraph_cb` imposta il flag senza esaminare
   l'esito (`notcurses/src/lib/in.c:1409`): `:kitty_static` è corretto anche se il log mostra l'errore.

### 2.2 Processi figli

- Ogni prova gira in un processo figlio (`spawn` di `RbConfig.ruby -I lib spec/graphics/probe.rb <modo> <json>`), con
  stdin e stdout ereditati dal terminale: un solo contesto per processo, e la suite non tiene un contesto aperto.
- Il figlio resta nel process group in primo piano (nessun `timeout`, nessun `setsid`): in background verrebbe
  fermato da SIGTTOU (problema trovato nella Parte 1). Il timeout è nel padre, come `run_child` di
  `spec/integration/pty_spec.rb`: dopo la scadenza `Process.kill(:KILL, pid)` e un fallimento con il log.
- Dopo un figlio ucciso il terminale può restare nel modo di notcurses: il padre esegue `stty sane` e scrive
  `\e[?1049l\e[?25h` (schermo normale, cursore visibile) prima di fallire (regola 16).

### 2.3 Esempi

| Esempio | Attese |
| --- | --- |
| capacità e rilevamento | `detected_terminal` inizia con `Kitty ` o `ghostty `; `pixel_support` `:kitty_animated` (Kitty) o `:kitty_static` (Ghostty); quadranti, sestanti, braille e semiblocchi sì; ottanti no; `pixel_geom` con celle e area > 0 |
| blit con ogni blitter | `:pixel`, `:quad`, `:sextant`, `:braille`, `:half`, `:ascii` riusciti con `no_degrade: true`; `:octant` solleva `VisualError` |
| `Direct` | `can_pixel?` true; `render_image(..., blitter: :pixel)` riuscito |
| `Direct#stream` (ICH-284) | `frames.mkv` (8×8 px, 4 frame) con `scale: :none`: per ogni blitter il cursore è alla stessa riga dopo tutti e quattro i frame, sotto la riga iniziale. La spec controlla +4 righe per `:half` e `:quad`; per `:pixel` controlla solo che il cursore scenda (misurato: +1 riga) (`spec/graphics/terminal_spec.rb:126-138`) |
| tasti (solo Kitty, ICH-280) | `send-key` di Ctrl+C con CapsLock, con NumLock e da solo durante `EventLoop#run`: ogni run restituisce `:interrupt` e `on_key` non riceve niente |
| glifo largo (solo Kitty, ICH-281) | `TextInput` con `cols - 1` lettere più `漢`, `send-key left`: `kitty @ get-text` mostra la prima riga che finisce con `漢` |

Fuori dalle spec, con il motivo:

- Shift+1 (ICH-279): `send-key` non manda il testo associato, quindi la prova vera serve la tastiera dell'utente.
  Controllato a mano nella Parte 1, in Kitty e Ghostty.
- ICH-272: le guardie sollevano `ArgumentError` prima del C e non dipendono dal terminale; le spec normali le coprono
  già.
- Sixel: nessuno dei due terminali lo supporta.

La tabella delle attese vale per notcurses 3.0.17. Un aggiornamento di notcurses che cambia le euristiche
(`termdesc.c`) fa fallire la spec: è il segnale voluto (utente).

### 2.4 Come si avvia

Da Kitty o Ghostty, dalla radice del progetto, con il `TERM` del terminale (non `xterm-256color`):

```sh
NC_GRAPHICS=1 bundle exec rspec spec/graphics
NC_GRAPHICS=1 NC_GRAPHICS_HOLD=3 bundle exec rspec spec/graphics   # con il controllo a vista
```

Da una sessione senza terminale (per esempio il tool Bash di Claude Code) la spec si avvia in una finestra nuova:
`kitty @ launch --type=os-window --cwd="$PWD" -- <comando>`, oppure `ghostty -e <comando>`, con il percorso assoluto
del Ruby di mise e l'output di RSpec in un file.

## 3. Rimozione di `Util.timespec`

`Util` è `@api private` e `Util.timespec` (`lib/notcurses/util.rb:360-382`) non ha chiamanti né spec. La rimozione
non tocca la Fase 1: `FFI::Timespec` resta, perché la usano le funzioni C e `spec/ffi_layout_spec.rb`. Dopo la
rimozione: suite completa, coverage, `yard stats --list-undoc` al 100 %.

## 4. Piano per macOS (Parte 3)

1. Branch `test/fase5-macos` da `master` aggiornato dopo il merge della Parte 2.
2. `brew install notcurses coreutils`; controlla se Homebrew installa `libnotcurses-ffi` e con quale nome
   (`spec/support/nc_oracle.rb:29`).
3. Caricamento: `ruby -Ilib -e 'require "notcurses"'`, prima senza variabili, poi con
   `DYLD_FALLBACK_LIBRARY_PATH="$(brew --prefix)/lib"`. Un cambio di `ffi_lib` tocca la Fase 1: chiedi all'utente
   (regola 1). Controlla `wchar_t` e `uintmax_t` (ICH-313).
4. termios: `EventLoop#run(no_flow_control: true, no_linesigs: true)` in un terminale vero (Ctrl+Q, Ctrl+S, Ctrl+C
   arrivano a `on_key`, `stty -g` torna quello di prima).
5. Prove grafiche: `NC_GRAPHICS=1 bundle exec rspec spec/graphics` in Kitty e Ghostty; controllo a vista con
   `NC_GRAPHICS_HOLD`; i controlli manuali del lotto 7 (Shift+1) con gli script della Parte 1.
6. Suite completa con `gtimeout` (o il `PATH` di coreutils); le spec legate a Linux (tabella della Parte 3 di
   `handoff.md`) vanno in skip con il motivo o diventano portabili (regola 17).

Rischio noto per macOS: notcurses spegne sestanti e ottanti se `wcwidth` della libc non conosce i glifi
(`termdesc.c:1065-1075`). Se la libc di macOS non conosce U+1FB38, i sestanti risultano assenti anche in Kitty e
Ghostty, e la tabella esatta fallisce. In quel caso la tabella riceve una riga per macOS, con il motivo scritto nella
spec: è una differenza della libc, non del terminale. Sul macOS 26.5.2 provato U+1FB38 non ha disattivato i sestanti,
quindi quella riga non è servita. Esiti delle prove di caricamento e delle spec: [ambiente.md](ambiente.md) e
[comandi.md](comandi.md).

## 5. Ordine di lavoro e commit

1. Commit di sola documentazione su `master`, con `[skip ci]`: questo design e la storia delle prove.
2. Branch `test/fase5-linux`: commit `test(grafica): ...` per `spec/graphics/`, `refactor(util): rimuovi
   Util.timespec` con la voce di `CHANGELOG.md`.
3. Suite completa (ordine normale e semi `1234`, `4242`, `7`), coverage, `bundle exec rubocop`, poi la spec grafica in
   Kitty e Ghostty con l'esito nel log.
4. PR, CI verde su tutta la matrice, merge dopo la conferma dell'utente; il branch remoto si elimina.

## 6. Controlli di accettazione della Parte 2

- `NC_GRAPHICS=1 bundle exec rspec spec/graphics` passa in Kitty e in Ghostty su Linux; fuori da un terminale va in
  skip con il motivo; senza `NC_GRAPHICS` la suite normale ha lo stesso numero di esempi di prima (1046) e 0 pending
  in più.
- La suite completa e la CI restano verdi, con le soglie di coverage invariate.
- `bundle exec rubocop` 0 offense; `git diff b2fed69 -- lib/notcurses/ffi lib/notcurses/ffi.rb` vuoto.
- Il terminale resta pulito dopo la spec grafica, anche quando un esempio fallisce.
