# GL - Globals

# Public Functions ------------------------------------------------------------

# GL_init sets the only global variables that should be in use anywhere.
# The only other globals are the associative arrays.
# Args: None expected.
GL_init() {
  local dummy

  declare -g OK=0
  declare -g TRUE=0
  declare -g ERROR=1
  declare -g FALSE=1
  declare -g STOP=2
  declare -g STDOUT="/dev/stdout"
  declare -g STDERR="/dev/stderr"

  # The following just keep shellcheck happy
  dummy="${OK}"
  dummy="${ERROR}"
  dummy="${STOP}"
  dummy="${STDOUT}"
  dummy="${STDERR}"
  dummy="${TRUE}"
  dummy="${FALSE}"
  dummy="${dummy}"
}

# vim:ft=sh:sw=2:et:ts=2:
