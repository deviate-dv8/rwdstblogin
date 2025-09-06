#!/bin/bash
username=$TB_USERNAME
password=$TB_PASSWORD

# Function to set or disable Wine proxy settings
set_wine_proxy() {
    local proxy=$1
    if [[ -n "$proxy" ]]; then
        echo "Setting Wine proxy to: $proxy"
        wine reg add "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" /v ProxyEnable /t REG_DWORD /d 1 /f
        wine reg add "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" /v ProxyServer /t REG_SZ /d "$proxy" /f
    else
        echo "No proxy detected. Disabling Wine proxy."
        wine reg add "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f
    fi
}

# Check if HTTP_PROXY or HTTPS_PROXY is set
if [[ -n "$HTTP_PROXY" ]]; then
    set_wine_proxy "$HTTP_PROXY"
elif [[ -n "$HTTPS_PROXY" ]]; then
    set_wine_proxy "$HTTPS_PROXY"
else
    set_wine_proxy ""  # Disable proxy if none is set
fi
# Verify external IP
echo "Verifying external IP..."
curl ifconfig.io

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

user=$(whoami)

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

if [[ $rewardStatus == "claimable" ]]; then
    echo "Starting Toribash client..."
    
    # Start xvfb with a known display number
    Xvfb :99 -screen 0 1024x768x24 &
    XVFB_PID=$!
    export DISPLAY=:99
    
    # Wait for X server to start
    sleep 3
    
    # Start a simple window manager
    fluxbox &
    FLUXBOX_PID=$!
    
    sleep 2
    
    # Start the Toribash client
    wine ./Toribash/toribash.exe &
    TB_PID=$!
    
    # Wait for the client to initialize
    sleep 10
    
    # Take initial screenshot
    mkdir -p ./screenshots
    take_screenshot "./screenshots/initial_$(date +%Y%m%d%H%M%S).png"
    
    # Monitor reward status
    attempt=0
    max_attempts=30
    
    while [[ $rewardStatus != "successfully claimed" && $rewardStatus != "claimed" && $attempt -lt $max_attempts ]]; do
        sleep 10  # Wait for 10 seconds before checking again
        
        # Take screenshot
        screenshot_file="./screenshots/screenshot_$(date +%Y%m%d%H%M%S).png"
        take_screenshot "$screenshot_file"
        
        rewardStatus="$(claimReward $userId)"
        ((attempt++))
    done
    
    # Take final screenshot
    take_screenshot "./screenshots/final_$(date +%Y%m%d%H%M%S).png"
    
    # Final reward status check
    if [[ $rewardStatus == "successfully claimed" ]]; then
        summary="Reward successfully claimed."
    elif [[ $attempt -ge $max_attempts ]]; then
        summary="Reward claim timed out after $max_attempts attempts."
    else 
        summary="Reward processing completed with status: $rewardStatus."
    fi
    
    # Clean up processes
    if [ ! -z "$TB_PID" ]; then
        kill $TB_PID 2>/dev/null || true
    fi
    
    if [ ! -z "$FLUXBOX_PID" ]; then
        kill $FLUXBOX_PID 2>/dev/null || true
    fi
    
    if [ ! -z "$XVFB_PID" ]; then
        kill $XVFB_PID 2>/dev/null || true
    fi
    
    # List screenshots taken
    ls -la ./screenshots/
    
elif [[ $rewardStatus == "claimed" ]]; then
    summary="Reward already claimed."
else
    summary="No reward available."
fi

# Final summary
echo "$summary"
