# case / select


```bash title="case statement"
case "$action" in
  start)
    start_service
    ;;
  stop|halt)           # OR pattern
    stop_service
    ;;
  re*)                  # glob pattern
    restart_service
    ;;
  ?)                   # single char
    echo "single char"
    ;;
  *)                   # default/fallthrough
    echo "unknown: $action"
    exit 1
    ;;
esac

# ;;& = test next pattern (fallthrough)
# ;& = execute next block unconditionally
case "$char" in
  [[:upper:]]) echo "upper";;&
  [[:alpha:]]) echo "letter";;
esac
```


```bash title="select (interactive menu)"
# select prints numbered menu, reads choice
PS3="Choose: "   # custom prompt
select opt in "Start" "Stop" "Quit"; do
  case "$opt" in
    Start) start;;
    Stop)  stop;;
    Quit)  break;;
    *)     echo "invalid";;
  esac
done
```


```bash title="argument parsing with getopts"
while getopts ":hv:f:" opt; do
  case $opt in
    h) usage;;
    v) VERBOSE="$OPTARG";;
    f) FILE="$OPTARG";;
    :) echo "missing arg for -$OPTARG";;
    ?) echo "unknown: -$OPTARG";;
  esac
done
shift $((OPTIND - 1))  # remove parsed args
```
