#!/usr/bin/python
#Licensed under the GPLv2 (not later versions)
#see LICENSE.txt for details

import cgi
import os
import re
import lindenip
import distributors
import logging
import tools

import wsgiref.handlers
from google.appengine.ext import db
from google.appengine.ext import webapp
from google.appengine.ext.webapp.util import run_wsgi_app
from google.appengine.api import memcache

from model import FreebieItem, FreebieDelivery

class Deliver(webapp.RequestHandler):
    def post(self):
        #check linden IP  and allowed avs
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        elif not distributors.Distributor_authorized(self.request.headers['X-SecondLife-Owner-Key']):
            logging.info("Illegal attempt to request an item from %s, box %s located in %s at %s" % (self.request.headers['X-SecondLife-Owner-Name'], self.request.headers['X-SecondLife-Object-Name'], self.request.headers['X-SecondLife-Region'], self.request.headers['X-SecondLife-Local-Position']))
            self.error(403)
        else:
            #populate a dictionary with what we've been given in post
            #should be newline-delimited, token=value
            lines = self.request.body.split('\n')
            params = {}
            for line in lines:
                params[line.split('=')[0]] = line.split('=')[1]

            try:
                name = params['objname']
                token = 'item_%s' % name
                item = memcache.get(token)
                if item is None:
                    freebieitem = FreebieItem.gql("WHERE freebie_name = :1", name).get()
                    if freebieitem is None:
                        #could not find item to look up its deliverer.  return an error
                        logging.error('Error, freebie %s not found. Requested by %s using %s.' % (name, self.request.headers['X-SecondLife-Owner-Name'], self.request.headers['X-SecondLife-Object-Name']))
                        self.error(403)
                        return
                    else:
                        item = {"name":freebieitem.freebie_name, "version":freebieitem.freebie_version, "giver":freebieitem.freebie_giver}
                        memcache.set(token, item)

                name_version = "%s - %s" % (name, item['version'])
                rcpt = str(params['rcpt'])

                if tools.enqueue_delivery(item['giver'], rcpt, name_version, self.request.host_url):
                    self.response.out.write('%s|%s' % (rcpt, name_version))
                else:
                    logging.error('Enqueing failed for vendor %s, queue entry: %s|%s' % (item['giver'], rcpt, name_version))
                    self.error(403)
            except KeyError:
                logging.error('Key error for vendor %s, queue entry: %s|%s' % (item['giver'], rcpt, name_version))
                self.error(403)


class AddDist(webapp.RequestHandler):
    def post(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        elif not self.request.headers['X-SecondLife-Owner-Key'] in tools.adminkeys:
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
            distributors.Distributor_add(params['key'], params['name'])
            self.response.out.write('Added distributor %s' % params['name'])

class RemDist(webapp.RequestHandler):
    def post(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        elif not self.request.headers['X-SecondLife-Owner-Key'] in tools.adminkeys:
            self.error(403)
        else:
            #add distributor
            #populate a dictionary with what we've been given in post
            #should be newline-delimited, token=value
            lines = self.request.body.split('\n')
            params = {}
            for line in lines:
                params[line.split('=')[0]] = line.split('=')[1]
            logging.info('Distributor removed: %s (%s)' % (params['name'], params['key']))
            distributors.Distributor_delete(params['key'], params['name'])
            self.response.out.write('Removed Distributor %s' % params['name'])

class AddContrib(webapp.RequestHandler):
    def post(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        elif not self.request.headers['X-SecondLife-Owner-Key'] in tools.adminkeys:
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

class RemContrib(webapp.RequestHandler):
    def post(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        elif not self.request.headers['X-SecondLife-Owner-Key'] in tools.adminkeys:
            self.error(403)
        else:
            #add distributor
            #populate a dictionary with what we've been given in post
            #should be newline-delimited, token=value
            lines = self.request.body.split('\n')
            params = {}
            for line in lines:
                params[line.split('=')[0]] = line.split('=')[1]
            logging.info('Contributor removed: %s (%s)' % (params['name'], params['key']))
            distributors.Contributor_delete(params['key'], params['name'])
            self.response.out.write('Removed Contributor %s' % params['name'])



def main():
  application = webapp.WSGIApplication([
                                        (r'/.*?/deliver',Deliver),
                                        (r'/.*?/adddist',AddDist),
                                        (r'/.*?/remdist',RemDist),
                                        (r'/.*?/addcontrib',AddContrib),
                                        (r'/.*?/remcontrib',RemContrib)
                                        ], debug=True)
  wsgiref.handlers.CGIHandler().run(application)


if __name__ == '__main__':
  main()