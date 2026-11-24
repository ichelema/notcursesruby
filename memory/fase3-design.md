# Fase 3 — design: ciclo degli eventi, focus, resize e widget composti

- Data: 2026-10-26. Base: commit `e710a92` (Parte 0 applicata).
- Stato: **approvato dall'utente il 2026-10-26** e implementato (commit `6c55106`…`692c455`). Le scelte con due
  letture valide (D1–D7) sono decise dall'utente (sezione 9) e il testo le applica. Le decisioni prese durante
  l'implementazione sono nel codice e in [lezioni.md](lezioni.md); la storia della Fase 3 è in git
  ([indice.md](indice.md), «Fuori da `memory/`»).

## Principi

1. Le classi nuove usano l'API pubblica della Fase 2 (regola 11). Il design non prevede chiamate FFI dirette.
2. Un solo thread chiama notcurses: quello che esegue `run` (regola 13). Gli altri thread e i `trap` passano dal
   ciclo con `post`.
3. I widget composti sono Ruby puro sopra `Plane`, come `Reel`. A ogni layout ridisegnano tutto dal proprio stato:
   non dipendono dal contenuto di un piano dopo un resize (bug `logrow`) e non copiano celle fra piani (causa di
   A4-01).
4. Le opzioni con un default sono keyword (regola 7). `spec/notcurses/api_spec.rb` controlla per riflessione anche il
   modulo nuovo.

## 0. File e namespace

Tutto sta in `Notcurses::UI` (D1): il modulo separa il framework Ruby dai wrapper degli oggetti C della Fase 2.

| File | Contenuto |
| --- | --- |
| `lib/notcurses/ui.rb` | modulo `Notcurses::UI`, `require` dei file sotto |
| `lib/notcurses/ui/event_loop.rb` | `EventLoop`, `Timer` |
| `lib/notcurses/ui/app.rb` | `App` |
| `lib/notcurses/ui/component.rb` | modulo `Component`, helper privato `Text` (controllo, taglio e a capo del testo) |
| `lib/notcurses/ui/container.rb` | `Container` |
| `lib/notcurses/ui/label.rb`, `button.rb`, `text_input.rb`, `list_view.rb`, `log_view.rb`, `dialog.rb` | i widget |
| `examples/demo.rb` | prova manuale su un terminale vero (D4) |

`lib/notcurses.rb` richiede `notcurses/ui` dopo gli altri file.

## 1. Ciclo degli eventi: `EventLoop`

`EventLoop` possiede il ciclo: attende l'input, i blocchi degli altri thread e i timer, consegna gli eventi e rende
lo schermo al massimo una volta per giro. Si usa da solo (applicazioni senza widget) oppure attraverso `App`, che ne è
una sottoclasse.

```ruby
Notcurses::Context.open do |nc|
  ev = Notcurses::UI::EventLoop.new(nc)
  ev.on_key('q') { ev.stop }
  ev.on_resize { |rows, cols| relayout(rows, cols) }
  ev.every(1) { |timer| clock.redraw }
  Thread.new { data = fetch; ev.post { show(data) } }
  reason = ev.run # :stop, :eof o :interrupt
end
```

| Metodo | Thread | Effetto |
| --- | --- | --- |
| `new(context)` | ciclo | nessuna risorsa: il pipe di risveglio nasce in `run` |
| `run` → Symbol | ciclo | esegue il ciclo fino a `stop`, `Key::EOF` o `Interrupt` |
| `stop` → self | qualsiasi, anche un `trap` | `run` esce alla fine del giro, senza leggere altri eventi |
| `post(&block)` → self | qualsiasi, anche un `trap` | il blocco gira nel thread del ciclo, nell'ordine di arrivo |
| `after(seconds, &block)` → Timer | ciclo | blocco una volta, dopo `seconds` |
| `every(seconds, &block)` → Timer | ciclo | blocco ogni `seconds` |
| `on_key(key, ctrl:, alt:, shift:, &block)` → self | ciclo | tasto globale (D5); il blocco riceve l'`Input` |
| `on_input(&block)` → self | ciclo | input non consumato da nessun altro passo |
| `on_resize(&block)` → self | ciclo | nuove dimensioni del terminale `(rows, cols)` |
| `dispatch(input)` → Boolean | ciclo | consegna un `Input` come se arrivasse dal terminale (eventi sintetici, test) |
| `running?` → Boolean | qualsiasi | true durante `run` |
| `Timer#cancel` → self, `#active?`, `#interval` | ciclo | ferma il timer; `interval` è nil per `after` |

Gli handler sono blocchi che ricevono i valori già esistenti: `Input`, `(rows, cols)`, `Timer` (D2).

Il ciclo non aspetta direttamente `Context#inputready_fd`: `run` avvia `Context#input_reader_start` e attende il pipe
del lettore Ruby, che legge dal C e filtra i tasti di segnale anche quando un handler è impegnato. Il lettore non parte
con `drain_input`. Lo studio ICH-600 tiene questo percorso: lo scheduler dei Fiber non lo cambia.

### Un giro del ciclo

```text
run
  ├─ prepara: pipe di risveglio (IO.pipe), IO del fd di Context#inputready_fd,
  │           trap('WINCH') se il contesto non ha il gestore di notcurses
  └─ finché non c'è uno stop:
       1. IO.select([input, risveglio], timeout = scadenza del prossimo timer)
       2. svuota il pipe di risveglio
       3. resize segnalato dal trap  → Context#refresh → handler di resize
       4. input: Context#get(timeout: 0) fino a nil
            Key::EOF → stop (:eof);  Key::RESIZE → passo 3;  altro → dispatch
       5. blocchi di post presenti all'inizio del passo
       6. timer scaduti, per scadenza
       7. Context#render, se il giro ha consegnato almeno un evento
  ensure: ripristina il trap, chiude il pipe
```

Fatti del C che il ciclo rispetta (verificati in `notcurses/src/lib/in.c` e con esperimenti):

- Ogni `notcurses_get` svuota tutto il pipe di prontezza, anche se in coda restano altri eventi (`in.c:2751-2757`). Il
  passo 4 legge quindi fino al primo `nil`: altrimenti gli eventi rimasti aspetterebbero l'input successivo.
- A fine stdin il thread di input scrive un byte sul pipe e `get` restituisce `Key::EOF` senza svuotarlo
  (`in.c:2610-2616`, `2702-2710`): dopo l'EOF il fd resta leggibile per sempre, quindi il ciclo si ferma.
- Con `drain_input: true` il fd diventa leggibile a fine stdin, ma `get` solleva sempre `InputError` (provato su
  `/dev/null`). Il ciclo non ascolta l'input di un contesto che scarta l'input: lo sa da `Context#drain_input?` (D6).
- `render` e `refresh` leggono le nuove dimensioni del terminale e ridimensionano lo stdplane
  (`notcurses_resize_internal`, `render.c:62-114`).

Uscita e errori:

- `run` restituisce `:stop`, `:eof` oppure `:interrupt` (D7). `Interrupt` arriva solo se `run` gira nel thread
  principale: con il default `no_quit_sighandlers: true`, Ctrl-C diventa `Interrupt` nel thread principale.
- Un'eccezione in un blocco esce da `run` dopo la pulizia (pipe chiuso, trap ripristinato); il contesto lo chiude
  `Context.open` come sempre.
- `run` dentro `run` solleva `Notcurses::Error`; `run` con il contesto chiuso solleva `ClosedError`. Se un blocco
  chiude il contesto, il ciclo esce alla fine del giro senza render.

Timer: orologio `CLOCK_MONOTONIC`. Per `every` la scadenza successiva è la precedente più l'intervallo; se il ciclo è
in ritardo di più di un intervallo, i giri persi saltano (nessuna raffica). A pari scadenza vale l'ordine di creazione.

`post`: `Queue#push` più un byte sul pipe con `write_nonblock(exception: false)`. Dentro un `trap` `Queue#push` e
`write_nonblock` funzionano, `Mutex` no (provato su Ruby 4.0.7 e 3.1.7): il ciclo non usa lock. Il passo 5 esegue solo
i blocchi presenti all'inizio del passo, quindi un blocco che si ripubblica non ferma il ciclo. Un `post` fatto quando
`run` non gira resta in coda e parte al `run` successivo.

## 2. Focus e consegna degli eventi: `App`

`App < EventLoop` aggiunge i componenti, il focus e le finestre modali.

```ruby
Notcurses::Context.open do |nc|
  app = Notcurses::UI::App.new(nc)
  form = Notcurses::UI::Container.new(app.root, border: true, title: 'Accesso')
  Notcurses::UI::Label.new(form, text: 'Nome:', size: 1)
  name = Notcurses::UI::TextInput.new(form, size: 1)
  Notcurses::UI::Button.new(form, 'Entra', size: 3) { app.stop }
  app.on_key('x', ctrl: true) { app.stop } # Ctrl+Q non arriva: il terminale lo usa per il controllo di flusso
  app.run
  puts name.text
end
```

| Metodo | Effetto |
| --- | --- |
| `new(context)` | crea `root`: un `Container` verticale grande quanto lo stdplane |
| `root` → Container | radice dei componenti |
| `focused` → Component, nil | componente con il focus |
| `focus(component)` → self | dà il focus (nil = nessuno); `ArgumentError` se il componente non è focusabile, non è visibile o sta fuori dalla finestra modale aperta |
| `focus_next`, `focus_prev` → Component, nil | ordine di Tab e Shift+Tab, circolare |
| `component_at(y, x)` → Component, nil | componente sotto il punto (coordinate dell'area di rendering) |
| `dispatch(input)` → Boolean | consegna con il focus (sotto) |
| `close` → nil | chiude finestre modali e `root`; idempotente |

**Chi ha il focus.** Un solo componente alla volta, o nessuno. Il primo componente focusabile che nasce prende il
focus se nessuno lo ha. Quando il componente con il focus si chiude o diventa invisibile (spazio esaurito, sezione 4),
il focus passa al successivo.

**Ordine di Tab e Shift+Tab.** L'ordine dell'albero dei componenti, in profondità (pre-order), dalla radice attiva:
la finestra modale in cima, se c'è, altrimenti `root`. Dentro un contenitore conta l'ordine di creazione. Contano
solo i componenti focusabili e visibili.

**Componenti non focusabili.** `Container` e `Label`. `Button`, `TextInput` e `ListView` sono focusabili.

**Consegna di un evento** (`dispatch`):

```text
mouse   → component_at(y, x) nella radice attiva
            pressione di BUTTON1..3 su un componente focusabile → focus
            offer_input al componente, poi ai contenitori sopra di lui
tastiera → offer_input al componente con il focus, poi ai contenitori sopra di lui
non consumato → on_key (il primo che corrisponde) → Tab / Shift+Tab → on_input
```

La risalita si ferma alla radice attiva: da una finestra modale un evento non arriva ai componenti sotto.
`dispatch` restituisce true se un componente, un tasto `on_key` o Tab lo ha consumato.

**Mouse.** `component_at` scende la pila dello stdplane dall'alto (`Context#top`, `Plane#below`) e prende il primo
piano che contiene il punto (`Plane#translate_abs`) e appartiene a un componente della radice attiva, o il cui antenato
più vicino appartiene a un componente. I piani che non sono di un componente non fermano la ricerca. Gli eventi del
mouse arrivano solo dopo `Context#mice_enable`, che serve un tty e l'applicazione chiama da sé; gli eventi sintetici
(`Input.synthesize(Key::BUTTON1, y:, x:)`) funzionano anche su `/dev/null`.

**Cursore del terminale.** Prima del render `App` chiede `focused.cursor` (posizione nel piano del componente, o nil)
e chiama `Context#cursor_enable` o `#cursor_disable` solo quando la posizione cambia. Senza un tty
`cursor_disable` solleva `ContextError` (provato): `App` lo ignora.

**Finestre modali.** Un `Dialog` aperto diventa la radice attiva: focus, Tab e mouse restano dentro il dialogo. I
tasti `on_key` restano attivi. Alla chiusura il focus torna al componente che lo aveva prima.

## 3. Resize

Modalità A, default (`no_winch_sighandler: true` del `Context`): durante `run` il ciclo installa `trap('WINCH')`. Il
gestore imposta un flag e scrive sul pipe di risveglio; il ciclo chiama `Context#refresh`, poi il layout. Alla fine di
`run` il ciclo ripristina il gestore precedente.

Modalità B (`no_winch_sighandler: false`): il ciclo non tocca SIGWINCH (un `trap` sostituirebbe il gestore C di
notcurses) e reagisce a `Key::RESIZE`. Limite del C: notcurses mette `Key::RESIZE` in coda solo quando il suo thread
di input elabora altro input (`in.c:2439-2445`); il resize arriva quindi con il tasto successivo. Il ciclo sceglie la
modalità da `Context#no_winch_sighandler?` (D6).

In entrambe le modalità il ciclo chiama gli handler solo se `refresh` restituisce dimensioni diverse dalle
precedenti. `App` esegue prima `root.layout(rows, cols)` e il layout delle finestre modali (che si ricentrano), poi
gli handler `on_resize`.

Limiti noti del C:

- l'intestazione di `Tabbed` non segue il resize e un `Reader` ridimensionato solleva `WidgetError`: i widget C della
  Fase 2 dentro un'applicazione vanno ricreati in `on_resize`. I widget composti non li usano;
- dopo uno scroll, resize e `duplicate` permutano le righe del piano (`logrow`): i componenti ridisegnano tutto a ogni
  layout e non fanno mai scorrere i propri piani. Un piano che scorre (per esempio quello di un `FdPlane`) non va
  ridimensionato dopo uno scroll: va ricreato, oppure il testo va tenuto in Ruby e ridisegnato.

## 4. Widget composti

### Protocollo: modulo `Component`

Ogni widget composto include `Component` (che include `Resource`). Un componente ha un piano proprio, figlio del piano
del contenitore (o dello stdplane per `root` e `Dialog`), creato con `Plane#create_child` e distrutto con
`Plane#close`.

| Metodo | Scopo |
| --- | --- |
| `app`, `parent`, `context` | applicazione, contenitore (nil per `root` e `Dialog`), contesto |
| `plane` | piano del componente; `ClosedError` se il componente è chiuso |
| `offer_input(input)` → Boolean | gestisce l'evento; true se lo consuma. Default false |
| `focusable?` | default false |
| `focused?`, `focus` | true se ha il focus; `focus` lo chiede ad `App#focus` |
| `visible?` | false se il contenitore non gli ha dato spazio (o se non lo è un antenato) |
| `layout(rows, cols)` → self | ridimensiona il piano e ridisegna; con 0 righe o colonne nasconde il componente |
| `redraw` → self | cancella il piano e ridisegna dallo stato; `App` lo chiama quando cambia il focus |
| `cursor` → [y, x], nil | posizione del cursore del terminale quando il componente ha il focus. Default nil |
| `close` → nil | idempotente: chiude i figli, toglie il componente dal contenitore (che rifà il layout) e da `App`, chiude il piano |

Differenza dal prompt: niente metodi di notifica `focus`/`blur`. `App` chiama `redraw` sul componente che perde e su
quello che prende il focus, e ogni componente disegna lo stato di focus da `focused?`. `focus` chiede il focus, come
`Element#focus` del DOM.

Costruzione: `Classe.new(parent, ..., size: nil, weight: nil)`. `parent` è un `Container` (o `App` per `root` e
`Dialog`). `size:` è la dimensione fissa lungo l'asse del contenitore (righe in uno verticale, colonne in uno
orizzontale); `weight:` è la quota dello spazio restante (default 1). Il componente nasce già disposto: il
contenitore rifà subito il layout. Le keyword interne `layout_size` e `layout_weight` hanno nomi intenzionali: `size`
nei widget navigabili è il numero di elementi, non lo spazio assegnato dal contenitore. I rilasci dei tasti non
arrivano ai componenti, quelli del mouse sì; i widget ignorano i rilasci anche quando li ricevono da `offer_input`.
Il testo che il widget dichiara passa da `Text.check!`, che usa `Plane#check_text!` alla costruzione e nel setter;
`LogView` riceve byte qualsiasi e al disegno scrive `"?"` per un grapheme che notcurses divide diversamente da Ruby.

Un componente nascosto (0 righe o colonne) ha il piano 1×1 spostato fuori dallo schermo: niente disegni sovrapposti
quando il terminale è troppo piccolo; Tab e mouse lo saltano.

Ciclo di vita: `App` si registra nel contesto con il meccanismo dei figli adottati (`Context#adopt`, `@api private`),
quindi `Context#close` chiama `App#close` prima di `notcurses_stop`. `App#close` chiude dall'alto: finestre modali, poi
`root`; ogni contenitore chiude i figli prima del proprio piano, senza rifare il layout. Dopo `App#close` tutti i
componenti risultano chiusi.

Componenti dell'utente: una classe che include `Component`, chiama `attach_component!(parent, size:, weight:)` alla
fine di `initialize` e implementa il disegno privato `draw`. Il design lo documenta con un esempio YARD.

### Widget proposti (D3)

| Widget | Descrizione | Base |
| --- | --- | --- |
| `Container` | figli in righe (`direction: :vertical`) o colonne (`:horizontal`), con `size:` o `weight:`; bordo e titolo facoltativi (`border:`, `title:`) | piani figli |
| `Label` | testo statico, una riga per `"\n"`, tagliato alla larghezza; `align:`, `styles:`, `channels:`; non focusabile | `putstr` |
| `Button` | etichetta con bordo (3 righe o più) o `[ etichetta ]` (meno di 3 righe); Invio, Spazio o clic chiamano il blocco | `box`, `putstr` |
| `TextInput` | campo di testo a una riga: inserimento, Backspace, Canc, frecce, Home, Fine, scorrimento orizzontale, glifi larghi; Invio chiama il blocco | Ruby (non `Reader`) |
| `ListView` | elenco con selezione e scorrimento: frecce, PgUp, PgDn, Home, Fine, rotella, clic; Invio chiama il blocco | Ruby (non `Selector`) |
| `LogView` | ultime righe di un testo che cresce (`append`), tenute in Ruby (`max_lines:`, default 1000) e tagliate alla larghezza; accetta byte grezzi; non focusabile | Ruby |
| `Dialog` | finestra modale centrata: titolo, testo (a capo sulle parole), pulsanti; Esc chiude con nil | `Container` + `Button` |

`LogView` è la destinazione dei dati di `FdPlane` e `Subprocess` dentro un layout (D3). `append` accetta anche i byte
grezzi del thread di lettura: tiene da parte la riga non finita (anche un carattere UTF-8 spezzato fra due blocchi) e
ripulisce il testo solo al disegno, e solo per le righe visibili (UTF-8 non valido e caratteri di controllo diventano
`?`, TAB diventa spazi). Le righe stanno in Ruby: il piano non scorre mai, quindi un resize non incontra il bug
`logrow`.

Perché `TextInput` e `ListView` in Ruby (D3): `Reader` non scorre in orizzontale (con `HORSCROLL` due glifi larghi
terminano il processo), solleva `WidgetError` dopo un resize e accende il cursore del terminale a ogni ridisegno;
`Selector` decide da sé le dimensioni del proprio piano, non cancella voci (`ncselector_delitem` va in segfault) e con
un genitore troppo piccolo distrugge il piano. Dentro un layout che si ridimensiona i due widget C andrebbero ricreati
a ogni resize.

Colori: ogni widget ha `channels:` (colori normali) e i focusabili anche `focused_channels:`, con default leggibili su
sfondo chiaro e scuro (`ListView` usa `focused_channels:` per la voce selezionata).

Testo: `Label`, `Button`, `ListView` e `Dialog` controllano il testo alla creazione e nei setter con le regole di
`Plane#putstr` (niente TAB, caratteri di controllo, U+2028/U+2029, caratteri di larghezza zero), così un errore esce
subito e non durante un layout successivo.

## 5. Thread

- Solo il thread che esegue `run` chiama notcurses. `App`, i componenti, `on_*`, `after` ed `every` si usano da quel
  thread (o prima di `run`). Il wrapper non aggiunge lock (regola 3): lo dice il YARD.
- `post` e `stop` sono gli unici metodi per gli altri thread e per i `trap`.
- Un timer è una scadenza controllata a ogni giro: il timeout di `IO.select` è il tempo che manca al primo timer.
- `trap('WINCH')` imposta un flag e scrive sul pipe; non chiama notcurses.
- `FdPlane` e `Subprocess` restano come nella Fase 2; il loro blocco gira nel thread di lettura e passa i dati al
  ciclo con `post`, di solito verso un `LogView`:

  ```text
  thread di lettura ── post { log.append(bytes) } ──► Queue + 1 byte sul pipe ──► IO.select ──► passo 5
  ```

  ```ruby
  log = Notcurses::UI::LogView.new(app.root, weight: 1)
  Notcurses::Subprocess.new(log.plane, 'ping', '-c', '3', 'localhost') do |_s, bytes|
    app.post { log.append(bytes) unless log.closed? }
  end
  ```

  `FdPlane` e `Subprocess` attivano lo scrolling del piano ricevuto e non ci scrivono: `LogView` scrive ogni riga in
  una posizione esplicita, quindi il piano non scorre. Un blocco già in coda dopo `LogView#close` trova `closed?`. La
  `Queue` non ha limite: un produttore più veloce del ciclo la fa crescere (documentato).

## 6. Test

| Spec | Contenuto |
| --- | --- |
| `spec/notcurses/ui/event_loop_spec.rb` | contesto di test su `/dev/null` (input scartato: il ciclo non ascolta l'input): `post` da un altro thread sveglia il ciclo, `stop` da un thread e da un `trap`, `after`/`every`/`cancel` e il loro ordine, un render per giro (`Context#stats.renders`), eccezioni dei blocchi, `run` annidato, `on_key` (Ctrl con le maiuscole di notcurses, Shift+Tab, rilasci ignorati), `trap('WINCH')` installato e ripristinato |
| `spec/notcurses/ui/app_spec.rb` | `dispatch` con `Input.synthesize`: focus iniziale, Tab e Shift+Tab, risalita ai contenitori, precedenza di `on_key`, mouse (`component_at` con piani sovrapposti), finestra modale, chiusura del componente con il focus, cursore |
| `spec/notcurses/ui/container_spec.rb`, `label_spec.rb`, `button_spec.rb`, `text_input_spec.rb`, `list_view_spec.rb`, `log_view_spec.rb`, `dialog_spec.rb` | layout (dimensioni e posizioni dei piani), disegno (`Plane#contents`, `Context#at` dopo un render), input, ciclo di vita, glifi larghi, byte grezzi e UTF-8 spezzato (`LogView`) |
| `spec/integration/ui_pty_spec.rb` | ciclo completo in un processo figlio con un pty, come `pty_spec.rb`: tasti veri (testo, Tab, Invio), clic SGR, resize con `winsize` e SIGWINCH, dati di un `FdPlane` e di un `Subprocess` passati con `post`, Ctrl-C (`:interrupt`), EOF (`:eof`) |

## 7. Cambi all'API della Fase 2 (regola 12)

| Cambio | Perché |
| --- | --- |
| `Context#drain_input?` (nuovo) | il ciclo non deve leggere l'input di un contesto che lo scarta (`get` solleva `InputError`) |
| `Context#no_winch_sighandler?` (nuovo) | il ciclo installa `trap('WINCH')` solo se notcurses non ha il proprio gestore |

Scelta dell'utente (D6): predicati in `Context`. L'alternativa scartata erano due keyword di `EventLoop.new`
(`input:`, `trap_winch:`) da tenere coerenti a mano con le opzioni del contesto.

La regione condivisa vale per `Visual.from_plane` e `Plane#as_rgba` (`y:`, `x:`, `rows:`, `cols:`). `Visual#blit`,
`#geometry` e `#create_plane` tengono `begy:`, `begx:`, `leny:`, `lenx:` in pixel (`0` = fino al bordo), perché la
scelta dell'utente riguardava le regioni lette da un piano.

## 8. Limiti e cose escluse

- `run` gira nel thread principale per ricevere `Interrupt`; in un altro thread Ctrl-C arriva al thread principale.
- Con `no_winch_sighandler: false` il resize arriva con il tasto successivo (limite del C, sezione 3).
- Esclusi: i widget C della Fase 2 come componenti (si ospitano in un componente dell'utente), `TextArea` a più righe,
  temi globali, scorciatoie per contenitore, drag del mouse, incolla con bracketed paste.
- `post` senza limite di coda (sezione 5).

## 9. Decisioni dell'utente (2026-10-26)

| Id | Scelta | Decisione | Alternativa scartata |
| --- | --- | --- | --- |
| D1 | Namespace | `Notcurses::UI` | tutto in `Notcurses` |
| D2 | Handler | blocchi con i valori esistenti (`Input`, `rows, cols`, `Timer`) | classi evento dedicate (`KeyEvent`, `MouseEvent`, `ResizeEvent`) |
| D3 | Widget | i 6 della sezione 4 in Ruby, più `LogView` | sopra `Reader` (più righe) e `Selector`; un sottoinsieme |
| D4 | Esempio per la prova manuale | `examples/demo.rb` | nessun esempio |
| D5 | Notazione dei tasti | keyword: `on_key('c', ctrl: true)`, `on_key(Key::TAB, shift: true)` | stringhe: `on_key('Ctrl+C')`, `'Shift+Tab'`, `'F5'` |
| D6 | Stato del contesto | `Context#drain_input?` e `#no_winch_sighandler?` (cambio della Fase 2) | keyword `input:` e `trap_winch:` di `EventLoop.new` |
| D7 | Ctrl-C | `run` restituisce `:interrupt` | `run` rilancia `Interrupt` dopo la pulizia |

Regole di `on_key` (D5): il blocco scatta per le pressioni e le ripetizioni, non per i rilasci. `key` è un carattere
(String di un grapheme) o un Integer (codepoint o costante `Key`). Con `ctrl: true` una lettera ASCII corrisponde
anche in maiuscolo, perché notcurses consegna Ctrl+c come `'C'` con Ctrl (`in.c`, `load_ncinput`). Shift conta solo
per le costanti `Key` (Tab e Shift+Tab sono diversi: notcurses consegna Shift+Tab, `kcbt`, come `'\t'` con Shift,
`in.c:190`); per i caratteri è già nel carattere (`'Q'`). CapsLock e NumLock
non contano; Meta, Super e Hyper devono mancare.
