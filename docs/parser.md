# How to use the My Own Kind Parser in your own Code

Before starting, a question that keeps being asked is 'Why Bash?'.

Bash is a great tool for automating commands. In `mokctl`, Bash is a wrapper around podman or docker - that's it. Bash is perfect for this.

Bash can be a great tool for Rapid Application Development and for Proof of Concepts. Kubernetes started [more or less] this way - small Go applications and lots of Bash glue code. The `mokctl` code, working out how to do it, and all the documentation was written in about 2 weeks. That's from zero to fully working application in 2 weeks - and 19 GitHub stars - in 2 weeks. That would be difficult to do in Python, Go, Java, Haskell, or whatever.

Why was it so fast to write? Well, whilst investigating how to create a kubernetes cluster in containers I copied and pasted all the commands in a Markdown document. Then the list of commands were pasted, as-is, into functions so I knew they would work. Doing this in another language would actually be alot more work.

Bash code from 10 years ago still works now. There aren't many languages that can do that, so I can be sure that code I have written will not be deprecated any time soon. Indeed Bash can still run the original Bourne shell (sh) code. If you didn't know, Bash is an acronym for Bourne Again SHell.

Bash is something every sysadmin knows. So for sysadmin tools it makes sense.

Later, in another document, I will show how a Bash program can be wrapped in a pretty GUI, using Go (golang) and a Javascript Framework to create a solid and maintainable user application.

## Overview

The command `mokctl` uses a command-line parser that follows the format used by most tools found in the kubernetes ecosystem. The parser has been made into a library so anyone can use it in their own Bash project and this page is intended to help with that.

The parser is programmed externally by supplying it with callbacks and state definitions.

It supports command lines in the following format:

> ./theprogram --global-options COMMAND --command-options SUBCOMMAND --subcommand-options ARG1 --subcommand-options ARG2 --subcommand-options ...

A '-h' in the global options position will show global help.

A '-h' in the command options position will show help for the COMMAND.

A '-h' in the subcommand options positions will show help for the SUBCOMMAND.

There is no limit to the number of ARGs a command line can have.

There are three functions for programming the parser:

* PA_add_option_callback()
  
  Add a callback to your code that processes options.

* PA_add_usage_callback()
  
  Add a callback to your code that shows COMMAND or SUBCOMMAND usage.

* PA_add_state()
  
  Add states using this command, along with optional callbacks for what to call if the state matches. The parser will add the COMMAND and SUBCOMMAND for the program to retrieve via the getters, PA_command() and PA_subcommand().

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
cmdline-player start playback using "FILENAME.scr"

cmdline-player start playback using "FILENAME.scr" and record clicked window

cmdline-player start playback using "FILENAME.scr" and record window "Gnome Terminal"

cmdline-player get window name by clicking on it

cmdline-player start e2e-test using "FILENAME.scr"

```

That's a very wordy, although very descriptive, user interface! It uses the COMMAND/SUBCOMMAND features of the parser, but not in the way it was designed for!

We could also program a terse, more "unixy" version and have both versions supported at the same if required. Let's not do that, as it will be confusing for the user, but we'll start with the unix-like version then do the verbose one after:

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

Here we will code both versions starting with...

#### The Unix-like Version

I will present the changes and explain them as we go.

```bash
  # Set up the parser
  setup_parser
  PA_run "$@" || exit 1
  sanity_checks
```

Those lines were added to the top of the `main()` function. The first function that cmdline player calls. The three lines call three functions shown next.

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

Since we have no COMMAND or SUBCOMMAND states for the Unix-like version, everything is set up in the global scope.

* PA_set state "ARG1" sets the initial state to ARG1, completely bypassing the COMMAND and SUBCOMMAND states.

* PA_add_state takes four arguments:
  
  1. The current state, in this case ARG1.
  
  2. The token for the current state, in this case "" as it's the global state.
  
  3. The next state to transition to, in this case END since everything is in the global state.

. PA_add_option_callback takes two arguments:

1. The COMMAND/SUBCOMMAND token to process options for.

2. The function to call that will process those options

. PA_add_usage_callback takes two arguments:

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

The `usage` function outputs the usage to the screen. It should be longer than that!

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

* `-w` or `--window` sets the WINDOWNAME global variable to the second argument. If the second argument is used then an extra shift is required. You signal an extra shift by returning PA_shift (a getter).

That's all that is required to get the parser working. A parser that can grow without worry or needing to change lots of code later on.

If you want to take a look I saved it as [cmdline-player-unixlike.sh](cmdline-player-unixlike.sh)

#### The Very Wordy Version

The same functions will be called for the wordy version so only the `setup_parser()` function will be changed. I'm going to use this parser set up in My Own Kind because it makes me chuckle :)

Looking at the following table you can easily see the states, and which tokens are expected in each state.

```bash
CMD   SUBCMD   ARG1  ARG2       ARG3     ARG4   ARG5    ARG6
start playback using "FILENAME"
start playback using "FILENAME" and      record clicked window
start playback using "FILENAME" and      record window  "WINNAME"
get   window   name  by         clicking on     it
start e2e-test using "FILENAME"
```

With such a wordy user interface lets give the user synonyms:

* using = with, from

* start = begin

* get = display, output, choose (I much prefer display to get!)

* clicking = tapping, choosing, pointing, pressing

* on = at, it

* 'on it' - can be completely omitted, so optional

It's also possible to allow the full 'cmdline-player get window name ...` and the shorter 'cmdline-player get' (or it's synonyms).

Now it should actually be pretty hard to get the command line wrong!

This should show how versatile the parser is, and how professional the results can be.

I'm going to start at the top of the table, work through the states, do the synonyms, then do the next line. The following code shows the result.

```bash

```

There are many different ways to use the Parser and I haven't discovered them all yet. I hope you have fun playing with it!
