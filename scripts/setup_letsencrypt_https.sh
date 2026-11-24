#!/bin/bash

# Detenemos el script si ocurre algún error.
set -e

# Obtenemos las rutas del proyecto.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Comprobamos que se ejecuta como root.
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ejecutarse como root."
    exit 1
fi

# Cargamos las variables de entorno.
source "$SCRIPT_DIR/.env"

# Comprobamos las variables necesarias.
if [ -z "$CERTIFICATE_DOMAIN" ] || [ -z "$LETSENCRYPT_EMAIL" ]; then
    echo "Error: faltan variables de configuración en .env"
    exit 1
fi

# Instalamos Certbot y el complemento de Apache.
apt update
apt install certbot python3-certbot-apache -y

# Solicitamos el certificado y configuramos Apache.
certbot --apache \
    --non-interactive \
    --agree-tos \
    --redirect \
    --email "$LETSENCRYPT_EMAIL" \
    -d "$CERTIFICATE_DOMAIN"

echo "Configuración HTTPS completada correctamente."
