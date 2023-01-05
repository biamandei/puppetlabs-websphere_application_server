# @summary
#   Manages a DMGR profile.
#
# @example Create a basic Deployment Manager profile
#   websphere_application_server::profile::dmgr { 'PROFILE_DMGR_01':
#     instance_base => '/opt/IBM/WebSphere/AppServer',
#     profile_base  => '/opt/IBM/WebSphere/AppServer/profiles',
#     cell          => 'CELL_01',
#     node_name     => 'dmgrNode01',
#   }
#
# @param instance_base
#   Required. The full path to the installation of WebSphere that this profile should be created under. The IBM default is '/opt/IBM/WebSphere/AppServer'.
# @param cell
#   Required. The cell name to create. For example: 'CELL_01'.
# @param node_name
#   Required. The name for this "node". For example: 'dmgrNode01'.
# @param profile_base
#   Required. The full path to the base directory of profiles. The IBM default is '/opt/IBM/WebSphere/AppServer/profiles'.
# @param profile_name
#   The name of the profile. The directory that gets created will be named this. Example: 'PROFILE_DMGR_01' or 'dmgrProfile01'. Recommended to keep this alpha-numeric.
# @param user
#   The user that should own this profile.
# @param group
#   The group that should own this profile.
# @param dmgr_host
#   The address for this DMGR system. Should be an address that other hosts can connect to.
# @param template_path
#   Should point to the full path to profile templates for creating the profile.
# @param options
#   String. Defaults to '-create -profileName ${profile_name} -profilePath ${profile_base}/${profile_name} -templatePath ${_template_path} -nodeName ${node_name} -hostName ${::fqdn} -cellName ${cell}'.  These are the options that are passed to manageprofiles.sh to create the profile.
# @param manage_service
#   Specifies whether the service for the DMGR profile should be managed by this defined type instance. In IBM terms, this is startManager.sh and stopManager.sh.
# @param manage_sdk
#   Specifies whether SDK versions should be managed by this defined type instance. When managed here, it sets the default SDK for servers created under this profile.
# @param sdk_name
#   The SDK name to set if manage_sdk is `true`. This parameter is required if manage_sdk is `true`. By default, it has no value set.  Example: 1.71_64. Refer to the details for the `websphere_sdk` resource type for more information.
# @param collect_nodes
#   Specifies whether to collect exported `websphere_node` resources. This is useful for instances where unmanaged servers export `websphere_node` resources to dynamically add themselves to a cell. Refer to the details for the `websphere_node` resource type for more information.
# @param collect_web_servers
#   Specifies whether to collect exported `websphere_web_server` resources. This is useful for instances where IHS servers export `websphere_web_server` resources to dynamically add themselves to a cell. Refer to the details for the `websphere_web_server` resource type for more information
# @param collect_jvm_logs
#   Specifies whether to collect exported `websphere_jvm_log` resources. This is useful for instances where application servers export `websphere_jvm_log` resources to manage their JVM logging properties. Refer to the details for the `websphere_jvm_log` resource type for more information.
# @param wsadmin_user
#   Optional. The username for `wsadmin` authentication if security is enabled.
# @param wsadmin_pass
#   Optional. The password for `wsadmin` authentication if security is enabled.
#
define websphere_application_server::profile::dmgr (
  $instance_base,
  $cell,
  $node_name,
  $profile_base            = undef,
  $profile_name            = $title,
  $user                    = $::websphere_application_server::user,
  $group                   = $::websphere_application_server::group,
  $dmgr_host               = $::fqdn,
  $template_path           = undef,
  $options                 = undef,
  $manage_service          = true,
  $manage_sdk              = false,
  $sdk_name                = undef,
  $collect_nodes           = true,
  $collect_web_servers     = true,
  $collect_jvm_logs        = true,
  $wsadmin_user            = undef,
  $wsadmin_pass            = undef,
) {
  validate_absolute_path($instance_base)
  validate_string($cell, $node_name, $profile_name, $user, $group, $dmgr_host)

  ## Template path. Figure out a sane default if not explicitly specified.
  if ! $template_path {
    $_template_path = "${instance_base}/profileTemplates/dmgr"
  } else {
    $_template_path = $template_path
  }
  validate_absolute_path($_template_path)

  if ! $profile_base {
    $_profile_base = "${instance_base}/profiles"
  } else {
    $_profile_base = $profile_base
  }
  validate_absolute_path($_profile_base)

  if $manage_sdk and !$sdk_name {
    fail('sdk_name is required when manage_sdk is true. E.g. 1.71_64')
  }

  if ! $options {
    $_options = "-create -profileName ${profile_name} -profilePath ${_profile_base}/${profile_name} -templatePath ${_template_path} -nodeName ${node_name} -hostName ${dmgr_host} -cellName ${cell}"
  } else {
    $_options = $options
  }
  validate_string($_options)

  # Create the DMGR profile
  # IBM's stuff almost always exits 0, so we test that the profile directory
  # at leasts exists before saying success.
  exec { "was_profile_dmgr_${title}":
    command => "${instance_base}/bin/manageprofiles.sh ${_options} && test -d ${_profile_base}/${profile_name}",
    creates => "${_profile_base}/${profile_name}",
    path    => '/bin:/usr/bin:/sbin:/usr/sbin',
    cwd     => "${instance_base}/bin",
    user    => $user,
    timeout => 900,
    returns => [0, 2],
  }

  # Ensure ownership of profile directory is correct
  websphere_application_server::ownership { $title:
    user    => $user,
    group   => $group,
    path    => "${_profile_base}/${profile_name}",
    require => Exec["was_profile_dmgr_${title}"],
  }

  # We use the DMGR hostname/fqdn to export a file resource so nodes can
  # federate with us.
  $_dmgr_host = downcase($dmgr_host)
  $_cell      = downcase($cell)
  $_profile   = downcase($profile_name)
  $_node      = downcase($node_name)
  $soap_port  = $facts["websphere_${_profile}_${_cell}_${_node}_soap"]

  if $soap_port {
    @@file { "/etc/dmgr_${_dmgr_host}_${_cell}":
      ensure  => 'file',
      content => template("${module_name}/dmgr_federation.yaml.erb"),
    }
  }

  validate_bool($manage_sdk)
  if $manage_sdk {
    websphere_sdk { "${title}_${sdk_name}":
      profile             => $profile_name,
      server              => 'all',
      sdkname             => $sdk_name,
      instance_base       => $instance_base,
      new_profile_default => $sdk_name,
      command_default     => $sdk_name,
      user                => $user,
      username            => $wsadmin_user,
      password            => $wsadmin_pass,
      require             => Exec["was_profile_dmgr_${title}"],
      subscribe           => Websphere_application_server::Ownership[$title],
    }
  }

  validate_bool($manage_service)
  if $manage_service {
    websphere_application_server::profile::service { $title:
      type         => 'dmgr',
      profile_base => $_profile_base,
      user         => $user,
      wsadmin_user => $wsadmin_user,
      wsadmin_pass => $wsadmin_pass,
      require      => Exec["was_profile_dmgr_${title}"],
      subscribe    => Websphere_application_server::Ownership[$title],
    }
  }

  validate_bool($collect_nodes)
  if $collect_nodes {
    Websphere_node <<| cell == $cell and dmgr_host == $dmgr_host |>> {
      profile_base => $_profile_base,
      dmgr_profile => $title,
      user         => $user,
      wsadmin_user => $wsadmin_user,
      wsadmin_pass => $wsadmin_pass,
    }
  }

  validate_bool($collect_web_servers)
  if $collect_web_servers {
    Websphere_web_server <<| cell == $cell and dmgr_host == $dmgr_host |>> {
      profile_base => $_profile_base,
      dmgr_profile => $title,
      user         => $user,
      wsadmin_user => $wsadmin_user,
      wsadmin_pass => $wsadmin_pass,
    }
  }

  validate_bool($collect_jvm_logs)
  if $collect_jvm_logs {
    Websphere_jvm_log <<| cell == $cell and dmgr_host == $dmgr_host |>> {
      profile_base => $_profile_base,
      profile      => $title,
      user         => $user,
      wsadmin_user => $wsadmin_user,
      wsadmin_pass => $wsadmin_pass,
    }
  }
}
