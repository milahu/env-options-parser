#! /usr/bin/env bash

#set -x
set -e

# based on gcc-options-parser.sh
# https://github.com/milahu/gcc-options-parser

# based on coreutils-9.0/src/env.c
# https://github.com/coreutils/coreutils

# related
# https://github.com/uutils/coreutils/issues/1326

dry_run=true # dont call gcc, just print args

#gccPath="$1"
#shift

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


    -o*)
      [ -n "$oPath" ] && { echo "error: can have only one output. old: $oPath. new: $a"; exit 1; }
      if [ "$a" != "-o" ]; then oPath=${a:2}; else : $((i++)); oPath=${args[$i]}; fi
      #echo "o: $oPath"
    ;;
    -x*)
      if [ "$a" != "-x" ]; then inLang=${a:2}; else : $((i++)); inLang=${args[$i]}; fi
      #echo "f: $inLang"
    ;;
    -E) stopE=1;;
    -S) stopS=1;;
    -c) stopC=1;;
    -frandom-seed=*);; # ignore
    -T|-e|-R|-A|-L|-G|-z|-I|-U|-h|-l|-F|-u|-B|-D|-J|-Hd|-Xf|-MQ|-Hf|-MD|-MT|-MF|-MMD|-init|-Tbss|-arch|--dump|-rpath|-Tdata|-gnatO|-specs|-Ttext|-iquote|-soname|-assert|-defsym|--specs|--param|--entry|--assert|-wrapper|-segprot|--output|-isystem|-iprefix|-segaddr|-imacros|-Xlinker|-include|--prefix|-dumpdir|--include|-seg1addr|-isysroot|--sysroot|-filelist|--dumpdir|-dumpbase|--imacros|-aux-info|--dumpbase|-undefined|-sectorder|-idirafter|--language|-sectalign|-segcreate|-framework|-imultilib|-rpath-link|-iframework|-Xassembler|-sectcreate|-imultiarch|-image_base|-dylib_file|--for-linker|-iwithprefix|-client_name|-sub_library|--output-pch|--force-link|-sub_umbrella|-dumpbase-ext|-install_name|--dumpbase-ext|-bundle_loader|--define-macro|-Xpreprocessor|-pagezero_size|-mtarget-linker|--for-assembler|-seg_addr_table|-current_version|--include-prefix|-dependency-file|--undefine-macro|--print-file-name|-read_only_relocs|-allowable_client|--print-prog-name|-multiply_defined|-msmall-data-limit|-iwithprefixbefore|-sectobjectsymbols|--library-directory|--include-directory|-segs_read_only_addr|--write-dependencies|-segs_read_write_addr|--include-with-prefix|-dylinker_install_name|-exported_symbols_list|-compatibility_version|-multiply_defined_unused|-unexported_symbols_list|-seg_addr_table_filename|-fintrinsic-modules-path|--include-directory-after|--write-user-dependencies|-weak_reference_mismatches|--include-with-prefix-after|--include-with-prefix-before)
      globalArgIdxList+=($i)
      : $((i++))
      globalArgIdxList+=($i)
      b=${args[$i]}
      #echo "2: $a $b"
    ;;
    -*)
      #echo "1: $a"
      globalArgIdxList+=($i)
    ;;
    @*)
      argsFile="${a:1}"
      [ ! -e "$argsFile" ] && { echo "error parsing option $a: no such file"; exit 1; }
      eval "fileArgs=( $(cat "$argsFile") )" # WARNING eval is unsafe
      args=( "${args[@]:0:$i}" "${fileArgs[@]}" "${args[@]:$((i + 1))}" )
      argsLen=${#args[@]}
      : $((i--))
    ;;
    *)
      inPathList+=("$a")
      if [ ! -e "$a" ];
      then
        echo "error: missing input file: $a"
        exit 1
      fi
      inPathIdxList+=("$i")
      if [ "$inLang" = "none" ]
      then
        ext="${a##*.}"
        if [ "$ext" = "$a" ]; then inLangList+=("_ld")
        elif [[ "$cLangExtPatt" = *" $ext "* ]]; then inLangList+=("_cfam")
        else inLangList+=("_not_cfam")
        fi
      else
        inLangList+=("$inLang")
      fi
      #echo "i: $a [format: ${inLangList[ -1]}]"
    ;;
  esac
done

echo "defaultSignal = $defaultSignal"
printf 'passArgs: '; printf '%q ' "${passArgs[@]}"; printf '\n'












if [[ $stopE || $stopS ]];
then
  echo "dont preprocess <- stopE=$stopE stopS=$stopS stopC=$stopC"
  echo "$gccPath" "${args[@]}"
  $dry_run || "$gccPath" "${args[@]}"
  exit
fi


# split the gcc command line -> one call per source file
# NOT. TODO run gcc calls in parallel # not: already done by cmake

if false; then
  echo original args
  for (( i=0; i<${#args[@]}; i++ ))
  do
    echo "arg $i: ${args[$i]}"
  done

  echo global args
  for i in ${globalArgIdxList[@]}
  do
    echo "arg $i: ${args[$i]}"
  done
fi

tmpPathIdxList=()
tmpPathList=()
tmpLangList=()

# TODO preprocess only C/C++ sources
echo preprocess args:
for (( i=0; i<${#inPathList[@]}; i++ ))
do
  inPathIdx=${inPathIdxList[$i]}
  inPath=${inPathList[$i]}
  inLang=${inLangList[$i]}
  tmpPathIdxList+=($inPathIdx)
  if [[ "$inLang" != "_ld" && "$inLang" != "_not_cfam" ]]
  then
    #echo "arg $inPathIdx -> input $i: path $inPath + lang = $inLang"
    inArgs=()
    doneInPath=
    for idx in ${globalArgIdxList[@]}; do
      if [[ ! $doneInPath && $idx -gt $inPathIdx ]]; then
        # insert input-path argument at original index
        if [ "$inLang" != "_cfam" ]; then
          inArgs+=(-x "$inLang")
        fi
        inArgs+=("$inPath")
        doneInPath=1
      fi
      inArgs+=("${args[$idx]}")
    done
    # insert input-path argument at end
    if [[ ! $doneInPath ]]; then
      inArgs+=("$inPath")
    fi

    inExt=${inPath##*.}
    tmpExt=${tmpExtOfInExt[$inExt]}
    #echo "tmpExt = $tmpExt from ext $inExt"
    # if language was set ...
    if [ "$inLang" != "_cfam" ]; then
      tmpExt=${tmpExtOfInLang[$inLang]}
      #echo "tmpExt = $tmpExt from lang $inLang"
      if [ -z "$tmpExt" ]; then
        # not a cfam language -> dont preprocess
        #echo "dont preprocess input $i: path $inPath + lang = $inLang"
        tmpPathList+=("$inPath")
        tmpLangList+=("$inLang")
        continue
      fi
    fi
    #tmpName=$(echo "$inPath" | tr / _)
    tmpName="$(basename "$inPath")"
    tmpName=${tmpName%.*}
    [ ${#tmpName} -gt 200 ] && tmpName=${tmpName: -200} # max 255 chars
    #tmpPath="/tmp/$tmpName.$tmpExt"
    #tmpPath="$(mktemp "/tmp/$tmpName-XXXXX.$tmpExt")" # must not be random! reproducible builds.
    tmpPath="/tmp/$(nix-hash --base32 "$inPath")-$tmpName.$tmpExt"
    # nix-hash -> 26 chars
    # 255 - 1 - 26 = 228
    tmpPathList+=("$tmpPath")
    tmpLangList+=("_cfam_prep") # prep = preprocessed

    inArgs+=("-o" "$tmpPath")
    inArgs+=("-E") # stop after preprocess
    $remove_linemarkers && inArgs+=("-P") # remove linemarkers#
      inArgs+=("-frandom-seed=$tmpPath")

    echo "$gccPath" "${inArgs[@]}"
    $dry_run || "$gccPath" "${inArgs[@]}"

    # TODO run gcc
    # TODO run gcc in background, wait for all to finish
    # TODO patch all temp files in one sed call
    # TODO
  else
    #echo "dont preprocess input $i: path $inPath + lang = $inLang"
    tmpPathList+=("$inPath")
    tmpLangList+=("$inLang")
  fi

done




# array_indexof without echo
function array_contains() {
  [ $# -lt 2 ] && return 1
  local a=("$@")
  local v="${a[-1]}"
  unset a[-1]
  local i
  for i in ${!a[@]}; do
    if [ "${a[$i]}" = "$v" ]; then
      #echo $i
      return 0 # stop after first match
    fi
  done
  return 1
}

# https://stackoverflow.com/a/70793702/10440128
function array_indexof() {
  [ $# -lt 2 ] && return 1
  local a=("$@")
  local v="${a[-1]}"
  unset a[-1]
  local i
  for i in ${!a[@]}; do
    if [ "${a[$i]}" = "$v" ]; then
      echo $i
      return 0 # stop after first match
    fi
  done
  return 1
}


inArgs=()
iMax=${#args[@]}
for (( i=0; i<$iMax; i++ )); do
  a="${args[$i]}"
  #echo "i = $i + a = $a" # debug
  if array_contains "${globalArgIdxList[@]}" $i
  then
    inArgs+=("$a")
  else
    tmpIdx=$(array_indexof "${inPathIdxList[@]}" $i)
    [ -n "$tmpIdx" ] && inArgs+=(${tmpPathList[$tmpIdx]})
  fi
done



# TODO add output arg?
# TODO add -frandom-seed=xxx arg?

if [ -n "$oPath" ]; then
  inArgs+=("-o" "$oPath")
fi

if [[ $stopC ]]; then
  inArgs+=("-c")
fi

# fix sort order
export LC_ALL=C
export LANG=C

# TODO maybe avoid hashing file paths, instead, hash the file contents
randomSeed=$(printf '%s
' "${tmpPathList[@]}" | sort | nix-hash --base32 /dev/stdin)
inArgs+=("-frandom-seed=$randomSeed")

echo final args:
echo "$gccPath" "${inArgs[@]}"
$dry_run || "$gccPath" "${inArgs[@]}"


done < <( echo "$testShebangLines" )
