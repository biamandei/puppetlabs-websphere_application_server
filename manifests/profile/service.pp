# @summary
#   Manages the node service for WAS profiles.
#
# @example Manage a Deployment Manager profile service
#   websphere_application_server::profile::service { 'PROFILE_DMGR_01':
#     type         => 'dmgr',
#     ensure       => 'running',
#     profile_base => '/opt/IBM/WebSphere/AppServer/profiles',
#     user         => 'webadmin',
#   }
#
# @param type
#   Specifies the type of service. Valid values are 'dmgr' and 'app'. DMGR profiles are managed via IBM's startManager and stopManager scripts. Application servers are managed via the startNode and stopNode scripts.
# @param profile_base
#   Required. The full path to the base directory of profiles. The IBM default is '/opt/IBM/WebSphere/AppServer/profiles'.
# @param profile_name
#   The name of the profile. The directory that gets created will be named this. Example: 'PROFILE_APP_01' or 'appProfile01'. Recommended to keep this alpha-numeric.
# @param user
#   The user that should own this profile.
# @param ensure
#   Specifies the state of the service. Valid values are 'running' and 'stopped'.
# @param start
#   Specifies a command to start the service with. This differs between DMGR hosts and Application Servers.
#
#   On a DMGR, the default is:
#
#   `/bin/su - ${user} -c '${profile_base}/${profile_name}/bin/startManager.sh -profileName ${profile_name}'`
#
#   On an application server, the default is:
#
#   `/bin/su - ${user} -c '${profile_base}/${profile_name}/bin/startNode.sh'`
# @param stop
#   Specifies a command to stop the service with. This differs between DMGR hosts and Application Servers.
#
#   On a DMGR, the default is:
#
#   `/bin/su - ${user} -c '${profile_base}/${profile_name}/bin/stopManager.sh -profileName ${profile_name}'`
#
#   On an application server, the default is:
#
#   `/bin/su - ${user} -c '${profile_base}/${profile_name}/bin/stopNode.sh'`
# @param status
#   Specifies a command to check the status of the service with. This differs between DMGR hosts and Application Servers.
#
#   On a DMGR, the default is:
#
#   `/bin/su - ${user} -c '${profile_base}/${profile_name}/bin/serverStatus.sh dmgr -profileName ${profile_name} | grep -q STARTED'`
#
#   On an application server, the default is:
#
#   `/bin/su - ${user} -c '${profile_base}/${profile_name}/bin/serverStatus.sh nodeagent -profileName ${profile_name} | grep -q STARTED'`
# @param restart
#   Specifies a command to restart the service with. By default, we do not define anything. Instead, Puppet will stop the service and start the service to restart it.
# @param wsadmin_user
#   Optional. The username for `wsadmin` authentication if security is enabled.
# @param wsadmin_pass
#   Optional. The password for `wsadmin` authentication if security is enabled.
#
define websphere_application_server::profile::service (
  $type,
  $profile_base,
  $profile_name = $title,
  $user         = 'root',
  $ensure       = 'running',
  $start        = undef,
  $stop         = undef,
  $status       = undef,
  $restart      = undef,
  $wsadmin_user = undef,
  $wsadmin_pass = undef,
) {
  ## Really, we can create more profile types than this, but this is all we
  ## support right now.
  validate_re($type, '(dmgr|app|appserver|node)')
  validate_absolute_path($profile_base)
  validate_string($profile_name)
  validate_string($user)
  validate_re($ensure, '(running|stopped)')

  if $start { validate_string($start) }
  if $stop { validate_string($stop) }
  if $status { validate_string($status) }
  if $restart { validate_string($restart) }

  if $wsadmin_user and $wsadmin_pass {
    $_auth_string = "-username \"${wsadmin_user}\" -password \"${wsadmin_pass}\" "
  } else {
    $_auth_string = undef
  }

  if ! $status {
    if $type == 'dmgr' {
      $_status = "/bin/su - ${user} -c '${profile_base}/${profile_name}/bin/serverStatus.sh dmgr ${_auth_string} -profileName ${profile_name} | grep -q STARTED'"
    } else {
      $_status = "/bin/su - ${user} -c '${profile_base}/${profile_name}/bin/serverStatus.sh nodeagent -profileName ${profile_name} ${_auth_string}| grep -q STARTED'"
    }
  } else {
    $_status = $status
  }

  if ! $start {
    if $type == 'dmgr' {
      $_start = "/bin/su - ${user} -c '${profile_base}/${profile_name}/bin/startManager.sh -profileName ${profile_name} ${_auth_string}'"
    } else {
      $_start = "/bin/su - ${user} -c '${profile_base}/${profile_name}/bin/startNode.sh ${_auth_string}'"
    }
  } else {
    $_start = $start
  }

  if ! $stop {
    if $type == 'dmgr' {
      $_stop = "/bin/su - ${user} -c '${profile_base}/${profile_name}/bin/stopManager.sh -profileName ${profile_name} ${_auth_string}'"
    } else {
      $_stop = "/bin/su - ${user} -c '${profile_base}/${profile_name}/bin/stopNode.sh ${_auth_string}'"
    }
  } else {
    $_stop = $stop
  }

  if ! $restart {
    $_restart = undef
  } else {
    $_restart = $restart
  }

  service { "was_profile_${title}":
    ensure   => $ensure,
    start    => $_start,
    stop     => $_stop,
    status   => $_status,
    restart  => $_restart,
    provider => 'base',
  }
}
