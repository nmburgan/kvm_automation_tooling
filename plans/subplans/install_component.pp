# Installs a single openvox component on behalf of the caller.
#
# Uses puppet-openvox_bootstrap tasks.
#
# @param targets The targets to install the component on.
# @param package The name of the package to install.
# @param params The parameters for the openvox installation.
# @param defaults The default parameters for the openvox installation.
plan kvm_automation_tooling::subplans::install_component(
  TargetSpec $targets,
  String $package,
  Kvm_automation_tooling::Openvox_install_params $params,
  Kvm_automation_tooling::Openvox_install_params $defaults,
) {
  $install_params = kvm_automation_tooling::validate_openvox_version_parameters(
    $defaults + $params,
  )

  $released = $install_params['openvox_released']
  $version = $install_params['openvox_version']
  $collection = $install_params['openvox_collection']
  $artifacts_dir = $install_params['openvox_artifacts_dir']
  $artifacts_url = $install_params['openvox_artifacts_url']
  $download_params = $artifacts_url =~ NotUndef ? {
    true    => {
      'artifacts_source' => $artifacts_url,
    },
    default => {},
  }

  out::message("Installing ${package} ${version} (${collection})")

  if $released {
    # Loop in case of package manager locks from another process.
    $installed = ctrl::do_until(limit => 5, interval => 10) || {
      $install_results = run_task(
        'openvox_bootstrap::install',
        $targets,
        'package'      => $package,
        'version'      => $version,
        'collection'   => $collection,
        '_catch_errors' => true,
      )
      kvm_automation_tooling::test_results("Error installing ${package}", $install_results)
    }
  } elsif $artifacts_dir =~ NotUndef {
    # Targets can't read a directory on the controller, so a package found
    # there is uploaded to its target and installed from that file. A target
    # whose package isn't there downloads it from the artifacts server.
    $package_files = get_targets($targets).reduce({}) |$files, $target| {
      $path = kvm_automation_tooling::build_artifact_path($package, $version, $target.vars['platform'])
      if file::exists("${artifacts_dir}/${path}") {
        $package_file = "/tmp/${path.split('/')[-1]}"
        log::debug("Uploading ${artifacts_dir}/${path} to ${package_file} on ${target.name}")
        upload_file("${artifacts_dir}/${path}", $package_file, $target)
        $files + { $target.name => $package_file }
      } else {
        log::debug("Downloading ${package} on ${target.name}, since ${artifacts_dir}/${path} doesn't exist")
        $files
      }
    }
    # Loop in case of package manager locks from another process.
    $installed = ctrl::do_until(limit => 5, interval => 10) || {
      $install_results = run_task_with(
        'openvox_bootstrap::install_build_artifact',
        $targets,
        '_catch_errors' => true,
      ) |$target| {
        $local_file_params = $package_files[$target.name] =~ NotUndef ? {
          true    => {
            'local_package_file' => $package_files[$target.name],
          },
          default => {},
        }
        $download_params + $local_file_params + {
          'package' => $package,
          'version' => $version,
        }
      }
      kvm_automation_tooling::test_results("Error installing ${package}", $install_results)
    }
  } else {
    $install_build_params = $download_params + {
      'package'      => $package,
      'version'      => $version,
      '_catch_errors' => true,
    }
    # Loop in case of package manager locks from another process.
    $installed = ctrl::do_until(limit => 5, interval => 10) || {
      $install_results = run_task(
        'openvox_bootstrap::install_build_artifact',
        $targets,
        $install_build_params,
      )
      kvm_automation_tooling::test_results("Error installing ${package}", $install_results)
    }
  }

  if !$installed {
    fail("Failed to install ${package} on some targets (see above).")
  }

  $version_results = run_task('package', $targets, {
    'name'    => $package,
    'action'  => 'status',
  })

  return $version_results
}
