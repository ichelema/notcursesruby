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
- `benchmark/plane_writes.rb`: misura le scritture di `Plane` contro la FFI diretta su un piano 60x200 e stampa
  una tabella markdown (ICH-594).
- `Notcurses::UI::EventLoop#run` installa un Fiber scheduler per la sua durata (ICH-606): `Fiber.schedule` in un
  handler crea un task che attende I/O, `sleep`, Queue, Mutex e `Timeout.timeout` senza fermare il ciclo. Gli
  handler restano sul Fiber del ciclo, che è bloccante, e il thread di input resta. Con un task ancora pronto il
  ciclo rende al massimo `max_fps` volte al secondo: keyword nuova di `EventLoop#run` e `App#run`, default 60.
  `run` solleva `Error` se nel thread è attivo il Fiber scheduler di un'altra libreria (per esempio dentro
  `Async { }`); un `run` annidato in un handler resta permesso. Su Ruby 4.0 lo scheduler consuma all'avvio il
  warning «IO::Buffer is experimental», che altrimenti finirebbe sullo schermo alla prima scrittura da un task, e
  un `IO#close` da un handler di un IO su cui attende un task solleva `Error` invece di bloccare il processo.
  `benchmark/fiber/run.rb` misura il codice finale; il prototipo `benchmark/fiber/fiber_app.rb` esce dal
  repository.
- `Notcurses::UI::EventLoop#async` (quindi anche `App#async`) crea un `Notcurses::UI::Task` (ICH-607): il blocco
  gira in un Fiber dello scheduler di `run` e legge pipe e socket, o attende `sleep` e code, senza un thread. Il
  blocco parte subito, fino alla prima attesa; un `async` fuori da `run` parte all'avvio del `run` successivo.
  `Task#wait` restituisce il valore del blocco (`nil` per un task fermato o uscito con un'eccezione); da un handler,
  su un task non finito, solleva `Error`, perché l'attesa fermerebbe il ciclo: attendi da un altro task
  (`app.async { task.wait }`). `Task#stop` manda `Task::Stop`, che non deriva da `StandardError`, e l'`ensure` del
  task gira prima che `stop` ritorni, salvo da un Fiber che un handler riprende con resume (per esempio
  `Enumerator#next`), dove il task si ferma dopo la fine dell'handler; da un altro thread solleva `Error` (usa
  `post { task.stop }`). `Task#pass` cede il ciclo: serve a un task che legge un flusso sempre pronto, che
  altrimenti ferma input e render. All'uscita di `run` i task vivi, anche quelli di `Fiber.schedule`, ricevono
  `Task::Stop`; un `run` annidato usa lo scheduler del `run` esterno, e i suoi task si fermano all'uscita di
  quello. `examples/demo.rb` legge il processo figlio con un task e `IO.popen`, al posto di `Subprocess` e `post`.

### Modificato

- `Notcurses::Plane#putstr`, `#printf`, `#puttext`, `#putegc`, `#putc`, `#hline` e `#vline` leggono dimensioni,
  cursore, scrolling e autogrow del piano una volta sola per chiamata, e segmentano il testo in grapheme una volta
  sola: prima `putegc` leggeva le dimensioni due volte e `putstr` fino a cinque, con tre ricerche su tutto il testo.
  Il comportamento, le firme e i messaggi d'errore non cambiano. Su un piano 60x200 (Ruby 4.0.7), rispetto alla FFI
  diretta: `putegc("x")` da 38x a 11,7x, `putc` da 29x a 14,3x, `putstr` con gli accenti da 4,5x a 1,6x, `hline` da
  4,6x a 2,7x, `vline` da 8,2x a 4,9–5,1x, `putstr` con un EGC da 6 MB da 18,5x a 4,4x (ICH-594). `putegc` ricorda
  gli EGC di al massimo 4 byte che ha già controllato, finché il contesto è aperto: `putegc("é")` e `putegc("漢")`
  ripetuti costano 8x la FFI diretta, e 19x la prima volta di ogni carattere.
- Sotto un Fiber scheduler i blocchi che notcurses chiama dentro una chiamata C (resize di un piano, `Visual#stream`,
  `Tree`, `Tabbed`) girano in un contesto bloccante: `sleep` e l'I/O nel blocco fermano il thread e non passano dallo
  scheduler (ICH-604). Prima il Fiber si poteva sospendere a metà della chiamata C, e un altro Fiber poteva rientrare
  in notcurses mentre la pila dei frame di ffi, che è per thread, era ancora aperta. Senza scheduler, e nel Fiber
  radice, non cambia niente, anche dentro un `Fiber.new`. Su Ruby 3.1, sotto uno scheduler, il blocco gira in un
  Fiber bloccante nuovo: `Fiber.current` e i valori locali al Fiber del chiamante cambiano, e un `throw` verso fuori
  dal blocco diventa `UncaughtThrowError` al posto di `LocalJumpError`.

### Rimosso

- `Notcurses::Util.timespec` (`@api private`): non aveva chiamanti.

### Corretto

- `Notcurses::UI::LogView`: la riga non finita ha un limite in byte, `max_partial_bytes:` di `LogView.new` (default
  65 536, minimo 4); oltre il limite i byte più vecchi escono, a partire da un inizio di carattere UTF-8 (ICH-230).
  Prima un produttore senza "\n" faceva crescere la riga senza limite, e ogni `append` costava di più: 4,7 s per il
  primo MiB in blocchi da 4 KiB, 14 s per il secondo; ora circa 0,6 s per MiB. "\r" sostituisce la riga, anche in
  una riga finita: resta l'ultimo pezzo non vuoto, quindi "10%\r20%\r30%" mostra "30%" invece di "10%?20%?30%". I
  "\r" in coda non cancellano niente: "\r\n" vale ancora "\n".
- `Notcurses::UI`: `Label`, `Button`, `TextInput`, `ListView`, `Dialog` e il titolo di `Container` controllano il
  testo anche con le regole di notcurses: un grapheme che notcurses 3.0.17 divide con un pezzo largo 0, come il
  keycap "1️⃣", solleva `ArgumentError` alla creazione e nei setter, con un messaggio che nomina il grapheme; in
  `TextInput` il tasto che lo completerebbe non viene inserito (ICH-232). Prima il controllo passava e il disegno
  scriveva "?". `LogView`, che mostra byte grezzi, lo mostra ancora come "?", e così anche un EGC lungo senza spazio
  nell'egcpool, invece di sollevare `PlaneError`.
- `Cell`: con un grapheme che notcurses 3.0.17 divide in più caratteri (bandiere, coniugati devanagari, hangul con
  i jamo L, V e T, keycap) le scritture con una cella sollevano `CellError` con i pezzi e con che cosa usare:
  `Plane#putstr` per i coniugati e le bandiere, la forma composta (`String#unicode_normalize(:nfc)`) per gli hangul
  (ICH-217). Prima il messaggio diceva solo "notcurses non accetta ... come un solo carattere". `Plane#set_base` con
  uno di quei grapheme solleva `CellError`: prima teneva in silenzio il primo pezzo (per esempio "🇮" di "🇮🇹").
  `Cell.new` non cambia: controlla con le regole di Ruby, perché senza un piano non sa come notcurses divide il
  grapheme. Lo YARD di `Cell` elenca i casi.
- `Plane#putstr`, `#putegc` e `#puttext`: con l'egcpool del piano pieno (16 MiB) un EGC di più di 4 byte solleva
  `PlaneError` con un messaggio che nomina l'egcpool e l'EGC (ICH-533). notcurses scrive gli EGC che entrano e si
  ferma lì; il glifo dove si ferma (che il C svuota prima di fallire) e il cursore tornano com'erano, quindi un solo
  EGC che non entra lascia il piano com'era. Un EGC che sovrascrive celle con EGC lunghi entra se
  il C, che prima libera quelle celle, trova spazio. Prima un EGC con segni combinanti sollevava `ArgumentError`
  ("notcurses non accetta"), come un testo non valido, anche quando il C l'avrebbe scritto; senza segni combinanti
  `putstr` e `puttext` sollevavano `PlaneError` senza nominare il pool, e `putegc` `CellError` ("divide in più
  caratteri"). Il controllo dei caratteri di larghezza zero, che carica i pezzi con `nccell_load`, usa un piano
  temporaneo quando il pool è pieno. I messaggi d'errore mostrano solo l'inizio e i byte di un EGC lungo.
- `Plane#putc`, `#hline`, `#vline`, `#box`, `#perimeter`, `#polyfill`, `#gradient` e `#set_base`: quando l'egcpool
  del piano (16 MiB) non ha spazio per un EGC di più di 4 byte, o per le copie che il C ne fa (una per la cella
  temporanea, una per la linea, una per cella scritta), sollevano `PlaneError` con un messaggio che nomina l'egcpool,
  e il piano, la cella base e il cursore restano com'erano (ICH-582). Prima della scrittura il wrapper la prova su
  una copia del piano (`ncplane_dup`). Prima le scritture con una `Cell` sollevavano `CellError` ("notcurses non
  accetta ... come un solo carattere"), come se la cella non fosse valida, con l'EGC intero nel messaggio, e `hline`,
  `vline` e `box` spostavano il cursore; con il pool quasi pieno il C cambiava il piano prima di fallire: celle
  scritte a metà, la cella di arrivo svuotata, la base persa, e linee e box lasciavano nel pool la loro copia di
  lavoro fino a `erase`. `set_base` con una bandiera seguita da segni combinanti teneva in silenzio il primo
  indicatore: ora solleva `CellError`, come con il pool vuoto; anche U+2028 e U+2029, che il C troncava a un byte
  rotto nella base, sollevano `CellError`. Le celle che notcurses divide davvero (bandiere,
  keycap) sollevano ancora `CellError`. I messaggi d'errore mostrano solo l'inizio e i byte di un EGC lungo.
- Un indicatore regionale da solo (un grapheme cluster con un solo indicatore, U+1F1E6..U+1F1FF) solleva
  `ArgumentError` in `Cell.new`, `Plane#putstr`, `#putegc`, `#puttext`, `#printf`, `#set_base`, `#gradient` e nel
  testo dei componenti di `Notcurses::UI` (ICH-586). notcurses 3.0.17 lo conta largo 1 colonna, mentre Ghostty 1.4
  e Kitty 0.51 lo disegnano largo 2: il testo dopo si spostava e le scritture successive lasciavano caratteri vecchi
  sullo schermo. Una bandiera (due indicatori) si scrive come prima: notcurses, Ghostty e Kitty la contano larga 2.
  Il messaggio di `CellError` per una bandiera in una `Cell` non dice più che molti terminali la disegnano più
  larga: lo fa solo un terminale che non raggruppa i grapheme, come libghostty-vt senza il modo 2027.
- `Reader#offer_input`: Backspace, Ctrl+U e Ctrl+W cancellano anche il carattere della colonna 0, ASCII o glifo
  largo (ICH-218). Prima il carattere restava, perché il C cancella scrivendo `""` e in colonna 0 la scrittura
  fallisce (`notcurses.c:1883`); il carattere successivo lo sovrascriveva. Ctrl+W si ferma ancora, come nel C, su un
  separatore in colonna 0 (per esempio uno spazio). Con `cursor: false` un reader non lascia più acceso il cursore
  del terminale: dopo ogni ridisegno, che il C fa accendendo il cursore nel campo, il wrapper rimette lo stato
  dell'ultima chiamata a `Context#cursor_enable` (anche la posizione) o `#cursor_disable`. Senza un tty il C non
  spegne il cursore. Con `cursor: true` il reader mostra il cursore nel campo, come prima.
- `Reader#offer_input`: dopo Backspace, Ctrl+U e Ctrl+W le metà destre dei glifi larghi rimasti nella vista hanno
  di nuovo la larghezza del glifo, e `reader.plane.at` su quelle celle restituisce il glifo (ICH-484). Prima il
  ridisegno del C, che non confronta la larghezza delle celle (`internal.h:1510-1523`), le lasciava larghe 0, e
  `plane.at` restituiva una cella vuota. `Reader#contents` era già corretto.
- `Reader#offer_input`: Backspace dopo un glifo largo porta il cursore sulla prima colonna del glifo, nella vista, nella
  copia nascosta e, con `cursor: true`, nel terminale (ICH-581). Prima il C cancellava le due metà del glifo ma
  lasciava i cursori sulla colonna della metà destra (`reader.c:263-265`): la scrittura dopo lasciava un buco nella
  riga (`"a漢"`, Backspace, `"c"`: celle `a`, vuota, `c`) e `contents` non lo mostrava. Vale anche sulle righe sotto la
  prima.
- `Reader` con `cursor: false`: dopo un reader con `cursor: true` rimette di nuovo il cursore del terminale come l'ha
  chiesto l'ultima chiamata a `Context#cursor_enable` (con la posizione) o `#cursor_disable`, o nascosto se non ce ne
  sono state (ICH-580). Prima il reader con `cursor: true` rendeva sconosciuto lo stato del cursore, e i reader con
  `cursor: false` non facevano nulla: il cursore restava acceso nel campo anche dopo `Context#cursor_disable`. Ora
  `Context` tiene separati lo stato chiesto dall'applicazione e quello noto del cursore del C, che serve solo a
  rendere idempotente `#cursor_disable` (che tollera ancora un cursore già nascosto dalla chiusura di un reader con
  `cursor: true`). Con un reader con `cursor: true` e uno con `cursor: false` aperti insieme decide l'ultima
  operazione. I reader con `cursor: true` non cambiano.
- `Context.new` e `Direct.new`: quando il rollback dell'init solleva (per esempio un errore dello stop), il chiamante
  riceve l'eccezione per cui `new` ha rinunciato: l'`Interrupt` del Ctrl-C, l'eccezione di un `Thread#raise` o
  l'`InitError` di un init NULL (ICH-577). Prima l'errore del rollback la sostituiva, e un `rescue Interrupt` attorno a
  `new` non scattava più. L'errore del rollback viene scartato, senza scrivere su stderr; registro, `FILE*`
  dell'output e `TERM` tornano a posto come prima.
- `Context.new` e `Direct.new` con un terminale che non risponde mai alle query dell'init: SIGTERM, un Ctrl-C o due
  Ctrl-C chiudono il processo in circa 2 secondi (ICH-576). Prima il processo restava vivo, e solo SIGKILL lo
  chiudeva: il C aspetta la risposta senza timeout (`pthread_cond_wait`, `in.c:2924-2925`), `new` aspettava il thread
  dell'init, e all'uscita Ruby aspettava lo stesso thread. Ora, dopo un segnale o un `exit` (anche da un gestore
  `trap` del segnale), `new` aspetta al più 2 secondi e poi esce con l'eccezione del segnale o la `SystemExit`; se il
  processo esce con l'init ancora fermo, l'hook `at_exit` del wrapper lo
  chiude senza aspettare gli altri thread, con la morte per il segnale (o lo stato di `exit`). Prima di uscire rimette
  il terminale come l'ha trovato l'init: echo e modo canonico, `O_NONBLOCK` del fd 0, la tastiera kitty e (`Context`)
  lo schermo alternativo. Con un terminale che risponde entro i 2 secondi non cambia nulla; oltre, un solo Ctrl-C si
  comporta come prima il secondo (`new` esce, e il contesto resta registrato fino alla risposta).
- `Direct#stream` con il blitter `:pixel` ridisegna ogni frame sulle righe del primo anche in fondo allo schermo
  (ICH-458). Prima un frame più basso dello schermo poteva finire sull'ultima riga (per esempio con il cursore in
  fondo: il C sposta in alto un frame che non entra sotto il cursore, `direct.c:442-448`); il C mandava poi una CUP
  alla riga sotto lo schermo (`direct.c:607-613`), e su un terminale che non fa scorrere lo schermo dopo un bitmap
  sull'ultima riga i frame dopo il primo partivano una riga più in alto: l'ultima riga del primo frame restava
  visibile. Ora, sui terminali con la grafica a pixel, prima di ogni frame `stream` fa posto sotto il cursore: il
  cursore scende di tante righe quante ne ha il frame (lo schermo scorre se serve) e risale. Il frame parte dalla
  riga del cursore e non finisce sull'ultima riga: sotto resta una riga libera, e l'esito è lo stesso sui terminali
  che fanno scorrere lo schermo dopo un bitmap sull'ultima riga e su quelli che non lo fanno (la posizione del
  cursore non li distingue: per questo `stream` non può lasciare un frame sull'ultima riga). `Direct#render_image` e
  `Frame#raster` non cambiano: lì un frame che non entra sotto il cursore finisce ancora sull'ultima riga.
  Il costo è di pochi byte per frame (un carattere VT per riga e una CUU), senza altre query al terminale.
  Un frame alto quanto lo schermo parte dalla riga 0 come prima, e sui terminali che scorrono dopo un bitmap
  sull'ultima riga lo schermo scorre ancora di una riga a ogni frame. Con i blitter a celle, e con `:pixel` su un
  terminale senza grafica a pixel, l'output non cambia. Lo stream va avviato con il cursore a inizio riga: con
  `align: :left` il primo frame parte dalla colonna del cursore e i successivi dalla colonna 0; in fondo allo schermo
  prima il C, spostando in alto il primo frame, lo riportava alla colonna 0. Se il cursore non si sposta per fare
  posto al frame o non risale sul frame precedente, `stream` solleva `DirectError`.
- `Direct#close` (e `#stop`) con `output:` su un file o su un `FILE*` non scrive più il reset di `ncdirect_stop`
  (`\e[39;49m\e(B\e[m`) sullo stdout del processo (ICH-222, `direct.c:841`): durante lo stop il fd 1 punta a
  `/dev/null`, poi torna com'era, anche con il fd 1 chiuso all'avvio o con `FD_CLOEXEC`, e con `$stdout` di Ruby
  chiuso o senza `flush`. Un altro thread che scrive sullo stdout durante lo stop perde quell'output, e lo perde anche
  il testo scritto sullo stdout della libc (per esempio da un'estensione nativa) e non ancora svuotato (ICH-560); un
  processo figlio creato da un altro thread durante lo stop eredita il fd 1 su `/dev/null`. Se il fd 1 non si può
  spostare (per esempio senza descrittori liberi) il reset arriva sullo stdout come prima. Un fd 1 aperto in sola
  lettura non si sposta: se il terminale ha un reset il C non riesce a scriverlo e `close` solleva `DirectError`, come
  prima.
  `Direct::Frame#close` continua a non liberare la memoria del frame: in 3.0.17 non esiste un free sicuro
  (`free_plane` non è esportato, `ncplane_destroy` va in crash su un piano di `Direct`); lo YARD ne spiega il motivo.
- `Plane#qrcode` sopra una metà di un glifo largo non lascia più l'altra metà orfana (ICH-488): il C disegna il
  codice con il blitter `:half`, che scrive ogni cella da sola, come i blit di ICH-486. Controllato su una build di
  notcurses 3.0.17 con libqrcodegen: un codice dal cursore in (0, 0) che copre la metà sinistra lasciava la metà
  destra, e una scrittura larga successiva cancellava la prima cella della riga sotto. Ora l'altra metà diventa una
  cella vuota. Sulla build senza qrcodegen (quella di Arch Linux) la spec viene saltata.
- `Visual.from_palidx` ora dà ai pixel i colori della palette e `Visual#rotate` ai multipli di π/2 non perde più pixel
  (ICH-223):
  `ncvisual_from_palidx` di 3.0.17 ignora la palette, e `ncvisual_rotate` perde la prima riga e la prima colonna
  (confronta con `>` invece di `>=`, visual.c:746, anche a 0 radianti) e, con bordi trasparenti diversi sui lati,
  anche pixel opachi (ruota il riquadro dei pixel opachi attorno al suo centro e i pixel attorno al centro
  dell'immagine, visual.c:658-705: un 4x4 con 4 pixel opachi in basso a destra diventava un 2x2 senza pixel opachi).
  `from_palidx` costruisce i pixel RGBA in Ruby (RGB del canale, alpha 0 se `:transparent` altrimenti 255, bianco
  per il colore di default) e crea il visual come `from_rgba`; un indice >= `palette.size` solleva ancora
  `VisualError`, e una voce della palette con un indice di palette (`Channel.palindex`), che non ha un colore RGB,
  solleva `ArgumentError` (ICH-551). `rotate` ripete in Ruby l'algoritmo del C con le due correzioni, senza cambiare
  il puntatore del visual: il costo è proporzionale all'area, con una chiamata C per pixel. Un'eccezione asincrona
  (per esempio `Thread#raise`) arriva dopo la scrittura dei pixel: il visual è tutto ruotato o com'era.
- `Visual.blit_rgba`, `.blit_bgrx`, `.blit_rgb_loose`, `.blit_rgb_packed` e `Visual#blit` su un piano esistente
  sopra una metà di un glifo largo non lasciano più l'altra metà orfana (ICH-486): il C scrive ogni cella da sola, e
  una scrittura larga successiva vicino alla metà destra orfana cancellava la prima cella della riga sotto
  (sull'ultima riga scriveva fuori dal framebuffer). Ora l'altra metà diventa una cella vuota, come nei riempimenti
  di ICH-450, con ogni blitter di celle. Il controllo legge solo i glifi a cavallo dei lati del rettangolo del blit,
  che il wrapper calcola con `ncvisual_geom` (ICH-549): il costo è proporzionale alle righe del blit, non all'area
  del piano. Con `:braille`, che non tocca le celle con soli pixel trasparenti, legge anche i glifi dentro il
  rettangolo. Con un blitter che diventa `:pixel` il C non scrive celle e il wrapper non fa il controllo (ICH-550):
  i glifi larghi sotto il bitmap restano interi.
- Un gestore `trap` che chiude il contesto o il `Direct` e poi torna al codice interrotto non fa più usare al C un
  puntatore già liberato (ICH-464). Il segnale poteva arrivare fra `to_ptr` e la chiamata C, o fra due chiamate C con
  lo stesso puntatore (per esempio `ncpile_render` e `ncpile_rasterize` dentro `Context#render`: 37 crash su 80
  corse). Ora ogni metodo del wrapper che usa un puntatore C gira dentro `Notcurses::Guard.run` (349 metodi in 16
  file): `close` segna subito il contesto chiuso e rinvia lo stop alla fine dell'operazione interrotta, e la
  chiamata successiva solleva `ClosedError`. Un `close` durante l'attesa di `Context#get`, `#getvec` o `Direct#get`
  solleva `ClosedError` invece di `Errno::EBADF`. `Context#close` dentro un callback chiamato dal C (per esempio
  da un gestore `trap` durante il blocco di `Visual#stream` o un callback di resize) non solleva più `ContextError`:
  lo stop avviene alla fine dell'operazione. Anche `Visual#close` da un gestore `trap` rinvia `ncvisual_destroy` alla
  fine dell'operazione interrotta (per esempio `Visual#dims`); le operazioni in corso in altri thread non lo
  rinviano. Un'eccezione asincrona (un secondo Ctrl+C) dentro `close` prima dello stop, anche al ritorno di un metodo
  C, non lo fa più perdere: un `close` successivo o l'hook `at_exit` lo eseguono una volta sola. Lo stesso vale per
  `ncvisual_destroy`: un `Visual#close` successivo o il close del contesto la eseguono.
  Un controllo statico e un audit nella suite (`to_ptr` fuori dalla guardia) tengono la copertura completa. Restano
  documentati due limiti: il close di un piano o di un widget da un gestore `trap` non è rinviato (ICH-540), e un
  Fiber sospeso dentro un'operazione tiene lo stop in attesa (ICH-541).
- Chiudere il contesto, il `Direct` o un `Visual` mentre un altro thread è dentro `Visual#decode`, `#decode_loop`,
  `#stream`, `Visual.from_file`, `Direct#render_frame` o `Direct#stream` non libera più la memoria che il C sta usando
  (ICH-475). Prima l'hook `at_exit` o un `close` da un altro thread durante la chiamata C senza GVL davano SIGSEGV,
  SIGABRT o un blocco (`Visual#stream` all'uscita: 30 crash su 30). Ora `close` segna subito l'oggetto chiuso (le
  chiamate nuove sollevano `ClosedError`) e rinvia la chiusura fisica alla fine dell'operazione in corso, nel suo
  thread (`Notcurses::Guard`, `@api private`). `decode`, `decode_loop` e `from_file` non usano il contesto nel C:
  il contesto si ferma subito e il visual viene distrutto al ritorno della lettura; `from_file` solleva
  `ClosedError` e distrugge il visual appena creato. `Visual#stream` e `Direct#stream` si fermano al frame successivo.
  `Visual#stream` senza blocco fa in Ruby il lavoro di `ncvisual_simple_streamer` (render e attesa fino al frame),
  per controllare la chiusura a ogni frame. `Direct#stream` rilegge il puntatore a ogni frame. Un `Visual#close` da un
  altro thread durante il blocco di `stream` non solleva più `VisualError`: il controllo dei callback per
  `Visual#close` vale solo nel thread del callback.
- Dopo un `EventLoop#run` uscito con `:interrupt` per il Ctrl+C di kitty (`\e[99;5u`) o di xterm con modifyOtherKeys
  (`\e[27;5;99~`), un `run(no_linesigs: true)` non consegna più quel Ctrl+C a `on_key` (ICH-455). notcurses alzava il
  segnale e metteva anche il tasto in coda, e `run` usciva prima di leggerlo. Ora il thread di input di `run` legge il
  tasto prima di alzare il segnale: restano solo i tasti successivi, che arrivano al `run` dopo. Anche la ripetizione
  e il rilascio di un Ctrl+C tenuto premuto restano fuori dai `run` dopo, anche di un altro `EventLoop` o `App` sullo
  stesso contesto, dopo la pressione di un altro tasto di segnale e quando l'utente lascia Ctrl prima del tasto
  (ICH-537): il contesto ricorda ogni tasto di segnale tenuto premuto fino al suo rilascio
  (`Context#held_signal_keys`, nuovo, `@api private`).
- `EventLoop#run` segue ISIG del terminale anche per i tasti di segnale di kitty dopo uno `stty` (ICH-454).
  notcurses decide se alzare il segnale da un flag suo, che `stty` non cambia: dopo `stty -isig` un
  `run(no_linesigs: true)` usciva con `:interrupt` invece di consegnare Ctrl+C a `on_key`, e dopo
  `Context#linesigs_disable` e `stty isig` Ctrl+C non faceva niente. Ora `run` spegne all'avvio il flag di notcurses,
  se è acceso, anche con ISIG già spento, e decide solo da ISIG. Il wrapper tiene lo stato del flag
  (`Context#linesigs_flag?`, nuovo, `@api private`): `run` non chiama più `linesigs_disable` con il flag già spento,
  che con `loglevel: :warning` scriveva "linedisc signals already disabled" a ogni `run` dopo il primo (ICH-538).
  Con il flag già spento `run(no_linesigs: true)` spegne solo ISIG (`Context#isig_disable`, nuovo, `@api private`).
- `EventLoop#run` alza un solo segnale per ogni pressione di Ctrl+C, Ctrl+Z e Ctrl+\ di kitty (ICH-456). notcurses lo
  alzava anche per la ripetizione e il rilascio del tasto, anche dopo la fine di `run`: un Ctrl+C interrompeva due
  volte. Ora all'avvio `run` toglie il compito a notcurses (`Context#linesigs_disable`) e rimette ISIG com'era
  (`Context#isig_enable`, nuovo, `@api private`). Durante `run` un thread di input del contesto (`InputReader`,
  `Context#input_reader_start` e `#input_reader_stop`, nuovi, `@api private`) legge i tasti appena arrivano e alza il
  segnale alla pressione, subito anche mentre un handler, un timer o un blocco di `post` occupa il ciclo, e anche per
  Ctrl+C con CapsLock o NumLock (ICH-536); la ripetizione e il rilascio non alzano niente. Il thread legge la coda di
  notcurses a blocchi (`notcurses_getvec`, che notcurses permette in parallelo al render) e la tiene vuota: una
  raffica di 10000 tasti con il ciclo occupato, con la macchina scarica, non fa più perdere il Ctrl+C che la segue.
  Durante `run` `Context#get` e `#getvec` leggono gli eventi del thread, e `Key::EOF` resta disponibile a ogni
  lettura, come in notcurses. Un secondo Ctrl+C mentre `run` fa pulizia arriva alla fine della pulizia (`run` solleva
  `Interrupt`); anche su Ruby 3.1, 3.2 e 3.3, dove l'Interrupt di un segnale non si rimanda, perché la pulizia
  ricomincia e finisce (su queste versioni resta una finestra: vedi "Limiti noti", ICH-539). Limiti: il thread ha bisogno del GVL, quindi un handler che lo tiene ritarda il segnale (con più di 8192
  tasti nel frattempo notcurses scarta anche Ctrl+C); notcurses consegna gli eventi più lentamente di quanto li mette
  in coda: nelle prove, con la macchina scarica, 10000 tasti in un colpo non perdono niente; con altri processi che
  occupano la CPU anche il Ctrl+C dopo 10000 tasti si è perso, di rado, e con 20000-50000 tasti, sotto carico, in
  circa una corsa su sei. Durante `run` per attendere un tasto serve `Context#get` con un timeout, non
  `Context#inputready_fd`; dopo `run` il descrittore non segnala gli eventi già letti dal thread, e prima di attendere
  su di esso serve `Context#get(timeout: 0)`. Dopo `run` il flag di notcurses resta spento: fuori da `run` un Ctrl+C
  di kitty non alza segnali e arriva al `run` successivo; `Context#linesigs_enable` ridà il compito a notcurses. Con
  un contesto che scarta l'input (`drain_input: true`) `run` non legge i tasti e il compito resta a notcurses. Senza
  terminale (input da una pipe) notcurses non spegne il flag, e il limite resta.
- `Plane#merge_down` non copre più il glifo che in `src` segue una metà sinistra orfana di un glifo largo (ICH-532).
  Il wrapper riscriveva la metà sinistra come un glifo intero, e il glifo dopo spariva da `dst`. Ora, durante la
  fusione, il wrapper cambia la metà orfana in uno spazio con gli stessi stili e colori (`src` torna com'era dopo):
  `dst` mostra lo spazio e il glifo di `src`, anche largo o di più di 4 byte, con i colori composti come nelle altre
  celle. Se il glifo non entra nell'egcpool di `dst`, la fusione fallisce con `PlaneError` e `dst` non cambia.
- `Plane#rotate_cw`, `#rotate_ccw` e `#resize_region` (che non conserva niente) non perdono più la cella base con
  l'egcpool pieno (ICH-531). Durante la chiamata C il wrapper rilasciava l'EGC della base dal pool, e il C poteva
  usare quello spazio: dopo la chiamata la base non trovava posto, diventava vuota e l'errore di `ncplane_set_base`
  nascondeva quello del C. Ora l'EGC resta nel pool durante la chiamata. Se il C rifiuta la rotazione, la base resta
  com'era e il metodo solleva l'errore del C. Se il C fa il resize, la base torna prima del primo callback Ruby di
  resize di un figlio: un callback che riempie il pool vede fallire le sue scritture, non la base.
- `Plane#contents` legge gli EGC di più di 4 byte anche con l'egcpool del piano pieno (ICH-490). `ncplane_at_yx_cell`
  copia l'EGC nel pool (16 MiB) e fallisce quando non c'è spazio: `contents` sollevava `PlaneError` con il contenuto
  intatto. Ora legge quelle celle con `ncplane_at_yx`, che non usa il pool, come `Plane#at`. Un piano con un bitmap
  solleva ancora `PlaneError`.
- `Plane#at` solleva `PlaneError` su un piano con un bitmap (sixel o Kitty) invece di andare in SIGSEGV (ICH-493).
  Con Kitty il C libera la sequenza dello sprixel dopo il disegno e `ncplane_at_yx` fa `strdup(NULL)`. Lo stesso
  vale per sixel, dove `at` restituiva la sequenza di escape: come `Plane#contents`, il piano con un bitmap non si
  legge cella per cella.
- `Plane#resize_region` senza regione conservata (`keep_rows: 0`), `#rotate_cw` e `#rotate_ccw` non lasciano più la
  cella base su un egcpool liberato (ICH-489). notcurses svuota il pool quando il resize non conserva niente, ma la
  cella base tiene il suo offset: con un EGC di più di 4 byte (per esempio `👍🏽`) `Plane#base` andava in SIGSEGV. Il
  wrapper rimette la stessa cella base (EGC, stili e canali) dopo il resize.
- `Plane#merge_down` non lascia più in `dst` una cella rotta dopo una metà sinistra orfana di un glifo largo in
  `src` (ICH-530). notcurses lascia la cella a destra con `gcluster` 0 e la larghezza della cella di `src`; il
  wrapper cercava solo le metà destre con larghezza 0. Ora riscrive anche questa cella (il contenuto è quello di
  ICH-532). Prima la sequenza di scritture successiva su quella
  riga corrompeva l'heap (`free(): invalid pointer` in `Plane#close`).
- `Plane#merge_down`: il ripristino di `dst` (egcpool pieno) controlla dimensione, puntatore del pool e dimensione del
  pool in una sola espressione, subito prima di scrivere il framebuffer vecchio (ICH-529). Prima il controllo era un
  lambda con un ciclo: un gestore `trap` che ridimensionava `dst` fra il controllo e la scrittura faceva scrivere 288
  byte in un blocco da 64 (heap corrotto o SIGSEGV).
- `Plane#resize`, `#resize_region`, `#resize_maximize` e il controllo dei bordi prima delle scritture svuotano la
  metà di un glifo largo tagliato dal resize anche quando notcurses non riesce a rileggere il glifo. Con l'egcpool
  del piano pieno (16 MiB) `ncplane_at_yx_cell` fallisce sugli EGC di più di 4 byte: il wrapper ora legge quelle
  celle con `ncplane_at_yx`, che non usa il pool, e ne misura la larghezza. Prima la metà sinistra tagliata restava
  nell'ultima colonna, e la scrittura successiva su quella cella cancellava la prima cella della riga sotto o,
  sull'ultima riga, corrompeva l'heap; un glifo largo illeggibile rimasto intero nelle ultime due colonne perdeva
  invece la metà destra. Anche `#erase_region`, `#gradient`, `#gradient2x1` e `#polyfill` ora leggono quelle celle,
  e non svuotano più nel dubbio le due metà. La lettura vale solo con la libreria 3.0.17, perché il wrapper deve
  riconoscere i piani con un bitmap dai campi privati del piano C (ICH-487).
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
  chiamati due volte (ICH-215). Su un piano che ha già fatto scroll i due passi conservano ogni riga, nel loro
  ordine.
- `Plane#duplicate` copia anche il flag `fixed` e l'allineamento verticale del piano: la copia di un piano creato
  con `fixed: true` non scorre più con il genitore, e `resize_realign` la riallinea come l'originale. Prima
  `ncplane_dup` di notcurses 3.0.17 li azzerava (ICH-216).
- `Plane#merge_down` ripetuto su un `dst` con EGC di più di 4 byte (emoji con un modificatore, lettere con più segni
  combinanti) lascia invariato il contenuto di `dst`. Prima notcurses 3.0.17 copiava a ogni merge quegli EGC
  nell'egcpool di `dst` senza rilasciare le copie vecchie: il pool cresceva fino al limite di 16 MiB, poi le celle
  di `dst` restavano vuote senza errore (ICH-482). Se durante una fusione le copie nuove non entrano nel pool (EGC di
  `dst` per più di circa 8 MiB), `merge_down` lascia `dst` com'era e solleva `PlaneError`.
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
  bloccava la chiamata per sempre (ICH-312). Un'eccezione asincrona (`Thread#raise`, `Timeout`, il kill di
  `FdPlane#close`) sveglia la chiamata e arriva al suo ritorno: `Visual.from_file`, `Direct#load_image` e
  `Direct::Image.new` liberano prima il visual o l'immagine creati dal C, con il file aperto (ICH-474); su Ruby 3.1,
  3.2 e 3.3 un Ctrl-C può ancora lasciarli allocati, e su ogni versione resta una finestra di un'istruzione al
  ritorno del metodo, a risorsa già consegnata.
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
  al terminale lo schermo scorreva a ogni frame (ICH-284). Con il blitter `:pixel` e un frame più basso dello schermo
  in fondo al terminale l'esito non dipende più dal terminale: vedi la voce di ICH-458.
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
- `Process.daemon` con un `Context` o un `Direct` aperto solleva `ContextError` o `DirectError` prima del fork, e il
  contesto resta aperto e usabile (ICH-441): chiudilo prima di `Process.daemon`. Prima il processo che aveva creato
  il contesto usciva dentro `daemon(3)` senza lo stop (`Process.daemon` non passa da `Process._fork`), e il
  terminale restava senza echo e in modo non canonico, con `Context` anche sullo schermo alternativo e con il cursore
  nascosto. L'errore arriva anche mentre un altro thread è dentro `Context.new` o `Direct.new`, con il terminale già
  nel modo dell'init. Senza un contesto aperto, o in un processo figlio creato con `fork`, `Process.daemon` non cambia.
- `Context.new` e `Direct.new` interrotti durante l'init non lasciano più il registro occupato né il contesto C attivo
  (ICH-226). Il thread interno dell'init esegue anche il rollback, e lo finisce dopo un secondo Ctrl-C e dopo un
  `Thread#kill` del thread che chiama `new`. Prima un secondo Ctrl-C mentre il terminale non aveva ancora risposto
  faceva uscire il rollback a metà: ogni init successivo sollevava `InitError`, e all'uscita il processo poteva
  terminare con SIGSEGV. Ora il secondo Ctrl-C fa uscire subito `new`, e fino al ritorno dell'init un nuovo init
  solleva ancora `InitError`; dopo il registro è libero. Un errore della chiamata C arriva al chiamante senza scrivere
  niente su stderr (prima il thread scriveva il proprio report), e il registro resta libero (prima restava occupato).
  Un'eccezione asincrona subito dopo l'apertura di `output:` non lascia più aperto il file. Resta una finestra di
  un'istruzione al ritorno di `new`, a contesto già adottato: il contesto resta aperto e registrato, e lo chiude
  l'hook `at_exit`.

### Limiti noti

- notcurses 3.0.17 si blocca quando una lettura dell'input finisce a metà di un carattere UTF-8 di più byte:
  `Context#get`, `Direct#get` ed `EventLoop#run` non ricevono più input, e `Context#close` e `Direct#close` non
  ritornano. Succede con stdin sul terminale (per esempio un incolla lungo di testo non ASCII) o rediretto senza
  `/dev/tty`. Il wrapper non lo può evitare: il limite è nello YARD e nel README, e la correzione è proposta a
  notcurses ([PR #2954](https://github.com/dankamongmen/notcurses/pull/2954)) (ICH-463).
- Su Ruby 3.1, 3.2 e 3.3 `Thread.handle_interrupt` non rimanda l'Interrupt di un segnale (lo rimanda da Ruby 3.4).
  Due segnali, il secondo consegnato in pochi passi di codice, possono saltare una parte della pulizia (ICH-539).
  In `EventLoop#run`, un secondo segnale dopo l'interruzione della pulizia, prima che ricominci, fa uscire `run` con
  i passi rimasti da fare: i trap di WINCH e CONT, i pipe di risveglio, ISIG o IXON e `running?`, che resta true (un
  nuovo `run` dello stesso ciclo solleva `Error`). In `Context#close` durante `run`, lo stesso caso nell'attesa del
  thread di input fa uscire `close` prima dello stop: il contesto resta aperto, e un `close` successivo completa lo
  stop. Nelle prove con 200 segnali a 0,2 ms di distanza la finestra non si è mai vista. Il limite è nello YARD.

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
