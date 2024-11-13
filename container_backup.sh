#!/bin/bash

CONTAINER_NAME="313490859a8d"
NEW_IMAGE_NAME="nginx_proxy_db:21-8-1403"

docker commit "$CONTAINER_NAME" "$NEW_IMAGE_NAME"
echo "Container $CONTAINER_NAME committed as image $NEW_IMAGE_NAME"
