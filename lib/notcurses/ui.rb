# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Framework per le applicazioni interattive, scritto in Ruby sopra il
  # wrapper: il ciclo degli eventi ({EventLoop}), il focus e la consegna
  # dell'input ({App}), il resize e i widget composti ({Container}, {Label},
  # {Button}, {TextInput}, {ListView}, {LogView}, {Dialog}).
  #
  # Thread: solo il thread che esegue {EventLoop#run} chiama notcurses, tranne
  # il thread di input del contesto, che durante run legge i tasti; gli altri
  # thread passano dal ciclo con {EventLoop#post}.
  module UI
  end
end

require_relative 'ui/task'
require_relative 'ui/scheduler'
require_relative 'ui/event_loop'
require_relative 'ui/component'
require_relative 'ui/container'
require_relative 'ui/app'
require_relative 'ui/label'
require_relative 'ui/button'
require_relative 'ui/text_input'
require_relative 'ui/list_view'
require_relative 'ui/log_view'
require_relative 'ui/dialog'
