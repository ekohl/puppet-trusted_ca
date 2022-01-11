# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'trusted_ca', order: :defined do
  context 'failure before cert' do
    # Set up site first, verify things don't work
    it 'sets up apache for testing' do
      pp = <<-EOS
      include java
      include apache
      apache::vhost { 'trusted_ca':
        docroot    => '/tmp',
        port       => 443,
        servername => $facts['fqdn'],
        ssl        => true,
        ssl_cert   => '/etc/ssl-secure/test.crt',
        ssl_key    => '/etc/ssl-secure/test.key',
      }
      EOS
      apply_manifest(pp, catch_failures: true)
    end

    describe command("/usr/bin/curl https://#{fact('hostname')}.example.com:443") do
      its(:exit_status) { is_expected.to eq 60 }
    end

    describe command("cd /root && /usr/bin/java SSLPoke #{fact('hostname')}.example.com 443") do
      its(:exit_status) { is_expected.to eq 1 }
    end
  end

  context 'success after cert' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        class { 'trusted_ca': }
        trusted_ca::ca { 'test': source => '/etc/ssl-secure/test.crt' }
        PUPPET
      end
    end

    describe package('ca-certificates') do
      it { is_expected.to be_installed }
    end

    # https://github.com/rubocop/rubocop-rspec/issues/1231
    # rubocop:disable RSpec/RepeatedExampleGroupBody
    describe command("/usr/bin/curl https://#{fact('hostname')}.example.com:443") do
      its(:exit_status) { is_expected.to eq 0 }
    end

    describe command("cd /root && /usr/bin/java SSLPoke #{fact('hostname')}.example.com 443") do
      its(:exit_status) { is_expected.to eq 0 }
    end
    # rubocop:enable RSpec/RepeatedExampleGroupBody
  end
end
