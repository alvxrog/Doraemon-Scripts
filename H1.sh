systemctl stop firewalld.service

# Vaciar reglas iptables existentes
iptables -F

# Política drop para conexiones salientes
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Permitir conexiones entrantes/salientes establecidas
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Permitir tráfico local
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -o lo -j ACCEPT

# Permitir conexiones salientes para DNS, HTTP Y HTTPS
# TODO: habrá que añadir las inputs correspondiente para un correcto funcionamiento
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

iptables -A INPUT -p tcp --sport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A INPUT -p tcp --sport 80 -j ACCEPT
iptables -A INPUT -p tcp --sport 443 -j ACCEPT

# Permitir conexiones salientes sobre el router y puerto 3000 (ntopng)
iptables -A OUTPUT -d 192.168.1.1 -p tcp --dport 3000 -j ACCEPT

resolvectl dns enp0s3 8.8.8.8