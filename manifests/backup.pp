# @summary Creates a resic backup cronjob
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
  $ensure       = 'present',
  $backup_flags = '',
  $forget_flags = '--prune --keep-last 7',
  $cron_user    = 'root',
  $cron_hour    = '3',
  $cron_minute  = '0',
  $environment  = [],
) {
  cron { $title:
    command     => "/usr/local/bin/restic_backup.sh -r ${repo} -s ${files} -f '${forget_flags}' -b '${backup_flags}' >> /var/log/restic/${title}-$(date +\%F).log",
    ensure      => $ensure,
    user        => $cron_user,
    hour        => $cron_hour,
    minute      => $cron_minute,
    environment => concat($restic::default_environment, $environment),
  }
}
