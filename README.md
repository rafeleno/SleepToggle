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

## Ветки и текущая сборка

Текущая ветка: `test/combined-sleep-toggle`. Версия в `Info.plist`: **1.2**.

| Ветка | Версия | Содержание |
|---|---|---|
| [`main`](https://github.com/rafeleno/SleepToggle/tree/main) | 1.0 | Исходный постоянный режим |
| [`fix/macos-sleep-state`](https://github.com/rafeleno/SleepToggle/tree/fix/macos-sleep-state) | 1.1 | Исправление чтения SleepDisabled и сообщений об ошибках |
| [`feat/one-lid-session`](https://github.com/rafeleno/SleepToggle/tree/feat/one-lid-session) | 1.0 | Один цикл крышки от исходной базы; без исправления чтения |
| [`test/combined-sleep-toggle`](https://github.com/rafeleno/SleepToggle/tree/test/combined-sleep-toggle) | 1.2 | Объединённая тестовая сборка: исправление и один цикл |

Исходная база кода — коммит `757687c`. Исправление и фича созданы в
независимых ветках; объединённая ветка содержит оба изменения. Для проверки
обоих изменений используйте `test/combined-sleep-toggle`.

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

Сессию нового режима создаёт включение через значок или горячую клавишу.
Если сон был отключён старой постоянной версией или другой программой,
после перехода сначала верните `💤`, затем включите `☕` заново: это начнёт
отдельный цикл крышки. `install.sh` сам не переносит старый постоянный режим.

## Проверка разработки

```sh
./test.sh
./build.sh
```

`test.sh` проверяет чтение состояния сна, переходы цикла, отмену, восстановление сохранённого этапа,
повторные события и формат уведомлений крышки. Он не изменяет настройки сна.
Для проверки настоящего датчика без изменения сна:

```sh
SLEEP_TOGGLE_LIVE_SENSOR_CHECK=1 ./test.sh
```

Автоматические проверки не заменяют тест реальной крышки.
Физический сценарий проверяется отдельно: включение → закрытие → открытие →
`pmset -g` с `SleepDisabled 0` → следующее закрытие с обычным сном.

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

Вставьте правило, сохраните файл и выйдите из редактора. В Vim нажмите
`Esc`, введите `:wq` и нажмите Enter. `YOUR_USERNAME` замените результатом
`whoami` (например, `rafeleno`). Затем проверьте права файла и правило:

```sh
sudo chmod 0440 /etc/sudoers.d/SleepToggle
sudo visudo -c
sudo -n -l /usr/bin/pmset -a disablesleep 0
sudo -n -l /usr/bin/pmset -a disablesleep 1
```

Проверки `-l` только показывают разрешённые команды и не меняют сон.
`-n` запрещает интерактивный запрос пароля; `-a` применяет настройку для
батареи и адаптера питания. `disablesleep 1` отключает сон, `0` возвращает его.
Скрипт установки не создаёт правило `sudoers` автоматически.

Правило разрешает вашей учётной записи только две команды переключения сна
от имени `root` без пароля, для всех источников питания (`-a`). Добавляйте его
только на личном компьютере и только если понимаете последствия.

## Тестовая сборка 1.2

Эта сборка объединяет исправленное чтение состояния сна на новом Mac и режим
на один цикл закрытия/открытия крышки. Сообщения об ошибках сохранены; при
автоматических повторных попытках приложение показывает сообщение один раз.

## Состояние и диагностика

- `☕`: сон отключён (`SleepDisabled 1`), включая сон при закрытии крышки.
- `💤`: обычный сон включён (`SleepDisabled 0` или настройка ещё не записана).
- `❔`: не удалось прочитать системные настройки; нажатие показывает ошибку.

На новом Mac `pmset -g` может не выводить строку `SleepDisabled`, пока эту
настройку не меняли. Эта сборка распознаёт это как обычный включённый сон,
если системные настройки успешно прочитаны. Ошибки запуска и неизвестный
вывод по-прежнему считаются ошибками чтения.

После сохранения правила проверьте его, не меняя настройку сна:

```sh
sudo -n -l /usr/bin/pmset -a disablesleep 1
```

При ошибке прав приложение показывает сообщение с выводом `sudo`.
Настройка сна действует на весь Mac. Обычный выход из приложения завершает
его активную сессию и возвращает сон. Ручная отмена: переключите `☕` на `💤`.

## Установка в `/Applications`

Для новой копии репозитория выберите именно эту ветку:

```sh
git clone --branch test/combined-sleep-toggle https://github.com/rafeleno/SleepToggle.git SleepToggle
cd SleepToggle
```

Если репозиторий уже есть, перейдите в его каталог и выберите ветку:

```sh
git fetch origin
git switch test/combined-sleep-toggle
```

Перед переустановкой переведите запущенный SleepToggle в `💤`, затем выберите
«Выйти из SleepToggle» в меню правого клика.


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

## Branches and this build

Current branch: `test/combined-sleep-toggle`. Bundle version: **1.2**.

| Branch | Version | Contents |
|---|---|---|
| [`main`](https://github.com/rafeleno/SleepToggle/tree/main) | 1.0 | Original persistent mode |
| [`fix/macos-sleep-state`](https://github.com/rafeleno/SleepToggle/tree/fix/macos-sleep-state) | 1.1 | SleepDisabled parsing fix and visible toggle errors |
| [`feat/one-lid-session`](https://github.com/rafeleno/SleepToggle/tree/feat/one-lid-session) | 1.0 | One lid cycle from the original base; without the parsing fix |
| [`test/combined-sleep-toggle`](https://github.com/rafeleno/SleepToggle/tree/test/combined-sleep-toggle) | 1.2 | Combined test build: parsing fix and one lid cycle |

The original code base is commit `757687c`. The fix and feature were created
as independent branches; the combined branch merges both. For trying both
changes, use `test/combined-sleep-toggle`.

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

Activating via the icon or hotkey creates the new session. If sleep was
already disabled by the old persistent version or another app, switch to
`💤` first, then activate `☕` again to start a fresh lid cycle. `install.sh`
does not migrate an old persistent mode automatically.

## Development checks

```sh
./test.sh
./build.sh
```

`test.sh` checks sleep-state parsing, cycle transitions, cancellation, saved phase recovery,
repeated events and the lid notification format. It does not change sleep.
To check the actual sensor without changing sleep:

```sh
SLEEP_TOGGLE_LIVE_SENSOR_CHECK=1 ./test.sh
```

Automated checks do not replace a real lid test.
Test the physical scenario separately: activate → close → open → `pmset -g`
with `SleepDisabled 0` → next close with normal sleep.

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

Paste the rule, save the file, and exit the editor. In Vim, press `Esc`, type
`:wq`, and press Enter. Replace `YOUR_USERNAME` with the output of `whoami`
(for example, `rafeleno`). Then validate file permissions and the rule:

```sh
sudo chmod 0440 /etc/sudoers.d/SleepToggle
sudo visudo -c
sudo -n -l /usr/bin/pmset -a disablesleep 0
sudo -n -l /usr/bin/pmset -a disablesleep 1
```

The `-l` checks list allowed commands without changing sleep. `-n` prevents
an interactive password prompt; `-a` applies the setting to battery and AC
power. `disablesleep 1` disables sleep; `0` restores it. The installation
script does not create the `sudoers` rule automatically.

This rule allows only the two sleep toggle commands to run as `root` without
a password, for all power sources (`-a`). Add it only on a personal computer
and only if you understand the security implications.

## Test build 1.2

This build combines the new-Mac sleep-state fix with the single lid-close/open
cycle. Error details are preserved; automatic restoration retries display an
alert only once.

## State and diagnostics

- `☕`: sleep is disabled (`SleepDisabled 1`), including sleep on lid close.
- `💤`: normal sleep is enabled (`SleepDisabled 0` or an unset flag).
- `❔`: system settings could not be read; clicking shows an error.

On a new Mac, `pmset -g` can omit `SleepDisabled` until the setting has first
been changed. This build recognizes this as normal enabled sleep when the
system settings were read successfully. Launch failures and unrecognized
output still count as read errors.

After saving the rule, verify it without changing the sleep setting:

```sh
sudo -n -l /usr/bin/pmset -a disablesleep 1
```

Permission failures now display an alert with the output from `sudo`.
The sleep setting applies to the entire Mac. A normal quit ends the active
session and restores sleep. To cancel manually, toggle `☕` back to `💤`.

## Installation in `/Applications`

For a fresh checkout, select this branch:

```sh
git clone --branch test/combined-sleep-toggle https://github.com/rafeleno/SleepToggle.git SleepToggle
cd SleepToggle
```

For an existing checkout, enter its directory and select the branch:

```sh
git fetch origin
git switch test/combined-sleep-toggle
```

Before reinstalling, switch the running SleepToggle to `💤`, then choose
“Выйти из SleepToggle” (“Quit”) from its right-click menu.


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
