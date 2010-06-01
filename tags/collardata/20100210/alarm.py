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

alarm_intervall = 600

class AppSettings(db.Model):
  #token = db.StringProperty(multiline=False)
  value = db.StringProperty(multiline=False)


def AlarmUrl():
    theurl=memcache.get('alarmurl')
    if theurl is None:
        alarm = AppSettings.get_by_key_name("alarmurl")
        if alarm is None:
            return ''
        else:
            memcache.set('alarmurl', alarm.value)
            return alarm.value
    else:
        return theurl
    

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
            memcache.set('alarmurl', alarmurl)
            logging.info('Alarm URL set to %s' % alarmurl)
            self.response.out.write('Added')

def SendAlarm(issue, target, admins, message, redirecturl):
    unique = "alarm_%s_%s" % (issue, target)
    # logging.info('Alarm triggered: %s: %s' % (unique, message))
    notified = memcache.get(unique)
    if notified is None:
        memcache.set(unique, "", alarm_intervall)
        logging.info('Alarm send for %s: \n%s' % (unique, message))
        rpc = urlfetch.create_rpc()
        urlfetch.make_fetch_call(rpc, redirecturl + "/alarm/redirect/" , payload=message, method="POST", headers={'issue': issue, 'target': target, 'admins': admins})

class Redirect(webapp.RequestHandler):
    def post(self):
        RedirURL = AlarmUrl()
        if (RedirURL == ""):
            logging.error('Alarm was raised, but no alarm URL existed. Message:\n%s' % message)
        else:
            # logging.info('Redirecting to %s' % RedirURL)
            self.redirect(RedirURL, True)

def main():
  application = webapp.WSGIApplication([(r'/.*?/urlset',SetAlarmURL),
                                        (r'/.*?/redirect/',Redirect)
                                        ],
                                       debug=True)
  wsgiref.handlers.CGIHandler().run(application)


if __name__ == '__main__':
  main()