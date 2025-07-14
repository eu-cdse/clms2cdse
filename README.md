# clms2cdse
This repository holds tools to integrate Copernicus Land Monitoring Service (CLMS) data sets into the Copernicus Data Space Ecosystem (CDSE) platform

## [clms_upload.sh](https://github.com/eu-cdse/clms2cdse/blob/main/clms_upload.sh) - tool to upload nominal CLMS production to CDSE

This utility copies CLMS products from **LOCAL STORAGE** of a producer to the CDSE delivery point. If the 3-digits versioning convention in product naming (e.g. 1.1.1) is kept then the script will automatically checks if a product being uploaded has a previous version and it will replace it in the CDSE.

## Prerequisites:

- Linux distribution with bash shell and pre-installed [jq](https://jqlang.org/) , [rclone](https://rclone.org/docs/) and [gdal+ogr](https://gdal.org/en/stable/download.html#binaries) utilities.
- Exported environmental variables. Can be added to [.bashrc](https://www.digitalocean.com/community/tutorials/bashrc-file-in-linux) file:

```
export RCLONE_CONFIG_CLMS_TYPE=s3
export RCLONE_CONFIG_CLMS_ACCESS_KEY_ID=YOUR_CLMS_PUBLIC_S3_KEY
export RCLONE_CONFIG_CLMS_SECRET_ACCESS_KEY=YOUR_CLMS_PRIVATE_S3_KEY
export RCLONE_CONFIG_CLMS_REGION=default
export RCLONE_CONFIG_CLMS_ENDPOINT='https://s3.waw3-1.cloudferro.com'
export RCLONE_CONFIG_CLMS_PROVIDER='Ceph'
```
## Tool options:
```
   -b	   [REQUIRED] bucket name to upload to specific to a producer e.g. CLMS-YOUR-BUCKET-NAME
   -h      this message
   -l      [REQUIRED] local path (i.e. file system) path to input file or a directory with CLMS product name containing product files (e.g. COGs & STAC JSON metadata) 
   -o      [OPTIONAL] shall input file in the CLMS-YOUR-BUCKET-NAME bucket in the CDSE staging storage be overwritten?
   -p      [OPTIONAL] job priority ranging 0-9. Higher priority indicates that a CLMS product will be ingested faster. Default 0.  
   -r      [OPTIONAL] product name(s) to be replaced/patched by the product to uploaded. 
		       If more than one product needs to be replaced (e.g. NetCDF & COGs) than comma-separated list of names should be provided.
   -t      [CONDITIONALLY REQUIRED] if a CLMS product is a directory containing many files. This flag indicates that a CLMS folder should be combined as a TAR archive.  
   -v      clms_upload.sh version
```
## Single CLMS product upload:
```
clms_upload.sh -b CLMS-YOUR-BUCKET-NAME -l /tmp/c_gls_NDVI_200503110000_GLOBE_VGT_V3.0.1.nc
```
## Upload a directory of a CLMS product containing multiple files:
```
clms_upload.sh -b CLMS-YOUR-BUCKET-NAME -l /tmp/c_gls_NDVI_202001010000_GLOBE_PROBAV_V3.0.2.cog/ -t
```
## Batch upload of all NetCDF files stored locally in /home/ubuntu directory in 5 parallel sessions:
```
find /home/ubuntu -name '*.nc' | xargs -l -P 5 bash -c 'clms_upload.sh -b CLMS-YOUR-BUCKET-NAME -l $0'
```
## Batch upload of all COG folders residing localy in /home/ubuntu directory in 5 parallel sessions:
```
find /home/ubuntu -name "*.cog" -type d | xargs -l -P 5 bash -c 'clms_upload.sh -b CLMS-YOUR-BUCKET-NAME -l $0 -t'
```

# For WINDOWS and MacOS users the tool can be executed via Docker environment
##Build Docker container

Build the clms2cdse Docker image:

```
docker build --no-cache https://github.com/eu-cdse/clms2cdse.git -t clms2cdse
```
## Importnat Note: Handling of the input/output directories using [Bind Mounts](https://docs.docker.com/storage/bind-mounts/) in Docker
The local storage of your computer can be attached directly to the Docker Container as a Bind Mount. Consequently, you can easily manage ingestion/outputing data directly from/to your local storage. For instance:
```
docker run -it -v /home/JohnLane:/home/ubuntu
```
maps the content of the local home directory named /home/JohnLane to the /home/ubuntu directory in a Docker container.

## Problem with docker permission

Please click [here](https://betterstack.com/community/questions/how-to-fix-docker-got-permission-denied/) if you encounter the following error while running Docker container:
```
docker: permission denied while trying to connect to the Docker daemon socket at unix
```
## Single product upload using [clms_upload.sh](https://github.com/eu-cdse/clms2cdse/blob/main/clms_upload.sh):
```
docker run -it -v /home/JohnLane:/home/ubuntu -e RCLONE_CONFIG_CLMS_ACCESS_KEY_ID=YOUR_CLMS_PUBLIC_S3_KEY -e RCLONE_CONFIG_CLMS_SECRET_ACCESS_KEY=YOUR_CLMS_PRIVATE_S3_KEY clms2cdse clms_upload.sh -b CLMS-YOUR-BUCKET-NAME -l /tmp/c_gls_NDVI_200503110000_GLOBE_VGT_V3.0.1.nc
```
