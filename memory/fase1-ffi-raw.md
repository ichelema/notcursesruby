# Fase 1 — layer FFI raw: log di lavoro

- Data: 2026-10-25
- Versione mappata: notcurses 3.0.17 (`NOTCURSES_VERSION_*` di `version.h`)
- Ambiente di prova: Arch Linux, pacchetto `notcurses 3.0.17-3`, Ruby 4.0.7 (mise), gem `ffi` 1.17.4, `rspec` 3.13.2
- Nota sul percorso: il prompt chiede `Memory/fase1-ffi-raw.md`. Il filesystem (ext4) distingue maiuscole e
  minuscole, e nel progetto esisteva già la cartella vuota `memory/`: il log è in `memory/`.

## Fonti e inventario

- Header letti: `version.h`, `notcurses.h`, `nckeys.h`, `ncseqs.h`, `ncport.h`, `direct.h`.
  `direct.h` è un header pubblico (API "direct mode"): la regola "ogni funzione pubblica" include le sue 53 funzioni.
- `version.h` non è nel repository (lo genera CMake): la versione viene da `/usr/include/notcurses/version.h`.
  Gli altri header di `/usr/include/notcurses` sono identici a `notcurses/include/notcurses`.
- Inventario meccanico con `gcc -aux-info` sugli header (non un parser scritto a mano):
  - 373 funzioni API (320 in `notcurses.h`, 53 in `direct.h`). L'insieme coincide con i simboli `T` esportati da
    `libnotcurses-core.so.3` più `libnotcurses.so.3`.
  - 236 funzioni `static inline`. L'insieme coincide con i simboli di `/usr/lib/libnotcurses-ffi.so.3`.
  - 12 macro funzione da reimplementare (elenco sotto).
- `libnotcurses-sys` (Rust) è servito solo come riferimento secondario, perché è più vecchio di 3.0.17 (vedi il confronto sotto).
- Gli script di estrazione, generazione e controllo sono nello scratchpad della sessione, non nel progetto: la regola 8
  vieta tool di generazione nel deliverable. I file in `lib/` sono Ruby puro.

## Decisioni

1. **`::FFI` qualificato.** Dentro `module Notcurses::FFI` il nome `FFI` indica il modulo stesso. Per questo la gem si
   scrive sempre `::FFI` (`::FFI::Struct`, `::FFI::MemoryPointer`, `::FFI::Pointer::NULL`).
2. **Librerie.** `ffi_lib` carica tre librerie:
   - `libnotcurses`, che esporta solo `notcurses_init` e `ncdirect_init`, cioè le varianti con il supporto multimedia;
   - `libnotcurses-core`, che contiene quasi tutta l'API;
   - la libc.
   Ai nomi del prompt ho aggiunto `libnotcurses.so.3`/`libnotcurses.3.dylib` (e gli analoghi per core): senza pacchetto
   `-dev` molte distribuzioni installano solo il nome versionato.
3. **Puntatori a struct pubbliche.** Diventano `Classe.by_ref` (`NcPlaneOptions.by_ref`, ...). I vettori di struct
   restano `:pointer`, per esempio `ncinput* ni` di `notcurses_getvec`. Un ritorno `by_ref` NULL non diventa `nil`:
   diventa un'istanza con `.null? == true` (controllato con ffi 1.17.4, scritto in testa a `functions.rb`).
4. **Stringhe.** `const char*`, come parametro o come ritorno, diventa `:string`: FFI copia la stringa e `nil` vale NULL.
   I `char*` allocati dal chiamato diventano `:pointer` con `# ALLOC`, e vanno liberati con `Notcurses::FFI.free`.
   Vale anche per i parametri `char**` di uscita (`ncselector_destroy`, `ncreader_destroy`) e per
   `notcurses_stats_alloc`. I `:string` restituiti hanno encoding BINARY (ASCII-8BIT).
5. **Campi `const char*` delle struct.** Diventano `:pointer`, perché FFI non permette di scrivere un campo `:string`.
6. **Enum.** Sono `typedef :int`. Sono enum di 4 byte: gcc usa `unsigned int` per 5 enum su 6 e `int` per
   `ncloglevel_e` (che ha -1). `:int` ha la stessa dimensione e la stessa classe ABI.
7. **Callback.** Sono `:pointer` nelle firme, con `# callback: <firma C>` sopra la riga. `typedefs.rb` contiene anche
   gli alias `:fadecb`, `:ncstreamcb`, ... come documentazione per la Fase 2.
8. **`va_list` e varargs.** `va_list` diventa `:pointer` con `# REVIEW:`: da Ruby non si può costruire in modo portabile.
   `...` diventa `:varargs`, con coppie tipo/valore come vuole ruby-ffi.
9. **Alias `:ncchannel`/`:ncchannels`** (`:uint32`/`:uint64`). Non esistono nell'header C. Li ho tenuti come alias
   documentati per la Fase 2, ma nessuna firma li usa: le firme usano i tipi C reali.
10. **Inline e macro: contratto.** Ogni metodo di `inline_reimpl.rb` si comporta come un `attach_function` sulla stessa
    inline compilata in `libnotcurses-ffi.so`. Questo vuol dire:
    - stessi tipi di parametri e di ritorno;
    - interi nel range del tipo C, `true`/`false` per i bool, `::FFI::Pointer::NULL` per NULL;
    - stesse scritture attraverso i puntatori;
    - stranezze del C replicate e documentate con `# NOTE: comportamento C replicato`.
    Dove il C ha comportamento indefinito (UB), il metodo ha un comportamento definito, documentato con `# NOTE:`.
11. **Inline: fuori contratto** (scritto in testa a `inline_reimpl.rb`). Gli interi fuori dal range del tipo C vengono
    troncati con una maschera, senza `RangeError` come farebbe FFI. Float, `nil` o oggetti di tipo sbagliato danno
    un'eccezione di classe diversa da quella di FFI. Un controllo di range in 248 metodi costerebbe molto per input che
    il C stesso non definisce: la validazione spetta ai wrapper della Fase 2.
12. **NUL interno.** Una String con NUL interno su un parametro `:string` fa sollevare `ArgumentError` a ruby-ffi prima
    della chiamata C. Le reimplementazioni sollevano la stessa eccezione prima di qualsiasi effetto.
13. **Funzioni libc.** Oltre a `fopen`/`fclose` (regola 9) ho collegato `free`, `strdup`, `snprintf` (varargs),
    `wcwidth`, `wcswidth`, `wcslen`, `wcsrtombs` e `wcrtomb`. Servono alle reimplementazioni fedeli
    (`ncplane_printf*`, `ncwcsrtombs`, `nccell_strdup`, ...) e a liberare la memoria `ALLOC`.
14. **Nomi delle macro.** Le macro funzione restano metodi con il nome C, per esempio
    `Notcurses::FFI.NCCHANNEL_INITIALIZER(r, g, b)`. `NCCELL_TRIVIAL_INITIALIZER` non ha argomenti e si chiama con il
    punto (`Notcurses::FFI.NCCELL_TRIVIAL_INITIALIZER`): con `::` Ruby cerca una costante e solleva `NameError`.
15. **Aree.** Uso gli 8 separatori del prompt più due aree:
    - `NcDirect (direct.h)`: è un'API separata che non rientra in nessuna delle 8 aree;
    - `libc`: le funzioni della libc non sono funzioni di notcurses.
    Le NOTE seguono il modello `# NOTE: potrebbe appartenere a <altra area>`. Quando serve, la categoria va tra
    parentesi, per esempio `Input (wrapper di I/O, non widget)` per `ncfdplane_*`/`ncsubproc_*`.
16. **Costanti.** I `NCKEY_*` sono scritti come `PRETERUNICODEBASE + n`, come nell'header. Le stringhe di `ncseqs.h` e le
    varianti `L"..."` sono stringhe Ruby con escape `\u{...}`. `NOTCURSES_VERNUM_TWEAK` non è mappata, perché nell'header
    è una macro vuota. `NCOPTION_NO_WINCH_SIGHANDLER` vale `0x0004`: l'esempio del prompt diceva `0x0002`, ma fa fede l'header.
17. **Struct.** Le struct hanno i campi nell'ordine dell'header, compresi i bool deprecati di `ncinput` e `eff_text[4]`.
    `Timespec` esiste perché diverse firme usano `const struct timespec*`. Nessuna struct pubblica di 3.0.17 contiene una
    union, quindi non c'è nessun `# UNION:`.
18. **Intestazione (regola 7).** Tutti i file Ruby generati iniziano con le due righe `# Generated from notcurses 3.0.17` e
    `# Source: ...`: i 7 file di `lib/`, le 3 spec e il `Gemfile`. Nella spec di sanità le due righe sono l'unica
    aggiunta al codice fornito dall'utente.
19. **Spec aggiuntiva.** `spec/inline_reimpl_spec.rb` (con `spec/support/nc_oracle.rb`) confronta ogni reimplementazione
    con l'inline C vera di `libnotcurses-ffi.so.3` (l'oracolo). Se l'oracolo non si carica, la spec va in skip.
    La spec usa `termtype = "xterm-256color"`: con `TERM` assente o `dumb` funziona lo stesso.

## Problemi incontrati e soluzioni

| Problema | Soluzione |
| --- | --- |
| `gcc -aux-info` non vedeva `wcwidth` | aggiunto `-D_GNU_SOURCE` |
| `ncplane_resizecb` restituisce un puntatore a funzione e veniva letto come `int` | caso gestito nel parser; firma controllata a mano |
| Il controllo struct/costanti contro il C non trovava `NOTCURSES_VERSION_*` | aggiunto `#include <notcurses/version.h>` al programma C di controllo |
| L'oracolo non risolveva i typedef degli enum | `typedef :int` anche nell'oracolo |
| L'assemblatore di `inline_reimpl.rb` ordinava le sottoaree per prima apparizione | ordine canonico delle sottoaree e ordine dell'header dentro ogni sottoarea |
| Primo smoke test in crash: `free()` sul buffer di `ncpile_render_to_buffer` | bug di 3.0.17 (buffer interno, mmap su Linux): `# REVIEW:` sulla firma |
| `ncpile_render_to_file` causa un double free in `notcurses_stop` | bug di 3.0.17 trovato con una bisezione: `# REVIEW:` sulla firma |
| Dopo una corruzione dell'heap il crash handler di Ruby resta appeso | test lanciati con `timeout -k 5` / `-s KILL` |
| Test senza tty | `notcurses_init` su un `FILE*` di `/dev/null` con `NCOPTION_SUPPRESS_BANNERS`; stdin da `/dev/null` |
| `ncdirect_core_init` fallisce se è attivo un contesto notcurses | contesti ncdirect e notcurses usati uno dopo l'altro, mai insieme |
| `notcurses_init` con `termtype` NULL legge `TERM`: senza `TERM` o con `TERM=dumb` restituisce NULL | spec differenziale con `termtype` fisso; la spec di sanità (codice dell'utente) richiede `TERM` valido |
| Review V3: `ncplane_putnstr_yx(n, y, x, 0, nil)` sollevava `NoMethodError`, mentre il C restituisce 0 | corretto con `&.`; caso di regressione nella spec, che fallisce sul codice vecchio (prova di mutazione) |
| Review V3: `nccells_load_box(..., nil)` solleva `NoMethodError`, mentre il C scrive su `ul` e restituisce -1 | non replicato: nel C è UB (`utf8_egc_len(NULL)` legge `wc` non inizializzato, raro NULL deref). Documentato con `# NOTE:` |
| Note `ALLOC` mancanti (`notcurses_stats_alloc`, `ncselector_destroy`, `ncreader_destroy`, `nccell_strdup`, `nccell_extract`) | aggiunte |
| NOTE che nominavano categorie invece di aree | 22 NOTE riscritte con un'area vera e la categoria tra parentesi |

### Bug e stranezze di notcurses 3.0.17 trovati durante i test

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

## Verifiche eseguite

- `check_base` (programma C compilato con gcc sugli header): 217 righe `sizeof`/`_Alignof`/`offsetof` identiche al C per
  le 26 struct; 340 costanti (301 `#define` più 39 enumeratori) uguali al C; completezza contro `#define` ed enum.
- `check_full` (`require 'notcurses/ffi'` con una spia su `attach_function`):
  - 383 `attach_function` (373 API più 10 libc), con tipi uguali alla mappatura meccanica;
  - 248 metodi inline e macro, con arità uguale al C;
  - intestazione presente in ogni file.
- `bundle exec rspec`: 257 esempi, 0 fallimenti. La spec differenziale da sola (254 esempi, circa 215.000 confronti)
  passa anche senza `TERM`, con `TERM=dumb` e con altri seed (`NC_SPEC_SEED`).
- AddressSanitizer su 7 seed: 0 errori.
- Mutation testing: 19 mutanti su 20 trovati dalla spec (l'unico sopravvissuto è equivalente); 49 su 49 nei test del
  gruppo I2; per la correzione di V3 il mutante fa fallire i 2 esempi attesi.
- Review indipendenti dopo la generazione: firme (V2), semantica delle inline (V3), completezza contro il prompt (V4).
  V2 e V4 non hanno trovato bug funzionali; le correzioni accettate sono nella tabella sopra.
- Non verificato: Ruby 3.1 non è installato. La compatibilità con Ruby >= 3.1 è controllata solo con grep (nessuna
  funzionalità successiva alla 3.1). Non ho provato i test da un terminale interattivo: l'ambiente di lavoro non ha `/dev/tty`.

## Confronto con libnotcurses-sys (regola 4)

La regola 4 dice che le funzioni "reimplemented" del Rust "sono le stesse" inline del C. Per 3.0.17 non è vero:
`libnotcurses-sys` è più vecchio. Ho seguito l'header C, che è la fonte della mappatura.

- Il Rust reimplementa 219 funzioni. 195 sono in comune con le 236 inline del C.
- 41 inline del C mancano nei `reimplemented.rs`:
  - 2 esistono in altra forma: `nccapability_canchangecolor` in `capabilities.rs` e `ncplane_move_rel` (in Rust `ncplane_moverel`);
  - 39 mancano del tutto: `ncqprefix`, `nciprefix`, `ncbprefix`, `nccell_load_char`, `nccell_load_egc32`,
    `nccell_load_ucs32`, `nccell_set_fg_rgb8_clipped`, `nccell_set_bg_rgb8_clipped`, `ncchannel_set_rgb8_clipped`,
    `ncchannels_set_fg_rgb8_clipped`, `ncchannels_set_bg_rgb8_clipped`, `ncdirect_light_box`, `ncdirect_heavy_box`,
    `ncdirect_ascii_box`, `ncdirect_canoctant`, `notcurses_canoctant`, `nckey_pua_p`, `nckey_supppuaa_p`,
    `nckey_supppuab_p`, `ncplane_descendant_p`, `ncplane_printf`, `ncplane_printf_yx`, `ncplane_printf_aligned`,
    `ncplane_printf_stained`, `ncplane_vprintf`, `ncplane_pututf32_yx`, `ncplane_putwc`, `ncplane_putwc_yx`,
    `ncplane_putwc_stained`, `ncplane_putwc_utf32`, `ncplane_putwegc`, `ncplane_putwegc_yx`, `ncplane_putwstr`,
    `ncplane_putwstr_yx`, `ncplane_putwstr_aligned`, `nctabbed_hdrchan`, `nctabbed_selchan`, `nctabbed_sepchan`, `ncwcsrtombs`.
  Tutte e 41 sono reimplementate in Ruby.
- 24 funzioni Rust non sono inline del C 3.0.17:
  - 11 sono funzioni API esportate, quindi collegate con `attach_function`: `ncdirect_capabilities`,
    `ncdirect_hline_interp`, `ncdirect_vline_interp`, `ncplane_channels`, `ncplane_set_channels`,
    `ncplane_set_bchannel`, `ncplane_set_fchannel`, `ncplane_gradient`, `ncplane_putchar_stained`,
    `ncplane_putegc_stained`, `ncplane_putegc_yx`;
  - 13 non esistono nel C 3.0.17 e non sono mappate (mappatura 1:1): `ncchannel_set_r`/`_g`/`_b`,
    `ncchannel_set_not_default`, `ncchannels_set_default`, `ncchannels_set_not_default`,
    `ncchannels_set_fg_not_default`, `ncchannels_set_bg_not_default`, `ncplane_set_default`, `ncplane_set_not_default`,
    `ncplane_set_fg_not_default`, `ncplane_set_bg_not_default`, `ncplane_moverel`.
- Il Rust non reimplementa nessuna delle 12 macro funzione; Ruby le reimplementa tutte.

## Funzioni inline reimplementate (lista completa)

248 metodi in `lib/notcurses/ffi/inline_reimpl.rb`: 236 `static inline` e 12 macro funzione. Le macro sono
`NOTCURSES_VERSION_COMPARABLE`, `preterunicode`, `NCCHANNEL_INITIALIZER`, `NCCHANNELS_INITIALIZER`,
`NCCELL_INITIALIZER`, `NCCELL_CHAR_INITIALIZER`, `NCCELL_TRIVIAL_INITIALIZER`, `htole`, `NCMETRICFWIDTH`,
`NCPREFIXFMT`, `NCIPREFIXFMT` e `NCBPREFIXFMT`. Nell'elenco i nomi sono raggruppati per area e sottoarea, nell'ordine del file.

**Notcurses lifecycle** (19)

- version: `NOTCURSES_VERSION_COMPARABLE`
- stdplane: `notcurses_top`, `notcurses_bottom`, `notcurses_stddim_yx`, `notcurses_stddim_yx_const`, `notcurses_term_dim_yx`
- rendering: `notcurses_render`
- capabilities: `nccapability_canchangecolor`, `notcurses_cantruecolor`, `notcurses_canchangecolor`, `notcurses_canfade`, `notcurses_canutf8`, `notcurses_canhalfblock`, `notcurses_canquadrant`, `notcurses_cansextant`, `notcurses_canoctant`, `notcurses_canbraille`, `notcurses_canpixel`
- utilità: `notcurses_align`

**NcPlane** (75)

- creazione: `ncplane_resize_simple`
- relazioni: `ncplane_descendant_p`
- geometria: `ncplane_dim_y`, `ncplane_dim_x`, `ncplane_halign`, `ncplane_valign`
- z-order: `ncplane_move_rel`, `ncplane_move_top`, `ncplane_move_bottom`, `ncplane_move_family_top`, `ncplane_move_family_bottom`
- cursore: `ncplane_cursor_y`, `ncplane_cursor_x`
- output: `ncplane_putc`, `ncplane_putchar_yx`, `ncplane_putchar`, `ncplane_putegc`, `ncwcsrtombs`, `ncplane_putwegc`, `ncplane_putwegc_yx`, `ncplane_putstr_yx`, `ncplane_putstr`, `ncplane_putstr_aligned`, `ncplane_putstr_stained`, `ncplane_putnstr_yx`, `ncplane_putnstr`, `ncplane_putwstr_yx`, `ncplane_putwstr_aligned`, `ncplane_putwstr`, `ncplane_pututf32_yx`, `ncplane_putwc_yx`, `ncplane_putwc`, `ncplane_putwc_utf32`, `ncplane_putwc_stained`, `ncplane_vprintf`, `ncplane_printf`, `ncplane_printf_yx`, `ncplane_printf_aligned`, `ncplane_printf_stained`
- linee e box: `ncplane_hline`, `ncplane_vline`, `ncplane_box_sized`, `ncplane_perimeter`, `ncplane_rounded_box`, `ncplane_perimeter_rounded`, `ncplane_rounded_box_sized`, `ncplane_double_box`, `ncplane_ascii_box`, `ncplane_perimeter_double`, `ncplane_double_box_sized`
- nccell (contenuto e stile): `NCCELL_INITIALIZER`, `NCCELL_CHAR_INITIALIZER`, `NCCELL_TRIVIAL_INITIALIZER`, `nccell_init`, `nccell_prime`, `nccell_set_styles`, `nccell_styles`, `nccell_on_styles`, `nccell_off_styles`, `nccell_double_wide_p`, `nccell_wide_right_p`, `nccell_wide_left_p`, `nccell_cols`, `nccell_strdup`, `nccell_extract`, `nccellcmp`, `nccell_load_char`, `nccell_load_egc32`, `nccell_load_ucs32`, `nccells_load_box`, `nccells_ascii_box`, `nccells_double_box`, `nccells_rounded_box`, `nccells_light_box`, `nccells_heavy_box`

**Input** (19)

- nckey: `preterunicode`, `nckey_synthesized_p`, `nckey_pua_p`, `nckey_supppuaa_p`, `nckey_supppuab_p`, `nckey_mouse_p`
- ncinput: `ncinput_shift_p`, `ncinput_ctrl_p`, `ncinput_alt_p`, `ncinput_meta_p`, `ncinput_super_p`, `ncinput_hyper_p`, `ncinput_capslock_p`, `ncinput_numlock_p`, `ncinput_equal_p`, `ncinput_nomod_p`
- lettura: `notcurses_get_nblock`, `notcurses_get_blocking`
- mouse e segnali: `notcurses_mice_disable`

**Channels / Colors** (96)

- ncchannel: `NCCHANNEL_INITIALIZER`, `ncchannel_alpha`, `ncchannel_set_alpha`, `ncchannel_default_p`, `ncchannel_set_default`, `ncchannel_palindex_p`, `ncchannel_palindex`, `ncchannel_set_palindex`, `ncchannel_rgb_p`, `ncchannel_r`, `ncchannel_g`, `ncchannel_b`, `ncchannel_rgb`, `ncchannel_rgb8`, `ncchannel_set_rgb8`, `ncchannel_set`, `ncchannel_set_rgb8_clipped`
- ncchannels: `NCCHANNELS_INITIALIZER`, `ncchannels_bchannel`, `ncchannels_fchannel`, `ncchannels_channels`, `ncchannels_bg_rgb_p`, `ncchannels_fg_rgb_p`, `ncchannels_bg_alpha`, `ncchannels_set_bchannel`, `ncchannels_set_fchannel`, `ncchannels_set_channels`, `ncchannels_set_bg_alpha`, `ncchannels_fg_alpha`, `ncchannels_set_fg_alpha`, `ncchannels_reverse`, `ncchannels_combine`, `ncchannels_fg_palindex`, `ncchannels_bg_palindex`, `ncchannels_fg_rgb`, `ncchannels_bg_rgb`, `ncchannels_fg_rgb8`, `ncchannels_bg_rgb8`, `ncchannels_set_fg_rgb8`, `ncchannels_set_fg_rgb8_clipped`, `ncchannels_set_fg_palindex`, `ncchannels_set_fg_rgb`, `ncchannels_set_bg_rgb8`, `ncchannels_set_bg_rgb8_clipped`, `ncchannels_set_bg_palindex`, `ncchannels_set_bg_rgb`, `ncchannels_fg_default_p`, `ncchannels_fg_palindex_p`, `ncchannels_bg_default_p`, `ncchannels_bg_palindex_p`, `ncchannels_set_fg_default`, `ncchannels_set_bg_default`
- colori del piano: `ncplane_bchannel`, `ncplane_fchannel`, `ncplane_fg_rgb`, `ncplane_bg_rgb`, `ncplane_fg_alpha`, `ncplane_fg_default_p`, `ncplane_bg_alpha`, `ncplane_bg_default_p`, `ncplane_fg_rgb8`, `ncplane_bg_rgb8`
- colori della cella: `nccell_set_fg_default`, `nccell_set_bg_default`, `nccell_set_fg_alpha`, `nccell_set_bg_alpha`, `nccell_set_bchannel`, `nccell_set_fchannel`, `nccell_set_channels`, `nccell_channels`, `nccell_bchannel`, `nccell_fchannel`, `nccell_fg_rgb`, `nccell_bg_rgb`, `nccell_fg_alpha`, `nccell_bg_alpha`, `nccell_fg_rgb8`, `nccell_bg_rgb8`, `nccell_set_fg_rgb8`, `nccell_set_fg_rgb8_clipped`, `nccell_set_fg_rgb`, `nccell_set_fg_palindex`, `nccell_fg_palindex`, `nccell_set_bg_rgb8`, `nccell_set_bg_rgb8_clipped`, `nccell_set_bg_rgb`, `nccell_set_bg_palindex`, `nccell_bg_palindex`, `nccell_fg_default_p`, `nccell_fg_palindex_p`, `nccell_bg_default_p`, `nccell_bg_palindex_p`
- palette: `ncpalette_set_rgb8`, `ncpalette_set`, `ncpalette_get`, `ncpalette_get_rgb8`

**NcVisual** (12)

- ncvisual: `ncvisualplane_create`
- ncpixel: `htole`, `ncpixel_a`, `ncpixel_r`, `ncpixel_g`, `ncpixel_b`, `ncpixel_set_a`, `ncpixel_set_r`, `ncpixel_set_g`, `ncpixel_set_b`, `ncpixel`, `ncpixel_set_rgb8`

**Widgets (selector, menu, reader, reel, tabbed, tree, plot, progbar)** (3)

- nctabbed: `nctabbed_hdrchan`, `nctabbed_selchan`, `nctabbed_sepchan`

**Stats / Debug** (7)

- metric: `NCMETRICFWIDTH`, `NCPREFIXFMT`, `NCIPREFIXFMT`, `NCBPREFIXFMT`, `ncqprefix`, `nciprefix`, `ncbprefix`

**NcDirect (direct.h)** (17)

- colori: `ncdirect_set_bg_rgb8`, `ncdirect_set_fg_rgb8`
- linee e box: `ncdirect_light_box`, `ncdirect_heavy_box`, `ncdirect_ascii_box`
- input: `ncdirect_get_nblock`, `ncdirect_get_blocking`
- capabilities: `ncdirect_cantruecolor`, `ncdirect_canchangecolor`, `ncdirect_canfade`, `ncdirect_canopen_images`, `ncdirect_canopen_videos`, `ncdirect_canhalfblock`, `ncdirect_canquadrant`, `ncdirect_cansextant`, `ncdirect_canoctant`, `ncdirect_canbraille`

L'area Fade / Animation non ha inline: le sue funzioni sono tutte API collegate con `attach_function`.

## Funzioni saltate

Nessuna funzione saltata.

- Tutte le 373 funzioni API sono collegate con `attach_function`. Tutte le 236 `static inline` e le 12 macro funzione
  sono reimplementate.
- Le 4 funzioni con `va_list` sono mappate, ma da Ruby non si possono chiamare in modo portabile (`# REVIEW:`).
  Sono 3 API (`ncplane_vprintf_aligned`, `ncplane_vprintf_yx`, `ncplane_vprintf_stained`) e 1 inline (`ncplane_vprintf`).
  Al loro posto si usano `ncplane_printf*` con `:varargs`.
- Non sono funzioni di notcurses, quindi non sono mappate come macro:
  - `wcwidth(w)` e `wcswidth(w, s)` di `ncport.h`, ridefinite solo per Hurd e Windows. Su Linux, macOS e BSD sono le
    funzioni della libc, collegate direttamente.
  - `_Static_assert(...)`, `RESTRICT` e gli attributi `API`/`ALLOC` usati dal compilatore.
- `NOTCURSES_VERNUM_TWEAK` è una costante vuota, non una funzione: non è mappata.
