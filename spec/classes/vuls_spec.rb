# frozen_string_literal: true

require 'spec_helper'
require 'json'

describe 'vuls' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:linux_rows) do
        [
          { 'certname' => 'b.example.com', 'facts.networking.ip' => '192.0.2.2', 'facts.os.family' => 'RedHat',
            'facts.ssh' => { 'ed25519' => { 'type' => 'ssh-ed25519', 'key' => 'AAAAed' }, 'dsa' => { 'type' => 'ssh-dss', 'key' => 'AAAAdss' } } },
          { 'certname' => 'a.example.com', 'facts.networking.ip' => '192.0.2.1', 'facts.os.family' => 'Debian',
            'facts.ssh' => { 'rsa' => { 'type' => 'ssh-rsa', 'key' => 'AAAArsa' } } },
          { 'certname' => 'gce-1.example.com', 'facts.networking.ip' => '10.0.0.1', 'facts.os.family' => 'Debian',
            'facts.ssh' => { 'rsa' => { 'type' => 'ssh-rsa', 'key' => 'AAAAgce' } } },
          { 'certname' => 'nofacts.example.com', 'facts.networking.ip' => '192.0.2.9', 'facts.os.family' => 'Debian' },
        ]
      end
      let(:windows_rows) do
        [
          { 'certname' => 'w.example.com', 'facts.networking.ip' => '192.0.2.3', 'facts.kernelrelease' => '10.0.20348',
            'facts.os' => { 'windows' => { 'product_name' => 'Windows Server 2022 Standard', 'installation_type' => 'Server' }, 'release' => { 'major' => '2022' } },
            'facts.vuls_windows' => { 'ubr' => '4052', 'hotfixes' => ['KB5012170'] } },
          { 'certname' => 'nofact.example.com', 'facts.networking.ip' => '192.0.2.4', 'facts.kernelrelease' => '10.0.20348',
            'facts.os' => {} },
        ]
      end
      let(:pre_condition) do
        <<~PP
          function node_encrypt::secret($data) { $data }
          function puppetdb_query(String $query) {
            $query ? {
              /vuls_windows/ => #{windows_rows.inspect},
              default        => #{linux_rows.inspect},
            }
          }
        PP
      end
      let(:toml) { catalogue.resource('file', '/etc/vuls/config.toml')[:content] }
      let(:unit) { catalogue.resource('systemd::timer', 'vuls-scan.timer')[:service_content] }

      context 'with a bare include' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_user('vuls').with(ensure: 'present', system: true, shell: '/sbin/nologin') }
        it { is_expected.to contain_exec('vuls-install-0.40.1').with_creates('/opt/vuls/vuls-0.40.1') }
        it { is_expected.to contain_file('/usr/local/bin/vuls').with(ensure: 'link', target: '/opt/vuls/vuls-0.40.1') }
        it { is_expected.to contain_class('vuls::install').that_comes_before('Class[vuls::config]') }
        it { is_expected.to contain_class('vuls::config').that_comes_before('Class[vuls::service]') }
        it { is_expected.to contain_class('vuls::service') }
        it { is_expected.to contain_group('vuls').with(ensure: 'present', system: true) }
        it { is_expected.to contain_file('/opt/vuls').with(ensure: 'directory', owner: 'root', mode: '0755') }
        it { is_expected.to contain_file('/etc/vuls').with(ensure: 'directory', owner: 'root', group: 'vuls', mode: '0750') }

        ['/var/lib/vuls', '/var/lib/vuls/results', '/var/lib/vuls/log', '/var/lib/vuls/.vuls'].each do |dir|
          it { is_expected.to contain_file(dir).with(ensure: 'directory', owner: 'vuls', group: 'vuls', mode: '0750') }
        end

        it { is_expected.to contain_file('/etc/vuls/config.toml').with(owner: 'root', group: 'vuls', mode: '0640') }
        it { is_expected.to contain_file('/etc/vuls/windows.json').with(owner: 'root', group: 'vuls', mode: '0640') }

        it 'keeps the timer off, but the service there to run by hand' do
          is_expected.to contain_systemd__timer('vuls-scan.timer').with(active: false, enable: false)
        end

        it 'logs in as vuls' do
          expect(toml).to include('user = "vuls"')
          is_expected.to contain_file('/etc/vuls/ssh_config').with_content(%r{User vuls})
        end

        it 'writes no key file' do
          is_expected.to contain_file('/etc/vuls/scan_key').with_ensure('absent')
        end

        it 'scans RedHat offline and the rest fast, by certname, sorted' do
          expect(toml).to match(%r{\[servers\."a\.example\.com"\]\nhost = "192\.0\.2\.1"\n\n\[servers\."b\.example\.com"\]\nhost = "192\.0\.2\.2"\nscanMode = \["offline"\]})
        end

        it 'leaves out a node with no ssh facts' do
          expect(toml).not_to include('nofacts.example.com')
        end

        it 'skips DSA host keys' do
          is_expected.to contain_file('/etc/vuls/known_hosts').with_content(%r{192\.0\.2\.2,b\.example\.com ssh-ed25519 AAAAed})
          is_expected.to contain_file('/etc/vuls/known_hosts').without_content(%r{ssh-dss})
        end

        it 'sends only Windows nodes with the fact' do
          hosts = JSON.parse(catalogue.resource('file', '/etc/vuls/windows.json')[:content])
          expect(hosts.map { |h| h['certname'] }).to eq(['w.example.com'])
          expect(hosts[0]).to include('ubr' => '4052', 'product_name' => 'Windows Server 2022 Standard', 'release_major' => '2022')
        end

        it 'runs no condition, and ends by recording the complete run' do
          expect(unit).not_to include('ExecCondition')
          expect(unit).to match(%r{ExecStart=-/usr/local/bin/vuls scan .*\nExecStart=/usr/local/bin/vuls report .*-ignore-unfixed})
          expect(unit).to include('ExecStart=/usr/local/sbin/vuls-windows-collect --config=/etc/vuls/windows.json')
          expect(unit).to match(%r{ExecStart=/usr/local/sbin/vuls-mark-complete /var/lib/vuls/results /var/lib/vuls/last-complete-run\n})
          expect(unit).to include('MemoryMax=8G')
          expect(unit).to include('-mtime +3 ')
        end

        it { is_expected.to contain_file('/usr/local/sbin/vuls-mark-complete').with(mode: '0755', source: 'puppet:///modules/vuls/vuls-mark-complete') }
        it { is_expected.to contain_file('/usr/local/sbin/vuls-windows-collect').with(mode: '0755', source: 'puppet:///modules/vuls/vuls-windows-collect.py') }
      end

      context 'with a key, a login, schedules, and a condition' do
        let(:params) do
          {
            'scan_ssh_private_key' => sensitive("-----BEGIN OPENSSH PRIVATE KEY-----\nabc\n-----END OPENSSH PRIVATE KEY-----\n"),
            'scan_login' => 'openvas',
            'scan_schedule_enabled' => true,
            'scan_time' => 'Sun *-*-* 22:00:00',
            'scan_condition' => '/usr/local/sbin/busy-check idle',
            'exclude' => ['a.example.com'],
            'exclude_patterns' => ['^gce-'],
          }
        end

        it { is_expected.to contain_systemd__timer('vuls-scan.timer').with(active: true, enable: true).with_timer_content(%r{OnCalendar=Sun \*-\*-\* 22:00:00}) }
        it { is_expected.to contain_file('/etc/vuls/scan_key').with(ensure: 'file', mode: '0640', group: 'vuls').with_content(%r{\A-----BEGIN OPENSSH PRIVATE KEY-----\nabc\n-----END OPENSSH PRIVATE KEY-----\n\z}) }
        it { expect(unit).to include('ExecCondition=+/usr/local/sbin/busy-check idle') }
        it { expect(toml).to include('user = "openvas"') }

        it 'drops excluded certnames and patterns' do
          expect(toml).not_to include('a.example.com')
          expect(toml).not_to include('gce-1.example.com')
          expect(toml).to include('b.example.com')
        end
      end

      context 'when PuppetDB returns nothing' do
        let(:linux_rows) { [] }
        let(:windows_rows) { [] }

        it 'still installs, with no servers' do
          is_expected.to compile.with_all_deps
          is_expected.to contain_exec('vuls-install-0.40.1')
          expect(toml).not_to include('[servers.')
        end
      end

      context 'when PuppetDB is down' do
        let(:pre_condition) do
          <<~PP
            function node_encrypt::secret($data) { $data }
            function puppetdb_query(String $query) { fail('connection refused') }
          PP
        end

        it { is_expected.to compile.with_all_deps }
      end

      context 'with a bad version' do
        let(:params) { { 'sha256' => 'short' } }

        it { is_expected.to compile.and_raise_error(%r{sha256}) }
      end
    end
  end
end
