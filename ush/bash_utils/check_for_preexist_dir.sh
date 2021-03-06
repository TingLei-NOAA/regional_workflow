#
#-----------------------------------------------------------------------
#
# This file defines a function that checks for a preexisting version of
# the specified directory and, if present, deals with it according to 
# the method specified by the argument preexisting_dir_method.
#
#-----------------------------------------------------------------------
#
function check_for_preexist_dir() {
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
  local scrfunc_fp=$( readlink -f "${BASH_SOURCE[0]}" )
  local scrfunc_fn=$( basename "${scrfunc_fp}" )
  local scrfunc_dir=$( dirname "${scrfunc_fp}" )
#
#-----------------------------------------------------------------------
#
# Get the name of this function.
#
#-----------------------------------------------------------------------
#
  local func_name="${FUNCNAME[0]}"
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

  Function name:  \"${func_name}\"
  Number of arguments specified:  $#

Usage:

  ${func_name}  dir  preexisting_dir_method

where the arguments are defined as follows:

  dir:
  Name of directory to check for a preexisting version.

  preexisting_dir_method:
  String specifying the action to take if a preexisting version of dir
  is found.  Valid values are \"delete\", \"rename\", and \"quit\".
"

  fi
#
#-----------------------------------------------------------------------
#
# Set local variables to appropriate input arguments.
#
#-----------------------------------------------------------------------
#
  local dir="$1"
  local preexisting_dir_method="$2"
#
#-----------------------------------------------------------------------
#
# Set the valid values that preexisting_dir_method can take on and check
# to make sure the specified value is valid.
#
#-----------------------------------------------------------------------
#
  local valid_vals_preexisting_dir_method=( "delete" "rename" "quit" )
  check_var_valid_value "preexisting_dir_method" \
                        "valid_vals_preexisting_dir_method"
#
#-----------------------------------------------------------------------
#
# Check if dir already exists.  If so, act depending on the value of
# preexisting_dir_method.
#
#-----------------------------------------------------------------------
#
  if [ -d "$dir" ]; then

    case ${preexisting_dir_method} in
#
#-----------------------------------------------------------------------
#
# If preexisting_dir_method is set to "delete", we remove the preexist-
# ing directory in order to be able to create a new one (the creation of
# a new directory is performed in another script).
#
#-----------------------------------------------------------------------
#
    "delete")

      rm_vrfy -rf "$dir"
      ;;
#
#-----------------------------------------------------------------------
#
# If preexisting_dir_method is set to "rename", we move the preexisting
# directory in order to be able to create a new one (the creation of a
# new directory is performed in another script).
#
#-----------------------------------------------------------------------
#
    "rename")

      local i=1
      local old_indx=$( printf "%03d" "$i" )
      local old_dir="${dir}_old${old_indx}"
      while [ -d "${old_dir}" ]; do
        i=$[$i+1]
        old_indx=$( printf "%03d" "$i" )
        old_dir="${dir}_old${old_indx}"
      done

      print_info_msg "$VERBOSE" "
Specified directory (dir) already exists:
  dir = \"$dir\"
Moving (renaming) preexisting directory to:
  old_dir = \"${old_dir}\""

      mv_vrfy "$dir" "${old_dir}"
      ;;
#
#-----------------------------------------------------------------------
#
# If preexisting_dir_method is set to "quit", we simply exit with a non-
# zero status.  Note that "exit" is different than "return" because it
# will cause the calling script (in which this file/function is sourced)
# to stop execution.
#
#-----------------------------------------------------------------------
#
    "quit")

      print_err_msg_exit "\
Specified directory (dir) already exists:
  dir = \"$dir\""
      ;;

    esac
  
  fi
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/func-
# tion.
#
#-----------------------------------------------------------------------
#
  { restore_shell_opts; } > /dev/null 2>&1

}


