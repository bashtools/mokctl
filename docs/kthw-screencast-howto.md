# How to create the kubernetes the hard way screencasts

Open a terminal window.

Clone the my-own-kind repo.

```none
cd my-own-kind/cmdline-player
```

Open another terminal window and make it large and white.

Open another 100x38 window, this time black, and place on top of the white one.

```none
while true; do screen -r -e ^Oo screencast; sleep .5; done
```

In the first teminal, `vim cmdline-player`.

Uncomment the long `<<<$(xwininfo ...)` line and comment out the short one.

quit vim.

Start the screencast recording. It will take about 50 mins.

```none
for i in {2..13}; do ./cmdline-player kthw-$i.scr <<<"\n"; sleep 2; mv -f screencast.gif docs/images/kthw-$i.gif; sleep 2; done
```

That's it.
