//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//on attach and on state_entry, http request for update

key wearer;

integer UPDATE = 10001;

string dbtoken = "updatemethod";//valid values are "replace" and "inplace"
string updatemethod = "inplace";

integer updatechannel = -7483210;
integer updatehandle;
string newversion;

string baseurl = "http://collardata.appspot.com/updater/check?";

key httprequest;

integer checked = FALSE;//set this to true after checking version

key updater; // key of avi who asked for the update
integer updatersNearby = -1;
integer willingUpdaters = -1;
      
debug(string message)
{
    //llOwnerSay("DEBUG " + llGetScriptName() + ": " + message);
} 
Notify(key id, string msg, integer alsoNotifyWearer) {
    if (id == wearer) {
        llOwnerSay(msg);
    } else {
        llInstantMessage(id,msg);
        if (alsoNotifyWearer) {
            llOwnerSay(msg);
        }
    }    
}

CheckForUpdate()
{
    list params = llParseString2List(llGetObjectDesc(), ["~"], []);
    string name = llList2String(params, 0);
    string version = llList2String(params, 1);
    
    //handle in-place updates.
    if (updatemethod == "inplace")
    {
        name = "OC_Sub_AO_Updater";
    }
    
    if (name == "" || version == "")
    {
        llOwnerSay("You have changed my description.  Automatic updates are disabled.");
    }
    else if ((float)version)
    {
        string url = baseurl;
        url += "object=" + llEscapeURL(name);
        url += "&version=" + llEscapeURL(version);
        httprequest = llHTTPRequest(url, [HTTP_METHOD, "GET"], "");
    }
}
ReadyToUpdate(integer del)
{
    integer pin = (integer)llFrand(99999998.0) + 1; //set a random pin
    llSetRemoteScriptAccessPin(pin);
    llWhisper(updatechannel, "ready|" + (string)pin ); //give the ok to send update sripts etc...
}

default
{
    state_entry()
    {
        wearer = llGetOwner();
        llSetTimerEvent(10.0);
    }
    on_rez(integer param)
    {
        llResetScript();
    }
    
    http_response(key request_id, integer status, list metadata, string body)
    {
        if (request_id == httprequest)
        {
            if (llGetListLength(llParseString2List(body, ["|"], [])) == 2)
            {
                llOwnerSay("There is a new version of me available.  An update should be delivered in 30 seconds or less.");
                //client side is done now.  server has queued the delivery, 
                //and in-world giver will send us our object when it next 
                //pings the server
            }
        }
    }
    
    link_message(integer sender, integer auth, string str, key id)
    {
        if (auth == UPDATE && str == "Update")
        {
            if (llGetAttached())
            {
                Notify(id, "Sorry, the AO cannot be updated while attached.  Rez it on the ground and try again.",FALSE);
            }
            else
            {
                string version = llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 1);
                updatersNearby = 0;
                willingUpdaters = 0;
                updater = id;
                Notify(id,"Searching for nearby updater",FALSE);
                updatehandle = llListen(updatechannel, "", "", "");
                llWhisper(updatechannel, "UPDATE|" + version);
                llSetTimerEvent(5.0); //set a timer to close the listener if no response                
            }
        }
    }
    listen(integer channel, string name, key id, string message)
    {   //collar and updater have to have the same Owner else do nothing!
        debug(message);
        if (llGetOwnerKey(id) == wearer)
        {
            list temp = llParseString2List(message, [","],[]);
            string command = llList2String(temp, 0);
            if(message == "nothing to update")
            {
                updatersNearby++;
            }
            else if( message == "get ready")
            {
                updatersNearby++;
                willingUpdaters++;
            }
        }
    }
    timer()
    {
        llSetTimerEvent(0.0);
        llListenRemove(updatehandle);
        if (updatersNearby > -1) {
            if (!updatersNearby) {
                Notify(updater,"No updaters found.  Please rez an updater within 10m and try again",FALSE);
            } else if (willingUpdaters > 1) {
                Notify(updater,"Multiple updaters were found within 10m.  Please remove all but one and try again",FALSE);
            } else if (willingUpdaters) {
                integer pin = (integer)llFrand(99999998.0) + 1; //set a random pin
                llSetRemoteScriptAccessPin(pin);
                llWhisper(updatechannel, "ready|" + (string)pin ); //give the ok to send update sripts etc...
            }
            updatersNearby = -1;
            willingUpdaters = -1;
        }
        if (!checked)
        {
            //there can be only one update script in the prim.  make it so
            //ThereCanBeOnlyOne();
            //check version after
            CheckForUpdate();   
            checked = TRUE;            
        }        
    }
    changed(integer change)
    {
        if (change & CHANGED_OWNER)
        {
            wearer = llGetOwner();
        }
    }
}
