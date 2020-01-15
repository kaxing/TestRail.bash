#!/usr/bin/env bash

set -e

# key variables

EXIT_CODE=0
HEADER="Content-Type: application/json"
API_PATH="index.php?/api/v2"

# major functions

check_variables() {
  if [[ -z "$TOKEN" ]] || [[ -z "$HOST" ]]; then
    echo "\$TOKEN or \$HOST is NULL, Please assign proper values!"
    exit 1
  fi
}

pause() {
  echo -e "$@"
  read -p "Press any key to continue.."
}

check_exit_status(){
  if [[ "$EXIT_CODE" -gt "0" ]]; then
    echo "$@"
    exit 1
  fi
}

check_depedency() {
  for command in "$@"; do
    if [[ ! -x "$(command -v $command)" ]]; then
      echo "Please install \`$command\`, thank you so much!"
      let EXIT_CODE+=1
    fi
  done
  check_exit_status "Error: dependencies are not met"
}

json_formatter() {
  local input="${@:1:1}"
  local format="${@:2:2}"

  filter_default() { echo $input | jq -jr '.'; }
  filter_id_name() { echo $input | jq -jr '.[]|"\t",.id," ",.name,"\n"'; }

  case $format in
   "id-name") filter_id_name;;
   *) filter_default;;
  esac
}

call_api() {

  local variables=("$@")

  local method="${variables[0]}"
  local endpoint="${variables[1]}"
  local data="${variables[2]}"
  local parameters="${variables[3]}"

  local url=""

  # TODO: check api parameters

  if [[ ! -z $parameters ]]; then
    url="$HOST/$API_PATH/$endpoint&$parameters"
  else
    url="$HOST/$API_PATH/$endpoint"
  fi

  # Idea of redirect output via: https://superuser.com/a/862395
  exec 3>&1
  HTTP_STATUS="$( \
    curl \
    --silent \
    --write-out "%{http_code}" \
    --output >(cat >&3) \
    --request "$method" \
    --header "$HEADER" \
    --user "$TOKEN" \
    --data "$data" \
    "$url")"
}


# minor functions

get_user_id_from_json() {
  list_of_user=$(call_api "GET" "get_users")
  email="$@"
  echo "$(jq --arg email "$email" '.[]|select(.email==$email)| .id' <(echo $list_of_user))"
}

get_list_of_tests_from_run(){
  local run_id=$@
  list_of_tests=$(call_api "GET" "get_tests/$run_id")
  list_of_testids=$(shuf <(jq '.[]|.id' <(echo $list_of_tests)))
  number_of_tests=$(echo "$list_of_testids"|wc -l)
  list_of_testids=($list_of_testids)
}

add_result() {
  local variables=($@)
  local test=${variables[0]}
  local tester=${variables[1]}
  local data='{"test_id":"'$test'","assignedto_id":"'$tester'","comment":"Assign_through_API"}'
  test_id=$test # keep the name convention
  call_api "POST" "add_result/$test_id $data"
}

# main features

get_projects() {
  json_formatter "$(call_api "GET" "get_projects")" "id-name"
}

get_runs() {
  local project_id="$@"
  if [[ ! "$project_id" =~ ^[0-9]+$ ]] || [[ "$project_id" -lt "1" ]] ; then
    echo -e "Please give one valid project id."
    exit 1
  fi
  
  json_formatter "$(call_api "GET" "get_runs/$project_id")" "id-name"
}

get_cases() {
  local project_id="$@"
  local suite_id="$(call_api "GET" "get_suites/$project_id"|jq '.[]|.id')"
  # &section_id=:section_id
  json_formatter "$(call_api "GET" "get_cases/$project_id&suite_id=$suite_id")"
}

add_run() {
  local variables=("$@")
  
  local project_id="${variables[0]}"
  local name="${variables[1]}"
  local description="${variables[2]}"

  if [[ ! "$project_id" =~ ^[0-9]+$ ]] || [[ "$project_id" -lt "1" ]] ; then
    echo -e "Please give one valid project id."
    exit 1
  fi

  if [[ -z "${variables[1]}" ]]; then
    echo -e "Please assign name and description after project id,"
    echo -e "in following format:"
    echo -e " \t $(basename "$0") create-run $project_id \"A New Run\" \"and some description\""
    exit 1
  fi

  local suite_id="$(call_api "GET" "get_suites/$project_id"|jq '.[]|.id')"
  local data='{"suite_id":"'$suite_id'","name":"'$name'","description":"'$description'","include_all":true}'

  call_api "POST" "add_run/$project_id" "$data"
}

delete_run() {
  local run_id="$@"

  if [[ ! "$run_id" =~ ^[0-9]+$ ]] || [[ "$run_id" -lt "1" ]] ; then
    echo -e "Please give one valid project id."
    exit 1
  fi

  call_api "POST" "delete_run/$run_id"

  echo -e "$HTTP_STATUS"
}


assign_tests_to() {
  local args=("$@")
  local numnber_of_args="${#@}"
  local second_arg="${args[1]}"

  if [[ "$numnber_of_args" -lt "1" ]] || [[ -z "$second_arg" ]]; then
    echo "Please assign test run ID with at least one email"
    echo "Example: 12345 first.person@gmail.com second.person@gmail.com"
    exit 1
  fi

  # quiccheck server status, avoid maintaince mode
  api_server_status=$( curl --write-out "%{http_code}" --silent --output /dev/null --header "$HEADER" --request GET --user "$TOKEN" $HOST/$API_PATH/get_project/1 )
  if [ ! "$api_server_status" == "200" ]; then
    echo -e "Something wrong with API connection;\nPlease check Test Rail status."
    exit 1
  fi

  test_run_id="${args[0]}"
  get_list_of_tests_from_run $test_run_id

  email_list=("${args[@]:1}")
  testers=("${email_list[@]}")
  range=${#testers[@]}
  for((i=0; i<$range; i++)); do
    testers[$i]=$(get_user_id_from_json ${testers[i]})
  done

  tester_index=0
  divide_base=0
  test_remainders=0

  number_of_testers="${#testers[@]}"

  let divide_base=number_of_tests/number_of_testers
  if [ "$number_of_testers" -gt "1" ]; then
    let "test_remainders = number_of_tests % number_of_testers"
  fi

  pause "About to start sending massive requests to TestRail API service;"

  let "range = number_of_tests - 1"
  t=0 # tester index counter
  for((i=0; i<=$range; i++)); do
    sleep 0."$(shuf -i 0-9 -n 1)"
    add_result ${list_of_testids[$i]} ${testers[t]}
    divide_counter=$( echo $(( divide_base*(t+1) )) )
    if(( $i == $divide_counter )) && (( $t < ${#testers[@]} )); then
      let t++
    fi
  done
}

# scipt begin here

check_depedency bash curl jq

check_variables

case "$1" in
  list-project)
    get_projects
    ;;
  list-runs)
    get_runs "${@:2}"
    ;;
  list-cases)
    get_cases "${@:2}"
    ;;
  create-run)
    add_run "${@:2}"
    ;;
  delete-run)
    delete_run "${@:2}"
    ;;
  assign-tests)
    assign_tests_to "${@:2}"
    ;;
  *)
    echo -e "Actions:"
    echo -e "\tlist-project, list-runs, list-cases,\n\tcreate-run, delete-run,\n\tassign-tests"
    echo -e "\tMore detailed help messages are coming soon..."
    exit
    ;;
esac
