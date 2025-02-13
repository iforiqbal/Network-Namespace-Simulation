#!/bin/bash

set -e  # Exit on any error

run_command(){
    echo -e "\n>>> $1"
    eval "$1"
    sleep 2
}

echo -e "\nCleaning up network configuration...\n"

# Delete network namespaces
run_command "sudo ip netns delete ns-red 2> /dev/null || true"
run_command "sudo ip netns delete ns-green 2> /dev/null || true"
run_command "sudo ip netns delete ns-router 2> /dev/null || true"

# Delete bridges
run_command "sudo ip link delete br1 2> /dev/null || true"
run_command "sudo ip link delete br2 2> /dev/null || true"

# Cleanup veth pairs
run_command "sudo ip link delete veth-red 2> /dev/null || true"
run_command "sudo ip link delete veth-red-br 2> /dev/null || true"
run_command "sudo ip link delete veth-rt1 2> /dev/null || true"
run_command "sudo ip link delete veth-rt1-br 2> /dev/null || true"
run_command "sudo ip link delete veth-green 2> /dev/null || true"
run_command "sudo ip link delete veth-green-br 2> /dev/null || true"
run_command "sudo ip link delete veth-rt2 2> /dev/null || true"
run_command "sudo ip link delete veth-rt2-br 2> /dev/null || true"

echo -e "\n✅ Cleanup complete! All resources removed.\n"