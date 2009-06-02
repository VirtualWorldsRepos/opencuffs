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
from google.appengine.api import urlfetch
from google.appengine.ext import webapp
from google.appengine.ext import db

null_key = "00000000-0000-0000-0000-000000000000"

class FreebieItem(db.Model):
    freebie_name = db.StringProperty(required=True)
    freebie_version = db.StringProperty(required=True)
    freebie_giver = db.StringProperty(required=True)
    
class FreebieDelivery(db.Model):
    giverkey = db.StringProperty(required=True)
    rcptkey = db.StringProperty(required=True)
    itemname = db.StringProperty(required=True)#in form "name - version"


class Check(webapp.RequestHandler):
    def get(self):
        self.response.headers['Content-Type'] = 'text/plain'
        #look for an item with the requested name
        name = cgi.escape(self.request.get('object'))    
        version = cgi.escape(self.request.get('version'))
        #creator = cgi.escape(self.request.get('creator'))
        logging.info('%s checked %s version %s' % (self.request.headers['X-SecondLife-Owner-Name'], name, version))
        items = FreebieItem.gql("WHERE freebie_name = :1", name)   
        #items = FreebieItem2.gql("WHERE name = :1 AND creator = :2", name, creator)
        item = items.get()   
        if (item == None):
            self.response.out.write("NSO %s" % (name))
        else:
            thisversion = 0.0
            try:
                thisversion = float(version)
            except ValueError:
                avname = self.request.headers['X-SecondLife-Owner-Name']
                logging.error('%s is using %s with bad version "%s" and will be sent an update' % (avname, name, version))
                
            if thisversion < float(item.freebie_version):
                #get recipient key from http headers or request
                try:
                    rcpt = self.request.headers['X-SecondLife-Owner-Key']
                    #self.response.out.write(owner)
                except KeyError:
                    #self.response.out.write('Error: no owner key provided')
                    #try to get key from url
                    rcpt = cgi.escape(self.request.get('recipient'))
                
                if rcpt == '':
                    #error
                    self.response.out.write('Error: no recipient specified')
                else:
                    #enqueue delivery, if queue does not already contain this delivery
                    name_version = "%s - %s" % (name, item.freebie_version)
                    queue = FreebieDelivery.gql("WHERE rcptkey = :1 AND itemname = :2", rcpt, name_version)
                    if queue.count() == 0:
                        delivery = FreebieDelivery(giverkey = item.freebie_giver, rcptkey = rcpt, itemname = name_version)
                        delivery.put()
                    #in the future return null key instead of giver's key
                    self.response.out.write("%s|%s - %s" % (null_key, item.freebie_name, item.freebie_version))
            else:
                self.response.out.write('current')       

class UpdateItem(webapp.RequestHandler):
    def get(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        elif not distributors.authorized(self.request.headers['X-SecondLife-Owner-Key']):
            self.error(403)
        else:
            self.response.headers['Content-Type'] = 'text/plain'            
            name = cgi.escape(self.request.get('object'))    
            version = cgi.escape(self.request.get('version'))
            giverkey = self.request.headers['X-SecondLife-Object-Key']
            avname = self.request.headers['X-SecondLife-Owner-Name']
            #look for an existing item with that name
            items = FreebieItem.gql("WHERE freebie_name = :1", name)   
            item = items.get()
            if (item == None):
                newitem = FreebieItem(freebie_name = name, freebie_version = version, freebie_giver = giverkey)
                newitem.put()
            else:
                item.freebie_version = version
                item.freebie_giver = giverkey
                item.put()
            self.response.out.write('saved')    
            logging.info('saved item %s version %s by %s' % (name, version, avname))
        
class DeliveryQueue(webapp.RequestHandler):
    def get(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        elif not distributors.authorized(self.request.headers['X-SecondLife-Owner-Key']):
            self.error(403)
        else:        
            #get the deliveries where giverkey = key provided (this way we can still have multiple givers)
            giverkey = self.request.headers['X-SecondLife-Object-Key']
            pop = cgi.escape(self.request.get('pop'))#true or false.  if true, then remove items from db on returning them
            avname = self.request.headers['X-SecondLife-Owner-Name']
            
            deliveries = FreebieDelivery.gql("WHERE giverkey = :1", giverkey)
            #write each out in form <objname>|receiverkey
            response = ""
            for delivery in deliveries:
                #make sure the response is shorter than 2048.  If longer, then stop looping and set last line to "more", so giver will know to request again
                if len(response) > 2000:
                    response += "\nmore"
                    break
                else:
                    response += "%s|%s\n" % (delivery.itemname, delivery.rcptkey)
                    logging.info('%s\'s box delivering %s to %s' % (avname, delivery.itemname, delivery.rcptkey))
                    #delete from datastore
                    if pop == 'true':
                        delivery.delete()
            self.response.out.write(response) 

def main():
  application = webapp.WSGIApplication([(r'/.*?/check',Check),
                                        (r'/.*?/givercheckin',UpdateItem),
                                        (r'/.*?/deliveryqueue',DeliveryQueue)
                                        ],
                                       debug=True)
  wsgiref.handlers.CGIHandler().run(application)


if __name__ == '__main__':
  main()
