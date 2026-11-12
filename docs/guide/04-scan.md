# 4. Run a scan

## Why

Nothing is scanned until you decide it should be, because a scan crosses the whole estate. Run the first scan by hand, then decide whether later ones run on a schedule.

## Before you start

- Step 3 done, with every Linux node in configtest's list
- About 10 GB free for the database, which the first scan downloads
- `jq`, for the check below

## Do it

Run one by hand:

```sh
sudo systemctl start vuls-scan.service
```

It returns once the scan has finished, which on the first run includes the database download. To scan on a schedule, see [Scans are off by default](../../README.md#scans-are-off-by-default).

If Greenbone runs on the same node, keep the two from scanning at once. See [Keeping out of another scanner's way](../../README.md#keeping-out-of-another-scanners-way). With the openvas module that's:

```yaml
vuls::scan_condition: "/usr/local/sbin/greenbone-reconcile idle"
```

## Done when

```sh
sudo cat /var/lib/vuls/last-complete-run
sudo sh -c 'cd "$(cat /var/lib/vuls/last-complete-run)" && jq -r "[.serverName, (.errors | length)] | @tsv" *.json'
```

The first names today's run directory. The second has a line for every scanned Linux or Windows node, each with `0` errors. `last-complete-run` only moves once a run has finished every step, so if it still names an older directory, the run didn't finish.

## If it fails

| You see | Because | Do |
|---|---|---|
| `last-complete-run` doesn't exist or didn't move | The run failed part way | `sudo journalctl -u vuls-scan.service -o cat` |
| The service was skipped | `vuls::scan_condition` exited non-zero, such as Greenbone scanning | Run it again later |
| A node with errors | It couldn't be reached or logged in to | Go back to the configtest check in step 3 |
| A Windows node is missing | It has no `vuls_windows` fact yet | Run the agent on it. See [Windows](../../README.md#windows) |

## Next

To get the findings into Puppet Enterprise, [get ready for Soundwave](05-soundwave.md).
