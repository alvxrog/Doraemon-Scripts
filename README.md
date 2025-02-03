---
author:
- Álvaro González Moya
date: October 2024
title: "ASOR-ADARED: Valoracion Proyecto Conjunto"
---

------------------------------------------------------------------------

**ASOR - AdARed.**

**Proyecto conjunto: Doraemon**

------------------------------------------------------------------------

*González Moya, Álvaro - alvaro.gonzalezm@um.es*

# Introducción

Esta es la memoria final para el proyecto conjunto de las asignaturas
Arquitectura de Sistemas Operativos y Redes y Administración Avanzada de
Redes: el proyecto Doraemon. En este proyecto, se ha de simular el
despliegue de servicios de una organización ficticia sobre máquinas
virtuales VirtualBox.\

![Esquema general de
Doraemon](./readme_media/toplogia_basica.png)

El supuesto práctico esta basado sobre una empresa llamada Dorayaki, que
quiere desplegar una serie de máquinas hosts para sus trabajadores sobre
una intranet y servidores para sus servicios, algunos de estos
públicamente accesibles y otros de manera interna. Un router se
encargara de exponer estos servicios a una red no confiable, como podría
ser Internet.\
\
Un host como Host2 sobre una organización no confiable debería de poder
conectarse a los servicios expuestos públicamente a través del Router de
la sede Dorayaki, pero si este host quisiera acceder a los servicios
internos, podría hacer uso de una conexión tipo tunel, como una conexión
VPN, para acceder a estos de forma externa.\
\
Por último, un tercer host, Host3, se encargaría de realizar auditorías
de seguridad sobre la infraestructura de Dorayaki.\
\
Los servicios en un principio se desplegarían de manera tradicional,
sobre máquinas individuales y cada una como un servicio gestionado por
el sistema operativo. Soluciones de contenedores y su orquestración, con
tecnologías como Docker o Kubernetes, nos permitirán desplegar servicios
de manera más sencilla y permitir un potente escalado de los mismos.

# Estructura del documento

La estructura del documento presenta los contenidos necesarios para la
correcta verificación de la solución según la asignatura a la que
pertenecen: sobre la asignatura de Arquitectura de Sistemas Operativos y
Redes se muestran los aspectos relacionados con la configuración de red
y orquestación de contenedores: topología de red, traducción, filtrado y
soluciones de contenedores elegidas.\
\
Sobre la parte de la asignatura de Arquitectura avanzada de Redes se
presentan los servicios desplegados y su configuración.\
\
Las secciones de la 3 a la 6 son las relativas a Arquitectura de
Sistemas Operativos y redes. Las secciones 7 en adelante, las relativas
a Arquitectura avanzada de Redes.\
\
Debido a la extensión del documento, no se han podido añadir anexos para
complementar las explicaciones con las reglas específicas o *snippets*
de código utilizados. Todos los ficheros de configuración, docker
compose y otros se pueden consultar en el [repositorio de
GitHub](https://github.com/alvxrog/Doraemon-Scripts).

# Topología de red e interconexión de equipos

## Resúmen inicial

![Topología final del Proyecto Doraemon.
\*=192.168](./readme_media/DoraemonTopoFinal.png)

El proyecto Doraemon consta de tres áreas diferenciadas: una sede
central de la compañía Dorayaki, la sede de una organización no
confiable y una red para auditores externos a la empresa.\
\
La sede Dorayaki está formada por dos redes, una intranet (denominada en
el diagrama como *dorayakih*), con rango ***192.168.1.0/24***,
subdidivida en dos subredes, que contiene los hosts de los trabajadores
sobre la subred **192.168.1.0/25**, y los servidores con servicios de
consumo interno, como ficheros de la compañía, servicios de
monitorización y correo electrónico*\...* sobre la subred
**192.168.128.0/25**. Cabe destacar que, para algunas reglas de filtrado
que veremos más adelante, al referirnos a intranet nos referiremos al
primer rango que hemos mencionado.\
\
La otra parte diferenciada es la *DMZ*, *dorayakis*
(***192.168.0.0/24***) que contiene los servicios accesibles
públicamente, como podría ser un servidor HTTPs que aloja algún tipo de
servicio Web como Wordpress, entre otras cosas. El nombre DMZ viene de
*zona desmilitarizada*: esta zona está expuesta a Internet, ya que R1
hará *port forwarding*, exponiendo estos servicios al resto del mundo.
Un actor externo mailitencionado podría encontrar una vulnerabilidad
sobre nuestro servidor, infectar los equipos, y propagar su infección
por el resto de la red. Por eso es fundamental que sobre esta área, haya
el mínimo flujo de paquetes permitido.\
\
El router *R1* actúa como router central de la organización. Cumple las
funciones de punto de conexión para los servicios de Dorayaki, realizar
*NAT* para los servicios de la *DMZ*, aplicar reglas de *firewall* para
control de peticiones entrantes/salientes de la organización, servidor
DHCP para los hosts de la sede, resolver consultas DNS, diferenciando
las direcciones IPs que resuelve según se traten de solicitudes externas
o internas, y enrutar y controlar el tráfico dirigido hacia/desde la
sede.\
\
Una organización no confiable trabaja con nosotros en el desarrollo de
alguno de nuestros productos, y nos requieren la presencia de una VPN
sobre nuestra topología de red para acceder a los servicios internos que
podamos exponer. En un principio, se planteo la adición de otro router
en la sede Dorayaki, RVPN, sobre el que se realizaran las conexiones VPN
de los hosts, pero se decidió descartar.\
\
Un router RC se encarga de encaminar todo el tráfico entre las
diferentes partes del proyecto (Sede Dorayaki, Externos y OrgNoConf), y
de enviar los paquetes a Internet.

## Traducción de direcciones

Las direcciones IPs que comienzan por 192.168.33,34 y 35 se
considerarían públicas bajo nuestra topología, y sobre las interfaces
donde están asignadas dichas IPs se tiene esto como consideración.\
Para traducción de direcciones, port forwarding y filtrado, se utilizará
**iptables**.\
\
Todos los routers de la topología que actúan como gateway (punto de
conexión hacia internet) de alguna de las organizaciones (R1,R2,R3)
realizan Source NAT para las subredes internas que gestionan. Por
ejemplo, sobre las subredes 192.168.0.0/24 y 192.168.1.0/24, R1 hace
SNAT con las siguientes reglas:

    # SNAT para las subredes de host y DMZ
    iptables -t nat -A POSTROUTING -s 192.168.0.0/24 -o enp0s9 -j SNAT --to 192.168.33.253
    iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o enp0s9 -j SNAT --to 192.168.33.253

Estas reglas permiten que los hosts y servidores de la intranet no
expongan su dirección IP privada, cambiando el campo To en la trama IP y
saliendo hacia otra organización/internet. Cuando el paquete respuesta
llegue de nuevo al gateway, el router se encargará de traducir la IP
destino a la verdadera IP del host/servidor que realizó la petición.

## Port forwarding (Destination NAT)

Para poder acceder a los servicios hospedados en algún servidor de
nuestra DMZ, R1 realiza *port forwarding* (o **destination NAT**): todas
las peticiones que reciba sobre su dirección IP (que consideramos)
pública: 192.168.33.253, las redirigirá a la máquina que contenga dicho
servicio. De hecho, y como veremos en la sección de servicios
desplegados, una misma máquina puede tener varios servicios sobre el
mismo puerto utilizando un *reverse proxy*, como el que hemos
implementado con nginx.\
\
Los puertos que expone públicamente R1 son **443,1194,943**: 443 para
HTTPS, 1194 UDP para las conexiones VPN, y 943 para el dashboard de
admin de OpenVPN. Su correspondiente regla forward se encarga de
permitir la redirección del tráfico que acabamos de mencionar (aunque
esta regla pertenezca a las áreas de filtrado, se mencionan aquí y en la
siguietne sección por la estrecha relación que mantienen):

    # Servidor OpenVPN en la .0.10 (D2)
    # Forward TCP 443
    iptables -t nat -A PREROUTING -p tcp -i enp0s9 -d 192.168.33.253 --dport 443 \ 
    -j DNAT --to-destination 192.168.0.10:443

    iptables -A FORWARD -p tcp -i enp0s9 -d 192.168.0.10 --dport 443 \ 
    -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

    # Forward UDP 1194
    iptables -t nat -A PREROUTING -i enp0s9 -p udp -d 192.168.33.253 --dport 1194 \ 
    -j DNAT --to-destination 192.168.0.10:1194

    iptables -A FORWARD -p udp -i enp0s9 -d 192.168.0.10 --dport 1194 \ 
    -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

    # Forward TCP 943
    iptables -t nat -A PREROUTING -i enp0s9 -p tcp -d 192.168.33.253 --dport 943 \ 
    -j DNAT --to-destination 192.168.0.10:943

    iptables -A FORWARD -i enp0s9 -p tcp -d 192.168.0.10 --dport 943 \ 
    -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# Filtrado de paquetes

Debido a que a menudo es establecida como la política recomendada para
un firewall en una organización, se ha implementado una **política por
defecto de denegar todo el tráfico entrante y saliente** en los hosts y
servidores tanto de la DMZ como de la Intranet de Dorayaki. La razón
principal es que, de esta manera, es más fácil conocer qué tráfico entra
y sale de cada uno de los hosts, ya que solo saldrá el explícitamente
mencionado en una regla de filtrado.

    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT DROP

Sobre esta sección, mostraremos las **reglas que se han ejecutado sobre
los diferentes hosts/servidores/R1** para permitir el filtrado
específico. Sobre **R1**, la **interfaz pública es la enp0s9**.

## Filtrado del exterior

R1 debe de no enrutar las solicitudes internas que le llegan por su
interfaz pública: esto es lógico, pero al estar tratando con máquinas
virtuales la regla debe de ser explícita, y aparece al inicio de la
cadena de FORWARD:

    # Denegar todo el tráfico que venga de la enp0s9 (exterior) hacia dentro
    iptables -A FORWARD -i enp0s9 -d 192.168.0.0/24 -j DROP
    iptables -A FORWARD -i enp0s9 -d 192.168.1.0/24 -j DROP

## Filtrado Intranet-DMZ,DMZ-Intranet

**La intranet y la DMZ no deberían de poder comunicarse** y, en caso de
hacerlo, deberían de permitirse las conexiones mínimas para un correcto
funcionamiento de los servicios. La razón principal es que en la DMZ
existe el riesgo de que uno de los servidores se vea comprometido por
una brecha de seguridad. Esto se logra con la política denegar todo que
hemos mencionado anteriormente. Sin embargo, sobre R1, se hacen
explícitas con las siguientes reglas al final de las cadenas FORWARD:

    # Bloquear tráfico DMZ-Intranet
    iptables -A FORWARD -s 192.168.0.0/24 -d 192.168.1.0/24 -j DROP

    # Bloquear tráfico Intranet-DMZ
    iptables -A FORWARD -s 192.168.1.0/24 -d 192.168.0.0/24 -j DROP

    # Bloquear tráfico Intranet hosts-Intranet servers
    iptables -A FORWARD -s 192.168.1.0/25 -d 192.168.128.0/25 -j DROP

    # Bloquear tráfico Intranet servers-Intranet hosts
    iptables -A FORWARD -s 192.168.128.0/25 -d 192.168.1.0/25 -j DROP

    # Bloquear tráfico DMZ saliente
    iptables -A OUTPUT -s 192.168.0.0/24 -j DROP

Evidentemente, si no permitiéramos ningún tipo de tráfico, los hosts de
la organización no podrían acceder a los servicios que exponemos
públicamente, y tampoco queremos generar sobrecarga accediendo a ellos a
través de la interfaz pública. Para solucionar esto, el **DNS** ubicado
sobre R1 **resuelve la dirección IP de los servicios de una forma u otra
dependiendo de la IP o interfaz por la que le llegan las solicitudes**:
las direcciones internas resuelven los nombres de los servicios
(www.agm-dorayaki.net) como direcciones IP internas, mientras que las
externas resolverán sólo aquellos servicios expuestos públicamente, y
con la dirección pública a la que están asociados estos.

## Filtrado hosts/servidores Intranet

Los hosts de la intranet deben de poder utilizar servicios como correo
electrónico, FTP, y acceder a la web mediante HTTP y HTTPS, así como
realizar resoluciones DNS.\
\
Sobre nuestra topología, **D1** contiene servicios internos de **correo
electrónico, FTP, un servidor Nagios de monitorización y un proxy web**.
Utilizamos una serie de reglas multiport (dado que no podemos meter
todos los puertos en una sola) para permitir el reenvío de dichas
tramas.

    #R1
    # Reenviar tramas de la intranet sobre D1 y los puertos de los servicios que hospeda
    iptables -A FORWARD -p tcp -s 192.168.1.0/25 -d 192.168.1.131 -m multiport \ 
    --dports 25,80,443,21,20,110 -j ACCEPT

    iptables -A FORWARD -p tcp -s 192.168.1.0/25 -d 192.168.1.131 -m multiport \ 
    --dports 143,465,587,993,995,3128,4599 -j ACCEPT

    iptables -A FORWARD -p tcp -s 192.168.1.0/25 -d 192.168.1.131 -m multiport \ 
    --dports 4560,4561,4562,4563,4564,8080 -j ACCEPT

D1, que hospeda los servicios, tiene que permitir conexiones entrantes a
dichos puertos:

    #D1
    # --------
    # PROFTPD
    # -------
    # Permitir conexiones entrantes desde hosts de la intranet para servir el contenido FTP
    iptables -A INPUT  -p tcp -m tcp --dport 21 -m state --state NEW,ESTABLISHED -j ACCEPT
    iptables -A OUTPUT -p tcp -m tcp --sport 21 -m state --state ESTABLISHED -j ACCEPT 

    # Permitir conexiones en modo activo
    iptables -A OUTPUT -p tcp -m tcp --sport 20 \ 
    -m state --state RELATED,ESTABLISHED -j ACCEPT

    iptables -A INPUT  -p tcp -m tcp --dport 20 \ 
    -m state --state ESTABLISHED -j ACCEPT 

    # Permitir conexiones en modo pasivo (rango 4599-4564)
    iptables -A OUTPUT -p tcp -m tcp --sport 4559:4564 \ 
    -m state --state RELATED,ESTABLISHED -j ACCEPT

    iptables -A INPUT  -p tcp -m tcp --dport 4559:4564 \ 
    -m state --state ESTABLISHED -j ACCEPT 

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

    (...)
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

    (...)

Las conexiones a Nagios van separadas según IPs que se consideran
administradoras (la 192.168.1.100 es una de ellas).\
Sobre H1, hosts de la intranet, al tener política denegar todo, también
tiene que permitir salir el tráfico y recibir respuestas:

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

Destacar que solo permitimos resoluciones DNS sobre el DNS de la empresa
(que está en la gateway de cada máquina), y la última regla nos permite
ver la dashboard de ntop sobre R1 también.

## Filtrado servidores DMZ

D2 y D3 son máquinas en Ubuntu sobre la DMZ que exponen los servicios
públicos: hay que tener en cuenta que algunos servicios **están
replicados utilizando docker swarm**. **D2** es el manager del swarm, y
**D3** actúa como worker. En general, docker tiene sus propias reglas
forward y cadenas propias para permitir únicamente las conexiones a los
contenedores desde el host que han sido expuestas en sus ficheros de
configuración, por lo que únicamente tenemos que asegurarnos de que las
peticiones que recibimos sobre los ports de los hosts son las
estrictamente necesarias.\
\
Docker utiliza los puertos 2376,2377 y 7946 para comunicarse entre peers
de un swarm. Sin embargo, durante la realización de las reglas de
filtado, se ha tenido problemas de funcionamiento, por lo que las reglas
son un poco mas laxas, permitiendo cualquier tipo de tráfico entre ambas
máquinas.

    # D3
    # Permitir tráfico de Swarm Manager (TCP)
    iptables -A OUTPUT -d 192.168.0.10 -j ACCEPT
    iptables -A INPUT -s 192.168.0.10 -j ACCEPT

Sobre D2, se permite también el tráfico al swarm worker D3, y las
conexione sobre los puertos de los servicios expuestos públicamente:
HTTP(s) (que irán a un reverse proxy NGINX que se explicará más
adelante) y conexiones VPN sobre 943, UDP 1194:

    # D2
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

Por último, K1 es un host con Minikube y despliega una aplicación de
ejemplo sencilla con una base de datos MongoDB y un portal web. **TODO:
REGLAS K1**

## Filtrado sobre R1: *predica con el ejemplo*

El router R1, además de las labores que hemos mencionado, tiene que
**asegurar las mismas condiciones que el resto de equipos**: bloquear
tráfico DMZ-Intranet, Intranet-DMZ, y tráfico DMZ saliente a excepción
del tráfico de los servicios expuestos públicamente.

    # Permitir tráfico de salida HTTP por parte de los hosts de la intranet y del proxy web
    iptables -A FORWARD -p tcp -s 192.168.1.0/25 --dport 80 -j ACCEPT
    iptables -A FORWARD -p tcp -s 192.168.1.0/25 --dport 443 -j ACCEPT

    iptables -A FORWARD -p tcp -s 192.168.1.131 --dport 80 \ 
    -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

    iptables -A FORWARD -p tcp -s 192.168.1.131 --dport 443 \ 
    -m state --state NEW,ESTABLISHED -j ACCEPT

    # Permitir tráfico entrante DNS
    iptables -A INPUT -p tcp --dport 53 -j ACCEPT
    iptables -A INPUT -p udp --dport 53 -j ACCEPT
    iptables -A OUTPUT -p tcp --sport 53 -j ACCEPT
    iptables -A OUTPUT -p udp --sport 53 -j ACCEPT

    # Trafico saliente para resoluciones DNS recursivas 
    iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
    iptables -A OUTPUT -p udp --dport 53 -j ACCEPT

    # Permitir trafico TCP sobre el puerto 3000 (ntpong) desde hosts de la Intranet
    iptables -A INPUT -s 192.168.1.0/25 -p tcp --dport 3000 \ 
    -m state --state NEW,ESTABLISHED -j ACCEPT

    iptables -A OUTPUT -s 192.168.1.0/25 -p tcp --sport 3000 \ 
    -m state --state ESTABLISHED,RELATED -j ACCEPT

    # ---  DMZ  ---
    # Permitir tráfico HTTP a D2,D3 HTTP(s)
    iptables -A FORWARD -d 192.168.0.10 -p tcp --sport 80 -j ACCEPT
    iptables -A FORWARD -d 192.168.0.10 -p tcp --sport 443 -j ACCEPT
    iptables -A FORWARD -d 192.168.0.10 -p tcp --sport 943 -j ACCEPT

Cada uno de los routers de la topología está configurado para que **no
aparezcan en un comando *traceroute***, bloqueando los paquetes
time-exceeded, evitando de esta manera exponerse y que un atacante
externo obtuviera información de nuestra topología de red.

    # Los routers no deben aparecer en los traceroute.
    iptables -A OUTPUT -p icmp --icmp-type time-exceeded -j DROP

Las configuraciones completas más relevantes están disponibles en el
[repositorio de GitHub](https://github.com/alvxrog/Doraemon-Scripts).
Los contenedores son un mecanismo de virtualización a nivel de proceso
que permiten desplegar servicios, cada uno con sus dependencias
individuales, agilizando el proceso de despliegue, y permitiendo una
replicación sencilla de los mismos. La principal ventaja con respecto a
las máquinas virtuales es que **no necesitan un hipervisor**, y en lugar
de eso se ejecutan como un programa sobre la máquina y utilizan un
**engine (docker engine, por ejemplo) para realizar las traducciones
necesarias**.\
\
En este proyecto, **se utiliza Docker y Kubernetes** como soluciones
basadas en contenedores. Sobre la figura 2 se
pueden observar qué servicios están **dockerizados** (o desplegados
sobre kubernetes).\
\
Como solución de orquestación basada en contenedores, se utilizó
**Docker swarm**: es potente, robusta, y lo suficientemente ligera para
funcionar correctamente sobre una máquina virtual con escasos recursos y
un *overhead* importante debido al hipervisor sobre el que se ejecutan.\
\
Se destaca que se intentó desplegar la solución de orquestación basada
en Kubernetes que se mencionó en clase, **kubeadm**, pero existían
problemas a la hora de hacerla correr sobre las máquinas virtuales.
Investigué y encontré **k3s** como una alternativa para desplegar
Kubernetes multinodo de manera sencilla, permitiendo la ejecución de un
binario autocontenido con todos los requisitos de kubernetes. Sin
embargo, no se ha desplegado y se ha dedicido por utilizar **minikube**.

# Despliegue de elementos basados en contenedores

## Contenedores Docker

Los contenedores docker son el mecanismo más conocido y con más
desarrollo por parte de la comunidad para el despliegue de contenedores:
permiten una **configuración sencilla** mediante **diferentes formatos
de fichero** o **una interfaz de comandos**. Los aspectos más
importantes para entender el despliegue realizado son:

-   **Imágenes (images)**: Plantillas de solo lectura que contienen las
    instrucciones para crear un contenedor.

-   **Contenedores (containers)**: Instancias ejecutables de las
    imágenes.

-   **Volúmenes (volumes)**: Sistemas de ficheros, generalmente por
    capas, que almacenan los datos necesarios para la ejecución de un
    contenedor.

-   **Redes (networks)**: redes virtuales simuladas que permiten la
    comunicación entre contenedores

La mayoría de servicios se han desplegado utilizando un fichero .yml y
**docker compose**. Por falta de espacio, están todos disponibles sobre
el [repositorio de
GitHub](https://github.com/alvxrog/Doraemon-Scripts).\
Los servicios que se han desplegado utilizando Docker
(independientemente de si han sido replicados o no) han sido. Sobre
**D1**, en la intranet:

-   **Mailu**: servicio de correo basado en contenedores, ofrece
    servidores POP3, SMTP e IMAP, y su asistente de configuración web
    genera un fichero docker compose y .env automáticamente. El
    despliegue es sencillo y permite la ejecución de un portal web para
    extraer correo. Para más información y capturas ver la sección
    [10.4](#correo)

-   **ProFTP**: un servidor de FTP sencillo. Más información en
    [10.5](#ftp)

-   **Nagios**: un servidor de monitorización para ver el estado de los
    diferentes servicios. Sección [8](#nagios)

-   **Squid**: un proxy web para el control y optimización del tráfico
    web de la organización. Sección [12](#squid)
Sobre **D2**, en la DMZ:

-   **Nginx**: como *reverse proxy* para diferenciar servicios y
    permitir su despliegue bajo la misma máquina. Sección
    [10.2](#nginx)

-   **OpenVPN AS**: la solución de acess server de OpenVPN, para
    gestionar conexiones VPN de usuarios externos de forma sencilla.
    Sección [11](#openvpn)

-   **Wordpress**: que incluye sobre una imágen de wordpress los
    servidores Apache y configuraciones necesarias para su despliegue y
    una base de datos MySQL para almacenar sus contenidos. Sección
    [10.3](#wordpress)

Los servicios sobre docker compose se pueden desplegar con la orden
docker compose -f nombre-fichero.yml up -d.

## Contenedores Kubernetes

Kubernetes es otra solución de contenedores que promete ser más avanzada
y potente que docker. A pesar de que no vamos a explorar sus capacidades
multinodo, los conceptos principales que tenemos que entender de
Kubernetes son:

-   **Pods**: La unidad más básica en Kubernetes, que agrupa uno o más
    contenedores.

-   **Services**: Proporcionan una abstracción para acceder a los pods.

-   **Deployments**: Gestionan el estado deseado de las aplicaciones.

-   **ConfigMaps y Secrets**: Almacenan información de configuración y
    datos sensibles.

Estos contenedores se construyen sobre **imágenes docker** como base. Se
ha seguido el tutorial recomendado en clase para desplegar una webapp de
ejemplo conectada a una base de datos MongoDB para almacenar las
respuetas.\
\
Los servicios que hemos desplegados de Kubernetes no son estrictamente
necesarios para la parte de despliegue de servicios de la práctica, por
lo que los vamos a exponer aquí y no en la sección de servicios.\
\
Vamos a ver las diferentes partes del despliegue de un servidor de
kubernetes. Comenzaremos por el fichero **mongo.yaml**:

    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: mongo-deployment
      labels:
        app: mongo
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: mongo
      template:
        metadata:
          labels:
            app: mongo
        spec:
          containers:
          - name: mongodb
            image: mongo:5.0
            ports:
            - containerPort: 27017
            env:
            - name: MONGO_INITDB_ROOT_USERNAME
              valueFrom:
                secretKeyRef:
                  name: mongo-secret
                  key: mongo-user
            - name: MONGO_INITDB_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mongo-secret
                  key: mongo-password  
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: mongo-service
    spec:
      selector:
        app: mongo
      ports:
        - protocol: TCP
          port: 27017
          targetPort: 27017

Tenemos dos partes dentro del fichero: un deployment y un service. El
deployment nos define el pod: un pod con la imagen de MongoDB, que es
una base de datos. A destacar tenemos las labels (app: mongo), que
utilizaremos para identificar a la app en la especificación (por
ejemplo, replicas con matchLabels), replicas nos efine el numero de
replicas de la aplicación, containers identifica los contenedores
propiamente, donde name es el nombre del contenedor, image la imagen de
Docker, y ports los puertos que el contenedor debe habilitar, exponiendo
el 27017 de foma interna en el pod. Estos puertos no se pueden acceder
externamente, ya que la base de datos servirá para servir contenido a la
aplicación web. La sección variables de entorno carga del fichero mongo
secret el usuario y contraseñas root para la base de datos, utilizando
secretKeyRef. El servicio es un portal web donde podemos modificar la
información contenida en el, y se almacena en una base de datos.\
\
La otra parte, el service, de tipo ClusterIP expone el puerto 27017 del
pod de mongo DB para que otras aplicaciones del cluster lo puedan
utilizar. Al no exponer un NodePort, no es accesible fuera del clúster.\
\
Tenemos otros servicios de configuración de la base de datos, como
mongo-config y mongo-secrets para almacenar las variables de entorno
mencionadas anteriormente, pero vamos a explicar el otro fichero
importante, que define la aplicación web:

    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: webapp-deployment
      labels:
        app: webapp
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: webapp
      template:
        metadata:
          labels:
            app: webapp
        spec:
          containers:
          - name: webapp
            image: nanajanashia/k8s-demo-app:v1.0
            ports:
            - containerPort: 3000
            env:
            - name: USER_NAME
              valueFrom:
                secretKeyRef:
                  name: mongo-secret
                  key: mongo-user
            - name: USER_PWD
              valueFrom:
                secretKeyRef:
                  name: mongo-secret
                  key: mongo-password 
            - name: DB_URL
              valueFrom:
                configMapKeyRef:
                  name: mongo-config
                  key: mongo-url
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: webapp-service
    spec:
      type: NodePort
      selector:
        app: webapp
      ports:
        - protocol: TCP
          port: 3000
          targetPort: 3000
          nodePort: 30100

La estrucutra es muy similar al anteriormente explicado, por lo que
iremos rápido: el deployment define un pod basado en la imagen docker
nanajanashia/k8s-demo-app, configura las credenciales para mongo DB de
mongo-secrets, utilizando Secrets y ConfigMaps, y expone el puierto
interno 3000. El servicio expone la aplicación web al puerto externo
30100 y redirige las solicitudes al puerto interno del pod 3000.\
\
minikube nos da una ip (minikube ip) sobre la que se expone el puerto
30100 que hemos mencionado. Por lo tanto, podemos hacer port forwarding
(Destination NAT). Vamos a probar el servicio desde un host de la
intranet:

![Portal web antes de modificar la
información](./readme_media/kubectl_1.png)

\
Podemos cambiar el nombre, email e intereses a lo que nosotros
queramos.\

![Portal web después de
modificar](./readme_media/kubectl_2.png)

\

# Orquestación de servicios basados en contenedores: Docker Swarm

Las ventajas principales de utilizar Docker Swarm frente a un despliegue
tradicional de docker son una orquestación integrada, sin necesidad de
modificar en gran medida los ficheros de despliegue tradicionales,
lograr alta disponibilidad, balanceo de carga, gestión descentralizada,
y la definición de un estado deseado el cual Docker tratará de
conseguir.\
\
El host **D2** actúa como nodo **manager** y el **D3** como **worker**
del swarm.\
\
Este es el stack que vamos a desplegar sobre swarm:

    version: "3"

    services:
      wordpress:
        depends_on:
          - db
        image: wordpress:latest
        restart: always
        ports:
          - "80:80"
        networks:
          - frontend
          - backend
        deploy:
          replicas: 2
        environment:
          WORDPRESS_DB_HOST: db
          WORDPRESS_DB_NAME: wordpress
          WORDPRESS_DB_USER: harsh
          WORDPRESS_DB_PASSWORD: redhat
        volumes:
          - wordpress_db:/var/www/html

      db:
        image: mysql:5.7
        restart: always
        environment:
          MYSQL_DATABASE: wordpress
          MYSQL_USER: harsh
          MYSQL_PASSWORD: redhat
          MYSQL_ROOT_PASSWORD: admin
        volumes:
          - mysql_db:/var/lib/mysql
        ports:
          - "3306:3306"
        networks:
          - backend
        deploy:
          replicas: 1

    networks:
      frontend:
      backend:

    volumes:
      wordpress_db:
      mysql_db:

Un servicio de docker swarm define un estado relativo a una serie de
contenedores. El servicio de Wordpress (que llamaremos WordpressService)
tiene dos componenetes: **los servidores de wordpress**, que tienen los
servidores web que gestionan las peticiones, y una **base de datos**
mysql. Sobre la imagen de wordpress, queremos conseguir dos réplicas
para mejorar la disponibilidad.\
Las conexiones se realizarán al nodo manager, y este se encargará de
redirigir las peticiones si los contenedores no se encuentran en su
máquina física. Estos contenedores están conectados con una red virtual
de tipo **overlay**.\
\
La presencia de un servidor nginx que actua como proxy inverso hace
necesaria la conexión de todos los contenedores sobre una red llamada
webnet. Al recibir solicitudes sobre www.agm-dorayaki.net, redirigirá
las peticiones a wordpress. El dns de docker permite que podamos
escribir sobre los ficheros de configuración el nombre de los servicios
como wordpress o db. Por ejemplo, en la variable de entorno
WORDPRESS_DB_HOST podemos poner db, y al acceder a dicha base de datos
el DNS resolverá el nombre del servicio a la IP interna del contendor.\
\
Se deja una red \"frontend\" para comunicar las imagenes de wordpress, y
una red \"backend\" para comunicarse con el servidio mysql, que no está
expuesto sobre la máquina local y sólo a los contenedores de wordpress.\
\
Desplegaremos el stack con docker *stack deploy
--compose-file=wordpress-stack.yml WordpressService*.\
\
Con la orden docker service ls podemos ver el estado de los servicios.

![Salida de docker service ls mostrando las replicas de los servicios de
Wordpress y la base de
datos](./readme_media/docker_service.png)

A partir de esta parte de la entrega comienzan los contenidos relativos
a la rúbrica de la asignatura **Arquitectura Avanzada de Redes**.

# Preámbulo: Entidad de certificación y certificados X.509

La mayoría de los servicios desplegados necesitan una serie de
certificados para poder funcionar sobre SSL (HTTPs). Para ello, se ha
generado una entidad de certificación con openssl, tal y como se explicó
en la asignatura del pasado año de la carrera **Servicios Telemáticos**.
Su generación, debido a la extensión del documento, la vamos a dejar
fuera del mismo.\
\
Esta entidad de certificación firma los certificados de los servicios
públicos y privados de la empresa. A pesar de que en un entorno real no
tendrían validez y se tendría que buscar una CA como Lets Encrypt para
genera certificados SSL aceptables por los buscadores de internet sin
requerir configuración extra, podemos importar el certificado de la CA
sobre el navegador Firefox que vayamos a utilizar. Aun así, existen
algunos problemas en Firefox que hacen que a veces salten excepciones de
seguridad, a pesar de que estan incluidos los certificados.\
\
El dominio elegido para nuestra organización es **agm-dorayaki.net**,
donde AGM son mis iniciales.

# Despliegue de herramientas de monitorización para control de disponibilidad: Nagios

Nagios es una herramienta de monitorización de infraestructura que nos
permitirá ver en un panel de control el estado de nuestros servicios:
sobre ella podemos mapear todas las máquinas de nuestra infraestructura
y comprobar que están levantadas correctamente.

![Mapa de servidores realizado en Nagios. La IP pública (web-services) y
el localhost (máquina sobre la que se está ejecutando nagios) están
levantados. K1 y D3 están pendientes de ejecución. D1 y D2 están
caidos.](./readme_media/nagios_1.png){width="0.75\\linewidth"}

La unidad en Nagios es el host, y cada host tiene uno o varios servicios
que hospeda. Se han monitorizado todos los servidores de la organización
y los servicios de cada uno: sobre D1 (servidor de la Intranet) FTP,
SMTP, POP3 e IMAP, D2 y D3, para comprobar que no estén caidos, K1, que
es un servidor de juguete para verificar el funcionamiento de
kubernetes, y lo que llamamos web-services, que son los servicios web
que la empresa expone públicamente.\
\
Nagios es únicamente accesible a usuarios administradores de intranet, y
está disponible en nagios.agm-dorayaki.net (nombre que solo es resoluble
sobre la zona interna de la organización, ver Sección
[10.1](#dns){reference-type="ref" reference="dns"}) Toda la
configuración esta disponible en un único fichero, nagios.cfg, en [el
repositorio](https://github.com/alvxrog/Doraemon-Scripts).

# Despliegue de herramientas de monitorización para el control de uso y rendimiento de la red: Ntop

Ntop es una herramienta de monitorización de redes que permite
monitorización en tiempo real de los hosts y aplicaciones que consumen
recursos de red. Cuenta con una interfaz web que permite ver estos
datos. Además, la generación de alertas nos permitiria detectar
problemas (aunque existen soluciones más específicas como veremos más
adelante).\
\
He decidido desplegar Ntop sobre R1, sin dockerizar para que pueda
acceder a las interfaces de red sin problemas, y quitar las políticas
denegar todo para permitir que los paquetes pasen por la pila de red del
kernel y los pueda visualizar ntop.\
\
Veamos un ejemplo: la sección hosts nos permite ver qué hosts están
mandado tráfico. Si un usuario de la intranet con la IP 192.168.1.100 se
pone a ver YouTube, podemos ver a qué esta accediendo:

![Pestaña \"Peers\" sobre el host 192.168.1.100 reproduciendo un vídeo
de YouTube. Los peers de googleusercontent delatan al usuario. El
departamento de recursos humanos está al tanto de la
situación.](./readme_media/ntop_1.png){width="0.9\\linewidth"}

# Despliegue de servicios públicos básicos de red.

Toda organización necesita una serie de servicios para llevar a cabo sus
labores en Internet: enviar y recibir correos electrónicos, una web o un
blog con sus productos, que los usuarios puedan acceder a su web a
través de un dominio relacionado con el nombre de la organización **(en
nuestro caso agm-dorayaki.net)**, tener un directorio de archivos donde
almacenar las facturas de la empresa\.... Para ello, desplegamos una
serie de servicios de interés general:

## DNS

El servicio de DNS es de los pocos servicios que no está dockerizado,
debido a su facilidad de configuración con soluciones como la suit de
bind9: en concreto, el demonio named se encarga de resolver los nombres
de la organización. Se eligió named al haber sido explicado en la
**asignatura Servicios Telemáticos** del pasado curso.\
\
El router R1 se encargará de realizar las resoluciones de nombres de los
hosts y servidores de la organización y de las consultas externas. Sin
embargo, utilizará zonas (llamadas internal y external) para evitar
exponer aquellos servicios que no son accesibles desde el exterior.
Además, los usuarios accederan a los servicios expuestos públicamente
desde la intranet con las ips internas de los mismos. Esto se consigue
en named con las **views**: una view **internal** y una view
**external** que utilizan diferentes zonas\

![Views internal y external en
/etc/named.conf](./readme_media/dns_zonas.png)

Las entradas que se exponen públicamente son:

    ns1 IN A 192.168.33.253
    www IN A 192.168.33.253
    vpn IN A 192.168.33.253

Y las que se exponen internamente

    ns1 IN A 192.168.33.253
    www IN A 192.168.0.10
    vpn IN A 192.168.0.10
    agm-dorayaki.net.   IN MX 10 mail.agm-dorayaki.net
    smtp IN A 192.168.1.131
    pop IN A 192.168.1.131
    mail IN A 192.168.1.131
    proxy IN A 192.168.1.131
    ftp IN A 192.168.1.131
    openvas IN A 192.168.1.132
    nagios IN A 192.168.1.131
    k8s IN A 192.168.0.5

## Nginx como reverse proxy

Sobre D2-D3 tenemos un swarm con, en este momento, solamente dos
máquinas, pero potencialmente escalable a un gran número. Al ejecutar
sobre estas máquinas una solución de orquestración de contenedores como
es Docker Swarm, un número muy grande de servicios se podría desplegar
sobre la misma puerta de enlace.\
\
Los problemas surgen cuando dos servicios desplegados sirven portales
http o https (por ejemplo) y, por lo tanto, comparten puertos: ¿cómo
diferenciamos a que servicio nos queremos referir? Lo haremos mediante
los hostnames y un reverse proxy de nginx.\
\
Este reverse proxy está sobre un contenedor y está conectado a una red a
la que está conectados todos los contenedores que tendrían que estar
expuestos públicamente. Según el subdominio al que se quiera acceder, el
reverse proxy seleccionará un contenedor u otro. Por ejemplo,
www.agm-dorayaki.net resolverá sobre el contenedor de Wordpress,
mientrás que VPN sobre el contenedor de OpenVPN, aunque ambos se acceda
a través del puerto 443.\
Los ficheros de configuración más relevantes se encuentran [en el
repositorio](https://github.com/alvxrog/Doraemon-Scripts).

## Web: Wordpress

Una de las soluciones más famosas para desplegar un blog donde mostrar
artículos de una organización es Wordpress. Nuestro despliegue del
servicio wordpress se realiza sobre contenedores Docker, y la
orquestración de los mismos nos permite una alta tolerancia a fallos de
máquinas individuales (suponiendo que escalamos lo suficiente). Las
instancias de wordpress utilizan un servidor Apache para servir
contenidos, y un servidor de bases de datos MySQL para guardar la
información.

![Página de ejemplo de un servicio de
Wordpress](./readme_media/wp_ejemplo.png){width="0.75\\linewidth"}

## Correo electrónico

Como solución de correo electrónico he optado por desplegar
[Mailu](https://mailu.io/2024.06/), una solución de correo basada en
contenedores y que permite el acceso al correo utilizando protocolos
como POP3, IMAP y SMTP, además de un coveniente portal web.\
\
La configuración del servicio es bastante sencilla, ya que tiene una
interfaz web donde puedes descargar el fichero docker compose y el
fichero de variables de entorno. Una vez movidos los ficheros a la
máquina y desplegado, podemos acceder al correo desde
**mail.agm-dorayaki.net**\
\
El portal web está securizado con un certificado X.509 generado por la
CA de la organización. A pesar de que generalmente el servidor de correo
debería de estar en la DMZ, para poder enviar correos al exterior, al no
tener los certificados pertinentes se ha decidido desplegarlo sobre el
segmento de la intranet.\
\
El usuario admin tiene acceso a una dashboard de gestión, y un usuario
normal puede acceder a su Webmail:\

![Dashboard de administración de
Mailu](./readme_media/mailu_admin_dashboard.png){width="0.75\\linewidth"}

![Webmail para un usuario
corriente](./readme_media/mailu_user_dashboard.png){width="0.75\\linewidth"}

\
Los ficheros de configuración de esta solución son relativamente
complejos, y para evitar ocupar mucho espacio en este documento se
dejarán en el repositorio.

## FTP

El servicio FTP se implementa como un servicio de la intranet desplegado
sobre un contenedor ejecutando proFTP. Podemos acceder al servidor en
**ftp.agm-dorayaki.net**. Se generan 5 shares de prueba, cada una con su
usuario y contraseña propios. Un cliente FTP como FileZilla nos permite
acceder a los archivos que hospedamos.

![Ejemplo del servidor FTP que hospeda el fichero
testfile.txt](./readme_media/ftp_example.png){width="0.75\\linewidth"}

# Acceso seguro remoto a la sede de la empresa: OpenVPN AS

Como solución de VPN, para que un cliente de la organización no
confiable acceda a los servicios internos de nuestra sede, se ha optado
por desplegar **OpenVPN Acess Server**. La ventaja de desplegar Access
Server frente a una configuración tradicional de OpenVPN es la
autenticación de usuarios integrada, la facilidad de interconexión con
otros servicios de autenticación de directorio activo, una interfaz
gráfica que permite a los usuarios de la VPN descargar directamente su
fichero de configuración, además de que está pensado para ser altamente
escalable y ejecutable como diferentes nodos, por lo que su despliegue
como contenedor docker es ideal. A la expensa, claro está, de que no es
una solución gratuita, y el modelo de prueba solo permite dos conexiones
VPN simultáneas. Pero nos es muy útil en nuestro proyecto para verificar
la funcionalidad de los túneles de forma sencilla.\

![Dashboard de administrador de
OpenVPN](./readme_media/openvpn_dashboard.png){width="0.75\\linewidth"}

Desde la dashboard podemos ver que estamos ejecutando OpenVPN sobre la
layer 3 (modo transporte), el server name y el número de usuarios
activos, entre otros. Tras desplegarlo, los paquetes enviados a través
de los túneles saldrán por la interfaz tun de la máquina D2.

![Interfaz web para descargar la configuración de un
usuario](./readme_media/openvpn_interfaz.png){#fig:enter-label
width="0.75\\linewidth"}

Exponer las diferentes subredes a las que está conectada una máquina y
sus reglas de filtrado correspondientes se deja fuera del alcance de
esta sección (principalmente porque no me da tiempo a realizarlas). Aun
así, vamos a ver como se establece correctamente una conexión desde la
máquina en la organización no confiable (por simplicidad, se ha
habilitado el acceso a la dashboard de admin desde el exterior para esta
prueba):

![H3 de OrgNoConf realizando una conexión VPN al servidor OpenVPN AS de
la
organización](./readme_media/openvpn_conexion_orgnoconf.png){width="0.9\\linewidth"}

\

# Monitorización y control de uso de la web por parte de los empleados: proxy web Squid

Configurar un proxy web Squid con un contenedor Docker es de nuevo muy
sencillo: utiliza un puerto para recibir las solicitudes de los
clientes, obtener el contenido, devolverlo al usuario y aprovechar para
guardar en caché el contenido en caso de que otro usuario lo solicite
poco tiempo después. Podemos ver que, si añadimos el proxy sobre un
navegador Firefox y realizamos una petición web a cualquier página (ej:
adidas), el contenedor de docker genera logs indicando del acceso de los
usuarios:

![Un usuario de la intranet accede a Adidas para comprarse unas
zapatillas. Nuestro proxy web Squid recibe la petición. Dependiendo de
las políticas establecidas, cacheará los contenidos estáticos de una
forma u otra.](./readme_media/squid_1.png){width="0.75\\linewidth"}

Como hemos mencionado, este proxy se tiene que configurar manualmente en
los navegadores, es decir **no es transparente**.

# Auditoria de seguridad

En una organización es muy importante definir políticas de seguridad
para verificar que los servicios externos e internos no se ven
comprometidos. Un plan de auditorias podría ayudar a detectar estos
errores antes que los actores malintencionados, salvando a la
organización de catástrofes.

## Plan de auditoría

Se va a plantear un plan de auditoría basado en tres soluciones: Nmap,
OpenVAS y Wazuh.\
\
Nmap se debería de lanzar sobre cualquier subred de la organización para
asegurar de que únicamente tiene los puertos *abiertos* de los servicios
que debería de mostrar: se debe de evitar exponer puertos como el 22
referente a conexiones SSH para que un actor no pueda *crackear* hacia
dentro de la máquina.\
\
Durante la ejecución de estas herramientas sobre la topología de la red,
se han detectado vulnerabilidades (o *missconfigurations* más bien) que
han sido corregidas.

## Nmap

Como hemos mencionado, Nmap se debería de lanzar sobre todas las
subredes de la organización. Para comprobar el correcto funcionamiento
del gateway público, se realizó un NMAP sobre su IP pública
(192.168.33.253) desde el router de externos R3. Nmap es una herramienta
que nos permitiría encontrar los servicios que podrían ser vulnerables,
no las vulnerabilidades propiamente. Sobre estos puertos, podríamos
probar vulnerabilidades sabiendo que podrían residir servicios
vulnerables (ej: un servidor Apache desactualizado).\
\
La orden nmap con único argumento la IP de la gateway nos dará los
puertos abiertos:\

![Salida de la ejecución de nmap
192.168.33.253](./readme_media/nmap_1.png){width="0.75\\linewidth"}

\
¡Oh, no! ¡El router no debería de exponer ningún servicio sobre el
puerto 22 (ssh), puerto 3000 (¿¡está exponiendo el dashboard de ntopng
públicamente!?) y la consola de administración de Fedora sobre el 9090!
Mejor añadimos reglas iptables para denegar el tráfico a esos puertos.\
\
Con la orden *nmap -sV 192.168.33.253* podemos obtener un listado de los
servicios expuestos y versiones de dichos servicios.

![Salida de la orden nmap -sV
192.168.33.253](./readme_media/nmap_2.png){width="0.75\\linewidth"}

Con las versiones de OpenSSH, nginx o la versión Mongoose de httpd
podríamos ejecutar una búsqueda de CVEs para ver si existe alguna
vulnerabilidad sobre ellos.\
\
Vale, vamos a prohibir el acceso por interfaces externas sobre el puerto
22,3000 y 9090. Ejecutamos nmap de nuevo para ver si los cambios han
sido efectivos:

![Salida de nmap 192.168.33.253 tras aplicar los cambios
necesarios](./readme_media/nmap_3.png){width="0.75\\linewidth"}

## OpenVAS

Vamos a utilizar OpenVAS, ejecutado sobre Ubuntu en A1 y desplegado en
contenedores, como herramienta para realizar escaneos exhaustivos, que
nos permitirá la generación de informes de vulnerabilidad y su visionado
a través de una interfaz web. Cada vulnerabilidad detectada puede
asociarse con una técnica específica en MITRE ATT&CK que los atacantes
podrían usar para explotarla.\
\
Para poder acceder a la dashboard de forma remota, hay que realizar unos
cambios en el fichero docker compose que se genera de su instalación,
tal y como se menciona [en la documentación
oficial](https://greenbone.github.io/docs/latest/22.4/container/workflows.html#accessing-the-web-interface-remotely).

# Detección de intrusos: Wazuh

Wazuh es una imagen de sistema operativo basado en Linux que se puede
utilizar para realizar auditorías de configuración en sistemas y
aplicaciones. En nuestro caso, configuraremos Wazuh para detectar y
alertar sobre posibles intrusiones o comportamientos anómalos. Wazuh
utiliza Suricata, que es la evolución de Snort, para detectar posibles
comportamientos erráticos.\
\
Para ello, podemos poner Wazuh en el switch virtual que recibe las
tramas que vienen de internet a la organización en modo promiscuo, para
que escuche todo lo que llega, o dentro de la DMZ para evitar que ningún
intruso se mueva lateralmente. Vamos a desplegarlo como una VM sobre la
DMZ a modo de prueba. Podemos descargar un fichero .ova, muy conveniente
para su ejecución.\
\
A la hora de realizar su ejecución, me he topado con el problema de que
no tengo suficiente espacio en mi disco para generar el disco virtual
(requiere más de 50 GB, a parte de las más de 100 GB que ocupan todas
las máquinas virtuales del proyecto), por lo que ante esta situación y
que Snort era una adición opcional, se deja en esta documentación
simplemente como mención a las tecnologías posibles.
