#!/bin/bash

CONTAINER_ID="313490859a8d"
NEW_IMAGE_NAME="nginx_proxy_db:21-8-1403"
EXPORT_FILE="/tmp/nginx_db_image_backup.tar"

docker commit "$CONTAINER_ID" "$NEW_IMAGE_NAME"
echo "Container $CONTAINER_ID committed as image $NEW_IMAGE_NAME"


docker save -o "$EXPORT_FILE" "$NEW_IMAGE_NAME"
echo "Image $NEW_IMAGE_NAME saved as $EXPORT_FILE"
