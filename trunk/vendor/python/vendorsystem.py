#!/usr/bin/python
#Licensed under the GPLv2 (not later versions)
#see LICENSE.txt for details

import cgi
import os
import re
import lindenip
import distributors
import logging
import adminnotify
import time


import yaml

import wsgiref.handlers
from google.appengine.ext import db
from google.appengine.ext import webapp
from google.appengine.ext.webapp.util import run_wsgi_app
from google.appengine.api import memcache

from dbdefinitions import FreebieItem, FreebieDelivery, VendorTexture, Distributor
import dbdefinitions

#only nandana singh and athaliah opus are authorized to add distributors
adminkeys = ['2cad26af-c9b8-49c3-b2cd-2f6e2d808022', '98cb0179-bc9c-461b-b52c-32420d5ac8ef','dbd606b9-52bb-47f7-93a0-c3e427857824']




class AddObject(webapp.RequestHandler):
    def get(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        else:
            giverkey = self.request.headers['X-SecondLife-Object-Key']
            av=self.request.headers['X-SecondLife-Owner-Key']
            if not distributors.authorized_distributor(av): # function needs to be changed to distributors.authorized_designer as soon as the database for that is fully functioning
                self.error(402)
            else:
                name = cgi.escape(self.request.get('object'))
                version = cgi.escape(self.request.get('version'))
                avname = self.request.headers['X-SecondLife-Owner-Name']

                logging.info('Item update from %s' % avname)
                self.response.headers['Content-Type'] = 'text/plain'
                giver_url=self.request.body
                t = int(time.time())
                ts = "%d" % t
                
                
                #look for an existing item with that name
                items = VendorItem.gql("WHERE freebie_name = :1", name)
                item = items.get()
                
                response = 'saved'
                if item is None:
                    # updated to store the key of the distributor as well as a time stamp
                    newitem = VendorItem(item_name = name, item_version = version, item_giver = giverkey, item_owner = avname, item_lastupdate=t, item_url=giver_url)

                    dbdefinitions.GenericStorage_store('ObjectsTime',ts)
                    newitem.put()

                    logging.info('Saved item %s version %s from %s. URL: %s' % (name, version, avname, giver_url))
                else:
                    # if the items exists in the DB, check if the assiged owner tries to update it
                    if item.item_owner != avname:
                        # someone is trying to replace an item, put in by another av, ignore the request and notify admins
                        # prepare the mail
                        old_name = item.item_owner
                        response="Illegal item update (%s, %s) from %s" % (name,old_name,avname)
                        logging.info(response)
                        subj = "OpenCollar Distributors: Update for existing item by new distributor"
                        tex = """This mail has been sent to you, because someone tried to update an item, which is in an distributor already from another person.
Item: %s
Version: %s
Currently distributed by: %s using distributor %s
Change requested from: %s using distributor %s

The DB entry has not been updated, manual assistance is required to do so.""" % (item.item_name, item.item_version, old_name, item.item_giver, avname, giverkey)
                        # and now send the mail
                        adminnotify.notify_all(subj, tex)

                    else:
                        # the person is autorized, so updated the item
                        item.item_version = version
                        item.item_giver = giverkey
                        item.item_lastupdate = t
                        if (item.item_url != giver_url): # check if the texture for this item has been changed
                            item.item_url=giver_url
                            dbdefinitions.GenericStorage_store('ObjectsTime',ts) # and store the timestamp
                        item.put()
                        logging.info('Updated item %s version %s by %s' % (name, version, avname))
                self.response.out.write(response) # send the response back to the delivery box




class AddTexture(webapp.RequestHandler):
    def post(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        elif not self.request.headers['X-SecondLife-Owner-Key'] in adminkeys:
            self.error(403)
        else:
            self.response.headers['Content-Type'] = 'text/plain'
            name = self.request.headers['X-SecondLife-Owner-Name']
            item = cgi.escape(self.request.get('object'))
            texture = cgi.escape(self.request.get('texture'))
            t=int(time.time())
            ts="%d" % t

            record = VendorTexture.gql('WHERE item_name = :1', item).get()
            if record is None:
                NewText = VendorTexture(item_name = item, item_texture = texture, texture_owner = name, item_update_time= t)
                NewText.put()

                dbdefinitions.GenericStorage_store('TextureTime',ts)
                logging.info("Texture created for %s with %s at %d" % (item,texture,t))
            else:
                if record.item_texture != texture:
                    record.item_texture = texture
                    record.texture_owner = name
                    dbdefinitions.GenericStorage_store('TextureTime',ts)
                    logging.info("Texture updated for %s with %s at %d" % (item,texture,t))
                else:
                    logging.info("Texture for %s does not need a change at %d" % (item,t))
                record.item_update_time= t
                record.put()
            self.response.out.write('saved')



class GetAllTextures(webapp.RequestHandler):
    def post(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        else:
            av=self.request.headers['X-SecondLife-Owner-Key']
            if not distributors.vendor_authorized(av): # function needs to be changed to distributors.authorized_designer as soon as the database for that is fully functioning
                self.error(402)
            else:
                # Use a query parameter to keep track of the last key of the last
                # batch, to know where to start the next batch.
                last_key_str = self.request.get('last')
                if last_key_str:
                    last_key=int(last_key_str)
                    query = VendorTexture.gql('')
                    entities = query.fetch(21,last_key)
                    count = 0
                    result =''
                    more = False
                    for texture in entities:
                        count = count + 1
                        if count < 21:
                            result=result + texture.item_name +"|"+texture.item_texture+"|"
                        else:
                            last_key=last_key+20
                            result=result + ("startwith=|%d" % (last_key))
                            more = True
                    if more == False:
                        result=result +"end|"
                    self.response.out.write(result)
  
class GetTexture(webapp.RequestHandler):
    def post(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        else:
            av=self.request.headers['X-SecondLife-Owner-Key']
            if not distributors.vendor_authorized(av): # function needs to be changed to distributors.authorized_designer as soon as the database for that is fully functioning
                self.error(402)
            else:
                # Use a query parameter to keep track of the last key of the last
                # batch, to know where to start the next batch.
                object = self.request.get('object')
                if object:
                    query = VendorTexture.gql('WHERE item_name = :1', object)
                    result="none"
                    if query is None:
                        result="none"
                    else:
                        result=query.item_name+"|"+query.item_texture
                    self.response.out.write(result)



def main():
  application = webapp.WSGIApplication([
                                        (r'/.*?/updatetexture',AddTexture),
                                        (r'/.*?/getalltextures',GetAllTextures),
                                        (r'/.*?/updateobject',AddObject)
                                        ], debug=True)
  wsgiref.handlers.CGIHandler().run(application)


if __name__ == '__main__':
  main()