#!/usr/bin/python
#Licensed under the GPLv2 (not later versions)
#see LICENSE.txt for details
#handles urls for redirecting to map them user friendly to the google wiki pages

import wsgiref.handlers
from google.appengine.ext import webapp

WikiMainPage = 'OpenCollar?tm=6'
WikiAddress = 'http://code.google.com/p/opencollar/wiki/'
AppRedirectPath = '/wiki_redirect/'

class Redirect(webapp.RequestHandler):
    def get(self):
        # path starts with
        path = self.request.path[len(AppRedirectPath):]

        if path == '':
            # emty path, so we want the WikiMainpage, as the base page looks ugly
            TargetULR = WikiAddress + WikiMainPage
        else:
            # User wants a special page, so add it to the base URL
            TargetULR = WikiAddress + path
            
        self.redirect(TargetULR, True)

def main():
  application = webapp.WSGIApplication([('/.*', Redirect)
                                        ], debug=True)
  wsgiref.handlers.CGIHandler().run(application)


if __name__ == '__main__':
  main()
