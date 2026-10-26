# Fase 3 — ciclo degli eventi, focus, resize e widget composti: log di lavoro

- Data di inizio: 2026-10-26
- Base: commit `383a14e` (Fase 2, review e fix di Ruby 3.1); suite di partenza 827 esempi, 0 fallimenti.
- Design: `memory/fase3-design.md`.

## Parte 0 — punti aperti della review

Commit `e710a92`. Per ogni punto prima una spec, fallita sul codice di allora (8 esempi rossi), poi il fix, poi la
suite completa: 831 esempi, 0 fallimenti su Ruby 4.0.7 (anche con il seme 4242) e su Ruby 3.1.7 (seme 4242).

| Punto | Cambio | Spec |
| --- | --- | --- |
| `Visual.from_plane` | `y: 0, x: 0, rows: nil, cols: nil` al posto di `begy:`, `begx:`, `leny:`, `lenx:`; `nil` = cursore o «fino al bordo»; `-1` e `0` sollevano `ArgumentError` | `visual_spec.rb`: «legge la regione con y:, x:, rows: e cols:, come Plane#as_rgba» |
| `Plane#as_rgba` | default `y: 0, x: 0` (prima il cursore) | `plane_spec.rb`: «as_rgba legge le celle come glifi del blitter» |
| `Visual.blit_*` | `linesize:` diventa `rowstride:` nei 4 metodi | `visual_spec.rb`: «accettano rowstride con padding, come i metodi from_*» |
| `Reel#empty?`, `Tabbed#empty?` | nuovi, come `Tree#empty?` | `reel_spec.rb`, `tabbed_spec.rb` |
| `Plane#putstr` | `"\n"` dopo una riga piena va a capo una volta sola | `plane_spec.rb`: «putstr: "\n" dopo una riga piena va a capo una volta sola» |

Decisioni:

- **Regione condivisa.** Nel C `ncvisual_from_plane` chiama `ncplane_as_rgba` con gli stessi argomenti
  (`visual.c:1214-1218`); la conversione Ruby → C della regione è ora `Util.c_region`, usata da entrambi. Il wrapper
  chiama ancora `ncvisual_from_plane`: la copertura FFI non cambia.
- **`pixel_buffer`.** Il parametro `name` serviva solo a `'linesize'`: rimosso, i messaggi dicono `rowstride`.
- **Nota su `putstr` (bug di 3.0.17, corretto nel comportamento).** Verificato nel C e con un esperimento: per `"\n"`
  `utf8_egc_len` restituisce 1 colonna (`egcpool.h:133-135`); con il cursore a `x == lenx` (dopo una riga piena)
  `ncplane_put` vede `linesend` e chiama `scroll_down` (`notcurses.c:1888-1890`), poi esegue il `"\n"` con un secondo
  `scroll_down` (`notcurses.c:1903-1904`). `"abcd\nefgh"` su 4 colonne lasciava una riga vuota. Il fix è corto e
  sicuro: `putstr` spezza il testo prima di ogni `"\n"` e, se il cursore è a `x == dim_x`, lo porta sull'ultima
  colonna (`ncplane_cursor_move_yx`) prima del `"\n"`; il C allora va a capo una volta sola. Con `y:` esplicito e
  `x: nil` il cursore va su `(y, dim_x - 1)`: sparisce anche lo scroll in più della riga di partenza. La cella
  `"\n"` che il C lascia sotto il cursore (A2-05) resta dove la lascia un `"\n"` normale. Serve alla Fase 3:
  `FdPlane`, `Subprocess` e i log scrivono righe larghe quanto il piano seguite da `"\n"`.
- **`Visual#blit`, `#geometry`, `#create_plane`** hanno ancora `begy:`, `begx:`, `leny:`, `lenx:` (regione in pixel
  del visual, `0` = fino al bordo): la decisione dell'utente riguardava solo `from_plane`; non cambiati.

## Parte 1 — design

Ricerca prima del design (C e esperimenti nello scratchpad):

- `notcurses_get` svuota tutto il pipe di prontezza a ogni lettura (`in.c:2751-2757`): il ciclo legge fino al primo
  `nil` a ogni risveglio.
- A fine stdin il pipe resta leggibile e `get` restituisce `NCKEY_EOF` senza svuotarlo (`in.c:2610-2616`,
  `2702-2710`). Con `drain_input: true` il fd è leggibile a fine stdin ma `get` solleva sempre `InputError` (provato
  su `/dev/null`).
- `NCKEY_RESIZE` entra in coda solo quando il thread di input elabora altro input (`in.c:2439-2445`).
- `render` e `refresh` rilevano le nuove dimensioni e ridimensionano lo stdplane (`render.c:62-114`).
- Shift+Tab (`kcbt`) arriva come `'\t'` con Shift (`in.c:190`); Ctrl+lettera arriva in maiuscolo con Ctrl
  (`load_ncinput`).
- Dentro un `trap`, su Ruby 4.0.7 e 3.1.7, funzionano `write_nonblock`, `syswrite` e `Queue#push`; `Mutex` solleva
  `ThreadError`.
- Senza tty `cursor_disable` e `mice_enable` sollevano `ContextError`; `cursor_enable` e `refresh` funzionano.
- notcurses 3 non ha uno stile «reverse»: il focus si mostra con i colori.

Domande all'utente (AskUserQuestion, due gruppi) e risposte: sezione 9 del design. L'unica scelta diversa da quella
consigliata è D3: in più un `LogView` per i dati di `FdPlane` e `Subprocess`. L'utente ha approvato il design con una
regola in più: un bug semplice trovato durante il lavoro si corregge subito, uno non semplice diventa una issue in
Linear (`/trinity:workflow:0_create-issue`). Nessun bug ha richiesto una issue.

## Parte 2 — implementazione

Un commit per area, ognuno con la suite completa verde su Ruby 4.0.7 e 3.1.7 prima del push:

| Commit | Area | Esempi nuovi | Suite |
| --- | --- | ---: | ---: |
| `6c55106` | `Context#drain_input?` e `#no_winch_sighandler?` (D6, cambio della Fase 2) | 1 | 832 |
| `aab16b6` | `EventLoop` e `Timer` | 18 | 850 |
| `db19dbc` | `Component`, `Text`, `Container`, `App` | 23 | 873 |
| `2534b02` | `Label`, `Button`, `TextInput`, `ListView`, `LogView`, `Dialog` | 35 | 908 |
| `692c455` | `spec/integration/ui_pty_spec.rb`, `examples/demo.rb` | 2 | 910 |

Per tenere coerente il commit `db19dbc`, `lib/notcurses/ui.rb` richiedeva solo i file di quell'area; i `require` dei
widget sono entrati con `2534b02`.

### Decisioni prese durante l'implementazione

- **Controllo del testo dei widget.** Il controllo esatto di `Plane#putstr` (`zero_width_egc!`) usa `nccell_load` ed è
  privato. Per usarlo serviva un cambio dell'API della Fase 2 o una chiamata FFI diretta, e il design approvato non
  prevede nessuna delle due. `Text.check!` applica alla creazione e nei setter le regole che Ruby vede da solo: TAB,
  `"\n"` dove non è ammesso, caratteri di controllo, U+2028, U+2029, grapheme di larghezza zero. Il caso residuo è un
  grapheme che notcurses 3.0.17 divide in modo diverso da Ruby (il keycap `"1️⃣"`): `putstr` lo rifiuta, e il disegno
  (`Component#put_text`) lo scrive come `"?"` invece di sollevare durante un layout. `LogView`, che riceve byte
  qualsiasi, usa lo stesso percorso. Commento `ponytail:` nel codice.
- **`layout_size` e `layout_weight`** (`@api private`) per le keyword `size:` e `weight:`, non `size` e `weight`: in
  `Reel`, `Tabbed` e `Tree` `size` è il numero di elementi (convenzione controllata da `api_spec.rb`), e un
  `ListView#size` con un altro significato confonderebbe.
- **Sopra l'App stanno solo `root` e i `Dialog`**: un altro componente con l'App come genitore solleva
  `ArgumentError` prima di creare il piano.
- **Rilasci.** I rilasci dei tasti non arrivano ai componenti (vanno solo a `on_input`); quelli del mouse sì. I widget
  ignorano comunque i rilasci anche se li ricevono da `offer_input`.
- **Blocchi dei widget.** `Button`, `TextInput` e `ListView` passano al blocco il widget stesso; `Dialog` passa
  l'etichetta scelta (nil per Esc) e chiama il blocco dopo la chiusura, così il blocco può aprire un altro dialogo o
  spostare il focus.
- **`App#close` dentro `run` ferma il ciclo** (come `stop`): altrimenti il giro successivo userebbe componenti chiusi.
- **Z-order.** Un piano nuovo va in cima alla pila: quando nasce un componente sotto un dialogo aperto, `App` riporta
  in cima le famiglie dei dialoghi (`Plane#move_family_top`).
- **Componenti nascosti.** Piano 1x1 in (-65536, -65536) rispetto al genitore. Un `layout(0, 0)` chiamato a mano dura
  fino al layout successivo del contenitore, che decide da solo.
- **Colori.** `FOCUSED_CHANNELS` bianco su `#005faf`, `FIELD_CHANNELS` nero su `#bcbcbc`: primo piano e sfondo
  espliciti, leggibili su terminali chiari e scuri. Senza il focus la voce scelta di un `ListView` è in grassetto.
- **Integrazione su un pty.** Il processo figlio fa del pty il proprio terminale di controllo (`Process.setsid` e
  `ioctl(TIOCSCTTY)`, valore Linux `0x540E`): così `"\x03"` scritto sul master manda SIGINT dal kernel e
  `slave.winsize = [30, 100]` manda SIGWINCH, come su un terminale vero. Il test di `:eof` usa un altro figlio con
  stdin su `/dev/null` e `drain_input: false`.

### Problemi e soluzioni

- Le spec nuove avevano 7 aspettative sbagliate, non il codice: `Plane#contents` salta le celle vuote (`"│"`, non
  `"│ "`), `Plane#at` su una cella vuota restituisce la cella base (`" "`), `"abcd漢"` entra in 6 colonne, in un campo
  di 5 colonne `"漢字"` con il cursore in colonna 4 è la vista giusta, `"cinque sei"` occupa esattamente 10 colonne.
  Corrette dopo il controllo dei numeri.
- Un `layout(0, 0)` a mano su un componente creato prima di un altro veniva annullato dal layout successivo: la spec
  ora nasconde il componente per ultimo (comportamento voluto).
- La demo, provata in un pty con `PTY.spawn` e tasti simulati, non reagiva a Ctrl+Q: vedi il primo bug sotto. La demo
  ora usa Ctrl+X; con Ctrl+X, Invio su «Sì» ferma l'App («Uscita: stop», exit 0).

### Bug e limiti di notcurses 3.0.17 trovati nella Parte 2

| Bug o limite | Dove | Effetto | Gestione |
| --- | --- | --- | --- |
| Modo del terminale: notcurses toglie solo ECHO, ICANON e ICRNL; ISIG resta (tranne con `notcurses_linesigs_disable`) e IXON non viene toccato | `termdesc.c:1631-1637`, `in.c:2840-2856` | Ctrl+S e Ctrl+Q restano il controllo di flusso, Ctrl+C, Ctrl+Z e Ctrl+\ restano segnali: non arrivano mai come tasti | YARD di `EventLoop#on_key`; esempio di `App` e demo con Ctrl+X |
| Condizione su `errno` in `read_input_nblock`: `errno != EAGAIN && errno != EBUSY && errno == EWOULDBLOCK` non è mai vera dove `EAGAIN == EWOULDBLOCK` (Linux) | `in.c:2180-2190` | ogni errore di `read`, anche EAGAIN o EIO, segna la fine dell'input: per esempio un pty il cui master si chiude dà `Key::EOF` | letto nel C, non riprodotto; `run` restituisce `:eof` |
| Segmentazione diversa da Ruby: notcurses divide il keycap `"1️⃣"` e ne scrive U+20E3 come carattere di larghezza zero | `nccell_load` | `putstr` lo rifiuta, ma Ruby lo vede come un solo grapheme largo 1 | disegnato come `"?"` (decisione sopra) |

## Parte 3 — controlli finali e documentazione

Controlli sul commit `692c455`, con uno script nello scratchpad (log per ogni esecuzione, esito PASS):

| Controllo | Risultato |
| --- | --- |
| Suite su Ruby 4.0.7: ordine normale, `--order rand:1234`, `rand:4242`, `rand:7` | 910 esempi, 0 fallimenti in tutte e 4 (circa 17 s ciascuna) |
| Suite su Ruby 3.1.7 (Gemfile copiato fuori dal progetto), stessi 4 ordini | 910 esempi, 0 fallimenti in tutte e 4 (circa 40 s ciascuna) |
| `ruby -w -Ilib -e 'require "notcurses"'` | nessun warning su 4.0.7 e 3.1.7 |
| `spec/coverage_spec.rb`, `spec/notcurses/api_spec.rb` | passano (dentro la suite); `api_spec.rb` vede anche le classi di `Notcurses::UI` |
| `yard_check.rb` e `yard_raise_check.rb` su 39 file di `lib/` (Fase 1 esclusa) | 0 problemi; 678 metodi controllati, solo il falso positivo noto `input.rb:300 to_ffi` |
| `git diff 5dbf71e -- lib/notcurses/ffi lib/notcurses/ffi.rb Gemfile Gemfile.lock` | nessun cambio |
| `examples/demo.rb` in un pty (`PTY.spawn`, tasti simulati) | saluto nel log, Ctrl+X apre la conferma, Invio su «Sì» ferma l'App (`Uscita: stop`, exit 0) |

Documentazione: sezione "Fase 3" in `RICONSEGNA.md` (file, classi, cambi dell'API della Fase 2, test, bug, cosa
serve alla fase successiva); questo log, rinominato da `fase3-log.md` a `fase3-ui.md` come chiede il prompt
(`memory/fase3-<argomento>.md`); stato e esempio con Ctrl+X nel design; retain in Hindsight (bank `notcursesruby`):
cause radice dei tasti consumati dal terminale e di `read_input_nblock`, tecnica del pty come terminale di
controllo, decisione sul controllo del testo, differenza fra `Plane#contents` e `Plane#at` nelle spec.
