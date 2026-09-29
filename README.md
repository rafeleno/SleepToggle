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

## Одно закрытие крышки

Каждое включение (`☕`) действует на один цикл крышки:

1. Включите SleepToggle, пока крышка открыта. Сон отключится сразу.
2. Закройте крышку — Mac продолжит работать.
3. Откройте крышку — SleepToggle автоматически включит обычный сон (`💤`).
4. При следующем закрытии Mac снова сможет уйти в сон по обычным правилам macOS.

Открытая крышка до первого закрытия не отменяет режим. Если включить режим,
когда крышка уже закрыта (например, с внешним экраном), он закончится при её
открытии. Повторное нажатие значка или горячей клавиши отменяет режим вручную.
При обычном выходе SleepToggle также возвращает сон; если восстановление не
удалось, приложение покажет сообщение и отменит выход.

Для автоматического завершения приложение должно быть запущено. Этап цикла
сохраняется: если приложение перезапустилось после замеченного закрытия,
открытая крышка завершит режим. Если приложение принудительно завершили ещё
до закрытия, оно не может узнать о закрытии и открытии, случившихся без него.

Если датчик крышки недоступен, режим не включается. Если после открытия крышки
возникает ошибка прав `pmset`, приложение сообщает об этом и повторяет попытки;
оно не показывает режим как завершённый до подтверждения изменения.

## Проверка разработки

```sh
./test.sh
./build.sh
```

`test.sh` проверяет переходы цикла, отмену, восстановление сохранённого этапа,
повторные события и формат уведомлений крышки. Он не изменяет настройки сна.
Для проверки настоящего датчика без изменения сна:

```sh
SLEEP_TOGGLE_LIVE_SENSOR_CHECK=1 ./test.sh
```

Физический сценарий проверяется отдельно: включение → закрытие → открытие →
`pmset -g` с `SleepDisabled 0` → следующее закрытие с обычным сном.

## Важно

Для изменения настроек сна приложение запускает `pmset` без запроса пароля.
Перед использованием добавьте правило `sudoers`, заменив `YOUR_USERNAME` на
имя своей учётной записи macOS:

```text
YOUR_USERNAME ALL=(root) NOPASSWD: /usr/bin/pmset
```

Эту строку нельзя запускать как обычную команду. Откройте отдельный файл
`sudoers` безопасным редактором:

```sh
sudo visudo -f /etc/sudoers.d/SleepToggle
```

Вставьте правило, сохраните файл и выйдите из редактора.(если открылся vim - введи :wq)
Имя текущего
пользователя можно узнать командой `whoami`.

Правило разрешает вашей учётной записи запускать `/usr/bin/pmset` от имени
`root` без пароля. Добавляйте его только на личном компьютере и только если
понимаете последствия.

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

## One lid-close cycle

Each activation (`☕`) applies to one lid cycle:

1. Activate SleepToggle with the lid open. Sleep is disabled immediately.
2. Close the lid — the Mac keeps running.
3. Open the lid — SleepToggle automatically restores normal sleep (`💤`).
4. The next lid close can put the Mac to sleep under normal macOS rules.

An open lid before the first close does not cancel the mode. Activating while
the lid is already closed (for example, with an external display) lasts until
the lid opens. Clicking or using the hotkey again cancels the mode manually.
A normal quit also restores sleep; if restoration fails, the app displays an
error and cancels quitting.

The app must be running for automatic completion. The cycle phase is saved:
if the app restarts after observing a close, an open lid ends the mode. If the
app was force-quit before the close, it cannot detect a complete close/open
cycle that happened while it was absent.

If the lid sensor is unavailable, the mode is not activated. A `pmset`
permission failure on reopening displays an error and is retried. The mode is
only marked complete after the setting change is confirmed.

## Development checks

```sh
./test.sh
./build.sh
```

`test.sh` checks cycle transitions, cancellation, saved phase recovery,
repeated events and the lid notification format. It does not change sleep.
To check the actual sensor without changing sleep:

```sh
SLEEP_TOGGLE_LIVE_SENSOR_CHECK=1 ./test.sh
```

Test the physical scenario separately: activate → close → open → `pmset -g`
with `SleepDisabled 0` → next close with normal sleep.

## Important

The application runs `pmset` without asking for a password in order to change
the sleep settings. Before using it, add the following `sudoers` rule, replacing
`YOUR_USERNAME` with the name of your macOS user account:

```text
YOUR_USERNAME ALL=(root) NOPASSWD: /usr/bin/pmset
```

Do not run this line as a regular shell command. Open a separate `sudoers` file
with the safe editor instead:

```sh
sudo visudo -f /etc/sudoers.d/SleepToggle
```

Paste the rule, save the file, and exit the editor. You can find your current
username by running `whoami`.

This rule allows your user account to run `/usr/bin/pmset` as `root` without a
password. Add it only on a personal computer and only if you understand the
security implications.

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
