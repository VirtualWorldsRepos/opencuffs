#!/usr/bin/python
#Licensed under the GPLv2 (not later versions)
#see LICENSE.txt for details
# Module for notifying Admins of the app
# the names, keys and email adresses are stored in a DB and have to be edited via the AppEngine interface

import logging

from google.appengine.ext import db
from google.appengine.api import mail

# db storage of key, name and email for admins
class AdminEmails(db.Model):
    avname = db.StringProperty()
    avkey = db.StringProperty()
    avmail = db.StringProperty()

# sends a mail toall admins in the list
def notify_all(mail_subject, mail_text):
    # send the mail to every admin in this listm as there migt be a security problem
    record = db.GqlQuery("SELECT * FROM AdminEmails")
    # get all admins and send them a email with the notifications
    if record is None:
        logging.warning("No admin emails found!")
    else:
        for admin in record:
            mail.send_mail(sender="cleo.collins.sl@googlemail.com", to=admin.avmail, subject=mail_subject, body=mail_text)

# routines to add and check autorized admins, currently not in use, databse wil be handled via data viewer
def authorized(av):
    #True if av is on the authorized distributor list, else False
    record = AdminEmails.gql('WHERE avkey = :1', av).get()
    if record is None:
        return False
    else:
        return True

def add(av, name, mail):
    record = AdminEmails.gql('WHERE avkey = :1', av).get()
    if record is None:
        NewAdmin = AdminEmails(avkey = av, avname = name, avmail = mail)
        NewAdmin.put()

def delete(av, name):
    record = AdminEmails.gql('WHERE avkey = :1', av).get()
    if record is not None:
        record.delete()
