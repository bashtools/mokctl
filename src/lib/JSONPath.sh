#!/usr/bin/env bash

declare -A JSONPath

JSONPath_new() {
  JSONPath[DEBUG]=0
  JSONPath[INCLEMPTY]=0
  JSONPath[NOCASE]=0
  JSONPath[WHOLEWORD]=0
  JSONPath[FILE]=
  JSONPath[NO_HEAD]=0
  JSONPath[NORMALIZE_SOLIDUS]=0
  JSONPath[BRIEF]=0
  JSONPath[PASSTHROUGH]=0
  JSONPath[JSON]=0
  JSONPath[MULTIPASS]=0
  JSONPath[FLATTEN]=0
  JSONPath[STDINFILE]=/var/tmp/JSONPath.$$.stdin
  JSONPath[STDINFILE2]=/var/tmp/JSONPath.$$.stdin2
  JSONPath[PASSFILE]=/var/tmp/JSONPath.$$.pass1
  declare -a INDEXMATCH_QUERY
}

# JSONPath reads JSON from stdin and applies a JSON Path query.
# Args: arg1-N - command line arguments to be parsed.
JSONPath() {

  JSONPath_sanity_checks
  JSONPath_parse_options "$@"

  trap JSONPath_cleanup EXIT

  if [[ ${QUERY} == *'?(@'* ]]; then
    # This will be a multipass query

    [[ -n ${JSONPath[FILE]} ]] && JSONPath[STDINFILE]=${JSONPath[FILE]}
    [[ -z ${JSONPath[FILE]} ]] && cat >"${JSONPath[STDINFILE]}"

    while true; do
      JSONPath_tokenize_path
      JSONPath_create_filter

      JSONPath_tokenize | JSONPath_parse | JSONPath_filter |
        JSONPath_indexmatcher >"${JSONPath[PASSFILE]}" <"${JSONPath[STDINFILE]}"

      [[ ${JSONPath[MULTIPASS]} -eq 1 ]] && {
        # replace filter expression with index sequence
        SET=$(sed -rn 's/.*[[,"]+([0-9]+)[],].*/\1/p' "${JSONPath[PASSFILE]}" | tr '\n' ,)
        SET=${SET%,}
        #QUERY=$(sed "s/?(@[^)]\+)/${SET}/" <<<"${QUERY}")
        # Testing:
        QUERY="${QUERY//\?\(@*)/${SET}}"
        [[ ${JSONPath[DEBUG]} -eq 1 ]] && echo "QUERY=${QUERY}" >/dev/stderr
        JSONPath_reset
        continue
      }

      JSONPath_flatten | JSONPath_json | JSONPath_brief <<<"${JSONPath[PASSFILE]}"

      break
    done

  else

    JSONPath_tokenize_path
    JSONPath_create_filter

    if [[ ${JSONPath[PASSTHROUGH]} -eq 1 ]]; then
      JSONPath[JSON]=1
      JSONPath_flatten | JSONPath_json
    elif [[ -z ${JSONPath[FILE]} ]]; then
      JSONPath_tokenize | JSONPath_parse | JSONPath_filter | JSONPath_indexmatcher | JSONPath_flatten | JSONPath_json | JSONPath_brief
    else
      JSONPath_tokenize | JSONPath_parse | JSONPath_filter | JSONPath_indexmatcher | JSONPath_flatten <"${JSONPath[FILE]}"
      JSONPath_json | JSONPath_brief
    fi

  fi
}

JSONPath_sanity_checks() {

  local binary

  # Reset some vars
  for binary in gawk grep sed; do
    if ! command -v "${binary}" >&/dev/null; then
      echo "ERROR: ${binary} binary not found in path. Aborting."
      exit 1
    fi
  done
}

JSONPath_reset() {

  # Reset some vars
  declare -a INDEXMATCH_QUERY
  PATHTOKENS=
  FILTER=
  OPERATOR=
  RHS=
  JSONPath[MULTIPASS]=0
}

JSONPath_cleanup() {

  [[ -e ${JSONPath[PASSFILE]} ]] && rm -f "${PASSFILE}"
  [[ -e ${JSONPath[STDINFILE2]} ]] && rm -f "${JSONPath[STDINFILE2]}"
  [[ -z ${JSONPath[FILE]} && -e ${JSONPath[STDINFILE]} ]] &&
    rm -f "${JSONPath[STDINFILE]}"
}

JSONPath_usage() {

  echo
  echo "Usage: JSONPath.sh [-b] [j] [-h] [-f FILE] [pattern]"
  echo
  echo "pattern - the JSONPath query. Defaults to '$.*' if not supplied."
  echo "-b      - Brief. Only show values."
  echo "-j      - JSON output."
  echo "-u      - Strip unnecessary leading path elements."
  echo "-i      - Case insensitive."
  echo "-p      - Pass-through to the JSON parser."
  echo "-w      - Match whole words only (for filter script expression)."
  echo "-f FILE - Read a FILE instead of stdin."
  echo "-h      - This help text."
  echo
}

JSONPath_parse_options() {

  set -- "$@"
  local ARGN=$#
  while [[ ${ARGN} -ne 0 ]]; do
    case $1 in
    -h)
      JSONPath_usage
      exit 0
      ;;
    -f)
      shift
      JSONPath[FILE]=$1
      ;;
    -i)
      JSONPath[NOCASE]=1
      ;;
    -j)
      JSONPath[JSON]=1
      ;;
    -n)
      JSONPath[NO_HEAD]=1
      ;;
    -b)
      JSONPath[BRIEF]=1
      ;;
    -u)
      JSONPath[FLATTEN]=1
      ;;
    -p)
      JSONPath[PASSTHROUGH]=1
      ;;
    -w)
      JSONPath[WHOLEWORD]=1
      ;;
    -s)
      JSONPath[NORMALIZE_SOLIDUS]=1
      ;;
    *)
      QUERY=$1
      ;;
    esac
    shift 1
    ARGN=$((ARGN - 1))
  done
  [[ -z ${QUERY} ]] && QUERY='$.*'
}

JSONPath_awk_egrep() {
  local pattern_string=$1

  gawk '{
    while ($0) {
      start=match($0, pattern);
      token=substr($0, start, RLENGTH);
      print token;
      $0=substr($0, start+RLENGTH);
    }
  }' pattern="${pattern_string}"
}

JSONPath_tokenize() {

  local GREP
  local ESCAPE
  local CHAR

  if echo "test string" | grep -Eao --color=never "test" >/dev/null 2>&1; then
    GREP='grep -Eao --color=never'
  else
    GREP='grep -Eao'
  fi

  if echo "test string" | grep -Eo "test" >/dev/null 2>&1; then
    ESCAPE='(\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})'
    CHAR='[^[:cntrl:]"\\]'
  else
    GREP=JSONPath_awk_egrep
    ESCAPE='(\\\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})'
    CHAR='[^[:cntrl:]"\\\\]'
  fi

  local STRING="\"${CHAR}*(${ESCAPE}${CHAR}*)*\""
  local NUMBER='-?(0|[1-9][0-9]*)([.][0-9]*)?([eE][+-]?[0-9]*)?'
  local KEYWORD='null|false|true'
  local SPACE='[[:space:]]+'

  # Force zsh to expand $A into multiple words
  local is_wordsplit_disabled
  is_wordsplit_disabled=$(unsetopt 2>/dev/null | grep -c '^shwordsplit$')
  if [[ ${is_wordsplit_disabled} != 0 ]]; then setopt shwordsplit; fi
  ${GREP} "${STRING}|${NUMBER}|${KEYWORD}|${SPACE}|." | grep -Ev "^${SPACE}$"
  if [[ ${is_wordsplit_disabled} != 0 ]]; then unsetopt shwordsplit; fi
}

JSONPath_tokenize_path() {

  local GREP
  local ESCAPE
  local CHAR

  if echo "test string" | grep -Eao --color=never "test" >/dev/null 2>&1; then
    GREP='grep -Eao --color=never'
  else
    GREP='grep -Eao'
  fi

  if echo "test string" | grep -Eo "test" >/dev/null 2>&1; then
    CHAR='[^[:cntrl:]"\\]'
  else
    GREP=JSONPath_awk_egrep
  fi

  local WILDCARD='\*'
  local WORD='[ A-Za-z0-9_-]*'
  local INDEX="\\[${WORD}(:${WORD}){0,2}\\]"
  local INDEXALL='\[\*\]'
  local STRING="[\\\"'][^[:cntrl:]\\\"']*[\\\"']"
  local SET="\\[(${WORD}|${STRING})(,(${WORD}|${STRING}))*\\]"
  local FILTER='\?\(@[^)]+'
  local DEEPSCAN='\.\.'
  local SPACE='[[:space:]]+'

  # Force zsh to expand $A into multiple words
  local is_wordsplit_disabled
  is_wordsplit_disabled=$(unsetopt 2>/dev/null | grep -c '^shwordsplit$')
  if [[ ${is_wordsplit_disabled} != 0 ]]; then setopt shwordsplit; fi
  readarray -t PATHTOKENS < <(echo "${QUERY}" |
    ${GREP} "${INDEX}|${STRING}|${WORD}|${WILDCARD}|${FILTER}|${DEEPSCAN}|${SET}|${INDEXALL}|." |
    grep -Ev "^${SPACE}$|^\\.$|^\[$|^\]$|^'$|^\\\$$|^\)$")
  [[ ${JSONPath[DEBUG]} -eq 1 ]] && {
    echo "grep -Eo '${INDEX}|${STRING}|${WORD}|${WILDCARD}|${FILTER}|${DEEPSCAN}|${SET}|${INDEXALL}|.'" >/dev/stderr
    echo -n "TOKENISED QUERY="
    echo "${QUERY}" |
      ${GREP} "${INDEX}|${STRING}|${WORD}|${WILDCARD}|${FILTER}|${DEEPSCAN}|${SET}|${INDEXALL}|." |
      grep -Ev "^${SPACE}$|^\\.$|^\[$|^\]$|^'$|^\\\$$|^\)$" >/dev/stderr
  }
  if [[ ${is_wordsplit_disabled} != 0 ]]; then unsetopt shwordsplit; fi
}

# JSONPath_create_filter creates the filter from the user's query.
# Filter works in a single pass through the data, unless a filter (script)
#  expression is used, in which case two passes are required (MULTIPASS=1).
JSONPath_create_filter() {

  local len=${#PATHTOKENS[*]}

  local -i i=0
  local a query="^\[" comma=
  while [[ i -lt len ]]; do
    case "${PATHTOKENS[i]}" in
    '"')
      :
      ;;
    '..')
      query+="${comma}[^]]*"
      comma=
      ;;
    '[*]')
      query+="${comma}[^,]*"
      comma=","
      ;;
    '*')
      query+="${comma}(\"[^\"]*\"|[0-9]+[^],]*)"
      comma=","
      ;;
    '?(@'*)
      a=${PATHTOKENS[i]#?(@.}
      elem="${a%%[<>=!]*}"
      rhs="${a##*[<>=!]}"
      a="${a#${elem}}"
      elem="${elem//./[\",.]+}" # Allows child node matching
      operator="${a%${rhs}}"
      [[ -z ${operator} ]] && {
        operator="=="
        rhs=
      }
      if [[ ${rhs} == *'"'* || ${rhs} == *"'"* ]]; then
        case ${operator} in
        '==' | '=')
          OPERATOR=
          if [[ ${elem} == '?(@' ]]; then
            # To allow search on @.property such as:
            #   $..book[?(@.title==".*Book 1.*")]
            query+="${comma}[0-9]+[],][[:space:]\"]*${rhs//\"/}"
          else
            # To allow search on @ (this node) such as:
            #   $..reviews[?(@==".*Fant.*")]
            query+="${comma}[0-9]+,\"${elem}\"[],][[:space:]\"]*${rhs//\"/}"
          fi
          FILTER="${query}"
          ;;
        '>=' | '>')
          OPERATOR=">"
          RHS="${rhs}"
          query+="${comma}[0-9]+,\"${elem}\"[],][[:space:]\"]*"
          FILTER="${query}"
          ;;
        '<=' | '<')
          OPERATOR="<"
          RHS="${rhs}"
          query+="${comma}[0-9]+,\"${elem}\"[],][[:space:]\"]*"
          FILTER="${query}"
          ;;
        *) return 1 ;;
        esac
      else
        case ${operator} in
        '==' | '=')
          OPERATOR=
          query+="${comma}[0-9]+,\"${elem}\"[],][[:space:]\"]*${rhs}"
          FILTER="${query}"
          ;;
        '>=')
          OPERATOR="-ge"
          RHS="${rhs}"
          query+="${comma}[0-9]+,\"${elem}\"[],][[:space:]\"]*"
          FILTER="${query}"
          ;;
        '>')
          OPERATOR="-gt"
          RHS="${rhs}"
          query+="${comma}[0-9]+,\"${elem}\"[],][[:space:]\"]*"
          FILTER="${query}"
          ;;
        '<=')
          OPERATOR="-le"
          RHS="${rhs}"
          query+="${comma}[0-9]+,\"${elem}\"[],][[:space:]\"]*"
          FILTER="${query}"
          ;;
        '<')
          OPERATOR="-lt"
          RHS="${rhs}"
          query+="${comma}[0-9]+,\"${elem}\"[],][[:space:]\"]*"
          FILTER="${query}"
          ;;
        *) return 1 ;;
        esac
      fi
      JSONPath[MULTIPASS]=1
      ;;
    "["*)
      if [[ ${PATHTOKENS[i]} =~ , ]]; then
        a=${PATHTOKENS[i]#[}
        a=${a%]}
        if [[ ${a} =~ [[:alpha:]] ]]; then
          # converts only one comma: s/("[^"]+),([^"]+")/\1`\2/g;s/"//g
          #a=$(echo $a | sed 's/\([[:alpha:]]*\)/"\1"/g')
          a=$(echo "${a}" | sed -r "s/[\"']//g;s/([^,]*)/\"\1\"/g")
        fi
        query+="${comma}(${a//,/|})"
      elif [[ ${PATHTOKENS[i]} =~ : ]]; then
        if ! [[ ${PATHTOKENS[i]} =~ [0-9][0-9] || ${PATHTOKENS[i]} =~ :] ]]; then
          if [[ ${PATHTOKENS[i]#*:} =~ : ]]; then
            INDEXMATCH_QUERY+=("${PATHTOKENS[i]}")
            query+="${comma}[^,]*"
          else
            # Index in the range of 0-9 can be handled by regex
            query+="${comma}$(echo "${PATHTOKENS[i]}" |
              gawk '/:/ { a=substr($0,0,index($0,":")-1);
                         b=substr($0,index($0,":")+1,index($0,"]")-index($0,":")-1);
                         if(b>0) { print a ":" b-1 "]" };
                         if(b<=0) { print a ":]" } }' |
              sed 's/\([0-9]\):\([0-9]\)/\1-\2/;
                       s/\[:\([0-9]\)/[0-\1/;
                       s/\([0-9]\):\]/\1-9999999]/')"
          fi
        else
          INDEXMATCH_QUERY+=("${PATHTOKENS[i]}")
          query+="${comma}[^,]*"
        fi
      else
        a=${PATHTOKENS[i]#[}
        a=${a%]}
        if [[ ${a} =~ [[:alpha:]] ]]; then
          a=$(echo "${a}" | sed -r "s/[\"']//g;s/([^,]*)/\"\1\"/g")
        else
          [[ ${i} -gt 0 ]] && comma=","
        fi
        query+="${comma}${a}"
      fi
      comma=","
      ;;
    *)
      PATHTOKENS[i]=${PATHTOKENS[i]//\'/\"}
      query+="${comma}\"${PATHTOKENS[i]//\"/}\""
      comma=","
      ;;
    esac
    i=$((i + 1))
  done

  [[ -z ${FILTER} ]] && FILTER="${query}[],]"
  [[ ${JSONPath[DEBUG]} -eq 1 ]] && echo "FILTER=${FILTER}" >/dev/stderr
}

JSONPath_parse_array() {

  local index=0
  local ary=''
  read -r token
  case "${token}" in
  ']') ;;

  *)
    while :; do
      JSONPath_parse_value "$1" "${index}"
      index=$((index + 1))
      ary="${ary}""${value}"
      read -r token
      case "${token}" in
      ']') break ;;
      ',') ary="${ary}," ;;
      *) JSONPath_throw "EXPECTED , or ] GOT ${token:-EOF}" ;;
      esac
      read -r token
    done
    ;;
  esac
  value=
  :
}

JSONPath_parse_object() {

  local key
  local obj=''
  read -r token
  case "${token}" in
  '}') ;;

  *)
    while :; do
      case "${token}" in
      '"'*'"') key=${token} ;;
      *) JSONPath_throw "EXPECTED string GOT ${token:-EOF}" ;;
      esac
      read -r token
      case "${token}" in
      ':') ;;
      *) JSONPath_throw "EXPECTED : GOT ${token:-EOF}" ;;
      esac
      read -r token
      JSONPath_parse_value "$1" "${key}"
      obj="${obj}${key}:${value}"
      read -r token
      case "${token}" in
      '}') break ;;
      ',') obj="${obj}," ;;
      *) JSONPath_throw "EXPECTED , or } GOT ${token:-EOF}" ;;
      esac
      read -r token
    done
    ;;
  esac
  value=
  :
}

JSONPath_parse_value() {

  local jpath="${1:+$1,}$2" isleaf=0 isempty=0 print=0
  case "${token}" in
  '{') JSONPath_parse_object "${jpath}" ;;
  '[') JSONPath_parse_array "${jpath}" ;;
    # At this point, the only valid single-character tokens are digits.
  '' | [!0-9]) JSONPath_throw "EXPECTED value GOT ${token:-EOF}" ;;
  *)
    value=${token}
    # if asked, replace solidus ("\/") in json strings with normalized value: "/"
    # Testing:
    #[ "${JSONPath[NORMALIZE_SOLIDUS]}" -eq 1 ] && value=$(echo "${value}" | sed 's#\\/#/#g')
    [[ ${JSONPath[NORMALIZE_SOLIDUS]} -eq 1 ]] && value=$(${value//\\\///})
    isleaf=1
    [[ ${value} == '""' ]] && isempty=1
    ;;
  esac
  [[ -z ${JSONPath[INCLEMPTY]} ]] && [[ ${value} == '' ]] && return
  [[ ${JSONPath[NO_HEAD]} -eq 1 ]] && [[ -z ${jpath} ]] && return

  [[ ${isleaf} -eq 1 ]] && [[ ${isempty} -eq 0 ]] && print=1
  [[ ${print} -eq 1 ]] && printf "[%s]\t%s\n" "${jpath}" "${value}"
  :
}

JSONPath_flatten() {

  local path a prevpath pathlen

  if [[ ${JSONPath[FLATTEN]} -eq 1 ]]; then
    cat >"${JSONPath[STDINFILE2]}"

    highest=9999

    while read -r line; do
      a=${line#[}
      a=${a%%]*}
      readarray -t path < <(grep -o "[^,]*" <<<"${a}")
      [[ -z ${prevpath} ]] && {
        prevpath=("${path[@]}")
        highest=$((${#path[*]} - 1))
        continue
      }

      pathlen=$((${#path[*]} - 1))

      for i in $(seq 0 "${pathlen}"); do
        [[ ${path[i]} != "${prevpath[i]}" ]] && {
          high=${i}
          break
        }
      done

      [[ ${high} -lt ${highest} ]] && highest=${high}

      prevpath=("${path[@]}")
    done <"${JSONPath[STDINFILE2]}"

    if [[ ${highest} -gt 0 ]]; then
      sed -r 's/\[(([0-9]+|"[^"]+")[],]){'$((highest))'}(.*)/[\3/' \
        "${JSONPath[STDINFILE2]}"
    else
      cat "${JSONPath[STDINFILE2]}"
    fi
  else
    cat
  fi
}

# JSONPath_indexmatcher is for double digit or greater indexes match each line
# individually Single digit indexes are handled more efficiently by regex
JSONPath_indexmatcher() {

  local a b

  [[ ${JSONPath[DEBUG]} -eq 1 ]] && {
    for i in $(seq 0 $((${#INDEXMATCH_QUERY[*]} - 1))); do
      echo "INDEXMATCH_QUERY[${i}]=${INDEXMATCH_QUERY[i]}" >/dev/stderr
    done
  }

  matched=1

  step=
  if [[ ${#INDEXMATCH_QUERY[*]} -gt 0 ]]; then
    while read -r line; do
      for i in $(seq 0 $((${#INDEXMATCH_QUERY[*]} - 1))); do
        [[ ${INDEXMATCH_QUERY[i]#*:} =~ : ]] && {
          step=${INDEXMATCH_QUERY[i]##*:}
          step=${step%]}
          INDEXMATCH_QUERY[i]="${INDEXMATCH_QUERY[i]%:*}]"
        }
        q=${INDEXMATCH_QUERY[i]:1:-1} # <- strip '[' and ']'
        a=${q%:*}                     # <- number before ':'
        b=${q#*:}                     # <- number after ':'
        [[ -z ${b} ]] && b=99999999999
        readarray -t num < <((grep -Eo '[0-9]+[],]' | tr -d ,]) <<<"${line}")
        if [[ ${num[i]} -ge ${a} && ${num[i]} -lt ${b} && matched -eq 1 ]]; then
          matched=1
          [[ ${i} -eq $((${#INDEXMATCH_QUERY[*]} - 1)) ]] && {
            if [[ ${step} -gt 1 ]]; then
              [[ $(((num[i] - a) % step)) -eq 0 ]] && {
                [[ ${JSONPath[DEBUG]} -eq 1 ]] && echo -n "(${a},${b},${num[i]}) " >/dev/stderr
                echo "${line}"
              }
            else
              [[ ${JSONPath[DEBUG]} -eq 1 ]] && echo -n "(${a},${b},${num[i]}) " >/dev/stderr
              echo "${line}"
            fi
          }
        else
          matched=0
          continue
        fi
      done
      matched=1
    done
  else
    cat -
  fi
}

JSONPath_brief() {
  # Only show the value

  if [[ ${JSONPath[BRIEF]} -eq 1 ]]; then
    sed 's/^[^\t]*\t//;s/^"//;s/"$//;'
  else
    cat
  fi
}

JSONPath_json() {
  # Turn output into JSON

  local a tab="$'\t'"
  local UP=1 DOWN=2 SAME=3
  local prevpathlen=-1 prevpath=() path a
  declare -a closers

  if [[ ${JSONPath[JSON]} -eq 0 ]]; then
    cat -
  else
    while read -r line; do
      a=${line#[}
      a=${a%%]*}
      readarray -t path < <(grep -o "[^,]*" <<<"${a}")
      value=${line#*${tab}}

      # Not including the object itself (last item)
      pathlen=$((${#path[*]} - 1))

      # General direction

      direction=${SAME}
      [[ ${pathlen} -gt ${prevpathlen} ]] && direction=${DOWN}
      [[ ${pathlen} -lt ${prevpathlen} ]] && direction=${UP}

      # Handle jumps UP the tree (close previous paths)

      [[ ${prevpathlen} != -1 ]] && {
        for i in $(seq 0 $((pathlen - 1))); do
          [[ ${prevpath[i]} == "${path[i]}" ]] && continue
          [[ ${path[i]} != '"'* ]] && {
            # Testing double quotes:
            a="(${!arrays[*]})"
            [[ -n ${a} ]] && {
              for k in $(seq $((i + 1)) "${a[-1]}"); do
                arrays[k]=
              done
            }
            a="(${!comma[*]})"
            [[ -n ${a} ]] && {
              for k in $(seq $((i + 1)) "${a[-1]}"); do
                comma[k]=
              done
            }
            for j in $(seq $((prevpathlen)) -1 $((i + 2))); do
              arrays[j]=
              [[ -n ${closers[j]} ]] && {
                indent=$((j * 4))
                printf "\n%${indent}s${closers[j]}" ""
                unset "closers[j]"
                comma[j]=
              }
            done
            direction=${DOWN}
            break
          }
          direction=${DOWN}
          for j in $(seq $((prevpathlen)) -1 $((i + 1))); do
            arrays[j]=
            [[ -n ${closers[j]} ]] && {
              indent=$((j * 4))
              printf "\n%${indent}s${closers[j]}" ""
              unset "closers[j]"
              comma[j]=
            }
          done
          a="(${!arrays[*]})"
          [[ -n ${a} ]] && {
            for k in $(seq "${i}" "${a[-1]}"); do
              arrays[k]=
            done
          }
          break
        done
      }

      [[ ${direction} -eq ${UP} ]] && {
        [[ ${prevpathlen} != -1 ]] && comma[prevpathlen]=
        for i in $(seq $((prevpathlen + 1)) -1 $((pathlen + 1))); do
          arrays[i]=
          [[ -n ${closers[i]} ]] && {
            indent=$((i * 4))
            printf "\n%${indent}s${closers[i]}" ""
            unset "closers[i]"
            comma[i]=
          }
        done
        a="(${!arrays[*]})"
        [[ -n ${a} ]] && {
          for k in $(seq "${i}" "${a[-1]}"); do
            arrays[k]=
          done
        }
      }

      # Opening braces (the path leading up to the key)

      broken=
      for i in $(seq 0 $((pathlen - 1))); do
        [[ -z ${broken} && ${prevpath[i]} == "${path[i]}" ]] && continue
        [[ -z ${broken} ]] && {
          broken=${i}
          [[ ${prevpathlen} -ne -1 ]] && broken=$((i + 1))
        }
        if [[ ${path[i]} == '"'* ]]; then
          # Object
          [[ ${i} -ge ${broken} ]] && {
            indent=$((i * 4))
            printf "${comma[i]}%${indent}s{\n" ""
            closers[i]='}'
            comma[i]=
          }
          indent=$(((i + 1) * 4))
          printf "${comma[i]}%${indent}s${path[i]}:\n" ""
          comma[i]=",\n"
        else
          # Array
          if [[ ${arrays[i]} != 1 ]]; then
            indent=$((i * 4))
            printf "%${indent}s" ""
            echo "["
            closers[i]=']'
            arrays[i]=1
            comma[i]=
          else
            indent=$(((i + 1) * 4))
            printf "\n%${indent}s${closers[i - 1]}" ""
            direction=${DOWN}
            comma[i + 1]=",\n"
          fi
        fi
      done

      # keys & values

      if [[ ${path[-1]} == '"'* ]]; then
        # Object
        [[ ${direction} -eq ${DOWN} ]] && {
          indent=$((pathlen * 4))
          printf "${comma[pathlen]}%${indent}s{\n" ""
          closers[pathlen]='}'
          comma[pathlen]=
        }
        indent=$(((pathlen + 1) * 4))
        printf "${comma[pathlen]}%${indent}s" ""
        echo -n "${path[-1]}:${value}"
        comma[pathlen]=",\n"
      else
        # Array
        [[ ${arrays[i]} != 1 ]] && {
          indent=$(((pathlen - 0) * 4))
          printf "%${indent}s[\n" ""
          closers[pathlen]=']'
          comma[pathlen]=
          arrays[i]=1
        }
        indent=$(((pathlen + 1) * 4))
        printf "${comma[pathlen]}%${indent}s" ""
        echo -n "${value}"
        comma[pathlen]=",\n"
      fi

      prevpath=("${path[@]}")
      prevpathlen=${pathlen}
    done

    # closing braces

    for i in $(seq $((pathlen)) -1 0); do
      indent=$((i * 4))
      printf "\n%${indent}s${closers[i]}" ""
    done
    echo
  fi
}

JSONPath_filter() {
  # Apply the query filter

  local a tab=$'\t' v

  [[ ${JSONPath[NOCASE]} -eq 1 ]] && opts+="i"
  [[ ${JSONPath[WHOLEWORD]} -eq 1 ]] && opts+="w"
  if [[ -z ${OPERATOR} ]]; then
    [[ ${JSONPath[MULTIPASS]} -eq 1 ]] && FILTER="${FILTER}[\"]?$"
    grep "-E${opts}" "${FILTER}"
    [[ ${JSONPath[DEBUG]} -eq 1 ]] && echo "FILTER=${FILTER}" >/dev/stderr
  else
    grep "-E${opts}" "${FILTER}" |
      while read -r line; do
        v=${line#*${tab}}
        case ${OPERATOR} in
        '-ge')
          if gawk '{exit !($1>=$2)}' <<<"${v} ${RHS}"; then echo "${line}"; fi
          ;;
        '-gt')
          if gawk '{exit !($1>$2) }' <<<"${v} ${RHS}"; then echo "${line}"; fi
          ;;
        '-le')
          if gawk '{exit !($1<=$2) }' <<<"${v} ${RHS}"; then echo "${line}"; fi
          ;;
        '-lt')
          if gawk '{exit !($1<$2) }' <<<"${v} ${RHS}"; then echo "${line}"; fi
          ;;
        '>')
          v=${v#\"}
          v=${v%\"}
          RHS=${RHS#\"}
          RHS=${RHS%\"}
          [[ ${v,,} > ${RHS,,} ]] && echo "${line}"
          ;;
        '<')
          v=${v#\"}
          v=${v%\"}
          RHS=${RHS#\"}
          RHS=${RHS%\"}
          [[ ${v,,} < ${RHS,,} ]] && echo "${line}"
          ;;
        *) return 1 ;;
        esac
      done
  fi
}

JSONPath_parse() {
  # Parses json

  read -r token
  JSONPath_parse_value
  read -r token
  case "${token}" in
  '') ;;
  *)
    JSONPath_throw "EXPECTED EOF GOT ${token}"
    exit 1
    ;;
  esac
}

JSONPath_throw() {
  echo "$*" >&2
  exit 1
}

JSONPath_new || exit 1

# vi: expandtab sw=2 ts=2
