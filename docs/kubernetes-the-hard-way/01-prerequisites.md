>  **My Own Kind changes:**
> 
> * GCP section removed

# Prerequisites

## Install `mokctl`

Install `mokctl`. Instructions are on the [My Own Kind GitHub page](https://github.com/mclarkson/my-own-kind).

## Running Commands in Parallel with tmux

> NOTE: The `tmux` configuration used in all labs was set up as shown in [this Blog post](http://blogger.smorg.co.uk/2020/04/tmux-for-gnu-screen-users-on-linux.html?view=magazine). It changes the defaults, such as: C-a instead of C-b, C-a j to go down one pane.

[tmux](https://github.com/tmux/tmux/wiki) can be used to run commands on multiple compute instances at the same time. Labs in this tutorial may require running the same commands across multiple compute instances, in those cases consider using tmux and splitting a window into multiple panes with synchronize-panes enabled to speed up the provisioning process.

> The use of tmux is optional and not required to complete this tutorial.

![tmux screenshot](images/tmux-screenshot.png)

> Enable synchronize-panes by pressing `ctrl+b` followed by `shift+:`. Next type `set synchronize-panes on` at the prompt. To disable synchronization: `set synchronize-panes off`.

Next: [Installing the Client Tools](02-client-tools.md)
