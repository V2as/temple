#!/bin/bash

# Устанавливаем пароль для root пользователя
echo "Введите новый пароль для root пользователя:"
read -s root_password
echo "root:$root_password" | sudo chpasswd

# Добавляем строки в конец файла /etc/ssh/sshd_config
sudo bash -c 'echo "ListenAddress 0.0.0.0" >> /etc/ssh/sshd_config'
sudo bash -c 'echo "ListenAddress ::" >> /etc/ssh/sshd_config'
sudo bash -c 'echo "PermitRootLogin yes" >> /etc/ssh/sshd_config'

# Перезапускаем службу SSH
sudo systemctl restart ssh

echo "Пароль для root пользователя установлен, конфигурация SSH обновлена и служба SSH перезапущена."
