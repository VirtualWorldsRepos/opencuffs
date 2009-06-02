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
import wsgiref.handlers

from dbmodels import FreebieItem
from dbmodels import FreebieDelivery

from google.appengine.api import urlfetch
from google.appengine.ext import webapp
from google.appengine.ext import db

null_key = "00000000-0000-0000-0000-000000000000"

class CronFreebieItems(webapp.RequestHandler):
    # cron job to clean the freebie items which are outdated
    def get(self):
      #if False: # safety to prevent crons to go off before we really want them, remove as soon as all is ready
        cronjob=self.request.headers['X-AppEngine-Cron'] # request this header to make sure only the google cron engine can call it, if this is not in the header the py code wil crash (on purpose :) )
        record = db.GqlQuery("SELECT * FROM FreebieItem") # process all items in the FreebieItem DB
        deleted=0
        if record is None: # do we have any freebies?
            logging.info("No Freebie items found!")
        else:
            delete_limit=time.time()-(24*2600) # set the time limit, currently 24 (48?) hours
            for item in record: # process each item
                if item.freebie_lastupdate<delete_limit: # and check if it is utdated
                    logging.info("Deleting item: %s: %s - %s from %s (last updated %d ago)" % (item.freebie_giver,item.freebie_name,item.freebie_version,item.freebie_owner,time.time()-item.freebie_lastupdate))
                    item.delete() # if outdated throw it away
                    deleted=deleted+1
        logging.info("Cron job at %s deleted %d freebie(s)." % (time.strftime('%X %x %Z',time.gmtime()),deleted)) # all done, write a log entry

class CronFreebieDelivery(webapp.RequestHandler):
    def get(self):
      #if False: # safety to prevent crons to go off before we really want them
        cronjob=self.request.headers['X-AppEngine-Cron'] # request this header to make sure only the google cron engine can call it, if this is not in the header the py code wil crash (on purpose :) )
        record = db.GqlQuery("SELECT * FROM FreebieDelivery") # process all items in FreebieDelivery DB
        deleted=0
        if record is None: # do we have any deliveries
            logging.info("No Deliveries found!")
        else:
            delete_limit=time.time()-(6*3600) # set the time limit, currently 6 hours
            for delivery in record: # process each request
            # do we need exception handling here, if the entry gets deleted by the Delivery Box requester?
                if delivery.requesttime<delete_limit: # items is outdated
                    logging.info("Deleting outdated delivery: %s: %s from %s (no time)" % (delivery.itemname,delivery.rcptkey,delivery.giverkey))
                    delivery.delete() # so delete it
                    deleted=deleted+1
                elif delivery.requesttime==None: # item has no timestamp
                    logging.info("Deleting outdated delivery: %s: %s from %s (last updated %d ago)" % (delivery.itemname,delivery.rcptkey,delivery.giverkey,time.time()-delivery.requesttime))
                    delivery.delete() # delete it as well
                    deleted=deleted+1
        logging.info("Cron job at %s deleted %d freebie(s)." % (time.strftime('%X %x %Z',time.gmtime()),deleted)) # all done, write a log entry

def main():
  application = webapp.WSGIApplication([(r'/.*?/cronfreebieitems',CronFreebieItems),
                                        (r'/.*?/cronfreebiedelivery',CronFreebieDelivery)
                                        ],
                                       debug=True)
  wsgiref.handlers.CGIHandler().run(application)


if __name__ == '__main__':
  main()
