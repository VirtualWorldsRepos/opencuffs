#!/usr/bin/python
#Licensed under the GPLv2 (not later versions)
#see LICENSE.txt for details

import cgi
import os
import re
import lindenip
import logging
import time


import yaml

import wsgiref.handlers
from google.appengine.ext import db
from google.appengine.ext import webapp
from google.appengine.ext.webapp.util import run_wsgi_app
from google.appengine.api import memcache
from google.appengine.api import urlfetch

from model import FreebieItem, FreebieDelivery
import model

#only nandana singh and athaliah opus are authorized to add distributors
adminkeys = ['2cad26af-c9b8-49c3-b2cd-2f6e2d808022', '98cb0179-bc9c-461b-b52c-32420d5ac8ef','dbd606b9-52bb-47f7-93a0-c3e427857824','8487a396-dc5a-4047-8a5b-ab815adb36f0']




class StartTextureUpdate(webapp.RequestHandler):
    def post(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        elif not self.request.headers['X-SecondLife-Owner-Key'] in adminkeys:
            self.error(403)
        else:
            t=int(time.time())
            serverkey= self.request.headers['X-SecondLife-Object-Key']
            logging.info('Texture update started from texture server %s at %d' % (serverkey, t))
            # Setting texture time to -1111 to signalize texure update is in progress
            if model.GenericStorage_Get('TextureTime') == '-1111':
                logging.warning('Texture update requested from texture server %s at %d, but already in progress' % (serverkey, t))
                self.response.out.write('Update already in progress, try again later' )
            else:
                logging.info('Texture update started from texture server %s at %d' % (serverkey, t))
                model.GenericStorage_Store('TextureTime', '-1111')
                self.response.out.write('Timestamp:%d' % t )


class AddTextures(webapp.RequestHandler):
    def post(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        elif not self.request.headers['X-SecondLife-Owner-Key'] in adminkeys:
            self.error(403)
        else:
            self.response.headers['Content-Type'] = 'text/plain'
            name = self.request.headers['X-SecondLife-Owner-Name']
            serverkey= self.request.headers['X-SecondLife-Object-Key']
            logging.info('Receiving textures from texture server %s' % (serverkey))
            lines = self.request.body.split('\n')

            for line in lines:
                params = {}
                if line != "":
                    params['item'] = line.split('=')[0]
                    params['texture'] = line.split('=')[1]
                    item = params['item']
                    texture = params['texture']

                    t=int(time.time())
                    ts="V%d" % t

                    record = FreebieItem.gql('WHERE freebie_name = :1', item).get()
                    if record is None:
                        logging.info("Item %s not in freebielist, skipping texture %s" % (item ,texture))
                    else:
                        record.freebie_texture_key = texture
                        record.freebie_texture_serverkey = serverkey
                        record.freebie_texture_update= t
                        record.put()
                        logging.info("Texture updated for %s with %s form server %s at %d" % (item,texture,serverkey,t))
#            model.GenericStorage_Store('TextureTime', ts)
            self.response.out.write('saved')

class UpdateVersion(webapp.RequestHandler):
    def post(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        elif not self.request.headers['X-SecondLife-Owner-Key'] in adminkeys:
            self.error(403)
        else:
            done_str = self.request.get('done')
            serverkey= self.request.headers['X-SecondLife-Object-Key']
            logging.info('Finalizing texture update from texture server %s' % (serverkey))
            if not done_str:
                logging.info ('Done not confirmed, something is seriously wrong')
                self.error(402)
            else:
                starttime=int(done_str)
                t=int(time.time())
                ts="V%d" % t
                logging.info ('Cleaning all textures for server %s with timestamp below %d' % (serverkey, starttime))

                query = FreebieItem.gql("WHERE freebie_texture_serverkey = :1", serverkey)
                for record in query:
                    if record.freebie_texture_update < starttime:
                        logging.info ('Cleaned info for %s' % record.freebie_name)
                        record.freebie_texture_serverkey = ''
                        record.freebie_texture_update = -1
                        record.freebie_texture_key = ''

                logging.info ('Version info stored: %s' % ts)
                model.GenericStorage_Store('TextureTime', ts)
                self.response.out.write('Version updated: %s' % ts)




class GetAllTextures(webapp.RequestHandler):
    def post(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        else:
##            av=self.request.headers['X-SecondLife-Owner-Key']
##            if not distributors.distributor_authorized(av): # function needs to be changed to distributors.authorized_designer as soon as the database for that is fully functioning
##                self.error(402)
##            else:
                # Use a query parameter to keep track of the last key of the last
                # batch, to know where to start the next batch.
                last_key_str = self.request.get('start')
                last_version_str = self.request.get('last_version')
                current_version = model.GenericStorage_Get('TextureTime')
                if current_version == '-1111':
                    # system updating at the moment
                    logging.info ('System in update mode, inform the client')
                    self.response.out.write('Updating')
                else:
                    # normal work mode, lets do check and send texture
                    result =''
                    if not last_version_str:
                        # no last time given so we can use the stored time
                        last_version_str = '0'
                        logging.info ('no last_version, send update')
                    else:
                        logging.info ('last_version (%s)' % last_version_str)
                    if current_version == last_version_str:
                        logging.info ('Versions are identic, no action needed')
                        self.response.out.write('CURRENT')
                    else:
                        logging.info ('Versions different (DB:%s,Vendor:%s) Starting to send update...' % (current_version, last_version_str))
                        if not last_key_str:
                            last_key = 0
                            result ='version\n%s\n' % current_version
                            logging.info ('no last_key, send from start')
                        else:
                            last_key=int(last_key_str)
                            result ='continue\n%s\n' % current_version
                            logging.info ('last_key was: %s' % last_key_str)
                        query = FreebieItem.gql('WHERE freebie_texture_update > 0')
                        entities = query.fetch(21,last_key)
                        count = 0
                        more = False
                        for texture in entities:
                            count = count + 1
                            if count < 21:
                                logging.info('%s:%d' % (texture.freebie_name,texture.freebie_texture_update))
                                result=result + texture.freebie_name +"\n"+texture.freebie_texture_key+"\n"
                            else:
                                last_key=last_key+20
                                result=result + ("startwith\n%d" % (last_key))
                                more = True
                                logging.info ('More texture availabe, request next time from %d' % (last_key))
                        if more == False:
                            logging.info ('Sending finished now')
                            result = result + "end\n"
                        self.response.out.write(result)


class VersionCheck(webapp.RequestHandler):
    def post(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        else:
            vendor_version = self.request.get('tv')
            current_version = model.GenericStorage_Get('TextureTime')
            logging.info("Texture request rom vendor with version %s, db at version %s" % (vendor_version, current_version))
            if vendor_version:
                if current_version != vendor_version:
                    self.response.out.write('UPDATE:%s' % current_version)
                else:
                    self.response.out.write('CURRENT')





def main():
  application = webapp.WSGIApplication([
                                        (r'/.*?/starttextureupdate',StartTextureUpdate),
                                        (r'/.*?/updatetextures',AddTextures),
                                        (r'/.*?/getalltextures',GetAllTextures),
                                        (r'/.*?/versioncheck',VersionCheck),
                                        (r'/.*?/updateversion',UpdateVersion)
                                        ], debug=True)
  wsgiref.handlers.CGIHandler().run(application)


if __name__ == '__main__':
  main()



# used to add a single texture, not in use for texture server
##class AddTexture(webapp.RequestHandler):
##    def post(self):
##        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
##            self.error(403)
##        elif not self.request.headers['X-SecondLife-Owner-Key'] in adminkeys:
##            self.error(403)
##        else:
##            self.response.headers['Content-Type'] = 'text/plain'
##            name = self.request.headers['X-SecondLife-Owner-Name']
##            item = cgi.escape(self.request.get('object'))
##            texture = cgi.escape(self.request.get('texture'))
##            t=int(time.time())
##            ts="%d" % t
##
##            record = VendorTexture.gql('WHERE item_name = :1', item).get()
##            if record is None:
##                NewText = VendorTexture(item_name = item, item_texture = texture, texture_owner = name, item_update_time= t)
##                NewText.put()
##
##                model.GenericStorage_Store('TextureTime',ts)
##                logging.info("Texture created for %s with %s at %d" % (item,texture,t))
##            else:
##                if record.item_texture != texture:
##                    record.item_texture = texture
##                    record.texture_owner = name
##                    model.GenericStorage_Store('TextureTime',ts)
##                    logging.info("Texture updated for %s with %s at %d" % (item,texture,t))
##                else:
##                    logging.info("Texture for %s does not need a change at %d" % (item,t))
##                record.item_update_time= t
##                record.put()
##            self.response.out.write('saved')


# used to get a texture for a single object, not in use on textureserver
##class GetTexture(webapp.RequestHandler):
##    def post(self):
##        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
##            self.error(403)
##        else:
####            av=self.request.headers['X-SecondLife-Owner-Key']
####            if not distributors.vendor_authorized(av): # function needs to be changed to distributors.authorized_designer as soon as the database for that is fully functioning
####                self.error(402)
####            else:
##                # Use a query parameter to keep track of the last key of the last
##                # batch, to know where to start the next batch.
##                object = self.request.get('object')
##                if object:
##                    query = VendorTexture.gql('WHERE item_name = :1', object).get()
##                    result="none"
##                    if query is None:
##                        result="none"
##                    else:
##                        result=query.item_name+"|"+query.item_texture
##                    self.response.out.write(result)

# used to send texture to http_in devices
##class SendAllTextures(webapp.RequestHandler):
##    def post(self):
##        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
##            self.error(403)
##        elif not distributors.Distributor_authorized(self.request.headers['X-SecondLife-Owner-Key']):
##            logging.info("Illegal attempt to request texture from %s, vendor %s located in %s at %s" % (self.request.headers['X-SecondLife-Owner-Name'], self.request.headers['X-SecondLife-Object-Name'], self.request.headers['X-SecondLife-Region'], self.request.headers['X-SecondLife-Local-Position']))
##            self.error(403)
##        else:
##            # Use a query parameter to keep track of the last key of the last
##            # batch, to know where to start the next batch.
##            URL = self.request.body + "/Textures/"
##            logging.info("Sending data to %s" % URL)
##            query = VendorTexture.gql('')
##            entities = query.fetch(1000,0)
##            objectcount = 0
##            tosend= ''
##            for texture in entities:
##                objectcount=objectcount+1
##                tosend += "%s=%s\n" % (texture.item_name, texture.item_texture)
##                if objectcount==10:
##                    rpc = urlfetch.create_rpc()
##                    urlfetch.make_fetch_call(rpc, URL, payload=tosend, method="POST")
##                    logging.info("Sending:\n%s" % tosend)
##                    objectcount = 0
##                    tosend= ''
##            if objectcount > 0:
##                rpc = urlfetch.create_rpc()
##                urlfetch.make_fetch_call(rpc, URL, payload=tosend, method="POST")
##                logging.info("Sending:\n%s" % tosend)
