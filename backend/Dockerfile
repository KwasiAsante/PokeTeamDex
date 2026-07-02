FROM python:3.12-slim

WORKDIR /app

# Install dependencies first for better layer caching.
# Build context is the project root (see docker-compose.yml).
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy shared PS data so the backend can read it at startup.
COPY shared/ps_data/ /app/shared/ps_data/

# Copy the backend application.
COPY backend/ /app/

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
