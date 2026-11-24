# Coda dei lavori — fase «Issue in Backlog»

Lo stato di ogni issue è in Linear, progetto `notcursesruby`. L'obiettivo della fase, i criteri dei lotti, le note
delle issue senza lotto e i controlli finali sono in [fase-backlog.md](fase-backlog.md), che si legge quando componi un
gruppo o chiudi la fase. Il prossimo passo è in [handoff.md](../handoff.md).

## Ordine dei lavori

Scelto dall'utente il 2026-11-24: gruppo H, una issue per lotto (ICH-604 fatta nel lotto 16, PR #39; poi ICH-606,
poi ICH-607), studio ICH-601,
studio ICH-602, gruppo I, gruppi A, B, C (dopo la riprogettazione), lotti 10–14, gruppi D, E, F, G, lotto 15. Il
gruppo H e gli studi vengono prima dei bug High e Medium. I gruppi prendono i numeri di lotto 16 e seguenti quando
partono; i numeri 10–15 restano quelli della storia in git. ICH-603, nata nel lotto 9c, non ha gruppo: lo sceglie
l'utente. ICH-463 è in Blocked ([fase-backlog.md](fase-backlog.md)).

## Lotti

| Lotto | Prefisso | Issue | Titolo |
| --- | --- | --- | --- |
| 10 | `bug` | ICH-220 | Fai seguire l'intestazione di Tabbed ai ridimensionamenti del piano |
| 10 | `bug` | ICH-221 | Correggi lo scostamento del focus in Tree con elementi di altezza diversa |
| 10 | `bug` | ICH-219 | Correggi la perdita della selezione in Menu al clic su un separatore e mouse_selected per le sezioni allineate a destra |
| 11 | `bug` | ICH-459 | Chiudi ogni figlio di un contenitore UI quando la chiusura di un figlio o il cambio di focus solleva un'eccezione |
| 11 | `bug` | ICH-460 | Mantieni visibili tutti i pulsanti di Dialog su un'area molto stretta |
| 11 | `bug` | ICH-461 | Dai il focus a un componente che diventa visibile quando nessuno ha il focus |
| 11 | `bug` | ICH-473 | Stampare il risultato dopo Context.open nell'esempio YARD di Notcurses::UI::App |
| 12 | `improvments` | ICH-227 | Impedisci alle interruzioni di close di FdPlane di raggiungere i metodi di testo del wrapper su Ruby 3.1 |
| 13 | `improvments` | ICH-231 | Aggiungi un limite opzionale alla coda e un post non bloccante a EventLoop (funzionalità nuova: scelta dell'utente) |
| 13 | `improvments` | ICH-457 | Consegna il movimento del trascinamento del mouse al componente da cui è iniziato il trascinamento (cattura del puntatore) (funzionalità nuova: scelta dell'utente) |
| 14 | `bug` | ICH-483 | Liberare le stringhe di ncplane_putwegc con l'allocatore usato da notcurses (layer FFI) (Fase 1: approvazione dell'utente prima del fix, regola 1) |
| 15 | `improvments` | ICH-469 | Applica le autocorrezioni sicure di RuboCop e passa alle virgolette doppie |
| 15 | `improvments` | ICH-470 | Rimuovere il commento rubocop:disable ridondante in ui/component.rb |

## Gruppi

| Gruppo | Issue | Nota |
| --- | --- | --- |
| H | ICH-606, ICH-607 | Un lotto per issue, in quest'ordine: ICH-606 blocca ICH-607. Design in [studio-fiber.md](studio-fiber.md) |
| I | ICH-605 | Da sola: solo la label `Performance`, `1_create-worktree` può chiedere il prefisso |
| A | ICH-542 | Bug High, da solo |
| B | ICH-560, ICH-567, ICH-561 | Bug Medium: `Direct` e blit `:pixel`; ICH-560 chiede l'approvazione della regola 1 |
| C | ICH-214 | Bug Medium, da riprogettare prima del fix |
| D | ICH-591, ICH-592 | Bug Low: `plane.rb` e `with_glyph_kept`, cambiati dal lotto 9c |
| E | ICH-554, ICH-556, ICH-562 | Performance Low: `Visual` e blit; ICH-554 può chiedere un cambio della Fase 1 |
| F | ICH-540, ICH-541 | Bug Low: dopo il gruppo H (ICH-541 è collegata a ICH-600) |
| G | ICH-590, ICH-596 | Bug Low: ognuna chiede una scelta dell'utente prima del fix |

## Studi di design

| Issue | Studio | Stato |
| --- | --- | --- |
| ICH-600 | Fiber al posto dei thread | Fatto: PR #38, merge `e90c5d3`; design in [studio-fiber.md](studio-fiber.md) |
| ICH-601 | Ractor per il calcolo parallelo | Dopo il gruppo H |
| ICH-602 | Rilascio del GVL durante il rasterize | Dopo il gruppo H; tocca la Fase 1 (regola 1) e la regola 3 |
