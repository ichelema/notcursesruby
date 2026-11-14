# Correzioni della revisione del 2026-11-06 — log

Decisioni, problemi e soluzioni, lotto per lotto. Ordine dei lotti e regole in `RIPRESA.md`; esito in
`RICONSEGNA.md`, sezione "Correzioni della revisione del 2026-11-06".

## Decisioni iniziali (2026-11-08)

- Modello dei comandi del workflow: `opus`. Il modello serve solo al nome del branch e del worktree: il lavoro gira
  nella sessione.
- Issue correlate (ICH-214…ICH-232): fuori dai lotti.
- Lotto 17 (Fase 1, ICH-312 e ICH-313): decisione rimandata a dopo il lotto 16.
- `--force` per `git worktree remove`: approvato per i worktree del lotto 1 che hanno in più solo il submodule
  `notcurses` e `git status` vuoto. `git worktree remove` rifiuta i worktree con un submodule inizializzato. Il
  2026-11-08, prima del lotto 2, l'utente ha esteso l'approvazione a tutti i lotti, con le stesse condizioni.

## Lotto 1 — ICH-268, ICH-269, ICH-270 (PR #2, merge `e22a117`)

### Fix

- **ICH-268 (Ctrl-C durante lo stop).** `close` segna l'oggetto chiuso prima di `notcurses_stop`/`ncdirect_stop` e fa
  il resto in un `ensure` (metodo privato `mark_closed!(fclose:)`). `drop_planes` invalida ogni wrapper prima del suo
  `ncplane_destroy` e il resto prima di `notcurses_drop_planes`; `generation` cresce in un `ensure`. Il reviewer
  Fable ha controllato con un SIGINT vero (output su una pipe piena) che Ruby consegna l'Interrupt nel frame della
  funzione FFI, come la simulazione con `prepend` delle spec.
- **ICH-269 (fork).** Con `@pid != Process.pid`, `close` fa solo `mark_closed!(fclose: false)`: niente `fclose`, che
  chiuderebbe il FILE* copiato dal padre.
- **ICH-270 (trap).** `release_context` prende il Mutex; in un gestore trap `Mutex#lock` solleva `ThreadError`, e il
  `rescue` assegna direttamente, solo se l'oggetto è il contesto attivo.
- **ICH-433 (nata dalla review).** Il figlio di un fork ereditava il buffer stdio di `Direct` (`putstr` usa `fputs`
  su `ttyfp`), e la libc lo scriveva all'uscita del figlio: testo duplicato. Prima scelta: documentare il limite.
  Scelta finale dell'utente: un hook `Process._fork` (modulo privato `DirectForkFlush`, anteposto a
  `Process.singleton_class`) che chiama `ncdirect_flush` sul `Direct` aperto prima di ogni fork. Il round 3 ha trovato
  il fork annidato: il controllo `ctx.pid == Process.pid` saltava il flush nel figlio; tolto (fflush tocca solo la
  libc).

### Review (3 round)

- Round 1: buffer di Direct nel figlio (Fable LOW, GPT MEDIUM); spec mancante per l'eccezione al ritorno di
  `notcurses_drop_planes`. Scartato: `run_child` duplicato (preferenza; una terza copia è in `ui_pty_spec.rb`).
- Round 2: GPT ripropone il buffer di Direct come violazione dell'AC di ICH-269; l'utente sceglie il fix completo.
  Fable: limite di 1 s non controllato nella spec del fork (corretto).
- Round 3: fork annidato e commento sbagliato sul lock di fflush (GPT MEDIUM, corretti senza nuovo round);
  `Process.daemon` (GPT MEDIUM, ICH-441); figlio che non può aprire un nuovo contesto, CHANGELOG, contatori delle
  chiamate C nel nipote (Fable, corretti).

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| Job Ruby 3.1.7 rosso prima delle spec | cache scaduta; mise 2026.10.19 non passa `RUBY_CFLAGS` a ruby-build, gcc 16 compila in C23 | `CFLAGS: -std=gnu17` in `ci.yml`; causa trovata riproducendo il container con Podman |
| `codecov/patch` e `codecov/project` rossi | i rami nuovi girano solo nei processi figli delle spec | `codecov.yml` con status informativi (scelta dell'utente) |
| `git worktree remove` rifiuta i worktree di review | submodule `notcurses` inizializzato per la suite | `--force` dopo `git status` vuoto (approvato dall'utente) |
| Figlio di fork: nuovo `Context.open` fallisce | notcurses registra i segnali in una variabile globale, che il figlio copia (`already registered for signals`) | documentato nel YARD di `close`: il figlio può solo uscire o fare `exec` |

### Verifica finale

- `master` su `e22a117`: 933 esempi, 0 fallimenti, in ordine normale e con i semi 1234, 4242 e 7 (Ruby 4.0.7); la
  stessa suite su Ruby 3.1.7 in locale e in CI.
- `git diff ab75226 -- lib/notcurses/ffi lib/notcurses/ffi.rb`: vuoto.

## Lotto 2 — ICH-271 (PR #3, merge `d4970c4`)

### Fix

- **Design (scelta dell'utente, ibrido).** `clear_cut_glyphs!` svuota con `ncplane_erase_region` le metà orfane sui
  bordi di ogni riga: la metà sinistra (larga 2) nell'ultima colonna, la metà destra in colonna 0, la metà destra
  nell'ultima colonna senza la sua metà sinistra. Le tre `resize*` la chiamano subito (forzata, prima di
  `raise_callback_errors!`: il resize resta applicato anche in errore); `text_target!`, `line_start!` e ogni segmento
  di `putstr` la chiamano solo se le colonne sono cambiate dall'ultimo controllo. Copre i resize fatti dal C
  (stdplane nel render, figli `:maximize`) e i callback Ruby che scrivono durante la cascata.
- **Render dentro `ncplane_put`.** Su uno stdplane che scorre ogni a capo (`"\n"` o a capo automatico, anche fuori
  dall'ultima riga: `scroll_down` fa solo `++y`) fa un `notcurses_render`, che restringe lo stdplane a metà della
  chiamata C. `putstr` e `hline` chiamano prima `ncpile_render` (`render.c:1579`) se la scrittura può andare a capo.
- **`merge_down`** porta glifi larghi senza passare dalle scritture: azzera la cache del piano di destinazione (metodo
  `protected` `forget_cut_glyphs!`; `&:sym` non chiama un metodo protected, serve il blocco esplicito).
- **Prestazioni.** La cache confronta solo le colonne: con le dimensioni intere un piano `scrolling + autogrow`
  rileggeva tutti i bordi a ogni a capo (3000 scritture: da 0,05 s a 4,9 s).

### Review (3 round + review singola, solo Fable)

- Round 1: HIGH render dentro `ncplane_put` (fix più largo del report: vale anche per l'a capo automatico); LOW YARD
  di `resize_region`; scartato l'ordine della pulizia prima di `raise_callback_errors!` (voluto).
- Round 2: MEDIUM `merge_down` + resize che riportano le colonne controllate; test mancante di `hline`.
- Round 3: HIGH metà destra orfana nell'ultima colonna (`resize_region` con `x_off < 0`): PR in draft, poi fix
  (scelta dell'utente: fix e review singola fuori dal loop); MEDIUM stato per wrapper → ICH-448.
- Review singola: MEDIUM scritture quadratiche con autogrow (regressione della PR); LOW commento sbagliato
  sull'origine delle metà orfane.
- Bug già presenti su `master`, issue aperte su richiesta dell'utente: ICH-449, ICH-450.

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| Secondo parere GPT senza report (0 tool call, 2 volte) | limite di utilizzo di GPT | solo Fable per il lotto 2 (scelta dell'utente) |
| `Refs ICH-215` nella PR ha portato ICH-215 a In Progress | l'automazione GitHub → Linear tratta anche i link non chiudenti | riga tolta, ICH-215 riportata a Backlog; nei lotti non collegare issue fuori dal lotto |
| Worktree di review non rimovibile | la sessione era dentro il worktree (`/cd` dell'utente) | `/cd` alla root prima della rimozione |
| Spec pty con heredoc interpolato | escape della regex rovinati | heredoc letterale con costanti in testa allo script |
| Il double free di ICH-449 non si riproduce con 20 iterazioni | intermittente | 200 iterazioni con `libc_malloc_debug` |

### Verifica finale

- `master` su `d4970c4`: 956 esempi, 0 fallimenti; CI verde su tutta la matrice sull'ultimo commit della PR.
- `git diff ab75226 -- lib/notcurses/ffi lib/notcurses/ffi.rb`: vuoto.

## Lotto 3 — ICH-272 (PR #4, merge `29f5a41`)

### Fix

- **Tabella unica.** `Util::IMAGE_BLITTERS` (`Util::BLITTERS` senza `:four_by_one` e `:eight_by_one`) e
  `Util.image_blitter_value`. La usano `Visual.from_plane`, `Plane#as_rgba` e `Visual::Internal.options`, che serve
  `#blit`, `#geometry`, `#create_plane`, `#stream` e i quattro `blit_*`: un solo cambio copre otto metodi.
  `Direct::Args::BLITTERS` è rimossa, `Direct::Args.blitter` usa lo stesso helper. `Plot`, `parse_blitter`,
  `blitter_name` e `Visual::Geometry#blitter` restano su `Util::BLITTERS`.
- **Spec del crash.** Processo figlio con `termtype: 'rxvt-256color'`, che accende i quadranti anche su `/dev/null`;
  su `master` il figlio va in core dump. Un commit solo (`d7eaf4f`).

### Review (1 round, Fable e GPT)

- Fable: nessun finding; crash riprodotto su `master` (exit 139) e assente sul branch.
- GPT: nessun finding; probe con i quadranti su tutte le API delle immagini, con i simboli e le costanti intere.

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| Reviewer GPT senza report (0 tool call, poi report perso dopo 46–50 tool call) | il tunnel SSH verso LiteLLM (porta 4000, host `litellm-vps`) cadeva dopo pochi minuti: `ssh` usciva con il codice 144, senza errori; non era il limite di utilizzo | l'utente ha riavviato LiteLLM; `SendMessage` all'agente dopo la caduta ha recuperato il report |
| `/cd` della sessione nei worktree (implementazione, review GPT) e in Trinity, non chiesti da nessuno | funzione "Follow work" della mod filetree 0.8.2: dopo qualche minuto di letture e scritture in un altro repo git (un worktree conta come repo) esegue `/cd` da sola | `Follow work: off` in `/config` (sezione filetree); dopo un `/cd` la root resta fuori dalle directory di lavoro e il `cd` del tool Bash non ci torna |
| `bundle install` su Ruby 3.1.7 fallisce in `rubygems/resolver/conflict.rb` | in Ruby 3.1.7 è installato anche Bundler 4.0.22, che `bundle` sceglie e che richiede Ruby >= 3.2 | `bundle _2.3.27_` con il `Gemfile` copiato fuori dal progetto (`BUNDLE_GEMFILE`, procedura di `RICONSEGNA.md`) |

### Verifica finale

- Branch: 958 esempi, 0 fallimenti, in ordine normale e con i semi 1234, 4242 e 7 (Ruby 4.0.7) e su Ruby 3.1.7;
  coverage 98,19 % righe; CI verde su tutta la matrice.
- `git diff ab75226 -- lib/notcurses/ffi lib/notcurses/ffi.rb`: vuoto.
- `master` su `29f5a41`: 958 esempi, 0 fallimenti.

## Lotto 4 — ICH-273, ICH-274, ICH-275 (PR #5, merge `1f441f3`)

### Fix

- **ICH-273 (larghezza zero sull'ultima colonna).** `put_egc` scarta un EGC con `ncstrwidth == 0` quando il cursore è
  sull'ultima colonna e restituisce 0 (conta come scritto). Il controllo sta prima della sostituzione TAB → spazio:
  `ncstrwidth("\t") == 1`, quindi il TAB non cambia. Nuovo metodo privato `move_view_cursor!`: `prepare!` e il
  workaround di Backspace/Ctrl+U/Ctrl+W sollevano `WidgetError` se `ncplane_cursor_move_yx` fallisce. Anche i
  `@raise` dei quattro `move_*` lo dicono (passano da `prepare!`). `wrap_backspace` ignora ancora il ritorno: è il
  codice di ICH-218 e con `x = colonne - 1` non può fallire.
- **ICH-274 (grapheme divisi).** `write` passa a `put_egc` ogni EGC di notcurses: `nccell_load` su una cella
  temporanea, rilasciata subito (serve solo la lunghezza). Un ritorno negativo solleva `WidgetError` (fix della
  review). Un pezzo che taglia un codepoint (U+2028: `nccell_load` restituisce 1 byte) non si usa: il resto del
  grapheme va al C, che lo rifiuta, come prima.
- **ICH-275 (egcpool di `contents`).** `contents` fa `to_ptr` e restituisce `@plane.contents`;
  `ncreader_contents` è esclusa in `coverage_spec.rb` con il motivo `:contents`.

### Review (2 round, Fable e GPT)

- Round 1: MEDIUM (GPT) `nccell_load == -1` ignorato in `write`: il resto del grapheme andava al C, che ne scrive
  solo il primo EGC (testo perso senza errore; riprodotto con lo stub e con l'egcpool della vista pieno). LOW
  (Fable) commento falso: `nccell_load` rilascia il contenuto precedente (`pool_blit_direct`, `internal.h:1448`).
  Corretti in `932ea62`, con la stessa frase sbagliata nel corpo della PR.
- Round 2: nessun finding. Nota di Fable non adottata: una spec dedicata al TAB sull'ultima colonna (già coperta).

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| Stub `not_to receive` del primo blocco attivo anche nel secondo blocco dello stesso esempio | le aspettative di rspec-mocks valgono per tutto l'esempio | due esempi separati |
| Comando dei controlli finali in coda per conferma | conteneva un `rm -rf` di `doc`, `.yardoc` e `coverage`, già in `.gitignore` | rilanciato senza `rm` |
| La sessione è finita due volte nei worktree di review con `/cd` | non chiarito: "Follow work" della mod filetree è spento | l'utente ha riportato la sessione alla root prima della rimozione |

### Verifica finale

- Branch prima della review (`0cf69e1`): 964 esempi, 0 fallimenti, in ordine normale e con i semi 1234, 4242 e 7
  (Ruby 4.0.7) e su Ruby 3.1.7; coverage 98,29 % righe; YARD 100 %, 0 warning. Dopo il fix della review (`932ea62`):
  966 esempi, 0 fallimenti in ordine normale (Ruby 4.0.7); CI verde su tutta la matrice (Ruby 3.1.7–4.0.9).
- `git diff ab75226 -- lib/notcurses/ffi lib/notcurses/ffi.rb`: vuoto.
- `master` su `1f441f3`: 966 esempi, 0 fallimenti.

## Lotto 5 — ICH-276, ICH-277 (PR #6, merge `119a98f`)

### Fix

- **ICH-276 (widget creati dentro i callback).** `Tree.new`, `Tabbed.new` e `Reel.new` chiamano
  `check_not_in_callback!('<Classe>.new', WidgetError)` subito dopo `claim_plane!`, come gli altri sei widget. Causa
  radice: il blocco di un tablet gira in `callback_scope`, e `check_hosted_widgets!` controlla i widget ospitati solo
  all'inizio di `layout!`; nello stesso ridisegno il reel distrugge il piano dati (blocco che restituisce 0) o i piani
  dei tablet (`ensure` dopo un'eccezione). Il widget restava aperto su piani liberati: `nctree_destroy` e
  `Reel#close` li liberavano una seconda volta (SIGABRT), il `nctabbed` restava allocato (`free_plane` azzera
  `p->widget` prima del distruttore, `notcurses.c:482-489`). L'alternativa del report (controllare prima di ogni
  `destroy_family`) non serve. YARD di classe di `Tree` e `Reel`: il blocco non può creare widget.
- **ICH-277 (MultiSelector di 1 riga).** `offer_input` legge `ncplane_dim_y` del piano del widget a ogni chiamata e
  sotto 2 righe solleva `WidgetError` prima del C. Causa radice: `ncmultiselector_draw` confronta `yoff` unsigned con
  `dimy - 2` (`selector.c:696`): con 1 riga circa 2^32 giri, con il GVL tenuto. Il controllo sta dopo il `TypeError`
  dell'input e prima del ritorno `false` per un evento vuoto.

### Decisioni

- ICH-277 (regola 14): soglia di 2 righe, l'aritmetica del C, e non il minimo di `check_room!` (5 o 7 righe).
  L'utente ha chiesto la soluzione migliore; una prova con 2, 3 e 4 righe, da 1 a 8 colonne, con e senza `title:`
  non ha trovato blocchi né risultati sbagliati. `check_room!` misura il genitore solo per la creazione
  (`selector.c:865-880`).
- Spec in più rispetto ai *Required tests*: creazione dei tre widget nel blocco di disegno di un Tree e nel blocco
  di un Tab (terzo acceptance criterion di ICH-276), e uno stub `not_to receive(:ncmultiselector_offer_input)` per
  ICH-277.

### Review (2 round, solo Fable)

- La review GPT non ha mai girato: il modello GPT dietro il proxy LiteLLM restituiva `usage_limit_reached` (piano
  plus, azzeramento dopo circa 70 minuti). Il subagente finiva senza report (122 token). L'utente ha scelto di
  proseguire con il solo Fable, come nel lotto 2.
- Round 1: LOW (Fable) mancavano le voci di `CHANGELOG.md` per ICH-276 e ICH-277. Corretto in `f3ca7d8`. Scartate
  come preferenze: `plane.dim_y` al posto di `FFI.ncplane_dim_y(FFI.ncmultiselector_plane(ptr))`; il controllo prima
  del ritorno `false` per un evento vuoto (voluto).
- Round 2: nessun finding. Fable ha tolto le guardie in una copia di `lib/`: le spec nuove falliscono, lo script di
  ICH-276 esce con 134 e il caso di ICH-277 con 137.
- Nota di Fable, preesistente e fuori lotto: se il blocco di un tablet solleva, il tablet resta nel reel e il blocco
  gira di nuovo al ridisegno successivo.

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| Review GPT ferma senza report, anche rilanciata | limite di utilizzo del modello GPT (`usage_limit_reached`, visto con una richiesta diretta al proxy) | solo Fable, scelta dell'utente |
| Comando dei controlli in coda per conferma, poi scaduto | conteneva `rm -f` del file `.gem` | `gem build --output` nello scratchpad, senza `rm` |
| Spec nel processo figlio ferma al primo widget | `expect` dentro il ciclo | esiti dei tre widget raccolti e confrontati insieme |

### Verifica finale

- Branch prima della review (`f6de8dd`): 974 esempi, 0 fallimenti, in ordine normale e con i semi 1234, 4242 e 7
  (Ruby 4.0.7) e su Ruby 3.1.7; coverage 98,29 % righe; YARD 100 %, 0 warning. CI verde su tutta la matrice (Ruby
  3.1.7–4.0.9) su `f3ca7d8`.
- `git diff ab75226 -- lib/notcurses/ffi lib/notcurses/ffi.rb`: vuoto.
- `master` su `119a98f`: 974 esempi, 0 fallimenti.

## Lotto 6 — ICH-278 (PR #7, merge `a55606b`)

### Fix

- **ICH-278 (`nucleo-04` + `ui-04`, ridisegno dopo SIGCONT).** Con `no_winch_sighandler?` true `EventLoop#run`
  installa `trap('CONT') { resize_signal }` accanto a `trap('WINCH')`, e nell'`ensure` lo ripristina con la stessa
  regola (`@old_cont || 'SYSTEM_DEFAULT'`). Causa radice: `NCOPTION_NO_WINCH_SIGHANDLER` toglie un solo gestore C,
  che serve SIGWINCH e SIGCONT (`unixsig.c:204-211`); alla ripresa quel gestore fa fare al render un
  `notcurses_refresh` (`in.c:30-38`, `render.c:1538-1541`) e accoda `NCKEY_SIGNAL`. Con il default del wrapper
  nessuno ridisegnava dopo Ctrl+Z e `fg`. Il fix riusa `resize_signal` (flag e byte sul pipe) e
  `handle_resize(refresh: true)`, che chiama `Context#refresh` e chiama `on_resize` solo se le dimensioni cambiano.
  Con il gestore di notcurses `run` non installa trap: un trap Ruby sostituirebbe la sua `sigaction`.
- YARD: sezione "Resize del terminale", `@param no_winch_sighandler` e `no_winch_sighandler?` di `Context`,
  `Key::SIGNAL`, nuovo paragrafo "Ctrl+Z e fg" di `EventLoop`. Il default `no_winch_sighandler: true` non cambia.

### Decisioni

- Nessuna spec per "`Key::SIGNAL` arriva a `on_input` con `no_winch_sighandler: false`" (requisito 4): serve un
  contesto reale con quel flag. Controllato con uno script: `on_input` riceve `["SIGNAL", "x"]`.
- Review con `/trinity:workflow:3_independent-review` (un reviewer), non con il loop: GPT rispondeva di nuovo, ma il
  fix era piccolo.

### Review (2 round, Fable)

- Round 1 (`d79759b`): APPROVABILE, un LOW: il `@param no_winch_sighandler` dava il rimedio solo per rimando alla
  sezione di classe. Corretto in `45dd517`. Il reviewer ha eseguito le spec nuove su una copia di `lib/` con il
  vecchio `event_loop.rb`: 2 fallimenti, come vuole la regola 11.
- Round 2 (`45dd517`, solo la differenza): APPROVABILE, nessun finding.

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| Script di controllo del requisito 4: `SIGNAL` non arrivava | lo script leggeva il gestore con `Signal.trap('CONT', 'SYSTEM_DEFAULT')`, che sostituisce la `sigaction` di notcurses | script senza lettura dei trap; l'assenza di trap è già coperta dalla spec `expect(Signal).not_to receive(:trap)` |
| Suite della review con 2 fallimenti falsi | `rspec` con cwd nel worktree principale mette il suo `lib/` nel load path prima di `-I` e carica il codice vecchio | `rspec` con cwd neutro (`env -C /`) o nel worktree di review |
| `git worktree remove` rifiutato | il worktree contiene il submodule `notcurses` | `--force` con `git status` vuoto (decisione già presa) |

### Verifica finale

- Branch (`45dd517`): 975 esempi, 0 fallimenti, in ordine normale e con il seme 1234 (Ruby 4.0.7); coverage
  98,29 % righe; YARD 100 %, 0 warning; `ruby -w` senza warning. CI verde su tutta la matrice (Ruby 3.1.7–4.0.9).
  Semi 4242 e 7 e Ruby 3.1.7 in locale: non eseguiti (Ruby 3.1.7 coperto dalla CI).
- Riproduzione della issue: `EventLoop: refreshes after SIGCONT=1`, le due righe di `Context` invariate.
- `git diff ab75226 -- lib/notcurses/ffi lib/notcurses/ffi.rb`: vuoto.
- `master` su `a55606b`: 975 esempi, 0 fallimenti.

## Lotto 7 — ICH-279, ICH-280, ICH-281 (PR #8, merge `29748c8`)

### Fix

- **ICH-279 (`ui-01`, Shift sotto il protocollo kitty).** `TextInput#offer_input` inserisce `input.eff_text`;
  `EventLoop#key_match?` confronta un binding stampabile con il primo codepoint di `eff_text`, o con `id` se
  `eff_text` è vuoto; i binding non stampabili restano su `id` e Shift. Causa radice: con kitty notcurses tiene in
  `id` il tasto senza Shift e costruisce `utf8` da `id` (`in.c:2737`); il testo digitato è solo in `eff_text`
  (`in.c:834-838`), che notcurses riempie con l'`id` finale, già in maiuscolo con Ctrl, quando il terminale non
  manda testo (`in.c:2740-2742`): per questo `on_key('x', ctrl: true)` regge.
- **ICH-280 (`ui-05`, Ctrl+C con CapsLock o NumLock).** `run` legge ISIG una volta (`Context#linesigs?`, con la
  guardia su `FFI::ISIG` solo senza `no_linesigs`); `read_input` chiama `line_signal` prima di `dispatch`. Con ISIG
  attivo un evento C, Z o `\` con Ctrl più soli blocchi e con il campo deprecato `ctrl` della struct vero non viene
  consegnato; alla pressione con un blocco il ciclo fa `Process.kill(sig, Process.pid)`. Causa radice:
  `load_ncinput` alza il segnale solo con `modifiers == NCKEY_MOD_CTRL` (`in.c:506`). `Input#ctrl_field?`
  (`@api private`) espone il campo `ctrl`: notcurses lo scrive solo per le sequenze con Ctrl (kitty `in.c:814`, xterm
  `in.c:738`, terminfo, mouse), mai per un byte di controllo (`in.c:539` cambia solo `modifiers`).
- **ICH-281 (`ui-11`, glifo largo sotto il cursore).** I due cicli di scorrimento di `TextInput#draw` aggiungono
  `widths[@position] || 1`, la formula della issue.
- `Context#input_tty` controlla `STDIN.closed?` prima di `STDIN.tty?`: `run` ora chiama `linesigs?` a ogni avvio e
  con STDIN chiuso sollevava `IOError`.

### Decisioni

- Commit divisi per issue anche dove un file conteneva cambi di più issue: blob intermedi con `git hash-object` e
  `git update-index`, oppure `git apply --cached` di hunk scelti; ogni commit intermedio passava le spec UI e pty.
- Divergenza fra ISIG del terminale e `ictx->linesigs` (finding MEDIUM del round 1): non è un fix minimo (il flag
  di notcurses non è esposto e il ripristino di `run` cambierebbe), quindi ICH-454.
- Ctrl+C in coda consegnato a un `run(no_linesigs: true)` successivo (LOW del round 3): serve uno stato fra i run,
  quindi ICH-455 invece di un fix senza review.
- Controllo di "Da controllare, senza issue" di `RIPRESA.md`: vero (il rilascio `\e[99;5:3u` da solo fa uscire
  `run` con `:interrupt`; pressione, ripetizione e rilascio danno 3 SIGINT). Issue ICH-456, aperta su richiesta
  dell'utente.

### Review (3 round, Fable e GPT)

- Round 1 (`45a8f7d`): Fable APPROVABILE CON RISERVE, GPT NON APPROVABILE. Corretti: byte 0x03/0x1a classico
  scartato con ISIG attivo (MEDIUM), `run(no_linesigs: true)` senza `ContextError` con ISIG non noto (LOW), YARD
  senza la lettura di ISIG all'avvio (LOW), due buchi nei test (LOW: ramo `eff_text` vuoto; `kitty true` sempre
  vero perché notcurses scrive `\e[>u\e[=27u` a ogni avvio, `termdesc.c:538-543`). In ICH-454: divergenza ISIG.
- Round 2 (`2c849fd`): entrambi lo stesso MEDIUM: con kitty acceso ogni evento senza tipo diventa `:press`
  (`in.c:501-505`), quindi il controllo su `evtype` del round 1 non bastava. Corretto con il campo `ctrl`
  (`8865ecd`), che chiude anche il Ctrl+C di xterm `\e[27;5;99~` in coda (LOW). Corretto anche `IOError` con STDIN
  chiuso (LOW, `7f1d97e`).
- Round 3 (`7f1d97e`): GPT APPROVABILE, nessun finding; Fable un LOW, in ICH-455.

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| 10 fallimenti nella suite del worktree | submodule `notcurses` non inizializzato: mancano `notcurses/data/*.png` | `git submodule update --init --depth 1 notcurses` (nota già in `RIPRESA.md`) |
| `bundle exec rspec` su Ruby 3.1.7 fallisce nel resolver | `Gemfile.lock` con Bundler 4.0.22 | `mise exec ruby@3.1.7 -- rspec`, senza `bundle` |
| Script che sceglie gli hunk perdeva l'intestazione di un file | `id()` di una lista Python liberata viene riusato | contatore dei file al posto di `id()` |
| Un reviewer ha messo in coda un mutation test con `Process.kill(signal, 0)` e `rm -rf` | hook Blast Radius sui comandi con `rm` | nei prompt dei reviewer: niente segnali al process group, comandi con `rm` separati e brevi |
| Worktree di review con `.review-tmp/mut` dopo il comando in coda | il comando è fallito a metà (errore di sintassi alla riga 18) | rimosso `.review-tmp` con la conferma dell'utente, poi `--force` |

### Verifica finale

- Branch (`7f1d97e`): 982 esempi, 0 fallimenti su Ruby 4.0.7 e 3.1.7; YARD 100 %, 0 warning; `ruby -w` senza
  warning. CI verde su tutta la matrice (Ruby 3.1.7–4.0.9) e Codecov.
- Le spec nuove falliscono tutte sul codice di prima di ogni fix (controllato togliendo il diff di `lib/`).
- I tre `repro.rb` delle issue danno l'output atteso.
- `git diff dc10c8e -- lib/notcurses/ffi lib/notcurses/ffi.rb`: vuoto.
- `master` su `29748c8`: 982 esempi, 0 fallimenti.

## Lotto 8 — ICH-282, ICH-283 (PR #9, merge `0c72ad1`)

### Fix

- **ICH-282 (`ui-02`, `LogView#append('')`).** `@partial = parts.pop || ''.b`. Causa radice: `"".split("\n", -1)`
  è `[]`, quindi con la riga non finita vuota (vista nuova, dopo `clear`, dopo un blocco che finisce con `"\n"`)
  `append('')` metteva `@partial` a `nil`, e da lì `append`, `lines`, il ridisegno e il layout del contenitore
  sollevavano `NoMethodError`.
- **ICH-283 (`ui-03`, drag che ripete il clic).** `App#drag?` tiene in `@held` i tasti BUTTON1..3 premuti: una
  pressione di un tasto già in `@held` restituisce `false` da `offer` prima del focus e dei componenti, e arriva solo
  a `on_input` (`key_binding` salta il mouse); il rilascio toglie il suo tasto. Causa radice: notcurses perde il bit
  del movimento del report SGR (`in.c:610-620`), quindi ogni cella del drag arriva come pressione nuova dello stesso
  tasto. Un rilascio perso costa un clic.
- **Console Linux (review round 1).** Lì notcurses legge il mouse da gpm e trasforma ogni evento, rilascio compreso,
  in `\e[<0;x;yM` (`gpm.c:31`, `mice.c:4-19`): `@held` non si svuotava mai e il mouse arrivava ai componenti una
  volta sola. `App` non applica la regola quando `detected_terminal` è `FBcon` o `VT`, seguito o no da spazio e
  versione (`LINUX_CONSOLE`, confronto sui byte). Lì ogni pressione resta un clic, come prima della PR.

### Decisioni

- ICH-283, scelta della regola 14: l'utente ha scelto la soluzione della issue (pressione ripetuta = movimento, il
  Button scatta alla pressione), non il clic al rilascio. Dopo un esempio pratico l'utente ha chiesto se il drag and
  drop resta possibile: con la soluzione scelta si scrive in `App#on_input`, non dentro un componente. Il drag dentro
  i componenti (pointer capture) è ICH-457, aperta su richiesta dell'utente.
- Console Linux (MEDIUM del round 1): fra esclusione della console, solo documentazione e stato che scade, l'utente
  ha scelto l'esclusione con `detected_terminal`.
- Confronto del nome sui byte (`.b`) invece dello `scrub` in `Util.take_string`: lo `scrub` è ICH-301 (lotto 14).
- La PR descrive ICH-457 senza l'ID, per la regola che vieta le magic word verso issue fuori dal lotto.

### Review (3 round, Fable e GPT)

- Round 1 (`828886f`): Fable APPROVABILE CON RISERVE, un MEDIUM (console Linux con gpm), corretto in `b6ab903`; GPT
  APPROVABILE, nessun finding. Corretto anche il testo della voce del CHANGELOG di ICH-282 (`f92dc5f`), segnalato da
  Fable come nota.
- Round 2 (`b6ab903`): Fable due LOW, corretti in `de79ba7`: `App.new` sollevava `ArgumentError` con un nome del
  terminale non UTF-8 (la versione viene da XTVERSION); la spec non usava i nomi reali con la release del kernel
  (`termdesc.c:940`) e nessuna mutazione della regexp la faceva fallire. GPT nessun finding (ha consegnato il report
  solo dopo una richiesta).
- Round 3 (`de79ba7`): nessun finding da entrambi. Fable ha segnalato un buco di test marginale (un rilascio che
  svuota tutti i tasti premuti): spec aggiunta dopo il loop (`5dbba40`), non riverificata da una review.

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| `yard doc --fail-on-warning` fallisce | `@held` in un commento è letto come tag YARD sconosciuto | commento senza `@` |
| `git apply --cached` di un solo hunk del CHANGELOG mette in stage entrambi i cambi | con `-U1` i due cambi vicini formano un hunk | `git diff -U0` e `git apply --cached --unidiff-zero` |
| `git worktree remove` dei worktree di review rifiutato | worktree con il submodule `notcurses` | `--force` con `status` vuoto (approvato in `RIPRESA.md`) |
| La review GPT del round 2 finisce senza report | il subagente non ha chiamato l'hand-back | `SendMessage` con la richiesta del report |
| La skill `linear` avviata dal tool Skill parte in background senza compito | la skill ha `context: fork` | skill fermata; issue creata con `scripts/linear.py` |

### Verifica finale

- Branch (`5dbba40`): 986 esempi, 0 fallimenti su Ruby 4.0.7, anche con i semi 1234, 4242 e 7 (su `828886f`); coverage
  98,21 %; YARD 100 %, 0 warning; `ruby -w` senza warning; `gem build` senza warning. CI verde su tutta la matrice
  (Ruby 3.1.7–4.0.9) e Codecov.
- Ogni spec nuova falliva sul codice di prima del suo fix; le mutazioni della regexp e del rilascio fanno fallire
  `app_spec.rb`.
- I due `repro.rb` delle issue danno l'output atteso.
- `git diff 6368d9c -- lib/notcurses/ffi lib/notcurses/ffi.rb`: vuoto.
- `master` su `0c72ad1`: 986 esempi, 0 fallimenti.

## Lotto 9 — ICH-284 (PR #10, merge `106c700`)

### Fix

- **ICH-284 (`direct-visual-02`, `Direct#stream`).** Prima di ogni frame dopo il primo `stream` chiama
  `ncdirect_cursor_up(rows)` con l'altezza del frame precedente; via il ramo `cols == dim_x` e il `cursor_left`.
  Causa radice: il riposizionamento era copiato da `ncdirect_stream` (`direct.c:1550-1559`), che presume il cursore
  sull'ultima riga del frame e sale di `rows - 1`; il raster a celle chiude anche l'ultima riga con `"\n%*.*s"`
  (`direct.c:558`) e lascia il cursore sotto il frame. Ogni frame scendeva di una riga e la prima riga dei frame
  precedenti restava sullo schermo. Il CUB dalla colonna 0 non faceva nulla; per l'allineamento basta la HPA del
  raster.
- **`:pixel` documentato, non gestito.** `ncdirect_dump_sprixel` sposta in alto un frame che non entra sotto il
  cursore (`direct.c:442-448`), poi `ncdirect_dump_plane` manda una CUP a `min(y + rows, dim_y)` (`direct.c:607-613`).
  Per un frame più basso dello schermo che finisce sull'ultima riga quella CUP punta sotto lo schermo: su un
  terminale che la ferma sull'ultima riga del frame, il frame successivo parte una riga più in alto e da lì resta
  fermo; se un sixel sull'ultima riga fa scorrere lo schermo (`termdesc.h:165-166`), i frame si sovrappongono. Un
  frame alto quanto lo schermo parte dalla riga 0 (`direct.c:444`) e non si sposta. Descritto nel YARD di `#stream` e
  nel CHANGELOG; la gestione in codice è ICH-458.

### Decisioni

- `:pixel`: la issue ammette "Handle it or document it"; il piano approvato dall'utente lo documenta. Dopo il round 1
  la gestione in codice è andata in ICH-458 (MEDIUM, `related` a ICH-284), perché serve una lettura del cursore per
  frame e un finto terminale sixel che segue il cursore: non è un fix minimo.
- Per i frame più stretti del terminale, su un terminale che ferma la CUP, il caso `:pixel` in fondo allo schermo è
  una regressione rispetto a prima: su master si sovrapponevano. L'utente ha fatto il merge con il compromesso
  descritto nel report del loop.
- Spec in più rispetto all'issue: `scale: :stretch` controlla che un frame largo come il terminale salga ancora di
  tutta l'altezza (passa anche sul codice di prima, è una guardia del criterio "as today").
- La PR e il commento sulla PR citano ICH-458 solo con il link, senza magic word.

### Review (3 round, Fable e GPT)

- Round 1 (`4f81490`): Fable APPROVABILE CON RISERVE, un MEDIUM (`:pixel` in fondo allo schermo è il caso comune e
  il testo lo presentava come raro); testo corretto in `e67e511`, gestione in codice in ICH-458. GPT APPROVABILE,
  nessun finding.
- Round 2 (`e67e511`): Fable due LOW, corretti in `632f659`: il CHANGELOG chiamava "limite che resta" un caso che su
  master funzionava per i frame stretti; un frame alto quanto lo schermo non si sposta. Corretto anche il riferimento
  `direct.c:441` → `442`. GPT nessun finding.
- Round 3 (`632f659`): Fable due LOW, corretti dopo il loop in `4604996` e non riverificati: l'esito `:pixel` dipende
  dal terminale (`termdesc.h:165-166`); la vecchia deriva valeva solo per i frame più stretti del terminale. GPT
  nessun finding.
- Mutazioni dei reviewer: 7 nel round 1 e 6 nel round 2, tutte uccise dalle spec nuove.

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| I worktree di review del round 1 esistevano già, il submodule solo in uno | il comando che li creava è stato interrotto dall'utente dopo la creazione | l'utente ha scelto di riusarli; submodule inizializzato nell'altro |
| `git worktree remove` dei worktree di review e di quello del lotto rifiutato | worktree con il submodule `notcurses` | `--force` con `status` vuoto (approvato in `RIPRESA.md`) |
| Il branch remoto del lotto esisteva ancora dopo il merge | GitHub non lo cancella | `git push origin --delete` dopo la conferma chiesta da `5_remove-worktree` (la decisione è già in `RIPRESA.md`) |
| I passi di chiusura del lotto non partivano dopo il merge | la procedura li elencava solo nella sezione "Stato" | su richiesta dell'utente, il passo 7 della "Procedura per ogni lotto" dice di eseguirli subito dopo ogni merge |

### Verifica finale

- Branch (`4604996`): 988 esempi, 0 fallimenti su Ruby 4.0.7; con il seme 1234 e la coverage (su `4f81490`): righe
  98,24 %, rami 90,89 %; YARD 100 %, 0 warning; `ruby -w` senza warning. CI verde su tutta la matrice (Ruby
  3.1.7–4.0.9) e Codecov.
- La spec nuova falliva sul codice di prima (`"\e[2A\e[1D"` al posto di `"\e[3A"`).
- Il `repro.rb` della issue dà `" \n \n \n\e[3A \n \n \n"`.
- `git diff ab75226 -- lib/notcurses/ffi lib/notcurses/ffi.rb`: vuoto.
- `master` su `106c700`: 988 esempi, 0 fallimenti, anche con i semi 4242 e 7; `gem build` senza warning; CI verde.

## Lotto 10 — ICH-285, ICH-286 (PR #11, merge `23fd73a`)

### Fix

- **ICH-285 (`direct-visual-03`, `Direct#putegc` e `#print_aligned`).** `zwj_segments` passa da `Plane` (privato) a
  `Util.zwj_segments`. `Notcurses.strwidth` somma `ncstrwidth` sui segmenti, con l'offset del byte d'errore riferito
  a tutto il testo. `putegc` passa al C solo il primo segmento; `print_aligned` misura con `Notcurses.strwidth` e
  trasforma il suo `ArgumentError` nel messaggio di prima ("contiene caratteri di controllo"). Causa radice: dopo uno
  ZWJ `utf8_egc_len` resta in `injoin` e conta 0 colonne per tutto il resto (`egcpool.h:119`, `126-128`); il
  workaround esisteva solo in `Plane#putstr`, mentre `ncdirect_putegc` (`direct.c:49-66`) e `ncstrwidth`
  (`notcurses.c:3311-3333`) usano la stessa funzione.
- **ICH-286 (`piani-02`, `Plane#puttext`).** Nessun cambio a `wrap_lines`: misura le parole con
  `Notcurses.strwidth`, che ora conosce lo ZWJ. Solo la spec.
- **Perimetro allargato alla UI.** `UI::Component` (`Text.truncate`, `Text.wrap`, `put_text`), `Dialog#place` e
  `ListView#draw` misurano con `strwidth`: una `Label` con un emoji ZWJ e `size: 10` non solleva più `PlaneError`.

### Decisioni

- Regola 14 (ICH-286 e il vincolo tecnico di ICH-285): l'utente ha scelto `Notcurses.strwidth` consapevole dello ZWJ
  invece del fix locale in `Direct` e `wrap_lines`. Motivo: una sola correzione alla causa, che arriva a tutti i
  chiamanti, e niente issue nuova per la UI. Il contratto "con le regole di notcurses" cambia; la gem non ha utenti.
- Regola 16: l'utente ha approvato l'allargamento del perimetro alla UI. Commento su ICH-285 con la scelta; magic
  word solo per ICH-285 e ICH-286.
- I widget disegnati dal C (`Reader`, `MultiSelector`, `Cell`, `Widget`) chiamano `FFI.ncstrwidth` direttamente e
  restano invariati: devono misurare come il C.
- Le asserzioni richieste per le righe 309, 317 e 326 di `direct_spec.rb` sono in esempi nuovi accanto a quelli
  esistenti, non dentro di essi.

### Review (1 round, `3_independent-review`)

- Round 1 (`4f264d4`), nella stessa sessione dell'implementazione: APPROVABILE CON RISERVE. Un LOW: per una sequenza
  ZWJ che non è un emoji (congiunta devanagari) `strwidth` dipende dalla versione di Ruby (4 su Ruby 4.0.7, 5 su
  3.1.7), come già `Plane#putstr`. Due test mancanti: `Dialog` con ZWJ e offset del byte d'errore.
- Dopo la review, su richiesta dell'utente, `fd089bf`: frase nel YARD di `strwidth` e le due spec, senza un nuovo
  round. La spec di `Dialog` falliva sul codice di prima (`[6, 11]` al posto di `[5, 12]`); quella dell'offset
  fallisce con una mutazione senza offset ("dal byte 2").
- Controesempi della review senza anomalie: in 6 casi su 6 `strwidth`, il ritorno di `putstr` e il cursore coincidono;
  `putegc` con ZWJ iniziale, `"a‍b"` e controllo iniziale; `print_aligned` con testo più largo del terminale e con
  NUL. Limite già presente e fuori dal lotto: `putstr` rifiuta la bandiera 🏳️‍🌈 seguita da testo.

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| Le spec delle immagini di `direct_spec` fallivano nel worktree | `git submodule update -q` con `-q` dopo il sottocomando: git lo legge come un percorso | `git submodule -q update --init --depth 1 notcurses` |
| Seme e coverage senza output | `$E` con più parole in zsh non si divide | una funzione `E() { ...; }` (nota già in `RIPRESA.md`) |
| La prima prova su `master` della spec di `Dialog` passava | il numero di riga indicava lo spec precedente: il nuovo è alla riga 41 | rilanciata con la riga giusta: fallisce |
| Il comando di pulizia della review è andato in coda | contiene `rm -r` | l'utente l'ha confermato |

### Verifica finale

- Branch (`fd089bf`): 994 esempi, 0 fallimenti su Ruby 4.0.7; con la coverage (su `4f264d4`): righe 98,24 %, rami
  90,93 %; YARD 100 %, 0 warning; `ruby -w` senza warning. CI verde su tutta la matrice (Ruby 3.1.7–4.0.9) e Codecov.
- Le 5 spec nuove del round di implementazione fallivano sul codice di prima.
- `git diff ab75226 -- lib/notcurses/ffi lib/notcurses/ffi.rb`: vuoto.
- `master` su `23fd73a`: 994 esempi, 0 fallimenti, anche con i semi 1234, 4242 e 7; `gem build` senza warning; CI
  verde.

## Lotto 11 — ICH-287, ICH-288, ICH-289, ICH-290 (PR #12, merge `cb3f0ba`)

### Fix

- **ICH-287 (`widget-06`, `Tree`).** `resize_item` dà al piano della voce `rows` righe e
  `dim_x(albero) - ncplane_x(voce)` colonne, almeno 1, e salta il resize solo se le due dimensioni coincidono.
  Causa radice: `nctree` fissa la larghezza del piano solo alla creazione (`tree.c:441-456`, `FIXME possibly
  enlarge`), e il wrapper correggeva solo l'altezza. Dopo un resize in larghezza il blocco riceveva i piani vecchi:
  su un albero più stretto disegnava fuori, perché i piani delle voci sono figli del piano dell'albero e non vengono
  tagliati.
- **ICH-289 (`widget-08`, `Tab#move`).** Se il tab spostato è il primo mostrato e `before:` è già il suo successore,
  `nctab_move` lascia la lista com'era (`tabbed.c:318-330`) e il wrapper non sposta più `leftmost`. Causa radice:
  la regola fissa "il primo diventa quello che lo seguiva" valeva anche per lo spostamento nullo.
- **ICH-288 (`widget-07`, `ProgBar`).** Solo YARD (classe, `initialize`, `progress=`) e due spec che fissano la regola
  dei colori di `fill.c:192-197` e `238-255`, una in un processo figlio con `LANG=C`.
- **ICH-290 (`widget-09`, `Plot`).** Solo YARD ("Limiti noti di 3.0.17" e `label_ticks:`) e una spec che fissa il
  limite delle etichette sopra circa 1,84e17.

### Decisioni

- Regola 14 (ICH-288): l'utente ha scelto l'opzione A, solo documentazione, invece di un controllo in Ruby in
  `progress=` prima del C. Motivi: la issue lo chiede, il wrapper non copia una regola del C che una versione nuova
  può cambiare, il messaggio del C resta.
- ICH-290, criterio cambiato durante la review (con la conferma dell'utente): sopra il limite l'etichetta dipende
  dalla build di notcurses. La conversione da double a `uintmax_t` fuori intervallo è un comportamento indefinito:
  la build CachyOS `x86_64_v4` (znver4, AVX-512, `vcvttsd2usi` satura) mostra "184.47P", la build Arch generica
  della CI mostra "0.00". La spec accetta i due valori noti: un valore nuovo su un'altra piattaforma la fa fallire.
  Su Linear sono cambiati criterio, test richiesto e titolo ("…labels are wrong above about 1.8e17").
- Il YARD di `Tab#move` promette il caso nullo solo per il primo tab mostrato: l'ultimo tab spostato prima del suo
  successore circolare (il primo) diventa ancora il primo, come già documentato.
- Commit `docs(...)` per ICH-288 e ICH-290, che non cambiano codice.

### Review (3 round, Fable e GPT)

- Round 1 (`f4133af`): Fable NON APPROVABILE per un HIGH, la spec di Plot rossa su tutta la CI (già corretta in
  `85e56e3` durante la review), più due LOW: `resize_item` con colonne ≤ 0 se il blocco sposta la voce oltre il
  bordo destro (ogni redraw successivo falliva: regressione del fix, `547aa19`) e la frase YARD di `Tab#move` falsa
  per l'ultimo tab (trovata anche da GPT, `4a0691c`). Una nota di forma in `progbar.rb` (`bd37ef6`). GPT:
  APPROVABILE CON RISERVE, solo il LOW di `Tab#move`.
- Round 2 (`bd37ef6`): Fable un LOW, la riga alta di Plot con `exponential:` e `:uint64` moltiplica interi e va in
  wrap modulo 2^64 su ogni build ("15.53P" per 2e17), documentato in `94f32ae`. GPT nessun finding.
- Round 3 (`94f32ae`): nessun finding da tutti e due. Nessuna issue creata, nessun residuo.
- Scartati: una chiamata a `render` nella spec di Tree (il controllo geometrico richiesto basta); spec opzionali
  per Plot `:double` e ProgBar 1x1 senza UTF-8. Accettato: un blocco che restringe da sé il piano lo ritrova largo
  (conseguenza del criterio). Fuori dal lotto: `Plane#resize_region` che sposta l'origine dell'albero (notcurses non
  sposta i piani figli).

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| La spec di ICH-290 passava in locale e falliva su tutta la CI ("0.00" invece di "184.47P") | notcurses locale è la build CachyOS `x86_64_v4`; la CI usa il pacchetto Arch generico; la conversione fuori intervallo è indefinita | YARD e spec con i due valori noti; criterio aggiornato su Linear dopo la conferma dell'utente |
| Il controllo con il seme 1234 non dava output | `for o in "" "--order rand:1234"` con `$o` non quotato: in zsh non si divide in parole | comando rilanciato con il seme scritto per esteso |
| `echo =====` nel ciclo delle query Linear | in zsh `=parola` è l'espansione di un comando | separatore tra virgolette |
| La spec senza UTF-8 di ProgBar richiede `Open3` | `progbar_spec.rb` non lo caricava; in suite arrivava da altri file | `require 'open3'` in testa al file |

### Verifica finale

- Branch (`94f32ae`): 1000 esempi, 0 fallimenti su Ruby 4.0.7; YARD 100 %, 0 warning; `ruby -w` senza warning. CI
  verde su tutta la matrice (Ruby 3.1.7–4.0.9), coverage e Codecov.
- Le spec nuove di ICH-287 e ICH-289 fallivano sul codice di prima (`[20, 20, 18]`, `["b", "c", "a"]`); quelle di
  ICH-288 e ICH-290 passano sul codice di prima, come chiesto: fissano il comportamento di notcurses.
- `git diff ab75226 -- lib/notcurses/ffi lib/notcurses/ffi.rb`: vuoto.
- `master` su `cb3f0ba`: 1000 esempi, 0 fallimenti, anche con i semi 1234, 4242 e 7; `gem build` senza warning; CI
  verde.

## Lotto 12 — ICH-291, ICH-292, ICH-293 (PR #13, merge `4ec4f4c`)

### Fix

- **ICH-291 (`ui-06`, rollback alla creazione).** `Component#close_on_error` (privato) avvolge l'attach di
  `attach_component!` e il corpo di `Dialog#initialize`: se la creazione solleva, chiude il componente, rimette lo
  stato del focus letto prima dell'attach (`App#focus_state`/`#restore_focus_state`, `@api private`) e propaga
  l'eccezione originale; un errore `StandardError` della pulizia è ingoiato. `Component#close` fa `unregister` e
  `remove_child` in un `ensure`, `Dialog#close` chiama `super` in un `ensure` dopo `close_modal`. Il nuovo
  `Util.plane_channels_value` rifiuta lo sfondo `:highcontrast` nei 9 punti della UI e in `Plane#channels=`. Causa
  radice: `add_child` disegna il figlio prima di `App#attached`, e niente toglieva un figlio la cui creazione falliva;
  il controllo dei canali stava solo nel disegno.
- **ICH-292 (`ui-08`, focus dopo il resize).** `release_focus` ricorda in `@lost_focus` il componente che non trova un
  sostituto visibile; `resized` lo sostituisce con il focus di prima del layout e chiama `restore_focus` dopo
  `root.layout` e `place`, prima di `super`. Solo `App#focus` e un focus non nil cancellano la memoria; un `Dialog`
  salva anche il focus in attesa e `close_modal` restituisce al ripristino un componente salvato ma nascosto.
  `offer` dà un tasto alla radice attiva quando nessuno ha il focus. Causa radice: il focus si sceglieva solo alla
  creazione e in `close_modal`, mai quando un layout mostrava di nuovo i componenti.
- **ICH-293 (`ui-10`, pulsanti del Dialog).** I pulsanti nascono con `weight: strwidth(label) + 5`, la quantità che
  `place` somma. Causa radice: pesi tutti 1, quindi `distribute` divideva la riga in parti uguali.

### Decisioni

- Regola 14 (ICH-291): l'utente ha scelto l'opzione A, rollback più controllo anticipato, anche se `Container`
  senza titolo con lo sfondo `:highcontrast`, prima accettato, ora solleva `ArgumentError`.
- `Plane#channels=` usa l'helper nuovo: il messaggio comincia con il nome del parametro (`channels: ...`).
- Il rollback non ingoia le eccezioni fuori da `StandardError` della pulizia (`Interrupt`, `SystemExit`): una
  richiesta di fermarsi conta più dell'errore di creazione (finding GPT del round 3, scartato).
- I fix dei round 1 e 2 toccano ICH-291 e ICH-292 nello stesso `app_spec.rb` e nello stesso helper: un commit per
  round, con `Refs` alle due issue.

### Review (3 round, Fable e GPT)

- Round 1 (`6019a93`): GPT NON APPROVABILE, Fable APPROVABILE CON RISERVE; cinque finding distinti, tutti corretti
  in `cab0681`: `close` saltava `remove_child`/`unregister` se il ridisegno del focus sollevava (HIGH); il rollback non
  ridava il focus al fratello nascosto dal figlio nuovo; dopo il resize tornava l'ultimo candidato transitorio del
  layout sequenziale, non il focus di prima; `change_focus(nil)` interno (dialogo aperto o chiuso) cancellava il focus
  da ripristinare; tre buchi di test trovati con i mutation test di Fable.
- Round 2 (`cab0681`): GPT due MEDIUM (`Dialog#close` senza `ensure`; focus in attesa perso da un pulsante del
  dialogo o da un rollback), Fable quattro LOW (stesso tema, `Dialog.new` fallito con focus nil, `close_parts`,
  CHANGELOG). Corretti in `6a3592f`, tranne `Container#close_parts`/`release_focus` già su `master`: ICH-459.
- Round 3 (`6a3592f`): Fable APPROVABILE, un LOW (riga di pulsanti di 4-6 colonne: ICH-460) e tre rischi già su
  `master` (ICH-461); GPT un MEDIUM scartato (`Interrupt` nella pulizia). Commento riassuntivo sulla PR.

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| Lavoro ripreso su una VPS invece della macchina locale | checkout in `/mnt/data/...`, lo stesso disco di `/Dati/...`; notcurses 3.0.17-3 generico di Arch, come la CI | nessun cambio ai comandi; la differenza di build della spec di ICH-290 non tocca la VPS |
| Semi e coverage non partivano in uno script | `E="env ..."` in una variabile: zsh non la divide in parole | array `E=(env ...)` e `"${E[@]}"` |
| Due spec controllavano `component_at` = nil | sotto ogni punto c'è `root`, che copre tutto lo schermo | attesa `equal(app.root)` o `not_to equal(componente)` |
| `Plane` non ha `children` | la spec voleva contare i piani figli dello stdplane | controllo su `app.root.children` |

### Verifica finale

- Branch (`6a3592f`): 1019 esempi, 0 fallimenti su Ruby 4.0.7, anche con i semi 1234, 4242 e 7; line coverage
  98,24 %; YARD 100 %, 0 warning; `ruby -w` senza warning. CI verde su tutta la matrice (Ruby 3.1.7–4.0.9) e Codecov.
- Ogni spec nuova falliva sul codice di prima (controllato prima di ogni fix; per `change_focus` togliendo il fix).
- `git diff ab75226 -- lib/notcurses/ffi lib/notcurses/ffi.rb`: vuoto.
- `master` su `4ec4f4c`: 1019 esempi, 0 fallimenti, anche con i semi 1234, 4242 e 7; `gem build` senza warning; CI
  verde.

## Lotto 13 — ICH-294, ICH-295, ICH-296, ICH-298, ICH-299 (PR #14, merge `7f91ae7`)

### Fix

- **ICH-294 (`nucleo-06`, timeout massimo).** `Util::TIMEOUT` (`0.0..2147483647.0`) è l'intervallo usato da
  `Context#wait_input` e `Direct#get`: sopra il massimo `ArgumentError` prima di ogni attesa, con l'intervallo nel
  messaggio. Causa radice: `Util.float!` controllava solo che il valore fosse finito e >= 0, e `IO#wait_readable`
  solleva `RangeError` oltre `time_t`.
- **ICH-295 (`nucleo-08`, buffer di `getvec`).** `Context#queued_inputs` (privato) legge a blocchi di `GETVEC_MAX`
  (8192) slot: chiama ancora il C solo se il blocco è tornato pieno, l'ultimo evento non è EOF e `count` non è
  raggiunto; gli `Input` nascono dopo l'ultima chiamata C; `to_ptr` è valutato prima di ogni blocco. Causa radice:
  il buffer era di `count` × 52 byte a ogni tentativo, e a fine input il C riempie tutti gli slot di EOF.
- **ICH-296 (`ui-07`, timer `every`).** `run_timers` riprogramma il timer in un `ensure` attorno a `Timer#fire`.
  Causa radice: il timer usciva dalla lista prima del blocco e rientrava solo dopo un blocco riuscito.
- **ICH-298 (`ui-09`, tasti in coda).** Il primo `IO.select` di ogni `run` usa timeout 0. Causa radice: `read_input`
  si ferma appena `live?` è false, ma notcurses ha già svuotato il pipe di prontezza: gli eventi rimasti nella coda
  C non svegliavano il run successivo.
- **ICH-299 (`ui-12`, ritardi enormi).** `select_timeout` limita il valore a `0..86_400`. Causa radice: il tempo
  alla prima scadenza passava a `IO.select` senza limite superiore.

### Decisioni

- Regola 14, scelte dell'utente prima del fix: ICH-294 `ArgumentError` sopra il massimo (non "vale come `nil`");
  ICH-296 il timer resta programmato (non "si ferma"), dopo un approfondimento con tabella dei due contratti;
  ICH-299 limite in `select_timeout` (non `ArgumentError` in `after` ed `every`).
- Regola 14, round 1 della review (ICH-295): tra "solo documentazione", "più blocchi per chiamata", "issue
  separata" e "nessun cambio" l'utente ha scelto più blocchi per chiamata. I criteri 1 e 4, il vincolo tecnico e i
  test richiesti di ICH-295 sono stati riscritti su Linear dopo la conferma del testo.
- ICH-298: timeout 0 al primo `IO.select`, non uno `step` dopo il render iniziale: uno `stop` chiesto prima di `run`
  esce ancora senza eseguire i blocchi di `post`.
- Il massimo del timeout è in `Util` e non in `Context`, perché lo usa anche `Direct`.
- Buffer dei blocchi azzerati: la variante senza azzeramento (`MemoryPointer.new(type, n, false)`) non dava un
  guadagno misurabile e la spec con il C simulato leggeva memoria non inizializzata.

### Review (3 round, Fable e GPT)

- Round 1 (`f45d76d`): GPT APPROVABILE, nessun finding; Fable APPROVABILE CON RISERVE, un LOW: con il limite secco
  `getvec(count > 8192)` perdeva più eventi di `master` in una raffica più grande della coda (30000 tasti: 0 raffiche
  complete su 20, 4 su 20 su `master`). Corretto in `74d4573` con la lettura a blocchi.
- Round 2 (`74d4573`): GPT APPROVABILE, nessun finding; Fable un MEDIUM: `queued_inputs` leggeva `to_ptr` una sola
  volta, e un `close` da un gestore `trap` tra due blocchi portava a un SIGSEGV (9 prove su 28, 0 su `master`).
  Corretto in `1a68d5f`, con una spec che simula il contesto chiuso al secondo `to_ptr`.
- Round 3 (`1a68d5f`): nessun finding da entrambi; 9 mutazioni in memoria tutte rilevate dalle spec. Fuori dalla
  PR, già su `master`: ICH-463 (carattere UTF-8 a cavallo della lettura da 8192 byte) e ICH-464 (`to_ptr` e chiamata
  C non atomici per i gestori `trap`), create dopo la conferma dell'utente. Commento riassuntivo sulla PR.
- Il codice l'ha scritto una sessione Fable: la review Fable era meno indipendente di quella GPT, ma i due finding
  reali sono venuti da Fable.

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| La spec di ICH-298 passava già per il caso dell'eccezione | i timer di sicurezza cancellati dei run precedenti erano già scaduti e svegliavano il ciclo | un `EventLoop` nuovo per ogni coppia di tasti |
| `pty_spec.rb:170` fallito una volta con il seme 4242 | gara di tempi dell'esempio esistente: `getvec` si sveglia dopo il primo dei 4 tasti | non toccato (regola 16); 25 esecuzioni isolate su 25 verdi sul branch e su `master` |
| La CI della PR non partiva subito | ritardo di GitHub, circa 3 minuti | attesa in background con un ciclo `until gh run list ...` |
| Misure della raffica molto rumorose | distribuzione bimodale: la raffica arriva tutta o si ferma vicino a 8192-16384 | 40 esecuzioni alternate tra `master` e branch; con il fix 6 complete su 40, `master` 10 su 40: parità non raggiunta |
| Il reviewer Fable del round 2 non poteva cancellare `.review-tmp/` | il sistema di permessi ha negato `find -delete` | conferma dell'utente per `git worktree remove --force` con file non tracciati; nel round 3 il prompt chiede file di appoggio piccoli |
| `gem build` in locale stampa 18 warning | rdoc 7.2.0 e 8.1.0 installati insieme sulla VPS | nessun cambio: la gem si costruisce, la CI fa lo stesso passo ed è verde |

### Verifica finale

- Branch (`1a68d5f`): 1026 esempi, 0 fallimenti su Ruby 4.0.7, anche con i semi 1234, 4242 e 7; line coverage
  98,15 %; YARD 100 %, 0 warning; `ruby -w` senza warning. CI verde su tutta la matrice (Ruby 3.1.7–4.0.9) e Codecov.
- Ogni spec nuova falliva sul codice di prima (controllato prima di ogni fix); la seconda spec di ICH-296 (`cancel`
  e poi eccezione, `after` che solleva) è una guardia dei casi invariati e passa anche su `master`.
- `git diff ab75226 -- lib/notcurses/ffi lib/notcurses/ffi.rb`: vuoto.
- `master` su `7f91ae7`: 1026 esempi, 0 fallimenti, anche con i semi 1234, 4242 e 7; `gem build` riuscito (warning
  solo di rdoc, vedi sopra); CI verde.

## Lotto 14 — ICH-300, ICH-301, ICH-302, ICH-303 (PR #15, merge `d47e3ac`)

### Fix

- **ICH-300 (`nucleo-05`, stringhe di `Input`).** `Input#initialize` congela `@utf8` ed `@eff_text`; `synthesize`
  passa da `new`, quindi i due percorsi sono coperti. Causa radice: `freeze` sull'oggetto non congela le String
  costruite a runtime (`scrub`, `pack('U*')`), e `frozen_string_literal` copre solo i letterali; un `<<` del
  chiamante allungava `utf8` oltre i 5 byte di `char[5]` e `to_ffi` sollevava `IndexError`.
- **ICH-301 (`nucleo-07`, UTF-8 non valido).** `Util.take_string` fa `scrub` dopo `force_encoding`; NULL dà ancora
  `nil` e `free` resta in `ensure`. Causa radice: `take_string` marcava come UTF-8 byte che vengono da fuori dal
  wrapper (`getenv("LOGNAME")`, `pw_name`, la risposta del terminale in `termdesc_longterm`).
- **ICH-302 (`nucleo-09`, overflow di `ncnmetric`).** `check_metric_overflow!` (privato, `format.rb`) ripete il
  ciclo di `metric.c:53-59` con gli Integer di Ruby e solleva `ArgumentError` solo se il valore supera 2^64 - 1;
  lo chiamano `metric` dopo il controllo di `base` e `prefix_buffer`, che ora riceve la base (1000 o 1024). Causa
  radice: bug di notcurses 3.0.17, la guardia di `metric.c:56` controlla `dv`, che in quel ramo non cambia.
- **ICH-303 (`nucleo-10`, YARD).** Solo documentazione: `Context#refresh` e `#create_pile` si riferiscono all'area di
  rendering (`{#dims}`), non al terminale; spec che fissa `refresh == dims` e la pila `[18, 72]` con i margini.

### Decisioni

- Regola 14 (ICH-301): l'opzione scelta (`scrub` in `take_string`) è quella della issue. Il piano non ha mostrato le
  alternative prima del fix, come chiede la regola; la tabella delle opzioni (solo nei cinque metodi, String
  binaria, errore) è arrivata dopo la review, e l'utente ha confermato `scrub` in `take_string` prima del merge.
  Decisione registrata in un commento su ICH-301.
- ICH-302: controllo sulla coppia, non limite di `decimal` abbassato a `(2**64 - 1)/base`, come chiede il vincolo
  della issue; il range documentato resta `1..(2**64 - 1)/10`.
- ICH-302, round 1: `base.to_i` nel controllo invece di una validazione stretta (`base.is_a?(Integer)`): i valori
  che `metric` accetta su `master` restano accettati.
- Il bug di `ncnmetric` sta in una nuova sottosezione "Formato (`format.rb`)" della tabella dei bug aggirati, perché
  nessuna delle sottosezioni esistenti riguarda la formattazione (scelta approvata dall'utente nel piano).

### Review (2 round, Fable e GPT)

- Round 1 (`71b90a0`): GPT APPROVABILE, nessun finding; Fable APPROVABILE CON RISERVE, due LOW: con `base: 1000.0` o
  `1024.0` (accettati da `[1000, 1024].include?`) il controllo girava in aritmetica Float, rifiutava la coppia valida
  `(2**54 - 1, 2**60, 1024.0)` (regressione rispetto a `master`) e lasciava passare l'overflow
  `(313413999946230, 313413999946230001, 1000.0)`; mancavano le voci del CHANGELOG (regola di `RIPRESA.md`).
  Corretti in `7cf2632` e `40fbdf8`.
- Round 2 (`40fbdf8`): nessun finding da entrambi; fuzz del controllo contro `FFI.ncnmetric` (300 000 e 200 000
  coppie, basi intere e Float) senza discrepanze. Commento riassuntivo sulla PR.
- Fuori dalla PR, già su `master`: `Marshal.load(Marshal.dump(ev))` restituisce un `Input` non congelato; nessuna
  issue (fuori dai criteri di ICH-300).

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| 10 esempi falliti nel worktree (9 in `direct_spec.rb`, `pty_spec.rb:215`) | il submodule `notcurses` del worktree è vuoto: mancano le immagini di `notcurses/data` | `direct_spec.rb` del checkout principale con la `lib` del worktree (60 su 60); non si inizializza il submodule, perché `git worktree remove` rifiuta i worktree con submodule; la CI li esegue ed è verde |
| `pty_spec.rb` lanciato dal checkout principale non prova il codice del worktree | il processo figlio usa `lib_dir` relativo al file di spec | esempio lasciato alla CI |
| RuboCop non eseguibile con `bundle exec` | la gem non è nel `Gemfile` e la CI non ha uno step di lint | ICH-465 (Standard con `rubocop-performance` e `rubocop-thread_safety`, struttura del progetto ikigai) |
| Il reviewer GPT del round 2 non poteva cancellare `.review-tmp/` | il sistema di permessi ha negato la cancellazione | conferma dell'utente per `git worktree remove --force` (solo 75 file in `.review-tmp/`) |
| Il branch remoto della PR esisteva ancora dopo il merge | GitHub non lo ha cancellato | `git push origin --delete` su richiesta dell'utente |

### Verifica finale

- Branch (`40fbdf8`): 1033 esempi su Ruby 4.0.7, solo i 10 esempi delle immagini falliti nel worktree (vedi sopra);
  YARD 100 %, 0 warning; `ruby -w` senza warning. CI verde su tutta la matrice (Ruby 3.1.7–4.0.9) e Codecov.
- Ogni spec nuova falliva sul codice di prima (controllato dal reviewer Fable nel round 1: 6 esempi rossi con la
  `lib` di `d507e3e`); la spec di ICH-303 fissa il contratto e passa anche su `master`.
- `git diff ab75226 -- lib/notcurses/ffi lib/notcurses/ffi.rb`: vuoto.
- `master` su `d47e3ac`: 1033 esempi, 0 fallimenti con i semi 1234, 4242 e 7 (le immagini ci sono nel checkout
  principale); `gem build` riuscito (warning solo di rdoc, vedi lotto 13); CI verde.

## Fuori dai lotti — ICH-465, RuboCop (PR #16, merge `ba3367f`)

### Cambi

- **ICH-465 (`Improvement`, RuboCop nel `Gemfile` e nella CI).** Cinque commit: `92d8b96` (gem, `.rubocop.yml`,
  `.rubocop_todo.yml`), `ca327d9` (step della CI), `0829f12` (README), `7cac717` (`parallel < 2`), `e1f5e58`
  (`Lint/RedundantCopDisableDirective` acceso). Nessun cambio in `lib/`, `spec/`, `examples/` e nel gemspec; nessuna
  voce nel CHANGELOG (non è un fix e il contenuto della gem non cambia).
- `.rubocop_todo.yml` si rigenera identico con il comando scritto nella sua intestazione
  (`--auto-gen-config --exclude-limit 1000 --no-auto-gen-timestamp`): 5307 offense in 93 file, 46 cop, solo
  `Exclude` per file.

### Decisioni

- `--exclude-limit 1000` (più dei 93 file): nessun cop spento per tutto il progetto, come chiede la issue.
- Lo step «RuboCop senza offense» è l'ultimo del job `full: true`, non accanto a YARD: un fallimento del linter non
  salta gli artifact.
- `parallel < 2` nel `Gemfile`, non solo una correzione del lockfile: il vincolo regge anche ai `bundle update` fatti
  con un Ruby recente (scelta dell'utente dopo la review: «fixa entrambi»).
- `Lint/RedundantCopDisableDirective` acceso in `.rubocop.yml`: differenza voluta dalla configurazione di riferimento
  della issue (scelta dell'utente dopo la review). Il criterio della issue sui 10 commenti `# rubocop:disable`
  passava a vuoto, perché Standard spegne il cop.
- I file YAML nuovi non hanno l'intestazione "Generated from notcurses": la regola 7 riguarda i file Ruby generati
  (`codecov.yml` non la ha).
- Merge fatto dalla sessione su richiesta dell'utente («chiudila tu adesso»), con la CI verde.

### Review (1 round, stessa sessione dell'implementazione)

- `/trinity:workflow:3_independent-review` su `0829f12`: NON APPROVABILE. HIGH: il lockfile, generato con Ruby
  4.0.7, bloccava `parallel 2.3.0`, che richiede Ruby >= 3.3; il job Ruby 3.2.11 installa dal lockfile
  (`BUNDLE_FROZEN`) e `bundle install` falliva. Il job 3.1.7 non lo vedeva, perché non usa il lockfile. LOW: 9
  commenti `# rubocop:disable` su 10 servono; quello di `lib/notcurses/ui/component.rb:223`
  (`Lint/UnusedMethodArgument`) no, perché Standard spegne anche quel cop. Corretti in `7cac717` ed `e1f5e58`, senza
  un nuovo round; il commento resta (la issue vieta i cambi in `lib/`) e il file è nel todo.
- Prove del reviewer senza finding: `.rubocop.yml` identico al riferimento della issue (prima di `e1f5e58`); un file
  nuovo con una offense e una offense di un cop non escluso in un file esistente danno esito 1; RuboCop non entra
  nelle directory nascoste, quindi i worktree in `.claude/worktrees/` non cambiano l'esito.

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| `bundle install` rosso nel job Ruby 3.2.11 | `bundle lock` con Ruby 4.0.7 sceglie `parallel 2.3.0` (Ruby >= 3.3) | `gem 'parallel', '< 2'` nel `Gemfile`; lockfile con la 1.28.0 |
| Su Ruby 3.2 Bundler avvisa per `prism 2.1.0` | le gem precompilate di `prism` richiedono Ruby >= 3.3: su 3.2 si compila la gem generica | nessuna: il job è verde |
| PR aperta prima dell'esito della CI | `2_work-issue` si ferma dopo l'apertura della PR | il job rosso è emerso nella review: controlla sempre `gh pr checks <n> --watch` prima della review |
| 10 esempi falliti nel worktree | submodule `notcurses` non inizializzato | `git submodule update --init --depth 1 notcurses` nel worktree; poi `git worktree remove --force` (il `deinit` non basta: Git guarda `.git/worktrees/<nome>/modules`) |
| Un comando con `rm -rf` in coda, eseguito dall'utente dopo la rimozione del worktree di review | il comando ricreava con `mkdir -p` la directory già rimossa | tre directory vuote tolte con `rmdir`; nei comandi di prova niente `rm` |
| `linear.py` senza il bit di esecuzione | permessi del file della skill | `chmod +x` su richiesta dell'utente |
| Chiusura (passo 7) non eseguita dopo il merge e dopo `5_remove-worktree` | la sessione ha seguito solo i command del workflow, senza leggere `RIPRESA.md` | chiusura fatta su richiesta dell'utente; `5_remove-worktree` ora la ricorda |

### Verifica finale

- Branch (`e1f5e58`): `bundle exec rubocop` 95 file, 0 offense; 1033 esempi, 0 fallimenti su Ruby 4.0.7 con il
  submodule inizializzato; `ruby -w` senza warning. CI verde su tutta la matrice (Ruby 3.1.7–4.0.9) e Codecov.
- `git diff ab75226 -- lib/notcurses/ffi lib/notcurses/ffi.rb`: vuoto.
- `master` su `ba3367f`: 1033 esempi, 0 fallimenti in ordine normale e con i semi 1234, 4242 e 7; RuboCop senza
  offense; `gem build` riuscito; CI verde.

## Lotto 15 — ICH-304, ICH-305 (PR #17, merge `28ef91a`)

### Fix

- **ICH-304 (`ffi-04`, esempio `Notcurses::UI` del README).** Il blocco di `Context.open` restituisce
  `[app.run, name.text]` e `puts` sta dopo il blocco, come in `examples/demo.rb`. Causa radice: `Context.open` usa lo
  schermo alternativo, quindi una riga stampata dentro il blocco sparisce alla chiusura (`\e[?1049l`). Nessun
  cambio in `lib/`, nessuna spec nuova (la suite non esegue gli esempi del README).
- **ICH-305 (`ffi-06`, limite minimo di `ffi`).** `~> 1.16` nel gemspec, nel `Gemfile` e in `spec/gemspec_spec.rb`;
  nel lockfile cambia solo la riga `ffi (~> 1.16)` di `DEPENDENCIES`. Causa radice: il vincolo `~> 1.15` veniva dal
  `Gemfile` della Fase 4, non da una API; `spec/inline_reimpl_spec.rb` usa `FFI::Library#attached_functions`
  (ffi 1.16.0) e ffi 1.15.0 e 1.15.1 non cercano in `/opt/homebrew/lib`.

### Decisioni

- La voce di ICH-305 sta nell'elenco "Cambi a `Gemfile` e `Gemfile.lock`" della sezione delle correzioni, non nella
  tabella della Fase 4 che la issue indicava (`RICONSEGNA.md:804-809`): scelta approvata dall'utente nel piano,
  criterio della issue aggiornato su Linear.
- Le citazioni di `ffi ~> 1.15` nelle tabelle delle fasi 1, 4 e 5 di `RICONSEGNA.md` e in `memory/` restano: sono
  lo stato di allora.
- ICH-304 ha una voce nel CHANGELOG anche se la issue non la chiede (nota di `RIPRESA.md`: ogni fix ha una voce).
- Il commento `# :stop, :eof o :interrupt (Ctrl+C)` resta identico sulla riga di `[app.run, name.text]`, come chiede
  il criterio.
- Implementazione fatta dalla sessione (Fable), non delegata: sette file, modifiche già definite dalle issue.

### Review (1 round, Fable e GPT)

- Round 1 (`f2b1784`): Fable e GPT APPROVABILE CON RISERVE, nessun finding. La riserva è la prova a mano di ICH-304
  in un terminale reale, fatta dall'utente prima del merge (`stop: abc` resta sullo schermo). I reviewer hanno
  ripetuto la riproduzione nel pty sul README di `master` (6237 prima di 6291) e del branch (6777 dopo 6280), anche
  con Ctrl+C, testo vuoto, testo UTF-8 e il pulsante "Entra". Commento riassuntivo sulla PR.
- Fuori dalla PR, già su `master`: l'esempio YARD di `Notcurses::UI::App` (`lib/notcurses/ui/app.rb:50-60`) stampa
  dentro il blocco di `Context.open`; ICH-473, su richiesta dell'utente.
- Mai eseguita la suite con ffi 1.16.x: CI e lockfile usano la 1.17.4. I reviewer hanno letto il CHANGELOG di ffi
  dalla 1.16.0 alla 1.17.4 e non hanno trovato API più recenti in uso.

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| `spec/integration/pty_spec.rb:170` fallito una volta nel worktree (`getvec x` invece di `getvec x,y,z,UP`) | la gara di tempi nota di `getvec` | suite ripetuta: 0 fallimenti; l'esempio da solo passa 5 volte su 5 |
| Il reviewer Fable non ha cancellato `.review-tmp/` (4 file) | un hook ha messo in coda il suo `rm -rf` per la conferma dell'utente | conferma dell'utente per `git worktree remove --force` |
| Un comando in coda del reviewer GPT, approvato dall'utente, è fallito con exit 125 | il suo worktree era già rimosso (era pulito) | nessuna |
| Prima prova a mano con `stop: abx` | un tasto diverso nella prova | seconda prova: `stop: abc` |

### Verifica finale

- Branch (`f2b1784`): 1033 esempi, 0 fallimenti su Ruby 4.0.7 con il submodule inizializzato; `bundle exec rubocop`
  95 file, 0 offense; `gem build` riuscito. CI verde su tutta la matrice (Ruby 3.1.7–4.0.9, compreso il job 3.2.11
  che installa dal lockfile) e Codecov.
- La spec di ICH-305 falliva prima del fix (`expected [["ffi", "~> 1.16"]], got [["ffi", "~> 1.15"]]`); il gemspec
  rifiuta ffi 1.15.0 e 1.15.5 e accetta la 1.16.0.
- `git diff ab75226 -- lib/notcurses/ffi lib/notcurses/ffi.rb`: vuoto.
- `master` su `28ef91a`: 1033 esempi, 0 fallimenti in ordine normale e con i semi 1234, 4242 e 7; RuboCop senza
  offense; `ruby -w` senza warning; `gem build` riuscito; CI verde.

## Lotto 16 — ICH-306…ICH-311 (PR #18, merge `9672bd5`)

### Fix

Solo spec e CI: nessun cambio in `lib/`. Ogni spec nuova passa sul codice attuale; la prova è la mutazione chiesta
dalla issue, che la fa fallire.

- **ICH-306 (`nucleo-11`, Alt nel campo deprecato).** `spec/notcurses/input_spec.rb`: un `NcInput` con `alt = true`
  e `modifiers = 0` dà `alt?`, il bit `NCKEY_MOD_ALT`, `modifier_list == [:alt]` e `to_ffi[:modifiers]` con Alt.
  `get_script` di `spec/integration/pty_spec.rb` scrive `"\ex"` con una sola `master.write` prima dell'Interrupt e
  si aspetta `alt x true [:alt]`. Causa radice: ogni spec costruiva Alt con `Input.synthesize(modifiers: [:alt])`,
  quindi nessuna passava da `input.rb:395`. Mutazione (riga tolta in una copia di `lib/`): i due esempi falliscono.
- **ICH-307 (`nucleo-12`, `Palette#use`).** Dopo `use`, `described_class.open(nc) { |p| p.rgb(3) }` deve dare
  `[1, 2, 3]`. Causa radice: l'esempio controllava solo il ritorno `self`. Mutazioni: `use` senza `ncpalette_use` e
  `use` con una copia `ncpalette_new` danno `got: [0, 0, 0]`.
- **ICH-308 (`direct-visual-04`, `count:` negativo).** Per i quattro `cursor_*`: `count: -1` solleva
  `ArgumentError` con `/count/` e `ncdirect_cursor_*` non viene chiamata; la chiamata posizionale resta, con
  `/wrong number of arguments/`. Causa radice: la chiamata posizionale prendeva l'errore di arità di Ruby, non la
  validazione. Mutazione: senza `Util.nonneg_int!` in uno qualsiasi dei quattro metodi l'esempio fallisce.
- **ICH-309 (`ffi-05`, layout FFI contro gli header C).** Nuova `spec/ffi_layout_spec.rb`: genera un programma C
  dalle definizioni Ruby, lo compila con `-D_GNU_SOURCE` (più `pkg-config --cflags notcurses` se c'è) in
  `Dir.mktmpdir` e confronta 26 struct (sizeof, `_Alignof`, offset e dimensione di 191 campi), gli offset dei flag di
  `Termios` con `sizeof(struct termios) <= Termios.size`, e le 343 costanti (286 Integer come signed 64 bit, 57
  String, le 51 wide in UTF-8 con un `_Generic` e una codifica a mano). Mappa esplicita classe → tipo C (27 voci);
  una classe senza voce o una costante senza macro C fa fallire la spec; un errore di compilazione è un fallimento;
  skip con il motivo solo senza compilatore o senza header usabili. `version_spec.rb`: `lib_version` deve iniziare
  con `HEADER_VERSION`. Causa radice: il confronto con il C era stato fatto una volta sola, nella Fase 1, con un
  programma di appoggio. Mutazioni: scambio `cellelisions`/`cellemissions`, `NCKEY_F60` + 1, un campo rinominato
  (errore di compilazione), una stringa wide cambiata: la spec fallisce. Nessuna differenza tra Ruby e C.
- **ICH-310 (`ui-13`, kitty e `Key::RESIZE`).** `spec/integration/ui_pty_spec.rb`: `kitty_app_script` riusa
  `kitty_prelude` (lotto 7) e manda le sequenze CSI u della issue: testo `abb` con ripetizione e rilasci, Ctrl+X con
  NumLock una volta, Tab al `Button`, Invio una volta, i 5 rilasci a `on_input` e a nessun componente (un
  `offer_input` singleton su `TextInput` e `Button` li conta: 0), Ctrl+C → `:interrupt`. `winch_script`
  (`no_winch_sighandler: false`, pty come terminale di controllo) cambia `winsize` a 30x100, aspetta 0,2 s e manda
  `z`: log `[[:resize, 30, 100], [:z, [30, 100]]]`. Mutazioni: NumLock in `MOD_OTHER` fa fallire l'esempio kitty
  nuovo e anche quello dei segnali kitty già esistente; `when Key::RESIZE then nil` fa fallire l'esempio della
  modalità B (log `[[:z, [24, 80]], [:resize, 30, 100]]`).
- **ICH-311 (`ffi-02`, codecov-action).** `ci.yml`: `codecov/codecov-action@303a32d7a59b442fa8d48b6a1cc6825c09c847a5
  # v7.1.1`, `if:` e `with:` invariati. `v7.1.1` è un tag annotato: lo SHA è quello del commit (`gh api
  .../commits/v7.1.1`), non dell'oggetto tag (`23209167…`). Nuova `spec/ci_workflow_spec.rb` (falliva su `@v7`).
  Punto 5 di "Cosa serve alla fase successiva" della Fase 4 in `RICONSEGNA.md`: SHA e comando per leggerlo.

### Decisioni

- ICH-310: il terminale finto con kitty esisteva già (lotto 7), quindi il primo criterio era coperto; l'esempio
  della modalità B ha un preambolo proprio con `setsid` e `TIOCSCTTY`, perché il gestore SIGWINCH di notcurses
  riceve il segnale solo dal terminale di controllo.
- ICH-308: la chiamata posizionale resta, come controllo dell'API solo keyword (la issue lo permette).
- Nessuna voce in `CHANGELOG.md`: il lotto cambia solo spec e CI, come ICH-465.
- Implementazione: ICH-306, 307, 308 e 311 dalla sessione (Opus); ICH-309 e ICH-310 da due `trinity:fast-worker`
  (Sonnet) in parallelo, su file separati, senza commit; diff e mutazioni ricontrollati dalla sessione.

### Review (2 round, Fable e GPT)

- Round 1 (`9fb5117`): GPT nessun finding. Fable un LOW: `spec/ci_workflow_spec.rb` e `spec/ffi_layout_spec.rb`
  senza l'intestazione di due righe (`# Generated from notcurses 3.0.17`, `# Source: ...`) che hanno tutti gli altri
  93 file Ruby, spec scritte a mano comprese. Corretto in `9213c75`.
- Round 2 (`9213c75`): nessun finding da Fable e da GPT. Commento riassuntivo sulla PR.
- Note dei reviewer, non finding: lo skip di `ffi_layout_spec.rb` non fa fallire la CI (come chiede la issue; nota
  nella sezione CI di `RICONSEGNA.md`); un campo C nuovo dentro il padding finale di una struct non cambia sizeof né
  offset; `ci_workflow_spec.rb` legge solo `ci.yml`; `winch_script` è la terza copia del preambolo pty senza kitty.

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| `echo =====` ha fermato il ciclo di lettura delle issue | in zsh una parola che comincia con `=` è una expansion del percorso | testo tra virgolette o `jq` |
| La mutazione di ICH-306 non poteva toccare `lib/` del worktree | il worker di ICH-310 usava lo stesso `lib/` in quel momento | mutazione su una copia di `lib/` e `spec/` nello scratchpad; nella copia fallisce anche l'esempio `:pixel`, per le immagini del submodule assenti |
| `pty_spec.rb:173` fallisce sotto carico (circa 1 su 30, review Fable round 2) | la gara di tempi nota di `getvec` (`getvec x` invece di `getvec x,y,z,UP`), già su `master` | nessuna; la riga nuova di ICH-306 era corretta nello stesso output |
| Un comando del reviewer Fable con `rm -f` è andato in coda per la conferma | hook Blast Radius | l'utente l'ha approvato; worktree di review rimossi con `status` vuoto |
| `sleep 0.2` nell'esempio della modalità B | il gestore SIGWINCH deve girare prima del tasto | 0 fallimenti in 5 giri del worker e in 42 giri dei reviewer, 30 sotto carico |

### Verifica finale

- Branch (`9213c75`): 1044 esempi, 0 fallimenti su Ruby 4.0.7 (11 esempi in più del lotto 15), anche con i semi
  1234, 4242 e 7; `bundle exec rubocop` 97 file, 0 offense; `actionlint` su `ci.yml` senza errori. CI verde su tutta
  la matrice (Ruby 3.1.7–4.0.9) e Codecov, senza esempi `pending` nei log: `ffi_layout_spec.rb` gira in ogni job.
- `git diff ab75226 -- lib/notcurses/ffi lib/notcurses/ffi.rb`: vuoto.
- `master` su `9672bd5`: 1044 esempi, 0 fallimenti in ordine normale e con i semi 1234, 4242 e 7; RuboCop senza
  offense; `ruby -w` senza warning; `gem build` riuscito. CI di `master` (run 43642485059) verde su tutta la
  matrice; lo step "Upload su Codecov" con lo SHA fissato è riuscito al primo push su `master` (ultimo criterio di
  ICH-311). Le sei issue sono a Done.

## Lotto 17 — ICH-312, ICH-313 (PR #19, merge `e3e8737`)

### Fix

Fase 1 congelata (regola 1): lotto approvato dall'utente il 2026-11-14. `git diff ab75226 -- lib/notcurses/ffi
lib/notcurses/ffi.rb` contiene solo le righe delle due issue.

- **ICH-312 (`ffi-01`, GVL durante l'I/O di ffmpeg).** `blocking: true` su `ncvisual_from_file`, `ncvisual_decode`,
  `ncvisual_decode_loop`, `ncdirect_render_frame` e `ncdirectf_from_file` (`functions.rb:287`, `298-299`, `609`,
  `611`); firme invariate, `ncdirect_stream` senza flag (il wrapper non la chiama). Commento di testa di
  `functions.rb`, YARD dei 7 metodi, commenti di classe di `Direct` e `FdPlane`, decisione 20 di
  `memory/fase1-ffi-raw.md` (ora 15 funzioni, con A3-02), "Modifiche successive" della Fase 1 e `CHANGELOG.md`.
  Causa radice: la decisione 20 teneva il GVL per "scritture e render brevi", ma queste cinque funzioni fanno I/O di
  ffmpeg senza limite di tempo (FIFO, URL, file system lento), e lo stesso codice C girava già senza il GVL dentro
  `ncdirect_render_image` e `ncvisual_stream`. Spec: `pty_spec.rb`, FIFO riempita dopo 0,3 s da un thread del figlio
  per `Visual.from_file`, `render_frame` e `load_image` (prima il figlio restava bloccato e `run_child` lo uccideva).
  Repro della issue: `Direct#render_frame: returned after 0.30 s`.
- **ICH-313 (`ffi-03`, `wchar_t` e `uintmax_t`).** `typedefs.rb` definisce `:wchar_t` (`:int32`) e `:uintmax_t`
  (`:uint64`) in `Notcurses::FFI` solo se `::FFI.find_type` solleva `TypeError`; su Linux x86_64 il modulo non
  aggiunge typedef. Le cinque `::FFI::MemoryPointer.new(:wchar_t, n)` (`inline_reimpl.rb:794`, `3042`, `3054`,
  `3066`, `direct.rb` `Direct#box_chars`) usano `:int32`. Causa radice: il commento di `typedefs.rb` dava per certi i
  tipi del `types.conf` di ffi, che mancano su FreeBSD, NetBSD, OpenBSD e Linux i386/ppc64/riscv64/s390x; e
  `MemoryPointer.new(Symbol)` usa la mappa globale di ffi, che non vede le typedef del modulo. Spec:
  `ffi_sanity_spec.rb` copia la `lib/` di ffi, toglie le due typedef da `types.conf` e avvia un figlio con
  `--disable-gems` (prima: `TypeError: unable to resolve type 'uintmax_t'` a `functions.rb:541`).

### Decisioni

- Regola 14, ICH-313: typedef solo se `::FFI.find_type` solleva `TypeError` (chiesta dalla issue); una typedef
  senza condizione avrebbe cambiato `wchar_t` da `uint` a `int32` su aarch64.
- La spec FIFO di `pty_spec.rb` era già nel worktree, non committata, prima che la sessione la scrivesse; nessuna
  sessione dice di averla scritta. L'utente ha scelto di tenerla (corrisponde ai requisiti).
- Review, protezioni non fatte nella PR (non sono fix minimi; per ICH-475 la regola 3 vieta un lock): limite scritto
  nello YARD, protezione in ICH-474 (LOW, priorità 4) e ICH-475 (MEDIUM, priorità 3), `related` a ICH-312.
- Implementazione e fix dalla sessione (Opus), senza subagenti.

### Review (3 round, Fable e GPT)

- Round 1 (`6d5c03c`): GPT nessun finding. Fable un LOW: con `blocking: true` un'eccezione asincrona arriva al
  ritorno della chiamata C e la risorsa creata (visual, frame, immagine, con il file aperto) va persa; `fd_plane.rb`
  diceva che il kill di `close` non arriva mai a metà di una chiamata (`FdPlane#run` usa `:on_blocking`, e la chiamata
  FFI senza GVL conta come attesa). Testo corretto in `9589611`, protezione in ICH-474. Lacuna di test: la ffi
  simulata copriva 2 delle 5 chiamate `:int32`; coperte in `7d4858a` (mutazioni: ognuna fa fallire l'esempio).
- Round 2 (`7d4858a`): GPT nessun finding. Fable un MEDIUM: chiudere il contesto (anche con `at_exit`) mentre un
  altro thread è dentro `decode`/`decode_loop` è un use-after-free (5 su 65 del reviewer, 1 blocco su 30 della
  sessione; 65 su 65 pulite senza `blocking`); un LOW: le frasi di `FdPlane` non elencavano `Visual#stream`.
  Testo corretto in `0e1d663`, protezione in ICH-475.
- Round 3 (`0e1d663`): GPT nessun finding. Fable un LOW: il rimedio "ferma il thread" non vale per `Thread#kill`
  (la chiamata C continua); corretto dopo il loop senza review in `f690db3` (`Thread#join`). Commento riassuntivo
  sulla PR.
- Note dei reviewer, non finding: `Direct#render_frame` e simili passano al C la String del chiamante senza copia
  (come `render_image`); `spec/support/nc_oracle.rb` usa ancora `:wchar_t`/`:uintmax_t`; "8 funzioni" in
  `memory/fase2-wrapper-idiomatico.md` (da A3-02).

### Problemi e soluzioni

| Problema | Causa | Soluzione |
| --- | --- | --- |
| `spec/integration/pty_spec.rb` modificato nel worktree prima della scrittura della sessione | origine sconosciuta; la sessione parallela `notcursesruby-14` dice di non averlo toccato | chiesto all'utente, che l'ha tenuto; avvisata l'altra sessione |
| `findReferences` di ruby-lsp su un `attach_function` restituisce tutte le chiamate | i metodi di `attach_function` sono dinamici; il server indicizza il repository principale, non il worktree | `grep` per i chiamanti delle funzioni FFI |
| YARD: `Cannot resolve link to Image.new` nel commento di classe di `Direct` | il link di un commento di classe si risolve dal namespace esterno | `{Direct::Image#initialize}` |
| RuboCop: `Layout/SpaceInsideHashLiteralBraces` nel codice nuovo | Standard vuole `{a: 1}`; i file esistenti sono esclusi cop per cop | hash senza spazi nel codice nuovo |
| Il primo giro di mutazioni di ICH-313 non provava nulla | il filtro `-e` non trovava l'esempio (0 esempi, nessuna riga `examples,`) | mutazioni rieseguite su tutto il file: 3 su 3 falliscono |
| Job Ruby 3.1.7 rosso su `0e1d663` in `context_spec.rb:358` (`getvec` chiamata 2 volte) | spec non toccata dal lotto; corsa nell'esempio, non riprodotta | verde su `7d4858a` e `f690db3`; nessuna issue finché non si ripete |
| `git worktree remove` rifiuta i worktree di review | i reviewer inizializzano il submodule `notcurses` | `--force` (approvato), con `status` vuoto |

### Verifica finale

- Branch (`f690db3`): 1046 esempi, 0 fallimenti su Ruby 4.0.7 (2 esempi in più del lotto 16); `bundle exec rubocop`
  97 file, 0 offense; YARD 0 warning, 100 %. CI verde su tutta la matrice (Ruby 3.1.7–4.0.9) e Codecov.
- `git diff ab75226 -- lib/notcurses/ffi lib/notcurses/ffi.rb`: `functions.rb`, `inline_reimpl.rb` e `typedefs.rb`,
  solo le righe di ICH-312 e ICH-313.
- `master` su `e3e8737`: 1046 esempi, 0 fallimenti in ordine normale e con i semi 1234, 4242 e 7; RuboCop senza
  offense; YARD 0 warning, 100 %; `ruby -w` senza warning; `gem build` riuscito. CI di `master` (run 43652653505)
  verde su tutta la matrice. ICH-312 e ICH-313 sono a Done.
