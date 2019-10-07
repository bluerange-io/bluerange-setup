#!/bin/bash

if test ! "$HERE"; then
	HERE=$(cd $(dirname $0) && pwd)
fi

PID_FILE=/var/run/mosquitto.pid

running() {
	test -f $PID_FILE && kill -0 `cat $PID_FILE` 2> /dev/null
}


runwait() {
	local i

	for i in `seq 1 $1`; do
		echo -n .
		if ! running; then
			rm $PID_FILE
			echo " done."
			return 0
		fi

		test $i -eq $1 || sleep 1
	done

	return 1
}


start() {
	if running; then
		echo Mosquitto is already running
		return 0
	fi

	test -z "$NOFILE" || ulimit -n $NOFILE || exit 1

	rm -f $PID_FILE

	test -n "$MAX_OPEN_FILES" && ulimit -n $MAX_OPEN_FILES

	$HERE/mosquitto-foreground.sh &

	PID=$!

	echo $PID > $PID_FILE
}


stop() {
	# return if not running
	if ! running; then
		echo Mosquitto is not running or insufficient privileges
		return 0
	fi

	echo -n stopping

	# read pid
	read pid < $PID_FILE

	# shutdown
	kill $pid

	runwait 10 && return 0

	echo ' killing'

	# kill
	kill -9 $pid

	rm $PID_FILE

	return 0
}


status() {
	if test -f $PID_FILE; then
		if kill -0 `cat $PID_FILE` 2> /dev/null; then
			echo Mosquitto is running
			return 150
		fi
		echo Mosquitto is dead
		return 1
	fi

	echo Mosquitto is not running
	return 3
}


reload() {
	echo reloading is not implemented
	return 3
}

case "$1" in
	'start')
		start
		exit
		;;
	'start-verbose')
		start verbose
		exit
		;;
	'stop')
		stop
		exit
		;;
	'restart')
		stop
		start
		exit
		;;
	'try-restart')
		running || exit 0
		stop
		start
		exit
		;;
	'reload')
		reload
		exit
		;;
	'force-reload')
		stop
		start
		exit
		;;
	'status')
		status
		exit
		;;
	*)
		echo "Usage: $0 {start|start-verbose|stop|restart|reload|force-reload|status}"
		exit 1
		;;
esac

