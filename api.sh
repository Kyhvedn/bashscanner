#!/usr/bin/env bash

COOKIES=$(mktemp)
POSTFILE=$(mktemp)

function ApiUserRegister {
	local EMAIL, PASSWORD, OUTPUT, AUTHED, ERRORS, USER

	EMAIL=$(Urlencode "$1")
	PASSWORD=$(Urlencode "$2")

	OUTPUT=$(wget -t2 -T6 --keep-session-cookies --save-cookies "$COOKIES" -qO- "${MY_HOME}/api/user/register" --post-data "email=$EMAIL&password=$PASSWORD&password_confirmation=$PASSWORD")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (1)" >&2
		exit 77
	fi

	AUTHED=$(echo "$OUTPUT" | json | grep '^\["authed"\]' | cut -f2-)
	ERRORS=$(echo "$OUTPUT" | json | grep '^\["errors",[0-9]\]' | cut -f2-)
	USER=$(echo "$OUTPUT" | json | grep '^\["user"\]' | cut -f2-)

	echo "${AUTHED:-false}"
	echo "${ERRORS:-false}"
	echo "${USER:-false}"
}

function ApiUserLogin {
	local EMAIL, PASSWORD, OUTPUT, AUTHED, ERRORS, USER, CRITICAL, TYPE

	EMAIL=$(Urlencode "$1")
	PASSWORD=$(Urlencode "$2")

	OUTPUT=$(wget -t2 -T6 --keep-session-cookies --save-cookies "$COOKIES" -qO- "${MY_HOME}/api/user/login" --post-data "email=$EMAIL&password=$PASSWORD")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (2)" >&2
		exit 77
	fi

	AUTHED=$(echo "$OUTPUT" | json | grep '^\["authed"\]' | cut -f2-)
	ERRORS=$(echo "$OUTPUT" | json | grep '^\["errors",[0-9]\]' | cut -f2-)
	USER=$(echo "$OUTPUT" | json | grep '^\["user"\]' | cut -f2-)
	CRITICAL=$(echo "$OUTPUT" | json | grep '^\["critical"\]' | cut -f2-)
	TYPE=$(echo "$OUTPUT" | json | grep '^\["type"\]' | cut -f2-)

	echo "${CRITICAL:-false}"
	echo "${TYPE:-false}"
	echo "${AUTHED:-false}"
	echo "${ERRORS:-false}"
	echo "${USER:-false}"
}

function ApiServerExists {
	local HOST, OUTPUT, ERRORS, ERROR, EXISTS

	HOST=$(Urlencode "$1")

	OUTPUT=$(wget -t2 -T6 -qO- "${MY_HOME}/api/server/exists?host=$HOST")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (3)" >&2
		exit 77
	fi

	ERRORS=$(echo "$OUTPUT" | json | grep '^\["errors"\]' | cut -f2-)
	ERROR=$(echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-  | sed -e 's/^"//'  -e 's/"$//')
	EXISTS=$(echo "$OUTPUT" | json | grep '^\["exists"\]' | cut -f2-)

	echo "${EXISTS:-false}"
	echo "${ERROR:-false}"
	echo "${ERRORS:-false}"
}

function ApiServerCreate {
	local KEY, SECRET, HOSTNAME, OUTPUT, ID, ERROR

	KEY=$(Urlencode "$1")
	SECRET=$(Urlencode "$2")
	HOSTNAME=$(Urlencode "$3")
	
	OUTPUT=$(wget -t2 -T6 -qO- "${MY_HOME}/extern/api/servers?key=$KEY&secret=$SECRET" --post-data "domain=$HOSTNAME")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (4)" >&2
		exit 77
	fi

	ID=$(echo "$OUTPUT" | json | grep '^\["data","id"\]' | cut -f2-)
	ERROR=$(echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-)

	echo "${ERROR:-false}"
	echo "${ID:-false}"
}	

function ApiServerToken {
	local HOSTNAME, OUTPUT, TOKEN, ERROR
	
	HOSTNAME=$(Urlencode "$1")
	
	OUTPUT=$(wget -t2 -T6 -qO- "${MY_HOME}/extern/api/request_verification_token?domain=$HOSTNAME")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (5)" >&2
		exit 77
	fi

	TOKEN=$(echo "$OUTPUT" | json | grep '^\["data","token"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//')
	ERROR=$(echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-)

	echo "${ERROR:-false}"
	echo "${TOKEN:-false}"
}	

function ApiVerifyServer {
	local KEY, SECRET, SERVER_ID, TOKEN, OUTPUT, ERROR

	KEY=$(Urlencode "$1")
	SECRET=$(Urlencode "$2")
	SERVER_ID=$(Urlencode "$3")
	TOKEN=$(Urlencode "$4")
	
	OUTPUT=$(wget -t2 -T6 -qO- "${MY_HOME}/extern/api/servers/${SERVER_ID}/verify?key=$KEY&secret=$SECRET" --post-data "token=$TOKEN")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (6)" >&2
		exit 77
	fi

	ERROR=$(echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-)

	echo "${ERROR:-false}"
}	
	
function ApiServerPush {
	local KEY, SECRET, SERVER_ID, BUCKET, EXPIRE, OUTPUT, ERROR

	KEY=$(Urlencode "$1")
	SECRET=$(Urlencode "$2")
	SERVER_ID=$(Urlencode "$3")
	BUCKET=$(Urlencode "$4")
	EXPIRE="129600"

	echo -n "expire=$EXPIRE&software=" > "$POSTFILE"

	SOFTWARE=$(sort < "$SOFTWARE" | uniq | awk 'BEGIN { RS="\n"; FS="\t"; print "["; prevLocation="---"; prevName="---"; prevVersion="---"; prevParent="---";} 
		{ 
			if($1 == prevLocation){ $1=""; } else { prevLocation = $1; $1 = "\"l\":\""$1"\"," }; 
			if($2 == prevParent){ $2=""; } else { prevParent = $2; $2 = "\"p\":\""$2"\"," }; 
			if($3 == prevName){ $3=""; } else { prevName = $3; $3 = "\"n\":\""$3"\"," }; 
			if($4 == prevVersion){ $4=""; } else { prevVersion = $4; $4 = "\"v\":\""$4"\"," }; 
			line = $1$2$3$4; 
			print "{"line"},"; 
		} 
		END { print "{}]"; }' | sed 's/,},/},/' | tr -d '\n')
	SOFTWARE=$(Urlencode "$SOFTWARE")

	echo "$SOFTWARE" >> "$POSTFILE"


	OUTPUT=$(wget -t2 -T6 -qO- "${MY_HOME}/extern/api/servers/${SERVER_ID}/software_bucket/$BUCKET?key=$KEY&secret=$SECRET&scope=silent" --post-file $POSTFILE)

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (7)" >&2
		exit 77
	fi

	ERROR=$(echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-)

	echo "${ERROR:-false}"
}

function ApiKeySecret {
	local OUTPUT, KEY, SECRET

	OUTPUT=$(wget -t2 -T6 --load-cookies "$COOKIES" -qO- "${MY_HOME}/api/user/api_credentials")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (8)" >&2
		exit 77
	fi

	KEY=$(echo "$OUTPUT" | json | grep '^\[0,"key"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//')
	SECRET=$(echo "$OUTPUT" | json | grep '^\[0,"secret"\]' | cut -f2- | sed -e 's/^"//'  -e 's/"$//')

	echo "${KEY:-false}"
	echo "${SECRET:-false}"
}

function ApiCreateKeySecret {
	local OUTPUT

	OUTPUT=$(wget -t2 -T6 --load-cookies "$COOKIES" -qO- "${MY_HOME}/api/user/api_credentials" --post-data "not=used")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (9)" >&2
		exit 77
	fi
}

function ApiServers {
	local KEY, SECRET, OUTPUT, SERVERS, ERROR

	KEY=$(Urlencode "$1")
	SECRET=$(Urlencode "$2")

	OUTPUT=$(wget -t2 -T6 -qO- "${MY_HOME}/extern/api/servers?key=$KEY&secret=$SECRET")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (10)" >&2
		exit 77
	fi

	SERVERS=$(echo "$OUTPUT" | json | grep '^\["data"\]' | cut -f2-)
	ERROR=$(echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-)

	echo "${ERROR:-false}"
	echo "${SERVERS:-false}"
}

function ApiSoftware {
	local KEY, SECRET, SERVER_ID, OUTPUT, SOFTWARE, ERROR

	KEY=$(Urlencode "$1")
	SECRET=$(Urlencode "$2")
	SERVER_ID=$(Urlencode "$3")

	OUTPUT=$(wget -t2 -T6 -qO- "${MY_HOME}/extern/api/servers/$SERVER_ID/software?key=$KEY&secret=$SECRET&scope=exploits")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (11)" >&2
		exit 77
	fi

	SOFTWARE=$(echo "$OUTPUT" | json | grep '^\["data"\]' | cut -f2-)
	ERROR=$(echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-)

	echo "${ERROR:-false}"
	echo "${SOFTWARE:-false}"
}

function ApiServerScan {
	local KEY, SECRET, SERVER_ID, OUTPUT, ERROR

	KEY=$(Urlencode "$1")
	SECRET=$(Urlencode "$2")
	SERVER_ID=$(Urlencode "$3")

	OUTPUT=$(wget -t2 -T6 -qO- "${MY_HOME}/extern/api/servers/$SERVER_ID/scan?key=$KEY&secret=$SECRET"  --post-data "not=used")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (12)" >&2
		exit 77
	fi

	ERROR=$(echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-)

	echo "${ERROR:-false}"
}

function ApiServerIsScanning {
	local KEY, SECRET, SERVER_ID, OUTPUT, ERROR, SCANNING

	KEY=$(Urlencode "$1")
	SECRET=$(Urlencode "$2")
	SERVER_ID=$(Urlencode "$3")

	OUTPUT=$(wget -t2 -T6 -qO- "${MY_HOME}/extern/api/servers/$SERVER_ID/isScanning?key=$KEY&secret=$SECRET")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (13)" >&2
		exit 77
	fi

	ERROR=$(echo "$OUTPUT" | json | grep '^\["error"\]' | cut -f2-)
	SCANNING=$(echo "$OUTPUT" | json | grep '^\["data"\]' | cut -f2-)

	echo "${ERROR:-false}"
	echo "${SCANNING:-false}"
}

function ApiUserChange {
	local KEY, SECRET, EMAIL, OUTPUT, ERRORS, SUCCESS

	KEY=$(Urlencode "$1")
	SECRET=$(Urlencode "$2")
	EMAIL=$(Urlencode "$3")

	OUTPUT=$(wget -t2 -T6 -qO- "${MY_HOME}/extern/api/user/update?key=$KEY&secret=$SECRET" --post-data "email=$EMAIL")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (14)" >&2
		exit 77
	fi

	ERRORS=$(echo "$OUTPUT" | json | grep '^\["errors"\]' | cut -f2-)
	SUCCESS=$(echo "$OUTPUT" | json | grep '^\["success"\]' | cut -f2-)

	echo "${ERRORS:-false}"
	echo "${SUCCESS:-false}"
}

function ApiUserRemove {
	local KEY, SECRET, OUTPUT

	KEY=$(Urlencode "$1")
	SECRET=$(Urlencode "$2")

	OUTPUT=$(wget -t2 -T6 -qO- "${MY_HOME}/extern/api/user/delete?key=$KEY&secret=$SECRET" --post-data "not=used")

	if [ "$OUTPUT" == "" ]
	then
		echo "> patrolserver.com is not reachable, contact us (15)" >&2
		exit 77
	fi

	#ERRORS=$(echo "$OUTPUT" | json | grep '^\["errors"\]' | cut -f2-)
	#SUCCESS=$(echo "$OUTPUT" | json | grep '^\["success"\]' | cut -f2-)

	#echo "${ERRORS:-false}"
	#echo "${SUCCESS:-false}"
}

function Urlencode {
	local STRING, STRLEN, ENCODED

	STRING="${1}"
	STRLEN=${#STRING}
	ENCODED=""

	for (( pos=0 ; pos<STRLEN ; pos++ )); do
		c=${STRING:$pos:1}
		case "$c" in
			[-_.~a-zA-Z0-9] ) o="${c}" ;;
			* )               printf -v o '%%%02x' "'$c"
		esac
		ENCODED+="${o}"
	done

	echo "${ENCODED:-false}"
}

function Jsonspecialchars {
	echo "$1" | sed "s/'/\\\\\'/g"
}