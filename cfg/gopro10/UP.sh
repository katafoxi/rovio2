#!/bin/bash

# Сreating a .xauth file to add to the docker container
# https://www.baeldung.com/linux/docker-container-gui-applications#4-handling-problems-with-the-xauthority-file-different-user-id
# touch "$XAUTH"
# xauth nlist "$DISPLAY" | sed -e 's/^..../ffff/' | xauth -f "$XAUTH" nmerge -

# https://hub.docker.com/r/henry2423/ros-x11-ubuntu
XSOCK=/tmp/.X11-unix
XAUTH=/tmp/.docker.xauth
touch $XAUTH
xauth nlist $DISPLAY | sed -e 's/^..../ffff/' | xauth -f $XAUTH nmerge -

# docker compose up