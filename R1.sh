systemctl stop NetworkManager.service
systemctl stop firewalld.service

trap 'echo "Error en el comando: $BASH_COMMAND"' ERR

# Asignamos las IPs de las interfaces del router de las dos subredes de Dorayaki
# dorayakih
ifconfig enp0s3 192.168.1.1 netmask 255.255.255.128 up
# dorayakis
ifconfig enp0s8 192.168.0.1 netmask 255.255.255.0 up
# pppr1rc
ifconfig enp0s9 192.168.33.253 netmask 255.255.255.252 up
# dorayakih_s
ifconfig enp0s10 192.168.1.129 netmask 255.255.255.128 up

# Activar encaminamiento de paquetes
# Se puede sustituir añadiendo la linea de configuración al fichero /etc/sysctl.conf
sysctl -w net.ipv4.conf.all.forwarding=1
sysctl -p

# Añadir a RC como router por defecto
route add default gw 192.168.33.254

# Configuración de servicio de DHCP sobre la red de hosts
# Si no está instalado dhcp-server: dnf install dhcp-server
systemctl start dhcpd.service

# Limpiar tablas iptables
iptables -F
iptables -t nat -F

# Denegar todo el tráfico que venga de la enp0s9 (exterior) hacia dentro
iptables -A FORWARD -i enp0s9 -d 192.168.0.0/24 -j DROP
iptables -A FORWARD -i enp0s9 -d 192.168.1.0/24 -j DROP

# --------- SNAT Y PORT FOWARDING --------- 
# SNAT para las subredes de host y DMZ
iptables -t nat -A POSTROUTING -s 192.168.0.0/24 -o enp0s9 -j SNAT --to 192.168.33.253
iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o enp0s9 -j SNAT --to 192.168.33.253

# REGLAS DE PORT FORWARDING
# Permitir conexiones entrantes/salientes establecidas
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Servidor OpenVPN en la .0.10 (D2)
# Forward TCP 443
iptables -t nat -A PREROUTING -p tcp -i enp0s9 -d 192.168.33.253 --dport 443 -j DNAT --to-destination 192.168.0.10:443
iptables -A FORWARD -p tcp -i enp0s9 -d 192.168.0.10 --dport 443 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# Forward UDP 1194
iptables -t nat -A PREROUTING -i enp0s9 -p udp -d 192.168.33.253 --dport 1194 -j DNAT --to-destination 192.168.0.10:1194
iptables -A FORWARD -p udp -i enp0s9 -d 192.168.0.10 --dport 1194 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# Forward TCP 943
iptables -t nat -A PREROUTING -i enp0s9 -p tcp -d 192.168.33.253 --dport 943 -j DNAT --to-destination 192.168.0.10:943
iptables -A FORWARD -i enp0s9 -p tcp -d 192.168.0.10 --dport 943 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# ------------- FILTRADO ------------- 
# --- INTRANET ---
# Peticiones para A1
iptables -A FORWARD -p tcp -d 192.168.1.132 --dport 9392 -j ACCEPT 

# Denegar todo el tráfico del exterior (enp0s9) hacia dentro sobre puertos no permitidos (22, 3000, )
iptables -A INPUT -i enp0s9 -p tcp --dport 22 -j DROP
iptables -A INPUT -i enp0s9 -p tcp --dport 22 -j DROP
iptables -A INPUT -i enp0s9 -p tcp --dport 3000 -j DROP
iptables -A FORWARD -i enp0s9 -p tcp --dport 3000 -j DROP
iptables -A FORWARD -i enp0s9 -p tcp --dport 9090 -j DROP
iptables -A FORWARD -i enp0s9 -p tcp --dport 9090 -j DROP

# Reenviar tramas de la intranet sobre D1 y los puertos de los servicios que hospeda
iptables -A FORWARD -p tcp -s 192.168.1.0/25 -d 192.168.1.131 -m multiport --dports 25,80,443,21,20,110 -j ACCEPT
iptables -A FORWARD -p tcp -s 192.168.1.0/25 -d 192.168.1.131 -m multiport --dports 143,465,587,993,995,3128,4599 -j ACCEPT
iptables -A FORWARD -p tcp -s 192.168.1.0/25 -d 192.168.1.131 -m multiport --dports 4560,4561,4562,4563,4564,8080 -j ACCEPT

# Permitir tráfico de salida HTTP por parte de los hosts de la intranet y del proxy web
iptables -A FORWARD -p tcp -s 192.168.1.0/25 --dport 80 -j ACCEPT
iptables -A FORWARD -p tcp -s 192.168.1.0/25 --dport 443 -j ACCEPT

iptables -A FORWARD -p tcp -s 192.168.1.131 --dport 80 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -p tcp -s 192.168.1.131 --dport 443 -m state --state NEW,ESTABLISHED -j ACCEPT

# Permitir tráfico entrante DNS
iptables -A INPUT -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --sport 53 -j ACCEPT
iptables -A OUTPUT -p udp --sport 53 -j ACCEPT

# Permitir tráfico saliente DNS
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p tcp --sport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT

# Permitir trafico TCP sobre el puerto 3000 (ntpong) desde hosts de la Intranet
iptables -A INPUT -s 192.168.1.0/25 -p tcp --dport 3000 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -s 192.168.1.0/25 -p tcp --sport 3000 -m state --state ESTABLISHED,RELATED -j ACCEPT

# ---  DMZ  ---
# Permitir tráfico HTTP a D2,D3 HTTP(s)
iptables -A FORWARD -d 192.168.0.10 -p tcp --sport 80 -j ACCEPT
iptables -A FORWARD -d 192.168.0.10 -p tcp --sport 443 -j ACCEPT
iptables -A FORWARD -d 192.168.0.10 -p tcp --sport 943 -j ACCEPT

# Permitir tráfico HTTP a K1 solo de la intranet
iptables -A FORWARD -d 192.168.0.5 -s 192.168.1.0/25 -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -s 192.168.0.5 -d 192.168.1.0/25 -p tcp --sport 80 -j ACCEPT

# Reglas finales
# Los routers no deben aparecer en los traceroute.
iptables -A OUTPUT -p icmp --icmp-type time-exceeded -j DROP

# Bloquear tráfico DMZ-Intranet
iptables -A FORWARD -s 192.168.0.0/24 -d 192.168.1.0/24 -j DROP

# Bloquear tráfico Intranet-DMZ
iptables -A FORWARD -s 192.168.1.0/24 -d 192.168.0.0/24 -j DROP

# Bloquear tráfico Intranet hosts-Intranet servers
iptables -A FORWARD -s 192.168.1.0/25 -d 192.168.128.0/25 -j DROP

# Bloquear tráfico Intranet servers-Intranet hosts
iptables -A FORWARD -s 192.168.128.0/25 -d 192.168.1.0/25 -j DROP

# Bloquear tráfico DMZ saliente
iptables -A OUTPUT -s 192.168.0.0/24 -j DROP

resolvectl dns enp0s9 8.8.8.8