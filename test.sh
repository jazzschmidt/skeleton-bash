#!/usr/bin/env bash

declare __description __command
declare -A __args=()
declare -A __flags=()
declare argv="$*"

declare flag
declare -a arg


function get_command() {
  local command="${*%% -*}"
  if [ "${command:0:1}" != "-" ]; then echo "$command"; fi
}


command=$(get_command "$argv")
opts="${argv:${#command}}"

function description() {
  __description="$*"
}

function command() {
  __command="$*"
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
  local short; local long; local param; local desc;
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

  local args_list="${__args["${__command}"]}"
  if [ -n "${args_list}" ]; then args_list+="\n"; fi
  args_list+="${short:--}#${long:--}#${param}#${desc}"

  __args+=( ["${__command:-"_"}"]="${args_list}")
  get_arg "$short" "$long"
}



# Retrieves an argument and sets $arg to its value
function get_arg() {
  local short="${1}"; local long="${2}"; local match=false;
  local success=false

  arg=()

  for opt in $opts; do
    if $match; then
      arg+=("$opt")
      match=false
      success=true
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
  local short; local long; local desc;

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

  local flags_list="${__flags["${__command}"]}"
  if [ -n "${flags_list}" ]; then flags_list+="\n"; fi
  flags_list+="${short:--}#${long:--}#${desc}"

  __flags+=( ["${__command:-"_"}"]="${flags_list}" )

  has_flag "$short" "$long"
}

# Checks whether a flag is present
function has_flag() {
  local short="${1}"; local long="${2}";

  opt=false

  if [ -n "$long" ] && echo " ${opts} " | grep -qe " --${long} "; then
    opt=true; return 0
  fi

  if [ -n "$short" ] && echo " ${opts}" | grep -E " -[a-zA-Z0-9]*${short}"; then
    opt=true; return 0
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
    echo "-- foo bar"
    command "foo"
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










declare -a handlers
declare -A handlers_hashes=()

declare -A commands=()
declare -A commands_descriptions=()
declare -A commands_args=()

function handler_fingerprint() {
  local handler="$1"
  hash=$(declare -f "@${handler}" | md5)

  if [ -n "${handlers_hashes[$handler]}" ] && [ "${handlers_hashes[$handler]}" != "${hash}" ]; then
    echo "ERR ! Overwriting: $handler"
    exit 1
  fi

  handlers_hashes+=( ["${handler}"]="${hash}" )
}

function parse_handler() {
  local prefix="${1:-}"; local new_handlers=()
  local command="" description=""

  echo "Prefix: $prefix"

  # Read handlers
  mapfile -t handlers < <( declare -F | grep '@' | cut -d'@' -f2 )
  for handler in "${handlers[@]}"; do
    if [ -z "${handlers_hashes["${handler}"]}" ]; then
      new_handlers+=( "${handler}" )
    fi

    handler_fingerprint "${handler}"
  done

  if [ "${#new_handlers[*]}" -eq 0 ]; then return 0; fi

  for handler in "${new_handlers[@]}"; do
    __command="${handler}"
    __description=""

    ${handler/#/@}
    __command="${prefix}${__command}" # prefixed nested command


    [ -z "${__description}" ] && echo "No description for ${handler}!" && exit 1

    echo "command: $__command"
    if [ -n "${commands["${__command}"]}" ]; then
      echo "ERR! Cannot overwrite ${__command}"
      exit 1
    fi

    commands+=( ["${__command}"]="@${handler}" )
    commands_descriptions+=( ["${__command}"]="${__description}" )
  done

  # Add recursion via function
  parse_handler "${prefix}${handler} "
}

parse_handler ""
readonly commands

echo "Commands: ${commands[*]}"
echo "Descriptions: ${commands_descriptions[*]}"
echo
echo


echo "Args:"
echo -e "${__args[*]}"
echo "Global flags:"
echo -e "${__flags["_"]}"
echo "Command bar:"
echo -e "${__flags["foo"]}"


currentArg=""

function validate_short() {
  local option=$1 command=$2
  echo "Validating:"

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

  echo "Unknown option: $1" && exit 1
}

for opt in $opts; do
  if [ -n "$currentArg" ]; then
    if [ "${opt:0:1}" = "-" ]; then # value must not start with dash!
      echo "value for $currentArg must not start with '-'" && exit 1
    fi

    currentArg="";
    continue
  fi

  if [ "${opt:0:2}" = "--" ]; then
    validate_short "${opt:2}" "$command"
  elif [ "${opt:0:1}" = "-" ]; then # validate short options as lists
    for (( i=1; i<${#opt}; i++ )); do
      validate_short "${opt:$i:1}" "$command"
    done
  fi
done

if [ -n "$currentArg" ]; then
  echo "No value provided for $currentArg!" && exit 1
fi
