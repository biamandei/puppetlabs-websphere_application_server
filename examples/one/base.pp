#
# The "base" websphere profile.  The basic, common stuff for all WebSphere
# related nodes should go here.
#
class profile::websphere::base { # lint:ignore:autoloader_layout

  # Declare the IBM Installation Manager class. Make sure IM is installed.
  # We want to install it to /opt/IBM/InstallationManager
  # We have it downloaded and extracted under /vagrant/ibm/IM
  class { 'ibm_installation_manager':
    source_dir => '/vagrant/ibm/IM',
    target     => '/opt/IBM/InstallationManager',
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
  class { 'websphere':
    user     => 'webadmin',
    group    => 'webadmins',
    base_dir => '/opt/IBM',
    require  => Class['ibm_installation_manager'],
  }
}
