#!/usr/bin/env bash
# Create two veth pairs for VPP to bind/use from host
# Usage: sudo ./create_veths.sh
#set -euo pipefail

VETH_A_HOST=veth-host-a
VETH_A_PEER=veth-peer-a
VETH_B_HOST=veth-host-b
VETH_B_PEER=veth-peer-b

# cleanup previous
ip link del "$VETH_A_HOST" 2>/dev/null || true
ip link del "$VETH_B_HOST" 2>/dev/null || true

# create veth pairs
ip link add "$VETH_A_HOST" type veth peer name "$VETH_A_PEER"
ip link add "$VETH_B_HOST" type veth peer name "$VETH_B_PEER"

# Bring up host ends
ip link set "$VETH_A_HOST" up
ip link set "$VETH_B_HOST" up

# Bring up peer ends (these could be moved to netns for container test)
ip link set "$VETH_A_PEER" up
ip link set "$VETH_B_PEER" up

# Show summary
ip -d link show "$VETH_A_HOST" "$VETH_A_PEER" "$VETH_B_HOST" "$VETH_B_PEER"

echo "Created veth pairs: $VETH_A_HOST<->$VETH_A_PEER and $VETH_B_HOST<->$VETH_B_PEER"

echo "If you want to move peers into a namespace for testing, run:\n  ip netns add vppns\n  ip link set $VETH_A_PEER netns vppns\n  ip link set $VETH_B_PEER netns vppns\n  ip netns exec vppns ip link set $VETH_A_PEER up\n  ip netns exec vppns ip link set $VETH_B_PEER up"
