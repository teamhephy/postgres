FROM postgres:11-alpine

ENV WALE_LOG_DESTINATION stderr
ENV WALE_ENVDIR /etc/wal-e.d/env

RUN mkdir -p $WALE_ENVDIR \
    && echo 'http://dl-cdn.alpinelinux.org/alpine/v3.5/main' >> /etc/apk/repositories \
    && apk add --update --virtual .build-deps \
           git \
           build-base \
           libffi-dev \
           openssl-dev \
           python3-dev=3.5.6-r0 \
           linux-headers \
    && apk add \
           lzo \
           pv \
           util-linux \
           ca-certificates \
           python3=3.5.6-r0 \
    && pip3 install --upgrade pip setuptools \
    && pip install  --disable-pip-version-check --no-cache-dir \
           psycopg2-binary==2.7.6.1 \
           envdir==1.0.1 \
           wal-e[aws,azure,google,swift]==1.1.0 \
           gcloud==0.18.3 \
           oauth2client==4.1.3 \
           azure-storage==0.20.0 \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/*

COPY rootfs /

ARG PATCH_CMD="python3 /patcher-script.py"
RUN $PATCH_CMD file /bin/create_bucket /patcher-script.d/patch_boto_s3.py
RUN $PATCH_CMD module wal_e.cmd /patcher-script.d/patch_boto_s3.py
RUN $PATCH_CMD module wal_e.worker.worker_util /patcher-script.d/patch_wal_e_s3.py

CMD ["/docker-entrypoint.sh", "postgres"]
EXPOSE 5432
