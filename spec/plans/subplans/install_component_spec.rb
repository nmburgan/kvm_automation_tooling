require 'spec_helper'

describe 'plan: kvm_automation_tooling::subplans::install_component' do
  include_context 'plan_init'

  let(:install_params) { {} }
  let(:defaults) do
    {
      'openvox_released'   => true,
      'openvox_version'    => 'latest',
      'openvox_collection' => 'openvox8',
    }
  end
  let(:plan_params) do
    {
      'targets'  => 'spec',
      'package'  => 'openvox-agent',
      'params'   => install_params,
      'defaults' => defaults,
    }
  end

  it 'runs the install task if released' do
    install_params['openvox_version'] = '8.0.0'

    expect_out_message
    expect_task('openvox_bootstrap::install')
      .with_targets('spec')
      .with_params(
        {
          'package' => 'openvox-agent',
          'version' => '8.0.0',
          'collection' => 'openvox8',
          'apt_source' => 'https://apt.voxpupuli.org',
          'yum_source' => 'https://yum.voxpupuli.org',
          'stop_service' => false,
          'force_release_package' => true,
          '_catch_errors' => true,
        }
      )
    expect_task('package')
      .with_targets('spec')
      .with_params('name' => 'openvox-agent', 'action' => 'status')
      .always_return({'version' => '8.0.0'})

    $results = run_plan(
      'kvm_automation_tooling::subplans::install_component',
      plan_params
    )

    expect($results.ok?).to(eq(true), $results.value.to_s)
    expect($results.value.map(&:value)).to eq(
      [{'version' => '8.0.0'}]
    )
  end

  context 'not released' do
    before do
      install_params['openvox_released'] = false
    end

    it 'runs the install_build_artifact task if not released' do
      install_params['openvox_version'] = '8.1.1'

      expect_out_message
      expect_task('openvox_bootstrap::install_build_artifact')
        .with_targets('spec')
        .with_params(
          {
            'package' => 'openvox-agent',
            'version' => '8.1.1',
            'artifacts_source' => 'https://artifacts.voxpupuli.org',
            '_catch_errors' => true,
          }
        )
      expect_task('package')
        .with_targets('spec')
        .with_params('name' => 'openvox-agent', 'action' => 'status')
        .always_return({'version' => '8.1.1'})

      $results = run_plan(
        'kvm_automation_tooling::subplans::install_component',
        plan_params
      )

      expect($results.ok?).to(eq(true), $results.value.to_s)
      expect($results.value.map(&:value)).to eq(
        [{'version' => '8.1.1'}]
      )
    end

    it 'overrides artifacts url if given' do
      install_params['openvox_version'] = '8.1.1'
      install_params['openvox_artifacts_url'] = 'https://custom.artifacts.source'

      expect_out_message
      expect_task('openvox_bootstrap::install_build_artifact')
        .with_targets('spec')
        .with_params(
          {
            'package' => 'openvox-agent',
            'version' => '8.1.1',
            'artifacts_source' => 'https://custom.artifacts.source',
            '_catch_errors' => true,
          }
        )
      expect_task('package')

      $results = run_plan(
        'kvm_automation_tooling::subplans::install_component',
        plan_params
      )

      expect($results.ok?).to(eq(true), $results.value.to_s)
    end

    context 'with a directory on the controller' do
      let(:artifacts_dir) { Dir.mktmpdir }
      let(:rpm) { 'openvox-agent-8.1.1-1.el9.x86_64.rpm' }
      let(:deb) { 'openvox-agent_8.1.1-1+debian13_amd64.deb' }

      def inventory_data
        {
          'targets' => [
            { 'name' => 'agent', 'vars' => { 'platform' => 'almalinux-9-x86_64' } },
            { 'name' => 'primary', 'vars' => { 'platform' => 'debian-13-amd64' } },
          ],
        }
      end

      around(:each) do |example|
        # upload_file checks that its source exists.
        FileUtils.mkdir_p("#{artifacts_dir}/openvox-agent/8.1.1")
        FileUtils.touch(["#{artifacts_dir}/openvox-agent/8.1.1/#{rpm}", "#{artifacts_dir}/openvox-agent/8.1.1/#{deb}"])
        example.run
      ensure
        FileUtils.remove_entry_secure(artifacts_dir)
      end

      it 'uploads each target its own package and installs that file' do
        install_params['openvox_version'] = '8.1.1'
        install_params['openvox_artifacts_dir'] = artifacts_dir
        plan_params['targets'] = ['agent', 'primary']

        expect_out_message
        { 'agent' => rpm, 'primary' => deb }.each do |target, file|
          expect_upload("#{artifacts_dir}/openvox-agent/8.1.1/#{file}")
            .with_destination("/tmp/#{file}")
            .with_targets(target)
          expect_task('openvox_bootstrap::install_build_artifact')
            .with_targets(target)
            .with_params(
              {
                'package' => 'openvox-agent',
                'version' => '8.1.1',
                'artifacts_source' => 'https://artifacts.voxpupuli.org',
                'local_package_file' => "/tmp/#{file}",
                '_catch_errors' => true,
              }
            )
        end
        expect_task('package')

        $results = run_plan(
          'kvm_automation_tooling::subplans::install_component',
          plan_params
        )

        expect($results.ok?).to(eq(true), $results.value.to_s)
      end
    end
  end

  it 'fails for invalid install parameters' do
    install_params['openvox_released'] = false
    install_params['openvox_version'] = 'latest'

    $results =  run_plan('kvm_automation_tooling::subplans::install_component', plan_params)

    expect($results.ok?).to(eq(false))
    expect($results.value.to_s).to match(/must supply an explicit version/)
  end
end
