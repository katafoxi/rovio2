#!/bin/bash

CATKIN_WS=$HOME/ws1


#------------------------------------------------------------------------------
# Install common tools
sudo apt-get update
sudo apt-get install -y \
    autoconf \
    automake \
    git \
    nano \
    pip \
    python3-psutil \
    python3-rosdep \
    wget 

#------------------------------------------------------------------------------
# Install ROS1
sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu \
$(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'

sudo apt-key adv \
    --keyserver 'hkp://keyserver.ubuntu.com:80' \
    --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654
sudo apt-get update
export ROS1_DISTRO=noetic # kinetic=16.04, melodic=18.04, noetic=20.04
sudo apt-get install -y ros-$ROS1_DISTRO-desktop-full
sudo apt-get install -y \
    python3-catkin-tools \
    python3-osrf-pycommon # ubuntu 20.04

# Source ROS version="noetic" to use Catkin
source /opt/ros/$ROS_DISTRO/setup.bash            


# Create workspace
mkdir -p $CATKIN_WS/src
cd $CATKIN_WS
rosdep init
catkin init
catkin config --extend /opt/ros/$ROS1_DISTRO
catkin config --merge-devel # Necessary for catkin_tools >= 0.4.
catkin config --cmake-args -DCMAKE_BUILD_TYPE=Release


#------------------------------------------------------------------------------
# Install dependens for kalibr 
# https://github.com/ethz-asl/kalibr/wiki/installation
sudo apt-get install -y \
    doxygen \
    libblas-dev \
    libboost-all-dev \
    libeigen3-dev \
    liblapack-dev \
    libopencv-dev \
    libpoco-dev \
    libsuitesparse-dev \
    libtbb-dev \
    libv4l-dev

# Install dependens for kalibr  only for Ubuntu 20.04
sudo apt-get install -y \
    ipython3 \
    python3-dev \
    python3-igraph \
    python3-matplotlib \
    python3-pip \
    python3-pyx \
    python3-scipy \
    python3-tk \
    python3-wxgtk4.0 

# Clone and build kalibr repo
git clone https://github.com/ethz-asl/kalibr.git $CATKIN_WS/src/kalibr
catkin build kalibr -j2 --mem-limit 70% -DCMAKE_BUILD_TYPE=Release 


#------------------------------------------------------------------------------
# GOPRO_ROS - tool for convert .MP4 video to rosbag-files.
# Create .bag files
# Clone ang build gopro_ros 
sudo apt-get install -y \
    ffmpeg
    #libeigen3-dev
    #libopencv-dev
git clone --recursive https://github.com/joshi-bharat/gopro_ros.git \
$CATKIN_WS/src/gopro_ros
catkin build gopro_ros -j2 --mem-limit 70% -DCMAKE_BUILD_TYPE=Release 


#------------------------------------------------------------------------------
# ALLAN_VARIANCE_ROS - tool for define IMU noise_density and random_walk param.
# Will produce an imu.yaml file.
git clone --recursive https://github.com/ori-drs/allan_variance_ros.git \
$CATKIN_WS/src/allan_variance_ros
catkin build  allan_variance_ros


#------------------------------------------------------------------------------
# ROVIO - Robust Visual Inertial Odometry framework.
sudo apt-get install -y \
    freeglut3-dev \
    libglew-dev \
    libyaml-cpp-dev \
    ros-$ROS_DISTRO-image-transport \
    ros-$ROS_DISTRO-image-transport-plugins \
    ros-$ROS_DISTRO-rviz 
sudo pip3 install -U catkin_tools

git clone https://github.com/ANYbotics/kindr.git $CATKIN_WS/src/kindr
git clone \
    --recurse-submodules https://github.com/katafoxi/rovio2.git \
    $CATKIN_WS/src/rovio
rosdep install --from-paths src --ignore-src -r -y

# uncomment to build ROVIO without OpenGL scene
#catkin build rovio -j 1 --mem-limit 70% --cmake-args -DCMAKE_BUILD_TYPE=Release -DROVIO_NCAM=1

#build rovio with OpenGL scene
catkin build rovio -j 1 --mem-limit 70% --cmake-args -DCMAKE_BUILD_TYPE=Release -DROVIO_NCAM=1 -DMAKE_SCENE=ON 