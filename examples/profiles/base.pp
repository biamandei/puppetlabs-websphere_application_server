#
# The "base" websphere profile.  The basic, common stuff for all WebSphere
# related nodes should go here.
#
class websphere_profile::base { # lint:ignore:autoloader_layout
  $base_dir         = '/opt/IBM'
  $instance_name    = 'WebSphere85'
  $instance_base    = "${base_dir}/${instance_name}/AppServer"
  $profile_base     = "${instance_base}/profiles"

  $was_installer    = '/opt/QA_resources/ibm_websphere/ndtrial'
  $package_name     = 'com.ibm.websphere.NDTRIAL.v85'
  $package_version  = '8.5.5000.20130514_1044'
  $user             = 'webadmin'
  $group            = 'webadmins'

  $java7_installer  = '/opt/QA_resources/ibm_websphere/ibm_was_java'
  $java7_package    = 'com.ibm.websphere.IBMJAVA.v71'
  $java7_version    = '7.1.2000.20141116_0823'

  # Declare the IBM Installation Manager class. Make sure IM is installed.
  # We want to install it to /opt/IBM/InstallationManager
  # We have it downloaded and extracted under /opt/QA_resources/ibm/IM
  class { 'ibm_installation_manager':
    deploy_source => true,
    source        => '/opt/QA_resources/ibm_installation_manager/1.8.3/agent.installer.linux.gtk.x86_64_1.8.3000.20150606_0047.zip',
    target        => '/opt/IBM/InstallationManager',
  }

  # Organizational log locations
  file { [
      '/opt/log',
      '/opt/log/websphere',
      '/opt/log/websphere/appserverlogs',
      '/opt/log/websphere/applogs',
      '/opt/log/websphere/wasmgmtlogs',
    ]:
      ensure => 'directory',
      owner  => 'webadmin',
      group  => 'webadmins',
  }

  # Base stuff for WebSphere.  Specify a common user/group and the base
  # directory to where we want things to live.  Make sure the
  # InstallationManager is managed before we do this.
  class { 'websphere_application_server':
    user     => 'webadmin',
    group    => 'webadmins',
    base_dir => '/opt/IBM',
  }

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
    ensure        => 'present',
    package       => $package_name,
    version       => '8.5.5004.20141119_1746',
    repository    => '/opt/QA_resources/ibm_websphere/FP/repository.config',
    target        => $instance_base,
    package_owner => $user,
    package_group => $group,
    require       => Websphere_application_server::Instance['WebSphere85'],
  }

  ibm_pkg { 'Websphere85_Java7':
    ensure        => 'present',
    package       => $java7_package,
    version       => $java7_version,
    repository    => "${java7_installer}/repository.config",
    target        => $instance_base,
    package_owner => $user,
    package_group => $group,
    require       => Ibm_pkg['WebSphere_8554_fixpack'],
  }
}
