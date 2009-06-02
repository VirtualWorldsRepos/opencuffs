//new viewer checking method, as of 2.73
//on rez, restart script
//on script start, query db for rlvon setting
//on rlvon response, if rlvon=0 then just switch to checked state.  if rlvon=1 or rlvon=unset then open listener, do @version, start 30 second timer
//on listen, we got version, so stop timer, close listen, turn on rlv flag, and switch to checked state
//on timer, we haven't heard from viewer yet.  Either user is not running RLV, or else they're logging in and viewer could not respond yet when we asked.
    //so do @version one more time, and wait another 30 seconds.
//on next timer, give up. User is not running RLV.  Stop timer, close listener, set rlv flag to FALSE, save to db, and switch to checked state.     

integer rlvon = FALSE;//set to TRUE if DB says user has turned RLV features on
integer viewercheck = FALSE;//set to TRUE if viewer is has responded to @version message
integer listener;
float versiontimeout = 30.0;
integer versionchannel = 293847;
integer checkcount;//increment this each time we say @version.  check it each time timer goes off in default state. give up if it's >= 2

//"checked" state - HANDLING RLV SUBMENUS AND COMMANDS
//on start, request RLV submenus
//on rlv submenu response, add to list
//on main submenu "RLV", bring up this menu

string parentmenu = "Main";
string submenu = "RLV";
list menulist;
integer menutimeout = 30;
integer menulistener;
integer menuchannel = 2380982;
integer verbose;

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
//integer CHAT = 505;//deprecated
integer COMMAND_OBJECT = 506;
integer COMMAND_RLV_RELAY = 507;

//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bt of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
                            //str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent by httpdb script when a token has no value in the db

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer MENUNAME_REMOVE = 3003;

integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.

integer ANIM_START = 7000;//send this with the name of an anim in the string part of the message to play the anim
integer ANIM_STOP = 7001;//send this with the name of an anim in the string part of the message to stop the anim

string UPMENU = "~PrevMenu~";
string TURNON = "*Turn On*";
string TURNOFF = "*Turn Off*";
string CLEAR = "*Clear All*";

CheckVersion()
{
    //llOwnerSay("checking version");
    if (verbose)
    {
        llOwnerSay("Attempting to enable Restrained Life Viewer functions.  This will only work if you are currently using the Restrained Life Viewer.");        
    }
    //open listener
    listener = llListen(versionchannel, "", llGetOwner(), "");
    //start timer
    llSetTimerEvent(versiontimeout);
    //do ownersay
    checkcount++;
    llOwnerSay("@version=" + (string)versionchannel);
}

DoMenu(key id)
{
    list buttons;
    if (rlvon)
    {
        buttons += [TURNOFF, CLEAR] + llListSort(menulist, 1, TRUE);        
    }
    else
    {
        buttons += [TURNON];
    }
    
    string prompt = "Restrained Life Viewer Options";
    prompt += "\n(Menu will time out in " + (string)menutimeout + " seconds.)";     
    menuchannel = llRound(llFrand(9999999.0));       
    menulistener = llListen(menuchannel, "", id, "");
    llSetTimerEvent(menutimeout);
    buttons += [UPMENU];
    buttons = RestackMenu(FillMenu(buttons));
    llDialog(id, prompt, buttons, menuchannel);
    //TO-DO: handle multi-page menus, in case we ever have like 13 RLV plugins (please god no)
    //TO-DO: sort the buttons alphabetically before delivering the dialog.  fill and restack
}

list FillMenu(list in)
{
    //adds empty buttons until the list length is multiple of 3, to max of 12
    while (llGetListLength(in) != 3 && llGetListLength(in) != 6 && llGetListLength(in) != 9 && llGetListLength(in) < 12)
    {
        in += [" "];
    }
    return in;
}

list RestackMenu(list in)
{
    //re-orders a list so dialog buttons start in the top row
    list out = llList2List(in, 9, 11);
    out += llList2List(in, 6, 8);
    out += llList2List(in, 3, 5);    
    out += llList2List(in, 0, 2);    
    return out;
}

default
{    
    on_rez(integer param)
    {
        llResetScript();
    }
    
    state_entry()
    {
        //request setting from DB
        llSleep(1.0);
        llMessageLinked(LINK_THIS, HTTPDB_REQUEST, "rlvon", NULL_KEY);        
        //Tell main menu we've got a submenu
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);      
    }
    
    link_message(integer sender, integer num, string str, key id)
    {
        if (num == HTTPDB_RESPONSE && str == "rlvon=0")
        {     
            //RLV is turned off in DB.  just switch to checked state without checking viewer
            //llOwnerSay("rlvdb false");            
            state checked;
        }        
        else if (num == HTTPDB_RESPONSE && str == "rlvon=1")
        {
            //DB says we were running RLV last time it looked.  do @version to check.
            //llOwnerSay("rlvdb true");
            rlvon = TRUE;                       
            //check viewer version
            CheckVersion();
        }
        else if ((num == HTTPDB_EMPTY && str == "rlvon") || (num == HTTPDB_RESPONSE && str == "rlvon=unset"))
        {
            //the db has no record of whether this person runs RLV or not
            //llOwnerSay("rlvdb unset");            
            //check viewer version
            CheckVersion();            
        }
        else if (num == MENUNAME_REQUEST && str == parentmenu)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);      
        }
        else if (num == SUBMENU && str == submenu)
        {
            //someone clicked "RLV" on the main menu.  Tell them we're not ready yet.
           llInstantMessage(id, "Still querying for viewer version.  Please try again in a minute.");
        }          
    }
    
    listen(integer channel, string name, key id, string message)
    {
        if (channel == versionchannel)
        {
            //llOwnerSay("heard " + message);
            llListenRemove(listener);
            llSetTimerEvent(0.0);       
                 
            llMessageLinked(LINK_THIS, HTTPDB_SAVE, "rlvon=1", NULL_KEY);
            
            //this is already TRUE if rlvon=1 in the DB, but not if rlvon was unset.  set it to true here regardless, since we're setting rlvon=1 in the DB
            rlvon = TRUE;
            
            if (verbose)
            {
                llOwnerSay("Restrained Life functions enabled.");
            }
            viewercheck = TRUE;
            state checked;     
        }
    }
    
    timer()
    {
        llListenRemove(listener);
        llSetTimerEvent(0.0);  
        if (checkcount == 1)
        {
            //the viewer hasn't responded after 30 seconds, but maybe it was still logging in when we did @version
            //give it one more chance
            CheckVersion();
        }
        else if (checkcount >= 2)
        {          
            //we've given the viewer a full 60 seconds
            viewercheck = FALSE;
            rlvon = FALSE;
            llMessageLinked(LINK_THIS, HTTPDB_SAVE, "rlvon=0", NULL_KEY);
            //else the user normally logs in with RLv, but just not this time
            //in which case, leave it turned on in the database, until user manually changes it
            
            if (verbose)
            {
                llInstantMessage(llGetOwner(), "Could not detect Restrained Life Viewer.  Restrained Life functions disabled.");
            }
            
            //DEBUG force rlvon and viewercheck for now, during development
            //viewercheck = TRUE;
            //rlvon = TRUE;
            //llOwnerSay("DEBUG: rlv on");
            
            state checked;            
        }
    }
}

state checked
{
    on_rez(integer param)
    {
        llResetScript();
    }
    
    attach(key id)
    {
        if (id == NULL_KEY && rlvon && viewercheck)
        {
            llOwnerSay("@clear");
        }
    }
    
    state_entry()
    {
        menulist = [];//clear this list now in case there are old entries in it
        //we only need to request submenus if rlv is turned on and running
        if (rlvon && viewercheck)
        {
            //ask RLV plugins to tell us about their rlv submenus
            llMessageLinked(LINK_THIS, MENUNAME_REQUEST, submenu, NULL_KEY);        
            
            //tell rlv plugins to reinstate restrictions
            llMessageLinked(LINK_THIS, RLV_REFRESH, "", NULL_KEY);            
        }
        //llOwnerSay("entered checked state.  rlvon=" + (string)rlvon + ", viewercheck=" + (string)viewercheck);
    }
    
    link_message(integer sender, integer num, string str, key id)
    {
        if (num == MENUNAME_REQUEST)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        else if (num == SUBMENU && str == submenu)
        {
            //someone clicked "RLV" on the main menu.  Give them our menu now
            DoMenu(id);
        }        
        
        if (rlvon && viewercheck)
        {
            //if RLV is off, don't even respond to RLV submenu events
            if (num == MENUNAME_RESPONSE)
            {
                //str will be in form of "parentmenu|menuname"
                list params = llParseString2List(str, ["|"], []);
                string thisparent = llList2String(params, 0);
                string child = llList2String(params, 1);
                if (thisparent == submenu)
                {
                    //add this str to our menu buttons
                    if (llListFindList(menulist, [child]) == -1)
                    {
                        menulist += [child];
                    }                    
                }
            }
            else if (num == MENUNAME_REMOVE)
            {
                //str will be in form of "parentmenu|menuname"
                list params = llParseString2List(str, ["|"], []);
                string thisparent = llList2String(params, 0);
                string child = llList2String(params, 1);                
                if (thisparent == submenu)
                {
                    integer index = llListFindList(menulist, [child]);
                    if (index != -1)
                    {
                        menulist = llDeleteSubList(menulist, index, index);
                    }                    
                }                
            }       
            else if (num == RLV_CMD)
            {
                llOwnerSay("@" + str);
                //llOwnerSay("RLV: " + str);
            }             
            else if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
            {
                if (str == "clear")
                {
                    if (num == COMMAND_WEARER)
                    {
                        llInstantMessage(llGetOwner(), "Sorry, but the sub cannot clear RLV settings.");
                    }
                    else
                    {
                        llMessageLinked(LINK_THIS, RLV_CLEAR, "", NULL_KEY);                    
                        llOwnerSay("@clear");                        
                    }
                }
            }
        }
    }
    
    listen(integer channel, string name, key id, string message)
    {
        if (channel == menuchannel)
        {
            llListenRemove(menulistener);
            llSetTimerEvent(0.0);
            if (message == TURNON)
            {
                //save the setting to the database
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "rlvon=1", NULL_KEY);            
                rlvon = TRUE;    
                verbose = TRUE;
                state default;
            }
            else if (message == TURNOFF)
            {
                rlvon = FALSE;
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "rlvon=0", NULL_KEY);
                llOwnerSay("@clear");
                DoMenu(id);
            }
            else if (message == CLEAR)
            {
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "clear", id);
                DoMenu(id);                
            }            
            else if (message == UPMENU)
            {
                llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);                   
            }
            else if (llListFindList(menulist, [message]) != -1 && rlvon)
            {
                llMessageLinked(LINK_THIS, SUBMENU, message, id);
            }
        }        
    }
    
    timer()
    {
        llListenRemove(menulistener);
        llSetTimerEvent(0.0);        
    }
}