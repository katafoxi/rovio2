ARG ROS_IMAGE=ros:noetic-ros-base
FROM --platform=$BUILDPLATFORM ${ROS_IMAGE} as base

SHELL ["/bin/bash", "-c"]
ARG WS=/opt/ros/overlay_ws
ARG cfg_kit=gopro10
ARG opengl_scene="false"

WORKDIR $WS/src
WORKDIR $WS/

ENV CUDA_VERSION=10.0.130
ENV CUDA_PKG_VERSION=10-0=10.0.130-1

ENV PATH=/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Добавляем переменные для X11 и GPU
ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_DRIVER_CAPABILITIES=all
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics,compat32,utility
ENV NVIDIA_REQUIRE_CUDA=cuda>=10.0 brand=tesla,driver>=384,driver<385
ENV NCCL_VERSION=2.3.5
ENV LIBRARY_PATH=/usr/local/cuda/lib64/stubs
ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/usr/lib/i386-linux-gnu


RUN <<EOT bash
      apt-get update && apt-get install -y \
      mc \
      git \
      pip \
      wget \
      nano \
      byobu \
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

#------------------------------------------------------------------------------
RUN <<EOT bash
      apt-get install -y \
      xauth \
      x11-apps \
      libxv1 \
      libglu1-mesa \
      libgl1-mesa-glx \
      libgl1-mesa-dri \
      mesa-utils \
      libnvidia-gl-535 \
      at-spi2-core \
      dbus-x11
EOT

#------------------------------------------------------------------------------
# It is necessary to select the appropriate Rovio build option
RUN <<EOT bash
  source ~/.bashrc
  source /opt/ros/${ROS_DISTRO}/setup.bash
  catkin config --extend /opt/ros/${ROS_DISTRO}
  source ${WS}/devel/setup.bash

  # build ROVIO with or without OpenGL scene
  # if ${opengl_scene}; then
  if false; then
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
# install converter GoPro video to rosbag-file
RUN <<EOT bash
  sudo apt install -y libopencv-dev ffmpeg libeigen3-dev && \
  source /opt/ros/${ROS_DISTRO}/setup.bash && \
  catkin config --extend /opt/ros/${ROS_DISTRO} && \
  source ${WS}/devel/setup.bash && \
  git clone https://github.com/joshi-bharat/gopro_ros.git ./src/gopro_ros && \
  catkin build gopro_ros -j1 --mem-limit 70% --cmake-args -DCMAKE_BUILD_TYPE=Release 

EOT

# Добавляем пользователя ДО создания рабочих директорий
ARG user
ARG uid
ARG gid

RUN useradd -m -u ${uid} ${user} && \
  echo "${user}:${user}" | chpasswd && \
  usermod --shell /bin/bash ${user} && \
  groupmod --gid ${gid} ${user} && \
  usermod -aG video ${user} && \
  usermod -aG sudo ${user} && \
  echo "${user} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Настраиваем X11 runtime директорию
ENV XDG_RUNTIME_DIR=/run/user/${uid}
RUN mkdir -p ${XDG_RUNTIME_DIR} && \
  chown ${user}:${user} ${XDG_RUNTIME_DIR} && \
  chmod 700 ${XDG_RUNTIME_DIR}


USER ${user}
WORKDIR $WS/src/rovio/cfg/${cfg_kit}
ENV DISABLE_ROS1_EOL_WARNINGS=1
#------------------------------------------------------------------------------
# launch ros package
# ENTRYPOINT ["/opt/ros/overlay_ws/src/rovio/cfg/gopro10/entrypoint.sh"]
# CMD ["bash"]
# CMD tail -f /dev/null
