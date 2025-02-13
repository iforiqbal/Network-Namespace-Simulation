#!/bin/bash

set -e  # Exit on any error

run_command(){
    echo -e "\n>>> $1"
    eval "$1"
    sleep 2
}

echo -e "\nSetting up network namespaces, bridges, and router...\n"

# Create namespaces
run_command "sudo ip netns add ns-red"
run_command "sudo ip netns add ns-green"
run_command "sudo ip netns add ns-router"

# Create bridges
run_command "sudo ip link add br1 type bridge"
run_command "sudo ip link add br2 type bridge"

# Bring up bridges
run_command "sudo ip link set br1 up"
run_command "sudo ip link set br2 up"

# Create veth pairs for ns-red and ns-router (via br1)
run_command "sudo ip link add veth-red type veth peer name veth-red-br"
run_command "sudo ip link add veth-rt1 type veth peer name veth-rt1-br"

# Create veth pairs for ns-green and ns-router (via br2)
run_command "sudo ip link add veth-green type veth peer name veth-green-br"
run_command "sudo ip link add veth-rt2 type veth peer name veth-rt2-br"

# Assign veth interfaces to namespaces and bridges
run_command "sudo ip link set veth-red netns ns-red"
run_command "sudo ip link set veth-red-br master br1"
run_command "sudo ip link set veth-rt1 netns ns-router"
run_command "sudo ip link set veth-rt1-br master br1"

run_command "sudo ip link set veth-green netns ns-green"
run_command "sudo ip link set veth-green-br master br2"
run_command "sudo ip link set veth-rt2 netns ns-router"
run_command "sudo ip link set veth-rt2-br master br2"

# Assign IP addresses
run_command "sudo ip netns exec ns-red ip addr add 10.11.0.10/24 dev veth-red"
run_command "sudo ip netns exec ns-router ip addr add 10.11.0.1/24 dev veth-rt1"
run_command "sudo ip netns exec ns-green ip addr add 10.12.0.10/24 dev veth-green"
run_command "sudo ip netns exec ns-router ip addr add 10.12.0.1/24 dev veth-rt2"

# Bring up interfaces
run_command "sudo ip netns exec ns-red ip link set veth-red up"
run_command "sudo ip netns exec ns-router ip link set veth-rt1 up"
run_command "sudo ip netns exec ns-green ip link set veth-green up"
run_command "sudo ip netns exec ns-router ip link set veth-rt2 up"
run_command "sudo ip link set veth-red-br up"
run_command "sudo ip link set veth-rt1-br up"
run_command "sudo ip link set veth-green-br up"
run_command "sudo ip link set veth-rt2-br up"

# Bring up loopback interfaces
run_command "sudo ip netns exec ns-red ip link set lo up"
run_command "sudo ip netns exec ns-green ip link set lo up"
run_command "sudo ip netns exec ns-router ip link set lo up"

# Set default routes
run_command "sudo ip netns exec ns-red ip route add default via 10.11.0.1"
run_command "sudo ip netns exec ns-green ip route add default via 10.12.0.1"

# Add routes in ns-router
run_command "sudo ip netns exec ns-router ip route add 10.11.0.0/24 dev veth-rt1 2> /dev/null || true"
run_command "sudo ip netns exec ns-router ip route add 10.12.0.0/24 dev veth-rt2 2> /dev/null || true"

# Enable IP forwarding in router namespace
run_command "sudo ip netns exec ns-router sysctl -w net.ipv4.ip_forward=1"

# Configure iptables rules for forwarding
run_command "sudo ip netns exec ns-router iptables -A FORWARD -i veth-rt1 -o veth-rt2 -j ACCEPT"
run_command "sudo ip netns exec ns-router iptables -A FORWARD -i veth-rt2 -o veth-rt1 -j ACCEPT"

# Configure iptables rules for bridge interface 
run_command "sudo iptables --append FORWARD --in-interface br1 --jump ACCEPT"
run_command "sudo iptables --append FORWARD --out-interface br1 --jump ACCEPT"
run_command "sudo iptables --append FORWARD --in-interface br2 --jump ACCEPT"
run_command "sudo iptables --append FORWARD --out-interface br2 --jump ACCEPT"

echo -e "\n✅ Setup complete! Testing connectivity...\n"

# Test connectivity
run_command "sudo ip netns exec ns-red ping -c 3 10.12.0.10"
run_command "sudo ip netns exec ns-green ping -c 3 10.11.0.10"