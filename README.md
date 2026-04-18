
# EngineChecker

iOS-приложение для диагностики двигателя по звуку. Записывает аудио с микрофона (или импортирует ZIP-архив с записями), отправляет на сервер классификации и показывает результат: **здоров** или **аномалия**.

## Возможности

- **Запись звука двигателя** — моно 44.1 kHz, 16-bit PCM (.wav)
- **Пауза/продолжение** — несколько сегментов объединяются в один файл перед отправкой
- **Пакетное сканирование** — загрузка ZIP-архива с несколькими записями
- **Результаты от ML-модели** — статус (норма/аномалия), anomaly score, оценка RPM, версия модели

## Технологии

| Область | Стек |
|---------|------|
| UI | SwiftUI |
| Аудио | AVFoundation (AVAudioRecorder) |
| Реактивность | Combine |
| Сеть | URLSession, multipart/form-data |

## Структура проекта

```
EngineChecker/
├── EngineCheckerApp.swift    # Точка входа
├── Info.plist                # Конфигурация (ATS, шрифты, микрофон)
├── Assets.xcassets/          # Цвета, иконки
├── Fonts/                    # Orbitron
├── Models/                   # AnswersFromAPI, RequestModel
├── Extensions/               # Вспомогательные расширения
└── Root/Base/
    ├── VIews/                # MainScreen, ScanScreen, ResultScreen, BatchResultScreen
    ├── ModelViews/           # MainScreenVIewModel
    └── Services/             # AudioRecorder
```

## API

Приложение работает с бэкендом по адресу `http://178.154.233.146:8000`:

- `POST /api/v1/audio/classify` — классификация одной записи
- `POST /api/v1/audio/classify-batch` — пакетная классификация (ZIP)

**Параметры запроса:** `vehicle_id`, `segment_type` (idle / high_hold / background), `duration_sec`, `file`

## Требования

- iOS 17+
- Xcode 15+
- Доступ к микрофону

## Сборка

1. Открыть `EngineChecker.xcodeproj` в Xcode
2. Выбрать симулятор или устройство
3. Build & Run (⌘R)
<img width="648" height="1180" alt="photo_2026-04-18 1 45 10 PM" src="https://github.com/user-attachments/assets/92328c66-e5ae-4183-88b3-558fa265dbf7" />

<img width="582" height="1162" alt="photo_2026-04-18 1 45 21 PM" src="https://github.com/user-attachments/assets/7c247e09-029d-4cf4-8cbc-819730a41e29" />

<img width="640" height="1140" alt="photo_2026-04-18 1 45 37 PM" src="https://github.com/user-attachments/assets/9a1c29d8-1efa-4434-963e-0ea624c1d2e2" />
