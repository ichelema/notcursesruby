# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

module Notcurses
  # Framework per le applicazioni interattive, scritto in Ruby sopra il
  # wrapper: il ciclo degli eventi ({EventLoop}), il focus e la consegna
  # dell'input ({App}), il resize e i widget composti ({Container}, {Label},
  # {Button}, {TextInput}, {ListView}, {LogView}, {Dialog}).
  #
  # Thread: solo il thread che esegue {EventLoop#run} chiama notcurses; gli
  # altri thread passano dal ciclo con {EventLoop#post}.
  module UI
  end
end

require_relative 'ui/event_loop'
