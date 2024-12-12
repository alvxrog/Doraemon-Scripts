# Interfaz conectada a enp0s3
# TODO: cambiar la IP asignada al reestructurar la topología
ifconfig enp0s3 192.168.0.5 netmask 255.255.255.0 up

sysctl -w net.ipv4.conf.all.forwarding=1
# R1 como router por defecto
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

resolvectl dns enp0s3 192.168.0.1