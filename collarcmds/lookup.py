# Code was released into the public domain by Darien Caldwell
# http://forums.secondlife.com/showthread.php?t=323981

import cgi
import urllib
import logging
import lindenip
import os
import relations
import time
import datetime
from model import Lookup
from google.appengine.ext import webapp
from google.appengine.ext.webapp.util import run_wsgi_app
from google.appengine.ext import db

class Pacific_tzinfo(datetime.tzinfo):
 """Implementation of the Pacific timezone."""
 def utcoffset(self, dt):
   return datetime.timedelta(hours=-8) + self.dst(dt)

 def _FirstSunday(self, dt):
   """First Sunday on or after dt."""
   return dt + datetime.timedelta(days=(6-dt.weekday()))

 def dst(self, dt):
   # 2 am on the second Sunday in March
   dst_start = self._FirstSunday(datetime.datetime(dt.year, 3, 8, 2))
   # 1 am on the first Sunday in November
   dst_end = self._FirstSunday(datetime.datetime(dt.year, 11, 1, 1))

   if dst_start <= dt.replace(tzinfo=None) < dst_end:
     return datetime.timedelta(hours=1)
   else:
     return datetime.timedelta(hours=0)

 def tzname(self, dt):
   if self.dst(dt) == datetime.timedelta(hours=0):
     return "PST"
   else:
     return "PDT"


class AvTPs(db.Model):
    av = db.StringProperty(multiline=False)
    tps = db.ListProperty(str)


def updateTPs(av, tp):
    querya = AvTPs.gql("WHERE av =  :1", av)
    query = querya.get()
    if querya.count() == 0:
        record = AvTPs(av = av, tps = [tp])
        record.put()
    elif len(query.tps)>9 :
        logging.info('more than 9 items')
        query.tps[0:1]=[]
        query.tps += [tp]
        query.put()
    else:
        query.tps += [tp]
        query.put()
        
 
class MainPage(webapp.RequestHandler):
  def put(self):
    #check linden ip
    if not lindenip.inrange(os.environ['REMOTE_ADDR']):
        self.error(403)
    else:
          # This is for a internal logging system... Not for real use...
          logging.debug('R:%s LP:%s ON:%s OK:%s N:%s' % (self.request.headers['X-SecondLife-Region'], self.request.headers['X-SecondLife-Local-Position'], self.request.headers['X-SecondLife-Object-Name'], self.request.headers['X-SecondLife-Object-Key'], self.request.headers['X-SecondLife-Owner-Name']))
          av = self.request.headers['X-SecondLife-Owner-Key']
          avname = self.request.headers['X-SecondLife-Owner-Name']
          if avname != "(Loading...)":
              relations.update_av(av, avname)
          param2=self.request.headers['X-SecondLife-Owner-Key'] #the Name the service will be known by         
          bodyparams = self.request.body.split("|")
          param3=bodyparams[0]# the URL for the web service
          time=datetime.datetime.now(Pacific_tzinfo())
          param4=self.request.headers['X-SecondLife-Region']+"|"+self.request.headers['X-SecondLife-Local-Position']+"|"+time.strftime("%Y/%m/%d at %I:%M:%S %p")
          try:
              ownparam = bodyparams[1]
              secparam = bodyparams[2]
          except(IndexError):
              pathparms = self.request.path.split("/")
              ownparam = pathparms[-2]
              secparam = pathparms[-1]
          try:
              pubparam = bodyparams[3]
          except(IndexError):
              pubparam = "disabled"
          ownurl = param3+'/'+ownparam
          securl = param3+'/'+secparam
          puburl = param3+'/'+pubparam
          logging.info('%s created their url %s' % (param2, param3))
          updateTPs(param2, param4)
          q = db.GqlQuery("SELECT * FROM Lookup WHERE av = :kk",kk=param2)
          count=q.count(2)

          if count!=0 :
            results=q.fetch(10)            
            db.delete(results)  # remove them all (just in case some how, some way, there is more than one service with the same name 

          if param2=="" or param3=="" :
              self.error(400)
          else:
              newrec=Lookup(av=param2,ownurl=ownurl,securl=securl,puburl=puburl)
              newrec.put()
              self.response.out.write('Added')

  def delete(self):
    #check linden ip
    if not lindenip.inrange(os.environ['REMOTE_ADDR']):
        self.error(403)
    else:
          param2=self.request.headers['X-SecondLife-Owner-Key'] # the name the service is known by
          # This is for a internal logging system... Not for real use...
          logging.debug('R:%s LP:%s ON:%s OK:%s N:%s' % (self.request.headers['X-SecondLife-Region'], self.request.headers['X-SecondLife-Local-Position'], self.request.headers['X-SecondLife-Object-Name'], self.request.headers['X-SecondLife-Object-Key'], self.request.headers['X-SecondLife-Owner-Name']))

          param2=self.request.headers['X-SecondLife-Owner-Key']

          logging.info('%s deleted their url' % (param2))
          q = db.GqlQuery("SELECT * FROM Lookup WHERE av = :kk",kk=param2)
          count=q.count(2)

          if count==0 :
            self.error(404)
          else:
            results=q.fetch(10)            
            db.delete(results)  # remove them all (just in case some how, some way, there is more than one service with the same name 
            self.response.out.write('Removed')

  def get(self):
    #check linden ip
    if not lindenip.inrange(os.environ['REMOTE_ADDR']):
        self.error(403)
    else:
          # This is for a internal logging system... Not for real use...
          logging.debug('R:%s LP:%s ON:%s OK:%s N:%s' % (self.request.headers['X-SecondLife-Region'], self.request.headers['X-SecondLife-Local-Position'], self.request.headers['X-SecondLife-Object-Name'], self.request.headers['X-SecondLife-Object-Key'], self.request.headers['X-SecondLife-Owner-Name']))

          param1 = self.request.path.split("/")[-2]
          param2 = self.request.path.split("/")[-1]
          param3=self.request.headers['X-SecondLife-Owner-Key']

          query = relations.getby_subj_obj_type(param3, param2, "owns")
          query2 = relations.getby_subj_obj_type(param3, param2, "secowns")
          if not query.count() == 0:
              q = db.GqlQuery("SELECT * FROM Lookup WHERE av = :kk",kk=param2)
              count=q.count(2)
              if count==0 :
                    logging.warning('%s an owner is retrieving the url for %s and product %s but it doesnt exist' % (param3, param2, param1))
                    self.error(404)
              else:
                    logging.info('%s an owner is retrieving the url for %s for product %s' % (param3, param2, param1))
                    record=q.get()
                    self.response.out.write(record.ownurl) #print the URL
          elif not query2.count() == 0:
              q = db.GqlQuery("SELECT * FROM Lookup WHERE av = :kk",kk=param2)
              count=q.count(2)
              if count==0 :
                    logging.warning('%s a secowner is retrieving the url for %s and product %s but it doesnt exist' % (param3, param2, param1))
                    self.error(404)
              else:
                    logging.info('%s a secowner is retrieving the url for %s for product %s' % (param3, param2, param1))
                    record=q.get()
                    self.response.out.write(record.securl) #print the URL
          else:
              logging.error('%s is retrieving the url for %s for product %s but was not authorized to do so' % (param3, param2, param1))
              self.error(403)

application = webapp.WSGIApplication(
    [('.*', MainPage)
     ], 
    debug=True) 

def main():
  run_wsgi_app(application)

if __name__ == "__main__":
  main()