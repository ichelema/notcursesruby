---
name: context7-mcp
description: >-
  Usa questa skill solo quando l'utente chiede di Ruby, della libreria standard di Ruby, di gem o di
  strumenti Ruby (Bundler, RubyGems, RSpec, RuboCop, YARD), oppure di concetti, architettura ed
  esempi di notcurses (dankamongmen/notcurses). Per firme, valori di ritorno, flag e costanti
  dell'API C di notcurses usa prima la skill notcurses-man. Non usarla per altro codice C, per Rust
  o per altre librerie.
---

Quando l'utente chiede di Ruby, di una gem, di uno strumento Ruby o di notcurses, usa Context7 per
recuperare la documentazione aggiornata invece di affidarti ai dati di addestramento. Non usare
Context7 per altro codice C, per Rust o per altre librerie.

Per notcurses, Context7 affianca le man page installate. Le man page restano la fonte autorevole per
firme, valori di ritorno, flag, costanti e proprietà dei puntatori: per questi dettagli usa prima la
skill `notcurses-man`. Se Context7 e le man page non concordano, vale la man page, perché
corrisponde alla versione installata.

## Quando usare questa skill

Attiva questa skill quando l'utente:

- Fa domande di installazione o configurazione sugli strumenti Ruby ("Come configuro RuboCop
  per...?")
- Chiede codice che usa gem ("Scrivi una struct `ffi` per...")
- Ha bisogno di riferimenti all'API Ruby ("Quali sono le opzioni di `Data.define`?")
- Nomina gem o strumenti Ruby specifici (`ffi`, RSpec, Bundler, YARD, ecc.)
- Chiede come funziona notcurses o come usarla ("Come interagiscono pile e piani?", "Un esempio di
  `ncvisual` con i blitter?")

## Come recuperare la documentazione

### Passo 1: risolvi l'ID della libreria

Per notcurses salta questo passo e usa direttamente uno di questi ID:

- `/dankamongmen/notcurses` (Notcurses su GitHub): riferimento principale per implementazione,
  funzioni, parametri ed esempi.
- `/websites/deepwiki_dankamongmen_notcurses` (Notcurses su DeepWiki): riferimento complementare
  quando devi esplorare l'architettura, capire le relazioni tra componenti o analizzare il
  funzionamento interno.

Per le altre librerie chiama `resolve-library-id` con:

- `libraryName`: il nome della libreria estratto dalla domanda dell'utente
- `query`: cosa cercare nella documentazione della libreria (migliora l'ordinamento per pertinenza)

### Passo 2: scegli la corrispondenza migliore

Tra i risultati della risoluzione, scegli in base a:

- La corrispondenza esatta o più vicina al nome chiesto dall'utente
- Il benchmark score: un punteggio più alto indica una documentazione di qualità migliore
- Se l'utente ha indicato una versione (per esempio "React 19"), preferisci gli ID specifici per
  versione

### Passo 3: recupera la documentazione

Chiama `query-docs` con:

- `libraryId`: l'ID Context7 della libreria scelta (per esempio `/vercel/next.js`)
- `query`: cosa cercare nella documentazione della libreria, limitato a un solo concetto

Se la domanda dell'utente copre più concetti distinti (per esempio routing, autenticazione e
caching), fai una chiamata `query-docs` separata per ogni concetto con lo stesso ID di libreria. Fai
eccezione quando la domanda riguarda l'interazione tra i concetti. Le query combinate diluiscono
l'ordinamento e restituiscono risultati superficiali per ogni argomento.

### Passo 4: usa la documentazione

Integra la documentazione recuperata nella risposta:

- Rispondi alla domanda dell'utente con informazioni aggiornate e accurate
- Includi gli esempi di codice pertinenti presi dalla documentazione
- Cita la versione della libreria quando è rilevante

## Linee guida

- **Sii specifico**: descrivi cosa cercare nella documentazione della libreria, ma limita ogni query
  a un solo concetto
- **Un argomento per query**: dividi le domande su più argomenti in chiamate `query-docs` separate.
  Risolvi l'ID della libreria una sola volta, poi fai una query per concetto. Fai eccezione quando
  la domanda riguarda l'interazione tra i concetti
- **Attenzione alle versioni**: quando l'utente nomina una versione ("Next.js 16", "React 19"), usa
  gli ID specifici per versione, se il passo di risoluzione li restituisce
- **Preferisci le fonti ufficiali**: quando esistono più corrispondenze, preferisci i pacchetti
  ufficiali o principali rispetto ai fork della comunità
