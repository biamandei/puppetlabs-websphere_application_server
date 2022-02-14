# frozen_string_literal: true

# Provider for managing websphere cluster members.
# This parses the cluster member's "server.xml" to read current status, but
# uses the 'wsadmin' tool to make changes.  We cannot modify the xml data, as
# it's basically read-only.
#
require_relative '../websphere_helper'

Puppet::Type.type(:websphere_cluster_member).provide(:wsadmin, parent: Puppet::Provider::Websphere_Helper) do
  desc 'wsadmin provider for `websphere_cluster_member`'

  # This is a rather inelegant work-around the get_xml_val() method from the helper class to do
  # an arbitrary number of levels instead of the fixed "three-down-from-the-root".
  # It should be that we modify *that* method, but we are running out of time and can't test
  # everything if we modify it.
  # TODO: update the original get_xml_val() in webpshere_helper.rb
  def get_xml_val2(section, element, attribute, server_xml = nil)

    # If we weren't told where the server.xml file is, we have to
    # piece it together from the fragments we have
    unless server_xml
      serverxml_failure_message = 'Unable to find server xml file.'

      if resource[:profile]
        server_xml = resource[:profile_base] + '/' \
          + resource[:profile] + '/config/cells/' \
          + resource[:cell] + '/nodes/' + resource[:node_name] \
          + '/servers/' + resource[:server] + '/server.xml'
        serverxml_failure_message += " File doesn't exist at '#{server_xml}'."
      end

      if resource[:profile].nil? || !File.exist?(server_xml)
        server_xml = resource[:profile_base] + '/' \
          + resource[:dmgr_profile] + '/config/cells/' \
          + resource[:cell] + '/nodes/' + resource[:node_name] \
          + '/servers/' + resource[:server] + '/server.xml'
        serverxml_failure_message += " File doesn't exist at '#{server_xml}'."
      end

      # File.exists? is a double check if resource[:profile] is set
      raise Puppet::Error, "#{serverxml_failure_message}. Please ensure the server.xml exists in the proper location." unless File.exist?(server_xml)
    end

    unless File.exist?(server_xml)
      raise Puppet::Error, "#{resource[:name]}: "\
        + "Unable to open server.xml at #{server_xml}. Make sure the profile "\
        + 'exists, the node has been federated, a corresponding app instance '\
        + 'exists, and the names are correct. Hint:  The DMGR may need to '\
        + 'Puppet.'
    end

    debug "Using XML file: #{server_xml}"
    doc = REXML::Document.new(File.open(server_xml))

    debug "Looking into the XML doc for section: #{section} , element: #{element}"
    element_entry = XPath.first(doc, "//#{section}/#{element}/")
    debug "Found Section/Element entries: #{element_entry}" if element_entry
  
    value = element_entry.attributes[attribute] if element_entry
    debug "Found: #{server_xml}/#{element}:#{attribute}: #{value}"

    false unless value
    value.to_s
  end

  def exists?
    xml_file = resource[:profile_base] + '/' + resource[:dmgr_profile] + '/config/cells/' + resource[:cell] + '/clusters/' + resource[:cluster] + '/cluster.xml'

    unless File.exist?(xml_file)
      debug "#{xml_file} does not exist!}"
      return false
    end
    doc = REXML::Document.new(File.open(xml_file))
    path = REXML::XPath.first(doc, "//members[@memberName='#{resource[:name]}'][@nodeName='#{resource[:node_name]}']")
    value = REXML::XPath.first(path, '@memberName') if path

    debug "Exists? #{resource[:name]} : #{value}"

    unless value
      debug "#{resource[:name]} does not exist on node #{resource[:node_name]}"
      return false
    end
    true
  end

  def create
    cmd = "\"AdminTask.createClusterMember('[-clusterName "
    cmd += resource[:cluster] + ' -memberConfig [-memberNode ' + resource[:node_name]
    cmd += ' -memberName ' + resource[:name] + ' -memberWeight ' + resource[:weight]
    cmd += ' -genUniquePorts ' + resource[:gen_unique_ports].to_s
    cmd += "]]')\""

    result = wsadmin(command: cmd, user: resource[:user], failonfail: false)
    unless %r{'#{resource[:name]}\(cells\/#{resource[:cell]}\/clusters\/#{resource[:cluster]}}.match?(result)
      msg = "Websphere_cluster_member[#{resource[:name]}]: Failed to "\
               + 'add cluster member. Make sure the node service is running '\
               + "on the remote server. Output: #{result}"
      raise Puppet::Error, "Failed to add cluster member. Run with --debug --trace for details. #{msg}"
    end
    resource.class.validproperties.each do |property|
      value = resource.should(property)
      if value
        @property_hash[property] = value
      end
    end
    true
  end

  def destroy
    cmd = <<-END.unindent
    AdminTask.deleteClusterMember(['-clusterName', '#{resource[:cluster]}', '-memberNode', '#{resource[:node_name]}', '-memberName', '#{resource[:name]}'])
    AdminConfig.save()
    END
    wsadmin(file: cmd, user: resource[:user])
  end

  ## Helper method for modifying JVM properties
  ## This breaks horribly if we are using a Jython List instead of a Jython String. This is because if the arguments contain dashes
  ## they are interpreted as options to Jython, not values to the previous option - so you can't set JVM arguments which contain -Dxxxx
  def jvm_property(name, value)
    cmd = <<-END.unindent
    AdminTask.setJVMProperties('[-nodeName "#{resource[:node_name]}" -serverName "#{resource[:name]}" -#{name} "#{value}"]')
    AdminConfig.save()
    END

    debug "Running command: #{cmd}"
    wsadmin(file: cmd, user: resource[:user])
  end

  def runas_user
    get_xml_val('processDefinitions', 'execution', 'runAsUser')
  end

  def runas_user=(_value)
    cmd = <<-END.unindent
    the_id = AdminConfig.list('ProcessExecution', '(cells/#{resource[:cell]}/nodes/#{resource[:node_name]}/servers/#{resource[:name]}|server.xml)')
    AdminConfig.modify(the_id, [['runAsUser', #{resource[:runas_user]}]])
    AdminConfig.save()
    END
    wsadmin(file: cmd, user: resource[:user])
  end

  def runas_group
    get_xml_val('processDefinitions', 'execution', 'runAsGroup')
  end

  def runas_group=(_value)
    cmd = <<-END.unindent
    the_id = AdminConfig.list('ProcessExecution', '(cells/#{resource[:cell]}/nodes/#{resource[:node_name]}/servers/#{resource[:name]}|server.xml)')
    AdminConfig.modify(the_id, [['runAsGroup', #{resource[:runas_group]}]])
    AdminConfig.save()
    END
    wsadmin(file: cmd, user: resource[:user])
  end

  def umask
    value = get_xml_val('processDefinitions', 'execution', 'umask')
    ## WAS returns an empty string if the umask is set to 022.
    value = '022' if value.nil? || value == ''
    value
  end

  def umask=(_value)
    cmd = <<-END.unindent
    the_id = AdminConfig.list('ProcessExecution', '(cells/#{resource[:cell]}/nodes/#{resource[:node_name]}/servers/#{resource[:name]}|server.xml)')
    AdminConfig.modify(the_id, [['umask', #{resource[:umask]}]])
    AdminConfig.save()
    END
    wsadmin(file: cmd, user: resource[:user])
  end

  def jvm_maximum_heap_size
    get_xml_val('processDefinitions', 'jvmEntries', 'maximumHeapSize')
  end

  def jvm_maximum_heap_size=(_value)
    jvm_property('maximumHeapSize', resource[:jvm_maximum_heap_size])
  end

  def jvm_verbose_mode_class
    get_xml_val('processDefinitions', 'jvmEntries', 'verboseModeClass')
  end

  def jvm_verbose_mode_class=(_value)
    jvm_property('verboseModeClass', resource[:jvm_verbose_mode_class].to_s)
  end

  def jvm_verbose_garbage_collection
    get_xml_val('processDefinitions', 'jvmEntries', 'verboseModeGarbageCollection')
  end

  def jvm_verbose_garbage_collection=(_value)
    jvm_property('verboseModeGarbageCollection', resource[:jvm_verbose_garbage_collection].to_s)
  end

  def jvm_verbose_mode_jni
    get_xml_val('processDefinitions', 'jvmEntries', 'verboseModeJNI')
  end

  def jvm_verbose_mode_jni=(_value)
    jvm_property('verboseModeJNI', resource[:jvm_verbose_mode_jni].to_s)
  end

  def jvm_initial_heap_size
    get_xml_val('processDefinitions', 'jvmEntries', 'initialHeapSize')
  end

  def jvm_initial_heap_size=(_value)
    jvm_property('initialHeapSize', resource[:jvm_initial_heap_size].to_s)
  end

  def jvm_debug_mode
    get_xml_val('processDefinitions', 'jvmEntries', 'debugMode')
  end

  def jvm_debug_mode=(_value)
    jvm_property('debugMode', resource[:jvm_debug_mode])
  end

  def jvm_debug_args
    get_xml_val('processDefinitions', 'jvmEntries', 'debugArgs')
  end

  def jvm_debug_args=(_value)
    jvm_property('debugArgs', "\"#{resource[:jvm_debug_args]}\"")
  end

  def jvm_run_hprof
    get_xml_val('processDefinitions', 'jvmEntries', 'runHProf')
  end

  def jvm_run_hprof=(_value)
    jvm_property('runHProf', resource[:jvm_run_hprof].to_s)
  end

  def jvm_hprof_arguments
    get_xml_val('processDefinitions', 'jvmEntries', 'hprofArguments')
  end

  def jvm_hprof_arguments=(_value)
    # Might need to quote the value
    jvm_property('hprofArguments', "\"#{resource[:jvm_hprof_arguments]}\"")
  end

  def jvm_executable_jar_filename
    value = get_xml_val('processDefinitions', 'jvmEntries', 'executableJarFilename')
    value = '' if value.to_s == ''
    value
  end

  def jvm_executable_jar_filename=(_value)
    # Might need to quote the value
    jvm_property('executableJarFileName', resource[:jvm_executable_jar_filename])
  end

  def jvm_generic_jvm_arguments
    value = get_xml_val('processDefinitions', 'jvmEntries', 'genericJvmArguments')
    ## WAS returns an empty string if the jvm args are default
    value = '' if value.to_s == ''
    value
  end

  def jvm_generic_jvm_arguments=(_value)
    # Might need to quote the value
    jvm_property('genericJvmArguments', resource[:jvm_generic_jvm_arguments])
  end

  def jvm_disable_jit
    get_xml_val('processDefinitions', 'jvmEntries', 'disableJIT')
  end

  def jvm_disable_jit=(_value)
    jvm_property('disableJIT', resource[:jvm_disable_jit].to_s)
  end

  def total_transaction_timeout
    get_xml_val(
      'components[@xmi:type="applicationserver:ApplicationServer"]',
      'services',
      'totalTranLifetimeTimeout',
    )
  end

  def total_transaction_timeout=(_value)
    cmd = <<-END.unindent
    the_id = AdminConfig.list('TransactionService', '(cells/#{resource[:cell]}/nodes/#{resource[:node_name]}/servers/#{resource[:name]}|server.xml)')
    AdminConfig.modify(the_id, [['totalTranLifetimeTimeout', #{resource[:total_transaction_timeout]}]])
    AdminConfig.save()
    END
    wsadmin(file: cmd, user: resource[:user])
  end

  # Do not correct the spelling of the category we're looking for, this is
  # how they spell it in the documentation too.
  def max_transaction_timeout
    get_xml_val(
      'components[@xmi:type="applicationserver:ApplicationServer"]',
      'services',
      'propogatedOrBMTTranLifetimeTimeout',
    )
  end

  def max_transaction_timeout=(_value)
    cmd = <<-END.unindent
    the_id = AdminConfig.list('TransactionService', '(cells/#{resource[:cell]}/nodes/#{resource[:node_name]}/servers/#{resource[:name]}|server.xml)')
    AdminConfig.modify(the_id, [['propogatedOrBMTTranLifetimeTimeout', #{resource[:max_transaction_timeout]}]])
    AdminConfig.save()
    END
    wsadmin(file: cmd, user: resource[:user])
  end

  def client_inactivity_timeout
    get_xml_val(
      'components[@xmi:type="applicationserver:ApplicationServer"]',
      'services',
      'clientInactivityTimeout',
    )
  end

  def client_inactivity_timeout=(_value)
    cmd = <<-END.unindent
    the_id = AdminConfig.list('TransactionService', '(cells/#{resource[:cell]}/nodes/#{resource[:node_name]}/servers/#{resource[:name]}|server.xml)')
    AdminConfig.modify(the_id, [['clientInactivityTimeout', #{resource[:client_inactivity_timeout]}]])
    AdminConfig.save()
    END
    wsadmin(file: cmd, user: resource[:user])
  end

  def threadpool_webcontainer_min_size
    get_xml_val(
      'services[@xmi:type="threadpoolmanager:ThreadPoolManager"]',
      'threadPools[@name="WebContainer"]',
      'minimumSize',
    )
  end

  def threadpool_webcontainer_min_size=(_value)
    ## (J|P)ython is whitespace sensitive, and this bit doesn't do well when
    ## being passed as a normal command-line argument.
    cmd = <<-END.unindent
      the_id=AdminConfig.getid('/Node:#{resource[:node_name]}/Server:#{resource[:name]}/')
      tpList=AdminConfig.list('ThreadPool', the_id).split(lineSeparator)
      for tp in tpList:
        if tp.count('WebContainer') == 1:
          tpWebContainer=tp
      AdminConfig.modify(tpWebContainer, [['minimumSize', #{resource[:threadpool_webcontainer_min_size]}]])
      AdminConfig.save()
    END
    wsadmin(file: cmd, user: resource[:user])
  end

  def threadpool_webcontainer_max_size
    get_xml_val(
      'services[@xmi:type="threadpoolmanager:ThreadPoolManager"]',
      'threadPools[@name="WebContainer"]',
      'maximumSize',
    )
  end

  def threadpool_webcontainer_max_size=(_value)
    ## (J|P)ython is whitespace sensitive, and this bit doesn't do well when
    ## being passed as a normal command-line argument.
    cmd = <<-END.unindent
      the_id=AdminConfig.getid('/Node:#{resource[:node_name]}/Server:#{resource[:name]}/')
      tpList=AdminConfig.list('ThreadPool', the_id).split(lineSeparator)
      for tp in tpList:
        if tp.count('WebContainer') == 1:
          tpWebContainer=tp
      AdminConfig.modify(tpWebContainer, [['maximumSize', #{resource[:threadpool_webcontainer_max_size]}]])
      AdminConfig.save()
    END
    wsadmin(file: cmd, user: resource[:user])
    refresh
  end

  def mls_thread_inactivity_timeout
    get_xml_val2(
      'services[@xmi:type="applicationserver.ejbcontainer.messagelistener:MessageListenerService"]',
      'threadPool[@name="Message.Listener.Pool"]',
      'inactivityTimeout',
    )
  end

  def mls_thread_inactivity_timeout=(_value)
    cmd = <<-END.unindent
      the_id=AdminConfig.getid('/Node:#{resource[:node_name]}/Server:#{resource[:name]}/')
      tpList=AdminConfig.list('ThreadPool', the_id).split(lineSeparator)
      for tp in tpList:
        if tp.count('Message.Listener.Pool') == 1:
          tpMessageListenerPool=tp
      AdminConfig.modify(tpMessageListenerPool, [['inactivityTimeout', #{resource[:mls_thread_inactivity_timeout]}]])
      AdminConfig.save()
    END
    wsadmin(file: cmd, user: resource[:user])
  end

  def mls_threadpool_min_size
    get_xml_val2(
      'services[@xmi:type="applicationserver.ejbcontainer.messagelistener:MessageListenerService"]',
      'threadPool[@name="Message.Listener.Pool"]',
      'minimumSize',
    )
  end

  def mls_threadpool_min_size=(_value)
    cmd = <<-END.unindent
      the_id=AdminConfig.getid('/Node:#{resource[:node_name]}/Server:#{resource[:name]}/')
      tpList=AdminConfig.list('ThreadPool', the_id).split(lineSeparator)
      for tp in tpList:
        if tp.count('Message.Listener.Pool') == 1:
          tpMessageListenerPool=tp
      AdminConfig.modify(tpMessageListenerPool, [['minimumSize', #{resource[:mls_threadpool_min_size]}]])
      AdminConfig.save()
    END
    wsadmin(file: cmd, user: resource[:user])
  end

  def mls_threadpool_max_size
    get_xml_val2(
      'services[@xmi:type="applicationserver.ejbcontainer.messagelistener:MessageListenerService"]',
      'threadPool[@name="Message.Listener.Pool"]',
      'maximumSize',
    )
  end

  def mls_threadpool_max_size=(_value)
    cmd = <<-END.unindent
      the_id=AdminConfig.getid('/Node:#{resource[:node_name]}/Server:#{resource[:name]}/')
      tpList=AdminConfig.list('ThreadPool', the_id).split(lineSeparator)
      for tp in tpList:
        if tp.count('Message.Listener.Pool') == 1:
          tpMessageListenerPool=tp
      AdminConfig.modify(tpMessageListenerPool, [['maximumSize', #{resource[:mls_threadpool_max_size]}]])
      AdminConfig.save()
    END
    wsadmin(file: cmd, user: resource[:user])
  end

  def refresh
    flush
  end
end
