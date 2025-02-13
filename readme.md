---

# Linux Network Namespace Simulation

This project demonstrates how to create and connect two network namespaces (`ns-red` and `ns-green`) using bridges (`br1` and `br2`) and a router namespace (`ns-router`). The goal is to enable communication between the two namespaces via the router namespace, while also testing packet flow using `tcpdump` and inspecting ARP and routing tables.

---

## Diagram

![Namespace Network Diagram](https://i.imgur.com/uZvvbAy.png)

## Table of Contents

1. [Purpose](#purpose)
2. [Setup Overview](#setup-overview)
3. [Steps to Reproduce](#steps-to-reproduce)
4. [Testing Connectivity](#testing-connectivity)
5. [Inspecting ARP and Routing Tables](#inspecting-arp-and-routing-tables)
6. [Cleaning Up](#cleaning-up)
7. [How to Use the Scripts](#How-to-Use-the-Scripts)
8. [Poridhi Lab Issue](#poridhi-lab-issue)
9. [Github Action Workflow](#Added-github-actions-workflow)

---

## Purpose
The purpose of this task is to:

1. **Understand Linux Network Namespaces**: Learn how to isolate network interfaces and routing tables using namespaces.
2. **Work with Bridges**: Use Linux bridges to connect network interfaces across namespaces.
3. **Set Up Routing**: Configure a router namespace (`ns-router`) to forward packets between two isolated namespaces (`ns-red` and `ns-green`).
4. **Test Packet Flow**: Use `tcpdump` to monitor packets at the interface level and verify connectivity.
5. **Inspect ARP and Routing Tables**: Learn how to check ARP and routing tables to debug and understand network communication.

---

## Setup Overview

The setup consists of:

1. **Two Namespaces**:
   - `ns-red`: Represents the first network with IP `10.11.0.10/24`.
   - `ns-green`: Represents the second network with IP `10.12.0.10/24`.

2. **A Router Namespace**:
   - `ns-router`: Acts as a router between `ns-red` and `ns-green`. It has two interfaces:
     - `veth-rt1` with IP `10.11.0.1/24` (connected to `ns-red` via `br1`).
     - `veth-rt2` with IP `10.12.0.1/24` (connected to `ns-green` via `br2`).

3. **Two Bridges**:
   - `br1`: Connects `ns-red` and `ns-router`.
   - `br2`: Connects `ns-green` and `ns-router`.

4. **Routing and Forwarding**:
   - IP forwarding is enabled in `ns-router` to allow packets to flow between `ns-red` and `ns-green`.
   - `iptables` rules are added to allow traffic through the bridges.

---

## Steps to Reproduce

### 1. Create Network Namespaces
```bash
sudo ip netns add ns-red
sudo ip netns add ns-green
sudo ip netns add ns-router
```

### 2. Create Bridges
```bash
sudo ip link add br1 type bridge
sudo ip link add br2 type bridge
sudo ip link set br1 up
sudo ip link set br2 up
```

### 3. Create and Assign veth Interfaces
```bash
# For ns-red and ns-router (via br1)
sudo ip link add veth-red type veth peer name veth-red-br
sudo ip link add veth-rt1 type veth peer name veth-rt1-br

sudo ip link set veth-red netns ns-red
sudo ip link set veth-red-br master br1
sudo ip link set veth-rt1 netns ns-router
sudo ip link set veth-rt1-br master br1

# For ns-green and ns-router (via br2)
sudo ip link add veth-green type veth peer name veth-green-br
sudo ip link add veth-rt2 type veth peer name veth-rt2-br

sudo ip link set veth-green netns ns-green
sudo ip link set veth-green-br master br2
sudo ip link set veth-rt2 netns ns-router
sudo ip link set veth-rt2-br master br2
```

### 4. Assign IP Addresses
```bash
sudo ip netns exec ns-red ip addr add 10.11.0.10/24 dev veth-red
sudo ip netns exec ns-router ip addr add 10.11.0.1/24 dev veth-rt1
sudo ip netns exec ns-green ip addr add 10.12.0.10/24 dev veth-green
sudo ip netns exec ns-router ip addr add 10.12.0.1/24 dev veth-rt2
```

### 5. Bring Up Interfaces
```bash
sudo ip netns exec ns-red ip link set veth-red up
sudo ip netns exec ns-router ip link set veth-rt1 up
sudo ip netns exec ns-green ip link set veth-green up
sudo ip netns exec ns-router ip link set veth-rt2 up
sudo ip link set veth-red-br up
sudo ip link set veth-rt1-br up
sudo ip link set veth-green-br up
sudo ip link set veth-rt2-br up
```

### 6. Set Default Routes
```bash
sudo ip netns exec ns-red ip route add default via 10.11.0.1
sudo ip netns exec ns-green ip route add default via 10.12.0.1
```

### 7. Enable IP Forwarding in `ns-router`
```bash
sudo ip netns exec ns-router sysctl -w net.ipv4.ip_forward=1
```

### 8. Add `iptables` Rules for Forwarding
```bash
sudo ip netns exec ns-router iptables -A FORWARD -i veth-rt1 -o veth-rt2 -j ACCEPT
sudo ip netns exec ns-router iptables -A FORWARD -i veth-rt2 -o veth-rt1 -j ACCEPT
```

---

## Testing Connectivity

### Ping Between Namespaces
```bash
sudo ip netns exec ns-red ping -c 3 10.12.0.10
sudo ip netns exec ns-green ping -c 3 10.11.0.10
```

### Monitor Traffic with `tcpdump`
```bash
# Monitor traffic on veth-red in ns-red
sudo ip netns exec ns-red tcpdump -i veth-red

# Monitor traffic on veth-rt1 in ns-router
sudo ip netns exec ns-router tcpdump -i veth-rt1

# Monitor traffic on veth-rt2 in ns-router
sudo ip netns exec ns-router tcpdump -i veth-rt2

# Monitor traffic on veth-green in ns-green
sudo ip netns exec ns-green tcpdump -i veth-green
```

---

## Inspecting ARP and Routing Tables

### Check ARP Tables
```bash
sudo ip netns exec ns-red arp -n
sudo ip netns exec ns-green arp -n
sudo ip netns exec ns-router arp -n
```

### Check Routing Tables
```bash
sudo ip netns exec ns-red ip route
sudo ip netns exec ns-green ip route
sudo ip netns exec ns-router ip route
```

---


---

## Poridhi Lab Issue

If you encounter bridge connectivity issues in the Poridhi lab environment, add the following `iptables` rules:

```bash
sudo iptables --append FORWARD --in-interface br1 --jump ACCEPT
sudo iptables --append FORWARD --out-interface br1 --jump ACCEPT
sudo iptables --append FORWARD --in-interface br2 --jump ACCEPT
sudo iptables --append FORWARD --out-interface br2 --jump ACCEPT
```

### Explanation

The need to explicitly add the `iptables` rules for the bridge interfaces (`br1` and `br2`) is likely related to the specific configuration of the Poridhi lab environment and the Kubernetes (`k8s`) cluster running inside the VM. Here's why this might be happening and why it works differently on other machines:

1. **Default Firewall Policies**:
   - The Poridhi lab environment might have stricter default firewall policies or security groups that block traffic unless explicitly allowed.
   - The `iptables` rules you added ensure that traffic is allowed to pass through the bridge interfaces (`br1` and `br2`).

2. **Kubernetes Networking**:
   - Kubernetes uses its own networking plugins (e.g., CNI plugins like Flannel, Calico, or Weave) that manipulate `iptables` rules to manage pod-to-pod communication.
   - These plugins might override or interfere with the default `iptables` rules, requiring you to explicitly allow traffic through the bridges.

3. **Bridge Behavior in the Lab**:
   - In some environments, bridges do not forward traffic by default unless explicitly configured to do so.
   - The Poridhi lab might have additional restrictions or configurations that prevent bridge traffic from being forwarded without explicit `iptables` rules.

4. **Isolation in Student Labs**:
   - Student labs are often designed to be more restrictive for security and isolation purposes. This could include stricter `iptables` policies or additional network filtering.

---

## How to Use the Scripts

1. **Make the Scripts Executable**:
   ```bash
   chmod +x ns.sh ns_delete.sh
   ```

2. **Run the Setup Script**:
   ```bash
   sudo ./ns.sh
   ```

3. **Test Connectivity**:
   - The script will automatically test connectivity using `ping`.
   - You can also manually test:
     ```bash
     sudo ip netns exec ns-red ping -c 3 10.12.0.10
     sudo ip netns exec ns-green ping -c 3 10.11.0.10
     ```

4. **Clean Up**:
   ```bash
   sudo ./ns_delete.sh
   ```

---

---
### Added github actions workflow
   - You can check the workflow from actions, there is a simple pipeline for test this two scripts in Ubuntu
---

Let me know if you need further assistance! 😊