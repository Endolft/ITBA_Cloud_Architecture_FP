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

### 001 - Laboratorios locales

Decision: usar Docker Compose y LocalStack en lugar de cuentas AWS personales.

Contexto: evitar costos accidentales y reducir la fricción de configuración.

Tradeoff: no se practica la consola AWS real en profundidad.

Resultado: los labs son reproducibles y reutilizables.

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

### 004 - Registro de Contenedores Privado en ECR con Escaneo Activo

Decision: utilizar un repositorio privado en Amazon ECR (`taller-backend`) con la opción de escaneo automático de vulnerabilidades activa (`scanOnPush=true`).

Contexto: almacenar las imágenes Docker del Backend en un registro seguro y centralizado antes de ser desplegadas en el orquestador de contenedores (ECS).

Alternativas: usar Docker Hub público (inseguro para código propietario) o compilar la imagen localmente sin registro (no simula un flujo Cloud/DevOps real).

Tradeoff: agrega el paso de etiquetado (`docker tag`) y publicación (`docker push`) al ciclo de compilación, a cambio de simular paridad total con el entorno de producción de AWS y adherir a prácticas DevSecOps.

Resultado: repositorio ECR automatizado, aislado y listo para recibir las imágenes de la aplicación.
