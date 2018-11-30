#! /bin/bash

#TODO: use jq for json parsing?

function req {

	RET=$(request -X "$@" -H "Authorization: Bearer $TOKEN" );

	# if token is expired -> refresh the access token
	#RET='{ "error": { "status": 401, "message": "The access token expired" } }';
	if [[ "$RET" =~ (The access token expired) ]]; then
		refresh_token;
		#query again with refresehed token
		RET=$(request -X "$@");
	fi
	echo "$RET";
}

function request {
	curl -s "$@";
}


function get_accesscode {

	local SCOPES="user-read-private%20user-modify-playback-state%20user-read-playback-state%20user-read-currently-playing%20playlist-read-private%20playlist-read-collaborative";
	echo "open in your browser":
	echo "https://accounts.spotify.com/authorize?client_id=${CLIENTID}&response_type=code&redirect_uri=${REDIRECTURL}&scope=$SCOPES&state=optionalrandomstuff";

}

function token_for_code {

	if [[ "$1" =~ code=[a-zA-Z0-9_\-]* ]]; then
		CODE=${BASH_REMATCH[0]:5}
	else
		echo "no access granted or wrong url?";
		exit;
	fi

	RES=$(request -H "Authorization: Basic ${B64}" -d grant_type=authorization_code -d code=$CODE -d redirect_uri=$REDIRECTURL https://accounts.spotify.com/api/token);

	#echo $RES;

	ERR=0;
	if [[ "$RES" =~ \"access_token\":\"[a-zA-Z0-9_\-]* ]]; then
		TOKEN=${BASH_REMATCH[0]:16};
		echo "$TOKEN";
	else
		ERR=1;
	fi

	if [[ "$RES" =~ \"refresh_token\":\"[a-zA-Z0-9_\-]* ]]; then
		local RFT=${BASH_REMATCH[0]:17};
		echo "$RFT";
	else
		ERR=1;
	fi


	if [ "$ERR" = 0 ]; then
		save_auth "$TOKEN" "$RFT";
	else
		echo "Error:";
		echo "$RES";
	fi

}


function refresh_token {

	RES=$(request -H "Authorization: Basic $B64" -d grant_type=refresh_token -d refresh_token=$REFRESH_TOKEN https://accounts.spotify.com/api/token);

	echo "$RES";
	if [[ "$RES" =~ \"access_token\":\"[a-zA-Z0-9_\-]* ]]; then
		TOKEN="${BASH_REMATCH[0]:16}";
		#echo $TOKEN;
		save_auth "$TOKEN" "$REFRESH_TOKEN";

	else
		echo "Error:";
		echo "$RES";
		exit;
	fi

}


function save_auth {

	#TODO:  less save calls/ no rewrite of the first lines
	echo "CLIENTID=\"$CLIENTID\"" > .spotifyconfig;
	echo "SECRET=\"$SECRET\"" >> .spotifyconfig;
	echo "REDIRECTURL=\"$REDIRECTURL\"" >> .spotifyconfig;

	echo "TOKEN=\"$1\"" >> .spotifyconfig;
	echo "REFRESH_TOKEN=\"$2\"" >> .spotifyconfig;
	echo "" >> .spotifyconfig;
	echo "auth saved";

}


function list_devices {
	RES=$(req GET https://api.spotify.com/v1/me/player/devices -d "");
	echo "$RES";
}

function activate_device {
	ID="$1";

	RES=$(req PUT "https://api.spotify.com/v1/me/player" -H "Content-Type: application/json" -d "{\"device_ids\":[\"${ID}\"]}" -d play=true );
	echo "$RES";

}

function volume {
	PERCENT="$1";
	RES=$(req PUT "https://api.spotify.com/v1/me/player/volume?volume_percent=$PERCENT" -d "");
	echo "$RES";

}

function play {

	if [ "$1" = "" ]; then
		#play current song
		RES=$(req PUT "https://api.spotify.com/v1/me/player/play" -d "");
	else
		#play a track
		RES=$(req PUT "https://api.spotify.com/v1/me/player/play" -H "Accept: application/json" -H "Content-Type: application/json" -d "{\"uris\": [\"$1\"]}" );

	fi
	echo "$RES";


}

function play_list {
	#play an allbum/playlist whatever is given 
	RES=$(req PUT "https://api.spotify.com/v1/me/player/play" -H "Accept: application/json" -H "Content-Type: application/json" -d "{\"context_uri\": \"$1\"}" );
	echo "$RES";
}

function pause {
	RES=$(req PUT "https://api.spotify.com/v1/me/player/pause" -d "" )
	echo "$RES";
}

function previous {
	RES=$(req POST "https://api.spotify.com/v1/me/player/previous" -d "");
	echo "$RES";

}

function next {
	RES=$(req POST "https://api.spotify.com/v1/me/player/next" -d "");
	echo "$RES";
}



function my_playlists {
	RES=$(req GET "https://api.spotify.com/v1/me/playlists");
	if [[ "$RES" =~ \"href\"\ :\ \"[^\"]* ]]; then
		URL=${BASH_REMATCH[0]:10}
		echo "URL: $URL";

		#get first entries
		local RET=$(req GET "$URL");

		#local NAME=();
		#local ID=();

		# get more playlist entries
		while [ "$URL" != "null" ]; do
			if [[ "$RET" =~ \"next\"\ :\ (\"[^\"]*|null) ]]; then
				URL=${BASH_REMATCH[0]:10}
				local RET=$(req GET "$URL");
				echo "$RET";

				# TODO: filter uri and name

			else
				URL="null";		#break
			fi
		done;

	fi
#	echo "$RES";
}

function load_credentials {
	# auth data exists?
	if [ ! -e .spotifyconfig ]; then
		echo "insert CLIENTID and CLIENTSECRET from your spotify developer account into .spotifyconfig";
		# TODO: ui for inserting
		save_auth;
		exit 0;
	fi

	#load credentials
	. .spotifyconfig
	if [ "$CLIENTID" = "" ]; then
		echo "insert ClientId and ClientSecret into the config file \".spotifyconfig\" .";
		exit;
	fi

	B64=$( echo -n "$CLIENTID:$SECRET" | openssl base64 -A);

	if [ "$TOKEN" = "" ]; then
		get_accesscode;
		echo "copy redirected url from browser";
		read FORWARDEDURL;
		token_for_code "$FORWARDEDURL";
	fi

}


function logout {
	save_auth "" "";
	exit;
}
