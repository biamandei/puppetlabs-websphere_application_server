# IHS
class websphere_profile::ihs { # lint:ignore:autoloader_layout
  ## Simply install the 'base' websphere
  $ibm_base_dir     = '/opt/IBM'
  $instance_name    = 'HTTPServer85'
  $instance_base    = "${ibm_base_dir}/${instance_name}"

  $ihs_installer    = '/opt/QA_resources/ibm_websphere/ihs_ilan'
  $package_name     = 'com.ibm.websphere.IHSILAN.v85'
  $package_version  = '8.5.5000.20130514_1044'

  $user             = 'webadmin'
  $group            = 'webadmins'

  $dmgr_profile     = 'PROFILE_DMGR_01'
  $dmgr_cell        = 'CELL_01'
  $dmgr_node        = 'NODE_DMGR_01'
  $dmgr_host        = 'dmgr-centos'

  $java7_installer  = '/opt/QA_resources/ibm_websphere/ibm_was_java'
  $java7_package    = 'com.ibm.websphere.IBMJAVA.v71'
  $java7_version    = '7.1.2000.20141116_0823'


  ## WAS IHS instance
  websphere_application_server::ihs::instance { 'HTTPServer85':
    target          => $instance_base,
    package         => $package_name,
    version         => $package_version,
    repository      => "${ihs_installer}/repository.config",
    install_options => '-properties user.ihs.httpPort=80',
    user            => $user,
    group           => $group,
    manage_user     => false,
    manage_group    => false,
    log_dir         => '/opt/log/websphere/httpserver',
    admin_username  => 'httpadmin',
    admin_password  => 'password',
    webroot         => '/opt/web',
  }

  ibm_pkg { 'Plugins':
    ensure     => 'present',
    target     => "${ibm_base_dir}/Plugins85",
    repository => '/opt/QA_resources/ibm_websphere/plg_ilan/repository.config',
    package    => 'com.ibm.websphere.PLGILAN.v85',
    version    => '8.5.5000.20130514_1044',
    require    => Websphere_application_server::Ihs::Instance['HTTPServer85'],
  }

  websphere_application_server::ihs::server { 'test':
    target       => "${ibm_base_dir}/HTTPServer85",
    log_dir      => '/opt/log/websphere/httpserver',
    plugin_base  => "${ibm_base_dir}/Plugins85",
    cell         => $dmgr_cell,
    node_name    => $dmgr_node,
    dmgr_host    => $dmgr_host,
    httpd_config => '/opt/IBM/HTTPServer85/conf/httpd_test.conf',
    access_log   => '/opt/log/websphere/httpserver/access_log',
    error_log    => '/opt/log/websphere/httpserver/error_log',
    listen_port  => '10080',
    require      => Ibm_pkg['Plugins'],
  }

}
