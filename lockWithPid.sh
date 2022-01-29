#!/bin/bash -eu

LOCK_PATH=
LOCK_DIR=/var/run
# CAUTION: DONOT USE /var/run. USE /run  (if symlinked)

###
### lockWithPid and unlockWithPid
###
#
# Get lock with symlink to PID file
# When it failed to get lock, returns immediately 
#
# CAUTION: When you use trap "..." EXIT handler, Plese insert unlockWithPid separated semi colon ";"
#
function lockWithPid() {
  [ "$#" -eq 1 ] || { echo 'usage: lockWithPid [LOCKFILENAME]' >&2; return 1; }

  LOCK_PATH="$LOCK_DIR/$1.pid"

  # PROBLEM: overwriting exising trap 
  if [ -n "$(trap -p EXIT)" ] && (trap -p EXIT | grep -vq unlockWithPid); then
    echo "Error: EXIT trap handler already exists. Please install 'unlockWithPid' manually" >&2
    return 4
  fi
  trap unlockWithPid EXIT

  # make a file with our PID, with showing who's waiting for a lock
  if ! touch "$LOCK_PATH.$$" ; then
    echo "Error: failed to create lockfile for PID: $LOCK_PATH.$$" >&2
    return 2
  fi

  # try to symlink it
  if ! ln -s "$LOCK_PATH.$$" "$LOCK_PATH" 2>/dev/null; then
    echo "Error: failed to create symlink lock: $LOCK_PATH.$$ -> $LOCK_PATH" >&2
    return 3
  fi
  return 0   # symlink was created successfully, lock acquired
}

function unlockWithPid() {
  if [ -f "$LOCK_PATH.$$" ]; then rm -f "$LOCK_PATH.$$"; fi
  if [ "$(readlink -f $LOCK_PATH)" = "$LOCK_PATH.$$" ]; then rm -f "$LOCK_PATH"; fi
  return 0
}

cat <<__EOF__ >/dev/null
trap "echo byebye; unlockWithPid" EXIT
lockWithPid test || { echo "failed"; exit 1; }
echo LOCKED

ls -l $LOCK_DIR
sleep 10

unlockWithPid test
echo UNLOCKED
ls -l $LOCK_DIR
__EOF__
