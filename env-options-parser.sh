#! /usr/bin/env bash

#set -x
set -e

# based on gcc-options-parser.sh
# https://github.com/milahu/gcc-options-parser

# based on coreutils-9.0/src/env.c
# https://github.com/coreutils/coreutils

# related
# https://github.com/uutils/coreutils/issues/1326

testShebangLines="$(cat <<EOF
/usr/bin/env -S deno run --unstable --allow-read --allow-write --allow-env --no-check
/usr/bin/env -S deno run --unstable --allow-read --allow-write --allow-env --no-check
/usr/bin/env -S deno
/usr/bin/env deno
/usr/bin/env -S cat "some file.txt"
/usr/bin/env -S cat "some 'file'.txt"
/usr/bin/env -S cat some\ \'file\'.txt
/usr/bin/env -S cat 'some file.txt'
/usr/bin/env -S cat some\ file.txt
/usr/bin/env -S cat 'some "file".txt'
/usr/bin/env -S cat 'some \"file.txt'
/usr/bin/env -S cat 'some "file.txt FIXME xargs: unmatched double quote'
/usr/bin/env -S cat some\ \\\"file.txt
/usr/bin/env -S cat some\ \"file.txt\ "FIXME xargs: unmatched double quote"
/usr/bin/env -S echo "home is ${HOME}, and argv0 is ..."

/usr/bin/env -S -v - X=1 Y=2
/usr/bin/env -S -v - -X=1 Y=2
/usr/bin/env -S -v -i X=1 Y=2
/usr/bin/env -S -v -i -X=1 Y=2 # error: /usr/bin/env: invalid option -- 'X'

/usr/bin/env --split-string="printf" 'arg: %q\n' asdf asdf - X=asdf

/usr/bin/env - X=asdf -S echo yeah # error: /usr/bin/env: '-S': No such file or directory (no options after -)

/usr/bin/env -i X=asdf -S echo yeah # error: /usr/bin/env: '-S': No such file or directory (no options after -i)
/usr/bin/env -i -S echo

/usr/bin/env -i -S # error: /usr/bin/env: option requires an argument -- 'S'

/usr/bin/env -i X=asdf -S"echo yeah"
/usr/bin/env  -S"echo yeah"
/usr/bin/env  -S"echo yeah" - X=1
/usr/bin/env  -S"echo yeah" - X=1 Y=2
/usr/bin/env  -S"echo yeah" -i X=1 Y=2
/usr/bin/env -i X=1 Y=2 -S echo
/usr/bin/env -i X=1 Y=2 echo
/usr/bin/env - X=1 Y=2 echo
/usr/bin/env - X=1 Y=2 env
/usr/bin/env - X=1 Y=2 env -S asdf
/usr/bin/env - X=1 Y=2 echo -S hello
/usr/bin/env - X=1 Y=2 -S echo hello
/usr/bin/env - X=1 Y=2 echo hello
/usr/bin/env -S - X=1 Y=2 echo hello
/usr/bin/env - X=1 Y=2 -S echo hello
/usr/bin/env -S - X=1 Y=2 echo hello
/usr/bin/env - X=1 Y=2 echo hello
/usr/bin/env -S - X=1 Y=2 echo hello world
/usr/bin/env - X=1 Y=2 echo hello world
/usr/bin/env -S"echo hello" - X=1 Y=2 
/usr/bin/env -S "echo hello" - X=1 Y=2 
/usr/bin/env -S - X=1 Y=2 
/usr/bin/env -S -v - X=1 Y=2 


EOF
)"

while read argstring; do # ...; done < <( echo "$testShebangLines" )

echo
echo "argstring = $argstring"

# tokenize string to array
# https://stackoverflow.com/questions/26067249
#echo "tokenize string to array ..."
args=()
while IFS= read -r -d ''; do
  args+=("$REPLY")
done < <(xargs printf '%s\0' <<<"$argstring")
#echo "tokenize string to array done"
# FIXME this should throw on parse error
# example: argstring='a " '
# -> xargs: unmatched double quote; by default quotes are special to xargs unless you use the -0 option

# debug
#for ((i = 0; i < ${#args[@]}; i++ )); do a=${args[$i]}; echo "args[$i] = $a"; done

# serialize array to string
# https://unix.stackexchange.com/questions/518012
# always add single quotes:
echo "args quoted 1: ${args[@]@Q}"
# add backslash-escapes when needed:
echo "args quoted 2: $(printf '%q ' "${args[@]}")"

continue

echo "num args: ${#args[@]}"


null=

envArgs=()
passArgs=()

blockSignal=
defaultSignal=
debugSignals=
debug=

for ((i = 0; i < ${#args[@]}; i++ ))
do
  a=${args[$i]}
  case "$a" in
    #
    # Usage: env [OPTION]... [-] [NAME=VALUE]... [COMMAND [ARG]...]
    #
    # Set each NAME to VALUE in the environment and run COMMAND.
    #
    # A mere - implies -i.  If no COMMAND, print the resulting environment.
    #
    # SIG may be a signal name like 'PIPE', or a signal number like '13'.
    # Without SIG, all known signals are included.  Multiple signals can be
    # comma-separated.
    #
    -)
      # end of options
      # all following *=* args are key=value pairs for env-vars
      ;;
    -i|--ignore-environment)
      # start with an empty environment
      envArgs+=("$a")
      ;;
    -0|--null)
      # end each output line with NUL, not newline
      envArgs+=("$a")
      ;;
    -u)
      # remove variable from the environment
      # TODO
    ;;
    --unset|--unset=*)
      # remove variable from the environment
      if [ "$a" = "--unset" ]; then : $((i++)); envArgs+=("$a" "${args[$i]}"); else envArgs+=("$a"); fi
      ;;
    -C|--chdir|--chdir=*)
      # change working directory to DIR
      ;;
    -S|--split-string|--split-string=*)
      # consume all following args
      passArgs=("${args[@]:$i}")
      if [ "$a" = "--split-string" ]; then
        : $((i++))
        passArgs=("${args[@]:$i}")
      else
        # --split-string=arg0 arg1 arg2
        passArgs=("${a:15}" "${args[@]:$i}")
      fi
      break # done parsing
      ;;
    --block-signal|--block-signal=*)
      # block delivery of SIG signal(s) to COMMAND
      if [ "$a" = "--block-signal" ]; then : $((i++)); envArgs+=("$a" "${args[$i]}"); else envArgs+=("$a"); fi
      ;;
    --default-signal|--default-signal=*)
      # reset handling of SIG signal(s) to the default
      if [ "$a" = "--default-signal" ]; then : $((i++)); envArgs+=("$a" "${args[$i]}"); else envArgs+=("$a"); fi
      ;;
    --ignore-signal|--ignore-signal=*)
      # set handling of SIG signal(s) to do nothing
      if [ "$a" = "--ignore-signal" ]; then : $((i++)); envArgs+=("$a" "${args[$i]}"); else envArgs+=("$a"); fi
      ;;
    --list-signal-handling)
      # list non default signal handling to stderr
      envArgs+=("$a")
      ;;
    -v|--debug)
      # print verbose information for each processing step
      envArgs+=("$a")
      ;;
    --help)
      # display this help and exit
      envArgs+=("$a")
      ;;
    --version)
      # output version information and exit
      envArgs+=("$a")
      ;;

    *)
      echo "FIXME handle arg: $a"
      ;;

  esac
done

echo "defaultSignal = $defaultSignal"
printf 'passArgs: '; printf '%q ' "${passArgs[@]}"; printf '\n'



done < <( echo "$testShebangLines" )
