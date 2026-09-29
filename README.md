# SleepToggle

Небольшое приложение для строки меню macOS, которое включает и отключает
спящий режим. Обычное нажатие на значок переключает режим, а нажатие двумя
пальцами на трекпаде или правой кнопкой мыши открывает меню с настройкой
глобального сочетания клавиш и выходом из приложения.

По умолчанию сочетание клавиш не назначено. Чтобы назначить или изменить его,
нажмите значок двумя пальцами или правой кнопкой мыши, выберите «Сменить
сочетание клавиш…», нажмите желаемое сочетание с `Command`, `Option` или
`Control`, затем нажмите «Сохранить».
Настройка сохраняется между запусками. Кнопка «Отключить» в том же окне удаляет
назначенное сочетание.

## Важно

Для изменения настроек сна приложение запускает `pmset` без запроса пароля.
Перед использованием добавьте правило `sudoers`, заменив `YOUR_USERNAME` на
имя своей учётной записи macOS:

```text
YOUR_USERNAME ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
```

Эту строку нельзя запускать как обычную команду. Откройте отдельный файл
`sudoers` безопасным редактором:

```sh
sudo visudo -f /etc/sudoers.d/SleepToggle
```

Вставьте правило, сохраните файл и выйдите из редактора.(если открылся vim - введи :wq)
Имя текущего
пользователя можно узнать командой `whoami`.

Правило разрешает вашей учётной записи только две команды переключения сна
от имени `root` без пароля, для всех источников питания (`-a`). Добавляйте его
только на личном компьютере и только если понимаете последствия.

## Состояние и диагностика

- `☕`: сон отключён (`SleepDisabled 1`), включая сон при закрытии крышки.
- `💤`: обычный сон включён (`SleepDisabled 0` или настройка ещё не записана).
- `❔`: не удалось прочитать системные настройки; нажатие показывает ошибку.

На новом Mac `pmset -g` может не выводить строку `SleepDisabled`, пока эту
настройку не меняли. Версия 1.1 распознаёт это как обычный включённый сон,
если системные настройки успешно прочитаны. Ошибки запуска и неизвестный
вывод по-прежнему считаются ошибками чтения.

После сохранения правила проверьте его, не меняя настройку сна:

```sh
sudo -n -l /usr/bin/pmset -a disablesleep 1
```

При ошибке прав приложение показывает сообщение с выводом `sudo`.
Настройка сна действует на весь Mac и сохраняется после выхода из приложения.
Чтобы вернуть обычный сон, переключите значок с `☕` на `💤`.

## Установка в `/Applications`

1. Установите инструменты командной строки Xcode, если они ещё не установлены:

   ```sh
   xcode-select --install
   ```

2. Перейдите в каталог проекта и запустите установку:

   ```sh
   cd /путь/к/SleepToggle
   ./install.sh
   ```

3. Запустите приложение:

   ```sh
   open /Applications/SleepToggle.app
   ```

Скрипт `install.sh` собирает приложение и копирует его в
`/Applications/SleepToggle.app`. При необходимости macOS запросит пароль
администратора для записи в `/Applications`.

---

# SleepToggle (English)

A small macOS menu bar application that enables and disables sleep mode. You
can toggle it with a primary click on the application icon. A two-finger click
on a trackpad or a right-click opens a menu for configuring a global keyboard
shortcut or quitting the application.

No keyboard shortcut is assigned by default. To assign or change one,
two-finger click or right-click the icon, choose “Сменить сочетание клавиш…”
(“Change Keyboard Shortcut…”), press the desired combination containing
`Command`, `Option`, or `Control`, and click “Сохранить” (“Save”). The setting
persists between launches. The “Отключить” (“Disable”) button in the same
window removes the assigned shortcut.

## Important

The application runs `pmset` without asking for a password in order to change
the sleep settings. Before using it, add the following `sudoers` rule, replacing
`YOUR_USERNAME` with the name of your macOS user account:

```text
YOUR_USERNAME ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
```

Do not run this line as a regular shell command. Open a separate `sudoers` file
with the safe editor instead:

```sh
sudo visudo -f /etc/sudoers.d/SleepToggle
```

Paste the rule, save the file, and exit the editor. You can find your current
username by running `whoami`.

This rule allows only the two sleep toggle commands to run as `root` without
a password, for all power sources (`-a`). Add it only on a personal computer
and only if you understand the security implications.

## State and diagnostics

- `☕`: sleep is disabled (`SleepDisabled 1`), including sleep on lid close.
- `💤`: normal sleep is enabled (`SleepDisabled 0` or an unset flag).
- `❔`: system settings could not be read; clicking shows an error.

On a new Mac, `pmset -g` can omit `SleepDisabled` until the setting has first
been changed. Version 1.1 recognizes this as normal enabled sleep when the
system settings were read successfully. Launch failures and unrecognized
output still count as read errors.

After saving the rule, verify it without changing the sleep setting:

```sh
sudo -n -l /usr/bin/pmset -a disablesleep 1
```

Permission failures now display an alert with the output from `sudo`.
The sleep setting applies to the entire Mac and persists after quitting the app.
To restore normal sleep, toggle the icon from `☕` to `💤`.

## Installation in `/Applications`

1. Install the Xcode Command Line Tools if they are not already installed:

   ```sh
   xcode-select --install
   ```

2. Go to the project directory and run the installation script:

   ```sh
   cd /path/to/SleepToggle
   ./install.sh
   ```

3. Launch the application:

   ```sh
   open /Applications/SleepToggle.app
   ```

The `install.sh` script builds the application and copies it to
`/Applications/SleepToggle.app`. macOS will request an administrator password
if it is required to write to `/Applications`.
