#!/bin/bash

# ==========================================
# [ ВАЖНОЕ ПРЕДУПРЕЖДЕНИЕ ГЕНИЯ ]
# !!! ЭТО ДЕСТРУКТИВНЫЙ СКРИПТ! ЗАПУСК ТОЛЬКО НА ТЕСТЕ!!! 
# Выполняет операции, которые стирают данные на указанных дисках.
# ==========================================

# --- [ 1. ПРОВЕРКА АРГУМЕНТОВ ВВОДА ] ---
if [ "$#" -ne 2 ]; then
    echo "Ошибка! Неправильный формат вызова."
    echo "Использование: $0 <Количество_Дисков> <RAID_Уровень>"
    echo "Доступные уровни: raid0 (striping), raid5 (parity)."
    echo "Пример: $0 3 raid5"
    exit 1
fi

DISK_COUNT=$1          # Первый аргумент: Количество дисков
RAID_LEVEL=$(echo "$2" | tr '[:upper:]' '[:lower:]') # Второй аргумент: Уровень RAID (raid0 или raid5)

# --- [ 2. ВАЛИДАЦИЯ ] ---
if ! [[ $DISK_COUNT =~ ^[1-9][0-9]*$ ]]; then
    echo "Ошибка: Количество дисков должно быть положительным числом."
    exit 1
fi

case "$RAID_LEVEL" in
    raid0|raid5) : ;; # Если уровень в списке, продолжаем
    *) echo "Ошибка: Неизвестный RAID уровень '$2'. Используйте 'raid0' или 'raid5'." ; exit 1 ;;
esac


# --- [ 3. ПОДГОТОВКА УСТРОЙСТВ ] ---

DISK_DEVICES=()
for i in $(seq 1 $DISK_COUNT); do
    # Предполагаем, что устройства начинаются с sdb и идут подряд!
    DEVICE="/dev/sd${i}b" 
    if [ -b "$DEVICE" ]; then
        DISK_DEVICES+=("$DEVICE")
    else
        echo "Критическая Ошибка: Устройство $DEVICE не найдено или нет блочного устройства. Проверьте подключения!"
        exit 1
    fi
done

# Генерируем имя массива, чтобы оно было уникальным (например /dev/md5)
RAID_DEVICE="/dev/md$(($RANDOM % 8 + 2))" 
echo "============================================="
echo " Начинаем процесс RAID-массива: $RAID_LEVEL (${DISK_COUNT} дисков)"
echo "Устройства: ${DISK_DEVICES[*]}"
echo "Целевой массив: $RAID_DEVICE"
echo "=============================================\n";

# --- [ 4. СОЗДАНИЕ МАССИВА mdadm ] ---

echo -e "\n--- ЭТАП 1: Создание массива ---\n"

case "$RAID_LEVEL" in
    raid0) # Striping (Самый быстрый, но нет отказоустойчивости!)
        mdadm --create "$RAID_DEVICE" --level=raid0 --raid-devices=$DISK_COUNT "${DISK_DEVICES[@]}"
        ;;
    raid5) # Parity (Отличный баланс производительности и избыточности)
        # Проверка: RAID5 требует минимум 3 диска.
        if [ "$DISK_COUNT" -lt 3 ]; then
            echo "Ошибка! Для RAID5 необходимо минимум 3 диска."
            exit 1
        fi
        mdadm --create "$RAID_DEVICE" --level=raid5 --raid-devices=$DISK_COUNT "${DISK_DEVICES[@]}"
        ;;
esac

if [ $? -ne 0 ]; then
    echo "КРАХ! Ошибка при создании массива mdadm. Проверьте права (root) и состояние дисков!"
    exit 1
fi


# --- [ 5. КОНФИГУРАЦИЯ СИСТЕМЫ ] ---

echo -e "\n--- ЭТАП 2: Конфигурация системы ---\n"

# Сохранение конфигурации в mdadm.conf (для восстановления!)
if ! mdadm --detail --scan --verbose | tee -a /etc/mdadm.conf; then
    echo "Предупреждение: Не удалось сохранить данные в /etc/mdadm.conf."
fi

# Форматирование файловой системы
echo "Форматируем новый RAID-массив $RAID_DEVICE как ext4..."
mkfs.ext4 -F "$RAID_DEVICE" || { echo "Ошибка форматирования!"; exit 1; }

# Создание точки монтирования и обновление fstab
MOUNT_POINT="/raid" # Используем фиксированный, но заданный пользователем путь для чистоты.
mkdir -p "$MOUNT_POINT"

echo "${RAID_DEVICE}    ${MOUNT_POINT}    ext4    defaults    0    0" >> /etc/fstab
echo "Настройки /etc/fstab обновлены."


# --- [ 6. ТЕСТ И ЗАВЕРШЕНИЕ ] ---
echo -e "\n---  ЭТАП 3: Монтирование и тест ---\n"

mount -a # Пытаемся смонтировать ВСЁ (включая наш RAID)

if mountpoint -q "$MOUNT_POINT"; then
    echo "УСПЕХ! Массив ${RAID_DEVICE} успешно создан, отформатирован и смонтирован в $MOUNT_POINT."
else
    echo "Критика: Не удалось смонтировать массив. Проверьте права пользователя (root) и /etc/fstab вручную!"
fi

exit 0
