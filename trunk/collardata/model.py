import logging
from google.appengine.ext import db
from google.appengine.api import memcache

#only nandana singh and athaliah opus are authorized to add distributors
adminkeys = ['2cad26af-c9b8-49c3-b2cd-2f6e2d808022', '98cb0179-bc9c-461b-b52c-32420d5ac8ef','dbd606b9-52bb-47f7-93a0-c3e427857824','8487a396-dc5a-4047-8a5b-ab815adb36f0']

class Av(db.Model):
    id = db.StringProperty()
    name = db.StringProperty()

class Relation(db.Model):
    subj_id = db.StringProperty()
    type = db.StringProperty()
    obj_id = db.StringProperty()

class AvTokenValue(db.Model):
    av = db.StringProperty()
    token = db.StringProperty()
    value = db.TextProperty()

class AppSettings(db.Model):
  #token = db.StringProperty(multiline=False)
  value = db.StringProperty(multiline=False)

class Contributor(db.Model):
    avname = db.StringProperty()
    avkey = db.StringProperty()

class Distributor(db.Model):
    avname = db.StringProperty()
    avkey = db.StringProperty()

class FreebieItem(db.Model):
    freebie_name = db.StringProperty(required=True)
    freebie_version = db.StringProperty(required=True)
    freebie_giver = db.StringProperty(required=True)
    freebie_owner = db.StringProperty(required=False)
    freebie_timedate = db.DateTimeProperty(required=False)
    freebie_location = db.StringProperty(required=False)
    freebie_texture_key = db.StringProperty(required=False)
    freebie_texture_serverkey = db.StringProperty(required=False)
    freebie_texture_update = db.IntegerProperty(required=False)

class FreebieDelivery(db.Model):
    giverkey = db.StringProperty(required=True)
    rcptkey = db.StringProperty(required=True)
    itemname = db.StringProperty(required=True)#in form "name - version"

class VendorInfo(db.Model):
    vendor_key = db.StringProperty(required=True)
    vendor_owner = db.StringProperty(required=True)
    vendor_slurl = db.StringProperty(required=True, indexed=False)
    vendor_parcel = db.StringProperty(required=True)
    vendor_agerating = db.StringProperty(required=True)
    vendor_lastupdate = db.IntegerProperty(required=True)
    vendor_public = db.IntegerProperty(required=True)

def GenericStorage_Store(generic_token, generic_value):
    memtoken = "genstore_%s" % generic_token
    record = AppSettings.get_by_key_name(generic_token)
    if record is None:
        AppSettings(key_name=generic_token, value = generic_value).put()
    else:
        record.value = generic_value
        record.put()
    memcache.set(memtoken, generic_value)
    logging.info("Generic token '%s' saved, Value: %s" % (generic_token,generic_value))

def GenericStorage_Get(generic_token):
    memtoken = "genstore_%s" % generic_token
    value = memcache.get(memtoken)
    if value is None:
        record = AppSettings.get_by_key_name(generic_token)
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


