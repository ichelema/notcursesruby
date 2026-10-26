# RICONSEGNA — notcursesruby

## Fase 1 — layer FFI raw

- **Data di completamento:** 2026-10-25
- **Versione mappata:** notcurses 3.0.17 (`version.h`)
- **Log dettagliato:** `memory/fase1-ffi-raw.md` (decisioni, problemi e soluzioni, lista completa delle inline, funzioni saltate)
- **Modifiche successive (2026-10-26):** `blocking: true` su 8 funzioni di `functions.rb` che aspettano il terminale o
  il tempo (gli init, `ncdirect_cursor_yx`, `ncdirect_cursor_move_yx`, `ncdirect_readline`, `ncvisual_stream`);
  decisione 20 di `memory/fase1-ffi-raw.md`. Nella review della Fase 2, su autorizzazione dell'utente, anche su
  `ncdirect_render_image` e `ncdirect_raster_frame` (finding A3-02).

### File generati

| File | Righe | Contenuto |
| --- | ---: | --- |
| `lib/notcurses/ffi.rb` | 28 | modulo `Notcurses::FFI`, `ffi_lib` (libnotcurses, libnotcurses-core, libc), `require` dei sotto-file |
| `lib/notcurses/ffi/typedefs.rb` | 51 | 14 typedef: 6 enum (`:int`), 6 callback (`:pointer`), 2 alias `:ncchannel`/`:ncchannels` |
| `lib/notcurses/ffi/enums.rb` | 58 | 6 enum, 39 enumeratori |
| `lib/notcurses/ffi/constants.rb` | 461 | 301 costanti: `version.h`, `#define` di `notcurses.h`/`direct.h`, `NCKEY_*` di `nckeys.h`, stringhe di `ncseqs.h` |
| `lib/notcurses/ffi/structs.rb` | 313 | 26 struct `::FFI::Struct` |
| `lib/notcurses/ffi/functions.rb` | 646 | 383 `attach_function`, divise per area |
| `lib/notcurses/ffi/inline_reimpl.rb` | 3171 | 248 metodi Ruby (236 `static inline` e 12 macro funzione), ognuno con il C originale in commento |
| `spec/ffi_sanity_spec.rb` | 27 | spec di sanità (codice del prompt più le due righe di intestazione) |
| `spec/inline_reimpl_spec.rb` | 1970 | spec differenziale: ogni reimplementazione contro l'inline C vera |
| `spec/support/nc_oracle.rb` | 275 | oracolo: le 236 inline C collegate da `libnotcurses-ffi.so.3` |
| `Gemfile`, `Gemfile.lock` | 5 | `ffi ~> 1.15` (bloccata a 1.17.4), `rspec ~> 3.12` (3.13.2) nel gruppo `test` |
| `memory/fase1-ffi-raw.md` | 255 | log della Fase 1 |

### Totali

| Voce | Numero | Dettaglio |
| --- | ---: | --- |
| Funzioni collegate (`attach_function`) | 383 | 373 API di notcurses (320 da `notcurses.h`, 53 da `direct.h`) più 10 della libc |
| Funzioni reimplementate in Ruby | 248 | 236 `static inline` più 12 macro funzione |
| Struct | 26 | 25 struct pubbliche più `Timespec` |
| Enum | 6 | 39 enumeratori |
| Costanti | 340 | 301 in `constants.rb` (244 intere, di cui 151 `NCKEY_*`, e 57 stringhe) più 39 enumeratori |
| Typedef | 14 | 6 enum, 6 callback, 2 alias |

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
  - macOS: i nomi `.dylib` sono in `ffi_lib`, ma non sono provati.
- **Facoltativa:** `libnotcurses-ffi.so.3`, solo per la spec differenziale. Se manca, quella spec va in skip.
- **libc** (glibc su Linux): `fopen`, `fclose`, `free` e le funzioni usate dalle reimplementazioni.
- **terminfo** (database di ncurses) con una voce per il terminale, per esempio `xterm-256color`.
- **Ruby >= 3.1** (provato solo su Ruby 4.0.7), Bundler, le gem del `Gemfile`. Nessun compilatore: il progetto non ha
  C extension.

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
- **Dimensioni** (dopo la review): 28 file in `lib/` (12 594 righe, Fase 1 esclusa); 31 file di spec e helper
  (8 109 righe) più 2 fixture (`spec/fixtures/visual/rgbw.png`, `frames.mkv`).
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

### Copertura delle funzioni FFI (383 + 248)

| Voce | Funzioni |
| --- | ---: |
| Funzioni della Fase 1 | 631 (383 `attach_function`, 248 inline e macro) |
| Chiamate direttamente dal wrapper | 477 (75,6%): 317 `attach_function`, 160 inline |
| Escluse, ognuna con un motivo | 154 (24,4%) |
| - raggruppate in un metodo più generale o sostituite da un valore Ruby | 97 |
| - bug di 3.0.17: reimplementate in Ruby o non offerte | 41 |
| - non applicabili da Ruby (libc, `wchar_t`, macro di formato e di byte order, `userptr`) | 14 |
| - attesa con il GVL tenuto (`notcurses_get_blocking`, `ncdirect_get_blocking`) | 2 |

`spec/coverage_spec.rb` controlla l'elenco a ogni esecuzione: fallisce se una funzione non è né chiamata né esclusa,
se un'esclusione riguarda una funzione chiamata o inesistente, o se manca il motivo.

### Test

| Spec | Esempi |
| --- | ---: |
| `spec/notcurses/` (26 file, uno per classe o area) | 542 |
| `spec/integration/` (`lifecycle_spec.rb` 8, `visual_spec.rb` 12, `pty_spec.rb` 4) | 24 |
| `spec/coverage_spec.rb` | 3 |
| Totale Fase 2 | 569 |
| Fase 1 (`ffi_sanity_spec.rb`, `inline_reimpl_spec.rb`) | 257 |
| **Totale** | **826, 0 fallimenti (100% pass)** |

- Numeri dopo la review della Fase 2 (prima: 802 esempi). Stesso risultato in ordine casuale (semi `1234`, `4242`,
  `7`; prima della modifica del 2026-10-26 anche `1`, `31337`, `2026`); durata circa 15 s su Ruby 4.0.7.
- Esempi per file: plane 79, visual 73, direct 56, tabbed 29, context 28, reel 27, tree 27, plot 24, reader 24,
  menu 23, selector 19, channel 16, fd_plane 16, subprocess 15, progbar 14, multiselector 13, input 11, format 10,
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
   `Subprocess` che passano i dati con una `Queue`).
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
8. **Ruby 3.1.** Sintassi controllata con `Parser::Ruby31` su tutti i file di `lib`, ma la suite non è mai stata
   eseguita su 3.1: il build di Ruby 3.1.7 con gcc 16 fallisce su questa macchina. Serve un ambiente con Ruby 3.1 (o
   una matrice CI 3.1–4.0).
9. **Pacchetto.** Non c'è ancora un gemspec né la documentazione YARD generata (la gem `yard` non è tra le
   dipendenze).
10. **Finding aperti della review.** Prima di costruire sopra l'API, decidi i punti aperti della sezione "Review della
    Fase 2 e Ruby 3.1": i nomi `from:`/`channels:` di `hline` e `rowstride:`/`linesize:` di `Visual`,
    `print_aligned` contro `putstr(align:)`, i valori `-1` e `0` di `Visual.from_plane`, `empty?` in `Reel` e
    `Tabbed`.

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
- `ruby -w -Ilib -e 'require "notcurses"'`: nessun warning.
- `spec/coverage_spec.rb` passa: la review non aggiunge e non toglie chiamate FFI (477 chiamate, 154 escluse).
- YARD: 0 problemi con `yard_check.rb`; `yard_raise_check.rb` controlla 605 metodi e segnala solo il falso positivo
  noto `input.rb:300 to_ffi`, presente anche prima della review.
