# Parameter Expansion Cheatsheet


| Syntax | Meaning | Example |
| --- | --- | --- |
| ${var} | value of var | ${name} |
| ${var:-default} | value if set, else default | ${PORT:-8080} |
| ${var:=default} | assign default if unset | ${LOG:=/tmp/app.log} |
| ${var:?message} | error & exit if unset/empty | ${HOST:?must set HOST} |
| ${var:+other} | other if set, else empty | ${DEBUG:+-v} (add -v if DEBUG set) |
| ${#var} | length of string | ${#name} |
| ${var:N} | substring from N | ${s:5} |
| ${var:N:L} | substring from N, length L | ${s:5:3} |
| ${var#pattern} | strip shortest prefix | ${path#*/} |
| ${var##pattern} | strip longest prefix (greedy) | ${path##*/} = basename |
| ${var%pattern} | strip shortest suffix | ${file%.gz} |
| ${var%%pattern} | strip longest suffix (greedy) | ${url%%/*} = scheme |
| ${var/pat/rep} | replace first match | ${s/foo/bar} |
| ${var//pat/rep} | replace all matches | ${s// /_} |
| ${var/#pat/rep} | replace prefix match | ${path/#\~/$HOME} |
| ${var/%pat/rep} | replace suffix match | ${file/%.txt/.bak} |
| ${var,,} | all lowercase |  |
| ${var^^} | all uppercase |  |
| ${var,} | first char lowercase |  |
| ${var^} | first char uppercase |  |
| ${!var} | indirect: value of variable named by $var | ${!prefix*} |
| ${!prefix*} | variable names starting with prefix |  |
| ${var@Q} | quoted (shell-safe) representation | for logging/eval |
| ${var@A} | assignment statement (like declare -p) |  |
| ${var@a} | attribute flags (r=readonly, x=exported) |  |
