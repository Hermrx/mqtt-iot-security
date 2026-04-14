#!/bin/bash
# ============================================================
# Script de instalación y configuración del broker MQTT seguro
# Autor: Herminio Jose Aquino Ramos — CEUPE, Módulo 9 IoT
# ============================================================

set -e

CERT_DIR=~/mqtt-certs
MOSQUITTO_DIR=/etc/mosquitto

echo "======================================"
echo " Instalación del broker Mosquitto"
echo "======================================"
sudo apt install mosquitto mosquitto-clients -y
sudo systemctl enable mosquitto

echo ""
echo "======================================"
echo " Creación de usuarios MQTT"
echo "======================================"
sudo mosquitto_passwd -c $MOSQUITTO_DIR/passwd panel
sudo mosquitto_passwd $MOSQUITTO_DIR/passwd salon
sudo mosquitto_passwd $MOSQUITTO_DIR/passwd cocina
sudo mosquitto_passwd $MOSQUITTO_DIR/passwd habitacion

echo ""
echo "======================================"
echo " Copiando configuración de autenticación y ACL"
echo "======================================"
sudo cp configs/auth.conf $MOSQUITTO_DIR/conf.d/auth.conf
sudo cp configs/acl.conf  $MOSQUITTO_DIR/acl

echo ""
echo "======================================"
echo " Generando certificados SSL/TLS"
echo "======================================"
mkdir -p $CERT_DIR && cd $CERT_DIR

# CA
openssl genrsa -out ca.key 2048
openssl req -new -x509 -days 365 -key ca.key -out ca.crt

# Clave y CSR del broker
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -config ../certs/server.cnf

# Firma del certificado
openssl x509 -req \
  -in server.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 365 \
  -extensions req_ext -extfile ../certs/server.cnf

cd -

echo ""
echo "======================================"
echo " Copiando certificados al directorio Mosquitto"
echo "======================================"
sudo cp $CERT_DIR/ca.crt $CERT_DIR/server.crt $CERT_DIR/server.key $MOSQUITTO_DIR/

sudo chown mosquitto:mosquitto $MOSQUITTO_DIR/ca.crt $MOSQUITTO_DIR/server.crt $MOSQUITTO_DIR/server.key
sudo chmod 644 $MOSQUITTO_DIR/ca.crt $MOSQUITTO_DIR/server.crt
sudo chmod 600 $MOSQUITTO_DIR/server.key

sudo cp configs/tls.conf $MOSQUITTO_DIR/conf.d/tls.conf

echo ""
echo "======================================"
echo " Reiniciando el servicio"
echo "======================================"
sudo systemctl restart mosquitto
sudo systemctl status mosquitto

echo ""
echo "✅ Configuración completada. Broker MQTT activo en puerto 8883 (TLS)."
