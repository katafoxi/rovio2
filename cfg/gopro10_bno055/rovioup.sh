#!/bin/bash

sudo chmod 666 /dev/i2c-1    # https://answers.ros.org/question/397084/i2c-device-open-failed/
XAUTH=./.docker.xauth
touch $XAUTH
xauth nlist $DISPLAY | sed -e 's/^..../ffff/' | xauth -f $XAUTH nmerge -

docker compose up