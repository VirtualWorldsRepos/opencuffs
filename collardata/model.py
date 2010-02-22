from google.appengine.ext import db

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

class FreebieDelivery(db.Model):
    giverkey = db.StringProperty(required=True)
    rcptkey = db.StringProperty(required=True)
    itemname = db.StringProperty(required=True)#in form "name - version"

