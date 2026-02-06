# @summary Creates a restic backup cronjob
#
# The define allows to create a restic backup cronjob
#
# @example
#   class { 'restic':
#     default_environment = [
#       RESTIC_PASSWORD       = 'mypassword',
#       AWS_ACCESS_KEY_ID     = 'DEADBEEF',
#       AWS_SECRET_ACCESS_KEY = 'DEADBEEF',
#     ],
#   }
#
#   restic::backup { 'namevar':
#     repo         = 's3:s3.amazonaws.com/bucket_name',
#     files        = '/',
#     backup_flags = '--exclude /dev --exclude /proc'
#   }

# @param ensure
#   Whether the cronjob should be present or absent
# @param repo
#   The restic repository to use
# @param files
#   The files to backup
# @param backup_flags
#   Additional flags to pass to the backup command
# @param forget_flags
#   Additional flags to pass to the forget flag (default: --prune --keep-last 7)
# @param textfile_flag
#   Additional flags to pass to the textfile flag
# @param command_flags
#   Additional flags to pass to the command flag
# @param cron_user
#   The user to run the cronjob as
# @param cron_day
#   The day to run the cronjob on (default: *)
# @param cron_hour
#   The hour to run the cronjob on (default: 3)
# @param cron_minute
#   The minute to run the cronjob on (default: 0)
# @param environment
#   Additional environment variables to set for the cronjob
define restic::backup (
  Variant[String,Sensitive[String]] $repo,
  String $files,
  String $ensure                       = 'present',
  Optional[String] $backup_flags       = undef,
  String $forget_flags                 = '--prune --keep-last 7',
  Optional[String] $textfile_flag      = undef,
  Optional[String] $command_flags      = undef,
  String $cron_user                    = 'root',
  Variant[String,Integer] $cron_day    = '*',
  Variant[String,Integer] $cron_hour   = '3',
  Variant[String,Integer] $cron_minute = '0',
  Hash[String,String]  $environment    = {},
) {
  if $repo =~ Sensitive {
    file { "${restic::bin_path}/backup.sh":
      mode    => '0755',
      content => stdlib::deferrable_epp("${module_name}/backup.sh.epp",
        {
          'repo'          => $repo,
          'files'         => $files,
          'forget_flags'  => $forget_flags,
          'command_flags' => $command_flags,
          'textfile_flag' => $textfile_flag,
          'backup_flags'  => $backup_flags,
          'title'         => $title,
          'environment'   => $restic::default_environment + $environment,
        },
      ),
    }
  } else {
    file { "${restic::bin_path}/backup.sh":
      mode    => '0755',
      content => epp("${module_name}/backup.sh.epp",
        {
          'repo'          => $repo,
          'files'         => $files,
          'forget_flags'  => $forget_flags,
          'command_flags' => $command_flags,
          'textfile_flag' => $textfile_flag,
          'backup_flags'  => $backup_flags,
          'title'         => $title,
          'environment'   => $restic::default_environment + $environment,
        },
      ),
    }
  }
  cron { $title:
    ensure  => $ensure,
    command => "${restic::bin_path}/backup.sh",
    user    => $cron_user,
    weekday => $cron_day,
    hour    => $cron_hour,
    minute  => $cron_minute,
  }
}
