#!/bin/bash

# Скрипт для подбора наиболее удачных коэффициентов умножения для imu.yaml с последующей калибровкой.
source $WS/devel/setup.bash
WORKDIR="${kit_clbr}"
TARGET="cam_target_aprilgrid"
# Возможные camera models    omni-none omni-radtan ds-none eucm-none pinhole-equi pinhole-radtan pinhole-fov
MODELS=(     pinhole-radtan    )
pref="klbr"
target_grid_name="${pref}0_target_aprilgrid.yaml"
image_topic_name="main_camera/image_raw/compressed"
imu_topic_name="imu/data"
static_bag_name="${pref}0_static"
dynamic_bag_name="${pref}0_static"


cd $WORKDIR

# Генерация imu.yaml файла на базе получнных данных калибровки IMU, с умножением на поправочные коэффициенты
function create_imu_yaml() {
    local white_noise_factor=$1
    local random_walk_factor=$2
    cat > imu.yaml <<- EOM
    # example values for GoPro9 https://github.com/urbste/OpenImuCameraCalibrator/blob/master/docs/compare_to_kalibr.md

    #Accelerometer
    #values after IMU-calibration allan_variance
    #accelerometer_noise_density:     0.002386
    #accelerometer_random_walk:       0.000177 
    #values ​​after multiplying by {$white_noise_factor} for white noise
    accelerometer_noise_density: $( printf "%.6f" "$(( 2386 * $white_noise_factor))e-6" | sed "s/,/./")
    #values ​after multiplying by {$random_walk_factor} for random walk
    accelerometer_random_walk:   $( printf "%.6f" "$(( 177  * $random_walk_factor))e-6" | sed "s/,/./") 

    #Gyroscope
    #values after IMU-calibration allan_variance
    #gyroscope_noise_density:      0.000332
    #gyroscope_random_walk:        0.000001

    gyroscope_noise_density:      $( printf "%.6f" "$(( 332 * $white_noise_factor))e-6" | sed "s/,/./")
    gyroscope_random_walk:        $( printf "%.6f" "$(( 1  * $random_walk_factor))e-6" | sed "s/,/./") 

    rostopic: ${imu_topic_name} 
    update_rate: 99 
EOM
}

function calibrate_cameras() {
    local cam_type=$1
    rosrun kalibr kalibr_calibrate_cameras \
        --models "${cam_type}" \
        --bag "${WORKDIR}"/"${static_bag_name}".bag \
        --bag-freq 4 \
        --topics ${image_topic_name}  \
        --target "${WORKDIR}"/"${target_grid_name}" \
        --bag-from-to 5 45 \
        --dont-show-report > out_cam.txt 2>&1
        #--verbose \
    echo "kalibr_calibrate_cameras ok"
    mv $WORKDIR/*-camchain.yaml      ./${pref}1_camchain.yaml
    mv $WORKDIR/*-report-cam.pdf     ./${pref}1_report-cam.pdf
    mv $WORKDIR/*-results-cam.txt    ./${pref}1_results-cam.txt
}

# Калибровка камеры + IMU по динамическому набору данных.
function calibrate_imu_camera() {
    local cam_type=$1
    local white_noise_factor=$2
    local random_walk_factor=$3
    PREFIX="$white_noise_factor"_"$random_walk_factor"
    DIR="$PREFIX"_"$cam_type"
    mkdir "$DIR"
    cd $DIR
    create_imu_yaml "$white_noise_factor" "$random_walk_factor"

    cp $WORKDIR/*camchain.yaml      ./${pref}1_camchain.yaml
    cp $WORKDIR/*report-cam.pdf     ./${pref}1_report-cam.pdf
    cp $WORKDIR/*results-cam.txt    ./${pref}1_results-cam.txt

    rosrun kalibr kalibr_calibrate_imu_camera \
    --bag "$WORKDIR"/"${dynamic_bag_name}".bag \
    --bag-freq 4 \
    --cam ./${pref}1_camchain.yaml \
    --imu ./imu.yaml \
    --imu-models calibrated \
    --target "${WORKDIR}"/"${target_grid_name}"  \
    --max-iter 50 \
    --bag-from-to 5 45 \
    --dont-show-report > out_cam_imu.txt 2>&1

    filename="${dynamic_bag_name}-camchain-imucam.yaml"

    if [[ -e ../$filename ]] 
    then
        mv $WORKDIR/*camchain-imucam.yaml  ./"$PREFIX"_camchain-imucam.yaml 
        mv $WORKDIR/*imu.yaml              ./"$PREFIX"_imu.yaml
        mv $WORKDIR/*report-imucam.pdf     ./${pref}3_"$PREFIX"_report-imucam.pdf
        mv $WORKDIR/*results-imucam.txt    ./${pref}3_"$PREFIX"_results-imucam.txt

        rosrun kalibr kalibr_rovio_config \
        --cam "${WORKDIR}"/"${DIR}"/"${PREFIX}"_camchain-imucam.yaml 

        #mv ./imu.yaml        ./${pref}2_"$PREFIX"_generated_imu.yaml
        mv ./rovio_cam*.yaml ./"$PREFIX"_cam0.yaml  
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
        calibrate_cameras "${m}"
        calibrate_imu_camera "${m}" 1 1
        for white_noise_factor in {6..31..5}; do
            for random_walk_factor in {6..31..5}; do
                calibrate_imu_camera "${m}" "$white_noise_factor" "$random_walk_factor"
            done
        done
    done
}

main 

# Для ручного подбора
#for m in "${MODELS[@]}"; do
#    calibrate_imu_camera ${m} 10 10
#done