# @summary Vuls, the agentless vulnerability scanner, with what it scans built
# from PuppetDB.
#
# A bare include installs a pinned Vuls release, builds its configuration from
# every active Linux node in PuppetDB, and installs the scan as a systemd
# service. Nothing scans on a schedule until `scan_schedule_enabled` is true;
# until then `systemctl start vuls-scan.service` runs it by hand.
#
# Linux nodes are scanned over SSH as `scan_login`, with host keys from
# PuppetDB's ssh facts. Windows nodes are assessed through `vuls server` from
# what PuppetDB and the `vuls_windows` fact already know, so nothing logs in to
# them. `vuls::target` prepares a Linux node to be scanned.
#
# When a scan has finished every step, the run it produced is recorded in
# `/var/lib/vuls/last-complete-run`. Anything reading results on its own
# schedule should read that run, not the newest directory.
#
# @param version
#   Vuls release to install.
# @param sha256
#   SHA-256 of that release's linux_amd64 tarball, from its checksums.txt.
# @param scan_login
#   The account Vuls logs in to Linux nodes as. Not `vuls`, the scanner's own
#   service account, so `vuls::target` can go on the scanner too.
# @param scan_ssh_private_key
#   The private key it logs in with. Without one, Linux nodes can't be scanned.
# @param exclude
#   Certnames to leave out.
# @param exclude_patterns
#   Regular expressions; a Linux node whose certname matches any is left out,
#   for whole networks the scanner can't reach.
# @param scan_schedule_enabled
#   Run the scan on `scan_time`. Off by default.
# @param scan_time
#   systemd OnCalendar for the scheduled scan.
# @param scan_condition
#   A command run as root before each scan; the scan is skipped when it exits
#   non-zero. For keeping out of another scanner's way.
# @param memory_max
#   Hard memory ceiling for a run. Vuls's database is about 13 GB, and a run
#   over a few dozen nodes peaks around 6 GB.
# @param keep_days
#   Days of results to keep.
#
# @example
#   include vuls
#
# @example Scheduled, with credentials
#   class { 'vuls':
#     scan_schedule_enabled => true,
#     scan_ssh_private_key  => Sensitive('-----BEGIN OPENSSH PRIVATE KEY-----...'),
#   }
class vuls (
  String[1]                      $version               = '0.40.1',
  String[64, 64]                 $sha256                = '31fc4660f3266916f8d4fb30c2c4a5477a912f0178573853f4ce19dd2a1f91f4',
  String[1]                      $scan_login            = 'vulsscan',
  Optional[Sensitive[String[1]]] $scan_ssh_private_key  = undef,
  Array[String[1]]               $exclude               = [],
  Array[String[1]]               $exclude_patterns      = [],
  Boolean                        $scan_schedule_enabled = false,
  String[1]                      $scan_time             = '*-*-* 02:15:00',
  Optional[String[1]]            $scan_condition        = undef,
  String[1]                      $memory_max            = '8G',
  Integer[1]                     $keep_days             = 3,
) {
  contain vuls::install
  contain vuls::config
  contain vuls::service

  Class['vuls::install'] -> Class['vuls::config'] -> Class['vuls::service']
}
