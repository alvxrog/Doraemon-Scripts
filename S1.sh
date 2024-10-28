systemctl stop NetworkManager.service
systemctl stop firewalld.service
# Asignamos a la interfaz su direccion IP
ifconfig enp0s3 192.168.0.2 netmask 255.255.255.0 up

# Añadimos a R1 como router por defecto
route add default gw 192.168.0.1

# Vaciar reglas iptables
iptables -F

# Política drop para todas las cadenas
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Permitir conexiones establecidas
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT    # comprobar que es la misma q sale en los apuntes
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Permitir tráfico local
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Permitir SSH de equipos ubicados en la DMZ
iptables -A INPUT -s 192.168.0.0/24 -p tcp --dport 22 -j ACCEPT
iptables -A OUTPUT -s 192.168.0.0/24 -p tcp --sport 22 -j ACCEPT

# Permitir recepción y envio de ping hacia S1
iptables -A OUTPUT -p icmp -d 192.168.1.2 -j ACCEPT
iptables -A INPUT -p icmp -s 192.168.1.2 -j ACCEPT

# Permitir peticiones DNS al DNS de Google
iptables -A OUTPUT -d 8.8.8.8 -p udp --dport 53 -j ACCEPT 
iptables -A OUTPUT -d 8.8.8.8 -p tcp --dport 53 -j ACCEPT 

# Permitir trafico entrante y saliente HTTP(s)
iptables -A OUTPUT -p tcp --sport 80 -j ACCEPT
iptables -A OUTPUT -p tcp --sport 443 -j ACCEPT

iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

resolvectl dns enp0s3 8.8.8.8