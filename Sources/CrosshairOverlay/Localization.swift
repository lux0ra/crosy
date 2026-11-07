import Foundation

/// UI language is stored separately so resetting crosshair settings preserves it.
@MainActor
enum L {
    static var language: String {
        get { UserDefaults.standard.string(forKey: "crosshair.language") == "en" ? "en" : "ru" }
        set { UserDefaults.standard.set(newValue == "en" ? "en" : "ru", forKey: "crosshair.language") }
    }

    static func text(_ russian: String) -> String {
        language == "en" ? english[russian, default: russian] : russian
    }

    static func format(_ russian: String, _ arguments: CVarArg...) -> String {
        String(format: text(russian), arguments: arguments)
    }

    private static let english: [String: String] = [
        "Настройки прицела": "Crosshair Settings",
        "Ваш прицел": "Your crosshair",
        "Язык": "Language",
        "Показывать прицел": "Show crosshair",
        "Крест": "Cross",
        "Точка": "Dot",
        "Кольцо": "Circle",
        "Предпросмотр · 1:1": "Preview · 1:1",
        "Точка в центре": "Center dot",
        "Скрыть или показать прицел, сохранив все настройки.": "Show or hide the crosshair without changing your settings.",
        "Видимость прицела": "Crosshair visibility",
        "Форма прицела": "Crosshair shape",
        "Выберите форму. Доступные настройки справа зависят от неё.": "Choose a shape. Available settings on the right depend on it.",
        "Цвет прицела": "Crosshair color",
        "Цвет обводки": "Outline color",
        "Сбросить настройки": "Reset settings",
        "Настройки сохраняются автоматически.": "Settings are saved automatically.",
        "Закрытие окна оставляет прицел работать. Открыть настройки можно в строке меню.": "Closing this window keeps the crosshair running. Reopen settings from the menu bar.",
        "Геометрия прицела": "Crosshair geometry",
        "Длина лучей": "Line length",
        "Отступ от центра": "Center gap",
        "Толщина": "Thickness",
        "Радиус кольца": "Circle radius",
        "Размер точки": "Dot size",
        "Обводка": "Outline",
        "Непрозрачность": "Opacity",
        "Экран и положение": "Display & position",
        "Монитор для прицела": "Crosshair display",
        "Монитор": "Display",
        "Смещение вправо": "Horizontal offset",
        "Смещение вверх": "Vertical offset",
        "0, 0 — центр экрана · +X вправо · +Y вверх": "0, 0 — screen center · +X right · +Y up",
        "От 0 до 100 %. 0 % полностью скрывает прицел.": "From 0 to 100%. At 0% the crosshair is invisible.",
        "Размеры в пунктах macOS. Точное значение можно ввести в поле справа.": "Sizes are in macOS points. Enter an exact value in the field on the right.",
        "Главный монитор": "Main display",
        "Все мониторы": "All displays",
        "Монитор %@ отключён": "Display %@ is disconnected",
        "Предпросмотр · прицел прозрачен при 0 %": "Preview · invisible at 0%",
        "Предпросмотр · уменьшен до %d %%": "Preview · scaled to %d%%",
        "Прицел включён": "Crosshair enabled",
        "Прицел выключен": "Crosshair disabled",
        "Сбросить настройки прицела?": "Reset crosshair settings?",
        "Форма, цвета, размеры и положение вернутся к исходным значениям.": "Shape, colors, sizes, and position will return to their defaults.",
        "Отмена": "Cancel",
        "Сбросить": "Reset",
        "Скрыть прицел": "Hide crosshair",
        "Показать прицел": "Show crosshair",
        "Crosy — прицел включён": "Crosy — crosshair enabled",
        "Crosy — прицел выключен": "Crosy — crosshair disabled",
        "Настройки прицела…": "Crosshair Settings…",
        "Завершить": "Quit",
        "Длина лучей: точное значение": "Line length: exact value",
        "Отступ от центра: точное значение": "Center gap: exact value",
        "Толщина: точное значение": "Thickness: exact value",
        "Радиус кольца: точное значение": "Circle radius: exact value",
        "Размер точки: точное значение": "Dot size: exact value",
        "Обводка: точное значение": "Outline: exact value",
        "Непрозрачность: точное значение": "Opacity: exact value",
        "Смещение вправо: точное значение": "Horizontal offset: exact value",
        "Смещение вверх: точное значение": "Vertical offset: exact value",
    ]
}
