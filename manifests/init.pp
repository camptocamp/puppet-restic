# @summary Installs restic
#
# This class will install restic on the node
#
# @example
#   include restic
class restic(
  $version       = '0.9.5',
  $checksum      = '08cd75e56a67161e9b16885816f04b2bf1fb5b03bc0677b0ccf3812781c1a2ec',
  $checksum_type = 'sha256',
) {
  archive { "restic_${version}_linux_amd64.bz2":
    ensure        => present,
    extract       => true,
    extract_path  => '/usr/local/bin',
    source        => "https://github.com/restic/restic/releases/download/v${version}/restic_${version}_linux_amd64.bz2",
    checksum      => $checksum,
    checksum_type => $checksum_type,
    creates       => "/usr/local/bin/restic_${version}_linux_amd64",
    cleanup       => true,
  }
}
