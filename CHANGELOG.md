<!--
Generated from notcurses 3.0.17
Source: notcurses/include/notcurses/notcurses.h
-->
# Changelog

Tutti i cambi rilevanti di notcursesruby. Formato basato su
[Keep a Changelog](https://keepachangelog.com/it/1.1.0/); le versioni seguono
[Semantic Versioning](https://semver.org/lang/it/).

## [Non rilasciato]

### Corretto

- `Context#close`, `Direct#close` e `Context#drop_planes`: un'eccezione durante la chiamata C (per esempio un
  Ctrl-C) lascia l'oggetto chiuso, i piani distrutti invalidi e il registro libero; prima l'hook `at_exit`
  richiamava lo stop su memoria liberata (SIGSEGV) (ICH-268).
- `Context#close` e `Direct#close` in un figlio creato con `fork` non chiamano notcurses: il figlio non ripristina
  più il terminale del padre e non si blocca nello stop (ICH-269).
- `Context#close` e `Direct#close` funzionano dentro un gestore `trap` (ICH-270).
- `fork` svuota prima il buffer dell'output di un `Direct` aperto: il testo non ancora svuotato non si duplica
  all'uscita del figlio (ICH-433).
- Un resize che taglia un glifo largo non lascia più una metà orfana sul bordo del piano: la scrittura successiva
  su quella cella cancellava una cella della riga vicina o corrompeva l'heap. Vale per `Plane#resize`,
  `#resize_region` e `#resize_maximize` e per i resize fatti da notcurses (stdplane quando il terminale si
  restringe, figli con `resize: :maximize`) (ICH-271).
- `Visual.from_plane` e `Plane#as_rgba` non vanno più in SIGSEGV con i blitter dei plot `:four_by_one` e
  `:eight_by_one` sui terminali con i quadranti (Kitty, Ghostty, rxvt): sollevano `ArgumentError`. Lo stesso vale per
  `Visual#blit`, `#geometry`, `#create_plane`, `#stream` e `Visual.blit_*`, che prima tagliavano l'immagine senza
  errore. `Plot` accetta ancora i due blitter (ICH-272).
- `Reader#offer_input` e `#write` scartano un carattere di larghezza zero (U+FE0F di "❤️", ZWJ, U+200B, un segno
  combinante isolato) sull'ultima colonna: prima il cursore andava oltre la riga, il testo successivo si perdeva e
  Backspace seguito da una freccia sinistra terminava il processo (asserzione di `ncreader_redraw`). Se il cursore
  della vista non torna al suo posto, i metodi del `Reader` sollevano `WidgetError` prima della chiamata C (ICH-273).
- `Reader#write` non perde più la parte dei grapheme che notcurses divide in più EGC (il keycap "1️⃣", le bandiere, i
  congiunti devanagari): scrive i pezzi uno alla volta, ciascuno in una cella (ICH-274).
- `Reader#contents` legge la vista con `Plane#contents`: `ncreader_contents` lasciava nell'egcpool della vista una
  copia di ogni EGC lungo a ogni chiamata, e dopo qualche decina di migliaia di letture `contents` sollevava
  `WidgetError`. Ora può sollevare `PlaneError` se la lettura di una cella fallisce (ICH-275).
- `Tree.new`, `Tabbed.new` e `Reel.new` sollevano `WidgetError` dentro un callback chiamato da notcurses, come gli
  altri widget, e lasciano il piano aperto: prima il blocco di un tablet poteva creare il widget su un figlio del
  piano del tablet, il reel distruggeva quel piano nello stesso ridisegno e la chiusura liberava i piani una seconda
  volta (abort) o lasciava il `Tabbed` su piani liberati (SIGSEGV, `ClosedError` in `Context#close`) (ICH-276).
- `MultiSelector#offer_input` solleva `WidgetError` prima della chiamata C se il piano del widget ha una sola riga:
  prima il disegno di notcurses girava circa 2^32 volte tenendo il GVL e il processo si bloccava (ICH-277).
- `EventLoop#run` (e quindi `UI::App`) ridisegna lo schermo dopo Ctrl+Z e `fg`: con il default
  `no_winch_sighandler: true` installa anche `trap('CONT')` e chiama `Context#refresh`, senza `on_resize` se le
  dimensioni non cambiano; prima il testo scritto dalla shell restava sullo schermo fino al resize successivo. Il
  YARD di `Context` e di `Key::SIGNAL` ora dice che quel flag toglie anche il gestore di SIGCONT di notcurses
  (ICH-278).
- `UI::TextInput` inserisce il testo digitato (`Input#eff_text`) e `EventLoop#on_key` confronta un carattere
  stampabile con quel testo: con il protocollo tastiera kitty (Kitty, Ghostty) Shift+1 inseriva "1" invece di "!" e
  attivava `on_key('1')` invece di `on_key('!')`. Il YARD di `Input#utf8` dice che è il tasto senza Shift, e quello
  di `on_key` il limite di Alt o Ctrl con Shift e un simbolo (ICH-279).
- `EventLoop#run` (e quindi `UI::App`) esce con `:interrupt` anche per il Ctrl+C di kitty con CapsLock o NumLock
  attivi, e alza SIGSTOP e SIGQUIT per Ctrl+Z e Ctrl+\: prima notcurses consegnava il tasto e il ciclo andava
  avanti. Con ISIG attivo questi tasti non arrivano più a componenti, `on_key` e `on_input`, nemmeno l'evento che
  notcurses mette in coda per il Ctrl+C senza blocchi (ICH-280).
- `UI::TextInput` scorre il testo anche per il grapheme sotto il cursore: un glifo largo dopo il cursore
  nell'ultima colonna restava tagliato, e Canc cancellava un carattere non visibile (ICH-281).

## [0.1.0] - 2026-10-27

Prima versione. Binding completo di notcurses 3.0.17.

### Aggiunto

- **Layer FFI raw** (`Notcurses::FFI`): mappatura 1:1 dell'API C di `notcurses.h` e `direct.h`. 385
  `attach_function` (373 di notcurses, 12 della libc), 248 funzioni `static inline` e macro reimplementate in Ruby,
  27 struct, 6 enum, 343 costanti. Le funzioni che aspettano il terminale rilasciano il GVL (`blocking: true`).
- **Wrapper Ruby idiomatico:** `Context`, `Plane`, `Cell`, `Channel` e `Channels`, `Input` e `Key`, `Palette`,
  `Pixel`, `Stats`, `Visual`, `Direct`, `FdPlane`, `Subprocess` e i widget C (`Selector`, `MultiSelector`, `Menu`,
  `Reader`, `Reel`, `Tabbed`, `Tree`, `Plot`, `ProgBar`). Ogni puntatore C ha un distruttore (`close` o `destroy`),
  ogni errore C diventa un'eccezione della gerarchia `Notcurses::Error`, le opzioni con un default sono keyword
  arguments.
- **`Notcurses::UI`:** ciclo degli eventi (`EventLoop`: `post`, `stop`, timer, `on_key`, `on_input`, `on_resize`),
  `App` con focus, mouse e dialoghi modali, widget composti in Ruby (`Container`, `Label`, `Button`, `TextInput`,
  `ListView`, `LogView`, `Dialog`).
- `EventLoop#run` e `App#run` accettano `no_flow_control:` (Ctrl+S e Ctrl+Q arrivano come tasti) e `no_linesigs:`
  (Ctrl+C, Ctrl+Z e Ctrl+\ arrivano come tasti).
- `examples/demo.rb`: prova manuale di `Notcurses::UI` su un terminale vero.

### Limiti noti

- Diversi bug di notcurses 3.0.17 sono aggirati nel wrapper; alcune funzioni C non sono offerte perché non
  funzionano in 3.0.17 (per esempio `ncpile_render_to_buffer` e `ncpile_render_to_file`).
- notcurses non è thread-safe: un contesto va usato da un solo thread alla volta.
- Provato solo su Linux x86_64. macOS non è provato; Windows non è supportato.

[Non rilasciato]: https://github.com/ichelema/notcursesruby/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/ichelema/notcursesruby/commits/master
