require 'spec_helper'
require 'tmpdir'

describe 'plan: standup_cluster' do
  include_context 'plan_init'

  let(:tempdir) { Dir.mktmpdir('rspec-kat-standup-cluster') }
  let(:params) do
    {
      'cluster_id' => 'spec',
      'os'           => 'ubuntu',
      'os_version'   => '24.04',
      'os_arch'      => 'x86_64',
      'network_addresses'   => '192.168.100.0/24',
      'terraform_state_dir' => tempdir,
      'image_download_dir'  => '/dev/null',
      'vms' => [
        {
          'role' => 'primary',
          'cpus' => 2,
          'mem_mb' => 2048,
          'disk_gb' => 20,
        },
        {
          'role' => 'agent',
        }
      ],
    }
  end
  let(:cluster_id) { 'spec' }
  let(:apply_result) do
    {
      'vmdomain_details' => {
        'value' => {
          'spec-primary-1' => {
            'ip_addresses' => ['10.2.3.4'],
          },
          'spec-agent-1' => {
            'ip_addresses' => ['10.2.3.5'],
          },
        },
      },
    }
  end

  around(:each) do |example|
    example.run
  ensure
    FileUtils.remove_entry_secure(tempdir)
  end

  before(:each) do
    # Provide a terraform state file for inventory to resolve from.
    FileUtils.cp(File.join(KatRspec.fixture_path, '/terraform/spec.tfstate'), "#{tempdir}/#{cluster_id}.tfstate")
  end

  context 'with bad parameters' do
    it 'raises if os params partially set' do
      params.delete('os_version')
      result = run_plan('kvm_automation_tooling::standup_cluster', params)
      expect(result.ok?).to eq(false)
      expect(result.value.msg).to match(/os_version.*must all be set/)
    end

    it 'raises if os params not set and vms do not all have os params' do
      params.delete('os')
      params.delete('os_version')
      params.delete('os_arch')

      result = run_plan('kvm_automation_tooling::standup_cluster', params)
      expect(result.ok?).to eq(false)
      expect(result.value.msg).to match(/os_version.*must be set if not set in the vm spec hashes/)
    end

    it 'raises if os params unset and only some vms have os params' do
      params.delete('os')
      params.delete('os_version')
      params.delete('os_arch')
      params['vms'] = [
        {
          'role' => 'primary',
        },
        {
          'role' => 'agents',
          'os'   => {
            'name'    => 'ubuntu',
            'version' => '24.04',
            'arch'    => 'x86_64',
          },
        },
      ]

      result = run_plan('kvm_automation_tooling::standup_cluster', params)
      expect(result.ok?).to eq(false)
      expect(result.value.msg).to match(/os_version.*must be set if not set in the vm spec hashes/)
    end
  end

  context 'successfully runs' do
    before(:each) do
      allow_any_out_message

      expect_task('terraform::initialize')
      expect_plan('terraform::apply')
        .with_params(
          'dir'      => './terraform',
          'var_file' => "#{tempdir}/#{cluster_id}.tfvars.json",
          'state'    => "#{tempdir}/#{cluster_id}.tfstate",
        )
      expect_plan('terraform::refresh')
        .with_params(
          'dir'           => './terraform',
          'var_file'      => "#{tempdir}/#{cluster_id}.tfvars.json",
          'state'         => "#{tempdir}/#{cluster_id}.tfstate",
          'return_output' => true,
        )
        .always_return(apply_result)
      expect_task('kvm_automation_tooling::package_init')
        .with_targets(['spec-primary-1', 'spec-agent-1'])
        .with_params({
          'refresh_package_cache' => true,
          'upgrade_packages' => false,
        })
      expect_plan('kvm_automation_tooling::subplans::setup_cluster_ssh')
    end

    context 'for a single platform' do
      before(:each) do
        expect_command("mkdir -p /dev/null")
          .with_targets('localhost')
        expect_task('kvm_automation_tooling::download_image')
        expect_task('kvm_automation_tooling::import_libvirt_volume')
        expect_task('kvm_automation_tooling::create_libvirt_image_pool')
      end

      it 'terraforms and installs openvox' do
        expect_task('openvox_bootstrap::install')
          .with_targets(['spec-primary-1', 'spec-agent-1'])
          .with_params({
            'package'    => 'openvox-agent',
            'version'    => 'latest',
            'collection' => 'openvox8',
            'apt_source' => 'https://apt.voxpupuli.org',
            'yum_source' => 'https://yum.voxpupuli.org',
            'stop_service' => false,
            'force_release_package' => true,
            '_catch_errors' => true,
          })
        expect_plan('facts').be_called_times(2)
        expect_task('openvox_bootstrap::install')
          .with_targets(['spec-primary-1'])
          .with_params({
            'package'    => 'openvox-server',
            'version'    => 'latest',
            'collection' => 'openvox8',
            'apt_source' => 'https://apt.voxpupuli.org',
            'yum_source' => 'https://yum.voxpupuli.org',
            'stop_service' => false,
            'force_release_package' => true,
            '_catch_errors' => true,
          })
        expect_task('openvox_bootstrap::install')
          .with_targets(['spec-primary-1'])
          .with_params({
            'package'    => 'openvoxdb',
            'version'    => 'latest',
            'collection' => 'openvox8',
            'apt_source' => 'https://apt.voxpupuli.org',
            'yum_source' => 'https://yum.voxpupuli.org',
            'stop_service' => false,
            'force_release_package' => true,
            '_catch_errors' => true,
          })
        expect_task('openvox_bootstrap::install')
          .with_targets(['spec-primary-1'])
          .with_params({
            'package'    => 'openvoxdb-termini',
            'version'    => 'latest',
            'collection' => 'openvox8',
            'apt_source' => 'https://apt.voxpupuli.org',
            'yum_source' => 'https://yum.voxpupuli.org',
            'stop_service' => false,
            'force_release_package' => true,
            '_catch_errors' => true,
          })
        expect_task('package')
          .be_called_times(4)
          .always_return({'version' => '1.0.0'})

        result = run_plan('kvm_automation_tooling::standup_cluster', params)
        expect(result.ok?).to(eq(true), result.value.to_s)

        target_map = result.value
        expect(target_map).to match(
          {
            'spec-primary-1' => {
              'ip'                => '192.168.100.224',
              'role'              => 'primary',
              'platform'          => 'ubuntu-2404-amd64',
              'openvox-agent'     => '1.0.0',
              'openvox-server'    => '1.0.0',
              'openvoxdb'         => '1.0.0',
              'openvoxdb-termini' => '1.0.0',
            },
            'spec-agent-1' => {
              'ip'             => '192.168.100.37',
              'role'           => 'agent',
              'platform'       => 'ubuntu-2404-amd64',
              'openvox-agent'  => '1.0.0',
            },
          }
        )
      end

      it 'just terraforms when install_openvox is false' do
        params['install_openvox'] = false
        expect_plan('facts')
        result = run_plan('kvm_automation_tooling::standup_cluster', params)
        expect(result.ok?).to(eq(true), result.value.to_s)
        target_map = result.value
        expect(target_map).to match(
          {
            'spec-primary-1' => {
              'ip'       => '192.168.100.224',
              'platform' => 'ubuntu-2404-amd64',
              'role'     => 'primary',
            },
            'spec-agent-1' => {
              'ip'       => '192.168.100.37',
              'platform' => 'ubuntu-2404-amd64',
              'role'     => 'agent',
            },
          }
        )
      end

      it 'adds host root access when requsted' do
        expect_plan('facts')
        expect_plan('kvm_automation_tooling::install_openvox')

        public_key_path = "#{tempdir}/ssh_rspec.pub"
        File.write(public_key_path, 'rspec-public-key')
        params['ssh_public_key_path'] = public_key_path
        params['host_root_access'] = true
        expect_task('kvm_automation_tooling::add_ssh_authorized_key')
          .with_targets(['spec-primary-1', 'spec-agent-1'])
          .with_params({
            'user' => 'root',
            'ssh_public_key' => 'rspec-public-key',
          })

        result = run_plan('kvm_automation_tooling::standup_cluster', params)
        expect(result.ok?).to(eq(true), result.value.to_s)
      end
    end

    context 'with multiple vm platforms' do
      before(:each) do
        expect_command("mkdir -p /dev/null")
          .with_targets('localhost')
          .be_called_times(2)

        # Expect ubuntu 24.04
        expect_task('kvm_automation_tooling::download_image')
          .with_params(
            'image_url' => 'https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img',
            'download_dir' => '/dev/null',
          )
        expect_task('kvm_automation_tooling::import_libvirt_volume')
          .with_params(
            'image_path' => '/dev/null/noble-server-cloudimg-amd64.img',
            'volume_name' => 'noble-server-cloudimg-amd64.img',
          )
        expect_task('kvm_automation_tooling::create_libvirt_image_pool')
          .with_params(
            'name' => 'ubuntu-2404-amd64.pool',
            'path' => 'ubuntu-2404-amd64',
          )

        # And expect ubuntu 22.04
        expect_task('kvm_automation_tooling::download_image')
          .with_params(
            'image_url' => 'https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img',
            'download_dir' => '/dev/null',
          )
        expect_task('kvm_automation_tooling::import_libvirt_volume')
          .with_params(
            'image_path' => '/dev/null/jammy-server-cloudimg-amd64.img',
            'volume_name' => 'jammy-server-cloudimg-amd64.img',
          )
        expect_task('kvm_automation_tooling::create_libvirt_image_pool')
          .with_params(
            'name' => 'ubuntu-2204-amd64.pool',
            'path' => 'ubuntu-2204-amd64',
          )
        expect_plan('facts')
        expect_plan('kvm_automation_tooling::install_openvox')
      end

      it 'manages all platforms' do
        params['vms'] << {
          'role' => 'agent',
          'os' => {
            'name' => 'ubuntu',
            'version' => '22.04',
            'arch' => 'x86_64',
          },
        }
        result = run_plan('kvm_automation_tooling::standup_cluster', params)
        expect(result.ok?).to(eq(true), result.value.to_s)
      end
    end
  end

  context 'with network problems' do
    before(:each) do
      allow_any_out_message

      expect_task('terraform::initialize')
      expect_plan('terraform::apply')
        .with_params(
          'dir'      => './terraform',
          'var_file' => "#{tempdir}/#{cluster_id}.tfvars.json",
          'state'    => "#{tempdir}/#{cluster_id}.tfstate",
        )
      expect_command("mkdir -p /dev/null")
        .with_targets('localhost')
      expect_task('kvm_automation_tooling::download_image')
      expect_task('kvm_automation_tooling::import_libvirt_volume')
      expect_task('kvm_automation_tooling::create_libvirt_image_pool')
      expect_plan('facts')
    end

    context 'when domains do not refresh with ip addresses' do
      it 'raises an error and gets debug state' do
        params['wait_for_ip_timeout'] = 0

        expect_plan('terraform::refresh')
          .with_params(
            'dir'           => './terraform',
            'var_file'      => "#{tempdir}/#{cluster_id}.tfvars.json",
            'state'         => "#{tempdir}/#{cluster_id}.tfstate",
            'return_output' => true,
          )
          .always_return({
            'vmdomain_details' => {
              'value' => {
                'spec-primary-1' => {
                  'ip_addresses' => [],
                },
                'spec-agent-1' => {
                  'ip_addresses' => [],
                },
              },
            },
          })
        expect_plan('terraform::refresh')
          .with_params(
            'dir'           => './terraform',
            'var_file'      => "#{tempdir}/#{cluster_id}.tfvars.json",
            'state'         => "#{tempdir}/#{cluster_id}.tfstate",
          )
          .return { Bolt::PlanResult.new(['stdout' => 'terraform-result'], 'success') }
        expect_plan('kvm_automation_tooling::subplans::debug_libvirt_state')
          .with_params(
            'cluster_id' => cluster_id,
            'vm_hostnames' => ['spec-primary-1', 'spec-agent-1'],
          )

        result = run_plan('kvm_automation_tooling::standup_cluster', params)
        expect(result.ok?).to eq(false)
        expect(result.value.msg).to match(/Timed out waiting for VMs/)
      end
    end

    context 'when unable to connect to domains' do
      it 'raises an error and gets debug state' do
        expect_plan('terraform::refresh')
          .with_params(
            'dir'           => './terraform',
            'var_file'      => "#{tempdir}/#{cluster_id}.tfvars.json",
            'state'         => "#{tempdir}/#{cluster_id}.tfstate",
            'return_output' => true,
          )
          .always_return(apply_result)
        expect(executor).to receive(:wait_until_available)
          .and_return(Bolt::ResultSet.new([
            Bolt::Result.new('spec-primary-1', error: { 'msg' => 'unreachable'}),
            Bolt::Result.new('spec-agent-1', message: 'reachable'),
          ]))
        expect_plan('kvm_automation_tooling::subplans::debug_libvirt_state')
          .with_params(
            'cluster_id' => cluster_id,
            'vm_hostnames' => ['spec-primary-1', 'spec-agent-1'],
          )

        result = run_plan('kvm_automation_tooling::standup_cluster', params)
        expect(result.ok?).to eq(false)
        expect(result.value.msg).to eq(<<~EOS)
          wait_until_available failed for targets: [
            "spec-primary-1"
          ]
        EOS
      end
    end
  end
end
