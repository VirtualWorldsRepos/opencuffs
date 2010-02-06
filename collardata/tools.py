from google.appengine.api import memcache
import logging
import yaml

#only nandana singh and athaliah opus, cleo collins, master starship are authorized to add distributors
adminkeys = ['2cad26af-c9b8-49c3-b2cd-2f6e2d808022', '98cb0179-bc9c-461b-b52c-32420d5ac8ef', 'dbd606b9-52bb-47f7-93a0-c3e427857824', '8487a396-dc5a-4047-8a5b-ab815adb36f0']


def enqueue_delivery(giver, rcpt, objname):
    #check memcache for giver's queue
    token = "deliveries_%s" % giver
    queue = memcache.get(token)
    if queue is None:
        #if not, create new key and save
        memcache.set(token, yaml.safe_dump([[objname, rcpt]]))
    else:
        deliveries = yaml.safe_load(queue)
        if len(deliveries) > 200:
            logging.error('Queue for %s hosting %s is too long, data not stored' % (giver, objname))
            return False
        else:
            if len(deliveries) > 40:
                logging.warning('Queue for %s hosting %s is getting long (%d entries)' % (giver, objname, len(deliveries)))
            logging.info('queue for %s is %s' % (giver, queue))
            objname = '%s / %d' % (objname, len(deliveries))
            deliveries.append([objname, rcpt])#yes I really mean append.  this is a list of lists
            memcache.set(token, yaml.safe_dump(deliveries))
            return True
