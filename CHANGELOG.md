# Changelog

## 0.1.0

First release. Installs Vuls on Ubuntu 24.04 and builds its scan list from PuppetDB. Scheduled scans are off by default.

- `include vuls` needs no Hiera data, and `vuls-scan.service` can be run by hand
- Windows nodes are assessed through `vuls server` from PuppetDB and the `vuls_windows` fact, without logging in
- `vuls::target` creates the scan account on Linux nodes, and only warns while its key is missing
- Each finished run is recorded in `/var/lib/vuls/last-complete-run`, for anything reading results on its own schedule
