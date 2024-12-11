# Configuración manual IP para N1
ifconfig enp0s3 192.168.0.10 netmask 255.255.255.128 up

# Añadimos a R1 como router por defecto
route add default gw 192.168.0.1

# Reglas de iptables
iptables -F
# Política drop para todas las cadenas
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Permitir tráfico local
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Permitir tráfico de Swarm Manager
iptables -A INPUT -s 192.168.0.11 -j ACCEPT
iptables -A OUTPUT -d 192.168.0.11 -j ACCEPT
# --------
# Nginx
# -------
# Permitir conexiones Nginx (80, 443) 
iptables -A INPUT -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 80 -m state --state RELATED,ESTABLISHED -j ACCEPT

iptables -A INPUT -p tcp --dport 443 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 443 -m state --state RELATED,ESTABLISHED -j ACCEPT

# --------
# OpenVPN
# -------
# Conexiones 943, 1194 UDP
iptables -A INPUT -p tcp --dport 943 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 943 -m state --state RELATED,ESTABLISHED -j ACCEPT

iptables -A INPUT -p udp --dport 1194 -j ACCEPT
iptables -A OUTPUT -p udp --sport 1194 -j ACCEPT

# Conexiones sobre la interfaz del tunel
iptables -A FORWARD -i tun0 -o enp0s3 -j ACCEPT
iptables -A FORWARD -i eth0 -o enp0s3 -j ACCEPT

# Reiniciar servicio docker
systemctl restart docker