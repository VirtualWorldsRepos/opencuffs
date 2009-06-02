#!/usr/bin/python
#Licensed under the GPLv2 (not later versions)
#see LICENSE.txt for details

import cgi
import os
import re
import lindenip
import logging
import relations

relationtokens = {"owner":"owns", "secowners":"secowns"}#watch for these being saved, and make relations for them

from google.appengine.ext import db
from google.appengine.ext import webapp
from google.appengine.ext.webapp.util import run_wsgi_app

alltoken = "_all"

class AvTokenValue(db.Model):
    av = db.StringProperty()
    token = db.StringProperty()
    value = db.TextProperty()

class MainPage(webapp.RequestHandler):
    def get(self):
        #check that we're coming from an LL ip
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        else:
            av = self.request.headers['X-SecondLife-Owner-Key']
            avname = self.request.headers['X-SecondLife-Owner-Name']
            token = self.request.path.split("/")[-1]
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
            av = self.request.headers['X-SecondLife-Owner-Key']
            avname = self.request.headers['X-SecondLife-Owner-Name']
            token = self.request.path.split("/")[-1]
            logging.info('%s saved by %s' % (token, avname))
            record = AvTokenValue.gql("WHERE av = :1 AND token = :2", av, token).get()
            if record is None:
                record = AvTokenValue(av = av, token = token, value = self.request.body)
            else:
                record.value = self.request.body
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
                    relations.create_unique(keys[i], type, av)
                    #parse the value, create a relation for each
            self.response.set_status(202)#accepted
            
    def delete(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        else:
            av = self.request.headers['X-SecondLife-Owner-Key']
            avname = self.request.headers['X-SecondLife-Owner-Name']
            token = self.request.path.split("/")[-1]
            logging.info('%s deleted by %s' % (token, avname))
            #get record with this key/token
            if token == alltoken:
                #delete all this av's tokens
                query = AvTokenValue.gql("WHERE av = :1", av)
                if query.count() > 0:
                    for record in query:
                        record.delete()
                    relations.del_by_obj(av)
                else:
                    self.error(404)
            else:
                record = AvTokenValue.gql("WHERE av = :1 AND token = :2", av, token).get()
                if record is not None:
                    record.delete()
                else:
                    self.error(404)        

application = webapp.WSGIApplication(
    [('/.*', MainPage)], 
    debug=True) 

def main():
    run_wsgi_app(application)

if __name__ == "__main__":
    main()
