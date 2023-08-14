# @summary Installs restic
#
# This class will install restic on the node
#
# @example Installing restic
#   class { 'restic': }
#
# @param version
#   The version of restic to install
# @param checksum
#   The checksum of the restic archive
# @param checksum_type
#   The type of checksum to use
# @param default_environment
#   The default environment to use
# @param install_path
#   The path to install restic to
# @param bin_path
#   The path to install the restic binary to
class restic (
  String $version                    = '0.9.5',
  String $checksum                   = '08cd75e56a67161e9b16885816f04b2bf1fb5b03bc0677b0ccf3812781c1a2ec',
  String $checksum_type              = 'sha256',
  Array[String] $default_environment = [],
  Stdlib::AbsolutePath $install_path = '/opt/restic',
  Stdlib::AbsolutePath $bin_path     = '/usr/local/bin',
) {
  file { $install_path:
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }
  -> archive { '/tmp/restic.bz2':
    ensure          => present,
    extract         => true,
    extract_path    => $install_path,
    extract_command => "bunzip2 -c %s > ${install_path}/restic-${version}",
    source          => "https://github.com/restic/restic/releases/download/v${version}/restic_${version}_linux_amd64.bz2",
    checksum        => $checksum,
    checksum_type   => $checksum_type,
    cleanup         => true,
    creates         => "${install_path}/restic-${version}",
    require         => Package['bzip2'],
  }
  -> file { "${install_path}/restic-${version}":
    ensure => file,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }
  -> file { "${bin_path}/restic":
    ensure => link,
    target => "${install_path}/restic-${version}",
  }
  file { '/var/log/restic':
    ensure => directory,
  }
  file { '/usr/local/bin/restic_backup.sh':
    ensure  => file,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => file("${module_name}/restic_backup.sh"),
  }
  file { '/etc/logrotate.d/restic':
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => file("${module_name}/logrotate.restic"),
  }
  ensure_packages(['bzip2', 'jq'], { 'ensure' => 'present' })
}
