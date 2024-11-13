#!/bin/bash

BACKUP_SERVER_USER="ubuntu"
BACKUP_SERVER_IP="192.168.110.70"
BACKUP_SERVER_PATH="/tmp/"

DATE_TAG=$(date +"%Y-%m-%d")


ACTIVE_CONTAINERS=$(docker ps -q)

for CONTAINER_ID in $ACTIVE_CONTAINERS; do

  NEW_IMAGE_NAME="backup_image_${CONTAINER_ID}_$DATE_TAG"
  EXPORT_FILE="/tmp/${NEW_IMAGE_NAME}.tar"

  docker commit "$CONTAINER_ID" "$NEW_IMAGE_NAME"
  echo "Container $CONTAINER_ID committed as image $NEW_IMAGE_NAME"

  docker save -o "$EXPORT_FILE" "$NEW_IMAGE_NAME"
  echo "Image $NEW_IMAGE_NAME saved as $EXPORT_FILE"

  scp "$EXPORT_FILE" "$BACKUP_SERVER_USER@$BACKUP_SERVER_IP:$BACKUP_SERVER_PATH"
  echo "Image file $EXPORT_FILE sent to backup server at $BACKUP_SERVER_IP:$BACKUP_SERVER_PATH"
done
