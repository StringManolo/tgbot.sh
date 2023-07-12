#!/usr/bin/env bash

# Load a file into a variable
loadFile() {
  local -n _result=$2;
  _result=$(cat "$1");
}

# Encode quotes and other characters that can break the response embeeded into the url
encodeURIComponent() {
  local string="${1}";
  local strlen=${#string};
  local encoded="";
  local pos c o;

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in                                                                                            [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}";
  done
  globEncoded=$(echo "${encoded}");
}

# Load new Telegram messages into a variable
getUpdates() {
  local -n _result=$2;
  local command='curl '"'"'https://api.telegram.org/bot';
  command+=$1; # $TOKEN
  command+='/getUpdates'"'"' --silent';
  _result=$(eval $command);
}

# Delete all Telegram messages from the API (because messages already processed)
deleteMessages() {
  local -n _result=$2;
  local command='curl '"'"'https://api.telegram.org/bot';
  command+=$1; # $TOKEN
  command+='/getUpdates?offset=';
  command+=$(($lastId));

  command+=''"'"' --silent';
  _result=$(eval $command);
}

# Answer to the user
sendResponse() {
  local -n _result=$3;
  local response=$1;
  local chatId=$2;
  # If the response to send is bigger than the max allowed size of a Telegram Message
  if [[ ${#response} -gt 4000 ]]; then
    local command='curl '"'"'https://api.telegram.org/bot';
    command+=$TOKEN;
    command+='/sendMessage?chat_id=';
    command+=$chatId;
    command+='&text=';
    command+='ResponseIsChunked:';
    command+=''"'"' --silent';
    # Send the message "ResponseIsChunked:" to indicate that the response will be chunked into multiple messages
    _result=$(eval $command);
    # Send the big respomse in chuncks of 4000 characters
    for ((i=0; i<${#response}; i+=4000)) do
       local command2='curl '"'"'https://api.telegram.org/bot';
       command2+=$TOKEN;
       command2+='/sendMessage?chat_id=';
       command2+=$chatId;
       command2+='&text=';
       globEncoded="";
       encodeURIComponent "${response:$i:4000}";
       command2+="$globEncoded";
       command2+=''"'"' --silent';
       _result=$(eval $command2);
    done
  else
    local command='curl '"'"'https://api.telegram.org/bot';
    command+=$TOKEN;
    command+='/sendMessage?chat_id=';
    command+=$chatId;
    command+='&text=';
    globEncoded="";
    encodeURIComponent "$response"; # uses globEncoded
    command+="$globEncoded";
    command+=''"'"' --silent';
    _result=$(eval $command);
  fi
}

# Check if the @username is logged in (used the /login validPassword)
isLoggedInUser() {
  local -n _result=$2;
  local username=$1;
  for ((i=0; i < ${#loggedInUsers}; i++)) do
    if [[ $username = ${loggedInUsers[$i]} ]]; then
      _result="true";
      return;
    fi
  done
  _result="false";
}

# This function checks if any command is detected and defines what to do when the command is detected
processData() {
  local -n _result=$4;
  local text=$1;
  local username=$2;
  local chatId=$3;

  printf '%s send me %s using chat n°%s\n' "$username" "$text" "$chatId";

  local aux='/login ';
  aux+="$PASSWORD";

  if [[ "$text" = "\"$aux\"" ]]; then
    loggedInUsers+=($username);
    local aux2="$username";
    aux2+=' is logged in';
    sendResponse "$aux2" "$chatId" dummy;
  fi

  # This hello or /start its here as an example on how to implement your commands
  if [[ ${text:1:5} = 'hello' || ${text:1:6} = '/start' ]]; then
    echo "/start or hello found!";
    local aux3='Hey ';
    aux3+=$username;
    aux3+=', how are you?';

    sendResponse "$aux3" "$chatId" dummy
  fi

  local boolIsLogged;
  isLoggedInUser "$username" boolIsLogged;
  if [[ $boolIsLogged = 'true' ]]; then
    if [[ ${text:1:4} = '/run' ]]; then
      commandLength=${#text};
      commandLength=$(($commandLength - 7));
      output="$(eval ${text:6:$commandLength})";
      if [[ -z $output ]]; then
        sendResponse 'Void output from stdout' "$chatId" dummy
      else
        sendResponse "$output" "$chatId" dummy
      fi
    fi
  fi
}



loadFile token.txt TOKEN;        # load token.txt into $TOKEN
loadFile password.txt PASSWORD;  # load password.txt into $PASSWORD

# manual clean API example:
# lastId=890167895;
# deleteMessages "$TOKEN" dummy;

loggedInUsers=();
lastId=0;

if [[ -z $TOKEN ]]; then
  echo 'Unable to find token.txt file';
  exit;
fi

if [[ -z $PASSWORD ]]; then
  echo "Unable to find password.txt file";
  exit;
fi

# Bot logic (Main loop)
while [ true ]; do
  getUpdates $TOKEN updates;
  if [[ -z $updates ]]; then
    echo 'Unable to retrieve updates';
    exit;
  fi

  # echo "Updates: $updates"; # debug json

  if [[ ! $(echo $updates | jq .ok) = true ]]; then
    echo 'Telegram API is returning an error';
    exit;
  fi

  messages=$(echo $updates | jq .result);
  if [[ -z $messages ]]; then
    echo 'No messages to parse';
    exit;
  fi

  # echo "Messages: $messages"; # debug messages json
  numberOfMessages=$(echo $messages | jq '. | length');
  for ((m=1; m<$numberOfMessages; m++)) do
    text='NULL'
    text=$(echo $messages | jq .[$m].message.text);
    username='NULL';
    username=$(echo $messages | jq .[$m].message.from.username);
    chatId=0;
    chatId=$(echo $messages | jq .[$m].message.chat.id);
    lastId=$(echo $messages | jq .[$m].update_id);
    if [[ $text != 'NULL' && $username != 'NULL' && $chatId -ne 0 ]]; then
      processData "$text" "$username" "$chatId" dummy;
    fi
  done

  deleteMessages "$TOKEN" dummy;
  sleep 7s;

done
