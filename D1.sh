# Configuración manual IP para N1
ifconfig enp0s3 192.168.1.131 netmask 255.255.255.128 up

# Añadimos a R1 como router por defecto
route add default gw 192.168.1.129

# Política drop para todas las cadenas
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Permitir tráfico local
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Reglas para los servicios de Docker
# --------
# PROFTPD
# -------
# Permitir conexiones entrantes desde hosts de la intranet para servir el contenido FTP
iptables -A INPUT  -p tcp -m tcp -s 192.168.1.0/25 --dport 21 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp -m tcp -d 192.168.1.0/25 --sport 21 -m state --state ESTABLISHED -j ACCEPT 

# Permitir conexiones en modo activo
iptables -A OUTPUT -p tcp -m tcp -d 192.168.1.0/25 --sport 20 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT  -p tcp -m tcp -s 192.168.1.0/25 --dport 20 -m state --state ESTABLISHED -j ACCEPT 

# Permitir conexiones en modo pasivo (rango 4599-4564)
iptables -A OUTPUT -p tcp -m tcp -d 192.168.1.0/25 --sport 4559:4564 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT  -p tcp -m tcp -s 192.168.1.0/25 --dport 4559:4564 -m state --state ESTABLISHED -j ACCEPT 
# --------
# NAGIOS
# -------
# Permitir conexiones solo para los PCs administradores (192.168.1.100)
iptables -P INPUT -p tcp -s 192.168.1.100 --dport 8080 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp -d 192.168.1.100 --sport 8080 -m state --state ESTABLISHED -j ACCEPT

# Reiniciar servicio de Docker
systemctl restart docker