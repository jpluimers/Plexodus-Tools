#!/usr/bin/env bash
# encoding: utf-8

#FIXME: move this to an variables.env file
REQUEST_THROTTLE="${REQUEST_THROTTLE:-0}"

function debug() {
  if [ "$DEBUG" == "1" -o "$DEBUG" == "true" -o "$DEBUG" == "TRUE" ]; then
    echo -e "$@" 1>&2
  fi
}

function gnused_string() {
  if hash gsed 2>/dev/null; then
    echo 'gsed -E'
  else
    echo 'sed -E'
  fi
}

function gnudate_string() {
  if hash gdate 2>/dev/null; then
    echo 'LC_ALL=en_GB gdate'
  else
    echo 'LC_ALL=en_GB date'
  fi
}

function gnugrep_string() {
  if hash ggrep 2>/dev/null; then
    echo 'ggrep -E'
  else
    echo 'grep -E'
  fi
}

function gnused() {
  if hash gsed 2>/dev/null; then
    debug "gnused(): gsed -E \"$@\""
    gsed -E "$@"
  else
    debug "gnused(): sed -E \"$@\""
    sed -E "$@"
  fi
}

function gnugrep() {
  if hash ggrep 2>/dev/null; then
    debug "gnugrep(): ggrep -E \"$@\""
    ggrep "$@"
  else
    debug "gnugrep(): grep -E \"$@\""
    grep "$@"
  fi
}

function gnudate() {
  #FIXME: find out how I can prevent the loss of the quotes around the format in the debug output
  debug "gnudate(): $(gnudate_string) $@"
  if hash gdate 2>/dev/null; then
    gdate "$@"
  else
    date "$@"
  fi
}

function sanitise_filename() {
  debug "sanitising filename $@"
  gnused 's/[^-a-zA-Z0-9_.]/-/g'
}


function domain_from_url() {
  debug "Retrieving domain from URL $1: echo \"$1\" | $(gnused_string) 's/https?:\/\/([^/]+)\/.+/\1/g')"
  domain="$(echo "$1" | gnused 's/https?:\/\/([^/]+)\/.+/\1/g')"
  debug "Domain: $domain"
  echo "$domain"
}

function path_from_url() {
  debug "Retrieving path from URL $1: echo \"$1\" | $(gnused_string) 's/https?:\/\/([^/]+)\/(.+)$/\2/g')"
  path="$(echo "$1" | gnused 's/https?:\/\/([^/]+)\/(.+)$/\2/g')"
  debug "Path: $path"
  echo "$path"
}

function ensure_path() {
  debug "ensure_path called with: $@ "
  if [ -z "$1" -o "$1" == "" ]; then
    echo "ensure_path called with an undefined path \$1" 1>&2
    exit 255
  elif [ -z "$2" -o "$2" == "" ]; then
    echo "ensure_path called with an undefined filename \$2" 1>&2
    exit 255
  else
    mkdir -p "$1"
    echo "$1/$2"
  fi
}

function ensure_blogger_api() {
  if [ -z "$BLOGGER_APIKEY" -o "$BLOGGER_APIKEY" == "" ]; then
    echo "This command requires access to the Blogger API, but ENVironment variable BLOGGER_APIKEY is not set. Please set it to your Blogger API v3 API key." 1>&2
    exit 255
  fi
}

function ensure_gplus_api() {
  if [ -z "$GPLUS_APIKEY" -o "$GPLUS_APIKEY" == "" ]; then
    echo "This command requires access to the Google+ API via an API key, but ENVironment variable GPLUS_APIKEY is not set. Please set it to your Google Plus API key." 1>&2
    exit 255
  fi
}

function check_help() {
  if [ -n "$1" -a "$1" == "--help" ]; then
    if [ -z "$2" -o "$2" == "" ]; then
      echo -e "Usage: $(basename "$0")\nUsage definition undefined" 1>&2
      exit 255
    fi
    echo -e "$2"
    exit 0
  fi
}

function timestamp() {
  function_usage=("Usage: timestamp(\"\$format\" \"\$additional_date_arguments\")")
  function_usage+=("Supports a number of format shorthands, as well as custom format.")
  function_usage+=("Examples:")
  function_usage+=("timestamp \"day\" # $(DEBUG=0 gnudate +"%Y-%m-%d")")
  function_usage+=("timestamp \"week\" # $(DEBUG=0 gnudate +"%Y-%W")")
  function_usage+=("timestamp \"month\" # $(DEBUG=0 gnudate +"%Y-%m")")
  function_usage+=("timestamp \"year\" # $(DEBUG=0 gnudate +"%Y")")
  function_usage+=("timestamp \"iso-8601\" # $(DEBUG=0 gnudate --iso-8601)")
  function_usage+=("timestamp \"iso-8601=seconds\" # $(DEBUG=0 gnudate --iso-8601=seconds)")
  function_usage+=("timestamp \"rfc-3339\" # $(DEBUG=0 gnudate --rfc-3339=seconds)")
  function_usage+=("timestamp \"rfc-email\" # or \"rfc-5322\" # $(DEBUG=0 gnudate --rfc-email)")
  function_usage+=("timestamp \"rss\" # $(DEBUG=0 gnudate "+\"%a, %d %b %Y %H:%M:%S %z\"")")
  function_usage+=("timestamp \"%H:%M:%S, %a %d-%m-%y\" -u -d '2019-02-03 18:23:01' # $(DEBUG=0 gnudate +"%H:%M:%S, %a %d-%m-%y" -u -d '2019-02-03 18:23:01')")
  function_usage=$( IFS=$'\n'; echo "${function_usage[*]}" )

  date_arguments=()
  if [ -z "$1" ]; then
    echo -e "timestamp() called without arguments.\n$function_usage" 1>&2 && return 255
  elif [ "$1" == "day" ]; then
    ts_format="%Y-%m-%d"
  elif [ "$1" == "week" ]; then
    ts_format="%Y-%W"
  elif [ "$1" == "month" ]; then
    ts_format="%Y-%m"
  elif [ "$1" == "year" ]; then
    ts_format="%Y"
  elif [ "$1" == "iso-8601" ]; then
    date_arguments+=("--$1")
    ts_format=""
  elif [ "$1" == "iso-8601-seconds" -o "$1" == "iso-8601=seconds" ]; then
    date_arguments=("--iso-8601=seconds")
    ts_format=""
  elif [ "$1" == "rfc-3339" ]; then
    date_arguments=("--$1=seconds")
    ts_format=""
  elif [ "$1" == "rfc-5322" -o "$1" == "rfc-email" ]; then
    date_arguments=("--rfc-email")
    ts_format=""
  elif [ "$1" == "rss" -o "$1" == "rfc-822" ]; then # per https://groups.yahoo.com/neo/groups/rss-public/conversations/topics/536
    ts_format="%a, %d %b %Y %H:%M:%S %z"
  else
    ts_format="$1"
  fi

  shift 1
  # echo "ts_format: '$ts_format'"
  # echo "date_arguments: '$date_arguments'"
  if [ "$ts_format" == "" ]; then
    gnudate "$date_arguments$@"
  else
    debug "gnudate(): $(gnudate_string) $date_arguments$@" +"\"$ts_format\""
    DEBUG=0 gnudate "$date_arguments$@" +"$ts_format"
  fi
}

# FIXME: replace calls to this with the more generic version
function timestamp_date() {
  timestamp "%y-%m-%d" #FIXME: should probably just use 'day' instead of this double-digit year format.
}

function activity_file() {
  activity_id="$1"
  if [ "$activity_id" == "" ]; then
    echo "activity_file() called with an undefined activity_id \$1" 1>&2
    exit 255
  else
    activity_filepath="$(ensure_path "./data/gplus/activities" "$activity_id.json")"
    debug "Filepath for Activity Resource $activity_id: $activity_filepath"
    echo "$activity_filepath"
  fi
}

function user_profile_file() {
  user_id="$1"
  if [ "$user_id" == "" ]; then
    echo "user_profile_filepath() called with an undefined user_id \$1" 1>&2
    exit 255
  elif [[ "$1" =~ [0-9]+$ ]]; then
    if [ -z "$2" ]; then
      suffix=""
    else
      suffix=".$(timestamp "$2" -u)"
    fi
    user_id="$1"
    user_profile_filepath="$(ensure_path "./data/gplus/users" "${user_id}${suffix}.json")"
    debug "Filepath for GPlus People resource with ID $user_id: $user_profile_filepath"
    echo "$user_profile_filepath"
  else
    echo "user_profile_filepath(): Please supply the user id (\$1) in their numeric form" 1>&2
    exit 255
  fi
}

function comments_file() {
  activity_id="$1"
  if [ "$activity_id" == "" ]; then
    echo "comments_file() called with an undefined activity_id \$1" 1>&2
    exit 255
  else
    comments_filepath="$(ensure_path "./data/gplus/activities/$activity_id" "comments.json")"
    debug "Filepath for Comments Resource List for Activity with id $activity_id: $comments_filepath"
    echo "$comments_filepath"
  fi
}

function api_url() {
  api_url_usage="Usage: api_url(\"\$api_name\" \"\$api_endpoint\" \"\$api_endpoint_action\" \$api_arguments)\nExamples:\n"
  api_url_usage="${api_url_usage}api_url(\"gplus\" \"people\" \"get\" \$user_id)\n"
  if [ -z "$1" ]; then
    echo -e "api_url() called without arguments.\n$api_url_usage" 1>&2 && return 255
  elif [ "$1" == "gplus" ]; then #https://developers.google.com/+/web/api/rest/index
    gplus_api_url="https://www.googleapis.com/plus/v1"
    
    if [ -z "$2" ]; then
      echo -e "api_url(\"$1\") needs more arguments.\n$api_url_usage" 1>&2 && return 255
    elif [ "$2" == "people" ]; then #https://developers.google.com/+/web/api/rest/latest/people
      gplus_api_url="${gplus_api_url}/people"
      if [ -z "$3" ]; then
        echo -e "api_url(\"$1\" \"$3\") needs more arguments.\n$api_url_usage" 1>&2 && return 255
      elif [ "$3" == "get" ]; then #https://developers.google.com/+/web/api/rest/latest/people/get
        if [ -z "$4" ]; then
          echo -e "api_url(\"$1\" \"$3\" \"\$user_id\") is missing its \$user_id.\n$api_url_usage" 1>&2 && return 255
        elif [[ "$4" =~ [0-9]+$ ]]; then
          echo "$gplus_api_url/$4?key=$GPLUS_APIKEY"
        else
          echo -e "api_url(\"$1\" \"$3\" \"\$user_id\") \$user_id needs to be a numeric id; '$4' was given.\n$api_url_usage" 1>&2 && return 255
        fi
      else
        echo -e "api_url(\"$1\" \"$2\" \"$api_endpoint_action\") called with an unknown API endpoint action '$3'. $api_url_usage" 1>&2 && return 255
      fi
    else
      echo -e "api_url(\"$1\" \"$api_endpoint\") called with an unknown API endpoint '$2'. $api_url_usage" 1>&2 && return 255
    fi
  else
    echo -e "api_url(\"\$api_name\") called with an unknown API name '$1'. $api_url_usage" 1>&2 && return 255
  fi
}

function cache_remote_document_to_file() { # $1=url, $2=local_file, $3=curl_args
  function_usage="Usage: cache_external_document_to_file(\"\$url\" \"\$local_filepath\")\n"
  if [ -z "$1" ]; then
    echo -e "cache_external_document_to_file() called without arguments.\n$api_url_usage" 1>&2 && return 255
  elif [[ "$1" =~ (^https?|ftps?):// ]]; then
    if [ -z "$2" ]; then
      echo -e "cache_external_document_to_file(\"$1\") needs more arguments.\n$function_usage" 1>&2 && return 255
    elif [ ! -f "$2" ]; then
      if [ -z "$3" ]; then
        curl_args=""
      else
        curl_args="$3 "
      fi
      debug "cache_external_document_to_file(): Retrieving JSON from $1 and storing it at $2"
      status_code="$(curl --write-out %{http_code} --silent --output ${curl_args}"$2" "$1")"
      if [ "$status_code" -ne 200 ]; then
        echo "cache_external_document_to_file(\"$1\" \"$2\" \"$3\"): Error while retrieving remote document. Status code returned: $status_code" 1>&2 && return 255
      else
        echo "$2"
      fi
    else
      debug "Cache hit for ${1}: $2"
      echo "$2"
    fi
  else
    echo -e "cache_external_document_to_file(): unsupported protocol for \$url ('$1'); only http(s) and ftp(s) are currently supported.\n$function_usage" 1>&2 && return 255
  fi
}