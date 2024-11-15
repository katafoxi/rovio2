# Описание конфигурации

Камера [Raspberry Pi Global Shutter Camer](https://www.raspberrypi.com/products/raspberry-pi-global-shutter-camera/)

[Raspberry Pi Pico RP2040](https://datasheets.raspberrypi.com/pico/pico-datasheet.pdf)

IMU - [BNO055](https://www.bosch-sensortec.com/products/smart-sensor-systems/bno055/).
[BNO055_datasheet](https://zizibot.ru/directory/sensor/bno055/doc/1526196990adafruit-bno055-absolute-orientation-sensor-1006287.pdf)


Конфигурация предназначена для работы в режиме онлайн.

## Camera


## IMU BNO055 
[TOOL:bno055 serial to ros](https://github.com/katafoxi/bno055_serial_to_ros.git)

Датчик BNO055 подключен к Raspberry Pico. Pico посылает пакеты к RPI5 через COM-порт `/dev/ttyACM0`.

Определить адрес подключенного датчика с помощью команды:
```bash
sudo apt-get update 
sudo apt-get -y install i2c-tools # Установка инструмента 
sudo i2cdetect -l
```

## IMU and GoPro10 as usb-cam connect with docker-container

Для подключения COM-порта с данными IMU/временной меткой и камеры  к docker-контейнеру в `docker-compose.yaml` добавлен проброс видеоустройства 
`/dev/video0` и `/dev/ttyACM0`.
Добавлениы права доступа к этим устройствам в секции `device_cgroup_rules`.

```yaml
    volumes:
      - /tmp/.X11-unix:/tmp/.X11-unix
      - ./.docker.xauth:/tmp/.docker.xauth:rw
      - ./:/opt/ros/overlay_ws/src/rovio/cfg/gscam_bno055_rp2040
      - /dev/video42:/dev/video0 # Проброс устройства для обработки видео https://foundries.io/insights/blog/sharing-camera-with-docker/
      - /etc/localtime:/etc/localtime:ro # Монтирование настроек времени
      - /dev/ttyACM0:/dev/ttyACM0 # Проброс COM-порта в контейнер
      
    devices:  
      - "/dev/ttyACM0:/dev/ttyACM0"

    device_cgroup_rules:
      - 'c 89:* rmw' #Установка прав доступа к символьному устройству I2C датчику
```

## Сборка контейнера
Выбрать архитектуру хоста. Для arm64v8(Raspberry Pi 5) Dockerfile привести к виду:
```
#FROM ros:noetic-ros-base
FROM arm64v8/ros:noetic-ros-base
```

Собрать контейнер
```bash
cd gscam_bno055_rp2040 
docker compose build
```
## Проверка корректной работы IMU+RP2040.

Зайти в контейнер 
```bash
docker compose run --rm rovio
```

Будет открыта консоль в  контейнере. В консоли запустить лаунчер для IMU.
```bash
roslaunch bno055_serial_to_imu demo.launch
```

## Запуск записи для калибровки

В первом терминале:sudo chmod 666 /dev/i2c-1  
```bash
sudo chmod 666 /dev/i2c-1  
sudo gopro webcam  \
--resolution "1080" \
--fov "wide"
ffmpeg -nostdin -threads 1 \
-i 'udp://@0.0.0.0:8554?overrun_nonfatal=1&fifo_size=50000000' \
-f:v mpegts -fflags nobuffer -vf format=yuv420p  \
-f v4l2 /dev/video42
```
В следующем терминале:
```bash
sudo docker  compose run --rm rovio_online
```
В контейнере:
```bash
roslaunch rovio gscam_bno055_rp2040_rosbag_record.launch
```

```bash
sudo modprobe v4l2loopback
```

```bash
sudo gst-launch-1.0 udpsrc uri=udp://0.0.0.0:8554 \! tsdemux latency=100 \! "video/x-h264, profile=baseline, framerate=30/1, width=1920, height=1080, format=(string)YUY2" \! h264parse \! avdec_h264 \! queue \! videoconvert \! v4l2sink device=/dev/video42 sync=false

```

```bash
sudo nohup bash -c "gopro webcam  --resolution "1080" --fov "wide" --non-interactive && \
ffmpeg -nostdin -threads 1 -i 'udp://@0.0.0.0:8554?overrun_nonfatal=1&fifo_size=50000000' -f:v mpegts -fflags nobuffer -vf format=gray -f v4l2 /dev/video42" && \
sudo chmod 666 /dev/video42 && \
sudo chmod 666 /dev/i2c-1 && cd && cdws

rosbag info --yaml --freq src/rovio/cfg/gscam_bno055_rp2040/bags/gscam_bno055_rp2040_record.bag
```

Если вам нужна помощь с поддерживаемыми разрешениями и частотой кадров веб-камеры, попробуйте:

``` bash
sudo modprobe v4l2loopback
v4l2-ctl --list-formats-ext
```
 --non-interactive



```bash
 roslaunch rovio gscam_bno055_rp2040_rosbag_play.launch rviz:=true conf_prefix:=16_16 bag_name:=way.bag 
 ```


    std::string encoding = sensor_msgs::image_encodings::BGR8;
        if (grayscale) {
          cv::cvtColor(img, img, cv::COLOR_BGR2GRAY);
          encoding = sensor_msgs::image_encodings::MONO8;
        }