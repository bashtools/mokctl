# How to use the My Own Kind Parser in your own Code

## Overview

The command `mokctl` uses a command-line parser that follows the format used by most tools found in the kubernetes ecosystem. The parser has been made into a library so anyone can use it in their own Bash project and this page is intended to help with that.

The parser is programmed externally by supplying it with callbacks and state definitions.

It supports command lines in the following format:

> ./theprogram --global-options COMMAND --command-options SUBCOMMAND --subcommand-options ARG1 --subcommand-options ARG2 --subcommand-options ...

A '-h' in the global options position will show global help.

A '-h' in the command options position will show help for the COMMAND.

A '-h' in the subcommand options positions will show help for the SUBCOMMAND.

There is no limit to the number of ARGs a command line can have.

There are four functions for programming the parser:

* PA_add_option_callback()
  
  Add a callback to your code that processes options.

* PA_add_usage_callback()
  
  Add a callback to your code that shows COMMAND or SUBCOMMAND usage.

* PA_add_state()
  
  Add states using this command, along with optional callbacks for what to call if the state matches. The parser will add the COMMAND and SUBCOMMAND for the program to retrieve via the getters, PA_command() and PA_subcommand().

* PA_set_state()
  
  This defaults to COMMAND, but can be set to SUBCOMMAND, or ARG1 for a more traditional Unix style of option processing, shown later.

## Mokctl

I gathered all the parser programming commands in the next code block so it's easy to see the full user interface definition. The callback functions can be viewed by doing `make tags` and then, for example, `vim -t BI_process_options` - will take you directly to that function.

```bash
  # Program the parser's state machine
  PA_add_state "COMMAND" "build" "SUBCOMMAND" ""
  PA_add_state "SUBCOMMAND" "buildimage" "END" ""
  PA_add_state "COMMAND" "create" "SUBCOMMAND" ""
  PA_add_state "SUBCOMMAND" "createcluster" "ARG2" ""
  PA_add_state "ARG1" "createcluster" "ARG2" "CC_set_clustername"
  PA_add_state "ARG2" "createcluster" "ARG3" "CC_set_nummasters"
  PA_add_state "ARG3" "createcluster" "END" "CC_set_numworkers"
  PA_add_state "COMMAND" "exec" "ARG1" ""
  PA_add_state "ARG1" "exec" "END" "EX_set_containername"
  PA_add_state "COMMAND" "get" "SUBCOMMAND" ""
  PA_add_state "SUBCOMMAND" "getcluster" "ARG1" ""
  PA_add_state "ARG1" "getcluster" "END" "GC_set_clustername"
  PA_add_state "COMMAND" "delete" "SUBCOMMAND" ""
  PA_add_state "SUBCOMMAND" "deletecluster" "ARG1" ""
  PA_add_state "ARG1" "deletecluster" "END" "DC_set_clustername"
  PA_add_state "COMMAND" "build" "SUBCOMMAND" ""
  PA_add_state "SUBCOMMAND" "buildimage" "END" ""

  # Set up the parser's option callbacks
  PA_add_option_callback "build" "BI_process_options" || return
  PA_add_option_callback "buildimage" "BI_process_options" || return
  PA_add_option_callback "create" "CC_process_options" || return
  PA_add_option_callback "createcluster" "CC_process_options" || return
  PA_add_option_callback "exec" "EX_process_options" || return
  PA_add_usage_callback "exec" "EX_usage" || return
  PA_add_option_callback "get" "GC_process_options" || return
  PA_add_option_callback "getcluster" "GC_process_options" || return
  PA_add_option_callback "delete" "DC_process_options" || return
  PA_add_option_callback "deletecluster" "DC_process_options" || return
  PA_add_option_callback "build" "BI_process_options" || return
  PA_add_option_callback "buildimage" "BI_process_options" || return

  # Set up the parser's usage callbacks
  PA_add_usage_callback "build" "BI_usage" || return
  PA_add_usage_callback "buildimage" "BI_usage" || return
  PA_add_usage_callback "create" "CC_usage" || return
  PA_add_usage_callback "createcluster" "CC_usage" || return
  PA_add_usage_callback "get" "GC_usage" || return
  PA_add_usage_callback "getcluster" "GC_usage" || return
  PA_add_usage_callback "delete" "DC_usage" || return
  PA_add_usage_callback "deletecluster" "DC_usage" || return
  PA_add_usage_callback "build" "BI_usage" || return
  PA_add_usage_callback "buildimage" "BI_usage" || return
```

## Example

I have a small Bash script called cmdline-player that has grown complex enough to need a few command line options. Cmdline-player is used to create the screencasts in My Own Kind.

I was lazy when writing cmdline-player. I thought it would be easier and shorter than it is now, even though it's only about 260 lines long.

I don't want to worry too much about code style, I just want to bolt on the parser and get on with other things. If cmdline-player grows more, then functions can be split out into single files later and global variables can be cleaned up.

Make sure shellcheck is integrated into whatever IDE is being used. It helps alot if shellcheck passes with all optional checks. The first thing is to get all those variables surrounded by double quotes and curly braces where it tells us. The following commands will do that for us, otherwise doing this is a real pain.

```bash
cd cmdline-player
shellcheck --shell bash -o all -i 2250 -f diff cmdline-player | git apply
shellcheck --shell bash -o all -i 2248 -f diff cmdline-player | git apply
```

`-i 2250` and `-i 2248` are the codes for checking the format of the variables. Shellcheck tries to fix the code, with `-f diff`, and uses `git apply` to apply the diff output to the code.

I don't expect this file to grow any more so I'll just append `src/lib/parser.sh` close to the end of the cmdline-player file.

The read-only globals, `OK`, `ERROR`, and `STDERR` need to be defined, as they are only declared in parser.sh. Add the following lines close to the top of cmdline-player:

```bash
declare -rg STOP=3 OK=0 ERROR=1 STDERR='/dev/stderr'
```

That's it for importing the parser library, next let's program the parser.

## Programming the Parser

### Designing the UI

Using the command line format shown in Overview above the following commands would allow the use of all of the cmdline-player's features:

```none
# Play and record choosing the window with a click
cmdline-player FILENAME.scr

# long and short options
cmdline-player -w "Name of window" FILENAME.scr
cmdline-player --window "Name of window" FILENAME.scr

# long and short options
cmdline-player -n FILENAME.scr
cmdline-player -norecord FILENAME.scr

# long and short options
cmdline-player -q
cmdline-player --query
```

The command line interface in the previous code block uses global options only. There are no COMMANDS or SUBCOMMANDS, just options and an ARG1.

### Programming the UI

I will present the changes and explain them as we go.

```bash
  # Set up the parser
  setup_parser                             # <- 1

  local retval="${OK}"
  PA_run "$@" || retval=$?                 # <- 2
  if [[ ${retval} -eq ${ERROR} ]]; then
    return "${ERROR}"
  elif [[ ${retval} -eq ${STOP} ]]; then
    return "${OK}"
  fi

  sanity_checks                            # <- 3
```

Those lines were added to the top of the `main()` function - the first function that cmdline-player calls. The three lines call three functions shown next.

```bash
setup_parser() {
  # Program the parser's state machine
  PA_set_state "ARG1"
  PA_add_state "ARG1" "" "END" "set_filename"

  # Set up the parser's option callbacks
  PA_add_option_callback "" "process_options" || return

  # Set up the parser's usage callbacks
  PA_add_usage_callback "" "usage" || return
}
```

Since we have no COMMAND or SUBCOMMAND states for the Unix-like version, everything is set up in the global scope ("").

* 'PA_set state "ARG1"' sets the initial state to ARG1, completely bypassing the COMMAND and SUBCOMMAND states.

* PA_add_state takes four arguments:
  
  1. The current state, in this case ARG1.
  
  2. The token for the current state, in this case "" as it's the global state.
  
  3. The next state to transition to, in this case END since everything is in the global state.
  
  4. An optional callback used to set variables, or more.

* PA_add_option_callback takes two arguments:
  
  1. The COMMAND/SUBCOMMAND token to process options for.
  
  2. The function to call that will process those options.

* PA_add_usage_callback takes two arguments:
  
  1. The COMMAND/SUBCOMMAND token for which this usage will apply.
  
  2. The function to call when usage needs to be shown.

`PA_run` is the entrypoint for the parser. This will parse the command line calling callbacks as required to process options, show usage, and set other variables from the arguments.

```bash
sanity_checks() {
  [[ -z ${FILE} ]] && {
    usage
    printf 'ERROR: Please provide the file name to play.\n'
    exit 1
  }
}
```

`sanity_checks` is run next, to make sure anything that needed to be set is actually set.

That's it for main() and the support functions there.

The callback functions that were set in `setup_parser` need to be written, shown next:

```bash
set_filename() {
  FILE="$1"
}
```

The parser calls `set_filename` when ARG1 is found.

```bash
usage() {
  printf 'cmdline-player - play commands from a .scr file.'
}
```

The `usage` function outputs the usage to the screen. You can see the full help text in [cmdline-player](/cmdline-player/cmdline-player).

```bash
process_options() {
  case "$1" in
  -h | --help)
    usage
    return "${STOP}"
    ;;
  -w | --window)
    WINDOWNAME="$2"
    return "$(PA_shift)"
    ;;
  -n | --norecord)
    E2E="yes"
    return "$(PA_shift)"
    ;;
  -q | --query)
    xwininfo | awk '/xwininfo: Window id:/ { print $NF; }'
    exit 0
    ;;
  *)
    usage
    printf 'ERROR: "%s" is not a valid option.\n' "${1}" \
      >"${STDERR}"
    return "${ERROR}"
    ;;
  esac
}
```

The `process_options()` function is called by the parser each time a global option is encountered. Key points to note:

* `-h` or `--help` will output usage then return STOP. When the parser sees STOP it will stop parsing and return without error. In this program 'exit 0' could have been called instead of `return "${STOP}"`. In `mokctl` the `exit` command is never used.

* `-w` or `--window` sets the WINDOWNAME global variable to the second argument. If the second argument is used then an extra shift is required. You signal an extra shift by returning PA_shift (a getter - a function call).

That's all that is required to get the parser working. A parser that can grow without worry or needing to change lots of code later on.

If you want to take a look it's here: [cmdline-player](/cmdline-player/cmdline-player).

That's it!
