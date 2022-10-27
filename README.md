# Documentation

The Sovereign Stack scripts in this repository are meant to be cloned to and executed from your management machine.

You can update Sovereign Stack scripts on your management machine by running `git pull --all --tags`. Generally, you want to use ONLY signed git tags for your deployments. Use `git checkout v0.1.0` for example to switch to a specific version of Sovereign Stack. The scripts check to ensure that the code you're running on your management machine is GREATER THAN OR EQUAL TO the version of your deployments (TODO). The scripts work to bring your old deployments into line with the current Sovereign Stack version.

Once your managent machine checkedout a specific version of Sovereign stack, you will want to run the various scripts against your remotes. But before you can do that, you need to bring a bare-metal Ubuntu 22.04 cluster host under management (i.e., add it as a remote). Generally speaking you will run `ss-cluster` to bring a new bare-metal host under management of your management machine. This can be run AFTER you have verified SSH access to the bare-metal hosts. The device SHOULD also have a DHCP Reservation and DNS records in place. 

After you have taken a machine under management, you can run `ss-deploy` it. All Sovereign Stack scripts execute against your current lxc remote. (Run `lxc remote list` to see your remotes). This will deploy Sovereign Stack software to your active remote in accordance with the various cluster, project, and site defintions. These files are stubbed out for the user automatically and documetnation guides the user through the process.

It is the responsiblity of the management machine (i.e,. system owner) to run the scripts on a regular and ongoing basis to ensure active deployments stay up-to-date with the Sovereign Stack master branch.

By default (i.e., without any command line modifiers), Sovereign Stack scripts will back up active deployments resulting in minimal downtime. (zero downtime for Ghost, minimal for Nextcloud/Gitea, BTCPAY Server).

All other documentation for this project can be found at the [sovereign-stack.org](https://www.sovereign-stack.org).