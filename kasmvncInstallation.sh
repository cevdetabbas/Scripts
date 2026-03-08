#!/bin/bash

echo "KasmVNC Automated Installer for Arch / Manjaro"
echo

read -p "Enter hostname for VNC (example: vnc.example.com): " HOSTNAME
read -p "Enter server IP address: " SERVER_IP
read -p "Enter VNC username: " VNCUSER
read -s -p "Enter VNC password: " VNCPASS
echo
read -p "Choose Desktop (1=KDE 2=XFCE): " DESKTOP
read -p "Port (default 8445): " PORT

PORT=${PORT:-8445}

echo
echo "Installing dependencies..."

sudo pacman -Sy --needed git base-devel openssl --noconfirm

cd ~

if [ ! -d AUR ]; then
git clone https://github.com/vidalinux/AUR.git
fi

cd ~/AUR/perl-hash-merge-simple
makepkg -si --noconfirm

cd ~/AUR/kasmvncserver-bin
makepkg -si --noconfirm

echo
echo "Creating SSL certificates..."

sudo mkdir -p /opt/ssl/certs
sudo chmod -R 755 /opt/ssl

cd /opt/ssl/certs

sudo openssl genrsa -out server.key 3072

sudo openssl req -new -key server.key -out server.csr <<EOF
US
Texas
SanAntonio
KasmVNC
IT
$HOSTNAME
admin@$HOSTNAME


EOF

sudo openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt

sudo openssl req -x509 -new -nodes -key server.key -sha256 -out ca.pem <<EOF
US
Texas
SanAntonio
KasmVNC
IT
$HOSTNAME
admin@$HOSTNAME


EOF

echo
echo "Creating VNC configuration..."

mkdir -p ~/.vnc

cat > ~/.vnc/kasmvnc.yaml <<EOF
desktop:
  resolution:
    width: 1280
    height: 800
  allow_resize: true
  pixel_depth: 24
  gpu:
    hw3d: false
    drinode: /dev/dri/renderD128

logging:
  log_writer_name: all
  log_dest: logfile
  level: 100

network:
  protocol: https
  interface: 0.0.0.0
  websocket_port: $PORT
  use_ipv4: true
  use_ipv6: false
  ssl:
    pem_certificate: /opt/ssl/certs/server.crt
    pem_key: /opt/ssl/certs/server.key
    require_ssl: true
EOF

echo
echo "Creating xstartup..."

if [ "$DESKTOP" == "1" ]; then
cat > ~/.vnc/xstartup <<EOF
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
startplasma-x11 &
EOF
else
cat > ~/.vnc/xstartup <<EOF
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
dbus-launch startxfce4 &
EOF
fi

chmod +x ~/.vnc/xstartup

echo
echo "Setting VNC password..."

echo "$VNCPASS" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

echo
echo "Creating systemd user service..."

mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/kasmvnc.service <<EOF
[Unit]
Description=KasmVNC Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/vncserver :2
ExecStop=/usr/bin/vncserver -kill :2
Restart=on-failure

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable kasmvnc.service
systemctl --user start kasmvnc.service

echo
echo "Adding hostname entry..."

echo "$SERVER_IP $HOSTNAME" | sudo tee -a /etc/hosts

echo
echo "Cleaning stale locks..."

rm -f /tmp/.X*-lock
rm -f /tmp/.X11-unix/X*

echo
echo "Installation complete."
echo
echo "Access your desktop:"
echo
echo "https://$HOSTNAME:$PORT"
echo
echo "Display used: :2"
echo
echo "To check service:"
echo "systemctl --user status kasmvnc"
echo
