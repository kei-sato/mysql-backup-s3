#!/usr/bin/env bash

cd "$(dirname "$0")" || exit 1

S3_BUCKET=s3://bucket-$RANDOM

DOCKER_IP="$(docker-machine ip)"
export DOCKER_IP
export MYSQL_ROOT_PASSWORD=my-secret-pw
export S3_PATH="$S3_BUCKET"/mysql-backup/
export CONTAINER_MYSQL="mysql-$RANDOM"
export CONTAINER_MYSQL_BACKUP="mysql-backup-$RANDOM"
export MYSQL_PORT=13306

(cd .. && docker build -t "$CONTAINER_MYSQL_BACKUP" .) > /dev/null && echo "created image $CONTAINER_MYSQL_BACKUP"

aws s3 mb "$S3_BUCKET" && echo "created bucket $_"

cleanup() {
  docker rm -f $CONTAINER_MYSQL_BACKUP $CONTAINER_MYSQL
  docker rmi $CONTAINER_MYSQL_BACKUP > /dev/null && echo deleted $CONTAINER_MYSQL_BACKUP
  aws s3 rm --recursive $S3_BUCKET && aws s3 rb $S3_BUCKET
}

trap cleanup EXIT SIGHUP SIGINT SIGTERM

# use this for both starting and restarting
start-container() {

# start mysql server
docker run -d -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" --name "$CONTAINER_MYSQL" -p "$MYSQL_PORT":3306 mysql:5.6 > /dev/null

sleep 3

# wait connection
c=0
while ! mysql -h"$DOCKER_IP" -P"$MYSQL_PORT" -uroot -p"$MYSQL_ROOT_PASSWORD" <<< 'select now();' &> /dev/null; do
  [[ $((c++)) -gt 10 ]] && exit 1
  echo "trying mysql connection $c"
  sleep 1;
done

# automated backup to s3://bucketname/mysql-backup/ everyday, expire after 30 days
docker run -d \
-e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
-e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
-e AWS_DEFAULT_REGION="$AWS_DEFAULT_REGION" \
-e S3_PATH="$S3_PATH" \
--link "$CONTAINER_MYSQL":mysql \
-e MYSQL_HOST=mysql \
-e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
-e EXPIRE_DAY_AFTER=30 \
--name "$CONTAINER_MYSQL_BACKUP" "$CONTAINER_MYSQL_BACKUP" > /dev/null
echo created container "$CONTAINER_MYSQL_BACKUP"

sleep 3

# wait connection
c=0
while ! { docker logs "$CONTAINER_MYSQL_BACKUP" | grep -E '(empty|restored)' &> /dev/null; } do
  [[ $((c++)) -gt 100 ]] && exit 1
  echo "waiting restored $c"
  sleep 1;
done

}

start-container

# change something
mysql -h"$DOCKER_IP" -P"$MYSQL_PORT" -uroot -p"$MYSQL_ROOT_PASSWORD" << 'EOF'

DROP DATABASE IF EXISTS `Whiskey`;
CREATE DATABASE `Whiskey` CHARACTER SET utf8;
grant all privileges on `Whiskey`.* to sushi@`%` identified by 'sushi';

use `Whiskey`;

CREATE TABLE `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO `users` VALUES (1, 'jack'), (2, 'daniel');

DROP DATABASE IF EXISTS `Inception`;
CREATE DATABASE `Inception` CHARACTER SET utf8;
grant all privileges on `Inception`.* to sushi@`%` identified by 'sushi';

use `Inception`;

CREATE TABLE `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO `users` VALUES (1, 'christopher'), (2, 'nolan');

EOF

# backup manually
docker exec -it "$CONTAINER_MYSQL_BACKUP" backup

# restart
docker rm -f "$CONTAINER_MYSQL_BACKUP" "$CONTAINER_MYSQL" && start-container

# check restore result
mysql -h"$DOCKER_IP" -P"$MYSQL_PORT" -uroot -p"$MYSQL_ROOT_PASSWORD" << 'EOF'
SHOW GRANTS FOR 'sushi';
SELECT * FROM `Whiskey`.`users`;
SELECT * FROM `Inception`.`users`;
EOF
