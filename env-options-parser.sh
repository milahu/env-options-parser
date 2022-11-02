#! /usr/bin/env bash

#set -x
set -e

# based on gcc-options-parser.sh
# https://github.com/milahu/gcc-options-parser

# based on coreutils-9.0/src/env.c
# https://github.com/coreutils/coreutils

# related
# https://github.com/uutils/coreutils/issues/1326



# simple options
simpleOptions="chdir null ignoreEnvironment listSignalHandling debug help version"
chdir=
null=
ignoreEnvironment=
listSignalHandling=
debug=
help=
version=

# array options
arrayOptions="passArgs setEnvs unsetEnvs blockSignals ignoreSignals defaultSignals"
passArgs=()
setEnvs=()
unsetEnvs=()
blockSignals=()
ignoreSignals=()
defaultSignals=()



argstring="$1"

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
#echo "args quoted 1: ${args[@]@Q}"
# add backslash-escapes when needed:
#echo "args quoted 2: $(printf '%q ' "${args[@]}")"



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
      # TODO
      ;;
    -i|--ignore-environment)
      # start with an empty environment
      ignoreEnvironment=1
      ;;
    -0|--null)
      # end each output line with NUL, not newline
      null=1
      ;;
    -u|--unset|--unset=*)
      # remove variable from the environment
      if [ "$a" = "-u" ] || [ "$a" = "--unset" ]; then : $((i++)); unsetEnvs+=("$a" "${args[$i]}"); else unsetEnvs+=("$a"); fi
      ;;
    -C|--chdir|--chdir=*)
      # change working directory to DIR
      if [ "$a" = "-C" ] || [ "$a" = "--chdir" ]; then : $((i++)); chdir="${args[$i]}"; else chdir=("$a"); fi
      ;;
    -S|-S*|--split-string|--split-string=*)
      # consume all following args
      passArgs=("${args[@]:$i}")
      : $((i++))
      if [ "$a" = "--split-string" ]; then
        # --split-string arg0 arg1 arg2
        passArgs=("${args[@]:$i}")
      elif [ "$a" = "-S" ]; then
        # -S arg0 arg1 arg2
        passArgs=("${args[@]:$i}")
      elif [ "${a:0:2}" = "-S" ]; then
        # -Sarg0 arg1 arg2
        passArgs=("${a:2}" "${args[@]:$i}")
      else
        # --split-string=arg0 arg1 arg2
        passArgs=("${a:15}" "${args[@]:$i}")
      fi
      break # done parsing
      ;;
    --block-signal|--block-signal=*)
      # block delivery of SIG signal(s) to COMMAND
      if [ "$a" = "--block-signal" ]; then : $((i++)); blockSignals+=("$a" "${args[$i]}"); else blockSignals+=("$a"); fi
      ;;
    --default-signal|--default-signal=*)
      # reset handling of SIG signal(s) to the default
      if [ "$a" = "--default-signal" ]; then : $((i++)); defaultSignals+=("$a" "${args[$i]}"); else defaultSignals+=("$a"); fi
      ;;
    --ignore-signal|--ignore-signal=*)
      # set handling of SIG signal(s) to do nothing
      if [ "$a" = "--ignore-signal" ]; then : $((i++)); ignoreSignals+=("$a" "${args[$i]}"); else ignoreSignals+=("$a"); fi
      ;;
    --list-signal-handling)
      # list non default signal handling to stderr
      listSignalHandling=1
      ;;
    -v|--debug)
      # print verbose information for each processing step
      debug=1
      ;;
    --help)
      # display this help and exit
      help=1
      ;;
    --version)
      # output version information and exit
      version=1
      ;;

    *)
      echo "FIXME handle arg: $a"
      ;;

  esac
done



# print result

# simple options
for name in $simpleOptions
do
  printf "%s: " "$name"
  eval "printf '%q ' \"\${$name}\""
  printf '\n'
done

# array options
#printf 'passArgs: '; printf '%q ' "${passArgs[@]}"; printf '\n'
for name in $arrayOptions
do
  printf "%s: " "$name"
  #eval "printf '%q ' \"\${$name[@]}\""
  eval "for a in \"\${$name[@]}\"; do printf '%q ' \"\$a\"; done"
  printf '\n'
done
