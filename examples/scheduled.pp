# Scan every Linux and Windows node weekly. In practice, keep the key in eyaml
# and these values in Hiera.
class { 'vuls':
  scan_schedule_enabled => true,
  scan_time             => 'Sun *-*-* 22:00:00',
  scan_ssh_private_key  => Sensitive('-----BEGIN OPENSSH PRIVATE KEY-----...'),
}
