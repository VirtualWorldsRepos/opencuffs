#!/usr/bin/python
#Licensed under the GPLv2 (not later versions)
#see LICENSE.txt for details

import cgi
import os
import re
import lindenip
import distributors
import logging

import wsgiref.handlers
from google.appengine.ext import db
from google.appengine.ext import webapp
from google.appengine.ext.webapp.util import run_wsgi_app

#only nandana singh adn athaliah opus are authorized to add distributors
adminkeys = ['2cad26af-c9b8-49c3-b2cd-2f6e2d808022', '98cb0179-bc9c-461b-b52c-32420d5ac8ef']

class FreebieItem(db.Model):
    freebie_name = db.StringProperty(required=True)
    freebie_version = db.StringProperty(required=True)
    freebie_giver = db.StringProperty(required=True)
    
class FreebieDelivery(db.Model):
    giverkey = db.StringProperty(required=True)
    rcptkey = db.StringProperty(required=True)
    itemname = db.StringProperty(required=True)#in form "name - version"
    
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
            #look for 
            try:
                query = FreebieItem.gql('WHERE freebie_name = :1', params['objname'])
                if query.count() > 0:
                    item = query.get()
                    giver = str(item.freebie_giver)
                    rcpt = str(params['rcpt'])
                    obj = '%s - %s' % (params['objname'], item.freebie_version)
                    delivery = FreebieDelivery(giverkey = item.freebie_giver, rcptkey = rcpt, itemname = obj)
                    logging.info('enqueued delivery of %s to %s by %s' % (obj, rcpt, self.request.headers['X-SecondLife-Owner-Name']))
                    delivery.put()
                    self.response.out.write('hi there')                    
                else:
                    #return an error
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
            distributors.add(params['key'], params['name'])   
            self.response.out.write('added %s' % params['name'])
    
def main():
  application = webapp.WSGIApplication([
                                        (r'/.*?/deliver',Deliver),
                                        (r'/.*?/adddist',AddDist)                                     
                                        ], debug=True)
  wsgiref.handlers.CGIHandler().run(application)


if __name__ == '__main__':
  main()