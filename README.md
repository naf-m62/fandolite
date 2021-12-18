# FandoLite

**FandoLite** — система связывающая мобильное приложение и фандомат.

Например: Клиент сдает бутылки(банки) в фандомат и получает баллы в приложении. Эти баллы можно будет обменять у партнеров. 

![image](https://user-images.githubusercontent.com/59660045/146642349-9a1c1745-d888-4f1a-97ad-6b5abb9ef026.png)

Device — состоит из следующих компонентов: 
- Микроконтроллер Arduino nano 33 ble
- Датчики расстояния - 4 штуки
- Датчик считывания штрих-кода
- Сервопривод

Принимает команды от Mobile App

Mobile App — Мобильное приложение (в примере написан на flutter). Основная логика работы заложена тут.

Backend — Бэк системы (в примере используется база данных — PG и микросервис на Go). Хранит данные о контейнерах и клиентах.

**Принцип работы**
- При запуске приложение отправляет запрос на создание сессии пользователя
- Клиент подключает приложение(flutter) к устройству по bluetooth
- Проверка на наличие объекта внутри контейнера
- Клиент засовывает бутылку в контейнер
- Датчик считывает наличие руки внутри контейнера и передает сигнал приложению
- Устройство считывает штрихкод и отправляет его в телефон
- Приложение отправляет запрос на бэк
- На бэке проверяется штрихкод на список разрешенных кодов для получения баллов
- Устройство ждет пока клиент вытащить руку из отверстия
- Устройство проверяет наличие объекта внутри
- Устройство вращает сервопривод
- Еще одна проверка на наличие объекта внутри
- Если объект не упал — бал не будет засчитан, если объект упал - засчитывается бал
