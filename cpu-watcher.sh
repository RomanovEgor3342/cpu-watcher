#!/bin/bash

while true; do
    clear

    max_cpu=0
    PID=1

    while read -r user pid cpu _; do
        cpu_val=${cpu%.*} 
        if (( $(echo "$cpu > $max_cpu" | bc -l) )); then
            max_cpu=$cpu
            PID=$pid
        fi
    done < <(ps -eo user,pid,%cpu --no-headers)


    if [ ! -d "/proc/$PID" ]; then
        continue
    fi

    echo "Информация о процессе PID: $PID\n-----------------------------"

    echo "Имя процесса: $(cat "/proc/$PID/comm" 2>/dev/null)"

    echo -n "Командная строка: "
    tr '\0' ' ' < "/proc/$PID/cmdline" 2>/dev/null
    echo

    echo "Статус процесса:"
    awk '/^Pid|^PPid|^Uid|^State|^Threads/ {print "  " $0}' "/proc/$PID/status" 2>/dev/null

    echo "Статистика процесса (stat):"
    awk '{print "  cstime="$17 "\n  priority="$18, "\n  nice="$19, "\n  num_threads="$20, "\n  starttime="$22}' "/proc/$PID/stat" 2>/dev/null

    if [ -f "/proc/$PID/statm" ]; then
        read size resident shared text lib data dt < "/proc/$PID/statm"
        page_size=$(getconf PAGE_SIZE)

        size_mb=$(( size * page_size / 1048576 ))
        resident_mb=$(( resident * page_size / 1048576 ))
        shared_mb=$(( shared * page_size / 1048576 ))
        text_mb=$(( text * page_size / 1048576 ))
        data_mb=$(( data * page_size / 1048576 ))

        echo "Использование памяти процессом:"
        printf "  Общая виртуальная память (size):       %d страниц = %d MiB\n" "$size" "$size_mb"
        printf "  Резидентная память (resident):         %d страниц = %d MiB\n" "$resident" "$resident_mb"
        printf "  Общая разделяемая память (shared):     %d страниц = %d MiB\n" "$shared" "$shared_mb"
        printf "  Код (text):                            %d страниц = %d MiB\n" "$text" "$text_mb"
        printf "  Данные (data):                         %d страниц = %d MiB\n" "$data" "$data_mb"
    fi

    echo "Количество открытых файловых дескрипторов: $(ls "/proc/$PID/fd" | wc -l)" 2>/dev/null

    echo "Ограничения ресурсов:"
    awk '{print "  " $0}' "/proc/$PID/limits" 2>/dev/null

    echo "Окружение процесса:"
    tr '\0' '\n' < "/proc/$PID/environ" 2>/dev/null |
    grep -E '^(USER|HOME|PATH|LANG|SHELL|PWD|SSH_AUTH_SOCK|DESKTOP_SESSION|GDMSESSION|SYSTEMD_EXEC_PID)=' |
    awk '{print "  " $0}'


    echo "Информация о планировании процесса PID=$PID:"
    echo "  Политика планирования: $(grep '^policy' "/proc/$PID/sched" 2>/dev/null | awk '{print $NF}')"
    echo "  Приоритет: $(grep '^prio' "/proc/$PID/sched" 2>/dev/null | awk '{print $NF}')"
    echo "  Время выполнения (сек): $(grep '^se.sum_exec_runtime' "/proc/$PID/sched" 2>/dev/null | awk '{print $NF/1000000}')"
    echo "  Всего переключений: $(grep '^nr_switches' "/proc/$PID/sched" 2>/dev/null | awk '{print $NF}')"

    sleep 5
done
