#!/usr/bin/python
#Licensed under the GPLv2 (not later versions)
#see LICENSE.txt for details

import cgi
import os
import re
import lindenip
import logging
import relations

from google.appengine.ext import db
from google.appengine.ext import webapp
from google.appengine.ext.webapp.util import run_wsgi_app
from collardb import AvTokenValue

g_owner = "owner" #token for owner
g_secowner= "secowners" #tokes for secowner

class MainPage(webapp.RequestHandler):
    def delete(self):
         if not lindenip.inrange(os.environ['REMOTE_ADDR']):#only allow access from sl
            self.error(403)
         else:
            av = self.request.headers['X-SecondLife-Owner-Key']#get owner av key
            avname = self.request.headers['X-SecondLife-Owner-Name']#get owner av name
            subbie = self.request.path.split("/")[-1] #get key of sub from path
            if avname != "(Loading...)":
                relations.update_av(av, avname)#resolve key 2 name for owner
            logging.info("Remove sub request from %s (%s) for sub (%s)" % (av,avname,subbie))
            answer=0
            # first check if owner
            record = AvTokenValue.gql("WHERE av = :1 AND token = :2", subbie, g_owner).get() # request owner record of subbie
            if record is not None:
                #found a record for that subbie
                if av in record.value:
                    # and the av is stil the owner, so remove it
                    ownerlist=record.value.split(",")
                    owner_index=ownerlist.index(av)
                    del ownerlist[owner_index:owner_index+2]
                    if ownerlist == []:
                        #list is emty, so just delete the record
                        record.delete()
                        logging.info("Remove sub request from %s for %s: Primary owner record deleted" % (avname,subbie))
                    else:
                        #build the new secowner list and save it
                        s=""
                        for x in ownerlist:
                            s += x+","
                        logging.info(s.rstrip(','))
                        # update the records value
                        record.value=s.rstrip(',')
                        # and save it
                        record.put()
                        logging.info("Remove sub request from %s for %s: Primary record updated: %s" % (avname,subbie, record.value))

                    #update the reealtion db
                    relations.delete(av,"owns",subbie)
                    # and prepare the answer for sl
                    answer+=1

            #now we do the same for the secowner
            record = AvTokenValue.gql("WHERE av = :1 AND token = :2", subbie, g_secowner).get() # request owner record of subbie
            if record is not None:
                #found a record for that subbie
                if av in record.value:
                    # and the av is stil the owner, so remove it
                    ownerlist=record.value.split(",")
                    owner_index=ownerlist.index(av)
                    del ownerlist[owner_index:owner_index+2]
                    if ownerlist == []:
                        #list is emty, so just delete the record
                        record.delete()
                        logging.info("Remove sub request from %s for %s: Secower owner record deleted" % (avname,subbie))
                    else:
                        #build the new secowner list and save it
                        s=""
                        for x in ownerlist:
                            s += x+","
                        logging.info(s.rstrip(','))
                        # update the records value
                        record.value=s.rstrip(',')
                        # and save it
                        record.put()
                        logging.info("Remove sub request from %s for %s: Secower record updated: %s" % (avname,subbie, record.value))

                    #update the reealtion db
                    relations.delete(av,"secowns",subbie)
                    # and prepare the answer for sl
                    answer+=2

            #answer to sl so we know what happened
            self.response.headers['Content-Type'] = 'text/plain'
            self.response.out.write("%d" % answer)
            self.response.set_status(200)




application = webapp.WSGIApplication(
    [('/.*', MainPage)],
    debug=True)

def main():
    run_wsgi_app(application)

if __name__ == "__main__":
    main()