#!/usr/bin/python
#Licensed under the GPLv2 (not later versions)
#see LICENSE.txt for details
# we now have 2 databases for handling the permissions of the for the OC distributing system
# Distributors are persons, who can place vendorsto deliver items to clients
# Designers are persons who can place Distribuor boxes for delivering the actual items to the clients


import cgi
import os
import re
import lindenip
import distributors
import logging
import time # needed for the time stamp

# database models moved to a separate module so it can be easy used by muliple modules
from dbmodels import FreebieItem
from dbmodels import FreebieDelivery


import wsgiref.handlers
from google.appengine.ext import db
from google.appengine.ext import webapp
from google.appengine.ext.webapp.util import run_wsgi_app

#only nandana singh adn athaliah opus are authorized to add distributors
# added Cleo Collins for the text application, remove for live application
adminkeys = ['2cad26af-c9b8-49c3-b2cd-2f6e2d808022', '98cb0179-bc9c-461b-b52c-32420d5ac8ef', 'dbd606b9-52bb-47f7-93a0-c3e427857824']

class Deliver(webapp.RequestHandler):
    def post(self):
        #check linden IP  and allowed avs
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        elif not distributors.authorized_distributor(self.request.headers['X-SecondLife-Owner-Key']): # needs to be changed to distributors.authorized_designers as soon as the changes went through
        # make sure only request from person who are allowed to place vendors will get processed
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
                    delivery = FreebieDelivery(giverkey = item.freebie_giver, rcptkey = rcpt, itemname = obj, requesttime= time.time()) # added time stamp
                    logging.info('enqueued delivery of %s to %s by %s' % (obj, rcpt, self.request.headers['X-SecondLife-Owner-Name']))
                    delivery.put()
                    self.response.out.write('hi there')
                else:
                    #return an error
                    # changed to error 405, so the vendor knows the item could not be found and inform the client
                    logging.info("No querry results for %s" % params['objname'])
                    self.error(405)
            except KeyError:
                self.error(403)

class AddDist(webapp.RequestHandler):
   # Distributors are persons which are allowed to place vendors
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
            distributors.add_distributor(params['key'], params['name'])
            self.response.out.write('Distributor added %s' % params['name'])

class AddDesigner(webapp.RequestHandler):
    # Designers are persons who are allowed to distribute items via Distributor boxes
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
            distributors.add_designer(params['key'], params['name'])
            self.response.out.write('Designer added %s' % params['name'])


def main():
  application = webapp.WSGIApplication([
                                        (r'/.*?/deliver',Deliver),
                                        (r'/.*?/adddist',AddDist),
                                        (r'/.*?/adddesigner',AddDesigner)
                                        ], debug=True)
  wsgiref.handlers.CGIHandler().run(application)


if __name__ == '__main__':
  main()