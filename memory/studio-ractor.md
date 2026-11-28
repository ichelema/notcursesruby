# Studio ICH-601 — calcolo parallelo in Ractor per le applicazioni di `Notcurses::UI`

- Data: 2026-11-28. Base: `master` `223d451`. Branch: `improvments/ICH-601-opus`.
- Stato: scelte D1–D5 **approvate dall'utente il 2026-11-28** (sezione 6). Il codice finale lo scrivono le issue di
  implementazione (sezione 7).
- Prototipo e misure: `benchmark/ractor/` (`background.rb`, `jobs.rb`, `compute.rb`, `app.rb`, `run.rb`,
  `facts.rb`; uso nell'intestazione di ogni file). Nessun cambio in `lib/`.
- Macchina a 4 core, ffi 1.17.4, Ruby 3.1.7, 3.4.12 e 4.0.7 (come eseguirli: [comandi.md](comandi.md)).

## 1. Risposta breve

- Un helper `app.background(Job, *args) { |risultato| ... }` si può fare per Ruby 3.1–4.0, senza dipendenze: il
  prototipo (`background.rb`) è circa 220 righe con i commenti. Il wrapper e notcurses restano nel Ractor principale
  (regola 3).
- **Il guadagno sicuro è la reattività**: con 4 job da 140–210 ms ciascuno la latenza mediana dei tasti scende da 188–442 ms
  (calcolo nell'handler o in `Thread`) a 0,1–8,4 ms, su tutte e tre le versioni. I `Thread` non aiutano.
- Il guadagno di tempo dipende dalla versione: su Ruby 4.0.7 i tre carichi vanno da 1,75x a 3,09x più veloci della
  serie; su 3.1.7 e 3.4.12 un carico con molti oggetti può essere più lento della serie (fino a 0,70x).
- L'helper deve evitare cinque trappole che un'applicazione non vede: il warning «experimental» e il testo delle
  eccezioni sullo schermo, l'attesa del Ractor che ferma il ciclo, il blocco di due attese insieme su Ruby 3.x, la
  lambda che non passa al Ractor, la copia degli argomenti che ferma il ciclo.
- Le immagini si decodificano solo nel Ractor principale: un Ractor può produrre pixel RGBA per
  `Visual.from_rgba` o `Visual.blit_rgba`.

## 2. Misure

### Calcolo senza UI (`compute.rb`)

4 job uguali, 5 ripetizioni, mediana. Un job dura circa 140–210 ms su un core. Il rapporto è il tempo in serie diviso
il tempo in 4 Ractor: sopra 1 il Ractor è più veloce.

| Carico | Ruby 3.1.7 | Ruby 3.4.12 | Ruby 4.0.7 |
| --- | --- | --- | --- |
| Segment: grapheme di un testo (pochi oggetti) | 2,74x | 2,59x | 3,09x |
| PlotData: CSV di 900 000 numeri, media mobile (molti oggetti) | 0,79x | 0,81x | 2,58x |
| Pixels: RGBA 1280x960 in grigio e a metà (Array grandi) | 3,08x | 0,70x | 1,75x |

- 4 `Thread` costano come la serie o di più (da 0,97x a 1,07x del tempo in serie), su tutte le versioni.
- Il numero di GC è quasi uguale in serie e in Ractor (per esempio PlotData 108 / 111 su 3.1.7): il GC non spiega
  i rapporti sotto 1. La causa non è provata (sezione 5).
- Il minimo e il massimo dei 4 Ractor cambiano molto fra le ripetizioni con PlotData e Pixels (per esempio PlotData su
  3.1.7: 694–1136 ms), poco con Segment (264–290 ms).
- Un job in un Ractor costa come lo stesso job nel thread (fra −5% e +10%): creare un Ractor costa 0,03–0,2 ms.

### Trasporto dei dati (`compute.rb`)

Latenza di un passaggio, dall'ora presa da chi manda all'ora presa da chi riceve, mediana di 5.

| Dati | Argomento copiato | Argomento condiviso | `send(move: true)` | Valore finale del blocco | `Ractor.main.send(move: true)` | `Ractor.main.send` con copia |
| --- | --- | --- | --- | --- | --- | --- |
| String di 16 MB | 7,1–7,8 ms | 0,02–0,03 ms | 0,01–0,03 ms | 0,01–0,03 ms | 0,01–0,02 ms | 0,7–7,6 ms |
| Array di 200 000 String | 35–40 ms | 0,01–0,06 ms | 19–27 ms | 0,03–0,04 ms | 19–32 ms | 28–42 ms |
| Array di 1 000 000 Float | 6,7–8,2 ms | 0,01–0,05 ms | 3,5–4,4 ms | 0,03–0,04 ms | 3,6–3,9 ms | 4,0–5,1 ms |

- **Un argomento non condiviso si copia nel thread che chiama `Ractor.new`**, cioè nel ciclo della UI: con 200 000
  String il thread principale si ferma 35–46 ms. Un input grande va passato frozen (`Ractor.make_shareable` costa
  quanto creare i dati).
- Il costo di `send(move: true)` lo paga quasi tutto il Ractor che manda: con 200 000 String la pausa più lunga del
  thread principale è 3,7–13,6 ms.
- Il valore finale del blocco passa senza costo, ma per riceverlo serve `take` o `value` (sezione 3, fatti 3 e 4).
- Un `Ractor::Port` di Ruby 4.0.7 costa come `Ractor.main.send`: 27 ms per 200 000 String con `move: true`.

### UI su un pty finto (`run.rb`)

4 job, 3 ripetizioni, un tasto ogni 10 ms durante il calcolo. `inline`: i job girano nell'handler, come oggi;
`thread`: un `Thread` per job e `post`; `ractor`: il prototipo, con il canale finale (D5: `Port` su 4.0.7).
Latenza: dal byte del tasto sul pty all'handler.

| Ruby | Carico | Tempo fino all'ultimo risultato, inline / thread / ractor ms | Latenza mediana, inline / thread / ractor ms | Latenza max ractor ms | Render nel calcolo, ractor |
| --- | --- | --- | --- | --- | --- |
| 3.1.7 | Segment | 802 / 798 / 454 | 404 / 269 / 0,40 | 35 | 44 |
| 3.1.7 | PlotData | 780 / 834 / 763 | 391 / 219 / 0,24 | 33 | 75 |
| 3.1.7 | Pixels | 685 / 731 / 255 | 347 / 188 / 8,4 | 129 | 14 |
| 3.4.12 | Segment | 768 / 831 / 290 | 388 / 408 / 0,54 | 24 | 30 |
| 3.4.12 | PlotData | 758 / 785 / 920 | 385 / 394 / 0,24 | 25 | 92 |
| 3.4.12 | Pixels | 645 / 620 / 783 | 322 / 307 / 0,13 | 89 | 66 |
| 4.0.7 | Segment | 857 / 880 / 306 | 442 / 426 / 0,25 | 18 | 33 |
| 4.0.7 | PlotData | 765 / 800 / 366 | 384 / 396 / 0,21 | 22 | 39 |
| 4.0.7 | Pixels | 644 / 643 / 219 | 327 / 322 / 3,90 | 108 | 15 |

- Con `inline` e `thread` il ciclo non fa quasi nessun render durante il calcolo (0–4); con `ractor` ne fa uno ogni
  10 ms circa.
- La latenza massima più alta di Pixels (89–129 ms) viene dalla consegna: ogni risultato disegna 640x480 pixel con
  `Visual.blit_rgba` nel thread del ciclo.
- Nessun modello ha scritto byte su stderr: il prototipo spegne il warning e tiene le eccezioni fuori da stderr.
- I `Thread` fermano la UI quasi come `inline`: i 4 thread di calcolo prendono il GVL, e il thread di input e il
  ciclo aspettano il loro turno.

## 3. Fatti trovati (`facts.rb`)

Uguali su Ruby 3.1.7, 3.4.12 e 4.0.7, salvo dove è scritto.

1. API: Ruby 3.1–3.4 hanno `Ractor#take`; Ruby 4.0 ha `Ractor#value`, `Ractor::Port` e `Ractor.shareable_proc`, e
   non `Ractor#take`. Tutte le versioni hanno `Ractor.select`, `Ractor#send` con `move: true` e `Ractor.make_shareable`.
2. Il primo `Ractor.new` del processo scrive su stderr «Ractor is experimental...» (3.x) o «Ractor API is experimental
   and may change in future versions of Ruby.» (4.0): in un'applicazione a schermo intero il testo va sullo schermo.
   Ruby lo scrive solo quando esiste solo il Ractor principale: con `Warning[:experimental] = false` in quel momento
   non lo scrive più, neanche con la categoria riaccesa dopo.
3. `take`, `value` e `Ractor::Port#receive` in un task di un Fiber scheduler fermano tutto il ciclo: 0 tick in 200 ms
   (`ProtoScheduler` di `benchmark/fiber/`). Un thread che attende il Ractor e passa il risultato con una `Queue`
   lascia girare il ciclo: 39–40 tick su 40.
4. **Su Ruby 3.1.7 e 3.4.12 due thread del Ractor principale che attendono insieme un'operazione di Ractor si bloccano
   per sempre**: due `take` su due Ractor diversi, oppure un `Ractor.receive` e un `take`. Su 4.0.7 no. Un solo thread
   che attende (`take` in sequenza, `Ractor.select`, `Ractor.receive`) funziona su tutte le versioni.
5. Un thread di consegna fermo in `Ractor.receive`, con i Ractor che mandano a `Ractor.main` con `move: true`, riceve
   4 risultati da 16 MB in 220–231 ms. `Ractor.new` e `Ractor#send` dal thread del ciclo, mentre il thread di
   consegna attende, funzionano anche su 3.x. Su 4.0.7 lo stesso vale con un `Ractor::Port` dedicato, e
   l'applicazione può usare intanto la coda di `Ractor.main`.
6. `Ractor.select` si sveglia con un messaggio: con `Ractor.current` fra gli argomenti su 3.x, con un `Ractor::Port`
   su 4.0.
7. Un'eccezione non gestita nel Ractor arriva come `Ractor::RemoteError` (con `cause`) e scrive 147 byte su stderr
   («terminated with exception»). Con un `rescue` nel corpo del Ractor stderr resta vuoto.
8. **Un'eccezione mandata dal Ractor arriva con classe e messaggio, ma con il backtrace vuoto**. `NoMethodError` e
   `NameError` non si copiano su 3.1.7 e 3.4.12 (`TypeError: allocator undefined for RubyVM::InstructionSequence`);
   su 4.0.7 sì. `move: true` non aiuta (`can not move Thread::Backtrace object`). Il prototipo manda il backtrace
   come array di String e lo ripristina con `set_backtrace`.
9. Il blocco di `Ractor.new` non può usare variabili esterne (`ArgumentError: can not isolate a Proc`). Una lambda del
   programma non passa come argomento (`TypeError: allocator undefined for Proc`), e `Ractor.make_shareable` la
   rifiuta perché il suo `self` (main) non è condivisibile. Passano un modulo con `self.call` e una lambda resa
   condivisibile dentro il corpo di un modulo (`self` = il modulo).
10. `require` in un Ractor non principale fallisce su 3.1.7 (`Ractor::IsolationError` su
    `Kernel::RUBYGEMS_ACTIVATION_MONITOR`); funziona su 3.4.12 e 4.0.7. Una libreria caricata prima nel Ractor
    principale funziona in tutte le versioni. Una costante non frozen letta da un Ractor solleva
    `Ractor::IsolationError`.
11. `Notcurses::FFI.ncstrwidth` e `Notcurses.strwidth` funzionano in un Ractor non principale.
12. `ncvisual_from_file` restituisce NULL senza contesto, anche nel Ractor principale: il motore delle immagini lo
    installa `notcurses_init` (`src/media/shim.c:7`), e la regola 3 vuole notcurses in un solo thread alla volta.
    Quindi un Ractor non può decodificare un'immagine con notcurses.
13. Ruby non ha `Ractor#kill`. Una cancellazione cooperativa funziona: un thread nel Ractor riceve un messaggio e
    alza un flag nella memoria locale del Ractor (`Ractor.current[:chiave]`); con un calcolo che tiene il GVL del
    Ractor il flag si alza in 50–51 ms.
14. `exit` del processo con un Ractor in un calcolo senza fine termina in 55–58 ms, con stato 0.

## 4. Proposta di design

```text
thread principale (Ractor principale)
  ciclo di EventLoop
    ├─ handler: app.background(Job, *args, on_error:) { |r| ... } → Ractor.new (argomenti frozen)
    └─ blocchi di post: il blocco del risultato o on_error, nel thread del ciclo
  thread di consegna (uno per processo) ◄── Port (4.0) / coda di Ractor.main (3.x) ◄── Ractor dei job
thread di input (InputReader, invariato)
```

1. **API (D1).** `EventLoop#background(job, *args, on_error: nil, &block)` restituisce un `Job` con `cancel` e
   `cancelled?`. `job` è un oggetto condivisibile che risponde a `call`, di solito un modulo con `self.call`; un
   altro valore solleva `ArgumentError` subito. Il blocco riceve il valore di `job.call(*args)` nel thread del ciclo,
   tramite `post`. Gli argomenti non condivisibili si copiano nel thread del chiamante: lo YARD dice di passare frozen
   un input grande. Un argomento che non si copia solleva subito.
2. **Versioni (D2).** Un solo codice per Ruby 3.1–4.0. Le differenze stanno in due costanti: il canale (D5) e la
   lettura del canale. Lo YARD dice che su Ruby 3.x il tempo totale può peggiorare con i carichi che creano molti
   oggetti (sezione 2), mentre la reattività migliora su tutte le versioni.
3. **Errori (D3).** Il corpo del Ractor fa `rescue Exception` e manda l'eccezione, il suo backtrace e la sua classe
   (`StandardError` o no), decisa sull'eccezione originale. Un'eccezione che non si copia diventa
   `RuntimeError("Classe: messaggio")`, con lo stesso backtrace. Uno `StandardError` va a `on_error:`, se c'è; senza
   `on_error:`, e per le altre eccezioni, esce da `run`, come quella di un handler (D3 di ICH-600). Un'eccezione
   dentro il blocco del risultato o dentro `on_error:` esce da `run`. `on_error:` che non risponde a `call` solleva
   `TypeError`, come `on_done:` di `Subprocess` (`subprocess.rb:77`). Lo YARD dice che il confronto per classe vale
   solo per le eccezioni che si copiano (su 3.x `NoMethodError` arriva come `RuntimeError`).
4. **Cancellazione e chiusura (D4).** `Job#cancel` manda un messaggio al Ractor, che alza un flag; il job lo controlla
   con un metodo di classe (nome da scegliere nella issue, per esempio `Notcurses::UI::Job.cancelled?`). Dopo
   `cancel` non arrivano né il blocco né `on_error:`. Il controllo sta nel blocco di `post`, non nel thread di
   consegna: un `cancel` fra l'arrivo del messaggio e il giro del ciclo deve valere, e la coda di `post` sopravvive a
   `run` (`event_loop.rb:188`). All'uscita di `run` ogni job non ancora consegnato riceve `cancel`, anche se il suo
   risultato è già nella coda di `post`; `run` non attende i Ractor.
5. **Canale (D5).** Un solo thread di consegna per processo (fatto 4), avviato al primo job. Su Ruby 4.0 riceve da un
   `Ractor::Port` dedicato; su 3.x dalla coda di `Ractor.main`, perché 3.x non ha `Port`. Lo YARD scrive il limite di
   3.x: un'applicazione che usa `Ractor.receive` nel Ractor principale prende anche i messaggi dei job, e la sua
   attesa si blocca con quella del thread di consegna. Il risultato passa con `move: true`; se non si può spostare,
   arriva come errore.
6. **Warning.** Il primo `Ractor.new` gira con `Warning[:experimental] = false` (fatto 2). La categoria è globale:
   per un istante un altro thread non vede un warning sperimentale suo. Lo stesso schema consuma il warning di
   `IO::Buffer` (D6 di ICH-600).
7. **Immagini.** Un job produce pixel RGBA in Ruby; il blocco del risultato li disegna con `Visual.from_rgba` o
   `Visual.blit_rgba` (fatto 12). Lo YARD lo dice con un esempio.
8. **Alternativa scartata per il canale.** Il valore finale del blocco passa senza costo (sezione 2), ma per riceverlo
   il thread di consegna deve usare `Ractor.select` sui Ractor aperti, con un risveglio diverso per 3.x
   (`Ractor.current`) e 4.0 (`Port`) per i job nuovi (fatto 6). Il guadagno è nella latenza del risultato, non nella
   reattività: il costo di `move: true` lo paga il Ractor che manda.

## 5. Non provato

- La causa dei rapporti sotto 1 su Ruby 3.x (sezione 2): il numero di GC non cambia; resta da misurare
  l'allocazione e il lock della VM.
- Macchine con più di 4 core, più job dei core, la memoria usata dai Ractor.
- Le misure girano su un pty finto, non su Kitty o Ghostty.
- `fork` con Ractor vivi, e un'applicazione che usa anche lei `Ractor.select`.
- Un job che chiama notcurses tramite `Notcurses::FFI` mentre il Ractor principale usa il contesto: la regola 3 lo
  vieta, e lo studio non lo prova.

## 6. Decisioni dell'utente (2026-11-28)

| Id | Scelta | Decisione | Alternativa scartata |
| --- | --- | --- | --- |
| D1 | Forma | helper `app.background(Job, *args) { \|r\| ... }` con `Job#cancel` | helper con anche `Job#wait` per i task; solo un esempio nello YARD |
| D2 | Versioni | Ruby 3.1–4.0 con un solo codice; lo YARD scrive le differenze di tempo su 3.x | solo Ruby 4.0, con un errore su 3.x |
| D3 | Errori del job | `on_error:` facoltativo, solo `StandardError`, nel thread del ciclo; senza `on_error:` esce da `run`; dopo `cancel` si scarta. Consigliata da `trinity:deep-reasoner` e `gpt-bridge:deep-reasoner` in modo indipendente | esce sempre da `run`; il blocco riceve `\|risultato, errore\|` |
| D4 | Chiusura | all'uscita di `run` i job ricevono `cancel` e il risultato si scarta; `run` non li attende | `run` attende i job |
| D5 | Canale | `Ractor::Port` su Ruby 4.0, coda di `Ractor.main` su 3.x | coda di `Ractor.main` su tutte le versioni |

## 7. Issue di implementazione

Creata in Linear il 2026-11-28 con la conferma dell'utente, in Backlog, priorità Low, collegata a ICH-601:

| Issue | Label | Contenuto |
| --- | --- | --- |
| ICH-608 | Improvement | `EventLoop#background` e `Notcurses::UI::Job` (punti 1–7; D1–D5), con spec su Ruby 3.1, 3.4 e 4.0, YARD, `CHANGELOG`, un esempio in `examples/demo.rb` e `benchmark/ractor/` adattato al codice finale. Il nome del metodo con cui il job controlla la cancellazione si sceglie prima del fix |
