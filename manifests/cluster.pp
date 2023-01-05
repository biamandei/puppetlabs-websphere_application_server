# @summary
#   Manage WebSphere clusters.
#
# @example Create a simple cluster
#   websphere_application_server::cluster { 'MyCluster01':
#     profile_base => '/opt/IBM/WebSphere/AppServer/profiles',
#     dmgr_profile => 'PROFILE_DMGR_01',
#     cell         => 'CELL_01',
#     require      => Websphere_application_server::Profile::Dmgr['PROFILE_DMGR_01'],
#   }
#
# @param dmgr_profile
#   Required. The DMGR profile under which this cluster should be created. The `wsadmin` tool is used from this profile.
# @param profile_base
#   Path to the base directory for your profiles.
# @param cell
#   Required. The cell that this cluster should be created under.
# @param user
#   The user that should run the `wsadmin` commands.  Defaults to `$::websphere_application_server::user`
# @param cluster
#   The name of the cluster to manage. Defaults to the resource title.
# @param collect_members
#   Specifies whether _exported_ resources relating to WebSphere clusters should be _collected_ by this instance of the defined type. If true, `websphere_application_server::cluster::member`, `websphere_cluster_member`, and `websphere_cluster_member_service` resources that match this cell are collected.  The use case for this is so application servers, for instance, can export themselves as a cluster member in a certain cell. When this defined type is evaluated by a DMGR, those can automatically be collected.
# @param wsadmin_user
#   Optional. The username for `wsadmin` authentication if security is enabled.
# @param wsadmin_pass
#   Optional. The password for `wsadmin` authentication if security is enabled.
# @param dmgr_host
#   The resolvable hostname for the DMGR that this cluster exists on. This is needed for collecting cluster members. Defaults to `$::fqdn`.
#
define websphere_application_server::cluster (
  $dmgr_profile,
  $profile_base,
  $cell,
  $ensure           = 'present',
  $user             = $::websphere_application_server::user,
  $cluster          = $title,
  $collect_members  = true,
  $wsadmin_user     = undef,
  $wsadmin_pass     = undef,
  $dmgr_host        = $::fqdn,
) {
  websphere_cluster { $cluster:
    ensure       => $ensure,
    profile_base => $profile_base,
    dmgr_profile => $dmgr_profile,
    user         => $user,
    wsadmin_user => $wsadmin_user,
    wsadmin_pass => $wsadmin_pass,
  }

  if $collect_members {
    ## Collect any or our exported defined types
    Websphere_application_server::Cluster::Member <<| cell == $cell and dmgr_host == $dmgr_host |>> {
      profile_base => $profile_base,
      dmgr_profile => $dmgr_profile,
      user         => $user,
      wsadmin_user => $wsadmin_user,
      wsadmin_pass => $wsadmin_pass,
      require      => Websphere_cluster[$name],
    }

    ## Collect any of the individual resources
    Websphere_cluster_member <<| cell == $cell and dmgr_host == $dmgr_host |>> {
      profile_base => $profile_base,
      dmgr_profile => $dmgr_profile,
      user         => $user,
      wsadmin_user => $wsadmin_user,
      wsadmin_pass => $wsadmin_pass,
      require      => Websphere_cluster[$name],
    }

    Websphere_cluster_member_service <<| cell == $cell and dmgr_host == $dmgr_host |>> {
      profile_base => $profile_base,
      dmgr_profile => $dmgr_profile,
      user         => $user,
      wsadmin_user => $wsadmin_user,
      wsadmin_pass => $wsadmin_pass,
    }
  }
}
