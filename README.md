#  ITBA - Proyecto Integrador: Plan de Migración a AWS (Plataforma Hudson)
**Integrantes: Agustin Fernandez**

---

##  Visión General del Proyecto

**Hudson** es una plataforma integral B2B/B2C diseñada para la gestión del ecosistema automotor (talleres, propietarios y venta de autopartes). Este proyecto diseña y ejecuta la migración de la infraestructura de Hudson desde un monolito local (*on-premise*) hacia una **arquitectura en la nube de AWS de 3 capas (3-tier)**, serverless, elástica y de alta disponibilidad.

### Aspectos Clave de la Arquitectura
- **Frontend Serverless:** React SPA alojado en **Amazon S3** (`taller-frontend-static`) y distribuido globalmente mediante **Amazon CloudFront CDN**.
- **Backend Contenedorizado:** API en Python/Docker orquestada con **Amazon ECS + AWS Fargate** en subredes privadas, expuesta a través de un **Application Load Balancer (ALB)**.
- **Base de Datos Relacional Aislada:** **Amazon RDS PostgreSQL 16 Multi-AZ** (Principal en `AZ-1a` y Standby en `AZ-1b`) con una **Read Replica** dedicada para consultas analíticas de administración.
- **Almacenamiento Inteligente de Fotos:** Subida directa desde el navegador/App móvil a **Amazon S3** (`taller-backend-storage`) mediante **Presigned URLs**, reduciendo la carga del backend y el ancho de banda del ALB.
- **Seguridad Zero-Trust:** Encadenamiento de tráfico por referencias entre Security Groups (`ALB → ECS → RDS`), secretos cifrados en **AWS Secrets Manager** y comunicación privada a S3 vía **VPC Gateway Endpoint**.

---

##  Inicio Rápido (Despliegue Local e IaC)

La infraestructura como código (IaC) está completamente automatizada mediante scripts idempotentes en Bash y un entorno emulado con **Docker Compose + LocalStack + Caddy**.

### Requisitos Previos
- **Docker Desktop** (o Docker Engine) y **Docker Compose**.
- **Python 3.x**.
- **Git**.

### Pasos para Ejecutar

1. **Clonar el repositorio:**

```bash
git clone <URL_DE_TU_REPOSITORIO>
cd ITBA_Cloud_Architecture_FP
```

2. Levantar los contenedores
```bash
docker compose up -d
```

3. **Desplegar la infraestructura completa:**

```bash
./scripts/deploy_all.sh
```

4. **Verificar la salud de los servicios:**

```bash
./scripts/check.sh
```

Si estás evaluando este proyecto dentro de GitHub Codespaces, la plataforma bloquea por defecto el tráfico entre distintos puertos privados desde el navegador, lo que genera errores sintéticos de CORS (Failed to fetch).

Pasos obligatorios antes de probar la aplicación:

1. Abre la pestaña Ports (Puertos) en la terminal inferior de VS Code.
2. Busca los puertos 80 (Backend / ALB Mock) y 4566 (LocalStack / S3 Mock).
3. Haz clic derecho sobre la columna Visibility (que dirá Private) y cámbialos a Public.
4. Verifica que ambos puertos muestren el ícono del candado abierto.
5. Recarga la página del Frontend e inicia las pruebas de subida de imágenes.

### Estructura del Repositorio

- **docs/** — Documentación y reportes
  - `architecture.md` — Informe de Arquitectura As-Is/To-Be y Objetivos SMART
  - `decisions.md` — Registro de 13 Decisiones de Arquitectura (ADR)
  - `plan.md` — Plan de Migración a 8 semanas y Matriz de Riesgos
  - `costs_calculator.pdf` — Estimación de Costos Mensuales (AWS Calculator)

- **infra/** — Scripts de infraestructura como código (IaC)
  - `vpc/` — Red Multi-AZ, Subredes y VPC Gateway Endpoint
  - `secrets/` — Gestión de secretos con AWS Secrets Manager
  - `rds/` — DB Subnet Groups e instancia PostgreSQL 16
  - `ecr/` — Repositorio de imágenes de contenedores
  - `s3/` — Buckets estáticos, storage de fotos, CORS y Frontend
  - `s3/create_cloudfront.sh` — Distribución CloudFront con origen S3 privado y OAC
  - `iam/` — Roles y Políticas de Menor Privilegio (ECS Task/Execution)
  - `alb/` — Application Load Balancer y Target Groups
  - `ecs/` — Tareas de Fargate y Auto-Scaling
  - `ecs/configure_autoscaling.sh` — Escalado por CPU del servicio ECS

- **scripts/**
  - `deploy_all.sh` — Orquestador principal de despliegue idempotente
  - `check.sh` — Script de diagnóstico y validación de salud

- **backend_mock/** — Código fuente de la API Python, requirements y Dockerfile
- **compose.yaml** — Entorno de emulación local (Postgres, LocalStack, Caddy)
- **README.md** — Guía principal del repositorio


###  Equivalencias de Arquitectura (Local vs. AWS Cloud)

| Servicio Cloud (AWS Real) | Homólogo en Entorno Local | Implementación y Comportamiento Local |
| :--- | :--- | :--- |
| **AWS VPC & Subredes** | LocalStack EC2 + Red Bridge de Docker | LocalStack emula la API (`vpc-xxx` y Security Groups) para los scripts, mientras que la red de Docker maneja el aislamiento de tráfico real. |
| **AWS ALB (ELBv2)** | Caddy Server (`alb-mock`) | Reverse proxy en puerto 80 que enruta el tráfico hacia la app en la red privada. |
| **AWS ECS Fargate** | Docker Daemon (`docker run`) | Ejecución del contenedor backend aislado sin exponer puertos al host (`-p`). |
| **AWS ECR** | Docker Engine Local | Construcción y etiquetado local de la imagen (`taller-backend:latest`). |
| **AWS RDS PostgreSQL** | Contenedor `postgres:16` | Instancia local de PostgreSQL accesible solo por el Security Group simulado. |
| **AWS Secrets Manager** | LocalStack Secrets Manager | Bóveda emulada que sincroniza las claves dinámicamente desde el archivo `.env`. |
| **AWS S3** | LocalStack S3 | Buckets locales para archivos del backend y alojamiento del frontend estático. |
| **AWS CloudWatch Logs** | LocalStack Logs / `docker logs` | Grupo de logs `/ecs/taller-backend` y volcado de trazas vía CLI de Docker. |
| **AWS IAM Roles** | LocalStack IAM | Definición e inyección de variables de credenciales (`test`/`test`) en runtime. |
