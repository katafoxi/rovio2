#FROM ros:noetic-ros-base
FROM arm64v8/ros:noetic-ros-base

SHELL ["/bin/bash", "-c"]
ARG WS=/opt/ros/overlay_ws

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
      git clone https://github.com/CopterExpress/clover.git ./src/clover
      rosdep install --from-paths src --ignore-src -r -y
      echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> ~/.bashrc
      source ~/.bashrc

EOT

# It is necessary to select the appropriate Rovio build option
RUN <<EOT bash
  source ~/.bashrc
  source /opt/ros/${ROS_DISTRO}/setup.bash
  catkin config --extend /opt/ros/${ROS_DISTRO}
  source ${WS}/devel/setup.bash

  # uncomment to build ROVIO without OpenGL scene
  catkin build rovio -j 1 --mem-limit 70% --cmake-args -DCMAKE_BUILD_TYPE=Release -DROVIO_NCAM=1

  #build rovio with OpenGL scene
  #catkin build rovio -j 1 --mem-limit 70% --cmake-args -DCMAKE_BUILD_TYPE=Release -DROVIO_NCAM=1 -DMAKE_SCENE=ON
  
  #build clover package
  # https://github.com/CopterExpress/clover/tree/master/clover
  rosdep install -y --from-paths src --ignore-src
  catkin build clover -j1 --mem-limit 70%
EOT

#install and build ros_imu_bno055 module
RUN <<EOT bash
  sudo apt install -y libi2c-dev

  source /opt/ros/${ROS_DISTRO}/setup.bash
  catkin config --extend /opt/ros/${ROS_DISTRO}
  source ${WS}/devel/setup.bash

  git clone https://github.com/dheera/ros-imu-bno055.git ./src/ros_imu_bno055
  catkin build imu_bno055 -j1 --mem-limit 70% --cmake-args -DCMAKE_BUILD_TYPE=Release 

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

#------------------------------------------------------------------------------
# launch ros package
ENTRYPOINT ["/opt/ros/overlay_ws/src/rovio/cfg/gopro10_docker/entrypoint.sh"]
# CMD ["bash"]
# CMD tail -f /dev/null
