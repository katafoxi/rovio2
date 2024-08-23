#!/bin/bash

#camera models    omni-none omni-radtan ds-none eucm-none pinhole-equi pinhole-radtan pinhole-fov

MODELS=(       pinhole-radtan-rs    )
WORKDIR="$HOME/1video"
TARGET="cam_target_aprilgrid"
source $HOME/2calibration_ws/devel/setup.bash
cd $WORKDIR

function create_imu_yaml() {
    local white_noise_factor=$1
    local random_walk_factor=$2
    cat > imu.yaml <<- EOM
T_i_b:
  - [1.0, 0.0, 0.0, 0.0]
  - [0.0, 1.0, 0.0, 0.0]
  - [0.0, 0.0, 1.0, 0.0]
  - [0.0, 0.0, 0.0, 1.0]
#Accelerometer
#values after IMU-calibration allan_variance
#accelerometer_noise_density:     0.001220
#accelerometer_random_walk:       0.000319 
#values ​​after multiplying by {$white_noise_factor} for white noise
#values ​after multiplying by {$random_walk_factor} for random walk
accelerometer_noise_density: $( printf "%.6f" "$(( 1220 * $white_noise_factor))e-6" | sed "s/,/./")
accelerometer_random_walk:   $( printf "%.6f" "$(( 319 * $random_walk_factor))e-6" | sed "s/,/./") 

#Gyroscope
#values after IMU-calibration allan_variance
#gyroscope_noise_density:      0.000133
#gyroscope_random_walk:        0.000033

gyroscope_noise_density:      $( printf "%.6f" "$(( 133 * $white_noise_factor))e-6" | sed "s/,/./")
gyroscope_random_walk:        $( printf "%.6f" "$(( 33 * $random_walk_factor))e-6" | sed "s/,/./") 
model: calibrated
rostopic: '/gopro/imu' 
update_rate: 197.0
EOM

}

function calibrate() {
    local cam_type=$1
    local white_noise_factor=$2
    local random_walk_factor=$3
    PREFIX=rs_"$white_noise_factor"_"$random_walk_factor"
    DIR="$cam_type"_imu_"$PREFIX"_sm
    mkdir $DIR
    cd $DIR
    create_imu_yaml $white_noise_factor $random_walk_factor
    rosrun kalibr kalibr_calibrate_rs_cameras \
    --model $cam_type \
    --bag $WORKDIR/"$TARGET"_static.bag \
    --topic /gopro/image_raw  \
    --target $WORKDIR/$TARGET.yaml \
    --time-calibration \
    --imu ./imu.yaml \
    --imu-model calibrated \
    --feature-variance 1 > "out_cam.txt" 2>&1
    #--verbose \

    mv $WORKDIR/"$TARGET"_static-camchain.yaml      ./"$TARGET"-camchain.yaml
    mv $WORKDIR/"$TARGET"_static-report-cam.pdf     ./"$TARGET"-report-cam.pdf
    mv $WORKDIR/"$TARGET"_static-results-cam.txt    ./"$TARGET"-results-cam.txt

    rosrun kalibr kalibr_calibrate_imu_camera \
    --bag $WORKDIR/"$TARGET"_dynamic.bag \
    --cam ./$TARGET-camchain.yaml \
    --imu ./imu.yaml \
    --imu-models calibrated \
    --target $WORKDIR/$TARGET.yaml \
    --estimate-line-delay \
    --identifyNoises \
    --dont-show-report > out_imu.txt 2>&1

    filename="$TARGET"_dynamic-camchain-imucam.yaml

    if [[ -e ../$filename ]] 
    then
        mv $WORKDIR/$TARGET-camchain-imucam.yaml .
        mv $WORKDIR/$TARGET-imu.yaml .
        mv $WORKDIR/$TARGET-report-imucam.pdf .
        mv $WORKDIR/$TARGET-results-imucam.txt .

        rosrun kalibr kalibr_rovio_config \
        --cam $WORKDIR/$DIR/$TARGET-camchain-imucam.yaml

        mv ./imu.yaml                   ./"$PREFIX"_imu.yaml
        mv ./rovio_camo.yaml            ./"$PREFIX"_cam0.yaml  
        sed  -i '3s/camo/cam0/g'        "$PREFIX"_cam0.yaml 
        mv ./rovio_test.info            ./"$PREFIX"_rovio.info 
        sed  -i '9s/Camerao/Camera0/g'  "$PREFIX"_rovio.info
        tee -a "$PREFIX"_rovio.info << EOF
VelocityUpdate
{
    UpdateNoise
    {
        vel_0 0.0001
        vel_1 0.0001
        vel_2 0.0001
    }
    MahalanobisTh0 7.689997599999999
    qAM_x 0
    qAM_y 0
    qAM_z 0
    qAM_w 1
}
EOF
    else 
        echo "$PREFIX something wrong with cam+imu calibrate"
    fi
    cd ..
}

for m in "${MODELS[@]}"; do
    for white_noise_factor in {5..6..5}; do
        for random_walk_factor in {10..11..5}; do
            calibrate ${m} $white_noise_factor $random_walk_factor
        done
    done
done
 