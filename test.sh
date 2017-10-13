#!/bin/bash

# edit this stuff to test with
# TODO: make it get this stuff from CF/terraform/aws/whatever
export PGUSER=defaultuser
export PGPASSWORD=TotallyS3cur3Password
export PGHOST=fox.cmjzzq0b5wgo.us-east-1.redshift.amazonaws.com
export PGPORT=5439
export PGDATABASE=dev

BUCKET=fox-cluster-bucket
IAM_ROLE=arn:aws:iam::948887820110:role/foxRedshiftRole

PSQL="psql"
# okay stop editing

echo "Syncing test files to AWS"

rm -rf temp
mkdir temp
pushd temp
unzip ../LoadingDataSampleFiles.zip
aws s3 sync LoadingDataSampleFiles/ s3://${BUCKET}/load
popd
rm -rf temp

echo "Creating redshift tables"
${PSQL} < tables.sql

echo "Copying part CSV data from s3 with null as"
${PSQL} -c "copy part from 's3://${BUCKET}/load/part-csv.tbl'
iam_role '${IAM_ROLE}' csv null as '\000';"

echo "Selecting part data with nulls"
${PSQL} -c "select p_partkey, p_name, p_mfgr, p_category from part where p_mfgr is null;"

echo "Loading dwdate table"
${PSQL} -c "copy dwdate from 's3://${BUCKET}/load/dwdate-tab.tbl'
iam_role '${IAM_ROLE}'
delimiter '\t'
dateformat 'auto';"

echo "Vacuuming"
${PSQL} -c "vacuum;"

echo "Analyzing"
${PSQL} -c "analyze;"

echo "Checking tables"
${PSQL} -c "select
(select count(*) from part) as parts,
(select count(*) from supplier) as suppliers,
(select count(*) from customer) as customers,
(select count(*) from dwdate) as dates,
(select count(*) from lineorder) as orders;
"

echo "Test writing to s3"
${PSQL} -c "
UNLOAD ('select * from part')
TO 's3://${BUCKET}'
iam_role '${IAM_ROLE}'
gzip
allowoverwrite;
"
