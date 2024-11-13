#!/bin/bash

BACKUP_SERVER_USER="ubuntu"
BACKUP_SERVER_IP="192.168.110.70"
BACKUP_SERVER_PATH="/tmp/"

NEXUS_SERVER="192.168.110.58:8082"
NEXUS_REPO="docker-backup"
NEXUS_USER="user"
NEXUS_PASSWORD="password"


DATE_TAG=$(date +"%Y-%m-%d")


ACTIVE_CONTAINERS=$(docker ps -q)

for CONTAINER_ID in $ACTIVE_CONTAINERS; do

  LOCAL_IMAGE_NAME="backup_image_${CONTAINER_ID}_$DATE_TAG"
  NEXUS_IMAGE_NAME="$NEXUS_SERVER/$NEXUS_REPO/$LOCAL_IMAGE_NAME"
  EXPORT_FILE="/tmp/${LOCAL_IMAGE_NAME}.tar"


  docker commit "$CONTAINER_ID" "$LOCAL_IMAGE_NAME"
  echo "Container $CONTAINER_ID committed as image $LOCAL_IMAGE_NAME"

  docker tag "$LOCAL_IMAGE_NAME" "$NEXUS_IMAGE_NAME"
  echo "Tagged image as $NEXUS_IMAGE_NAME for Nexus push"


  docker login "$NEXUS_SERVER" -u "$NEXUS_USER" -p "$NEXUS_PASSWORD"
  docker push "$NEXUS_IMAGE_NAME"
  echo "Image $NEXUS_IMAGE_NAME pushed to Nexus repository"


  docker save -o "$EXPORT_FILE" "$LOCAL_IMAGE_NAME"
  echo "Image $LOCAL_IMAGE_NAME saved as $EXPORT_FILE"


  #scp "$EXPORT_FILE" "$BACKUP_SERVER_USER@$BACKUP_SERVER_IP:$BACKUP_SERVER_PATH"
  #echo "Image file $EXPORT_FILE sent to backup server at $BACKUP_SERVER_IP:$BACKUP_SERVER_PATH"
done
