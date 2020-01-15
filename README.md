# TestRail.bash
a simple script to access TestRail APIs.

### Requirement:
  - bash version 3.2.57 
  - curl
  - jq

### What does it do:
It started with an idea to help test planner randomly assigning tests to a list of testers since TestRail web UI does not provide such a feature. TR.sh will evolve into a script that provides CLI ways to list, create and delete Project, Runs, Cases and Tests through TestRails.

### Usage:
$ HOST="https://where.testrail.com" TOKEN="email:secrets" TR.sh

### Note:
This script begins as a practice for myself, please feel free to give any suggestions to the feature and code logic.

