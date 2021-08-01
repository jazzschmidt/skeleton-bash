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


