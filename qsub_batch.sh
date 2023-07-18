#! /bin/bash

source ~/miniconda3/etc/profile.d/conda.sh
conda activate dina

cd ~/dina-image-upload
output=`./upload_assets_worker.rb --identifier $SGE_TASK_ID`
echo "$output" | tee -a upload_assets_output.csv  >/dev/null
