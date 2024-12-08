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
iptables -A INPUT -i lo -j ACCEPT

# Permitir conexiones salientes para DNS, HTTP Y HTTPS
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

# ntop: Permitir conexiones salientes sobre el router y puerto 3000
iptables -A OUTPUT -p tcp -d 192.168.1.1 --dport 3000 -j ACCEPT

# nagios: Permitir conexiones a D1:8080
iptables -A OUTPUT -p tcp -d 192.168.1.131 --dport 8080 -j ACCEPT

resolvectl dns enp0s3 8.8.8.8