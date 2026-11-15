# RIPRESA — prompt per la prossima sessione

> Avvio: incolla questo file nella nuova sessione di Claude Code, oppure scrivi «Leggi RIPRESA.md ed esegui il
> prompt». Scritto il 2026-11-15, dopo la Parte 3 della Fase 5 su macOS: la PR #21 (ICH-478, branch
> `test/fase5-macos`, ultimo commit `db15e62`) è aperta, con la CI verde, e aspetta la conferma del merge. Il
> prossimo passo è il merge della PR #21, poi la Parte 4 (sezione "Parte 4 — cosa resta"). Il prompt
> riprende quello della Fase 5 scritto il 2026-10-27 (`git show 49732a3:RIPRESA.md`), aggiornato allo stato attuale.

## Contesto

- **Progetto:** binding Ruby completo per notcurses 3.0.17. Repository **privato**
  https://github.com/ichelema/notcursesruby, branch `master`. Gem `notcursesruby` 0.1.0 (Apache-2.0),
  `require 'notcurses'`; non pubblicata su rubygems.org.
- **Fase 1** (layer FFI raw, `lib/notcurses/ffi.rb` e `lib/notcurses/ffi/`): completa, `465418f`; cambiata per
  ICH-229 (`afb91c8`) e per il lotto 17 (ICH-312 `blocking: true` sulle funzioni di I/O di ffmpeg, ICH-313 typedef
  `:wchar_t` e `:uintmax_t`; PR #19, merge `e3e8737`).
- **Fase 2** (wrapper Ruby idiomatico), **Fase 3** (`Notcurses::UI`), **Fase 4** (pacchetto, YARD, coverage, CI):
  complete. Dettagli nelle sezioni omonime di `RICONSEGNA.md`.
- **Correzioni della revisione del 2026-11-06:** chiuse. 17 lotti, PR #2…#19 (PR #16 = ICH-465, RuboCop), 45 issue a
  Done. Dettagli in `RICONSEGNA.md` ("Correzioni della revisione del 2026-11-06") e in `memory/correzioni-review.md`.
- **Fase 5, Parti 1 e 2 (Linux):** fatte il 2026-11-15. Design approvato in `memory/fase5-design.md`, log in
  `memory/fase5-terminali-macos.md`. PR #20 (merge `4d3430a`): spec grafiche in `spec/graphics/` (solo con
  `NC_GRAPHICS=1` in Kitty o Ghostty) e rimozione di `Util.timespec`.
- **Fase 5, Parte 3 (macOS):** fatta il 2026-11-15 su un MacBook Pro M1 (macOS 26.5.2), PR #21 aperta (ICH-478).
  Ambiente, esiti, problemi e punto aperto in `memory/fase5-terminali-macos.md`, sezione "Parte 3 — macOS".
  Review del 2026-11-15 (stesso agente, non indipendente): F1 corretto in `db15e62`; F2 e F3 in "Parte 4".
- **Stato al `db15e62` (branch della PR #21):** 1048 esempi, 0 fallimenti (su macOS 11 pending con il motivo);
  su `master` prima del merge 1046 esempi. Valori di `master`: `bundle exec rubocop` 0 offense (99 file). Soglie di coverage:
  98 % totale, 90 % per file, layer FFI escluso.
- **CI:** container `archlinux:base` fissato per digest, pacchetti dello snapshot `2026/10/26` dell'Arch Linux Archive
  (`notcurses 3.0.17-3`, `ffmpeg 2:9.0.2-2`), Ruby da mise, matrice 3.1.7, 3.2.11, 3.3.13, 3.4.12, 4.0.9. Lo step
  RuboCop gira solo nel job 4.0.9. `spec/ffi_layout_spec.rb` compila un programma C contro gli header (serve `gcc`).
  Status di Codecov informativi (`codecov.yml`). I commit di sola documentazione usano `[skip ci]`.
- **Submodule `notcurses/`:** su `v3.0.17-22-gb26048eeb`; usa `notcurses/src/` per la semantica del C, non
  `libnotcurses-sys/`. `notcurses/data` serve alle spec delle immagini.
- **Bug di notcurses 3.0.17:** nelle tabelle di `RICONSEGNA.md` (Fase 2 e Fase 3). Per uno nuovo vale la regola 11.

### Punti aperti

1. **`Util.timespec`:** rimosso nella PR #20 (scelta dell'utente del 2026-11-15). Punto chiuso.
2. **Issue in Backlog:** ICH-441, ICH-448, ICH-449, ICH-450, ICH-454, ICH-455, ICH-456, ICH-457, ICH-458, ICH-459,
   ICH-460, ICH-461, ICH-463, ICH-464, ICH-469, ICH-470, ICH-473, ICH-474, ICH-475 (elenco in `RICONSEGNA.md`,
   "Issue aperte nate dai lotti"), più ICH-214…ICH-232. **Restano fuori dalla Fase 5** (scelta dell'utente del
   2026-11-15). ICH-454, ICH-455, ICH-456 (Ctrl+C e linesigs con il protocollo kitty) e ICH-458 (`Direct#stream`
   con `:pixel`) riguardano proprio Kitty e Ghostty: se una prova le incontra, cita la issue nel log e non correggerla.
3. **Podman:** installato sulla VPS (6.1.4, rootless). Serve a provare i job della CI in locale (comandi in
   "Comandi"); sulla macchina dell'utente può mancare.

## Dove gira questa fase

Le fasi 1–4 e i lotti 12–17 sono stati fatti su una **VPS** Arch Linux, senza terminale grafico. La Fase 5 gira sulla
**macchina dell'utente**, in una sessione di Claude Code avviata dentro Kitty o Ghostty:

| Sistema | Terminali | Protocollo grafico |
| --- | --- | --- |
| Linux (CachyOS) | Kitty, Ghostty | kitty graphics (Kitty e Ghostty); niente sixel |
| macOS | Kitty, Ghostty | kitty graphics; niente sixel |

- Linux: **fatto** (Parti 1 e 2). Ambiente e risultati in `memory/fase5-terminali-macos.md`. Se la sessione parte su
  Linux o sulla VPS e non su macOS, la Parte 3 non si può fare: dillo all'utente e fermati dopo "Prima di iniziare".
- macOS: **fatto** (Parte 3). Checkout in `/Users/sphynx/Sviluppo/Progetti/Personali/20261027_notcursesruby`;
  Ruby 4.0.9 di frum in `~/.frum/versions/4.0.9/bin` (mettilo all'inizio del `PATH`: il Ruby 4.0.7 di mise non ha
  le gem); `brew install coreutils` per `timeout`; Kitty 0.50.0 e Ghostty 1.4.0 installati.
- Sixel resta non provato (nessuno dei due terminali lo supporta): scrivilo nei risultati.
- **Prova preliminare del 2026-10-27** sulla VPS, dentro herdr (multiplexer con Ghostty come backend,
  `TERM=xterm-256color`), con uno script che disegna `notcurses/data/worldmap.png` con ogni blitter e
  `no_degrade: true`: `detected_terminal` = `XTerm` (herdr risponde come XTerm), `can_pixel?` true e blit `:pixel`
  riuscito (celle 16×35 pixel); `:half`, `:braille`, `:ascii` riusciti; `:quad`, `:sextant`, `:octant` non
  disponibili, perché le euristiche di XTerm (`termdesc.c:844-857`) non li attivano. Con Ghostty riconosciuto
  direttamente (`apply_ghostty_heuristics`, `termdesc.c:930-933`) ci si aspettano quadranti e sestanti, non ottanti.
  Senza `no_degrade: true` un blitter non supportato ripiega in silenzio e il blit sembra riuscito.
- Il server Hindsight (`127.0.0.1:8888`) può non esistere sulla macchina dell'utente: se il recall non risponde,
  prosegui con `RICONSEGNA.md` e i file `memory/`, e dillo in una riga.
- La CI non cambia (scelta dell'utente): niente job grafico headless.

## Obiettivo

La Fase 5 prova i blitter grafici su un terminale vero e porta il binding su macOS. Oggi le spec girano su `/dev/null`
o su un pty finto, i blitter a pixel non sono provati e macOS non è mai stato provato. La fase non aggiunge funzionalità
al binding.

1. **Parte 1 (Linux):** ambiente, prove grafiche in Kitty e Ghostty, design, approvazione dell'utente.
2. **Parte 2 (Linux):** script e spec grafiche.
3. **Parte 3 (macOS):** caricamento della gem e prove grafiche, poi la suite completa.
4. **Parte 4:** controlli finali e documentazione.

Fuori scope, salvo una richiesta esplicita dell'utente: nuove funzionalità o widget, cambi all'API pubblica, le issue
aperte in Backlog, pubblicazione della gem, job grafici in CI, Windows.

## Flusso di lavoro (scelta dell'utente del 2026-11-15)

- **Branch e PR** per i cambi a spec, script e `lib/`: un branch da `master` aggiornato e una PR per la Parte 2
  (Linux) e una per la Parte 3 (macOS). Nomi: `test/fase5-linux` e `test/fase5-macos`. Le Parti 1 e 2 non
  hanno issue Linear. Dalla Parte 3 ogni PR ha una issue Linear associata (scelta dell'utente del 2026-11-15):
  la PR #21 ha ICH-478, con `Fixes ICH-478` nella descrizione. Crea branch e PR con `git` e `gh`.
- Prima del merge: CI verde su tutta la matrice, soglie di coverage invariate, `bundle exec rubocop` 0 offense. Il
  merge richiede la conferma dell'utente (regola 13). Dopo il merge il branch remoto si elimina.
- Diretti su `master`, con `[skip ci]`: i commit di sola documentazione (`memory/`, `RICONSEGNA.md`, `RIPRESA.md`).
- Lingua: Conventional Commits con scope in italiano, come nelle fasi 1–4 (la Fase 5 non ha issue Linear con
  `lang:en`). Titolo e corpo delle PR in italiano.

## Prima di iniziare

1. Fai il recall in Hindsight, bank `notcursesruby` (comando in "Comandi"), se il server risponde.
2. Leggi in `RICONSEGNA.md`: "Dipendenze di sistema" e "Come eseguire i test" (Fase 1), "Test" della Fase 2, "Cosa
   serve alla fase successiva" della Fase 4, "Correzioni della revisione del 2026-11-06" (soprattutto "CI", "RuboCop"
   e "Issue aperte nate dai lotti"). Leggi anche `memory/fase4-design.md` (sezione 6).
3. Leggi `spec/integration/pty_spec.rb` (blitter `:pixel` con `Direct` su un pty finto, da `:186`) e
   `spec/integration/ui_pty_spec.rb` (pty come terminale di controllo).
4. Controlla `git status` e `git log --oneline -3`: working tree pulito, su `4d3430a` o dopo. Il repository è privato:
   serve l'accesso a GitHub per `git pull`.
5. Controlla l'ambiente e scrivilo nel log: `uname -a`, `echo $TERM $TERM_PROGRAM $COLORTERM $KITTY_WINDOW_ID`,
   versione di notcurses (`pkg-config --modversion notcurses` o il pacchetto), Ruby (`ruby -v`), dove sono le
   librerie (`ldconfig -p | grep notcurses` su Linux, `ls "$(brew --prefix)/lib" | grep notcurses` su macOS).
6. Il submodule `notcurses/` serve alle spec delle immagini: `git submodule update --init --depth 1 notcurses`.
7. Esegui `bundle install`, la suite completa e `bundle exec rubocop` (comandi in "Comandi"): 1048 esempi dopo il
   merge della PR #21 (1046 prima), 0 fallimenti; 0 offense.
8. Leggi `memory/fase5-design.md` (sezioni 2 e 4) e `memory/fase5-terminali-macos.md` (soprattutto "Problemi e
   soluzioni"), poi `spec/graphics/terminal_spec.rb` e `spec/graphics/probe.rb`.

## Regole vincolanti

Le regole 1–14 vengono dalle fasi precedenti, le regole 15–18 dal prompt della Fase 5 del 2026-10-27, le regole 19–20
dai lotti delle correzioni.

1. Non cambiare la Fase 1 (`lib/notcurses/ffi/`, `lib/notcurses/ffi.rb`). Se un cambio serve, fermati e chiedi
   all'utente. Vale anche per macOS: per esempio aggiungere percorsi di Homebrew alla ricerca di `ffi_lib`.
2. Ogni puntatore opaco ha un distruttore (`close` o `destroy`). Il pattern `owned:` copre i puntatori non posseduti.
3. notcurses non è thread-safe. Il wrapper lo documenta e non aggiunge lock interni.
4. I metodi restituiscono `self` dove il chaining ha senso.
5. Nomi Ruby: `snake_case`, suffisso `?` per i predicati, nessun prefisso `nc` o `notcurses_`.
6. Ogni ritorno C che indica un errore (-1 o NULL) diventa un'eccezione con un messaggio chiaro.
7. Le opzioni con un default sono keyword arguments. `spec/notcurses/api_spec.rb` controlla le regole 5 e 7.
8. `define_method` e `method_missing` sono vietati.
9. Ogni metodo pubblico ha un commento YARD con `@param`, `@return` e `@raise`.
10. Dipendenze runtime: solo la gem `ffi`. Ruby >= 3.1.
11. La fase non cambia il comportamento della libreria. Un cambio in `lib/` serve solo per un bug trovato dalle prove:
    prima una spec che fallisce, poi il fix, poi la suite completa. Una spec di un crash o di un blocco esegue il caso
    in un processo figlio con un timeout. Ogni fix ha una voce in "Corretto" di `[Non rilasciato]` in `CHANGELOG.md`.
    Un bug che corrisponde a una issue aperta in Backlog resta fuori (punto aperto 2).
12. Una dipendenza di sviluppo nuova entra nel design e richiede l'approvazione dell'utente. Va in un gruppo del
    `Gemfile`. Elenca ogni cambio a `Gemfile` e `Gemfile.lock` in `RICONSEGNA.md`. Dopo un cambio del lockfile
    controlla il job Ruby 3.2.11 della CI (`parallel < 2`, vedi "Cambi a `Gemfile` e `Gemfile.lock`").
13. Le azioni esterne o difficili da annullare richiedono la conferma esplicita dell'utente: merge di una PR,
    pubblicazione, tag, release, impostazioni del repository, secret, GitHub Pages. Il push dei branch della fase,
    l'apertura delle PR e il push su `origin/master` dei commit di sola documentazione sono autorizzati.
14. Una scelta con due letture valide spetta all'utente: chiedi con AskUserQuestion. Se hai dubbi, fermati e
    chiarisci con l'utente.
15. Le spec grafiche non rompono la suite normale né la CI: richiedono un terminale grafico vero, quindi stanno dietro
    un tag RSpec o una variabile d'ambiente e vanno in skip con un messaggio chiaro fuori da un terminale adatto.
16. Le prove grafiche scrivono sul terminale dell'utente: dopo ogni prova il terminale torna pulito (schermo
    alternativo chiuso, immagini cancellate, cursore visibile). Chiedi all'utente di confermare a vista quando l'esito
    del C non basta.
17. Su macOS una spec legata a Linux (per esempio `/proc/self/fd`, `TIOCSCTTY`, `osversion` che inizia con `Linux`)
    va in skip con il motivo, oppure diventa portabile se il cambio è piccolo; non indebolire i controlli su Linux.
18. La CI resta verde su tutta la matrice, con le soglie di coverage invariate.
19. RuboCop: `bundle exec rubocop` esce con 0 prima di ogni PR. Un file nuovo passa da ogni cop di Standard (stringhe
    con le virgolette doppie); `.rubocop_todo.yml` non va rigenerato per far passare codice nuovo.
20. Ogni file nuovo ha l'intestazione di due righe (`# Generated from notcurses 3.0.17` e `# Source: ...`).

## Parte 1 — ambiente, prove grafiche su Linux e design (fatta il 2026-11-15)

Risultati, controlli dei lotti 3, 7 e 9 e problemi: `memory/fase5-terminali-macos.md`. Testo originale della parte:

1. Su Linux, in Kitty e poi in Ghostty, esegui uno script di prova (prima nello scratchpad, poi nel repository se
   approvato) che apre un `Context` sul terminale vero e scrive in un file JSON:
   - `can_pixel?`, l'implementazione dei pixel in `Capabilities`, `can_quadrant?`, `can_sextant?`, `can_octant?`,
     `Plane#pixel_geom`, `detected_terminal`;
   - l'esito di un blit di `spec/fixtures/visual/rgbw.png` con `blitter: :pixel`, `:quadrant`, `:sextant`, `:octant`,
     `:braille`, `:half`, `:ascii`, con `no_degrade: true`;
   - `Direct#render_image(..., blitter: :pixel)`.
   Lo script avvia con `timeout` e chiude sempre il contesto.
2. Controlla sul terminale vero le correzioni dei lotti provate solo su terminali finti. Sono controlli, non nuove
   correzioni: un difetto nuovo segue la regola 11.
   - Lotto 3 (ICH-272): con i quadranti attivi, `Visual.from_plane(..., blitter: :four_by_one)` e
     `Plane#as_rgba(:eight_by_one)` sollevano un'eccezione e non vanno in SIGSEGV.
   - Lotto 7 (ICH-279, ICH-280, ICH-281): con il protocollo di tastiera kitty, Shift+1 in un `TextInput` inserisce
     `!`; Ctrl+C con CapsLock o NumLock attivi è un segnale di linea in `run`; il glifo largo sotto il cursore
     resta visibile nell'ultima colonna.
   - Lotto 9 (ICH-284): `Direct#stream` disegna ogni frame sopra il precedente (il caso di ICH-458 resta fuori).
3. Controlla nel C come notcurses 3.0.17 rileva il terminale e il protocollo grafico (`termdesc.c`, risposta DA1,
   `XTGETTCAP`, `TERM`, `TERM_PROGRAM`, `KITTY_WINDOW_ID`) e confronta con quello che vedi in Kitty e Ghostty.
4. Scrivi `memory/fase5-design.md`: risultati delle prove, come si controlla l'esito (solo il C, oppure anche un
   controllo a vista dell'utente o una lettura del terminale), dove stanno script e spec grafiche, tag RSpec, piano
   per macOS.
5. Chiedi all'utente, con AskUserQuestion, le scelte con due letture valide (per esempio: script in `examples/` o
   spec con un tag; quali blitter controllare; come trattare un rilevamento sbagliato di notcurses).

Non scrivere codice della Parte 2 nel repository prima dell'approvazione.

## Parte 2 — script e spec grafiche (Linux) (fatta: PR #20, merge `4d3430a`)

- Lavora sul branch `test/fase5-linux` (sezione "Flusso di lavoro").
- Se una prova trova un bug del wrapper, vale la regola 11; un bug di notcurses va nelle tabelle di `RICONSEGNA.md`.
- Suite completa dopo ogni cambio, in ordine normale e con i semi; `bundle exec rubocop` prima della PR.
- Apri la PR, aspetta la CI (`gh pr checks <n> --watch`), poi chiedi il merge all'utente.

## Parte 4 — cosa resta

1. **Merge della PR #21:** serve la conferma dell'utente (regola 13). Dopo il merge elimina il branch remoto e
   controlla che ICH-478 passi a Done.
2. **Linux (CachyOS):** suite completa in ordine normale e con `rand:1234`, `rand:4242`, `rand:7`. La PR #21 cambia
   anche le spec di Linux, e la CI copre solo l'ordine casuale.
3. **`RICONSEGNA.md`:** sezione "Fase 5" (consegna 3). Scrivi anche: il cambio della Fase 1 (`notcurses_stop` con
   `blocking: ::FFI::Platform.mac?`); il limite F2 (la spec del fix non protegge in CI, che gira solo su Linux: la
   suite su macOS va eseguita a mano); il bug di notcurses «`tcsetattr` interrotta da un segnale (`EINTR`) non viene
   ripetuta in `notcurses_stop`» nella tabella dei bug; "Dipendenze di sistema" con macOS provato e coreutils.
4. **README:** tabella di installazione con macOS, e i limiti.
5. **Punto aperto:** blocco raro in `Context#close` su macOS (`pthread_join`, 1 volta su 62 con `rand:2026`), causa
   non trovata: log, "Punti aperti". Chiedi all'utente se aprire una issue.
6. **Controlli finali** (sezione omonima) e chiusura (consegne 4 e 5). Hindsight: retain della Parte 3 fatto il
   2026-11-15 (10 fatti); sul Mac il server risponde solo a volte.

## Parte 3 — macOS (fatta: PR #21, in attesa del merge)


Lavora sul branch `test/fase5-macos`, da `master` aggiornato dopo il merge della Parte 2.

1. **notcurses:** `brew install notcurses` (Homebrew ha 3.0.17). Controlla se Homebrew installa anche
   `libnotcurses-ffi` (serve solo alla spec differenziale `spec/inline_reimpl_spec.rb`) e con quale nome: l'oracolo
   `spec/support/nc_oracle.rb:29` cerca `libnotcurses-ffi.so.3` e `notcurses-ffi`.
2. **Caricamento:** `ruby -Ilib -e 'require "notcurses"'`. Su Apple Silicon Homebrew sta in `/opt/homebrew/lib`, che
   `dlopen` potrebbe non cercare: prova prima `DYLD_FALLBACK_LIBRARY_PATH="$(brew --prefix)/lib"`. Un cambio di
   `ffi_lib` tocca la Fase 1: chiedi all'utente (regola 1). Controlla anche ICH-313: su macOS il `types.conf` di ffi
   deve avere `wchar_t` e `uintmax_t`, oppure `lib/notcurses/ffi/typedefs.rb` li definisce.
3. **termios:** su macOS `tcflag_t` è `unsigned long` e `IXON`/`ISIG` hanno i valori BSD: finora controllati solo
   sugli header. Prova `EventLoop#run(no_flow_control: true, no_linesigs: true)` nel terminale vero.
4. **Prove grafiche:** `NC_GRAPHICS=1 bundle exec rspec spec/graphics` in Kitty e in Ghostty, con il `TERM` del
   terminale; una volta con `NC_GRAPHICS_HOLD=3` e il controllo a vista dell'utente. Shift+1 in un `TextInput`
   (ICH-279) solo con la tastiera vera: `kitty @ send-key` non manda il testo associato. Rischio noto (design,
   sezione 4): se la libc di macOS non conosce i sestanti, la tabella esatta fallisce; serve una riga per macOS.
5. **Suite completa:** punti già noti che dipendono da Linux:

   | Punto | Dove |
   | --- | --- |
   | `Dir.children('/proc/self/fd')` per contare i descrittori | `spec/notcurses/context_spec.rb:41`, `spec/notcurses/fd_plane_spec.rb:13`, `spec/notcurses/subprocess_spec.rb:12` e `:97`, `spec/notcurses/ui/event_loop_spec.rb:26` |
   | `osversion` che inizia con `Linux` | `spec/notcurses/stats_spec.rb:47` |
   | comando `timeout` di coreutils (`gtimeout` con `brew install coreutils`) | `spec/notcurses/{reel,multiselector,progbar,visual,reader,plane}_spec.rb` e i comandi di test |
   | `TIOCSCTTY` (`0x540E`), già in skip fuori da Linux | `spec/integration/ui_pty_spec.rb` |
   | nome della libreria dell'oracolo | `spec/support/nc_oracle.rb:29` |
   | compilazione contro gli header con `gcc` | `spec/ffi_layout_spec.rb` (va in skip senza compilatore o header) |

   Cerca gli altri con la suite. Su macOS lo stdin di `/dev/null`, `fopen("/dev/null")` e i pty si comportano in modo
   simile, ma non è provato.
6. Apri la PR, aspetta la CI, poi chiedi il merge all'utente. La CI gira solo su Linux: la suite su macOS la controlli
   in locale e scrivi l'esito nella PR.

## Consegne

1. Script e spec grafiche, cambi alle spec per macOS: due PR con la CI verde e il merge confermato dall'utente.
2. `memory/fase5-design.md` (design approvato) e il log `memory/fase5-<argomento>.md`: ambiente delle due macchine,
   risultati per terminale e blitter, controlli dei lotti 3, 7 e 9, problemi e soluzioni.
3. `RICONSEGNA.md`: sezione "Fase 5" con data, file, come avviare le prove grafiche, risultati per sistema, terminale e
   blitter, stato di macOS (cosa passa, cosa è in skip e perché), problemi trovati, cambi a `Gemfile`/`Gemfile.lock`
   (se ci sono), "Cosa serve alla fase successiva". Aggiorna "Dipendenze di sistema" (macOS provato) e il README
   (tabella di installazione, limiti).
4. Hindsight, bank `notcursesruby`, se il server risponde: decisioni e cause radice.
5. Alla fine proponi il passo successivo e chiedi all'utente se scrivere in `RIPRESA.md` il prompt della fase dopo.

## Controlli finali

- Suite completa su Linux (macchina dell'utente): 0 fallimenti, anche con `rand:1234`, `rand:4242` e `rand:7`.
- Suite completa su macOS: 0 fallimenti; gli skip hanno un motivo scritto.
- Prove grafiche in Kitty e Ghostty, su Linux e su macOS, con i risultati nel log.
- CI verde su tutta la matrice sull'ultimo commit di `master`; coverage >= 98 % e >= 90 % per file.
- `ruby -w -Ilib -e 'require "notcurses"'` senza warning; `bundle exec rubocop` 0 offense; `yard doc
  --fail-on-warning` e `yard stats --list-undoc` al 100 %; `gem build` senza warning.
- `git diff b2fed69 -- lib/notcurses/ffi lib/notcurses/ffi.rb` vuoto, salvo cambi approvati dall'utente.

## Note pratiche (dai lotti)

- `spec/notcurses/context_spec.rb:358` fallisce a volte con `--order rand:4242` (due chiamate a `notcurses_getvec`),
  anche su `master` prima della Fase 5: ripeti la suite (log della Fase 5, "Esempio instabile con il seme 4242").
- `spec/integration/pty_spec.rb:173` è instabile per una gara di tempi (`getvec` si sveglia dopo il primo di 4
  tasti). Se fallisce, ripeti la suite prima di cercare una regressione. Non ha una issue.
- In zsh un comando in una variabile non si divide in parole: usa un array (`E=(env ...)`, `"${E[@]}"`) e scrivi
  `--order "rand:$seed"`.
- Nei comandi non mettere `rm` né `rm -rf`: un hook li mette in coda per la conferma dell'utente. `doc`, `.yardoc` e
  `coverage` sono già in `.gitignore`. Per `gem build` usa `--output` con un file nello scratchpad.
- Non lanciare `rspec` con cwd in un checkout per provare il codice di un altro: `rspec` mette il `lib/` del cwd nel
  load path prima di `-I`.
- Dopo l'apertura della PR la CI può partire con qualche minuto di ritardo: aspetta con
  `until gh run list --branch <branch> --limit 1 | grep -q .; do sleep 15; done`, poi `gh pr checks <n> --watch`.
- `gem build` può stampare warning di rdoc dell'installazione locale (più versioni installate), non del gemspec: conta
  che la gem si costruisca e che la CI sia verde.
- Su Ruby 3.1.7 basta `mise exec ruby@3.1.7 -- rspec` dalla radice del progetto, senza `bundle`.

## Comandi

`S` è il percorso assoluto dello scratchpad della sessione, scritto nel prompt di sistema: assegnalo a mano. Non
esiste una variabile `$SCRATCHPAD`.

```sh
S=/percorso/dello/scratchpad   # dal prompt di sistema della sessione
cd /Dati/Sviluppo/Progetti/Personali/20261027_notcursesruby   # macOS: /Users/sphynx/Sviluppo/Progetti/Personali/20261027_notcursesruby

# suite completa (dalla radice del progetto); COLORTERM serve alle 10 spec dei colori RGB
TERM=xterm-256color COLORTERM=truecolor LANG=C.UTF-8 LC_ALL=C.UTF-8 timeout -k 5 -s KILL 600 bundle exec rspec < /dev/null
TERM=xterm-256color COLORTERM=truecolor LANG=C.UTF-8 LC_ALL=C.UTF-8 timeout -k 5 -s KILL 600 \
  bundle exec rspec --order rand:1234 < /dev/null
# La suite non grafica forza TERM=xterm-256color anche dentro Kitty o Ghostty (TERM=xterm-kitty, xterm-ghostty):
# i valori attesi delle spec sono calcolati per xterm-256color. Le prove grafiche usano invece il TERM del terminale.
# macOS: timeout viene da coreutils di Homebrew (brew install coreutils) come gtimeout, oppure aggiungi
# "$(brew --prefix)/opt/coreutils/libexec/gnubin" al PATH; libreria: DYLD_FALLBACK_LIBRARY_PATH="$(brew --prefix)/lib".
# coverage (report in coverage/; con una sola spec fallisce per la soglia)
TERM=xterm-256color COLORTERM=truecolor LANG=C.UTF-8 LC_ALL=C.UTF-8 timeout -k 5 -s KILL 600 \
  bundle exec rspec --require ./spec/support/coverage.rb < /dev/null
# script di prova contro notcurses: un solo contesto per processo. Su un terminale vero serve --foreground:
# senza, timeout mette il comando in background e il kernel lo ferma con SIGTTOU alla prima scrittura del termios
timeout --foreground -k 5 -s KILL 60 ruby -Ilib "$S/prova.rb"
# spec grafiche: da Kitty o Ghostty; --out tiene stdout sul tty (con > file gli esempi vanno in skip)
NC_GRAPHICS=1 bundle exec rspec spec/graphics --format documentation --out "$S/graphics.log"
# da una sessione senza tty (il tool Bash di Claude Code): finestra nuova, con il PATH del Ruby di mise
kitty @ launch --type=os-window --cwd="$PWD" --env PATH="$(dirname "$(command -v ruby)"):$PATH" -- \
  bash -c "NC_GRAPHICS=1 bundle exec rspec spec/graphics --out $S/graphics.log; echo \$? > $S/graphics.exit"

# RuboCop, YARD e gem
bundle exec rubocop
bundle exec yard doc --fail-on-warning
bundle exec yard stats --list-undoc
RUBYOPT=-W0 gem build notcursesruby.gemspec --output "$S/notcursesruby.gem"

# workflow: controllo prima del push
mise x aqua:rhysd/actionlint@1.7.12 -- actionlint -ignore SC2016 .github/workflows/ci.yml

# GitHub
gh pr create --base master --head <branch> --title '<titolo>' --body-file "$S/pr.md"
gh pr checks <n> --watch
gh run list --limit 5
gh run view <id> --log-failed

# CI in locale con Podman (VPS): passi del job 4.0.9 nel container della CI.
# P = cartella delle cache, fuori dal progetto; ci-local.sh = lo script sotto, salvato nello scratchpad.
P="$S/podman-cache"; mkdir -p "$P/pacman" "$P/mise" "$P/bundle"
podman run --rm -v "$PWD":/w:ro -w /w -v "$S/ci-local.sh":/ci-local.sh:ro \
  -v "$P/pacman":/var/cache/pacman/pkg -v "$P/mise":/opt/mise -v "$P/bundle":/opt/bundle \
  -e ARCH_SNAPSHOT=2026/10/26 -e RUBY=4.0.9 -e MISE_DATA_DIR=/opt/mise -e BUNDLE_PATH=/opt/bundle \
  -e TERM=xterm-256color -e COLORTERM=truecolor -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 -e MISE_GITHUB_TOKEN="$(gh auth token)" \
  docker.io/library/archlinux:base@sha256:52dfbd5afb23a220d5ee92dafcb4c788d96c026ed04179890c23adef4c897fa0 /ci-local.sh
# ci-local.sh (chmod +x):
#   #!/usr/bin/env bash
#   set -euo pipefail
#   echo "Server = https://archive.archlinux.org/repos/${ARCH_SNAPSHOT}/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist
#   pacman-key --init > /dev/null; pacman-key --populate archlinux > /dev/null
#   pacman -Syuu --noconfirm --needed notcurses git mise base-devel libyaml openssl zlib libffi > /tmp/pacman.log 2>&1 \
#     || { tail -20 /tmp/pacman.log; exit 1; }
#   mise install "ruby@${RUBY}" > /tmp/mise.log 2>&1 || { tail -20 /tmp/mise.log; exit 1; }
#   export PATH="$(mise where "ruby@${RUBY}")/bin:$PATH"
#   gem install --no-document bundler -v "$(tail -n 1 Gemfile.lock | tr -d ' ')" > /dev/null
#   BUNDLE_FROZEN=true bundle install --jobs 4 --quiet
#   BUNDLE_FROZEN=true timeout -k 5 -s KILL 600 bundle exec rspec --order rand < /dev/null
# Per Ruby 3.1.7 servono CFLAGS/RUBY_CFLAGS=-std=gnu17 e una copia del Gemfile senza lockfile, come nel workflow.

# recall dal bank notcursesruby
curl -s -m 30 -X POST http://127.0.0.1:8888/v1/default/banks/notcursesruby/memories/recall \
  -H 'Content-Type: application/json' \
  -d '{"query":"Fase 5 blitter pixel kitty Ghostty, pty e terminale, macOS e termios, correzioni lotti 3 7 9","budget":"high","max_tokens":6000}'

# retain nel bank notcursesruby: il JSON sta in un file dello scratchpad
curl -s -m 30 -X POST http://127.0.0.1:8888/v1/default/banks/notcursesruby/memories \
  -H 'Content-Type: application/json' --data @"$S/retain.json"
```

Formato di `retain.json`:

```json
{"async": true, "items": [{"content": "fatto autosufficiente, con comandi e percorsi alla lettera",
  "context": "una riga che descrive il dominio", "tags": ["claude-code", "repo:notcursesruby"]}]}
```
