#!/bin/bash
nohup nginx &
nohup python3 /var/www/html/a.py &
su - www-data -c "nohup /var/www/html/main &"
while true; do sleep 1000; done