# Manage a DMGR
#
# Install a WebSphere instance of 8.5, a fixpack, and Java 7.
#
# Create a profile for the DMGR and a cluster.
#
class websphere_profile::dmgr { # lint:ignore:autoloader_layout
  $base_dir         = '/opt/IBM'
  $instance_name    = 'WebSphere85'
  $instance_base    = "${base_dir}/${instance_name}/AppServer"
  $profile_base     = "${instance_base}/profiles"
  $was_installer    = '/opt/QA_resources/ibm_websphere/ndtrial'

  $package_name     = 'com.ibm.websphere.NDTRIAL.v85'
  $package_version  = '8.5.5000.20130514_1044'

  $user             = 'webadmin'
  $group            = 'webadmins'
  $dmgr_profile     = 'PROFILE_DMGR_02'
  $dmgr_cell        = 'CELL_01'
  $dmgr_node        = 'dmgrNode01'

  $java7_installer  = '/opt/QA_resources/ibm_websphere/ibm_was_java'
  $java7_package    = 'com.ibm.websphere.IBMJAVA.v71'
  $java7_version    = '7.1.2000.20141116_0823'

  ## Create a DMGR Profile
  websphere_application_server::profile::dmgr { $dmgr_profile:
    instance_base => $instance_base,
    profile_base  => $profile_base,
    cell          => $dmgr_cell,
    node_name     => $dmgr_node,
    user          => $user,
    group         => $group,
  }

  ## Create a cluster
  websphere_application_server::cluster { 'PuppetCluster01':
    profile_base => $profile_base,
    dmgr_profile => $dmgr_profile,
    cell         => $dmgr_cell,
    user         => $user,
    require      => Websphere_application_server::Profile::Dmgr[$dmgr_profile],
  }
}
