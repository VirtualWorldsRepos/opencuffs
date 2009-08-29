//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//on attach and on state_entry, http request for update


integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
                            //str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent by httpdb script when a token has no value in the db

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
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

integer seppuku = FALSE;//set this to true if, during inplace update, the updater script itself will be replaced, meaning that I should delete myself at the end

list childScripts; //3 strided list with format [id(of the prim), pin, (short)scriptname]
        
debug(string message)
{
//    llOwnerSay("DEBUG " + llGetScriptName() + ": " + message);
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

ThereCanBeOnlyOne()
{//make sure that there's only one opencollar update script in here
    integer resetneeded = FALSE;

    //first, delete self if a clone, ie, if name is like "OpenCollar - update - 3.014 1"
    string myname = llGetScriptName();
    list parts = llParseString2List(myname, [" - "], []);
    string versionpart = llList2String(parts, 2);
    if (llSubStringIndex(versionpart, " ") != -1)
    {//there's a space in the last part of the script name, which means I'm a clone
        SafeRemoveInventory(myname);
    }
    //next, delete self if there's an opencollar update script with higher version than me
    integer n;
    integer stop = llGetInventoryNumber(INVENTORY_SCRIPT);
    for (n = 0; n < stop; n++)
    {
        string thisname = llGetInventoryName(INVENTORY_SCRIPT, n);
        if (thisname != myname)//don't examine self
        {
            if (llSubStringIndex(thisname, "OpenCollar - update") == 0)//only examine update scripts
            {
                float myversion = (float)versionpart;
                float thisversion = (float)llList2String(llParseString2List(thisname, [" - "], []), 2);
                if (myversion <= thisversion)
                {
                    SafeRemoveInventory(myname);
                }
                else
                {
                    //finally, delete younger opencollar update scripts (needed for upgrades to update scripts that didn't have this function) 
                    SafeRemoveInventory(thisname);    
                    resetneeded = TRUE;                 
                }
            }
        }
    }
    
    if (resetneeded)
    {
        OrderlyReset();
    }
}

OrderlyReset()
{//reset menu script, then everything else, then httpdb script
 //there's some redundancy here with some of the "finalize" steps, but I don't want to sort through it right now
    integer n;
    integer stop = llGetInventoryNumber(INVENTORY_SCRIPT);
    
    for (n = 0; n < stop; n++)//reset menu script(s)
    {
        string name = llGetInventoryName(INVENTORY_SCRIPT, n);
        if (~llSubStringIndex(name, "menu"))
        {
            SafeResetOther(name);
        }
    }
    
    for (n = 0; n < stop; n++)//reset everything but menu script(s), httpdb, and self
    {
        string name = llGetInventoryName(INVENTORY_SCRIPT, n);
        if (llSubStringIndex(name, "menu") == -1 && llSubStringIndex(name, "update") == -1 && llSubStringIndex(name, "httpdb") == -1)
        {
            SafeResetOther(name);
        }
    }    
    
    for (n = 0; n < stop; n++)//reset httpdb script
    {
        string name = llGetInventoryName(INVENTORY_SCRIPT, n);
        if (~llSubStringIndex(name, "httpdb"))
        {
            SafeResetOther(name);
            return;
        }
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

integer isOpenCollarPlugin(string name)
{
    name = llGetSubString(llList2String(llParseString2List(name, [" - "], []), 0), 0,1);
    if (llToLower(name) == "oc")
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

DeleteOld(list toDelete)
{
    integer i;
    for (i = 0; i < llGetListLength(toDelete); i++)
    {
        string delName = llList2String(toDelete, i);
        if(llGetInventoryType(delName) != -1)
        {
            SafeRemoveInventory(delName);
        }
    }
}
    
DeleteItems(list toDelete)
{
    integer deleteSelf = FALSE;
    integer type = (integer)llList2String(toDelete, 0);
    toDelete = llDeleteSubList(toDelete, 0,0);
    integer i;
    if(type == INVENTORY_SCRIPT)
    {//handle replacing scripts.  These are different from other inventory because they're versioned.
        list oldScripts;
        list newScripts;
        string fullScriptName;
        string shortScriptName;
        
        //make list of scripts that we'll be receiving from updater, w/o version numbers
        for(i = 0; i < llGetListLength(toDelete); i++)
        {
            fullScriptName = llList2String(toDelete, i);
            shortScriptName = llGetSubString(fullScriptName, 0, llStringLength(fullScriptName) - 6);
            newScripts += [shortScriptName];
        }
        
        //make strided list of scripts in inventory, in form versioned,nonversioned
        for(i = 0; i < llGetInventoryNumber(INVENTORY_SCRIPT); i ++)
        {
            fullScriptName = llGetInventoryName(type, i);
            shortScriptName = llGetSubString(fullScriptName, 0, llStringLength(fullScriptName) - 6);
            oldScripts += [fullScriptName, shortScriptName];
        }
        
        //loop through new scripts.  Delete old, superseded ones
        for(i = 0; i < llGetListLength(newScripts); i++)
        {
            shortScriptName = llList2String(newScripts, i);
            integer foundAt = llListFindList(oldScripts, [shortScriptName]);
            if(foundAt != -1)
            {
                fullScriptName = llList2String(oldScripts, foundAt -1);
                if(fullScriptName != llGetScriptName())
                {
                    debug("deleting " + fullScriptName);
                    SafeRemoveInventory(fullScriptName);
                }
                else
                {
                    debug("got update to update script.  I will SEPPUKU!");
                    deleteSelf = TRUE;
                    seppuku = TRUE;
                }
            }
/* //actually no more needed here
            else
            {   // script is new or in a different prim
                llMessageLinked(LINK_ALL_OTHERS, UPDATE, "prepare", NULL_KEY);
            }
*/
        }
    }
    else
    {
        for (i = 0; i < llGetListLength(toDelete); i++)
        {
            string delName = llList2String(toDelete, i);
            if(llGetInventoryType(delName) != -1)
            {
                SafeRemoveInventory(delName);
            }
        }
    }
    integer index = llListFindList(itemTypes, [(string)type]); // should always be 0
    itemTypes = llDeleteSubList(itemTypes, index, index);
    if(llGetListLength(itemTypes))
    {
        llWhisper(updatechannel, "giveList|" + llList2String(itemTypes, 0));
    }
    else
    {
        debug("updating non-items, will self-delete");
        ReadyToUpdate(deleteSelf);
    }
}

ReadyToUpdate(integer del)
{
    integer pin = (integer)llFrand(99999998.0) + 1; //set a random pin
    llSetRemoteScriptAccessPin(pin);
    llWhisper(updatechannel, "ready|" + (string)pin ); //give the ok to send update sripts etc...
}

FinalizeUpdate()
{
    debug("finalize 1");
    llSetRemoteScriptAccessPin(0);
    integer childs = llGetNumberOfPrims();
    integer i;
    string fullScriptName;
    string scriptName;
    string scriptToPrim;
    integer scriptNumber = llGetInventoryNumber(INVENTORY_SCRIPT);
    for (i = 2; i < childs; i++)
    {   //load script (hovertext, and possibly relay) into the hovertext prim
        string primDesc = (string)llGetObjectDetails(llGetLinkKey(i), [OBJECT_DESC]);
        primDesc = llList2String(llParseString2List(primDesc, ["~"], []), 0);
        key dest = llGetLinkKey(i);
        integer n;
        if(primDesc != "")
        {
            for (n = 0; n < scriptNumber; n++)
            {
                fullScriptName = llGetInventoryName(INVENTORY_SCRIPT, n);
                scriptToPrim = llList2String(llParseString2List(fullScriptName, [" - "], []) , 1);
                scriptToPrim = llList2String(llParseString2List(scriptToPrim, ["@"], []), 1);
                if ((llToLower(primDesc) == llToLower(scriptToPrim)) && (scriptToPrim != ""))
                {
                    llRemoteLoadScriptPin(dest, fullScriptName, updateChildPin, TRUE, 41);
                    SafeRemoveInventory(fullScriptName);
                }
            }
        }
    }//######################################
    // new way to update childprim scripts the part before can be deleted in the next coming update cycle tp prevent the annoying script error when the script tries to load a script into a non-prepared child prim
    list newChildScripts;
    string shortScriptName;
    //make strided list of scripts in inventory, in form versioned,nonversioned
    for(i = 0; i < llGetInventoryNumber(INVENTORY_SCRIPT); i ++)
    {
        fullScriptName = llGetInventoryName(INVENTORY_SCRIPT, i);
        //shortScriptName = llGetSubString(fullScriptName, 0, llStringLength(fullScriptName) - 6);
        shortScriptName = llList2String(llParseString2List(fullScriptName, [" - "],[]), 1);
        newChildScripts += [fullScriptName, shortScriptName];
    }
//    debugChilds(childScripts);
    childs = llGetListLength(childScripts);
    for( i = 2; i < childs; i = i + 3)
    {
        shortScriptName = llList2String(childScripts, i);
        integer pin = (integer)llList2String(childScripts, i - 1);
        key destPrim = llList2String(childScripts, i - 2);
        integer index = llListFindList(newChildScripts, [shortScriptName]);
        if(index != -1)
        {
            fullScriptName = llList2String(newChildScripts, index - 1);
            llRemoteLoadScriptPin(destPrim, fullScriptName, pin, TRUE, 41);
            SafeRemoveInventory(fullScriptName);
        }
    }
    //lets check if a script that was meant to be in a child prim is still here and if... delete it
    scriptNumber = llGetInventoryNumber(INVENTORY_SCRIPT);
    for (i = 0; i < scriptNumber; i++)
    {
        fullScriptName = llGetInventoryName(INVENTORY_SCRIPT, i);
        if (llSubStringIndex(fullScriptName, "@") != -1)
        {
            SafeRemoveInventory(fullScriptName);
        }
    }
    //lets reset scripts in order...
    debug("finalize 2");    
    scriptNumber = llGetInventoryNumber(INVENTORY_SCRIPT);
    //shall be resetted in order in the list
    integer resetNext = 0;
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
                    {
                        resetNext++;
                        SafeResetOther(fullScriptName);
                    }
                }
            }
        }
    }
    debug("finalize 3");    
    for (i = 0; i < scriptNumber; i++)
    {   //reset all other OpenCollar scripts
        fullScriptName = llGetInventoryName(INVENTORY_SCRIPT, i);
        scriptName = llList2String(llParseString2List(fullScriptName, [" - "], []) , 1);
        if(isOpenCollarScript(fullScriptName) && llListFindList(resetFirst, [scriptName]) == -1)
        {
            if(fullScriptName != llGetScriptName() && scriptName != "httpdb")
            {   //not sure if needed but to make sure not to reset myself here
                if (llSubStringIndex(fullScriptName, "@") != -1)
                {
                    SafeRemoveInventory(fullScriptName);
                }
                else
                {
                    SafeResetOther(fullScriptName);
                }
            }
        }
    }
    llMessageLinked(LINK_ALL_OTHERS, UPDATE, "reset", NULL_KEY);
// not sure if we should do this !!!!
    debug("finalize 4");
    for (i = 0; i < scriptNumber; i++)
    {   //reset other scripts which are not default OpenCollar scripts
        fullScriptName = llGetInventoryName(INVENTORY_SCRIPT, i);
        if(isOpenCollarPlugin(fullScriptName))
        {
            if (llSubStringIndex(fullScriptName, "@") != -1)
            {
                SafeRemoveInventory(fullScriptName);
            }
            else
            {
                SafeResetOther(fullScriptName);
            }
        }
    }
    
    string collarName = llList2String(llParseString2List(llGetObjectName(), [" - "], []), 0);
    string currentVersionName = llList2String(llParseString2List(llGetObjectName(), [" - "], []), 1);
    string currentVersionDesc = llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 1);
    string collarDesc = llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 0);
    if(currentVersionName == currentVersionDesc)
    {
        collarName += " - " + newversion;
        llSetObjectName(collarName);
    }
    /*
    if (collarName == collarDesc)
    {
        collarName += " - " + newversion;
        llSetObjectName(collarName);
    }
    */
    collarDesc += "~" + newversion + "~";
    collarDesc += llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
    llSetObjectDesc(collarDesc); //set the new version in the collar description
    llWhisper(updatechannel, "finished"); //announce to the updater that all is done
    llSetTexture("bd7d7770-39c2-d4c8-e371-0342ecf20921", ALL_SIDES);
        
    debug("finalize 5");
    for (i = 0; i < scriptNumber; i++)
    {   //last before myself reset the httpdb script
        fullScriptName = llGetInventoryName(INVENTORY_SCRIPT, i);
        scriptName = llList2String(llParseString2List(fullScriptName, [" - "], []) , 1);
        if(isOpenCollarScript(fullScriptName) && scriptName == "httpdb")
        {
            debug("Restting httpdb script");
            SafeResetOther(fullScriptName);
        }
    }
    debug("finalize 6");
    /* // moved  this part before the httpdb script
    string collarName = llList2String(llParseString2List(llGetObjectName(), [" - "], []), 0);
    string collarDesc = llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 0);
    if (collarName == collarDesc)
    {
        collarName += " - " + newversion;
        llSetObjectName(collarName);
    }
    collarDesc += "~" + newversion + "~";
    collarDesc += llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
    llSetObjectDesc(collarDesc); //set the new version in the collar description
    llWhisper(updatechannel, "finished"); //announce to the updater that all is done
    llSetTexture("bd7d7770-39c2-d4c8-e371-0342ecf20921", ALL_SIDES);
    */
    //die if there's a replacement
    debug("finalize 7");    
    if (seppuku)
    {
        debug("SEPPUKU!");
        SafeRemoveInventory(llGetScriptName());
    }
    debug("finalize 8");    
    llResetScript(); //finally reset myself
}

default
{
    state_entry()
    {
        debug("state_entry()");
        if( llGetStartParameter() == 42)
        {
            debug("started with startParam 42.");
            ThereCanBeOnlyOne(); //any older update script might work against me so... DELETE them!
            updatehandle = llListen(updatechannel, "", "", "");
            llMessageLinked(LINK_ALL_OTHERS, UPDATE, "prepare", NULL_KEY);
        }
        else
        {
            llSetRemoteScriptAccessPin(0);
            llSleep(1.0);
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
            llSetTimerEvent(10.0);//will check version after this runs out.
        }
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
        if (auth == SUBMENU && str == submenu)
        {
            if (llGetAttached())
            {
                llMessageLinked(LINK_ROOT, SUBMENU, parentmenu, id);
                llInstantMessage(id, "Sorry, the collar cannot be updated while attached.  Rez it on the ground and try again.");
            }
            else
            {
                string version = llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 1);
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
        else if (auth == UPDATE)
        {
            list temp = llParseString2List(str, ["|"],[]);
            string scriptName = llList2String(temp, 0);
            string pin = llList2String(temp,1);
            if (llListFindList(childScripts, [(string)id, str]) == -1) 
            {
                childScripts += [(string)id, pin, scriptName];
            }
        }
    }
    listen(integer channel, string name, key id, string message)
    {   //collar and updater have to have the same Owner else do nothing!
        debug(message);
        if (llGetOwnerKey(id) == llGetOwner())
        {
            list temp = llParseString2List(message, [","],[]);
            string command = llList2String(temp, 0);
            if(message == "nothing to update")
            {
                llListenRemove(updatehandle);
                llSetTimerEvent(0.0);
            }
            else if(command == "delete")
            {
                list thingstodelete = llDeleteSubList(temp, 0, 0);
                debug("deleting: " + llDumpList2String(thingstodelete, ","));
                DeleteOld(thingstodelete);
                //send a message to child prims
//                llMessageLinked(LINK_ALL_OTHERS, UPDATE, "prepare", "");
                llWhisper(updatechannel, "deleted");
            }
            else if(command == "toupdate")
            {
                llSetTimerEvent(0.0);
                itemTypes = llList2List(temp, 1, -1);
                llWhisper(updatechannel, "giveList|" + llList2String(itemTypes, 0));
            }
            else if(command == "items")
            {
                DeleteItems(llDeleteSubList(temp, 0, 0));
            }
            else if(command == "version")
            {
                newversion = llGetSubString((string)llList2Float(temp, 1), 0, 4);
                llListenRemove(updatehandle);
                FinalizeUpdate();
            }
        }
    }
    timer()
    {
        llSetTimerEvent(0.0);
        llListenRemove(updatehandle);
        if (!checked)
        {
            //there can be only one update script in the prim.  make it so
            ThereCanBeOnlyOne();
            //check version after
            CheckForUpdate();   
            checked = TRUE;            
        }        
    }
}
