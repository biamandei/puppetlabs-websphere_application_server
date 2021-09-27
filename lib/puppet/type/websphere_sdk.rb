# frozen_string_literal: true

require 'pathname'

Puppet::Type.newtype(:websphere_sdk) do
  @doc = <<-DOC
    @summary This manages WebSphere SDK/JDK versions'
    DOC

  autorequire(:user) do
    self[:user]
  end

  def self.title_patterns
    [
      [
        %r{^(.*)_(.*)$},
        [
          [:profile],
          [:sdkname],
        ],
      ],
      [
        %r{^(.*)$},
        [
          [:sdkname],
        ],
      ],
    ]
  end

  validate do
    [:server, :profile, :user].each do |value|
      raise ArgumentError, "Invalid #{value} #{self[:value]}" unless %r{^[-0-9A-Za-z._]+$}.match?(value)
    end

    raise ArgumentError, 'Name of the SDK to modify is required.' unless self[:sdkname]
    raise ArgumentError, "Invalid instance_base #{self[:instance_base]}" unless Pathname.new(self[:instance_base]).absolute?
  end

  newparam(:server) do
    desc <<-EOT
      The server in the scope for this variable.
      This can be a specific server or 'all' to affect all servers

      'all' corresponds to the 'managesdk.sh' option '-enableServers'
    EOT
  end

  newparam(:node_name) do
    desc <<-EOT
      Required: The node name this sdk is to be managed on.
    EOT
  end

  newparam(:dmgr_profile) do
    desc <<-EOT
      Optional: The dmgr_profile to use as base profile. Will use profile if unset.
    EOT
  end

  newparam(:profile_base) do
    desc <<-EOT
      The profile base directory
    EOT
  end

  newparam(:profile) do
    desc <<-EOT
      The profile to modify.
      Specify 'all' for all profiles. 'all' corresponds to the 'managesdk.sh'
      option '-enableProfileAll'

      A specific profile name can also be provided. Example: PROFILE_APP_001.
      This corresponds to 'managesdk.sh' options -enableProfile -profileName
    EOT
  end

  newproperty(:sdkname) do
    desc 'The name of the SDK to modify. Example: 1.7.1_64'
  end

  newparam(:instance_base) do
    desc <<-EOT
      The base directory that WebSphere is installed.
      Example: `/opt/IBM/WebSphere/AppServer/`
    EOT
  end

  newproperty(:command_default) do
    desc <<-EOT
      Manages the SDK name that script commands in the
      app_server_root/bin, app_client_root/bin, or plugins_root/bin directory
      are enabled to use when no profile is specified by the command and when
      no profile is defaulted by the command.
    EOT
  end

  newproperty(:new_profile_default) do
    desc <<-EOT
      Manages the SDK name that is currently configured for all profiles
      that are created with the manageprofiles command. The -sdkname parameter
      specifies the default SDK name to use. The sdkName value must be an SDK
      name that is enabled for the product installation.
    EOT
  end

  newparam(:user) do
    defaultto 'root'
    desc "The user to run 'wsadmin' with"
  end

  newparam(:wsadmin_user) do
    desc 'The username for authentication if security is enabled.'
  end

  newparam(:wsadmin_pass) do
    desc 'The username for authentication if security is enabled.'
  end

  newparam(:username) do
    desc "The username for 'managesdk.sh' authentication"
  end

  newparam(:password) do
    desc "The password for 'managesdk.sh' authentication"
  end
end
