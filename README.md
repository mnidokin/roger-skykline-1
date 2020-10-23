# School-21
School 21 Workspace

## roger-skyline-1

- [x] Создать не-суперпользователся для подключения и работы

	```
	apt-get install sudo
	sudo adduser test
	```
- [x] Использовать sudo при работе через пользователя
	
	in /etc/sudoers add `test ALL=(ALL:ALL) ALL`

- [x] **Нельзя использовать DHCP.** Нужно сконфигурировать статический IP по маске \30.

	in /etc/network/interfaces add

	```
	allow-hotplug enp0s8
	iface enp0s8 inet static
	address 192.168.56.2
	netmask 255.255.255.252
	```

- [x] Изменить стандартный порт SSH. Подключение должно происходить с помощью **публичного ключа**. Подключение суперпользователя должно быть запрещено.

	in /etc/ssh/sshd_config change:

	```
	line 13 : Port 50683
	line 32 : PermitRootLogin no
	line 56 : PasswordAuthentication no
	line 57 : PermitEmptyPassword no
	```

	then `sudo service sshd restart` to accept

	on host:

	```
	ssh-keygen -t rsa
	```
	from `~/.ssh`:
	
	```
	ssh-copy-id -i id_rsa.pub mni@192.168.56.2 -p 50683
	```
- [x] Установить правила брандмауэра.
	
	IPTABLES
	
	`sudo apt-get install iptables`

    ```sh
    #!/bin/bash

    #(1)Зачищаем все правила и цепочки
    sudo iptables -F
    sudo iptables -X
    sudo iptables -t nat -F
    sudo iptables -t nat -X
    sudo iptables -t mangle -F
    sudo iptables -t mangle -X
    sudo iptables -P INPUT ACCEPT
    sudo iptables -P FORWARD ACCEPT
    sudo iptables -P OUTPUT ACCEPT

    #(2)Устанавливаем политику по умолчанию - блокировать
    sudo iptables -P INPUT DROP
    sudo iptables -P FORWARD DROP
    sudo iptables -P OUTPUT DROP

    #(3)Все пакеты с значением INVALID - блокировать
    sudo iptables -A INPUT -m state --state INVALID -j DROP
    sudo iptables -A FORWARD -m state --state INVALID -j DROP
    sudo iptables -A OUTPUT -m state --state INVALID -j DROP

    #(4)Защита от флуда пакетами RST
    sudo iptables -A INPUT -p tcp -m tcp --tcp-flags RST RST -m limit --limit 2/second --limit-burst 2 -j ACCEPT

    #(5)Защита от SMURF атаки
    sudo iptables -A INPUT -p icmp -m icmp --icmp-type address-mask-request -j DROP
    sudo iptables -A INPUT -p icmp -m icmp --icmp-type timestamp-request -j DROP

    #(6)Атакующий IP будет заблокирован на 24 часа и удален по истечение этого срока из списка
    sudo iptables -A INPUT -m recent --name portscan --rcheck --seconds 86400 -j DROP
    sudo iptables -A FORWARD -m recent --name portscan --rcheck --seconds 86400 -j DROP
    sudo iptables -A INPUT -m recent --name portscan --remove
    sudo iptables -A FORWARD -m recent --name portscan --remove
    
    #(7)Примитивная защита от сканирования портов
    sudo iptables -A INPUT -p TCP -m state --state NEW -m recent --set
    sudo iptables -A INPUT -p TCP -m state --state NEW -m recent --update --seconds 1 --hitcount 10 -j DROP
    
    #(8)Защита от отказа в обслуживания - проверка на количество запросов за одну минуту
    sudo iptables -I INPUT -p TCP --dport 50683 -i enp0s8 -m state --state NEW -m recent --set
    sudo iptables -I INPUT -p TCP --dport 50683 -i enp0s8 -m state --state NEW -m recent --update --seconds 60 --hitcount 15 -j DROP
    sudo iptables -I INPUT -p TCP --dport 80 -i enp0s3 -m state --state NEW -m recent --set
    sudo iptables -I INPUT -p TCP --dport 80 -i enp0s3 -m state --state NEW -m recent --update --seconds 60 --hitcount 15 -j DROP
    sudo iptables -I INPUT -p TCP --dport 443 -i enp0s3 -m state --state NEW -m recent --set
    sudo iptables -I INPUT -p TCP --dport 443 -i enp0s3 -m state --state NEW -m recent --update --seconds 60 --hitcount 15 -j DROP
    sudo iptables -I INPUT -p TCP --dport 25 -i enp0s3 -m state --state NEW -m recent --set
    sudo iptables -I INPUT -p TCP --dport 25 -i enp0s3 -m state --state NEW -m recent --update --seconds 60 --hitcount 15 -j DROP
    
    #(9)Разрешаем пакеты с пометкой - ESTABLISHED
    sudo iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
    sudo iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
    sudo iptables -A OUTPUT -m conntrack ! --ctstate INVALID -j ACCEPT
    
    #(10)Разрешаем работу петлевого интерфейса
    sudo iptables -t filter -A INPUT -i lo -j ACCEPT
    sudo iptables -t filter -A OUTPUT -o lo -j ACCEPT
    sudo iptables -A INPUT -p TCP --dport 50683 -j ACCEPT
    sudo iptables -A OUTPUT -p TCP --dport 50683 -j ACCEPT
    sudo iptables -A INPUT -p TCP --dport 80 -j ACCEPT
    sudo iptables -A OUTPUT -p TCP --dport 80 -j ACCEPT
    sudo iptables -A INPUT -p TCP --dport 443 -j ACCEPT
    sudo iptables -A OUTPUT -p TCP --dport 443 -j ACCEPT
    sudo iptables -t filter -A INPUT -p tcp --dport 25 -j ACCEPT
    sudo iptables -t filter -A OUTPUT -p tcp --dport 25 -j ACCEPT
    
    #(11)Остальной входящий трафик не подключаем
    sudo iptables -A INPUT -j REJECT
    
    #(12)Разрешаем пинг изнутри и внутрь
    sudo iptables -t filter -A INPUT -p icmp -j ACCEPT
    sudo iptables -t filter -A OUTPUT -p icmp -j ACCEPT
    
    exit 0
```
	move into `~/etc/network/if-pre-up.d/`
	chmod 777 mni_iptables
	sh mni_iptables
	to view rules `sudo iptables -L`
```

- [x] Установить защиту от DOS-атак на открытых портах.
	Fail2Ban
```
	`sudo apt-get install fail2ban`

[DEFAULT]
destemail       = root
banaction       = iptables-multiport
ignoreip        =  192.168.56.2 192.168.56.1

#### правила для SSH ####
[sshd]
enabled         = true
port            = ssh,
filter          = sshd
logpath         = /var/log/auth.log
bantime         = 600
maxretry        = 5
```
- [x] Установить защиту от защиту от прослушки на открытых портах.

	Portsentry

	`sudo apt-get install portsentry`
```
/etc/init.d/portsentry stop

in /etc/default/portsentry
add
	TCP_MODE="atcp"
	UDP_MODE="audp"

in /etc/portsentry/portsentry.conf
change to
	##################
	# Ignore Options #
	##################
	# 0 = Do not block UDP/TCP scans.
	# 1 = Block UDP/TCP scans.
	# 2 = Run external command only (KILL_RUN_CMD)
	
	BLOCK_UDP="1"
	BLOCK_TCP="1"
and
	KILL_ROUTE="/sbin/iptables -I INPUT -s $TARGET$ -j DROP"
to check KILL_ROUTE
	cat portsentry.conf | grep KILL_ROUTE | grep -v "#"

then
	/etc/init.d/portsentry start
```

- [x] Остановать ненужные сервисы.
	
	Проверить запущенные сервисы: `systemctl list-units --type service --state running`

	Остановить ненужные:

```sh
sudo systemctl disable console-setup.service
sudo systemctl disable keyboard-setup.service
sudo systemctl disable apt-daily.timer
sudo systemctl disable apt-daily-upgrade.timer
sudo systemctl disable syslog.service
```

- [x] Написать скрипт, обновляющий пакеты и записыващий изменения в `/var/log/update_script.log`. Расписание для сценария -  **раз в неделю в 4 часа утра** или **при перезагрузке**.

	Sendmail `sudo apt-get install sendmail`
	
	config sendmail `sudo sendmailconfig`
	
	up_date_n_grade.sh	

	```
	sudo apt-get update -y >> /var/log/update_script.log
	sudo apt-get upgrade -y >> /var/log/update_script.log
	```
	
	in /etc/crontab

	```
	0  4    * * 0   root    /home/mni/up_date_n_grade.sh
	@reboot         root    /home/mni/up_date_n_grade.sh

	```
- [x] Написать скрипт для мониторинга изменений в /etc/crontab, при изменении в этом файле отправляется письмо к root. Сценарий - **каждый день в полночь**.

	crontab

```bash
#!/bin/bash

cat /etc/crontab > /home/mni/crontab_save/new

DIFF=$(diff /home/mni/crontab_save/new /home/mni/crontab_save/crontab)

if [ "$DIFF" != "" ]; then
        echo "Crontab has changed, sending mail!"
        sudo sendmail root@localhost < /home/mni/msg/msg_mail.txt
        rm /home/mni/crontab_save/crontab
        mv /home/mni/crontab_save/new /home/mni/crontab_save/crontab
else
        echo "No changes on crontab!"
fi

exit 0
```

in /etc/crontab

```
0  0    * * *   root    /home/mnidokin/test_cron.sh
```


###### Опционально:

- [ ] Установить веб-сервер, доступный по IP виртуальной машины (init.login.com etc.) с помощью Nginx или Apache, установив SSL.

	Установка SSL

	```
	sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -subj "/C=RU/ST=MSC/O=21/OU=roger-skyline-1/CN=192.168.56.2" -keyout /etc/ssl/private/apache-selfsigned.key -out /etc/ssl/certs/apache-selfsigned.crt
	```

	in file `/etc/apache2/conf-available/ssl-params.conf`

	```
	SSLCipherSuite EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH
	SSLProtocol All -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
	SSLHonorCipherOrder On
	
	Header always set X-Frame-Options DENY
	Header always set X-Content-Type-Options nosniff

	SSLCompression off
	SSLUseStapling on
	SSLStaplingCache "shmcb:logs/stapling-cache(150000)"
	
	SSLSessionTickets Off
	```

	in file `/etc/apache2/sites-available/default-ssl.conf`

	```
	<IfModule mod_ssl.c>
		<VirtualHost _default_:443>
			ServerAdmin 0512209@gmail.com
			ServerName	192.168.56.2

			DocumentRoot /var/www/html

			ErrorLog ${APACHE_LOG_DIR}/error.log
			CustomLog ${APACHE_LOG_DIR}/access.log combined

			SSLEngine on

			SSLCertificateFile	/etc/ssl/certs/apache-selfsigned.crt
			SSLCertificateKeyFile /etc/ssl/private/apache-selfsigned.key

			<FilesMatch "\.(cgi|shtml|phtml|php)$">
					SSLOptions +StdEnvVars
			</FilesMatch>
			<Directory /usr/lib/cgi-bin>
					SSLOptions +StdEnvVars
			</Directory>

		</VirtualHost>
	</IfModule>
	```

	in file `/etc/apache2/sites-available/000-default.conf`

	```
	<VirtualHost *:80>

		ServerAdmin webmaster@localhost
		DocumentRoot /var/www/html

		Redirect "/" "https://192.168.56.2/"

		ErrorLog ${APACHE_LOG_DIR}/error.log
		CustomLog ${APACHE_LOG_DIR}/access.log combined

	</VirtualHost>
	```

	to enable apache2

	```
	sudo a2enmod ssl
	sudo a2enmod headers
	sudo a2ensite default-ssl
	sudo a2enconf ssl-params
	systemctl reload apache2
	```
	
	##### Auto-deployment
