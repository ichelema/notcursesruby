---
name: notcurses-man
description: Consulta l'API C di notcurses nelle man page e negli header installati prima di scrivere, rivedere o fare il debug di codice che la usa. Usa questa skill ogni volta che il compito riguarda una funzione, una struct, un flag o una costante C di notcurses — aggiungere o controllare le firme di `attach_function`, struct, enum o costanti in `lib/notcurses/ffi/`, reimplementare una funzione `static inline` in `inline_reimpl.rb`, decidere cosa deve restituire o sollevare un wrapper in `lib/notcurses/`, proprietà e ciclo di vita dei puntatori restituiti, oppure una domanda come «cosa restituisce ncplane_putstr_yx in caso di errore?» — anche se l'utente non nomina le man page. Non usarla per Ruby, gem o strumenti Ruby (per quelli c'è la skill context7-mcp).
---

# Man page di notcurses

`Notcurses::FFI` mappa l'API C 1:1 e non ha documentazione YARD: il progetto rimanda
la semantica alle man page di notcurses (README, `memory/fase4-design.md`).
Quindi leggi la documentazione C invece di rispondere a memoria: notcurses ha molte
funzioni quasi identiche (varianti `_yx`, `_aligned`, `_stained`) e dettagli come i
valori di ritorno in caso di errore o chi libera un puntatore si ricordano male con
facilità.

## Cercare un simbolo

Esegui lo script incluso dalla radice del repository (lo stesso percorso vale nei worktree):

```sh
.claude/skills/notcurses-man/scripts/ncman.sh ncplane_putstr_yx
```

Accetta qualsiasi identificatore C: funzione, struct, typedef, flag o macro. Output:

1. una riga con la versione delle man page e degli header installati (devono coincidere);
2. **MAN PAGES**: per ogni pagina `notcurses*(3)` che nomina il simbolo, la riga
   SYNOPSIS, i paragrafi che lo nominano (o ne nominano la forma base, per esempio
   `ncplane_putstr()` per `ncplane_putstr_yx`) e le regole generiche di RETURN VALUES;
3. **HEADERS**: il commento e la definizione in `/usr/include/notcurses/*.h`,
   compreso il corpo completo delle funzioni `static inline` e i campi delle struct.

Altre modalità:

```sh
.claude/skills/notcurses-man/scripts/ncman.sh --search 'scroll(ing)?'   # ricerca per concetto, in tutte le pagine
.claude/skills/notcurses-man/scripts/ncman.sh --page plane              # tutta la pagina notcurses_plane(3)
.claude/skills/notcurses-man/scripts/ncman.sh --list                    # pagine e descrizioni
```

Usa `--page` quando l'estratto non basta: alcuni paragrafi descrivono un'intera
famiglia («`ncplane_putc_yx()`, etc.») senza nominare ogni membro.

## Conciliare man page e header

Le man page e gli header a volte non concordano. Vengono dalla stessa release
(3.0.17), quindi la discordanza è in notcurses stesso, non in una differenza di
versione. Decidi in base a ciò che riguarda la domanda:

- **Linkage e firma → header.** Una funzione definita `static inline` nell'header
  non è esportata da `libnotcurses`, quindi `attach_function` non può collegarla,
  anche quando il SYNOPSIS della man page mostra un prototipo normale. Esempio:
  `notcurses_output(3)` elenca `int ncplane_putstr_yx(...)`, ma `notcurses.h` la
  definisce `static inline`. Reimplementa queste funzioni in Ruby
  (`lib/notcurses/ffi/inline_reimpl.rb`) seguendo il corpo dell'header. Prendi
  dall'header anche i tipi dei parametri e del valore di ritorno.
- **Comportamento → il codice che gira.** Per il codice `static inline` il corpo
  nell'header è l'implementazione. Per le funzioni esportate, controlla il sorgente
  nel submodule `notcurses/` (`notcurses/src/lib/`) se i testi sono in conflitto.
  Esempio: per `ncplane_putstr_yx` la man page dice che un valore negativo è un
  errore di input, mentre il corpo nell'header restituisce `-ret`, il conteggio
  negato delle colonne scritte prima del fallimento (quindi anche `0` può indicare
  un errore dopo zero colonne).
- **Intento e garanzie → man page.** Thread safety, proprietà della memoria («copia
  allocata sull'heap, il chiamante deve liberarla») e quando una chiamata è valida
  sono di solito descritti solo nella man page.

Quando i due testi sono in conflitto, scrivilo nella risposta e nomina entrambe le
fonti. Scegliere in silenzio nasconde una trappola al prossimo lettore.

## Simboli senza man page

Circa 20 funzioni di notcurses collegate in `lib/notcurses/ffi/functions.rb` non
compaiono in nessuna man page (per esempio `ncdirect_flush`, `ncblit_rgba`,
`notcurses_version`). In quel caso lo script stampa `no man page mentions …`: il
commento nell'header è l'unica documentazione. Scrivilo nella risposta invece di
colmare il vuoto a memoria. I simboli che non sono affatto negli header di notcurses
(`free`, `wcwidth`, `tcgetattr`) appartengono a libc: usa le man page di libc
(`man 3 wcwidth`).

## Sorgenti grezzi

- `notcurses/doc/man/man3/*.md`: sorgenti pandoc delle stesse pagine, identici a
  quelli installati al tag `v3.0.17`. Comodi per cercare con Grep tra le pagine.
- `notcurses/include/notcurses/`: gli stessi header di `/usr/include/notcurses`,
  tranne `version.h`, che genera CMake.
- `notcurses/src/lib/`: l'implementazione, per il comportamento che la
  documentazione lascia aperto.

## Citare

Cita la pagina come `notcurses_plane(3)` e l'header come `percorso:riga` (lo script
stampa entrambi), così l'utente può controllare l'affermazione.
