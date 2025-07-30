#!/bin/bash
set -e

# Setup ROS environment
if [ -z "${SETUP}" ]; then
    source "/opt/ros/$ROS_DISTRO/setup.bash"
else
    source "/opt/ros/overlay_ws/devel/setup.bash"
fi

# Additional environment setup
source "/opt/ros/overlay_ws/devel/setup.bash"
export ROS_HOSTNAME=localhost
export ROS_MASTER_URI=http://localhost:11311
video_bags_data="/opt/ros/overlay_ws/src/rovio/cfg/gopro10/video_bags_data"

# Функция для получения списка видеофайлов
get_gopro_videos() {
    local videos=()
    local video_names=()
    
    if [ -d "$video_bags_data" ]; then
        while IFS= read -r -d $'\0' file; do
            videos+=("$file")
            video_names+=("$(basename "$file")")
        done < <(find "$video_bags_data" -type f \( -name "*.mp4" -o -name "*.MP4" -o -name "*.mov" -o -name "*.avi" \) -print0)
    fi
    
    # Возвращаем оба массива через глобальные переменные
    GP_VIDEOS=("${videos[@]}")
    GP_VIDEO_NAMES=("${video_names[@]}")
}

get_bagfiles(){
    local bagfiles=()
    local bagfiles_names=()
    
    if [ -d "$video_bags_data" ]; then
        while IFS= read -r -d $'\0' file; do
            bagfiles+=("$file")
            bagfiles_names+=("$(basename "$file")")
        done < <(find "$video_bags_data" -type f \( -name "*.bag" \) -print0)
    fi
    
    # Возвращаем оба массива через глобальные переменные
    GP_BAGFILES=("${bagfiles[@]}")
    GP_BAGFILE_NAMES=("${bagfiles_names[@]}")
}

# Список доступных launch-файлов
LAUNCH_FILES=(
    "gopro_to_rosbag.launch"
    "rosbagplay_gopro10.launch"
)

process_launch_file() {
    local file="$1"
    case "$file" in
        *"gopro_to_rosbag.launch")
            get_gopro_videos  # Получаем списки файлов
            echo "На хосте добавьте видеофайл в /rovio2/cfg/gopro10/video_bags_data"
            echo "Файл появится в контейнере в /opt/ros/overlay_ws/src/rovio/cfg/gopro10/video_bags_data"
            
            if [ ${#GP_VIDEOS[@]} -eq 0 ]; then
                echo "В указанной директории не найдено видеофайлов"
                return 1
            fi
            
            echo ""
            echo "Доступные видеофайлы:"
            for i in "${!GP_VIDEO_NAMES[@]}"; do
                echo "$((i+1)). ${GP_VIDEO_NAMES[$i]}"
            done
            
            read -p "Выберите видеофайл [1-${#GP_VIDEO_NAMES[@]}]: " video_choice
            
            if [[ $video_choice =~ ^[0-9]+$ && $video_choice -ge 1 && $video_choice -le ${#GP_VIDEO_NAMES[@]} ]]; then
                gopro_video="${GP_VIDEOS[$((video_choice-1))]}"
                echo "Выбран файл: $gopro_video"
            else
                echo "Неверный выбор, попробуйте снова"
                return 1
            fi

            base_name=$(basename "$gopro_video")
            file_name="${base_name%.*}"
            bag_dir=$(dirname "$gopro_video")
            bag_file="${bag_dir}/${file_name}.bag"
            echo "Выходной rosbag-файл: $bag_file"
            
            # Проверяем существование файла
            if [ -f "$bag_file" ]; then
                echo ""
                echo "Файл $bag_file уже существует:"
                echo "1. Перезаписать .bag файл (запустить gopro_to_rosbag.launch)"
                echo "2. Запустить существующий .bag файл (rosbagplay_gopro10.launch)"
                echo "3. Отменить операцию"
                
                read -p "Выберите действие [1-3]: " choice
                
                case $choice in
                    1)
                        roslaunch gopro_ros gopro_to_rosbag.launch gopro_video:="$gopro_video" rosbag:="$bag_file"
                        ;;
                    2)
                        launch_bag_playback "$bag_file"
                        ;;
                    *)
                        echo "Отмена операции."
                        return 1
                        ;;
                esac
            else
                roslaunch gopro_ros gopro_to_rosbag.launch gopro_video:="$gopro_video" rosbag:="$bag_file"
            fi
            ;;
        *"rosbagplay_gopro10.launch")
            get_bagfiles
            if [ ${#GP_BAGFILES[@]} -eq 0 ]; then
                echo "В указанной директории не найдено bag-файлов"
                return 1
            fi
            
            echo ""
            echo "Доступные bag-файлы:"
            for i in "${!GP_BAGFILE_NAMES[@]}"; do
                echo "$((i+1)). ${GP_BAGFILE_NAMES[$i]}"
            done
            
            read -p "Выберите bag-файл [1-${#GP_BAGFILE_NAMES[@]}]: " bag_choice
            
            if [[ $bag_choice =~ ^[0-9]+$ && $bag_choice -ge 1 && $bag_choice -le ${#GP_BAGFILE_NAMES[@]} ]]; then
                selected_bag="${GP_BAGFILES[$((bag_choice-1))]}"
                echo "Выбран файл: $selected_bag"
                launch_bag_playback "$selected_bag"
            else
                echo "Неверный выбор, попробуйте снова"
                return 1
            fi
            ;;
        *)
            echo "Неизвестный launch-файл: $file"
            return 1
            ;;
    esac
}

launch_bag_playback() {
    local bag_file="$1"
    
    # Запрашиваем параметры воспроизведения
    read -p "Введите время начала воспроизведения (сек) [по умолчанию 0]: " start_time
    start_time=${start_time:-0}
    
    read -p "Введите продолжительность воспроизведения (сек) [по умолчанию - всё]: " duration
    duration=${duration:--1}
    
    # Формируем параметры для rosbag play
    local play_args=()
    if [ "$start_time" != "0" ]; then
        play_args+=("--start=$start_time")
    fi
    
    if [ "$duration" != "-1" ]; then
        play_args+=("--duration=$duration")
    fi
    
    echo "Запускаю воспроизведение: $bag_file"
    echo "Параметры: ${play_args[@]}"
    
    roslaunch rovio rosbagplay_gopro10.launch rviz:=true conf_prefix:=16_16 bag:="$bag_file" play_args:="${play_args[*]}"
}

main_menu() {
    while true; do
        echo ""
        echo "========== Главное меню =========="
        echo "1. Выбрать и запустить launch-файл"
        echo "2. Открыть интерактивный терминал"
        echo "3. Выйти"
        echo "=================================="
        
        read -p "Выберите действие [1-3]: " choice
        
        case $choice in
            1)
                choose_and_launch
                ;;
            2)
                echo "Открываю интерактивную bash-сессию..."
                exec bash
                ;;
            3)
                echo "Завершение работы..."
                exit 0
                ;;
            *)
                echo "Неверный выбор, попробуйте снова"
                ;;
        esac
    done
}

choose_and_launch() {
    # Если нет интерактивного терминала, запускаем файл по умолчанию
    if [ ! -t 0 ]; then
        echo "No terminal detected. Launching default: ${LAUNCH_FILES[0]}" >&2
        roslaunch rovio "${LAUNCH_FILES[0]}"
        return $?
    fi

    # Интерактивный выбор
    while true; do
        echo ""
        echo "Доступные launch-файлы:"
        for i in "${!LAUNCH_FILES[@]}"; do
            echo "$((i+1)). ${LAUNCH_FILES[$i]}"
        done
        echo "0. Назад в главное меню"
        
        read -p "Выберите файл для запуска: " choice
        
        if [[ $choice -eq 0 ]]; then
            return
        elif [[ $choice -gt 0 && $choice -le ${#LAUNCH_FILES[@]} ]]; then
            SELECTED_FILE="${LAUNCH_FILES[$((choice-1))]}"
            echo "Запускаю: $SELECTED_FILE"
            process_launch_file "$SELECTED_FILE"
            read -p "Нажмите Enter чтобы вернуться в меню..."
        else
            echo "Неверный выбор! Пожалуйста, попробуйте снова."
        fi
    done
}

# Основное выполнение
if [[ "$1" == "--non-interactive" ]]; then
    # Режим без меню (для автоматических запусков)
    roslaunch rovio "${LAUNCH_FILES[0]}"
else
    # Интерактивный режим с меню
    main_menu
fi