# @summary What Vuls scans, from PuppetDB, and how it logs in.
# @api private
class vuls::config {
  assert_private()

  $etc   = '/etc/vuls'
  $var   = '/var/lib/vuls'
  $key   = "${etc}/scan_key"
  $login = $vuls::scan_login

  file { $etc:
    ensure => directory,
    owner  => 'root',
    group  => 'vuls',
    mode   => '0750',
  }

  if $vuls::scan_ssh_private_key =~ Undef {
    file { $key:
      ensure => absent,
    }
  } else {
    file { $key:
      ensure  => file,
      owner   => 'root',
      group   => 'vuls',
      mode    => '0640',
      content => "${vuls::scan_ssh_private_key.unwrap.chomp}\n".node_encrypt::secret,
    }
  }

  # Every active Linux node PuppetDB knows, with its address and host keys.
  $rows = vuls::puppetdb_rows('inventory[certname, facts.networking.ip, facts.os.family, facts.ssh] { node_state = "active" and facts.os.family != "windows" }')
  # A test double or an odd PuppetDB answer can be a Hash; that is no data.
  $linux_rows = $rows ? {
    Array   => $rows,
    default => [],
  }
  $usable = $linux_rows.filter |$r| {
    $r['facts.networking.ip'] =~ String[1] and $r['facts.ssh'] =~ Hash and !($r['certname'] in $vuls::exclude) and
    !$vuls::exclude_patterns.any |$p| { $r['certname'] =~ Regexp($p) }
  }
  if $usable.empty {
    warning('vuls: PuppetDB gave no Linux nodes to scan')
  }
  # Sorted by certname so the rendered files don't churn between runs.
  $by_certname = $usable.reduce({}) |$memo, $r| { $memo + { $r['certname'] => $r } }
  $nodes = $by_certname.keys.sort.map |$certname| { $by_certname[$certname] }

  # DSA host keys are skipped: some nodes still report one, OpenSSH hasn't
  # offered ssh-dss for years, and its presence fails Vuls's host key check on
  # exactly those nodes ("Failed to find the server key that matches the key
  # registered in the client").
  $known_hosts = $nodes.map |$r| {
    $r['facts.ssh'].values.filter |$k| {
      $k =~ Hash and $k['type'] =~ String[1] and $k['key'] =~ String[1] and $k['type'] != 'ssh-dss'
    }.map |$k| {
      "${r['facts.networking.ip']},${r['certname']} ${k['type']} ${k['key']}"
    }
  }.flatten

  # Windows goes through `vuls server` rather than SSH: Windows nodes usually
  # have no sshd, and Vuls has no WinRM. Everything it needs is already in
  # PuppetDB except the update build revision and the hotfix list, which the
  # vuls_windows fact supplies.
  #
  # A node missing the fact is left out rather than sent with a partial version:
  # Vuls answers a wrong version with a confident zero.
  $windows_rows = vuls::puppetdb_rows('inventory[certname, facts.networking.ip, facts.kernelrelease, facts.os, facts.vuls_windows] { node_state = "active" and facts.os.family = "windows" }')
  $windows_list = $windows_rows ? {
    Array   => $windows_rows,
    default => [],
  }
  $windows = $windows_list.filter |$r| {
    $r['facts.vuls_windows'] =~ Hash and $r['facts.vuls_windows']['ubr'] =~ String[1] and
    $r['facts.kernelrelease'] =~ String[1] and !($r['certname'] in $vuls::exclude)
  }.sort |$a, $b| { compare($a['certname'], $b['certname']) }

  file { "${etc}/windows.json":
    ensure  => file,
    owner   => 'root',
    group   => 'vuls',
    mode    => '0640',
    content => stdlib::to_json_pretty($windows.map |$r| {
      {
        'certname'          => $r['certname'],
        'ipaddress'         => $r['facts.networking.ip'],
        'kernel_release'    => $r['facts.kernelrelease'],
        'ubr'               => $r['facts.vuls_windows']['ubr'],
        'hotfixes'          => $r['facts.vuls_windows']['hotfixes'].lest || { [] },
        'product_name'      => dig($r, 'facts.os', 'windows', 'product_name'),
        'installation_type' => dig($r, 'facts.os', 'windows', 'installation_type'),
        'release_major'     => dig($r, 'facts.os', 'release', 'major'),
      }
    }),
  }

  file { "${etc}/known_hosts":
    ensure  => file,
    owner   => 'root',
    group   => 'vuls',
    mode    => '0640',
    content => "# Managed by Puppet (vuls), from PuppetDB ssh facts\n${known_hosts.join("\n")}\n",
  }

  # Vuls forces StrictHostKeyChecking=yes, which a host's own ssh config may not
  # be able to pass, so this file is Vuls's alone.
  file { "${etc}/ssh_config":
    ensure  => file,
    owner   => 'root',
    group   => 'vuls',
    mode    => '0640',
    content => @("EOT"),
      # Managed by Puppet (vuls)
      Host *
        User ${login}
        IdentityFile ${key}
        IdentitiesOnly yes
        UserKnownHostsFile ${etc}/known_hosts
        StrictHostKeyChecking yes
        ConnectTimeout 10
      | EOT
  }

  # Servers are named by certname and scanned at the address PuppetDB reports.
  #
  # RedHat scans offline. In fast mode Vuls asks the node for its updatable
  # packages with `sudo repoquery`, and the scan account needs no sudo, so every
  # EL host would warn and the run exit 1. Offline skips that query; CVE
  # detection compares installed versions against the advisories either way,
  # and the only loss is the "a newer version exists" note.
  $servers = $nodes.map |$r| {
    $mode = $r['facts.os.family'] ? {
      'RedHat' => "scanMode = [\"offline\"]\n",
      default  => '',
    }
    "[servers.\"${r['certname']}\"]\nhost = \"${r['facts.networking.ip']}\"\n${mode}"
  }.join("\n")

  file { "${etc}/config.toml":
    ensure  => file,
    owner   => 'root',
    group   => 'vuls',
    mode    => '0640',
    content => @("EOT"),
      # Managed by Puppet (vuls)
      [vuls2]
      Path = "${var}/vuls.db"

      [default]
      port = "22"
      user = "${login}"
      keyPath = "${key}"
      sshConfigPath = "${etc}/ssh_config"
      scanMode = ["fast"]
      scanModules = ["ospkg"]

      ${servers}
      | EOT
  }
}
