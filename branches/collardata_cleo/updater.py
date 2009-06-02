#!/usr/bin/python
#Licensed under the GPLv2 (not later versions)
#see LICENSE.txt for details

import cgi
import sys
import os
import logging
import lindenip
import time

import distributors
import adminnotify
import wsgiref.handlers

from dbmodels import FreebieItem
from dbmodels import FreebieDelivery

from google.appengine.api import urlfetch
from google.appengine.ext import webapp
from google.appengine.ext import db

null_key = "00000000-0000-0000-0000-000000000000"


def CleanupFreebieItems(giverkey):
    # subroutine to clwan out items, which are not updated within a certain time
    # this routine is called from the put rooutines, which the delivery boxes use for finalizing
    logging.info('Cleanup request for distributor %s' % (giverkey))
    itemstorage=FreebieItem.gql("WHERE freebie_giver = :1", giverkey) # querry all items for this box
    deleted=0
    response="ok" # prepare a positive response
    delete_limit=time.time()-240 # delted items which are older than 3 minutes, this should hopeful be long enough even for big delivery boxes
    if itemstorage is not None: # there have been items found
        for item in itemstorage: # so process all
            if item.freebie_lastupdate<delete_limit: # and check if they are older than the previously set time limit
                logging.info("Deleting item: %s: %s - %s from %s (last updated %d ago)" % (item.freebie_giver,item.freebie_name,item.freebie_version,item.freebie_owner,time.time()-item.freebie_lastupdate))
                item.delete() # the item is outdated, so delete it
                deleted=deleted+1 # and increase the counter just for fun
    if deleted>0: # if we deleted some items, send the number as response
        response="Deleted: %d" % deleted
    return response # and hand back the response


class Check(webapp.RequestHandler):
# no changes to this routine from Cleo
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
            self.response.out.write("NO %s" % (name))
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
# this part of UpdateItem will be in use, till the FreebieItems have a timestamp and key of the distributor
    def get1(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        elif not distributors.authorized_distributor(self.request.headers['X-SecondLife-Owner-Key']): # function needs to be changed to distributors.authorized_designer as soon as the database for that is fully functioning
            self.error(403)
        else:
            logging.info('Item update from %s' % self.request.headers['X-SecondLife-Owner-Key'])
            self.response.headers['Content-Type'] = 'text/plain'
            name = cgi.escape(self.request.get('object'))
            version = cgi.escape(self.request.get('version'))
            giverkey = self.request.headers['X-SecondLife-Object-Key']
            avname = self.request.headers['X-SecondLife-Owner-Name']
            av=self.request.headers['X-SecondLife-Owner-Key']
            #look for an existing item with that name
            items = FreebieItem.gql("WHERE freebie_name = :1", name)
            item = items.get()
            if (item == None):
                # updated to store the key of the distributor as well as a time stamp
                newitem = FreebieItem(freebie_name = name, freebie_version = version, freebie_giver = giverkey, freebie_owner = av, freebie_lastupdate=time.time())
                logging.info(newitem)
                newitem.put()
            else:
                item.freebie_version = version
                item.freebie_giver = giverkey
                item.freebie_owner = av # store key of the distributor
                item.freebie_lastupdate=time.time() # store the timestamp
                item.put()
            self.response.out.write('saved')
            logging.info('saved item %s version %s by %s' % (name, version, avname))

    # this part would get in use, after the avkey has been added and apll currently inactive items have been removed
    def get(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        elif not distributors.authorized_distributor(self.request.headers['X-SecondLife-Owner-Key']): # function needs to be changed to distributors.authorized_designer as soon as the database for that is fully functioning
            self.error(403)
        else:
            logging.info('Item update from %s' % self.request.headers['X-SecondLife-Owner-Key'])
            self.response.headers['Content-Type'] = 'text/plain'
            name = cgi.escape(self.request.get('object'))
            version = cgi.escape(self.request.get('version'))
            giverkey = self.request.headers['X-SecondLife-Object-Key']
            avname = self.request.headers['X-SecondLife-Owner-Name']
            av=self.request.headers['X-SecondLife-Owner-Key']
            #look for an existing item with that name
            items = FreebieItem.gql("WHERE freebie_name = :1", name)
            item = items.get()
            response = 'saved'
            if (item == None):
                # updated to store the key of the distributor as well as a time stamp
                newitem = FreebieItem(freebie_name = name, freebie_version = version, freebie_giver = giverkey, freebie_owner = av, freebie_lastupdate = time.time())
                logging.info(newitem)
                newitem.put()
                logging.info('saved item %s version %s by %s' % (name, version, avname))
            else:
                # if the items exists in the DB, check if the assiged owner tries to update it
                if item.freebie_owner != av:
                    # someone is trying to replace an item, put in by another av, ignore the request and notify admins
                    # prepare the mail
                    new_name = distributors.getname_distributor(av)
                    old_name = distributors.getname_distributor(item.freebie_owner)
                    response="Illegal item update (%s, %s) from %s" % (name,old_name,new_name)
                    logging.info(response)
                    subj = "OpenCollar Distributors: Update for existing item by new distributor"
                    tex = """This mail has been sent to you, because someone tried to update an item, which is in an distributor already from another person.
Item: %s
Version: %s
Currently distributed by: %s (%s) using distributor %s
Change requested from: %s (%s) using distributor %s

The DB entry has not been updated, manual assistance is required to do so.""" % (item.freebie_name, item.freebie_version, old_name, item.freebie_owner, item.freebie_giver, new_name, av, giverkey)
                    # and now send the mail
                    adminnotify.notify_all(subj, tex)

                else:
                    # the person is autorized, so updated the item
                    item.freebie_version = version
                    item.freebie_giver = giverkey
                    item.freebie_lastupdate = time.time()
                    item.put()
                    logging.info('saved item %s version %s by %s' % (name, version, avname))
            self.response.out.write(response) # send the response back to the delivery box

    def put(self):
    # called from the distributor box after all items have been submitted to trigger a cleanup of not anymore used items
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        elif not distributors.authorized_distributor(self.request.headers['X-SecondLife-Owner-Key']): # function needs to be changed to distributors.authorized_designer as soon as the database for that is fully functioning
            self.error(403)
        else:
            self.response.headers['Content-Type'] = 'text/plain'
            # read distributor box key, owner key and owner name from header
            giverkey = self.request.headers['X-SecondLife-Object-Key']
            avname = self.request.headers['X-SecondLife-Owner-Name']
            avkey = self.request.headers['X-SecondLife-Owner-Key']
            # and call the cleanup routine
            response=CleanupFreebieItems(giverkey)
            # after we are done, we inform the delivery box
            self.response.out.write(response)

class DeliveryQueue(webapp.RequestHandler):
# Update from cleo is only temporary to make sure all items in currently used delivery boxes get a timestamp and the name of the distributor assigned
# this routine has only to run very shortly, maybe max 5 minutes, for seafty reasosn 30 minutes, after that all boxes should be updated
# additional after that routine run, the Database needs to be cleaned manually in the Dataviewer
    def get(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        elif not distributors.authorized_distributor(self.request.headers['X-SecondLife-Owner-Key']): # function needs to be changed to distributors.authorized_designer as soon as the database for that is fully functioning
            self.error(403)
        else:
            #get the deliveries where giverkey = key provided (this way we can still have multiple givers)
            giverkey = self.request.headers['X-SecondLife-Object-Key']
            pop = cgi.escape(self.request.get('pop'))#true or false.  if true, then remove items from db on returning them
            avname = self.request.headers['X-SecondLife-Owner-Name']
            av=self.request.headers['X-SecondLife-Owner-Key']

            # temporary code to update the entries in the FreebieItem with an AV record
            store_avkey = False # set to off atm

            if store_avkey == True: # only run temporary
                logging.info("Updating %s: Distributor set to %s" % (giverkey,av) )
                itemstorage=FreebieItem.gql("WHERE freebie_giver = :1", giverkey) # querry all items fior the giver requesting data
                if itemstorage is not None: # if any items are found
                    for item in itemstorage: # process all items
                        logging.info("Item: %s: %s - %s from %s" % (item.freebie_giver,item.freebie_name,item.freebie_version,item.freebie_owner))
                        item.freebie_owner = av # assign the key of the owner to it
                        item.freebie_lastupdate = time.time() # and update the timestamp
                        item.put() # before we save the entry again
            # end of the adding part, after the code has run for 30 mins to an hour we need to manually clean the db to remove inactive items. The will be readded when their distributor boxex are rezzed again and than be updated to use the security fixed system
            # rest of this routine is unchanged


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
