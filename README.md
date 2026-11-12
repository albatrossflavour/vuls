# vuls

[Vuls](https://github.com/future-architect/vuls), the agentless vulnerability scanner, checking the installed packages on every node in your Puppet estate. The module builds Vuls's scan list from PuppetDB, so a new node is scanned without anyone editing Vuls. Linux nodes are scanned over SSH with an account that needs no sudo, and Windows nodes are assessed from what PuppetDB knows about them, without logging in.

It works on its own, writing a JSON result per node. To get the findings into Puppet Enterprise Vulnerability Remediation, add [Soundwave](https://github.com/albatrossflavour/soundwave).

## What it installs

| Class | Goes on | Does |
|---|---|---|
| `vuls` | the scanner | Installs Vuls, builds its scan list from PuppetDB, and runs the scan. Everything is a parameter on this class |
| `vuls::target` | every Linux node you want scanned | Creates the account Vuls logs in as. Put it in a profile every node gets |

They are separate because Puppet only changes the node it is running on. The scanner's catalogue can't create an account on another node, so each scanned node does that in its own.

`vuls::target` is safe to include everywhere before the key is in Hiera: it warns and changes nothing until it is. On Windows it does nothing, because Vuls never logs in there.

### What `include vuls` does

On a clean agent, with no Hiera data:

- Creates a `vuls` system account, and `/etc/vuls` and `/var/lib/vuls`
- Downloads a pinned Vuls release, checks its SHA-256, and installs it as `/usr/local/bin/vuls`
- Writes a configuration listing every active Linux node in PuppetDB by certname, with host keys from their ssh facts
- Writes the Windows nodes PuppetDB knows, for the Windows step
- Installs the scan as `vuls-scan.service`, and schedules nothing. Nothing is scanned until you run it or turn the schedule on, because a scan logs in to every node

## Requirements

- Ubuntu 24.04, where it runs in production. A bare install on AlmaLinux 9 and 10 and Ubuntu 26.04 was tested on 2026-11-09, without running a scan
- Puppet 8 with PuppetDB. Without PuppetDB, Vuls still installs, with nothing to scan, and the run warns
- About 20 GB of disk for the database and results, and memory for `memory_max`, 8 GB by default

## Getting started

Follow [the install guide](docs/guide/README.md). It goes from an empty node to a finished scan one step at a time, with a check at the end of each, and on to Soundwave if you want the findings in PE.

## Reference

- Schedules, credentials, Windows, leaving nodes out, sharing a node with Greenbone, and reading the results from another tool: [configuration](docs/configuration.md)
- Removing it: [operating](docs/operating.md)
- Every class and parameter: [REFERENCE.md](REFERENCE.md)
- What changed in each release: [CHANGELOG.md](CHANGELOG.md)

## Limitations

- Ubuntu 24.04, 26.04, and AlmaLinux 9 and 10 for the scanner
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
