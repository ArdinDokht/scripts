#!/bin/bash

if [ "$#" -ne 3 ]; then
        echo "This script need more argumant"
        echo "plz enter correct format : $0 <server-ip> <username> <password>"
        exit 1
fi

SERVER_IP=$1
USER=$2
PASSWORD=$3

ping -c 2 $SERVER_IP &> /dev/null

if [ $? -eq 0 ]; then

    echo "Server $SERVER_IP is reachable..."

    scp /etc/passwd $USER@$SERVER_IP:/home/user/

else
    echo "Server $SERVER_IP is not reachable."
fi
