#!/bin/bash

push_metrics()
{
  if [ "$TEXTFILE_COLLECTOR" = true ] ; then
    # Write out metrics to a temporary file if textfile collecting is enabled
    echo "$1" > "$TEXTFILE_COLLECTOR_DIR/restic-snapshot.prom.$$"
    # move the textfile atomically (to avoid the exporter seeing half a file)
    mv "$TEXTFILE_COLLECTOR_DIR/restic-snapshot.prom.$$" "$TEXTFILE_COLLECTOR_DIR/restic-snapshot$(echo $SOURCE | tr '/' '_' | tr ' ' '+').prom"
  else
    # By default send data to the local pushgateway
    echo "$1" | curl -X"$2" --data-binary @- http://127.0.0.1:9091/metrics/job/restic/files/"$(echo "$SOURCE" | tr '/' '_' | tr ' ' '+')"
  fi
}

log()
{
  echo "[$(date '+%F %T %Z')] $@"
}

while getopts ":r:s:f:c:b:t" opt; do
  case ${opt} in
    r )
      REPO=$OPTARG
      ;;
    s )
      SOURCE=$OPTARG
      ;;
    f )
      FORGET_ARGS=$OPTARG
      ;;
    c )
      COMMAND_ARGS=$OPTARG
      ;;
    b )
      BACKUP_ARGS=$OPTARG
      ;;
    t )
      TEXTFILE_COLLECTOR=true
      TEXTFILE_COLLECTOR_DIR=/var/lib/node_exporter/textfile_collector
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      exit 1
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

: "${FORGET_ARGS:="--keep-last 7"}"

if test -z "${REPO}" || test -z "${SOURCE}" ; then
  echo "Usage: $(basename "$0") -r <repo> -s <source> [-f <forget_args>] [-b <backup_args>] [-t]" 1>&2
  exit 1
fi

PATH="/usr/local/bin:$PATH" # Add restic cmd dir to path (if not set in crontab)

if [ "$TEXTFILE_COLLECTOR" = true ] ; then
  # clean up old textfile
  rm "$TEXTFILE_COLLECTOR_DIR/restic-snapshot$(echo $SOURCE | tr '/' '_' | tr ' ' '+').prom"
fi

echo
log Test if the repo exists
restic $COMMAND_ARGS --json -r "$REPO" snapshots --last > /dev/null
rc=$?

if [ $rc -ne 0 ]; then
  log Initialize the repo
  restic $COMMAND_ARGS --json -r "$REPO" init
  rc=$?

  if [ $rc -ne 0 ]; then
    log Failed to initialize the restic repo 2>&1
    read -r -d '' data <<EOF
# HELP restic_init_return_code Return code of restic init command
# TYPE restic_init_return_code gauge
restic_init_return_code{repo="$REPO",source="$SOURCE"} $rc
EOF
    push_metrics "$data" "POST"
    exit 1
  fi
fi

echo
log Launch backup
output=$(restic $COMMAND_ARGS --json -r "$REPO" backup $SOURCE $BACKUP_ARGS)
rc=$?
log "$output"

summary=$(echo "$output"|jq -s 'map(select(.message_type == "summary"))[0]')

read -r -d '' data<<EOF
# HELP restic_backup_return_code Return code of restic backup command
# TYPE restic_backup_return_code gauge
restic_backup_return_code{repo="$REPO",source="$SOURCE"} $rc

# HELP restic_backup_last Date of last backup
# TYPE restic_backup_last gauge
restic_backup_last{repo="$REPO",source="$SOURCE"} $(date +%s)

# HELP restic_backup_files_new Number of new files in snapshot
# TYPE restic_backup_files_new gauge
restic_backup_files_new{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.files_new')

# HELP restic_backup_files_changed Number of modified files in snapshot
# TYPE restic_backup_files_changed gauge
restic_backup_files_changed{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.files_changed')

# HELP restic_backup_files_unmodifed Number of unmodifed files in snapshot
# TYPE restic_backup_files_unmodifed gauge
restic_backup_files_unmodifed{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.files_unmodified')

# HELP restic_backup_dirs_new Number of new directories in snapshot
# TYPE restic_backup_dirs_new gauge
restic_backup_dirs_new{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.dirs_new')

# HELP restic_backup_dirs_changed Number of changed directories in snapshot
# TYPE restic_backup_dirs_changed gauge
restic_backup_dirs_changed{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.dirs_changed')

# HELP restic_backup_dirs_unmodified Number of unmodified directories in snapshot
# TYPE restic_backup_dirs_unmodified gauge
restic_backup_dirs_unmodified{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.dirs_unmodified')

# HELP restic_backup_data_blobs Number of data blobs
# TYPE restic_backup_data_blobs gauge
restic_backup_data_blobs{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.data_blobs')

# HELP restic_backup_tree_blobs Number of tree blobs
# TYPE restic_backup_tree_blobs gauge
restic_backup_tree_blobs{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.tree_blobs')

# HELP restic_backup_data_added Data added in bytes
# TYPE restic_backup_data_added gauge
restic_backup_data_added{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.data_added')

# HELP restic_backup_total_files_processed Total number of processed files
# TYPE restic_backup_total_files_processed gauge
restic_backup_total_files_processed{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.total_files_processed')

# HELP restic_backup_total_bytes_processed Total number of processed bytes
# TYPE restic_backup_total_bytes_processed gauge
restic_backup_total_bytes_processed{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.total_bytes_processed')

# HELP restic_backup_total_duration Restic backup command duration
# TYPE restic_backup_total_duration gauge
restic_backup_total_duration{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.total_duration')
EOF
push_metrics "$data" "POST"

echo
log Forget old backups
# The folling line returns a shellcheck warning, but I could not find a workaround
# as $FORGET_ARGS must not be quoted.
restic $COMMAND_ARGS --json -r "$REPO" forget $FORGET_ARGS
rc=$?

read -r -d '' data<<EOF
$data

# HELP restic_forget_return_code Return code of restic forget command
# TYPE restic_forget_return_code gauge
restic_forget_return_code{repo="$REPO",source="$SOURCE"} $rc

# HELP restic_forget_last Last restic forget
# TYPE restic_forget_last gauge
restic_forget_last{repo="$REPO",source="$SOURCE"} $(date +%s)
EOF
push_metrics "$data" "POST"

echo
log Prune old backups
restic $COMMAND_ARGS --json -r "$REPO" prune
rc=$?

read -r -d '' data<<EOF
$data

# HELP restic_prune_return_code Return code of restic prune command
# TYPE restic_prune_return_code gauge
restic_prune_return_code{repo="$REPO",source="$SOURCE"} $rc

# HELP restic_prune_last Last restic prune
# TYPE restic_prune_last gauge
restic_prune_last{repo="$REPO",source="$SOURCE"} $(date +%s)
EOF
push_metrics "$data" "POST"

echo
log Check after prune
restic $COMMAND_ARGS --json -r "$REPO" check
rc=$?

read -r -d '' data<<EOF
$data

# HELP restic_check_return_code Return code of restic check command
# TYPE restic_check_return_code gauge
restic_check_return_code{repo="$REPO",source="$SOURCE"} $rc

# HELP restic_check_last Last restic check
# TYPE restic_check_last gauge
restic_check_last{repo="$REPO",source="$SOURCE"} $(date +%s)
EOF
push_metrics "$data" "POST"

log Push statistics as metrics
stats_output=$(restic $COMMAND_ARGS --json -r "$REPO" stats 2> /dev/null)
echo "$stats_output"

read -r -d '' data<<EOF
$data

# HELP restic_stats_total_size Total size of repository in bytes
# TYPE restic_stats_total_size gauge
restic_stats_total_size{repo="$REPO",source="$SOURCE"} $(echo "$stats_output"|jq '.total_size')

# HELP restic_stats_total_file_count Number of files in repository
# TYPE restic_stats_total_file_count gauge
restic_stats_total_file_count{repo="$REPO",source="$SOURCE"} $(echo "$stats_output"|jq '.total_file_count')
EOF
push_metrics "$data" "POST"

echo
log Count the number of snapshots after prune
snapshots_output=$(restic $COMMAND_ARGS --json -r "$REPO" snapshots)
log "$snapshots_output"

read -r -d '' data<<EOF
$data

# HELP restic_snapshots_total Number of snapshots in repository
# TYPE restic_snapshots_total gauge
restic_snapshots_total{repo="$REPO",source="$SOURCE"} $(echo "$snapshots_output"|jq '. | length')
EOF

# PUT metrics
push_metrics "$data" "PUT"
