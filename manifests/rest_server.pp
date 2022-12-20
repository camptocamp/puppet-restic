# restic rest server class

class restic::rest_server (
  Array[String] $extra_groups = [],
  Boolean $manage_group = true,
  Boolean $manage_user = true,
  Boolean $service_active = true,
  Boolean $service_enable = true,
  String $arch = 'linux_amd64',
  String $backups_path = '/tmp/restic',
  String $bin_dir = '/usr/local/bin',
  String $group = 'restic',
  String $server_parameters = '',
  String $service_name = 'rest-server',
  String $user = 'restic',
  String $usershell = '/usr/sbin/nologin',
  String $version = '0.11.0',
) {
  archive { "/tmp/rest-server-${version}.tar.gz":
    ensure          => present,
    extract         => true,
    extract_path    => '/opt',
    source          => "https://github.com/restic/rest-server/releases/download/v${version}/rest-server_${version}_${arch}.tar.gz",
    checksum_verify => false,
    creates         => "/opt/rest-server_${version}_${arch}/rest-server",
    cleanup         => true,
  }
  -> file { "/opt/rest-server_${version}_${arch}/rest-server":
    owner => 'root',
    group => 'root',
    mode  => '0555'
  }
  -> file { "${bin_dir}/rest-server":
    ensure => link,
    target => "/opt/rest-server_${version}_${arch}/rest-server",
  }

  ~> systemd::unit_file { "${service_name}.service":
   content => template("${module_name}/rest-server.service.erb"),
   enable => true,
   active => true,
  }

  if $manage_user {
    User[$user] ~> Systemd::Unit_file["${service_name}.service"]
    ensure_resource('user', [$user], {
        ensure => 'present',
        system => true,
        groups => $extra_groups,
        shell  => $usershell,
    })

    if $manage_group {
      Group[$group] -> User[$user]
    }
  }
  if $manage_group {
    ensure_resource('group', [$group], {
        ensure => 'present',
        system => true,
    })
  }

}
