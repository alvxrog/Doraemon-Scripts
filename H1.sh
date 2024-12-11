systemctl stop firewalld.service

trap 'echo "Error en el comando: $BASH_COMMAND"' ERR

# Vaciar reglas iptables existentes
iptables -F

# Política drop para conexiones salientes
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Permitir conexiones entrantes establecidas
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
# Con la regla anterior, ahorramos en número de reglas al no tener que escribir las de entrada, 
# pero es menos seguro que especificar el estado en cada regla. Para un host con filtrado del router previo,
# nos bastará así.

# Permitir tráfico local
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT

# Permitir conexiones salientes para DNS, HTTP Y HTTPS
# DNS de la org (.1.1)
iptables -A OUTPUT -p tcp -d 192.168.1.1 --dport 53 -j ACCEPT
iptables -A OUTPUT -p udp -d 192.168.1.1 --dport 53 -j ACCEPT

# Trafico saliente HTTP
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

# Permitir conexiones FTP
iptables -A OUTPUT -p tcp -m tcp --dport 21 -j ACCEPT 

# Permitir conexiones en modo activo
iptables -A OUTPUT -p tcp -m tcp --dport 20 -j ACCEPT

# Permitir conexiones en modo pasivo (rango 4599-4564)
iptables -A OUTPUT -p tcp -m tcp --dport 4559:4564 -j ACCEPT

# Permitir conexion al servidor Nagios
iptables -A OUTPUT -p tcp -d 192.168.1.131 --dport 8080 -j ACCEPT

# Permitir conexiones SMTP (25, 465, 587) (SMTP Estándar, SMTP over SSL, SMTP autenticado)
iptables -A OUTPUT -p tcp --dport 25 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 465 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 587 -j ACCEPT

# Permitir conexiones IMAP (143, 993) 
iptables -A OUTPUT -p tcp --dport 143 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 993 -j ACCEPT

# Permitir conexiones POP3 (110, 995) 
iptables -A OUTPUT -p tcp --dport 110 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 995 -j ACCEPT

# Permitir conexiones al Proxy Web (3128)
iptables -A OUTPUT -p tcp -d 192.168.1.131 --dport 3128 -j ACCEPT

# ntop: Permitir conexiones salientes sobre el router y puerto 3000
iptables -A OUTPUT -p tcp -d 192.168.1.1 --dport 3000 -j ACCEPT

resolvectl dns enp0s3 192.168.1.1