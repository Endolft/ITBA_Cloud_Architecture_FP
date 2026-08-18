import os
import json
import boto3
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

# Configuración de Entorno
S3_BUCKET = os.environ.get('S3_BACKEND_BUCKET', 'taller-backend-storage')
REGION = os.environ.get('AWS_REGION', 'us-east-1')
ENDPOINT_URL = os.environ.get('AWS_ENDPOINT_URL', None) # LocalStack

# Inicializar cliente S3
s3_client = boto3.client(
    's3',
    region_name=REGION,
    endpoint_url=ENDPOINT_URL
)

class RequestHandler(BaseHTTPRequestHandler):
    def send_cors_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_cors_headers()
        self.end_headers()

    def do_GET(self):
        parsed_path = urlparse(self.path)
        
        # Endpoint para generar la Presigned URL
        if parsed_path.path == '/api/upload-url':
            query_params = parse_qs(parsed_path.query)
            filename = query_params.get('filename', ['imagen.jpg'])[0]
            
            try:
                presigned_url = s3_client.generate_presigned_url(
                    'put_object',
                    Params={
                        'Bucket': S3_BUCKET,
                        'Key': f"fotos/{filename}",
                        'ContentType': 'image/*'
                    },
                    ExpiresIn=3600
                )
                
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.send_cors_headers()
                self.end_headers()
                
                response = {'url': presigned_url, 'filename': filename}
                self.wfile.write(json.dumps(response).encode())
                
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-type', 'application/json')
                self.send_cors_headers()
                self.end_headers()
                self.wfile.write(json.dumps({'error': str(e)}).encode())
                
        # Endpoint de salud
        elif parsed_path.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok", "service": "backend-api"}).encode())
            
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8000))
    server_address = ('', port)
    httpd = HTTPServer(server_address, RequestHandler)
    print(f"Backend corriendo en el puerto {port}...")
    httpd.serve_forever()
