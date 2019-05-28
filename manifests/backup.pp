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
  $backup_flags = '',
  $forget_flags = '--prune --keep-weekly 3 --keep-daily 7 --keep-monthly 12',
  $cron_user    = 'root',
  $cron_hour    = '3',
  $cron_minute  = '0',
  $environment  = [],
) {
  cron { $title:
    command     => "restic -r ${repo} stats 2> /dev/null || restic -r ${repo} init && restic -r ${repo} backup ${backup_flags} ${files} && restic -r ${repo} forget ${forget_flags}",
    user        => $cron_user,
    hour        => $cron_hour,
    minute      => $cron_minute,
    environment => concat($restic::default_environment, $environment),
  }
}
