#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ejecutarse como root."
    exit 1
fi

source "$SCRIPT_DIR/.env"

if [ -z "$WORDPRESS_DB_NAME" ] || \
   [ -z "$WORDPRESS_DB_USER" ] || \
   [ -z "$WORDPRESS_DB_PASSWORD" ] || \
   [ -z "$WORDPRESS_DB_HOST" ] || \
   [ -z "$IP_CLIENTE_MYSQL" ]; then
    echo "Error: faltan variables de configuración en .env"
    exit 1
fi

WORDPRESS_DIR="/var/www/html"

# Creamos la base de datos.
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS \`${WORDPRESS_DB_NAME}\`
DEFAULT CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;
EOF

# Creamos el usuario y asignamos permisos.
mysql -u root <<EOF
CREATE USER IF NOT EXISTS '${WORDPRESS_DB_USER}'@'${IP_CLIENTE_MYSQL}'
IDENTIFIED BY '${WORDPRESS_DB_PASSWORD}';
ALTER USER '${WORDPRESS_DB_USER}'@'${IP_CLIENTE_MYSQL}'
IDENTIFIED BY '${WORDPRESS_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${WORDPRESS_DB_NAME}\`.* 
TO '${WORDPRESS_DB_USER}'@'${IP_CLIENTE_MYSQL}';
FLUSH PRIVILEGES;
EOF

# Descargamos WordPress.
cd /tmp
wget -O latest.tar.gz https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz

# Descargamos las claves de seguridad.
curl -fsSL https://api.wordpress.org/secret-key/1.1/salt/ -o wordpress-salts.php

# Sustituimos el contenido del directorio web.
rm -rf "$WORDPRESS_DIR"/*
cp -r /tmp/wordpress/. "$WORDPRESS_DIR/"

# Creamos y configuramos wp-config.php.
cp "$WORDPRESS_DIR/wp-config-sample.php" "$WORDPRESS_DIR/wp-config.php"

sed -i "s/database_name_here/${WORDPRESS_DB_NAME}/" "$WORDPRESS_DIR/wp-config.php"
sed -i "s/username_here/${WORDPRESS_DB_USER}/" "$WORDPRESS_DIR/wp-config.php"
sed -i "s/password_here/${WORDPRESS_DB_PASSWORD}/" "$WORDPRESS_DIR/wp-config.php"
sed -i "s/localhost/${WORDPRESS_DB_HOST}/" "$WORDPRESS_DIR/wp-config.php"

# Sustituimos las claves de ejemplo por las generadas.
python3 - <<'PY'
from pathlib import Path

config = Path("/var/www/html/wp-config.php")
salts = Path("/tmp/wordpress-salts.php")

content = config.read_text()
generated_salts = salts.read_text()

start = content.index("define( 'AUTH_KEY'")
end = content.index("define( 'NONCE_SALT'") 
end = content.index(";", end) + 1

content = content[:start] + generated_salts + content[end:]
config.write_text(content)
PY

# Asignamos permisos.
chown -R www-data:www-data "$WORDPRESS_DIR"
find "$WORDPRESS_DIR" -type d -exec chmod 755 {} \;
find "$WORDPRESS_DIR" -type f -exec chmod 644 {} \;

# Eliminamos archivos temporales.
rm -rf /tmp/wordpress /tmp/latest.tar.gz /tmp/wordpress-salts.php

# Reiniciamos Apache.
systemctl restart apache2

echo "WordPress instalado correctamente en el directorio raíz."
