#!/bin/bash
# @requires awk, curl, grep, mktemp, sed, tr.

## START EDIT HERE.
old_ip_address=$(cat ./old_ip_address.txt);
api_key=$(cat ./api_key.txt);
device_registration_id=$(cat ./device_registration_id.txt);
do_access_token=$(cat ./do_access_token.txt);
curl_timeout="15";
loop_max_records="50";
url_do_api="https://api.digitalocean.com/v2";
url_ext_ip="http://checkip.dyndns.org";
url_ext_ip2="http://ifconfig.me/ip";
update_only=false;
verbose=true;
filename="$(basename $BASH_SOURCE)";
## END EDIT.

# check for access token
if [ -z "$do_access_token" ] ; then
  echo "No access token provided.";
  exit 1;
fi

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
curl -X POST -H "Authorization: key=$api_key"  -H "Content-Type: application/json" -d '{ "registration_ids": ["'"$device_registration_id"'"], "data": { "message": "'"$1"'" } }'  https://android.googleapis.com/gcm/send
}

# get options.
while getopts "ush" opt; do
  case $opt in
    u)  # update.
      update_only=true;
      ;;
    s)  # silent.
      verbose=false;
      ;;
    h)  # help.
      echo "Usage: $filename [options...] <record name> <domain>";
      echo "Options:";
      echo "  -h      This help text";
      echo "  -u      Updates only. Don't add non-existing";
      echo "  -s      Silent mode. Don't output anything";
      echo "Example:";
      echo "  Add/Update nas.mydomain.com DNS A record with current public IP";
      echo "    ./$filename -s nas mydomain.com";
      echo;
      exit 0;
      ;;
    \?)
      echo "Invalid option: -$OPTARG (See -h for help)" >&2
      exit 1;
      ;;
  esac
done

# validate.
shift $(( OPTIND - 1 ));
do_record="$1";
do_domain="$2";
if [ $# -lt 2 ] || [ -z "$do_record" ] || [ -z "$do_domain" ] ; then
  echo "Missing required arguments. (See -h for help)";
  exit 1;
fi

echov()
{
  if [ $verbose == true ] ; then
    if [ $# == 1 ] ; then
      echo "$1";
    else
      printf "$@";
    fi
  fi
}

# modified from https://gist.github.com/cjus/1047794#comment-1249451
json_value()
{
  local KEY=$1
  local num=$2
  awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/\042'$KEY'\042/){print $(i+1)}}}' | tr -d '"' | sed -n "$num"p
}

get_external_ip()
{
  ip_address=$(dig @ns1.google.com -t txt o-o.myaddr.l.google.com +short | sed s/\"//g)
  if [ -z "$ip_address" ] ; then
    ip_address="$(curl -s --connect-timeout $curl_timeout $url_ext_ip | sed -e 's/.*Current IP Address: //' -e 's/<.*$//' | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')";
    if [ -z "$ip_address" ] ; then
      ip_address="$(curl -s --connect-timeout $curl_timeout $url_ext_ip2 | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')";
      if [ -z "$ip_address" ] ; then
        return 1;
      else
        echov "* Retrieved external IP from $url_ext_ip2";
      fi
    else
      echov "* Retrieved external IP from $url_ext_ip";
      return 0;
    fi
  else
    echov "* Retrieved external IP from Google's nameservers using dig";
    return 0;
  fi
}

# https://developers.digitalocean.com/#list-all-domain-records
get_record()
{
  local tmpfile="$(mktemp)";
  curl -s --connect-timeout "$curl_timeout" -H "Authorization: Bearer $do_access_token" -X GET "$url_do_api/domains/$do_domain/records" > "$tmpfile"
  if [ ! -s "$tmpfile" ] ; then
    return 1;
  fi

  local do_num_records="$(json_value total 1 < $tmpfile)";
  if [[ ! "$do_num_records" =~ ^[0-9]+$ ]] || [ "$do_num_records" -gt "$loop_max_records" ] ; then
    do_num_records=$loop_max_records;
  fi

  for (( i=1; i<="$do_num_records"; i++ ))
  do
    record['name']="$(json_value name $i < $tmpfile)";
    if [ "${record[name]}" == "$do_record" ] ; then
      record['id']="$(json_value id $i < $tmpfile)";
      record['data']="$(json_value data $i < $tmpfile)";

      if [ ! -z "${record[id]}" ] && [[ "${record[id]}" =~ ^[0-9]+$ ]] ; then
        rm -f "$tmpfile";
        return 0;
      fi
      break;
    fi
  done

  rm -f "$tmpfile";
  return 1;
}

# https://developers.digitalocean.com/#update-a-domain-record
set_record_ip()
{
  local id=$1
  local ip=$2

  local data=`curl -s --connect-timeout $curl_timeout -H "Content-Type: application/json" -H "Authorization: Bearer $do_access_token" -X PUT "$url_do_api/domains/$do_domain/records/$id" -d'{"data":"'"$ip"'"}'`;
  if [ -z "$data" ] || [[ "$data" != *"id\":$id"* ]]; then
    return 1;
  else
    return 0;
  fi
}

# https://developers.digitalocean.com/v2/#create-a-new-domain-record
new_record()
{
  local ip=$1

  local data=`curl -s --connect-timeout $curl_timeout -H "Content-Type: application/json" -H "Authorization: Bearer $do_access_token" -X POST "$url_do_api/domains/$do_domain/records" -d'{"name":"'"$do_record"'","data":"'"$ip"'","type":"A"}'`;
  if [ -z "$data" ] || [[ "$data" != *"data\":\"$ip"* ]]; then
    return 1;
  else
    return 0;
  fi
}

# start.
echov "* Updating IP for %s.%s at $(date +"%Y-%m-%d %H:%M:%S")\n" "$do_record" "$do_domain";
echov "* Fetching external IP...";
get_external_ip;
if [ $? -ne 0 ] ; then
  echov "Unable to extract external IP address";
  exit 1;
fi

echov "* External IP is $ip_address";

if [ "$old_ip_address" != "$ip_address" ]; then
  echov "* External IP address has changed..sending to Android through Google Cloud Messaging";
  android_message "$ip_address -  dell-json.jasonbrazeal.com"
fi

# update ip address on file
echo -n $ip_address > ./old_ip_address.txt

echov "* Fetching DO DNS Record ID for: $do_record";
just_added=false;
declare -A record;
get_record;
if [ $? -ne 0 ] ; then
  if [ $update_only == true ] ; then
    echov "Unable to find requested record in DO account";
    exit 1;
  else
    echov "* No record found. Adding: $do_record";
    new_record "$ip_address";
    if [ $? -ne 0 ] ; then
      echov "Unable to add new record";
      exit 1;
    fi
    just_added=true;
  fi
fi

if [ $update_only == true ] || [ $just_added != true ] ; then
  echov "* Comparing DO record (${record[data]}) to current ip ($ip_address)";
  if [ "${record[data]}" == "$ip_address" ] ; then
    echov "Record $do_record.$do_domain already set to $ip_address";
    exit 1;
  fi

  echov "* Updating record ${record[name]}.$do_domain to $ip_address";
  set_record_ip "${record[id]}" "$ip_address";
  if [ $? -ne 0 ] ; then
    echov "Unable to update IP address";
    exit 1;
  fi
fi

echov "* IP Address successfully added/updated.\n\n" "";
android_message "DNS record for dell-json.jasonbrazeal.com updated"
exit 0;