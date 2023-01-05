# @summary
#   Manage web server (http) instances on IHS
#
# @example Set up an IHS Server
#   websphere_application_server::ihs::server { 'test':
#     target      => '/opt/IBM/HTTPServer',
#     log_dir     => '/opt/log/websphere/httpserver',
#     plugin_dir  => '/opt/IBM/Plugins/config/test',
#     plugin_base => '/opt/IBM/Plugins',
#     cell        => 'CELL_01',
#     config_file => '/opt/IBM/HTTPServer/conf/httpd_test.conf',
#     access_log  => '/opt/log/websphere/httpserver/access_log',
#     error_log   => '/opt/log/websphere/httpserver/error_log',
#     listen_port => '10080',
#     require     => Ibm_pkg['Plugins'],
#   }
#
# @param target
#   Required. Specifies the full path to the IHS installation that this server should belong to.  
#
#   Example: `/opt/IBM/HTTPServer`
# @param status
#   Ensure status for the server service.
# @param httpd_config
#   Specifies the full path to the HTTP configuration file to manage. Assembled as `${target}/conf/httpd_${title}.conf`.
# @param user
#   The user that should own and run this server instance. The service will be managed as this user. This also corresponds to the "User" option in the HTTP configuration.
# @param group
#   The group that should own and run this server instance. This also corresponds to the "Group" option in the HTTP configuration.
# @param docroot
#   Specifies the full path to the document root for this server instance. Assembled as `${target}/htdocs`.
# @param instance
#   This parameter is inactive. Defaults to the resource's title.
# @param httpd_config_template
#   Specifies a Puppet-readable location for a template to use for the HTTP configuration. One is provided, but this allows you to use your own custom template. Assembled as `${module_name}/ihs/httpd.conf.erb`.
# @param timeout
#   Specifies the value for `Timeout`.
# @param max_keep_alive_requests
#   Specifies the value for `MaxKeepAliveRequests`.
# @param keep_alive
#   Specifies the value for `KeepAlive`. Valid values are `On` or `Off`.
# @param keep_alive_timeout
#   Specifies the value for `KeepAliveTimeout`.
# @param thread_limit
#   Specifies the value for `ThreadLimit`.
# @param server_limit
#   Specifies the value for `ServerLimit`.
# @param start_servers
#   Specifies the value for `StartServers`.
# @param max_clients
#   Specifies the value for `MaxClients`.
# @param min_spare_threads
#   Specifies the value for `MinSpareThreads`.
# @param max_spare_threads
#   Specifies the value for `MaxSpareThreads`.
# @param threads_per_child
#   Specifies the value for `ThreadsPerChild`.
# @param max_requests_per_child
#   Specifies the value for `MaxRequestsPerChild`.
# @param limit_request_field_size
#   Specifies the value for `LimitRequestFieldSize`.
# @param listen_address
#   Specifies the address for the `Listen` HTTP option. To listen on all available addresses, set to an asterisk (*).
# @param listen_port
#   Specifies the port for the `Listen` HTTP option.
# @param server_admin_email
#   Specifies the value for the `ServerAdmin` e-mail address
# @param server_name
#   Specifies the value for the `ServerName` HTTP option. Typically, an HTTP ServerName option will look like:
#
#    ```
#    ServerName host:port
#    ```
#
#    This specifies the _host_ part of that.
# @param server_listen_port
#   Specifies the port value for the `ServerName` HTTP option. See the `server_name` parameter above for more information.
# @param pid_file
#   Specifies the base filename for a PID file.  Defaults to the resource's title. This _isn't the full path_, just the filename.
# @param replace_config
#   Specifies whether Puppet should replace this server's HTTP configuration once it's present. If the file doesn't exist, Puppet creates it. If this parameter is set to `true`, Puppet ensures that the configuration file matches what is described. If this value is `false`, Puppet ignores the file's contents. We recommend that you leave this set to `true` and manage the config file through Puppet exclusively.
# @param directory_index
#   Specifies the `DirectoryIndex` for this instance. Should be a string that has space-separated filenames.
#
#   Example: `index.html index.html.var`
# @param log_dir
#   Specifies the full path to where access/error logs should be stored. Assembled as `${target}/logs`.
# @param access_log
#   The filename for the access log.
# @param error_log
#   The filename for the error log.
# @param export_node
#   Specifies whether a `websphere_node` resource should be exported. This is intended to be used for DMGRs to collect to create an _unmanaged_ node.
# @param export_server
#   Specifies whether a `websphere_web_server` resource should be exported for this server. This allows a DMGR to collect it to create a web server instance.
# @param node_name
#   Required if `export_node` is `true`. Specifies the node name to use for creation on a DMGR.
# @param node_hostname
#   Specifies the resolvable address for this server for creating the node. The DMGR host needs to be able to reach this server at this address.
# @param node_os
#   Specifies the operating system for this server. This is used for the DMGR to create an _unmanaged_ node for this server. We currently only support 'aix' and 'linux'.
# @param cell
#   Required if `export_node` is `true`.  The cell that this node should be a part of.
# @param admin_username
#   This is required if `export_server` is true.  Specifies the administrator username that a DMGR can query and manage this server with.
# @param admin_password
#   This is required if `export_server` is true.  Specifies the administrator password that a DMGR can query and manage this server with.
# @param plugin_base
#   Specifies the full path to the plugin base directory.
# @param propagate_keyring
#   Specifies whether the plugin keyring should be propagated from the DMGR to this server after the web server instance is created on the DMGR. This is only relevant if `export_server` is `true`.
# @param dmgr_host
#   This is required if you're exporting the server for a DMGR to collect. The DMGR host to add this server to.
#
define websphere_application_server::ihs::server (
  $target,
  $status                  = 'running',
  $httpd_config            = undef,
  $user                    = $::websphere_application_server::user,
  $group                   = $::websphere_application_server::group,
  $docroot                 = undef,
  $instance                = $title,
  $httpd_config_template   = "${module_name}/ihs/httpd.conf.erb",
  $timeout                 = '300',
  $max_keep_alive_requests = '100',
  $keep_alive              = 'On',
  $keep_alive_timeout      = '10',
  $thread_limit            = '25',
  $server_limit            = '64',
  $start_servers           = '1',
  $max_clients             = '600',
  $min_spare_threads       = '25',
  $max_spare_threads       = '75',
  $threads_per_child       = '25',
  $max_requests_per_child  = '25',
  $limit_request_field_size = '12392',
  $listen_address          = $::fqdn,
  $listen_port             = '10080',
  $server_admin_email      = 'user@example.com',
  $server_name             = $::fqdn,
  $server_listen_port      = '80',
  $pid_file                = "${title}.pid",
  $replace_config          = true,
  $directory_index         = 'index.html index.html.var',
  $log_dir                 = undef,
  $access_log              = 'access_log',
  $error_log               = 'error_log',
  $export_node             = true,
  $export_server           = true,
  $node_name               = $::fqdn,
  $node_hostname           = $::fqdn,
  $node_os                 = undef,
  $cell                    = undef,
  $admin_username          = 'httpadmin',
  $admin_password          = 'password',
  $plugin_base             = '/opt/IBM/Plugins',
  $propagate_keyring       = true,
  $dmgr_host               = undef,
) {

  Exec {
    path => '/bin:/sbin:/usr/bin:/usr/sbin',
  }

  File {
    owner  => $user,
    group  => $group,
  }

  if !$docroot {
    $_docroot = "${target}/htdocs"
  } else {
    $_docroot = $docroot
  }

  if !$httpd_config {
    $_httpd_config = "${target}/conf/httpd_${title}.conf"
  } else {
    $_httpd_config = $httpd_config
  }

  if !$log_dir {
    $_log_dir = "${target}/logs"
  } else {
    $_log_dir = $log_dir
  }

  file { "${title} ${_docroot}":
    ensure => 'directory',
    path   => $_docroot,
  }

  file { "${plugin_base}/config/${instance}":
    ensure => 'directory',
  }

  ## Use exec to create the log_dir.  It might be several levels deep.  In that
  ## case, a regular 'file' resource would be tricky.
  exec { "${title}_log_dir":
    command => "mkdir -p ${_log_dir}",
    creates => $_log_dir,
  }

  file_line { 'Adding user':
    path  => $_httpd_config,
    line  => "User ${user}",
    match => '^User $',
  }

  file_line { 'Adding group':
    path  => $_httpd_config,
    line  => "Group ${group}",
    match => '^Group $',
  }

  file { '/etc/ld.so.conf.d/httpd-pp-lib.conf':
    ensure => present,
  }

  file_line { 'Adding shared library paths':
    ensure => present,
    path   => '/etc/ld.so.conf.d/httpd-pp-lib.conf',
    line   => '/opt/IBM/HTTPServer/lib',
  }

  exec { 'refresh_ld_cache':
    command     => 'ldconfig',
    path        => [ '/sbin/' ],
    refreshonly => true,
    subscribe   => File_line['Adding shared library paths'],
  }

  file { "${title}_httpd_config":
    ensure  => 'file',
    path    => $_httpd_config,
    content => template($httpd_config_template),
    replace => $replace_config,
  }

  if $status == 'stopped' {
    service { "${title}_httpd_config":
      ensure    => 'stopped',
      start     => "su - ${user} -c \"${target}/bin/adminctl start\"",
      stop      => "su - ${user} -c \"${target}/bin/adminctl stop\"",
      restart   => "su - ${user} -c \"${target}/bin/adminctl restart\"",
      hasstatus => false,
      pattern   => "${target}/bin/httpd.*-f ${target}/conf/admin.conf",
      provider  => 'base',
    }
  }

  service { "${title}_httpd":
    ensure    => $status,
    start     => "su - ${user} -c \"${target}/bin/apachectl -d ${target} -k start -f '${_httpd_config}'\"",
    stop      => "su - ${user} -c \"${target}/bin/apachectl -d ${target} -k stop -f '${_httpd_config}'\"",
    restart   => "su - ${user} -c \"${target}/bin/apachectl -d ${target} -k restart -f '${_httpd_config}'\"",
    hasstatus => false,
    pattern   => "${target}/bin/httpd.*-f ${_httpd_config}",
    provider  => 'base',
    subscribe => File["${title}_httpd_config"],
  }

  # Exporting for a DMGR to collect.
  if $export_node {

    if $node_os {
      $_node_os = $node_os
    } else {
      $_node_os = downcase($::kernel)
    }

    validate_re($_node_os, '(aix|linux)', "Invalid node_os: #{_node_os}. Must be 'aix' or 'linux'")

    if !$cell {
      fail('cell is required when export_node is true')
    }

    if !$node_name {
      fail('node_name is required when export_node is true')
    }

    if !$dmgr_host {
      fail('dmgr_host is required when export_node is true')
    }

    validate_bool($propagate_keyring)

    @@websphere_node { "ihs_${title}_${node_hostname}":
      ensure    => present,
      node_name => $node_name,
      os        => $_node_os,
      hostname  => $node_hostname,
      cell      => $cell,
      dmgr_host => $dmgr_host,
    }

    if $export_server {
      @@websphere_web_server { "web_${title}_${node_hostname}":
        ensure            => present,
        name              => $title,
        node_name         => $node_name,
        cell              => $cell,
        admin_user        => $admin_username,
        admin_pass        => $admin_password,
        plugin_base       => $plugin_base,
        install_root      => $target,
        config_file       => $_httpd_config,
        access_log        => $access_log,
        error_log         => $error_log,
        web_port          => $listen_port,
        propagate_keyring => $propagate_keyring,
        dmgr_host         => $dmgr_host,
        require           => Websphere_node["ihs_${title}_${node_hostname}"],
      }
    }
  }
}
