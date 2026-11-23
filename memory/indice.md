# Indice della memoria

Memoria persistente di notcursesruby: i fatti durevoli che servono a più sessioni. Ogni file tratta un solo tema.
Leggi questo indice, poi apri solo i file che servono. Le regole d'uso sono in [CLAUDE.md](../CLAUDE.md), sezione
«Memoria del progetto».

## Temi

| File | Contenuto |
|---|---|
| [piano.md](piano.md) | Fase «Issue in Backlog»: obiettivo, avanzamento, criteri dei lotti, lotti da fare, issue senza lotto, ICH-463 in Blocked, consegne e controlli finali |
| [regole.md](regole.md) | Le 22 regole vincolanti: valgono per ogni lotto e per ogni changeset di codice, anche nelle review |
| [ambiente.md](ambiente.md) | Progetto, macchina, versioni, submodule, terminale headless `ncvt`, CI, GitHub, Linear |
| [comandi.md](comandi.md) | Suite, coverage, script di prova, Kitty, RuboCop, YARD, gem, CI e Linear, con le note per eseguirli |
| [lezioni.md](lezioni.md) | Insidie emerse dai lotti: glifi larghi ed egcpool, gestori trap e segnali, coverage, review |
| [punti-aperti.md](punti-aperti.md) | Difetti sospetti e spec instabili che non sono issue |

## Log delle fasi e dei lotti

| File | Contenuto |
|---|---|
| [backlog-issue.md](backlog-issue.md) | Fase «Issue in Backlog»: decisioni iniziali, file per issue e un capitolo per lotto (fix, decisioni, review, problemi e soluzioni, verifica finale) |
| [correzioni-review.md](correzioni-review.md) | Correzioni della revisione del 2026-11-06: decisioni iniziali, un capitolo per ognuno dei 17 lotti e uno per ICH-465 fuori dai lotti (PR #2…#19) |
| [review-2026-11-06.md](review-2026-11-06.md) | Revisione completa del 2026-11-06: ogni finding con scenario, prova e issue Linear |
| [fase1-ffi-raw.md](fase1-ffi-raw.md) | Fase 1, layer FFI raw: decisioni, bug di notcurses 3.0.17, confronto con libnotcurses-sys, funzioni inline reimplementate e saltate |
| [fase2-wrapper-idiomatico.md](fase2-wrapper-idiomatico.md) | Fase 2, wrapper idiomatico: ciclo di vita e ownership, callback, thread e GVL, segnali, bug di notcurses aggirati e non aggirati, metodi non wrappati |
| [fase2-review.md](fase2-review.md) | Review della Fase 2: finding, decisioni, cambi dell'API pubblica, Ruby 3.1 |
| [fase3-design.md](fase3-design.md) | Design della Fase 3: `EventLoop`, focus, resize, widget composti, thread, test |
| [fase3-ui.md](fase3-ui.md) | Fase 3, `Notcurses::UI`: decisioni, problemi e bug di notcurses trovati |
| [fase4-design.md](fase4-design.md) | Design della Fase 4: gemspec, file del pacchetto, YARD, coverage, CI |
| [fase4-pacchetto-ci.md](fase4-pacchetto-ci.md) | Fase 4: gemspec, YARD, coverage e CI, con i controlli |
| [fase5-design.md](fase5-design.md) | Design della Fase 5: blitter su un terminale vero, spec grafiche, piano per macOS |
| [fase5-terminali-macos.md](fase5-terminali-macos.md) | Fase 5: prove su Kitty e Ghostty, porting su macOS, punti aperti |

## Fuori da `memory/`

- [RICONSEGNA.md](../RICONSEGNA.md): esito di ogni fase e di ogni lotto, con le tabelle dei bug di notcurses 3.0.17,
  i cambi dell'API pubblica, i cambi a `Gemfile` e `Gemfile.lock` e le issue aperte nate dai lotti.
- [CHANGELOG.md](../CHANGELOG.md): una voce per ogni fix in `[Non rilasciato]`.
- [.claude/skills/verify/SKILL.md](../.claude/skills/verify/SKILL.md): ricetta del verify con `ncvt` e dello script
  `screen`.
- Il bank Hindsight `notcursesruby`: vedi [CLAUDE.md](../CLAUDE.md), sezione «Hindsight».
