from google.appengine.api import memcache
import logging
import alarm

import model

def enqueue_delivery(giver, rcpt, objname, redirecturl):
    #check memcache for giver's queue
    token = "deliveries_%s" % giver
    deliveries = memcache.get(token)
    if deliveries is None:
        #if not, create new key and save
        memcache.set(token, [[objname, rcpt]])
        return True
    else:
        if len(deliveries) > 200:
            logging.error('Queue for %s hosting %s is too long, data not stored' % (giver, objname))
            alarm.SendAlarm('Vendor', giver, True, 'Vendor queue for %s hosting %s is too long, data not stored. Please make sure to check the object and the database usage!' % (giver, objname), redirecturl)
            return False
        else:
            if len(deliveries) > 50:
                logging.warning('Queue for %s hosting %s is getting long (%d entries)' % (giver, objname, len(deliveries)))
            logging.info('queue for %s is %s' % (giver, deliveries))
            deliveries.append([objname, rcpt])#yes I really mean append.  this is a list of lists
            memcache.set(token, deliveries)
            return True
