# 3. Add scan credentials

## Why

Vuls reads the installed packages on each Linux node over SSH, so without an account to log in as it finds nothing there. Windows nodes need no account, only a fact this module ships.

## Before you start

- Step 2 done
- eyaml, to encrypt the private key
- A profile every scanned node gets, to put `vuls::target` in

## Do it

Follow [Credentials](../configuration.md#credentials): make a key, put both halves in Hiera at a level the scanner and the scanned nodes read, and include `vuls::target` on the scanned nodes. Run the agent on the scanned nodes, then on the scanner.

The account needs no sudo. If another scanner already logs in as the same account, see [Sharing the account with another scanner](../configuration.md#sharing-the-account-with-another-scanner).

## Done when

On the scanner, ask Vuls to check every server without scanning:

```sh
sudo -u vuls sh -c 'cd /var/lib/vuls && /usr/local/bin/vuls configtest -config=/etc/vuls/config.toml -log-dir=/var/lib/vuls/log'
```

It ends with `Scannable servers are below...` and a list of certnames. Every Linux node should be in it. A node missing from the list has an error line above it saying why.

For Windows, on the Puppet server:

```sh
sudo puppet query 'facts[certname] { name = "vuls_windows" and value != "" }'
```

lists every Windows node, once each has run the agent since the module was installed. On Linux the fact is empty.

## If it fails

| You see | Because | Do |
|---|---|---|
| `vuls::target::ssh_public_key is not set, so no scan account is created` | The node can't read the public key | Put it at a Hiera level the scanned nodes read, such as `common.yaml` |
| configtest reports an SSH authentication error for a node | The account or key isn't on that node yet | Run the agent on that node |
| configtest reports a host key error for a node | `/etc/vuls/known_hosts` comes from the node's ssh facts, which have changed since | Run the agent on that node, then on the scanner |
| configtest times out | TCP 22 is blocked from the scanner | Fix the route, or leave the node out |
| A Windows node has no `vuls_windows` value | It hasn't run the agent since pluginsync delivered the fact | Run the agent on it |

## Next

[Run a scan](04-scan.md).
