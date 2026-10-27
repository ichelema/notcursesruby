<!--
Generated from notcurses 3.0.17
Source: notcurses/include/notcurses/notcurses.h
-->
# notcursesruby

Binding Ruby completo per [notcurses](https://github.com/dankamongmen/notcurses) 3.0.17, la libreria per
interfacce testuali moderne nel terminale (colori a 24 bit, Unicode, immagini e video, widget).

La gem ha tre livelli:

| Livello | Modulo | Uso |
| --- | --- | --- |
| Layer FFI raw | `Notcurses::FFI` | mappatura 1:1 dell'API C: ogni funzione di `notcurses.h` e `direct.h` è collegata o reimplementata in Ruby |
| Wrapper idiomatico | `Notcurses::Context`, `Plane`, `Visual`, `Direct`, widget… | oggetti Ruby con distruttori, eccezioni e keyword arguments |
| Framework UI | `Notcurses::UI` | ciclo degli eventi, focus, resize e widget composti (`App`, `Container`, `Button`, `TextInput`, `ListView`, `LogView`, `Dialog`) |

La gem è scritta in Ruby puro sopra la gem [ffi](https://github.com/ffi/ffi): non serve un compilatore.

## Requisiti

- Ruby >= 3.1 (provato su 3.1, 3.2, 3.3, 3.4 e 4.0).
- notcurses **3.0.17** di sistema, con `libnotcurses.so.3` e `libnotcurses-core.so.3`. Il layer FFI collega le
  funzioni al caricamento: con una versione più vecchia può mancare un simbolo e `require 'notcurses'` fallisce.
- Un database terminfo (ncurses) con la voce del terminale, per esempio `xterm-256color`.
- Una locale UTF-8.

### Installare notcurses

| Sistema | Comando | Note |
| --- | --- | --- |
| Arch Linux | `pacman -S notcurses` | provato con 3.0.17-3 |
| Ubuntu 26.04 LTS | `apt install libnotcurses3 libnotcurses-core3` | non provato; Ubuntu 24.04 ha 3.0.7, non supportata |
| Fedora 44 | `dnf install notcurses` | non provato; Fedora 43 ha 3.0.16 |
| macOS (Homebrew) | `brew install notcurses` | non provato |
| Windows | — | non supportato |

Per le immagini e i video notcurses deve essere compilato con ffmpeg (è così nei pacchetti sopra).

## Installazione

La gem non è pubblicata su rubygems.org. Con Bundler, dal repository:

```ruby
# Gemfile
gem 'notcursesruby', git: 'https://github.com/ichelema/notcursesruby'
```

Oppure costruisci e installa la gem da un checkout:

```sh
gem build notcursesruby.gemspec
gem install ./notcursesruby-0.1.0.gem
```

Il nome della gem è `notcursesruby`; il `require` è `notcurses`.

## Uso

### Disegnare su un piano

```ruby
require 'notcurses'

Notcurses::Context.open do |nc|
  plane = nc.stdplane
  plane.set_fg_rgb(255, 200, 0).putstr('Ciao da notcurses!', y: 1, x: 2)
  nc.render
  nc.get(timeout: 5) # aspetta un tasto per al massimo 5 secondi
end
```

`Context.open` chiude il contesto e ripristina il terminale alla fine del blocco, anche con un'eccezione.

### Un'applicazione con `Notcurses::UI`

```ruby
require 'notcurses'

Notcurses::Context.open do |nc|
  app = Notcurses::UI::App.new(nc)
  form = Notcurses::UI::Container.new(app.root, border: true, title: 'Accesso')
  Notcurses::UI::Label.new(form, text: 'Nome:', size: 1)
  name = Notcurses::UI::TextInput.new(form, size: 1)
  Notcurses::UI::Button.new(form, 'Entra', size: 3) { app.stop }
  app.on_key('x', ctrl: true) { app.stop }
  reason = app.run # :stop, :eof o :interrupt (Ctrl+C)
  puts "#{reason}: #{name.text}"
end
```

Tab e Shift+Tab spostano il focus. Ctrl+S, Ctrl+Q, Ctrl+C, Ctrl+Z e Ctrl+\ di default restano al terminale; con
`app.run(no_flow_control: true, no_linesigs: true)` arrivano come tasti a `on_key`.

Un esempio completo (modulo, elenco, log di un processo figlio, orologio, dialogo di conferma) è nella gem:

```sh
ruby "$(gem contents notcursesruby | grep examples/demo.rb)"
```

## Limiti noti

- notcurses non è thread-safe: un contesto va usato da un solo thread alla volta. In `Notcurses::UI` gli altri
  thread passano il lavoro al ciclo con `post`.
- Alcuni bug di notcurses 3.0.17 sono aggirati nel wrapper; alcune funzioni C non sono offerte perché in 3.0.17 non
  funzionano (render su buffer o su file, cancellazione delle voci di un `Selector`).
- Ctrl+S, Ctrl+Q e i tasti dei segnali non arrivano all'applicazione senza le opzioni di `run` descritte sopra.
- Provata solo su Linux x86_64. Le spec non provano i blitter a pixel (sixel, kitty) su un terminale vero.

## Documentazione

La documentazione dell'API è nei commenti YARD. Per generarla in `doc/`:

```sh
bundle install
bundle exec yard doc
```

La CI la genera a ogni push e la allega al run come artifact. Il layer `Notcurses::FFI` non è nella documentazione
generata: segue l'API C, descritta nelle man page di notcurses.

## Sviluppo

```sh
git clone --recurse-submodules https://github.com/ichelema/notcursesruby
cd notcursesruby
bundle install
TERM=xterm-256color COLORTERM=truecolor LANG=C.UTF-8 bundle exec rspec < /dev/null
```

- Le spec aprono un contesto su `/dev/null` con `termtype: 'xterm-256color'`: non serve un terminale.
- `COLORTERM=truecolor` serve alle spec dei colori RGB: senza, notcurses non abilita i 24 bit e 10 esempi falliscono.
- Il submodule `notcurses/` serve alle spec delle immagini (`notcurses/data`).
- La spec differenziale del layer FFI usa `libnotcurses-ffi.so.3`; se la libreria manca, va in skip.
- Coverage: `bundle exec rspec --require ./spec/support/coverage.rb`, report in `coverage/`.

## Licenza

Apache-2.0, come notcurses. Vedi `LICENSE` e `NOTICE`.
