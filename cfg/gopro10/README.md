### Описание конфигурации

Камера [GoPro 10](https://gopro.com/ru/ru/shop/cameras/hero10-black/CHDHX-101-master.html)
IMU - встроенное в камеру.

Конфигурация не предназначена для работы в режиме онлайн, по причине невозможности читать IMU-данные во время подключения камеры, как веб-камеры (по USB).
Нарезать видео с сохранением всех потоков можно командой:
```bash
vid_filename="GX020357.MP4" && \
out_filename="GX020357_4s49_6s00.MP4" && \
ffmpeg -i "${vid_filename}" -ss 00:04:49 -to 00:06:00 -c copy -map 0 "${out_filename}"
```

Общая последовательность действий:
1) В терминале перейти в папку с конфигурацией `rovio2/cfg/gopro10`
2) Cнять видео
3) Положить в `/rovio2/cfg/gopro10/video_bags_data`
4) Собрать контейнер `docker compose build && docker compose run --rm app`
5) Транслировать в rosbag-file. В меню `1.Выбрать и запустить launch-файл -> 1.gopro_to_rosbag.launch ->1.выбрать видео`. 
6) Запустить ноду `1.Выбрать и запустить launch-файл ->rosbagplay_node_gorpo10.launch`
   