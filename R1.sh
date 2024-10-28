systemctl stop NetworkManager.service
systemctl stop firewalld.service
# Asignamos las IPs de las interfaces del router de las dos subredes de Dorayaki
# dorayakih
ifconfig enp0s3 192.168.1.1 netmask 255.255.255.0 up
# dorayakis
ifconfig enp0s8 192.168.0.1 netmask 255.255.255.0 up
# pppr1rc
ifconfig enp0s9 192.168.33.253 netmask 255.255.255.252 up

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

# --------- SNAT Y PORT FOWARDING --------- 
# SNAT para las subredes de host y DMZ
iptables -t nat -A POSTROUTING -s 192.168.0.0/24 -o enp0s9 -j SNAT --to 192.168.33.253
iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o enp0s9 -j SNAT --to 192.168.33.253

# REGLAS DE PORT FORWARDING
# Servidor HTTP en la .0.2
iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to 192.168.0.2

# Permitir conexiones entrantes/salientes establecidas
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# ------------- FILTRADO ------------- 
# Permitir reenvio solicitudes ICMP N1-S1
iptables -A FORWARD -p icmp -s 192.168.1.2 -d 192.168.0.2 -j ACCEPT

# Permitir solicitudes DNS de los servidores al servidor DNS de Google
iptables -A FORWARD -s 192.168.0.0/24 -d 8.8.8.8 -p udp --dport 53 -j ACCEPT
iptables -A FORWARD -s 192.168.0.0/24 -d 8.8.8.8 -p tcp --dport 53 -j ACCEPT

# Permitir solicitudes DNS de la Intranet al servidor DNS de Google
iptables -A FORWARD -s 192.168.1.0/24 -d 8.8.8.8 -p udp --dport 53 -j ACCEPT
iptables -A FORWARD -s 192.168.1.0/24 -d 8.8.8.8 -p tcp --dport 53 -j ACCEPT

# Permitir tráfico HTTP a S1
iptables -A FORWARD -d 192.168.0.2 -p tcp --dport 80 -j ACCEPT

# Permitir trafico TCP sobre el puerto 3000 (ntpong) desde hosts de la Intranet
iptables -A INPUT -s 192.168.0.0/24 -p tcp --dport 3000 -j ACCEPT
iptables -A OUTPUT -s 192.168.0.0/24 -p tcp --sport 3000 -j ACCEPT

# Reglas finales
# Los routers no deben aparecer en los traceroute.
iptables -A OUTPUT -p icmp --icmp-type time-exceeded -j DROP

# Bloquear tráfico DMZ-Intranet
iptables -A FORWARD -s 192.168.0.0/24 -d 192.168.1.0/24 -j DROP

# Bloquear tráfico Intranet-DMZ
iptables -A FORWARD -s 192.168.1.0/24 -d 192.168.0.0/24 -j DROP

# Bloquear tráfico DMZ saliente
iptables -A OUTPUT -s 192.168.1.0/24 -j DROP

resolvectl dns enp0s9 8.8.8.8