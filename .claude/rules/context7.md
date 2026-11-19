Usa Context7 MCP solo per due ambiti:

- Ruby: il linguaggio Ruby e la sua libreria standard, le gem (come `ffi` e le dipendenze in
  `Gemfile` e `notcursesruby.gemspec`), Bundler, RubyGems, RSpec, RuboCop, YARD e gli altri
  strumenti Ruby.
- notcurses (`dankamongmen/notcurses`): la libreria C che questa gem incapsula. Usa gli ID fissi
  della sezione [notcurses](#notcurses).

Usa Context7 anche quando pensi di conoscere la risposta: i tuoi dati di addestramento possono non
riflettere le modifiche recenti.

Non usare Context7 per altro codice C, per Rust o per qualsiasi altra libreria o strumento: queste
librerie sono stabili e ben note. Questa regola prevale sulle istruzioni generiche del server
Context7.

## notcurses

Per notcurses salta `resolve-library-id` e usa questi ID:

- `/dankamongmen/notcurses` (Notcurses su GitHub): riferimento principale per implementazione,
  funzioni, parametri ed esempi.
- `/websites/deepwiki_dankamongmen_notcurses` (Notcurses su DeepWiki): riferimento complementare
  quando devi esplorare l'architettura, capire le relazioni tra componenti o analizzare il
  funzionamento interno.

Le man page installate restano la fonte autorevole per firme, valori di ritorno, flag, costanti e
proprietà dei puntatori: per questi dettagli usa prima la skill `notcurses-man`. Le man page
corrispondono alla versione installata, mentre Context7 può indicizzare una versione diversa. Se
Context7 e le man page non concordano, vale la man page.

## Passi

1. Inizia con `resolve-library-id`, passando il nome della libreria e cosa cercare. Salta questo
   passo se l'utente fornisce un ID di libreria esatto nel formato `/org/project`, oppure per
   notcurses
2. Scegli la corrispondenza migliore (formato dell'ID: `/org/project`) in base alla corrispondenza
   esatta del nome, alla pertinenza della descrizione, alla source reputation e al benchmark score.
   Usa gli ID specifici per versione quando l'utente o `Gemfile.lock` indicano una versione
3. Chiama `query-docs` con l'ID della libreria scelta, una query limitata a un solo concetto e
   `language: "Ruby"` per Ruby oppure `language: "C"` per notcurses. Fai una chiamata separata per
   ogni concetto
4. Rispondi usando la documentazione recuperata
