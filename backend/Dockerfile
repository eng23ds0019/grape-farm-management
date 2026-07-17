FROM python:3.10-slim

# Install system dependencies (OpenCV requires libglib2.0 and libgl1-mesa-glx)
RUN apt-get update && apt-get install -y \
    build-essential \
    libglib2.0-0 \
    libgl1 \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy dependency specifications first to leverage Docker build cache
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY . .

# Expose port 8000 for FastAPI connections
EXPOSE 8000

# Run uvicorn server
CMD ["python", "main.py"]
