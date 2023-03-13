#!/bin/bash
#TODO ideas:
# - run filterApplyLoop in subprocess,
#   so that it can be killed/waitedfor by the exit trap
# - (?) construct the ownerReferences part within this script

: ${WATCH_TARGET:="configmap"} # Object being watched
: ${WATCH_MASK:=".data"} # Only react to changes in that object path
: ${EXTRA_ARGS_PATH:=""}
: ${TRANSFORM_DEF_FILE:="/in/filter.jq"}
: ${WATCH_EVENTS:='ADDED, MODIFIED'}

msg() { echo "$@"; }
dbg() { [ "$DEBUG" ] && msg ">DEBUG> $@"; }
kj() {
  kubectl $@ -o json \
    | jq --unbuffered -c --arg watch_events "$WATCH_EVENTS" \
      '
        .type as $type
        | select(
            ( $watch_events | split(", ") | index($type) ) != null
          )
        | .object
      '
}

filterApplyLoop() {
  local inputUpdate lastValue result
  dbg "in filterApplyLoop"
  while read -r inputUpdate
  do
    dbg "Read new json: \"$inputUpdate\""
    [ "${inputUpdate}" == "${lastValue}" ] \
    || {
      msg "> Update detected"
      <<<${inputUpdate} jq -c \
        -f ${TRANSFORM_DEF_FILE} \
        $JQ_EXTRA_ARGS \
      | kubectl apply -f -
      result=$?
      lastValue="${inputUpdate}"
    }
  done
  msg ">> APPLY LOOP EXITED"
  if [ $result -gt 0 ]
  then
    msg "Dumping dry-run output:"
    <<<${inputUpdate} jq -c \
      -f ${TRANSFORM_DEF_FILE} \
      $JQ_EXTRA_ARGS
  fi
}

msg ">> JQ Controller startig..."
msg " > watching resource: $WATCH_TARGET"
msg " > watch json mask: $WATCH_MASK"
msg " > transform definition file: $TRANSFORM_DEF_FILE"
[ -r ${TRANSFORM_DEF_FILE} ] || {
  msg "ERROR: $TRANSFORM_DEF_FILE is not readable!" | tee /dev/stderr
  ls -l "${TRANSFORM_DEF_FILE}" 2>&1
  exit 1
}
WATCH_LIST=${TRANSFORM_DEF_FILE}:x
WATCH_LIST+=" ${BASH_ARGV0}:ex"
[ "${EXTRA_ARGS_PATH}" != "" ] && {
  echo .... obtaining args from ${EXTRA_ARGS_PATH} ....
  cd ${EXTRA_ARGS_PATH}
  for name in *
  do
    if [[ $name == *".json" ]]
    then
      value=$( < $name jq '@json' )
      JQ_EXTRA_ARGS+=" --argjson ${name%%\.json} $value"
    else
      value=$(< $name )
      JQ_EXTRA_ARGS+=" --arg $name $value"
    fi
    WATCH_LIST+=" ${EXTRA_ARGS_PATH}/${name}:x"
  done
  cd - &>/dev/null
  echo "JQ_EXTRA_ARGS: $JQ_EXTRA_ARGS"
}

handleExit() {
  msg ">> INTERRUPT caught. Killing own pod <<"
  set -x
  #We need to force our parent to generate new pod,
  # so that our children can be recreated
  kubectl delete pod $HOSTNAME --wait=false --grace-period=2
  #alternatively, if pod name is exposed through downwardAPI:
  #kubectl delete po $(< ${EXTRA_ARGS_PATH}/name )
  #exit
}

####################
trap handleExit EXIT QUIT KILL TERM
echo "MY PID: $$"
set -x
inotifyd /ctr/reloader.sh ${WATCH_LIST} &
trap -p
set +x
while true
do
  kj get --watch --output-watch-events  ${WATCH_TARGET} | filterApplyLoop
done

