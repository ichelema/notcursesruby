# Generated from notcurses 3.0.17
# Source: notcurses/include/notcurses/notcurses.h
require 'rspec'
require 'notcurses/ffi'
require 'fileutils'
require 'open3'
require 'rbconfig'
require 'tmpdir'

RSpec.describe Notcurses::FFI do
  it 'loads the library without error' do
    expect { Notcurses::FFI }.not_to raise_error
  end

  it 'returns a version string' do
    version = Notcurses::FFI.notcurses_version
    expect(version).to be_a(String)
    expect(version).to match(/\d+\.\d+\.\d+/)
  end

  it 'can init and stop without crash' do
    # usa /dev/null come output per evitare di prendere il terminale
    opts = Notcurses::FFI::NotcursesOptions.new
    fp = Notcurses::FFI.fopen("/dev/null", "w")
    nc = Notcurses::FFI.notcurses_init(opts, fp)
    expect(nc).not_to be_null
    result = Notcurses::FFI.notcurses_stop(nc)
    expect(result).to eq(0)
    Notcurses::FFI.fclose(fp)
  end

  # Su FreeBSD, NetBSD, OpenBSD e Linux i386/ppc64/riscv64/s390x il types.conf
  # di ffi non ha wchar_t e uintmax_t. Una copia della gem ffi senza le due
  # typedef simula quelle piattaforme in un processo figlio.
  it 'works when the ffi types.conf has no wchar_t and uintmax_t' do
    Dir.mktmpdir do |dir|
      FileUtils.cp_r(File.join(Gem.loaded_specs['ffi'].full_gem_path, 'lib'), dir)
      conf = File.join(dir, 'lib', 'ffi', 'platform', FFI::Platform::NAME, 'types.conf')
      File.write(conf, File.readlines(conf).grep_v(/^rbx\.platform\.typedef\.(wchar_t|uintmax_t) /).join)
      ffi_c_dir = File.dirname($LOADED_FEATURES.grep(/ffi_c\./).first) # anche con una gem ffi compilata da sorgente
      script = <<~RUBY
        require 'notcurses'
        raise 'wcwidth' unless Notcurses::FFI.wcwidth(0x4e00) == 2
        raise 'metric' unless Notcurses.metric(1234) == '1.23K'
        Notcurses::Direct.open(output: '/dev/null', termtype: 'xterm-256color') do |d|
          d.box(3, 3)
          d.box(3, 3, set: '┌┐└┘─│')
        end
        puts 'ok'
      RUBY
      lib = File.expand_path('../lib', __dir__)
      cmd = [RbConfig.ruby, '--disable-gems', '-I', File.join(dir, 'lib'), '-I', ffi_c_dir, '-I', lib, '-e', script]
      out, status = Open3.capture2e({'RUBYOPT' => nil}, *cmd, stdin_data: '')
      expect(status.exitstatus).to eq(0), out
      expect(out).to include('ok')
    end
  end
end
