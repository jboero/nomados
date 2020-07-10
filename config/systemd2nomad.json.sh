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
    -e 's/(/\\(/g' \
    -e 's/)/\\)/g' \
    $1 > /tmp/service

# Defaults here:
export User=root
export Group=root

. /tmp/service 2>/dev/null

export DOLLAR='$'
envsubst <<EOF
{
    "ID": "$name",
    "Name": "$name",
    "Type": "system",
    "Datacenters": ["dc1"],
    "Priority": 10,
    "TaskGroups": [{
        "Name": "SystemD2Nomad",
        "Count": 1,
        "Tasks": [{
            "Driver": "exec",
            "Name": "$name",
            "User": "$User",
            "Sroup": "$Group",
            "Config": {
                "Command": "$ExecStart"
            }
        }]
    }]
}
EOF
