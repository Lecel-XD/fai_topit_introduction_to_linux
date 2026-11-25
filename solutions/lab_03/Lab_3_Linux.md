# ПРАКТИЧЕСКАЯ РАБОТА №3

**Дисциплина:** «Введение в OC Linux»
**Тема:** Подсистема безопасности Linux: пользователи, права, SSH, процессы

**Выполнила:** Гейко Валерия Игоревна
**Проверил:** Береснев Артем Дмитриевич

**Дата**: 16.11.2026
**Санкт-Петербург 2026**

---
# Артефакты

## Часть 1

Вывод sshd \-T:
```bash
permitrootlogin yes
maxauthtries 2
logingracetime 30
```

Вывод who:
```bash
root     sshd pts/1   2026-11-18 12:40 (10.0.2.2)
gvi-1    sshd pts/0   2026-11-18 12:37 (10.0.2.2)
lecel    seat0        2026-11-18 12:00
lecel    tty1         2026-11-18 12:00
```

Вывод ss:
```bash
State Recv-Q Send-Q Local Address:Port Peer Address:Port Process                                                               
ESTAB 0      0          10.0.2.15:2079     10.0.2.2:51740 users:(("sshd-session",pid=845,fd=7),("sshd-session",pid=822,fd=7))
ESTAB 0      0          10.0.2.15:2079     10.0.2.2:49374 users:(("sshd-session",pid=893,fd=7),("sshd-session",pid=885,fd=7))

```

Команды scp:
```bash
scp -P 9041 Downloads/02_BASH_и_работа_с_оборудованием22.pdf gvi-1@127.0.0.1:~/
scp -P 9041 lecel@127.0.0.1:~/script_passport.sh Downloads/
```

---
## Часть 2

Скрипт script31:
```bash
#!/bin/bash

checks() {
	if (( EUID != 0 )); then
		echo "[ERROR] Permission denied." >&2
		exit 1
	fi
	if [ "$#" -ne 2 ]; then
		echo "[ERROR] Expected 2 arguments, got $#." >&2
		exit 1
	fi
	for arg in "$@"; do
		if ! [[ "$arg" =~ ^[0-9]+$ ]]; then
			echo "[ERROR] $arg is not an integer" >&2
			exit 1
		fi
	done
}

checks "$@"

start=$2
amount=$1

for (( i=start; i<start+amount; i++ )); do
	username="u$i"
	password="DerParol$i"
	if id $username &>/dev/null; then
		echo "User $username already exists. Skipping..."
		continue
	fi
	if useradd -m -s /bin/bash "$username"; then
		echo "$username:$password" | chpasswd
		echo "Success. User $username had been created."
	else
		echo "[ERROR] couldn't create $username." >&2
	fi
done
```

Вывод id:
```bash
id u1 u2     # команда

uid=1002(u1) gid=1002(u1) groups=1002(u1),1007(project),1008(task3-3_admin)
uid=1003(u2) gid=1003(u2) groups=1003(u2),1007(project)
```

Фрагмент /etc/passwd:
```bash
lecel:x:1000:1000:Valeria,,,:/home/lecel:/bin/bash
gvi-1:x:1001:1001:valeria,,,:/home/gvi-1:/bin/bash
u1:x:1002:1002::/home/u1:/bin/bash
u2:x:1003:1003::/home/u2:/bin/bash
u3:x:1004:1004::/home/u3:/bin/bash
u4:x:1005:1005::/home/u4:/bin/bash
u5:x:1006:1006::/home/u5:/bin/bash
```

Фрагмент /etc/group:
```bash
lecel:x:1000:
gvi-1:x:1001:
u1:x:1002:
u2:x:1003:
u3:x:1004:
u4:x:1005:
u5:x:1006:
project:x:1007:u1,u2,u3
task3-3_admin:x:1008:u1
task3-3_group:x:1009:u4,u5
```

## Часть 3

Вывод прав всех созданных каталогов и файлов:
```bash
/DATA:
total 16
-rw-rw-r-- 1 u3   u3               4 Nov 11 22:32 example.txt
drwxrwxrwt 2 root root          4096 Nov 13 14:51 sec1
drwxr-x--- 2 u1   task3-3_group 4096 Nov 11 23:58 sec2
drwxr-xr-x 2 root root          4096 Nov 11 23:35 sec3

/DATA/sec1:
total 8
-rw-rw-r-- 1 u1 u1 4 Nov 11 23:13 u1
-rw-rw-r-- 1 u3 u3 4 Nov 11 23:12 u3

/DATA/sec2:
total 8
-rw-rw-r-- 1 u1 u1 5 Nov 11 23:42 e2
-rw-rw-r-- 1 u1 u3 3 Nov 11 23:58 ex2

/DATA/sec3:
total 300
-rwsr-xr-x 1 u1 root 303960 Nov 11 23:35 nano
permitrootlogin no
maxauthtries 2
logingracetime 30
```

## Часть 4

Изменённые параметры sshd:
```bash
permitrootlogin no
pubkeyauthentication yes
authorizedkeysfile .ssh/authorized\_keys
passwordauthentication no
```

Команды ssh и scp с ключом:
```bash
ssh -p 9041 lecel@127.0.0.1

scp -P 9041 -i ~/.ssh/id_ed25519 lecel@127.0.0.1:~/scripts/script31.sh /home/lecel/scripts/
```

## Часть 5

Файл /etc/sudoers.d/u1:
```bash
u1 ALL=(root) /usr/bin/passwd, !/usr/bin/passwd root, !/usr/bin/passwd 0
```