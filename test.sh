#!/usr/bin/env bash

{
  # Public variables
  # ----------------
  declare flag # determines whether a flag is present
  declare -a arg # holds the values of an argument
}

{
  # Internal variables
  # ------------------

  # current handler properties
  declare __handler_description __handler_command __parent_handler

  # handlers
  declare -a __handlers
  declare -A __handlers_hashes=()

  # lists of [command]: [handler-function/description]
  declare -A __commands=()
  declare -A __commands_descriptions=()

  declare __argv="$*" __command __opts
  {
    # set command by removing options
    __command="${__argv%% -*}"
    if [ "${__command:0:1}" = "-" ]; then __command=; fi

    __opts="${__argv:${#__command}}"
  }


  # lists of [command]: [args/flags]
  declare -A __args=()
  declare -A __flags=()
}


function __main() {
  cat <<EOF
Main function started

command: $__command
EOF

  handler="${__commands["$__command"]}"
  $handler && execute
  declare -p __flags
}



function description() {
  __handler_description="$*"
}

function command() {
  __handler_command="$*"
  [ -n "$__parent_handler" ] && __handler_command="${__parent_handler} $*"
}

# Registers an argument and sets $arg to its value, if present.
# ARGS:
#   $1: option (short or long)
#   $2: parameter name
#   $3: description
#   -- OR --
#   $1-$2: option (short and long)
#   $3: parameter name
#   $4: description
function arg() {
  local short long param desc i value;
  local registered_args="${__args["${__handler_command}"]}"
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

  if [ -n "${registered_args}" ]; then registered_args+="\n"; fi
  registered_args+="${short:--}#${long:--}#${param}#${desc}"

  # Global args are saved in _
  __args+=( ["${__handler_command:-"_"}"]="${registered_args}")
  get_arg "$short" "$long"
}



# Retrieves an argument and sets $arg to its values
function get_arg() {
  local short="${1}" long="${2}"
  local match=false success=false

  arg=() # reset current value

  for opt in $__opts; do
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


# Registers a flag and sets $flag to either true or false
# ARGS:
#   $1: option (short or long)
#   $2: description
#   -- OR --
#   $1-$2: option (short and long)
#   $3: description
function flag() {
  local short long desc
  local registered_flags="${__flags["${__handler_command}"]}"

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

  if [ -n "${registered_flags}" ]; then registered_flags+="\n"; fi
  registered_flags+="${short:--}#${long:--}#${desc}"

  # Global flags are saved in _
  __flags+=( ["${__handler_command:-"_"}"]="${registered_flags}" )
  has_flag "$short" "$long"
}

# Checks whether a flag is present and sets $flag
function has_flag() {
  local short="${1}" long="${2}"

  flag=false

  if [ -n "$long" ] && echo " ${__opts} " | grep -qe " --${long} "; then
    flag=true; return 0
  fi

  if [ -n "$short" ] && echo " ${__opts}" | grep -qE " -[a-zA-Z0-9]*${short}"; then
    flag=true; return 0
  fi

  return 1
}


function @foo() {
  echo "-- foo"
  flag "s" "silent" "silences bubu"
  flag "w" "write to file"
  arg "n" "string" "name"
  arg "q" "quiet" "value" "quiet bubu"
  description "says hello"

  execute() {
    echo "Hello from froo"
  }

  function @foobar() {
    command "foo"
    echo "-- foo bar"
    flag "g" "gggg"
    description "says goodbye"

    execute() {
      echo "Goodbye!"
    }
  }
}

function @bar() {
  echo "-- bar"
  description "says hello parameterized"

  local name="default"

  execute() {
    echo "Hello ${name}"
  }
}









function handler_fingerprint() {
  local handler="$1" hash

  hash=$(declare -f "@${handler}" | md5)

  if [ -n "${__handlers_hashes[$handler]}" ] && [ "${__handlers_hashes[$handler]}" != "${hash}" ]; then
    echo "ERR ! Overwriting: $handler"
    exit 1
  fi

  __handlers_hashes+=( ["${handler}"]="${hash}" )
}

function parse_handler() {
  local command old_parent_handler
  local new_handlers=()

  # Set top handler
  old_parent_handler="$__parent_handler"
  __parent_handler="${1:-}"

  # Read handlers
  mapfile -t __handlers < <( declare -F | grep '@' | cut -d'@' -f2 )
  for handler in "${__handlers[@]}"; do
    if [ -z "${__handlers_hashes["${handler}"]}" ]; then
      new_handlers+=( "${handler}" )
    fi

    handler_fingerprint "${handler}"
  done

  if [ "${#new_handlers[*]}" -eq 0 ]; then return 0; fi

  for handler in "${new_handlers[@]}"; do
    __handler_command="${handler}"
    __handler_description=""

    ${handler/#/@} # evaluate handler function

    # fail if a handler has no description
    [ -z "${__handler_description}" ] && echo "ERR ! No description for ${handler}!" && exit 1

    if [ -n "${__commands["${__handler_command}"]}" ]; then
      echo "ERR! Cannot overwrite ${__handler_command}"
      exit 1
    fi

    __commands+=( ["${__handler_command}"]="@${handler}" )
    __commands_descriptions+=( ["${__handler_command}"]="${__handler_description}" )
  done

  # Add recursion via function
  parse_handler "${handler}"
  __parent_handler="${old_parent_handler}"
}

parse_handler

currentArg=""

function validate_short() {
  local option="$1" command="$2"

  local flags="${__flags["_"]}\n${__flags["$command"]}"
  local args="${__args["_"]}\n${__args["$command"]}"

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
      currentArg="$option"
      return
    fi
  done

  echo "ERR ! Unknown option: $1" && exit 1
}

for opt in $__opts; do
  if [ -n "$currentArg" ]; then
    if [ "${opt:0:1}" = "-" ]; then # value must not start with dash!
      echo "ERR ! value for $currentArg must not start with '-'" && exit 1
    fi

    currentArg="";
    continue
  fi

  if [ "${opt:0:2}" = "--" ]; then
    validate_short "${opt:2}" "$__command"
  elif [ "${opt:0:1}" = "-" ]; then # validate short options as lists
    for (( i=1; i<${#opt}; i++ )); do
      validate_short "${opt:$i:1}" "$__command"
    done
  fi
done

if [ -n "$currentArg" ]; then
  echo "ERR ! No value provided for $currentArg!" && exit 1
fi

__main "$@"
