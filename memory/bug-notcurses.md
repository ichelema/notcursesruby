# Bug di notcurses 3.0.17

Registro dei bug e dei limiti di notcurses 3.0.17 trovati dal progetto: per ognuno il file C, la riga e la gestione
nel wrapper. Un bug nuovo va nella tabella della sua area, con il lotto e la issue (regola 11 di
[regole.md](regole.md)).

## Regola

Un bug che corrompe la memoria o va in crash si previene **prima** della chiamata C, con un'eccezione chiara. Un bug
di semantica si aggira in Ruby se il workaround è corto e sicuro; altrimenti si documenta nel YARD ("Bug di 3.0.17
...") e in questo file. Una funzione che non funziona affatto non si espone e va nell'elenco `excluded` della spec
di copertura.

## Bug aggirati

### Contesto e input

| Bug | Workaround |
| --- | --- |
| Un secondo contesto (notcurses o direct) fallisce, anche con i gestori di segnale disattivati (`unixsig.c:199-203`) | `acquire_context`: `InitError` prima del C |
| `termtype:` scrive `ENV['TERM']` anche se l'init fallisce; l'init successivo fallisce (`termdesc.c:1661-1681`) | il wrapper ripristina `TERM` dopo un init fallito |
| `notcurses_stop`/`drop_planes` con un `ncreader` vivo: double free (`reader.c:12`; stesso schema in `plot.c:608`) | widget adottati chiusi prima, in ordine inverso |
| `drop_planes` lascia una pila non standard di 2 o più piani con puntatori pendenti (`notcurses.c:467-480`, `1413-1435`) | il wrapper distrugge prima, piano per piano, le pile con piani conosciuti |
| `ncpile_rasterize` su una pila mai renderizzata: SIGSEGV | solo `render_pile(rasterize: true)`, che fa render e rasterize |
| `notcurses_stop` restituisce l'OR di più ritorni | errore solo se diverso da 0 |
| `cursor_disable` e `mice_disable` non sono idempotenti (-1 se già spenti) | stato in Ruby; dopo un `Reader` lo stato è "sconosciuto" e il -1 è tollerato |
| `notcurses_get`/`get_blocking`: GVL tenuto, nessun timeout | attesa in Ruby su `inputready_fd`, poi `get_nblock` |
| Alt segnalato solo nel campo deprecato `alt` (prefisso ESC) | `Input#modifiers` aggiunge `NCKEY_MOD_ALT` |
| `ncpalette_set*` accetta l'indice 256 (heap overflow) | indice controllato in 0..255 |
| `ncpile_render_to_buffer`/`render_to_file`: nessun output, double free nel secondo | non esposte |
| Con un terminale che non risponde mai alle query dell'init, il C aspetta la risposta senza timeout (`termdesc.c:1217` → `inputlayer_get_responses`, `pthread_cond_wait`, `in.c:2924-2925`): nessun segnale né l'ubf di Ruby lo sveglia, e all'uscita `rb_thread_terminate_all` aspetta il thread dell'init per sempre | dopo un segnale o un `exit` `new` aspetta al più 2 secondi (`Util.await_init`, `INIT_GRACE`) e poi esce con l'eccezione del segnale o la `SystemExit`; se il processo esce con l'init ancora fermo, l'hook `at_exit` ripristina il terminale da Ruby (`restore_init_tty`, come il ramo `err:` di `interrogate_terminfo`, `termdesc.c:1538-1552`) e chiude il processo senza aspettare gli altri thread (`force_exit`) (lotto 8c, ICH-576; scelte dell'utente) |
| Su macOS `notcurses_stop` aspetta il lettore del pty in `tcsetattr(TCSAFLUSH)` (`notcurses.c:147`): con un pty letto da un thread Ruby dello stesso processo e il GVL tenuto, `Context#close` si blocca | `blocking: ::FFI::Platform.mac?` su `notcurses_stop`: solo su macOS la chiamata rilascia il GVL, su Linux non cambia (scelta dell'utente; Fase 5, ICH-478) |
| `tcsetattr` interrotta da `EINTR` non viene ripetuta (`notcurses.c:147`); succede solo dove `TCSAFLUSH` aspetta (macOS). Con il GVL rilasciato, un `Thread#raise` o un `Timeout` durante la chiusura sblocca la chiamata e lascia il terminale nel modo di notcurses. Un segnale gestito da Ruby durante l'attesa fa fallire `notcurses_stop` con -1 e il termios non torna com'era, anche con il GVL tenuto | `Context#stop_notcurses` esegue lo stop in un thread dedicato, atteso con le interruzioni rimandate (`Thread.handle_interrupt` da solo non basta). Il segnale gestito da Ruby resta non aggirato: `Context#close` solleva `ContextError` (Fase 5) |

### Piani

| Bug | Workaround |
| --- | --- |
| `ncplane_resize_marginalized`/`placewithin` spostano il piano fuori dal genitore | scritte in Ruby |
| `NCPLANE_OPTION_MARGINALIZED` ignora i margini alto e sinistro | `create_child(margins:)` calcola posizione e dimensioni in Ruby |
| `ncplane_dup` posiziona la copia con le coordinate assolute come relative, la mette in cima e azzera scrolling e autogrow; crea la copia con `flags = 0` e copia solo `halign`, quindi perde il flag fixed e `valign` (`notcurses.c:776`, `793`) | `Plane#duplicate` sposta la copia e ripristina i flag; scrive `fixedbound` e `valign` nei campi privati della copia (`Plane::Internals`, solo con la libreria 3.0.17 e se i campi coincidono con l'API pubblica) (ICH-216); non copia il callback di resize interno di un widget (crash al primo resize) |
| `ncplane_resize`: offset positivi, regione che non entra (con `x_off < 0` scrive oltre il buffer), resize ignorato, `y_off` con larghezza intera | casi rifiutati con `ArgumentError` |
| `ncplane_resize` con `keep_x > 0`: il ciclo che rilascia gli EGC delle celle perse (`notcurses.c:995-997`) parte dall'indice nel framebuffer nuovo (`itery * xlen - xoff + keeplenx`) e lo usa come colonna di quello vecchio. Nelle righe di destinazione in cui quell'indice è minore di `keepx + keeplenx` (di solito la sola riga 0) rilascia dall'egcpool EGC di più di 4 byte che restano nella regione conservata: quelle celle risultano vuote (`ncplane_at_yx_cell` fallisce) o, dopo un'altra scrittura, mostrano l'EGC di un'altra cella. Solo il contenuto, non la memoria del processo (ICH-215) | `Plane#resize_region` fa il resize in due passi quando `keep_x + x_off > -y_off * cols`: il primo con `extra = ceil((keep_x + x_off) / cols) + y_off` righe vuote in più in alto (`y_off - extra`, `rows + extra`), che portano la prima riga copiata oltre quell'indice; il secondo (`keep_y: extra`, `keep_x: 0`, dove il ciclo non tocca la regione) le toglie. I callback di resize dei figli girano due volte, la prima con il piano più alto. Il secondo passo si fa sempre quando il C accetta il primo (non è lo stdplane, la regione sta nel piano, `notcurses.c:842-849`, `1013`, e la malloc riesce: il framebuffer cambia), anche quando ha restituito il -1 di un callback o un callback ha spostato il piano (review). Con le righe in più il ciclo del C non rilascia nemmeno gli EGC delle celle scartate: dopo i due passi il wrapper rilascia quelli del framebuffer vecchio che non sono nel nuovo e che hanno ancora il primo byte nel pool (`release_unused!`, review del round 2). Fra i due passi il wrapper azzera `logrow`: il C scrive il framebuffer nuovo in ordine logico ma lo lascia, e su un piano che ha fatto scroll il secondo passo perdeva una riga |
| `ncplane_cursor_move_yx` cambia x anche quando poi rifiuta y | posizione controllata prima |
| `ncplane_scrollup` tratta ogni riga come un "a capo" dal cursore | il cursore va prima sull'ultima riga |
| `ncplane_at_yx` con la metà destra di un glifo largo isolata in colonna 0 può non tornare più | il wrapper cerca la metà sinistra; altrimenti restituisce la cella base |
| Un resize che taglia un glifo largo lascia la metà sinistra (larga 2) nell'ultima colonna, o la metà destra in colonna 0 con `keep_x > 0` (`notcurses.c:991`), oppure nell'ultima colonna senza la metà sinistra con `x_off < 0`; la scrittura successiva su quella cella cancella una cella della riga vicina, o scrive fuori dal framebuffer (`notcurses.c:1917-1927`). Succede anche nei resize del C: lo stdplane quando il terminale si restringe (`render.c:108`), i figli con `:maximize` (ICH-271) | le tre `resize*` svuotano le metà orfane sui bordi; prima di ogni scrittura il wrapper fa lo stesso se le colonne del piano sono cambiate dall'ultima volta o se un `merge_down` lo ha toccato; su uno stdplane che scorre, prima di una scrittura che va a capo, `ncpile_render` lo porta alle dimensioni del terminale (il render dentro `ncplane_put` lo restringerebbe a metà chiamata). Le celle si leggono con `ncplane_at_yx_cell`, che duplica l'EGC nell'egcpool (`notcurses.c:297`) e con il pool pieno (16 MiB, `egcpool.h:36`) fallisce sugli EGC di più di 4 byte: quelle celle il wrapper le legge con `ncplane_at_yx`, che copia l'EGC con `strdup`, e ne misura la larghezza con `ncstrwidth`; prima la metà sinistra tagliata di un glifo illeggibile restava (ICH-487). Sui piani con un bitmap (campo `sprite`) `ncplane_at_yx` copierebbe la sequenza dello sprixel (`notcurses.c:236-243`), già liberata con Kitty: quelle celle non si leggono |
| `ncplane_erase_region` (`notcurses.c:2536-2541`), `ncplane_gradient` (`fill.c:259-264`), `ncplane_gradient2x1` (`fill.c:199-206`) e `ncplane_polyfill_yx` (`fill.c:23-60`) cambiano ogni cella da sola: su una sola metà di un glifo largo lasciano l'altra metà orfana, e la scrittura larga successiva vicino a una metà destra orfana cancella la prima cella della riga dopo o scrive fuori dal framebuffer (`notcurses.c:1956-1962`). `ncplane_stain` e `ncplane_format` non toccano gli EGC (ICH-450) | prima della chiamata il wrapper legge i glifi larghi interi a cavallo dei lati del rettangolo (per `polyfill` tutti quelli del piano, perché la regione riempita non è nota); dopo la chiamata, anche se fallisce a metà, svuota l'altra metà di quelli coperti solo a metà. Non si guarda lo stato dopo la chiamata: una metà destra con width 0, che `merge_down` lasciava sempre (ICH-481) e, fino a ICH-485, con l'egcpool pieno, è uguale a una cella vuota, quindi una metà sinistra seguita da una cella vuota può essere un glifo intero. Con l'egcpool pieno `ncplane_at_yx_cell` non legge le celle con un EGC di più di 4 byte (le duplica nel pool): da ICH-487 il wrapper le legge con `ncplane_at_yx`, quindi sa se sono una metà sinistra. Prima una cella illeggibile davanti a una metà destra contava come glifo, e se il riempimento scriveva un EGC lungo il wrapper nel dubbio svuotava le due metà: quel ramo resta per le celle che non si leggono affatto |
| `ncplane_mergedown` lascia la metà destra di ogni glifo largo di dst con width 0 (`paint`, `render.c:393-395`; ciclo di `postpaint_cell`, `render.c:471-485`): per notcurses non è più una metà destra, `ncplane_at_yx` restituisce la cella base, e `ncplane_put` sulla metà sinistra non la cancella; una scrittura stretta e poi una larga sulla stessa colonna lasciano una metà destra orfana, che porta alla scrittura fuori dalla riga (`notcurses.c:1917-1927`, `1956-1962`) (ICH-481) | dopo la fusione il wrapper riscrive con `ncplane_putc_yx` ogni glifo largo di dst con la metà destra vuota e larga 0, e rimette il cursore di dst dov'era. Per riscriverlo lo legge con `ncplane_at_yx_cell`, che duplica l'EGC nell'egcpool di dst (`notcurses.c:297`) e con il pool pieno (16 MiB) fallisce sugli EGC di più di 4 byte: quei glifi li legge con `ncplane_at_yx` (`strdup`) e li rimette con `ncplane_putegc_yx`, con gli stili e i canali della cella al posto di quelli del piano per la durata della scrittura (`ncplane_put` rilascia la vecchia copia prima di salvare la nuova, quindi lo spazio c'è); se la scrittura fallisce svuota le due metà. Lo stesso per l'ultima cella della riga quando il cursore va rimesso oltre l'ultima colonna (ICH-485) |
| Non è un bug, ma serve a leggere le righe di `ncplane_mergedown`: `paint` scrive uno spazio largo 1 al posto di un glifo largo nell'ultima colonna dello schermo, o con la cella dopo occupata da un piano più alto (`render.c:375-383`) | nessuno serve: `postpaint_cell` non trova mai un glifo largo nell'ultima colonna (ipotesi scartata nel lotto 1) |
| `ncplane_mergedown` dopo una metà sinistra orfana di src seguita da un glifo disegna il glifo largo intero: la cella dopo perde l'EGC e prende i canali della metà sinistra (`postpaint_cell`, `render.c:471-485`) (ICH-530, ICH-532) | per la fusione il wrapper cambia in src ogni metà orfana seguita da un glifo in uno spazio con gli stessi stili e canali (scrittura grezza della cella, l'EGC resta nel pool) e rimette i byte dopo: il C compone lo spazio e il glifo |
| `ncplane_resize` che non conserva niente scarica l'egcpool (`notcurses.c:957`; anche la rotazione, `fill.c:446`) e la cella base tiene il suo offset (ICH-489). `rotate_2x1_cw` e `rotate_2x1_ccw` non rilasciano le celle lette con `ncplane_at_yx_cell` quando rifiutano un carattere (`fill.c:377-437`): le copie restano nel pool fino al prossimo svuotamento (ICH-531) | durante la chiamata il wrapper scrive uno spazio nel campo privato della base senza rilasciare l'EGC; con il framebuffer invariato rimette i byte, altrimenti ricarica la base con `ncplane_set_base` prima del primo callback Ruby di resize o dopo la chiamata. Le copie della rotazione rifiutata: non aggirato |
| `ncplane_contents` lascia nell'egcpool una copia di ogni EGC lungo, a ogni chiamata (fino a 16 MiB) | `Plane#contents` legge le celle una per una e le rilascia |
| `ncplane_mergedown` ignora la regione | solo `merge_down` completo (`ncplane_mergedown_simple`) |
| `ncplane_mergedown` copia ogni EGC di più di 4 byte nell'egcpool di dst (`cell_duplicate_far`, `internal.h:909-925`) e libera il framebuffer vecchio senza rilasciare i suoi EGC (`render.c:602-603`): il pool di dst cresce a ogni merge fino al limite di 16 MiB (`egcpool.h:36`), poi le celle restano vuote e `ncplane_mergedown_simple` restituisce comunque 0. Con 10 EGC di 8 byte in un dst 1x20 `dst.contents` diventava `""` dopo circa 186.000 merge (ICH-482) | `Plane#merge_down` legge prima del merge i byte del framebuffer di dst (`fb_bytes`, dai campi privati di `Plane::Internals`, solo con la libreria 3.0.17 e se i campi coincidono con l'API pubblica) e dopo un merge riuscito rilascia con `nccell_release` gli EGC delle celle che stanno nel pool. Durante il merge copie vecchie e nuove stanno insieme nel pool: se una copia non entra, `cell_duplicate_far` lascia la cella con `gcluster` 0 e `width` > 0 (`internal.h:909-922`); il wrapper lo vede nel framebuffer nuovo, rilascia le copie nuove, rimette i byte del framebuffer vecchio e solleva `PlaneError` (review). 400.000 merge dello scenario: contenuto invariato, pool fermo a 8192 byte (90 usati), circa 46 µs per merge |
| `ncplane_puttext`: ciclo infinito, -1 dopo una scrittura completa, allineamento sbagliato | `Plane#puttext` in Ruby |
| `ncplane_putstr_aligned` e scritture con `x:` su un piano che scorre: il primo carattere va fuori dalla riga | controllo prima della chiamata |
| TAB nell'ultima colonna: il ciclo di espansione scrive la cella `x == lenx`, cioè la riga successiva o oltre il framebuffer (`notcurses.c:1936-1957`) | TAB rifiutati in `putstr`/`putegc`/`Cell`; il `Reader` scrive uno spazio |
| EGC che notcurses segmenta come larghezza zero (U+200B, segno combinante isolato, keycap U+20E3, jamo hangul): con il cursore a `x == dim_x` scrive fuori dalla riga (`notcurses.c:1873-1893`) | rifiutati prima della scrittura |
| Dopo uno ZWJ (U+200D) il C unisce tutto il resto del testo in un solo EGC (`egcpool.h:126-128`) | testo spezzato dopo ogni grapheme con ZWJ (`Util.zwj_segments`); `Notcurses.strwidth` misura i segmenti, così anche `puttext` e la UI (ICH-285, ICH-286) |
| U+2028 e U+2029 troncati a un byte | rifiutati |
| `ncplane_fadeout`/`fadein`: render della pila standard, `nanosleep` con il GVL, con un callback lento non arrivano in fondo | `Plane#fadeout`/`#fadein` in Ruby sopra `FadeContext` |
| `ncplane_pulse` resta nero dopo il primo ciclo e senza callback non ritorna | `Plane#pulse` in Ruby, blocco obbligatorio |
| Bit di servizio dei canali (`0x87000000`) copiati dai setter | canali mascherati |
| Eccezione Ruby in un callback di resize: attraversa il C, `pilelock` resta acquisito | trampolino con `Util.guard` |
| Limiti dello stdplane (non si distrugge, sposta, ridimensiona con `resize`, riparenta; niente autogrow) | rifiutati prima della chiamata |
| Con l'egcpool pieno (16 MiB) `ncplane_put` svuota il glifo di arrivo (anche le due metà di un glifo largo) e gli dà gli stili e i canali della scrittura (del piano con `putstr`, della cella con `putc`, `notcurses.c:1928-1929`, `1996`), poi fallisce in `egcpool_stash` (`notcurses.c:1911-1950`, `internal.h:1459`): una scrittura fallita cambia il piano | `putstr`/`putegc`: ogni EGC di più di 4 byte ha una chiamata C sua; prima il wrapper legge il glifo di arrivo con `ncplane_at_yx` (`strdup`) e, se la scrittura fallisce, lo riscrive con `ncplane_putc_yx` (il C ha già rilasciato la copia vecchia) e rimette il cursore (lotto 8b, review mirata di ICH-533). Con il pool quasi pieno anche il ripristino può fallire e il glifo va perso (ICH-591, in Backlog). `putc` e le altre scritture con una `Cell`: prova su una copia del piano (`Plane#rehearse!`, lotto 8d, ICH-582) |
| `ncplane_hline_interp` e `ncplane_vline_interp` (anche da `ncplane_box`) tengono nel pool una copia di lavoro della cella (`dupc`), e quando una `ncplane_putc` fallisce escono senza rilasciarla (`notcurses.c:2207-2211`, `2268-2272`): la copia resta nel pool fino a `erase` o a un resize (misurati +5 MB). Prima di fallire hanno già scritto le prime celle e svuotato quella di arrivo | `Plane#rehearse!` prova la scrittura su una copia del piano (`ncplane_dup` copia framebuffer, cursore, cella base ed egcpool; il wrapper ripristina scrolling, autogrow e `logrow`) e solleva `PlaneError` prima della scrittura vera; solo per EGC di più di 4 byte (lotto 8d, ICH-582) |
| `ncplane_gradient` (`fill.c:259-263`), `ncplane_polyfill_yx` (`fill.c:40-42`) e `ncplane_set_base` (`notcurses.h:754-756`, `internal.h:1449`, `1464`) falliscono con il pool pieno dopo aver già cambiato celle (canali azzerati, cella svuotata) o la base (stili e canali nuovi, EGC vecchio rilasciato) | `Plane#rehearse!`, come sopra (lotto 8d, ICH-582) |
| `ncplane_base` duplica l'EGC della base nel pool (`notcurses.c:1572-1574`): con una base lunga e il pool pieno `Plane#base` solleva `PlaneError` senza dire il motivo | non aggirato: ICH-592, in Backlog |
| `nccell_load` divide in più EGC alcuni grapheme che per Ruby (da Unicode 15.1 per i coniugati) sono uno solo: bandiere (due indicatori regionali larghi 1), coniugati devanagari, hangul con i jamo L, V e T (T largo 0), keycap (U+20E3 largo 0) | le scritture con una `Cell` e `set_base` (che teneva il primo pezzo) sollevano `CellError` con i pezzi e con che cosa usare; `putstr` scrive bandiere e coniugati in celle vicine (lotto 8b, ICH-217) |
| notcurses conta un indicatore regionale largo 1 colonna (`wcwidth`). Un indicatore da solo, Ghostty 1.4 e Kitty 0.51 lo disegnano largo 2: il testo dopo si sposta e restano residui sullo schermo. Una bandiera è larga 2 per notcurses, Ghostty e Kitty; solo un terminale che non raggruppa i grapheme (libghostty-vt di `ncvt` senza il modo 2027) la disegna larga 4. Misure del 2026-11-23 con la colonna del cursore, tabella in `.claude/skills/verify/SKILL.md` | `Util.lone_regional_indicator!`: `Cell.new`, `putstr`, `putegc`, `puttext`, `printf`, `set_base`, `gradient` e il testo di `Notcurses::UI` rifiutano un indicatore da solo con `ArgumentError`; le bandiere passano (lotto 8d, ICH-586) |
| Il coniugato devanagari "क्ष" è largo 2 per notcurses (due EGC larghi 1) e per Ghostty, ma Kitty 0.51 lo disegna largo 1: su Kitty il testo dopo si sposta a sinistra | non aggirato: ICH-590, in Backlog |
| `ncplane_at_yx` su un piano con un bitmap legge il framebuffer come celle: con Kitty il C libera la sequenza dello sprixel dopo il disegno e la chiamata fa `strdup(NULL)` (SIGSEGV); con sixel restituisce la sequenza di escape | `Plane#at` solleva `PlaneError` su ogni piano con un bitmap, sixel compreso: come in `Plane#contents`, quel piano non si legge cella per cella (lotto 2b, ICH-493; scelta dell'utente) |

### Celle

| Bug | Workaround |
| --- | --- |
| `NCCELL_INITIALIZER` e `NCCELL_CHAR_INITIALIZER` con caratteri non ASCII: EGC non valido o finta cella larga | non esposte: `Cell.new` passa da `nccell_load` |
| `nccell_duplicate` svuota la cella se sorgente e destinazione coincidono, e non copia tra piani | una `Cell` si copia come valore |
| `nccells_load_box`: carica 6 celle senza controllare la segmentazione dei glifi | `Plane#box` carica le celle una per una con il controllo |

### Direct

| Bug | Workaround |
| --- | --- |
| `ncdirect_stop` scrive il proprio reset (`\e[39;49m\e(B\e[m`) sullo stdout del processo anche quando l'output è un file (`direct.c:841`) | dal lotto 6 delle issue in Backlog (ICH-222): durante lo stop il fd 1 punta a `/dev/null` (`mute_stdout!`); un fd 1 in sola lettura non si sposta (`IO#reopen` fra modi d'accesso diversi va in segfault in Ruby). Limiti nello YARD di `Direct#close`; il buffer stdio della libc si perde (ICH-560) |
| `ncdirect_vline` con `UINT_MAX` va in SIGFPE; oltre `INT_MAX` le linee fanno fino a 2^32 iterazioni con colori sbagliati (`direct.c:1351`) | lunghezza massima `INT_MAX - 1` |
| `ncdirect_vline` torna indietro di una colonna dopo ogni carattere (`direct.c:1389`) | un solo EGC largo una colonna |
| Dopo uno ZWJ (U+200D) `ncdirect_putegc` e `ncstrwidth` uniscono tutto il resto del testo in un solo EGC (`egcpool.h:126-128`) | `putegc` passa al C solo il primo segmento di `Util.zwj_segments`; `print_aligned` misura con `Notcurses.strwidth`, che somma i segmenti (ICH-285) |
| `hline`/`vline`/`box` interpolano i bit RGB anche dei canali a palette: l'indice finisce nel blu (`direct.c:1285-1292`) | `ArgumentError` per i canali a palette |
| `ncdirect_cursor_move_yx` per conservare la colonna legge la posizione dal terminale (condizione invertita, `direct.c:233`) | con `x: nil` serve `can_get_cursor?`, altrimenti `DirectError` (il C andrebbe alla colonna 0) |
| `ncdirect_align` con un allineamento non valido restituisce `INT_MAX` e il C scrive una sequenza spazzatura (`direct.c:411-426`) | solo `:left`, `:center`, `:right` |
| `ncdirect_printf_aligned` scrive su stdout invece che sull'output e aggiunge "\n" (`direct.c:818`) | `Direct#print_aligned` in Ruby: colonna come `ncdirect_align`, poi `ncdirect_putstr` |
| Il render direct legge solo blitter e scaling (`direct.c:635-737`); blitter fuori tabella (`blit.c:1375`) | opzioni ridotte a blitter e scaling; `:four_by_one` e `:eight_by_one` (solo per i plot) rifiutati |
| `ncdirect_raster_frame` libera il piano su tutti i percorsi, anche di errore (`direct.c:631`) | il `Frame` risulta chiuso prima della chiamata: un secondo `raster` non arriva al C |
| `ncdirect_putstr` con NULL: `fputs(NULL)` (`direct.c:46`, `52`) | `nil` rifiutato |
| Dopo la fine dell'input ogni lettura restituisce EOF (`in.c:2798`) | documentato in `Direct#get` |
| `readline` e `cursor_yx` attendono la risposta del terminale senza timeout (`in.c:2820`) | `DirectError` senza `can_get_cursor?`; con un terminale vero l'attesa resta (documentata), ma dal 2026-10-26 rilascia il GVL. `Direct#readline` restituisce `nil` a fine input e su errore, perché NULL non porta `errno` e `eof` è privato di `struct ncdirect` |
| `termtype:` scrive `ENV['TERM']` anche se l'init fallisce (`termdesc.c:1672`) | `TERM` ripristinato dopo un init fallito |
| `ncdirect_stream` ignora il ritorno del callback (`direct.c:1588`), va in SIGSEGV con `vopts` NULL e tiene il GVL per tutto il video | `Direct#stream` in Ruby: `break` nel blocco ferma lo stream. Il riposizionamento del C (`direct.c:1550-1559`) sale di `rows - 1` righe, ma il raster lascia il cursore sotto il frame (`direct.c:558`): dal 2026-11-11 `stream` sale di `rows` righe, senza CUB (ICH-284) |

### Visual

| Bug | Workaround |
| --- | --- |
| Un `ncvisual` creato senza un contesto attivo va in crash alla distruzione (`details` NULL, `ffmpeg.c:735`) | serve un contesto aperto; `Context#close` e `#drop_planes` chiudono i visual adottati |
| `ncvisual_from_rgba` accetta `rowstride < cols * 4` lasciando pixel non inizializzati (`visual.c:784`); senza ffmpeg, con `rowstride > cols * 4` scrive oltre il buffer (`visual.c:768`, `801`) | `rowstride` controllato, al C passano righe compatte |
| `ncvisual_from_rgb_loose` con `rowstride` maggiore dello stride interno copia righe oltre il buffer (`visual.c:884`) | al C passano righe compatte |
| `ncblit_rgb_packed` legge i pixel con passo di 1 byte invece di 3 (`visual.c:494`) | `Visual.blit_rgb_packed` usa `ncvisual_from_rgb_packed` e `ncvisual_blit` |
| `ncvisual_from_palidx` ignora i colori della palette (`visual.c:969`) | dal lotto 6 (ICH-223): `Visual.from_palidx` costruisce i pixel RGBA in Ruby e chiama `ncvisual_from_rgba`; una voce `Channel.palindex` solleva `ArgumentError` (ICH-551) |
| `ncvisual_rotate` perde la prima riga e la prima colonna a ogni angolo (`visual.c:746`, `>` al posto di `>=`); `rotate_bounding_box` ruota il riquadro dei pixel attorno al proprio centro e i pixel attorno al centro dell'immagine (`visual.c:658-705`): con bordi trasparenti diversi sui lati perde pixel opachi | dal lotto 6 (ICH-223): `Visual#rotate` è un porting in Ruby con `>=` e il riquadro ruotato attorno al centro dell'immagine; resize e scrittura dei pixel in un blocco `Thread.handle_interrupt`. Costo: una chiamata C per pixel (ICH-554) |
| `ncvisual_bounding_box` a volte calcola un riquadro più stretto di quello vero (`visual.c:537-628`; due pixel sulla diagonale di un 2x2 danno una colonna) | dal lotto 6: il wrapper calcola il riquadro vero (`Internal.bounding_box`) |
| I blitter di celle scrivono ogni cella da sola: un blit su una metà di un glifo largo lascia l'altra metà orfana (ICH-486), come `ncplane_gradient` prima di ICH-450 | dal lotto 6: i blit su un piano esistente svuotano l'altra metà; il rettangolo viene da `ncvisual_geom` (ICH-549), e con `:braille` il controllo copre anche l'interno, perché `braille_blit` non tocca le celle con soli pixel trasparenti (`blit.c:1205-1206`, costo in ICH-556); un blit `:pixel` non scrive celle e non si controlla (ICH-550); un blit `:pixel` che restringe il piano può tagliare un glifo largo (`visual.c:1123`, ICH-561, non aggirato) |
| `ncvisual_stream` su un visual non creato da file, o con `vopts` NULL: crash (`ffmpeg.c:501`, `508`) | `VisualError` per un visual non da file; opzioni sempre passate |
| Stream con `child: true` (`NCVISUAL_OPTION_CHILDPLANE`): un piano nuovo a ogni frame, tutti lasciati tranne l'ultimo (`ffmpeg.c:528`) | `child:` e regioni non ammessi in `stream` |
| Blit di una regione diversa dall'immagine intera: il C ridimensiona dall'inizio dei dati ignorando `begy`/`begx`, poi legge oltre il buffer (`ffmpeg.c:586`); con `nointerpolate` o senza ffmpeg la regione è ignorata | la regione viene copiata pixel per pixel in un visual temporaneo, che viene disegnato |
| Il decoder di `ncvisual_from_sixel` scrive o legge fuori dai buffer con indici di colore >= 65535, definizioni troncate, "!" senza cifre, righe dell'ultima banda oltre `rows` (`sixel.h:131`, `167`, `180`) | sequenza controllata prima della chiamata: passa solo ciò che il decoder legge in sicurezza |
| `ncvisual_resize_noninterpolative` con 0 righe o colonne | dimensioni controllate |
| `ncvisual_simple_streamer` va in crash con `vopts->n` NULL | non esposta: è già lo streamer predefinito di `Visual#stream` |
| I blitset dei plot `NCBLIT_4x1` e `NCBLIT_8x1` hanno `egcs` NULL (`blit.c:1279`, `1282`), e `lookup_blitset` li restituisce con i quadranti (Kitty, Ghostty, rxvt, Konsole; `blit.c:1329-1345`). `ncplane_as_rgba` e `ncvisual_from_plane` passano quel NULL a `wcsrchr` (`notcurses.c:3114`, `3175`): SIGSEGV. I blit li disegnano con `tria_blit` (2 righe di pixel per cella) su un piano calcolato per 4 o 8: l'immagine resta tagliata | `Util::IMAGE_BLITTERS` (senza `:four_by_one` e `:eight_by_one`) per `Visual`, `Plane#as_rgba` e `Direct`: `ArgumentError` prima del C; `Plot` usa ancora `Util::BLITTERS` (ICH-272) |

### Widget A (Selector, MultiSelector, Menu, Reader, ProgBar)

| Bug | Workaround |
| --- | --- |
| `ncselector_delitem`: selezione fuori limite, `startdisp` mai aggiornato, segfault nel ridisegno, double free nel destroy (`selector.c:436-441`) | non esposta: `Selector` non cancella voci |
| `ncselector_destroy(&item)` su un selettore vuoto legge da NULL (`selector.c:273`) | il wrapper passa sempre NULL; la voce si legge con `selected` |
| Testi con caratteri di controllo (`ncstrwidth` = -1) rompono il layout (`selector.c:308`, `413`, `909-913`) | rifiutati |
| `ncmultiselector_selected` non scrive mai la voce 0 (`selector.c:1006`) | stato ricavato in Ruby |
| `desc` NULL nel multiselector: segfault (`selector.c:942`, `951`) | `nil` diventa `""` |
| Multiselector con 0 voci: segfault sullo spazio (`selector.c:818`) | `ArgumentError` |
| Genitore troppo piccolo: il C distrugge il piano del selettore (`selector.c:865-880`) | controllo prima, `WidgetError`, piano intatto |
| Piano del multiselector di 1 riga: `ncmultiselector_draw` confronta `yoff` unsigned con `dimy - 2` (`selector.c:696`) e gira circa 2^32 volte, con il GVL tenuto | `offer_input` legge le righe a ogni chiamata e sotto 2 solleva `WidgetError` prima del C (lotto 5, ICH-277) |
| Scorciatoia di una voce di menu da U+0800: scrittura oltre il buffer; da U+10000: abort (`menu.c:103-124`) | rifiutata |
| `ncmenu_item_set_status`: `strcmp` su NULL (divisori, separatori), logica invertita (`menu.c:788-791`) | rifiuto, e doppia chiamata solo quando lo stato cambia |
| `ncmenu_nextitem`/`previtem` leggono `sections[-1]` se la sezione 0 non si apre (`menu.c:599`, `620`) | il wrapper apre prima un'altra sezione |
| `ncmenu_nextsection`/`prevsection`: ciclo infinito senza sezioni apribili (`menu.c:566-589`) | false senza chiamare il C |
| Un clic su una voce la seleziona ma restituisce false (`menu.c:721-726`) | `offer_input` restituisce true |
| Un evento con id 0 apre la prima sezione senza scorciatoia (`menu.c:746`) | in tutti i widget gli eventi con id 0 e `0xffffffff` non vanno al C |
| `ncreader_offer_input` con 4 codepoint legge oltre `eff_text` (`reader.c:404-410`) | il testo dell'evento lo scrive il wrapper, come farebbe il C |
| Backspace a inizio riga sposta solo la copia nascosta, poi abort (`reader.c:265`, `90`) | il wrapper riallinea vista e cursore del terminale |
| Backspace, Ctrl+U e Ctrl+W non cancellano la colonna 0: il C scrive `""` con `ncplane_putegc_yx` (`reader.c:263`), che in colonna 0 fallisce (`(unsigned)x + cols - 1` con cols 0, `notcurses.c:1883`) | il wrapper svuota la cella nella copia nascosta (campo privato `textarea`, `Reader::Internals`, solo con la libreria 3.0.17 e se i campi coincidono con l'API pubblica) e nella vista, con `ncplane_putc_yx` di una cella vuota, che toglie anche le due metà di un glifo largo; Ctrl+W solo se arriva alla colonna 0 senza fermarsi su un separatore, come il C (lotto 8 delle issue in Backlog, ICH-218) |
| `ncreader_redraw` copia una cella della copia nascosta nella vista solo se EGC, stile o canali sono diversi, senza confrontare la width (`cellcmp_and_dupfar`, `internal.h:1510-1523`, `reader.c:100`): dopo lo svuotamento della vista di Backspace, Ctrl+U e Ctrl+W le metà destre dei glifi larghi restano con width 0 (`Plane#at` non restituisce il glifo), e nei ridisegni successivi di Ctrl+U e Ctrl+W una metà destra cancellata resterebbe nella vista | durante quei tasti il wrapper dà a ogni cella della copia nascosta un bit di stile che notcurses non usa (`0x8000`, con `ncplane_format`); il C cancella con stile 0, quindi il ridisegno copia ogni cella cambiata con la sua width; dopo la chiamata lo stile torna 0 nei due piani (lotto 8 delle issue in Backlog, ICH-484) |
| Ogni ridisegno accende il cursore del terminale e lo porta nel campo, anche senza `NCREADER_OPTION_CURSOR` (`reader.c:105`) | con `cursor: false` il wrapper rimette dopo ogni operazione lo stato dell'ultimo `Context#cursor_enable` o `#cursor_disable` (`Context#restore_cursor!`, esito del C ignorato: senza un tty il C non spegne il cursore); con `cursor: true` il reader mostra il cursore, come vuole notcurses (ICH-218) |
| Backspace dopo un glifo largo cancella il glifo intero ma sposta il cursore di una sola colonna: `do_backspace` scrive `""` in `x - 1`, sulla metà destra, e lascia lì il cursore dei due piani (`reader.c:252-268`); la scrittura dopo lascia una cella vuota nel campo, che `contents` non mostra (`"a漢"`, Backspace, `"c"`: celle `a`, vuota, `c`, contenuto `"ac"`) | prima della chiamata C il wrapper controlla nella copia nascosta (`Reader::Internals`, solo con la libreria 3.0.17) se la colonna `x - 1` è la metà destra di un glifo largo (`Reader#wide_glyph_start`); dopo la chiamata porta i cursori della copia nascosta e della vista, e con `cursor: true` quello del terminale, sulla prima colonna del glifo (`ncplane_put` toglie le due metà: `notcurses.c:1917-1923`; lotto 8c, ICH-581) |
| `NCREADER_OPTION_HORSCROLL` con glifi larghi: abort (`reader.c:90`, `222-246`) | opzione non offerta |
| Cursore, dimensioni o scrolling della vista cambiati dall'esterno: letture fuori dal piano (`reader.c:134-136`) | cursore riallineato prima di ogni operazione, altrimenti `WidgetError` |
| EGC di larghezza zero sull'ultima colonna: vista e copia nascosta a x == colonne (`reader.c:240-246`, clamp con cols 0); poi ogni scrittura fallisce e Backspace + freccia sinistra fa abort (`reader.c:90`) | scartato in `put_egc`; il ritorno di `ncplane_cursor_move_yx` diventa `WidgetError` (lotto 4, ICH-273) |
| `ncreader_write_egc` scrive solo il primo EGC della stringa e restituisce 0 (`reader.c:233-238`) | `write` passa i pezzi di `nccell_load` uno alla volta (lotto 4, ICH-274) |
| `nccell_load` di U+2028 restituisce 1 byte e taglia il codepoint (`utf8_egc_len`, `egcpool.h`) | un pezzo non UTF-8 valido non si usa: il resto del grapheme va al C, che lo rifiuta (lotto 4) |
| `ncreader_contents` è `ncplane_contents` sulla vista: una copia nell'egcpool per ogni EGC di più di 4 byte a ogni chiamata (`reader.c:413-415`) | `Reader#contents` usa `Plane#contents` (lotto 4, ICH-275) |
| `ncprogbar_progress` non inizializzato prima del primo set (`progbar.c:18-23`) | 0.0 |
| NaN supera il controllo di `ncprogbar_set_progress` (`progbar.c:178`) | rifiutato |
| Con `-freciprocal-math` l'indice del glifo di bordo arriva a 8 per alcuni valori: -1 e barra a metà (`progbar.c:124`) | `p` abbassato di qualche ulp (0 fallimenti su 9922 valori) |

### Reel, Tree, Tabbed

| Bug | Workaround |
| --- | --- |
| `ncreel`: heap corrotto in `trim_reel_overhang` con una sequenza di add/del/next (`reel.c:494-544`); `infinite_scroll` e `circular` validati e poi ignorati (`reel.c:774-781`) | `Reel` e `Tablet` in Ruby sopra `Plane` (vedi sotto) |
| `nctree_del` legge `spec[-1]` (`tree.c:253`) | l'ultimo indice viene ripetuto davanti al vettore |
| Il `realloc` di `nctree_add` e `nctree_del` lascia `curitem` pendente (`tree.c:182-186`) | fuoco riportato con HOME e N × `nctree_next` |
| `nctree_prev`/`next`/`focused`/`offer_input` su un albero vuoto dereferenziano NULL (`tree.c:351`, `398`, `607`) | il C non viene chiamato |
| `nctree_del` con un percorso vuoto: double free (`tree.c:250`) | `ArgumentError` |
| Le voci di più righe sopra il fuoco si sovrappongono e i loro piani non cambiano mai altezza (`tree.c:419-448`) | il callback del wrapper impila le voci |
| I piani delle voci già creati non cambiano mai larghezza (`tree.c:456`, `FIXME possibly enlarge`): dopo un resize in larghezza dell'albero il blocco disegna fuori dall'albero, o non usa le colonne nuove | `resize_item` porta ogni piano a `dim_x(albero) - x(voce)` colonne, almeno 1 (lotto 11, ICH-287) |
| Indentazione più larga del piano: piani di larghezza negativa (`tree.c:444`) | rifiutata |
| Dopo un resize più piccolo la riga attiva resta fuori dal piano e `nctree_redraw` fallisce (`tree.c:522`) | fuoco riposizionato e nuovo tentativo |
| `nctree_goto` è uno stub (`tree.c:609-616`) | `Tree#goto` in Ruby |
| `nctabbed_rotate`, `nctab_move_left`/`right` senza tab: crash (`tabbed.c:335-363`) | `rotate` senza tab non fa nulla; gli altri due non si possono chiamare (il `Tab` è chiuso) |
| Nome di un tab o separatore NULL: crash (`tabbed.c:247`, `457`, `480`) | `TypeError`/`ArgumentError`; rifiutati anche i caratteri di controllo |
| `nctab_move` con `after` e `before` ha il controllo di adiacenza invertito (`tabbed.c:305`) | si accetta solo uno dei due |
| `nctab_move` non aggiorna `leftmost` (`tabbed.c:303-332`) | corretto con `nctabbed_rotate` |
| Nessuna funzione di `tabbed.c` controlla che un tab appartenga al widget | controllo in Ruby (`ArgumentError`) |

Il `Reel` in Ruby segue l'header di `ncreel` dove il C non lo fa: `infinite_scroll:` e `circular:` funzionano (il C è
sempre circolare). Differenze volute: `add` senza `after:`/`before:` mette il tablet in fondo (il C lo mette prima del
fuoco); cancellando il tablet con il fuoco il fuoco va al successivo, o al precedente se era l'ultimo; a ogni
ridisegno il piano del reel viene cancellato e il blocco di ogni tablet è chiamato una sola volta; `Tablet#plane` vale
fino al ridisegno successivo. Bordi arrotondati, ASCII senza UTF-8; niente PgUp/PgDn, come nel C. `Reel` include
`Widget` con il proprio piano (`to_ptr` restituisce il `ncplane*` del reel).

### Plot, FdPlane, Subprocess

| Bug | Workaround |
| --- | --- |
| Indici dei campioni: `ncuplot_add_sample`/`set_sample` e il ridisegno calcolano lo slot in due modi diversi (`plot.c:595`, `616`, `635` contro `657`) | il wrapper trasla le x passate al C, così ogni salto finisce su un multiplo di `slotcount`: `sample` e il dominio sono corretti |
| `set_sample` con x dietro la finestra (`plot.c:657`, `701`) | false senza chiamare il C; prima di ogni scrittura una lettura di controllo con `ncuplot_sample` |
| x >= 2^63 (`plot.c:595`, `616`) | con la traslazione il C non lo riceve mai; l'utente può passare x fino a 2^64-1 |
| `label_ticks:` su un piano di 7 colonne o meno (`plot.c:290`) | `ArgumentError` alla creazione, `WidgetError` a ogni campione (il piano si può ridimensionare dopo) |
| Blitter fuori tabella (`blit.c:1374`) | blitter controllato; la degradazione di `lookup_blitset` è replicata in Ruby e il C riceve sempre `NODEGRADE`, così il numero di slot calcolato in Ruby è quello del C |
| -1 sia per un campione fuori dal dominio fisso sia per un ridisegno fallito (`plot.c:583`, `706`) | il primo restituisce false (il valore resta leggibile), il secondo solleva `WidgetError` |
| Somma dei campioni oltre 2^64-1, o non finita per i double (`plot.c:661`, `673`) | `ArgumentError` |
| Plot in pixel con una cella di 0 pixel: `x % 0`, SIGFPE (`notcurses.c:382` non azzera `pixel_draw_late`; rischio teorico) | blitter pixel usato solo con celle di dimensione maggiore di 0 |
| `ncfdplane_destroy` durante o dentro il callback blocca l'interprete (`fd.c:136-148`); con `follow` busy loop a fine file (`fd.c:50-70`); il ritorno del callback non ferma il thread | `FdPlane` in Ruby: Thread Ruby con `IO#readpartial`, `follow:` ritenta ogni 0,1 s |
| `ncsubproc_destroy` in deadlock con il figlio vivo (`fd.c:432-436`); 3 fd lasciati aperti (`fd.c:231-234`, `438`); il figlio eredita lo stdin (`fd.c:196`); exec fallito non segnalato (`fd.c:207`); SIGKILL a un PID forse riciclato (`fd.c:411`); `restart_period` ignorato | `Subprocess` in Ruby (sottoclasse di `FdPlane`): stdin da `/dev/null`, `close_others`, exec fallito → `Errno::*` subito, kill solo se `Process.detach` non ha ancora raccolto il figlio |

### Formato (`format.rb`)

| Bug | Workaround |
| --- | --- |
| `ncnmetric` con 0 < value < decimal moltiplica value per la base fino a decimal senza un controllo di overflow funzionante (`metric.c:53-59`: la guardia di `metric.c:56` controlla `dv`, che non cambia): cifre e prefisso sbagliati, senza errore. Serve decimal > (2^64-1)/base | `metric`, `si_prefix`, `binary_prefix` e `byte_prefix` ripetono il ciclo del C con gli Integer di Ruby e sollevano `ArgumentError` solo per le coppie che vanno in overflow; l'intervallo di `decimal` resta `1..(2**64-1)/10` (ICH-302) |

## Input, eventi e segnali

Bug e limiti dell'input, degli eventi e dei segnali trovati dalla Fase 3 in poi. La colonna «Gestione» dice se il
wrapper li aggira.

| Bug o limite | Dove | Gestione |
| --- | --- | --- |
| `notcurses_get` svuota tutto il pipe di prontezza, anche con altri eventi in coda | `in.c:2751-2757` | il ciclo legge fino al primo `nil` a ogni risveglio; il primo giro di ogni `run` non attende, così legge subito gli eventi lasciati in coda dal run precedente (uscito con `stop` o con un'eccezione) |
| A fine input il pipe resta leggibile per sempre; con `drain_input: true` `get` solleva sempre `InputError` | `in.c:2610-2616`, `2702-2710` | `Key::EOF` ferma il ciclo (`:eof`); un contesto che scarta l'input non viene ascoltato (`Context#drain_input?`) |
| `NCKEY_RESIZE` entra in coda solo insieme ad altro input | `in.c:2439-2445` | di default `trap('WINCH')` durante `run`; dopo ogni render un cambio di dimensioni non segnalato si applica al giro dopo |
| `"\n"` dopo una riga piena: due a capo | `notcurses.c:1888-1890`, `1903-1904` | corretto nella Parte 0 della Fase 3 |
| Il modo del terminale toglie solo ECHO, ICANON e ICRNL: Ctrl+S e Ctrl+Q restano il controllo di flusso (IXON), Ctrl+C, Ctrl+Z e Ctrl+\ restano segnali (ISIG) | `termdesc.c:1631-1637` | non arrivano come tasti con le impostazioni predefinite; `EventLoop#run` con `no_flow_control: true` e `no_linesigs: true` li consegna a `on_key` (YARD); la demo usa Ctrl+X |
| In `read_input_nblock` la condizione su `errno` non è mai vera dove `EAGAIN == EWOULDBLOCK` (Linux): ogni errore di `read`, anche EIO, segna la fine dell'input | `in.c:2180-2190` | letto nel C, non riprodotto: per esempio un pty il cui master si chiude dà `Key::EOF`, e `run` restituisce `:eof` |
| notcurses divide il keycap `"1️⃣"` diversamente da Ruby e ne scrive U+20E3 come carattere di larghezza zero | `nccell_load` | `Text.check!` chiama `Plane#check_text!` alla costruzione e nel setter, prima che il piano del widget esista, quindi un keycap non valido viene rifiutato; `LogView` riceve byte qualsiasi e al disegno lo scrive come `"?"` |
| Nessuno stile «reverse»; senza tty `cursor_disable` e `mice_enable` sollevano `ContextError` | — | il focus si mostra con i colori; `App` ignora l'errore di `cursor_disable` |
| Con il protocollo tastiera kitty notcurses alza SIGINT, SIGSTOP o SIGQUIT per Ctrl+C, Ctrl+Z e Ctrl+\ solo se i modificatori sono Ctrl da solo: con CapsLock o NumLock (kitty li aggiunge) non alza niente e consegna il tasto; con Ctrl da solo alza il segnale e mette anche l'evento in coda. Lo alza anche per la ripetizione e il rilascio (notcurses chiede il flag kitty 2, i tipi di evento), e lo decide da un flag privato (`ictx->linesigs`) che `stty` non cambia: lo cambiano solo `notcurses_linesigs_disable` ed `enable`, che scrivono anche ISIG, e con `ttyfd < 0` nemmeno loro | `in.c:506-516`, `in.c:2840-2918`, `termdesc.c:390` | all'avvio `EventLoop#run` spegne il flag con `notcurses_linesigs_disable` e rimette ISIG com'era con `tcsetattr` (`Context#isig_enable`); con ISIG attivo alza lui lo stesso segnale al proprio processo, una volta per pressione e dopo aver letto il tasto, e non consegna questi tasti (ICH-280, ICH-454, ICH-456, ICH-455). Dopo `run` il flag resta spento. Con `drain_input` `run` non legge i tasti e lascia i segnali a notcurses, come su `master` (con `no_linesigs` spegne il flag e lo riaccende alla fine con `linesigs_enable`); senza terminale il flag resta acceso: limiti scritti nello YARD |
| Con la coda di input piena (8192 eventi) notcurses scarta il tasto nuovo: per l'input da terminale non frena chi scrive (`process_bulk` frena solo l'input rediretto) | `in.c:523-527`, `in.c:2370-2395` | il thread di input di `EventLoop#run` svuota la coda e legge solo l'id degli eventi che non sono tasti di segnale; con la CPU occupata anche il Ctrl+C dopo 10000 tasti si è perso, di rado: limiti nello YARD di `run` e su ICH-536 (lotto 3 delle issue in Backlog) |
| Una sequenza CSI-u di kitty spezzata fra due letture fa fallire `assert(val > 0)` e ferma il processo | `in.c:803` (`kitty_kbd_txt`) | non aggirato; succede anche con un ciclo di `Context#get` senza `EventLoop` (riprodotto dalla review del lotto 3 delle issue in Backlog) |
| Una sequenza escape spezzata fra due letture fa fallire `assert(ictx->amata.used <= buflen)` e ferma il processo | `in.c:2229` (`process_escape`) | non aggirato; succede anche su `master` (riprodotto dalla review del lotto 3 delle issue in Backlog) |
| Un carattere UTF-8 di più byte spezzato fra due letture blocca il thread di input: `process_input` restituisce 0 (servono altri byte), ma `process_melange` esce dal ciclo solo con un valore negativo e gira per sempre sugli stessi byte. `get` non riceve più eventi e `notcurses_stop` resta in `pthread_join`, perché il ciclo non ha punti di cancellazione. Succede quando notcurses legge stdin senza un terminale separato: stdin sul terminale (un incolla di 2731 caratteri CJK su un pty si ferma dopo 682) o rediretto senza `/dev/tty` (il repro di ICH-463 si ferma a 2730 su 2731, anche con `Direct#get` ed `EventLoop#run`). Con stdin rediretto e `/dev/tty`, `process_bulk` esce già su `<= 0` | `in.c:2335-2338` (`process_input`), `in.c:2427` (`process_melange`), `in.c:2662` | non aggirato: limite nello YARD di `Context#get`, `Direct#get` ed `EventLoop#run`, nel README e nel CHANGELOG. Correzione di una riga (`consumed <= 0`) proposta upstream: issue [#2947](https://github.com/dankamongmen/notcurses/issues/2947), PR [#2954](https://github.com/dankamongmen/notcurses/pull/2954). La prova si fa con `loglevel:` spento: il warning a ogni giro introduce un punto di cancellazione, e `close` può tornare anche con il blocco in corso. ICH-463 è in Blocked fino a una versione corretta di notcurses |
| Il report SGR del movimento con un tasto premuto (bit 32) diventa una nuova pressione dello stesso tasto: `mouse_click` mette `NCTYPE_PRESS` per ogni report `M` e `id = NCKEY_BUTTON1 + mods % 4` | `in.c:610-620` | `App` tratta come drag una pressione di BUTTON1..3 con lo stesso tasto già premuto: niente focus, niente componenti, solo `on_input`; un drag non ripete il clic di un `Button` (ICH-283) |
| Sulla console Linux il mouse viene da gpm: ogni evento (pressione, rilascio, drag, qualsiasi tasto) diventa `\e[<0;x;yM`, cioè una pressione di BUTTON1, e un rilascio non arriva mai | `mice.c:4-19`, `gpm.c:31` | `App` non applica la regola del drag quando `Context#detected_terminal` è `"FBcon"` o `"VT"`: lì ogni pressione è un clic (trovato nella review del lotto 8) |
| Con stdin che non è un tty, notcurses (build con gli assert) abortisce a ogni tasto letto da `/dev/tty`, anche senza `no_flow_control:` e `no_linesigs:` | `in.c:2308` | non aggirato: il ramo `/dev/tty` di `Context#flow_control_disable` oggi non ha un caso d'uso (ICH-229) |
| Con stdin e output su due tty diversi, notcurses applica ISIG al tty di output | — | `run` legge IXON e ISIG sul terminale di input: limite non aggirato (ICH-229) |
| Con il suo gestore di SIGWINCH, notcurses blocca SIGWINCH e SIGCONT con `pthread_sigmask` solo nel thread che esegue l'init | `unixsig.c:216-220` | il wrapper fa l'init in un thread interno, quindi i thread del chiamante non restano con i due segnali bloccati (YARD di `Context`) |
| I gestori dei segnali fatali (SIGINT, SIGTERM, SIGSEGV, ...) hanno `SA_RESETHAND`: dopo `fatal_handler` il segnale torna al default e termina il processo, senza `Interrupt`, `ensure` né `at_exit` | `unixsig.c:252-258` | default `no_quit_sighandlers: true`, diverso dal C (YARD di `Context.open`) |

## Bug noti non aggirati (documentati nel YARD)

- **`logrow` dopo il primo scroll** (`notcurses.c:615`, `1777`): `Plane#duplicate`, i resize (anche la crescita per
  autogrow), `rotate_cw`/`rotate_ccw`, il merge sul piano di destinazione e `FadeContext` permutano o perdono righe.
  Un workaround servirebbe un flag "ha fatto scroll" impostato da ogni output: non fatto.
- **Riga vuota sullo schermo dopo uno scroll su `ncvt`** (ICH-603): quando un `"\n"` fa scorrere lo stdplane, lo
  schermo mostra una riga vuota prima dell'ultima. Il piano è corretto e `Context#refresh` riallinea lo schermo. Succede
  anche con la FFI diretta e non è provato su Kitty o Ghostty con un display.
- `Cell`: notcurses segmenta alcuni grapheme in modo diverso da Ruby (bandiere, sillabe hangul composte, coniugati
  devanagari); scrivere quelle celle solleva `CellError`.
- Reader: `tchannels` e `tattrword` non hanno effetto (non offerti). La colonna 0 e il cursore del terminale sono
  aggirati dal lotto 8 delle issue in Backlog (ICH-218, tabella "Widget A"). `ncreader_redraw` copia le celle
  dell'area di testo nella vista con l'offset `xproject` (`reader.c:94-100`): può lasciare la metà destra di un
  glifo largo in colonna 0 della vista senza un resize, e il controllo di ICH-271 (basato sulle dimensioni) non la
  vede in una scrittura su `Reader#plane`.
- Menu: un clic su un separatore può togliere la selezione (`menu.c:722`, flag non inizializzato); `mouse_selected` è
  impreciso per le sezioni allineate a destra.
- Tabbed: l'intestazione non segue il resize del piano (`tabbed.c:35`, `39`); con `bottom: true` sta sulla penultima
  riga (`tabbed.c:37`, `191`).
- Tree: il C calcola la riga attiva con l'altezza della voce che aveva il fuoco prima: con voci di altezze diverse il
  fuoco si sposta di qualche riga.
- ProgBar: su un piano largo 1 colonna, e senza UTF-8 anche alto 1 riga, `ncplane_gradient2x1` e `ncplane_gradient`
  vogliono sinistra e destra uguali (`fill.c:192-197`, `238-255`); senza UTF-8 un piano 1x1 vuole i quattro colori
  uguali. Altrimenti ogni `progress=` solleva `WidgetError` (lotto 11, ICH-288).
- Plot: con `label_ticks:` da circa 1,84e17 (2^64/100) le etichette sono sbagliate. Il C converte il valore per 100
  da double a `uintmax_t` (`plot.c:128-136`, `298-306`): fuori intervallo è un comportamento indefinito, "184.47P"
  sulla build CachyOS x86-64-v4 e "0.00" sulla build Arch generica. Con `exponential:` e `:uint64` la riga alta
  moltiplica interi (`plot.c:300`) e riparte da 0 oltre 2^64 (lotto 11, ICH-290).
- Direct: `Frame#close` abbandona il frame senza liberarne la memoria C (3.0.17 non offre un distruttore pubblico;
  won't fix nel lotto 6 delle issue in Backlog, ICH-222). Il reset di `stop` su stdout è aggirato dal lotto 6.
- Visual: `ncvisual_from_palidx` e `ncvisual_rotate` sono aggirati dal lotto 6 (tabella "Visual").
- Piani: `ncplane_qrcode` con il cursore fuori da (0, 0) scrive fuori dal proprio buffer di pixel (`fill.c:612-616`)
  e corrompe la heap: documentato nello YARD di `Plane#qrcode` (ICH-542). Il codice QR sopra metà di un glifo largo
  lascia l'altra metà orfana: aggirato dal lotto 6 (ICH-488).

## Layer FFI (Fase 1)

Colpiscono anche il C nativo (e l'oracolo). Non sono bug del binding.

1. `ncpile_render_to_buffer`: senza postpaint non emette testo (`*buflen` vale 0). `*buf` è il buffer interno
   (mmap su Linux, malloc altrove): `free()`, come chiede l'header, va in crash o causa un double free.
2. `ncpile_render_to_file`: non scrive nulla su `fp` e libera `pile->crender` senza azzerarlo (double free in `notcurses_stop`).
3. `ncdirect_printf_aligned`: scrive con `puts()` su stdout e non sul `FILE*` di `ncdirect_init`. Aggiunge `"\n"` e
   restituisce il valore di `puts()`, non le colonne.
4. `ncplane_put` (usata da `putc`, box, `hline`/`vline`):
   - un glifo largo o un TAB all'ultima colonna di un piano che scorre scrive fuori dalla riga e corrompe l'heap;
   - una cella con `width > lenx` su un piano che scorre viene accettata e corrompe l'heap alla scrittura successiva;
   - una cella con `gcluster` 0 e `width >= 2` viene presa per la metà destra di un glifo largo, e la scrittura
     successiva legge prima dell'inizio del framebuffer;
   - un EGC di più byte che inizia con `'\n'` passa `is_control_egc`: `ncplane_hline_interp` con `len` grande esegue
     circa 2^32 iterazioni.
5. `ncplane_putegc_stained`: con il cursore a `x == lenx` sull'ultima riga legge fuori dal framebuffer.
6. `ncplane_vline_interp`: con `len == UINT_MAX` va in SIGFPE (divisione per `(int)len + 1`).
7. `ncplane_resize_marginalized` su un piano non marginalizzato legge `margin_b`/`margin_r` non inizializzati.
8. `nctree_goto` è uno stub che restituisce sempre NULL. `nctree_del` non aggiorna fuoco e percorso corrente.
9. `ncplane_scrollup` restituisce 0 invece del numero di righe scorse.
10. `ncplane_mergedown` controlla la regione ma dipinge tutto il piano sorgente.
11. `ncdirect_stream` ignora il ritorno del callback. Senza `NCVISUAL_OPTION_HORALIGNED` fallisce prima di chiamarlo.
12. `ncplane_qrcode` restituisce sempre -1 nella build Arch, compilata senza qrcodegen.
13. `nccell_load_ucs32` lascia non inizializzati i byte di `utf8[]` oltre la sequenza (UB). La reimplementazione azzera il buffer.
