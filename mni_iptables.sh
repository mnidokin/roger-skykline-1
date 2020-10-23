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

#(6)Атакующий IP будет заблокирован на 24 часа
sudo iptables -A INPUT -m recent --name portscan --rcheck --seconds 86400 -j DROP
sudo iptables -A FORWARD -m recent --name portscan --rcheck --seconds 86400 -j DROP

#(7)После 24 часов IP удаляется из базы знаний
sudo iptables -A INPUT -m recent --name portscan --remove
sudo iptables -A FORWARD -m recent --name portscan --remove

#(8)Примитивная защита от сканирования портов
sudo iptables -A INPUT -p TCP -m state --state NEW -m recent --set
sudo iptables -A INPUT -p TCP -m state --state NEW -m recent --update --seconds 1 --hitcount 10 -j DROP

#(9)Защита от отказа в обслуживания - проверка на количество запросов за одну минуту
sudo iptables -I INPUT -p TCP --dport 50683 -i enp0s3 -m state --state NEW -m recent --set
sudo iptables -I INPUT -p TCP --dport 50683 -i enp0s3 -m state --state NEW -m recent --update --seconds 60 --hitcount 15 -j DROP
sudo iptables -I INPUT -p TCP --dport 80 -i enp0s3 -m state --state NEW -m recent --set
sudo iptables -I INPUT -p TCP --dport 80 -i enp0s3 -m state --state NEW -m recent --update --seconds 60 --hitcount 15 -j DROP
sudo iptables -I INPUT -p TCP --dport 443 -i enp0s3 -m state --state NEW -m recent --set
sudo iptables -I INPUT -p TCP --dport 443 -i enp0s3 -m state --state NEW -m recent --update --seconds 60 --hitcount 15 -j DROP
sudo iptables -I INPUT -p TCP --dport 25 -i enp0s3 -m state --state NEW -m recent --set
sudo iptables -I INPUT -p TCP --dport 25 -i enp0s3 -m state --state NEW -m recent --update --seconds 60 --hitcount 15 -j DROP

#(10)Разрешаем пакеты с пометкой - ESTABLISHED
sudo iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -m conntrack ! --ctstate INVALID -j ACCEPT

#(11)Разрешаем работу петлевого интерфейса
sudo iptables -t filter -A INPUT -i lo -j ACCEPT
sudo iptables -t filter -A OUTPUT -o lo -j ACCEPT

#(12)Разрешаем подключение по безопасной оболочке с указанного порта
sudo iptables -A INPUT -p TCP --dport 50683 -j ACCEPT
sudo iptables -A OUTPUT -p TCP --dport 50683 -j ACCEPT

#(13)Разрешаем HTTP
sudo iptables -A INPUT -p TCP --dport 80 -j ACCEPT
sudo iptables -A OUTPUT -p TCP --dport 80 -j ACCEPT

#(14)Разрешаем HTTPS
sudo iptables -A INPUT -p TCP --dport 443 -j ACCEPT
sudo iptables -A OUTPUT -p TCP --dport 443 -j ACCEPT

#(15)Разрешаем SMTP
sudo iptables -t filter -A INPUT -p tcp --dport 25 -j ACCEPT
sudo iptables -t filter -A OUTPUT -p tcp --dport 25 -j ACCEPT

#(16)Остальной входящий трафик не подключаем
sudo iptables -A INPUT -j REJECT

#(17)Разрешаем пинг изнутри и внутрь
sudo iptables -t filter -A INPUT -p icmp -j ACCEPT
sudo iptables -t filter -A OUTPUT -p icmp -j ACCEPT

exit 0

