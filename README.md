# vuls

[Vuls](https://github.com/future-architect/vuls), the agentless vulnerability scanner, with what it scans built from PuppetDB.

## Two classes, on two kinds of node

| Class | Goes on | Does |
|---|---|---|
| `vuls` | the scanner | Installs Vuls, builds its scan list from PuppetDB, and runs the scan. Everything is a parameter on this class |
| `vuls::target` | every Linux node you want scanned | Creates the account Vuls logs in as. Put it in a profile every node gets |

They are separate because Puppet only changes the node it is running on. The scanner's catalogue can't create an account on another node, so each scanned node does that in its own.

`vuls::target` is safe to include everywhere before the key is in Hiera: it warns and changes nothing until it is. On Windows it does nothing, because Vuls never logs in there.

## What `include vuls` does

On a clean agent, with no Hiera data:

- Creates a `vuls` system account, and `/etc/vuls` and `/var/lib/vuls`
- Downloads a pinned Vuls release, checks its SHA-256, and installs it as `/usr/local/bin/vuls`
- Writes a configuration listing every active Linux node in PuppetDB by certname, with host keys from their ssh facts
- Writes the Windows nodes PuppetDB knows, for the Windows step
- Installs the scan as `vuls-scan.service`

## Scans are off by default

Nothing is scanned until you decide it should be, because a scan logs in to every node and Vuls downloads its database, about 10 GB, on a run when its copy is more than an hour old.

Run it by hand:

```sh
sudo systemctl start vuls-scan.service
```

Or on a schedule:

```yaml
vuls::scan_schedule_enabled: true
vuls::scan_time: "Sun *-*-* 22:00:00"
```

`scan_time` is a systemd `OnCalendar` value, daily at 02:15 by default.

## Requirements

- Ubuntu 24.04. Nothing else is tested yet
- Puppet 8 with PuppetDB. Without PuppetDB, Vuls still installs, with nothing to scan, and the run warns
- About 20 GB of disk for the database and results, and memory for `memory_max`, 8 GB by default

## Credentials

Vuls logs in to Linux nodes over SSH as `vuls::scan_login`, `vuls` by default. Make a key without a passphrase, since the module has no passphrase setting:

```sh
ssh-keygen -t rsa -b 4096 -N '' -C vuls-scan -f vuls_scan
eyaml encrypt -l vuls::scan_ssh_private_key -f vuls_scan
```

Then, at a level both the scanner and the scanned nodes read:

```yaml
vuls::scan_ssh_private_key: ENC[PKCS7,...]                       # the scanner logs in with this
vuls::target::ssh_public_key: "ssh-rsa AAAAB3Nza... vuls-scan"   # the nodes accept this
```

and on the scanned nodes:

```puppet
include vuls::target
```

The account needs no sudo. RedHat-family nodes are scanned in Vuls's offline mode for that reason: fast mode asks the node for its updatable packages with `sudo repoquery`, and offline skips that question. CVE detection compares installed versions against the advisories either way.

### Choosing the account

`vuls::target` creates an account named `vuls::scan_login`, so setting that once changes both. To use an account that already exists, or that something else manages, set `vuls::target::manage_user: false`, and the class only adds the key.

### Sharing the account with another scanner

The key is added as `<login>-vuls` by default, and `vuls::target::ssh_key_name` changes that. When another scanner logs in as the same account with the same key, give both the same key name: the key is declared once and appears once in `authorized_keys`. The same name with a different key fails the catalogue, naming the clash.

## Windows

Windows nodes are assessed without logging in. Vuls has no WinRM, and Windows nodes usually have no SSH, so the scan posts what PuppetDB knows about each one to a short-lived `vuls server` on the scanner. Two things PuppetDB doesn't carry, the update build revision and the installed hotfix list, come from the `vuls_windows` fact this module ships. Pluginsync puts it on every node, so Windows needs no class.

A Windows node without that fact yet is left out, rather than sent with a partial version, because Vuls answers a wrong version with a confident zero.

## Reading results from another tool

Each run writes a directory under `/var/lib/vuls/results`. A scan that runs long can still be writing its directory when something else looks, so read the run named in `/var/lib/vuls/last-complete-run` instead of the newest directory. That file is only written once a run has finished every step, and it holds the run directory's full path. The run's `.scanned` directory holds the `config.toml` and `windows.json` it scanned with, so a reader can tell a host the run never attempted from one it couldn't reach, even after today's configuration has moved on.

Results older than `keep_days`, 3 by default, are removed after each run.

## Keeping out of another scanner's way

`vuls::scan_condition` is a command run as root before each scan, and the scan is skipped when it exits non-zero:

```yaml
vuls::scan_condition: "/usr/local/sbin/some-scanner-check idle"
```

## Leaving nodes out

```yaml
vuls::exclude:
  - db1.example.com
vuls::exclude_patterns:
  - '\.cloud\.example\.com$'
```

`exclude_patterns` are regular expressions matched against the certname, for whole networks the scanner can't reach. A node the scanner can't reach is otherwise still listed and comes back with nothing.

## Removing it

Removing the class leaves everything in place. To remove it by hand:

```sh
sudo systemctl disable --now vuls-scan.timer
sudo rm -rf /etc/vuls /var/lib/vuls /opt/vuls /usr/local/bin/vuls /usr/local/sbin/vuls-windows-collect /usr/local/sbin/vuls-mark-complete
sudo rm -f /etc/systemd/system/vuls-scan.timer /etc/systemd/system/vuls-scan.service
sudo userdel vuls
```

## Limitations

- Ubuntu 24.04 only, for the scanner
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

See `REFERENCE.md` for every parameter.

## Licence

Apache-2.0.
