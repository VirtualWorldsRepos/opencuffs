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
from google.appengine.ext import webapp
from google.appengine.ext import db
from google.appengine.api import memcache

import yaml

new_updater_url = "http://openvendor.appspot.com/updater"

list_update_item = ['OpenCollarUpdater','OC Sub AO Updater','OpenCollar Sub AO','OpenCollar Cuffs','OpenCollar Owner Hud']

class DeliveryQueueVendors(db.Model):
    box = db.StringProperty()
    objectname = db.StringProperty()
    recipient = db.StringProperty()
    date = db.DateTimeProperty(auto_now_add=True)
    
class DeliveryQueueUpdates(db.Model):
    objectname = db.StringProperty()
    recipient = db.StringProperty()
    date = db.DateTimeProperty(auto_now_add=True)

null_key = "00000000-0000-0000-0000-000000000000"


class FreebieItem(db.Model):
    freebie_name = db.StringProperty(required=True)
    freebie_version = db.StringProperty(required=True)
    freebie_giver = db.StringProperty(required=True)
    freebie_owner = db.StringProperty(required=True)
    freebie_auth = db.IntegerProperty(required=True)
    freebie_date = db.DateTimeProperty(auto_now_add=True)

    
def enqueue_delivery(giver, rcpt, objname):
    # we put the item on in the database queue
    newentry = DeliveryQueueVendors(vendorqueue = giver, objectname = objname, recipient = rcpt)
    newentry.put()

def enqueue_massdelivery(rcpt, objname):
    # we put the item on in the database queue
    newentry = DeliveryQueueUpdates(objectname = objname, recipient = rcpt)
    newentry.put()


class Check(webapp.RequestHandler):
    def get(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)

        name = cgi.escape(self.request.get('object'))
        #normal item so check it normaly. til we move this over to the new app
        self.response.headers['Content-Type'] = 'text/plain'
        #look for an item with the requested name
        version = cgi.escape(self.request.get('version'))
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
                memcache.set(token, item)
        else:
            #pull the item's details out of the yaml'd dict
            item =cacheditem

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
            if name in list_update_item:
                enqueue_massdelivery(rcpt, name_version)
            else:
                enqueue_delivery(giver, rcpt, name_version)
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
        elif not distributors.authorized(self.request.headers['X-SecondLife-Owner-Key']):
            self.error(403)
        else:
            self.response.headers['Content-Type'] = 'text/plain'            
            name = cgi.escape(self.request.get('object'))    
            version = cgi.escape(self.request.get('version'))
            authlevel = cgi.escape(self.request.get('auth'))
            auth=int(authlevel)
            giverkey = self.request.headers['X-SecondLife-Object-Key']
            avname = self.request.headers['X-SecondLife-Owner-Name']
            #look for an existing item with that name
            items = FreebieItem.gql("WHERE freebie_name = :1", name)   
            item = items.get()
            if (item == None):
                newitem = FreebieItem(freebie_name = name, freebie_version = version, freebie_giver = giverkey, freebie_owner = avname, freebie_auth = auth)
                newitem.put()
                logging.info('saved item %s version %s by %s (Auth level: %d)' % (name, version, avname, auth))
            else:
                item.freebie_version = version
                item.freebie_giver = giverkey
                item.freebie_auth = auth
                if item.freebie_owner == avname:
                    logging.info('updated item %s version %s by %s (Auth level: %d)' % (name, version, avname, auth))
                else:
                    logging.warning('updated item %s version %s by %s (Auth level: %d), former owner was %s' % (name, version, avname, auth, item.freebie_owner))
                item.freebie_owner = avname
                item.put()
            #update item in memcache
            token = 'item_%s' % name
            memcache.set(token, {"name":name, "version":version, "giver":giverkey, "auth":auth})
            self.response.out.write('saved')    
            
        
class DeliveryQueue(webapp.RequestHandler):
    def get(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        auth = distributors.authorized(self.request.headers['X-SecondLife-Owner-Key'])
        if auth == 0:
            logging.info("403:%s:%d" % (self.request.headers['X-SecondLife-Owner-Key'],auth))
            self.error(403)
        else:        
            #get the deliveries where giverkey = key provided (this way we can still have multiple givers)
            giverkey = self.request.headers['X-SecondLife-Object-Key']
            givername = self.request.headers['X-SecondLife-Object-Name']
            pop = cgi.escape(self.request.get('pop'))#true or false.  if true, then remove items from db on returning them
            avname = self.request.headers['X-SecondLife-Owner-Name']
            
            out=''
            
            # send maximum 20 request to make sure the answer is 2048 bytes
            logging.info("WHERE vendorqueue = %s ORDER BY date ASC LIMIT 20" % giverkey)
#            query = DeliveryQueueVendors.gql("WHERE vendorqueue = ':1' LIMIT 20", giverkey)
#            deliveries=query.get()
            deliveries = DeliveryQueueVendors.gql('WHERE box = :1 LIMIT 20', giverkey)
            if deliveries:
                # if there is something in the queue we send it in the format objectname|recipientkey to the distributor box, 1 per line
                for delivery in deliveries:
                    out = out + ('%s|%s\n' % (delivery.objectname,delivery.recipient))
                    # now delete the delivery
                    delivery.delete()
            # and send it to the box
            self.response.out.write(out)


class MassDelivery(webapp.RequestHandler):
    def get(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        auth = distributors.authorized(self.request.headers['X-SecondLife-Owner-Key'])
        if auth & 8 == 0:
        # only allow access for mass delivery users
            self.error(403)
        else:
            #get the deliveries where giverkey = key provided (this way we can still have multiple givers)
            name = cgi.escape(self.request.get('object'))
            version = cgi.escape(self.request.get('version'))
            pop = cgi.escape(self.request.get('pop'))#true or false.  if true, then remove items from db on returning them
            avname = self.request.headers['X-SecondLife-Owner-Name']
            objname = "%s - %s" % (name, version)
            logging.info('Mass delivery check by %s for %s' % (self.request.headers['X-SecondLife-Object-Key'], objname))
            
            out = ''
            count = 0

            while count<15:
            # send maximum 20 request to make sure the answer is 2048 bytes
                delivery = DeliveryQueueUpdates.gql('WHERE objectname = :1 LIMIT 1', objname).get()
                if delivery:
                    # if there is something in the queue we send it in the format objectname|recipientkey to the distributor box, 1 per line
                    out = out + ('%s|%s\n' % (delivery.objectname,delivery.recipient))
                    # now delete the delivery
                    delivery.delete()
                    count = count + 1
                else:
                # no more item found, sio we break and return the list
                    break
            # and send it to the box
            logging.info('Delivery for %d item(s) on its way' % count)
            self.response.out.write(out)

  
def main():
  application = webapp.WSGIApplication([(r'/.*?/check',Check),
                                        (r'/.*?/givercheckin',UpdateItem),
                                        (r'/.*?/deliveryqueue',DeliveryQueue),
                                        (r'/.*?/massdeliveryqueue',MassDelivery)
                                       ],
                                       debug=True)
  wsgiref.handlers.CGIHandler().run(application)


if __name__ == '__main__':
  main()
