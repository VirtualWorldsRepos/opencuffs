//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//on attach and on state_entry, http request for update

key wearer;

integer COMMAND_OWNER = 500;
integer COMMAND_WEARER = 503;
string resetScripts = "resetscripts";
integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
                            //str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent by httpdb script when a token has no value in the db

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
//integer ONREZ_EVENT = 4000; bullshit
integer UPDATE = 10001;

string dbtoken = "updatemethod";//valid values are "replace" and "inplace"
string updatemethod = "inplace";

integer updateChildPin = 4711;

string parentmenu = "Help/Debug";
string submenu = "Update";
integer updatechannel = -7483214;
integer updatehandle;
string newversion;

string baseurl = "http://collardata.appspot.com/updater/check?";
key httprequest;

list resetFirst = ["menu", "rlvmain", "anim/pose", "appearance"];
list itemTypes;

integer checked = FALSE;//set this to true after checking version

list childScripts; //3 strided list with format [id(of the prim), pin, (short)scriptname]

key updater; // key of avi who asked for the update
integer updatersNearby = -1;
integer willingUpdaters = -1;

//new for checking on resets in other collars:
integer lastReset;
      
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
SafeRemoveInventory(string item)
{
    if (llGetInventoryType(item) != INVENTORY_NONE)
    {
        llRemoveInventory(item);
    }
}
SafeResetOther(string scriptname)
{
    if (llGetInventoryType(scriptname) == INVENTORY_SCRIPT)
    {
            llResetOtherScript(scriptname);
            llSetScriptState(scriptname, TRUE);        
    }
} 

integer isOpenCollarScript(string name)
{
    name = llList2String(llParseString2List(name, [" - "], []), 0);
    if (name == "OpenCollar")
    {
        return TRUE;
    }
    else
    {
        return FALSE;
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
        name = "OpenCollarUpdater";
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
OrderlyReset(integer fullReset, integer isUpdateReset)
{
    string fullScriptName;
    string scriptName;
    integer scriptNumber = llGetInventoryNumber(INVENTORY_SCRIPT);
    integer resetNext = 0;
    integer i;
    llOwnerSay("OpenCollar scripts initializing...");
    while(resetNext <= llGetListLength(resetFirst) - 1)
    {   //reset script from the resetFirst list in order of their list position
        for (i = 0; i < scriptNumber; i++)
        {
            fullScriptName = llGetInventoryName(INVENTORY_SCRIPT, i);
            scriptName = llList2String(llParseString2List(fullScriptName, [" - "], []) , 1);
            if(isOpenCollarScript(fullScriptName))
            {   
                integer scriptPos = llListFindList(resetFirst, [scriptName]);
                if (scriptPos != -1)
                {
                    if(scriptPos == resetNext)
                    {//do not reset rlvmain on rez only on a full reset
                        resetNext++;
                        if (fullReset)
                        {
                            SafeResetOther(fullScriptName);
                        } 
                        else if (scriptName != "rlvmain" && scriptName != "settings")
                        {
                            SafeResetOther(fullScriptName);
                        }
                    }
                }
            }
        }
    }
    for (i = 0; i < scriptNumber; i++)
    {   //reset all other OpenCollar scripts
        fullScriptName = llGetInventoryName(INVENTORY_SCRIPT, i);
        scriptName = llList2String(llParseString2List(fullScriptName, [" - "], []) , 1);
        if(isOpenCollarScript(fullScriptName) && llListFindList(resetFirst, [scriptName]) == -1)
        {
            if(fullScriptName != llGetScriptName() && scriptName != "settings" && scriptName != "updateManager")
            {
                if (llSubStringIndex(fullScriptName, "@") != -1)
                { //just check once more if some childprim script remained and delete if
                    SafeRemoveInventory(fullScriptName);
                }
                else
                {
                    SafeResetOther(fullScriptName);
                }
            }
        }
        //take care of non OC script that were set to "not running" for the update, do not reset but set them back to "running"
        else //if (isUpdateReset)
        {
            if(!llGetScriptState(fullScriptName))
            {
                if (llGetInventoryType(fullScriptName) == INVENTORY_SCRIPT)
                {
                    llSetScriptState(fullScriptName, TRUE);        
                }
            }
        }
    }
    //send a message to childprim scripts to reset themselves
    llMessageLinked(LINK_ALL_OTHERS, UPDATE, "reset", NULL_KEY);
    for (i = 0; i < scriptNumber; i++)
    {   //last before myself reset the settings script
        fullScriptName = llGetInventoryName(INVENTORY_SCRIPT, i);
        scriptName = llList2String(llParseString2List(fullScriptName, [" - "], []) , 1);
        if(isOpenCollarScript(fullScriptName) && scriptName == "settings")
        {
            debug("Restting settings script");
            SafeResetOther(fullScriptName);
        }
    }
    llSleep(1.5);
    llMessageLinked(LINK_SET, COMMAND_OWNER, "refreshmenu", NULL_KEY);
    if (isUpdateReset)
    {
        llMessageLinked(LINK_THIS, UPDATE, "Reset Done", NULL_KEY);
    }
}

reseted_init()
{
    llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
    llSetTimerEvent(10.0);
}

default
{
    state_entry()
    {
        wearer = llGetOwner();
        debug("state default");
        //set our lastReset to the time of our startup 
        lastReset = llGetUnixTime();
        OrderlyReset(TRUE, TRUE);
        llSleep(1.5);
        llMessageLinked(LINK_SET, COMMAND_OWNER, "refreshmenu", NULL_KEY);
        state reseted;
    }
}


state reseted
{
    state_entry()
    {
        wearer = llGetOwner();
        debug("state reseted");
        reseted_init();
    }
    on_rez(integer param)
    {
       if (wearer == llGetOwner())
       {
            llSleep(1.5);
            reseted_init();
        }
        else
        {
            llResetScript();
        }
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
        
        if (auth == SUBMENU && str == submenu)
        {
            if (llGetAttached())
            {
                llMessageLinked(LINK_ROOT, SUBMENU, parentmenu, id);
                Notify(id, "Sorry, the collar cannot be updated while attached.  Rez it on the ground and try again.",FALSE);
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
                llSetTimerEvent(10.0); //set a timer to close the listener if no response                
            }
        }
        else if (auth == HTTPDB_RESPONSE)
        {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);            
            if (token == dbtoken)
            {
                updatemethod = value;
            }
        }
        else if( (id == wearer && auth <= COMMAND_WEARER && auth >= COMMAND_OWNER) || auth == COMMAND_OWNER)
        {
            if (str == resetScripts)
            {
                debug(str + (string)auth);
                OrderlyReset(TRUE, FALSE);
                reseted_init();
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
                llWhisper(updatechannel, "ready|" + (string)pin ); //give the ok to send update scripts etc...
            }
            updatersNearby = -1;
            willingUpdaters = -1;
        }
        if (!checked)
        {
            CheckForUpdate();   
            checked = TRUE;            
        }        
    }
}
