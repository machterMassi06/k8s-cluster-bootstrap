#!/bin/bash

set -euo pipefail

JOIN_COMMAND=""

usage() {
    echo "Usage:"
    echo "  $0 --join-command 'kubeadm join ...'"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --join-command)
            JOIN_COMMAND="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown argument: $1"
            usage
            ;;
    esac
done

if [[ -z "$JOIN_COMMAND" ]]; then
    echo "ERROR: kubeadm join command is required."
    usage
fi

eval "$JOIN_COMMAND"