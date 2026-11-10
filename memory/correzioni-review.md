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
