#!/bin/bash

# Mostramos los comandos y detenemos el script si ocurre algún error.
set -e

# Obtenemos las rutas del proyecto.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Comprobamos que se ejecuta como root.
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ejecutarse como root."
    exit 1
fi

# Cargamos las variables de entorno.
source "$SCRIPT_DIR/.env"

# Comprobamos las variables necesarias.
if [ -z "$WORDPRESS_DB_NAME" ] || [ -z "$WORDPRESS_DB_USER" ] || [ -z "$WORDPRESS_DB_PASSWORD" ] || [ -z "$WORDPRESS_DB_HOST" ] || [ -z "$CERTIFICATE_DOMAIN" ]; then
    echo "Error: faltan variables de configuración en .env"
    exit 1
fi

# Definimos los directorios de instalación.
WORDPRESS_DIR="/var/www/html/wordpress"
WEB_DIR="/var/www/html"

# Descargamos WordPress.
wget https://wordpress.org/latest.tar.gz -P /tmp

# Descomprimimos el archivo descargado.
tar -xzvf /tmp/latest.tar.gz -C /tmp

# Movemos WordPress a su propio directorio.
rm -rf "$WORDPRESS_DIR"
mv -f /tmp/wordpress "$WORDPRESS_DIR"

# Creamos la base de datos.
mysql -u root <<< "DROP DATABASE IF EXISTS $WORDPRESS_DB_NAME"
mysql -u root <<< "CREATE DATABASE $WORDPRESS_DB_NAME"

# Creamos el usuario de WordPress.
mysql -u root <<< "DROP USER IF EXISTS '$WORDPRESS_DB_USER'@'$IP_CLIENTE_MYSQL'"
mysql -u root <<< "CREATE USER '$WORDPRESS_DB_USER'@'$IP_CLIENTE_MYSQL' IDENTIFIED BY '$WORDPRESS_DB_PASSWORD'"

# Asignamos permisos al usuario.
mysql -u root <<< "GRANT ALL PRIVILEGES ON $WORDPRESS_DB_NAME.* TO '$WORDPRESS_DB_USER'@'$IP_CLIENTE_MYSQL'"
mysql -u root <<< "FLUSH PRIVILEGES"

# Creamos el archivo de configuración de WordPress.
cp "$WORDPRESS_DIR/wp-config-sample.php" "$WORDPRESS_DIR/wp-config.php"

# Configuramos los datos de conexión con MySQL.
sed -i "s/database_name_here/$WORDPRESS_DB_NAME/" "$WORDPRESS_DIR/wp-config.php"
sed -i "s/username_here/$WORDPRESS_DB_USER/" "$WORDPRESS_DIR/wp-config.php"
sed -i "s/password_here/$WORDPRESS_DB_PASSWORD/" "$WORDPRESS_DIR/wp-config.php"
sed -i "s/localhost/$WORDPRESS_DB_HOST/" "$WORDPRESS_DIR/wp-config.php"

# Configuramos las direcciones de WordPress y del sitio web.
sed -i "/DB_COLLATE/a define('WP_SITEURL', 'https://$CERTIFICATE_DOMAIN/wordpress');" "$WORDPRESS_DIR/wp-config.php"
sed -i "/WP_SITEURL/a define('WP_HOME', 'https://$CERTIFICATE_DOMAIN');" "$WORDPRESS_DIR/wp-config.php"

# Eliminamos las security keys predeterminadas.
sed -i "/AUTH_KEY/d" "$WORDPRESS_DIR/wp-config.php"
sed -i "/SECURE_AUTH_KEY/d" "$WORDPRESS_DIR/wp-config.php"
sed -i "/LOGGED_IN_KEY/d" "$WORDPRESS_DIR/wp-config.php"
sed -i "/NONCE_KEY/d" "$WORDPRESS_DIR/wp-config.php"
sed -i "/AUTH_SALT/d" "$WORDPRESS_DIR/wp-config.php"
sed -i "/SECURE_AUTH_SALT/d" "$WORDPRESS_DIR/wp-config.php"
sed -i "/LOGGED_IN_SALT/d" "$WORDPRESS_DIR/wp-config.php"
sed -i "/NONCE_SALT/d" "$WORDPRESS_DIR/wp-config.php"

# Generamos nuevas security keys mediante la API de WordPress.
SECURITY_KEYS=$(curl -fsSL https://api.wordpress.org/secret-key/1.1/salt/ | tr '/' '_')

# Añadimos las nuevas security keys al archivo de configuración.
sed -i "/@-/a $SECURITY_KEYS" "$WORDPRESS_DIR/wp-config.php"

# Copiamos el archivo index.php al directorio raíz.
cp "$WORDPRESS_DIR/index.php" "$WEB_DIR/index.php"

# Modificamos index.php para cargar WordPress desde su directorio.
sed -i "s#wp-blog-header.php#wordpress/wp-blog-header.php#" "$WEB_DIR/index.php"

# Copiamos el archivo .htaccess al directorio raíz.
cp "$PROJECT_DIR/htaccess/.htaccess" "$WEB_DIR/.htaccess"

# Asignamos los permisos correspondientes.
chown -R www-data:www-data "$WORDPRESS_DIR"
chown www-data:www-data "$WEB_DIR/index.php" "$WEB_DIR/.htaccess"

# Eliminamos los archivos temporales.
rm -f /tmp/latest.tar.gz

# Habilitamos el módulo rewrite.
a2enmod rewrite

# Reiniciamos Apache.
systemctl restart apache2

echo "WordPress instalado correctamente en su propio directorio."
