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

from model import VendorInfo

head = '''
<html>
<head>
<title>%s</title>
<script src="/static/sorttable.js"></script>
<style>
body {
    background-color: #000000;
    color: #FF0000;
    font-family:"Arial",Arial,sans-serif;
}

a:link { text-decoration:none; color:#e00000; }
a:visited { text-decoration:none; color:#800000; }
a:hover { text-decoration:none; background-color:#ff0; }

input {
    background-color: #000000;
    color: #FF0000;
    outline-color: #000000;
    border-color: #FF0000;
}
table.sortable thead {
    background-color:#202020;
    color:#FF0000;
    font-weight: bold;
    cursor: default;
}
</style>
</head>
<body>
<h1><img src='/static/OpenCollarLogo128.png' align="absmiddle">List of public available vendors of OpenCollar</h1>
<p>In the following you find a list of all public accessible vendors. You can click on the headers of the table to sort it for that column and use the SLURL to reach the vendors inworld.</p>
<p>This list is automatically maintained, outdated vendors will be removed within 48 hours. The vendors there are usually not maintained by OpenCollar self.</p>
'''

end = '''
</body>
</html>
'''


class MainPage(webapp.RequestHandler):
    def get(self):
        query = VendorInfo.gql("WHERE vendor_public=1 ORDER BY vendor_agerating ASC, vendor_parcel ASC")
        if query.count()==0:
            message = '<b>Currently no vendors are listed!</b>'
        else:
            message = '<table class="sortable" border=\"1\">'
            message += '<tr><th>Row</th><th>Parcel</th><th>AgeRating</th><th>SLURL</th></tr><br />\n'
            content =[]
            for record in query:
                content += ['<td>%s</td><td>%s</td><td><a target="_blank" href="%s">%s</a></td>\n' % (record.vendor_parcel, record.vendor_agerating, record.vendor_slurl, record.vendor_slurl)]



            #content = sorted(content)

            for i in range(0,len(content)):
                message += '<tr><td>%d</td>%s' % (i+1, content[i])

            message += "</table>"

        self.response.out.write((head % 'OpenCollar Vendor Locations') + message + end)


application = webapp.WSGIApplication([
    ('.*', MainPage)
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