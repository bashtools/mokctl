# Command Line Player

* `cmdline-player`
  
  This script plays back files ending in `.scr` and starts a recording with `byzanz-record`. GIF output is created by default but byzanz supports other formats.
  
  Example: `cmdline-player kthw-2.scr` - will start a playback and recording session. The animated GIF file will be saved as `screencast.gif`.

* `scr2md.sh`
  
  This script creates the Markdown format files, ending in `.md`.
  
  If the script is called with 2 arguments, then the markdown file for the `.scr` file is created as the transcript of commands. Lines starting with `.MD` and `screencast` are omitted.
  
  If the script is called with 3 arguments, then the markdown file for the .scr file is created containing just the lines starting with `.MD` and the actual commands that are run. Comments are excluded, as are lines starting with `screencast`.
  
  See the Makefile for example usage of `scr2md.sh`.

* `*.scr` files
  
  Files ending in `.scr` are used to create markdown format files. Edit these to change `.md` files listed in the Makefile, `docs` target.
  
  Having all the documentation, commands and screencast settings in one file helps to stop the Markdown files getting out of sync with what was actually typed, so the commands can be relied upon to work wherever they are seen.

* `*.md` files
  
  Files ending in `.md` were created from the `.scr` files and committed to Git.

* `e2e-*` files
  
  Files starting with `e2e` are used for end-to-end testing.


