# @summary The vuls account, its directories, the release, and the helpers.
# @api private
class vuls::install {
  assert_private()

  $version = $vuls::version
  $bin     = "/opt/vuls/vuls-${version}"
  $var     = '/var/lib/vuls'

  group { 'vuls':
    ensure => present,
    system => true,
  }

  user { 'vuls':
    ensure     => present,
    system     => true,
    gid        => 'vuls',
    home       => $var,
    managehome => false,
    # /sbin/nologin, not /usr/sbin/nologin, even where /sbin is a symlink: CIS
    # hardening commonly sets service accounts to /sbin/nologin, and the two
    # spellings would otherwise fight over the shell on every run.
    shell      => '/sbin/nologin',
    comment    => 'Vuls scanner, managed by Puppet',
  }

  file { [$var, "${var}/results", "${var}/log", "${var}/.vuls"]:
    ensure => directory,
    owner  => 'vuls',
    group  => 'vuls',
    mode   => '0750',
  }

  file { '/opt/vuls':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # Download, verify, and unpack in one exec, so a checksum mismatch leaves
  # nothing behind and fails the run.
  exec { "vuls-install-${version}":
    command => "sh -c 'set -e; t=\$(mktemp -d); curl -fsSL -o \$t/vuls.tgz https://github.com/future-architect/vuls/releases/download/v${version}/vuls_${version}_linux_amd64.tar.gz; echo \"${vuls::sha256}  \$t/vuls.tgz\" | sha256sum -c -; tar -xzf \$t/vuls.tgz -C \$t vuls; install -o root -g root -m 0755 \$t/vuls ${bin}; rm -rf \$t'",
    creates => $bin,
    path    => ['/usr/bin', '/bin'],
    require => File['/opt/vuls'],
  }

  file { '/usr/local/bin/vuls':
    ensure  => link,
    target  => $bin,
    require => Exec["vuls-install-${version}"],
  }

  file { '/usr/local/sbin/vuls-windows-collect':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/vuls/vuls-windows-collect.py',
  }

  file { '/usr/local/sbin/vuls-mark-complete':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/vuls/vuls-mark-complete',
  }
}
