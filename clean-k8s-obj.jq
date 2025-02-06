
.metadata |=
( del(.annotations)
  | del(.uid)
  | del(.creationTimestamp)
  | del(.resourceVersion)
  | del(.generation)
)
| del(.status)
| del(.secrets)
