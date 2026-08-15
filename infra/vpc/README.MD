# Módulo de Red y Seguridad (VPC Multi-AZ)

Este módulo automatiza el despliegue de la infraestructura de red base y capas de seguridad para la aplicación del Taller Mecánico en **AWS / LocalStack**.

## 📐 Arquitectura de Red

La infraestructura está distribuida en **2 Zonas de Disponibilidad (us-east-1a y us-east-1b)** para garantizar Alta Disponibilidad (HA):

* **VPC:** `10.0.0.0/16` (`taller-vpc`) con soporte DNS activo.
* **Subredes Públicas (`/24`):** Albergan el Load Balancer (ALB) y salida a Internet vía Internet Gateway (IGW).
  * `taller-public-subnet-1` (`10.0.1.0/24`) - `us-east-1a`
  * `taller-public-subnet-2` (`10.0.2.0/24`) - `us-east-1b`
* **Subredes Privadas (`/24`):** Aisladas de Internet, albergan la aplicación (ECS) y la base de datos (RDS PostgreSQL).
  * `taller-private-subnet-1` (`10.0.10.0/24`) - `us-east-1a`
  * `taller-private-subnet-2` (`10.0.20.0/24`) - `us-east-1b`

---

##  Capa de Seguridad (Zero-Trust)

El acceso al tráfico está encadenado estrictamente mediante **Security Groups (SG Referencing)** sin exponer IPs fijas:

| Security Group | Tipo | Regla de Ingreso (Ingress) |
| :--- | :--- | :--- |
| `taller-alb-sg` | Público | HTTP (`80`) abierto a Internet (`0.0.0.0/0`). |
| `taller-ecs-sg` | Privado | Puerto app (`8000`) permitido **únicamente** desde `taller-alb-sg`. |
| `taller-rds-sg` | Privado | PostgreSQL (`5432`) permitido **únicamente** desde `taller-ecs-sg`. |

---

## 📁 Estructura del Módulo

```text
infra/vpc/
├── deploy_vpc.sh              # Orquestador principal (Paso 1 a 4)
├── create_vpc.sh             # Paso 1: Creación de VPC y DNS
├── create_subnets.sh         # Paso 2: Segmentación Multi-AZ
├── create_routing.sh         # Paso 3: Internet Gateway y Tablas de Rutas
└── create_security_groups.sh # Paso 4: Firewalls e interconexión Zero-Trust