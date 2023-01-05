# @summary
#   Manages the base installation of a WebSphere instance.
#
# @example Install an instance of AppServer version 8
#   websphere_application_server::instance { 'WebSphere85':
#     target       => '/opt/IBM/WebSphere/AppServer',
#     package      => 'com.ibm.websphere.NDTRIAL.v85',
#     version      => '8.5.5000.20130514_1044',
#     profile_base => '/opt/IBM/WebSphere/AppServer/profiles',
#     repository   => '/mnt/myorg/was/repository.config',
#   }
# @example Install AppServer version 9
#   websphere_application_server::instance { 'WebSphere90':
#     target              => '/opt/IBM/WebSphere/AppServer',
#     package             => 'com.ibm.websphere.ND.v90',
#     version             => '9.0.0.20160526_1854',
#     profile_base        => '/opt/IBM/WebSphere/AppServer/profiles',
#     jdk_package_name    => 'com.ibm.websphere.IBMJAVA.v71',
#     jdk_package_version => '7.1.2000.20141116_0823',
#     repository          => '/mnt/myorg/was/repository.config',
#   }
# @example Install using an response file
#   websphere_application_server::instance { 'WebSphere85':
#     response     => '/mnt/myorg/was/was85_response.xml',
#     profile_base => '/opt/IBM/WebSphere/AppServer/profiles',
#   }
#
# @param base_dir
#  This should point to the base directory that WebSphere instances should be installed to. IBM's default is `/opt/IBM`
# @param target
#   The full path where this instance should be installed. The IBM default is '/opt/IBM/WebSphere/AppServer'. The module default for `target` is "${base_dir}/${title}/AppServer", where `title` refers to the title of the resource.
# @param package
#   This is the first part (before the first underscore) of IBM's full package name. For example, a full name from IBM looks like: "com.ibm.websphere.NDTRIAL.v85_8.5.5000.20130514_1044". The package name for this example is com.ibm.websphere.NDTRIAL.v85". This corresponds to the repository metadata provided with IBM packages. This parameter is required if a response file is not provided.
# @param version
#   This is the _second_ part (after the first underscore) of IBM's full package name. For example, a full name from IBM looks like: "com.ibm.websphere.NDTRIAL.v85_8.5.5000.20130514_1044". The package version in this example is "8.5.5000.20130514_1044". This corresponds to the repository metadata provided with IBM packages. This parameter is required if a response file is not provided.
# @param repository
#   The full path to the installation repository file to install WebSphere from. This should point to the location that the IBM package is extracted to. When extracting an IBM package, a `repository.config` is provided in the base directory. Example: `/mnt/myorg/was/repository.config`
# @param response_file
#   Specifies the full path to a response file to use for installation.  It is the user's responsibility to have a response file created and available for installation. Typically, a response file will include, at a minimum, a package name, version, target, and repository information.
# @param install_options
#   Specifies options to be appended to the base set of options. When using a response file, the base options are: `input /path/to/response/file`. When not using a response file, the base set of options are:`install ${package}_${version} -repositories ${repository} -installationDirectory ${target} -acceptLicense`.
# @param imcl_path
#   The full path to the `imcl` tool provided by the IBM Installation Manager. The `ibm_pkg` provider attempts to automatically discover this path by parsing IBM's data file in `/var/ibm` to determine where InstallationManager is installed.
# @param profile_base
#   Specifies the full path to where WebSphere profiles will be stored. The IBM default is `/opt/IBM/WebSphere/AppServer/profiles`.
# @param jdk_package_name
#   Starting with WebSphere 9, you must specify the JDK package you wish to install alongside WebSphere AppServer. Like the `package` parameter, this is the IBM package name. Example: 'com.ibm.websphere.IBMJAVA.v71'
# @param jdk_package_version
#   The version string for the JDK you would like to install. Example: '7.1.2000.20141116_0823'
# @param manage_user
#   Specifies whether this instance should manage the user specified by the `user` parameter.
# @param manage_group
#   Specifies whether this instance should manage the group specified by the `group` parameter.
# @param user
#   Specifies the user that should own this instance of WebSphere.
# @param group
#   Specifies the group that should own this instance of WebSphere.
# @param user_home
#   Specifies the home directory for the `user`. This is only relevant if you're managing the user _with this instance_ (that is, not via the base class). So if `manage_user` is `true`, this is relevant. Defaults to `$target`
define websphere_application_server::instance (
  $base_dir                  = undef,
  $target                    = undef,
  $package                   = undef,
  $version                   = undef,
  $repository                = undef,
  $response_file             = undef,
  $install_options           = undef,
  $imcl_path                 = undef,
  $profile_base              = undef,
  $jdk_package_name          = undef,
  $jdk_package_version       = undef,
  $manage_user               = false,
  $manage_group              = false,
  $user                      = $::websphere_application_server::user,
  $group                     = $::websphere_application_server::group,
  $user_home                 = undef,
) {

  if $version =~ /^9.*/ and !$jdk_package_name {
    fail('When installing WebSphere AppServer 9, you must specify a JDK')
  }

  if $target and $base_dir {
    fail('Only one of $target and $base_dir can be specified')
  }

  validate_bool($manage_user, $manage_group)

  # The target is where WebSphere will get installed. If it isn't set,
  # we default it to the base_dir from the base class/title/AppServer.  This
  # is pretty much IBM's default.
  if $target {
    $_target = $target
  } else {
    if $base_dir {
      $_base_dir = $base_dir
    } else {
      $_base_dir = $::websphere_application_server::base_dir
    }
    $_target = "${_base_dir}/${title}/AppServer"
  }

  validate_absolute_path($_target)

  # A reasonable default user home if we're managing it for this instance.
  if $user_home {
    $_user_home = $user_home
  } else {
    $_user_home = $_target
  }

  # This is the IBM default. E.g. /opt/IBM/WebSphere/AppServer/profiles
  # Yes - right in the installation path.
  if $profile_base {
    $_profile_base = $profile_base
  } else {
    $_profile_base = "${_target}/profiles"
  }

  # If no response file is provided, we need a package version, name,
  # repository, and target.  Otherwise, a response file can potentially include
  # those values.
  if $response_file {
    validate_absolute_path($response_file)
  } else {
    if !$package or !$version or !$repository or !$target {
      fail('package_name, package_version, target and repository are required
      when a response file is not provided.')
    }

    validate_absolute_path($repository)

    # The imcl path is optional.  We do our best to autodiscover it, but
    # this can be used if all else fails (or if preferences vary).
    if $imcl_path {
      validate_absolute_path($imcl_path)
    }
  }


  # We want a sanitized instance name derived from the title that we can use
  # in various places that need only alpha-numeric.
  $instance_name = regsubst($title,'[^0-9a-zA-Z_]+','', 'G')

  # Optionally manage a user for this specific instance.  By default, we'll
  # just let the base class (::websphere_application_server) handle this.  There may be some
  # cases where instances should have their own independent users/groups, and
  # this allows for that.
  if $manage_user {
    user { $user:
      ensure => 'present',
      home   => $_user_home,
      gid    => $group,
    }
  }
  if $manage_group {
    group { $group:
      ensure => 'present',
    }
  }

  ibm_pkg { $title:
    ensure              => 'present',
    package             => $package,
    version             => $version,
    target              => $_target,
    response            => $response_file,
    options             => $install_options,
    repository          => $repository,
    imcl_path           => $imcl_path,
    manage_ownership    => true,
    package_owner       => $user,
    package_group       => $group,
    jdk_package_name    => $jdk_package_name,
    jdk_package_version => $jdk_package_version,
    user                => $user,
  }

  file { $_profile_base:
    ensure  => 'directory',
    owner   => $user,
    group   => $group,
    require => Ibm_pkg[$title],
  }

  # Create some facts based on the parameter values
  concat::fragment { "${instance_name}_facts":
    target  => '/etc/puppetlabs/facter/facts.d/websphere.yaml',
    content => template("${module_name}/facts/was_instance.yaml.erb"),
    require => Ibm_pkg[$title],
  }

}
