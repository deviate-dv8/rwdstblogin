#!/bin/bash

username=$TB_USERNAME
password=$TB_PASSWORD

# Function to fetch user info
fetch_user_info() {
    local username=$1
    curl -s -X GET "https://forum.toribash.com/tori_ingame_userinfo.php?v=0&username=${username}"
}

# Function to parse user info and return key-value pairs
parse_user_info() {
    local tbUserInfo="$1"
    declare -A userInfo

    # Extract values and store them in the associative array
    userInfo[USERID]=$(echo "$tbUserInfo" | grep -oP "USERID 0;\K[0-9]+")
    userInfo[TC]=$(echo "$tbUserInfo" | grep -oP "TC 0;\K[0-9]+")
    userInfo[ST]=$(echo "$tbUserInfo" | grep -oP "ST 0;\K[0-9]+")

    # Output the associative array as key-value pairs
    for key in "${!userInfo[@]}"; do
        echo "$key=${userInfo[$key]}"
    done
}

# Fetch and parse user info
rawUserInfo=$(fetch_user_info "$username")
if [ -z "$rawUserInfo" ]; then
    echo "Failed to fetch user info"
    exit 1
fi

parsedUserInfo=$(parse_user_info "$rawUserInfo")
userId=$(echo "$parsedUserInfo" | grep -oP "USERID=\K[0-9]+")
# Check if parsing succeeded
if [ -z "$parsedUserInfo" ]; then
    echo "Failed to parse user info"
    exit 1
fi

# gen tb_login.dat
echo "Generating tb_login.dat..."
{
    echo -n "user $username" | sed 's/./&\x00/g' | tr -d '\n'
    echo -ne "\r\0\n\0"
    echo -n "pass $password" | sed 's/./&\x00/g' | tr -d '\n'
    echo -ne "\r\0\n\0"
} > ./Light_Config/tb_login.dat

# move Light_Config to /.wine/drive_c/users/$USER/Saved\ Games	/Toribash/
mkdir -p ~/.wine/drive_c/users/$USER/Saved\ Games/Toribash/
cp ./Light_Config/tb_login.dat ~/.wine/drive_c/users/$USER/Saved\ Games/Toribash/tb_login.dat
cp ./Light_Config/custom.cfg ~/.wine/drive_c/users/$USER/Saved\ Games/Toribash/custom.cfg
cp ./Light_Config/temp.cfg ~/.wine/drive_c/users/$USER/Saved\ Games/Toribash/temp.cfg

echo "Parsed User Info:"
echo "$parsedUserInfo"

function claimReward() {
    local userId=$1
    local response

    # Fetch the reward status
    response=$(curl -s -X GET "https://forum.toribash.com/tori_ingame_login_reward.php?v=0&userid=${userId}&claim=1")

    # Parse and handle the response
    case "$response" in
        "REWARDS 0; 1 0 0")
            echo "claimed"
            ;;
        "REWARDS 0; 1 1 0")
            echo "claimable"
            ;;
        *)
            echo "successfully claimed"
            ;;
    esac
}

# Check and claim rewards
rewardStatus="$(claimReward $userId)"

if [[ $rewardStatus == "claimable" ]]; then
	TBClientProcess="xvfb-run -a wine ./Toribash/toribash.exe"
	echo "Executing: $TBClientProcess"

	# Start the process in the background and capture its PID
	$TBClientProcess &
	TB_PID=$!
	while [[ $rewardStatus == "claimable" ]]; do  # Fixed spacing here
		echo "Waiting for the client to process the reward..."
		sleep 10  # Wait for 10 seconds before checking again
		rewardStatus="$(claimReward $userId)"
		echo "$rewardStatus"
	done
	echo "Reward Claimed"
	# Kill the process after the loop
	echo "Killing the Toribash process with PID: $TB_PID"
	kill $TB_PID
else
	echo "Reward claimed or already claimed."
fi

