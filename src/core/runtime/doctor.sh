#!/bin/bash

# Stable entry point for the diagnostic modules (also sourced by focused tests).
. "${BASH_SOURCE[0]%/*}/doctor/output.sh"
. "${BASH_SOURCE[0]%/*}/doctor/system.sh"
. "${BASH_SOURCE[0]%/*}/doctor/compat.sh"
. "${BASH_SOURCE[0]%/*}/doctor/clients.sh"
. "${BASH_SOURCE[0]%/*}/doctor/run.sh"
