# Special Variable Quick-ref


| Variable | Value |
| --- | --- |
| $? | Exit code of last command |
| $$ | PID of current shell |
| $! | PID of last background process |
| $0 | Script name / shell name |
| $# | Count of positional parameters |
| "$@" | All positional args as separate words |
| $_ | Last argument of previous command |
| $LINENO | Current line number |
| $BASH_COMMAND | Command about to be executed (in traps) |
| $BASH_LINENO | Array of line numbers in call stack |
| $BASH_SOURCE | Array of filenames in call stack |
| $FUNCNAME | Array of function names in call stack |
| $PIPESTATUS | Array of exit codes of last pipeline |
| $BASHPID | PID of current bash (differs in subshells) |
| $BASH_SUBSHELL | Depth of subshell nesting (0=main) |
| $RANDOM | Random 0–32767 each read |
| $SECONDS | Elapsed seconds since shell started |
| $IFS | Internal field separator (default: SPC TAB NL) |
| $OLDPWD | Previous working dir (cd -) |
| $REPLY | Default variable for read/select |
| $OPTIND | Index of next arg for getopts |
| $OPTARG | Argument of current getopts option |
| $EUID | Effective user ID (0 = root) |
| $HOSTNAME | Hostname of the system |
| $BASH_VERSION | Full bash version string |
