#!/bin/bash

# Create TUN device if VPN is enabled and config exists
if [ "$USE_VPN" = "1" ] && [ -f /app/config.ovpn ]; then
    echo "VPN enabled, checking TUN device..."
    if [ ! -c /dev/net/tun ]; then
        echo "Creating TUN device..."
        mkdir -p /dev/net
        mknod /dev/net/tun c 10 200
        chmod 666 /dev/net/tun
    fi
    
    echo "Starting OpenVPN..."
    openvpn --config /app/config.ovpn --daemon
    sleep 2
fi

# Start cron service
echo "Starting cron service..."
service cron start

# Start the Node.js application
echo "Starting Node.js application..."
exec npm run dev
