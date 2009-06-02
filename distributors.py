#!/usr/bin/python
#Licensed under the GPLv2 (not later versions)
#see LICENSE.txt for details

from google.appengine.ext import db

class Distributor(db.Model):
    avname = db.StringProperty()
    avkey = db.StringProperty()

def authorized(av):
    #True if av is on the authorized distributor list, else False
    record = Distributor.gql('WHERE avkey = :1', av).get()
    if record is None:
        return False
    else:
        return True

def add(av, name):
    record = Distributor.gql('WHERE avkey = :1', av).get()
    if record is None:
        NewDist = Distributor(avkey = av, avname = name)
        NewDist.put()
        
def delete(av, name):
    record = Distributor.gql('WHERE avkey = :1', av).get()
    if record is not None:
        record.delete()
       