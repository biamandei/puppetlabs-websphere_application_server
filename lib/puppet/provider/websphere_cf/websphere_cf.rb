# frozen_string_literal: true

require 'English'
require_relative '../websphere_helper'

Puppet::Type.type(:websphere_cf).provide(:wsadmin, parent: Puppet::Provider::Websphere_Helper) do
  desc <<-DESC
    Provider to manage or create a connection factory for the IBM MQ messaging provider at a specific scope.

    Please see the IBM documentation available at:
    https://www.ibm.com/docs/en/was/9.0.5?topic=scripting-createwmqconnectionfactory-command

    It is recommended to consult the IBM documentation as the JMS connection factory subject is very
    complex and difficult to abstract.

    This provider will not allow the creation of a dummy instance (i.e. no MQ server target)
    This provider will now allow the changing of the type of a Connection Factory. You need
    to destroy it first, then create another one of the desired type.

    We execute the 'wsadmin' tool to query and make changes, which interprets
    Jython. This means we need to use heredocs to satisfy whitespace sensitivity.
    DESC

  # We are going to use the flush() method to enact all the changes we may perform.
  # This will speed up the application of changes, because instead of changing every
  # attribute individually, we coalesce the changes in one script and execute it once.
  def initialize(val = {})
    super(val)
    @property_flush = {}
    @old_qmgr_data = {}
    @old_conn_pool_data = {}
    @old_sess_pool_data = {}
    @old_mapping_data = {}
  end

  def scope(what)
    file = "#{resource[:profile_base]}/#{resource[:dmgr_profile]}"
    case resource[:scope]
    when 'cell'
      query = "/Cell:#{resource[:cell]}"
      mod   = "cells/#{resource[:cell]}"
      file += "/config/cells/#{resource[:cell]}/resources.xml"
    when 'cluster'
      query = "/Cell:#{resource[:cell]}/ServerCluster:#{resource[:cluster]}"
      mod   = "cells/#{resource[:cell]}/clusters/#{resource[:cluster]}"
      file += "/config/cells/#{resource[:cell]}/clusters/#{resource[:cluster]}/resources.xml"
    when 'node'
      query = "/Cell:#{resource[:cell]}/Node:#{resource[:node_name]}"
      mod   = "cells/#{resource[:cell]}/nodes/#{resource[:node_name]}"
      file += "/config/cells/#{resource[:cell]}/nodes/#{resource[:node_name]}/resources.xml"
    when 'server'
      query = "/Cell:#{resource[:cell]}/Node:#{resource[:node_name]}/Server:#{resource[:server]}"
      mod   = "cells/#{resource[:cell]}/nodes/#{resource[:node_name]}/servers/#{resource[:server]}"
      file += "/config/cells/#{resource[:cell]}/nodes/#{resource[:node_name]}/servers/#{resource[:server]}/resources.xml"
    else
      raise Puppet::Error, "Unknown scope: #{resource[:scope]}"
    end

    case what
    when 'query'
      query
    when 'mod'
      mod
    when 'file'
      file
    else
      debug 'Invalid scope request'
    end
  end

  # Create a Connection Factory
  def create  
    cmd = <<-END.unindent
    import AdminUtilities

    # Global variable within this script
    bundleName = "com.ibm.ws.scripting.resources.scriptLibraryMessage"
    resourceBundle = AdminUtilities.getResourceBundle(bundleName)

    def createWMQConnectionFactory(scope, cftype, name, jndiName, otherAttrsList=[], failonerror=AdminUtilities._BLANK_ ):
      if (failonerror==AdminUtilities._BLANK_):
          failonerror=AdminUtilities._FAIL_ON_ERROR_
      #endIf
      msgPrefix = "createWMQConnectionFactory(" + `scope` + ", " + `cftype`+ ", " + `name`+ ", " + `jndiName` + ", " + `otherAttrsList` + `failonerror`+"): "
  
      try:
          #--------------------------------------------------------------------
          # Create a WMQ Connection Factory
          #--------------------------------------------------------------------
          print "---------------------------------------------------------------"
          print " AdminJMS:               createWMQConnectionFactory "
          print " Scope:                      "
          print "     scope:                  "+scope
          print " Type:                       "
          print "     type:                   "+cftype
          print " MQConnectionFactory:        "
          print "     name:                   "+name
          print "     jndiName:               "+jndiName
          print " Optional Parameters :                   "
          print "   otherAttributesList:        %s" % otherAttrsList
          print "     maxBatchSize            "
          print "     brokerCCSubQueue        "
          print "     brokerCtrlQueue         "
          print "     brokerQmgr              "
          print "     brokerSubQueue          "
          print "     brokerVersion           "
          print "     brokerPubQueue          "
          print "     ccdtQmgrName            "
          print "     ccdtUrl                 "
          print "     ccsid                   "
          print "     cleanupInterval         "
          print "     cleanupLevel            "
          print "     clientId                "
          print "     clonedSubs              "
          print "     compressHeaders         "
          print "     compressPayload         "
          print "     containerAuthAlias      "
          print "     description             "
          print "     failIfQuiescing         "
          print "     localAddress            "
          print "     mappingAlias            "
          print "     modelQueue              "
          print "     msgRetention            "
          print "     msgSelection            "
          print "     pollingInterval         "
          print "     providerVersion         "
          print "     pubAckInterval          "
          print "     qmgrHostname            "
          print "     qmgrName                "
          print "     qmgrPortNumber          "
          print "     qmgrSvrconnChannel      "
          print "     rcvExitInitData         "
          print "     rcvExit                 "
          print "     replyWithRFH2           "
          print "     rescanInterval          "
          print "     secExitInitData         "
          print "     secExit                 "
          print "     sendExitInitData        "
          print "     sendExit                "
          print "     sparseSubs              "
          print "     sslConfiguration        "
          print "     sslCrl                  "
          print "     sslPeerName             "
          print "     sslResetCount           "
          print "     sslType                 "
          print "     stateRefreshInt         "
          print "     subStore                "
          print "     support2PCProtocol      "
          print "     tempQueuePrefix         "
          print "     tempTopicPrefix         "
          print "     wildcardFormat          "
          print "     wmqTransportType        "
          print "     xaRecoveryAuthAlias     "
          print " "
          if (otherAttrsList == []):
            print " Usage: AdminJMS.createWMQConnectionFactory(\"" + scope + "\", \"" + cftype + "\", \"" + name + "\" , \"" + jndiName + "\")"
          else:
            if (str(otherAttrsList).startswith("[[") > 0 and str(otherAttrsList).startswith("[[[",0,3) == 0):
                print " Usage: AdminJMS.createWMQConnectionFactory(\"" + scope + "\", \"" + cftype + "\", \"" + name + "\" , \"" + jndiName + "\", %s)" % (otherAttrsList)
            else:
                # d714926 check if script syntax error
                if (str(otherAttrsList).startswith("[",0,1) > 0 or str(otherAttrsList).startswith("[[[",0,3) > 0):
                   raise AttributeError(AdminUtilities._formatNLS(resourceBundle, "WASL6049E", [otherAttrsList]))
                else:
                   if (otherAttrsList.find("\"") > 0):
                      otherAttrsList = otherAttrsList.replace("\"", "\'")
                   print " Usage: AdminJMS.createWMQConnectionFactory(\"" + scope + "\", \"" + cftype + "\", \"" + name + "\" , \"" + jndiName + "\", \"" + str(otherAttrsList) + "\")"
          print " Return: The Configuration Id of the new WMQ Connection Factory"
          print "---------------------------------------------------------------"
          print " "
          print " "

          # Make sure required parameters are non-empty
          if (len(scope) == 0):
            raise AttributeError(AdminUtilities._formatNLS(resourceBundle, "WASL6041E", ["scope", scope]))
          if (len(cftype) == 0):
            raise AttributeError(AdminUtilities._formatNLS(resourceBundle, "WASL6041E", ["type", cftype]))
          if (len(name) == 0):
            raise AttributeError(AdminUtilities._formatNLS(resourceBundle, "WASL6041E", ["name", name]))
          if (len(jndiName) == 0):
            raise AttributeError(AdminUtilities._formatNLS(resourceBundle, "WASL6041E", ["jndiName", jndiName]))

          # Validate the scope
          # We will end up with a containment path for the scope - convert that to the config id which is needed.
          if (scope.find(".xml") > 0 and AdminConfig.getObjectType(scope) == None):
            raise AttributeError(AdminUtilities._formatNLS(resourceBundle, "WASL6040E", ["scope", scope]))
          scopeContainmentPath = AdminUtilities.getScopeContainmentPath(scope)
          configIdScope = AdminConfig.getid(scopeContainmentPath)

          # If at this point, we don't have a proper config id, then the scope specified was incorrect
          if (len(configIdScope) == 0):
            raise AttributeError(AdminUtilities._formatNLS(resourceBundle, "WASL6040E", ["scope", scope]))

          # Prepare the parameters for the AdminTask command - set the implied type of CF in this case
          otherAttrsList = AdminUtilities.convertParamStringToList(otherAttrsList)
          requiredParameters = [["name", name], ["jndiName", jndiName], ["type", cftype]]
          finalAttrsList = requiredParameters + otherAttrsList
          finalParameters = []
          for attrs in finalAttrsList:
            attr = ["-"+attrs[0], attrs[1]]
            finalParameters = finalParameters+attr

          # Call the corresponding AdminTask command
          AdminUtilities.debugNotice("About to call AdminTask command with target : " + str(configIdScope))
          AdminUtilities.debugNotice("About to call AdminTask command with parameters : " + str(finalParameters))
          newObjectId = AdminTask.createWMQConnectionFactory(configIdScope, finalParameters)
          newObjectId = str(newObjectId)

          AdminConfig.save()

          # Return the config ID of the newly created object
          AdminUtilities.debugNotice("Returning config id of new object : " + str(newObjectId))
          return newObjectId

      except:
        typ, val, tb = sys.exc_info()
        if (typ==SystemExit):  raise SystemExit,`val`
        if (failonerror != AdminUtilities._TRUE_):
            print "Exception: %s %s " % (sys.exc_type, sys.exc_value)
            val = "%s %s" % (sys.exc_type, sys.exc_value)
            raise Exception("ScriptLibraryException: " + val)
        else:
            return AdminUtilities.fail(msgPrefix+AdminUtilities.getExceptionText(typ, val, tb), failonerror)
        #endIf
      #endTry
    #endDef

    scope = '/ServerCluster:CBIS_inf_st1_cluster/'

    cftype = "QCF"
    name = "PUPQCF"
    jndiName = "jms/PUPQCF"
    attrs = [['description', 'Puppet PUPQCF Queue Connection Factory'], ['XAEnabled', 'true'], ['queueManager', 'PUPP.SUPP.QMGR'], ['host', 'host1.fqdn.com'], ['port', '2000'], ['channel', 'PUP'], ['transportType', 'CLIENT'], ['tempModel', 'SYSTEM.DEFAULT.MODEL.QUEUE'], ['clientID', 'mqm'], ['CCSID', '819'], ['failIfQuiesce', 'true'], ['pollingInterval', '5000'], ['rescanInterval', '5000'], ['sslResetCount', '0'], ['sslType', 'SPECIFIC'], ['sslConfiguration', 'WAS2MQ'], ['connameList', 'host1.fqdn.com(2000),host2.fqdn.com(2000)'], ['clientReconnectOptions', 'DISABLED'], ['clientReconnectTimeout', '1800']]

    # Enable debug notices
    AdminUtilities.setDebugNotices(1)

    createWMQConnectionFactory(scope, cftype, name, jndiName, attrs)

    END

    debug "Running command: #{cmd} as user: #{resource[:user]}"
    result = wsadmin(file: cmd, user: resource[:user], failonfail: false)

    if %r{Invalid parameter value "" for parameter "parent config id" on command "create"}.match?(result)
      ## I'd rather handle this in the Jython, but I'm not sure how.
      ## This usually indicates that the server isn't ready on the DMGR yet -
      ## the DMGR needs to do another Puppet run, probably.
      err = <<-EOT
      Could not create Connection Factory: #{resource[:cf_name]} of type #{resource[:cf_type]}
      This appears to be due to the remote resource not being available.
      Ensure that all the necessary services have been created and are running
      on this host and the DMGR. If this is the first run, the cluster member
      may need to be created on the DMGR.
      EOT

      raise Puppet::Error, err

    end

    debug result
  end

  # Check to see if a Connection Factory exists - must return a boolean.
  def exists?
    unless File.exist?(scope('file'))
      return false
    end

    # This sounds mad, but it is possible to store different strange objects as
    # resources. I've found .zip and .XML files so far stored as resourceProperties
    # at which point parsing the resources.xml file becomes incredibly slow (40seconds)
    # and intensive. The easiest way out of this is to excise those resourceProperties
    # based on a regexp and pass the remaining XML to the DOM parser.
    #
    # What we are trying to remove are constructs of this type:
    # <resourceProperties xmi:id="J2EEResourceProperty_1499488858500" name="widgetFeedUrlMap.xml" value="&lt;?xml version=&quot;..." ...>
    # <resourceProperties xmi:id="J2EEResourceProperty_1499488861016" name="SolutionAdministration.zip" value="UEsDBAoAAAAIABIaa..." ...>
    #
    # This is making an educated guess that you are not trying to admin something of
    # this kind. If you do, you have my condolences for your dearly departed sanity.
    xml_content = nil
    if resource[:sanitize] == :true && ( !resource[:ignored_names].empty? )
      suffix_list = resource[:ignored_names].join('|')
      File.open(scope('file')).each_line do |line|
        xml_content += line unless /<resourceProperties.*name="\w+\.(#{suffix_list})"/.match?(line)
      end
    else
      xml_content = File.open(scope('file'))
    end

    debug "Retrieving value of #{resource[:jms_provider]}/#{resource[:cf_name]} from #{scope('file')}"
    doc = REXML::Document.new(xml_content)

    # We're looking for Connection Factory entries matching our cf_name. We have to ensure we're looking under the
    # correct provider entry.
    jms_entry = XPath.first(doc, "/xmi:XMI[@xmlns:resources.jms.mqseries]/resources.jms:JMSProvider[@xmi:id='#{resource[:jms_provider]}']")
    cf_entry = XPath.first(jms_entry, "factories[@name='#{resource[:cf_name]}']") unless jms_entry.nil?

    # Populate the @old_qmgr_data by discovering what are the params for the given Connection Factory
    debug "Exists? method is loading existing QMGR data attributes/values:"
    XPath.each(jms_entry, "factories[@name='#{resource[:cf_name]}']/@*")  { |attr|
      debug "#{attr.name} => #{attr.value}"
      @old_qmgr_data[attr.name.to_sym] = attr.value
    } unless cf_entry.nil?

    # Extract the connectionPool attributes
    XPath.each(cf_entry, "connectionPool/@*")  { |attr|
      debug "#{attr.name} => #{attr.value}"
      @old_conn_pool_data[attr.name] = attr.value
    } unless cf_entry.nil?

    # Extract the sessionPool attributes
    XPath.each(cf_entry, "sessionPool/@*")  { |attr|
      debug "#{attr.name} => #{attr.value}"
      @old_sess_pool_data[attr.name] = attr.value
    } unless cf_entry.nil?

    # Extract the Auth mapping attributes
    XPath.each(cf_entry, "mapping/@*")  { |attr|
      debug "#{attr.name} => #{attr.value}"
      @old_mapping_data[attr.name] = attr.value
    } unless cf_entry.nil?

    debug "Exists? method result for #{resource[:cf_name]} is: #{cf_entry}"

    !cf_entry.nil?
  end

  # Get a CF's JNDI
  def jndi_name
    @old_qmgr_data[:jndi_name]
  end

  # Set a CF's JNDI
  def jndi_name=(val)
    @property_flush[:jndi_name] = val
  end

  # Get a CF's description
  def description
    @old_qmgr_data[:description]
  end

  # Set a CF's description
  def description=(val)
    @property_flush[:description] = val
  end

  # Get a CF's QMGR Settings
  def qmgr_data
    @old_qmgr_data
  end

  # Set a CF's QMGR Settings
  def qmgr_data=(val)
    @property_flush[:qmgr_data] = val
  end

  # Get a CF's Auth mapping data
  def mapping_data
    @old_mapping_data
  end

  # Set a CF's connection pool data
  def mapping_data=(val)
    @property_flush[:mapping_data] = val
  end

  # Get a CF's connection pool data
  def conn_pool_data
    @old_conn_pool_data
  end

  # Set a CF's connection pool data
  def conn_pool_data=(val)
    @property_flush[:conn_pool_data] = val
  end

  # Get a CF's session pool data
  def sess_pool_data
    @old_sess_pool_data
  end

  # Set a CF's session pool data
  def sess_pool_data=(val)
    @property_flush[:sess_pool_data] = val
  end

  # Remove a given Connection Factory - we try to find it first
  def destroy
    cmd = <<-END.unindent

    AdminConfig.save()
    END

    debug "Running #{cmd}"
    result = wsadmin(file: cmd, user: resource[:user])
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
    result = wsadmin(file: cmd, user: resource[:user])
    debug "result: #{result}"
  end
end
