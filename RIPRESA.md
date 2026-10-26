# RIPRESA — prompt per la prossima sessione

> Avvio: incolla questo file nella nuova sessione di Claude Code, oppure scrivi «Leggi RIPRESA.md ed esegui il
> prompt». Scritto il 2026-10-26, con il repository su `5dbf71e`.

## Contesto

- **Progetto:** binding Ruby completo per notcurses 3.0.17, in `/mnt/data/Sviluppo/Progetti/notcursesruby`.
  Repository privato https://github.com/ichelema/notcursesruby, branch `master`.
- **Fase 1** (layer FFI raw, `lib/notcurses/ffi.rb` e `lib/notcurses/ffi/`): completa, commit `465418f`.
- **Fase 2** (wrapper Ruby idiomatico, gli altri 28 file di `lib/`, 12 604 righe): completa, commit `7e033bd`. Review
  indipendente e fix: commit `553aa1d` e `fe7e420`. Prova su Ruby 3.1 e fix di `FdPlane#close`: commit `5dbf71e`.
- **Stato:** 827 esempi e 0 fallimenti su Ruby 4.0.7 e 3.1.7, anche con i semi `1234`, `4242` e `7`; `ruby -w` senza
  warning; 0 problemi YARD secondo due script euristici; il wrapper chiama 477 delle 631 funzioni FFI, e le altre 154
  sono escluse con un motivo in `spec/coverage_spec.rb`.
- `notcurses/` (sorgenti C) e `libnotcurses-sys/` (binding Rust) sono submodule git. Usa `notcurses/src/` per
  controllare la semantica del C. Non usare `libnotcurses-sys/` come riferimento.

## Obiettivo

La Fase 3 aggiunge sopra l'API della Fase 2 ciò che serve a un'applicazione interattiva: il ciclo degli eventi, il
focus, il resize e i widget composti.

1. **Parte 0:** applica le decisioni dell'utente sui punti aperti della review.
2. **Parte 1:** scrivi il design e fallo approvare dall'utente.
3. **Parte 2:** implementa il design approvato, con le spec.
4. **Parte 3:** esegui i controlli finali e scrivi la documentazione.

Fuori scope, salvo una richiesta esplicita dell'utente: gemspec e pubblicazione della gem, documentazione YARD
generata, CI (punti 7, 8 e 9 di "Cosa serve alla Fase 3" in `RICONSEGNA.md`).

## Prima di iniziare

1. Fai il recall in Hindsight, bank `notcursesruby`, via REST (comando in "Comandi").
2. Leggi `RICONSEGNA.md`: la sezione "Fase 2", soprattutto "Cosa serve alla Fase 3", e la sezione "Review della
   Fase 2 e Ruby 3.1".
3. Leggi `memory/fase2-wrapper-idiomatico.md` (ciclo di vita, callback, thread e GVL, segnali, bug noti) e
   `memory/fase2-review.md` (decisioni e finding aperti).
4. Controlla `git status` e `git log --oneline -3`. Il working tree deve essere pulito, su `5dbf71e` o dopo.
5. Controlla che Ruby 3.1.7 sia installato: `MISE_EXEC_AUTO_INSTALL=false mise exec ruby@3.1.7 -- ruby -v`. Se
   manca, avvia in background il build con i comandi della sezione "Ruby 3.1" di `RICONSEGNA.md`.

## Regole vincolanti

Le regole 1–10 vengono dai prompt delle fasi precedenti. Le regole 11–14 sono nuove per la Fase 3.

1. Non cambiare la Fase 1 (`lib/notcurses/ffi/`, `lib/notcurses/ffi.rb`). Se un cambio serve, fermati e chiedi
   all'utente.
2. Ogni puntatore opaco ha un distruttore (`close` o `destroy`). Il pattern `owned:` copre i puntatori non posseduti,
   per esempio lo stdplane.
3. notcurses non è thread-safe. Il wrapper lo documenta e non aggiunge lock interni.
4. I metodi restituiscono `self` dove il chaining ha senso.
5. Nomi Ruby: `snake_case`, suffisso `?` per i predicati, nessun prefisso `nc` o `notcurses_`.
6. Ogni ritorno C che indica un errore (-1 o NULL) diventa un'eccezione con un messaggio chiaro.
7. Le opzioni con un default sono keyword arguments. Gli argomenti posizionali servono solo per i parametri
   obbligatori. `spec/notcurses/api_spec.rb` controlla le regole 5 e 7 per riflessione.
8. `define_method` e `method_missing` sono vietati: il codice deve essere leggibile e navigabile con grep.
9. Ogni metodo pubblico ha un commento YARD con `@param`, `@return` e `@raise`.
10. Dipendenze: solo la gem `ffi`. Ruby >= 3.1.
11. Le classi della Fase 3 usano l'API pubblica della Fase 2. Una chiamata FFI diretta serve solo se l'API non basta,
    con un commento che dice perché.
12. Un cambio all'API pubblica della Fase 2, oltre alla Parte 0, entra nel design e richiede l'approvazione
    dell'utente. Elenca ogni cambio in `RICONSEGNA.md`.
13. Solo il thread del ciclo degli eventi chiama notcurses. Gli altri thread (i blocchi di `FdPlane` e `Subprocess`,
    eventuali timer) passano i dati al ciclo, per esempio con una `Queue` e un pipe di risveglio. Un gestore `trap`
    non chiama notcurses: imposta un flag o sveglia il ciclo.
14. Una scelta con due letture valide spetta all'utente: chiedi con AskUserQuestion.

## Parte 0 — punti aperti della review

L'utente ha deciso il 2026-10-26:

1. `Visual.from_plane(plane, blitter:, y: 0, x: 0, rows: nil, cols: nil)` e
   `Plane#as_rgba(blitter, y: 0, x: 0, rows: nil, cols: nil)`: stessi nomi e stesse regole, e senza argomenti
   convertono tutto il piano. `y: nil` e `x: nil` valgono «posizione del cursore», `rows: nil` e `cols: nil` «fino
   al bordo»; `-1` e `0` (i valori speciali del C) sollevano `ArgumentError`. In `from_plane` le keyword `begy:`,
   `begx:`, `leny:` e `lenx:` spariscono. In `as_rgba` cambia il default di `y:` e `x:`: oggi è `nil`, cioè il
   cursore.
2. `rowstride:` in tutti i metodi di `Visual`: in `blit_rgba`, `blit_bgrx`, `blit_rgb_loose` e `blit_rgb_packed`
   `linesize:` diventa `rowstride:`.
3. `Reel#empty?` e `Tabbed#empty?`, come `Tree#empty?`.
4. `Direct` resta com'è: `print_aligned` e `hline`/`vline` con `channels:`.

Controlla anche la nota della review su `Plane#putstr`: su un piano che scorre, un testo largo quanto la riga e
seguito da `"\n"` lascia il cursore due righe sotto (`notcurses.c:1888-1890` e `1903-1904`), contro il YARD. Se il C
fa davvero così, correggi il YARD, oppure il comportamento se il fix è corto e sicuro.

Per ogni punto: prima una spec che fallisce con il codice attuale, poi il fix, poi la suite completa. I nomi vecchi
spariscono, senza alias. La Parte 0 ha un commit suo, prima della Parte 2.

## Parte 1 — design

Scrivi `memory/fase3-design.md` prima del codice. Il design copre:

1. **Ciclo degli eventi.** Una classe possiede il ciclo: attende l'input, gli eventi degli altri thread e i timer,
   consegna ogni evento e rende lo schermo al massimo una volta per giro. Punto di partenza: `IO.select` su
   `Context#inputready_fd` e su un pipe di risveglio, poi `Context#getvec` o `#get(timeout: 0)`. Il ciclo esce pulito
   su richiesta, su `Key::EOF` e su `Interrupt`: con il default `no_quit_sighandlers: true` Ctrl-C arriva come
   `Interrupt`.
2. **Focus e consegna degli eventi.** Il design dice chi ha il focus, l'ordine di Tab e Shift+Tab, il focus con il
   mouse e quali widget non ricevono il focus. Un evento va al widget con il focus (`offer_input`); se il widget non
   lo consuma, l'evento risale ai contenitori e poi ai tasti globali. Il mouse va al piano sotto il puntatore
   (`Plane#translate_abs`, z-order) e richiede `Context#mice_enable`.
3. **Resize.** `trap('WINCH')` sveglia il ciclo; il ciclo chiama `Context#refresh` e poi il layout. Con
   `no_winch_sighandler: false` arriva invece `Key::RESIZE`, solo insieme all'input successivo. Limiti noti:
   l'intestazione di `Tabbed` non segue il resize e un `Reader` ridimensionato solleva `WidgetError`, quindi vanno
   ricreati; dopo uno scroll, resize e `duplicate` permutano le righe del piano (bug `logrow`).
4. **Widget composti.** Un protocollo comune (per esempio `plane`, `offer_input`, focus, layout, `close`) e l'elenco
   dei widget. Proposta minima da far approvare: un contenitore che dispone i figli in righe o colonne, un'etichetta,
   un pulsante, un campo di testo sopra `Reader`, un elenco (sopra `Selector`, o in Ruby come `Reel`), una finestra di
   dialogo modale. Ogni widget composto segue il ciclo di vita della Fase 2: `close` idempotente e chiusura dal
   contesto prima di `notcurses_stop`.
5. **Thread.** La politica della regola 13, e il modo in cui `FdPlane` e `Subprocess` mandano i dati al ciclo.
6. **Test.** Eventi sintetici con `Input.synthesize` su un contesto su `/dev/null` (anche il mouse:
   `mice_enable` richiede un tty); il ciclo completo su un pty, come in `spec/integration/pty_spec.rb`.

Poi chiedi all'utente, con AskUserQuestion, le scelte con due letture valide: per esempio il namespace (`Notcurses`
o un sotto-modulo), lo stile degli handler (blocchi o oggetti evento), i widget da includere, un esempio eseguibile
per la prova manuale su un terminale vero. Non scrivere il codice della Parte 2 prima dell'approvazione.

## Parte 2 — implementazione

- Implementa nell'ordine del design. Ogni classe ha le sue spec in `spec/notcurses/`; il ciclo con un terminale ha un
  esempio in `spec/integration/pty_spec.rb`.
- Gli script che possono andare in crash girano nello scratchpad, in un processo figlio, con
  `timeout -k 5 -s KILL` e lo stdin da `/dev/null`.
- Vincoli della Fase 2 da rispettare:
  - `break`, `return` e `throw` in un blocco chiamato dal C diventano una `LocalJumpError`;
  - dentro un callback chiamato dal C non si distruggono né si riparentano piani (`check_not_in_callback!`);
  - `Plane.new` su un piano che ha già un `Plane` aperto solleva `ArgumentError`;
  - `FdPlane#close` aspetta il blocco in corso; su Ruby 3.1 il `kill` di `close` arriva anche a
    `String#grapheme_clusters`, quindi anche dentro i metodi di testo del wrapper;
  - la causa di A4-01 (`cellcmp_and_dupfar` non confronta la width, `internal.h:1512-1519`) può toccare le copie fra
    piani: se un widget composto copia celle fra piani, provalo con glifi larghi.
- Un difetto della Fase 2 trovato durante il lavoro segue la stessa regola: prima una spec che fallisce, poi il fix.

## Consegne

1. Codice e spec della Fase 3, con i `require` in `lib/notcurses.rb`.
2. `memory/fase3-design.md` (design approvato) e un log di lavoro `memory/fase3-<argomento>.md`: decisioni, problemi
   e soluzioni, bug di notcurses trovati, verifiche.
3. `RICONSEGNA.md`: una sezione "Fase 3" con la data, i file, le classi, i test, i cambi dell'API (Parte 0
   compresa), i bug trovati e "Cosa serve alla fase successiva". Aggiorna anche la tabella "Test".
4. Hindsight, bank `notcursesruby`: le decisioni e le cause radice (comando in "Comandi").
5. Commit separati: la Parte 0, poi uno per area della Parte 2, poi la documentazione. Conventional Commits con
   scope in italiano, poi push su `origin/master`.
6. Alla fine proponi il passo successivo e chiedi all'utente se scrivere in `RIPRESA.md` il prompt della fase
   successiva.

## Controlli finali

- Suite completa su Ruby 4.0.7 e su Ruby 3.1.7: 0 fallimenti, anche con `--order rand:1234`, `rand:4242` e `rand:7`.
  Su 3.1.7 i semi servono: la corsa di `FdPlane#close` è emersa solo con il seme `4242`.
- `ruby -w -Ilib -e 'require "notcurses"'`: nessun warning, su entrambe le versioni.
- `spec/coverage_spec.rb` passa: ogni funzione FFI è chiamata dal wrapper o esclusa con un motivo.
- `spec/notcurses/api_spec.rb` passa, anche sulle classi nuove.
- YARD: 0 problemi con gli script euristici, se esistono ancora (uso: `ruby <script> <file.rb>...`;
  `input.rb:300 to_ffi` è un falso positivo noto):

  ```text
  /home/ichelema/.claude/tmp/claude-1001/-mnt-data-Sviluppo-Progetti-notcursesruby/881ff4c3-b6e5-46db-b66a-11a45b82ccbf/scratchpad/scripts/yard_check.rb
  /home/ichelema/.claude/tmp/claude-1001/-mnt-data-Sviluppo-Progetti-notcursesruby/881ff4c3-b6e5-46db-b66a-11a45b82ccbf/scratchpad/scripts/yard_raise_check.rb
  ```

- `git diff 5dbf71e -- lib/notcurses/ffi lib/notcurses/ffi.rb Gemfile Gemfile.lock` non mostra cambi.

## Comandi

```sh
# suite completa su Ruby 4.0.7 (dalla radice del progetto)
TERM=xterm-256color timeout -k 5 -s KILL 600 bundle exec rspec < /dev/null
TERM=xterm-256color timeout -k 5 -s KILL 600 bundle exec rspec --order rand:1234 < /dev/null
# una sola spec
TERM=xterm-256color timeout -k 5 -s KILL 300 bundle exec rspec spec/notcurses/plane_spec.rb < /dev/null

# Ruby 3.1.7: Gemfile copiato fuori dal progetto (S = scratchpad della sessione). Non cambiare la versione globale
# di Ruby (4.0.7) e non usare il Gemfile.lock del progetto su 3.1.
mkdir -p "$S/gemfile31" && cp Gemfile "$S/gemfile31/Gemfile"
MISE_EXEC_AUTO_INSTALL=false BUNDLE_GEMFILE="$S/gemfile31/Gemfile" mise exec ruby@3.1.7 -- bundle install --quiet
MISE_EXEC_AUTO_INSTALL=false BUNDLE_GEMFILE="$S/gemfile31/Gemfile" TERM=xterm-256color \
  mise exec ruby@3.1.7 -- timeout -k 5 -s KILL 600 bundle exec rspec --order rand:1234 < /dev/null

# recall dal bank notcursesruby
curl -s -m 30 -X POST http://127.0.0.1:8888/v1/default/banks/notcursesruby/memories/recall \
  -H 'Content-Type: application/json' \
  -d '{"query":"decisioni Fase 2 e review, ciclo di vita, callback, thread, resize, Ruby 3.1","budget":"high","max_tokens":6000}'

# retain nel bank notcursesruby: il JSON sta in un file dello scratchpad
curl -s -m 30 -X POST http://127.0.0.1:8888/v1/default/banks/notcursesruby/memories \
  -H 'Content-Type: application/json' --data @"$S/retain.json"
```

In zsh una variabile non si divide in parole: scrivi `--order "rand:$seed"`, non `$opts` con `--order rand:N`
dentro.

Formato di `retain.json`:

```json
{"async": true, "items": [{"content": "fatto autosufficiente, con comandi e percorsi alla lettera",
  "context": "una riga che descrive il dominio", "tags": ["claude-code", "repo:notcursesruby"]}]}
```
