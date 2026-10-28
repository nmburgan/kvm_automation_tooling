require 'spec_helper'

describe 'kvm_automation_tooling::build_artifact_path' do
  it 'returns an el rpm for the cpu architecture' do
    is_expected.to(
      run.with_params('openvox-agent', '8.29.0', 'almalinux-9-x86_64')
        .and_return('openvox-agent/8.29.0/openvox-agent-8.29.0-1.el9.x86_64.rpm')
    )
  end

  it 'returns a noarch el rpm for openvox-server' do
    is_expected.to(
      run.with_params('openvox-server', '8.17.0', 'rocky-8-aarch64')
        .and_return('openvox-server/8.17.0/openvox-server-8.17.0-1.el8.noarch.rpm')
    )
  end

  it 'returns a debian deb for the cpu architecture' do
    is_expected.to(
      run.with_params('openvox-agent', '8.29.0', 'debian-13-arm64')
        .and_return('openvox-agent/8.29.0/openvox-agent_8.29.0-1+debian13_arm64.deb')
    )
  end

  it 'returns an ubuntu deb with a dotted version' do
    is_expected.to(
      run.with_params('openvoxdb', '8.17.0', 'ubuntu-2404-amd64')
        .and_return('openvoxdb/8.17.0/openvoxdb_8.17.0-1+ubuntu24.04_all.deb')
    )
  end

  it 'looks for openvoxdb-termini in the openvoxdb directory' do
    is_expected.to(
      run.with_params('openvoxdb-termini', '8.17.0', 'debian-12-amd64')
        .and_return('openvoxdb/8.17.0/openvoxdb-termini_8.17.0-1+debian12_all.deb')
    )
  end

  it 'leaves out the release number for snapshot builds' do
    is_expected.to(
      run.with_params('openvox-server', '8.18.0-0.1SNAPSHOT.2026.10.28T1149', 'almalinux-9-x86_64')
        .and_return('openvox-server/8.18.0-0.1SNAPSHOT.2026.10.28T1149/openvox-server-8.18.0-0.1SNAPSHOT.2026.10.28T1149.el9.noarch.rpm')
    )
  end

  it 'fails for a platform it has no naming for' do
    is_expected.to(
      run.with_params('openvox-agent', '8.29.0', 'fedora-43-x86_64')
        .and_raise_error(/parameter 'platform' expects a match/)
    )
  end
end
