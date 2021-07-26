{
  # Public
  declare flag # determines whether a flag is present
  declare -a arg # holds the values of an argument


  # Internal variables

  # lists of [command]: [args/flags]
  declare -a __args=()
  declare -a __flags=()
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
