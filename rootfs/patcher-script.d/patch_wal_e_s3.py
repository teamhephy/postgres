def patch_uri_put_file():
    import os
    from wal_e.blobstore import s3
    from wal_e.blobstore.s3 import s3_util
    def wrap_uri_put_file(creds, uri, fp, content_type=None, conn=None):
        assert fp.tell() == 0
        k = s3_util._uri_to_key(creds, uri, conn=conn)
        if content_type is not None:
            k.content_type = content_type

        # Currently WALE only supports AES256, so it's a boolean value.
        encrypt_key = False
        if os.getenv('DATABASE_STORAGE') == 's3':
            if os.getenv('WALE_S3_SSE', 'None') == 'AES256':
                encrypt_key = True
        k.set_contents_from_file(fp, encrypt_key=encrypt_key)
        return k
    s3.uri_put_file = wrap_uri_put_file
    s3_util.uri_put_file = wrap_uri_put_file
patch_uri_put_file()
