#!/bin/bash
set -e

cleanup () {
    kill -s SIGTERM $!
    echo "Caught SIGINT/SIGTERM, exiting gracefully..."
    exit 0
}
trap cleanup SIGINT SIGTERM

VNC_IP=$(hostname -i)

# Change vnc password
mkdir -p "$HOME/.vnc"
PASSWD_PATH="$HOME/.vnc/passwd"

if [[ -f $PASSWD_PATH ]]; then
    rm -f "$PASSWD_PATH"
fi

echo "$VNC_PW" | vncpasswd -f >> "$PASSWD_PATH"
chmod 600 "$PASSWD_PATH"

# Remove old vnc locks
vncserver -kill "$DISPLAY" &> "$START_DIR"/vnc_startup.log || rm -rf /tmp/.X*-lock /tmp/.X11-unix &> "$START_DIR"/vnc_startup.log

echo -e "\nDISPLAY = $DISPLAY\nVNC_COL_DEPTH = $VNC_COL_DEPTH\nVNC_RESOLUTION = $VNC_RESOLUTION\nVNC_IP = $VNC_IP\nVNC_PORT = $VNC_PORT"
vncserver "$DISPLAY" -depth "$VNC_COL_DEPTH" -geometry "$VNC_RESOLUTION" &> "$START_DIR"/vnc_startup.log

echo -e "\nConnect to $VNC_IP:$VNC_PORT"

# Start xfce4
"$START_DIR"/xfce.sh &> "$START_DIR"/xfce.log

# Cleanup to ensure pulseaudio is stateless
rm -rf /var/run/pulse /var/lib/pulse /home/zoomrec/.config/pulse

# Start audio
pulseaudio -D --exit-idle-time=-1 --log-level=error

# Create speaker Dummy-Output
pactl load-module module-null-sink sink_name=speaker sink_properties=device.description="speaker" > /dev/null
pactl set-source-volume 1 100%

# Create microphone Dummy-Output
pactl load-module module-null-sink sink_name=microphone sink_properties=device.description="microphone" > /dev/null
pactl set-source-volume 2 100%

# Map microphone-Output to microphone-Input
pactl load-module module-loopback latency_msec=1 source=2 sink=microphone > /dev/null
pactl load-module module-remap-source master=microphone.monitor source_name=microphone source_properties=device.description="microphone" > /dev/null
# Set microphone Volume
pactl set-source-volume 3 60%

echo -e "\nStart script.."

export SESSION_MANAGER=$(cat ~/.ICEauthority | perl -pe 's/.*(local.*?unix\/\d*).*/$1/'),$(cat ~/.ICEauthority | perl -pe 's/.*(local.*?unix\/\d*).*/$1/; s/local/unix/')

# Start python script in separated terminal
if [[ "$DEBUG" == "True" ]]; then
  # Wait if something failed
  echo "Starting Python script in debug mode (waits on error)"
  echo "HOME: ${HOME}"
  stat /home/zoomrec
  stat /home/zoomrec/zoomrec.py
  # ⚠ This means that output from the script is not visible from here!
  # xfce4-terminal -H --geometry 85x7+0 --title=zoomrec --hide-toolbar --hide-menubar --hide-scrollbar --hide-borders --zoom=-3 -e "python3 -u ${HOME}/zoomrec.py"
  python3 -u /home/zoomrec/zoomrec.py
else
  # Exit container if something failed
  echo "Starting Python script in normal mode (exits on error)"
  # ⚠ This means that output from the script is not visible from here!
  # xfce4-terminal --geometry 85x7+0 --title=zoomrec --hide-toolbar --hide-menubar --hide-scrollbar --hide-borders --zoom=-3 -e "python3 -u ${HOME}/zoomrec.py"
  python3 -u /home/zoomrec/zoomrec.py
fi

echo "Script exited"
