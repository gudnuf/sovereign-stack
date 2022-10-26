# Documentation

The Sovereign Stack scripts in this repository are meant to be cloned to and executed from your management machine.

You can update Sovereign Stack scripts on your management machine by running `git pull --all`. Generally, you want to use ONLY signed git tags for your deployments. Use `git checkout v0.1.0` for example to switch to a specific version of Sovereign Stack. The scripts ensure check to ensure that the code you're running on your management machine is GREATER THAN OR EQUAL TO each of your active deployments (TODO).

Once your managent machine is using a specific version of code, you will want to run the various scripts. But before you can do that, you need to bring a bare-metal Ubuntu 22.04 cluster host under management. Generally speaking you will run `ss-cluster` to bring a new bare-metal host under management of your management machine. This can be run AFTER you have verified SSH access to the bare-metal hosts. The device SHOULD also have a DHCP Reservation and DNS records in place. 

After you have taken a machine under management, you can run `ss-deploy` it. All Sovereign Stack scripts execute against your current lxc remote. (Run `lxc remote list` to see your remotes). This will deploy Sovereign Stack software to your active remote in accordance with the various cluster, project, and site defintions. These files are stubbed out for the user automatically and documetnation guides the user through the process.

It is the responsiblity of the management machine (i.e,. system owner) to run the scripts on a regular and ongoing basis to ensure active deployments stay up-to-date with the Sovereign Stack master branch.

All other documentation for this project can be found at the [sovereign-stack.org](https://www.sovereign-stack.org).