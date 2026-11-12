# 1. Plan the scanner

## Why

Vuls logs in to every Linux node over SSH and downloads a database of about 10 GB, so the scanner needs the disk, the memory, and the routes.

## Before you start

- Puppet 8 with PuppetDB. The scan list comes from PuppetDB, so without it nothing is scanned
- eyaml, to encrypt the scan key in step 3

## Do it

Pick a node that meets the [requirements](../../README.md#requirements): Ubuntu 24.04 or 26.04 or AlmaLinux 9 or 10, about 20 GB of disk, and the memory for `vuls::memory_max`, 8 GB by default. If you'll send both Vuls's and Greenbone's findings to Puppet Enterprise, it has to be the Greenbone scanner, because Soundwave reads both on one node and PE takes one Soundwave.

Check the network from that node:

- Outbound HTTPS, to download the Vuls release from GitHub and its database
- TCP 22 to every Linux node you want scanned, at its `networking.ip` fact

Windows nodes need no route, because they're assessed from what PuppetDB knows. See [Windows](../configuration.md#windows).

## Done when

On the scanner:

```sh
free -g | awk '/Mem/ {print $2 " GB"}'; df -h /var
sudo puppet agent -t
```

At least 8 GB of memory, 20 GB free under `/var`, and an agent run that completes.

## If it fails

A node the scanner can't reach is still listed and comes back with nothing. Leave whole networks out with `vuls::exclude_patterns`. See [Leaving nodes out](../configuration.md#leaving-nodes-out).

## Next

[Install Vuls](02-install.md).
