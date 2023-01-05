# @summary
#   Define to manage the installation of IBM HTTPServer (IHS) instances
#
# @example Install an instance of IBM HTTP Server
#   websphere_application_server::ihs::instance { 'HTTPServer':
#     target           => '/opt/IBM/HTTPServer',
#     package          => 'com.ibm.websphere.IHSILAN.v85',
#     version          => '8.5.5000.20130514_1044',
#     repository       => '/mnt/myorg/ihs/repository.config',
#     install_options  => '-properties user.ihs.httpPort=80',
#     user             => 'webadmin',
#     group            => 'webadmins',
#     manage_user      => false,
#     manage_group     => false,
#     log_dir          => '/opt/log/websphere/httpserver',
#     admin_username   => 'httpadmin',
#     admin_password   => 'password',
#     webroot          => '/opt/web',
#   }
#
# @param base_dir
#   Specifies the full path to the _base_ directory that IHS and IBM instances should be installed to. The IBM default is `/opt/IBM`.
# @param target
#   The target directory to where this instance of IHS should be installed to. The IBM default is `/opt/IBM/HTTPServer`.
#
#   The module default is `${base_dir}/${title}`, where `$title` is the title of this resource.  So if we declared it as such:
#
#   ```puppet
#   websphere_application_server::ihs::instance { 'HTTPServer85': }
#   ```
#
#   And assumed IBM defaults, it would be installed to `/opt/IBM/HTTPServer85`.
# @param package
#   Required in the absence of a response file. The IBM package name to install for the HTTPServer installation.  This is the _first_ part (before the first underscore) of IBM's full package name. 
#
#   For example, a full name from IBM looks like: `com.ibm.websphere.IHSILAN.v85_8.5.5000.20130514_1044`. The package name is the first part of that.  In this example, `com.ibm.websphere.IHSILAN.v85`.
#
#   This corresponds to the repository metadata provided with IBM packages.
# @param version
#   Required in the absence of a response file. The IBM package version to install for the HTTPServer installation.  This is the _second_ part (after the first underscore) of IBM's full package name. 
#
#   For example, a full name from IBM looks like: `com.ibm.websphere.IHSILAN.v85_8.5.5000.20130514_1044`. The package version is the second part of that. In this example, `8.5.5000.20130514_1044`
#
#   This corresponds to the repository metadata provided with IBM packages.
# @param repository
#   Required in the absence of a response file. The full path to the installation repository file to install IHS from. This should point to the location that the IBM package is extracted to.  When extracting an IBM package, a `repository.config` is provided in the base directory.
#
#   Example: `/mnt/myorg/ihs/repository.config`
# @param response_file
#   Optional. Specifies the full path to a response file to use for installation. The response file must already be created and available for installation.  Typically, a response file includes, at a minimum, a package name, version, target, and repository information.
# @param install_options
#   Specifies options to be _appended_ to the base set of options.
#
#   When using a response file, the base options are: `input /path/to/response/file`.
#
#   When not using a response file, the base set of options are: `install ${package}_${version} -repositories ${repository} -installationDirectory ${target} -acceptLicense`.
# @param imcl_path
#   The full path to the `imcl` tool provided by the IBM Installation Manager.
#
#   The IBM default is `/opt/IBM/InstallationManager/eclipse/tools/imcl`.
#
#   This will attempt to be auto-discovered by the `ibm_pkg` provider, which parses IBM's data file in `/var/ibm` to determine where InstallationManager is installed.
#
#   You can leave this blank unless `imcl` was not auto discovered.
# @param manage_user
#   Specifies whether this _instance_ should manage the user specified by the `user` parameter.
# @param manage_group
#   Specifies whether this _instance_ should manage the group specified by the `group` parameter.
# @param user
#   Specifies the user that should own this instance of IHS.
# @param group
#   Specifies the user that should own this instance of IHS.
# @param user_home
#   Specifies the home directory for the `user`. This is only relevant if you're managing the user _with this instance_ (e.g. not via the base class).  So if `manage_user` is `true`, this is relevant.
# @param log_dir
#   Specifies the full path to where log files should be placed. In `websphere_application_server::ihs::instance`, this only manages the directory.
# @param webroot
#   Specifies the full path to where individual document roots will be stored. This is basically the base directory for doc roots. In `websphere_application_server::ihs::instance`, this only manages the directory.
# @param admin_listen_port
#   Specifies the port that the IHS administration is listening on.
# @param adminconf_template
#   Specifies an ERB template to use for the resulting `admin.conf` file. By default, the module includes one.  The value of this parameter should refer to a Puppet-accessible source, like `$module_name/template.erb`.
# @param replace_config
#   Specifies whether Puppet should continue to manage the `admin.conf` configuration after it's already placed it. If the file does not exist, Puppet creates it accordingly. If it does already exist, Puppet does not replace it.
#
#   This parameter might yield unexpected results. If IBM provides an `admin.conf` file by default, then setting this parameter to `false` causes the module to _never_ manage the file.
# @param server_name
#   Specifies the server's name that will be used in the HTTP configuration for the `ServerName` option for the admin configuration.
# @param manage_htpasswd
#   Specifies whether this defined type should manage the `htpasswd` authentication for the administrator credentials. These are used by WebSphere consoles to query and manage an IHS instance.
#
#   If `true`, the `htpasswd` utility is used to manage the credentials. If `false`, the user is responsible for configuring this.
# @param admin_username
#   The administrator username that a WebSphere Console can use for authentication to query and manage this IHS instance.
# @param admin_password
#   The administrator password that a WebSphere Console can use for authentication to query and manage this IHS instance.
#
define websphere_application_server::ihs::instance (
  $base_dir                  = $::websphere_application_server::base_dir,
  $target                    = undef,
  $package                   = undef,
  $version                   = undef,
  $repository                = undef,
  $response_file             = undef,
  $install_options           = undef,
  $imcl_path                 = undef,
  $manage_user               = true,
  $manage_group              = true,
  $user                      = $::websphere_application_server::user,
  $group                     = $::websphere_application_server::group,
  $user_home                 = $::websphere_application_server::user_home,
  $log_dir                   = undef,
  $webroot                   = undef,
  $admin_listen_port         = '8008',
  $adminconf_template        = undef,
  $replace_config            = true,
  $server_name               = $::fqdn,
  $manage_htpasswd           = true,
  $admin_username            = 'httpadmin',
  $admin_password            = 'password',
) {

  File {
    owner => $user,
    group => $group,
  }

  if ! $target {
    $_target = "${base_dir}/${title}"
  } else {
    $_target = $target
  }
  validate_absolute_path($_target)

  if ! $log_dir {
    $_log_dir = "${_target}/logs"
  } else {
    $_log_dir = $log_dir
  }
  validate_absolute_path($_log_dir)

  if ! $webroot {
    $_webroot = '/opt/web'
  } else {
    $_webroot = $webroot
  }
  validate_absolute_path($_webroot)

  if ! $adminconf_template {
    $_adminconf_template = "${module_name}/ihs/admin.conf.erb"
  } else {
    $_adminconf_template = $adminconf_template
  }

  # Ensure any non-admin user and group we'll use are present.
  # IBM's "expected layout" wants this user's home to be where IM is installed.
  validate_bool($manage_user)
  if $manage_user {
    user { $user:
      ensure => 'present',
      home   => $user_home,
      gid    => $group,
    }
  }
  validate_bool($manage_group)
  if $manage_group {
    group { $group:
      ensure => 'present',
    }
  }

  ibm_pkg { "IHS ${title}":
    ensure           => 'present',
    package          => $package,
    version          => $version,
    target           => $_target,
    response         => $response_file,
    options          => $install_options,
    repository       => $repository,
    manage_ownership => true,
    imcl_path        => $imcl_path,
    package_owner    => $user,
    package_group    => $group,
  }

  file { $_webroot:
    ensure  => 'directory',
    require => Ibm_pkg["IHS ${title}"],
  }

  file { $_log_dir:
    ensure  => 'directory',
    require => Ibm_pkg["IHS ${title}"],
  }

  ## Config file for the admin HTTP instance.
  file { "ihs_adminconf_${title}":
    ensure  => 'file',
    path    => "${_target}/conf/admin.conf",
    content => template($_adminconf_template),
    mode    => '0775',
    replace => $replace_config,
    require => Ibm_pkg["IHS ${title}"],
  }

  # Total hack here. We want to configure an admin password during the run
  # so that things can "just work". This is a simple htpasswd auth.
  # Without having this setup, the DMGR won't be able to talk to the IHS
  # server.
  # Unfortunately, htpasswd doesn't offer a "verify" function. We have a small
  # shell script to do this using openssl.
  # It's in a template to keep the long stuff out of the DSL here. Eventually,
  # a cleaner way of doing this should be looked implemented.
  validate_bool($manage_htpasswd)
  if $manage_htpasswd {
    validate_string($admin_username)
    validate_string($admin_password)
    $htpasswd_verify = template("${module_name}/ihs/htpasswd.erb")
    exec { "htpasswd for admin ${title}":
      command => "${_target}/bin/htpasswd -b -c ${_target}/conf/admin.passwd ${admin_username} ${admin_password}",
      unless  => "/bin/sh -c '${htpasswd_verify}'",
      path    => '/bin:/usr/bin:/sbin:/usr/sbin',
      user    => $user,
      require => Ibm_pkg["IHS ${title}"],
    }
  }

  # IHS Admin service
  # Requires 'lynx' to check the status and hardcodes a port.
  # For now, let's look at the process table for a matching process.
  # The 'src' service provider for AIX yields unexpected results when providing
  # custom commands for start/stop/restart/status.  For now, we'll just use
  # 'base' as the provider until an upstream answer is retrieved.
  service { "ihs_admin_${title}":
    ensure    => 'running',
    start     => "su - ${user} -c '${_target}/bin/adminctl start'",
    stop      => "su - ${user} -c '${_target}/bin/adminctl stop'",
    restart   => "su - ${user} -c '${_target}/bin/adminctl restart'",
    #status   => "su - ${user} -c '${_target}/bin/adminctl status'",
    pattern   => "${target}/bin/httpd -f ${target}/conf/admin.conf",
    hasstatus => false,
    provider  => 'base',
    subscribe => File["ihs_adminconf_${title}"],
  }

}
