# Credits & Tools

Este repositorio se construyó utilizando las siguientes herramientas y proyectos:

- **Amazon Web Services (AWS):** servicios de referencia de la arquitectura,
  incluyendo VPC, ECS/Fargate, ECR, RDS, S3, CloudFront, IAM, Secrets Manager,
  CloudWatch y Application Load Balancer.
  https://aws.amazon.com/
- **LocalStack:** emulación local de servicios de AWS para desarrollo y pruebas.
  https://www.localstack.cloud/
- **Docker y Docker Compose:** ejecución y orquestación del entorno local.
  https://www.docker.com/
- **PostgreSQL:** base de datos utilizada en el entorno local y como motor de RDS.
  https://www.postgresql.org/
- **Caddy:** reverse proxy utilizado como mock local del Application Load Balancer.
  https://caddyserver.com/
- **Python, Boto3 y psycopg2:** implementación del backend mock e integración con
  AWS y PostgreSQL.
  https://www.python.org/ · https://boto3.amazonaws.com/ · https://www.psycopg.org/
