#!/bin/bash
### -e -o pipefail

########## ENV ###########
: ${WATCH_TARGET:="configmap"} # Object being watched
: ${WATCH_MASK:=".data"} # Only react to changes in that path of the object
: ${EXTRA_WATCHES:=""}
: ${TRANFORM_DEF_FILE:="/in/transform.jq"}

######## FUNCTIONS ########
msg() { echo "$@"; } #echo '{"msg": "'$1'"}'; }
dbg() { [ "$DEBUG" ] && msg ">DEBUG> $@"; }
kj() { kubectl $@ -o json | jq --unbuffered -c "$WATCH_MASK"; }
filterApplyLoop() {
  local inputUpdate lastValue
  dbg "in filterApplyLoop"
  while read -r inputUpdate
  do
    dbg "Read new json: \"$inputUpdate\""
    [ "${inputUpdate}" == "${lastValue}" ] \
    || {
      msg "> Update detected"
      <<<${inputUpdate} jq -c -f ${TRANFORM_DEF_FILE} \
      | kubectl apply -f -
      lastValue="${inputUpdate}"
    }
  done
  msg ">> APPLY LOOP EXITED"
}


######### MAIN ##########
msg ">> JQ Controller startig..."
msg " > watching resource: $WATCH_TARGET"
msg " > watch json mask: $WATCH_MASK"
msg " > transform definition file: $TRANFORM_DEF_FILE"
[ -r ${TRANFORM_DEF_FILE} ] || {
  msg "ERROR: $TRANFORM_DEF_FILE is not readable!" | tee /dev/stderr
  ls -l "${TRANFORM_DEF_FILE}" 2>&1
  exit 1
}
########## MAIN LOOP ############
kj get --watch ${WATCH_TARGET} | filterApplyLoop
