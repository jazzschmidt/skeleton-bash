
function array_contains() {
  local e match="$1"
  local -a args=()
  shift
  args=("$@")
  for e in "${args[@]}"; do
    [ "$e" == "$match" ] && return 0
  done
  return 1
}

