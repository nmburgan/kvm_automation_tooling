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
  end

  it 'fails for invalid install parameters' do
    install_params['openvox_released'] = false
    install_params['openvox_version'] = 'latest'

    $results =  run_plan('kvm_automation_tooling::subplans::install_component', plan_params)

    expect($results.ok?).to(eq(false))
    expect($results.value.to_s).to match(/must supply an explicit version/)
  end
end
