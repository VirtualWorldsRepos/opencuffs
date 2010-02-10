from google.appengine.api import memcache
import logging
import alarm

#only nandana singh and athaliah opus, cleo collins, master starship are authorized to add distributors
adminkeys = ['2cad26af-c9b8-49c3-b2cd-2f6e2d808022', '98cb0179-bc9c-461b-b52c-32420d5ac8ef', 'dbd606b9-52bb-47f7-93a0-c3e427857824', '8487a396-dc5a-4047-8a5b-ab815adb36f0']


def enqueue_delivery(giver, rcpt, objname, redirecturl):
    #check memcache for giver's queue
    token = "deliveries_%s" % giver
    deliveries = memcache.get(token)
    logging.info('Queue: %s|%s|%s|%s' % (giver, rcpt, objname, redirecturl))
    if deliveries is None:
        #if not, create new key and save
        memcache.set(token, [[objname, rcpt]])
        deliveries = memcache.get(token)
        logging.info('queue for %s is %s' % (giver, deliveries))
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
