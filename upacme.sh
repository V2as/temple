#!/bin/sh

# Дублирует время исполнения первой задачи crontab и добавляет новую задачу с этим временем.
# Если в crontab > 1 заполненной строки — ничего не добавляем.

set -eu

# Команда, которую нужно вставить (копируем как есть)
NEW_CMD='sudo bash -c "$(curl -sL https://raw.githubusercontent.com/V2as/SauceScripts/main/sauceban.sh)" @ restart'

# Получаем текущий crontab (если его нет — пустая строка)
CURRENT=$(crontab -l 2>/dev/null || true)

# Оставляем только непустые и не-комментированные строки
PLAIN_LINES=$(printf '%s\n' "$CURRENT" | awk '!/^[[:space:]]*#/ && !/^[[:space:]]*$/ {print}')

# Считаем количество заполненных строк
COUNT=$(printf '%s\n' "$PLAIN_LINES" | grep -c . || true)

if [ "$COUNT" -gt 1 ]; then
  echo "В crontab больше одной заполненной строки ($COUNT). Ничего не добавляю."
  exit 0
fi

if [ "$COUNT" -eq 0 ]; then
  echo "В crontab нет заполненных строк. Нечего дублировать."
  exit 1
fi

# Берём первую (и единственную) заполненную строку
FIRST_LINE=$(printf '%s\n' "$PLAIN_LINES" | sed -n '1p')

# Определяем расписание: либо @-метка (например @reboot), либо первые 5 полей
case "$FIRST_LINE" in
  [[:space:]]*@*)
    SCHEDULE=$(printf '%s\n' "$FIRST_LINE" | awk '{print $1}')
    ;;
  *)
    # берём первые 5 полей как расписание
    # (если строка короче — awk выдаст что есть; это обычный cron случай)
    SCHEDULE=$(printf '%s\n' "$FIRST_LINE" | awk '{printf "%s %s %s %s %s", $1,$2,$3,$4,$5}')
    ;;
esac

# Собираем новую строку
NEW_LINE="$SCHEDULE $NEW_CMD"

# Проверяем, не существует ли уже точно такой строки в crontab (чтобы не дублировать)
if printf '%s\n' "$CURRENT" | grep -F -x -q "$NEW_LINE"; then
  echo "Такая строка уже присутствует в crontab. Ничего не делаю."
  exit 0
fi

# Записываем новый crontab: оригинал + новая строка
TMP=$(mktemp /tmp/cronXXXXXX) || exit 1
printf '%s\n' "$CURRENT" > "$TMP"
# Если файл не заканчивается переводом строки — добавим
printf '\n' >> "$TMP"
printf '%s\n' "$NEW_LINE" >> "$TMP"

# Устанавливаем crontab
if crontab "$TMP"; then
  echo "Добавлена новая задача:"
  echo "$NEW_LINE"
  rm -f "$TMP"
  exit 0
else
  echo "Ошибка при установке crontab" >&2
  rm -f "$TMP"
  exit 2
fi
