#!/bin/bash

# Mostramos los comandos y detenemos el script si ocurre algún error.
set -ex

# Obtenemos las rutas del proyecto.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Comprobamos que se ejecuta como root.
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ejecutarse como root."
    exit 1
fi

# Actualizamos el sistema.
apt update
apt upgrade -y

# Instalamos Apache.
apt install apache2 -y

# Copiamos la configuración del VirtualHost.
cp "$PROJECT_DIR/conf/000-default.conf" /etc/apache2/sites-available/000-default.conf

# Instalamos PHP y los módulos necesarios para WordPress.
apt install php libapache2-mod-php php-mysql php-curl php-gd php-mbstring php-xml php-zip php-intl -y

# Instalamos MySQL Server.
apt install mysql-server -y

# Instalamos herramientas necesarias.
apt install wget curl unzip -y

# Habilitamos el módulo rewrite de Apache.
a2enmod rewrite

# Comprobamos la configuración de Apache.
apache2ctl configtest

# Habilitamos los servicios para que arranquen automáticamente.
systemctl enable apache2
systemctl enable mysql

# Reiniciamos Apache.
systemctl restart apache2

echo "Instalación LAMP completada correctamente."
