<<<<<<< HEAD
# 🔐 Seguridad en IoT — Broker MQTT Securizado

**Caso Práctico 9 | Módulo 9: Seguridad en IoT**  
**Herminio Jose Aquino Ramos**  
**CEUPE European Business School**  
**Docente: Jose Antonio Rubio**

---

## 📋 Descripción

Montaje y securización de un broker MQTT simulando un **hogar inteligente** con el protocolo MQTT (ampliamente usado en IoT y M2M). El sistema incluye dispositivos distribuidos en distintas estancias que se comunican a través de un broker central.

---

## 🏗️ Arquitectura del Sistema

```
                    Hogar Conectado
                    (MQTT Broker)
                         │
       ┌─────────────────┼─────────────────┐
       │                 │                 │
     Salón            Cocina          Habitación
       │                 │                 │
  ┌────┴────┐       ┌────┴────┐       ┌────┴────┐
  Termostato   Sensor apertura  Botón inalámbrico
  Sensor mov.       Luces          Persianas
  Luces                             Luces

                  Panel Principal
                       │
         ┌─────────────┼─────────────┐
    Visualización  Lógica auto.  Control MQTT
```

---

## 🚀 Instalación

### 1. Instalar el broker Mosquitto

```bash
sudo apt install mosquitto -y
sudo apt install mosquitto-clients -y
```

### 2. Verificar el servicio

```bash
sudo systemctl status mosquitto
```

---

## 👥 Gestión de Usuarios

### Crear usuario del Panel Principal

```bash
sudo mosquitto_passwd -c /etc/mosquitto/passwd panel
```

### Crear usuarios por estancia

```bash
sudo mosquitto_passwd /etc/mosquitto/passwd salon
sudo mosquitto_passwd /etc/mosquitto/passwd cocina
sudo mosquitto_passwd /etc/mosquitto/passwd habitacion
```

> ℹ️ El flag `-c` crea el archivo de contraseñas. Para usuarios adicionales se omite para no sobrescribir el archivo existente.

---

## ⚙️ Configuración del Broker

### Habilitar autenticación (`configs/auth.conf`)

```
allow_anonymous false
password_file /etc/mosquitto/passwd
```

Aplicar:
```bash
sudo cp configs/auth.conf /etc/mosquitto/conf.d/auth.conf
sudo systemctl restart mosquitto
```

---

## 🔑 Control de Acceso (ACL)

Ver archivo: [`configs/acl.conf`](configs/acl.conf)

| Usuario     | Puede publicar (write)         | Puede suscribirse (read)       |
|-------------|-------------------------------|-------------------------------|
| `panel`     | `home/+/+/cmd`                | `home/+/+/event`              |
| `salon`     | `home/salon/+/event`          | `home/salon/+/cmd`            |
| `cocina`    | `home/cocina/+/event`         | `home/cocina/+/cmd`           |
| `habitacion`| `home/habitacion/+/event`     | `home/habitacion/+/cmd`       |

Aplicar:
```bash
sudo cp configs/acl.conf /etc/mosquitto/acl
sudo systemctl restart mosquitto
```

---

## 🔒 Capa de Transporte Segura (SSL/TLS)

### 1. Generar la CA (Autoridad Certificadora)

```bash
mkdir ~/mqtt-certs && cd ~/mqtt-certs
openssl genrsa -out ca.key 2048
openssl req -new -x509 -days 365 -key ca.key -out ca.crt
```

### 2. Generar clave privada y CSR del broker

```bash
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -config certs/server.cnf
```

### 3. Firmar el certificado

```bash
openssl x509 -req \
  -in server.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 365 \
  -extensions req_ext -extfile certs/server.cnf
```

### 4. Copiar certificados y ajustar permisos

```bash
sudo cp ~/mqtt-certs/ca.crt ~/mqtt-certs/server.crt ~/mqtt-certs/server.key /etc/mosquitto/
sudo chown mosquitto:mosquitto /etc/mosquitto/ca.crt /etc/mosquitto/server.crt /etc/mosquitto/server.key
sudo chmod 644 /etc/mosquitto/ca.crt /etc/mosquitto/server.crt
sudo chmod 600 /etc/mosquitto/server.key
```

### 5. Configurar listener TLS (`configs/tls.conf`)

```bash
sudo cp configs/tls.conf /etc/mosquitto/conf.d/tls.conf
sudo systemctl restart mosquitto
```

---

## ✅ Pruebas de Funcionamiento

### Función 1 – Centralización de eventos

```bash
# Panel escucha todos los eventos
mosquitto_sub -h localhost -p 8883 --cafile ~/mqtt-certs/ca.crt \
  -u panel -P kali -t home/+/+/event

# Salón publica un evento
mosquitto_pub -h localhost -p 8883 --cafile ~/mqtt-certs/ca.crt \
  -u salon -P panel1 -t home/salon/movimiento/event -m "motion_detected"
```

### Función 2 – Distribución de comandos desde el panel

```bash
# Panel envía comando a las luces del salón
mosquitto_pub -h localhost -u panel -P kali -t home/salon/luces/cmd -m "on"

# Salón recibe el comando
mosquitto_sub -h localhost -u salon -P panel1 -t home/salon/+/cmd
```

### Función 3 – Aislamiento entre dispositivos

```bash
# Salón intenta leer eventos de otras estancias (debe fallar/no recibir)
mosquitto_sub -h localhost -u salon -P panel1 -t home/cocina/+/evento
mosquitto_sub -h localhost -u salon -P panel1 -t home/habitacion/+/evento
```

### Función 4 – Protección del panel frente a órdenes externas

```bash
# Dispositivo intenta enviar comando al panel (debe ser rechazado)
mosquitto_pub -h localhost -u salon -P panel1 -t home/panel/cmd -m "shutdown"
```

### Función 5 – Verificación de comunicación SSL/TLS

```bash
mosquitto_pub -h localhost -p 8883 --cafile ~/mqtt-certs/ca.crt \
  -u salon -P panel1 \
  -t home/salon/movimiento/event -m "SSL/TLS_APLICADO_Y_DEMOSTRADO"
```

---

## 📁 Estructura del Repositorio

```
mqtt-iot-security/
├── README.md
├── configs/
│   ├── auth.conf       # Configuración de autenticación
│   ├── acl.conf        # Listas de control de acceso
│   └── tls.conf        # Listener SSL/TLS (puerto 8883)
├── certs/
│   └── server.cnf      # Plantilla para generación de certificado
└── scripts/
    └── setup.sh        # Script de instalación automatizada
```

---

## 🛡️ Modelo de Seguridad Implementado

| Capa | Mecanismo | Herramienta |
|------|-----------|-------------|
| Autenticación | Usuario + contraseña | `mosquitto_passwd` |
| Autorización | ACL por topic y usuario | Mosquitto ACL |
| Confidencialidad | Cifrado en tránsito | SSL/TLS (puerto 8883) |
| Integridad | Certificado firmado por CA propia | OpenSSL |

---

## 🧰 Tecnologías Utilizadas

- **Kali Linux** — Entorno de laboratorio
- **Mosquitto 2.x** — Broker MQTT
- **OpenSSL** — Generación de certificados
- **MQTT protocol** — Comunicación IoT/M2M
=======
# mqtt-iot-security
MQTT broker security hardening with authentication, ACL, and SSL/TLS in a smart home IoT environment. Lab practice
>>>>>>> aa007a83ccdc0cb3859806dc0e11ab5b76fa9e4a
