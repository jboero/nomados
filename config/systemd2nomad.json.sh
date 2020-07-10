#!/bin/bash
# John Boero - jboero@hashicorp.com
# A Q&D cheater script to convert a SystemD unit (arg1) to a Nomad job System task.
name=$(basename $1)

# Replace wrapping newlines..
sed -e :a \
    -e '/\\$/N; s/\\\n//; ta' \
    -e 's/\$/\$\{DOLLAR\}/g' \
    -e 's/ /\\ /g' \
    -e 's/\t/\\t/g' \
    $1 > /tmp/service

# Defaults here:
export User=root
export Group=root

. /tmp/service 2>/dev/null

export DOLLAR='$'
envsubst <<EOF
{
    "id": "$name",
    "name": "$name",
    "type": "system",
    "group": "SystemD2Nomad",
    "priority": 10,
    "TaskGroups": [{
        "Name": "vault.service",
        "Count": 1,
        "tasks": [{
            "driver": "exec",
            "name": "$name",
            "user": "$User",
            "group": "$Group",
            "config": {
                "command": "$ExecStart"
            }
        }]
    }]
}
EOF
