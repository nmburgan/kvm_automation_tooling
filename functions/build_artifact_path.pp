# @summary Returns the path of an openvox build artifact package for a platform.
#
# The path is relative to a directory laid out like the build artifacts
# server, as `<package directory>/<version>/<package file>`. The names
# follow set_artifacts_package_url() in openvox_bootstrap's
# files/common.sh.
#
# @param package The name of the package.
# @param version The version of the package.
# @param platform The platform string of the target, as returned by
#   kvm_automation_tooling::platform().
# @return The path of the package file within the artifacts directory.
# @example An agent package for Ubuntu 24.04
#   kvm_automation_tooling::build_artifact_path('openvox-agent', '8.29.0', 'ubuntu-2404-amd64')
#   # => 'openvox-agent/8.29.0/openvox-agent_8.29.0-1+ubuntu24.04_amd64.deb'
# @example A server package for Rocky 9
#   kvm_automation_tooling::build_artifact_path('openvox-server', '8.17.0', 'rocky-9-x86_64')
#   # => 'openvox-server/8.17.0/openvox-server-8.17.0-1.el9.noarch.rpm'
function kvm_automation_tooling::build_artifact_path(
  String[1] $package,
  String[1] $version,
  Pattern[/\A(almalinux|rocky|debian|ubuntu)-[0-9]+-(x86_64|amd64|aarch64|arm64)\z/] $platform,
) {
  [$os, $os_version, $arch] = $platform.split('-')
  $noarch = $package in ['openvox-server', 'openvoxdb', 'openvoxdb-termini']
  # Snapshot builds of ezbake projects have no release number.
  $release = ($version =~ /SNAPSHOT/) ? {
    true    => '',
    default => '-1',
  }
  $directory = $package ? {
    'openvoxdb-termini' => 'openvoxdb',
    default             => $package,
  }
  $deb_arch = $noarch ? {
    true    => 'all',
    default => $arch,
  }
  $rpm_arch = $noarch ? {
    true    => 'noarch',
    default => $arch,
  }
  $file = $os ? {
    'debian' => "${package}_${version}${release}+debian${os_version}_${deb_arch}.deb",
    'ubuntu' => "${package}_${version}${release}+ubuntu${os_version[0, 2]}.${os_version[2, 2]}_${deb_arch}.deb",
    default  => "${package}-${version}${release}.el${os_version}.${rpm_arch}.rpm",
  }

  "${directory}/${version}/${file}"
}
