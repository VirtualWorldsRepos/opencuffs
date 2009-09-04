#!/usr/bin/python
#Licensed under the GPLv2 (not later versions)
#see LICENSE.txt for details

import cgi
import os
import re
import lindenip
import distributors
import logging

import time


import yaml

import wsgiref.handlers
from google.appengine.ext import db
from google.appengine.ext import webapp
from google.appengine.ext.webapp.util import run_wsgi_app
from google.appengine.api import memcache

from dbdefinitions import FreebieItem, FreebieDelivery, VendorTexture
import dbdefinitions

#only nandana singh and athaliah opus are authorized to add distributors
adminkeys = ['2cad26af-c9b8-49c3-b2cd-2f6e2d808022', '98cb0179-bc9c-461b-b52c-32420d5ac8ef','dbd606b9-52bb-47f7-93a0-c3e427857824']


class AddTexture(webapp.RequestHandler):
    def post(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        elif not self.request.headers['X-SecondLife-Owner-Key'] in adminkeys:
            self.error(403)
        else:
            self.response.headers['Content-Type'] = 'text/plain'
            item = cgi.escape(self.request.get('object'))
            texture = cgi.escape(self.request.get('texture'))
            t=time.time()
            ts="%f" % t
            
            record = VendorTexture.gql('WHERE item_name = :1', item).get()
            if record is None:
                NewText = VendorTexture(item_name = item, item_texture = texture, item_update_time= t)
                NewText.put()
                
                dbdefinitions.GenericStorage_store('TextureTime',ts)
                logging.info("Texture created for %s with %s at %f" % (item,texture,t))
            else:
                if record.item_texture != texture:
                    record.item_texture = texture
                    dbdefinitions.GenericStorage_store('TextureTime',ts)
                    logging.info("Texture updated for %s with %s at %f" % (item,texture,t))
                else:
                    logging.info("Texture for %s does not need a change at %f" % (item,t))
                record.item_update_time= time.time()
                record.put()
            self.response.out.write('saved')
               


class GetTexture(webapp.RequestHandler):
    def get(self):
        # Use a query parameter to keep track of the last key of the last
        # batch, to know where to start the next batch.
        last_key_str = self.request.get('last')
        query = VendorTexture.gql()
        
        if last_key_str:
            query = VendorTexture.gql()
            entities = query.fetch(21,last_key_str)
            count = 0
            result =''
            for texture in entities:
                count = count + 1
                if count < 21:
                    result=result + texture.item_name +"|"+texture.item_name+"|"
                else:
                    last_key_str=last_key_str+20
                    result=result + "startwith="
  


def main():
  application = webapp.WSGIApplication([
                                        (r'/.*?/updatetexture',AddTexture)
                                        ], debug=True)
  wsgiref.handlers.CGIHandler().run(application)


if __name__ == '__main__':
  main()