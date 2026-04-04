#!/bin/sh
set -eu

eval "$(ssh-agent -s)"
ssh-add /tmp/proxmox_automation

exec /home/tfc-agent/bin/tfc-agent