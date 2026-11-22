---
name: verify
description: Ricetta per verificare a mano notcursesruby (gem Ruby, wrapper di notcurses) con l'API pubblica, quando nell'ambiente non c'è un emulatore di terminale, su un terminale headless (ncvt, libghostty-vt 1.x) che mostra lo schermo e il cursore, o su un terminale finto su pty. Usala in /trinity:workflow:2_work-verify o per provare dal vivo Context, Direct, Visual, i widget e i segnali.
---

# Verifica di notcursesruby dall'API pubblica

La superficie è il confine della gem: script d'esempio con `require 'notcurses'` e l'API pubblica, mai le
funzioni interne. Cartelle, script e log vanno in `~/.claude/tmp/verify.*`
(`mktemp -d "$HOME/.claude/tmp/verify.XXXXXX"`), mai nel repository.

## Il terminale

notcurses aspetta, senza timeout, le risposte del terminale alle query dell'init. In questo ambiente non c'è un
emulatore utilizzabile:

- tmux staccato, o con un client dentro `script`, non risponde alle query: `Context.open` resta fermo anche con
  la lib di `master`;
- non c'è un display: kitty e gli altri emulatori non partono.

Funzionano due terminali senza display:

- **ncvt** (sezione sotto): un emulatore vero (libghostty-vt, il nucleo di Ghostty) che risponde da solo alle query
  e mostra lo schermo. Usalo quando la modifica si vede sullo schermo: testo, posizione e visibilità del cursore,
  schermo alternativo.
- **il terminale finto** delle spec: risponde solo a DA1 e alla posizione del cursore, ma può trattenere DA1 fino a
  un segnale (`FAKETERM_HOLD`). Usalo per i tempi dell'init.

### ncvt (libghostty-vt)

`ncvt.c`, in questa cartella, avvia un comando su un pty con `forkpty`, gli passa le risposte di libghostty-vt
(DA1, posizione del cursore, modi) e stampa lo stato dello schermo. La libreria va compilata una volta, fuori dal
repository:

```sh
B="$HOME/.claude/tmp/libghostty-vt"; V=1.0.1
mkdir -p "$B/dl" "$B/src" "$B/prefix"
for f in libghostty-vt-$V.tar.gz libghostty-vt-$V-deps.tar.gz SHA256SUMS SHA256SUMS.minisig; do
  curl -fsSL -o "$B/dl/$f" "https://release.files.ghostty.org/libghostty-vt/$V/$f"
done
minisign -V -P RWQlAjJC23149WL2sEpT/l0QKy7hMIFhYdQOFy0Z7z7PbneUgvlsnYcV -m "$B/dl/SHA256SUMS"
(cd "$B/dl" && sha256sum --ignore-missing -c SHA256SUMS)
tar -xzf "$B/dl/libghostty-vt-$V.tar.gz" -C "$B/src"; tar -xzf "$B/dl/libghostty-vt-$V-deps.tar.gz" -C "$B/src"
(cd "$B/src/libghostty-vt-$V" && mise x zig@0.17.1 -- zig build --prefix "$B/prefix" \
  --system "$B/src/libghostty-vt-$V-deps" -Doptimize=ReleaseFast)
PKG_CONFIG_PATH="$B/prefix/lib/pkgconfig" cc -O2 -Wall -Wextra -o "$B/ncvt" .claude/skills/verify/ncvt.c \
  $(PKG_CONFIG_PATH="$B/prefix/lib/pkgconfig" pkg-config --cflags --libs libghostty-vt) -lutil -Wl,-rpath,"$B/prefix/lib"
```

- libghostty-vt è stabile dalla 1.0 (ABI C stabile per tutta la serie 1.x). La build vuole Zig 0.17 e si ferma con
  le altre minor. Usa i tarball di `release.files.ghostty.org`, non l'archivio dei tag GitHub, che costruisce l'app.
- `minisign` è il pacchetto di sistema (`sudo pacman -S minisign`).

Uso: `ncvt [-c COLONNE] [-r RIGHE] [-t SECONDI] [-m] [-s FILE] -- comando`.

- `-s FILE`: lo script crea FILE con un'etichetta nella prima riga; ncvt aspetta che l'output si fermi, stampa lo
  snapshot, cancella FILE e crea `FILE.done`; lo script aspetta `FILE.done`, lo cancella e prosegue.
  `verify_reader.rb`, in questa cartella, è un esempio completo (Reader: colonna 0, metà destre, cursore).
- Uno snapshot ha la riga `cursor x=.. y=.. visible=0|1 screen=primary|alternate replies=N` (posizione da 0,
  `visible` è il modo 25) e le righe dello schermo numerate da 0. Alla fine stampa uno snapshot e l'exit status.
- `-m`: terminale muto, non risponde a niente; con `-t` il comando fermo nell'init viene ucciso con SIGKILL.
- Lancia lo script con `TERM=xterm-256color LANG=C.UTF-8 LC_ALL=C.UTF-8` e
  `Context.open(termtype: 'xterm-256color', suppress_banners: true)`, senza `output:`.
- Prendi lo snapshot a widget aperto: la chiusura di un Reader con `cursor: true` spegne il cursore.
- ncvt non mostra la larghezza delle celle: per i glifi larghi stampa `Plane#at` nell'etichetta.

### Prova rapida: `screen`

Per controllare in un minuto cosa vede l'utente, anche durante l'implementazione (regola 22 di `handoff.md`: un
consiglio in un messaggio o nello YARD si prova sullo schermo prima del commit). Lo script di prova usa la lib del
checkout che contiene `screen` (anche un worktree) e due helper di `snap.rb`, caricato da `screen`:

```ruby
Screen.open do |nc|
  pl = nc.stdplane.create_child(rows: 1, cols: 10, y: 2, x: 10)
  pl.putstr("A🇮🇹B", y: 0, x: 0)
  Screen.snap(nc, "bandiera: contents=#{pl.contents.inspect}")
  pl.putstr("xyz", y: 0, x: 1)
  Screen.snap(nc, "sovrascritta")   # schermo: "Axyz B", la B vecchia resta (ICH-586)
end
```

```sh
.claude/skills/verify/screen -c 40 -r 6 "$S/prova.rb"   # -a per stampare anche le righe vuote
```

`Screen.snap` fa il render e aspetta lo snapshot; l'etichetta va su una riga, al massimo 255 byte. Lo script di prova
sta nello scratchpad, non nel repository.

### Terminale finto

Il terminale finto delle spec di integrazione (`spec/integration/pty_spec.rb`): un pty con un thread
che risponde a DA1 e alla posizione del cursore.

```ruby
require 'io/console'
require 'pty'

master, slave = PTY.open
slave.winsize = [24, 80]
STDIN.reopen(slave)
answer = Queue.new
hold = ENV['FAKETERM_HOLD'] == '1' # con 1 il terminale risponde a DA1 solo dopo answer << true
Thread.new do
  loop do
    data = master.readpartial(65_536)
    data.scan(/\e\[6n|\e\[c/) do |q|
      answer.pop if q == "\e[c" && hold
      master.write(q == "\e[6n" ? "\e[5;7R" : "\e[?62;22c")
    end
  end
rescue IOError, Errno::EIO
  nil
end
opts = { output: slave.path, termtype: 'xterm-256color' } # Context: anche suppress_banners: true
```

Lo stato del terminale si legge da `slave.echo?`; l'output arriva su `master` (salvalo in una String per
contare quello che il programma ha scritto). Per i casi senza terminale basta
`output: '/dev/null', termtype: 'xterm-256color'` (con `drain_input: true` per `Context`).

## Lanciare gli esempi

- Lib del branch: `ruby -I<worktree>/lib esempio.rb`.
- Confronto con il codice di prima: `git -C <worktree> archive -o <tmp>/old.tar <commit> lib`, estrai l'archivio
  in `<tmp>/old` e lancia `ruby -I<tmp>/old/lib esempio.rb`. Il difetto deve vedersi con la lib vecchia e
  sparire con quella nuova.
- Sempre con un limite di tempo: `timeout -s KILL 30 ruby ...`.

## Segnali (Ctrl-C)

- Manda i Ctrl-C da fuori, come un utente: lo script scrive il proprio pid in un file, la shell fa
  `kill -INT <pid>`.
- Trappola: uno script bash non interattivo avvia i comandi con `&` e con SIGINT e SIGQUIT ignorati
  (`grep SigIgn /proc/<pid>/status` dà `0x6`). Metti `set -m` nello script che avvia il processo.
- Un processo fermo nell'init di notcurses (terminale che non risponde mai) non esce né con SIGTERM né con
  SIGINT: alla fine serve `kill -KILL`.

## Cosa provare

- Contesti: apertura e chiusura, `echo?` prima e dopo, registro (`Notcurses.active_context`), riapertura.
- Eccezioni asincrone: `Timeout.timeout`, `Thread#raise`, `Thread#kill` e Ctrl-C esterni durante l'init e le
  letture di file. Per le letture usa una FIFO con un writer esterno lento
  (`spawn(RbConfig.ruby, '-e', 'File.open(ARGV[0], "w") { |f| sleep 1; f.write(File.binread(ARGV[1])) }', fifo, png)`)
  e conta i descrittori in `/proc/self/fd` prima e dopo.
- Le finestre di un solo punto di codice (una seconda eccezione in una riga precisa) non hanno un innesco
  affidabile dall'API pubblica: le coprono le spec con `TracePoint`.
