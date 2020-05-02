# Contributing

## `make test` must pass

When `make test` is run it will:

1. Run all tests.

   Add new tests where required.
   Make sure tests are written for new functions.
   
2. Run `shellcheck` on mokctl/mokctl.

   This must pass when run with no options to be approved.
   
3. Run `shfmt`.

   This must pass when run with `-s -i 2` to be approved
   `-s` = simplify code
   `-i 2` = indention using two spaces
   
