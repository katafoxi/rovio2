# ------------------CHOSEE type architecture-----------------------------------
FROM ros:noetic-ros-base
#FROM arm64v8/ros:noetic-ros-base

SHELL ["/bin/bash", "-c"]
ARG WS=/opt/ros/overlay_ws
ARG cfg_kit=gscam_bno055_rp2040
ARG opengl_scene=true

WORKDIR $WS/src
WORKDIR $WS/

RUN <<EOT bash
      apt-get update && apt-get install -y \
      git \
      pip \
      wget \
      freeglut3-dev \
      libglew-dev \
      libyaml-cpp-dev \
      python3-psutil \
      python3-rosdep \
      ros-$ROS_DISTRO-rviz \
      ros-$ROS_DISTRO-image-transport \
      ros-$ROS_DISTRO-image-transport-plugins 
      sudo pip3 install -U catkin_tools
      rosdep init
      catkin init
      git clone https://github.com/ANYbotics/kindr.git ./src/kindr
      git clone --recurse-submodules https://github.com/katafoxi/rovio2.git ./src/rovio
      git clone https://github.com/CopterExpress/clover/tree/master/clover ./src/clover
      git clone https://github.com/katafoxi/bno055_serial_to_ros.git ./src/bno055_serial_to_ros
      rosdep install --from-paths src --ignore-src -r -y
      echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> ~/.bashrc
      source ~/.bashrc

EOT

#------------------------------------------------------------------------------
# It is necessary to select the appropriate Rovio build option
RUN <<EOT bash
  source ~/.bashrc
  source /opt/ros/${ROS_DISTRO}/setup.bash
  catkin config --extend /opt/ros/${ROS_DISTRO}
  source ${WS}/devel/setup.bash

  # build ROVIO with or without OpenGL scene
  if ${opengl_scene}; then
    catkin build rovio \
    -j1 --mem-limit 70% \
    --cmake-args -DCMAKE_BUILD_TYPE=Release -DROVIO_NCAM=1 -DMAKE_SCENE=ON
  else
    catkin build rovio \
    -j1 --mem-limit 70% \
    --cmake-args -DCMAKE_BUILD_TYPE=Release -DROVIO_NCAM=1
  fi

EOT

#------------------------------------------------------------------------------
# install and build clover pkg
# https://github.com/CopterExpress/clover/tree/master/clover
#RUN <<EOT bash

  # rosdep install -y --from-paths src --ignore-src
  #catkin build clover -j1 --mem-limit 70%

#EOT

#------------------------------------------------------------------------------
#install and build bno055_serial_to_ros module
RUN <<EOT bash
  sudo apt-get install ros-noetic-serial
  sudo apt-get install ros-noetic-rviz-imu-plugin

  source ${WS}/devel/setup.bash
  
  rosdep install -y --from-paths src --ignore-src
  catkin build bno055_serial_to_imu -j1 --mem-limit 70% \
  --cmake-args -DCMAKE_BUILD_TYPE=Release 

EOT

#------------------------------------------------------------------------------
# add support redirect X11 
# Arguments picked from the command line!
ARG user
ARG uid
ARG gid

#Add new user with our credentials
ENV USERNAME=${user}
RUN useradd -m $USERNAME && \
  echo "$USERNAME:$USERNAME" | chpasswd && \
  usermod --shell /bin/bash $USERNAME && \
  usermod  --uid ${uid} $USERNAME && \
  groupmod --gid ${gid} $USERNAME
USER ${user}

# https://answers.ros.org/question/10238/unable-to-contact-my-own-server/
ENV ROS_HOSTNAME=localhost
ENV ROS_MASTER_URI=http://localhost:11311
RUN echo "source ${WS}/devel/setup.bash">> ~/.bashrc

#------------------------------------------------------------------------------
# launch ros package
#ENTRYPOINT ["/opt/ros/overlay_ws/src/rovio/cfg/${cfg_kit}/entrypoint.sh"]
CMD ["/bin/bash"]
# CMD tail -f /dev/null
