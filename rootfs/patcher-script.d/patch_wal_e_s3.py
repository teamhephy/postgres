def patch_uri_put_file():
    import os
    from wal_e.blobstore import s3
    from wal_e.blobstore.s3 import s3_util
    def wrap_uri_put_file(creds, uri, fp, content_type=None, conn=None):
        assert fp.tell() == 0
        k = s3_util._uri_to_key(creds, uri, conn=conn)
        if content_type is not None:
            k.content_type = content_type
        if os.getenv('DATABASE_STORAGE') == 's3':
            encrypt_key=True
        else:
            encrypt_key=False
        k.set_contents_from_file(fp, encrypt_key=encrypt_key)
        return k
    s3.uri_put_file = wrap_uri_put_file
    s3_util.uri_put_file = wrap_uri_put_file
patch_uri_put_file()
