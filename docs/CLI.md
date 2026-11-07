# Command-line usage

[← README](../README.md)

Запуск с CLI-параметрами работает без окна настроек и не меняет сохранённые значения. Остановка: **Ctrl+C** в терминале. Полный список параметров: `.build/release/Crosy --help`.

Зелёный крест с центральной точкой:

```sh
.build/release/Crosy --color 00FF00 --length 12 --gap 5 --thickness 2 --center-dot
```

Полупрозрачное голубое кольцо:

```sh
.build/release/Crosy --style circle --radius 9 --color 00D9FF --opacity 0.8
```

Белая точка с чёрной обводкой:

```sh
.build/release/Crosy --style dot --dot-size 4 --color FFFFFF --outline 1
```

Мониторы и параметры:

```sh
.build/release/Crosy --list-screens
.build/release/Crosy --screen 1 --offset-x 0 --offset-y 0
.build/release/Crosy --screen all
.build/release/Crosy --help
```

`main` означает первый монитор macOS (с основной строкой меню). Центр вычисляется по полному экрану, включая область Dock и строки меню. Размеры задаются в пунктах macOS, не физических пикселях Retina. Положительный `--offset-y` сдвигает прицел вверх. При изменении конфигурации дисплеев окна пересоздаются; если выбранный индекс пропал, прицел скрывается до его появления.

Фоновый запуск с сохранением PID:

```sh
.build/release/Crosy --center-dot > /tmp/crosy.log 2>&1 &
crosshair_pid=$!
# Остановить в этой же сессии терминала:
kill "$crosshair_pid"
```

В режиме CLI настройки передаются при запуске. Для смены настроек CLI остановите процесс и запустите его с новыми параметрами. Дополнительные разрешения Accessibility или Screen Recording не используются.

Окно настроено на показ поверх приложений и на рабочих столах, включая полноэкранные Spaces. В отдельных играх с эксклюзивным полноэкранным выводом оверлей может не отображаться; попробуйте оконный режим без рамки. Поведение полноэкранных окон зависит от macOS и приложения: [NSWindow.CollectionBehavior](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallapplications).
