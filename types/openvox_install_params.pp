# Parameters defining OpenVox agent version for the
# kvm_automation_tooling::subplans::install_openvox
# subplan.
#
# Keys:
# - openvox_version: The version of OpenVox to install. If installing
#   a released version, major version must match openvox_collection,
#   or 'latest' to install latest version from collection.
# - openvox_collection: The collection of OpenVox to install from.
#   ('openvox7', 'openvox8', etc.).
# - openvox_released: Whether to install released packages from
#   the given openvox_collection via the system package manager,
#   or to download and install a pre-release openvox_version package
#   from the openvox_artifacts_url for dev testing.
# - openvox_artifacts_url: The URL to the OpenVox artifacts server.
# - openvox_artifacts_dir: A directory on the controller laid out like
#   the OpenVox artifacts server. When set, a pre-release package found
#   there is uploaded to the targets instead of downloaded from the
#   openvox_artifacts_url. A package that isn't there is still downloaded.
type Kvm_automation_tooling::Openvox_install_params = Struct[{
  Optional[openvox_version]       => Kvm_automation_tooling::Openvox_version,
  Optional[openvox_collection]    => Kvm_automation_tooling::Openvox_collection,
  Optional[openvox_released]      => Boolean,
  Optional[openvox_artifacts_url] => Optional[Stdlib::HTTPUrl],
  Optional[openvox_artifacts_dir] => Optional[Stdlib::Absolutepath],
}]
