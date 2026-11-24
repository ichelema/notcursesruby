# Prestazioni e concorrenza

Costi misurati del wrapper e dei modelli di concorrenza di Ruby, con il metodo di misura. Le misure sono del
2026-11-24 (Ruby 4.0.7, ffi 1.17.4, 4 core, `master` `a30715d`), salvo quelle «dopo il lotto 9c». Il lavoro che ne
segue è in Linear: ICH-594 (scritture, lotto 9c, fatto) e gli studi di design ICH-600 (Fiber), ICH-601 (Ractor) e
ICH-602 (GVL del rasterize) ([piano.md](piano.md)).

## Metodo

- Frame: `ncvt` 200x60 (skill `verify`), `Context.open(termtype: 'xterm-256color', suppress_banners: true)`, mediana
  di 15–40 ripetizioni. Il confronto è con la FFI diretta (`Notcurses::FFI.ncplane_*` su `plane.to_ptr`).
- Pause del GVL: un thread fa un tick ogni millisecondo e registra la pausa più lunga fra due tick.
- Terminale lento: un processo separato apre il pty, lo legge a velocità fissa e risponde a DA1 (`\e[c` →
  `\e[?62;22c`) e alla posizione del cursore (`\e[6n` → `\e[5;7R`). Il terminale finto delle spec gira nello stesso
  processo: il suo thread di lettura si ferma con il GVL, quindi non misura le pause del GVL.

## Costi base

| Operazione | Costo |
| --- | --- |
| Chiamata FFI semplice (`ncstrwidth("a")`) | 0,18 µs |
| `Guard.run { }` | 0,10 µs |
| `Mutex#synchronize` senza contesa | 0,085 µs |
| `::FFI::MemoryPointer.new(:uint)` / `FFI::NcCell.new` | 0,16 / 0,25 µs |
| Cambio di Fiber, andata e ritorno | 0,09 µs |
| Passaggio fra Thread con `Queue`, andata e ritorno | 11 µs |
| Messaggio a un Ractor, andata e ritorno / creazione di un Ractor | 11 / 28 µs |
| Stringa da 1 MB a un Ractor: copia / frozen | 518 / 8,7 µs |
| Segmentazione in grapheme di un EGC da 6 MB (`each_grapheme_cluster`) | 113 ms |
| `ncstrwidth` sullo stesso EGC | 51 ms |

## Scritture e render

- Prima del lotto 9c, schermo 200x60, wrapper contro FFI diretta: `putegc` e `putc` da 34x a 43x (costo fisso di
  circa 9 µs per chiamata contro 0,26 µs), `putstr` 1,8x con ASCII, 2,2x con CJK, 5,0x con gli accenti combinanti,
  `hline` 3,6x, `vline` 8,8x, `gradient` 1,1x. Tabella e passi in ICH-594. In `putegc("x")` `text_target!` costava
  4,4 µs su 9,1: rileggeva `dims` e `cursor`, e ogni lettura allocava due `MemoryPointer`.
- Dopo il lotto 9c (`7484deb`, 2026-11-24), `benchmark/plane_writes.rb` su un piano 60x200 con l'output su
  `/dev/null`, mediana di 5 esecuzioni, e tra parentesi `master` `5600391` sulla stessa macchina: `putegc("x")` 12,1x
  (38,4x), `putegc("é")` 8,9x (39,1x), `putegc("漢")` 8,5x (38,2x), `putc` 14,1x (30,4x), `putstr` con ASCII 1,0x
  (1,7x), con CJK 1,5x (2,3x), con gli accenti 1,5x (4,5x), `hline` 2,6x (4,7x), `vline` 5,0x (8,2x), EGC da 6 MB 4,4x
  (16,2x). `putegc("é")` e `putegc("漢")` scendono sotto 9x perché il contesto ricorda gli EGC già controllati: la
  prima volta di ogni carattere costa circa 19x.
- Dopo il lotto 9c il costo fisso di `vline` è circa 6,4 µs per chiamata contro 1,65 µs del C per una linea di 60
  celle: costruire la cella, caricarla nel C, leggere le dimensioni e controllare gli argomenti. Un percorso a parte
  è stimato a 3,4x, non provato.
- Il render di uno schermo cambiato costa circa 0,3 ms con un terminale veloce. A 100 KB/s dura 132 ms di mediana
  (201 ms al massimo) e ferma tutti gli altri thread Ruby: `ncpile_rasterize` scrive sul terminale tenendo il GVL
  (senza `blocking: true`). A 1 MB/s dura 1,4 ms.

## Concorrenza in Ruby

- I Thread non danno parallelismo al codice Ruby: 4 segmentazioni da 6 MB costano 452 ms in serie, 469 ms con 4
  Thread e 177 ms con 4 Ractor.
- Le funzioni FFI si chiamano anche da un Ractor non principale (`FFI.ncstrwidth`, `Notcurses.strwidth`). Il wrapper
  no: ha stato mutabile a livello di modulo (`Guard`, lock del contesto in `context.rb:10-11`).
- API dei Ractor: Ruby 3.1–3.4 hanno `Ractor#take` e non `Ractor::Port`; Ruby 4.0 ha `Ractor::Port` e
  `Ractor#value` e non `Ractor#take`. Ruby 4.0.7 stampa «Ractor API is experimental».
- Fiber: `Fiber.set_scheduler` esiste da Ruby 3.0, `Fiber.blocking` da 3.2 (manca in 3.1.7),
  `Fiber::Scheduler#blocking_operation_wait` da 3.4, gli hook `fiber_interrupt` e `yield` da 4.0.
- L'hook `blocking_operation_wait` non sposta le chiamate FFI con `blocking: true`: 0 chiamate su Ruby 3.4.12 e
  4.0.7 (`benchmark/fiber/hook.rb`). Ruby passa dall'hook solo `rb_nogvl` con `RB_NOGVL_OFFLOAD_SAFE`; ruby-ffi 1.17.4
  usa `rb_thread_call_without_gvl` (flag 0).
- Thread di oggi contro Fiber (studio ICH-600, `benchmark/fiber/run.rb`, Ruby 4.0.7 e 3.1.7, dettagli in
  [studio-fiber.md](studio-fiber.md)): tasto → handler 113–154 µs contro 70 µs di mediana; pipe in sola lettura
  60–85 contro 465–595 MB/s e 12–17 contro 1,6–1,9 ms di CPU per MB; con `LogView#append` tutti i modelli fanno circa
  2 MB/s e 400–510 ms di CPU per MB. Ctrl+C di kitty con un handler occupato: 101 ms con il thread di input, 450 ms
  con un Fiber.
- La gem `async` 2.46.0 chiede Ruby ≥ 3.3; l'ultima versione per Ruby 3.1 è la 2.24.0. `async` e `io-event` sono MIT.
  Scelta dell'utente del 2026-11-24: Async non diventa una dipendenza, lo studio sui Fiber la legge solo come spunto.
