# How to use the Parser in your own code

Before starting, a question that keeps being asked is 'Why Bash?'.

Bash is a great tool for automating commands. In `mokctl`, Bash is a wrapper around podman or docker - that's it. Bash is perfect for this.

Bash can be a great tool for Rapid Application Development and for Proof of Concepts. Kubernetes started [more or less] this way - small Go applications and lots of Bash glue code. The `mokctl` code, working out how to do it, and all the documentation was written in about 2 weeks. That's from zero to fully working application in 2 weeks - and 19 Github stars - in 2 weeks. That would be difficult to do in Python, Go, Java, Haskell, whatever.

Why was it so fast? Well, whilst investigating how to create a kubernetes cluster I copied and pasted all the commands in a Markdown document. Then the list of commands were pasted, as-is, into functions so I knew they would work. Doing this in another language would actually be alot more work.

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
declare -rg OK=0 ERROR=1 STDERR="/dev/stderr"
```

That's it for importing the parser library, next let's program the parser.

## Programming the Parser

### Designing the UI

Using the command line format shown in Overview above the following commands would allow the use of all of cmdline-players features:

```none
cmdline-player start playback using "FILNAME.scr"

cmdline-player start playback using "FILNAME.scr" and record clicked window

cmdline-player start playback using "FILENAME.scr" and record window "Gnome Terminal"

cmdline-player get window name by clicking on it

cmdline-player start e2e-test using "FILENAME.scr"

```

That's a very wordy, although very descriptive, user interface! It uses the COMMAND/SUBCOMMAND features of the parser.

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
