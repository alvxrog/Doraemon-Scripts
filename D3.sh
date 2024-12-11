# Configuración manual IP para N1
ifconfig enp0s3 192.168.0.11 netmask 255.255.255.128 up

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

# Permitir tráfico de Swarm Manager (TCP)
iptables -A OUTPUT -d 192.168.0.10 -j ACCEPT
iptables -A INPUT -s 192.168.0.10 -j ACCEPT

# Reiniciar servicio docker
systemctl restart docker