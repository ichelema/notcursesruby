<!--
Generated from notcurses 3.0.17
Source: notcurses/include/notcurses/notcurses.h
-->
# Changelog

Tutti i cambi rilevanti di notcursesruby. Formato basato su
[Keep a Changelog](https://keepachangelog.com/it/1.1.0/); le versioni seguono
[Semantic Versioning](https://semver.org/lang/it/).

## [Non rilasciato]

### Aggiunto

- Spec grafiche su un terminale vero (`spec/graphics/`), solo con `NC_GRAPHICS=1` in Kitty o Ghostty: rilevamento
  del terminale, capacità, blit con ogni blitter (anche `:pixel`), `Direct#render_image` e `Direct#stream` con
  `:pixel`, e in Kitty i tasti di controllo con `kitty @ send-key`. Senza la variabile la suite non le esegue.

### Rimosso

- `Notcurses::Util.timespec` (`@api private`): non aveva chiamanti.

### Corretto

- Un piano che ha fatto scroll tiene le righe nell'ordine in cui si vedono in `Plane#duplicate`, in `#resize`,
  `#resize_region` e `#resize_maximize`, in `#rotate_cw` e `#rotate_ccw`, come destinazione di `#merge_down` e nelle
  dissolvenze (`FadeContext`, `#fadeout`, `#fadein`, `#pulse`); anche nei resize che fa notcurses: lo stdplane quando
  cambia il terminale, i figli con `resize: :maximize`, la crescita per autogrow. Prima notcurses 3.0.17 permutava o
  perdeva righe (`logrow`). Il wrapper rimette in ordine le righe subito dopo ogni sua chiamata che fa scorrere il
  piano, scrivendo nei campi privati del piano C: lo fa solo con la libreria 3.0.17, altrimenti il bug resta. Non
  corregge gli scroll fatti con le funzioni di `Notcurses::FFI`, né il resize del terminale visto dal render che
  notcurses esegue dentro lo scroll di uno stdplane che scorre (ICH-214).
- `Plane#resize`, `#resize_region`, `#resize_maximize` e il controllo dei bordi prima delle scritture svuotano la
  metà di un glifo largo tagliato dal resize anche quando notcurses non riesce a rileggere il glifo. Con l'egcpool
  del piano pieno (16 MiB) `ncplane_at_yx_cell` fallisce sugli EGC di più di 4 byte: il wrapper ora legge quelle
  celle con `ncplane_at_yx`, che non usa il pool, e ne misura la larghezza. Prima la metà sinistra tagliata restava
  nell'ultima colonna, e la scrittura successiva su quella cella cancellava la prima cella della riga sotto o,
  sull'ultima riga, corrompeva l'heap; un glifo largo illeggibile rimasto intero nelle ultime due colonne perdeva
  invece la metà destra. Anche `#erase_region`, `#gradient`, `#gradient2x1` e `#polyfill` ora leggono quelle celle,
  e non svuotano più nel dubbio le due metà (ICH-487).
- `Plane#merge_down` rimette la metà destra anche ai glifi larghi di `dst` che notcurses non riesce a rileggere
  (egcpool di `dst` pieno, EGC di più di 4 byte): li legge con `ncplane_at_yx`, che non usa il pool, e li riscrive
  con gli stili e i colori della cella; se nemmeno la riscrittura riesce, le due metà diventano celle vuote. Stili,
  colori e cursore di `dst` non cambiano. Prima quei glifi restavano con la metà destra larga 0, e alcune sequenze
  di scritture cancellavano la prima cella della riga sotto o corrompevano l'heap (ICH-485).
- `Plane#resize_region` con `keep_x > 0` conserva gli EGC di più di 4 byte della regione (emoji con ZWJ o con un
  modificatore, lettere con più segni combinanti). Prima notcurses 3.0.17 ne rilasciava una parte dall'egcpool:
  quelle celle restavano vuote, `Plane#contents` sollevava `PlaneError`, e dopo altre scritture una cella poteva
  mostrare l'EGC di un'altra. Il wrapper fa il resize in due passi (prima con qualche riga vuota in più in alto,
  poi le toglie): quando serve, cioè con `keep_x + x_off > -y_off * cols`, i callback di resize dei figli vengono
  chiamati due volte (ICH-215).
- `Plane#duplicate` copia anche il flag `fixed` e l'allineamento verticale del piano: la copia di un piano creato
  con `fixed: true` non scorre più con il genitore, e `resize_realign` la riallinea come l'originale. Prima
  `ncplane_dup` di notcurses 3.0.17 li azzerava (ICH-216).
- `Plane#merge_down` ripetuto su un `dst` con EGC di più di 4 byte (emoji con un modificatore, lettere con più segni
  combinanti) lascia invariato il contenuto di `dst`. Prima notcurses 3.0.17 copiava a ogni merge quegli EGC
  nell'egcpool di `dst` senza rilasciare le copie vecchie: il pool cresceva fino al limite di 16 MiB, poi le celle
  di `dst` restavano vuote senza errore (ICH-482).
- Le stringhe e i buffer allocati da notcurses (`Plane#at`, `Plane#name`, `Plane#as_rgba`, `Context#stats`,
  `Context#at`, `detected_terminal`, `Notcurses.hostname` e gli altri) si liberano con la `free` di notcurses. Prima
  il wrapper usava la `free` di glibc anche quando `LD_PRELOAD` mette un altro allocatore (jemalloc, tcmalloc,
  `libc_malloc_debug`), e il processo terminava con `double free or corruption` (ICH-449).
- `Plane#erase_region`, `#gradient`, `#gradient2x1` e `#polyfill` su una sola metà di un glifo largo svuotano anche
  l'altra metà, anche quando la chiamata C fallisce a metà (`PlaneError`). Prima la metà orfana restava, e una
  scrittura larga vicina cancellava la prima cella della riga dopo, o sull'ultima riga scriveva fuori dal piano e
  corrompeva l'heap (ICH-450). Se notcurses non riesce a leggere una cella (egcpool pieno), il wrapper la tratta come
  una possibile metà sinistra e, nel dubbio, svuota le due metà del glifo.
- Il controllo delle metà orfane dopo i resize fatti da notcurses vale per il piano C, non per il singolo `Plane`: un
  `Plane` preso in prestito (`tracked: false`) usa lo stato del `Plane` tracciato dello stesso piano, e senza un
  `Plane` tracciato controlla i bordi a ogni scrittura. Prima un glifo largo scritto da un secondo wrapper e tagliato
  da un resize del terminale sfuggiva al controllo del primo, e la sua scrittura successiva cancellava la prima cella
  della riga sotto o, sull'ultima riga, corrompeva l'heap (ICH-448).
- `Plane#merge_down` lascia in `dst` glifi larghi con la metà destra normale: `dst.at` sulla metà destra restituisce
  il glifo, e una scrittura su una delle due metà cancella il glifo intero, come su ogni altro piano; il cursore di
  `dst` non cambia, anche quando è a fine riga. Prima la metà
  destra restava con larghezza 0 (bug di notcurses 3.0.17): `at` restituiva la cella base, e alcune sequenze di
  scritture lasciavano una metà destra orfana, cancellavano la prima cella della riga sotto o corrompevano l'heap
  (ICH-481).
- macOS: `Context#close` rilascia il GVL durante `notcurses_stop`, che con `tcsetattr(TCSAFLUSH)` aspetta che il
  terminale legga l'output in coda. Prima un terminale servito da un thread dello stesso processo (per esempio un
  pty nei test) bloccava la chiusura per sempre. Un'eccezione asincrona (`Thread#raise`, `Timeout`) per il thread
  che chiude arriva dopo lo stop, e non lascia il terminale nel modo di notcurses. Su Linux la chiamata non cambia.
- `Visual.from_file`, `Visual#decode`, `Visual#decode_loop`, `Direct#render_frame`, `Direct#load_image`,
  `Direct::Image.new` e `Direct#stream` aprono e leggono il file con ffmpeg senza il GVL: con una FIFO, un URL o un
  file system lento gli altri thread Ruby girano. Prima una FIFO riempita da un thread dello stesso processo
  bloccava la chiamata per sempre (ICH-312).
- `require 'notcurses'` funziona anche dove il `types.conf` della gem ffi non ha `wchar_t` o `uintmax_t` (FreeBSD,
  NetBSD, OpenBSD, Linux i386, ppc64, riscv64 e s390x): prima sollevava `TypeError`. Anche `Direct#box` non dipende
  più dalla mappa globale dei tipi di ffi (ICH-313).
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
  avanti. Con ISIG attivo questi tasti di kitty, e il Ctrl+C di xterm con modifyOtherKeys, non arrivano più a
  componenti, `on_key` e `on_input`, nemmeno l'evento che notcurses mette in coda per il Ctrl+C senza blocchi; i
  byte di controllo (0x03 da una pipe o con intr rimappato) restano tasti, anche con kitty (ICH-280).
- `UI::TextInput` scorre il testo anche per il grapheme sotto il cursore: un glifo largo dopo il cursore
  nell'ultima colonna restava tagliato, e Canc cancellava un carattere non visibile (ICH-281).
- `UI::LogView#append` accetta una stringa vuota: senza una riga non finita in attesa (vista nuova, dopo `clear` o
  dopo un `"\n"`) la riga non finita diventava `nil`, e da quel momento `append`, `lines`, il ridisegno e il layout
  del contenitore sollevavano `NoMethodError` (ICH-282).
- `UI::App`: un drag con BUTTON1..3 premuto non ripete più il clic. notcurses consegna il movimento come nuove
  pressioni dello stesso tasto: un `Button` chiamava il blocco a ogni cella e il focus passava a ogni componente
  attraversato. Ora una pressione con lo stesso tasto già premuto non cambia il focus e arriva solo a `on_input`.
  Sulla console Linux (gpm, senza rilasci) ogni pressione resta un clic (ICH-283).
- `Direct#stream` disegna ogni frame sopra il precedente: con i frame più stretti del terminale prima saliva di una
  riga in meno, ogni frame scendeva di una riga, la prima riga dei frame precedenti restava sullo schermo e in fondo
  al terminale lo schermo scorreva a ogni frame. Con il blitter `:pixel`, per un frame più basso dello schermo che
  finisce sull'ultima riga (per esempio con il cursore in fondo) l'esito dipende dal terminale. Se il terminale ferma
  il cursore sull'ultima riga del frame, prima i frame più stretti del terminale si sovrapponevano, ora i frame dopo
  il primo partono una riga più in alto e l'ultima riga del primo frame resta visibile. Se un sixel sull'ultima riga
  fa scorrere lo schermo, prima lo schermo scorreva a ogni frame, ora i frame si sovrappongono (ICH-284).
- `Notcurses.strwidth` misura anche il testo dopo una sequenza ZWJ (U+200D): `"👩‍🚀abc"` vale 5 colonne, non 2. Il
  workaround del bug di notcurses 3.0.17, prima solo in `Plane#putstr`, ora vale per `Direct#putegc` (scrive solo il
  primo EGC, non anche il resto del testo), `Direct#print_aligned` (colonna e valore restituito giusti; `ArgumentError`
  per un carattere di controllo dopo la sequenza), `Plane#puttext` (una parola con ZWJ più larga del piano va a capo
  invece di sollevare `PlaneError`) e la UI, che taglia e allinea il testo con `strwidth`: una `Label` con
  `"👩‍💻 sviluppatrice molto brava"` e `size: 10` non solleva più `PlaneError` (ICH-285, ICH-286).
- `Tree#redraw` adatta i piani delle voci alla larghezza corrente dell'albero: dopo un `Plane#resize` in larghezza
  il blocco di disegno riceveva piani larghi come prima, e su un albero più stretto disegnava fuori dall'albero
  (ICH-287).
- `Tab#move(before:)` del primo tab mostrato verso il suo successore non ruota più l'intestazione: con A, B e C,
  `a.move(before: b)` lascia "A B C" invece di "B C A" (ICH-289).
- YARD di `ProgBar`: documentata la regola dei colori di notcurses 3.0.17 sulle dimensioni del piano. Su un piano
  largo 1 colonna, e senza UTF-8 anche alto 1 riga, sinistra e destra devono avere gli stessi colori, altrimenti
  ogni `progress=` solleva `WidgetError`; il comportamento non cambia (ICH-288).
- YARD di `Plot`: documentato il limite di notcurses 3.0.17 delle etichette di `label_ticks:`. Da circa 1,84·10^17
  in su, con `:uint64` e con `:double`, le etichette sono sbagliate ("184.47P" o "0.00", secondo la build di
  notcurses), mentre i campioni mantengono il loro valore; il comportamento non cambia (ICH-290).
- UI: un componente il cui disegno solleva durante la creazione si chiude, esce dal contenitore e dall'App, e il
  focus resta com'era; prima restava fra i figli e ogni layout successivo (un fratello nuovo, un resize) sollevava
  di nuovo. Un `Dialog` che fallisce alla creazione si chiude e il focus resta com'era; prima restava la finestra
  modale attiva. `Component#close` e `Dialog#close` tolgono il componente dal contenitore e dall'App anche se il
  ridisegno del focus solleva. I costruttori di `Container`, `Label`, `Button`, `TextInput`, `ListView`, `LogView` e
  `Dialog` rifiutano subito `channels:` e `focused_channels:` con lo sfondo `:highcontrast` (`ArgumentError`), anche
  per un widget nascosto; prima un `Container` senza titolo li accettava (ICH-291).
- `App`: un resize che nasconde tutti i componenti focusabili e un resize successivo che li mostra ridanno il focus
  al componente che lo aveva prima del resize (o al primo candidato visibile), prima degli handler di `on_resize`,
  anche se nel frattempo un dialogo si apre o si chiude; prima il focus restava a nessuno fino a Tab. Senza focus un
  tasto va alla radice attiva, così Esc chiude un `Dialog` aperto. Un `focus(nil)` esplicito resta anche dopo un
  resize (ICH-292).
- `Dialog`: ogni pulsante ha spazio per tutta l'etichetta; prima la riga si divideva in parti uguali e
  un'etichetta più lunga della media restava tagliata. La larghezza del dialogo non cambia (ICH-293).
- `Context#get`, `Context#getvec` e `Direct#get` sollevano `ArgumentError` per un `timeout` sopra 2147483647 secondi
  (2^31 - 1, circa 68 anni); prima un valore oltre `time_t` (per esempio `1e19` o `Float::MAX`) dava un `RangeError`
  non documentato durante l'attesa. `nil` resta il modo per attendere senza limite (ICH-294).
- `Context#getvec` legge a blocchi di 8192 eventi, la dimensione della coda di input di notcurses, finché la coda è
  vuota o `count` è raggiunto: prima `getvec(2**31 - 1)` chiedeva un buffer di 104 GiB, e a fine input un `count`
  grande costava secondi e centinaia di MB per un solo evento EOF. La memoria dipende dagli eventi letti, non da
  `count` (ICH-295).
- `EventLoop#every`: un timer il cui blocco solleva resta programmato e scatta ancora nel `run` successivo, fino a
  `Timer#cancel`; prima non scattava più, mentre `Timer#active?` restava true (ICH-296).
- `EventLoop#run` consegna subito i tasti che il run precedente ha lasciato in coda (uscito con `stop` o con
  l'eccezione di un handler): il primo giro non attende. Prima arrivavano solo con il tasto, il timer o il `post`
  successivo (ICH-298).
- `EventLoop#run` non solleva più `RangeError` con un timer dal ritardo enorme (`after(1e20)`, `after(Float::MAX)`,
  `every(1e20)`): l'attesa di un giro dura al massimo un giorno, e il timer resta attivo (ICH-299).
- `Input#utf8` e `Input#eff_text` restituiscono stringhe congelate: `ev.utf8 << ...` solleva `FrozenError`. Prima
  modificava l'evento, e da lì `to_ffi`, `==` e i predicati dei modificatori sollevavano `IndexError` (ICH-300).
- `Notcurses.accountname`, `.hostname`, `.osversion` e `detected_terminal` di `Context` e `Direct` restituiscono
  sempre UTF-8 valido: i byte non validi (per esempio un `LOGNAME` Latin-1) diventano U+FFFD. Prima la String non
  era valida, e `Plane#putstr` o una regex sollevavano `ArgumentError` (ICH-301).
- `Notcurses.metric`, `.si_prefix`, `.binary_prefix` e `.byte_prefix` sollevano `ArgumentError` per le coppie
  value/decimal che mandano in overflow `ncnmetric` (bug di notcurses 3.0.17, solo con `decimal` oltre
  (2^64 - 1)/base); prima restituivano cifre e prefisso sbagliati senza errore. L'intervallo di `decimal` non
  cambia (ICH-302).
- YARD di `Context#refresh` e `#create_pile`: il valore e le opzioni si riferiscono all'area di rendering (il
  terminale meno i margini), come `#dims`, non al terminale (ICH-303).
- Il gemspec e il `Gemfile` chiedono `ffi ~> 1.16` (prima `~> 1.15`): la suite usa `FFI::Library#attached_functions`,
  che esiste da ffi 1.16.0, e ffi 1.15.0 e 1.15.1 non cercano le librerie in `/opt/homebrew/lib` (ICH-305).
- README, esempio `Notcurses::UI`: il risultato si stampa dopo il blocco di `Context.open`; prima la riga finiva
  sullo schermo alternativo e la chiusura la cancellava (ICH-304).

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
