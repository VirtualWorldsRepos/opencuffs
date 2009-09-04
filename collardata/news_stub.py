#!/usr/bin/python
#Licensed under the GPLv2 (not later versions)
#see LICENSE.txt for details

#
#
#
#

import os
import logging
import datetime
import urllib
import random
import lindenip
import relations

from google.appengine.ext import db
from google.appengine.ext import webapp
from google.appengine.ext.webapp.util import run_wsgi_app
from updater import FreebieDelivery

#people allowed to send notices
adminkeys = ['2cad26af-c9b8-49c3-b2cd-2f6e2d808022',#Nandana Singh 
             '98cb0179-bc9c-461b-b52c-32420d5ac8ef']#Athaliah Opus

class Article(db.Model):
    """the text of a notice, with author and date/time stamp"""
    title = db.StringProperty()
    author = db.StringProperty()
    text = db.TextProperty()
    dts = db.DateTimeProperty()
    
class Item(db.Model):
    """items in the in-world object will have corresponding records of this class""" 
    name = db.StringProperty()
    giverkey = db.StringProperty()

class Attachment(db.Model):
    """associates an Item with a Article"""
    article = db.ReferenceProperty(Article)
    item = db.StringProperty()
    
class AvLastChecked(db.Model):
    """stores the datetime that the avatar last checked for news"""
    av = db.StringProperty()
    dts = db.DateTimeProperty()
    
def format_article(article):    
    return "%s\n%s\n%s\n\n%s" % (article.title, relations.key2name(article.author), str(article.dts), article.text)
    
class UpdateItems(webapp.RequestHandler):
    """responds to in-world attachment box that give list of items"""

class GiverQueue(webapp.RequestHandler):
    """responds to in-world attachment box querying for deliveries"""
    
class MainPage(webapp.RequestHandler):
    """draws a web form for creating new Articles and attaching Items to them, responds to said web form"""
    def get(self):
        self.response.out.write('hello world')
    
class NewsCheck(webapp.RequestHandler):    
    """responds to collars querying for new news items.  Returns 
    newline-delimited list of new article ids that"""
    def get(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        else:    
            #get all tokens from badkey and delete
            self.response.out.write("")            

class CreateArticle(webapp.RequestHandler):
    """for creating news items from scripts in-world"""
    def put(self):
        if not lindenip.inrange(os.environ['REMOTE_ADDR']):
            self.error(403)
        else:
            av = self.request.headers['X-SecondLife-Owner-Key']
            if av in adminkeys:
                #save the notice
                title = urllib.unquote(self.request.path.split("/")[-1])
                article = Article(title = title, author = av, text = self.request.body, dts = datetime.datetime.now())
                article.put()
                self.response.out.write('Saved article %s:\n%s' % (article.key(), format_article(article)))
            else:
                self.error(403)
                
class GetArticle(webapp.RequestHandler):
    def get(self):
    	self.error(404)
        #key = self.request.path.split("/")[-1]
        #article = db.get(key)
        #self.response.out.write(format_article(article))
    
application = webapp.WSGIApplication(
    [('/.*?/article/.*', GetArticle),
     ('/.*?/create/.*', CreateArticle),
     ('/.*?/check', NewsCheck),
     ('/.*', MainPage)
     ], 
    debug=True) 

def main():
    run_wsgi_app(application)

if __name__ == "__main__":
    main()    
