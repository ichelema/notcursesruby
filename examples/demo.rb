# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

# Prova manuale di Notcurses::UI su un terminale vero:
#
#   ruby -Ilib examples/demo.rb
#
# Tab e Shift+Tab spostano il focus; il mouse sceglie le voci e preme i
# pulsanti; un task (app.async) legge un processo figlio e scrive nel log;
# l'orologio usa un timer.
# Ridimensiona il terminale: il layout segue. Ctrl+X o "Esci" chiedono
# conferma; Ctrl-C esce subito (:interrupt).

require 'notcurses'
require 'rbconfig'

ui = Notcurses::UI
reason = Notcurses::Context.open do |nc|
  app = ui::App.new(nc)
  begin
    nc.mice_enable
  rescue Notcurses::ContextError
    nil # terminale senza mouse: la demo funziona con la tastiera
  end

  top = ui::Container.new(app.root, direction: :horizontal)
  form = ui::Container.new(top, border: true, title: 'Modulo')
  log_box = ui::Container.new(app.root, border: true, title: 'Log')
  log = ui::LogView.new(log_box)
  ui::Label.new(form, text: 'Nome:', size: 1)
  name = ui::TextInput.new(form, size: 1) { |input| log.append("Invio nel campo: #{input.text}\n") }
  ui::Label.new(form, text: '', size: 1)
  dialog = nil
  confirm = lambda do
    next if dialog && !dialog.closed?

    dialog = ui::Dialog.new(app, text: 'Uscire dalla demo?', title: 'Conferma', buttons: %w[Sì No]) do |choice|
      choice == 'Sì' ? app.stop : log.append("Uscita annullata (#{choice.inspect})\n")
    end
  end
  buttons = ui::Container.new(form, direction: :horizontal, size: 3)
  ui::Button.new(buttons, 'Saluta') { log.append("Ciao, #{name.text.empty? ? 'sconosciuto' : name.text}!\n") }
  ui::Button.new(buttons, 'Esci') { confirm.call }
  ui::ListView.new(ui::Container.new(top, border: true, title: 'Elenco'), items: (1..30).map { |i| "Voce #{i}" }) do |list|
    log.append("Scelta: #{list.selected_item}\n")
  end
  clock = ui::Label.new(app.root, align: :right, size: 1)
  app.every(1) { clock.text = Time.now.strftime('%T') }

  # un task legge il processo figlio senza thread: readpartial attende senza fermare il ciclo
  child = '$stdout.sync = true; 5.times { |i| puts "riga #{i + 1} dal processo figlio"; sleep 1 }'
  app.async do
    IO.popen([RbConfig.ruby, '-e', child]) do |io|
      loop { log.append(io.readpartial(4096)) }
    rescue EOFError
      log.append("Fine del processo figlio\n")
    ensure
      Process.kill('TERM', io.pid) # uscita prima della fine del figlio: la chiusura di io non lo attende
    end
  end
  app.on_key('x', ctrl: true) { confirm.call } # non Ctrl+Q: il terminale lo usa per il controllo di flusso
  app.on_resize { |rows, cols| log.append("Resize: #{rows}x#{cols}\n") }
  app.run
end
puts "Uscita: #{reason}"
