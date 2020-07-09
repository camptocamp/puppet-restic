#!/bin/bash

push_metrics()
{
  if [ "$TEXTFILE_COLLECTOR" = true ] ; then
    # Write out metrics to a temporary file if textfile collecting is enabled
    echo "$1" >> "$TEXTFILE_COLLECTOR_DIR/restic-snapshot.prom.$$"
  else
    # By default send data to the local pushgateway
    echo "$1" | curl -X"$2" --data-binary @- http://127.0.0.1:9091/metrics/job/restic
  fi
}

move_textfile()
{
  # Before end of script, move the textfile atomically if enabled (to avoid the exporter seeing half a file)
  if [ "$TEXTFILE_COLLECTOR" = true ] ; then
    mv "$TEXTFILE_COLLECTOR_DIR/restic-snapshot.prom.$$" "$TEXTFILE_COLLECTOR_DIR/restic-snapshot.prom"
  fi
}

log()
{
  echo "[$(date '+%F %T %Z')] $@"
}

while getopts ":r:s:f:b:t" opt; do
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

echo
log Test if the repo exists
restic --json -r "$REPO" snapshots --last > /dev/null
rc=$?

if [ $rc -ne 0 ]; then
  log Initialize the repo
  restic --json -r "$REPO" init
  rc=$?

  if [ $rc -ne 0 ]; then
    log Failed to initialize the restic repo 2>&1
    read -r -d '' data <<EOF
# TYPE restic_init_return_code gauge
restic_init_return_code{repo="$REPO",source="$SOURCE"} $rc
EOF
    push_metrics "$data" "POST"
    move_textfile
    exit 1
  fi
fi

echo
log Launch backup
output=$(restic --json -r "$REPO" backup $SOURCE $BACKUP_ARGS)
rc=$?
log "$output"

summary=$(echo "$output"|jq 'select(.message_type == "summary")')

read -r -d '' data<<EOF
# TYPE restic_backup_return_code gauge
restic_backup_return_code{repo="$REPO",source="$SOURCE"} $rc

# TYPE restic_backup_last gauge
restic_backup_last{repo="$REPO",source="$SOURCE"} $(date +%s)

# TYPE restic_backup_files_new gauge
restic_backup_files_new{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.files_new')

# TYPE restic_backup_files_changed gauge
restic_backup_files_changed{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.files_changed')

# TYPE restic_backup_files_unmodifed gauge
restic_backup_files_unmodifed{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.files_unmodified')

# TYPE restic_backup_dirs_new gauge
restic_backup_dirs_new{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.dirs_new')

# TYPE restic_backup_dirs_changed gauge
restic_backup_dirs_changed{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.dirs_changed')

# TYPE restic_backup_dirs_unmodified gauge
restic_backup_dirs_unmodified{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.dirs_unmodified')

# TYPE restic_backup_data_blobs gauge
restic_backup_data_blobs{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.data_blobs')

# TYPE restic_backup_tree_blobs gauge
restic_backup_tree_blobs{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.tree_blobs')

# TYPE restic_backup_data_added gauge
restic_backup_data_added{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.data_added')

# TYPE restic_backup_total_files_processed gauge
restic_backup_total_files_processed{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.total_files_processed')

# TYPE restic_backup_total_bytes_processed gauge
restic_backup_total_bytes_processed{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.total_bytes_processed')

# TYPE restic_backup_total_duration gauge
restic_backup_total_duration{repo="$REPO",source="$SOURCE"} $(echo "$summary"|jq '.total_duration')
EOF
push_metrics "$data" "POST"

echo
log Forget old backups
# The folling line returns a shellcheck warning, but I could not find a workaround
# as $FORGET_ARGS must not be quoted.
restic --json -r "$REPO" forget $FORGET_ARGS
rc=$?

read -r -d '' data<<EOF
$data

# TYPE restic_forget_return_code gauge
restic_forget_return_code{repo="$REPO",source="$SOURCE"} $rc

# TYPE restic_last_forget gauge
restic_forget_last{repo="$REPO",source="$SOURCE"} $(date +%s)
EOF
push_metrics "$data" "POST"

echo
log Prune old backups
restic --json -r "$REPO" prune
rc=$?

read -r -d '' data<<EOF
$data

# TYPE restic_prune_return_code gauge
restic_prune_return_code{repo="$REPO",source="$SOURCE"} $rc

# TYPE restic_last_prune gauge
restic_prune_last{repo="$REPO",source="$SOURCE"} $(date +%s)
EOF
push_metrics "$data" "POST"

echo
log Check after prune
restic --json -r "$REPO" check
rc=$?

read -r -d '' data<<EOF
$data

# TYPE restic_check_return_code gauge
restic_check_return_code{repo="$REPO",source="$SOURCE"} $rc

# TYPE restic_last_check gauge
restic_check_last{repo="$REPO",source="$SOURCE"} $(date +%s)
EOF
push_metrics "$data" "POST"

log Push statisitcs as metrics
stats_output=$(restic --json -r "$REPO" stats 2> /dev/null)
echo "$stats_output"

read -r -d '' data<<EOF
$data

# TYPE restic_stats_total_size gauge
restic_stats_total_size{repo="$REPO",source="$SOURCE"} $(echo "$stats_output"|jq '.total_size')

# TYPE restic_stats_total_file_count gauge
restic_stats_total_file_count{repo="$REPO",source="$SOURCE"} $(echo "$stats_output"|jq '.total_file_count')
EOF
push_metrics "$data" "POST"

echo
log Count the number of snapshots after prune
snapshots_output=$(restic --json -r "$REPO" snapshots)
log "$snapshots_output"

read -r -d '' data<<EOF
$data

# TYPE restic_snapshots_total gauge
restic_snapshots_total{repo="$REPO",source="$SOURCE"} $(echo "$snapshots_output"|jq '. | length')
EOF

# PUT metrics
push_metrics "$data" "PUT"

move_textfile
