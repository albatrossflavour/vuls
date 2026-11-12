# 2. Install Vuls

## Why

This installs Vuls and writes its configuration from PuppetDB. Nothing is scanned yet.

## Before you start

- Step 1 done
- The module and its dependencies (`puppetlabs-stdlib`, `puppet-systemd`, and `puppetlabs-node_encrypt`) in your Puppetfile, and deployed to the scanner's environment

## Do it

Add the class to the scanner's profile, and run the agent:

```puppet
include vuls
```

```sh
sudo puppet agent -t
```

[What `include vuls` does](../../README.md#what-include-vuls-does) lists everything this sets up.

## Done when

On the scanner:

```sh
/usr/local/bin/vuls -v
sudo grep -c '^\[servers\.' /etc/vuls/config.toml
```

The first prints the Vuls version. The second is the number of Linux nodes Vuls will scan, which should match the active Linux nodes in PuppetDB, less any you've excluded.

## If it fails

| You see | Because | Do |
|---|---|---|
| The install exec fails, and `/usr/local/bin/vuls` doesn't exist | The download from GitHub failed or didn't match `vuls::sha256` | Check the scanner reaches github.com, and run the agent again. Don't change the checksum to get past it |
| `vuls::puppetdb_rows:` warnings, or `vuls: PuppetDB gave no Linux nodes to scan` | PuppetDB couldn't be queried, or holds no active Linux nodes | Fix that and run the agent again |
| Fewer servers than expected | Nodes left out by `vuls::exclude` or `vuls::exclude_patterns`, or inactive in PuppetDB | Check both settings |

## Next

[Add scan credentials](03-credentials.md).
