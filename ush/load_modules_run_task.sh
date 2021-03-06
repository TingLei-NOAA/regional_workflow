#!/bin/bash

#
#-----------------------------------------------------------------------
#
# Source the variable definitions file and the bash utility functions.
#
#-----------------------------------------------------------------------
#
. ${GLOBAL_VAR_DEFNS_FP}
. $USHDIR/source_util_funcs.sh
#
#-----------------------------------------------------------------------
#
# Save current shell options (in a global array).  Then set new options
# for this script/function.
#
#-----------------------------------------------------------------------
#
{ save_shell_opts; set -u +x; } > /dev/null 2>&1
#
#-----------------------------------------------------------------------
#
# Get the full path to the file in which this script/function is located
# (scrfunc_fp), the name of that file (scrfunc_fn), and the directory in
# which the file is located (scrfunc_dir).
#
#-----------------------------------------------------------------------
#
scrfunc_fp=$( readlink -f "${BASH_SOURCE[0]}" )
scrfunc_fn=$( basename "${scrfunc_fp}" )
scrfunc_dir=$( dirname "${scrfunc_fp}" )
#
#-----------------------------------------------------------------------
#
# Check arguments.
#
#-----------------------------------------------------------------------
#
if [ "$#" -ne 2 ]; then

    print_err_msg_exit "
Incorrect number of arguments specified:

  Number of arguments specified:  $#

Usage:

  ${scrfunc_fn}  task_name  jjob_fp

where the arguments are defined as follows:

  task_name:
  The name of the rocoto task for which this script will load modules 
  and launch the J-job.

  jjob_fp
  The full path to the J-job script corresponding to task_name.  This
  script will launch this J-job using the \"exec\" command (which will
  first terminate this script and then launch the j-job; see man page of
  the \"exec\" command).
"

fi
#
#-----------------------------------------------------------------------
#
# Source the script that initializes the Lmod (Lua-based module) system/
# software for handling modules.  This script defines the module() and
# other functions.  These are needed so we can perform the "module use 
# ..." and "module load ..." calls later below that are used to load the
# appropriate module file for the specified task.
#
# Note that the build of the FV3 forecast model code generates the shell
# script at 
#
#   ${UFS_WTHR_MDL_DIR}/NEMS/src/conf/module-setup.sh
#
# that can be used to initialize the Lmod (Lua-based module) system/
# software for handling modules.  This script:
#
# 1) Detects the shell in which it is being invoked (i.e. the shell of
#    the "parent" script in which it is being sourced).
# 2) Detects the machine it is running on and and calls the appropriate 
#    (shell- and machine-dependent) initalization script to initialize 
#    Lmod.
# 3) Purges all modules.
# 4) Uses the "module use ..." command to prepend or append paths to 
#    Lmod's search path (MODULEPATH).
#
# We could use this module-setup.sh script to initialize Lmod, but since
# it is only found in the forecast model's directory tree, here we pre-
# fer to perform our own initialization.  Ideally, there should be one
# module-setup.sh script that is used by all external repos/codes, but
# such a script does not exist.  If/when it does, we will consider 
# switching to it instead of using the case-statement below.
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "
Initializing the shell function \"module()\" (and others) in order to be
able to use \"module load ...\" to load necessary modules ..."

case "$MACHINE" in
#
  "WCOSS_C")
    . /opt/modules/default/init/sh
    ;;
#
  "DELL")
    . /usrx/local/prod/lmod/lmod/init/sh
    ;;
#
  "HERA")
    . /apps/lmod/lmod/init/sh
    ;;
#
  "JET")
    . /apps/lmod/lmod/init/sh
    ;;
#
  *) 
    print_err_msg_exit "\
The script to source to initialize lmod (module loads) has not yet been
specified for the current machine (MACHINE):
  MACHINE = \"$MACHINE\""
    ;;
#
esac
#
#-----------------------------------------------------------------------
#
# Get the task name and the name of the J-job script.
#
#-----------------------------------------------------------------------
#
task_name="$1"
jjob_fp="$2"
#
#-----------------------------------------------------------------------
#
# Set the directory (modules_dir) in which the module files for the va-
# rious workflow tasks are located.  Also, set the name of the module
# file for the specified task.  
#
# A module file is a file whose first line is the "magic cookie" string
# '#%Module'.  It is interpreted by the "module load ..." command.  It
# sets environment variables (including prepending/appending to paths)
# and loads modules.
#
# The regional_workflow repository contains module files for all the 
# workflow tasks in the template rocoto XML file for the FV3SAR work-
# flow.  The full path to a module file for a given task is 
#
#   $HOMErrfs/modulefiles/$machine/${task_name} 
#
# where HOMErrfs is the base directory of the workflow, machine is the
# name of the machine that we're running on (in lowercase), and task_-
# name is the name of the current task (an input to this script).  For
# all tasks in the rocoto XML except run_fcst, these are actual files 
# (as opposed to symlinks).  For the run_fcst task, there are two possi-
# ble module files.  The first one is named "run_fcst_no_ccpp" and is 
# used to run FV3 without CCPP (i.e. it is used if USE_CCPP is set to 
# "FALSE" in the experiment/workflow configuration file).  This is also
# an actual file.  The second one is named "run_fcst_ccpp" and is used
# to run FV3 with CCPP (i.e. it is used if USE_CCPP is set to "TRUE").
# This second file is a symlink (and is a part of the regional_workflow
# repo), and its target is
#
#   ${UFS_WTHR_MDL_DIR}/NEMS/src/conf/modules.fv3
#
# Here, UFS_WTHR_MDL_DIR is the directory in which the ufs_weather_model
# repository containing the FV3 model is cloned (normally "$HOMErrfs/
# sorc/ufs_weather_model"), and modules.fv3 is a module file that is ge-
# nerated by the forecast model's build process.  It contains the appro-
# priate modules to use when running the FV3 model.  Thus, we just point
# to it via the symlink "run_fcst_ccpp" in the modulefiles/$machine di-
# rectory.
#
# QUESTION:
# Why don't we do this for the non-CCPP version of FV3?
#
# ANSWER:
# Because for that case, we load different versions of intel and impi 
# (compare modules.nems to the modules loaded for the case of USE_CCPP
# set to "FALSE" in run_FV3SAR.sh).  Maybe these can be combined at some 
# point.  Note that a modules.nems file is generated in the same rela-
# tive location in the non-CCPP-enabled version of the FV3 forecast mo-
# del, so maybe that can be used and the run_FV3SAR.sh script modified
# to accomodate such a change.  That way the below can be performed for
# both the CCPP-enabled and non-CCPP-enabled versions of the forecast 
# model.
#
#-----------------------------------------------------------------------
#
machine=${MACHINE,,}
modules_dir="$HOMErrfs/modulefiles/tasks/$machine"
modulefile_name="${task_name}"

# Dom says that a correct modules.fv3 file is generated by the forecast
# model build regardless of whether building with or without CCPP.  
# Thus, we can have a symlink named "run_fcst" that points to that file
# regardless of the setting of USE_CCPP.  But this requires that we then
# test the non-CCPP-enabled version, which we've never done.  Leave this
# for another time...
#if [ "${task_name}" = "run_fcst" ]; then
#  if [ "${USE_CCPP}" = "TRUE" ]; then
#    modulefile_name=${modulefile_name}_ccpp
#  else
#    modulefile_name=${modulefile_name}_no_ccpp
#  fi
#fi
#
#-----------------------------------------------------------------------
#
# This comment needs to be updated:
#
# Use the "readlink" command to resolve the full path to the module file
# and then verify that the file exists.  This is not necessary for most
# tasks, but for the run_fcst task, when CCPP is enabled, the module 
# file in the modules directory is not a regular file but a symlink to a
# file in the ufs_weather_model external repo.  This latter target file
# will exist only if the forecast model code has already been built.  
# Thus, we now check to make sure that the module file exits.
#
#-----------------------------------------------------------------------
#
modulefile_path=$( readlink -f "${modules_dir}/${modulefile_name}" )

if [ ! -f "${modulefile_path}" ]; then

  if [ "${task_name}" = "${MAKE_OROG_TN}" ] || \
     [ "${task_name}" = "${MAKE_SFC_CLIMO_TN}" ] || \
     [ "${task_name}" = "${MAKE_ICS_TN}" ] || \
     [ "${task_name}" = "${MAKE_LBCS_TN}" ] || \
     [ "${task_name}" = "${RUN_FCST_TN}" ]; then

    print_err_msg_exit "\
The target (modulefile_path) of the symlink (modulefile_name) in the 
task modules directory (modules_dir) that points to module file for this
task (task_name) does not exist:
  task_name = \"${task_name}\"
  modulefile_name = \"${modulefile_name}\"
  modules_dir = \"${modules_dir}\"
  modulefile_path = \"${modulefile_path}\"
This is likely because the forecast model code has not yet been built."

  else

    print_err_msg_exit "\
The module file (modulefile_path) specified for this task (task_name)
does not exist:
  task_name = \"${task_name}\"
  modulefile_path = \"${modulefile_path}\""

  fi

fi
#
#-----------------------------------------------------------------------
#
# Purge modules and load the module file for the specified task on the 
# current machine.
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "
Loading modules for task \"${task_name}\" ..."
 
module purge

module use "${modules_dir}" || print_err_msg_exit "\
Call to \"module use\" command failed."

#
# Some of the task module files that are symlinks to module files in the
# external repositories are in fact shell scripts (they shouldn't be; 
# such cases should be fixed in the external repositories).  For such
# files, we source the "module" file.  For true module files, we use the
# "module load" command.
#
case "${task_name}" in
#
"${MAKE_ICS_TN}" | "${MAKE_LBCS_TN}" | "${MAKE_SFC_CLIMO_TN}")
  . ${modulefile_path} || print_err_msg_exit "\                                                                                           
Sourcing of \"module\" file (modulefile_path; really a shell script) for
the specified task (task_name) failed:
  task_name = \"${task_name}\"
  modulefile_path = \"${modulefile_path}\""
  ;;
#
*)
  module load ${modulefile_name} || print_err_msg_exit "\
Loading of module file (modulefile_name; in directory specified by mod-
ules_dir) for the specified task (task_name) failed:
  task_name = \"${task_name}\"
  modulefile_name = \"${modulefile_name}\"
  modules_dir = \"${modules_dir}\""
  ;;
#
esac

module list
#
#-----------------------------------------------------------------------
#
# Use the exec command to terminate the current script and launch the
# J-job for the specified task.
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "
Launching J-job (jjob_fp) for task \"${task_name}\" ...
  jjob_fp = \"${jjob_fp}\"
"
exec "${jjob_fp}"
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/func-
# tion.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1


