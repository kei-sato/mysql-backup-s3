
```
docker build -t mysql-backup-s3 .
docker run -d --name mysql-backup-s3 mysql-backup-s3 
```

```
MYSQL_ROOT_PASSWORD=my-secret-pw

# start mysql server
docker run -d -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" --name mysql mysql:5.6

# link with mysql server
docker run -d \
-e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
-e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
-e AWS_DEFAULT_REGION="$AWS_DEFAULT_REGION" \
-e S3_PATH=s3://bucketname/mysql-backup/ \
--link mysql:mysql \
-e MYSQL_HOST=mysql \
-e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
-e EXPIRE_DAY_AFTER=30 \
--name mysql-backup-s3 keisato/mysql-backup-s3

# restore 
docker exec -it mysql-backup-s3 restore
```

# links
- http://qiita.com/taiko19xx/items/215b9943c8aa0d8edcf6