# Indice della memoria

Memoria persistente di notcursesruby: i fatti durevoli che servono a più sessioni. Ogni file tratta un solo tema.
Leggi questo indice, poi apri solo i file che servono. Le regole d'uso sono in [CLAUDE.md](../CLAUDE.md), sezione
«Memoria del progetto».

## Temi

| File | Contenuto |
|---|---|
| [piano.md](piano.md) | Coda dei lavori della fase «Issue in Backlog»: ordine, lotti e gruppi con ID e titolo, studi di design |
| [fase-backlog.md](fase-backlog.md) | Fase «Issue in Backlog»: obiettivo, criteri dei lotti, note delle issue senza lotto, ICH-463 in Blocked, consegne e controlli finali |
| [regole.md](regole.md) | Le regole vincolanti 1–25: valgono per ogni lotto e per ogni changeset di codice, anche nelle review; le regole 23–25 sono per le review e le prove |
| [ambiente.md](ambiente.md) | Progetto, macchine, versioni, submodule, caricamento delle librerie, terminale headless `ncvt`, CI, GitHub, Linear |
| [comandi.md](comandi.md) | Suite, coverage, script di prova, Kitty e macOS, RuboCop, YARD, gem, CI e Linear, con le note per eseguirli |
| [lezioni.md](lezioni.md) | Insidie emerse dai lotti, scelte di design chiuse, test e coverage, review |
| [bug-notcurses.md](bug-notcurses.md) | Registro dei bug e dei limiti di notcurses 3.0.17: file C, riga e gestione nel wrapper, per area; un bug nuovo va qui (regola 11) |
| [punti-aperti.md](punti-aperti.md) | Difetti sospetti e spec instabili che non sono issue |
| [prestazioni.md](prestazioni.md) | Costi misurati del wrapper, del render e dei modelli di concorrenza (Thread, Fiber, Ractor, Async), con il metodo di misura |

## Design

| File | Contenuto |
|---|---|
| [fase3-design.md](fase3-design.md) | Design della Fase 3: `EventLoop`, focus, resize, widget composti, thread, test |
| [fase4-design.md](fase4-design.md) | Design della Fase 4: gemspec, file del pacchetto, YARD, coverage, CI |
| [fase5-design.md](fase5-design.md) | Design della Fase 5: blitter su un terminale vero, spec grafiche, piano per macOS |
| [studio-fiber.md](studio-fiber.md) | Studio ICH-600: Fiber al posto dei thread in `Notcurses::UI`, misure del prototipo `benchmark/fiber/`, design e scelte D1–D6 |

## Fuori da `memory/`

- `RICONSEGNA.md`, rimosso il 2026-11-23: esito delle fasi 1–5, delle correzioni della revisione e dei lotti fino
  all'8c. Il testo si legge con `git show 50e9edb:RICONSEGNA.md`.
- Storia dei lotti e delle fasi, rimossa il 2026-11-24: cosa è successo in ogni lotto sta in git, nelle PR e in Linear.
  I file si leggono con `git show f5ade53:<percorso>`, dove `f5ade53` è l'ultimo commit che li contiene.
  - `memory/backlog-issue.md`: i capitoli dei lotti 1–9c e dello studio ICH-600.
  - `memory/correzioni-review.md`: i 17 lotti della revisione del 2026-11-06 e ICH-465.
  - `memory/review-2026-11-06.md`: la revisione completa, con ogni finding e la sua issue Linear.
  - `memory/fase1-ffi-raw.md`: la Fase 1, layer FFI raw.
  - `memory/fase2-wrapper-idiomatico.md`: la Fase 2, wrapper idiomatico.
  - `memory/fase2-review.md`: la review della Fase 2.
  - `memory/fase3-ui.md`: la Fase 3, `Notcurses::UI`.
  - `memory/fase4-pacchetto-ci.md`: la Fase 4, pacchetto, YARD, coverage e CI.
  - `memory/fase5-terminali-macos.md`: la Fase 5, Kitty, Ghostty e macOS.
- [CHANGELOG.md](../CHANGELOG.md): una voce per ogni fix in `[Non rilasciato]`.
- [.claude/skills/verify/SKILL.md](../.claude/skills/verify/SKILL.md): ricetta del verify con `ncvt` e dello script
  `screen`.
- Il bank Hindsight `notcursesruby`: vedi [CLAUDE.md](../CLAUDE.md), sezione «Hindsight».
