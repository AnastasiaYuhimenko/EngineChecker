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
