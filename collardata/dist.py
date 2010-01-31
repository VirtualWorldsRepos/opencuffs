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

from updater import FreebieItem, FreebieDelivery

#only nandana singh and athaliah opus, cleo collins are authorized to add distributors
adminkeys = ['2cad26af-c9b8-49c3-b2cd-2f6e2d808022', '98cb0179-bc9c-461b-b52c-32420d5ac8ef', 'dbd606b9-52bb-47f7-93a0-c3e427857824']

def enqueue_delivery(giver, rcpt, objname):
    #check memcache for giver's queue
    token = "deliveries_%s" % giver
    queue = memcache.get(token)
    if queue is None:
        #if not, create new key and save
        memcache.set(token, yaml.safe_dump([[objname, rcpt]]))
    else:
        logging.info('queue for %s is %s' % (giver, queue))        
        deliveries = yaml.safe_load(queue)
        deliveries.append([objname, rcpt])#yes I really mean append.  this is a list of lists 
        memcache.set(token, yaml.safe_dump(deliveries))
    
class Deliver(webapp.RequestHandler):
    def post(self):
        #check linden IP  and allowed avs
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        elif not distributors.authorized(self.request.headers['X-SecondLife-Owner-Key']):
            self.error(403)
        else:
            #populate a dictionary with what we've been given in post
            #should be newline-delimited, token=value
            lines = self.request.body.split('\n')
            params = {}
            for line in lines:
                params[line.split('=')[0]] = line.split('=')[1]
            
            try:
                query = FreebieItem.gql('WHERE freebie_name = :1', params['objname'])
                if query.count() > 0:
                    item = query.get()
                    giver = str(item.freebie_giver)
                    rcpt = str(params['rcpt'])
                    obj = '%s - %s' % (params['objname'], item.freebie_version)
                    logging.info('enqueued delivery of %s to %s by %s' % (obj, rcpt, self.request.headers['X-SecondLife-Owner-Name']))
                    enqueue_delivery(giver, rcpt, obj)
                    #delivery = FreebieDelivery(giverkey = item.freebie_giver, rcptkey = rcpt, itemname = obj)
                    #delivery.put()
                    self.response.out.write('%s|%s' % (rcpt, obj))                    
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
            logging.info('Distributor added: %s (%s)' % (params['name'], params['key']))
            distributors.add(params['key'], params['name'])   
            self.response.out.write('Added distributor %s' % params['name'])

class AddContrib(webapp.RequestHandler):
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
            logging.info('Contributor added: %s (%s)' % (params['name'], params['key']))
            distributors.Contributor_add(params['key'], params['name'])
            self.response.out.write('Added contributor %s' % params['name'])

def main():
  application = webapp.WSGIApplication([
                                        (r'/.*?/deliver',Deliver),
                                        (r'/.*?/adddist',AddDist),
                                        (r'/.*?/addcontrib',AddContrib)
                                        ], debug=True)
  wsgiref.handlers.CGIHandler().run(application)


if __name__ == '__main__':
  main()