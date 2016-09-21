FROM keisato/docker-awscli

RUN apt-get update -y && apt-get install -y mysql-client

ADD etc/cron.d/ /etc/cron.d/
ADD usr/local/bin/ /usr/local/bin/

CMD [ "/usr/local/bin/start-cron" ]
