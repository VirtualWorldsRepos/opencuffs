import logging
import cgi
from google.appengine.ext import db
from google.appengine.api import urlfetch
from google.appengine.api import memcache
from google.appengine.ext import webapp
from google.appengine.ext.webapp.util import run_wsgi_app

import relations

relationtypes = ['owns', 'secowns']#valid relation types.  For the sake of consistency
                                    #let's keep only active verbs in this list
class Av(db.Model):
    id = db.StringProperty()
    name = db.StringProperty()

class AppSettings(db.Model):
  #token = db.StringProperty(multiline=False)
  value = db.StringProperty(multiline=False)


sharedpass = AppSettings.get_or_insert("sharedpass", value="sharedpassword").value
cmdurl = AppSettings.get_or_insert("cmdurl", value="http://yourcmdapp.appspot.com").value

class GetName2Key(webapp.RequestHandler):
    def get(self):
        if (self.request.headers['sharedpass'] == sharedpass):
            key = cgi.escape(self.request.get('key'))
            logging.info('Key2name request for %s' % (key))
            name = relations.key2name(key)
            if name:
                logging.info('Resolved as %s' % (name))
                self.response.out.write(name)
                self.response.set_status(200)#accepted
            else:
                logging.warning('Could not be resolved!')
                self.response.out.write('')
                self.response.set_status(202)#accepted
        else:
            self.error(403)
            logging.error('wrong shared password expecting %s received %s ip address' % (sharedpass,self.request.headers['sharedpass'],os.environ['REMOTE_ADDR']))


class MainPage(webapp.RequestHandler):
    def get(self):
        self.response.out.write('hello world')

application = webapp.WSGIApplication(
    [
     (r'/.*?/getname',GetName2Key),
     ('/.*', MainPage)
     ],
    debug=True)

def main():
    run_wsgi_app(application)

if __name__ == "__main__":
    main()