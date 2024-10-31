#!/bin/bash

MY_DATE=$(date +%Y-%m-%d)

MY_DATA=`cat ip_list`

FILE_NAME=`echo $HOSTNAME`-$MY_DATE


echo "$FILE_NAME " > $FILE_NAME.log
echo "---------------------------------------------------------------------------">> $FILE_NAME.log

echo "ip_list being to ping : "
for I in $MY_DATA
do
        echo "ping $I"
        `ping $I -c 2 >> ~/scripts/$FILE_NAME.log`
        echo "---------------------------------------------------------------------------">> $FILE_NAME.log
done

echo "$FILE_NAME.log are created"
