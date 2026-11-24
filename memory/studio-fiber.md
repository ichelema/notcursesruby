# Studio ICH-600 — Fiber al posto dei thread in `Notcurses::UI`

- Data: 2026-11-24. Base: `master` `6923f2c`. Branch: `improvments/ICH-600-opus`.
- Stato: **approvato dall'utente il 2026-11-24**, con le scelte D1–D6 (sezione 6). Il codice finale lo scrivono le
  issue di implementazione (sezione 7).
- Prototipo e misure: `benchmark/fiber/` (`run.rb`, `app.rb`, `scheduler.rb`, `fiber_app.rb`, `hook.rb`).
- Sorgenti letti come riferimento, fuori dal repository: `~/.claude/tmp/ich-600/vendor/` (async 2.24.0 e 2.46.0,
  io-event 1.11.2 e 1.22.3, fiber-profiler 0.7.1, `scheduler.c`, `thread.c`, `io.c` e `io_buffer.c` di Ruby 3.1–4.0,
  sorgente C di ffi 1.17.4). Il prototipo non contiene codice copiato da async o io-event: `NOTICE` non cambia.

## 1. Risposta breve

- Un Fiber scheduler scritto nel progetto si può fare per Ruby 3.1–4.0, senza dipendenze: circa 300–400 righe.
- I Fiber rendono più veloce e più economico il trasporto dei dati (pipe, socket): da 5 a 10 volte il throughput,
  da 6 a 11 volte meno CPU per MB, latenza da 2,5 a 6 volte più bassa (sezione 2, handler `read`). Con un handler
  costoso, per esempio `LogView#append`, la differenza sparisce.
- Il thread di input non va sostituito: un Fiber non può alzare Ctrl+C mentre un handler occupa il ciclo (D1).
- Lo scheduler ha bisogno di cinque cose che il prototipo ha trovato: `transfer` al posto di `resume`, gli hook
  `timeout_after`, `fiber_interrupt` e `yield`, una guardia «blocking» per i callback C, un render raggruppato per
  frame, e il warning di `IO::Buffer` di Ruby 4.0 consumato all'avvio.
- L'hook `blocking_operation_wait` di Ruby 3.4+ non sposta le chiamate FFI con `blocking: true`: non aiuta ICH-602.

## 2. Misure

Metodo: `ruby -Ilib benchmark/fiber/run.rb` (uso nell'intestazione del file). L'applicazione gira in un processo
figlio su un pty; il terminale finto è il processo padre, quindi non condivide il GVL con l'applicazione. I due
processi usano `CLOCK_MONOTONIC`. Macchina a 4 core, ffi 1.17.4, valori di default (500 tasti o righe, 16 MB, 5
ripetizioni). `threads` è `Notcurses::UI::App` di oggi; `fibers` è `FiberApp` del prototipo (sottoclasse di `App`
che cambia solo `run`: stesso `dispatch`, stesso `LogView`, stesso render).

### Tasto → handler `on_input`

3 corse su Ruby 4.0.7 e 4 su 3.1.7, 500 tasti per corsa. `fibers` legge l'input con un Fiber al posto del thread
di input.

| Ruby | Modello | Mediana di ogni corsa µs | p99 µs | CPU per tasto µs |
| --- | --- | --- | --- | --- |
| 4.0.7 | threads | 112,9; 127,4; 188,3 | 690–1086 | 443–576 |
| 4.0.7 | fibers | 70,4; 53,4; 115,9 | 270–722 | 383–509 |
| 3.1.7 | threads | 153,6; 143,8; 173,5; 117,8 | 338–510 | 435–538 |
| 3.1.7 | fibers | 69,3; 135,7; 122,9; 155,1 | 353–775 | 400–565 |

- Su 4.0.7 il Fiber è più veloce in tutte e 3 le corse, da 40 a 70 µs; su 3.1.7 la differenza sta dentro la
  variazione fra le corse. In ogni caso la mediana resta sotto 0,2 ms.
- I valori `fibers` sono del Fiber di input del prototipo, che D1 scarta: con il thread di input il design tiene la
  latenza di `threads`. Il guadagno dei Fiber è nel trasporto dei dati (tabella sotto), non nell'input.
- La CPU per tasto comprende un render per tasto (circa 0,4–0,5 ms): la differenza fra i modelli è piccola.
- CPU a ciclo fermo (2 corse su 4.0.7 e 3 su 3.1.7 con il metodo delle due finestre, `run.rb`): fra −35 e 61 µs/s
  in tutti e due i modelli, cioè zero entro il rumore della misura. Un risveglio con il render di uno schermo
  invariato costa 455–624 µs. Le prime corse davano 350–560 µs/s perché la finestra comprendeva il render dopo
  `ready` e la lettura del primo tasto (finding 2 della review).

### Pipe → handler

| Ruby | Modello | Handler | Mediana µs | p99 µs | MB/s | CPU ms per MB | Render nel flusso |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 4.0.7 | threads | read | 78,6 | 579,6 | 59,9 | 16,76 | 666 |
| 4.0.7 | fibers | read | 31,2 | 539,0 | 595,2 | 1,58 | 8 |
| 4.0.7 | fibers-pass | read | 25,7 | 108,0 | 546,2 | 1,80 | 4 |
| 3.1.7 | threads | read | 156,0 | 4522,2 | 84,5 | 12,15 | 472 |
| 3.1.7 | fibers | read | 28,8 | 152,3 | 544,9 | 1,56 | 18 |
| 3.1.7 | fibers-pass | read | 26,9 | 260,7 | 464,5 | 1,87 | 16 |
| 4.0.7 | threads | append | 621,8 | 1167,6 | 2,5 | 400,11 | 521 |
| 4.0.7 | fibers | append | 631,0 | 1491,4 | 2,6 | 387,16 | 0 |
| 4.0.7 | fibers-pass | append | 627,1 | 1286,3 | 2,4 | 410,53 | 355 |

- `threads`: `FdPlane` più `post`, come in [fase3-design.md](fase3-design.md), sezione 5. `fibers`: un Fiber legge
  il pipe con `readpartial`. `fibers-pass`: lo stesso Fiber cede il ciclo dopo ogni blocco.
- `read` misura il trasporto. `append` chiama `LogView#append` per ogni blocco: costa circa 400–510 ms di CPU per MB
  (2 MB/s) e copre la differenza. Su 3.1.7 due ripetizioni con 4 MB danno 716–772 µs di mediana per tutti e tre i
  modelli.
- `fibers` senza `pass` fa 0 render con `append`: il Fiber legge più lento di quanto il padre scrive, il pipe resta
  pieno, `readpartial` trova sempre dati, il Fiber non passa mai da `io_wait` e ferma ciclo, input e render. Con
  `read` il Fiber svuota il pipe prima della scrittura successiva del padre, passa da `io_wait`, e il ciclo fa
  qualche render (8 e 18). Con un render a ogni `pass` il throughput scende a 24,5 MB/s (misura preliminare, 2 MB);
  con un render al massimo ogni 16 ms quando un Fiber è ancora pronto torna a 546 MB/s.

### Ctrl+C con un handler occupato per 500 ms

Il terminale manda Ctrl+C 50 ms dopo l'inizio dell'handler. Uguale su Ruby 4.0.7 e 3.1.7 (5 ripetizioni).

| Modello | Tasto | Mediana ms | Max ms |
| --- | --- | --- | --- |
| threads | byte `0x03` | 0,1 | 0,2 |
| threads | kitty `\e[99;5u` | 101,3 | 102,1 |
| fibers | byte `0x03` | 0,1 | 0,1 |
| fibers | kitty `\e[99;5u` | 450,2 | 450,3 |
| fibers, segnali di notcurses | kitty `\e[99;5u` | 0,2 | 1,1 |

- Il byte `0x03` lo trasforma in SIGINT il kernel (ISIG): nessun modello è coinvolto.
- Con kitty il segnale lo alza il wrapper (ICH-536). Il thread di input aspetta il GVL per un quanto (100 ms, già
  scritto nello YARD di `EventLoop#run`). Il Fiber di input aspetta la fine dell'handler (450 ms). notcurses lo
  alzerebbe subito dal suo thread C, ma anche per ripetizioni e rilasci (ICH-456).

### Hook `blocking_operation_wait`

`benchmark/fiber/hook.rb`: un Fiber conta tick ogni 5 ms mentre un altro fa un'operazione di circa 100 ms.

| Operazione | Ruby 3.1.7 | Ruby 3.4.12 | Ruby 4.0.7 |
| --- | --- | --- | --- |
| `usleep` FFI con `blocking: true` | hook assente | 0 chiamate, 0 tick | 0 chiamate, 0 tick |
| `Zlib.deflate` di 64 MB (controllo) | hook assente | 4103 chiamate, 436 tick | 4103 chiamate, 765 tick |
| `IO::Buffer#copy` di 64 MB (controllo) | hook assente | 1 chiamata, 7 tick | 1 chiamata, 7 tick |

Causa: Ruby passa dall'hook solo `rb_nogvl` con il flag `RB_NOGVL_OFFLOAD_SAFE` (`thread.c` di 3.4 e 4.0); ruby-ffi
1.17.4 rilascia il GVL con `rb_thread_call_without_gvl` (flag 0, `ext/ffi_c/Call.c:344-346`).

## 3. Fatti trovati

1. `Context#get` attende con `IO#wait_readable` (`context.rb:1742`): sotto uno scheduler è già cooperativo, senza
   cambi al wrapper.
2. Gli hook obbligatori sono quattro (`block`, `unblock`, `kernel_sleep`, `io_wait`); `fiber` serve a
   `Fiber.schedule`. Ruby 4.0 scrive «Scheduler should implement #fiber_interrupt» su stderr a
   `Fiber.set_scheduler` se manca l'hook (`scheduler.c:412-413`).
3. Ruby 4.0.7 crea un `IO::Buffer` per ogni scrittura da un Fiber non bloccante, anche senza l'hook `io_write`
   (`io.c:1325-1335`, `scheduler.c:994-1002`). Il primo `IO::Buffer` del processo scrive su stderr «IO::Buffer is
   experimental»: in un'applicazione a schermo intero il testo va sullo schermo. Il warning esce una volta sola per
   processo (`io_buffer.c:170-183`, flag `static` impostato anche con la categoria spenta): lo scheduler lo consuma
   all'avvio con `Warning[:experimental]` spento per un istante. Ruby 3.1.7 e 3.4.12 non scrivono warning.
4. Senza `timeout_after`, `Timeout.timeout` in un Fiber solleva l'eccezione nel ciclo e non nel Fiber
   (`Timeout::Error` su 3.1.7, `Timeout::ExitException` su 3.4.12 e 4.0.7).
5. io-event riprende i Fiber con `transfer` (`selector/select.rb:71-83`): `Fiber.yield` torna a chi ha fatto
   `resume`, che con Fiber annidati non è il ciclo. Il prototipo usa `resume`, il design `transfer`.
6. Il risveglio di io-event 1.11.2 in Ruby puro scrive sul pipe solo se il ciclo è fermo (`selector/select.rb:38-46`): un
   `unblock` da un altro thread o da un `trap` fra il controllo della coda e `IO.select` si perde (inferenza dal
   codice). Il nostro risveglio resta incondizionato, come `EventLoop#wake`.
7. Un callback Ruby chiamato da notcurses (resize, stream, widget) gira dentro una chiamata C. Se il callback si
   sospende, un altro Fiber può rientrare in notcurses a metà chiamata, e la pila dei frame di ffi è per thread, non
   per Fiber (`ext/ffi_c/Thread.c:57-91`). Su Ruby 4.0 un callback si può sospendere anche senza I/O: dopo un
   segnale Ruby chiama l'hook `yield` (`thread.c:207-235`). Protezione: `Fiber.blocking { }` da Ruby 3.2;
   `Fiber.new(blocking: true) { }.resume` su 3.1 (idioma di io-event, `selector/select.rb:392-395`).
8. Con uno scheduler già attivo (per esempio dentro `Async { }`), `Fiber.set_scheduler` chiude quello vecchio
   (`scheduler.c`, `rb_fiber_scheduler_set`). Dentro async la chiusura termina anche il task che chiama `run`
   (inferenza da async 2.46.0, `scheduler.rb:129-173`, non eseguito). `IO.select` di oggi
   (`event_loop.rb:332`) sotto uno scheduler senza l'hook `io_select` (3.1) ferma tutto il reactor.

## 4. Proposta di design

```text
thread principale
  Fiber radice: ciclo di EventLoop = scheduler
    ├─ IO.select su: pipe di risveglio, ready_io del thread di input, IO dei task
    ├─ handler on_key / on_input / on_resize, timer, blocchi di post   (Fiber radice, come oggi)
    ├─ render: prima di ogni attesa; con un task ancora pronto, al massimo max_fps al secondo
    └─ task di app.async: Fiber non bloccanti (pipe, socket, sleep, Queue)
thread di input (InputReader, invariato) ──► ready_io
altri thread e trap ──► post: Queue + un byte sul pipe di risveglio (invariato)
```

1. **Scheduler.** Una classe privata di `Notcurses::UI` con gli hook `io_wait`, `block`, `unblock`, `kernel_sleep`,
   `fiber`, `timeout_after`, `fiber_interrupt`, `yield`, `close`. I Fiber ripartono con `transfer`. `unblock` e
   `fiber_interrupt` usano solo `Thread::Queue` e `write_nonblock`, senza Mutex: valgono anche da un `trap`. Le
   scadenze degli hook usano la lista dei `Timer` di `EventLoop` (ordine `(deadline, seq)`, `CLOCK_MONOTONIC`); un
   timer interno non conta come lavoro, quindi non causa un render.
2. **Ciclo.** `run` installa lo scheduler solo per la sua durata. Se `Fiber.scheduler` è già impostato, per
   esempio dentro `Async { }`, `run` solleva `Error` (D5). Il giro resta quello di
   [fase3-design.md](fase3-design.md), sezione 1, con due cambi: i task pronti ripartono prima dell'attesa, e con un
   task ancora pronto il ciclo fa al massimo `max_fps` render al secondo, keyword di `run` con default 60 (D4).
   Quando il ciclo sta per attendere, il render avviene subito.
3. **Input.** Il thread di input resta (D1). Gli handler restano sul Fiber del ciclo, che è bloccante: dentro un
   handler `sleep` e l'I/O fermano il ciclo come oggi. Il lavoro che attende va in un task.
4. **Task.** `app.async { |task| ... }` (D2, D3): il blocco parte subito fino alla prima attesa. `Task#wait`,
   `#stop`, `#alive?`; `Stop < Exception`, così un `rescue => e` non la ferma. All'uscita di `run` i task vivi
   ricevono `Stop` e i loro `ensure` girano. Un'eccezione non gestita di un task esce da `run` dopo la pulizia, come
   quella di un handler (D3). Un task che legge un flusso sempre pronto deve cedere il ciclo (`task.pass`).
   Dentro `run` funziona anche `Fiber.schedule`.
5. **Callback C.** Un helper privato (`Util.blocking`) esegue i trampolini sincroni in un contesto bloccante:
   `Fiber.blocking` da 3.2, un Fiber bloccante su 3.1, niente se il Fiber è già bloccante. I cinque
   `::FFI::Function.new` sono `visual.rb:1164`, `plane.rb:481`, `plane.rb:4009` (`NOOP_FADER`, restituisce solo 0),
   `widgets/tree.rb:123`, `widgets/tabbed.rb:462`. Quattro su cinque passano già da `Util.guard`, che può ospitare
   la guardia: `visual.rb:1165`, `plane.rb:482`, `widgets/tabbed.rb:463` e `widgets/tree.rb:365` (in `draw_item`,
   chiamato dal trampolino); fa eccezione solo `NOOP_FADER`. `Util.guard` ha anche un quinto chiamante,
   `fd_plane.rb:204`, nel thread di lettura di `FdPlane`: lì il Fiber è già bloccante e la guardia non fa niente. Il
   Fiber di ripiego su 3.1 cambia `Fiber.current` e i valori locali al Fiber dentro il callback.
6. **`FdPlane` e `Subprocess`.** Restano come sono: si usano anche senza `Notcurses::UI`, e cambiarli rompe l'API
   della Fase 2. Nella UI un pipe o un socket si legge in un task.
7. **Warning di Ruby 4.0.** Lo scheduler consuma il warning di `IO::Buffer` all'avvio (D6): dopo, Ruby non lo
   scrive più nel processo, neanche per l'applicazione.
8. **ICH-541.** Con gli handler sul Fiber del ciclo e la guardia dei callback, nessuna operazione del wrapper si
   sospende dentro `Guard.run` per colpa dello scheduler della UI. ICH-541 resta per i Fiber dell'applicazione fuori
   dalla UI (gruppo F).
9. **ICH-602.** Il worker pool non serve: l'hook non vede le chiamate FFI, e sposterebbe notcurses su un altro
   thread contro la regola 3.

## 5. Non provato

- `run` dentro uno scheduler di async: serve eseguire il codice di async, e lo studio lo legge soltanto.
- Il risveglio perso di io-event (fatto 6): inferenza dal codice, il nostro risveglio non ha il problema.
- `Fiber#raise` su un task che ha fatto `resume` di un Fiber interno (il `FiberError` di async 2.24.0,
  `task.rb:298-304`): da provare nel lotto dello scheduler.
- Le misure girano su un pty finto, non su Kitty o Ghostty.

## 6. Decisioni dell'utente (2026-11-24)

| Id | Scelta | Decisione | Alternativa scartata |
| --- | --- | --- | --- |
| D1 | Thread di input | resta un thread (`InputReader`): Ctrl+C di kitty entro 100 ms anche con un handler occupato | un Fiber con il filtro di Ruby (Ctrl+C dopo la fine dell'handler); un Fiber con i segnali di notcurses (torna ICH-456) |
| D2 | API dei task | `app.async { \|task\| ... }` con `Task` (`wait`, `stop`, `alive?`, `pass`) | solo `Fiber.schedule` dentro `run`, senza modo di fermare o attendere un task |
| D3 | Eccezione non gestita di un task | esce da `run`, come handler, timer e `post` | resta nel task e `Task#wait` la solleva |
| D4 | Render con task sempre pronti | keyword `max_fps:` di `run`, default 60 | limite fisso di 60 al secondo |
| D5 | Scheduler già attivo (Async) | `run` solleva `Error`; la cooperazione diventa una issue a parte se serve | `run` coopera con lo scheduler presente |
| D6 | Warning di `IO::Buffer` (Ruby 4.0) | lo scheduler lo consuma all'avvio | solo documentato nello YARD |

## 7. Issue di implementazione

Create in Linear il 2026-11-24 con la conferma dell'utente, in Backlog, priorità Low, collegate a ICH-600:

| Issue | Label | Contenuto | Relazioni |
| --- | --- | --- | --- |
| ICH-604 | Improvement | Guardia «blocking» dei callback C sincroni (punto 5) | blocca ICH-606 |
| ICH-606 | Improvement | Scheduler di `EventLoop` (punti 1, 2, 7; D1, D4–D6), con `benchmark/fiber/run.rb` adattato al codice finale | bloccata da ICH-604, blocca ICH-607 |
| ICH-607 | Improvement | `app.async` e `Task` (punto 4; D2, D3), con un esempio in `examples/demo.rb` | bloccata da ICH-606 |
| ICH-605 | Performance | `LogView#append` costa circa 400–510 ms di CPU per MB (2 MB/s) su uno schermo 60x200: difetto trovato dallo studio | — |

Su ICH-602 un commento riporta la misura dell'hook `blocking_operation_wait` (sezione 2).
