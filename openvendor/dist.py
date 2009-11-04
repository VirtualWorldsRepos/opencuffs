#!/usr/bin/python
#Licensed under the GPLv2 (not later versions)
#see LICENSE.txt for details

import cgi
import os
import re
import lindenip
import distributors
import logging

import yaml

import wsgiref.handlers
from google.appengine.ext import db
from google.appengine.ext import webapp
from google.appengine.ext.webapp.util import run_wsgi_app
from google.appengine.api import memcache

from updater import FreebieItem, DeliveryQueueVendors, DeliveryQueueUpdates

#only nandana singh and athaliah opus are authorized to add distributors,
# added Cleo Collins as well
adminkeys = ['2cad26af-c9b8-49c3-b2cd-2f6e2d808022', '98cb0179-bc9c-461b-b52c-32420d5ac8ef','dbd606b9-52bb-47f7-93a0-c3e427857824']

list_update_item = ['OpenCollarUpdater','OC Sub AO Updater','OpenCollar Sub AO','OpenCollar Cuffs','OpenCollar Owner Hud']

def enqueue_delivery(giver, rcpt, objname):
    # we put the item on in the database queue
    newentry = DeliveryQueueVendors(box = giver, objectname = objname, recipient = rcpt)
    newentry.put()

def enqueue_massdelivery(rcpt, objname):
    # we put the item on in the database queue
    newentry = DeliveryQueueUpdates(objectname = objname, recipient = rcpt)
    newentry.put()

class Deliver(webapp.RequestHandler):
    def post(self):
        #check linden IP  and allowed avs
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
            auth = 0
        else:
            auth = distributors.authorized(self.request.headers['X-SecondLife-Owner-Key'])
        if auth == 0:
            self.error(403)
        else:
            #populate a dictionary with what we've been given in post
            #should be newline-delimited, token=value
            lines = self.request.body.split('\n')
            params = {}
            for line in lines:
                params[line.split('=')[0]] = line.split('=')[1]

            try:
                found = False
                token = 'item_%s' % params['objname']
                memquery = memcache.get(token)
                if memquery:
                    found = True
                    authlevel = memquery['auth']
                    giverkey = memquery['giver']
                    version = memquery['version']
                else:
                    query = FreebieItem.gql('WHERE freebie_name = :1', params['objname'])
                    if query.count() > 0:
                        found= True
                        item = query.get()
                        logging.info("Auth needed: %d, avail: %d, matching: %d" % (item.freebie_auth, auth, item.freebie_auth & auth))
                        authlevel = item.freebie_auth
                        giverkey = item.freebie_giver
                        version = item.freebie_version
                        memcache.set(token, {"name": params['objname'], "version":version, "giver":giverkey, "auth":authlevel})
                        
                if found:
                    if (authlevel & auth) == authlevel:
                        giver = str(giverkey)
                        rcpt = str(params['rcpt'])
                        obj = '%s - %s' % (params['objname'], version)
                        logging.info('enqueued delivery of %s to %s by %s' % (obj, rcpt, self.request.headers['X-SecondLife-Owner-Name']))
                        if params['objname'] in list_update_item:
                            enqueue_massdelivery(rcpt, obj)
                        else:
                            enqueue_delivery(giver, rcpt, obj)
                        #delivery = FreebieDelivery(giverkey = item.freebie_giver, rcptkey = rcpt, itemname = obj)
                        #delivery.put()
                        self.response.out.write('hi there')
                    else:
                        #could not find item to look up its deliverer.  return an error
                        self.error(403)
                else:
                    #could not find item to look up its deliverer.  return an error
                    self.error(403)
            except KeyError:
                    self.error(403)

class AddDist(webapp.RequestHandler):
    def post(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        elif not self.request.headers['X-SecondLife-Owner-Key'] in adminkeys:
            self.error(403)
        else:
            #add distributor
            #populate a dictionary with what we've been given in post
            #should be newline-delimited, token=value
            lines = self.request.body.split('\n')
            params = {}
            for line in lines:
                params[line.split('=')[0]] = line.split('=')[1]
            logging.info("Add")
            # logging.info(self.request.body)
            newrights = distributors.add(params['key'], params['name'], params['auth'])
            self.response.out.write('%s has now the following rights flag: %d' % (params['name'], newrights))

class DelDist(webapp.RequestHandler):
    def post(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        elif not self.request.headers['X-SecondLife-Owner-Key'] in adminkeys:
            self.error(403)
        else:
            #add distributor
            #populate a dictionary with what we've been given in post
            #should be newline-delimited, token=value
            lines = self.request.body.split('\n')
            params = {}
            for line in lines:
                params[line.split('=')[0]] = line.split('=')[1]
            logging.info("Del")
            #logging.info(self.request.body)
            newrights = distributors.delete(params['key'], params['name'], params['auth'])
            self.response.out.write('%s has now the following rights flag: %d' % (params['name'], newrights))


def main():
  application = webapp.WSGIApplication([
                                        (r'/.*?/deliver',Deliver),
                                        (r'/.*?/adddist',AddDist),
                                        (r'/.*?/deldist',DelDist)
                                        ], debug=True)
  wsgiref.handlers.CGIHandler().run(application)


if __name__ == '__main__':
  main()