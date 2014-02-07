#!/bin/bash
#
# Written by Aaron Lindsay <aaron@aclindsay.com>

# These knobs control which backups to keep, and how long to keep them for. A
# backup is kept if its distance from the UNIX epoch in days divides evenly by
# BASE^power (where power is some integer 0 < MAX_POWER), and it is less than
# WINDOW_FACTOR*BASE^power days old.
BASE=2
MAX_POWER=16
WINDOW_FACTOR=4

# Returns output if the date passed in as the first argument is not in a format
# 'date' can understand
function invalid_date() {
  date -d "$1 + 1 min" +"%s" &> /dev/null
  if [[ $? -ne 0 ]]; then
    echo "invalid"
  fi
}

# Return the number of days which passed between the UNIX epoch and the first
# argument
function days_since_epoch() {
  echo $(( $(date -d "$1" +"%s") / (60*60*24) ))
}

# Prints "keep" if the backup with the indicated date should be kept
function keep_backup() {
  local current_day_count=$1
  local backup_day_count=$2
  local difference=$(( $current_day_count - $backup_day_count ))

  for (( power=0; power<=$MAX_POWER; power++ )); do
    local factor=$(( $BASE ** $power ))
    local remainder=$(( $backup_day_count % $factor ))
    if [[ $remainder -eq 0 ]] &&
        [[ $difference -le $(($factor * $WINDOW_FACTOR)) ]]; then
      echo "keep"
      return
    fi
  done
}

function usage() {
cat << EOF
Usage: $0 options

Print the backups which should (or should not with -r) be kept from a list of
dates passed via stdin.

OPTIONS:
   -h       Show this message
   -i FILE  Read candidate backup dates from FILE instead of stdin
   -d DATE  Calculate which backups should be kept from this date instead of
            today 
   -r       Reverse which dates are displayed (show those which should be
            deleted instead of kept)
EOF
}

reverse=
current_date=$(date -I)
input="/dev/stdin"

while getopts "hrd:i:" OPTION; do
  case $OPTION in
    i)
      input=$OPTARG
      if [[ ! -f $input ]]; then
        echo "Error: \"$input\" is not a file" 1>&2
        usage
        exit 1
      fi
      ;;
    d)
      current_date=$OPTARG
      if [[ $(invalid_date "$current_date") ]]; then
        echo "Error: \"$current_date\" is not a valid date" 1>&2
        usage
        exit 1
      fi
      ;;
    r)
      reverse="true"
      ;;
    h)
      usage
      exit
      ;;
    ?)
      usage
      exit 1
      ;;
  esac
done

current_days=$(days_since_epoch "$current_date")

while read line; do
  if [[ $(invalid_date "$line") ]]; then
    echo "Error: \"$line\" is not a valid date" 1>&2
    exit 1
  fi
  backup_days=$(days_since_epoch "$line")
  keep=$(keep_backup $current_days $backup_days)
  if [[ -z $reverse ]] && [[ $keep ]]; then
    echo $line
  elif [[ $reverse ]] && [[ -z $keep ]]; then
    echo $line
  fi
done < $input
