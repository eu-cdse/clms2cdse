#!/bin/bash
###############################
# release notes:
# Version 1.00 [20250405] code name hermes
# Version 1.01 [20250508] update sanity checks; adding attributes: 'clms-upload-version,odp-priority'; adjust date with time zone UTC
# Version 1.02 [20250709] addiotion of rclone --s3-disable-http2 flag to resolve potential problems with GO and http2 https://forum.rclone.org/t/disable-http2-in-conf-file/49149
###############################
version="1.02"
usage()
{
cat << EOF
#This utility copies the CLMS products to CDSE staging storage.
#IMPORTANT! First export environmental variables!!!!
export RCLONE_CONFIG_CLMS_TYPE=s3
export RCLONE_CONFIG_CLMS_ACCESS_KEY_ID=YOUR_CLMS_PUBLIC_S3_KEY
export RCLONE_CONFIG_CLMS_SECRET_ACCESS_KEY=YOUR_CLMS_PRIVATE_S3_KEY
export RCLONE_CONFIG_CLMS_REGION=default
export RCLONE_CONFIG_CLMS_ENDPOINT='https://s3.waw3-1.cloudferro.com'
export RCLONE_CONFIG_CLMS_PROVIDER='Ceph'
#
# example of usage
#
# Single file upload:
clms_upload.sh -b CLMS-YOUR-BUCKET-NAME -l /tmp/c_gls_NDVI_200503110000_GLOBE_VGT_V3.0.1.nc
#
# Upload directory of a CLMS product containing multiple files:
clms_upload.sh -b CLMS-YOUR-BUCKET-NAME -l /tmp/c_gls_NDVI_202001010000_GLOBE_PROBAV_V3.0.2.cog/ -t
#
#Batch upload of all NetCDF files residing localy in /home/ubuntu directory in 5 parallel sessions:
find /home/ubuntu -name "*.nc" | xargs -l -P 5 bash -c 'clms_upload.sh -b CLMS-YOUR-BUCKET-NAME -l $0'
#
#Batch upload of all COG folders residing localy in /home/ubuntu directory in 5 parallel sessions:
find /home/ubuntu -name "*.cog" -type d | xargs -l -P 5 bash -c 'clms_upload.sh -b CLMS-YOUR-BUCKET-NAME -l $0 -t'
#
################################################################
OPTIONS:
   -b	   [REQUIRED] bucket name to upload to specific to a producer e.g. CLMS-YOUR-BUCKET-NAME
   -h      this message
   -l      [REQUIRED] local path (i.e. file system) path to input file or a directory with CLMS product name containing product files (e.g. COGs & STAC JSON metadata) 
   -o      [OPTIONAL] shall input file in the CLMS-YOUR-BUCKET-NAME bucket in the CDSE staging storage be overwritten?
   -p      [OPTIONAL] job priority ranging 0-9. Higher priority indicates that a CLMS product will be ingested faster. Default 0.  
   -r      [OPTIONAL] product name(s) to be replaced/patched by the product to uploaded. 
		   If more than one product needs to be replaced (e.g. NetCDF & COGs) than comma-separated list of names should be provided.
   -t      [CONDITIONALLY REQUIRED] if a CLMS product is a directory containing many files. This flag indicates that a CLMS folder should be combined as a TAR archive.  
   -v      clms_upload.sh version

EOF
}
priority=0
taring=0
while getopts “b:l:p:r:hotv” OPTION; do
	case $OPTION in
		b)
			bucket=$OPTARG
			;;
		h)
			usage
			exit 0
			;;
		l)
			local_file="${OPTARG%/}"
			;;
		o)  
			overwrite=' --no-check-dest'
			;;
		p)
			priority=$OPTARG
			;;
		r)  
			rep=$OPTARG
			;;
		t)  
			taring=1
			;;
		v)
			echo version $version
			exit 0
			;;
		?)
			usage
			exit 1
			;;
	esac
done
#########################################sanity checks
#verify if bucket was set
if [ -z $bucket ]; then
	echo "ERROR: Bucket name must be specified!"
	exit 1
fi
#verify if local_file was set
if [ -z $local_file ]; then
	echo "ERROR: Local path must be specified!"
	exit 2
fi
#verify if environmental variables were set
if [ -z $RCLONE_CONFIG_CLMS_TYPE ] || [ -z $RCLONE_CONFIG_CLMS_ACCESS_KEY_ID ] || [ -z $RCLONE_CONFIG_CLMS_SECRET_ACCESS_KEY ] || [ -z $RCLONE_CONFIG_CLMS_REGION ] || [ -z $RCLONE_CONFIG_CLMS_ENDPOINT ] || [ -z $RCLONE_CONFIG_CLMS_PROVIDER ]; then
	echo "ERROR: Some environmental variables starting with RCLONE_CONFIG_CLMS_XXXXX were not set!"
	exit 3
fi
#verify if file/folder exists in the local storage
if [ $taring == 1 ]; then
	if [ ! -d  $local_file ] ; then
		echo "ERROR: Directory $local_file does not exist in the local storage!"
		exit 4
	fi
else
	if [ ! -f $local_file ] ; then
		echo "ERROR: File $local_file does not exist in the local storage!"
		exit 5
	fi
fi

#verify if the product exists already in the CDSE OData 
odata_product_count=$(wget -qO - 'https://datahub.creodias.eu/odata/v1/Products?$filter=(Collection/Name%20eq%20%27CLMS%27%20and%20startswith(Name,%27'$(basename $local_file | rev | cut -f 2- -d '.' | rev)'%27))' | jq '.value | length')
if [ $odata_product_count -gt 0 ]; then
	echo 'ERROR: Such product exists in the CDSE!'
	exit 6
fi
#verify if the product has not been already deleted from the CDSE
deleted_product_count=$(wget -qO - 'https://datahub.creodias.eu/odata/v1/DeletedProducts?$filter=(Collection/Name%20eq%20%27CLMS%27%20and%20startswith(Name,%27'$(basename $local_file | rev | cut -f 2- -d '.' | rev)'%27))' | jq '.value | length')
if [ $deleted_product_count -gt 0 ]; then
	echo 'ERROR: Such product has been deleted from the CDSE!'
	exit 7
fi
#verify if the product to be uploaded is readable by gdal
if [ $taring == 1 ]; then
	for gdal_product in $(find $local_file -name '*.tif' -o -name '*.tiff' -o -name '*.nc'); do
		gdalinfo $gdal_product > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			ogrinfo $gdal_product > /dev/null 2>&1
			if [ $? -ne 0 ]; then
				echo "ERROR: GDAL can not open ${gdal_product}!"
				exit 8
			fi
		fi
	done
else
	gdalinfo $local_file > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		ogrinfo $local_file > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo "ERROR: GDAL can not open ${local_file}!"
			exit 8
		fi
	fi
fi

if [ $(basename $local_file | tr -dc '.' | wc -c) -eq 3 ] || ([ $taring == 1 ] && [ $(basename $local_file | tr -dc '.' | wc -c) -eq 2 ]); then
	#verify path number is not 0
	patch_number=$(echo $local_file | rev | cut -f 2 -d '.')
	if [ $patch_number -eq 0 ]; then
		echo "ERROR: Patch number (i.e. last digit in version) has to start with 1"
		exit 9
	fi
	product_to_replace=''
	#verify if the previous product version exists
	odata_product=$(wget -qO - 'https://datahub.creodias.eu/odata/v1/Products?$filter=(Collection/Name%20eq%20%27CLMS%27%20and%20startswith(Name,%27'$(basename $local_file | rev | cut -f 3- -d '.' | rev)'%27))')
	if [ $(printf "$odata_product" | jq '.value|length') -gt 0 ]; then
		product_to_replace=$(printf "$odata_product" |  jq -r '.value[].Name' | paste -sd, -)
		odata_patch_number=$(printf "$odata_product" |  jq '.value[0].Name' | rev | cut -f 1 -d '.' | tr -dc '0-9')
		if [ $patch_number -ne $((${odata_patch_number}+1)) ]; then
			echo "ERROR: Patch version in CDSE is ${odata_patch_number} and the patch number of the product uploaded product should be $((${odata_patch_number}+1)) but it is ${patch_number}!"
			exit 11
		fi
	fi
fi
#verify product to replace
if [ ! -z $rep ]; then
	rep_product=$(wget -qO - 'https://datahub.creodias.eu/odata/v1/Products?$filter=(Collection/Name%20eq%20%27CLMS%27%20and%20startswith(Name,%27'$(basename $rep | rev | cut -f 2- -d '.' | rev)'%27))')
	if [ $(printf "$rep_product" | jq '.value|length') -gt 0 ]; then
		product_to_replace=$(printf "$rep_product" |  jq -r '.value[].Name' | paste -sd, -)
	else
		echo "ERROR: Product to patched does not exist in the CDSE: $rep"
		exit 12
	fi
fi
#print products to be replaced
if [ ! -z $product_to_replace ]; then
	echo "INFO: Following products will be patched in the CDSE: $product_to_replace"
fi

last_modified=$(date -r $local_file '+%Y-%m-%dT%H:%M:%SZ')
#tar directory if needed
if [ $taring == 1 ]; then
	echo "INFO: Taring directory: $local_file"
	cd ${local_file}
	tar cf "/tmp/$(basename ${local_file} | sed 's/\(.*\)\./\1_/').tar" -C $local_file .
	if [ $? -ne 0 ];then
		echo "ERROR: Could not tar the directory: $local_file"
		exit 13
	fi
	local_file="/tmp/$(basename ${local_file} | sed 's/\(.*\)\./\1_/').tar"
fi
s3_path=${bucket}$(date --date now '+/%Y/%m/%d')
timestamp=$(date -u -d now '+%Y-%m-%dT%H:%M:%SZ')
file_size=$(du -smb --apparent-size $local_file | cut -f1)
md5_checksum=$(md5sum -b $local_file | cut -c-32)
rclone -q copy --s3-disable-http2 --s3-no-check-bucket --retries=20 --low-level-retries=20 --checksum --s3-use-multipart-uploads='false' --metadata --metadata-set odp-priority=$priority --metadata-set clms-upload-version=$version --metadata-set uploaded=$timestamp --metadata-set WorkflowName="clms_upload" --metadata-set source-s3-endpoint-url=$RCLONE_CONFIG_CLMS_ENDPOINT --metadata-set file-size=$file_size --metadata-set md5=$md5_checksum --metadata-set last_modified=$last_modified --metadata-set s3-public-key=${RCLONE_CONFIG_CLMS_ACCESS_KEY_ID} --metadata-set source_s3_path='s3://'${s3_path} --metadata-set source_cleanup=true --metadata-set product_to_replace=${product_to_replace}${overwrite} $local_file CLMS:$s3_path
[ $? == 1 ] && echo "ERROR: Failed to upload $local_file to s3://${s3_path}" || echo "SUCCESS: Uploaded $local_file to s3://${s3_path}"
if [ $taring == 1 ]; then
	rm -v "/tmp/$(basename ${local_file})"
fi
