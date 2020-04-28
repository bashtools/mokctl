# Adding A New Command to mokctl

Start from `parse_options` and work down the file adding lines and functions as necessary.

For example: `mokctl get clusters OPTIONAL_NAME`:

1. Add help text to `usage()`.

2. Add a `get_command_help()` function.

3. Add to `check_command_token()`.

4. Add to `check_subcommand_token()`.

5. Create a new function, `check_get_subcommand_token()`.
   
   This command takes one option, so set `STATE=OPTION`.

6. Add to `check_option_token()`.

7. Add a new global at the top of the file.

8. Add new tests to `tests/unit-tests.sh`.

9. Add command to `main()`.

10. Add `do_get()`.

11. Add `do_get_clusters_sanity_checks().

12. In ‘MUTATIONS’ section add `do_get_clusters_mutate()`.

The outcome is shown in the commit:

[Add 'mokctl get cluster OPTIONAL_NAME' command · mclarkson/my-own-kind@6ba00b3 · GitHub](https://github.com/mclarkson/my-own-kind/commit/6ba00b3b01509a83a8bb43bfe83cb2cad6603f72)

Which is not totally clear, so will do another one soon... hopefully...


