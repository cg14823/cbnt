from couchbase import CouchbaseTest


class Cbbackupmgr(CouchbaseTest):
    pass


def create_instance():
    return Cbbackupmgr()
