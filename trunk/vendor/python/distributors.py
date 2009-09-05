#!/usr/bin/python
#Licensed under the GPLv2 (not later versions)
#see LICENSE.txt for details

from google.appengine.ext import db
from google.appengine.api import memcache

import logging

from dbdefinitions import Vendor, Distributor

def distributor_authorized(av):
    #True if av is on the authorized distributor list, else False
    token = "dist_auth_%s" % av
    memrecord = memcache.get(token)
    if memrecord is None:
        #dist is not in memcache, check db
        dbrecord = Distributor.gql('WHERE avkey = :1', av).get()
        if dbrecord is None:
            memcache.set(token, False, 60)
            return False
        else:
            memcache.set(token, True, 60)
            return True
    else:
        #dist is in memcache.  check value
        if memrecord:
            return True
        else:
            return False

def distributor_add(av, name):
    record = Distributor.gql('WHERE avkey = :1', av).get()
    if record is None:
        NewDist = Distributor(avkey = av, avname = name)
        NewDist.put()
        token = "dist_auth_%s" % av
        memcache.set(token, True, 60)
        
def distributor_delete(av, name):
    record = Distributor.gql('WHERE avkey = :1', av).get()
    if record is not None:
        record.delete()
        token = "dist_auth_%s" % av
        memcache.delete(token)
       
def vendor_authorized(av):
    #True if av is on the authorized distributor list, else False
    token = "vend_auth_%s" % av
    logging.info(token)
    memrecord = memcache.get(token)
    if memrecord is None:
        logging.info('Not memcache')
        #dist is not in memcache, check db
        dbrecord = Vendor.gql('WHERE avkey = :1', av).get()
        if dbrecord is None:
            logging.info('Not found')
            memcache.set(token, False, 60)
            return False
        else:
            logging.info('found')
            memcache.set(token, True, 60)
            return True
    else:
        logging.info('Memcache')
        #dist is in memcache.  check value
        if memrecord:
            logging.info('found')
            return True
        else:
            logging.info('not found')
            return False

def vendor_add(av, name):
    record = Vendor.gql('WHERE avkey = :1', av).get()
    if record is None:
        NewVend = Vendor(avkey = av, avname = name)
        NewVend.put()
        token = "vend_auth_%s" % av
        memcache.set(token, True, 60)

def vendor_delete(av, name):
    record = Vendor.gql('WHERE avkey = :1', av).get()
    if record is not None:
        record.delete()
        token = "vend_auth_%s" % av
        memcache.delete(token)
