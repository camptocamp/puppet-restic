#!/bin/bash

while getopts ":r:s:f:" opt; do
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
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      ;;
  esac
done
shift $((OPTIND -1))

: ${FORGET_ARGS:="--keep-last 7"}

if test -z "${REPO}" || test -z "${SOURCE}" ; then
  echo "Usage: `basename $0` -r <repo> -s <source> [-f <forget_args>]" 1>&2
  exit 1
fi

echo Test if the repo exists
restic --json -r $REPO stats 2> /dev/null

if [ $? -ne 0 ]; then
	echo Initialize the repo
	restic --json -r $REPO init
fi

echo 
echo Launch backup
output=$(restic --json -r $REPO backup $SOURCE)
echo $output

summary=$(echo $output|jq 'select(.message_type == "summary")')

echo
echo Forget old backups
restic --json -r $REPO forget --prune $FORGET_ARGS

echo
echo Prune old backups
restic --json -r $REPO prune

echo Push statisitcs as metrics
stats_output=$(restic --json -r $REPO stats 2> /dev/null)
echo $stats_output

echo
echo Count the number of snapshots after prune
snapshots_output=$(restic --json -r $REPO snapshots)
echo $snapshots_output

cat <<EOF | curl -XPUT --data-binary @- http://127.0.0.1:9091/metrics/job/restic
# TYPE restic_total_size gauge
restic_total_size{repo="$REPO",source="$SOURCE"} $(echo $stats_output|jq '.total_size')

# TYPE restic_total_file_count gauge
restic_total_file_count{repo="$REPO",source="$SOURCE"} $(echo $stats_output|jq '.total_file_count')

# TYPE restic_total_snapshots gauge
restic_total_snapshots{repo="$REPO",source="$SOURCE"} $(echo $snapshots_output|jq '. | length')

# TYPE restic_return_code gauge
restic_return_code{repo="$REPO",source="$SOURCE"} $?

# TYPE restic_last_backup gauge
restic_last_backup{repo="$REPO",source="$SOURCE"} $(date +%s)

# TYPE restic_files_new gauge
restic_files_new{repo="$REPO",source="$SOURCE"} $(echo $summary|jq '.files_new')

# TYPE restic_files_changed gauge
restic_files_changed{repo="$REPO",source="$SOURCE"} $(echo $summary|jq '.files_changed')

# TYPE restic_files_unmodifed gauge
restic_files_unmodifed{repo="$REPO",source="$SOURCE"} $(echo $summary|jq '.files_unmodified')

# TYPE restic_dirs_new gauge
restic_dirs_new{repo="$REPO",source="$SOURCE"} $(echo $summary|jq '.dirs_new')

# TYPE restic_dirs_changed gauge
restic_dirs_changed{repo="$REPO",source="$SOURCE"} $(echo $summary|jq '.dirs_changed')

# TYPE restic_dirs_unmodified gauge
restic_dirs_unmodified{repo="$REPO",source="$SOURCE"} $(echo $summary|jq '.dirs_unmodified')

# TYPE restic_data_blobs gauge
restic_data_blobs{repo="$REPO",source="$SOURCE"} $(echo $summary|jq '.data_blobs')

# TYPE restic_tree_blobs gauge
restic_tree_blobs{repo="$REPO",source="$SOURCE"} $(echo $summary|jq '.tree_blobs')

# TYPE restic_data_added gauge
restic_data_added{repo="$REPO",source="$SOURCE"} $(echo $summary|jq '.data_added')

# TYPE restic_total_files_processed gauge
restic_total_files_processed{repo="$REPO",source="$SOURCE"} $(echo $summary|jq '.total_files_processed')

# TYPE restic_total_bytes_processed gauge
restic_total_bytes_processed{repo="$REPO",source="$SOURCE"} $(echo $summary|jq '.total_bytes_processed')

# TYPE restic_total_duration gauge
restic_total_duration{repo="$REPO",source="$SOURCE"} $(echo $summary|jq '.total_duration')
EOF
