# Changelog

## 0.1.1

- The README links to the docs on GitHub, so they work on the Forge

## 0.1.0

First release. Installs Vuls on Ubuntu 24.04 and 26.04 and AlmaLinux 9 and 10, and builds its scan list from PuppetDB. Scheduled scans are off by default.

- An install guide in `docs/guide/`, from an empty node to a finished scan and on to Soundwave, with a check for each step that says what a good answer looks like
- `include vuls` needs no Hiera data, and `vuls-scan.service` can be run by hand
- Windows nodes are assessed through `vuls server` from PuppetDB and the `vuls_windows` fact, without logging in
- `vuls::target` creates the scan account on Linux nodes, and only warns while its key is missing
- Each finished run is recorded in `/var/lib/vuls/last-complete-run`, for anything reading results on its own schedule
- Logs in to Linux nodes as `vulsscan` by default, so the scanner can carry `vuls::target` and be scanned too
