# Regole vincolanti

Le regole valgono per ogni lotto e per ogni modifica al codice: leggile per intero prima di `2_work-issue`. Sono
vincolanti, non un consiglio come il resto della memoria, e valgono anche per le review. Le regole 1–10 vengono dalle
fasi 1–5, le regole 11–17 dai lotti della revisione del 2026-11-06, le regole 18–22 dai lotti successivi. Le regole
23–25, sulle review e sulle prove, raccolgono istruzioni dei lotti e della Fase 5 (2026-11-23). Spec, script e log
citano le regole per numero: non rinumerarle. Una regola nuova prende il numero successivo.

1. Non cambiare la Fase 1 (`lib/notcurses/ffi/`, `lib/notcurses/ffi.rb`) senza l'approvazione dell'utente. Se un
   fix lo richiede, fermati e chiedi.
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
    Una spec di un crash (SIGSEGV, abort, double free) o di un blocco esegue il caso in un processo figlio con un
    timeout e controlla lo stato di uscita, così la suite sopravvive anche prima del fix. Un bug di notcurses nuovo
    va in [bug-notcurses.md](bug-notcurses.md), nella tabella della sua area. Ogni fix ha una voce in "Corretto" di
    `[Non rilasciato]` in `CHANGELOG.md`.
12. Una dipendenza di sviluppo nuova richiede l'approvazione dell'utente e va in un gruppo del `Gemfile`. Elenca ogni
    cambio a `Gemfile` e `Gemfile.lock` nel corpo della PR e nel capitolo del lotto in
    [backlog-issue.md](backlog-issue.md). Dopo un cambio del lockfile controlla il job Ruby 3.2.11 della CI
    (`parallel < 2`).
13. Le azioni esterne o difficili da annullare richiedono la conferma esplicita dell'utente: merge di una PR, tag,
    release, impostazioni del repository, secret, GitHub Pages. Il push dei branch dei lotti, l'apertura delle PR e
    il push su `origin/master` dei commit di sola documentazione sono autorizzati.
14. Una scelta con due letture valide spetta all'utente: chiedi con AskUserQuestion. Se hai dubbi, fermati e
    chiarisci con l'utente.
15. Lingua: commit, titolo e corpo delle PR in inglese (label di progetto `git:en`, per esempio
    `fix(plane): ...`); issue e commenti su Linear in italiano (label `lang:it`). `handoff.md`, `CLAUDE.md` e
    `memory/` restano in italiano.
16. Un lotto tocca solo il codice delle sue issue. Se un fix richiede un cambio che appartiene a un altro lotto o a
    un'altra issue, fermati e chiedi all'utente. Un difetto nuovo trovato in review diventa una issue nuova in
    Backlog, con la conferma dell'utente.
17. Prima del merge di ogni PR: CI verde su tutta la matrice e soglie di coverage invariate.
18. RuboCop: `bundle exec rubocop` esce con 0 prima di ogni PR. Un file nuovo passa da ogni cop di Standard (stringhe
    con le virgolette doppie); `.rubocop_todo.yml` non va rigenerato per far passare codice nuovo (fino al lotto di
    ICH-469).
19. Ogni file Ruby nuovo in `lib/`, `spec/` ed `examples/` ha l'intestazione di due righe
    (`# Generated from notcurses 3.0.17` e `# Source: ...`).
20. Un controllo prima della chiamata C, o un workaround, che prevede il comportamento del C si scrive dopo aver letto
    per intero la funzione C che **scrive** (non solo quella che carica o legge), compreso il percorso d'errore e
    quello che cambia nel framebuffer prima del fallimento. Il commento del wrapper cita quelle righe (`file.c:riga`),
    e il piano di `2_work-issue` ha una riga «Percorso C letto» con le funzioni e le righe. Le spec di «piano
    invariato» usano gli helper di `spec/support/nc_helpers.rb`: `NcHelpers.occupy_row` (celle di arrivo occupate,
    glifo largo, colori non di default), `NcHelpers.fill_egcpool` e `NcHelpers.big_egc` (egcpool pieno) e il
    confronto di `NcHelpers.plane_snapshot` prima e dopo (lotto 8b: la scrittura su una riga vuota nascondeva il
    difetto).
21. La segmentazione di Ruby cambia con la versione di Unicode: Ruby 3.1 usa la 13.0, Ruby 3.2-3.4 la 15.0, Ruby 4.0
    la 17.0 (per esempio, prima della 15.1 Ruby divide il coniugato "क्ष"). Se il diff tocca grapheme o Unicode
    (`grapheme_clusters`, `each_grapheme_cluster`, `\X`, `\p{...}`, `unicode_normalize`, `Notcurses.strwidth`,
    codepoint `\u` nelle spec), prima della PR esegui le spec cambiate anche con `.claude/scripts/spec31` (Ruby 3.1.7).
    Una spec il cui risultato dipende dalla versione ricava l'atteso da Ruby al momento (per esempio
    `str.grapheme_clusters.size == 1`) e controlla tutti e due i rami. Ruby 3.2-3.4 li prova solo la CI (lotto 8b: la
    CI è fallita su Ruby 3.1-3.4 dopo i fix della review).
22. Un testo che dice all'utente che cosa fare (messaggio d'errore, YARD, `CHANGELOG`, per esempio «usa Plane#putstr»)
    è un'affermazione: prima del commit la provi sulla superficie, cioè sullo schermo con
    `.claude/skills/verify/screen` quando riguarda quello che si vede, con uno script sull'API pubblica negli altri
    casi. Se un acceptance criterion chiede un consiglio, provalo prima di scrivere la spec; se non regge, proponi
    all'utente il testo nuovo del criterio (regola «Acceptance criteria» del workflow in [CLAUDE.md](../CLAUDE.md)).
    `screen` usa `ncvt` (Ghostty): un terminale diverso, per esempio Kitty, si prova solo con un display (lotto 8b: il
    consiglio di `putstr` per le bandiere lasciava residui sullo schermo, trovato solo nel verify dopo la PR).
23. Una review prova l'egcpool pieno (EGC da 6 MB), i piani con bitmap su un pty finto (sixel e Kitty:
    `bitmap_plane_script` in `spec/integration/pty_spec.rb`), i piani che hanno fatto scroll, le metà sinistre
    orfane, i callback di resize che cambiano il piano e i gestori `trap`. Non rincorre ogni finestra dei gestori
    `trap`: i workaround che leggono i campi privati restringono le finestre, e lo YARD lo dice (decisione
    dell'utente nel lotto 2).
24. Un reviewer esegue rspec con `mise -C "<rev-path>" x -- bundle exec rspec ...`, senza `cd`, scrive i file di
    appoggio solo in `<rev-path>/.review-tmp/` e non usa `rm`. Prima di rimuovere un worktree di review in cui sono
    girati script su terminali muti, chi lo rimuove controlla con `pgrep` i processi orfani fermi nell'init.
25. Dopo una prova su un terminale vero, per esempio Kitty, il terminale torna pulito: modo del tty, schermo normale,
    cursore visibile, immagini kitty cancellate (regola 16 della Fase 5).
