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
  String $version                    = '0.18.0',
  String $checksum                   = '98f6dd8bf5b59058d04bfd8dab58e196cc2a680666ccee90275a3b722374438e',
  String $checksum_type              = 'sha256',
  Variant[Hash[String,String],Hash[String,Deferred]] $default_environment = {},
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
