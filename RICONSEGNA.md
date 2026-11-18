# RICONSEGNA — notcursesruby

## Fase 1 — layer FFI raw

- **Data di completamento:** 2026-10-25
- **Versione mappata:** notcurses 3.0.17 (`version.h`)
- **Log dettagliato:** `memory/fase1-ffi-raw.md` (decisioni, problemi e soluzioni, lista completa delle inline, funzioni saltate)
- **Modifiche successive (2026-10-26):** `blocking: true` su 8 funzioni di `functions.rb` che aspettano il terminale o
  il tempo (gli init, `ncdirect_cursor_yx`, `ncdirect_cursor_move_yx`, `ncdirect_readline`, `ncvisual_stream`);
  decisione 20 di `memory/fase1-ffi-raw.md`. Nella review della Fase 2, su autorizzazione dell'utente, anche su
  `ncdirect_render_image` e `ncdirect_raster_frame` (finding A3-02).
- **Modifiche successive (2026-10-27, ICH-229):** su autorizzazione dell'utente, `tcgetattr` e `tcsetattr` della libc,
  la struct `Termios` (i quattro flag e una coda opaca), la typedef `:tcflag_t` e le costanti `IXON`, `ISIG` e
  `TCSANOW`, con i valori per sistema. Dettagli nella sezione "ICH-229" in fondo.
- **Modifiche successive (2026-11-14, ICH-312):** su autorizzazione dell'utente (lotto 17), `blocking: true` anche su
  `ncvisual_from_file`, `ncvisual_decode`, `ncvisual_decode_loop`, `ncdirect_render_frame` e `ncdirectf_from_file`,
  che aprono o leggono un file con ffmpeg senza limite di tempo (FIFO, URL, file system lento); decisione 20 di
  `memory/fase1-ffi-raw.md`.
- **Modifiche successive (2026-11-15, ICH-478):** su autorizzazione dell'utente (Fase 5, Parte 3), `notcurses_stop`
  con `blocking: ::FFI::Platform.mac?`: solo su macOS la chiamata rilascia il GVL. Dettagli nella sezione "Fase 5".
- **Modifiche successive (2026-11-14, ICH-313):** su autorizzazione dell'utente (lotto 17), `typedefs.rb` definisce
  `:wchar_t` come `:int32` e `:uintmax_t` come `:uint64` dentro `Notcurses::FFI` solo quando il `types.conf` di ffi
  non li ha (FreeBSD, NetBSD, OpenBSD, Linux i386/ppc64/riscv64/s390x): prima `require 'notcurses'` sollevava
  `TypeError`. Le quattro `::FFI::MemoryPointer.new(:wchar_t, n)` di `inline_reimpl.rb` (e quella di
  `Direct#box_chars`) usano `:int32`, perché la mappa globale dei tipi di ffi non vede le typedef del modulo.

### File generati

| File | Righe | Contenuto |
| --- | ---: | --- |
| `lib/notcurses/ffi.rb` | 28 | modulo `Notcurses::FFI`, `ffi_lib` (libnotcurses, libnotcurses-core, libc), `require` dei sotto-file |
| `lib/notcurses/ffi/typedefs.rb` | 55 | 15 typedef: 6 enum (`:int`), 6 callback (`:pointer`), 2 alias `:ncchannel`/`:ncchannels`, `:tcflag_t` della libc |
| `lib/notcurses/ffi/enums.rb` | 58 | 6 enum, 39 enumeratori |
| `lib/notcurses/ffi/constants.rb` | 478 | 304 costanti: `version.h`, `#define` di `notcurses.h`/`direct.h`, `NCKEY_*` di `nckeys.h`, stringhe di `ncseqs.h`, `IXON`/`ISIG`/`TCSANOW` di `<termios.h>` |
| `lib/notcurses/ffi/structs.rb` | 325 | 27 struct `::FFI::Struct` |
| `lib/notcurses/ffi/functions.rb` | 653 | 385 `attach_function`, divise per area |
| `lib/notcurses/ffi/inline_reimpl.rb` | 3171 | 248 metodi Ruby (236 `static inline` e 12 macro funzione), ognuno con il C originale in commento |
| `spec/ffi_sanity_spec.rb` | 27 | spec di sanità (codice del prompt più le due righe di intestazione) |
| `spec/inline_reimpl_spec.rb` | 1970 | spec differenziale: ogni reimplementazione contro l'inline C vera |
| `spec/support/nc_oracle.rb` | 275 | oracolo: le 236 inline C collegate da `libnotcurses-ffi.so.3` |
| `Gemfile`, `Gemfile.lock` | 5 | `ffi ~> 1.15` (bloccata a 1.17.4), `rspec ~> 3.12` (3.13.2) nel gruppo `test` |
| `memory/fase1-ffi-raw.md` | 255 | log della Fase 1 |

### Totali

| Voce | Numero | Dettaglio |
| --- | ---: | --- |
| Funzioni collegate (`attach_function`) | 385 | 373 API di notcurses (320 da `notcurses.h`, 53 da `direct.h`) più 12 della libc |
| Funzioni reimplementate in Ruby | 248 | 236 `static inline` più 12 macro funzione |
| Struct | 27 | 25 struct pubbliche più `Timespec` e `Termios` |
| Enum | 6 | 39 enumeratori |
| Costanti | 343 | 304 in `constants.rb` (247 intere, di cui 151 `NCKEY_*`, e 57 stringhe) più 39 enumeratori |
| Typedef | 15 | 6 enum, 6 callback, 2 alias, `:tcflag_t` |

Nessuna funzione saltata: ogni funzione pubblica di `notcurses.h` e `direct.h` è collegata o reimplementata.

### `# REVIEW:` lasciati aperti (7)

| File e riga | Funzione | Motivo |
| --- | --- | --- |
| `lib/notcurses/ffi/functions.rb:50` | `ncpile_render_to_buffer` | bug di 3.0.17: senza postpaint non emette testo; `*buf` è il buffer interno di notcurses e non va liberato con `free()`, anche se l'header lo chiede |
| `lib/notcurses/ffi/functions.rb:52` | `ncpile_render_to_file` | bug di 3.0.17: non scrive su `fp` e causa un double free in `notcurses_stop` |
| `lib/notcurses/ffi/functions.rb:182` | `ncplane_vprintf_aligned` | `va_list` non costruibile da Ruby |
| `lib/notcurses/ffi/functions.rb:184` | `ncplane_vprintf_yx` | `va_list` non costruibile da Ruby |
| `lib/notcurses/ffi/functions.rb:186` | `ncplane_vprintf_stained` | `va_list` non costruibile da Ruby |
| `lib/notcurses/ffi/functions.rb:537` | `ncnmetric` | il C restituisce `buf` (memoria del chiamante) o NULL; `:string` ne restituisce una copia (`nil` se NULL) |
| `lib/notcurses/ffi/inline_reimpl.rb:802` | `ncplane_vprintf` | `va_list` non costruibile da Ruby; da Ruby si usa `ncplane_printf` |

### `# UNION:` da verificare a mano

Nessuno. Le struct pubbliche di notcurses 3.0.17 non contengono union. `check_base` conferma dimensione, allineamento
e offset di ogni campo delle 26 struct contro il C compilato.

### Dipendenze di sistema

- **notcurses 3.0.x**, con `libnotcurses.so.3` e `libnotcurses-core.so.3`.
  - Arch Linux: `pacman -S notcurses` (provato con 3.0.17-3: il pacchetto contiene librerie, header e `libnotcurses-ffi.so.3`).
  - Altre distribuzioni: `libnotcurses-dev` o equivalente (non provato). Basta anche il solo runtime, perché `ffi_lib`
    cerca pure i nomi versionati (`libnotcurses.so.3`, `libnotcurses-core.so.3`).
  - macOS: `brew install notcurses` (provato con 3.0.17_1 su macOS 26.5.2, Apple Silicon, nella Fase 5): la gem ffi
    trova le librerie in `/opt/homebrew/lib` senza variabili d'ambiente. Per i test serve anche
    `brew install coreutils` (comando `timeout`).
- **Facoltativa:** `libnotcurses-ffi.so.3`, solo per la spec differenziale. Se manca, quella spec va in skip.
- **libc** (glibc su Linux): `fopen`, `fclose`, `free`, `tcgetattr`, `tcsetattr` e le funzioni usate dalle
  reimplementazioni.
- **terminfo** (database di ncurses) con una voce per il terminale, per esempio `xterm-256color`.
- **Ruby >= 3.1** (provato su Ruby 4.0.7 e 3.1.7), Bundler, le gem del `Gemfile`. Nessun compilatore: il progetto
  non ha C extension.

### Come eseguire i test

Dalla radice del progetto:

```sh
bundle install
bundle exec rspec spec/ffi_sanity_spec.rb < /dev/null                         # spec di sanità (3 esempi)
bundle exec rspec < /dev/null                                                 # tutte le spec (257 esempi)
NC_SPEC_SEED=1234 bundle exec rspec spec/inline_reimpl_spec.rb < /dev/null    # spec differenziale con un altro seed
```

- La spec di sanità chiama `notcurses_init` con `termtype` NULL, quindi notcurses legge `TERM`. Se `TERM` manca o vale
  `dumb`, l'esempio `can init and stop without crash` fallisce perché `notcurses_init` restituisce NULL. In CI usa
  `TERM=xterm-256color bundle exec rspec`.
- Le spec dei colori RGB (`context_spec.rb`, `direct_spec.rb`, 10 esempi) richiedono `COLORTERM=truecolor`:
  notcurses abilita i 24 bit solo con quella variabile (`termdesc.c:191`). Trovato dalla CI nella Fase 4.
- La spec differenziale usa sempre `termtype = "xterm-256color"` e non dipende da `TERM`. Alcuni esempi vanno in skip
  con una locale non UTF-8 o su un host big-endian, perché i valori attesi sono calcolati con UTF-8 su little-endian.
- Ho eseguito i test senza terminale di controllo (stdin da `/dev/null`, nessun `/dev/tty`). Da un terminale
  interattivo notcurses può aprire `/dev/tty` e interrogare il terminale: questo caso non è provato.

### Cosa serve alla Fase 2

1. **Ciclo di vita degli oggetti.** Ogni puntatore opaco (`notcurses*`, `ncplane*`, `ncvisual*`, widget) deve avere
   una classe Ruby con il suo distruttore (`notcurses_stop`, `ncplane_destroy`, `ncvisual_destroy`,
   `nc*_destroy`, ...). In `functions.rb` i costruttori non indicano il distruttore: serve una tabella di abbinamento.
2. **Memoria `ALLOC`.** La memoria marcata `# ALLOC` va liberata con `Notcurses::FFI.free`. In `functions.rb` sono
   16 API più `strdup`; tra le 16 ci sono i parametri `char**` di uscita di `ncselector_destroy` e `ncreader_destroy`
   e il ritorno di `notcurses_stats_alloc`. Vale anche per le inline `nccell_strdup`, `nccell_extract` e
   `ncwcsrtombs`. Opzioni: `::FFI::AutoPointer` o blocchi `ensure`.
3. **NULL.** I ritorni `:pointer` vanno controllati con `.null?`. Anche un ritorno `Classe.by_ref` NULL diventa
   un'istanza con `.null? == true`, non `nil`.
4. **Stringhe.** I ritorni `:string` hanno encoding BINARY: serve `force_encoding(Encoding::UTF_8)`. Una String con NUL
   interno solleva `ArgumentError`.
5. **Callback.** I parametri callback sono `:pointer`. Serve un `::FFI::Function` con la firma C (in `typedefs.rb` e
   nei commenti `# callback:`), e il wrapper deve tenerlo referenziato finché notcurses lo può chiamare (GC).
6. **Validazione ai confini.** Le reimplementazioni inline troncano gli interi fuori range, senza `RangeError`. Le
   `attach_function` invece sollevano `RangeError`/`TypeError`. I wrapper devono controllare range e tipi.
7. **printf.** Le funzioni con `va_list` non si possono usare da Ruby. Si formatta in Ruby e si chiama
   `ncplane_putstr*`, oppure si usa `ncplane_printf*` con `:varargs`.
8. **Bug di notcurses 3.0.17 da aggirare** (elenco completo in `memory/fase1-ffi-raw.md`):
   - non liberare il buffer di `ncpile_render_to_buffer` e non usare `ncpile_render_to_file`;
   - sui piani che scorrono, rifiutare in `ncplane_putc`/box le celle con `width > lenx`, con `gcluster` 0 e
     `width >= 2`, o con un EGC di più byte che inizia con `"\n"`;
   - limitare `len` di `ncplane_vline`/`hline` (con `UINT_MAX` va in SIGFPE);
   - `ncdirect_printf_aligned` scrive su stdout; `nctree_goto` è uno stub; `ncplane_scrollup` restituisce 0;
     `ncplane_resize_marginalized` vuole un piano marginalizzato;
   - non passare `nil` come `gclusters` a `nccells_load_box`: nel C è comportamento indefinito.
9. **Contesti e segnali.** Un contesto notcurses e uno ncdirect non possono essere attivi insieme nello stesso
   processo: `ncdirect_core_init` fallisce con "already registered for signals". La Fase 2 deve decidere chi gestisce i
   segnali (`NCOPTION_NO_QUIT_SIGHANDLERS`, `NCOPTION_NO_WINCH_SIGHANDLER`) e il `termtype` di default.
10. **Test.** Lo schema della spec differenziale (oracolo `libnotcurses-ffi`, `termtype` fisso, contesto unico su
    `/dev/null`) si può riusare per i wrapper idiomatici.
11. **Piattaforme.** Provato solo su Linux x86_64. Big-endian solo simulato; macOS e Ruby 3.1 non provati.

## Fase 2 — wrapper Ruby idiomatico

- **Data di completamento:** 2026-10-25
- **Log dettagliato:** `memory/fase2-wrapper-idiomatico.md` (decisioni di design, ciclo di vita, memoria e callback,
  tabelle dei bug aggirati, funzioni escluse, differenze dai pattern del prompt, verifiche)
- **Fase 1:** nessun file modificato durante la Fase 2. Il 2026-10-26, su richiesta, `blocking: true` su 8 funzioni
  di `lib/notcurses/ffi/functions.rb`, e nella review su altre 2 (vedi il punto 6 di "Cosa serve alla Fase 3").
- **Dimensioni** (dopo la review e il fix trovato su Ruby 3.1): 28 file in `lib/` (12 604 righe, Fase 1 esclusa); 31
  file di spec e helper (8 130 righe) più 2 fixture (`spec/fixtures/visual/rgbw.png`, `frames.mkv`).
- **Uso:** `require 'notcurses'`; il punto di ingresso è `Notcurses::Context.open { |nc| ... }` (o
  `Notcurses::Direct.open`).

### Classi e moduli

| Classe o modulo | File | Metodi d'istanza | Metodi di classe | di cui `@api private` |
| --- | --- | ---: | ---: | ---: |
| `Notcurses` | `notcurses.rb`, `version.rb`, `format.rb`, `context.rb` | 0 | 20 | 2 |
| `Notcurses::Context` | `context.rb` | 65 | 1 | 15 |
| `Notcurses::Capabilities` | `context.rb` | 10 | 0 | 0 |
| `Notcurses::Plane` | `plane.rb` | 139 | 7 | 14 |
| `Notcurses::FadeContext` | `plane.rb` | 9 | 0 | 0 |
| `Notcurses::Cell` | `cell.rb` | 13 | 2 | 3 |
| `Notcurses::Channel` | `channel.rb` | 22 | 4 | 0 |
| `Notcurses::Channels` | `channel.rb` | 39 | 2 | 0 |
| `Notcurses::Input` | `input.rb` | 29 | 1 | 0 |
| `Notcurses::Key` | `input.rb` | 0 | 6 | 0 |
| `Notcurses::Palette` | `palette.rb` | 13 | 1 | 0 |
| `Notcurses::Pixel` | `pixel.rb` | 16 | 2 | 0 |
| `Notcurses::Stats` | `stats.rb` | 41 | 1 | 1 |
| `Notcurses::Direct` | `direct.rb` | 61 | 1 | 1 |
| `Notcurses::Direct::Frame` | `direct.rb` | 6 | 0 | 0 |
| `Notcurses::Direct::Image` | `direct.rb` | 7 | 1 | 0 |
| `Notcurses::Visual` | `visual.rb` | 20 | 14 | 0 |
| `Notcurses::Visual::Geometry` | `visual.rb` | 22 | 0 | 0 |
| `Notcurses::Selector` | `widgets/selector.rb` | 12 | 1 | 0 |
| `Notcurses::MultiSelector` | `widgets/multiselector.rb` | 9 | 1 | 0 |
| `Notcurses::Menu` | `widgets/menu.rb` | 18 | 1 | 0 |
| `Notcurses::Menu::Item` | `widgets/menu.rb` | 4 | 0 | 0 |
| `Notcurses::Reader` | `widgets/reader.rb` | 15 | 1 | 0 |
| `Notcurses::Reel` | `widgets/reel.rb` | 17 | 1 | 0 |
| `Notcurses::Tablet` | `widgets/reel.rb` | 9 | 0 | 6 |
| `Notcurses::Tabbed` | `widgets/tabbed.rb` | 33 | 3 | 5 |
| `Notcurses::Tab` | `widgets/tabbed.rb` | 17 | 0 | 4 |
| `Notcurses::Tree` | `widgets/tree.rb` | 19 | 1 | 0 |
| `Notcurses::Plot` | `widgets/plot.rb` | 14 | 1 | 0 |
| `Notcurses::ProgBar` | `widgets/progbar.rb` | 9 | 1 | 0 |
| `Notcurses::FdPlane` | `fd_plane.rb` | 8 | 1 | 0 |
| `Notcurses::Subprocess` | `subprocess.rb` | 9 | 1 | 0 |
| `Notcurses::Widget` | `widgets/widget.rb` | 7 | 0 | 0 |
| `Notcurses::Resource` | `resource.rb` | 3 | 0 | 0 |
| `Notcurses::Resource::ClassMethods` | `resource.rb` | 1 | 0 | 0 |
| `Notcurses::Util` (helper interni) | `util.rb` | 0 | 38 | 0 |

- Classi di errore (`error.rb`, 11): `Error` e le sottoclassi `InitError`, `ClosedError`, `RenderError`,
  `PlaneError`, `CellError`, `VisualError`, `InputError`, `WidgetError`, `DirectError`, `ContextError`.
- Conteggio per riflessione (`public_instance_methods`, `singleton_methods`): comprende alias, `attr_reader` e i
  metodi che una classe riceve dai moduli del wrapper (`Resource`, `Widget`, `Resource::ClassMethods#open`).
  Contando ogni definizione una sola volta i metodi pubblici sono 726. La colonna `@api private` conta i metodi
  pubblici per Ruby ma interni al wrapper (registro del contesto, collegamenti tra classi).

### Copertura delle funzioni FFI (385 + 248)

| Voce | Funzioni |
| --- | ---: |
| Funzioni della Fase 1 | 633 (385 `attach_function`, 248 inline e macro) |
| Chiamate direttamente dal wrapper | 479 (75,7%): 319 `attach_function`, 160 inline |
| Escluse, ognuna con un motivo | 154 (24,3%) |
| - raggruppate in un metodo più generale o sostituite da un valore Ruby | 97 |
| - bug di 3.0.17: reimplementate in Ruby o non offerte | 41 |
| - non applicabili da Ruby (libc, `wchar_t`, macro di formato e di byte order, `userptr`) | 14 |
| - attesa con il GVL tenuto (`notcurses_get_blocking`, `ncdirect_get_blocking`) | 2 |

`spec/coverage_spec.rb` controlla l'elenco a ogni esecuzione: fallisce se una funzione non è né chiamata né esclusa,
se un'esclusione riguarda una funzione chiamata o inesistente, o se manca il motivo.

### Test

| Spec | Esempi |
| --- | ---: |
| `spec/notcurses/` (26 file, uno per classe o area) | 543 |
| `spec/integration/` (`lifecycle_spec.rb` 8, `visual_spec.rb` 12, `pty_spec.rb` 4) | 24 |
| `spec/coverage_spec.rb` | 3 |
| Totale Fase 2 | 570 |
| Fase 1 (`ffi_sanity_spec.rb`, `inline_reimpl_spec.rb`) | 257 |
| **Totale** | **827, 0 fallimenti (100% pass)** |

- Numeri dopo la review della Fase 2 e il fix trovato su Ruby 3.1 (prima: 802 esempi). Stesso risultato in ordine
  casuale (semi `1234`, `4242`, `7`; prima della modifica del 2026-10-26 anche `1`, `31337`, `2026`) e su Ruby
  3.1.7; durata circa 15 s su Ruby 4.0.7 e 35 s su Ruby 3.1.7.
- Esempi per file: plane 79, visual 73, direct 56, tabbed 29, context 28, reel 27, tree 27, plot 24, reader 24,
  menu 23, selector 19, fd_plane 17, channel 16, subprocess 15, progbar 14, multiselector 13, input 11, format 10,
  cell 9, palette 6, pixel 6, version 5, fade_context 4, stats 4, api 3, error 1.
- YARD: ogni metodo pubblico ha commento, `@param` per ogni parametro e `@return`; i metodi che possono sollevare
  hanno `@raise` (controlli euristici con script fuori dal progetto).

Come eseguire (dalla radice del progetto):

```sh
TERM=xterm-256color timeout -k 5 -s KILL 600 bundle exec rspec < /dev/null                          # tutte le spec
TERM=xterm-256color timeout -k 5 -s KILL 300 bundle exec rspec spec/notcurses/plane_spec.rb < /dev/null  # una classe
```

- Le spec aprono un `Context` su `/dev/null` con `termtype: 'xterm-256color'` e l'input scartato: non serve un
  terminale. Un solo contesto alla volta: ogni gruppo lo apre in `before(:all)` e lo chiude in `after(:all)`.
- `timeout -s KILL`: dopo una corruzione dell'heap Ruby può restare appeso invece di terminare.
- Le spec dei visual usano le fixture e richiedono notcurses compilato con ffmpeg; quelle dei tabbed usano nomi non
  ASCII e richiedono una locale UTF-8.

### Bug di notcurses 3.0.17 aggirati

Le tabelle complete, con il file C, la riga e il workaround, sono in `memory/fase2-wrapper-idiomatico.md` (102 righe:
contesto e input 11, piani 20, celle 3, Direct 14, Visual 10, Selector/MultiSelector/Menu/Reader/ProgBar 20,
Reel/Tree/Tabbed 14, Plot/FdPlane/Subprocess 10). Regola seguita: un bug che corrompe la memoria o va in crash si
previene prima della chiamata C, con un'eccezione chiara; un bug di semantica si aggira in Ruby se il workaround è
corto e sicuro, altrimenti si documenta nel YARD. I più importanti:

- **double free** in `notcurses_stop`/`drop_planes` con un reader vivo, e in `drop_planes` con pile di 2 o più piani:
  il contesto chiude prima i widget e distrugge da sé quelle pile;
- **scritture oltre il piano**: TAB nell'ultima colonna, EGC di larghezza zero a fine riga, `ncplane_resize` con
  `x_off < 0`, scorciatoie del menu da U+0800: rifiutati prima della chiamata;
- **letture oltre il buffer**: regioni dei visual con `begy`/`begx`, `ncreader_offer_input` con 4 codepoint,
  `ncvisual_from_rgb_loose`, il decoder sixel: dati copiati o controllati in Ruby;
- **crash e cicli infiniti** nei widget (`ncselector_delitem`, menu senza sezioni apribili, albero vuoto, tabbed senza
  tab, `ncreel`): chiamate evitate o widget riscritti in Ruby;
- **blocchi dell'interprete**: `ncfdplane_destroy` dentro un callback, `ncsubproc_destroy` con il figlio vivo,
  `notcurses_get` con il GVL: `FdPlane`, `Subprocess` e le attese dell'input sono in Ruby;
- **segnali**: `NCOPTION_NO_QUIT_SIGHANDLERS` e `NCOPTION_NO_WINCH_SIGHANDLER` per default (con i gestori di notcurses
  Ctrl-C termina Ruby senza `ensure` e SIGWINCH resta bloccato per sempre; dopo la review solo nel thread interno
  dell'init, vedi il punto 2 di "Cosa serve alla Fase 3").

Bug noti **non** aggirati (documentati nel YARD): dopo il primo scroll di un piano `duplicate`, i resize (anche
l'autogrow), `rotate_*`, il merge sulla destinazione e `FadeContext` permutano o perdono righe (`logrow`);
`ncvisual_from_palidx` non usa i colori della palette; `ncvisual_rotate` perde la prima riga e la prima colonna;
Backspace del reader non cancella la colonna 0; l'intestazione di `Tabbed` non segue il resize.

### API volutamente non wrappate

Le 154 funzioni escluse sono elencate con il motivo in `spec/coverage_spec.rb`. Per quasi tutte la funzionalità esiste
con un altro metodo (per esempio `Plane#putstr` al posto delle 27 varianti `put*`/`printf*`, `Cell` e `Channels` al
posto delle 39 funzioni `nccell_*`). Funzionalità di notcurses **non offerte**:

- render su buffer o su file (`ncpile_render_to_buffer`, `ncpile_render_to_file`): non funzionano in 3.0.17;
- cancellazione delle voci di un `Selector` (`ncselector_delitem`: segfault);
- fusione di una regione (`ncplane_mergedown`): solo la fusione completa (`Plane#merge_down`);
- `NCREADER_OPTION_HORSCROLL`, `tchannels` e `tattrword` del reader;
- `userptr` di piani, tablet e tab: i dati Ruby stanno negli oggetti Ruby;
- attesa bloccante nel C (`notcurses_get_blocking`, `ncdirect_get_blocking`): `get(timeout: nil)` attende in Ruby.

Reimplementate in Ruby (stessa funzionalità, senza i bug): `ncreel`/`nctablet` (`Reel`, `Tablet`), `ncfdplane`
(`FdPlane`), `ncsubproc` (`Subprocess`), `ncplane_puttext`, `ncplane_contents`, `ncplane_fadeout`/`fadein`/`pulse`,
`ncplane_resize_marginalized`/`placewithin`, `ncdirect_stream`, `ncdirect_printf_aligned`, `nctree_goto`,
`ncblit_rgb_packed`.

### Cosa serve alla Fase 3

1. **Ciclo degli eventi e focus.** Il wrapper non ha un dispatcher: `Context#get(timeout:)` restituisce un `Input` e
   ogni widget ha `offer_input(input) → true/false`. La Fase 3 deve scegliere chi ha il focus e a chi passare
   l'evento non consumato.
2. **Resize.** Con il default `no_winch_sighandler: true` serve `trap('WINCH')` più `Context#refresh`; i piani
   reagiscono con `resize:`/`set_resize_callback` (`:maximize`, `:realign`, `:marginalized`, `:placewithin` o un
   blocco). Limiti da gestire: l'intestazione di `Tabbed` non segue il resize; un `Reader` il cui piano cambia
   dimensioni solleva `WidgetError` e va ricreato. Dalla review l'init gira in un thread interno: con
   `no_winch_sighandler: false` notcurses blocca SIGWINCH e SIGCONT solo in quel thread, non nei thread di Ruby, ma
   l'evento `Key::RESIZE` arriva comunque solo insieme all'input successivo.
3. **Composizione.** I widget avanzati si possono scrivere sopra `Plane`, come `Reel` (Ruby puro: piani figli, `box`,
   `putstr`, callback di disegno). Utili: `create_child(margins:)`, gli allineamenti, le pile separate
   (`Context#create_pile`, `Plane#render_pile`), `FadeContext` per le animazioni, `Visual#stream` con un blocco.
   Vincoli dalla review: `break`, `return` e `throw` in un blocco chiamato dal C (disegno, resize, callback dei
   widget) diventano una `LocalJumpError`; `Plane.new` su un piano che ha già un `Plane` aperto solleva
   `ArgumentError` (un secondo wrapper si crea con `owned: false, tracked: false`).
4. **Thread.** Nessun lock interno: serve una politica (per esempio un solo thread UI, e i blocchi di `FdPlane` e
   `Subprocess` che passano i dati con una `Queue`). Su Ruby 3.1 un `kill` o un `Thread#raise` rimandato nel blocco
   di un `FdPlane` o di un `Subprocess` arriva anche a `String#grapheme_clusters`, quindi anche dentro i metodi di
   testo del wrapper (vedi "Ruby 3.1" nella sezione della review).
5. **Bug `logrow` dopo lo scroll** (non aggirato): evitare `duplicate`, resize e `rotate` sui piani che hanno fatto
   scroll, oppure ricrearli.
6. **GVL nella Fase 1 (risolto il 2026-10-26).** `notcurses_init`, `notcurses_core_init`, `ncdirect_init`,
   `ncdirect_core_init`, `ncdirect_cursor_yx`, `ncdirect_cursor_move_yx`, `ncdirect_readline`, `ncvisual_stream` e,
   dalla review, `ncdirect_render_image` e `ncdirect_raster_frame` (con il blitter `:pixel`, o un allineamento su un
   terminale senza `hpa`, chiedono la posizione del cursore) ora hanno `blocking: true`: durante le loro attese gli
   altri thread Ruby girano, e un terminale finto in un thread dello stesso processo (un pty nei test) può
   rispondere. Prove: in `spec/integration/pty_spec.rb` gli esempi "init, cursor_yx, move_cursor e readline ..." e
   "render_image, Frame#raster e stream con il blitter :pixel ...", e l'esempio sul GVL in
   `spec/notcurses/visual_spec.rb`, tutti falliti prima della modifica che provano. Da gestire nella Fase 3:
   durante quelle attese un altro thread può chiamare notcurses insieme al C (il YARD lo vieta per lo stesso
   contesto, e vieta ENV durante l'init).
7. **Test grafici.** Blitter a pixel (sixel, kitty), quadranti, sestanti e ottanti non si provano su `/dev/null`:
   serve un emulatore di terminale vero su un pty (per esempio in CI).
8. **Ruby 3.1 (provato il 2026-10-26).** La suite completa passa su Ruby 3.1.7 (827 esempi, 0 fallimenti, anche con
   i semi), dopo il fix di una corsa in `FdPlane#close` che 3.1 rende più frequente. Su questa macchina il build di
   Ruby 3.1.7 con gcc 16 serve `RUBY_CFLAGS='-std=gnu17'` (comandi nella sezione "Review della Fase 2 e Ruby 3.1").
   Il controllo su 3.1 è manuale: per non regredire serve rieseguirlo a ogni fase, anche con i semi, o una matrice
   CI 3.1–4.0.
9. **Pacchetto.** Non c'è ancora un gemspec né la documentazione YARD generata (la gem `yard` non è tra le
   dipendenze).
10. **Finding aperti della review (decisi dall'utente il 2026-10-26, da applicare nella Parte 0 della Fase 3).**
    `Visual.from_plane(y:, x:, rows:, cols:)` come `Plane#as_rgba`, con default `y: 0, x: 0` in entrambi (`nil` =
    cursore o fino al bordo; `-1` e `0` rifiutati); `rowstride:` anche nei 4 `Visual.blit_*` (oggi `linesize:`);
    `empty?` in `Reel` e `Tabbed`. `Direct` resta com'è (`print_aligned`, `hline(channels:)`).

## Review della Fase 2 e Ruby 3.1

- **Data:** 2026-10-26
- **Log dettagliato:** `memory/fase2-review.md` (metodo, tabella dei 22 finding con il fix o il motivo, decisioni,
  cambi dell'API, finding aperti, controlli)
- **Fix:** commit `553aa1d`. Per ogni finding confermato prima una spec, fallita sul codice di allora, poi il fix e la
  suite completa. I 3 finding sui soli test aggiungono spec che passano subito.
- **Metodo:** 12 agenti. 6 finder in sola lettura, uno per area (nucleo e valori; piani; Direct e Visual; Selector,
  MultiSelector, Menu, Reader, ProgBar, Plot; Reel, Tree, Tabbed e processi; API di tutte le classi), senza la
  memoria della Fase 2. 6 agenti di controllo, uno per area, hanno provato a smentire ogni finding con uno script,
  una spec o le righe del C.
- **Fase 1:** un solo cambio, autorizzato dall'utente: `blocking: true` su `ncdirect_render_image` e
  `ncdirect_raster_frame` (A3-02).
- Le dimensioni, la tabella delle classi e i numeri dei test della sezione "Fase 2" descrivono lo stato dopo la
  review.

### Finding per severità e verdetto

I 6 finder hanno trovato 27 finding, 22 dopo l'unione dei doppioni. I 21 finding confermati sono tutti corretti.

| Severità | CONFERMATO | PLAUSIBILE | SMENTITO | Totale |
| --- | ---: | ---: | ---: | ---: |
| alta | 4 | 0 | 0 | 4 |
| media | 6 | 0 | 0 | 6 |
| bassa | 11 | 0 | 1 | 12 |
| **Totale** | **21** | **0** | **1** | **22** |

Alta:

- **R2:** un Ctrl-C, o un'altra eccezione asincrona, durante l'init di `Context` o `Direct` lasciava un contesto C
  attivo e irraggiungibile. Ora l'init gira in un thread interno e il wrapper ferma il contesto prima di rilanciare.
- **R1:** `break`, `return` e `throw` in un blocco chiamato dal C saltavano i frame C con il `pilelock` di notcurses
  tenuto. Ora diventano una `LocalJumpError`.
- **A2-01:** `Plane.new` su un piano con un wrapper aperto sostituiva quel wrapper nel registro del contesto, e il GC
  poteva raccogliere il callback di resize ancora registrato nel C (SIGSEGV al resize del genitore). Ora `Plane.new`
  solleva `ArgumentError`.
- **A4-01:** Backspace, Ctrl+U e Ctrl+W del `Reader` su un glifo largo lasciavano nella vista la sua metà destra, e il
  glifo largo successivo in fondo alla riga scriveva oltre il framebuffer (abort al `free`). Ora il wrapper svuota la
  vista prima di quei tasti.

Media:

- **A2-02:** `raise_callback_errors!` dentro un callback rilanciava le eccezioni di un altro callback, e un resize
  `:marginalized` si fermava a metà.
- **A2-03:** `Plane#set_base` accettava TAB e `"\n"`; il TAB arrivava crudo al terminale.
- **A2-04:** `Plane#==` dava true fra un piano chiuso e il piano nuovo creato allo stesso indirizzo.
- **A3-02:** `Direct#render_image` e `Direct::Frame#raster`, con il blitter `:pixel` o un allineamento senza `hpa`,
  bloccavano per sempre un terminale servito da un thread Ruby.
- **A5-01:** in `Reel` un tablet senza bordi orizzontali e con 0 righe usate faceva fallire ogni ridisegno.
- **A6-05:** `Plane#merge_down`, `Tabbed.new` e `Plot.new(label_ticks: true)` sollevavano `ArgumentError` dove le
  altre classi usano `PlaneError` o `WidgetError`.

Bassa: 6 finding di nomi e firme (R3, A6-02, A6-03, A6-04, A6-06, A6-07: vedi "Cambi dell'API pubblica"); 2 di
errori (A1-03: una String non convertibile in UTF-8 dava `EncodingError`; A2-05: la cella `"\n"` che `ncplane_put`
lascia dopo un a capo ora si legge vuota); 3 di test (A1-05, A2-07, A5-03: spec nuove per `Context#get` e `#getvec`
con eventi veri, lo z-order delle varianti `family`, `merge_down`, `erase_region`, `greyscale`, `as_rgba`, `qrcode`,
`Tree#delete` a profondità 2).

Smentito: A3-04. `Direct#readline` restituisce nil sia a fine input sia per un errore, come dice il YARD. Il wrapper
non può distinguere i due casi: il NULL del C non porta `errno` e il campo `eof` è privato di `struct ncdirect`.

### Cambi dell'API pubblica

| Prima | Dopo | Finding |
| --- | --- | --- |
| `Plane#at(y = nil, x = nil)` | `at(y: nil, x: nil)` | R3 |
| `Plane#set_base(egc = ' ', styles:, channels:)` | `set_base(egc: ' ', styles:, channels:)`; TAB e `"\n"` rifiutati | R3, A2-03 |
| `Plane#scrollup(lines = 1)` | `scrollup(lines: 1)` | R3 |
| `Plane#set_resize_callback(callback = nil, &block)` | `set_resize_callback(callback: nil, &block)` | R3 |
| `Cell.new(egc = ' ', ...)` | `Cell.new(egc: ' ', ...)` | R3 |
| `Channel.new(value = 0)`, `Channels.new(value = 0)`, `Pixel.new(value = 0)` | `new(value: 0)` | R3 |
| `Context#cursor_enable(y = 0, x = 0)` | `cursor_enable(y: 0, x: 0)` | R3 |
| `Context#mice_enable(events = :all)` | `mice_enable(events: :all)` | R3 |
| `Direct#cursor_up/down/left/right(count = 1)` | `cursor_*(count: 1)` | R3 |
| `Direct#set_styles(styles)` | `Direct#styles=(styles)` | A6-02 |
| `Direct#on_styles(styles)`, `off_styles(styles)` | `on_styles(*styles)`, `off_styles(*styles)` | A6-02 |
| `Direct#box(..., style:, omit:)` | `box(..., set:, hide:)` | A6-02 |
| `Direct#cursor_move(y: nil, x: nil)` | `Direct#move_cursor(y: nil, x: nil)` | A6-02 |
| `Plane#move_cursor(y, x)` con `-1` = asse invariato | `nil` = asse invariato; `-1` solleva `PlaneError` | A6-02 |
| — | `Plane#cursor_yx` (alias di `cursor`) | A6-02 |
| `Context.new(margins: String)` | anche `margins: [alto, destra, basso, sinistra]` | A6-03 |
| `Plot.new(grid:)` | `Plot.new(blitter:)` | A6-03 |
| `Visual` (`blit`, `geometry`, `blit_*`, `create_plane`, ...) `nodegrade:`, `nointerpolate:` | `no_degrade:`, `no_interpolate:` | A6-03 |
| `Plane#as_rgba(y: -1, x: -1, rows: 0, cols: 0)` | `as_rgba(y: nil, x: nil, rows: nil, cols: nil)`; `-1` e `0` sollevano `ArgumentError` | A6-03 |
| `Selector`, `MultiSelector`: `opchannels:`, `descchannels:`, `titlechannels:`, `footchannels:`, `boxchannels:` | `op_channels:`, `desc_channels:`, `title_channels:`, `foot_channels:`, `box_channels:` | A6-04 |
| `Menu`: `headerchannels:`, `sectionchannels:` | `header_channels:`, `section_channels:` | A6-04 |
| `ProgBar`: `ulchannel:`, `urchannel:`, `blchannel:`, `brchannel:` | `ul_channel:`, `ur_channel:`, `bl_channel:`, `br_channel:` | A6-04 |
| `Tabbed#select_next`, `#select_prev` | `Tabbed#next`, `#prev`; nuovo `Tabbed#size` | A6-06 |
| `Direct::Image#geom` → `Hash`, `Direct::Image::GEOM_FIELDS` | `Direct::Image#geometry` → `Visual::Geometry` | A6-07 |
| `Plane#merge_down`: `ArgumentError` per `dst` stesso o in un'altra pila | `PlaneError` | A6-05 |
| `Tabbed.new` (meno di 2 righe), `Plot.new(label_ticks: true)` (7 colonne o meno): `ArgumentError` | `WidgetError` | A6-05 |
| `Plane.new` su un piano con un wrapper aperto, tracciato o posseduto | `ArgumentError` | A2-01 |
| `String` non convertibile in UTF-8: `EncodingError` | `ArgumentError` | A1-03 |

I nomi vecchi sono rimossi, senza alias di compatibilità: la gem non ha ancora utenti.

### Finding aperti

PLAUSIBILI: parti di A6-02 e A6-03 con due letture valide, non cambiate.

- `Plane#hline(from:, to:)` contro `Direct#hline(channels:, to:)`: in `Plane` `from:` sono i colori della prima cella
  della sfumatura (nil = i colori della cella), in `Direct` `channels:` è il nome usato in tutta la classe per i
  colori di scrittura.
- `Direct#print_aligned` contro `Plane#putstr(align:)`: `Direct#putstr` rispecchia `ncdirect_putstr`, che non ha
  allineamento; `Plane#putstr` ha assorbito `ncplane_putstr_aligned`.
- In `Visual` `rowstride:` (5 metodi `from_*`) contro `linesize:` (4 metodi `blit_*`): i nomi seguono il C, ma il
  concetto è lo stesso.

Emersi dal controllo, fuori dai finding confermati (serve una decisione):

- `Visual.from_plane(begy:, begx:, leny:, lenx:)` usa ancora i valori speciali del C (`-1` = posizione del
  cursore, `0` = fino al bordo) e nomi diversi da `Plane#as_rgba(y:, x:, rows:, cols:)`, che avvolge una funzione C
  con gli stessi parametri: è la stessa correzione fatta per `as_rgba`.
- `empty?` esiste in `Tree` ma non in `Reel` e `Tabbed`.

Limiti residui di R2:

- un secondo Ctrl-C, mentre il wrapper ferma un contesto il cui terminale non risponde, lascia il registro del
  contesto occupato (l'oggetto resta chiuso, nessun crash);
- `Thread#kill` del thread chiamante durante l'init non passa dal `rescue`;
- il thread interno dell'init ha `report_on_exception` attivo (il thread non solleva eccezioni).

Note dei verificatori, da controllare:

- su un piano che scorre, un testo largo quanto la riga e seguito da `"\n"` lascia il cursore due righe sotto
  (`notcurses.c:1888-1890` e `1903-1904`), contro il YARD di `Plane#putstr`;
- la causa radice di A4-01 (`cellcmp_and_dupfar` non confronta la width, `internal.h:1512-1519`) può toccare altre
  copie fra piani: nessun altro caso trovato.

### Controlli

- Suite completa su Ruby 4.0.7: 826 esempi, 0 fallimenti, anche con i semi `1234`, `4242` e `7`.
- `ruby -w -Ilib -e 'require "notcurses"'`: nessun warning, su Ruby 4.0.7 e 3.1.7.
- `spec/coverage_spec.rb` passa: la review non aggiunge e non toglie chiamate FFI (477 chiamate, 154 escluse).
- YARD: 0 problemi con `yard_check.rb`; `yard_raise_check.rb` controlla 605 metodi e segnala solo il falso positivo
  noto `input.rb:300 to_ffi`, presente anche prima della review.

### Ruby 3.1

- **Risultato:** la suite completa passa su Ruby 3.1.7: 827 esempi, 0 fallimenti, anche con i semi `1234`, `4242` e
  `7` (circa 35 s). `ruby -w` non dà warning. Prima dei fix della review passava (802 esempi, 0 fallimenti, anche
  con i semi); dopo i fix (826 esempi) passava in ordine normale, ma il seme `4242` ha trovato la corsa R31-01.
- **R31-01** (media, CONFERMATO, corretto): `FdPlane#close` segnava l'oggetto come chiuso prima di aspettare il
  blocco in corso, quindi il blocco riceveva `ClosedError` da `f.plane` e `close` (o `Context#close`) lo
  rilanciava. Il YARD promette invece che `close` aspetta la fine del blocco. È un bug della Fase 2, non della
  review: l'esempio "Context#close chiude un FdPlane in lettura prima di notcurses_stop" falliva 2 volte su 40 su
  3.1.7 e 0 su 40 su 4.0.7. Ora un flag interno ferma la lettura e l'oggetto diventa chiuso dopo il `join`;
  `Subprocess` eredita il fix. La spec nuova fallisce sempre sul codice vecchio, su 3.1.7 e 4.0.7; dopo il fix
  l'esempio originale passa 80 volte su 80 su 3.1.7.
- **Differenza di Ruby 3.1:** `String#grapheme_clusters` e `each_grapheme_cluster` consegnano le interruzioni
  rimandate da `Thread.handle_interrupt(Object => :on_blocking)`, su 4.0.7 no (nelle prove `scan` e `match?` no in
  entrambe). Su 3.1 il blocco di un `FdPlane` o di un `Subprocess` può quindi essere interrotto anche dentro un
  metodo di testo del wrapper (per esempio `Plane#putstr`): lo dice il YARD di `FdPlane`.
- **Build:** mise 2026.10.17 compila Ruby 3.1.7 con ruby-build, perché non trova un binario precompilato. Con
  gcc 16.2.1 il build fallisce in `enc/euc_jp.o`: da gcc 15 lo standard C di default è C23, dove `f()` vale
  `f(void)`, e `enc/jis/props.h:72` dichiara `onig_jis_property()` senza parametri. Con `RUBY_CFLAGS='-std=gnu17'`
  il build riesce (circa 3 minuti).
- **Versioni:** `ruby 3.1.7p261`, RubyGems 3.3.27, Bundler 2.3.27, ffi 1.17.4, rspec 3.13.2 (rspec-core 3.13.6).
- **Gemfile:** il `Gemfile.lock` del progetto ha `BUNDLED WITH 4.0.22`, e Bundler 4 richiede Ruby >= 3.2. Su 3.1 usa
  una copia del `Gemfile` fuori dal progetto, con `BUNDLE_GEMFILE`; `Gemfile` e `Gemfile.lock` del progetto non
  cambiano.

Come eseguire, dalla radice del progetto (`S` è una cartella temporanea fuori dal progetto):

```sh
mkdir -p "$S/ruby-build-tmp" "$S/gemfile31" && cp Gemfile "$S/gemfile31/Gemfile"
TMPDIR="$S/ruby-build-tmp" RUBY_CFLAGS='-std=gnu17' mise install ruby@3.1.7 > "$S/ruby31-install.log" 2>&1; echo "exit $?"
MISE_EXEC_AUTO_INSTALL=false BUNDLE_GEMFILE="$S/gemfile31/Gemfile" mise exec ruby@3.1.7 -- bundle install --quiet
MISE_EXEC_AUTO_INSTALL=false BUNDLE_GEMFILE="$S/gemfile31/Gemfile" TERM=xterm-256color \
  mise exec ruby@3.1.7 -- timeout -k 5 -s KILL 600 bundle exec rspec < /dev/null
```

- `MISE_EXEC_AUTO_INSTALL=false` serve in ogni `mise exec`: se la versione non è installata, mise avvia il build da
  solo.
- `TMPDIR` nella cartella temporanea: ruby-build scrive log e cartelle di build di circa 340 MB.
- `mise exec` non cambia la versione globale di Ruby (4.0.7 in `~/.config/mise/config.toml`).

## Fase 3 — ciclo degli eventi, focus e widget composti

- **Data di completamento:** 2026-10-26
- **Design:** `memory/fase3-design.md`, approvato dall'utente (scelte D1–D7 nella sezione 9).
- **Log dettagliato:** `memory/fase3-ui.md` (Parte 0, ricerca del design, decisioni prese durante l'implementazione,
  problemi, bug di notcurses, controlli).
- **Commit:** `e710a92` (Parte 0); `6c55106`, `aab16b6`, `db19dbc`, `2534b02`, `692c455` (Parte 2, uno per area);
  poi la documentazione.
- **Fase 1:** nessun cambio. `git diff 5dbf71e -- lib/notcurses/ffi lib/notcurses/ffi.rb Gemfile Gemfile.lock` è
  vuoto.
- **Dimensioni:** 11 file nuovi in `lib/` (2 107 righe), `examples/demo.rb` (58 righe), 10 file di spec nuovi (1 405
  righe). Il framework usa solo l'API pubblica della Fase 2: nessuna chiamata FFI diretta.
- **Uso:** `require 'notcurses'`, poi `app = Notcurses::UI::App.new(nc)` dentro `Notcurses::Context.open`, i
  componenti sotto `app.root` e `app.run` (restituisce `:stop`, `:eof` o `:interrupt`). Prova manuale su un terminale
  vero: `ruby -Ilib examples/demo.rb`.

### File

| File | Righe | Contenuto |
| --- | ---: | --- |
| `lib/notcurses/ui.rb` | 26 | modulo `Notcurses::UI`, `require` dei file sotto (richiesto in fondo a `lib/notcurses.rb`) |
| `lib/notcurses/ui/event_loop.rb` | 516 | `EventLoop` (ciclo, `post`, `stop`, timer, `on_key`, `on_input`, `on_resize`), `Timer` |
| `lib/notcurses/ui/component.rb` | 398 | modulo `Component` (protocollo dei componenti), helper privato `Text`, `FOCUSED_CHANNELS`, `FIELD_CHANNELS` |
| `lib/notcurses/ui/container.rb` | 164 | `Container`: figli in righe o colonne, `size:` e `weight:`, bordo e titolo |
| `lib/notcurses/ui/app.rb` | 364 | `App < EventLoop`: radice, focus, consegna degli eventi, mouse, dialoghi, cursore |
| `lib/notcurses/ui/label.rb` | 69 | `Label` |
| `lib/notcurses/ui/button.rb` | 90 | `Button` |
| `lib/notcurses/ui/text_input.rb` | 137 | `TextInput` (in Ruby, non sopra `Reader`) |
| `lib/notcurses/ui/list_view.rb` | 142 | `ListView` (in Ruby, non sopra `Selector`) |
| `lib/notcurses/ui/log_view.rb` | 96 | `LogView`: righe in memoria, byte grezzi da `FdPlane` e `Subprocess` |
| `lib/notcurses/ui/dialog.rb` | 105 | `Dialog < Container`: finestra modale |
| `examples/demo.rb` | 58 | prova manuale: modulo, elenco, log di un processo figlio, orologio, dialogo di conferma |

### Classi e moduli

| Classe o modulo | File | Metodi d'istanza | Metodi di classe | di cui `@api private` |
| --- | --- | ---: | ---: | ---: |
| `Notcurses::UI::EventLoop` | `ui/event_loop.rb` | 12 | 0 | 1 |
| `Notcurses::UI::Timer` | `ui/event_loop.rb` | 8 | 0 | 4 |
| `Notcurses::UI::App` | `ui/app.rb` | 24 | 0 | 5 |
| `Notcurses::UI::Component` (modulo) | `ui/component.rb` | 18 | 0 | 2 |
| `Notcurses::UI::Container` | `ui/container.rb` | 24 | 0 | 4 |
| `Notcurses::UI::Label` | `ui/label.rb` | 21 | 0 | 2 |
| `Notcurses::UI::Button` | `ui/button.rb` | 20 | 0 | 2 |
| `Notcurses::UI::TextInput` | `ui/text_input.rb` | 21 | 0 | 2 |
| `Notcurses::UI::ListView` | `ui/list_view.rb` | 23 | 0 | 2 |
| `Notcurses::UI::LogView` | `ui/log_view.rb` | 22 | 0 | 2 |
| `Notcurses::UI::Dialog` | `ui/dialog.rb` | 27 | 0 | 5 |
| `Notcurses::UI::Text` (costante privata, helper interni) | `ui/component.rb` | 0 | 6 | 6 |

- Conteggio per riflessione, come nella Fase 2: comprende gli `attr_reader` e i metodi ricevuti da `Resource`,
  `Component`, `Container` ed `EventLoop`. Contando ogni definizione una sola volta i metodi pubblici sono 91, di cui
  20 `@api private` (collegamenti fra `App`, contenitori e componenti, la lista dei timer, le 6 funzioni di `Text`).
- Costanti pubbliche: `FOCUSED_CHANNELS`, `FIELD_CHANNELS`, `Container::DIRECTIONS`, `Label::ALIGNS`.
- Riassunto del funzionamento (i dettagli sono nel YARD di ogni classe e nel design):
  - un giro di `run`: `IO.select` sul fd di `Context#inputready_fd` e su un pipe di risveglio, con il timeout del
    primo timer; poi il resize segnalato, tutto l'input pronto, i blocchi di `post`, i timer scaduti e al massimo un
    render (dal lotto 3 delle issue in Backlog `run` attende sul pipe del thread di input del contesto, non sul fd
    di notcurses);
  - solo il thread del ciclo chiama notcurses (dal lotto 3 delle issue in Backlog anche il thread di input, che
    durante `run` legge i tasti con `notcurses_getvec`); `post` e `stop` funzionano da qualsiasi thread e dai `trap`
    (`Queue` e un byte sul pipe, niente `Mutex`);
  - consegna in `App`: componente con il focus (o sotto il mouse), risalita ai contenitori fino alla radice attiva,
    poi `on_key`, Tab e Shift+Tab, `on_input`;
  - un componente ridisegna tutto dal proprio stato a ogni layout: nessun widget scorre i propri piani o copia celle
    fra piani, quindi il resize non incontra il bug `logrow` né la causa di A4-01.

### Cambi all'API della Fase 2

| Prima | Dopo | Origine |
| --- | --- | --- |
| `Visual.from_plane(plane, blitter:, begy:, begx:, leny:, lenx:)`, con i valori speciali del C (`-1`, `0`) | `from_plane(plane, blitter:, y: 0, x: 0, rows: nil, cols: nil)`: `nil` = cursore o «fino al bordo»; `-1` e `0` sollevano `ArgumentError` | Parte 0, decisione dell'utente |
| `Plane#as_rgba(blitter, y: nil, x: nil, rows: nil, cols: nil)` | `as_rgba(blitter, y: 0, x: 0, rows: nil, cols: nil)`: senza argomenti converte tutto il piano | Parte 0 |
| `Visual.blit_rgba`, `blit_bgrx`, `blit_rgb_loose`, `blit_rgb_packed` con `linesize:` | `rowstride:`, come i metodi `from_*` | Parte 0 |
| — | `Reel#empty?`, `Tabbed#empty?`, come `Tree#empty?` | Parte 0 |
| `Plane#putstr`: un `"\n"` dopo una riga piena lasciava una riga vuota (due a capo nel C) | va a capo una volta sola | Parte 0, nota della review (bug di 3.0.17, `notcurses.c:1888-1890` e `1903-1904`) |
| — | `Context#drain_input?` e `Context#no_winch_sighandler?` | design, D6 |

I nomi vecchi sono rimossi, senza alias. Dentro il wrapper la regione di `from_plane` e `as_rgba` passa da un helper
comune (`Util.c_region`); la copertura FFI non cambia (477 chiamate, 154 escluse).

### Test

| Spec | Esempi |
| --- | ---: |
| `spec/notcurses/ui/` (9 file) | 76 |
| `spec/integration/ui_pty_spec.rb` | 2 |
| Totale Fase 3 (spec nuove) | 78 |
| Fase 2 (`spec/notcurses/` 26 file, `spec/integration/` 3 file, `spec/coverage_spec.rb`), con la Parte 0 e i due predicati | 575 |
| Fase 1 (`ffi_sanity_spec.rb`, `inline_reimpl_spec.rb`) | 257 |
| **Totale** | **910, 0 fallimenti (100% pass)** |

- Esempi per file della Fase 3: `event_loop` 18, `app` 15, `dialog` 9, `container` 8, `label` 6, `log_view` 6,
  `list_view` 5, `text_input` 5, `button` 4; integrazione 2. Spec della Fase 2 con un esempio nuovo: `plane` 80,
  `visual` 74, `tabbed` 30, `reel` 28 (Parte 0) e `context` 29 (i due predicati); gli altri file invariati.
- Stesso risultato in ordine normale e con `--order rand:1234`, `rand:4242`, `rand:7`, su Ruby 4.0.7 e 3.1.7.
- Le spec della Fase 3 usano eventi sintetici (`Input.synthesize`, anche per il mouse) su un contesto su `/dev/null`.
  `ui_pty_spec.rb` esegue il ciclo completo in un processo figlio: il pty diventa il terminale di controllo
  (`setsid` e `TIOCSCTTY`, solo Linux: altrove l'esempio viene saltato), un thread scrive tasti veri (testo, Tab,
  Invio, clic SGR, Ctrl+X), il cambio di `winsize` manda SIGWINCH e `"\x03"` manda SIGINT dal kernel; i dati di un
  `FdPlane` e di un `Subprocess` arrivano a un `LogView` con `post`. Un secondo figlio controlla `:eof`.
- Comandi: quelli della Fase 2 e della sezione "Ruby 3.1".

### Bug e limiti di notcurses 3.0.17 trovati nella Fase 3

| Bug o limite | Dove | Gestione |
| --- | --- | --- |
| `notcurses_get` svuota tutto il pipe di prontezza, anche con altri eventi in coda | `in.c:2751-2757` | il ciclo legge fino al primo `nil` a ogni risveglio; il primo giro di ogni `run` non attende, così legge subito gli eventi lasciati in coda dal run precedente (uscito con `stop` o con un'eccezione) |
| A fine input il pipe resta leggibile per sempre; con `drain_input: true` `get` solleva sempre `InputError` | `in.c:2610-2616`, `2702-2710` | `Key::EOF` ferma il ciclo (`:eof`); un contesto che scarta l'input non viene ascoltato (`Context#drain_input?`) |
| `NCKEY_RESIZE` entra in coda solo insieme ad altro input | `in.c:2439-2445` | di default `trap('WINCH')` durante `run`; dopo ogni render un cambio di dimensioni non segnalato si applica al giro dopo |
| `"\n"` dopo una riga piena: due a capo | `notcurses.c:1888-1890`, `1903-1904` | corretto nella Parte 0 |
| Il modo del terminale toglie solo ECHO, ICANON e ICRNL: Ctrl+S e Ctrl+Q restano il controllo di flusso (IXON), Ctrl+C, Ctrl+Z e Ctrl+\ restano segnali (ISIG) | `termdesc.c:1631-1637` | non arrivano come tasti: lo dice il YARD di `EventLoop#on_key`; la demo usa Ctrl+X (trovato con la demo) |
| In `read_input_nblock` la condizione su `errno` non è mai vera dove `EAGAIN == EWOULDBLOCK` (Linux): ogni errore di `read`, anche EIO, segna la fine dell'input | `in.c:2180-2190` | letto nel C, non riprodotto: per esempio un pty il cui master si chiude dà `Key::EOF`, e `run` restituisce `:eof` |
| notcurses divide il keycap `"1️⃣"` diversamente da Ruby e ne scrive U+20E3 come carattere di larghezza zero | `nccell_load` | il controllo del testo dei widget non lo vede; il disegno lo scrive come `"?"` invece di sollevare |
| Nessuno stile «reverse»; senza tty `cursor_disable` e `mice_enable` sollevano `ContextError` | — | il focus si mostra con i colori; `App` ignora l'errore di `cursor_disable` |
| Con il protocollo tastiera kitty notcurses alza SIGINT, SIGSTOP o SIGQUIT per Ctrl+C, Ctrl+Z e Ctrl+\ solo se i modificatori sono Ctrl da solo: con CapsLock o NumLock (kitty li aggiunge) non alza niente e consegna il tasto; con Ctrl da solo alza il segnale e mette anche l'evento in coda. Lo alza anche per la ripetizione e il rilascio (notcurses chiede il flag kitty 2, i tipi di evento), e lo decide da un flag privato (`ictx->linesigs`) che `stty` non cambia: lo cambiano solo `notcurses_linesigs_disable` ed `enable`, che scrivono anche ISIG, e con `ttyfd < 0` nemmeno loro | `in.c:506-516`, `in.c:2840-2918`, `termdesc.c:390` | all'avvio `EventLoop#run` spegne il flag con `notcurses_linesigs_disable` e rimette ISIG com'era con `tcsetattr` (`Context#isig_enable`); con ISIG attivo alza lui lo stesso segnale al proprio processo, una volta per pressione e dopo aver letto il tasto, e non consegna questi tasti (ICH-280, ICH-454, ICH-456, ICH-455). Dopo `run` il flag resta spento. Con `drain_input` `run` non legge i tasti e lascia i segnali a notcurses, come su `master` (con `no_linesigs` spegne il flag e lo riaccende alla fine con `linesigs_enable`); senza terminale il flag resta acceso: limiti scritti nello YARD |
| Con la coda di input piena (8192 eventi) notcurses scarta il tasto nuovo: per l'input da terminale non frena chi scrive (`process_bulk` frena solo l'input rediretto) | `in.c:523-527`, `in.c:2370-2395` | il thread di input di `EventLoop#run` svuota la coda e legge solo l'id degli eventi che non sono tasti di segnale; con la CPU occupata anche il Ctrl+C dopo 10000 tasti si è perso, di rado: limiti nello YARD di `run` e su ICH-536 (lotto 3 delle issue in Backlog) |
| Una sequenza CSI-u di kitty spezzata fra due letture fa fallire `assert(val > 0)` e ferma il processo | `in.c:803` (`kitty_kbd_txt`) | non aggirato; succede anche con un ciclo di `Context#get` senza `EventLoop` (riprodotto dalla review del lotto 3 delle issue in Backlog) |
| Una sequenza escape spezzata fra due letture fa fallire `assert(ictx->amata.used <= buflen)` e ferma il processo | `in.c:2229` (`process_escape`) | non aggirato; succede anche su `master` (riprodotto dalla review del lotto 3 delle issue in Backlog) |
| Un carattere UTF-8 di più byte spezzato fra due letture blocca il thread di input: `process_input` restituisce 0 (servono altri byte), ma `process_melange` esce dal ciclo solo con un valore negativo e gira per sempre sugli stessi byte. `get` non riceve più eventi e `notcurses_stop` resta in `pthread_join`, perché il ciclo non ha punti di cancellazione. Succede quando notcurses legge stdin senza un terminale separato: stdin sul terminale (un incolla di 2731 caratteri CJK su un pty si ferma dopo 682) o rediretto senza `/dev/tty` (il repro di ICH-463 si ferma a 2730 su 2731, anche con `Direct#get` ed `EventLoop#run`). Con stdin rediretto e `/dev/tty`, `process_bulk` esce già su `<= 0` | `in.c:2335-2338` (`process_input`), `in.c:2427` (`process_melange`), `in.c:2662` | non aggirato: limite nello YARD di `Context#get`, `Direct#get` ed `EventLoop#run`, nel README e nel CHANGELOG. Correzione di una riga (`consumed <= 0`) proposta upstream: issue [#2947](https://github.com/dankamongmen/notcurses/issues/2947), PR [#2954](https://github.com/dankamongmen/notcurses/pull/2954). ICH-463 è in Blocked fino a una versione corretta di notcurses |
| Il report SGR del movimento con un tasto premuto (bit 32) diventa una nuova pressione dello stesso tasto: `mouse_click` mette `NCTYPE_PRESS` per ogni report `M` e `id = NCKEY_BUTTON1 + mods % 4` | `in.c:610-620` | `App` tratta come drag una pressione di BUTTON1..3 con lo stesso tasto già premuto: niente focus, niente componenti, solo `on_input`; un drag non ripete il clic di un `Button` (ICH-283) |
| Sulla console Linux il mouse viene da gpm: ogni evento (pressione, rilascio, drag, qualsiasi tasto) diventa `\e[<0;x;yM`, cioè una pressione di BUTTON1, e un rilascio non arriva mai | `mice.c:4-19`, `gpm.c:31` | `App` non applica la regola del drag quando `Context#detected_terminal` è `"FBcon"` o `"VT"`: lì ogni pressione è un clic (trovato nella review del lotto 8) |

### Controlli

- Suite completa: 910 esempi, 0 fallimenti su Ruby 4.0.7 e 3.1.7, in ordine normale e con i semi `1234`, `4242`, `7`
  (8 esecuzioni sul commit `692c455`; circa 17 s su 4.0.7 e 40 s su 3.1.7).
- `ruby -w -Ilib -e 'require "notcurses"'`: nessun warning, su Ruby 4.0.7 e 3.1.7.
- `spec/coverage_spec.rb` e `spec/notcurses/api_spec.rb` passano; `api_spec.rb` controlla per riflessione anche le
  classi di `Notcurses::UI`.
- YARD: 0 problemi con `yard_check.rb`; `yard_raise_check.rb` segnala solo il falso positivo noto `input.rb:300
  to_ffi`.
- `git diff 5dbf71e -- lib/notcurses/ffi lib/notcurses/ffi.rb Gemfile Gemfile.lock`: nessun cambio.
- `examples/demo.rb` provata in un pty (`PTY.spawn`) con tasti simulati: il saluto compare nel log, Ctrl+X apre la
  conferma, Invio su «Sì» ferma l'App ed esce con `Uscita: stop`.

### Cosa serve alla fase successiva

1. **Pacchetto e CI** (fuori scope finora, punti 7, 8 e 9 di "Cosa serve alla Fase 3"): gemspec, documentazione YARD
   generata, matrice CI Ruby 3.1–4.0 con un emulatore di terminale vero per i test grafici. Il controllo su Ruby
   3.1 resta manuale.
2. **Widget esclusi dal design** (sezione 8): `TextArea` a più righe, temi, scorciatoie per contenitore, drag del
   mouse, incolla con bracketed paste. I widget C della Fase 2 si ospitano in un componente dell'utente e vanno
   ricreati in `on_resize` (`Tabbed`, `Reader`).
3. **Tasti consumati dal terminale.** Risolto da ICH-229 (sezione in fondo): `run(no_flow_control: true,
   no_linesigs: true)`.
4. **Limiti del framework.** Una riga senza `"\n"` in un `LogView` cresce senza limite; la coda di `post` non ha
   limite; ogni figlio aggiunto rifà il layout dei fratelli (costo quadratico alla costruzione, trascurabile per un
   modulo, da rivedere con migliaia di componenti: un elenco lungo va in un `ListView`).
5. **Controllo esatto del testo.** Per rifiutare alla creazione anche i grapheme che notcurses divide diversamente da
   Ruby serve un cambio dell'API della Fase 2: un controllo pubblico (o `@api private`) basato su
   `Plane#zero_width_egc!`.

## ICH-229 — tasti di controllo (IXON e ISIG)

- **Data:** 2026-10-27. **Issue:** ICH-229 su Linear. **PR:** https://github.com/ichelema/notcursesruby/pull/1
  (branch `improvments/ICH-229-opus`).
- **Commit:** `afb91c8` (Fase 1 e `Context`), `65cd277` (UI), `0a837d5` (correzioni della review), poi questa
  documentazione.
- **Uso:** `app.run(no_flow_control: true)` fa arrivare Ctrl+S e Ctrl+Q a `on_key`; `app.run(no_linesigs: true)` fa
  arrivare Ctrl+C, Ctrl+Z e Ctrl+\, e Ctrl-C non ferma più il ciclo (serve un tasto di uscita). Le due opzioni valgono
  `false` di default: senza opzioni il comportamento non cambia. Stesse opzioni in `EventLoop#run`.

### Scelte

| Scelta | Motivo |
| --- | --- |
| IXON con `tcgetattr`/`tcsetattr` della libc (cambio della Fase 1 approvato dall'utente) | notcurses non ha una funzione per IXON. `stty -ixon` avvia un processo (circa 300 volte più lento, dipende dal `PATH`); `IO#ioctl` usa codici diversi per architettura; `IO#raw` cambia anche altri flag |
| Terminale: stdin se è un tty, altrimenti `/dev/tty` | è il terminale da cui notcurses legge i tasti (`init_inputlayer`, `in.c:1967,1974`) |
| Ripristino dei soli flag tolti da `run`, solo se erano attivi, mai con il contesto chiuso | uno snapshot di tutto lo stato annullerebbe `linesigs_enable` e, dopo `notcurses_stop`, rimetterebbe ECHO e ICANON spenti |
| ISIG letto con `tcgetattr` (`Context#linesigs?`) | `run` non riaccende ISIG se era già spento, anche dopo `stty -isig` (finding 1 della review) |
| Un errore del ripristino non sostituisce l'eccezione di un handler | finding 2 della review |

### Cambi all'API

| Prima | Dopo |
| --- | --- |
| `EventLoop#run`, `App#run` senza argomenti | `run(no_flow_control: false, no_linesigs: false)` |
| — | `Context#flow_control_disable`, `#flow_control_enable` e `#linesigs?`, `@api private`: li usa solo la UI |
| — | Fase 1: `tcgetattr`, `tcsetattr`, `Termios`, `:tcflag_t`, `IXON`, `ISIG`, `TCSANOW` |

`Gemfile` e `Gemfile.lock` non cambiano.

### Test

- `spec/integration/ui_pty_spec.rb`: otto `run` su un pty che è il terminale di controllo (`setsid` e `TIOCSCTTY`):
  opzioni accese, spente, una sola alla volta, eccezione in un handler, ISIG già spento (con `linesigs_disable` e con
  `stty -isig`), IXON già spento. Ogni `run` controlla che `stty -g` dopo sia uguale a prima.
- `spec/notcurses/ui/event_loop_spec.rb`: `TypeError` per le opzioni; con stub, errore del ripristino durante
  un'eccezione e ISIG già spento. `spec/notcurses/context_spec.rb`: `ClosedError` dei tre metodi nuovi.
- Suite completa con `--order rand:1234`: 914 esempi, 0 fallimenti su Ruby 4.0.7 e su 3.1.7. Quattro mutazioni (i due
  metodi di IXON resi inerti, `linesigs?` sempre vero, il vecchio ripristino) fanno fallire i test nuovi.
- In un git worktree il sottomodulo `notcurses` non è inizializzato: le spec delle immagini (`direct_spec.rb`,
  `pty_spec.rb` con il blitter `:pixel`) cercano `notcurses/data`. Provate con un link temporaneo al checkout
  principale. Non inizializzare il sottomodulo nel worktree: `git worktree remove` rifiuta i worktree con sottomoduli.
- Review indipendente: «approvabile con riserve»; i due finding sono corretti in `0a837d5`.
- YARD: `yard doc` con lo `yard` 0.9.45 installato fuori dal `Gemfile` dà 0 avvisi e nessun oggetto nuovo non
  documentato.

### Limiti

- I valori per macOS, BSD e Linux powerpc/alpha sono controllati solo sulle intestazioni. Su un sistema senza valori
  noti (per esempio Solaris) le due opzioni sollevano `ContextError`.
- Con stdin e output su due tty diversi, `run` legge IXON e ISIG sul terminale di input, mentre notcurses applica ISIG
  a quello di output.
- Con stdin che non è un tty, notcurses 3.0.17 (build con gli assert) abortisce a ogni tasto letto da `/dev/tty`
  (`in.c:2308`), anche senza le opzioni: il ramo `/dev/tty` di `Context#flow_control_disable` oggi non ha un caso
  d'uso.

## Fase 4 — pacchetto, YARD generato, coverage e CI

- **Data:** 2026-10-27. **Design:** `memory/fase4-design.md`, approvato dall'utente (scelte nella sezione 0).
  **Log:** `memory/fase4-pacchetto-ci.md` (ricerca, decisioni, problemi della CI, controlli).
- **Commit:** `015633a` (design), `9ebad2f` (pacchetto), `50aa38d` (YARD), `b188bfb` (coverage), `b84aa96` (CI),
  `3e31692` e `1aff846` (correzioni della CI), poi questa documentazione.
- **Fase 1:** nessun cambio. `git diff 4906a35 -- lib/notcurses/ffi lib/notcurses/ffi.rb` è vuoto.
- **`lib/`:** `Notcurses::VERSION` da `0.2.0` a `0.1.0` (scelta dell'utente); per il resto solo commenti YARD
  (`input.rb`, `format.rb`, `visual.rb`).

### File

| File | Contenuto |
| --- | --- |
| `notcursesruby.gemspec` | gem `notcursesruby` 0.1.0, Apache-2.0, Ruby >= 3.1, dipendenza runtime solo `ffi ~> 1.15`, `requirements` notcurses 3.0.17, `rubygems_mfa_required`; file da `Dir.glob` |
| `README.md`, `CHANGELOG.md` | per gli utenti: requisiti, installazione di notcurses per sistema, esempi, limiti, sviluppo; changelog Keep a Changelog con la 0.1.0 |
| `LICENSE`, `NOTICE` | testo di Apache-2.0; attribuzione a notcurses per il layer FFI e il C nei commenti |
| `.yardopts` | README e file extra, `--hide-api private`, `--exclude lib/notcurses/ffi/`, uscita in `doc/` |
| `spec/gemspec_spec.rb` | file della gem, dipendenze, versione uguale a `Notcurses::VERSION` e al changelog |
| `spec/support/coverage.rb` | SimpleCov, caricato con `rspec --require` |
| `.github/workflows/ci.yml` | CI su GitHub Actions |
| `.gitignore` | più `/doc/`, `/.yardoc/`, `/coverage/`, `/*.gem` |

La gem contiene 52 file: i 46 di `lib/`, `examples/demo.rb`, `README.md`, `LICENSE`, `NOTICE`, `CHANGELOG.md`,
`.yardopts`. Nessun submodule, spec o documento interno.

### Come costruire la gem, la documentazione e la coverage

Dalla radice del progetto:

```sh
gem build notcursesruby.gemspec                       # notcursesruby-0.1.0.gem, senza warning
gem install ./notcursesruby-0.1.0.gem
bundle exec yard doc --fail-on-warning                # documentazione in doc/
bundle exec yard stats --list-undoc                   # 100.00% documented
TERM=xterm-256color COLORTERM=truecolor timeout -k 5 -s KILL 600 \
  bundle exec rspec --require ./spec/support/coverage.rb < /dev/null   # report in coverage/
```

- Sulla macchina di sviluppo ogni comando `gem` stampa warning di `rdoc` (`already initialized constant`): Ruby 4.0.7
  ha `rdoc` 7.2.0 e 8.1.0 installate. Non dipendono dalla gem; per controllare i warning di `gem build` usa
  `RUBYOPT=-W0 gem build notcursesruby.gemspec`.
- La coverage con una sola spec fallisce per la soglia (exit 2): le soglie valgono per la suite completa.

### YARD

- `yard doc --fail-on-warning`: 0 warning. `yard stats --list-undoc`: 100.00% (6 moduli, 51 classi, 164 costanti,
  101 attributi, 613 metodi). Gli script euristici delle fasi precedenti non servono più.
- Il layer FFI non è nella documentazione: le sue 251 costanti non hanno commento e la regola 1 vieta di aggiungerlo.
  Il modulo `Notcurses::FFI` resta documentato da `ffi.rb`.
- Gli oggetti `@api private` (`Util`, `Visual::Internal`, i metodi interni) non compaiono.

### Coverage

| Misura | Righe | Branch |
| --- | ---: | ---: |
| Locale, Ruby 4.0.7 | 98,32 % (5321/5412) | 91,26 % |
| CI, Ruby 4.0.9 (run `40449066107`) | 98,23 % (5316/5412) | 90,99 % |

- Soglie: righe 98 %, ogni file 90 %. Il layer FFI (`ffi.rb`, `ffi/`) è fuori dal totale.
- Il risultato varia di qualche riga tra le esecuzioni (thread e tempi): la soglia chiede 5304 righe, il margine è di
  17 righe in locale e 12 in CI.
- Non contano le righe eseguite nei processi figli delle spec (`pty_spec.rb`, `ui_pty_spec.rb`, `lifecycle_spec.rb`,
  `direct_spec.rb`, `reader_spec.rb`), per esempio `EventLoop#run` su un pty vero.
- **Codice morto:** `Util.timespec` (`util.rb:340`) non ha chiamanti; non rimosso e non coperto. Per questo `util.rb`
  è il file più basso (91,2 %).

### CI

- **Workflow:** `.github/workflows/ci.yml`, su push a `master` e pull request; un push nuovo ferma il run in corso
  sullo stesso ref.
- **Ambiente:** container `archlinux:base` fissato per digest; `pacman -Syuu` sullo snapshot `2026/10/26` dell'Arch
  Linux Archive: `notcurses 3.0.17-3` e `ffmpeg 2:9.0.2-2`, come sulla macchina di sviluppo. Ruby da mise: 3.2.11,
  3.3.13, 3.4.12 e 4.0.9 precompilati (`jdx/ruby`), 3.1.7 compilato con `RUBY_CFLAGS=-std=gnu17`.
- **Matrice:** Ruby 3.1.7, 3.2.11, 3.3.13, 3.4.12, 4.0.9. Ogni job: `ruby -w`, suite in ordine normale, suite con
  `--order rand` (il seme è nel log: «Randomized with seed N»). La voce 4.0.9 fa anche coverage (riepilogo nel job
  summary, artifact `coverage`), upload su Codecov se il secret `CODECOV_TOKEN` esiste, `gem build`, prova della gem
  installata da fuori del repository, YARD (artifact `doc`).
- **Ambiente delle spec:** `TERM=xterm-256color`, `COLORTERM=truecolor`, `LANG=C.UTF-8`, `timeout -k 5 -s KILL 600`,
  stdin da `/dev/null`.
- **Lockfile:** Ruby 3.2–4.0 usano `Gemfile.lock` con `BUNDLE_FROZEN` e Bundler 4.0.22; Ruby 3.1 una copia del
  `Gemfile` in `$RUNNER_TEMP`, senza lockfile.
- **Cache:** pacchetti (`/var/cache/pacman/pkg`, chiave = snapshot), Ruby (`/opt/mise/installs/ruby/<versione>`),
  gem (`/opt/bundle`, chiave = versione e hash di `Gemfile` e `Gemfile.lock`).
- **Primo run verde:** https://github.com/ichelema/notcursesruby/actions/runs/40449066107 (commit `1aff846`). Senza
  cache: job 3.2–4.0 circa 2,5 minuti (66 s per scaricare 339 MiB di pacchetti), job 3.1.7 circa 10 minuti (6 min 15 s
  per compilare Ruby). Suite: circa 60 s su 3.1.7, 21–26 s su 4.0.9.
- **Con le cache piene** (run https://github.com/ichelema/notcursesruby/actions/runs/40450186267): job da 1 min 40 s
  (3.2.11) a 2 min 47 s (3.1.7); `pacman` circa 25 s, Ruby e gem circa 5 s. Circa 11 minuti fatturati per push (ogni job
  si arrotonda al minuto), su un repository privato con minuti limitati.
- **Codecov:** attivo dal 2026-10-27. L'utente ha installato la GitHub App di Codecov sul repository privato (senza
  l'app Codecov vede solo i repository pubblici); il secret `CODECOV_TOKEN` è stato creato con `gh secret set`. Primo
  upload riuscito nel job 4.0.9 del run `40450186267` (secondo tentativo). Gli avvisi del CLI (`No gcov data found`,
  `xcrun`, `coverage.py`, nessun `codecov.yml`) vengono dalla ricerca automatica di altri formati e sono innocui.

### Cambi a `Gemfile` e `Gemfile.lock`

| File | Cambio |
| --- | --- |
| `Gemfile` | gruppo `:development` con `yard ~> 0.9`; gruppo `:test` con `rspec ~> 3.12` (prima senza blocco), `simplecov ~> 0.22`, `simplecov-cobertura ~> 3.0`. `gem 'ffi', '~> 1.15'` invariato, niente `gemspec` |
| `Gemfile.lock` | nuove: `yard 0.9.45`, `simplecov 0.22.0`, `simplecov-cobertura 3.2.0`, `simplecov-html 0.13.2`, `simplecov_json_formatter 0.1.4`, `docile 1.4.1`, `rexml 3.4.4`. `ffi`, `rspec` e `BUNDLED WITH 4.0.22` invariati |

### Test

| Spec | Esempi |
| --- | ---: |
| Fase 1, Fase 2 e Fase 3 dopo ICH-229 | 914 |
| `spec/gemspec_spec.rb` (nuova) | 3 |
| Spec nuove per la coverage (`event_loop_spec.rb` 2, `context_spec.rb` 1, `plane_spec.rb` 1, `subprocess_spec.rb` 1) | 5 |
| **Totale** | **922, 0 fallimenti** |

- Locale: Ruby 4.0.7 in ordine normale e con `rand:1234`, `rand:4242`, `rand:7`; Ruby 3.1.7 con gli stessi tre semi.
- CI: le cinque versioni, in ordine normale e casuale. Nessun esempio in skip: la spec differenziale trova
  `libnotcurses-ffi.so.3` anche in CI.

### Problemi trovati

| Problema | Causa | Soluzione |
| --- | --- | --- |
| 10 esempi dei colori RGB falliscono in CI | notcurses abilita i 24 bit solo con `COLORTERM=truecolor` o `24bit` (`termdesc.c:191`); il terminale di sviluppo la imposta, il container no | `COLORTERM: truecolor` nel workflow; vincolo nel README e in "Come eseguire i test" |
| `git submodule` esce con 128 nel container | «dubious ownership»: `actions/checkout` toglie l'eccezione `safe.directory` alla fine dello step | `git config --global --add safe.directory` prima del submodule |
| Riepilogo della coverage senza `.last_run.json` | con spec fallite SimpleCov scrive solo il report HTML | riepilogo solo dopo una suite riuscita |
| `gem build` segnala `homepage_uri` uguale a `source_code_uri` | metadati duplicati | tolto `homepage_uri` |
| Ubuntu inadatto alla CI | 24.04 ha notcurses 3.0.7; 26.04 ha 3.0.17 senza `libnotcurses-ffi` e setup-ruby non ha Ruby 3.1 su 26.04 | container Arch (scelta dell'utente) |

Docker e Podman non sono installati sulla macchina di sviluppo: il workflow è provato solo su GitHub Actions, con
`actionlint` 1.7.12 prima di ogni push.

### Cosa serve alla fase successiva

1. **Test grafici su un terminale vero** (rimandati dall'utente): xterm su Xvfb con `-ti vt340` annuncia sixel nella
   risposta DA1; uno script Ruby dentro xterm può controllare `pixel_impl` e un blit `:pixel`. kitty richiede OpenGL
   (Mesa llvmpipe con Xvfb), esito incerto.
2. **Codecov:** fatto (vedi CI). Il token è comparso nella chat della sessione: l'utente può rigenerarlo nella pagina
   di configurazione di Codecov e aggiornare il secret.
3. **`Util.timespec`:** codice morto; serve una decisione dell'utente (rimuoverlo è un cambio di `lib/`).
4. **Pubblicazione:** rubygems.org, tag `v0.1.0` e release su GitHub sono fuori scope e richiedono la conferma
   dell'utente; `CHANGELOG.md` ha già i link a `v0.1.0`.
5. **Aggiornare lo snapshot di Arch** quando cambia notcurses: `ARCH_SNAPSHOT` e il digest dell'immagine nel workflow;
   la chiave della cache dei pacchetti cambia da sola. Insieme allo snapshot va aggiornato lo SHA di
   `codecov/codecov-action` (oggi `303a32d7a59b442fa8d48b6a1cc6825c09c847a5`, `v7.1.1`), con il commento della
   versione: `gh api repos/codecov/codecov-action/commits/<tag> --jq .sha` (ICH-311).
6. **macOS** resta non provato: un job `macos-14` con Homebrew (notcurses 3.0.17) è possibile, ma i minuti macOS
   costano 10 volte quelli Linux su un repository privato.

## Correzioni della revisione del 2026-11-06

- **Inizio:** 2026-11-08. Modello passato ai comandi del workflow: `opus` (scelta dell'utente). Le issue già aperte
  che toccano lo stesso codice (ICH-214…ICH-232) restano fuori dai lotti (scelta dell'utente). Lotto 17 (Fase 1):
  approvazione rimandata a dopo il lotto 16, data dall'utente il 2026-11-14.
- **Review di ogni lotto:** `/trinity:workflow:4_review-fix-loop`, due reviewer in parallelo (Fable e GPT via
  LiteLLM), al massimo 3 round. Log lotto per lotto in `memory/correzioni-review.md`. Lotto 2: solo Fable (limite
  di utilizzo di GPT raggiunto), 3 round più una review singola dopo il loop. Lotto 3: Fable e GPT, 1 round, nessun
  finding. Lotto 4: Fable e GPT, 2 round (round 1: un MEDIUM e un LOW, corretti; round 2: nessun finding). Lotto 5:
  solo Fable (limite di utilizzo di GPT raggiunto, scelta dell'utente), 2 round (round 1: un LOW, corretto; round 2:
  nessun finding). Lotto 6: `/trinity:workflow:3_independent-review`, un reviewer Fable, 2 round (round 1: un LOW,
  corretto; round 2, solo sul commit nuovo: nessun finding). Lotto 7: Fable e GPT, 3 round (round 1: due MEDIUM e
  tre LOW, quattro corretti e un MEDIUM in ICH-454; round 2: un MEDIUM e due LOW, corretti; round 3: un LOW in
  ICH-455, GPT nessun finding). Lotto 8: Fable e GPT, 3 round (round 1: un MEDIUM, corretto; round 2: due LOW,
  corretti; round 3: nessun finding, un buco di test coperto dopo il loop senza review). Lotto 9: Fable e GPT, 3
  round (round 1: un MEDIUM, testo corretto e gestione in codice in ICH-458; round 2: due LOW, corretti; round 3: due
  LOW, corretti dopo il loop senza review; GPT nessun finding in tutti i round). Lotto 10:
  `/trinity:workflow:3_independent-review` nella stessa sessione dell'implementazione (non indipendente), 1 round:
  APPROVABILE CON RISERVE, un LOW (frase nel YARD) e due spec mancanti, aggiunti dopo la review senza un nuovo round.
  Lotto 11: Fable e GPT, 3 round (round 1: un HIGH, la spec di Plot rossa in CI, e due LOW, corretti; round 2: un
  LOW di Fable, corretto, GPT nessun finding; round 3: nessun finding). Lotto 12: Fable e GPT, 3 round (round 1: un
  HIGH, tre MEDIUM e due LOW, corretti; round 2: due MEDIUM e quattro LOW, quattro corretti e uno in ICH-459, più il
  formato del CHANGELOG; round 3: un MEDIUM di GPT scartato (`Interrupt` nella pulizia), un LOW di Fable in ICH-460;
  tre rischi già presenti su `master` in ICH-461). Lotto 13: Fable e GPT, 3 round (round 1: un LOW di Fable, il
  limite secco di `getvec` perdeva più eventi di `master` in raffica, corretto con la lettura a blocchi scelta
  dall'utente; round 2: un MEDIUM di Fable, SIGSEGV con un `close` da `trap` tra due blocchi, corretto; round 3:
  nessun finding; GPT nessun finding in tutti i round; due difetti già presenti su `master` in ICH-463 e ICH-464).
  Lotto 14: Fable e GPT, 2 round (round 1: due LOW di Fable, il controllo di overflow di `metric` in aritmetica
  Float con `base: 1000.0` o `1024.0` e le voci del CHANGELOG mancanti, corretti; round 2: nessun finding; GPT
  nessun finding in tutti i round). ICH-465 (fuori dai lotti): `/trinity:workflow:3_independent-review` nella stessa
  sessione dell'implementazione (non indipendente), 1 round: NON APPROVABILE, un HIGH (`parallel 2.3.0` nel lockfile
  richiede Ruby >= 3.3: `bundle install` rosso nel job Ruby 3.2.11) e un LOW (`Lint/RedundantCopDisableDirective`
  spento da Standard), corretti dopo la review senza un nuovo round; CI verde su tutta la matrice. Lotto 15: Fable e
  GPT, 1 round, nessun finding; implementazione fatta dalla sessione (Fable), quindi la review Fable è meno
  indipendente di quella GPT; l'esempio YARD di `Notcurses::UI::App`, già su `master`, in ICH-473. Lotto 16: Fable
  e GPT, 2 round (round 1: un LOW di Fable, l'intestazione di due righe mancante nei due file di spec nuovi,
  corretto; round 2: nessun finding; GPT nessun finding in tutti i round). Lotto 17: Fable e GPT, 3 round (round 1:
  un LOW di Fable, la perdita della risorsa C con un'eccezione asincrona e la frase falsa di `FdPlane`, testo
  corretto e protezione in ICH-474, più una lacuna di test della ffi simulata, coperta; round 2: un MEDIUM di Fable,
  use-after-free chiudendo il contesto durante `decode` in un altro thread, testo corretto e protezione in ICH-475, e
  un LOW, corretto; round 3: un LOW di Fable, corretto dopo il loop senza review; GPT nessun finding in tutti i
  round).

### Lotti

| Lotto | PR | Merge | Issue | Bug di notcurses nuovi |
| --- | --- | --- | --- | --- |
| 1 | [#2](https://github.com/ichelema/notcursesruby/pull/2) | `e22a117` | ICH-268, ICH-269, ICH-270; ICH-433 (nata dalla review) | nessuno |
| 2 | [#3](https://github.com/ichelema/notcursesruby/pull/3) | `d4970c4` | ICH-271 | resize che taglia un glifo largo: la scrittura successiva va fuori dalla riga (`notcurses.c:991`, `1917-1927`, `1956-1962`); render dentro `ncplane_put` dopo un a capo su uno stdplane che scorre (`notcurses.c:1978-1981`); tabella "Piani" di `memory/fase2-wrapper-idiomatico.md` |
| 3 | [#4](https://github.com/ichelema/notcursesruby/pull/4) | `29f5a41` | ICH-272 | i blitset dei plot `NCBLIT_4x1` e `NCBLIT_8x1` hanno `egcs` NULL (`blit.c:1279`, `1282`): con i quadranti `ncplane_as_rgba` e `ncvisual_from_plane` vanno in SIGSEGV (`notcurses.c:3114`), i blit tagliano l'immagine; tabella "Visual" di `memory/fase2-wrapper-idiomatico.md` |
| 4 | [#5](https://github.com/ichelema/notcursesruby/pull/5) | `1f441f3` | ICH-273, ICH-274, ICH-275 | `ncreader_write_egc` di un EGC di larghezza zero sull'ultima colonna porta vista e copia nascosta a x == colonne (`reader.c:240-246`, clamp con cols 0); `ncreader_write_egc` scrive solo il primo EGC della stringa e restituisce 0 (`reader.c:233-238`); `ncreader_contents` è `ncplane_contents`, che lascia copie nell'egcpool (`reader.c:413-415`); `nccell_load` di U+2028 restituisce 1 byte e taglia il codepoint; tabella "Widget A" di `memory/fase2-wrapper-idiomatico.md` |
| 5 | [#6](https://github.com/ichelema/notcursesruby/pull/6) | `119a98f` | ICH-276, ICH-277 | `ncmultiselector_draw` con il piano del widget di 1 riga: `yoff` unsigned contro `dimy - 2` (`selector.c:696`), circa 2^32 giri con il GVL tenuto; tabella "Widget A" di `memory/fase2-wrapper-idiomatico.md` |
| 6 | [#7](https://github.com/ichelema/notcursesruby/pull/7) | `a55606b` | ICH-278 | nessuno (limite già noto: `NCOPTION_NO_WINCH_SIGHANDLER` toglie anche il gestore di SIGCONT, `unixsig.c:204-211`; notcurses non gestisce SIGTSTP) |
| 7 | [#8](https://github.com/ichelema/notcursesruby/pull/8) | `29748c8` | ICH-279, ICH-280, ICH-281 | con il protocollo kitty notcurses alza SIGINT, SIGSTOP e SIGQUIT solo con Ctrl da solo (`in.c:506-516`): con CapsLock o NumLock non alza niente, con Ctrl da solo alza il segnale e mette anche l'evento in coda; lo stesso controllo non guarda `evtype`, quindi anche la ripetizione e il rilascio alzano il segnale (ICH-456); con kitty acceso ogni evento senza tipo diventa `:press`, byte di controllo compresi (`in.c:501-505`); tabella "Bug e limiti di notcurses 3.0.17 trovati nella Fase 3" |
| 8 | [#9](https://github.com/ichelema/notcursesruby/pull/9) | `0c72ad1` | ICH-282, ICH-283 | il report SGR del movimento con un tasto premuto diventa una nuova pressione dello stesso tasto (`in.c:610-620`); sulla console Linux il mouse viene da gpm e ogni evento, rilascio compreso, diventa una pressione di BUTTON1 (`gpm.c:31`, `mice.c:4-19`); tabella "Bug e limiti di notcurses 3.0.17 trovati nella Fase 3" |
| 9 | [#10](https://github.com/ichelema/notcursesruby/pull/10) | `106c700` | ICH-284; ICH-458 (nata dalla review) | `ncdirect_stream` sale di `rows - 1` righe (`direct.c:1550-1559`), ma il raster a celle lascia il cursore sotto il frame (`direct.c:558`): ogni frame scende di una riga; con `:pixel` un frame che finisce sull'ultima riga porta il cursore con una CUP alla riga sotto lo schermo (`direct.c:607-613`); tabella "Direct" di `memory/fase2-wrapper-idiomatico.md` |
| 10 | [#11](https://github.com/ichelema/notcursesruby/pull/11) | `23fd73a` | ICH-285, ICH-286 | nessuno nuovo: il bug noto dello ZWJ (`egcpool.h:126-128`) tocca anche `ncdirect_putegc` (`direct.c:49-66`) e `ncstrwidth` (`notcurses.c:3311-3333`); tabelle "Piani" e "Direct" di `memory/fase2-wrapper-idiomatico.md` |
| 11 | [#12](https://github.com/ichelema/notcursesruby/pull/12) | `cb3f0ba` | ICH-287, ICH-288, ICH-289, ICH-290 | i piani delle voci di `nctree` non cambiano mai larghezza (`tree.c:456`), tabella "Reel, Tree, Tabbed"; le etichette di `ncplot` sopra circa 1,84e17 passano da double a `uintmax_t` fuori intervallo (`plot.c:128-136`, `298-306`, comportamento indefinito: "184.47P" su x86-64-v4, "0.00" su x86-64 generico) e la riga alta esponenziale `uint64` va in wrap (`plot.c:300`); la regola dei colori di `ncprogbar` su 1 colonna o 1 riga (`fill.c:192-197`, `238-255`); "Bug noti non aggirati" di `memory/fase2-wrapper-idiomatico.md` |
| 12 | [#13](https://github.com/ichelema/notcursesruby/pull/13) | `4ec4f4c` | ICH-291, ICH-292, ICH-293 | nessuno |
| 13 | [#14](https://github.com/ichelema/notcursesruby/pull/14) | `7f91ae7` | ICH-294, ICH-295, ICH-296, ICH-298, ICH-299 | con stdin su un pipe, un carattere UTF-8 a cavallo della lettura da 8192 byte (`in.c:56`, `2179`) ferma l'input: `get` non restituisce quel carattere e `notcurses_stop` non ritorna; causa nel C non verificata, non ancora nelle tabelle dei bug (ICH-463). A coda piena notcurses scarta gli eventi (`in.c:523`) e li conta in `Stats#input_errors`: limite già noto, misurato nel lotto |
| 14 | [#15](https://github.com/ichelema/notcursesruby/pull/15) | `d47e3ac` | ICH-300, ICH-301, ICH-302, ICH-303 | `ncnmetric` con 0 < value < decimal moltiplica value per la base fino a decimal senza un controllo di overflow funzionante (`metric.c:53-59`: la guardia di `metric.c:56` controlla `dv`, che in quel ramo non cambia): con decimal > (2^64 - 1)/base restituisce cifre e prefisso sbagliati senza errore; nuova tabella "Formato (`format.rb`)" di `memory/fase2-wrapper-idiomatico.md` |
| fuori dai lotti | [#16](https://github.com/ichelema/notcursesruby/pull/16) | `ba3367f` | ICH-465 (RuboCop con Standard nel `Gemfile` e nella CI; nessun cambio in `lib/` e `spec/`) | nessuno |
| 15 | [#17](https://github.com/ichelema/notcursesruby/pull/17) | `28ef91a` | ICH-304, ICH-305; ICH-473 (nata dalla review) | nessuno |
| 16 | [#18](https://github.com/ichelema/notcursesruby/pull/18) | `9672bd5` | ICH-306, ICH-307, ICH-308, ICH-309, ICH-310, ICH-311 (solo spec e CI, nessun cambio in `lib/`) | nessuno |
| 17 | [#19](https://github.com/ichelema/notcursesruby/pull/19) | `e3e8737` | ICH-312, ICH-313 (Fase 1, regola 1, approvato dall'utente); ICH-474, ICH-475 (nate dalla review) | nessuno |

### Cambi dell'API pubblica

Nessun metodo nuovo né rimosso, salvo `Input#ctrl_field?` (`@api private`, lotto 7), `Util.plane_channels_value`,
`UI::App#focus_state` e `#restore_focus_state` (`@api private`, lotto 12). Comportamenti nuovi:

- `Context#close`, `Direct#close`, `Context#drop_planes`: un'eccezione al ritorno della chiamata C (Ctrl-C) lascia
  l'oggetto chiuso, i piani distrutti invalidi e il registro libero (lotto 1).
- `Context#close` e `Direct#close` in un figlio di `fork`: nessuna chiamata a notcurses, solo lo stato Ruby. Nel figlio
  notcurses resta inutilizzabile anche dopo `close` (i segnali restano registrati per il contesto del padre): il
  figlio può solo uscire o fare `exec` (lotto 1).
- `Context#close` e `Direct#close` si possono chiamare da un gestore `trap` (lotto 1).
- **Hook globale:** `Notcurses::DirectForkFlush` (privato) è anteposto a `Process._fork` (Ruby >= 3.1): prima di
  ogni `fork`, `Process.fork` e `IO.popen('-')` svuota il buffer stdio del `Direct` aperto. `Process.daemon` e
  `spawn` non passano da `_fork` (lotto 1, ICH-433).
- `Plane#resize`, `#resize_region`, `#resize_maximize`: la metà di un glifo largo tagliata dal nuovo bordo diventa
  una cella vuota. Per i resize fatti da notcurses (stdplane nel render, figli `:maximize`) la cella si svuota alla
  prima scrittura del wrapper sul piano, se le colonne sono cambiate o dopo un `merge_down` (lotto 2).
- `Plane#putstr` e `#hline` su uno stdplane che scorre: prima di una scrittura che può andare a capo chiamano
  `ncpile_render`, che porta lo stdplane alle dimensioni del terminale; possono quindi sollevare `RenderError` e le
  eccezioni dei callback Ruby di resize (lotto 2).
- `Visual.from_plane`, `Plane#as_rgba`, `Visual#blit`, `#geometry`, `#create_plane`, `#stream` e `Visual.blit_*`:
  `:four_by_one` e `:eight_by_one` (e le costanti `NCBLIT_4x1`, `NCBLIT_8x1`) sollevano `ArgumentError` prima del C.
  Una sola tabella, `Util::IMAGE_BLITTERS`, serve `Visual`, `Plane#as_rgba` e `Direct`; `Direct::Args::BLITTERS`
  (privata) è rimossa. `Plot` e i metodi di formato accettano ancora i due blitter (lotto 3).
- `Reader#offer_input` e `#write`: un carattere di larghezza zero sull'ultima colonna viene scartato e conta come
  scritto. `prepare!` e il workaround di Backspace/Ctrl+U/Ctrl+W controllano `ncplane_cursor_move_yx`: `offer_input`,
  `write` e `move_*` possono sollevare `WidgetError` prima della chiamata C (lotto 4).
- `Reader#write` scrive un EGC di notcurses alla volta (`nccell_load`): un grapheme che notcurses divide occupa più
  celle; se `nccell_load` fallisce solleva `WidgetError`, con il testo precedente scritto (lotto 4).
- `Reader#contents` legge la vista con `Plane#contents`: non solleva più `WidgetError` per l'egcpool pieno, può
  sollevare `PlaneError` se la lettura di una cella fallisce (lotto 4).
- `Tree.new`, `Tabbed.new` e `Reel.new` sollevano `WidgetError` dentro un callback chiamato da notcurses (blocco di
  un tablet, di un Tree o di un Tab, callback `resize:`), come gli altri widget; il piano resta aperto (lotto 5).
- `MultiSelector#offer_input` solleva `WidgetError` prima della chiamata C se il piano del widget ha una sola riga,
  anche per un evento vuoto (lotto 5).
- `EventLoop#run` (e `UI::App#run`): con `no_winch_sighandler: true` installa anche `trap('CONT')` e lo toglie alla
  fine, come `trap('WINCH')`; dopo Ctrl+Z e `fg` chiama `Context#refresh`, senza `on_resize` se le dimensioni non
  cambiano. Il default `no_winch_sighandler: true` non cambia (lotto 6).
- `UI::TextInput` inserisce `Input#eff_text` e `EventLoop#on_key` confronta un carattere stampabile con il primo
  codepoint di `eff_text` (con `eff_text` vuoto, con `id`): con il protocollo kitty Shift+1 dà "!" (lotto 7).
- `EventLoop#run` legge ISIG a ogni avvio, anche senza opzioni. Con ISIG attivo alza SIGINT, SIGSTOP o SIGQUIT al
  proprio processo per Ctrl+C, Ctrl+Z e Ctrl+\ di kitty con CapsLock o NumLock, e non consegna più questi tasti
  di kitty né il Ctrl+C di xterm con modifyOtherKeys; i byte di controllo restano tasti (lotto 7).
- `UI::TextInput` scorre il testo anche per il grapheme sotto il cursore (lotto 7).
- `Context#linesigs?` e il controllo di flusso con STDIN chiuso leggono `/dev/tty` invece di sollevare `IOError`
  (lotto 7).
- `UI::LogView#append('')` restituisce la vista e non cambia le righe (lotto 8).
- `UI::App`: una pressione di BUTTON1..3 con lo stesso tasto già premuto, senza rilascio, è un drag: non cambia il
  focus, non va ai componenti e arriva solo a `on_input`; un drag non ripete il clic di un `Button`. Sulla console
  Linux (`detected_terminal` `FBcon` o `VT`) la regola non vale. `App.new` legge `detected_terminal` (lotto 8).
- `Direct#stream`: prima di ogni frame dopo il primo il cursore sale di tutta l'altezza del frame precedente, senza
  CUB. Con `:pixel`, per un frame più basso dello schermo che finisce sull'ultima riga, l'esito dipende dal
  terminale: documentato nel YARD (lotto 9, ICH-458).
- `Notcurses.strwidth` misura il testo spezzato dopo ogni grapheme cluster con uno ZWJ (U+200D), come lo scrive
  `Plane#putstr`: `"👩‍🚀abc"` vale 5 colonne, non 2 come `ncstrwidth`. Il testo senza ZWJ dà lo stesso valore di prima.
  Il contratto "con le regole di notcurses" cambia (scelta dell'utente, regola 14): il valore nuovo arriva a
  `Direct#print_aligned`, `Plane#puttext` e alla UI (`Label`, `ListView`, `Button`, `Dialog`, `LogView`,
  `TextInput`). Per una sequenza ZWJ che non è un emoji il valore segue i grapheme cluster della versione di Ruby
  (lotto 10).
- `Direct#putegc` passa al C il testo solo fino al primo grapheme cluster con uno ZWJ; `Direct#print_aligned`
  solleva `ArgumentError` anche per un carattere di controllo dopo una sequenza ZWJ. `Plane#zwj_segments` (privato)
  diventa `Util.zwj_segments` (`@api private`) (lotto 10).
- `Tree#redraw` porta i piani delle voci alla larghezza corrente dell'albero meno la colonna della voce, almeno 1:
  un blocco che restringe da sé il piano della voce lo ritrova largo al redraw successivo (lotto 11).
- `Tab#move(before:)` del primo tab mostrato verso il tab alla sua destra non cambia più il primo tab mostrato
  (lotto 11).
- UI: un componente (anche un `Dialog`) che solleva durante la creazione si chiude, esce dal contenitore, dall'App e
  dalle finestre modali, e lo stato del focus torna quello di prima; `new` propaga l'eccezione originale.
  `Component#close` e `Dialog#close` completano la chiusura anche se il ridisegno del focus solleva (lotto 12).
- I costruttori di `Container`, `Label`, `Button`, `TextInput`, `ListView`, `LogView` e `Dialog` sollevano
  `ArgumentError` per `channels:` o `focused_channels:` con lo sfondo `:highcontrast`, prima di creare il piano; prima
  un `Container` senza titolo li accettava (scelta dell'utente, regola 14). Il messaggio di `Plane#channels=` comincia
  ora con il nome del parametro (`channels: ...`) (lotto 12).
- `UI::App`: se un resize nasconde tutti i componenti focusabili, il resize che li mostra ridà il focus al componente
  che lo aveva prima del resize (o al primo candidato visibile), prima di `on_resize`, anche se nel frattempo un
  dialogo si apre o si chiude; `focus(nil)` esplicito resta. Senza focus un tasto va alla radice attiva (Esc arriva a
  un `Dialog`) (lotto 12).
- `UI::Dialog`: i pulsanti hanno peso `strwidth(etichetta) + 5`, così ogni etichetta entra intera; la larghezza del
  dialogo non cambia (lotto 12).
- `Context#get`, `Context#getvec` e `Direct#get`: un `timeout` sopra 2147483647 secondi (2^31 - 1) solleva
  `ArgumentError`; prima un valore oltre `time_t` dava `RangeError` durante l'attesa (scelta dell'utente, regola 14:
  non "vale come `nil`"). L'intervallo è `Util::TIMEOUT` (lotto 13).
- `Context#getvec`: legge a blocchi di 8192 slot (`GETVEC_MAX`, costante privata) finché un blocco non torna pieno,
  finisce con EOF o `count` è raggiunto; la memoria dipende dagli eventi letti, non da `count`. Il primo fix, un
  limite secco di 8192 eventi per chiamata, è stato tolto nel round 1 della review (scelta dell'utente); i criteri di
  ICH-295 su Linear sono stati aggiornati (lotto 13).
- `UI::EventLoop#every`: un timer il cui blocco solleva resta programmato e scatta nel `run` successivo, fino a
  `Timer#cancel` (scelta dell'utente, regola 14: non "il timer si ferma") (lotto 13).
- `UI::EventLoop#run`: il primo giro non attende, quindi consegna subito i tasti lasciati in coda dal run precedente;
  l'attesa di un giro dura al massimo 86 400 s, così `after(Float::MAX)` resta valido come "mai" (scelta dell'utente,
  regola 14: non `ArgumentError` in `after` ed `every`) (lotto 13).
- `Input#utf8` e `Input#eff_text` restituiscono stringhe congelate: `<<` solleva `FrozenError` invece di cambiare
  l'evento (lotto 14).
- `Util.take_string` sostituisce con U+FFFD i byte che non sono UTF-8 valido, quindi lo fanno anche
  `Notcurses.accountname`, `.hostname`, `.osversion`, `Context#detected_terminal` e `Direct#detected_terminal`
  (scelta dell'utente, regola 14, confermata dopo la review: `scrub` in `take_string`, non solo nei cinque metodi,
  non una String binaria, non un errore) (lotto 14).
- `Notcurses.metric`, `.si_prefix`, `.binary_prefix` e `.byte_prefix` sollevano `ArgumentError` per le coppie
  value/decimal che mandano in overflow `ncnmetric`; l'intervallo di `decimal` non cambia, e con `base: 1000.0` o
  `1024.0` il controllo usa la base intera (lotto 14).
- `Visual.from_file`, `Visual#decode`, `#decode_loop`, `Direct#render_frame`, `#load_image`, `Direct::Image.new` e
  `Direct#stream` aprono e leggono il file senza il GVL: gli altri thread Ruby girano durante l'I/O di ffmpeg, ma non
  devono usare lo stesso contesto. Un'eccezione asincrona arriva al ritorno della chiamata C e la risorsa creata dal C
  va persa (ICH-474); chiudere il visual o il contesto, anche con `at_exit`, mentre un altro thread è dentro `decode`
  è un use-after-free (ICH-475). Dentro il blocco di un `FdPlane` il kill di `close` arriva anche durante queste
  chiamate e durante `Visual#stream` (lotto 17, ICH-312).
- `require 'notcurses'` funziona anche dove il `types.conf` di ffi non ha `wchar_t` o `uintmax_t`; nessun cambio su
  Linux x86_64 e macOS (lotto 17, ICH-313).

### Cambi a `Gemfile` e `Gemfile.lock`

- ICH-465: nel gruppo `:development`, con `require: false`, `rubocop ~> 1.91.0`, `rubocop-performance ~> 1.26.1`,
  `rubocop-thread_safety ~> 0.8.0`, `standard ~> 1.57.0` e `parallel < 2`. Il vincolo su `parallel` serve al job
  Ruby 3.2.11, che installa dal lockfile: `parallel` 2.x richiede Ruby >= 3.3 (nel lockfile c'è la 1.28.0). Un
  `bundle lock` o `bundle update` fatto con un Ruby recente può scegliere altre gem che non accettano Ruby 3.2: dopo
  ogni cambio del lockfile controlla il job Ruby 3.2.11 della CI.
- Nei lotti 1–14: nessuno.
- Lotto 15 (ICH-305): `gem 'ffi', '~> 1.16'` nel `Gemfile` e `ffi ~> 1.16` nel gemspec (prima `~> 1.15`). Nel
  `Gemfile.lock` cambia solo la riga `ffi (~> 1.16)` di `DEPENDENCIES`: `ffi 1.17.4`, le sue piattaforme e
  `BUNDLED WITH 4.0.22` restano uguali.
- Lotto 16: nessuno.

### RuboCop (ICH-465)

- `.rubocop.yml`: Standard come base (`inherit_gem`), plugin `rubocop-performance` e `rubocop-thread_safety`,
  `TargetRubyVersion: 3.1`, `NewCops: enable`, `Layout/EndOfLine` e `Style/Documentation` spenti. Una differenza
  dalla configurazione di riferimento della issue (scelta dell'utente dopo la review):
  `Lint/RedundantCopDisableDirective` è acceso, perché Standard lo spegne e senza quel cop niente controlla i
  commenti `# rubocop:disable`.
- `.rubocop_todo.yml`: generato con `bundle exec rubocop --auto-gen-config --exclude-limit 1000
  --no-auto-gen-timestamp`; congela 5307 offense in 93 file, solo con `Exclude` per file (46 cop). Nessun cop è
  spento per tutto il progetto: un file nuovo passa da ogni cop, quindi va scritto nello stile di Standard (stringhe
  con le virgolette doppie). Una offense nuova di un cop in un file già escluso per quel cop non viene rilevata.
- Lavoro rimasto, fuori da ICH-465 (elenco nella issue, sezione "Out of scope"): le offense correggibili con
  `rubocop -a` (ICH-469: la conversione alle virgolette doppie rompe due regex che leggono i sorgenti come testo,
  `notcursesruby.gemspec:7` e `spec/gemspec_spec.rb:24`: vanno corrette nello stesso commit); senza issue le 17
  correzioni non sicure e le offense `ThreadSafety/*`. In più (ICH-470): il commento `# rubocop:disable
  Lint/UnusedMethodArgument` di `lib/notcurses/ui/component.rb:223` non serve con Standard (file nel todo).

### CI

- Lotto 1: la cache di Ruby 3.1.7 era scaduta (GitHub cancella le cache non usate da 7 giorni), e il nuovo build
  falliva in `file.c`: mise 2026.10.19 dello snapshot non passa `RUBY_CFLAGS` a ruby-build 20261023, quindi gcc 16
  compilava Ruby 3.1 in C23. Lo step «Ruby» ora imposta anche `CFLAGS: -std=gnu17`. `codecov.yml` rende
  informativi gli status di Codecov: le soglie vincolanti restano quelle di SimpleCov, e i rami che girano solo nei
  processi figli delle spec non sono misurati.
- Podman 6.1.4 è ora installato sulla macchina di sviluppo: il container della CI si riproduce in locale (immagine
  `docker.io/library/archlinux:base@sha256:52dfbd5a…`, mirror dello snapshot, poi `pacman -Syuu` con i pacchetti di
  `ci.yml`).
- ICH-465: step «RuboCop senza offense» (`bundle exec rubocop`) solo nel job `full: true` (Ruby 4.0.9), ultimo step
  del job, così un fallimento del linter non salta gli artifact della coverage e della documentazione.
- Lotto 16 (ICH-311): `codecov/codecov-action` è fissata allo SHA del commit di `v7.1.1`
  (`303a32d7a59b442fa8d48b6a1cc6825c09c847a5`, con il commento `# v7.1.1`); `spec/ci_workflow_spec.rb` chiede uno
  SHA di 40 cifre e il commento della versione per ogni action fuori da `actions/`. Aggiornamento insieme allo
  snapshot: punto 5 di "Cosa serve alla fase successiva" della Fase 4.
- Lotto 16 (ICH-309): `spec/ffi_layout_spec.rb` compila in ogni job un programma C contro gli header di notcurses
  (`gcc` da `base-devel`, nessun cambio a `ci.yml`). Va in skip, senza far fallire la CI, solo se manca un
  compilatore o se `#include <notcurses/notcurses.h>` non compila: dopo un cambio di `ARCH_SNAPSHOT` controlla che
  nei log non ci siano esempi `pending`.

### Issue aperte nate dai lotti

- ICH-441 — `Process.daemon` con un `Context` o un `Direct` aperto lascia il terminale nel modo dell'init (lotto 1,
  review round 3).
- ICH-448 — lo stato del controllo dei bordi è del singolo wrapper `Plane`, non del piano C (lotto 2, review round 3). Chiusa nel lotto 1 delle issue in Backlog (PR #22).
- ICH-449 — double free dopo `merge_down` con glifi larghi seguito da `Plane#at` (lotto 2; esiste già su `master`). Chiusa nel lotto 1 delle issue in Backlog (PR #22): la causa era la `free` del wrapper.
- ICH-450 — `polyfill`, `gradient` ed `erase_region` su metà di un glifo largo lasciano una metà orfana (lotto 2;
  esiste già su `master`). Chiusa nel lotto 1 delle issue in Backlog (PR #22).
- ICH-454 — lo stato ISIG del terminale e il flag interno `linesigs` di notcurses possono divergere (`stty` fuori da
  notcurses), e `run` allora sbaglia per il Ctrl+C di kitty (lotto 7, review round 1).
- ICH-455 — dopo un `run` uscito con `:interrupt`, il Ctrl+C rimasto in coda arriva a un `run(no_linesigs: true)`
  successivo (lotto 7, review round 3).
- ICH-456 — notcurses alza il segnale anche per la ripetizione e il rilascio del Ctrl+C di kitty (lotto 7; esiste
  già su `master`).
- ICH-457 — consegnare il movimento del drag al componente dove il drag è partito (pointer capture); funzionalità
  nuova, `Improvement` (lotto 8, scelta dell'utente su ICH-283).
- ICH-458 — `Direct#stream` con `:pixel`: un frame più basso dello schermo che finisce sull'ultima riga fa partire i
  frame successivi una riga più in alto, su un terminale che ferma la CUP sull'ultima riga; per i frame più stretti
  del terminale è una regressione rispetto a prima del lotto 9 (lotto 9, review round 1).
- ICH-459 — `Container#close_parts` si ferma al primo figlio che solleva, e in `Component#close` un `release_focus`
  che solleva salta `close_parts`: figli aperti e registrati (lotto 12, review round 2; esiste già su `master`).
- ICH-460 — con i pesi di ICH-293 una riga di pulsanti di 4-6 colonne può dare 0 colonne all'etichetta più corta,
  che si nasconde e perde il focus (prima solo a 3 colonne) (lotto 12, review round 3).
- ICH-461 — un componente che diventa visibile fuori dal ripristino dopo un resize (dialogo aperto a terminale
  piccolo senza focus in attesa, componente nato nascosto, fratello mostrato dopo la chiusura del focus) non prende
  il focus (lotto 12, review round 3; esiste già su `master`).
- ICH-463 — con stdin rediretto, un carattere UTF-8 a cavallo della lettura da 8192 byte blocca notcurses: `get`
  restituisce 2730 caratteri CJK su 2731 e `Context#close` non ritorna (lotto 13, review round 3; esiste già su
  `master`, riprodotto; causa nel C non verificata).
- ICH-464 — `to_ptr` e la chiamata C non sono atomici per i gestori `trap`: un gestore che chiude il contesto e
  lascia proseguire il codice può dare SIGSEGV in ogni metodo del wrapper (lotto 13, review round 3; esiste già su
  `master`, misurato solo dal reviewer: 1 caso su 40; contiene una scelta della regola 14).
- ICH-469 — autocorrezioni sicure di RuboCop (`rubocop -a`) e conversione alle virgolette doppie di Standard, con le
  due regex del gemspec e di `spec/gemspec_spec.rb` da correggere nello stesso commit; `Improvement` (ICH-465).
- ICH-470 — il commento `# rubocop:disable Lint/UnusedMethodArgument` di `lib/notcurses/ui/component.rb:223` non
  serve con Standard; `Improvement` (ICH-465, review).
- ICH-473 — l'esempio YARD di `Notcurses::UI::App` (`lib/notcurses/ui/app.rb:50-60`) stampa `name.text` dentro il
  blocco di `Context.open`, come il README prima di ICH-304: la riga va sullo schermo alternativo (lotto 15, review;
  esiste già su `master`, letto e non eseguito).
- ICH-474 — un'eccezione asincrona (`Thread#raise`, `Timeout`, Ctrl-C, il kill di `FdPlane#close`) al ritorno di
  `ncvisual_from_file`, `ncdirectf_from_file` o `ncdirect_render_frame` perde la risorsa C, con il file aperto (lotto
  17, review round 1; con Ctrl-C esisteva già su `master`).
- ICH-475 — chiudere il contesto o il visual, anche con `at_exit`, mentre un altro thread è dentro `Visual#decode` o
  `#decode_loop` è un use-after-free; da verificare le varianti di `Direct`; lo stesso problema esiste già per
  `Visual#stream` (lotto 17, review round 2; contiene una scelta della regola 14).

## Fase 5 — blitter su un terminale vero e macOS

- **Data:** 2026-11-15. Design: `memory/fase5-design.md`. Log con ambienti, risultati e problemi:
  `memory/fase5-terminali-macos.md`.
- **PR:** [#20](https://github.com/ichelema/notcursesruby/pull/20) (Linux, merge `4d3430a`, senza issue) e
  [#21](https://github.com/ichelema/notcursesruby/pull/21) (macOS, merge `6cc619b`, ICH-478).
- **Stato al `6cc619b`:** 1048 esempi, 0 fallimenti (su macOS 11 pending con il motivo); coverage su macOS: righe
  98,47 %; `bundle exec rubocop` 0 offense (99 file). Nessun cambio a `Gemfile`, `Gemfile.lock` e alla CI.
- **Controlli finali su Linux** (2026-11-15, dopo il merge): suite con l'ordine normale e con `rand:1234`,
  `rand:4242` (3 volte), `rand:7`: 1048 esempi, 0 fallimenti; coverage righe 98,46 %; spec grafiche in Kitty
  verdi. Dettagli nel log, sezione "Parte 4".

### File

| File | Contenuto |
| --- | --- |
| `spec/graphics/terminal_spec.rb`, `spec/graphics/probe.rb` | spec grafiche su un terminale vero, solo con `NC_GRAPHICS=1` |
| `lib/notcurses/util.rb` | rimosso `Util.timespec` (senza chiamanti) |
| `lib/notcurses/ffi/functions.rb` | `notcurses_stop` con `blocking: ::FFI::Platform.mac?` |
| `lib/notcurses/context.rb` | metodo privato `stop_notcurses`: su macOS lo stop gira in un thread, con le interruzioni rimandate |
| `spec/support/nc_helpers.rb` | `NcHelpers::FD_DIR`, `NcHelpers.open_fd_count`, `NcHelpers::TIMEOUT` |
| `spec/integration/pty_spec.rb` | 2 esempi nuovi sulla chiusura del contesto su macOS |
| altre spec | attese per macOS in `stats`, `reader`, `subprocess`, `visual`; `context_spec.rb:358` aspetta l'EOF |

### Come avviare le prove grafiche

Da Kitty o Ghostty, dalla radice del progetto, con il `TERM` del terminale:

```sh
NC_GRAPHICS=1 bundle exec rspec spec/graphics
NC_GRAPHICS=1 NC_GRAPHICS_HOLD=3 bundle exec rspec spec/graphics   # controllo a vista
```

Senza `NC_GRAPHICS=1` RSpec esclude il gruppo. Gli esempi dei tasti girano solo in Kitty con il remote control
(`allow_remote_control yes` e `listen_on`). Da una sessione senza tty serve una finestra nuova: comandi nel log.

### Risultati per sistema, terminale e blitter

| Voce | Linux, Kitty 0.50.0 | Linux, Ghostty 1.4.0 | macOS, Kitty 0.50.0 | macOS, Ghostty 1.4.0 |
| --- | --- | --- | --- | --- |
| spec grafiche | 5 esempi verdi | 3 verdi, 2 in skip | 5 esempi verdi | 3 verdi, 2 in skip |
| `pixel_support` | `:kitty_animated` | `:kitty_static` | `:kitty_animated` | `:kitty_static` |
| `:pixel`, `:quad`, `:sextant`, `:braille`, `:half`, `:ascii` | riusciti | riusciti | riusciti | riusciti |
| `:octant` | assente | assente | assente | assente |
| controllo a vista dell'utente | sì | sì | sì | sì |
| Shift+1 in un `TextInput` (ICH-279), tastiera vera | `"!@"` | `"!@"` | `"!@"` | `"!@"` |
| termios di `EventLoop#run`, tastiera vera | — | — | flag corretti e ripristinati | flag corretti e ripristinati |

Sixel non è provato: nessuno dei due terminali lo supporta.

### Stato di macOS

- **Passa:** caricamento della gem senza variabili d'ambiente; suite completa in ordine normale e con `rand:1234`,
  `rand:4242`, `rand:7`; spec differenziale con `libnotcurses-ffi.dylib`; `ffi_layout_spec.rb` con Apple clang.
- **In skip (11):** `va_list` solo con l'ABI System V x86_64 (1); `libc_malloc_debug` di glibc (3); `TIOCSCTTY` e
  `/proc` in `ui_pty_spec.rb` (6); `visual_spec.rb:673`, perché su macOS `rxvt-256color` non attiva i quadranti
  (`unix_early_matches` è dentro `#ifndef __APPLE__`, `termdesc.c:1137-1155`) (1).
- **Limite:** la CI gira solo su Linux. I 2 esempi sulla chiusura del contesto passano su Linux anche senza il fix:
  dopo un cambio a `notcurses_stop` o a `Context#close` la suite va eseguita a mano su macOS.

### Problemi trovati

| Problema | Causa | Gestione |
| --- | --- | --- |
| Su macOS `Context#close` si blocca con un pty letto da un thread Ruby dello stesso processo | `notcurses_stop` chiama `tcsetattr(TCSAFLUSH)` (`notcurses.c:147`), che su macOS aspetta il lettore del pty, e teneva il GVL | `blocking: ::FFI::Platform.mac?`; su Linux la chiamata non cambia (scelta dell'utente) |
| Con il GVL rilasciato un `Thread#raise` o un `Timeout` durante la chiusura lascia il terminale nel modo di notcurses | Ruby sblocca la chiamata, `tcsetattr` esce con `EINTR` e notcurses non riprova; `Thread.handle_interrupt` da solo non basta | `Context#stop_notcurses`: stop in un thread dedicato, atteso con le interruzioni rimandate |
| Bug di notcurses 3.0.17, non corretto: un segnale gestito da Ruby durante l'attesa di `tcsetattr` fa fallire `notcurses_stop` con -1, e il termios non viene ripristinato | `tcsetattr` interrotta (`EINTR`) non viene ripetuta (`notcurses.c:147`); succede solo dove `TCSAFLUSH` aspetta (macOS), anche con il GVL tenuto | nessuna: `Context#close` solleva `ContextError` |
| `context_spec.rb:358` fallisce con `rand:4242` | l'esempio è il primo del gruppo e l'EOF non è ancora in coda: il wrapper ripete `notcurses_getvec` (corretto) | la spec aspetta l'EOF prima di contare le chiamate |
| Differenze di macOS nelle spec | niente `/proc`; `osversion` inizia con `macOS`; `wcwidth(U+2028)` vale 0; `ls` di BSD apre 2 descrittori; manca `timeout` | spec portabili, con le attese di Linux invariate |

**Punto aperto:** una volta su 62 esecuzioni con `rand:2026`, su macOS rspec si è bloccato in `Context#close`
(`notcurses_stop` → `stop_inputlayer` → `pthread_join`, con il thread di input di notcurses fermo in `poll` dopo
`pthread_cancel`). Causa non trovata; stack e ipotesi nel log, "Punti aperti". Nessuna issue.

Issue del Backlog incontrate e non corrette: ICH-455 (in Kitty il Ctrl+C che interrompe un `run` arriva al
`run(no_linesigs: true)` successivo).

### Cosa serve alla fase successiva

1. **Blocco raro su macOS** (punto aperto): cercare la causa con la traccia degli esempi e `sample`.
2. **Sixel:** serve un terminale che lo supporta (per esempio foot o xterm con `-ti vt340`).
3. **Job macOS in CI:** escluso dall'utente; senza, i fix di macOS non hanno una protezione automatica.
4. **Pubblicazione** della gem: fuori scope, richiede la conferma dell'utente.

## Issue in Backlog

- **Inizio:** 2026-11-15. Modello passato ai comandi del workflow: `opus`. Lotti: la proposta di `RIPRESA.md` con 4
  cambi approvati dall'utente (ICH-225 nel lotto 1, ICH-214 nel lotto 2, ICH-464 nel lotto 5, ICH-474 nel lotto 7).
  ICH-231 e ICH-457 restano nella fase; ICH-225 con audit e fix. Log lotto per lotto in `memory/backlog-issue.md`.
- **Review di ogni lotto:** `/trinity:workflow:4_review-fix-loop`, due reviewer in parallelo (Fable e GPT via
  LiteLLM), al massimo 3 round. Lotto 1: 3 round (round 1: due HIGH; round 2: tre HIGH e un MEDIUM, di cui due nati
  dal fix del round 2 stesso; round 3: un HIGH, un MEDIUM e due LOW); il HIGH del round 3 e i LOW corretti dopo il loop
  senza review, su richiesta dell'utente. Lotto 2: due loop da 3 round (il secondo in una sessione nuova, perché il
  contesto era pieno); ICH-214 tolta dopo il primo loop; nel secondo loop due HIGH sui gestori `trap` in `merge_down`,
  tre MEDIUM e quattro LOW corretti; i finding del round 3 corretti dopo il loop senza review, salvo ICH-529.
  Lotto 2b: 2 round; nel round 2 solo GPT, perché Fable ha finito il limite d'uso (429, si azzera il 2026-11-20); i
  finding del round 1 (ICH-489 e ICH-529) sono corretti in `f209900`; il ripristino della base che richiede spazio
  Lotto 2c: `/trinity:workflow:3_independent-review` in due round, solo GPT (Fable senza crediti, scelta dell'utente);
  round 1 non approvabile per due finding su ICH-532 (nuovo approccio in `13294e1`), round 2 approvabile. Prima del
  primo commit, un secondo parere di design di GPT su ICH-531 ha trovato il ripristino doppio della base (`9d07656`).
  Lotto 3: due `/trinity:workflow:4_review-fix-loop` da 3 round, con GPT e Sonnet (`trinity:reviewer` con `model:
  sonnet` ed `effort: max` al posto di Fable, scelta dell'utente). Dopo il primo loop la PR #26 è rimasta in draft
  (scelta dell'utente): con kitty il segnale arrivava solo quando `run` leggeva il tasto (ICH-536). ICH-536, ICH-537 e
  ICH-538 sono state fatte sullo stesso branch con il disegno B (un thread Ruby di input del contesto, nessun cambio
  FFI), poi il secondo loop; i 4 finding del suo round 3, tutti LOW dopo il triage, sono corretti in `e78d5cd`.

### Lotti

| Lotto | PR | Merge | Issue | Bug di notcurses nuovi |
| --- | --- | --- | --- | --- |
| 1 | [#22](https://github.com/ichelema/notcursesruby/pull/22) | `74deb80` | ICH-449, ICH-450, ICH-448, ICH-225; ICH-481 (nata dall'audit, nel lotto per scelta dell'utente) | `ncplane_erase_region`, `ncplane_gradient`, `ncplane_gradient2x1` e `ncplane_polyfill_yx` cambiano le celle una per una e lasciano metà orfane (ICH-450); `ncplane_mergedown` lascia le metà destre dei glifi larghi con width 0 (`render.c:393-395`, `471-485`, ICH-481); tabella "Piani" di `memory/fase2-wrapper-idiomatico.md` |
| 2 | [#23](https://github.com/ichelema/notcursesruby/pull/23) | `cb90c4f` | ICH-485, ICH-215, ICH-216, ICH-482, ICH-487 (ICH-485, ICH-482 e ICH-487 nate dal lotto 1); ICH-214 tolta dal lotto, di nuovo in Backlog | `ncplane_resize` con `keep_x > 0` rilascia EGC della regione conservata (`notcurses.c:995-997`, ICH-215) e lascia `logrow` (già noto); `ncplane_dup` crea la copia con `flags = 0` e copia solo `halign` (ICH-216); `ncplane_mergedown` copia gli EGC di più di 4 byte senza rilasciare i vecchi (`render.c:602-603`, ICH-482) e lascia `gcluster` 0 con la larghezza nella cella dopo una metà sinistra (`render.c:471-485`); `ncplane_at_yx` su un piano con bitmap copia la sequenza dello sprixel, già liberata con Kitty (`notcurses.c:236-243`, ICH-487); tabella "Piani" di `memory/fase2-wrapper-idiomatico.md` |
| 2b | [#24](https://github.com/ichelema/notcursesruby/pull/24) | `6374e41` | ICH-529, ICH-530, ICH-489, ICH-493, ICH-490 (tutte nate dal lotto 2) | `ncplane_resize` che non conserva niente scarica il pool con `egcpool_dump` (`notcurses.c:953-957`) e `ncplane_rotate_cw`/`ncplane_rotate_ccw` fanno lo stesso (`fill.c:446`): la cella base con un EGC di più di 4 byte punta al pool vuoto (ICH-489); `ncplane_at_yx` su un piano con bitmap, anche sixel, legge il framebuffer come celle e va in segfault (ICH-493); `ncplane_mergedown` lascia una metà destra a width 0 e `gcluster` 0 dopo una metà sinistra orfana sull'ultima riga di `src` (`render.c:471-485`, ICH-530) |
| 2c | [#25](https://github.com/ichelema/notcursesruby/pull/25) | `d2c5f7c` | ICH-531, ICH-532 (nate dal lotto 2b) | `rotate_2x1_cw` e `rotate_2x1_ccw` non rilasciano le copie nell'egcpool quando rifiutano un carattere (`fill.c:377-437`; non aggirato); `ncplane_mergedown` dopo una metà sinistra orfana seguita da un glifo copre il glifo e gli dà i canali della metà sinistra (`render.c:471-485`, ICH-532); tabella "Piani" di `memory/fase2-wrapper-idiomatico.md` |
| 3 | [#26](https://github.com/ichelema/notcursesruby/pull/26) | `e15b40a` | ICH-454, ICH-456, ICH-455; ICH-536, ICH-537, ICH-538 (nate dal lotto 3, sullo stesso branch per scelta dell'utente) | con kitty notcurses alza il segnale anche per la ripetizione e il rilascio e lo decide da un flag privato che `stty` non cambia (`in.c:506-516`, `termdesc.c:390`); con la coda di input piena (8192 eventi) scarta il tasto nuovo senza frenare chi scrive (`in.c:523-527`); due assert con le sequenze escape spezzate fra due letture (`in.c:803`, `in.c:2229`), non aggirati; tabella "Bug e limiti di notcurses 3.0.17 trovati nella Fase 3" |

### Cambi dell'API pubblica

Nessun metodo nuovo né rimosso, salvo `Util.free` (`Util` è `@api private`) e i metodi `@api private` di `Context`
del lotto 3. Comportamenti nuovi:

- La memoria allocata da notcurses (`Plane#at`, `#name`, `#as_rgba`, `Context#stats`, `Context#at`,
  `detected_terminal`, `Notcurses.hostname` e gli altri) si libera con la `free` di notcurses (`ncpalette_free`), non
  con la `free` di glibc: il wrapper funziona anche con un allocatore messo da `LD_PRELOAD` (lotto 1, ICH-449).
- `Plane#erase_region`, `#gradient`, `#gradient2x1` e `#polyfill` su una sola metà di un glifo largo svuotano anche
  l'altra metà, anche quando la chiamata C fallisce a metà. I glifi da tenere interi si leggono prima della chiamata;
  una cella che notcurses non riesce a leggere (egcpool pieno, piano con un bitmap) non solleva mai, e con l'egcpool
  pieno e un riempimento con un EGC di più di 4 byte il wrapper nel dubbio svuota le due metà (lotto 1, ICH-450).
- Lo stato del controllo dei bordi dopo i resize del C vale per il piano C: un `Plane` preso in prestito usa quello
  del `Plane` tracciato, e senza un `Plane` tracciato aperto controlla i bordi a ogni scrittura (lotto 1, ICH-448).
- `Plane#merge_down` riscrive i glifi larghi di `dst` con la metà destra a width 0: `dst.at` sulla metà destra
  restituisce il glifo, e una scrittura su una delle due metà cancella il glifo intero. Il cursore di `dst` non
  cambia, anche a fine riga. La fusione legge ogni cella di `dst`: su un piano 50x200 costa qualche millisecondo
  (lotto 1, ICH-481).
- `Plane#merge_down` rilascia le copie vecchie degli EGC di più di 4 byte di `dst`: il pool non cresce più a ogni
  fusione. Se le copie nuove non entrano nel pool (EGC di `dst` per più di circa 8 MiB), annulla la fusione e solleva
  `PlaneError`. Con l'egcpool pieno riscrive anche i glifi larghi che notcurses non rilegge. Su un piano 50x200 costa
  circa 11 ms invece di 5. Un gestore `trap` non deve cambiare `dst` durante la fusione: i controlli restringono le
  finestre, non le chiudono (lotto 2, ICH-482, ICH-485).
- `Plane#resize_region` con `keep_x > 0` conserva gli EGC di più di 4 byte: il resize è in due passi quando
  `keep_x + x_off > -y_off * cols`, e i callback di resize dei figli girano due volte (la prima sul piano intermedio,
  più alto). Su un piano che ha fatto scroll i due passi conservano anche l'ordine delle righe. Costo circa 2 ms invece
  di 0,2 su 50x200 (lotto 2, ICH-215).
- `Plane#duplicate` copia anche `fixed` e l'allineamento verticale (lotto 2, ICH-216).
- I resize svuotano anche la metà orfana di un glifo largo che `ncplane_at_yx_cell` non legge (egcpool pieno); i
  piani con un bitmap restano come prima (lotto 2, ICH-487).
- `Plane::Internals` (privata) legge e scrive campi di `struct ncplane` 3.0.17; i workaround che la usano non girano
  con un'altra versione della libreria (lotto 2).
- `Plane#merge_down` ricontrolla `dst` subito prima di riscrivere il framebuffer vecchio nell'annullamento; un `trap`
  che ridimensiona `dst` in quella finestra resta documentato nello YARD. Dopo una metà sinistra orfana sull'ultima
  riga di `src`, la cella seguente diventa la metà destra del glifo largo e non svuota più il piano (lotto 2b,
  ICH-529, ICH-530).
- `Plane#resize_region` (che non conserva niente), `#rotate_cw` e `#rotate_ccw` tengono valida la cella base con un EGC
  di più di 4 byte: il wrapper la sostituisce con uno spazio durante la chiamata C e la ripristina dopo. Se il piano ha
  un callback che cambia la base, il wrapper non la tocca (lotto 2b, ICH-489).
- `Plane#at` solleva `PlaneError` su ogni piano con un bitmap (sixel e Kitty), invece di andare in segfault (lotto 2b,
  ICH-493).
- `Plane#contents` legge gli EGC di più di 4 byte anche con l'egcpool pieno, con `ncplane_at_yx` (lotto 2b, ICH-490).
- `Plane#resize_region` (che non conserva niente), `#rotate_cw` e `#rotate_ccw` non perdono più la cella base con
  l'egcpool pieno: durante la chiamata C l'EGC della base resta nel pool. Una rotazione rifiutata lascia la base com'era
  e solleva l'errore del C, non quello di `ncplane_set_base`. Un callback Ruby di resize di un figlio vede la base vera
  (prima: uno spazio); se riempie il pool falliscono le sue scritture, non la base. Senza `Plane::Internals` il
  workaround non gira. Nuovo `Context#base_restores` (`@api private`) (lotto 2c, ICH-531).
- `Plane#merge_down`: una metà sinistra orfana di `src` seguita da un glifo diventa in `dst` uno spazio con gli stessi
  stili e colori, e il glifo resta nella sua cella con i colori composti, anche largo o di più di 4 byte (prima, dal
  lotto 2b: il glifo largo intero copriva il glifo). Durante la fusione il wrapper cambia quelle metà in `src` e le
  rimette dopo. Se il glifo non entra nell'egcpool di `dst`, `PlaneError` e `dst` non cambia. Su un piano 50x200 la
  fusione costa circa 15 ms invece di 11 (lotto 2c, ICH-532).
- Con kitty `EventLoop#run` alza SIGINT, SIGSTOP e SIGQUIT per Ctrl+C, Ctrl+Z e Ctrl+\ una volta per pressione,
  subito anche con il ciclo occupato in un handler, un timer o un blocco di `post`, e anche con CapsLock o NumLock; la
  ripetizione e il rilascio non alzano niente. Durante `run` un thread di input del contesto (`InputReader`, costante
  privata) legge la coda di notcurses con `notcurses_getvec`. Il segnale si ritarda se un handler tiene il GVL, e si
  perde se nel frattempo arrivano più di 8192 tasti: limiti nello YARD di `run` (lotto 3, ICH-456, ICH-536).
- `run` segue ISIG del terminale (`stty`) anche con kitty: all'avvio spegne il flag privato di notcurses, se è acceso,
  e rimette ISIG com'era. Dopo `run` il flag resta spento: fuori da `run` un Ctrl+C di kitty non alza segnali e arriva
  al `run` successivo; `Context#linesigs_enable` ridà il compito a notcurses. Con `drain_input` il compito resta a
  notcurses (lotto 3, ICH-454, ICH-538).
- La ripetizione e il rilascio di un tasto di segnale tenuto premuto non arrivano ai `run` dopo, anche di un altro
  `EventLoop` o `App` sullo stesso contesto, anche quando l'utente lascia Ctrl prima del tasto (lotto 3, ICH-455,
  ICH-537).
- Durante `run` `Context#get` e `#getvec` leggono gli eventi del thread di input: per attendere un tasto serve `get`
  con un timeout, non `Context#inputready_fd`; dopo `run`, prima di attendere sul descrittore, serve
  `get(timeout: 0)`. `Key::EOF` resta disponibile a ogni lettura (lotto 3, ICH-536).
- Un secondo Ctrl+C durante la pulizia di `run` arriva dopo la pulizia: `run` solleva `Interrupt` invece di
  restituire `:interrupt`. Su Ruby 3.1 e 3.2 la pulizia ricomincia; restano due finestre strette (ICH-539).
  `Context#close` ferma il thread di input prima di `notcurses_stop` e solleva l'`Interrupt` arrivato mentre lo
  aspettava (lotto 3, ICH-536).
- Nuovi metodi `@api private` di `Context`: `held_signal_keys`, `linesigs_flag?`, `isig_enable`, `isig_disable`,
  `input_reader_start`, `input_reader_stop` (lotto 3).

### Cambi a `Gemfile` e `Gemfile.lock`

- Lotto 1: nessuno.
- Lotto 2: nessuno.
- Lotto 2b: nessuno.
- Lotto 2c: nessuno.
- Lotto 3: nessuno.

### Issue aperte nate dai lotti

- ICH-482 — `ncplane_mergedown` non rilascia l'egcpool di `dst` (lotto 1, audit di ICH-225).
- ICH-483 — `FFI.ncplane_putwegc` libera la stringa con la `free` di glibc, lo stesso difetto di ICH-449 nel layer FFI
  (Fase 1, regola 1) (lotto 1, audit di ICH-225).
- ICH-484 — nella vista del `Reader`, dopo Backspace, Ctrl+U e Ctrl+W, le metà destre dei glifi larghi hanno width 0
  (lotto 1, audit di ICH-225).
- ICH-485 — con l'egcpool pieno `merge_down` non riesce a riscrivere i glifi larghi e la loro metà destra resta a
  width 0 (lotto 1, review round 3; MEDIUM).
- ICH-486 — `Visual.blit_*` sopra metà di un glifo largo lascia una metà orfana (lotto 1, review; esiste già su
  `master`).
- ICH-487 — un resize che taglia un glifo largo che notcurses non riesce a leggere (egcpool pieno) lascia la metà
  sinistra orfana (lotto 1, review round 3; esiste già su `master`).
- ICH-488 — controllare `Plane#qrcode` sopra metà di un glifo largo (lotto 1, review; non verificabile con la build
  di Arch, che ha solo lo stub).
- ICH-489 — cella base dopo un resize che non conserva niente: segfault (lotto 2, primo loop).
- ICH-490 — `Plane#contents` con l'egcpool pieno (lotto 2, primo loop).
- ICH-493 — `Plane#at` su un piano con un bitmap Kitty: segfault, anche su `master` (lotto 2, primo loop).
- ICH-495 — `Stats#fbbytes`: `Canceled`, nasceva dal fix di ICH-214 tolto dal lotto (lotto 2).
- ICH-529 — `undo_merge!` controlla `dst` e poi scrive il framebuffer vecchio: un `trap` che ridimensiona `dst` in
  mezzo corrompe l'heap (lotto 2, review round 3; MEDIUM).
- ICH-530 — una metà sinistra orfana seguita da un glifo sull'ultima riga di `src`, dopo `merge_down` e le scritture
  di ICH-481, dà `free(): invalid pointer` (lotto 2, review; esiste già su `master`).
- ICH-214 — di nuovo in Backlog: ruotare il framebuffer da Ruby non si rende sicuro; va riprogettata in un lotto suo
  (lotto 2).
- ICH-532 — dopo una metà sinistra orfana sull'ultima riga di `src`, `merge_down` lascia in `dst` il glifo largo che
  copre il glifo di `src`; `dst` deve mostrare uno spazio e quel glifo (lotto 2b, scelta dell'utente; Done nel lotto
  2c).
- ICH-531 — il ripristino della cella base dopo un resize o una rotazione richiede spazio nel pool; con il pool pieno
  la base resta uno spazio (lotto 2b, review round 2; Done nel lotto 2c).
- ICH-533 — `Plane#putstr`, `#putegc` e `#puttext` sollevano `ArgumentError` invece di `PlaneError` con l'egcpool
  pieno e un EGC con segni combinanti: il controllo di `zero_width_egc!` carica l'EGC nel pool (lotto 2c, trovata
  scrivendo le spec di ICH-531; nel lotto 8 con ICH-217 e ICH-232).
- ICH-536 — con kitty il segnale di Ctrl+C arrivava solo quando `run` leggeva il tasto: non interrompeva un handler
  occupato e si perdeva con la coda piena (lotto 3, primo loop; scelta dell'utente; Done nel lotto 3).
- ICH-537 — la memoria del tasto di segnale tenuto premuto, per tasto e per contesto (lotto 3, primo loop, review
  round 3; Done nel lotto 3).
- ICH-538 — `run` chiamava `notcurses_linesigs_disable` anche con il flag già spento (lotto 3, primo loop; Done nel
  lotto 3).
- ICH-539 — su Ruby 3.1 e 3.2 un secondo segnale nel `rescue` della pulizia di `run` o di `InputReader#halt` salta il
  resto della pulizia (lotto 3, secondo loop, review; Low, in Backlog per scelta dell'utente).
