#!/usr/bin/python
#Licensed under the GPLv2 (not later versions)
#see LICENSE.txt for details
# we now have 2 databases for handling the permissions of the for the OC distributing system
# Distributors are persons, who can place vendorsto deliver items to clients
# Designers are persons who can place Distribuor boxes for delivering the actual items to the clients

from google.appengine.ext import db

# people how are allowed to use Distribution boxes
class Designer(db.Model):
    avname = db.StringProperty()
    avkey = db.StringProperty()

# people who can place vendors
class Distributor(db.Model):
    avname = db.StringProperty()
    avkey = db.StringProperty()

# routines for identifying and adding Designers
def authorized_vendor(av):
    #True if av is on the authorized distributor list, else False
    record = Designer.gql('WHERE avkey = :1', av).get()
    if record is None:
        return False
    else:
        return True

def add_designer(av, name):
    record = Designer.gql('WHERE avkey = :1', av).get()
    if record is None:
        NewVendor = Designer(avkey = av, avname = name)
        NewVendor.put()

def delete_designer(av, name):
    record = Designer.gql('WHERE avkey = :1', av).get()
    if record is not None:
        record.delete()

def getname_designer(av):
    record = Designer.gql('WHERE avkey = :1', av).get()
    if record is not None:
        return record.avname

# routines for identifying and addign Distributors
def authorized_distributor(av):
    #True if av is on the authorized distributor list, else False
    record = Distributor.gql('WHERE avkey = :1', av).get()
    if record is None:
        return False
    else:
        return True

def add_distributor(av, name):
    record = Distributor.gql('WHERE avkey = :1', av).get()
    if record is None:
        NewVendor = Distributor(avkey = av, avname = name)
        NewVendor.put()

def delete_distributor(av, name):
    record = Distributor.gql('WHERE avkey = :1', av).get()
    if record is not None:
        record.delete()

def getname_distributor(av):
    record = Distributor.gql('WHERE avkey = :1', av).get()
    if record is not None:
        return record.avname
