#!/bin/bash

# starts Mosquitto as a foreground process
# this can be used for systems like docker, systemd or mesos

exec ${MOSQUITTO_EXECUTABLE:-mosquitto} -c /etc/mosquitto/mosquitto.conf
