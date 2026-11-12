# vuls

This module runs [Vuls](https://vuls.io/), the agentless vulnerability scanner, against every node in your Puppet estate, with the scan list kept in step with PuppetDB, so a new node is scanned without anyone editing Vuls. It checks installed packages against vendor advisories: Linux nodes over SSH, with an account that needs no sudo, and Windows nodes from what PuppetDB knows about them, without logging in.

It works on its own, writing a JSON result per node. [Soundwave](https://github.com/albatrossflavour/soundwave) pushes its findings, with any other scanner's, into [Vulnerability Remediation](https://help.puppet.com/pe/current/topics/advanced-patching-vulnerability-remediation.htm) in Puppet Enterprise Advanced, where PE shows which ones Puppet can patch.

## What it installs

| Class | Goes on | Does |
|---|---|---|
| `vuls` | the scanner | Installs Vuls, builds its scan list from PuppetDB, and runs the scan. Everything is a parameter on this class |
| `vuls::target` | every Linux node you want scanned | Creates the account Vuls logs in as. Put it in a profile every node gets |

`vuls::target` is safe to include everywhere before the key is in Hiera, because until then it warns and changes nothing, and on Windows it does nothing.

### What `include vuls` does

On a clean agent, with no Hiera data:

- Creates a `vuls` system account, and `/etc/vuls` and `/var/lib/vuls`
- Downloads a pinned Vuls release, checks its SHA-256, and installs it as `/usr/local/bin/vuls`
- Writes a configuration listing every active Linux node in PuppetDB by certname, with host keys from their ssh facts
- Writes the Windows nodes PuppetDB knows, for the Windows step
- Installs the scan as `vuls-scan.service`, and schedules nothing. Nothing is scanned until you run it or turn the schedule on, because a scan logs in to every node

## Requirements

- Ubuntu 24.04 or 26.04, or AlmaLinux 9 or 10
- Puppet 8 with PuppetDB
- About 20 GB of disk for the database and results, and memory for `memory_max`, 8 GB by default

## Getting started

Follow [the install guide](https://github.com/albatrossflavour/vuls/blob/main/docs/guide/README.md). It goes from an empty node to a finished scan, with a check at the end of each step, and on to Soundwave if you want the findings in VR.

## Reference

- Schedules, credentials, Windows, leaving nodes out, sharing a node with Greenbone, and reading the results from another tool: [configuration](https://github.com/albatrossflavour/vuls/blob/main/docs/configuration.md)
- Removing it: [operating](https://github.com/albatrossflavour/vuls/blob/main/docs/operating.md)
- Every class and parameter: [REFERENCE.md](https://github.com/albatrossflavour/vuls/blob/main/REFERENCE.md)
- What changed in each release: [CHANGELOG.md](https://github.com/albatrossflavour/vuls/blob/main/CHANGELOG.md)

## Limitations

- Linux packages only (`scanModules = ["ospkg"]`), in fast or offline mode
- Each node is scanned at its primary address, from the `networking.ip` fact
- The module has been run for real on one estate. It has no Litmus acceptance tests

## Development

```sh
pdk validate
pdk test unit
uvx pytest spec/python
```

`pdk test unit` fails below 100% resource coverage.

## Licence

Apache-2.0.
