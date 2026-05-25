# Test Operators Quick-ref


## File Tests


| Op | True if |
| --- | --- |
| -e f | exists (any type) |
| -f f | regular file |
| -d f | directory |
| -L f | symlink |
| -p f | named pipe (FIFO) |
| -S f | socket |
| -s f | size > 0 |
| -r f | readable by current user |
| -w f | writable |
| -x f | executable |
| -u f | setuid bit set |
| -g f | setgid bit set |
| -k f | sticky bit set |
| f1 -nt f2 | f1 newer than f2 |
| f1 -ot f2 | f1 older than f2 |
| f1 -ef f2 | same inode (hard link) |


## String & Integer Tests


| Op | True if |
| --- | --- |
| -z str | empty string |
| -n str | non-empty string |
| s1 == s2 | strings equal (glob in [[]]) |
| s1 != s2 | strings not equal |
| s1 < s2 | s1 lexically before s2 |
| s1 > s2 | s1 lexically after s2 |
| s =~ regex | regex match ([[]] only) |
| -v var | variable is set |
| n1 -eq n2 | integers equal |
| n1 -ne n2 | not equal |
| n1 -lt n2 | less than |
| n1 -le n2 | less or equal |
| n1 -gt n2 | greater than |
| n1 -ge n2 | greater or equal |
