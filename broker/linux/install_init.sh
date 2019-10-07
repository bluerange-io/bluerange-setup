#!/bin/bash

HERE=$(cd $(dirname $0) && pwd)

if [ "$EUID" -ne 0 ]; then
	echo "Please run as root"
	exit 1
fi

if ! id mosquitto; then
	echo "User mosquitto does not exist. Please create one and specify user mosquitto in /etc/mosquitto/mosquitto.conf to drop privileges."
	exit 1
fi

MOSQUITTO_EXECUTABLE=$(which mosquitto)
if [ -z "${MOSQUITTO_EXECUTABLE}" ]; then
	echo "mosquitto is not on the PATH!"
	exit 1
fi

writeDebianInit() {
cat > /etc/init.d/mosquitto <<EOF
#!/bin/bash
### BEGIN INIT INFO
# Provides:          mosquitto
# Required-Start:    \$local_fs \$remote_fs \$network
# Required-Stop:     \$local_fs \$remote_fs \$network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: mosquitto
# Description:       Start and stop Mosquitto
### END INIT INFO

export MOSQUITTO_EXECUTABLE="$MOSQUITTO_EXECUTABLE"

cd $HERE
exec ./mosquitto.sh \$@
EOF
chmod +x /etc/init.d/mosquitto
}

writeRedhatInit() {
cat > /etc/init.d/mosquitto <<EOF
#!/bin/bash
# chkconfig: 2345 20 80
# description: Start and stop Mosquitto

export MOSQUITTO_EXECUTABLE="$MOSQUITTO_EXECUTABLE"

cd $HERE
exec ./mosquitto.sh \$@
EOF
chmod +x /etc/init.d/mosquitto
}

writeSystemdInit() {
cat > /etc/systemd/system/mosquitto.service <<EOF
[Unit]
Description=Mosquitto Server
After=network.target

[Service]
TimeoutStartSec=0
Environment=MOSQUITTO_EXECUTABLE=$MOSQUITTO_EXECUTABLE
ExecStart=$HERE/mosquitto-foreground.sh
WorkingDirectory=$HERE
KillSignal=SIGINT
Restart=on-failure
SyslogIdentifier=mosquitto
LimitNOFILE=10000
LimitNPROC=10000

[Install]
WantedBy=multi-user.target
EOF
}


if which systemctl; then
	writeSystemdInit $@
	systemctl enable mosquitto
else

	if which lsb_release; then 
		dist=$(lsb_release -i | cut -f 2)
	elif [[ -f /etc/redhat-release ]]; then
		dist=RedHat
	elif [[ -f /etc/centos-release ]]; then
		dist=CentOS
	elif [[ -f /etc/SuSE-release ]]; then
		dist=SuSE
	elif [[ "$OSTYPE" =~ darwin.* ]]; then
		dist=MacOS
	elif [[ -f /etc/system-release && $(cat /etc/system-release) =~ Amazon.* ]]; then
		dist=Amazon
	else
		echo "distribution cannot be determined"
		exit 2
	fi


	case $dist in
	"Ubuntu") 
			writeDebianInit $@
			update-rc.d mosquitto defaults
			;;
	"CentOS" | "Amazon" | "RedHat" | "SuSE" | "OracleServer") 
			writeRedhatInit $@
			chkconfig --add mosquitto
			chkconfig --level 2345 mosquitto on
			;;
	"Debian")
			writeDebianInit $@
			update-rc.d mosquitto defaults
			insserv mosquitto
			;;
	*) 
			echo "Not supported distribution: $dist with init system $initsystem"
	 		exit 2
			;;
	esac
fi



exit 0
