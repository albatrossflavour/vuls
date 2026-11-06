# @summary Makes a Linux node ready to be scanned by Vuls.
#
# Include this on the nodes you scan; the scanner itself takes `vuls`. It
# creates the account Vuls logs in as, with the scan key's public half. It
# reads the scanner's `vuls::scan_login`, so the login is set once for both.
#
# Safe to include everywhere before the key exists: without it it warns and
# changes nothing. On Windows it does nothing, because Vuls reads Windows nodes
# from facts and never logs in to them.
#
# To use an account that already exists, set `manage_user` to false, and the
# class only adds the key.
#
# @param ssh_public_key
#   The whole line from the `.pub` file, such as `ssh-rsa AAAA... vuls-scan`.
# @param login
#   The account name. Defaults to `vuls::scan_login`, then `vuls`.
# @param manage_user
#   Whether to create the account. Set false for an account that already
#   exists or is managed elsewhere.
# @param ssh_key_name
#   The name of the authorised key, `<login>-vuls` by default. Declared with
#   stdlib's `ensure_resource`, so another module describing the same key under
#   the same name, such as a second scanner sharing this account, declares it
#   once. The same name for a different key fails the catalogue.
#
# @example In a profile every scanned node gets
#   include vuls::target
#
# @example Hiera, common to the scanner and the nodes
#   vuls::target::ssh_public_key: "ssh-rsa AAAAB3Nza... vuls-scan"
class vuls::target (
  Optional[Pattern[/\A(ssh|ecdsa|sk)-\S+ \S+/]] $ssh_public_key = undef,
  Optional[String[1]] $login = undef,
  Boolean $manage_user = true,
  Optional[String[1]] $ssh_key_name = undef,
) {
  # The scanner's key, so one Hiera value serves the scanner and the nodes.
  $_login = $login.lest || { lookup('vuls::scan_login', String[1], 'first', 'vuls') }

  if $facts['os']['family'] == 'windows' {
    # Nothing to do: Vuls never logs in to Windows.
  } elsif $ssh_public_key =~ Undef {
    warning('vuls::target: vuls::target::ssh_public_key is not set, so no scan account is created')
  } else {
    $key = $ssh_public_key.split(' ')
    $_key_name = $ssh_key_name.lest || { "${_login}-vuls" }

    if $manage_user {
      user { $_login:
        ensure     => present,
        managehome => true,
        shell      => '/bin/bash',
        before     => Ssh_authorized_key[$_key_name],
      }
    }

    ensure_resource('ssh_authorized_key', $_key_name, {
      'ensure' => 'present',
      'user'   => $_login,
      'type'   => $key[0],
      'key'    => $key[1],
    })
  }
}
