string parentmenu = "RLV";
string submenu = "Sit";
string dbtoken = "rlvsit";


list settings;//2-strided list in form of [option, param]


list rlvcmds = [
"unsit",//may stand, if seated
"sittp"//may sit 1.5M+ away
];

list prettycmds = [ //showing menu-friendly command names for each item in rlvcmds
"Stand",
"Sit"
];

list descriptions = [ //showing descriptions for commands
"Ability to Stand If Seated",
"Ability to Sit On Objects 1.5M+ Away"
];

//two of these commands take effect immediately and are not stored: force sit and force stand
//this list breaks tradition and is 3-strided, in form of cmd,prettyname,desc
list imdtcmds = [
"sit","SitNow","Force Sit",
"forceunsit","StandNow","Force Stand"
];


string TURNON = "Allow";
string TURNOFF = "Forbid";

integer timeout = 30;
integer menuchannel = 987345;
integer listener;
integer returnmenu = FALSE;

float scanrange = 20.0;//range we'll scan for scripted objects when doing a force-sit
key menuuser;//used to remember who to give the menu to after scanning
list sitbuttons;
string sitprompt;
list sitkeys;
integer sitchannel = 324590;
integer sitlistener;

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

Menu(key id)
{
    //build prompt showing current settings
    //make enable/disable buttons
    string prompt = "Pick an option";
    prompt += "\n(Menu will expire in " + (string)timeout + " seconds.)";
    prompt += "\nCurrent Settings: ";
    list buttons;
    
        
    integer n;
    integer stop = llGetListLength(rlvcmds);
    for (n = 0; n < stop; n++)
    {
        //see if there's a setting for this in the settings list
        string cmd = llList2String(rlvcmds, n);
        string pretty = llList2String(prettycmds, n);
        string desc = llList2String(descriptions, n);
        integer index = llListFindList(settings, [cmd]);
        if (index == -1)
        {
            //if this cmd not set, then give button to enable
            buttons += [TURNOFF + " " + llList2String(prettycmds, n)];
            prompt += "\n" + pretty + " = Enabled (" + desc + ")";
        }
        else
        {
            //else this cmd is set, then show in prompt, and make button do opposite
            //get value of setting         
            string value = llList2String(settings, index + 1);
            if (value == "y")
            {
                buttons += [TURNOFF + " " + llList2String(prettycmds, n)];
                prompt += "\n" + pretty + " = Enabled (" + desc + ")";                
            }   
            else if (value == "n")
            {
                buttons += [TURNON + " " + llList2String(prettycmds, n)];
                prompt += "\n" + pretty + " = Disabled (" + desc + ")";                
            }
        }
    }
    
    //add immediate commands
    integer m;
    integer imdtlength = llGetListLength(imdtcmds);
    for (m = 0; m < imdtlength; m = m + 3)
    {
        buttons += [llList2String(imdtcmds, m + 1)];
        prompt += "\n" + llList2String(imdtcmds, m + 1) + " = " + llList2String(imdtcmds, m + 2);
    }
    
    //give an Allow All button
    buttons += [TURNON + " All"];
    buttons += [TURNOFF + " All"];      
    
    buttons += [UPMENU];
    buttons = RestackMenu(FillMenu(buttons));
    menuchannel = llRound(llFrand(9999999.0));    
    listener = llListen(menuchannel, "", id, "");
    llSetTimerEvent(timeout);
    llDialog(id, prompt, buttons, menuchannel);
}

UpdateSettings()
{
    //build one big string from the settings list
    //llOwnerSay("TP settings: " + llDumpList2String(settings, ","));
    integer settingslength = llGetListLength(settings);
    if (settingslength > 0)
    {
        integer n;        
        list newlist;
        for (n = 0; n < settingslength; n = n + 2)
        {
            newlist += [llList2String(settings, n) + "=" + llList2String(settings, n + 1)];
        }
        //output that string to viewer
        llMessageLinked(LINK_THIS, RLV_CMD, llDumpList2String(newlist, ","), NULL_KEY);        
    }
}

SaveSettings()
{
    //save to DB
    llMessageLinked(LINK_THIS, HTTPDB_SAVE, dbtoken + "=" + llDumpList2String(settings, ","), NULL_KEY);    
}

ClearSettings()
{   
    //clear settings list
    settings = [];
    //remove tpsettings from DB
    llMessageLinked(LINK_THIS, HTTPDB_DELETE, dbtoken, NULL_KEY);           
    //main RLV script will take care of sending @clear to viewer
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
        llSleep(1.0);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        //llMessageLinked(LINK_THIS, HTTPDB_REQUEST, dbtoken, NULL_KEY);
    }
    
    link_message(integer sender, integer num, string str, key id)
    {
        if (num == MENUNAME_REQUEST && str == parentmenu)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        else if (num == SUBMENU && str == submenu)
        {
            Menu(id);
        }
        else if ((str == "reset" || str == "runaway") && (num == COMMAND_OWNER || num == COMMAND_WEARER))
        {
            //clear db, reset script
            llMessageLinked(LINK_THIS, HTTPDB_DELETE, dbtoken, NULL_KEY);
            llResetScript();       
        }
        else if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
        {
            //do simple pass through for chat commands
            
            //since more than one RLV command can come on the same line, loop through them
            list items = llParseString2List(str, [","], []);
            integer n;
            integer stop = llGetListLength(items);
            integer change = FALSE;//set this to true if we see a setting that concerns us
            for (n = 0; n < stop; n++)
            {
                //split off the parameters (anything after a : or =)
                //and see if the thing being set concerns us
                string thisitem = llList2String(items, n);
                string behavior = llList2String(llParseString2List(thisitem, ["=", ":"], []), 0);
                if (str == "unsit=force")
                {
                    //this one's just weird
                    //llOwnerSay("forcing stand");
                    if (num == COMMAND_WEARER)
                    {
                        llInstantMessage(llGetOwner(), "Sorry, but RLV commands may only be given by owner, secowner, or group (if set).");                        
                    }
                    else
                    {
                        llMessageLinked(LINK_THIS, RLV_CMD, str, NULL_KEY);
                    }
                    if (returnmenu)
                    {
                        Menu(id);
                    }                    
                }
                else if (llListFindList(rlvcmds, [behavior]) != -1)
                {
                    //this is a behavior that we handle.
                    //filter commands from wearer, if wearer is not owner
                    if (num == COMMAND_WEARER)
                    {
                        llInstantMessage(llGetOwner(), "Sorry, but RLV commands may only be given by owner, secowner, or group (if set).");
                        return;
                    }
                    
                    string option = llList2String(llParseString2List(thisitem, ["="], []), 0);
                    string param = llList2String(llParseString2List(thisitem, ["="], []), 1);
                    integer index = llListFindList(settings, [option]);
                    if (index == -1)
                    {
                        //we don't alread have this exact setting.  add it
                        settings += [option, param];
                    }                
                    else
                    {
                        //we already have a setting for this option.  update it.
                        settings = llListReplaceList(settings, [option, param], index, index + 1);
                    }
                    change = TRUE;
                }
                else if (llListFindList(imdtcmds, [behavior]) != -1)
                {
                    //this is an immediate command that we handle
                    llMessageLinked(LINK_THIS, RLV_CMD, str, NULL_KEY);        
                    if (returnmenu)
                    {
                        Menu(id);
                    }                              
                }
                else if (behavior == "clear")
                {
                    ClearSettings();
                }                
            }
            
            if (change)
            {
                UpdateSettings();
                SaveSettings();
                if (returnmenu)
                {
                    Menu(id);
                }
            }
        }
        else if (num == HTTPDB_RESPONSE)
        {
            //this is tricky since our db value contains equals signs
            //split string on both comma and equals sign            
            //first see if this is the token we care about
            list params = llParseString2List(str, ["="], []);
            integer change = FALSE;
            if (llList2String(params, 0) == dbtoken)
            {
                //throw away first element
                //everything else is real settings (should be even number)
                settings = llParseString2List(llList2String(params, 1), [","], []);
                UpdateSettings();
            }           
        }
        else if (num == RLV_REFRESH)
        {
            //rlvmain just started up.  Tell it about our current restrictions
            UpdateSettings();
        }        
        else if (num == RLV_CLEAR)
        {
            //clear db and local settings list
            ClearSettings();
        }
    }
    
    timer()
    {
        llListenRemove(sitlistener);
        llListenRemove(listener);
        llSetTimerEvent(0.0);
        returnmenu = FALSE;
    }
    
    listen(integer channel, string name, key id, string message)
    {
        if (channel == menuchannel)
        {
            llListenRemove(listener);
            llSetTimerEvent(0.0);            
            //if we got *Back*, then request submenu RLV
            if (message == UPMENU)
            {
                llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);
                returnmenu = FALSE;
            }
            else
            {                
                //if str == an immediate command, send cmd
                //else if str == a stored command, do that
                
                if (message == "SitNow")
                {
                    //give menu of nearby objects that have scripts in them
                    //this assumes that all the objects you may want to force your sub to sit on
                    //have scripts in them
                    menuuser = id;
                    llSensor("", NULL_KEY, SCRIPTED, scanrange, PI);
                }
                else if (message == "StandNow")
                {
                    
                    llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "unsit=force", id);
                    returnmenu = TRUE;
                }
                else
                {
                    //we got a command to enable or disable something, like "Enable LM"            
                    //get the actual command name by looking up the pretty name from the message
                    
                    list params = llParseString2List(message, [" "], []);        
                    string switch = llList2String(params, 0);
                    string cmd = llList2String(params, 1);
                    integer index = llListFindList(prettycmds, [cmd]); 
                    if (cmd == "All")
                    {
                        //handle the "Allow All" and "Forbid All" commands
                        string ONOFF;                 
                        //decide whether we need to switch to "y" or "n"
                        if (switch == TURNOFF)
                        {
                            //enable all functions (ie, remove all restrictions
                            ONOFF = "n";
                        }
                        else if (switch == TURNON)
                        {   
                            ONOFF = "y";                    
                        }
                        
                        //loop through rlvcmds to create list
                        string out;
                        integer n;
                        integer stop = llGetListLength(rlvcmds);                
                        for (n = 0; n < stop; n++)
                        {
                            //prefix all but the first value with a comma, so we have a comma-separated list
                            if (n)
                            {
                                out += ",";
                            }
                            out += llList2String(rlvcmds, n) + "=" + ONOFF;
                        }
                        llMessageLinked(LINK_THIS, COMMAND_NOAUTH, out, id);
                        returnmenu = TRUE;   
                    }                                       
                    else if (index != -1)
                    {
                        string out = llList2String(rlvcmds, index);                
                        out += "=";
                        if (llList2String(params, 0) == TURNON)
                        {
                            out += "y";
                        }
                        else if (llList2String(params, 0) == TURNOFF)
                        {
                            out += "n";
                        }
                        //send rlv command out through auth system as though it were a chat command, just to make sure person who said it has proper authority
                        llMessageLinked(LINK_THIS, COMMAND_NOAUTH, out, id);
                        returnmenu = TRUE;
                    }
                    else
                    {
                        //something went horribly wrong.  We got a command that we can't find in the list
                    }                
                }
            }            
        }
        else if (channel == sitchannel)
        {
            llListenRemove(sitlistener);
            llSetTimerEvent(0.0);              
            //we heard a number for an object to sit on
            integer seatnum = (integer)message - 1;
            returnmenu = TRUE;
            llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "sit:" + llList2String(sitkeys, seatnum) + "=force", id);            
        }
    }
    
    sensor(integer num)
    {
        sitbuttons = [];
        sitprompt = "Pick the object on which you want the sub to sit.  If it's not in the list, have the sub move closer and try again.\n";
        sitkeys = [];
        //give menuuser a list of things to choose from
        //lop the list off at 12 so we don't need multipage menu
        integer n;
        for (n = 0; n < num; n ++)
        {
            //don't add things named "Object"
            string name = llDetectedName(n);
            if (name != "Object")
            {
                sitbuttons += [(string)(n + 1)];
                sitprompt += "\n" + (string)(n + 1) + " - " + name;
                sitkeys += [llDetectedKey(n)];                
            }
        }
        
        //limit buttons and keys to first 12
        if (llGetListLength(sitbuttons) > 12)
        {
            sitbuttons = llList2List(sitbuttons, 0, 11);
            sitkeys = llList2List(sitkeys, 0, 11);
        }
        
        //prompt can only have 512 chars
        while (llStringLength(sitprompt) >= 512)
        {
            //pop the last item off the buttons, keys, and prompt
            sitbuttons = llDeleteSubList(sitbuttons, -1, -1);
            sitkeys = llDeleteSubList(sitkeys, -1, -1);
            sitprompt = llDumpList2String(llDeleteSubList(llParseString2List(sitprompt, ["\n"], []), -1, -1), "\n");
        }
        
        sitbuttons = RestackMenu(FillMenu(sitbuttons));
        sitlistener = llListen(sitchannel, "", menuuser, "");
        llSetTimerEvent(timeout);
        llDialog(menuuser, sitprompt, sitbuttons, sitchannel);
    }
    
    no_sensor()
    {
        //nothing close by to sit on, tell menuuser
        llInstantMessage(menuuser, "Unable to find sit targets.");
    }
}
