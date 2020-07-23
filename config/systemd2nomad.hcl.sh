#!/bin/bash
# John Boero - jboero@hashicorp.com
# A Q&D cheater script to convert a SystemD unit (arg1) to a Nomad job System task.
name=$(basename $1)

# Replace wrapping newlines..
export DOLLAR='$'
sed -e :a \
    -e '/\\$/N; s/\\\n//; ta' \
    -e 's/\$/\$\{DOLLAR\}/g' \
    -e 's/ /\\ /g' \
    -e 's/\t/\\t/g' \
    -e 's/(/\\(/g' \
    -e 's/)/\\)/g' \
    $1 > /tmp/service


# Defaults here:
export User=root
export Group=root

. /tmp/service 2>/dev/null

envsubst <<EOF
job "$name" {
  datacenters = ["dc1"]
  type = "system"
  group "systemd2nomad" {
    count = 1

    restart {
      attempts = $StartLimitBurst
      interval = "${RestartSec}s"
      mode = "fail"
    }

    task "$name" {
      driver = "system"

      config {
        command = ""
      }
    }
  }
}
EOF
