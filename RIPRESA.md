# RIPRESA — prompt per la prossima sessione

> Avvio: incolla questo file nella nuova sessione di Claude Code, oppure scrivi «Leggi RIPRESA.md ed esegui il
> prompt». Scritto il 2026-11-06, con il repository su `ab75226`, dopo la revisione completa del codice. La
> sessione corregge i difetti trovati dalla revisione, un lotto di issue Linear alla volta.

## Stato e prossimo step (aggiornato il 2026-11-14, dopo il lotto 13)

Questa sezione prevale sul resto del file quando i dati sono in conflitto.

**Stato.** I lotti 1–13 sono chiusi. Lotto 13: PR #14, merge `7f91ae7`, ICH-294, ICH-295, ICH-296, ICH-298 e
ICH-299 a Done. Scelte dell'utente: `ArgumentError` per un timeout sopra 2^31 - 1 secondi (ICH-294); `getvec` a
blocchi di 8192 slot fino a `count`, non un limite secco (ICH-295, criteri riscritti su Linear nel round 1 della
review); il timer `every` resta programmato dopo un'eccezione (ICH-296); limite di un giorno in `select_timeout`
(ICH-299). `master` è sul commit docs del lotto 13; suite: 1026 esempi, 0 fallimenti. Leggi in `RICONSEGNA.md` la
sezione "Correzioni della revisione del 2026-11-06" e il log `memory/correzioni-review.md` (lotti 1–13). Restano
aperte in Backlog, fuori dai lotti: ICH-441 (`Process.daemon`),
ICH-448 (stato del controllo dei bordi per wrapper `Plane`), ICH-449 (double free dopo `merge_down` + `Plane#at`),
ICH-450 (`polyfill`, `gradient` ed `erase_region` su metà di un glifo largo), ICH-454 (ISIG del terminale e
`ictx->linesigs` divergono), ICH-455 (Ctrl+C in coda consegnato a un `run(no_linesigs: true)` successivo), ICH-456
(segnale anche per ripetizione e rilascio del Ctrl+C di kitty), ICH-457 (drag consegnato al componente dove è
partito, `Improvement`), ICH-458 (`Direct#stream` con `:pixel` in fondo allo schermo), ICH-459
(`Container#close_parts` si ferma al primo figlio che solleva), ICH-460 (pulsanti del `Dialog` su 4-6 colonne),
ICH-461 (focus a un componente che diventa visibile fuori dal resize), ICH-463 (carattere UTF-8 a cavallo della
lettura da 8192 byte: notcurses si blocca con stdin rediretto), ICH-464 (`to_ptr` e chiamata C non atomici per un
`close` da `trap`; contiene una scelta della regola 14).

**Decisioni già prese, da non richiedere:**

- modello `opus` per i comandi del workflow;
- issue correlate ICH-214…ICH-232 fuori dai lotti;
- lotto 17 da decidere dopo il lotto 16;
- correzioni della CI nella PR del lotto, quando servono; status di Codecov informativi (`codecov.yml`);
- `git worktree remove --force` approvato per tutti i lotti, quando l'unica differenza è il submodule `notcurses` e
  `git status` è vuoto;
- nelle PR nessuna magic word (neanche `Refs`) verso issue fuori dal lotto;
- dopo il merge, il branch remoto del lotto si elimina.

**Da fare per primo:**

1. Recall in Hindsight, bank `notcursesruby`: decisioni e cause radice dei lotti 1–13 sono salvate (retain del lotto
   13: operazione `ae2f6010`).
2. Fai le verifiche di "Prima di iniziare", passi 1–5 (suite attesa: 1026 esempi, 0 fallimenti). Salta il passo 6.
3. Controlla il proxy LiteLLM con `curl -sS -m 10 http://127.0.0.1:4000/health/liveliness`. Controlla anche il
   limite di utilizzo del modello GPT: nei lotti 2 e 5 il modello restituiva `usage_limit_reached` e la review GPT
   finiva senza report; nei lotti 6–13 rispondeva. Se uno dei due controlli fallisce, dillo all'utente prima di
   iniziare: nei lotti 2 e 5 l'utente ha scelto di proseguire con il solo Fable, ma la scelta va chiesta ogni volta.
   ```sh
   curl -sS -m 60 http://127.0.0.1:4000/v1/chat/completions -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
     -H 'Content-Type: application/json' \
     -d '{"model":"claude-gpt-6-1-sol-high","max_tokens":20,"messages":[{"role":"user","content":"ok"}]}'
   ```
4. Prepara il lotto 14 (ICH-300 `nucleo-05`, stringhe congelate di `Input#utf8` e `Input#eff_text`; ICH-301
   `nucleo-07`, UTF-8 non valido in `Util.take_string`; ICH-302 `nucleo-09`, coppie valore/decimale che vanno in
   overflow in `metric` e negli helper dei prefissi; ICH-303 `nucleo-10`, YARD di `Context#refresh` e
   `#create_pile`): leggi le issue da Linear e di' all'utente il comando da lanciare,
   `/trinity:workflow:1_create-worktree master ICH-300 ICH-301 ICH-302 ICH-303 opus`. ICH-301 è tra le scelte aperte
   della regola 14: in `2_work-issue` chiedi all'utente la soluzione prima del fix. Spiega all'utente ogni scelta
   con una tabella delle opzioni e il loro effetto fuori dal lotto. Il lotto 14 tocca di nuovo `context.rb` (come i
   lotti 1 e 13) e `util.rb` (come i lotti 12 e 13).
5. Una spec che fissa un comportamento di notcurses (non un fix) può dipendere dalla build: la CI usa il pacchetto
   Arch generico. Prima della review controlla la CI della PR (`gh pr checks <n> --watch`).
6. Segui la "Procedura per ogni lotto": l'utente lancia `1_create-worktree`, `2_work-issue`, `4_review-fix-loop`,
   il merge e `5_remove-worktree`. **Dopo ogni merge esegui subito la chiusura del lotto** (passo 7 della procedura),
   senza aspettare che l'utente la chieda.

**Note:**

- `spec/integration/pty_spec.rb:170` è instabile per una gara di tempi (`getvec` si sveglia dopo il primo di 4
  tasti): nel lotto 13 è fallito una volta con il seme 4242 e mai in 25 esecuzioni isolate. Se fallisce, ripeti la
  suite prima di cercare una regressione. Non ha una issue.
- Un reviewer può non riuscire a cancellare `.review-tmp/` (permesso negato, lotto 13, round 2): in quel caso
  `git status` del worktree di review non è vuoto e `git worktree remove --force` chiede la conferma dell'utente.
  Nel prompt dei reviewer chiedi file di appoggio pochi e piccoli.
- `gem build` sulla VPS stampa warning di rdoc (7.2.0 e 8.1.0 installati insieme), non del gemspec: conta che la
  gem si costruisca e che la CI sia verde.
- Dopo l'apertura della PR la CI può partire con qualche minuto di ritardo (lotto 13): aspetta con un ciclo
  `until gh run list --branch <branch> --limit 1 | grep -q .; do sleep 15; done`, poi `gh pr checks <n> --watch`.

- Macchine: dal lotto 12 il lavoro gira su una VPS Arch, checkout in
  `/mnt/data/Sviluppo/Progetti/Personali/20261027_notcursesruby` (stesso disco di `/Dati/...`, che funziona ancora),
  notcurses 3.0.17-3 generico come la CI. In locale (CachyOS) notcurses è la build `x86_64_v4`.
- In zsh un comando in una variabile (`E="env ..."`) non si divide in parole: usa un array (`E=(env ...)`,
  `"${E[@]}"`), come nel lotto 12.
- I comandi `/trinity:workflow:*` li lancia l'utente.
- Ogni fix ha una voce nella sezione "Corretto" di `[Non rilasciato]` in `CHANGELOG.md`, nel commit del fix o in un
  commit `docs(changelog)` del lotto. Nel lotto 5 mancava ed è stato il finding del round 1.
- Podman e Ruby 3.1.7 (mise) sono installati. Su Ruby 3.1.7 usa `bundle _2.3.27_` con il `Gemfile` copiato fuori
  dal progetto (`BUNDLE_GEMFILE`), perché è installato anche Bundler 4.0.22.
- Nei worktree serve `git submodule update --init --depth 1 notcurses` prima della suite.
- Non lanciare `rspec` con cwd nel worktree principale per provare il codice di un altro worktree: `rspec` mette il
  `lib/` del cwd nel load path prima di `-I` e carica il codice di `master` (lotto 6).
- La funzione "Follow work" della mod filetree è spenta (`/config`), ma nel lotto 4 la sessione è finita lo stesso
  due volte nei worktree di review: se la sessione si trova dentro un worktree, dillo all'utente prima di rimuoverlo.
- Nei comandi non mettere `rm` né `rm -rf` (`doc`, `.yardoc` e `coverage` sono già in `.gitignore`): un comando con
  `rm` va in coda per la conferma dell'utente. Per `gem build` usa `--output` con un file nello scratchpad.
- Nei prompt dei reviewer di `4_review-fix-loop` vieta il codice che manda segnali al process group
  (`Process.kill(sig, 0)`, pid negativi), anche nei mutation test: nel lotto 7 un reviewer ne aveva messo in coda uno.
- In alternativa a `bundle _2.3.27_`, su Ruby 3.1.7 basta `mise exec ruby@3.1.7 -- rspec` dalla radice del
  worktree, senza `bundle` (lotto 7: 982 esempi, 0 fallimenti).
- Nei worktree di review serve anche `git submodule update --init --depth 1 notcurses`; per rimuoverli
  `git worktree remove` vuole `--force` per il submodule (approvato, vedi le decisioni).
- Se un reviewer GPT finisce senza report (lotto 8, round 2), chiedigli il report con `SendMessage`.
- La skill `linear` dal tool Skill parte in background senza compito (`context: fork`): per creare o leggere issue
  usa direttamente `lq` (sezione "Comandi").
- Le review Fable girano su `claude-fable-5-2` (alias `fable`), le review GPT su `claude-gpt-6-1-sol-high` (`gpt-model` in
  `agents/reviewer.md` della skill trinity, dal lotto 9).

## Contesto

- **Progetto:** binding Ruby completo per notcurses 3.0.17. Repository **privato**
  https://github.com/ichelema/notcursesruby, branch `master`. Gem `notcursesruby` 0.1.0 (Apache-2.0),
  `require 'notcurses'`; non pubblicata su rubygems.org.
- **Macchina:** checkout in `/Dati/Sviluppo/Progetti/Personali/20261027_notcursesruby` (CachyOS, Linux x86_64).
  notcurses 3.0.17-3.1 di sistema, con `libnotcurses-ffi.so.3`; Ruby 4.0.7 da mise. Ruby 3.1.7 **non** è
  installato: il controllo su 3.1 lo fa la CI.
- **Fasi 1–4:** complete (layer FFI, wrapper idiomatico, `Notcurses::UI`, pacchetto e CI). Dettagli in
  `RICONSEGNA.md`. Stato al `ab75226`: 922 esempi, 0 fallimenti, anche con i semi 1234, 4242 e 7; `ruby -w`
  senza warning; `yard doc --fail-on-warning` 0 warning e 100 % documentato; `gem build` senza warning.
- **Revisione completa del 2026-11-06:** 6 finder in sola lettura, uno per area (FFI e pacchetto, nucleo e
  contesto, piani e processi, Direct e Visual, widget, UI), poi 4 verificatori avversari con riproduzioni proprie.
  Risultato: 46 finding, 45 difetti distinti (`nucleo-04` e `ui-04` hanno la stessa causa): 7 di severità alta,
  11 media e 27 bassa. Log completo, con le prove e le parti non coperte: `memory/review-2026-11-06.md`.
- **Linear:** una issue per difetto, da ICH-268 a ICH-313 (ICH-297 non appartiene alla revisione), nel progetto `notcursesruby` del team Ichelema (`ICH`), stato
  Backlog. Priorità = severità della revisione: alta → High, media → Medium, bassa → Low. Label `Bug` o
  `Improvement`; estimate sulla scala t-shirt del team. Le issue sono in inglese (label di progetto `lang:en`).
  Ognuna ha `Problem` con una riproduzione minima in Ruby, `Acceptance criteria` e `Required tests`. Le issue
  dello stesso lotto sono collegate con relazioni `related`; nessuna relazione `blocks`, perché
  `/trinity:workflow:2_work-issue` si ferma su una issue bloccata.
- **Fase 5** (prove grafiche su Kitty e Ghostty, macOS): rimandata a dopo le correzioni. Il suo prompt completo è in
  `git show 49732a3:RIPRESA.md`. Alcune correzioni riguardano proprio i terminali della Fase 5 (SIGSEGV con i
  quadranti di Kitty e Ghostty, protocollo di tastiera kitty): per questo vengono prima.

## Obiettivo

Correggi le 45 issue della revisione nell'ordine dei lotti della sezione "Ordine di lavoro". Ogni lotto è un
worktree, un branch e una PR, con i comandi del workflow di Trinity. La fase cambia il comportamento della
libreria solo per correggere i difetti descritti nelle issue.

Fuori scope, salvo una richiesta esplicita dell'utente: nuove funzionalità o widget, le altre issue aperte del
progetto (ICH-214…ICH-232, vedi "Issue correlate"), la Fase 5, la pubblicazione della gem, Windows.

## Prima di iniziare

1. Fai il recall in Hindsight, bank `notcursesruby`, se il server risponde. Se non risponde, prosegui e dillo in una
   riga.
2. Leggi `memory/review-2026-11-06.md` (metodo, finding, prove dei verificatori, parti non coperte) e in
   `RICONSEGNA.md` le sezioni "Bug di notcurses 3.0.17 aggirati", "Finding aperti" e "Bug e limiti di notcurses
   3.0.17 trovati nella Fase 3".
3. Controlla `git status` (working tree pulito) e `git log --oneline -3` (su `ab75226` o dopo). Se manca
   `notcurses/data`: `git submodule update --init --depth 1 notcurses`.
4. Esegui `bundle install`, poi la suite completa (comando in "Comandi"): 922 esempi, 0 fallimenti.
5. Leggi da Linear le issue del primo lotto con la skill `linear` (query in "Comandi"): descrizione, acceptance
   criteria, relazioni e stato.
6. Chiedi all'utente, con AskUserQuestion:
   - il modello di implementazione da passare ai comandi del workflow (ICH-229 ha usato `opus`);
   - se aggiungere ai lotti le issue già aperte che toccano lo stesso codice (tabella "Issue correlate");
   - l'approvazione per il lotto 17, che cambia la Fase 1 (regola 1). Senza approvazione il lotto resta fuori.

## Regole vincolanti

Le regole 1–10 vengono dalle fasi precedenti, la 11 è cambiata, le regole 15–17 sono nuove.

1. Non cambiare la Fase 1 (`lib/notcurses/ffi/`, `lib/notcurses/ffi.rb`) senza l'approvazione dell'utente. Riguarda
   il lotto 17 (ICH-312, ICH-313). Le spec nuove sul layer FFI (lotto 16) non cambiano la Fase 1.
2. Ogni puntatore opaco ha un distruttore (`close` o `destroy`). Il pattern `owned:` copre i puntatori non posseduti.
3. notcurses non è thread-safe. Il wrapper lo documenta e non aggiunge lock interni.
4. I metodi restituiscono `self` dove il chaining ha senso.
5. Nomi Ruby: `snake_case`, suffisso `?` per i predicati, nessun prefisso `nc` o `notcurses_`.
6. Ogni ritorno C che indica un errore (-1 o NULL) diventa un'eccezione con un messaggio chiaro.
7. Le opzioni con un default sono keyword arguments. `spec/notcurses/api_spec.rb` controlla le regole 5 e 7.
8. `define_method` e `method_missing` sono vietati.
9. Ogni metodo pubblico ha un commento YARD con `@param`, `@return` e `@raise`.
10. Dipendenze runtime: solo la gem `ffi`. Ruby >= 3.1.
11. Ogni fix parte da una spec che fallisce sul codice attuale: prima la spec, poi il fix, poi la suite completa.
    Una spec di un crash (SIGSEGV, abort) o di un blocco esegue il caso in un processo figlio con un timeout e
    controlla lo stato di uscita, così la suite sopravvive anche prima del fix. Un bug di notcurses nuovo va nelle
    tabelle di `RICONSEGNA.md`.
12. Una dipendenza di sviluppo nuova richiede l'approvazione dell'utente e va in un gruppo del `Gemfile`. Elenca ogni
    cambio a `Gemfile` e `Gemfile.lock` in `RICONSEGNA.md`.
13. Le azioni esterne o difficili da annullare richiedono la conferma esplicita dell'utente: merge di una PR, tag,
    release, impostazioni del repository, secret, GitHub Pages. Il push dei branch dei lotti e l'apertura delle PR
    fanno parte del workflow e sono autorizzati; il push su `origin/master` resta autorizzato per i commit di sola
    documentazione.
14. Una scelta con due letture valide spetta all'utente: chiedi con AskUserQuestion. Se hai dubbi, fermati e
    chiarisci con l'utente.
15. Lingua: commit, titolo e corpo delle PR e commenti su Linear in inglese (progetto Linear con `lang:en`, come
    ICH-229: `fix(ui): ...`). `RICONSEGNA.md`, `RIPRESA.md` e `memory/` restano in italiano.
16. Un lotto tocca solo il codice delle sue issue. Se un fix richiede un cambio che appartiene a un altro lotto o a
    un'altra issue, fermati e chiedi all'utente.
17. Prima del merge di ogni PR: CI verde su tutta la matrice (Ruby 3.1.7–4.0.9) e soglie di coverage invariate (98 %
    totale, 90 % per file, layer FFI escluso).

## Ordine di lavoro

Criteri dell'ordine:

1. prima la severità: i crash e i blocchi (alta), poi i risultati sbagliati (media), poi il resto (bassa);
2. le issue che toccano lo stesso codice stanno nello stesso lotto, anche con severità diverse;
3. un lotto contiene solo issue dello stesso tipo: `/trinity:workflow:1_create-worktree` ricava un solo prefisso di
   branch, `bug` dalla label `Bug` e `improvments` dalla label `Improvement`;
4. il lotto 17 cambia la Fase 1 e chiude la lista, perché serve l'approvazione dell'utente.

| Lotto | Prefisso | Issue | Finding | Severità | Titolo |
| --- | --- | --- | --- | --- | --- |
| 1 | `bug` | ICH-268 | `nucleo-01` | alta | Harden Context#close, Direct#close and drop_planes against a Ctrl-C during the C call |
| 1 | `bug` | ICH-269 | `nucleo-02` | alta | Make Context#close and Direct#close skip the C stop in a forked child |
| 1 | `bug` | ICH-270 | `nucleo-03` | media | Make Context#close and Direct#close work inside a trap handler |
| 2 | `bug` | ICH-271 | `piani-01` | alta | Prevent heap corruption from writes over a wide glyph cut by a plane resize |
| 3 | `bug` | ICH-272 | `direct-visual-01` | alta | Reject the plot-only blitters :four_by_one and :eight_by_one in Visual and Plane#as_rgba |
| 4 | `bug` | ICH-273 | `widget-01` | alta | Keep zero-width characters out of the last Reader column |
| 4 | `bug` | ICH-274 | `widget-04` | media | Make Reader#write keep graphemes that notcurses splits into several EGCs |
| 4 | `bug` | ICH-275 | `widget-05` | media | Make Reader#contents read the view through Plane#contents to stop the egcpool leak |
| 5 | `bug` | ICH-276 | `widget-02` | alta | Reject Tree, Tabbed and Reel creation inside notcurses callbacks |
| 5 | `bug` | ICH-277 | `widget-03` | alta | Raise WidgetError in MultiSelector#offer_input when the plane is one row tall |
| 6 | `bug` | ICH-278 | `nucleo-04+ui-04` | media | Redraw the screen after SIGCONT in EventLoop and document the lost SIGCONT handler |
| 7 | `bug` | ICH-279 | `ui-01` | media | Use Input#eff_text in TextInput and on_key so Shift works under the kitty protocol |
| 7 | `bug` | ICH-280 | `ui-05` | media | Handle kitty Ctrl+C, Ctrl+Z and Ctrl+\ with CapsLock or NumLock as line signals in run |
| 7 | `bug` | ICH-281 | `ui-11` | bassa | Keep the wide glyph under the TextInput cursor visible in the last column |
| 8 | `bug` | ICH-282 | `ui-02` | media | Make LogView#append accept an empty string without breaking the view |
| 8 | `bug` | ICH-283 | `ui-03` | media | Treat repeated BUTTON1-3 presses during a mouse drag as motion, not as new clicks |
| 9 | `bug` | ICH-284 | `direct-visual-02` | media | Make Direct#stream draw each frame over the previous one |
| 10 | `bug` | ICH-285 | `direct-visual-03` | media | Apply the ZWJ workaround to Direct#putegc and Direct#print_aligned |
| 10 | `bug` | ICH-286 | `piani-02` | bassa | Measure ZWJ sequences in Plane#puttext like putstr so long words wrap |
| 11 | `bug` | ICH-287 | `widget-06` | media | Resize Tree item planes to the current tree width on every redraw |
| 11 | `bug` | ICH-288 | `widget-07` | bassa | Document the ProgBar color rule for one-column bars and non-UTF-8 terminals |
| 11 | `bug` | ICH-289 | `widget-08` | bassa | Keep the header order in Tab#move when a tab moves before its own successor |
| 11 | `bug` | ICH-290 | `widget-09` | bassa | Document that Plot label_ticks labels saturate at 184.47P above about 1.8e17 |
| 12 | `bug` | ICH-291 | `ui-06` | bassa | Roll back a UI component or Dialog when drawing raises during its creation |
| 12 | `bug` | ICH-292 | `ui-08` | bassa | Restore the focus when a resize shows components again, and let Esc reach the Dialog |
| 12 | `bug` | ICH-293 | `ui-10` | bassa | Give each Dialog button room for its whole label |
| 13 | `bug` | ICH-294 | `nucleo-06` | bassa | Bound the timeout of Context#get, #getvec and Direct#get to a documented maximum |
| 13 | `bug` | ICH-295 | `nucleo-08` | bassa | Cap the getvec buffer at the notcurses input queue size (8192 events) |
| 13 | `bug` | ICH-296 | `ui-07` | bassa | Keep an every timer scheduled after its block raises, as Timer#active? promises |
| 13 | `bug` | ICH-298 | `ui-09` | bassa | Deliver the keys already queued in notcurses at the start of EventLoop#run |
| 13 | `bug` | ICH-299 | `ui-12` | bassa | Cap the IO.select timeout of EventLoop#run for huge after/every delays |
| 14 | `bug` | ICH-300 | `nucleo-05` | bassa | Freeze the strings returned by Input#utf8 and Input#eff_text |
| 14 | `bug` | ICH-301 | `nucleo-07` | bassa | Scrub invalid UTF-8 in Util.take_string (accountname, detected_terminal) |
| 14 | `bug` | ICH-302 | `nucleo-09` | bassa | Reject value/decimal pairs that overflow ncnmetric in metric and the prefix helpers |
| 14 | `bug` | ICH-303 | `nucleo-10` | bassa | Fix the YARD of Context#refresh and #create_pile: rendering area, not terminal size |
| 15 | `bug` | ICH-304 | `ffi-04` | bassa | Print the result after Context.open in the README Notcurses::UI example |
| 15 | `bug` | ICH-305 | `ffi-06` | bassa | Raise the ffi lower bound to ~> 1.16 in the gemspec and Gemfile |
| 16 | `improvments` | ICH-306 | `nucleo-11` | bassa | Add specs for the Alt workaround in Input#initialize (deprecated alt field) |
| 16 | `improvments` | ICH-307 | `nucleo-12` | bassa | Make the Palette#use spec check that the context palette changes |
| 16 | `improvments` | ICH-308 | `direct-visual-04` | bassa | Test negative count: as a keyword in the Direct cursor-move spec |
| 16 | `improvments` | ICH-309 | `ffi-05` | bassa | Add a spec that compares FFI struct layouts and constants with the C headers |
| 16 | `improvments` | ICH-310 | `ui-13` | bassa | Add kitty keyboard protocol and Key::RESIZE examples to ui_pty_spec |
| 16 | `improvments` | ICH-311 | `ffi-02` | bassa | Pin codecov/codecov-action to a full commit SHA in the CI workflow |
| 17 | `bug` | ICH-312 | `ffi-01` | bassa | Release the GVL in the FFI functions that open or decode media files |
| 17 | `bug` | ICH-313 | `ffi-03` | bassa | Define wchar_t and uintmax_t when ffi lacks them so require works on BSD and ppc64 |

Ogni lotto parte da `master` aggiornato, dopo il merge del lotto precedente. I lotti 13 e 14 toccano di nuovo
`context.rb`, i lotti 8 e 12 di nuovo `app.rb`: per questo non vanno lavorati in parallelo.

### Issue correlate

Le issue aperte qui sotto toccano lo stesso codice o la stessa causa di una issue della revisione. Sono collegate
con una relazione `related`. Unirle a un lotto è una scelta dell'utente (passo 6 di "Prima di iniziare").

| Issue della revisione | Issue già aperte |
| --- | --- |
| ICH-268 (`nucleo-01`) | ICH-226, ICH-222 |
| ICH-269 (`nucleo-02`) | ICH-222 |
| ICH-271 (`piani-01`) | ICH-215 |
| ICH-273 (`widget-01`) | ICH-218 |
| ICH-274 (`widget-04`) | ICH-217, ICH-232 |
| ICH-282 (`ui-02`) | ICH-230 |
| ICH-287 (`widget-06`) | ICH-221 |

### Scelte aperte (regola 14)

Queste issue propongono una soluzione, ma la descrizione segnala un'alternativa valida: chiedi all'utente prima del fix. ICH-294 (`nucleo-06`), ICH-301 (`nucleo-07`), ICH-277 (`widget-03`), ICH-288 (`widget-07`), ICH-283 (`ui-03`), ICH-291 (`ui-06`), ICH-296 (`ui-07`), ICH-299 (`ui-12`), ICH-286 (`piani-02`).

### Da controllare, senza issue

Niente. Il rilascio di Ctrl+C con il flag 2 del protocollo kitty, emerso durante le bozze, è stato confermato nel
lotto 7 ed è ora ICH-456.

## Procedura per ogni lotto

`<model>` è il modello scelto dall'utente; `<ID...>` sono gli ID delle issue del lotto, nell'ordine della tabella.

```text
/trinity:workflow:1_create-worktree master <ID...> <model>
/trinity:workflow:2_work-issue <ID...> <model>
/trinity:workflow:3_independent-review <ID...> <model>
/trinity:workflow:4_review-fix-loop <ID...> <model>
/trinity:workflow:5_remove-worktree <prefisso>+<ID-numeri>-<model>
```

1. `1_create-worktree` crea il branch `<prefisso>/<ID-numeri>-<model>` (per esempio `bug/ICH-233-234-235-opus`) e il
   worktree in `.claude/worktrees/` del repository.
2. `2_work-issue` porta le issue a In Progress, scrive il piano e implementa. Per ogni issue: la spec che fallisce,
   il fix, la suite completa (regola 11). Commit separati per issue, Conventional Commits in inglese con scope
   (`fix(context): ...`, `fix(reader): ...`). Apre la PR con le magic words, senza merge.
3. `3_independent-review` fa una review indipendente in sola lettura del changeset rispetto agli acceptance
   criteria.
4. `4_review-fix-loop` serve solo se la review trova problemi.
5. Controlla la CI della PR (`gh pr checks <n> --watch`). Con la CI verde chiedi all'utente il merge (regola 13).
   Dopo il merge Linear porta le issue a Done.
6. `5_remove-worktree` rimuove worktree e branch (anche il branch remoto, vedi le decisioni).
7. **Dopo ogni merge chiudi il lotto subito**, senza aspettare che l'utente lo chieda: appena l'utente dice che ha
   fatto il merge, o dopo `5_remove-worktree`, esegui questi passi in ordine.
   1. `git pull` su `master`, poi la suite completa e la "Verifica finale" del log: semi 1234, 4242 e 7,
      `gem build`, `git diff ab75226 -- lib/notcurses/ffi lib/notcurses/ffi.rb` e la CI della PR e di `master`.
   2. Riga del lotto nella tabella "Lotti" di `RICONSEGNA.md` (lotto, PR, merge, issue, bug di notcurses nuovi), più
      le altre parti della sezione "Correzioni della revisione del 2026-11-06" che il lotto cambia: review, cambi
      dell'API, issue aperte nate dai lotti.
   3. Log del lotto in `memory/correzioni-review.md` (Fix, Decisioni, Review, Problemi e soluzioni, Verifica
      finale), con lo stesso formato dei lotti precedenti.
   4. Commit `docs(riconsegna): lotto <n> ... [skip ci]` dei due file.
   5. Retain in Hindsight, bank `notcursesruby`, con cause radice e decisioni; scrivi l'id dell'operazione nella
      sezione "Stato e prossimo step".
   6. Aggiorna la sezione "Stato e prossimo step" (stato, passi per il lotto successivo) e committala con
      `docs(ripresa): stato dopo il lotto <n>, prossimo step lotto <n+1> (...) [skip ci]`; poi `git push`.

Se un acceptance criterion si rivela sbagliato o impossibile, non cambiarlo da solo: proponi il testo nuovo
all'utente e, dopo la conferma, aggiorna la issue su Linear.

## Consegne

1. Una PR per lotto, con la CI verde e il merge confermato dall'utente.
2. Le 45 issue a Done, oppure chiuse con un motivo scritto nella issue (per esempio: lotto 17 non approvato).
3. `RICONSEGNA.md`: sezione "Correzioni della revisione del 2026-11-06" con data, tabella dei lotti (PR, commit,
   issue), cambi dell'API pubblica, bug di notcurses nuovi nelle tabelle esistenti, cambi a `Gemfile` e
   `Gemfile.lock` (se ci sono), "Cosa serve alla fase successiva".
4. Il log `memory/correzioni-review.md`: decisioni, problemi e soluzioni, lotto per lotto.
5. Hindsight, bank `notcursesruby`, se il server risponde: decisioni e cause radice.
6. Alla fine proponi il passo successivo (la Fase 5 di `git show 49732a3:RIPRESA.md`) e chiedi all'utente se
   riscrivere `RIPRESA.md` con quel prompt.

## Controlli finali

- Suite completa: 0 fallimenti, in ordine normale e con i semi 1234, 4242 e 7.
- `ruby -w -Ilib -e 'require "notcurses"'` senza warning.
- `yard doc --fail-on-warning` 0 warning, `yard stats --list-undoc` 100 %; `gem build` senza warning.
- Coverage >= 98 % totale e >= 90 % per file; `spec/coverage_spec.rb` e `spec/notcurses/api_spec.rb` passano.
- CI verde su tutta la matrice sull'ultimo commit di `master`.
- `git diff ab75226 -- lib/notcurses/ffi lib/notcurses/ffi.rb` vuoto, salvo il lotto 17 approvato.
- Ogni issue della revisione è a Done o ha un motivo scritto.

## Comandi

`S` è il percorso assoluto dello scratchpad della sessione, scritto nel prompt di sistema: assegnalo a mano. Non
esiste una variabile `$SCRATCHPAD`. In zsh una variabile non si divide in parole: usa una funzione o un array per i
comandi con più parole.

```sh
cd /Dati/Sviluppo/Progetti/Personali/20261027_notcursesruby

# suite completa; COLORTERM serve alle 10 spec dei colori RGB, TERM fisso anche dentro Kitty o Ghostty
TERM=xterm-256color COLORTERM=truecolor LANG=C.UTF-8 LC_ALL=C.UTF-8 timeout -k 5 -s KILL 600 bundle exec rspec < /dev/null
TERM=xterm-256color COLORTERM=truecolor LANG=C.UTF-8 LC_ALL=C.UTF-8 timeout -k 5 -s KILL 600 \
  bundle exec rspec --order rand:1234 < /dev/null
# coverage (report in coverage/)
TERM=xterm-256color COLORTERM=truecolor LANG=C.UTF-8 LC_ALL=C.UTF-8 timeout -k 5 -s KILL 600 \
  bundle exec rspec --require ./spec/support/coverage.rb < /dev/null
# script di prova contro notcurses: un solo contesto per processo, output su /dev/null
TERM=xterm-256color COLORTERM=truecolor LANG=C.UTF-8 LC_ALL=C.UTF-8 timeout -k 5 -s KILL 60 ruby -Ilib "$S/prova.rb" < /dev/null

# YARD e gem
bundle exec yard doc --fail-on-warning
bundle exec yard stats --list-undoc
RUBYOPT=-W0 gem build notcursesruby.gemspec

# workflow: controllo prima del push
mise x aqua:rhysd/actionlint@1.7.12 -- actionlint -ignore SC2016 .github/workflows/ci.yml

# GitHub
gh pr checks <n> --watch
gh run list --limit 5
gh run view <id> --log-failed
```

Linear, con la skill `linear` di Trinity (`LINEAR_API_KEY` è nell'ambiente):

```sh
lq() { (cd /Dati/AI/Claude/Trinity/skills/linear && mise x python -- python scripts/linear.py "$@"); }

# una issue, con stato e relazioni
lq query 'query($id: String!) { issue(id: $id) { identifier title state { name } priority estimate
  labels { nodes { name } } relations { nodes { type relatedIssue { identifier state { name } } } } description } }' \
  --variables '{"id": "ICH-268"}'

# issue della revisione ancora aperte
lq query 'query { issues(first: 100, filter: { project: { name: { eq: "notcursesruby" } },
  description: { contains: "full code review of 2026-11-06" }, state: { type: { nin: ["completed", "canceled"] } } })
  { nodes { identifier title priority state { name } } } }'
```

```sh
# recall dal bank notcursesruby
curl -s -m 30 -X POST http://127.0.0.1:8888/v1/default/banks/notcursesruby/memories/recall \
  -H 'Content-Type: application/json' \
  -d '{"query":"revisione completa 2026-11-06, correzioni per lotti, Context#close, Reader, kitty, SIGCONT","budget":"high","max_tokens":6000}'
```
