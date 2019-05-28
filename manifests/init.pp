# @summary Installs restic
#
# This class will install restic on the node
#
# @example
#   include restic
class restic(
  $version             = '0.9.5',
  $checksum            = '08cd75e56a67161e9b16885816f04b2bf1fb5b03bc0677b0ccf3812781c1a2ec',
  $checksum_type       = 'sha256',
  $default_environment = [],
) {
  archive { '/tmp/restic.bz2':
    ensure          => present,
    extract         => true,
    extract_path    => '/usr/local/bin',
    extract_command => 'bunzip2 -c %s > /usr/local/bin/restic',
    source          => "https://github.com/restic/restic/releases/download/v${version}/restic_${version}_linux_amd64.bz2",
    checksum        => $checksum,
    checksum_type   => $checksum_type,
    cleanup         => true,
    creates         => '/usr/local/bin/restic',
  }
  -> file { '/usr/local/bin/restic':
    ensure => file,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }
}
