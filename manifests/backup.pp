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
define restic::backup (
  $repo,
  $files,
  $ensure        = 'present',
  $backup_flags  = '',
  $forget_flags  = '--prune --keep-last 7',
  $textfile_flag = '',
  $cron_user     = 'root',
  $cron_day      = '*',
  $cron_hour     = '3',
  $cron_minute   = '0',
  $environment   = [],
) {
  cron { $title:
    ensure      => $ensure,
    command     => "/usr/local/bin/restic_backup.sh -r ${repo} -s '${files}' -f '${forget_flags}' -b '${backup_flags}' ${textfile_flag} >> /var/log/restic/${title}.log",
    user        => $cron_user,
    weekday     => $cron_day,
    hour        => $cron_hour,
    minute      => $cron_minute,
    environment => concat($restic::default_environment, $environment),
  }
}
