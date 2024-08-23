#!/bin/bash

# Скрипт для подбора наиболее удачных коэффициентов умножения для imu.yaml с последующей калибровкой.
source $HOME/kalibr1_ws/devel/setup.bash
WORKDIR="$HOME/1video"
TARGET="cam_target_aprilgrid"
# Возможные camera models    omni-none omni-radtan ds-none eucm-none pinhole-equi pinhole-radtan pinhole-fov
MODELS=(    pinhole-equi-rs pinhole-radtan-rs     )

cd $WORKDIR

# Генерация imu.yaml файла на базе получнных данных калибровки IMU, с умножением на поправочные коэффициенты
function create_imu_yaml() {
    local white_noise_factor=$1
    local random_walk_factor=$2
    cat > imu.yaml <<- EOM
    # example values for GoPro9 https://github.com/urbste/OpenImuCameraCalibrator/blob/master/docs/compare_to_kalibr.md

    #Accelerometer
    #values after IMU-calibration allan_variance
    #accelerometer_noise_density:     0.001220
    #accelerometer_random_walk:       0.000319 
    #values ​​after multiplying by {$white_noise_factor} for white noise
    accelerometer_noise_density: $( printf "%.6f" "$(( 1220 * $white_noise_factor))e-6" | sed "s/,/./")
    #values ​after multiplying by {$random_walk_factor} for random walk
    accelerometer_random_walk:   $( printf "%.6f" "$(( 319  * $random_walk_factor))e-6" | sed "s/,/./") 

    #Gyroscope
    #values after IMU-calibration allan_variance
    #gyroscope_noise_density:      0.000133
    #gyroscope_random_walk:        0.000033

    gyroscope_noise_density:      $( printf "%.6f" "$(( 133 * $white_noise_factor))e-6" | sed "s/,/./")
    gyroscope_random_walk:        $( printf "%.6f" "$(( 33  * $random_walk_factor))e-6" | sed "s/,/./") 

    rostopic: '/gopro/imu' 
    update_rate: 197 
EOM
}

function calibrate_cameras() {
    local cam_type=$1
    rosrun kalibr kalibr_calibrate_cameras \
        --models $cam_type \
        --bag $WORKDIR/"$TARGET"_static.bag \
        --bag-freq 5 \
        --topics /gopro/image_raw  \
        --target $WORKDIR/"$TARGET".yaml \
        --dont-show-report > out_cam.txt 2>&1
        # --bag-from-to 5 35 \
        #--verbose \
}

# Калибровка камеры + IMU по динамическому набору данных.
function calibrate_imu_camera() {
    local cam_type=$1
    local white_noise_factor=$2
    local random_walk_factor=$3
    PREFIX="$white_noise_factor"_"$random_walk_factor"
    DIR="$PREFIX"_"$cam_type"
    mkdir $DIR
    cd $DIR
    create_imu_yaml $white_noise_factor $random_walk_factor

    cp $WORKDIR/"$TARGET"_static-camchain.yaml      ./"$TARGET"-camchain.yaml
    cp $WORKDIR/"$TARGET"_static-report-cam.pdf     ./"$TARGET"-report-cam.pdf
    cp $WORKDIR/"$TARGET"_static-results-cam.txt    ./"$TARGET"-results-cam.txt

    rosrun kalibr kalibr_calibrate_imu_camera \
    --bag $WORKDIR/"$TARGET"_dynamic.bag \
    --bag-freq 5 \
    --cam ./$TARGET-camchain.yaml \
    --imu ./imu.yaml \
    --imu-models calibrated \
    --target $WORKDIR/$TARGET.yaml \
    --max-iter 50 \
    --dont-show-report > out_cam_imu.txt 2>&1
    #--bag-from-to 5 30 \

    filename="$TARGET"_dynamic-camchain-imucam.yaml

    if [[ -e ../$filename ]] 
    then
        mv $WORKDIR/"$TARGET"_dynamic-camchain-imucam.yaml  ./$TARGET-camchain-imucam.yaml 
        mv $WORKDIR/"$TARGET"_dynamic-imu.yaml              ./$TARGET-imu.yaml
        mv $WORKDIR/"$TARGET"_dynamic-report-imucam.pdf     ./"$PREFIX"-report-imucam.pdf
        mv $WORKDIR/"$TARGET"_dynamic-results-imucam.txt    ./"$PREFIX"-results-imucam.txt

        rosrun kalibr kalibr_rovio_config \
        --cam $WORKDIR/$DIR/$TARGET-camchain-imucam.yaml

        mv ./imu.yaml        ./"$PREFIX"_imu.yaml
        mv ./rovio_camo.yaml ./"$PREFIX"_cam0.yaml  
        sed  -i '3s/camo/cam0/g' "$PREFIX"_cam0.yaml 
        mv ./rovio_test.info ./"$PREFIX"_rovio.info 
        sed  -i '9s/Camerao/Camera0/g' "$PREFIX"_rovio.info
    else 
        echo "$PREFIX something wrong with cam+imu calibrate_imu_camera"
    fi
    cd ..
}

# Для подбора оптимальных коэффициентов умножения шумов IMU
function main(){
    for m in "${MODELS[@]}"; do
        calibrate_cameras ${m}
        calibrate_imu_camera ${m} 1 1
        for white_noise_factor in {6..31..5}; do
            for random_walk_factor in {6..31..5}; do
                calibrate_imu_camera ${m} $white_noise_factor $random_walk_factor
            done
        done
    done
}

main ()

# Для ручного подбора
#for m in "${MODELS[@]}"; do
#    calibrate_imu_camera ${m} 10 10
#done