##############################################################################################################
### Puppet Plan Details
##############################################################################################################
###
### Plan Name: websphere_application_server::create_repo
###
### Summary: Creates a copy of an IBM Webphere Application Server Repository
###
### Originally Written: 
###   By: Paul Reed (paul.reed@puppet.com)
###   Date: 2020-01-15
###
### Description:
###   This plan is designed to ease in the installation of IBM Websphere Application Server while using the 
###   Puppet modules from the Puppet Forge. This plan will create a file repository clone on a remote Linux 
###   server from which the Puppet Websphere Module can use as an installation source.
###   Also included in this plan is the capabily to list available packages and fixes available for those 
###   packages given a specific IBM repo url (and package id in the case of FixPacks).
###   You can use this plan to either create a local repo on a host to install WebSphere on that host, or 
###   create a repo on a selected host and then share it on the network to use for installation to other hosts.
###
### Requirements: 
###   This plan is designed to run from either MacOS, Linux or a Windows workstation (using WSL). The target
###   OS is Linux, however this plan was only testing using CentOS 7 specifically. You should be able to 
###   adapt to any Linux OS target by modifying the binary location variables either on the command line or
###   through the params.json input file.
###   When using bolt, you will need to add this module into the Puppetfile and have bolt install the module
###   with "bolt puppetfile install" to make the plan available to bolt.
###
###   Most of the variable defaults should get you what you need, but you must provide a local copy of the
###   IBM Packaging Utility zipfile for Linux. This can be freely downloaded from IBM using your IBM ID
###   (which only requires free registration on IBM's support site). The Packaging Utility can be found here:
###   https://www-945.ibm.com/support/fixcentral/swg/selectFixes?parent=ibm%7ERational&product=ibm/Rational/IBM+Packaging+Utility&platform=Linux
###   The required zipfile *should* be the first one in this list (as of 2020-01-15) and labelled as 
###   "fix pack: 1.9.1.1-IBMPU-LINUX-X86_64-20191112_1636". Feel free to try a newer version of the utility
###   if one becomes avaialble.
###
### Required Inputs:
###   This plan requires at least the following inputs be supplied via command line or through the 
###   params.json input file.
###
###      'package_utility_zipfile':              - The IBM Packaging Utility zipfile
###      'ibm_id_user':                          - The username for your IBM ID*
###      'ibm_id_password':                      - The password for your IBM ID*
###      'ibm_credential_store_main_password': - A main password used to encrypt credentials on the remote host
###
###       *Note: An IBM ID is required even to access the IBM WAS trial repositories.
###
### Example Usage:
###
###   "bolt plan run websphere_application_server::create_repo --targets <remote_host> --params=@<create_repo.params.json>"
###
###    Notes: See the 'create_repo.params.json' example file (in the module /examples/plans folder) for an example of 
###           how to use the json file for input. Yes, you need the '@' symbol in front of filename for the params 
###           input file, unless you want to just supply straight json on the command line (not recommended).
###
###           All variables listed in the top section of this plan can be overriden using the json input file.
###           The example file will list the avaialable packages in the supplied repo, but not make a copy, unless
###           the 'stage_copy_repo' variable is changed to 'true'. 
###
###           Also note that the copy repo stage of this plan will only copy the repo for the selected package id 
###           (including FixPacks). If you need more than a specific single Package (and it's FixPacks), you 
###           will need to run this plan for each additional package.
###
###           Although targets in this plan is plural, this plan was designed to run against a single target.
###           It will likely still work againsts multiple targets, but has not been tested for it.
###  
##############################################################################################################

plan websphere_application_server::create_repo (
  ##########
  ## Required Inputs
  TargetSpec $targets,
  String     $package_utility_zipfile,
  String     $ibm_id_user,
  String     $ibm_id_password,
  String     $ibm_credential_store_main_password,

  ##########
  ## Optional Overrides, 
  Optional[String[1]] $was_repo              = 'http://www.ibm.com/software/repositorymanager/com.ibm.websphere.NDTRIAL.v85',
  Optional[String[1]] $package_id            = 'com.ibm.websphere.NDTRIAL.v85_8.5.5016.20190801_0951',
  Optional[String[1]] $repo_directory        = '/var/ibm/ibm_packages',
  Optional[String[1]] $credential_file       = '/home/credential.store',
  Optional[String[1]] $main_password_file  = '~/master_password_file.txt',
  # This variable enables long listing format when listing packages and fixpacks
  Optional[Boolean]   $long_listing_format             = false,

  ##########
  ## Short circuit options to only run parts of the plan if desired.
  ## ie, you may want to only list packages or fixpacks for a particular package without the repo_copy
  Optional[Boolean] $stage_upload_ibm_pu               = true,
  Optional[Boolean] $stage_unzip_ibm_pu                = true,
  Optional[Boolean] $stage_install_ibm_pu              = true,
  # Note: The main_password_file stage is required for many following stages and should always be left on.
  Optional[Boolean] $stage_create_main_password_file = true,
  Optional[Boolean] $stage_store_credentials           = true,
  Optional[Boolean] $stage_list_packages               = true,
  Optional[Boolean] $stage_list_fixes                  = true,
  Optional[Boolean] $stage_copy_repo                   = true,
  Optional[Boolean] $stage_remove_main_password_file = true,

  ##########
  # Binary locations, likely only need to override if not found in path
  Optional[String[1]] $shell_local    = '/bin/sh',
  Optional[String[1]] $shell_remote   = '/bin/sh',
  Optional[String[1]] $openssl_local  = 'openssl',
  Optional[String[1]] $openssl_remote = 'openssl',
  Optional[String[1]] $awk_remote     = 'awk',
  Optional[String[1]] $awk_local      = 'awk',
  Optional[String[1]] $unzip_remote   = 'unzip',
  Optional[String[1]] $touch_remote   = 'touch',
  Optional[String[1]] $chmod_remote   = 'chmod',
  Optional[String[1]] $echo_remote    = 'echo',

  ##########
  ## remote locations for pu installer files, you can modify these, but its likely not necessary
  Optional[String[1]] $remote_install_dir    = '/opt/ibm_pu_installer',
  Optional[String[1]] $remote_ibm_pu_zipfile = 'ibm_pu.zip',

  ##########
  # In case future versions of the IBM tools expand/install in different locations
  # Otherwise, you shouldn't need to modify/override these at all
  Optional[String[1]] $remote_unzipped_location = "${remote_install_dir}/disk_linux.gtk.x86_64/InstallerImage_linux.gtk.x86_64/",
  Optional[String[1]] $pu_install_command       = "${remote_unzipped_location}/installc -acceptLicense",
  Optional[String[1]] $im_basedir               = '/opt/IBM/InstallationManager',
  Optional[String[1]] $imutilsc                 = "${im_basedir}/eclipse/tools/imutilsc",
  Optional[String[1]] $pucl                     = '/opt/IBM/PackagingUtility/PUCL',

) {
  ##############################################################################################################
  ## Upload IBM Package Utility Zipfile to Remote Host
  ##########
  if $stage_upload_ibm_pu {
    ## Create Remote Installers Directory
    run_command("sh -c \"
      [ ! -d '${remote_install_dir}' ] && mkdir -p \\\"${remote_install_dir}\\\";
      echo \\\"\\\"
      \"",
    $targets, 'Ensuring Installation Directory Exists','_run_as' => 'root')

    ## Check local and remote MD5 (to avoid download and save time if it's already the same file)
    if file::exists($package_utility_zipfile) {
      $local_file_check=run_command("${shell_local} -c \"
        if [ -f ${package_utility_zipfile} ]; then
          ${openssl_local} md5 -r \\\"${package_utility_zipfile}\\\" | ${awk_local} '{print \\\$1}';
        fi
        \"",
      'localhost','Checking MD5SUM for Local File')

      $local_md5=$local_file_check.first.to_data['result']['stdout']

      $remote_file_check=run_command("${shell_remote} -c \"
        if [ -f \\\"${remote_install_dir}/${remote_ibm_pu_zipfile}\\\" ]; then
          ${openssl_remote} md5 -r \\\"${remote_install_dir}/${remote_ibm_pu_zipfile}\\\" | ${awk_remote} '{print \\\$1}';
        fi
        \"",
      $targets,'Checking MD5SUM for Remote File (if it exists)','_run_as' => 'root')

      $remote_md5=$remote_file_check.first.to_data['result']['stdout']

      if ($local_md5 != '') {
        out::message("MD5SUM Local: ${local_md5}")
        out::message("MD5SUM Remote: ${remote_md5}")
        if ($remote_md5 == $local_md5) {
          out::message('MD5SUM of remote and local files match. Upload not required.')
        }
        else {
          out::message('MD5SUM mismatch or file does not exist at remote location. Uploading file...')
          upload_file($package_utility_zipfile,"${remote_install_dir}/${remote_ibm_pu_zipfile}",$targets,'_run_as' => 'root')
        }
      }
      else {
        fail_plan("MD5SUM empty for provided 'package_utility_zipfile': '${package_utility_zipfile}'.")
      }
    }
    else {
    fail_plan("IBM Package Utility either was not specified or does not exist at provided location.\n
      Specified 'package_utility_zipfile': '${package_utility_zipfile}'")
    }
  }

  ##############################################################################################################
  ## Unzip the IBM Package Utility on the Remote Host
  ##########
  if $stage_unzip_ibm_pu {
    ## Unzip the package utility files, with overwrite
    run_command("${shell_remote} -c \"cd \\\"${remote_install_dir}\\\"; ${unzip_remote} -o \\\"${remote_ibm_pu_zipfile}\\\" > /dev/null\"",
    $targets, 'Unzipping IBM Package Utility', '_run_as' => 'root')
  }

  ##############################################################################################################
  ## Run the IBM Package Utility installer on the Remote Host
  ##########
  if $stage_install_ibm_pu {
    run_command("${shell_remote} -c \"${pu_install_command}\"", $targets, 'Install IBM Package Utility', '_run_as' => 'root')
  }

  ##############################################################################################################
  ## Create a main password file for encrypting the IBM credentials store
  ## Note: This cleartext file is removed later unless 'remove_main_password_file' is set to false.
  ##       It may also be accidentally left on the remote system if this plan fails for any reason.
  ##########
  if $stage_create_main_password_file {
    run_command("${shell_remote} -c \"${touch_remote} ${main_password_file}; 
    ${chmod_remote} 700 ${main_password_file};
    ${echo_remote} \\\"${ibm_credential_store_main_password}\\\" > ${main_password_file}; \"",
    $targets, 'Create master password file for the IBM credentials store', '_run_as' => 'root')
  }

  ##############################################################################################################
  ## Store IBM ID Credentials on remote host for repository downloads
  ## IBM Documentation: https://www.ibm.com/support/knowledgecenter/en/SSDV2W_1.8.5/com.ibm.cic.commandline.doc/topics/t_store_credentials_pu.html
  ##########
  if $stage_store_credentials {
    run_command("${shell_remote} -c \"${imutilsc} saveCredential \
        -url ${was_repo} \
        -userName ${ibm_id_user} \
        -userPassword ${ibm_id_password} \
        -secureStorageFile ${credential_file} \
        -masterPasswordFile ${main_password_file}; \"",
    $targets, "Securely save IBM ID Credentials to ${credential_file}", '_run_as' => 'root')
  }

  ##############################################################################################################
  ## List available packages in selected repository
  ## IBM Documentation: https://www.ibm.com/support/knowledgecenter/en/SSDV2W_1.8.5/com.ibm.cic.commandline.doc/topics/t_pucl_viewing_available_packages.html
  ##########
  if $stage_list_packages {
    if $long_listing_format {
      $packages_result=run_command("${shell_remote} -c \"${pucl} listAvailablePackages \
          -repositories ${was_repo} \
          -secureStorageFile ${credential_file} \
          -masterPasswordFile ${main_password_file} \
          -long; \"",
      $targets, "List Repository Available Packages from ${was_repo}", '_run_as' => 'root')
    }
    else {
      $packages_result=run_command("${shell_remote} -c \"${pucl} listAvailablePackages \
          -repositories ${was_repo} \
          -secureStorageFile ${credential_file} \
          -masterPasswordFile ${main_password_file}; \"",
      $targets, "List Repository Available Packages from ${was_repo}", '_run_as' => 'root')
    }

    out::message("Available Packages:\n${packages_result.first.to_data['result']['stdout']}")
  }

  ##############################################################################################################
  ## List available fixes in selected repository
  ## IBM Documentation: https://www.ibm.com/support/knowledgecenter/en/SSDV2W_1.8.5/com.ibm.cic.commandline.doc/topics/t_pucl_viewing_available_fixes.html
  ##########
  if $stage_list_fixes {
    if $long_listing_format {
      $fixes_result=run_command("${shell_remote} -c \"${pucl} listAvailableFixes ${package_id} \
          -repositories ${was_repo} \
          -secureStorageFile ${credential_file} \
          -masterPasswordFile ${main_password_file} \
          -long; \"",
      $targets, "List Repository Available Fixes for ${package_id} from ${was_repo}", '_run_as' => 'root')
    }
    else {
      $fixes_result=run_command("${shell_remote} -c \"${pucl} listAvailableFixes ${package_id} \
          -repositories ${was_repo} \
          -secureStorageFile ${credential_file} \
          -masterPasswordFile ${main_password_file}; \"",
      $targets, "List Repository Available FixPacks for ${package_id} from ${was_repo}", '_run_as' => 'root')
    }

    out::message("Available FixPacks:\n${fixes_result.first.to_data['result']['stdout']}")
  }

  ##############################################################################################################
  ## Copy the selected IBM repository to the remote host
  ## IBM Documentation: https://www.ibm.com/support/knowledgecenter/en/SSDV2W_1.8.5/com.ibm.cic.commandline.doc/topics/t_pucl_copy_packages.html
  ##########
  if $stage_copy_repo {
    out::message('Note: The repository copy process may take an extremely long time depending on network connection speed (Potentially 45mins or more).') #lint:ignore:140chars
    run_command("${shell_remote} -c \"mkdir -p ${repo_directory} > /dev/null 2>&1;
      ${pucl} copy ${package_id} \
        -repositories ${was_repo} \
        -target ${repo_directory} \
        -secureStorageFile ${credential_file} \
        -masterPasswordFile ${main_password_file} \
        -acceptLicense; \"",
    $targets, "Copy repository files to ${repo_directory} from ${was_repo}", '_run_as' => 'root')
  }

  ##############################################################################################################
  ## Remove main password file used to encrypt the local credentials store
  ##########
  if $stage_remove_main_password_file {
    run_command("${shell_remote} -c \"rm -f ${main_password_file}; \"",
    $targets, 'Remove main password for IBM credentials store', '_run_as' => 'root')
  }
}
