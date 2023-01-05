#
# A profile for a WebSphere application server.
#
# Really, you can't get away with just making a one and only "app server"
# profile unless all of your application servers are made up almost
# exactly the same way.  You might break up your profiles for specific
# deployed "stacks" of a WebSphere cell.
#
class websphere_profile::appserver { # lint:ignore:autoloader_layout
  $base_dir         = '/opt/IBM'
  $instance_name    = 'WebSphere85'
  $instance_base    = "${base_dir}/${instance_name}/AppServer"
  $profile_base     = "${instance_base}/profiles"

  $was_installer    = '/opt/QA_resources/ibm_websphere/ndtrial'
  $package_name     = 'com.ibm.websphere.NDTRIAL.v85'
  $package_version  = '8.5.5000.20130514_1044'
  $user             = 'webadmin'
  $group            = 'webadmins'

  $dmgr_host        = '<DMGR_HOSTNAME>' # This is usually the FQDN of the DMGR agent
  $dmgr_profile     = 'PROFILE_DMGR_01'
  $dmgr_cell        = 'CELL_01'
  $dmgr_node        = 'NODE_DMGR_01'

  $java7_installer  = '/opt/QA_resources/ibm_websphere/ibm_was_java'
  $java7_package    = 'com.ibm.websphere.IBMJAVA.v71'
  $java7_version    = '7.1.2000.20141116_0823'

  ## Manage an App profile
  websphere_application_server::profile::appserver { 'PROFILE_APP_001':
    instance_base  => $instance_base,
    profile_base   => $profile_base,
    template_path  => "${instance_base}/profileTemplates/managed",
    dmgr_host      => $dmgr_host,
    cell           => $dmgr_cell,
    node_name      => 'appNode01',
    manage_sdk     => true,
    sdk_name       => '1.7.1_64',
    manage_service => true,
    user           => $user,
    dmgr_port      => '8879',
  }

  ## Export myself as a cluster member
  @@websphere_application_server::cluster::member { 'AppServer01':
    ensure                           => 'present',
    dmgr_profile                     => $dmgr_profile,
    profile_base                     => $profile_base,
    cluster                          => 'PuppetCluster01',
    node_name                        => 'appNode01',
    cell                             => $dmgr_cell,
    jvm_maximum_heap_size            => '512',
    jvm_verbose_mode_class           => true,
    jvm_verbose_garbage_collection   => false,
    jvm_executable_jar_filename      => '',
    total_transaction_timeout        => '120',
    client_inactivity_timeout        => '20',
    threadpool_webcontainer_max_size => '75',
    runas_user                       => $user,
    runas_group                      => $group,
  }

  ## Manage logging for the NODE
  $log_dirs = [
    '/opt/log/websphere/wasmgmtlogs/appNode01',
    '/opt/log/websphere/wasmgmtlogs/appNode01/nodeagent',
  ]

  file { $log_dirs:
    ensure => 'directory',
    owner  => $user,
    group  => $group,
  }

  websphere_jvm_log { "${dmgr_cell}:appNode01:node:AppServer01":
    profile             => 'PROFILE_APP_001',
    profile_base        => $profile_base,
    cell                => $dmgr_cell,
    scope               => 'node',
    node_name           => 'appNode01',
    server              => 'AppServer01',
    out_filename        => '/tmp/SystemOut.log',
    out_rollover_type   => 'both',
    out_rollover_size   => '7',
    out_maxnum          => '200',
    out_start_hour      => '13',
    out_rollover_period => '24',
    err_filename        => '/tmp/SystemErr.log',
    err_rollover_type   => 'both',
    err_rollover_size   => '7',
    err_maxnum          => '3',
    err_start_hour      => '13',
    err_rollover_period => '24',
    require             => Websphere_application_server::Profile::Appserver['PROFILE_APP_001'],
  }
}
