FROM postgres:11-alpine

ENV WALE_LOG_DESTINATION stderr
ENV WALE_ENVDIR /etc/wal-e.d/env
ENV PGDATA_RECOVERY /var/lib/postgresql/recovery

RUN mkdir -p $WALE_ENVDIR $PGDATA_RECOVERY \
    && apk add --update --virtual .build-deps \
           git \
           build-base \
           openssl-dev \
           libffi-dev \
           python3-dev \
           linux-headers \
    && apk add \
           lzo \
           pv \
           util-linux \
           ca-certificates \
           python3 \
           py-pip \
    && pip3 install --upgrade pip setuptools \
    && pip install  --disable-pip-version-check --no-cache-dir \
           psycopg2-binary==2.8.4 \
           envdir==1.0.1 \
           wal-e[aws,azure,google,swift]==1.1.1 \
           gcloud==0.18.3 \
           oauth2client==4.1.3 \
           azure-storage-blob==12.5.0 \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/*

COPY rootfs /

VOLUME /var/lib/postgresql/recovery

ARG PATCH_CMD="python3 /patcher-script.py"
RUN $PATCH_CMD file /bin/create_bucket /patcher-script.d/patch_boto_s3.py
RUN $PATCH_CMD module wal_e.cmd /patcher-script.d/patch_boto_s3.py
RUN $PATCH_CMD module wal_e.worker.worker_util /patcher-script.d/patch_wal_e_s3.py

CMD ["/docker-entrypoint.sh", "postgres"]
EXPOSE 5432
