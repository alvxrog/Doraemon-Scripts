# Configuración manual IP para N1
ifconfig enp0s3 192.168.1.131 netmask 255.255.255.128 up

# Añadimos a R1 como router por defecto
route add default gw 192.168.1.129

# Permitir DNS local
resolvectl dns enp0s3 192.168.1.129

# Política drop para todas las cadenas
iptables -P INPUT DROP
iptables -P OUTPUT DROP
# Docker establece por defecto la política de Forward en DROP

# Permitir tráfico local
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Reglas para los servicios de Docker
# Permitimos trafico entrante de la gateway (Proxy Squid transparente)
iptables -A INPUT -p tcp -s 192.168.1.129 --dport 3128 -j ACCEPT
# Y solo permitimos trafico de la intranet
iptables -A INPUT \! -s 192.168.1.0/25 -j DROP

# --------
# PROFTPD
# -------
# Permitir conexiones entrantes desde hosts de la intranet para servir el contenido FTP
iptables -A INPUT  -p tcp -m tcp --dport 21 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp -m tcp --sport 21 -m state --state ESTABLISHED -j ACCEPT 

# Permitir conexiones en modo activo
iptables -A OUTPUT -p tcp -m tcp --sport 20 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT  -p tcp -m tcp --dport 20 -m state --state ESTABLISHED -j ACCEPT 

# Permitir conexiones en modo pasivo (rango 4599-4564)
iptables -A OUTPUT -p tcp -m tcp --sport 4559:4564 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT  -p tcp -m tcp --dport 4559:4564 -m state --state ESTABLISHED -j ACCEPT 

# --------
# NAGIOS
# -------
# Permitir conexiones solo para los PCs administradores (192.168.1.100)
iptables -A INPUT -p tcp -s 192.168.1.100 --dport 8080 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp -d 192.168.1.100 --sport 8080 -m state --state ESTABLISHED -j ACCEPT

# --------
# MailU (correo + portal web)
# -------
# Permitir conexiones SMTP (25, 465, 587) (SMTP Estándar, SMTP over SSL, SMTP autenticado)
iptables -A INPUT -p tcp --dport 25 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 25 -m state --state RELATED,ESTABLISHED -j ACCEPT

iptables -A INPUT -p tcp --dport 465 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 465 -m state --state RELATED,ESTABLISHED -j ACCEPT

iptables -A INPUT -p tcp --dport 587 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 587 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Permitir conexiones IMAP (143, 993) 
iptables -A INPUT -p tcp --dport 143 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 143 -m state --state RELATED,ESTABLISHED -j ACCEPT

iptables -A INPUT -p tcp --dport 993 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 993 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Permitir conexiones POP3 (110, 995) 
iptables -A INPUT -p tcp --dport 110 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 110 -m state --state RELATED,ESTABLISHED -j ACCEPT

iptables -A INPUT -p tcp --dport 995 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 995 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Permitir conexiones Webmail (80, 443) 
iptables -A INPUT -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 80 -m state --state RELATED,ESTABLISHED -j ACCEPT

iptables -A INPUT -p tcp --dport 443 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 443 -m state --state RELATED,ESTABLISHED -j ACCEPT

# --------
# Squid (Proxy web)
# -------
# Permitir conexiones al Proxy Web (3128) de los hosts de la Intranet
iptables -A INPUT -p tcp --dport 3128 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 3128 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Permitir acceso saliente para realizar las consultas HTTP/S
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

# Permitir acceso al DNS de la organización (sobre su puerta de enlace)
iptables -A OUTPUT -p udp -d 192.168.1.129 --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp -d 192.168.1.129 --dport 53 -j ACCEPT
iptables -A INPUT -p udp -s 192.168.1.129 --sport 53 -j ACCEPT
iptables -A INPUT -p tcp -s 192.168.1.129 --sport 53 -j ACCEPT

# Reiniciar servicio de Docker
systemctl restart docker