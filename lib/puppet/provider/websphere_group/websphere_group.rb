# frozen_string_literal: true

require 'English'
require_relative '../websphere_helper'

Puppet::Type.type(:websphere_group).provide(:wsadmin, parent: Puppet::Provider::Websphere_Helper) do
  desc <<-DESC
    Provider to manage WebSphere groups in the default WIM file based realm

    Please see the IBM documentation available at:
    https://www.ibm.com/docs/en/was/9.0.5?topic=scripting-wimmanagementcommands-command-group-admintask-object#rxml_atwimmgt__cmd3
    https://www.ibm.com/docs/en/was/9.0.5?topic=scripting-authorizationgroupcommands-command-group-admintask-object

    We execute the 'wsadmin' tool to query and make changes, which interprets
    Jython. This means we need to use heredocs to satisfy whitespace sensitivity.
    DESC

  # We are going to use the flush() method to enact all the group changes we may perform.
  # This will speed up the application of changes, because instead of changing every
  # attribute individually, we coalesce the changes in one script and execute it once.
  def initialize(val = {})
    super(val)
    @property_flush = {}
    @old_member_list = []
    @old_roles_list = []
  end

  def scope(what)
    # (cells/CELL_01/nodes/appNode01/servers/AppServer01
    base_dir = "#{resource[:profile_base]}/#{resource[:dmgr_profile]}"
    query = "/Cell:#{resource[:cell]}"
    mod   = "cells/#{resource[:cell]}"
    file = base_dir + "/config/cells/#{resource[:cell]}/fileRegistry.xml"
    role = base_dir + "/config/cells/#{resource[:cell]}/admin-authz.xml"
    audit = base_dir + "/config/cells/#{resource[:cell]}/audit-authz.xml"

    case what
    when 'audit'
      audit
    when 'role'
      role
    when 'file'
      file
    else
      debug 'Invalid scope request'
    end
  end

  # Create a given group
  def create
    # Get the list of members and roles which need to be assigned to the newly created group
    add_members_string = ''
    add_roles_string = ''

    unless resource[:members].empty?
      add_members_string = resource[:members].map { |e| "'#{e}'" }.join(',')
    end

    unless resource[:roles].empty?
      add_roles_string = resource[:roles].map { |e| "'#{e}'" }.join(',')
    end
  
    cmd = <<-END.unindent
    # Group members to add/remove
    add_member_list = [#{add_members_string}]

    # Roles to add/remove
    add_role_list = [#{add_roles_string}]

    # Set a flag whether we need to reload the security configuration
    roles_changed = 0

    # Create group for #{resource[:groupid]}
    AdminTask.createGroup(['-cn', '#{resource[:groupid]}', '-description', '#{resource[:description]}'])
    AdminConfig.save()

    # Get the groupUniqueName for the target group
    groupUniqueName = AdminTask.searchGroups(['-cn', '#{resource[:groupid]}'])

    # Add members to the group membership for #{resource[:groupid]}
    if len(add_member_list):
      for member_uid in add_member_list:
        memberUniqueName=AdminTask.searchUsers(['-uid', member_uid])

        # If we can't find a user, maybe it is a group we need to add, look for it
        if len(memberUniqueName) == 0:
          memberUniqueName=AdminTask.searchGroups(['-cn', member_uid])

        if len(memberUniqueName):
          AdminTask.addMemberToGroup(['-memberUniqueName', memberUniqueName, '-groupUniqueName', groupUniqueName])

    # Add roles for the #{resource[:groupid]} group
    if len(add_role_list):
      for rolename_id in add_role_list:
          if rolename_id == 'auditor':
            AdminTask.mapGroupsToAuditRole(['-roleName', rolename_id, '-groupids', '#{resource[:groupid]}'])
          else:
            AdminTask.mapGroupsToAdminRole(['-roleName', rolename_id, '-groupids', '#{resource[:groupid]}'])

      # Ensure we refresh/reload the security configuration
      roles_changed = 1

    AdminConfig.save()

    if roles_changed:
      agmBean = AdminControl.queryNames('type=AuthorizationGroupManager,process=dmgr,*')
      AdminControl.invoke(agmBean, 'refreshAll')
    END

    debug "Running command: #{cmd} as user: resource[:user]"
    result = wsadmin(file: cmd, user: resource[:user], failonfail: true)

    if %r{Invalid parameter value "" for parameter "parent config id" on command "create"}.match?(result)
      ## I'd rather handle this in the Jython, but I'm not sure how.
      ## This usually indicates that the server isn't ready on the DMGR yet -
      ## the DMGR needs to do another Puppet run, probably.
      err = <<-EOT
      Could not create group: #{resource[:groupid]}
      This appears to be due to the remote resource not being available.
      Ensure that all the necessary services have been created and are running
      on this host and the DMGR. If this is the first run, the cluster member
      may need to be created on the DMGR.
      EOT

      raise Puppet::Error, err

    end

    debug result
  end

  # Small helper method so we don't repeat ourselves for the fields
  # we have to keep track on and see if they changed. This method is
  # passed a String argument which is the name of the field/sibling
  # we are trying to get the value for. i.e. it can be "wim:cn"
  # or "wim:description" or any other of them.
  #
  def get_groupid_data(field)
    if File.exist?(scope('file'))
      doc = REXML::Document.new(File.open(scope('file')))

      xpath_group_id = XPath.first(doc, "//wim:entities[@xsi:type='wim:Group']/wim:cn[text()='#{resource[:groupid]}']")
      field_data = XPath.first(xpath_group_id, "following-sibling::#{field}") if xpath_group_id

      debug "Getting #{field} for #{resource[:groupid]} elicits: #{field_data}"

      return field_data.text if field_data
    else
      msg = <<-END
      #{scope('file')} does not exist. This may indicate that the cluster
      member has not yet been realized on the DMGR server. Ensure that the
      DMGR has created the cluster member (run Puppet on it?) and that the
      names are correct (e.g. node name, profile name)
      END
      raise Puppet::Error, msg
    end
  end

  # Check to see if a group exists - must return a boolean.
  def exists?
    unless File.exist?(scope('file'))
      return false
    end

    debug "Retrieving value of #{resource[:groupid]} from #{scope('file')}"
    doc = REXML::Document.new(File.open(scope('file')))

    # We're looking for group-id entries matching our group name
    groupid = XPath.first(doc, "//wim:entities[@xsi:type='wim:Group']/wim:cn[text()='#{resource[:groupid]}']")

    debug "Exists? method result for #{resource[:groupid]} is: #{groupid}"

    !groupid.nil?
  end

  # Get a group's description
  def description
    get_groupid_data('wim:description')
  end

  # Set a group's description name
  def description=(val)
    @property_flush[:description] = val
  end

  # Get a group's list of members - users or groups
  def members
    if File.exist?(scope('file'))
      doc = REXML::Document.new(File.open(scope('file')))

      xpath_group_id = XPath.first(doc, "//wim:entities[@xsi:type='wim:Group']/wim:cn[text()='#{resource[:groupid]}']")
      members_data = XPath.match(xpath_group_id, 'following-sibling::wim:members') if xpath_group_id

      debug "Getting wim:members for #{resource[:groupid]} elicits: #{members_data}"

      XPath.each(xpath_group_id, 'following-sibling::wim:members') do |member|
        # The unique_name is something along the lines of:
        # uid=userName,o=defaultWIMFileBasedRealm -> for a user (note the uid=)
        # cn=groupName,o=defaultWIMFileBasedRealm -> for a group (note the cn=)
        unique_name = XPath.first(member, 'wim:identifier/@uniqueName').value

        # Extract the member name: any uid or cn value: remember that .scan() and .match()
        # return an array of matches.
        member_name = unique_name.match(%r{^(?:uid|cn)=(\w+),o=*}).captures.first
        @old_member_list.push(member_name) unless member_name.nil?
      end
      debug "Detected member array for group #{resource[:groupid]} is: #{@old_member_list}"

      # rubocop:disable Style/RedundantReturn
      return @old_member_list
      # rubocop:enable Style/RedundantReturn
    else
      msg = <<-END
      #{scope('file')} does not exist. This may indicate that the cluster
      member has not yet been realized on the DMGR server. Ensure that the
      DMGR has created the cluster member (run Puppet on it?) and that the
      names are correct (e.g. node name, profile name)
      END
      raise Puppet::Error, msg
    end
  end

  # Look up for the roles this group is associated with. Because Websphere uses a silly
  # indirection scheme - we have to find the role_id first, then look up to see what the 
  # corresponding role_name of that role_id is.
  # Once we found them all, we return an array of role_names and let Puppet compare it 
  # with what it should be
  def roles
    if File.exist?(scope('role')) && File.exist?(scope('audit'))

      # Note that there are two locations for the roles: admin and audit which map to
      # two different XML files. They are identical as XML structure but different data.
      # So if a group has audit role - it will be in the audit-authz.xml file.
      admin_doc = REXML::Document.new(File.open(scope('role')))
      audit_doc = REXML::Document.new(File.open(scope('audit')))

      # Find the parents of <groups ... name='blah' /> and get their 'role' attributes
      # We'll need to look each of them up - to find out what they are called.
      # I suppose we could risk it and hardcode the role_id -> role_name mappings
      # but I'm not sure how immutable those mappings are.
      # Also - when you talk about a parent - you gotta specify something to match - hence the *
      #        This used to work in older versions of Ruby - but broke from 2.7.x onwards.
      role_id_array = XPath.match(admin_doc, "/rolebasedauthz:AuthorizationTableExt[@context='domain']/authorizations/groups[@name='#{resource[:groupid]}']/parent::*/@role")
      audit_id_array = XPath.match(audit_doc, "/rolebasedauthz:AuthorizationTableExt[@context='domain']/authorizations/groups[@name='#{resource[:groupid]}']/parent::*/@role")

      # Extract the mapping from the role_id to the real role_name
      # These entries look something similar to this:
      # <roles xmi:id="SecurityRoleExt_2" roleName="operator"/>
      # and we're searching for a matching 'xmi:id' and retrieving the 'roleName'
      # Note the .to_sym conversion - because our arguments are defined as symbols.
      role_id_array.each do |role_id|
        role_name = XPath.first(admin_doc, "/rolebasedauthz:AuthorizationTableExt[@context='domain']/roles[@xmi:id='#{role_id}']/@roleName").value
        @old_roles_list.push(role_name.to_sym) unless role_name.nil?
      end

      audit_id_array.each do |audit_id|
        role_name = XPath.first(audit_doc, "/rolebasedauthz:AuthorizationTableExt[@context='domain']/roles[@xmi:id='#{audit_id}']/@roleName").value
        @old_roles_list.push(role_name.to_sym) unless role_name.nil?
      end

    end

    debug "Member #{resource[:groupid]} is part of the following roles: #{@old_roles_list}"
    # rubocop:disable Style/RedundantReturn
    return @old_roles_list
    # rubocop:enable Style/RedundantReturn
  end

  # Set the roles for the given group
  def roles=(val)
    @property_flush[:roles] = val
  end

  # Set a group's list of members - users or groups
  def members=(val)
    @property_flush[:members] = val
  end

  # Remove a given group - we try to find it first, and if it does exist
  # we remove the group.
  # We also first remove the group from the roles it is in, because if we
  # leave it there, the DMGR dies when you click on the role in the WebUI.
  def destroy
    removable_roles_string = ''
    unless @old_roles_list.empty? 
      removable_roles_string = @old_roles_list.map { |e| "'#{e}'" }.join(',')
    end

    cmd = <<-END.unindent
    remove_role_list = [#{removable_roles_string}]

    # Set a flag whether we need to reload the security configuration
    roles_changed = 0

    # Remove roles for the #{resource[:groupid]} group before we destroy the group
    if len(remove_role_list):
      for rolename_id in remove_role_list:
        if rolename_id == 'auditor':
          AdminTask.removeGroupsFromAuditRole(['-roleName', rolename_id, '-groupids', '#{resource[:groupid]}'])
        else:
          AdminTask.removeGroupsFromAdminRole(['-roleName', rolename_id, '-groupids', '#{resource[:groupid]}'])
      # Ensure we refresh/reload the security configuration
      roles_changed = 1

    uniqueName = AdminTask.searchGroups(['-cn', '#{resource[:groupid]}'])
    if len(uniqueName):
        AdminTask.deleteGroup(['-uniqueName', uniqueName])

    AdminConfig.save()

    if roles_changed:
      agmBean = AdminControl.queryNames('type=AuthorizationGroupManager,process=dmgr,*')
      AdminControl.invoke(agmBean, 'refreshAll')
    END

    debug "Running #{cmd}"
    result = wsadmin(file: cmd, user: resource[:user], failonfail: true)
    debug result
  end

  def flush
    wascmd_args = []
    new_member_list = nil
    new_roles_list = nil

    # If we haven't got anything to modify, we've got nothing to flush. Otherwise
    # parse the list of things to do
    return unless @property_flush
    wascmd_args.push("'-description'", "'#{resource[:description]}'") if @property_flush[:description]
    new_member_list = resource[:members] if @property_flush[:members]
    new_roles_list = resource[:roles] if @property_flush[:roles]

    # If property_flush had something inside, but wasn't what we expected, we really
    # need to bail, because the list of was command arguments will be empty. Ditto for
    # new_member_list and new_roles_list.
    return if wascmd_args.empty? && new_member_list.nil? && new_roles_list.nil?

    # If we do have to run something, prepend the grpUniqueName arguments and make a comma
    # separated string out of the whole array.
    arg_string = wascmd_args.unshift("'-uniqueName'", 'groupUniqueName').join(', ') unless wascmd_args.empty?

    # Initialise these variables, we're going to use them even if they're empty.
    add_members_string = ''
    removable_members_string = ''

    unless new_member_list.nil?
      removable_members_string = (@old_member_list - new_member_list).map { |e| "'#{e}'" }.join(',')
      add_members_string = (new_member_list - @old_member_list).map { |e| "'#{e}'" }.join(',')
    end

    add_roles_string = ''
    removable_roles_string = ''

    unless new_roles_list.nil?
      removable_roles_string = (@old_roles_list - new_roles_list).map { |e| "'#{e}'" }.join(',')
      add_roles_string = (new_roles_list - @old_roles_list).map { |e| "'#{e}'" }.join(',')
    end

    # If we don't have to add any members, and we don't enforce strict group membership, then
    # we don't care about users to remove, so we bail before we execute the Jython code.
    # However, it will complain every time it runs that the arrays look different and that
    # it would attempt to fix them.
    return if add_members_string.empty? && (resource[:enforce_members] != :true)

    cmd = <<-END.unindent
      # Change the Group configuration and/or the group membership for #{resource[:groupid]}
      # When adding group members, this module allows adding other groups, not just users.

      # Get the groupUniqueName for the target group
      groupUniqueName = AdminTask.searchGroups(['-cn', '#{resource[:groupid]}'])

      # Set a flag whether we need to reload the security configuration
      roles_changed = 0

      # Group params to change
      arg_string = [#{arg_string}]

      # Group members to add/remove
      remove_member_list = [#{removable_members_string}]
      add_member_list = [#{add_members_string}]

      # Roles to add/remove
      remove_role_list = [#{removable_roles_string}]
      add_role_list = [#{add_roles_string}]

      if len(groupUniqueName):

        # Update group configuration for #{resource[:groupid]}
        if len(arg_string):
          AdminTask.updateGroup(arg_string)

        # Add members to the group membership for #{resource[:groupid]}
        if len(add_member_list):
          for member_uid in add_member_list:
            memberUniqueName=AdminTask.searchUsers(['-uid', member_uid])

            # If we can't find a user, maybe it is a group we need to add, look for it
            if len(memberUniqueName) == 0:
              memberUniqueName=AdminTask.searchGroups(['-cn', member_uid])

            if len(memberUniqueName):
              AdminTask.addMemberToGroup(['-memberUniqueName', memberUniqueName, '-groupUniqueName', groupUniqueName])

        # Remove members from the group membership for #{resource[:groupid]}
        if len(remove_member_list):
          for member_uid in remove_member_list:
            memberUniqueName=AdminTask.searchUsers(['-uid', member_uid])

            # If we can't find a user, maybe it is a group we need to add, look for it
            if len(memberUniqueName) == 0:
              memberUniqueName=AdminTask.searchGroups(['-cn', member_uid])

            if len(memberUniqueName):
              AdminTask.removeMemberFromGroup(['-memberUniqueName', memberUniqueName, '-groupUniqueName', groupUniqueName])

        # Add roles for the #{resource[:groupid]} group
        if len(add_role_list):
          for rolename_id in add_role_list:
              if rolename_id == 'auditor':
                AdminTask.mapGroupsToAuditRole(['-roleName', rolename_id, '-groupids', '#{resource[:groupid]}'])
              else:
                AdminTask.mapGroupsToAdminRole(['-roleName', rolename_id, '-groupids', '#{resource[:groupid]}'])

          # Ensure we refresh/reload the security configuration
          roles_changed = 1

        # Remove roles for the #{resource[:groupid]} group
        if len(remove_role_list):
          for rolename_id in remove_role_list:
            if rolename_id == 'auditor':
              AdminTask.removeGroupsFromAuditRole(['-roleName', rolename_id, '-groupids', '#{resource[:groupid]}'])
            else:
              AdminTask.removeGroupsFromAdminRole(['-roleName', rolename_id, '-groupids', '#{resource[:groupid]}'])

          # Ensure we refresh/reload the security configuration
          roles_changed = 1

        AdminConfig.save()

        if roles_changed:
          agmBean = AdminControl.queryNames('type=AuthorizationGroupManager,process=dmgr,*')
          AdminControl.invoke(agmBean, 'refreshAll')
        END
    debug "Running #{cmd}"
    result = wsadmin(file: cmd, user: resource[:user], failonfail: true)
    debug "result: #{result}"
  end
end
