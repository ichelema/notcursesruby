# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
# frozen_string_literal: true

require_relative '../support/nc_helpers'

RSpec.describe Notcurses::Menu do
  let(:key) { Notcurses::Key }
  let(:quit) { ev('q'.ord, modifiers: [:ctrl]) }
  let(:alt_f) { ev('f'.ord, modifiers: [:alt]) }
  # File (0) | Edit (1, voce dopo un separatore) | divisore (2) | Help (3, a destra)
  let(:sections) do
    [{ name: 'File', shortcut: alt_f, items: ['New', nil, { desc: 'Quit', shortcut: quit }] },
     { name: 'Edit', items: %w[Cut Copy] },
     :right,
     { name: 'Help', shortcut: ev(key::F01), items: ['About'] }]
  end

  def ev(id, **opts) = Notcurses::Input.synthesize(id, **opts)

  def click(y, x) = ev(Notcurses::Key::BUTTON1, evtype: :release, y: y, x: x)

  def row_text(plane, y)
    (0...plane.dim_x).map do |x|
      Notcurses::Util.take_string(Notcurses::FFI.ncplane_at_yx(plane.to_ptr, y, x, nil, nil))
    end.join
  end

  # Colore di primo piano (0xRRGGBB) della cella.
  def fg_at(plane, y, x)
    channels = ::FFI::MemoryPointer.new(:uint64)
    Notcurses::Util.free(Notcurses::FFI.ncplane_at_yx(plane.to_ptr, y, x, nil, channels))
    Notcurses::Channels.new(value: channels.read_uint64).fg_rgb24
  end

  describe 'con un contesto aperto' do
    include_context 'con un contesto notcurses'

    let(:std) { nc.stdplane }

    def new_menu(**opts, &block) = described_class.open(nc.stdplane, sections: sections, **opts, &block)

    it 'new crea un piano figlio di parent, largo quanto parent, e disegna la barra' do
      before = nc.stats.planes
      new_menu do |menu|
        plane = menu.plane
        expect(plane).not_to equal(std)
        expect(plane.parent).to eq(std)
        expect(plane.dims).to eq([6, std.dim_x]) # 3 + la sezione più lunga
        expect(plane.yx).to eq([0, 0])
        expect(plane).to be_widget_plane
        expect(std).not_to be_widget_plane
        expect(nc.stats.planes).to eq(before + 1)
        header = row_text(plane, 0)
        expect(header).to start_with('  File  Edit')
        expect(header.rstrip).to end_with('Help')
        expect(menu.context).to equal(nc)
      end
      expect(nc.stats.planes).to eq(before)
      expect(std).not_to be_closed
    end

    it 'bottom: true mette la barra in fondo a parent' do
      parent = std.create_child(rows: 10, cols: 30)
      described_class.open(parent, sections: sections, bottom: true) do |menu|
        expect(menu.plane.yx).to eq([4, 0])
        expect(row_text(menu.plane, 5)).to include('File')
      end
      parent.close
    end

    it 'il piano del menu segue la larghezza di parent' do
      parent = std.create_child(rows: 8, cols: 30)
      described_class.open(parent, sections: sections) do |menu|
        parent.resize(8, 50)
        expect(menu.plane.dim_x).to eq(50)
        expect(row_text(menu.plane, 0).rstrip).to end_with('Help')
      end
      parent.close
    end

    it 'unroll, rollup e selected' do
      new_menu do |menu|
        expect(menu.selected).to be_nil
        expect(menu.unroll(0)).to be true
        item = menu.selected
        expect([item.section, item.desc, item.shortcut]).to eq(['File', 'New', nil])
        expect(row_text(menu.plane, 2)).to include('New')
        expect(menu.unroll(1)).to be true
        expect(menu.selected.desc).to eq('Cut')
        expect(menu.unroll(2)).to be false # il divisore
        expect(menu.selected.desc).to eq('Cut') # nessun cambiamento
        expect(menu.rollup).to equal(menu)
        expect(menu.selected).to be_nil
        expect(menu.rollup.selected).to be_nil
        expect { menu.unroll(4) }.to raise_error(ArgumentError)
        expect { menu.unroll(-1) }.to raise_error(ArgumentError)
        expect { menu.unroll('File') }.to raise_error(TypeError)
      end
    end

    it 'next_item e prev_item saltano i separatori, in modo circolare' do
      new_menu do |menu|
        # senza sezioni aperte srotola la prima e si sposta dalla sua voce selezionata
        expect(menu.next_item.desc).to eq('Quit')
        expect(menu.next_item.desc).to eq('New')
        expect(menu.prev_item.desc).to eq('Quit')
        expect(menu.selected.shortcut).to eq(ev('Q'.ord, modifiers: [:ctrl]))
      end
    end

    it 'next_section e prev_section scorrono le sezioni, saltando il divisore' do
      new_menu do |menu|
        expect(menu.next_section).to be true
        expect(menu.selected.section).to eq('File')
        expect(menu.next_section).to be true
        expect(menu.selected.section).to eq('Edit')
        expect(menu.next_section).to be true
        expect(menu.selected.section).to eq('Help')
        expect(menu.next_section).to be true
        expect(menu.selected.section).to eq('File')
        expect(menu.prev_section).to be true
        expect(menu.selected.section).to eq('Help')
        menu.rollup
        expect(menu.prev_section).to be true
        expect(menu.selected.section).to eq('Help')
      end
    end

    it 'Item è un value object congelato con la scorciatoia normalizzata' do
      new_menu do |menu|
        menu.unroll(0)
        quit_item = menu.next_item
        expect(quit_item).to be_frozen
        expect(quit_item.shortcut.id).to eq('Q'.ord) # Ctrl+q arriva come 'Q' con Ctrl
        expect(quit_item.shortcut.ctrl?).to be true
        expect(quit_item.shortcut).to eq(ev('Q'.ord, modifiers: [:ctrl]))
        expect(quit_item.inspect).to include('File', 'Quit')
        expect(menu.selected).to equal(quit_item)
      end
    end

    it 'set_item_enabled e item_enabled?: la voce disabilitata è saltata e una sezione vuota non si apre' do
      new_menu do |menu|
        expect(menu.item_enabled?('Edit', 'Cut')).to be true
        expect(menu.set_item_enabled('Edit', 'Cut', false)).to equal(menu)
        expect(menu.item_enabled?('Edit', 'Cut')).to be false
        expect(menu.unroll(1)).to be true
        expect(menu.selected.desc).to eq('Copy')
        expect(menu.next_item.desc).to eq('Copy')
        expect(menu.set_item_enabled('Edit', 'Cut', false)).to equal(menu) # stato invariato: nessuna chiamata
        menu.set_item_enabled('Edit', 'Copy', false)
        expect(menu.selected).to be_nil # la sezione aperta senza voci viene chiusa
        expect(fg_at(menu.plane, 0, 8)).to eq(0xdddddd) # intestazione grigia
        expect(menu.unroll(1)).to be false
        menu.set_item_enabled('Edit', 'Copy', true)
        expect(fg_at(menu.plane, 0, 8)).not_to eq(0xdddddd)
        expect(menu.unroll(1)).to be true
        expect(menu.selected.desc).to eq('Copy')
        menu.set_item_enabled('Edit', 'Cut', true)
        expect(menu.prev_item.desc).to eq('Cut')
      end
    end

    it 'selected non restituisce una voce selezionata e poi disabilitata' do
      new_menu do |menu|
        menu.unroll(0)
        expect(menu.selected.desc).to eq('New')
        menu.set_item_enabled('File', 'New', false)
        expect(menu.selected).to be_nil
        expect(menu.next_item.desc).to eq('Quit')
      end
    end

    it 'set_item_enabled rifiuta i casi che mandano in segfault il C' do
      new_menu do |menu|
        expect { menu.set_item_enabled('Help', 'About', false) }.to raise_error(Notcurses::WidgetError, /divisore/)
        expect { menu.set_item_enabled('File', 'Quit', false) }.to raise_error(Notcurses::WidgetError, /separatore/)
        expect { menu.set_item_enabled('Nessuna', 'New', false) }.to raise_error(ArgumentError, /sezione/)
        expect { menu.set_item_enabled('File', 'Open', false) }.to raise_error(ArgumentError, /voce/)
        expect { menu.set_item_enabled('File', 'New', 'no') }.to raise_error(TypeError)
        expect { menu.item_enabled?(:File, 'New') }.to raise_error(TypeError)
        expect(menu.item_enabled?('Help', 'About')).to be true
      end
    end

    it 'senza sezioni apribili next_section, prev_section e next_item non chiamano il C (ciclo infinito)' do
      described_class.open(std, sections: [{ name: 'Solo', items: %w[a] }]) do |menu|
        menu.set_item_enabled('Solo', 'a', false)
        expect([menu.next_section, menu.prev_section]).to eq([false, false])
        expect([menu.next_item, menu.prev_item]).to eq([nil, nil])
        expect(menu.unroll(0)).to be false
      end
    end

    it 'con il divisore in testa next_item e prev_item non leggono sections[-1]' do
      described_class.open(std, sections: [:right, { name: 'Solo', items: %w[a b] }]) do |menu|
        expect(menu.next_item.desc).to eq('b')
        menu.rollup
        expect(menu.prev_item.desc).to eq('a') # la sezione ricorda la voce selezionata
      end
    end

    it 'offer_input: scorciatoie delle sezioni, frecce, Esc' do
      new_menu do |menu|
        expect(menu.offer_input(alt_f)).to be true
        expect(menu.selected.desc).to eq('New')
        expect(menu.offer_input(ev(key::DOWN))).to be true
        expect(menu.selected.desc).to eq('Quit')
        expect(menu.offer_input(ev(key::UP))).to be true
        expect(menu.offer_input(ev(key::SCROLL_DOWN))).to be true
        expect(menu.offer_input(ev(key::SCROLL_UP))).to be true
        expect(menu.offer_input(ev(key::RIGHT))).to be true
        expect(menu.selected.section).to eq('Edit')
        expect(menu.offer_input(ev(key::LEFT))).to be true
        expect(menu.selected.section).to eq('File')
        expect(menu.offer_input(ev(key::ESC))).to be true
        expect(menu.selected).to be_nil
        expect(menu.offer_input(ev(key::ESC))).to be false # nulla aperto
        expect(menu.offer_input(ev(key::F01))).to be true # scorciatoia di Help
        expect(menu.selected.desc).to eq('About')
      end
    end

    it 'offer_input non consuma rilasci, eventi vuoti, scorciatoie di voci e scorciatoie con y o x diversi da 0' do
      described_class.open(std, sections: [{ name: 'Senza', items: %w[a] }, { name: 'Con', shortcut: alt_f, items: %w[b] }]) do |menu|
        expect(menu.offer_input(ev(0))).to be false # il C aprirebbe la sezione senza scorciatoia
        expect(menu.selected).to be_nil
        expect(menu.offer_input(ev(0xffff_ffff))).to be false
        expect(menu.offer_input(ev('f'.ord, modifiers: [:alt], evtype: :release))).to be false
        expect(menu.offer_input(ev('f'.ord, modifiers: [:alt], y: 3))).to be false
        expect(menu.offer_input(ev(key::DOWN))).to be false # nulla aperto
        expect(menu.offer_input(ev('f'.ord, modifiers: [:alt], evtype: :unknown))).to be true
      end
      new_menu do |menu|
        menu.unroll(0)
        expect(menu.offer_input(quit)).to be false # le scorciatoie delle voci sono dell'applicazione
        expect { menu.offer_input(:quit) }.to raise_error(TypeError)
      end
    end

    it "offer_input e mouse_selected con il mouse: intestazione e voci" do
      new_menu do |menu|
        expect(menu.offer_input(click(0, 3))).to be true # su "File"
        expect(menu.selected.desc).to eq('New')
        # voci dalla riga 2 (riga 1: bordo), colonne dopo il bordo sinistro
        expect(menu.mouse_selected(click(4, 4)).desc).to eq('Quit')
        expect(menu.selected.desc).to eq('New') # mouse_selected non cambia la selezione
        expect(menu.mouse_selected(click(3, 4))).to be_nil # separatore
        expect(menu.mouse_selected(ev(key::BUTTON1, evtype: :press, y: 4, x: 4))).to be_nil
        expect(menu.mouse_selected(ev(0))).to be_nil
        expect(menu.offer_input(click(4, 4))).to be true # il C restituisce false
        expect(menu.selected.desc).to eq('Quit')
        expect(menu.offer_input(click(0, 9))).to be true # su "Edit"
        expect(menu.selected.section).to eq('Edit')
        expect(menu.offer_input(click(0, 9))).to be true # di nuovo: chiude
        expect(menu.selected).to be_nil
        expect(menu.offer_input(click(20, 20))).to be false # fuori dal menu
        expect { menu.mouse_selected(nil) }.to raise_error(TypeError)
      end
    end

    it 'valida le sezioni prima della chiamata C' do
      item_sc = ->(id) { [{ name: 'S', items: [{ desc: 'a', shortcut: ev(id) }] }] }
      expect { described_class.new(:std, sections: sections) }.to raise_error(TypeError)
      expect { described_class.new(std) }.to raise_error(ArgumentError)
      expect { described_class.new(std, sections: []) }.to raise_error(ArgumentError)
      expect { described_class.new(std, sections: 'File') }.to raise_error(TypeError)
      expect { described_class.new(std, sections: [:right]) }.to raise_error(ArgumentError, /unica/)
      expect { described_class.new(std, sections: [:right, :right, { name: 'a', items: ['x'] }]) }
        .to raise_error(ArgumentError, /divisore/)
      expect { described_class.new(std, sections: [:left]) }.to raise_error(TypeError)
      expect { described_class.new(std, sections: [{ items: ['x'] }]) }.to raise_error(TypeError)
      expect { described_class.new(std, sections: [{ name: 'a', items: ['x'], colore: 1 }]) }
        .to raise_error(ArgumentError, /chiavi/)
      expect { described_class.new(std, sections: [{ name: 'a', items: [] }]) }.to raise_error(ArgumentError)
      expect { described_class.new(std, sections: [{ name: 'a', items: [nil, nil] }]) }.to raise_error(ArgumentError)
      expect { described_class.new(std, sections: [{ name: 'a', items: 'x' }]) }.to raise_error(TypeError)
      expect { described_class.new(std, sections: [{ name: 'a', items: [1] }]) }.to raise_error(TypeError)
      expect { described_class.new(std, sections: [{ name: "a\n", items: ['x'] }]) }.to raise_error(ArgumentError)
      expect { described_class.new(std, sections: [{ name: 'a', items: [{ desc: "\t" }] }]) }.to raise_error(ArgumentError)
      expect { described_class.new(std, sections: [{ name: 'a', items: [{ desc: 'x', tasto: 1 }] }]) }
        .to raise_error(ArgumentError)
      expect { described_class.new(std, sections: [{ name: 'a', items: [{ desc: 'x', shortcut: 'q' }] }]) }
        .to raise_error(TypeError)
      # scorciatoie delle voci da U+0800: buffer overflow (U+10000 e i Key: abort del processo)
      [0x800, 0xffff, 0x10000, 0x1f600, Notcurses::Key::UP, Notcurses::Key::F01, 0x1b, 0x85, 0].each do |id|
        expect { described_class.new(std, sections: item_sc.call(id)) }.to raise_error(ArgumentError)
      end
      expect { described_class.new(std, sections: [{ name: 'a', shortcut: ev(0), items: ['x'] }]) }
        .to raise_error(ArgumentError)
      expect { described_class.new(std, sections: sections, bottom: 1) }.to raise_error(TypeError)
      expect { described_class.new(std, sections: sections, header_channels: 'grigio') }.to raise_error(TypeError)
      expect(nc.stats.planes).to eq(1)
    end

    it 'accetta scorciatoie di voci fino a U+07FF e colori come Channels' do
      grey = Notcurses::Channels.new.with_fg_rgb24(0x808080)
      secs = [{ name: 'S', items: [{ desc: 'é', shortcut: ev('é'.ord, modifiers: [:alt]) },
                                   { desc: 'ߛ', shortcut: ev(0x7ff) }] }]
      described_class.open(std, sections: secs, header_channels: grey, section_channels: grey.value) do |menu|
        menu.unroll(0)
        expect(menu.selected.shortcut.alt?).to be true
        expect(row_text(menu.plane, 2)).to include('Alt+é')
      end
    end

    it 'close distrugge il piano del menu ma non parent, è idempotente, poi ClosedError' do
      parent = std.create_child(rows: 10, cols: 30)
      menu = described_class.new(parent, sections: sections)
      plane = menu.plane
      expect(menu.close).to be_nil
      expect([menu, plane]).to all(be_closed)
      expect(parent).not_to be_closed
      expect(menu.destroy).to be_nil
      expect { menu.unroll(0) }.to raise_error(Notcurses::ClosedError)
      expect { menu.rollup }.to raise_error(Notcurses::ClosedError)
      expect { menu.next_section }.to raise_error(Notcurses::ClosedError)
      expect { menu.prev_section }.to raise_error(Notcurses::ClosedError)
      expect { menu.next_item }.to raise_error(Notcurses::ClosedError)
      expect { menu.prev_item }.to raise_error(Notcurses::ClosedError)
      expect { menu.selected }.to raise_error(Notcurses::ClosedError)
      expect { menu.mouse_selected(click(0, 0)) }.to raise_error(Notcurses::ClosedError)
      expect { menu.offer_input(alt_f) }.to raise_error(Notcurses::ClosedError)
      expect { menu.set_item_enabled('File', 'New', false) }.to raise_error(Notcurses::ClosedError)
      expect { menu.item_enabled?('File', 'New') }.to raise_error(Notcurses::ClosedError)
      expect { menu.plane }.to raise_error(Notcurses::ClosedError)
      parent.close
    end

    it 'open con un blocco restituisce il valore del blocco e chiude il menu' do
      kept = nil
      result = new_menu do |menu|
        kept = menu
        menu.next_item.desc
      end
      expect(result).to eq('Quit')
      expect(kept).to be_closed
    end

    it 'sopravvive alla distruzione di parent; family_destroy di un antenato rifiuta' do
      grand = std.create_child(rows: 12, cols: 40)
      parent = grand.create_child(rows: 10, cols: 30)
      menu = described_class.new(parent, sections: sections)
      expect { grand.family_destroy }.to raise_error(Notcurses::PlaneError, /widget/)
      parent.close
      expect(menu.plane.parent).to eq(grand)
      expect(menu.unroll(0)).to be true
      menu.close
      grand.family_destroy
    end

    it 'non si crea dentro un callback chiamato da notcurses' do
      parent = std.create_child(rows: 3, cols: 3)
      parent.create_child(rows: 1, cols: 1, resize: ->(_p) { described_class.new(std, sections: sections) })
      expect { parent.resize(4, 4) }.to raise_error(Notcurses::WidgetError, /callback/)
      parent.family_destroy
    end
  end

  describe 'chiusura da parte del contesto' do
    it 'Context#close chiude il menu aperto' do
      menu = plane = nil
      NcHelpers.open_context do |nc|
        menu = described_class.new(nc.stdplane, sections: sections)
        plane = menu.plane
        menu.unroll(0)
      end
      expect([menu, plane]).to all(be_closed)
      expect(menu.close).to be_nil
    end

    it 'Context#drop_planes chiude il menu aperto' do
      NcHelpers.open_context do |nc|
        menu = described_class.new(nc.stdplane, sections: sections)
        nc.drop_planes
        expect(menu).to be_closed
        expect(nc.stats.planes).to eq(1)
      end
    end
  end
end
