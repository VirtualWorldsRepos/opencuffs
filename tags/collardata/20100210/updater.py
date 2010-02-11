#!/usr/bin/python
#Licensed under the GPLv2 (not later versions)
#see LICENSE.txt for details

import cgi
import sys
import os
import logging
import lindenip
import distributors
import wsgiref.handlers
import datetime
import tools

from google.appengine.ext import webapp
from google.appengine.ext import db
from google.appengine.api import memcache

import yaml

null_key = "00000000-0000-0000-0000-000000000000"

class FreebieItem(db.Model):
    freebie_name = db.StringProperty(required=True)
    freebie_version = db.StringProperty(required=True)
    freebie_giver = db.StringProperty(required=True)
    freebie_owner = db.StringProperty(required=False)
    freebie_timedate = db.DateTimeProperty(required=False)
    freebie_location = db.StringProperty(required=False)
    
class FreebieDelivery(db.Model):
    giverkey = db.StringProperty(required=True)
    rcptkey = db.StringProperty(required=True)
    itemname = db.StringProperty(required=True)#in form "name - version"


class Check(webapp.RequestHandler):
    def get(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        else:        
            self.response.headers['Content-Type'] = 'text/plain'
            #look for an item with the requested name
            name = cgi.escape(self.request.get('object'))    
            version = cgi.escape(self.request.get('version'))
            update = cgi.escape(self.request.get('update'))

            #logging.info('%s checked %s version %s' % (self.request.headers['X-SecondLife-Owner-Name'], name, version))
            
            token = 'item_%s' % name
            cacheditem = memcache.get(token)
            if cacheditem is None: 
                freebieitem = FreebieItem.gql("WHERE freebie_name = :1", name).get()
                if freebieitem is None:
                    self.response.out.write("NSO %s" % (name))
                    return
                else:
                    item = {"name":freebieitem.freebie_name, "version":freebieitem.freebie_version, "giver":freebieitem.freebie_giver}
                    memcache.set(token, yaml.safe_dump(item))
            else:
                #pull the item's details out of the yaml'd dict
                item = yaml.safe_load(cacheditem)
                
            thisversion = 0.0
            try:
                thisversion = float(version)
            except ValueError:
                avname = self.request.headers['X-SecondLife-Owner-Name']
                logging.error('%s is using %s with bad version "%s" and will be sent an update' % (avname, name, version))
                
            if thisversion < float(item['version']):
                #get recipient key from http headers or request
                rcpt = self.request.headers['X-SecondLife-Owner-Key']
                
                #enqueue delivery, if queue does not already contain this delivery
                name_version = "%s - %s" % (name, item['version'])
                if update != "no":
                    if tools.enqueue_delivery(item['giver'], rcpt, name_version, self.request.host_url)==False:
                        self.error(403)
                #queue = FreebieDelivery.gql("WHERE rcptkey = :1 AND itemname = :2", rcpt, name_version)
                #if queue.count() == 0:
                #    delivery = FreebieDelivery(giverkey = item.freebie_giver, rcptkey = rcpt, itemname = name_version)
                #    delivery.put()
                #in the future return null key instead of giver's key
                self.response.out.write("%s|%s - %s" % (null_key, name, item['version']))
            else:
                self.response.out.write('current')       

class UpdateItem(webapp.RequestHandler):
    def get(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        elif not distributors.Contributor_authorized(self.request.headers['X-SecondLife-Owner-Key']):
            logging.warning("Illegal attempt to update item from %s, box %s located in %s at %s" % (self.request.headers['X-SecondLife-Owner-Name'], self.request.headers['X-SecondLife-Object-Name'], self.request.headers['X-SecondLife-Region'], self.request.headers['X-SecondLife-Local-Position']))
            self.error(403)
        else:
            self.response.headers['Content-Type'] = 'text/plain'            
            name = cgi.escape(self.request.get('object'))    
            version = cgi.escape(self.request.get('version'))
            giverkey = self.request.headers['X-SecondLife-Object-Key']
            avname = self.request.headers['X-SecondLife-Owner-Name']
            location = '%s @ %s' % (self.request.headers['X-SecondLife-Region'], self.request.headers['X-SecondLife-Local-Position'])
            timestring = datetime.datetime.utcnow()

            #look for an existing item with that name
            items = FreebieItem.gql("WHERE freebie_name = :1", name)   
            item = items.get()
            if (item == None):
                newitem = FreebieItem(freebie_name = name, freebie_version = version, freebie_giver = giverkey, freebie_owner = avname, freebie_timedate = timestring, freebie_location = location)
                newitem.put()
            else:
                item.freebie_version = version
                item.freebie_giver = giverkey
                item.freebie_owner = avname
                item.freebie_timedate = timestring
                item.freebie_location = location
                item.put()
            #update item in memcache
            token = 'item_%s' % name
            memcache.set(token, yaml.safe_dump({"name":name, "version":version, "giver":giverkey}))
            self.response.out.write('saved')    
            logging.info('saved item %s version %s by %s' % (name, version, avname))
        
class DeliveryQueue(webapp.RequestHandler):
    def get(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        elif not distributors.Contributor_authorized(self.request.headers['X-SecondLife-Owner-Key']):
            logging.warning("Illegal attempt to check for item from %s, box %s located in %s at %s" % (self.request.headers['X-SecondLife-Owner-Name'], self.request.headers['X-SecondLife-Object-Name'], self.request.headers['X-SecondLife-Region'], self.request.headers['X-SecondLife-Local-Position']))
            self.error(403)
        else:
            #get the deliveries where giverkey = key provided (this way we can still have multiple givers)
            giverkey = self.request.headers['X-SecondLife-Object-Key']
            givername = self.request.headers['X-SecondLife-Object-Name']
            pop = cgi.escape(self.request.get('pop'))#true or false.  if true, then remove items from db on returning them
            avname = self.request.headers['X-SecondLife-Owner-Name']
            logging.info('%s (%s) from %s checked' % (givername, giverkey, avname))

# to enable/disable the update routine fast, only need to update old records
            if (False): 
                timestring = datetime.datetime.utcnow()
                location = '%s @ %s' % (self.request.headers['X-SecondLife-Region'], self.request.headers['X-SecondLife-Local-Position'])

                query = FreebieItem.gql("WHERE freebie_giver = :1", giverkey)
                for record in query:
                    record.freebie_owner = avname
                    record.freebie_timedate = timestring
                    record.freebie_location = location
                    record.put()
                    logging.info('Updated %s from %s' % (record.freebie_name, avname))

            #deliveries = FreebieDelivery.gql("WHERE giverkey = :1", giverkey)
            token = "deliveries_%s" % giverkey
            deliveries = memcache.get(token)
            if deliveries is not None:
                response = ""
                #take the list of lists and format it
                #write each out in form <objname>|receiverkey, one per line
                out = '\n'.join(['|'.join(x) for x in deliveries])
                self.response.out.write(out)
                logging.info('%s got delivery string\n%s' % (givername, out))
                memcache.delete(token)
            else:
                self.response.out.write('')

def main():
  application = webapp.WSGIApplication([(r'/.*?/check',Check),
                                        (r'/.*?/givercheckin',UpdateItem),
                                        (r'/.*?/deliveryqueue',DeliveryQueue)
                                        ],
                                       debug=True)
  wsgiref.handlers.CGIHandler().run(application)


if __name__ == '__main__':
  main()
