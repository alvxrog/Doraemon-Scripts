# Configuración manual IP para N1
ifconfig enp0s3 192.168.1.2 netmask 255.255.255.0 up

# Añadimos a R1 como router por defecto
route add default gw 192.168.1.1

# Vaciar reglas iptable
iptables -F

# Política drop para todas las cadenas
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Permitir conexiones establecidas
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Permitir tráfico local
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Permitir ping hacia S1
iptables -A OUTPUT -p icmp -d 192.168.0.2 -j ACCEPT
iptables -A INPUT -p icmp -s 192.168.0.2 -j ACCEPT

# Permitir conexiones entrantes desde hosts de la intranet para servir sobre servidor Apache y HTTP
iptables -A INPUT -s 192.168.1.0/24 -p tcp --dport 80 ACCEPT