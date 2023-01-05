# @summary
#   Manages WAS application servers.
#
# @example Create a basic AppServer profile
#   websphere_application_server::profile::appserver { 'PROFILE_APP_001':
#     instance_base  => '/opt/IBM/WebSphere/AppServer',
#     profile_base   => '/opt/IBM/WebSphere/AppServer/profiles',
#     cell           => 'CELL_01',
#     template_path  => '/opt/IBM/WebSphere/AppServer/profileTemplates/managed',
#     dmgr_host      => 'dmgr.example.com',
#     node_name      => 'appNode01',
#     manage_sdk     => true,
#     sdk_name       => '1.7.1_64',
#   }
#
# @param instance_base
#   Required. The full path to the installation of WebSphere that this profile should be created under. The IBM default is '/opt/IBM/WebSphere/AppServer'.
# @param profile_base
#   Required. The full path to the base directory of profiles. The IBM default is '/opt/IBM/WebSphere/AppServer/profiles'.
# @param cell
#   Required. The cell name to create. For example: 'CELL_01'.
# @param node_name
#   Required. The name for this "node". For example: 'appNode01'.
# @param profile_name
#   The name of the profile. The directory that gets created will be named this. Example: 'PROFILE_APP_01' or 'appProfile01'. Recommended to keep this alpha-numeric.
# @param user
#   The user that should own this profile.
# @param group
#   The group that should own this profile.
# @param dmgr_host
#   The address for the DMGR host.
# @param dmgr_port
#   The SOAP port that should be used for federation. You normally don't need to specify this, as it's handled by exporting and collecting resources.
# @param template_path
#   Should point to the full path to profile templates for creating the profile.
# @param options
#   The options that are passed to manageprofiles.sh to create the profile. If you specify a value for options, none of the defaults are used. Defaults to '-create -profileName ${profile_name} -profilePath ${profile_base}/${profile_name} -templatePath ${_template_path} -nodeName ${node_name} -hostName ${::fqdn} -federateLater true -cellName standalone' For application servers, the default cell name is standalone. Upon federation (which we aren't doing as part of the profile creation), the application server federates with the specified cell.
# @param manage_federation
#   Specifies whether federation should be managed by this defined type or not. If not, the user is responsible for federation. The `websphere_federate` type is used to handle the federation. Federation, by default, requires a data file to have been exported by the DMGR host and collected by the application server. This defined type collects any exported datafiles that match the DMGR host and cell.
# @param manage_service
#   Specifies whether the service for the app profile should be managed by this defined type instance. In IBM terms, this is startNode.sh and stopNode.sh.
# @param manage_sdk
#   Specifies whether SDK versions should be managed by this defined type instance or not. Essentially, when managed here, it sets the default SDK for servers created under this profile. This is only relevant if `manage_federation` is `true`.
# @param sdk_name
#   The SDK name to set if `manage_sdk` is `true`. This parameter is required if `manage_sdk` is `true`. Example: 1.71_64. Refer to the details for the `websphere_sdk` resource type for more information. This is only relevant if `manage_federation` and `manage_sdk` are `true`.
# @param wsadmin_user
#   Optional. The username for `wsadmin` authentication if security is enabled.
# @param wsadmin_pass
#   Optional. The password for `wsadmin` authentication if security is enabled.
#
define websphere_application_server::profile::appserver (
  $instance_base,
  $profile_base,
  $cell,
  $node_name,
  $profile_name      = $title,
  $user              = $::websphere_application_server::user,
  $group             = $::websphere_application_server::group,
  $dmgr_host         = undef,
  $dmgr_port         = undef,
  $template_path     = undef,
  $options           = undef,
  $manage_federation = true,
  $manage_service    = true,
  $manage_sdk        = false,
  $sdk_name          = undef,
  $wsadmin_user      = undef,
  $wsadmin_pass      = undef,
) {
  validate_absolute_path($instance_base)
  validate_absolute_path($profile_base)
  validate_string($cell)
  validate_string($node_name)
  validate_string($profile_name)
  validate_string($user)
  validate_string($group)
  validate_string($dmgr_host)
  validate_string($dmgr_host)
  validate_bool($manage_federation)
  validate_bool($manage_service)
  validate_bool($manage_sdk)

  ## Template path. Figure out a sane default if not explicitly specified.
  if ! $template_path {
    $_template_path = "${instance_base}/profileTemplates/app"
  } else {
    $_template_path = $template_path
  }
  validate_absolute_path($_template_path)

  if $manage_sdk and !$sdk_name {
    fail('sdk_name is required when manage_sdk is true. E.g. 1.71_64')
  }

  if $manage_sdk and !$manage_federation {
    fail('manage_federation must be true when manage_sdk is true')
  }

  ## Build our installation options if none are profided. These are mostly
  ## similar, but we do add extra to the 'app' profile type. Hackish.
  if ! $options {
    $_options = "-create -profileName ${profile_name} -profilePath ${profile_base}/${profile_name} -templatePath ${_template_path} -nodeName ${node_name} -hostName ${::fqdn} -federateLater true -cellName standalone"
  } else {
    $_options = $options
  }
  validate_string($_options)

  ## Create the profile
  ## manageprofiles.sh will exit 0 even if it fails. Let's at least test that
  ## the profile directory exists before calling it successful.
  exec { "was_profile_app_${title}":
    command => "${instance_base}/bin/manageprofiles.sh ${_options} && test -d ${profile_base}/${profile_name}",
    creates => "${profile_base}/${profile_name}",
    cwd     => $instance_base,
    path    => '/bin:/usr/bin:/sbin:/usr/sbin',
    user    => $user,
    timeout => 900,
    returns => [0, 2],
  }

  # Ensure ownership of profile directory is correct
  websphere_application_server::ownership { $title:
    user    => $user,
    group   => $group,
    path    => "${profile_base}/${profile_name}",
    require => Exec["was_profile_app_${title}"],
  }

  $_dmgr_host = downcase($dmgr_host)
  $_cell = downcase($cell)

  ## Collect the federation resource
  File <<| title == "/etc/dmgr_${_dmgr_host}_${_cell}" |>> {
    path   => "${profile_base}/${profile_name}/dmgr_${_dmgr_host}_${_cell}.yaml",
    before => Websphere_federate["${title}_${dmgr_host}_${cell}"],
  }

  if $manage_federation {
    websphere_federate { "${title}_${dmgr_host}_${cell}":
      ensure       => present,
      node_name    => $node_name,
      cell         => $cell,
      profile_base => $profile_base,
      profile      => $profile_name,
      dmgr_host    => $dmgr_host,
      user         => $user,
      username     => $wsadmin_user,
      password     => $wsadmin_pass,
      before       => Websphere_application_server::Profile::Service[$title],
    }

    ## Modifying SDK requires federation
    if $manage_sdk {
      websphere_sdk { "${title}_${sdk_name}":
        profile_base        => $profile_base,
        profile             => $profile_name,
        node_name           => $node_name,
        server              => 'all',
        sdkname             => $sdk_name,
        instance_base       => $instance_base,
        new_profile_default => $sdk_name,
        command_default     => $sdk_name,
        user                => $user,
        username            => $wsadmin_user,
        password            => $wsadmin_pass,
        require             => Websphere_federate["${title}_${dmgr_host}_${cell}"],
        notify              => Websphere_application_server::Profile::Service[$title],
      }
    }
  }

  if $manage_service {
    websphere_application_server::profile::service { $title:
      type         => 'app',
      profile_base => $profile_base,
      user         => $user,
      wsadmin_user => $wsadmin_user,
      wsadmin_pass => $wsadmin_pass,
      require      => Exec["was_profile_app_${title}"],
      subscribe    => Websphere_application_server::Ownership[$title],
    }
  }
}
