#! /usr/bin/env bash

HOST="https://yoursubdomain.testrail.com"
API_PATH="index.php?/api/v2"
EMAIL="your@email.co"
TOKEN="ToKeNsFrOmTeStRaIls"
TYPE="Content-Type: application/json"

call-api() {
  method="$1"
  endpoint="$2"
  curl --silent \
    --header "$TYPE" \
    --request "$method" \
    --user "$EMAIL:$TOKEN" \
    "$HOST/$API_PATH/$endpoint"
}

project_id=1
suite_id="$(call-api "GET" "get_suites/$project_id"|jq '.[]|.id')"
sections=( "$(call-api "GET" "get_sections/$project_id&suite_id=$suite_id"| jq -jr '.[]|.id," "')" )
for section_id in ${sections[@]}; do
  call-api "GET" "get_section/$section_id" \
    | jq -jr '.|.name, " - ",.description,"\n"'
  call-api "GET" "get_cases/$project_id&suite_id=$suite_id&section_id=$section_id" \
    | jq -jr '.[]|"\t",.id,", ",.title,"\n"'
done

