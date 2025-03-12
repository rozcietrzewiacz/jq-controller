#!/bin/bash
: ${KUBECTL_MAIN_ACTION:=apply} # apply (loop) or create (single)
: ${WATCH_TARGET:="configmap"} # Object being watched
: ${WATCH_MASK:="."} # Only react to changes in that object path
: ${EXTRA_ARGS_PATH:=""}
: ${LIB_PATH:=""}
: ${HEADER_DEF_FILE:="/in/header.jq"}
: ${TRANSFORM_DEF_FILE:="/in/filter.jq"}
: ${FOOTER_DEF_FILE:="/in/footer.jq"}
: ${WATCH_EVENTS:='ADDED, MODIFIED'}
: ${WATCH_FUNCTION:=kubectlGetWatch}
: ${APPLY_FUNCTION:=filterApplyLoop}

msg() { echo "$@"; }
dbg() { [ "$DEBUG" ] && msg ">DEBUG> $@"; }
main() {
  local fullFilter=$(mktemp)
  _combineJsons() {
    cat \
      ${HEADER_DEF_FILE} \
      ${TRANSFORM_DEF_FILE} \
      ${FOOTER_DEF_FILE} \
      > "$fullFilter"
  }
  _cleanup() {
    rm -v "$fullFilter"
  }

  _combineJsons
  export JQ_EXTRA_ARGS
  if [ ${#CUSTOM_APPLY_SCRIPT} -gt 0 ]
  then
    echo "${CUSTOM_APPLY_SCRIPT}" > /tmp/custom.sh
    APPLY_FUNCTION="bash /tmp/custom.sh"
  fi
  ${WATCH_FUNCTION} \
  | ${APPLY_FUNCTION} "$fullFilter"
  _cleanup
}

kubectlGetWatch() {
  local allNs=""
  [[ $ALL_NS ]] && allNs="-A"
  # The default is to only pass the k8s object to the APPLY_FUNCTION.
  # This can be changed by setting the
  # KUBECTL_WATCH_EVENTS_OBJECT_FILTER variable, which allows
  # to choose how the full event json is passed
  # to the main logic filter. Note that the default "header"
  # is applied directly after this, so unless you change
  # the HEADER_DEF_FILE, you should make sure that what comes out
  # from the events filter, includes the standard k8s object
  # metadata under .metadata field. The default value of
  # KUBECTL_WATCH_EVENTS_OBJECT_FILTER is ".object", which means
  # that the full k8s object is passed, but no event info.
  # But it you use custom APPLY_FUNCTION, you may choose to pass
  # the event info as an extra field, e.g.:
  # ".object|.event_type=$type"
  # (note that $type holds the event type name below)
  #
  # TODO:
  # Consider following alternative designs:
  # 1. (light change, similar overall complexity)
  #   Pass the object filter as an argument instead of env var;
  #   thus, override WATCH_FUNCTION="kubectlGetWatch <event_flt>"
  # 2. (deeper change, partly siplified design..?)
  #   Always pass the full original event (after type selection
  #   filter) and adjust header (?)
  : ${KUBECTL_WATCH_EVENTS_OBJECT_FILTER:=".object"}
  kubectl get --watch -o json --output-watch-events \
    $allNs ${WATCH_TARGET} \
    | jq --unbuffered -c --arg watch_events "${WATCH_EVENTS// /}" \
      '
        .type as $type
        | select(
            ( $watch_events | split(",") | index($type) ) != null
          )
        | '"${KUBECTL_WATCH_EVENTS_OBJECT_FILTER}"'
      '
}

filterApplyLoop() {
  local fullFilter=$1
  declare -A LastRev
  _uid() { jq -r '.metadata.uid'; }
  _rev() { jq -r '.metadata.resourceVersion'; }
  _masked() { <<<"$@" jq -c "$WATCH_MASK"; }

  local inputUpdate lastValue output result=0 selfMod= inUid
  dbg "in filterApplyLoop"
  while read -r inputUpdate
  do
    dbg "read new json: \"$inputUpdate\""
    # TODO: filter out based on fieldManager metadata
    #
    [ "$(_masked "${inputUpdate}")" == "$(_masked "${lastValue}")" ] \
    || {
      lastValue="${inputUpdate}"
      echo
      inUid=$(_uid <<<"${inputUpdate}")
      msg "> Update detected for uid $inUid"
      if [ $selfMod ] \
        && [[ ${LastRev[$inUid]} == $(_rev <<<"${inputUpdate}") ]]
      then
        msg ">> skip! Same revision as our update <<"
        sleep 1
        continue
      fi
      output=$(
        <<<"${inputUpdate}" jq -c \
          -f "${fullFilter}" \
          $JQ_EXTRA_ARGS \
        | tee >( jq '{kind, ns:.metadata.namespace, name: .metadata.name}' -cC  > /dev/stderr )
      )
      updateTimestamp=$(date +%s)
      # TODO: some sanity check/filter possible before apply
      output=$( <<<"${output}" jq \
        | kubectl ${KUBECTL_MAIN_ACTION} --field-manager='jq-controller' -o json -f - )
      result=$?
      # check if the output is the same object
      if [[ "$inUid" == $(_uid <<<"${output}") ]]
      then
        msg " >> Modifying source object!"
        selfMod=yes
        LastRev[$inUid]=$( _rev <<<"${output}" )
        msg "  > recorded: LastRev[$inUid]=${LastRev[$inUid]}"
      fi
      # If we're running in "create" mode, break after first successful run
      [[ ${KUBECTL_MAIN_ACTION} == "create" && $result -eq 0 ]] && break
    }
  done
  msg ">> APPLY LOOP EXITED"
  if [ $result -gt 0 ]
  then
    msg "Dumping dry-run output:"
    <<<${inputUpdate} jq ${JQ_EXTRA_DUMP_ARGS} \
      -f "${fullFilter}" \
      $JQ_EXTRA_ARGS
  fi
}

hello() {
  ############################################################
  # TODO:
  # - Add operating modes: poll/watch
  # - Abstract source command, so that 'kubectl get' can be replaced with any custom script. Ideas:
  #   . aws-cli --output json
  #   . curl <rss-feed> | yq <extraction_filter>
  #   . curl <any api endpoint>
  msg ">> JQ Controller startig..."                       #
  msg " > kubectl operting mode:    $KUBECTL_MAIN_ACTION" # H
  msg " > watching resource:         $WATCH_TARGET"       # e
  msg " > watch json mask:           $WATCH_MASK"         # l
  msg " > header definition file:    $HEADER_DEF_FILE"    # l
  msg " > transform definition file: $TRANSFORM_DEF_FILE" # o
  msg " > footer definition file:    $FOOTER_DEF_FILE"    # ?
  for f in ${HEADER_DEF_FILE} ${TRANSFORM_DEF_FILE} ${FOOTER_DEF_FILE}; do
    [ -r ${f} ] || {                                      # .
      msg "ERROR: $f is not readable!" | tee /dev/stderr  # .
      ls -l "${f}" 2>&1                                   #
      exit 1                                              # i
    }                                                     # s
  done                                                    #
  WATCH_LIST="${HEADER_DEF_FILE}:x"                       # i
  WATCH_LIST+=" ${TRANSFORM_DEF_FILE}:x"                  # t
  WATCH_LIST+=" ${FOOTER_DEF_FILE}:x"                     #
  WATCH_LIST+=" ${BASH_ARGV0}:ex"                         # m
  [ "${EXTRA_ARGS_PATH}" != "" ] && {                     # e
    msg " > obtaining args from ${EXTRA_ARGS_PATH} ..."   #
    cd ${EXTRA_ARGS_PATH}                                 # y
    for name in *                                         # o
    do                                                    # u
      if [[ $name == *".json" ]]                          # '
      then                                                # r
        value=$( < $name jq '@json' )                     # e
        JQ_EXTRA_ARGS+=" --argjson ${name%%\.json} $value" #
      else                                                # l
        value=$(< $name )                                 # o
        JQ_EXTRA_ARGS+=" --arg $name $value"              # o
      fi                                                  # k
      WATCH_LIST+=" ${EXTRA_ARGS_PATH}/${name}:x"         # i
    done                                                  # n
    cd - &>/dev/null                                      # g
  }                                                       #
  [ "${LIB_PATH}" != "" ] && {                            # f
    msg " > appending lib path to args..."                # o
    JQ_EXTRA_ARGS+=" -L $LIB_PATH"                        # r
  }                                                       #
  echo "JQ_EXTRA_ARGS: $JQ_EXTRA_ARGS"                    # ?
}

handleExit() {
  echo ">> INTERRUPT caught. Killing own pod <<"
  killall5 || kill $(pidof kubectl)
}

world() {
  ## TODO: Replace with sth generic like ACTION_ONCE ???
  if [[ ${KUBECTL_MAIN_ACTION} == "create" ]]
  then
    main
  else
    while true
    do
      main
      sleep 2
    done
  fi
}

####################
export -f handleExit
trap handleExit INT
echo "MY PID: $$"
trap -p

hello
world
