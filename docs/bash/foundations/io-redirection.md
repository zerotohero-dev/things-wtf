# I/O & Redirection


```bash title="file descriptors & redirection"
# stdin=0  stdout=1  stderr=2

# Redirect stdout
cmd > file       # overwrite
cmd >> file      # append

# Redirect stderr
cmd 2> error.log

# Redirect both stdout and stderr
cmd > out.log 2>&1       # classic — order matters! > first, then 2>&1
cmd &> out.log            # bash shorthand
cmd &>> out.log           # append both

# Suppress all output
cmd &> /dev/null

# Redirect stdin
cmd < input.txt

# Heredoc — multiline stdin
cat <<EOF
line 1
line 2: $variable is expanded
EOF

# Heredoc — quoted delimiter prevents expansion
cat <<'EOF'
$LITERAL — not expanded
EOF

# Heredoc — indented (tab-stripped with <<-)
cat <<-EOF
	line1   (leading tabs stripped)
	line2
EOF

# Herestring — single-line stdin from string
grep "pattern" <<< "$variable"
read a b c <<< "one two three"

# Custom file descriptors
exec 3> logfile          # open fd 3 for writing
echo "log line" >&3     # write to fd 3
exec 3>&-               # close fd 3

exec 4< input.txt        # open fd 4 for reading
read -u4 line           # read from fd 4
exec 4<&-               # close fd 4

# Tee stdin to file AND stdout
cmd | tee file.log          # stdout + file
cmd | tee -a file.log       # append mode
cmd | tee f1 f2 | next_cmd  # multiple files + continue pipeline

# Capture stderr separately
cmd 2>(tee error.log >&2)    # log stderr, still print it
```


!!! danger "2>&1 order matters"
    cmd > file 2>&1 = stderr goes where stdout currently points (file). 
            cmd 2>&1 > file = stderr goes to original stdout (terminal), then stdout redirected to file. This is the #1 redirection mistake.
