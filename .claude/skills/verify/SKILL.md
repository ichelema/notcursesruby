---
name: verify
description: Ricetta per verificare a mano notcursesruby (gem Ruby, wrapper di notcurses) su un terminale finto con l'API pubblica, quando nell'ambiente non c'è un emulatore di terminale. Usala in /trinity:workflow:2_work-verify o per provare dal vivo Context, Direct, Visual e i segnali.
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

Funziona il terminale finto delle spec di integrazione (`spec/integration/pty_spec.rb`): un pty con un thread
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
