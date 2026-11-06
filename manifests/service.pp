# @summary The scan, as a systemd service with an optional timer.
# @api private
class vuls::service {
  assert_private()

  $etc     = '/etc/vuls'
  $var     = '/var/lib/vuls'
  $config  = "${etc}/config.toml"
  $enabled = $vuls::scan_schedule_enabled

  $condition = $vuls::scan_condition ? {
    undef   => '',
    default => "ExecCondition=+${vuls::scan_condition}\n",
  }

  # The scan step may fail (the leading -): Vuls exits 1 when any one host
  # can't be scanned, and that would throw away every other host's results.
  # Nothing is hidden by carrying on. A configured host with no result is
  # visible to anything reading the run, and a run where nothing scanned leaves
  # the report nothing to read, which still fails the unit.
  #
  # -ignore-unfixed drops what no patch can close, which on Ubuntu is nearly
  # every CVE Vuls reports.
  #
  # The last step records the run as complete, so it only names a run that got
  # through every step before it, and keeps a copy of the configuration that run
  # used in its .scanned directory.
  #
  # The timer is declared either way, so the service exists to run by hand.
  systemd::timer { 'vuls-scan.timer':
    ensure          => present,
    service_unit    => 'vuls-scan.service',
    active          => $enabled,
    enable          => $enabled,
    timer_content   => @("EOT"),
      [Timer]
      OnCalendar=${vuls::scan_time}
      Unit=vuls-scan.service

      [Install]
      WantedBy=timers.target
      | EOT
    service_content => @("EOT"),
      [Unit]
      Description=Vuls scan and report
      After=network-online.target
      Wants=network-online.target

      [Service]
      Type=oneshot
      User=vuls
      Group=vuls
      WorkingDirectory=${var}
      Environment=HOME=${var}
      MemoryMax=${vuls::memory_max}
      TimeoutStartSec=4h
      ${condition}ExecStart=-/usr/local/bin/vuls scan -config=${config} -results-dir=${var}/results -log-dir=${var}/log
      ExecStart=/usr/local/bin/vuls report -config=${config} -results-dir=${var}/results -log-dir=${var}/log -format-json -to-localfile -ignore-unfixed -no-progress
      ExecStart=/usr/local/sbin/vuls-windows-collect --config=${etc}/windows.json --vuls-config=${config} --results-dir=${var}/results
      ExecStart=/usr/local/sbin/vuls-mark-complete ${var}/results ${var}/last-complete-run ${config} ${etc}/windows.json
      ExecStartPost=/usr/bin/find ${var}/results -mindepth 1 -maxdepth 1 -type d -mtime +${vuls::keep_days} -exec rm -rf {} +
      | EOT
  }
}
