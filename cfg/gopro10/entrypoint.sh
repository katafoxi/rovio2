#!/bin/bash
set -e

# Constants
ROS_OVERLAY_WS="/opt/ros/overlay_ws"
VIDEO_BAGS_DATA="$ROS_OVERLAY_WS/src/rovio/cfg/gopro10/video_bags_data"
LAUNCH_FILES=(
    "gopro_to_rosbag.launch"
    "rosbagplay_gopro10.launch"
)

# Global variables
declare -a GP_VIDEOS GP_VIDEO_NAMES GP_BAGFILES GP_BAGFILE_NAMES

# Initialize ROS environment
setup_ros_environment() {
    if [ -z "${SETUP}" ]; then
        source "/opt/ros/$ROS_DISTRO/setup.bash"
    else
        source "$ROS_OVERLAY_WS/devel/setup.bash"
    fi
    source "$ROS_OVERLAY_WS/devel/setup.bash"
    export ROS_HOSTNAME=localhost
    export ROS_MASTER_URI=http://localhost:11311
}

# Helper functions
get_files() {
    local dir="$1"
    shift
    local extensions=("$@")
    local files=() names=()
    
    if [ -d "$dir" ]; then
        # Создаем шаблон для find
        local pattern=""
        for ext in "${extensions[@]}"; do
            [ -n "$pattern" ] && pattern+=" -o"
            pattern+=" -name '*.$ext'"
        done
        
        while IFS= read -r -d $'\0' file; do
            files+=("$file")
            names+=("$(basename "$file")")
        done < <(eval "find \"$dir\" -type f \( $pattern \) -print0")
    fi
    
    echo "${files[@]}" "${names[@]}"
}

print_menu() {
    local title="$1" items=("${@:2}")
    echo ""
    echo "========== $title =========="
    for i in "${!items[@]}"; do
        echo "$((i+1)). ${items[$i]}"
    done
    echo "============================"
}

validate_numeric_input() {
    local input="$1" max="$2"
    [[ $input =~ ^[0-9]+$ ]] && (( input >= 1 && input <= max ))
}

# File handling functions
get_gopro_videos() {
    read -ra results <<< "$(get_files "$VIDEO_BAGS_DATA" "mp4" "MP4" "mov" "avi")"
    GP_VIDEOS=("${results[@]:0:${#results[@]}/2}")
    GP_VIDEO_NAMES=("${results[@]:${#results[@]}/2}")
}

get_bagfiles() {
    read -ra results <<< "$(get_files "$VIDEO_BAGS_DATA" "bag")"
    GP_BAGFILES=("${results[@]:0:${#results[@]}/2}")
    GP_BAGFILE_NAMES=("${results[@]:${#results[@]}/2}")
}

# Launch file processing
process_gopro_to_rosbag() {
    get_gopro_videos
    
    echo "На хосте добавьте видеофайл в /rovio2/cfg/gopro10/video_bags_data"
    echo "Файл появится в контейнере в $VIDEO_BAGS_DATA"
    
    if [ ${#GP_VIDEOS[@]} -eq 0 ]; then
        echo "В указанной директории не найдено видеофайлов"
        return 1
    fi
    
    print_menu "Доступные видеофайлы" "${GP_VIDEO_NAMES[@]}"
    read -p "Выберите видеофайл [1-${#GP_VIDEO_NAMES[@]}]: " video_choice
    
    if ! validate_numeric_input "$video_choice" "${#GP_VIDEO_NAMES[@]}"; then
        echo "Неверный выбор, попробуйте снова"
        return 1
    fi

    local gopro_video="${GP_VIDEOS[$((video_choice-1))]}"
    echo "Выбран файл: $gopro_video"

    local base_name=$(basename "$gopro_video")
    local file_name="${base_name%.*}"
    local bag_dir=$(dirname "$gopro_video")
    local bag_file="${bag_dir}/${file_name}.bag"
    echo "Выходной rosbag-файл: $bag_file"
    
    if [ -f "$bag_file" ]; then
        print_menu "Файл $bag_file уже существует" \
            "Перезаписать .bag файл (запустить gopro_to_rosbag.launch)" \
            "Запустить существующий .bag файл (rosbagplay_gopro10.launch)" \
            "Отменить операцию"
        
        read -p "Выберите действие [1-3]: " choice
        
        case $choice in
            1) roslaunch gopro_ros gopro_to_rosbag.launch gopro_video:="$gopro_video" rosbag:="$bag_file" ;;
            2) launch_bag_playback "$bag_file" ;;
            *) echo "Отмена операции."; return 1 ;;
        esac
    else
        roslaunch gopro_ros gopro_to_rosbag.launch gopro_video:="$gopro_video" rosbag:="$bag_file"
    fi
}

process_rosbag_playback() {
    get_bagfiles
    if [ ${#GP_BAGFILES[@]} -eq 0 ]; then
        echo "В указанной директории не найдено bag-файлов"
        return 1
    fi
    
    print_menu "Доступные bag-файлы" "${GP_BAGFILE_NAMES[@]}"
    read -p "Выберите bag-файл [1-${#GP_BAGFILE_NAMES[@]}]: " bag_choice
    
    if ! validate_numeric_input "$bag_choice" "${#GP_BAGFILE_NAMES[@]}"; then
        echo "Неверный выбор, попробуйте снова"
        return 1
    fi

    local selected_bag="${GP_BAGFILES[$((bag_choice-1))]}"
    echo "Выбран файл: $selected_bag"
    launch_bag_playback "$selected_bag"
}

launch_bag_playback() {
    local bag_file="$1"
    
    read -p "Введите время начала воспроизведения (сек) [по умолчанию 0]: " start_time
    start_time=${start_time:-0}
    
    read -p "Введите продолжительность воспроизведения (сек) [по умолчанию - всё]: " duration
    duration=${duration:--1}
    
    echo "Запускаю воспроизведение: $bag_file"
    roslaunch rovio rosbagplay_gopro10.launch rviz:=true conf_prefix:=16_16 \
        bag:="$bag_file" start:="$start_time" duration:="$duration"
}

# Menu functions
choose_and_launch() {
    if [ ! -t 0 ]; then
        echo "No terminal detected. Launching default: ${LAUNCH_FILES[0]}" >&2
        roslaunch rovio "${LAUNCH_FILES[0]}"
        return $?
    fi

    while true; do
        print_menu "Доступные launch-файлы" "${LAUNCH_FILES[@]}"
        echo "0. Назад в главное меню"
        
        read -p "Выберите файл для запуска: " choice
        
        if [[ $choice -eq 0 ]]; then
            return
        elif validate_numeric_input "$choice" "${#LAUNCH_FILES[@]}"; then
            local selected_file="${LAUNCH_FILES[$((choice-1))]}"
            echo "Запускаю: $selected_file"
            
            case "$selected_file" in
                *"gopro_to_rosbag.launch") process_gopro_to_rosbag ;;
                *"rosbagplay_gopro10.launch") process_rosbag_playback ;;
                *) echo "Неизвестный launch-файл: $selected_file"; return 1 ;;
            esac
            
            read -p "Нажмите Enter чтобы вернуться в меню..."
        else
            echo "Неверный выбор! Пожалуйста, попробуйте снова."
        fi
    done
}

main_menu() {
    while true; do
        print_menu "Главное меню" \
            "Выбрать и запустить launch-файл" \
            "Открыть интерактивный терминал" \
            "Выйти"
        
        read -p "Выберите действие [1-3]: " choice
        
        case $choice in
            1) choose_and_launch ;;
            2) echo "Открываю интерактивную bash-сессию..."; exec bash ;;
            3) echo "Завершение работы..."; exit 0 ;;
            *) echo "Неверный выбор, попробуйте снова" ;;
        esac
    done
}

# Main execution
setup_ros_environment

if [[ "$1" == "--non-interactive" ]]; then
    roslaunch rovio "${LAUNCH_FILES[0]}"
else
    main_menu
fi