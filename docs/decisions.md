# Decision log

## Formato

```text
Decision:
Contexto:
Alternativas:
Tradeoff:
Resultado:
```

## Decisiones

### 001 - Mapeo de equivalencias para entorno local (AWS vs. Local)
Decision: emular la arquitectura completa de AWS en la máquina del desarrollador mediante un stack ligero basado en Docker Compose, Caddy Server y LocalStack Community Edition.

Contexto: evitar costos accidentales en AWS real, reducir la fricción de configuración en el desarrollo diario y contar con un entorno de pruebas 100% reproducible y portable sin conexión a Internet.

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

Alternativas: usar cuentas AWS personales con riesgo de facturación accidental, pagar la licencia de LocalStack Pro o desarrollar sin emular la capa de infraestructura.

Tradeoff: la emulación local no valida las políticas de permisos IAM con el rigor estricto de AWS ni recrea la autorecuperación nativa de Fargate, pero garantiza costo cero y máxima velocidad de iteración.

Resultado: entorno de desarrollo 1:1, gratuito, resiliente y 100% compatible con los scripts de automatización en Bash.

---

### 002 - Arquitectura de red VPC Multi-AZ y subredes privadas

Decision: diseñar una VPC en 2 Zonas de Disponibilidad (us-east-1a y us-east-1b) dividida en 2 subredes públicas y 2 subredes privadas.

Contexto: aislar la base de datos (RDS) y los contenedores de la aplicación (ECS) del acceso directo desde Internet, dejando únicamente el Load Balancer (ALB) expuesto públicamente.

Alternativas: subred única pública para toda la infraestructura (más simple, pero inaceptable a nivel seguridad) o VPC mono-AZ (sin alta disponibilidad).

Tradeoff: mayor complejidad en los scripts de automatización e IDs de red a gestionar, a cambio de tolerancia a fallos y aislamiento de recursos críticos.

Resultado: red modular, segura y con alta disponibilidad (HA) automatizada mediante scripts de Bash 100% idempotentes.

---

### 003 - Seguridad Zero-Trust mediante Security Group Referencing

Decision: restringir el tráfico interno encadenando Security Groups por ID (`--source-group`) en lugar de filtrar por rangos de direcciones IP (CIDR).

Contexto: en entornos de contenedores (ECS), las IPs privadas son dinámicas y cambian en cada despliegue. Usar rangos CIDR amplios permitiría que cualquier recurso dentro de la VPC intente conectarse a la base de datos.

Alternativas: autorizar tráfico usando el rango CIDR de la subred (`10.0.0.0/16`).

Tradeoff: requiere un orden estricto en la ejecución (primero crear los 3 Security Groups y luego aplicar las reglas cruzadas), pero elimina la dependencia de IPs fijas.

Resultado: cadena de confianza estricta (`Internet ➔ ALB:80 ➔ ECS:8000 ➔ RDS:5432`). Nadie puede conectarse a la base de datos a menos que posea la credencial del Security Group de la aplicación.

---

### 004 - Estrategia de Registro de Contenedores (ECR en AWS vs. Daemon Local en LocalStack)

Decision: En AWS real usamos ECR (taller-backend), pero para correrlo localmente con LocalStack usamos directamente el Docker de la máquina (taller-backend:latest).

Contexto: LocalStack ahora pide la versión Pro (de pago) para emular ECR. Para no pagar ni agregar complejidad, hicimos que los scripts sean inteligentes: si detectan que corren en local, construyen la imagen en Docker y siguen de largo; si corren en AWS real, crean el repositorio ECR normalmente.

Alternativas:

Pagar LocalStack Pro.

Borrar create_ecr.sh (nos dejaría sin el script para cuando queramos subir esto a AWS de verdad).

Levantar un Registry local (agregaba otro contenedor y más consumo de memoria sin aportar nada).

Tradeoff: en el entorno local se omite el docker push hacia el endpoint de LocalStack para evitar limitaciones de la versión gratuita, manteniendo el script de infraestructura intacto y preparado para crear el repositorio real al desplegar en AWS.

Resultado: flujo de desarrollo local gratuito, rápido y resiliente, con scripts de IaC 100% portables a entornos reales de AWS.

---

### 005 - Manejo de Application Load Balancer (AWS ALB vs Local)

Decision: emular el Application Load Balancer (ALB) en el entorno local utilizando Caddy Server (alb-mock) en lugar de elbv2 de LocalStack.

Contexto: el servicio ELBv2 de AWS requiere la versión Pro de LocalStack. Se necesita un punto de entrada público en el puerto 80 que redirija el tráfico hacia la aplicación sin requerir licencias pagas.

Alternativas: usar Traefik (descartado por conflictos de ruteo y headers con GitHub Codespaces), requerir LocalStack Pro (descartado por costos) o no usar balanceador local (descartado por perder el aislamiento de red).

Tradeoff: se suma un contenedor liviano (caddy:2-alpine) al docker-compose.yml, pero se logra una simulación exacta del comportamiento del ALB sin modificar la lógica del script de infraestructura (create_alb.sh).

Resultado: el script create_alb.sh omite los comandos de AWS al detectar el entorno local, dejando el ruteo público a cargo de Caddy. En la nube real, creará el ALB de AWS.

---

### 006 - Estrategia de Aislamiento de Red y Ejecución de ECS
Decision: ejecutar el contenedor de la aplicación aislado en la red interna de Docker sin exponer el puerto 8000 a la máquina host (-p), delegando el acceso exclusivamente a Caddy.

Contexto: en AWS Fargate, las tareas corren en subredes privadas con el modo de red awsvpc y solo son accesibles a través del Target Group del ALB. Exponer el puerto de la aplicación al host rompería el modelo de seguridad Zero-Trust en la simulación local.

Alternativas: exponer el puerto 8000 al host mediante -p 8000:8000 (más simple, pero expone el backend directamente a Internet sin pasar por el balanceador).

Tradeoff: la aplicación solo es accesible vía http://localhost (puerto 80 de Caddy), exigiendo que el servicio de ruteo esté levantado para realizar pruebas.

Resultado: réplica 1:1 de la arquitectura de seguridad de AWS en local (Usuario ➔ Caddy:80 ➔ backend:8000).

---

### 007 - Gestión centralizada y dinámica de secretos con AWS Secrets Manager

Decision: almacenar las credenciales de la base de datos en AWS Secrets Manager (taller/db/credentials), sincronizando con .env en local y generando claves aleatorias con get-random-password en AWS real.

Contexto: evitar credenciales fijas (hardcoded) en scripts, repositorios de Git o variables de entorno expuestas, garantizando el cumplimiento de buenas prácticas de seguridad. En AWS real, el script create_rds.sh inyecta dinámicamente las claves host y dbname dentro del JSON del secreto una vez provista la instancia.

Alternativas: guardar contraseñas en archivos `.env` (alto riesgo de fuga al repositorio) o pasarlas por variables fijas en el orquestador.

Tradeoff: exige consultar el servicio de secretos en tiempo de ejecución e inyectar políticas de permisos IAM (`secretsmanager:GetSecretValue`) en la tarea de ECS.

Resultado: bóveda de secretos desacoplada, segura y compatible con desarrollo local y producción en AWS real.

---

### 008 - Aislamiento de la capa de datos mediante RDS PostgreSQL y DB Subnet Groups

Decision: desplegar la base de datos PostgreSQL en subredes privadas asociadas a un DB Subnet Group (`taller-db-subnet-group`) con acceso público bloqueado (`--no-publicly-accessible`). En desarrollo local se utiliza el contenedor nativo de Docker (`postgres:16`).

Contexto: impedir que la base de datos quede expuesta a Internet, forzando que solo el Security Group del backend (ECS) pueda conectarse en el puerto 5432.

Alternativas: desplegar RDS en subredes públicas (inaceptable a nivel seguridad) o emular el servicio en LocalStack Pro (descartado por costos de licencia).

Tradeoff: dificulta la conexión directa desde herramientas GUI locales sin un túnel de red o bastión, pero garantiza un esquema Zero-Trust.

Resultado: capa de datos aislada, segura e idempotente tanto en desarrollo local como en AWS real.

---

### 009 - Separación de Roles IAM en ECS (Task Execution Role vs Task Role)
Decision: crear dos roles independientes para las tareas de ECS: taller-ecs-execution-role (infraestructura) y taller-ecs-task-role (aplicación).

Contexto: aplicar el Principio de Menor Privilegio. El agente de ECS requiere permisos para descargar imágenes de ECR, leer secretos y escribir logs en CloudWatch, mientras que el código de la aplicación corriendo dentro del contenedor solo requiere permisos sobre los buckets de S3.

Alternativas: usar un único rol unificado para ejecución y tarea (más simple, pero vulnera la seguridad al otorgarle al runtime del contenedor permisos de infraestructura innecesarios).

Tradeoff: duplica la cantidad de políticas y roles de IAM a gestionar en los scripts de automatización.

Resultado: aislamiento total de permisos entre la capa de orquestación de AWS y la capa de aplicación/cómputo.

---

### 010 - Despliegue de Frontend Estático en S3 con CORS y Subida Directa (Presigned URLs)

Decision: alojar la interfaz de usuario como sitio web estático en un bucket dedicado de Amazon S3 (`taller-frontend-static`), configurando reglas de CORS en el bucket de almacenamiento (`taller-backend-storage`) para habilitar la subida directa de archivos desde el navegador mediante Presigned URLs.

Contexto: evitar el costo y la sobrecarga de mantener un servidor de cómputo (ECS/Nginx) corriendo 24/7 únicamente para servir HTML/CSS/JS estáticos, e impedir que el tráfico de archivos de imagen pase a través del Backend o del Load Balancer (ALB), evitando cuellos de botella de red y consumo innecesario de CPU/Memoria.

Tradeoff: exige configurar políticas de CORS explícitas en el bucket de destino y delegar la firma de URLs temporales al Backend, a cambio de desacoplar por completo la transferencia de datos.

Resultado: arquitectura Serverless de distribución estática de costo casi nulo, escalable a millones de peticiones y alineada con las mejores prácticas de AWS para manejo de blobs.

---

### 011 - Adaptación dinámica de red y CORS para Cloud IDEs (GitHub Codespaces)

Decision: implementar inyección dinámica de URLs en el Frontend (JavaScript) para soportar la ejecución remota en GitHub Codespaces sin harcodear direcciones, y requerir la exposición pública manual de puertos.

Contexto: los entornos de desarrollo en la nube (como Codespaces) exponen los contenedores mediante URLs proxy seguras. Las referencias a `localhost` o la red interna de Docker (`localstack:4566`) fallan al ejecutarse en el navegador físico del usuario. Además, las políticas estrictas de GitHub bloquean peticiones CORS si los puertos no son explícitamente públicos.

Alternativas: requerir Docker Desktop local obligatorio (excluye a usuarios con hardware limitado) o forzar al desarrollador a modificar el código HTML manualmente en cada sesión para inyectar su URL de Codespace.

Tradeoff: añade complejidad al código JavaScript del Frontend (detección de entorno en runtime mediante `window.location.origin` y expresiones regulares) y depende de un paso manual del desarrollador (cambiar puertos a Public), pero garantiza que el mismo código funcione en local y en la nube sin modificaciones.

Resultado: frontend resiliente, portable y plug-and-play, capaz de inferir su propio entorno de red para consumir el Backend y el bucket S3 simulado correctamente.