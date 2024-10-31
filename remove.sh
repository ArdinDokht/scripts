#!/bin/bash

today=$(date +%Y-%m-%d)
cut -d ':' -f 1,3 /etc/passwd > "$today.date"

VAR1=$(find . -name "*.date")


past_2days=$(date -d "2 days ago" +%Y-%m-%d)


for i in $VAR1
do
        file_date=$(basename "$i" .date | cut -d '-' -f 1-3)


        if [[ "$file_date" < "$past_2days" ]];then
                echo "removing file"
                rm "$i"

        fi

done
