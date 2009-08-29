//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//DEFAULT STATE

//on state entry, get db prefix from desc
    //look for default settings notecard.  if there, start reading
    //if not there, move straight to ready state
    
//on httpdb link message, stick command on queue

//READY STATE
//on state_entry, send new link message for each item on queue
//before sending HTTPDB_EMPTY on things, check default settings list.  send default if present

key wearer = NULL_KEY;

string parentmenu = "Help/Debug";
string submenu = "Refresh DB";
string dumpcache = "Dump Cache";

integer remoteon = FALSE;
float timeout = 30.0;
string queueurl = "http://collarcmds.appspot.com/";
key queueid;

list defaults;
list requestqueue;//requests are stuck here until we're done reading the notecard and web settings
string card = "defaultsettings";
integer line;
key dataid;


integer gotdefaults = FALSE;
integer gotsettings = FALSE;
list cache;
key allid;
string ALLTOKEN = "_all";

key newslistid;
list article_ids;

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
integer CHAT = 505;

//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bt of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
                            //str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent when a token has no value in the httpdb
integer HTTPDB_REQUEST_NOCACHE = 2005;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;

//5000 block is reserved for IM slaves

//5000 block is reserved for IM slaves

string HTTPDB = "http://collardata.appspot.com/db/"; //db url
key    reqid_load;                          // request id

//string dbprefix = "oc_";  //deprecated.  only appearance-related tokens should be prefixed now
                            //on a per-plugin basis

list tokenids;//strided list of token names and their corresponding request ids, so that token names can be returned in link messages

debug (string str)
{
    //llOwnerSay(llGetScriptName() + ": " + str);
}

integer DefaultValExists(string token)
{
    integer index = llListFindList(defaults, [token]);
    if (index == -1)
    {
        return FALSE;
    }    
    else
    {
        return TRUE;
    }
}

string GetDefaultVal(string token)
{
    integer index = llListFindList(defaults, [token]);
    return llList2String(defaults, index + 1);
}

integer CacheValExists(string token)
{
    integer index = llListFindList(cache, [token]);
    if (index == -1)
    {
        return FALSE;
    }    
    else
    {
        return TRUE;
    }
}

SetCacheVal(string token, string value)
{
    integer index = llListFindList(cache, [token]);
    if (index == -1)
    {
        cache += [token, value];
    }
    else
    {     
        cache = llListReplaceList(cache, [value], index + 1, index + 1);
    }  
}

string GetCacheVal(string token)
{
    integer index = llListFindList(cache, [token]);
    return llList2String(cache, index + 1);
}

DelCacheVal(string token)
{
    integer index = llListFindList(cache, [token]);
    if (index != -1)
    {
        cache = llDeleteSubList(cache, index, index + 1);
    }    
}

// Save a value to httpdb with the specified name.
httpdb_save( string name, string value ) 
{
    llHTTPRequest( HTTPDB + name, [HTTP_METHOD, "PUT"], value );
    llSleep(1.0);//sleep added to prevent hitting the sim's http throttle limit
}

// Load named data from httpdb.
httpdb_load( string name ) 
{
    tokenids += [name, llHTTPRequest( HTTPDB + name, [HTTP_METHOD, "GET"], "" )];
    llSleep(1.0);//sleep added to prevent hitting the sim's http throttle limit    
}

httpdb_delete(string name) {
    //httpdb_request( HTTPDB_DELETE, "DELETE", name, "" );
    llHTTPRequest(HTTPDB + name, [HTTP_METHOD, "DELETE"], "");
    llSleep(1.0);//sleep added to prevent hitting the sim's http throttle limit        
}

CheckQueue()
{
    debug("querying queue");
    queueid = llHTTPRequest(queueurl, [HTTP_METHOD, "GET"], "");
}

DumpCache()
{
    integer n;
    integer stop = llGetListLength(cache);
    string out = "Local Settings Cache:";
    for (n = 0; n < stop; n = n + 2)
    {
        //handle strlength > 1024
        string add = llList2String(cache, n) + "=" + llList2String(cache, n + 1) + "\n";
        if (llStringLength(out + add) > 1024)
        {
            //spew and clear
            llSay(0, "\n" + out);
            out = add;
        }
        else
        {
            //keep adding
            out += add;            
        }
    }
    llSay(0, "\n" + out);  
}

init()
{
    if (wearer == NULL_KEY)
    {//if we just started, save owner key
        wearer = llGetOwner();
    }
    else if (wearer != llGetOwner())
    {//we've changed hands.  reset script
        llResetScript();
    }
    
    defaults = [];//in case we just switched from the ready state, clean this now to avoid duplicates.    
    gotsettings = FALSE;
    gotdefaults = FALSE;
    allid = llHTTPRequest(HTTPDB + ALLTOKEN, [HTTP_METHOD, "GET"], "");
    if (llGetInventoryType(card) == INVENTORY_NOTECARD)
    {
        line = 0;
        dataid = llGetNotecardLine(card, line);
    }
    else
    {
        //default settings card not found, prepare for 'ready' state
        gotdefaults = TRUE;
    }    
}

default
{
    state_entry()
    {       
        init();
    }
    
    on_rez(integer param)
    {
        init();
    }
    
    dataserver(key id, string data)
    {
        if (id == dataid)
        {
            if (data != EOF)
            {
                integer index = llSubStringIndex(data, "=");
                string token = llGetSubString(data, 0, index - 1);
                string value = llGetSubString(data, index + 1, -1);
                defaults += [token, value];
                line++;
                dataid = llGetNotecardLine(card, line);                
            }
            else
            {
                //done reading notecard, switch to ready state
                gotdefaults = TRUE;
                if (gotdefaults && gotsettings)
                {
                    state ready;
                }
            }
        }
    }
    
    http_response(key id, integer status, list meta, string body)
    {  
        if (id == allid)
        {
            if (status == 200)
            {
                //got all settings page, parse it
                cache = [];
                list lines = llParseString2List(body, ["\n"], []);
                integer stop = llGetListLength(lines);
                integer n;
                for (n = 0; n < stop; n++)
                {
                    list params = llParseString2List(llList2String(lines, n), ["="], []);
                    string token = llList2String(params, 0);
                    string value = llList2String(params, 1);
                    SetCacheVal(token, value);
                }
                llOwnerSay("Settings loaded from web database.");
            }
            else
            {
                llOwnerSay("Unable to contact web database.  Using defaults and cached values.");
            }
            gotsettings = TRUE;

            if (gotsettings && gotdefaults)
            {
                state ready;
            }
        }
    }
    
    link_message(integer sender, integer num, string str, key id)
    {
        if (num == HTTPDB_REQUEST || num == HTTPDB_SAVE || num == HTTPDB_DELETE)
        {
            //we don't want to process these yet so queue them til done reading the notecard
            requestqueue += [num, str, id];
        }
    }
    
    changed(integer change)
    {
        if (change & CHANGED_OWNER)
        {
            llResetScript();
        }
    }      
}

state ready
{
    state_entry()
    {       
        llSleep(1.0);
        //loop through all the settings and defaults we've got
        //settings first
        integer n;
        integer stop = llGetListLength(cache);
        for (n = 0; n < stop; n = n + 2)
        {
            string token = llList2String(cache, n);
            string value = llList2String(cache, n + 1);
            llMessageLinked(LINK_SET, HTTPDB_RESPONSE, token + "=" + value, NULL_KEY);
        }
        
        //now loop through defaults, sending only if there's not a corresponding token in cache
        stop = llGetListLength(defaults);
        for (n = 0; n < stop; n = n + 2)
        {
            string token = llList2String(defaults, n);
            string value = llList2String(defaults, n + 1);
            if (!CacheValExists(token))
            {
                llMessageLinked(LINK_SET, HTTPDB_RESPONSE, token + "=" + value, NULL_KEY);
            }
        }
        
        //tell the world about our menu button
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + dumpcache, NULL_KEY); 
        CheckQueue();
        llSetTimerEvent(timeout);   
        
        //resend any requests that came while we weren't looking
        stop = llGetListLength(requestqueue);
        for (n = 0; n < stop; n = n + 3)
        {
            llMessageLinked(LINK_THIS, (integer)llList2String(requestqueue, n), llList2String(requestqueue, n + 1), (key)llList2String(requestqueue, n + 2));
        }
        requestqueue = [];
        
        //check for news
        newslistid = llHTTPRequest("http://collardata.appspot.com/news/check", [HTTP_METHOD, "GET"], "");        
    }
    
    link_message(integer sender, integer num, string str, key id)
    {
        //HandleRequest(num, str, id);
        //debug("Link Message: num=" + (string)num + ", str=" + str + ", id=" + (string)id);
        if (num == HTTPDB_SAVE)
        {
            //save the token, value  
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            httpdb_save(token, value);  
            SetCacheVal(token, value);
        }
        else if (num == HTTPDB_REQUEST)
        {
            //check the cache for the token
            if (CacheValExists(str))
            {          
                llMessageLinked(LINK_SET, HTTPDB_RESPONSE, str + "=" + GetCacheVal(str), NULL_KEY);            
            }
            else if (DefaultValExists(str))
            {
                llMessageLinked(LINK_SET, HTTPDB_RESPONSE, str + "=" + GetDefaultVal(str), NULL_KEY);               
            }
            else
            {
                llMessageLinked(LINK_SET, HTTPDB_EMPTY, str, NULL_KEY);            
            }
        }
        else if (num == HTTPDB_REQUEST_NOCACHE)
        {
            //request the token
            httpdb_load(str);        
        }
        else if (num == HTTPDB_DELETE)
        {
            DelCacheVal(str);       
            httpdb_delete(str);
        }    
        else if (num == HTTPDB_RESPONSE && str == "remoteon=1")
        {
            remoteon = TRUE;
            CheckQueue();
            llSetTimerEvent(timeout);
        }
        else if (num == HTTPDB_RESPONSE && str == "remoteon=0")
        {
            remoteon = FALSE;
            llSetTimerEvent(0.0);
        }    
        else if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
        {
            if (str == "cachedump")
            {
                DumpCache();
            }
            else if (str == "reset" || str == "runaway")
            {
                llHTTPRequest(HTTPDB + ALLTOKEN, [HTTP_METHOD, "DELETE"], "");    
                llSleep(3.0);
                llResetScript();        
            }
            else if (str == "remoteon")
            {
                remoteon = TRUE;
                //do http request for cmd list
                CheckQueue();
                //set timer to do same
                llSetTimerEvent(timeout);
                llInstantMessage(id, "Remote On.");
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "remoteon=1", NULL_KEY);
            }
            else if (str == "remoteoff")
            {
                //wearer can't turn remote off
                if (num == COMMAND_WEARER)
                {
                    llInstantMessage(id, "Sorry, the collar wearer can't turn off the remote.");
                }
                else
                {
                    remoteon = FALSE;
                    llSetTimerEvent(0.0);
                    llInstantMessage(id, "Remote Off.");   
                    llMessageLinked(LINK_THIS, HTTPDB_SAVE, "remoteon=0", NULL_KEY);                 
                }                   
            }
        }
        else if (num == SUBMENU)
        {
            if (str == submenu)
            {
                //notify that we're refreshing
                llInstantMessage(id, "Refreshing settings from web database.");
                //return parent menu
                llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);
                //refetch settings
                state default;            
            }
            else if (str == dumpcache)
            {
                DumpCache();
                llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);
            }
        }
        else if (num == MENUNAME_REQUEST && str == parentmenu)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + dumpcache, NULL_KEY);        
        }        
    }
    
    http_response( key id, integer status, list meta, string body ) 
    {
        integer index = llListFindList(tokenids, [id]);
        if ( index != -1 ) 
        {
            string token = llList2String(tokenids, index - 1);            
            if (status == 200)
            {
                string out = token + "=" + body;
                llMessageLinked(LINK_SET, HTTPDB_RESPONSE, out, NULL_KEY); 
                SetCacheVal(token, body);                            
            }
            else if (status == 404)
            {
                //check defaults, send if present, else send HTTPDB_EMPTY                
                integer index = llListFindList(defaults, [token]);
                if (index == -1)
                {
                    llMessageLinked(LINK_SET, HTTPDB_EMPTY, token, NULL_KEY); 
                }
                else
                {
                    llMessageLinked(LINK_SET, HTTPDB_RESPONSE, token + "=" + llList2String(defaults, index + 1), NULL_KEY);                     
                }             
            }
            //remove token, id from list
            tokenids = llDeleteSubList(tokenids, index - 1, index);
        }
        else if (id == queueid)//got a queued remote command
        {                             
            if (status == 200)
            {               
                //parse page, send cmds
                list lines = llParseString2List(body, ["\n"], []);
                integer n;
                integer stop = llGetListLength(lines);
                for (n = 0; n < stop; n++)
                {
                    //each line is pipe-delimited
                    list line = llParseString2List(llList2String(lines, n), ["|"], []);
                    string str = llList2String(line, 0);
                    key sender = (key)llList2String(line, 1);
                    debug("got queued cmd: " + str + " from " + (string)sender);
                    llMessageLinked(LINK_THIS, COMMAND_NOAUTH, str, sender);
                }
            }
        }
        else if (id == newslistid)
        {
            list articlekeys = llParseString2List(body, ["\n"], []);
            integer n;
            integer stop = llGetListLength(articlekeys);
            for (n = 0; n < stop; n++)
            {
                string articlekey = llList2String(articlekeys, n);
                article_ids += [llHTTPRequest("http://collardata.appspot.com/news/article/" + articlekey, [HTTP_METHOD, "GET"], "")];
            }            
        }
        else
        {
            integer newsindex = llListFindList(article_ids, [id]);
            if (newsindex != -1)
            {
                llOwnerSay(body);
                article_ids = llDeleteSubList(article_ids, newsindex, newsindex);
            }
        }        
    }
    
    on_rez(integer param)
    {
        state default;
    }  
    
    changed(integer change)
    {
        if (change & CHANGED_OWNER)
        {
            //problem: we may never get here, because "on_rez" happens before "changed", so we'll switch to state default first.
            llResetScript();
        }
    }
    
    timer()
    {
        if (remoteon)
        {
            CheckQueue();
        }
        else
        {
            //technically we should never get here, but if we do we should shut down the timer.
            llSetTimerEvent(0.0);
        }
    }
}
