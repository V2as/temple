#!/bin/bash

# === Парсинг аргументов ===
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --repo_url) REPO_URL="$2"; shift ;;
        --db_host) DB_HOST="$2"; shift ;;
        --db_pass) DB_PASS="$2"; shift ;;
        --db_name) DB_NAME="$2"; shift ;;
        --db_user) DB_USER="$2"; shift ;;
        --ip) IP="$2"; shift ;;
        *)
            echo "[ERROR] Неизвестный аргумент: $1"
            echo "Использование: $0 --repo_url <URL> --db_host 1.1.1.1 --db_pass pass --db_name name --db_user user --ip 194.87.215.166"
            exit 1
        ;;
    esac
    shift
done

# === Проверка обязательных аргументов ===
if [[ -z "$REPO_URL" || -z "$DB_HOST" || -z "$DB_PASS" || -z "$DB_NAME" || -z "$DB_USER" || -z "$IP" ]]; then
    echo "[ERROR] Не все обязательные аргументы заданы."
    echo "Использование: $0 --repo_url <URL> --db_host 1.1.1.1 --db_pass pass --db_name name --db_user user --ip 194.87.215.166"
    exit 1
fi

# === Установка Docker (если нет) ===
if ! command -v docker &>/dev/null; then
    echo "[INFO] Docker не найден. Устанавливаю..."
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    echo "[INFO] Docker установлен."
else
    echo "[INFO] Docker уже установлен."
fi

# === Установка Docker Compose (если нет) ===
if ! docker compose version &>/dev/null; then
    echo "[INFO] Docker Compose не найден. Устанавливаю..."
    sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) \
        -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "[INFO] Docker Compose установлен."
else
    echo "[INFO] Docker Compose уже установлен."
fi

# === Настройки ===
INSTALL_DIR="/opt/$(basename "$REPO_URL" .git)"

# === Клонирование репозитория ===
if [ -d "$INSTALL_DIR" ]; then
    echo "[INFO] Папка $INSTALL_DIR уже существует. Обновляю репозиторий..."
    sudo git -C "$INSTALL_DIR" pull
else
    echo "[INFO] Клонирую репозиторий в $INSTALL_DIR..."
    sudo git clone "$REPO_URL" "$INSTALL_DIR" || {
        echo "[ERROR] Не удалось клонировать репозиторий!"
        exit 1
    }
fi

cd "$INSTALL_DIR" || {
    echo "[ERROR] Не удалось перейти в директорию $INSTALL_DIR"
    exit 1
}

# === Создание .env ===
cat > .env <<EOF
DB_HOST="$DB_HOST"
DB_PASS="$DB_PASS"
DB_NAME="$DB_NAME"
DB_USER="$DB_USER"
IP="$IP"
EOF

echo "[INFO] Файл .env создан."

# === Запуск Docker Compose из папки с репозиторием ===
echo "[INFO] Запускаю docker compose в $INSTALL_DIR ..."
docker compose up -d

echo "[INFO] Готово!"
