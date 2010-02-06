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
from google.appengine.api import urlfetch

class AppSettings(db.Model):
  #token = db.StringProperty(multiline=False)
  value = db.StringProperty(multiline=False)

alarmurl = AppSettings.get_or_insert("alarmurl", value="").value

class SetAlarmURL(webapp.RequestHandler):
    def post(self):
        #check linden IP  and allowed avs
        logging.info('Alarm URL')
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        elif not self.request.headers['X-SecondLife-Owner-Key'] in tools.adminkeys:
            logging.warning("Illegal attempt to set alarm URL from %s, box %s located in %s at %s" % (self.request.headers['X-SecondLife-Owner-Name'], self.request.headers['X-SecondLife-Object-Name'], self.request.headers['X-SecondLife-Region'], self.request.headers['X-SecondLife-Local-Position']))
            self.error(403)
        else:
            alarmurl = self.request.body
            alarm = AppSettings(key_name="alarmurl", value=alarmurl)
            alarm.put()
            logging.info('Alarm URL set to %s' % alarmurl)
            self.response.out.write('Added')


def SendAlarm(issue, target, admins, message):
    if (alarmurl == ""):
        logging.error('Alarm was raised, but no alarm URL existed. Message:\n%s' % message)
    else:
        unique = "alarm_%s_%s" % (issue, target)
        logging.info('Alarm triggered: %s: %s' % (unique, message))
        m = memcache.get(unique)
        if True: #m is None:
            memcache.set(unique, "", 600)
            logging.info('Alarm send for %s to %s: \n%s' % (unique, alarmurl, message))
            rpc = urlfetch.create_rpc()
            urlfetch.make_fetch_call(rpc, alarmurl, method="POST", headers={'issue': issue, 'target': target, 'admins': admins})
##            try:
##                result = rpc.get_result()
##                logging.info('Result: %d' % result.status_code);
##            except urlfetch.DownloadError:
##                logging.info('urlfetch.DownloadError')



def main():
  application = webapp.WSGIApplication([(r'/.*?/urlset',SetAlarmURL)
                                        ],
                                       debug=True)
  wsgiref.handlers.CGIHandler().run(application)


if __name__ == '__main__':
  main()
