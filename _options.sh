{
  # Public
  declare flag # determines whether a flag is present
  declare -a arg # holds the values of an argument


  # Internal variables

  # lists of [command]: [args/flags]
  declare -a __args=()
  declare -a __flags=()

  declare __current_arg
}

function flag() {
  local short long desc

  while [ $# -gt 1 ]; do
    local value="$1"
    if [ "${#value}" -eq 1 ]; then
      short="${value}"
    else
      long="${value}"
    fi
    shift
  done

  desc="$1"

  __flags+=("${short:--}#${long:--}#${desc}")
  has_flag "$short" "$long"
}

# Checks whether a flag is present and sets $flag
function has_flag() {
  local short="${1}" long="${2}"

  flag=false

  if [ -n "$long" ] && echo " ${__opts[*]} " | grep -qe " --${long} "; then
    flag=true; return 0
  fi

  if [ -n "$short" ] && echo " ${__opts[*]}" | grep -qE " -[a-zA-Z0-9]*${short}"; then
    flag=true; return 0
  fi

  return 1
}

function arg() {
  local short long param desc i value;
  local args=( "$@" )

  for i in $(seq "$#" 1); do
    value="${args[$i-1]}"

    if [ -z "$desc" ]; then
      desc="$value"
    elif [ -z "$param" ]; then
      param="$value"
    elif [ "${#value}" -eq 1 ]; then
      short="$value"
    else
      long="$value"
    fi
  done

  __args+=("${short:--}#${long:--}#${param}#${desc}")

  get_arg "$short" "$long"
}

# Retrieves an argument and sets $arg to its values
function get_arg() {
  local short="${1}" long="${2}"
  local match=false success=false

  arg=() # reset current value

  for opt in "${__opts[@]}"; do
    if $match; then
      arg+=("$opt")
      success=true
      match=false
      continue
    fi

    if [ "$opt" == "--$long" ] || echo " $opt " | grep -qE " -[a-zA-Z0-9]*${short} "; then
      match=true
    fi
  done

  $success && return 0 || return 1
}






function __validate_option() {
  local option="$1" command="$2"
  echo "validating for $command"
  local flags="${__commands_flags["$command"]}"
  local args="${__commands_args["$command"]}"

  if [ "$command" != "_" ]; then
    flags+="\n${__commands_flags["_"]}"
    args+="\n${__commands_args["_"]}"
  fi

  for flag in $(echo -e "${flags}" | cut -d'#' -f1-2 | tr '#' ' '); do
    if [ "$flag" = "-" ]; then # skip empty flags
      continue
    elif [ "$flag" = "$option" ]; then # return when present
      return
    fi
  done

  for arg in $(echo -e "${args}" | cut -d'#' -f1-2 | tr '#' ' '); do
    if [ "$arg" = "-" ]; then # skip empty args
      continue
    elif [ "$arg" = "$option" ]; then # return when present
      __current_arg="$option"
      return
    fi
  done

  echo "ERR ! Unknown option: $1" && exit 1
}

function __parse_options() {
  local opt_nr=0 command="$1"

  for opt in "${__opts[@]}"; do
    if [ -n "$__current_arg" ]; then
      if [ "${opt:0:1}" = "-" ]; then # value must not start with dash!
        echo "ERR ! value for $__current_arg must not start with '-'" && exit 1
      fi

      __current_arg="";
      continue
    fi

    if [ "${opt:0:2}" = "--" ]; then
      __validate_option "${opt:2}" "$command"
    elif [ "${opt:0:1}" = "-" ]; then # validate short options as lists
      for (( i=1; i<${#opt}; i++ )); do
        __validate_option "${opt:$i:1}" "$command"
      done
    else
      echo "ERR ! Unrecognized option '${opt}'" && exit 1
    fi

    (( opt_nr+=1 ))
  done

  if [ -n "$__current_arg" ]; then
    echo "ERR ! No value provided for $__current_arg!" && exit 1
  fi
}
