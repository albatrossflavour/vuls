# frozen_string_literal: true

require 'spec_helper'

describe 'vuls::target' do
  let(:pub) { 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7 vuls-scan' }
  let(:logs) { [] }

  before(:each) do
    Puppet::Util::Log.newdestination(Puppet::Test::LogCollector.new(logs))
  end

  def warnings
    # Only this module's: the spec harness's own Hiera setup warns as well.
    logs.select { |l| l.level == :warning && l.message.include?('vuls::') }.map(&:message)
  end

  context 'on Linux' do
    let(:facts) { { 'os' => { 'family' => 'Debian', 'name' => 'Ubuntu' }, 'kernel' => 'Linux' } }

    context 'with a public key' do
      let(:params) { { 'ssh_public_key' => pub } }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_user('vulsscan').with(ensure: 'present', managehome: true, shell: '/bin/bash') }

      it 'adds the key under <login>-vuls' do
        is_expected.to contain_ssh_authorized_key('vulsscan-vuls')
          .with(ensure: 'present', user: 'vulsscan', type: 'ssh-rsa', key: 'AAAAB3NzaC1yc2EAAAADAQABAAABAQC7')
        is_expected.to contain_user('vulsscan').that_comes_before('Ssh_authorized_key[vulsscan-vuls]')
      end
    end

    context 'with the login only in Hiera' do
      let(:hiera_config) { 'spec/fixtures/hiera/hiera.yaml' }
      let(:params) { { 'ssh_public_key' => pub } }

      it { is_expected.to contain_user('hieralogin') }
      it { is_expected.to contain_ssh_authorized_key('hieralogin-vuls').with_user('hieralogin') }
    end

    context 'with an existing account' do
      let(:params) { { 'ssh_public_key' => pub, 'login' => 'svc_scan', 'manage_user' => false } }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.not_to contain_user('svc_scan') }
      it { is_expected.to contain_ssh_authorized_key('svc_scan-vuls').with_user('svc_scan') }
    end

    context 'sharing a key another module declared under the same name' do
      let(:params) { { 'ssh_public_key' => pub, 'login' => 'openvas', 'manage_user' => false, 'ssh_key_name' => 'openvas-scan' } }
      let(:pre_condition) do
        "ensure_resource('ssh_authorized_key', 'openvas-scan', { 'ensure' => 'present', 'user' => 'openvas', 'type' => 'ssh-rsa', 'key' => 'AAAAB3NzaC1yc2EAAAADAQABAAABAQC7' })"
      end

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_ssh_authorized_key('openvas-scan') }
    end

    context 'with the same key name declared for a different key' do
      let(:params) { { 'ssh_public_key' => pub, 'login' => 'openvas', 'manage_user' => false, 'ssh_key_name' => 'openvas-scan' } }
      let(:pre_condition) do
        "ensure_resource('ssh_authorized_key', 'openvas-scan', { 'ensure' => 'present', 'user' => 'openvas', 'type' => 'ssh-rsa', 'key' => 'AAAAother' })"
      end

      it { is_expected.to compile.and_raise_error(%r{Duplicate declaration}) }
    end

    context 'without a public key' do
      it 'compiles, changes nothing, and says why' do
        is_expected.to compile.with_all_deps
        is_expected.to have_resource_count(0)
        expect(warnings).to include(%r{vuls::target::ssh_public_key is not set})
      end
    end

    context 'with a private key by mistake' do
      let(:params) { { 'ssh_public_key' => '-----BEGIN OPENSSH PRIVATE KEY-----' } }

      it { is_expected.to compile.and_raise_error(%r{ssh_public_key}) }
    end
  end

  context 'on Windows' do
    let(:facts) { { 'os' => { 'family' => 'windows', 'name' => 'windows' }, 'kernel' => 'windows' } }
    let(:params) { { 'ssh_public_key' => pub } }

    it 'does nothing, because Vuls reads Windows from facts' do
      is_expected.to have_resource_count(0)
      expect(warnings).to be_empty
    end
  end
end
