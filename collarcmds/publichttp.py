# Code was released into the public domain by Darien Caldwell
# http://forums.secondlife.com/showthread.php?t=323981

import cgi
import urllib
import logging
import lindenip
import os
import relations
from math import log, ceil
from decimal import *
from model import GoogleSLIds
from operator import itemgetter
from google.appengine.api import memcache
from google.appengine.api import users
from google.appengine.ext import webapp
from google.appengine.ext.webapp.util import run_wsgi_app
from google.appengine.ext import db

class AvTPs(db.Expando):
    av = db.StringProperty(multiline=False)
    tps = db.ListProperty(str)


userid = ""
useremail = ""
param2 = ""

class MainPage(webapp.RequestHandler):
  def get(self):
    #check linden ip
    if False:#(self.request.headers['User-Agent'].find("SecondLife") == -1) :#lindenip.inrange(os.environ['REMOTE_ADDR']):
        self.error(403)
    else:
        param2 = self.request.get('key')
        q = db.GqlQuery("SELECT * FROM Lookup WHERE av = :kk",kk=param2)
        count=q.count(2)
        if count==0 :
            cmdurl=''
            '''Need to put error here'''
        else:
            record=q.get()
            cmdurl = record.puburl
            if cmdurl[-8:-1] == "disabled":
                '''Show a diffrent page'''
                pass
        q = db.GqlQuery("SELECT * FROM Av WHERE id = :kk",kk=param2)
        count=q.count(2)
        if count==0 :
            subname='Error finding name'
            '''Need to put error here'''
        else:
            record=q.get()
            subname = record.name
        q = db.GqlQuery("SELECT * FROM AvTPs WHERE av = :kk",kk=param2)
        count=q.count(2)
        if count==0 :
              logging.warning('%s is retrieving the url for %s but it doesnt exist' % (useremail, param2))
              self.error(404)
        else:
              logging.info('%s is retrieving the url for %s' % (useremail, param2))
              record=q.get()
              
              tps = ''
              links = ''
              xlist = []
              ylist = []
              for a in record.tps:
                  b = a.split("|")
                  globcor=b[0].split("(")[-1]
                  loccor=b[1].split(",")
                  xloc=loccor[0].strip("(")
                  yloc=loccor[1]
                  zloc=loccor[2].strip(")")
                  x=str(float(globcor.split(",")[0])/256+float(xloc)/256)
                  y=str(float(globcor.split(",")[1].strip(")"))/256+float(yloc)/256)
                  mapcor=x+", "+y+")"
                  xlist += [Decimal(x)]
                  ylist += [Decimal(y)]
                  tps += 'mapWindow = new MapWindow("'+subname+' was at '+b[0].split("(")[0]+' ('+str(int(float(xloc)))+', '+str(int(float(yloc)))+', '+str(int(float(zloc)))+') on '+b[2]+'");\n'
                  tps += 'marker = new Marker(all_images, new XYPoint('+mapcor+');\n'
                  tps += 'mapInstance.addMarker(marker, mapWindow);\n'
                  links += '<p><a href="javascript: mapInstance.panOrRecenterToSLCoord(new XYPoint('+mapcor+', true);"> '+subname+' was at '+b[0].split("(")[0]+' ('+str(int(float(xloc)))+', '+str(int(float(yloc)))+', '+str(int(float(zloc)))+') on '+b[2]+'</a></p>\n'
              xcenter = str((max(xlist)-min(xlist))/2+min(xlist))
              ycenter = str((max(ylist)-min(ylist))/2+min(ylist))
              xdiff=max(xlist)-min(xlist)
              ydiff=max(ylist)-min(ylist)
              if ydiff == 0 and xdiff == 0:
                  scale='2'
              elif xdiff>ydiff :
                  scale=str(ceil(log(xdiff,2)))
              else:
                  scale=str(ceil(log(ydiff,2)))
              if scale>8:
                  xcenter = str(sum(xlist)/len(xlist))
                  ycenter = str(sum(ylist)/len(ylist))
              header = '''
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
<head>
<title>OpenCollar webinterface for '''+subname+'''</title>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
<script src="http://maps.google.com/maps?file=api&v=2&key=ABQIAAAAllmRirwxU-abqO4akMFFPhRlOb26qSyU154aZeLwOrF4C7-DphS23YsdNRnYYJkSxtcIV2PDrFFQuw"  type="text/javascript"></script>
<script src="http://slurl.com/_scripts/slmapapi.js" type="text/javascript"></script>
<link rel="stylesheet" type="text/css" href="http://slurl.com/_styles/MAIN.css" />
<style>
div#map-container {
      width: 500px;
      height: 500px;
      float:left;
      margin: 5px;
      font-size: 11px;
      border-style:solid;
      border-width:0px 1px;
}
div#form {
      position: fixed;
      bottom: 0px;
      background-color: #000000;
      width: 100%;
      border-style:solid;
      border-width:1px 0px 0px;
}
div#cmdstore {
      display:none;
}
div#ownerlist {
      float:left;
}
div#title {
      width: 99%;
      position:absolute;
}
div#logo {
      left: 0px;
      position:absolute;
}
div#top {
      width: 100%;
      height:128px;
      border-style:solid;
      border-width:0px 0px 1px;
}
div#tplist {
    min-height:500px;
    font-size: 11px;
}
table {
    border-color: #FF0000;
    borderCollapse: collapse;
    border-spacing: 0px;
    border-width: 0px 1px 1px 0px;
}
td {
    border-color: #FF0000;
    border-width: 1px 0px 0px 1px;
}
body {
    background-color: #000000;
    color: #FF0000;
    overflow: auto;
    font-size: medium;
    border-color: #FF0000;
}
html {
    background-color: #000000
}
input {
    background-color: #000000;
    color: #FF0000;
    outline-color: #000000;
    border-color: #FF0000;
}
.center {
    text-align: center;
}
</style>
<script id="external_script" type="text/JavaScript"></script>
<script type="text/javascript">
var count=0;
function submit()
{
count = count + 1;
 var cmd=document.getElementById("cmd").value;
 document.getElementById("cmd").disabled=true
 document.getElementById('cmdstore').innerHTML=count;
 setTimeout("checkcmd(count)",3000);
   var old = document.getElementById('uploadScript');
   if (old != null) {
     old.parentNode.removeChild(old);
     delete old;
   }
   var body = document.getElementsByTagName("body")[0];
   var script = document.createElement('script');
   script.id = 'uploadScript';
   script.type = 'text/javascript';
   script.src = '''+"'"+cmdurl+"?'"+'''+cmd;
   body.appendChild(script);
}
function cmdreceived(cmd)
{
 if (cmd == 'ping')
 {
     collarworking();
 }
 else
 {
     //alert("it worked");
 }
 document.getElementById("cmd").value='';
 document.getElementById('cmdstore').innerHTML='0';
 document.getElementById("cmd").disabled=false;
}
function checkcmd(sentcount)
{
    if (document.getElementById('cmdstore').innerHTML==sentcount)
    {
        alert("There has been an error. Try refreshing the page.");
    }
}
function javascriptworking()
{
    document.getElementById("form").innerHTML='The wear is not online or httpin is disabled.';
    var body = document.getElementsByTagName("body")[0];
    var script = document.createElement('script');
    script.id = 'uploadScript';
    script.type = 'text/javascript';
    script.src = '''+"'"+cmdurl+"?'"+'''+'ping';
    body.appendChild(script);
}
function collarworking()
{
    document.getElementById("form").innerHTML='Type any chat command with out the prefix ie. if you send nadu the sub will assume nadu. To send a message to the sub type 'tosub:' then your message.<br><form action="javascript:submit();">Cmd <input type="text" id="cmd" size="100" maxlength="255"></form>';
}
var g_aData = {};
function Settings(sData,iMore,iPage)
{
    var lTemp;
    var sToken;
    var sValue;
    var lData = sData.split("|");
    for( var i = 0; i < lData.length; i++ )
    {
        lTemp = lData[i].split("=",2);
        sToken = lTemp[0];
        sValue = lTemp[1];
        g_aData[sToken] = sValue;
    }
}
</script>


<script>
// mapInstance and marker is set as a glabal, so that the removeMarker function can access them
var mapInstance, marker, mapWindow;
function loadmap() {
  // creates the map
  javascriptworking();//for OC to check if the collar is up.
  mapInstance = new SLMap(document.getElementById('map-container'));
  mapInstance.centerAndZoomAtSLCoord(new XYPoint('''+xcenter+', '+ycenter+'), '+scale+''');
  
  // creates the icons
  var yellow_dot_image = new Img("http://slurl.com/examples/b_map_yellow.gif", 9, 9);
  var yellow_icon = new Icon(yellow_dot_image);
  var all_images = [yellow_icon, yellow_icon, yellow_icon, yellow_icon, yellow_icon, 

yellow_icon];
'''
              mid = '''
}
</script>
</head>
<body onload="loadmap()" onunload="GUnload()">
<div id="top" class="center">
<div id="logo"><img src="/static/OpenCollarLogo128.png" /></div>
<div id="title">
<h1><a href="/webinterface/">Web Interface</a> for '''+subname+'''</h1>
<h2>OpenCollar</h2>
</div>
</div>
<div id="ownerlist">
<br />
'''+'</div><div id="map-container"></div><div id="tplist">'
              end = '''
</div>
<div id="form">
JavaScript does not seem to be enabled.
</div>
<div id="cmdstore">
</div>
</body>
'''

              self.response.out.write(header+tps+mid+links+end) #print the map

#      else:
#        logging.warning('%s is not owned by userid: %s' % (parm2,userid))
#        self.redirect("/webinterface/")


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