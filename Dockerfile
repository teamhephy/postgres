FROM postgres:11

ARG DEBIAN_FRONTEND=noninteractive
ARG BUILD_DEPS='gcc git libffi-dev libssl-dev python3-dev python3-pip python3-wheel'

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        $BUILD_DEPS \
        gosu \
        lzop \
        libpq-dev \
        pv \
        python3 \
        util-linux \
        # swift package needs pkg_resources and setuptools
        python3-pkg-resources \
        python3-setuptools \
        python3-pip && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip

# setuptools from ubuntu archives is too old for googleapis-common-protos
RUN pip install --upgrade setuptools && \
    pip install --disable-pip-version-check --no-cache-dir \
        envdir==1.0.1 \
        wal-e[aws,azure,google,swift]==1.1.0 \
        gcloud==0.18.3 \
        oauth2client==4.1.3 \
        azure-storage==0.20.0

# cleanup
RUN apt-get purge -y --auto-remove $BUILD_DEPS && \
    apt-get autoremove -y && \
    apt-get clean -y

COPY rootfs /
ENV WALE_ENVDIR=/etc/wal-e.d/env
RUN mkdir -p $WALE_ENVDIR

ARG PATCH_CMD="python3 /patcher-script.py"
RUN $PATCH_CMD file /bin/create_bucket /patcher-script.d/patch_boto_s3.py
RUN $PATCH_CMD file /usr/local/bin/wal-e /patcher-script.d/patch_boto_s3.py
RUN $PATCH_CMD module wal_e.worker.worker_util /patcher-script.d/patch_wal_e_s3.py


CMD ["/docker-entrypoint.sh", "postgres"]
EXPOSE 5432
