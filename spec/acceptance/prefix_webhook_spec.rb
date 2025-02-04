# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'Prefix Enabled,System Ruby with No SSL, Not protected, No mcollective', unless: default[:platform] =~ %r{archlinux} do
  context 'default parameters' do
    pp = %(
      file {'/usr/local/bin/prefix_command.rb':
        ensure => file,
        mode   => '0755',
        owner  => 'root',
        group  => '0',
        source => 'puppet:///modules/r10k/prefix_command.rb',
      }
      class { 'r10k':
        sources => {
          'webteam' => {
            'remote'  => 'https://github.com/webteam/somerepo.git',
            'basedir' => '${::settings::confdir}/environments',
            'prefix'  => true,
          },
          'secteam' => {
            'remote'  => 'https://github.com/secteam/someotherrepo.git',
            'basedir' => '${::settings::confdir}/environments',
            'prefix'  => true,
          },
          'noprefix' => {
            'remote'  => 'https://github.com/noprefix/repo.git',
            'basedir' => '${::settings::confdir}/environments'
          },
          'customprefix' => {
            'remote'  => 'https://github.com/customprefix/repo.git',
            'basedir' => '${::settings::confdir}/environments',
            'prefix'  => 'custom'
          }
        },
      }
      class {'r10k::webhook::config':
        enable_ssl      => false,
        protected       => false,
        use_mcollective => false,
        prefix          => true,
        prefix_command  => '/usr/local/bin/prefix_command.rb',
        require         => File['/usr/local/bin/prefix_command.rb'],
        notify          => Service['webhook.service'],
      }
      class {'r10k::webhook':
        require => Class['r10k::webhook::config'],
      }
    )

    it 'applies with no errors' do
      apply_manifest(pp, catch_failures: true)
    end

    it 'is idempotent' do
      apply_manifest(pp, catch_changes: true)
    end

    describe service('webhook') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    # rubocop:disable RSpec/RepeatedExampleGroupBody
    describe command('/usr/bin/curl -d \'{ "ref": "refs/heads/production", "repository": { "name": "puppet-control" , "url": "https://github.com/webteam/somerepo.git"} }\' -H "Accept: application/json" "http://localhost:8088/payload" -k -q') do
      its(:stdout) { is_expected.not_to match %r{.*You shall not pass.*} }
      its(:exit_status) { is_expected.to eq 0 }
    end

    describe command('/usr/bin/curl -d \'{ "ref": "refs/heads/production", "repository": { "name": "puppet-control" , "url": "https://github.com/secteam/someotherrepo.git"} }\' -H "Accept: application/json" "http://localhost:8088/payload" -k -q') do
      its(:stdout) { is_expected.not_to match %r{.*You shall not pass.*} }
      its(:exit_status) { is_expected.to eq 0 }
    end

    describe command('/usr/bin/curl -d \'{ "ref": "refs/heads/production", "repository": { "name": "puppet-control" , "url": "https://github.com/customprefix/repo.git"} }\' -H "Accept: application/json" "http://localhost:8088/payload" -k -q') do
      its(:stdout) { is_expected.not_to match %r{.*You shall not pass.*} }
      its(:exit_status) { is_expected.to eq 0 }
    end

    describe command('/usr/bin/curl -d \'{ "ref": "refs/heads/production", "repository": { "name": "puppet-control" , "url": "https://github.com/noprefix/repo.git"} }\' -H "Accept: application/json" "http://localhost:8088/payload" -k -q') do
      its(:stdout) { is_expected.not_to match %r{.*You shall not pass.*} }
      its(:exit_status) { is_expected.to eq 0 }
    end
    # rubocop:enable RSpec/RepeatedExampleGroupBody
  end
end
