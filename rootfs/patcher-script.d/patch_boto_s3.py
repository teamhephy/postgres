def patch_wal_e_hmac_auth_v4_handler():
    import os
    from boto.auth import HmacAuthV4Handler
    _init = HmacAuthV4Handler.__init__
    def wrap_init(self, *args, **kwargs):
        _init(self, *args, **kwargs)
        self.region_name = os.getenv('S3_REGION', self.region_name)
    HmacAuthV4Handler.__init__ = wrap_init


if __name__ == '__main__':
    patch_wal_e_hmac_auth_v4_handler()
