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

from model import VendorInfo
import model

# remove outdated vendors within 36-48 hours
VendorRemoveTimeout = 129600

class CleanVendors(webapp.RequestHandler):
    def get(self):
        t=int(time.time()) - VendorRemoveTimeout;
        logging.info('CRON CleanVendors: Removing vendors older than %d' % t)
        query = VendorInfo.gql("WHERE lastupdate < :1",  t)
        for record in query:
            logging.info('CRON: Vendor info for %s at %s outdated, removing it' % (record.vkey, record.slurl))
            record.delete()
        logging.info('CRON CleanVendors: Finished')



def main():
  application = webapp.WSGIApplication([
                                        (r'/.*?/CleanVendors',CleanVendors)
                                        ], debug=True)
  wsgiref.handlers.CGIHandler().run(application)


if __name__ == '__main__':
  main()

