#!/usr/bin/env bash

source mission/mission.sh

mission "install bash utilities"
  phase apk add vim wget curl openssh

mission "start bash"
  phase /bin/bash

