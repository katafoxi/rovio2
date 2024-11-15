# Описание конфигурации

Камера [GoPro 10](https://gopro.com/ru/ru/shop/cameras/hero10-black/CHDHX-101-master.html)

IMU - [BNO055](https://www.bosch-sensortec.com/products/smart-sensor-systems/bno055/).
[BNO055_datasheet](https://zizibot.ru/directory/sensor/bno055/doc/1526196990adafruit-bno055-absolute-orientation-sensor-1006287.pdf)


Конфигурация предназначена для работы в режиме онлайн.

## GoPro 10 as webcam
[TOOL: GoPro as webcam on linux](https://github.com/jschmid1/gopro_as_webcam_on_linux) инструмент для подключения GoPro10 как веб-камеры. 
Дальше надо камеру подключить к компьютеру:

Конкретная команда:
```bash
sudo gopro webcam  \
--resolution "1080" \
--fov "wide"
ffmpeg -nostdin -threads 1 \
-i 'udp://@0.0.0.0:8554?overrun_nonfatal=1&fifo_size=50000000' \
-f:v mpegts -fflags nobuffer -vf format=yuv420p  \
-f v4l2 /dev/video42
```
Теперь камера траслирует изображение как устройство `/dev/video42`.

## IMU BNO055 

[GUIDE: How to Publish IMU Data Using ROS and the BNO055 IMU Sensor.](https://automaticaddison.com/how-to-publish-imu-data-using-ros-and-the-bno055-imu-sensor/)


[TOOL: ros imu bno055](https://github.com/dheera/ros-imu-bno055?tab=readme-ov-file)

Датчик BNO055 подключить к RPI5 как i2c-устройство.

Определить адрес подключенного датчика с помощью команды:
```bash
sudo apt-get update 
sudo apt-get -y install i2c-tools # Установка инструмента 
sudo i2cdetect -l
```
Вывод комнды:
```bash
i2c-1   i2c             Synopsys DesignWare I2C adapter         I2C adapter
i2c-11  i2c             107d508200.i2c                          I2C adapter
i2c-12  i2c             107d508280.i2c                          I2C adapter
```
Видим, что устроство соответствует шине 1 `/dev/i2c-1`.

Смотрим конкретный адрес устройства на шине 1:
```bash
sudo i2cdetect -r -y 1
```
Вывод команды:
```bash
0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:                         -- -- -- -- -- -- -- --
10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
20: -- -- -- -- -- -- -- -- 28 -- -- -- -- -- -- --
30: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
40: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
50: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
60: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
70: -- -- -- -- -- -- -- --
```
Видим конкретный адрес на шине 28.

Далее, после каждой перезагрузки компьютера, необходимо давать права доступа для контейнера docker.

```bash
sudo chmod 666 /dev/i2c-1    # https://answers.ros.org/question/397084/i2c-device-open-failed/
```

## IMU and GoPro10 as usb-cam connect with docker-container

Для подключения i2c-устройства (IMU) и камеры GoPro10 к docker-контейнеру в docker-compose.yaml добавлен проброс видеоустройства 
`/dev/video0` и `/dev/i2c-1`. Добавлениы права доступа к этим устройствам в секции `device_cgroup_rules`.

```yaml
    volumes:
      - /tmp/.X11-unix:/tmp/.X11-unix
      - ./.docker.xauth:/tmp/.docker.xauth:rw
      - ./:/opt/ros/overlay_ws/src/rovio/cfg/gopro10_bno055
      - /dev/video42:/dev/video0 # Проброс устройства для обработки видео https://foundries.io/insights/blog/sharing-camera-with-docker/
      - /etc/localtime:/etc/localtime:ro # Монтирование настроек времени
      - /dev/i2c-1:/dev/i2c-1 #Проброс устройства i2c
      
    devices:  
    - "/dev/i2c-1:/dev/i2c-1"  #https://stackoverflow.com/questions/40265984/i2c-inside-a-docker-container

    device_cgroup_rules:
      - 'c 81:* rmw' #Установка прав доступа к символьному устроййству основным номером 81:*
      #ls -l /dev/video0 узнать основной и младший номер устройства камеры
      - 'c 89:* rmw' #Установка прав доступа к символьному устройству I2C датчику
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
roslaunch rovio gopro10_bno055_rosbag_record.launch
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

rosbag info --yaml --freq src/rovio/cfg/gopro10_bno055/bags/gopro10_bno055_record.bag
```

Если вам нужна помощь с поддерживаемыми разрешениями и частотой кадров веб-камеры, попробуйте:

``` bash
sudo modprobe v4l2loopback
v4l2-ctl --list-formats-ext
```
 --non-interactive



```bash
 roslaunch rovio gopro10_bno055_rosbag_play.launch rviz:=true conf_prefix:=16_16 bag_name:=way.bag 
 ```


    std::string encoding = sensor_msgs::image_encodings::BGR8;
        if (grayscale) {
          cv::cvtColor(img, img, cv::COLOR_BGR2GRAY);
          encoding = sensor_msgs::image_encodings::MONO8;
        }