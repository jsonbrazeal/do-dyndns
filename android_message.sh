#!/bin/bash

api_key=$(cat $HOME/do_dyndns/api_key.txt);
device_registration_id=$(cat $HOME/do_dyndns/device_registration_id.txt);
# check for api key
if [ -z "$api_key" ] ; then
  echo "No api key provided.";
  exit 1;
fi

# check for device registration id
if [ -z "$device_registration_id" ] ; then
  echo "No device registration id provided.";
  exit 1;
fi

android_message()
{
curl -X POST -H "Authorization: key=$api_key"  -H "Content-Type: application/json" -d '{ "registration_ids    ": ["'"$device_registration_id"'"], "data": { "message": "'"$1"'" } }'  https://android.googleapis.com/gcm    /send
 }

 android_message "$1";
 exit 0;