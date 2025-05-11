FROM ghcr.io/osgeo/gdal:ubuntu-small-3.10.2

# Install necessary packages
RUN apt-get update && \
    apt-get install -y \
        rclone && \
    rm -rf /var/lib/apt/lists/*

# Copy and set permissions for scripts
COPY clms_upload.sh /bin/clms_upload.sh

RUN chmod +x /bin/clms_upload.sh

# Set environment variables
ENV RCLONE_CONFIG_CLMS_TYPE=s3 \
    RCLONE_CONFIG_CLMS_REGION=default \
    RCLONE_CONFIG_CLMS_ENDPOINT='https://s3.waw3-1.cloudferro.com' \
    RCLONE_CONFIG_CLMS_PROVIDER='Ceph'
