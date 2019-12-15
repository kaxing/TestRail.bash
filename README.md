# TestRail.bash
a simple script to use TestRail APIs

### Requirement:
  - bash 3.2.57 
  - curl
  - jq

### What does it do:
Randomly assign tests to a list of testers. The remainders will be all assign to the last person, which is also random.

### Usage:
$ HOST="where.testrail.com" TOKEN="email:secrets" test-assign $TESTRUN_ID one@email.com second@gmail.com 3rd@mail.com

### Note:
This begins as a practice for myself, and I hope to develop this script into a library, any suggestions to the feature and code logic are welcome!
