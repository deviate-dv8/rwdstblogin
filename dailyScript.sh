#!/bin/bash
username=$TB_USERNAME
password=$TB_PASSWORD

# Function to fetch user info
fetch_user_info() {
    local username=$1

    while true; do
        response=$(curl -s -X GET "https://forum.toribash.com/tori_ingame_userinfo.php?v=0&username=${username}")
        if [ $? -eq 0 ]; then
            echo "$response"
            break
        else
            echo "Network error. Retrying..."
            sleep 2 # Wait for 2 seconds before retrying
        fi
    done
}

# Function to parse user info and return key-value pairs
parse_user_info() {
    local tbUserInfo="$1"
    declare -A userInfo
    
    # Extract values and store them in the associative array
    userInfo[USERNAME]=$(echo "$tbUserInfo" | grep -oP "USERNAME 0;\K[^;]+")
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
mkdir -p ~/.wine/drive_c/users/$USER/Saved\ Games/Toribash/

echo "Current User:"
whoami

# if [[ $(whoami) == "root" || $(whoami) == "" ]]; then
#     user="wineuser"
# else
user=$(whoami)
# fi
#
# # Ensure $user is not empty
# if [[ -z "$user" ]]; then
#     user="wineuser"
# fi

# Create the directory explicitly to ensure it exists
mkdir -p ~/.wine/drive_c/users/$user/Saved\ Games/Toribash/

# Move Light_Config files
cp ./Light_Config/custom.cfg ~/.wine/drive_c/users/$user/Saved\ Games/Toribash/custom.cfg
cp ./Light_Config/temp.cfg ~/.wine/drive_c/users/$user/Saved\ Games/Toribash/temp.cfg

echo "Generating tb_login.dat..."
{
    echo -n "user $username" | sed 's/./&\x00/g' | tr -d '\n'
    echo -ne "\r\0\n\0"
    echo -n "pass $password" | sed 's/./&\x00/g' | tr -d '\n'
    echo -ne "\r\0\n\0"
} > ~/.wine/drive_c/users/$user/Saved\ Games/Toribash/tb_login.dat

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
        "REWARDS 0; 1 1 0" | "REWARDS 0; 1 2 0")
            echo "claimable"
            ;;
        "REWARDS 0; 0 0 0")
            echo "successfully claimed"
            ;;
        *)
            echo "err"
            ;;
    esac
}

# Function to take screenshot with proper display detection
take_screenshot() {
    local filename="$1"
    local display_num=""
    
    # Try to detect the DISPLAY being used by xvfb
    for display in :0 :1 :2 :10 :99; do
        if DISPLAY=$display xdpyinfo >/dev/null 2>&1; then
            display_num=$display
            break
        fi
    done
    
    if [ -z "$display_num" ]; then
        echo "No X display found"
        return 1
    fi
    
    echo "Using display: $display_num"
    
    # Try multiple screenshot methods
    if DISPLAY=$display_num scrot "$filename" 2>/dev/null; then
        echo "Screenshot taken with scrot: $filename"
        return 0
    elif DISPLAY=$display_num import -window root "$filename" 2>/dev/null; then
        echo "Screenshot taken with ImageMagick: $filename"
        return 0
    else
        echo "Failed to take screenshot"
        return 1
    fi
}

# Check and claim rewards
rewardStatus="$(claimReward $userId)"
echo "Reward Status: $rewardStatus"

if [[ $rewardStatus == "err" ]]; then
    echo "Error checking reward status."
    exit 1
fi

if [[ $rewardStatus == "claimable" ]]; then
    echo "Starting Toribash client..."
    
    # Start xvfb with a known display number
    Xvfb :99 -screen 0 1024x768x24 &
    XVFB_PID=$!
    export DISPLAY=:99
    
    # Wait for X server to start
    sleep 3
    
    # Start a simple window manager to help with window management
    fluxbox &
    FLUXBOX_PID=$!
    
    sleep 2
    
    # Start the Toribash client
    echo "Executing: wine ./Toribash/toribash.exe"
    wine ./Toribash/toribash.exe &
    TB_PID=$!
    
    # Wait for the client to initialize
    echo "Waiting for client to initialize..."
    sleep 10
    
    # Take initial screenshot
    mkdir -p ./screenshots
    take_screenshot "./screenshots/initial_$(date +%Y%m%d%H%M%S).png"
    
    # Monitor reward status
    attempt=0
    max_attempts=30
    
    while [[ $rewardStatus != "successfully claimed" && $rewardStatus != "claimed" && $attempt -lt $max_attempts ]]; do
        echo "Waiting for the client to process the reward... (attempt $((attempt+1))/$max_attempts)"
        sleep 10  # Wait for 10 seconds before checking again
        
        # Take screenshot
        screenshot_file="./screenshots/screenshot_$(date +%Y%m%d%H%M%S).png"
        take_screenshot "$screenshot_file"
        
        rewardStatus="$(claimReward $userId)"
        echo "Current reward status: $rewardStatus"
        
        ((attempt++))
    done
    
    # Take final screenshot
    take_screenshot "./screenshots/final_$(date +%Y%m%d%H%M%S).png"
    
    if [[ $rewardStatus == "successfully claimed" ]]; then
        echo "Reward Claimed Successfully!"
    elif [[ $attempt -ge $max_attempts ]]; then
        echo "Timeout: Maximum attempts reached"
    else 
        echo "Reward processing completed with status: $rewardStatus"
    fi
    
    # Clean up processes
    echo "Cleaning up processes..."
    if [ ! -z "$TB_PID" ]; then
        echo "Killing Toribash process (PID: $TB_PID)"
        kill $TB_PID 2>/dev/null || true
    fi
    
    if [ ! -z "$FLUXBOX_PID" ]; then
        echo "Killing Fluxbox process (PID: $FLUXBOX_PID)"
        kill $FLUXBOX_PID 2>/dev/null || true
    fi
    
    if [ ! -z "$XVFB_PID" ]; then
        echo "Killing Xvfb process (PID: $XVFB_PID)"
        kill $XVFB_PID 2>/dev/null || true
    fi
    
    # List screenshots taken
    echo "Screenshots taken:"
    ls -la ./screenshots/
    
elif [[ $rewardStatus == "claimed" ]]; then
    echo "Reward already claimed."
else
    echo "No reward available."
fi
