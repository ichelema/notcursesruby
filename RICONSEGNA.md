# RICONSEGNA — notcursesruby

## Fase 1 — layer FFI raw

- **Data di completamento:** 2026-10-25
- **Versione mappata:** notcurses 3.0.17 (`version.h`)
- **Log dettagliato:** `memory/fase1-ffi-raw.md` (decisioni, problemi e soluzioni, lista completa delle inline, funzioni saltate)

### File generati

| File | Righe | Contenuto |
| --- | ---: | --- |
| `lib/notcurses/ffi.rb` | 28 | modulo `Notcurses::FFI`, `ffi_lib` (libnotcurses, libnotcurses-core, libc), `require` dei sotto-file |
| `lib/notcurses/ffi/typedefs.rb` | 51 | 14 typedef: 6 enum (`:int`), 6 callback (`:pointer`), 2 alias `:ncchannel`/`:ncchannels` |
| `lib/notcurses/ffi/enums.rb` | 58 | 6 enum, 39 enumeratori |
| `lib/notcurses/ffi/constants.rb` | 461 | 301 costanti: `version.h`, `#define` di `notcurses.h`/`direct.h`, `NCKEY_*` di `nckeys.h`, stringhe di `ncseqs.h` |
| `lib/notcurses/ffi/structs.rb` | 313 | 26 struct `::FFI::Struct` |
| `lib/notcurses/ffi/functions.rb` | 638 | 383 `attach_function`, divise per area |
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
| `lib/notcurses/ffi/functions.rb:43` | `ncpile_render_to_buffer` | bug di 3.0.17: senza postpaint non emette testo; `*buf` è il buffer interno di notcurses e non va liberato con `free()`, anche se l'header lo chiede |
| `lib/notcurses/ffi/functions.rb:45` | `ncpile_render_to_file` | bug di 3.0.17: non scrive su `fp` e causa un double free in `notcurses_stop` |
| `lib/notcurses/ffi/functions.rb:175` | `ncplane_vprintf_aligned` | `va_list` non costruibile da Ruby |
| `lib/notcurses/ffi/functions.rb:177` | `ncplane_vprintf_yx` | `va_list` non costruibile da Ruby |
| `lib/notcurses/ffi/functions.rb:179` | `ncplane_vprintf_stained` | `va_list` non costruibile da Ruby |
| `lib/notcurses/ffi/functions.rb:529` | `ncnmetric` | il C restituisce `buf` (memoria del chiamante) o NULL; `:string` ne restituisce una copia (`nil` se NULL) |
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
- **Fase 1:** nessun file modificato (`lib/notcurses/ffi.rb`, `lib/notcurses/ffi/`).
- **Dimensioni:** 28 file in `lib/` (12 470 righe, Fase 1 esclusa); 29 file di spec e helper (7 515 righe) più 2
  fixture (`spec/fixtures/visual/rgbw.png`, `frames.mkv`).
- **Uso:** `require 'notcurses'`; il punto di ingresso è `Notcurses::Context.open { |nc| ... }` (o
  `Notcurses::Direct.open`).

### Classi e moduli

| Classe o modulo | File | Metodi d'istanza | Metodi di classe | di cui `@api private` |
| --- | --- | ---: | ---: | ---: |
| `Notcurses` | `notcurses.rb`, `version.rb`, `format.rb`, `context.rb` | 0 | 20 | 2 |
| `Notcurses::Context` | `context.rb` | 64 | 1 | 14 |
| `Notcurses::Capabilities` | `context.rb` | 10 | 0 | 0 |
| `Notcurses::Plane` | `plane.rb` | 138 | 7 | 14 |
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
| `Notcurses::Tabbed` | `widgets/tabbed.rb` | 32 | 3 | 5 |
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
  Contando ogni definizione una sola volta i metodi pubblici sono 723. La colonna `@api private` conta i metodi
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
| `spec/notcurses/` (25 file, uno per classe o area) | 520 |
| `spec/integration/lifecycle_spec.rb`, `spec/integration/visual_spec.rb` | 20 |
| `spec/coverage_spec.rb` | 3 |
| Totale Fase 2 | 543 |
| Fase 1 (`ffi_sanity_spec.rb`, `inline_reimpl_spec.rb`) | 257 |
| **Totale** | **800, 0 fallimenti (100% pass)** |

- Stesso risultato in 5 ordini casuali (`--order rand:1234`, `4242`, `1`, `31337`, `2026`); durata circa 8 s.
- Esempi per file: plane 68, visual 72, direct 56, context 28, tabbed 28, tree 26, reel 25, plot 24, menu 23,
  reader 22, selector 19, channel 16, fd_plane 16, subprocess 15, progbar 14, multiselector 13, input 11, format 10,
  cell 8, palette 6, pixel 6, version 5, fade_context 4, stats 4, error 1.
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
  Ctrl-C termina Ruby senza `ensure` e SIGWINCH resta bloccato per sempre).

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
   dimensioni solleva `WidgetError` e va ricreato.
3. **Composizione.** I widget avanzati si possono scrivere sopra `Plane`, come `Reel` (Ruby puro: piani figli, `box`,
   `putstr`, callback di disegno). Utili: `create_child(margins:)`, gli allineamenti, le pile separate
   (`Context#create_pile`, `Plane#render_pile`), `FadeContext` per le animazioni, `Visual#stream` con un blocco.
4. **Thread.** Nessun lock interno: serve una politica (per esempio un solo thread UI, e i blocchi di `FdPlane` e
   `Subprocess` che passano i dati con una `Queue`).
5. **Bug `logrow` dopo lo scroll** (non aggirato): evitare `duplicate`, resize e `rotate` sui piani che hanno fatto
   scroll, oppure ricrearli.
6. **GVL nella Fase 1.** `ncdirect_readline`, `ncdirect_cursor_yx`, `ncdirect_cursor_move_yx`, `ncdirect_init` e
   `ncvisual_stream` sono collegate senza `blocking: true` e bloccano gli altri thread Ruby durante l'attesa. Serve una
   decisione: cambiare la Fase 1 o accettare il limite (documentato nel YARD).
7. **Test grafici.** Blitter a pixel (sixel, kitty), quadranti, sestanti e ottanti non si provano su `/dev/null`:
   serve un emulatore di terminale vero su un pty (per esempio in CI).
8. **Ruby 3.1.** Sintassi controllata con `Parser::Ruby31` su tutti i file di `lib`, ma la suite non è mai stata
   eseguita su 3.1: il build di Ruby 3.1.7 con gcc 16 fallisce su questa macchina. Serve un ambiente con Ruby 3.1 (o
   una matrice CI 3.1–4.0).
9. **Pacchetto.** Non c'è ancora un gemspec né la documentazione YARD generata (la gem `yard` non è tra le
   dipendenze).
