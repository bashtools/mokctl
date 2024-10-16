# Contributing

## `make test` must pass

When `make test` is run it will:

1. Run end-to-end and usage tests.

2. Run `shellcheck` on mok/mok.
   
   This must pass when run with no options to be approved.

3. Run `shfmt`.
   
   This must pass when run with `-s -i 2` to be approved
   `-s` = simplify code
   `-i 2` = indention using two spaces

Get `shfmt` from https://github.com/mvdan/sh.

I use the vim-shfmt plugin from https://github.com/z0mbix/vim-shfmt,
with the following lines added to `~/.vimrc`:

```
" shfmt
let g:shfmt_extra_args = '-s -i 2'
let g:shfmt_fmt_on_save = 1
```
