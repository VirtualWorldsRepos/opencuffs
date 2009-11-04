#!/usr/bin/python
#Licensed under the GPLv2 (not later versions)
#see LICENSE.txt for details

from google.appengine.ext import db
from google.appengine.api import memcache

# permission system, by bytes:
#    1 = Vendor
#    2 = Vendor who can access special/exclusive items
#    4 = Distributor
#    8 = SpecialDistributors who can the mass delivery lists

class Distributor(db.Model):
    avname = db.StringProperty()
    avkey = db.StringProperty()
    authlevel = db.IntegerProperty()

def authorized(av):
    # return the level of the  authentification
    token = "dist_auth_%s" % av
    memrecord = memcache.get(token)
    if memrecord is None:
        #dist is not in memcache, check db
        dbrecord = Distributor.gql('WHERE avkey = :1', av).get()
        if dbrecord is None:
            # add the user to the memcache, but only keep the entry shortly so we dont waste space
            memcache.set(token, 0, 300)
            return 0
        else:
            auth = dbrecord.authlevel
            memcache.set(token, auth)
            return auth
    else:
        #dist is in memcache.  check value
        return memrecord
 
def add(av, name, authstring):
# add or update the auth level of the distributor
# first the database
    auth=int(authstring)
    record = Distributor.gql('WHERE avkey = :1', av).get()
    if record is None:
        NewDist = Distributor(avkey = av, avname = name, authlevel = auth)
        NewDist.put()
    else:
        auth = record.authlevel | auth
        record.authlevel = auth
        record.put()

    # after that the memcache
    token = "dist_auth_%s" % av
    memrecord=memcache.get(token)
    if memrecord:
        memcache.replace(token, auth)
    else:
        memcache.add(token, auth)
    # and now we return the current auth level
    return auth
        
def delete(av, name, authstring):
# if auth is -99 we delete the user completly. otherwise we revoke the given permission. If the users permission is 0 than, we kill the entry
    auth=int(authstring)
    record = Distributor.gql('WHERE avkey = :1', av).get()
    token = "dist_auth_%s" % av
    if record is not None:
        if auth == 99:
        # we simply delete the user completly
            record.delete()
            memcache.delete(token)
            auth = 0
        else:
            # the user is in the db, so we update the auth level
            auth = record.authlevel & ~auth
            if auth==0:
                # if the auth is not existant anymore we delete the user
                record.delete()
                memcache.delete(token)
            else:
                # otherwise we update the aut lvel on the db
                record.authlevel = auth
                record.put()
                # and in the memecache
                memrecord=memcache.get(token)
                if memrecord:
                    memcache.replace(token, auth)
                else:
                    memcache.add(token, auth)
        # and now we return the current auth level
        return auth
    else:
        # we return -1 to signlaize something went wrong
        return -1

            
       