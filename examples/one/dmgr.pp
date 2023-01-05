# Manage a DMGR
#
# Install a WebSphere instance of 8.5, a fixpack, and Java 7.
#
# Create a profile for the DMGR and a cluster.
#
class profile::websphere::dmgr { # lint:ignore:autoloader_layout
  $base_dir         = '/opt/IBM'
  $instance_name    = 'WebSphere85'
  $instance_base    = "${base_dir}/${instance_name}/AppServer"
  $profile_base     = "${instance_base}/profiles"
  $was_installer    = '/vagrant/ibm/was'

  $package_name     = 'com.ibm.websphere.NDTRIAL.v85'
  $package_version  = '8.5.5000.20130514_1044'

  $user             = 'webadmin'
  $group            = 'webadmins'
  $dmgr_profile     = 'PROFILE_DMGR_01'
  $dmgr_cell        = 'CELL_01'
  $dmgr_node        = 'NODE_DMGR_01'

  $java7_installer  = '/vagrant/ibm/java7'
  $java7_package    = 'com.ibm.websphere.IBMJAVA.v71'
  $java7_version    = '7.1.2000.20141116_0823'

  ## Manage an instance of WebSphere 8.5
  websphere::instance { 'WebSphere85':
    target       => $instance_base,
    package      => $package_name,
    version      => $package_version,
    profile_base => $profile_base,
    repository   => "${was_installer}/repository.config",
    user         => $user,
    group        => $group,
  }

  ## Install the 8.5.5.4 FixPack
  ibm_pkg { 'Websphere_8554_fixpack':
    ensure     => 'present',
    package    => $package_name,
    version    => '8.5.5004.20141119_1746',
    repository => '/vagrant/ibm/FP04/repository.config',
    target     => $instance_base,
    user       => $user,
    group      => $group,
    require    => Websphere::Instance['WebSphere85'],
  }

  ## Install Java7
  ibm_pkg { 'Websphere85_Java7':
    ensure     => 'present',
    package    => $java7_package,
    version    => $java7_version,
    repository => "${java7_installer}/repository.config",
    target     => $instance_base,
    user       => $user,
    group      => $group,
    require    => Websphere::Package['Websphere_8554_fixpack'],
  }

  ## Create a DMGR Profile
  websphere::profile::dmgr { $dmgr_profile:
    instance_base => $instance_base,
    profile_base  => $profile_base,
    cell          => $dmgr_cell,
    node_name     => $dmgr_node,
    user          => $user,
    group         => $group,
    subscribe     => [
      Websphere::Package['Websphere_8554_fixpack'],
      Websphere::Package['Websphere85_Java7'],
    ],
  }

  ## Create a cluster
  websphere::cluster { 'PuppetCluster01':
    profile_base => $profile_base,
    dmgr_profile => $dmgr_profile,
    cell         => $dmgr_cell,
    user         => $user,
    require      => Websphere::Profile::Dmgr[$dmgr_profile],
  }
}
