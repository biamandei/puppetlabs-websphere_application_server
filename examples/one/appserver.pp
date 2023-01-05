#
# A profile for a WebSphere application server.
#
# Really, you can't get away with just making a one and only "app server"
# profile unless all of your application servers are made up almost
# exactly the same way.  You might break up your profiles for specific
# deployed "stacks" of a WebSphere cell.
#
class profile::websphere_application_server::appserver { # lint:ignore:autoloader_layout
  $base_dir         = '/opt/IBM'
  $instance_name    = 'WebSphere85'
  $instance_base    = "${base_dir}/${instance_name}/AppServer"
  $profile_base     = "${instance_base}/profiles"

  $was_installer    = '/vagrant/ibm/was'
  $package_name     = 'com.ibm.websphere.NDTRIAL.v85'
  $package_version  = '8.5.5000.20130514_1044'
  $user             = 'webadmins'
  $group            = 'webadmins'

  $dmgr_host        = 'dmgr.vagrant.vm'
  $dmgr_profile     = 'PROFILE_DMGR_01'
  $dmgr_cell        = 'CELL_01'
  $dmgr_node        = 'NODE_DMGR_01'

  $java7_installer  = '/vagrant/ibm/java7'
  $java7_package    = 'com.ibm.websphere.IBMJAVA.v71'
  $java7_version    = '7.1.2000.20141116_0823'

  ## Manage an instance of WebSphere 8.5
  websphere_application_server::instance { 'WebSphere85':
    target       => $instance_base,
    package      => $package_name,
    version      => $package_version,
    profile_base => $profile_base,
    repository   => "${was_installer}/repository.config",
    user         => $user,
    group        => $group,
  }

  ibm_pkg { 'WebSphere_8554_fixpack':
    ensure     => 'present',
    package    => $package_name,
    version    => '8.5.5004.20141119_1746',
    repository => '/vagrant/ibm/FP04/repository.config',
    target     => $instance_base,
    user       => $user,
    group      => $group,
    require    => Websphere_application_server::Instance['WebSphere85'],
    notify     => Websphere_application_server::Profile::Appserver['PROFILE_APP_001'],
  }

  ibm_pkg { 'Websphere85_Java7':
    ensure     => 'present',
    package    => $java7_package,
    version    => $java7_version,
    repository => "${java7_installer}/repository.config",
    target     => $instance_base,
    user       => $user,
    group      => $group,
    require    => Ibm_pkg['WebSphere_8554_fixpack'],
    notify     => Websphere_application_server::Profile::Appserver['PROFILE_APP_001'],
  }

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
  }

  ## Export myself as a cluster member
  @@websphere_application_server::cluster::member { 'AppServer01':
    ensure                           => 'present',
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

  websphere_variable { 'CELL_01:node:appNode01':
    ensure       => 'present',
    variable     => 'LOG_ROOT',
    value        => '/opt/log/websphere/wasmgmtlogs/appNode01',
    scope        => 'node',
    node_name    => 'appNode01',
    cell         => 'CELL_01',
    dmgr_profile => 'PROFILE_APP_001',
    profile_base => $profile_base,
    user         => $user,
    require      => [
      File['/opt/log/websphere/wasmgmtlogs/appNode01'],
      Websphere_application_server::Profile::Appserver['PROFILE_APP_001'],
    ],
  }

  ## Manage logging for the SERVER
  ## NOTE: This will cause a FAILURE during the first Puppet run because the
  ## cluster member has not yet been created on the DMGR.
  ## TODO: Look into ways to handle this better
  ## Options:
  ##   - Declare it statically on the DMGR and set a relationship to require
  ##     the 'websphere_cluster_member'
  ##   - Export it and collect it on the DMGR, also making a relationship
  ##   - Just deal with the resource failure on the first run.
  websphere_variable { 'CELL_01:server:appNode01:AppServer01':
    ensure       => 'present',
    variable     => 'LOG_ROOT',
    value        => '/opt/log/websphere/appserverlogs',
    scope        => 'server',
    server       => 'AppServer01',
    node_name    => 'appNode01',
    cell         => 'CELL_01',
    dmgr_profile => 'PROFILE_APP_001',
    profile_base => $profile_base,
    user         => $user,
    require      => [
      File['/opt/log/websphere/wasmgmtlogs/appNode01'],
      Websphere_application_server::Profile::Appserver['PROFILE_APP_001'],
    ],
  }
  websphere_jvm_log { 'CELL_01:appNode01:node:AppServer01':
    profile             => 'PROFILE_APP_001',
    profile_base        => $profile_base,
    cell                => 'CELL_01',
    scope               => 'node',
    node_name           => 'appNode01',
    server              => 'AppServer01',
    out_filename        => '/tmp/SystemOut.log',
    out_rollover_type   => 'BOTH',
    out_rollover_size   => '7',
    out_maxnum          => '200',
    out_start_hour      => '13',
    out_rollover_period => '24',
    err_filename        => '/tmp/SystemErr.log',
    err_rollover_type   => 'BOTH',
    err_rollover_size   => '7',
    err_maxnum          => '3',
    err_start_hour      => '13',
    err_rollover_period => '24',
    require             => Websphere_application_server::Profile::Appserver['PROFILE_APP_001'],
  }

  websphere_jvm_log { 'CELL_01:appNode01:server:AppServer01':
    profile             => 'PROFILE_APP_001',
    profile_base        => $profile_base,
    cell                => 'CELL_01',
    scope               => 'server',
    node_name           => 'appNode01',
    server              => 'AppServer01',
    out_filename        => '/tmp/fooSystemOut.log',
    out_rollover_type   => 'BOTH',
    out_rollover_size   => '7',
    out_maxnum          => '200',
    out_start_hour      => '13',
    out_rollover_period => '24',
    err_filename        => '/tmp/fooSystemErr.log',
    err_rollover_type   => 'BOTH',
    err_rollover_size   => '7',
    err_maxnum          => '3',
    err_start_hour      => '13',
    err_rollover_period => '24',
    require             => Websphere_application_server::Profile::Appserver['PROFILE_APP_001'],
  }
}
