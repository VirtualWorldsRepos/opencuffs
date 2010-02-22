# Cleo: I suggest to remove comment starting with Cleo


#!/usr/bin/python
#Licensed under the GPLv2 (not later versions)
#see LICENSE.txt for details

import cgi
import os
import re
import lindenip
import logging
import relations

import verify


relationtokens = {"owner":"owns", "secowners":"secowns"}#watch for these being saved, and make relations for them

allowed_quota=2048; # maximum allowed amount of data per user, might need to be adopted for 3.4 if we offer storage of bigger values via separate script

from google.appengine.ext import db
from google.appengine.ext import webapp
from google.appengine.ext.webapp.util import run_wsgi_app
from google.appengine.api import memcache


alltoken = "_all"

from model import AvTokenValue


def CheckMemoryUse(av, uservalue, oldvalue):
# check the allowed storage amount per AV, which is tempiorary stored in memcache
    cachekey = 'memoryuse-%s' % (av) # setup memcache key
    cachedata = memcache.get(cachekey) # and fetch value
    if cachedata is not None:
        #logging.info('Memcache found for %s: %s' % (av, cachedata))
        # stored value found, calculate new allowed sizes
		# make sure we do not sume up values, if a token was already stored and just gets updated
        size=int(cachedata)+len(uservalue)-len(oldvalue)
        if size>allowed_quota:
            logging.warning('Quota from %s exceeded: %d' % (av,size))
            # we are over the quota, so deny saving
            return False
        else:
            # still in the quota, so update stored size and allow the saving
            #logging.info('Memcache found for %s, Quota OK' % (av))
            memcache.replace(cachekey, str(size), 3600, 0)
            return True
    else:
        #logging.info('Memcache not found for %s' % (av))
        #no value in memcache we have to calculate it
        size=0

        # query all stored values
        query = AvTokenValue.gql("WHERE av = :1", av)
        for record in query:
            # and sum up their length
            size+=len(record.value)

		# make sure we do not sume up values, if a token was already stored and just gets updated
        if size+len(uservalue)-len(oldvalue)>allowed_quota:
            logging.warning('Quota from %s exceeded: %d' % (av,size+len(uservalue)-len(oldvalue)))
            # quota exceeded, store current size in memcach and deny saving
            memcache.add(cachekey,str(size),3600)
            return False
        else:
            #logging.info('Memcache not found for %s, Quota OK: %d' % (av,size+len(uservalue)))
            # stil in quota
			# make sure we do not sume up values, if a token was already stored and just gets updated
            memcache.add(cachekey,str(size+len(uservalue)-len(oldvalue)),3600)
            return True

def ClearMemoryUse(av):
# clear the values from memcache
    cachekey = 'memoryuse-%s' % (av) # setup memcache key
    cachedata = memcache.get(cachekey) # and fetch value
    if cachedata is not None:
        #logging.info('Memcache found, cleaning')
        memcache.delete(cachekey)


def SubstractMemoryUse(av, uservalue):
# remove the amount of storage needed for the current value
    cachekey = 'memoryuse-%s' % (av) # setup memcache key
    cachedata = memcache.get(cachekey) # and fetch value
    if cachedata is not None:
        # stored value found, calculate new allowed sizes
        size=int(cachedata)-len(uservalue)
        #logging.info('Memcache found for %s: reduced to %d' % (av, size))
        memcache.replace(cachekey, str(size), 3600, 0)

class MainPage(webapp.RequestHandler):
    def get(self):
        #check that we're coming from an LL ip
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        else:
            logging.debug('R:%s LP:%s ON:%s OK:%s N:%s' % (self.request.headers['X-SecondLife-Region'], self.request.headers['X-SecondLife-Local-Position'], self.request.headers['X-SecondLife-Object-Name'], self.request.headers['X-SecondLife-Object-Key'], self.request.headers['X-SecondLife-Owner-Name']))
            av = self.request.headers['X-SecondLife-Owner-Key']
            avname = self.request.headers['X-SecondLife-Owner-Name']
            token = self.request.path.split("/")[-1]

            if av == "00000000-0000-0000-0000-000000000000":
                self.response.set_status(500)
                self.response.out.write('Im sorry there is an error with your access to the database. Please contact the database administrator for more information.')
            else:
                if not verify.validvalue('read',av,avname,token,'', self.request.headers):
                    self.response.out.write('')
                else:
                    #get record with this key/token
                    logging.info('%s requested by %s' % (token, avname))
                    if token == alltoken:
                        #on requesting all, record av key
                        if avname != "(Loading...)":
                            relations.update_av(av, avname)
                        #get all settings, print out one on each line, in form "token=value"
                        query = AvTokenValue.gql("WHERE av = :1", av)
                        self.response.headers['Content-Type'] = 'text/plain'
                        for record in query:
                            self.response.out.write("%s=%s\n" % (record.token, record.value))
                    else:
                        record = AvTokenValue.gql("WHERE av = :1 AND token = :2", av, token).get()
                        if record is not None:
                            self.response.headers['Content-Type'] = 'text/plain'
                            self.response.out.write(record.value)
                        else:
                            self.error(404)

    def put(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        else:
            logging.debug('R:%s LP:%s ON:%s OK:%s N:%s' % (self.request.headers['X-SecondLife-Region'], self.request.headers['X-SecondLife-Local-Position'], self.request.headers['X-SecondLife-Object-Name'], self.request.headers['X-SecondLife-Object-Key'], self.request.headers['X-SecondLife-Owner-Name']))
            av = self.request.headers['X-SecondLife-Owner-Key']
            avname = self.request.headers['X-SecondLife-Owner-Name']
            token = self.request.path.split("/")[-1]
            if not verify.validvalue('write',av,avname,token,self.request.body, self.request.headers):
                self.response.set_status(202)
            else:
                record = AvTokenValue.gql("WHERE av = :1 AND token = :2", av, token).get()
                if record is None:
                    oldval = ''
                    record = AvTokenValue(av = av, token = token, value = self.request.body)
                else:
                    oldval = record.value
                    record.value = self.request.body
                if CheckMemoryUse(av,self.request.body,oldval):
                    logging.info('%s saved by %s [%s]' % (token, avname, self.request.body))
                    record.put()

                    if token in relationtokens:
                        type = relationtokens[token]

                        logging.info('creating new relation for %s of type %s' % (avname, type))
                        #first clear the decks
                        relations.del_by_obj_type(av, type)
                        key_name_list = self.request.body.split(",")
                        keys = key_name_list[::2]#slice the list, from start to finish, with a step of 2
                        #names = key_name_list[1::2]#slice the list from second item to finish, with step of 2
                        for i in range(len(keys)):
                            logging.info('creating new relation with %s of type %s' % (keys[i], type))
                            relations.create_unique(keys[i], type, av)
                            #parse the value, create a relation for each
                    self.response.set_status(202)#accepted

    def delete(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        else:
            logging.debug('R:%s LP:%s ON:%s OK:%s N:%s' % (self.request.headers['X-SecondLife-Region'], self.request.headers['X-SecondLife-Local-Position'], self.request.headers['X-SecondLife-Object-Name'], self.request.headers['X-SecondLife-Object-Key'], self.request.headers['X-SecondLife-Owner-Name']))
            av = self.request.headers['X-SecondLife-Owner-Key']
            avname = self.request.headers['X-SecondLife-Owner-Name']
            token = self.request.path.split("/")[-1]

            if verify.validvalue('delete',av,avname,token,'', self.request.headers):
                logging.info('%s deleted by %s' % (token, avname))
                #get record with this key/token
                if token == alltoken:
                    #delete all this av's tokens
                    query = AvTokenValue.gql("WHERE av = :1", av)
                    if query.count() > 0:
                        for record in query:
                            record.delete()
                        relations.del_by_obj(av)

                        ClearMemoryUse(av)
                    else:
                        self.error(404)
                else:
                    record = AvTokenValue.gql("WHERE av = :1 AND token = :2", av, token).get()
                    if record is not None:
                        SubstractMemoryUse(av, record.value)
                        record.delete()
                    else:
                        self.error(404)
                    # check if we need to remove the any relations
                    if token in relationtokens:
                        type = relationtokens[token]
                        relations.del_by_obj_type(av, type)


application = webapp.WSGIApplication(
    [('/.*', MainPage)],
    debug=True)

def main():
    run_wsgi_app(application)

if __name__ == "__main__":
    main()
