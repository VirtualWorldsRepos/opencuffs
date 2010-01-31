import cgi
import urllib
import logging
import lindenip
import os
import relations
import time
import datetime
import string
from google.appengine.api import users
from google.appengine.ext import webapp
from google.appengine.ext.webapp.util import run_wsgi_app
from google.appengine.ext import db

class FreebieItem(db.Model):
    freebie_name = db.StringProperty(required=True)
    freebie_version = db.StringProperty(required=True)
    freebie_giver = db.StringProperty(required=True)
    freebie_owner = db.StringProperty(required=False)
    freebie_timedate = db.DateTimeProperty(required=False)


head = '''
<html>
<head>
<title>Freebie Item List</title>
<script src="/static/sorttable.js"></script>
<style>
body {
    background-color: #000000;
    color: #FF0000;
}
input {
    background-color: #000000;
    color: #FF0000;
    outline-color: #000000;
    border-color: #FF0000;
}
table.sortable thead {
    background-color:#eee;
    color:#666666;
    font-weight: bold;
    cursor: default;
}
</style>
</head>
<body>
'''
end = '''
</body>
</html>
'''

def GenVeriCode(length=4, chars=string.letters + string.digits):
    return ''.join([choice(chars) for i in range(length)])

class MainPage(webapp.RequestHandler):

    def get(self):
        message = '''<h1>List of Freebie items</h1>
<p>This list all item currently in the distribution system as of %s.</p>
<table class="sortable" border=\"1\">''' % datetime.datetime.utcnow().isoformat(' ')
        message += '<tr><th>Row</th><th>Owner</th><th>Giver ID</th><th>Name</th><th>Version</th><th>Update Date</th><br />\n'
        query = FreebieItem.gql("")
        content =[]
        for record in query:
            owner = record.freebie_owner
            if (owner == None):
                owner = '***Not assigned***'
            content += ['<td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td>\n' % (owner, record.freebie_giver, record.freebie_name, record.freebie_version, record.freebie_timedate)]

        content = sorted(content)

        for i in range(0,len(content)-1):
            message += '<tr><td>%d</td>%s' % (i+1, content[i])

        message += "</table>"


        self.response.out.write(head+message+end)


application = webapp.WSGIApplication(
    [('.*', MainPage)
     ],
    debug=True)

def real_main():
  run_wsgi_app(application)

def profile_main():
 # This is the main function for profiling
 # We've renamed our original main() above to real_main()
 import cProfile, pstats, StringIO
 prof = cProfile.Profile()
 prof = prof.runctx("real_main()", globals(), locals())
 stream = StringIO.StringIO()
 stats = pstats.Stats(prof, stream=stream)
 stats.sort_stats("time")  # Or cumulative
 stats.print_stats(80)  # 80 = how many to print
 # The rest is optional.
 # stats.print_callees()
 # stats.print_callers()
 logging.info("Profile data:\n%s", stream.getvalue())

if __name__ == "__main__":
  profile_main()