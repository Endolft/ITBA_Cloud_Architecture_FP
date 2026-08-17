# Módulo de Registro de Contenedores (Amazon ECR)

Este módulo automatiza la creación del repositorio privado en **Amazon ECR** para alojar las imágenes Docker de la aplicación del Taller Mecánico en LocalStack / AWS.

## Recurso Desplegado

- **Nombre del Repositorio:** `taller-backend`
- **Escaneo de Imagen:** Activado (`scanOnPush=true`) para análisis de seguridad.
- **URI resultante:** `localhost:4566/taller-backend:latest`

---

## Uso

El script es **idempotente** (si el repositorio ya existe, no lo vuelve a crear y retorna la URI actual).

```bash
./infra/ecr/create_ecr.sh
```
