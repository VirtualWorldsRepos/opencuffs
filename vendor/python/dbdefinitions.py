from google.appengine.ext import db
from google.appengine.api import memcache
import logging

# persons allowed to distribute items
class Distributor(db.Model):
    avname = db.StringProperty()
    avkey = db.StringProperty()

# persons allowed to rez vendors
class Vendor(db.Model):
    avname = db.StringProperty()
    avkey = db.StringProperty()

# old delivery system
class FreebieItem(db.Model):
    freebie_name = db.StringProperty(required=True)
    freebie_version = db.StringProperty(required=True)
    freebie_giver = db.StringProperty(required=True)

# old delivery system
class FreebieDelivery(db.Model):
    giverkey = db.StringProperty(required=True)
    rcptkey = db.StringProperty(required=True)
    itemname = db.StringProperty(required=True)#in form "name - version"

# value storing in collardata
class AvTokenValue(db.Model):
    av = db.StringProperty()
    token = db.StringProperty()
    value = db.TextProperty()

# storage of items avail throughout the vendor system
class VendorItem(db.Model):
    item_name = db.StringProperty(required=True)
    item_version = db.StringProperty(required=True)
    item_giver = db.StringProperty(required=True)
    item_owner = db.StringProperty(required=True)
    item_lastupdate = db.IntegerProperty(required=True)

class DistributorBox(db.Model):
    box_key = db.StringProperty(required=True)
    box_url = db.StringProperty(required=True)
    box_owner = db.StringProperty(required=True)
    box_lastupdate = db.IntegerProperty(required=True)
    box_lastping = db.IntegerProperty(required=True)

# storage of textures for the disribution system, will be handled fromone cetral server
class VendorTexture(db.Model):
    item_name = db.StringProperty(required=True)
    item_texture = db.StringProperty(required=True)
    item_update_time = db.IntegerProperty(required=True)
    texture_owner = db.StringProperty(required=True)



# Generic storage for values like timestamps of different databases
class GenericStorage(db.Model):
    token = db.StringProperty(required=True)
    value  = db.StringProperty(required=True)

def GenericStorage_store(generic_token, generic_value):
    memtoken = "genstore_%s" % generic_token
    record = GenericStorage.gql('WHERE token = :1', generic_token).get()
    if record is None:
        NewGen = GenericStorage(token = generic_token, value = generic_value)
        NewGen.put()
    else:
        record.value = generic_value
        record.put()
    memcache.set(memtoken, generic_value)
    logging.info("Generic token '%s' saved, Value: %s" % (generic_token,generic_value))

def GenericStorage_get(generic_token):
    memtoken = "genstore_%s" % generic_token
    value = memcache.get(memtoken)
    if value is None:
        record = GenericStorage.gql('WHERE token = :1', generic_token).get()
        if record is not None:
            value = record.value
            logging.info("Generic token '%s' retrieved from DB, Value: %s" % (generic_token,value))
            return value
        else:
            logging.info("Generic token '%s' not found" % (generic_token))
            return ''
    else:
        logging.info("Generic token '%s' retrieved from Memcache, Value: %s" % (generic_token,value))
        return value

