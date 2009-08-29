//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//on start, send request for submenu names
//on getting submenu name, add to list if not already present
//on menu request, give dialog, with alphabetized list of submenus
//on listen, send submenu link message

list menunames = ["Main", "Help/Debug", "AddOns"];
list menulists;//exists in parallel to menunames, each entry containing a pipe-delimited string with the items for the corresponding menu
list menuprompts = [
"Pick an option.\n",
"Click 'Guide' to receive a help notecard,\nClick 'ResetScripts' to reset the OpenCollar scripts without losing your settings.\nClick any other button for a quick popup help about the chosen topic.\n",
"Please choose your AddOn:\n"
];


integer listenchannel = 1908789;
integer listener;
integer timeout = 60;

integer scriptcount;//when the scriptcount changes, rebuild menus

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

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer MENUNAME_REMOVE = 3003;

//5000 block is reserved for IM slaves

//string UPMENU = "↑";
//string MORE = "→";
string UPMENU = "^";
string MORE = ">";
string GIVECARD = "Guide";
string HELPCARD = "OpenCollar Guide";
string REFRESH_MENU = "Fix Menus";
string RESET_MENU = "ResetScripts";

debug(string text)
{
    //llOwnerSay(llGetScriptName() + ": " + text);
}

Menu(string name, key id)
{
    integer menuindex = llListFindList(menunames, [name]);
    debug((string)menuindex);    
    if (menuindex != -1)
    {
        //this should be multipage in case there are more than 12 submenus, but for now single page
        //get submenu
        list items = llParseString2List(llList2String(menulists, menuindex), ["|"], []);
        //start a listener
        llListenRemove(listener);
        listener = llListen(listenchannel, "", id, "");
        //start a timeout
        llSetTimerEvent((float)timeout);
        //give dialog
        string prompt = llList2String(menuprompts, menuindex);
        prompt += "  (Menu will time out in " + (string)timeout + " seconds.)\n";    
        llDialog(id, prompt, RestackMenu(items), listenchannel);        
    }
}

list RestackMenu(list in)
{ //adds empty buttons until the list length is multiple of 3, to max of 12
    while (llGetListLength(in) % 3 != 0 && llGetListLength(in) < 12)
    {
        in += [" "];
    }
    //look for ^ and > in the menu
    integer m = llListFindList(in, [MORE]);
    if (m != -1)
    {
        in = llDeleteSubList(in, m, m);
    }
    integer u = llListFindList(in, [UPMENU]);
    if (u != -1)
    {
        in = llDeleteSubList(in, u, u);
    }
    //re-orders a list so dialog buttons start in the top row
    list out = llList2List(in, 9, 11);
    out += llList2List(in, 6, 8);
    out += llList2List(in, 3, 5);    
    out += llList2List(in, 0, 2);
    //make sure we move ^ and > to position 1 and 2
    if (u != -1)
    {
        out = llListInsertList(out, [UPMENU], 1);
    }
    if (m != -1)
    {
        out = llListInsertList(out, [MORE], 2);
    }
    return out;
}

integer KeyIsAv(key id)
{
    return llGetAgentSize(id) != ZERO_VECTOR;
}

MenuInit()
{
    menulists = ["","",""];
    integer n;
    integer stop = llGetListLength(menunames);
    for (n = 0; n < stop; n++)
    {
        string name = llList2String(menunames, n);
        if (name != "Main")
        {
            //make each submenu appear in Main
            HandleMenuResponse("Main|" + name);
            
            //request children of each submenu
            llMessageLinked(LINK_THIS, MENUNAME_REQUEST, name, NULL_KEY);            
            
            //give each submenu a Prev button
            HandleMenuResponse(name + "|" + UPMENU);
        }
    }
    //give the help menu GIVECARD and REFRESH_MENU buttons    
    HandleMenuResponse("Help/Debug|" + GIVECARD);
    HandleMenuResponse("Help/Debug|" + REFRESH_MENU);
    HandleMenuResponse("Help/Debug|" + RESET_MENU);       
    
    llMessageLinked(LINK_SET, MENUNAME_REQUEST, "Main", ""); 
}

HandleMenuResponse(string entry)
{
    list params = llParseString2List(entry, ["|"], []);
    string name = llList2String(params, 0);
    integer menuindex = llListFindList(menunames, [name]);
    if (menuindex != -1)
    {             
        debug("we handle " + name);
        string submenu = llList2String(params, 1);
        //only add submenu if not already present
        debug("adding button " + submenu);
        list guts = llParseString2List(llList2String(menulists, menuindex), ["|"], []);
        debug("existing buttons for " + name + " are " + llDumpList2String(guts, ","));
        if (llListFindList(guts, [submenu]) == -1)
        {
            guts += [submenu];
            guts = llListSort(guts, 1, TRUE);
            menulists = llListReplaceList(menulists, [llDumpList2String(guts, "|")], menuindex, menuindex);
        }
    }    
    else
    {
        debug("we don't handle " + name);
    }
}

default
{
    state_entry()
    {
        listenchannel = -1 - llFloor(llFrand(9999999.0)); //randomizing listening channel
        llSleep(1.0);//delay sending this message until we're fairly sure that other scripts have reset too, just in case
        scriptcount = llGetInventoryNumber(INVENTORY_SCRIPT);
        MenuInit();      
    }
    
    touch_start(integer num)
    {
        llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "menu", llDetectedKey(0));
    }
    
    link_message(integer sender, integer num, string str, key id)
    {
        if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
        {
            list params = llParseString2List(str, [" "], []);
            string cmd = llList2String(params, 0);
            if (str == "menu")
            {
                Menu("Main", id);
            }
            else if (str == "help")
            {
                llGiveInventory(id, HELPCARD);                
            }
            if (str == "addons")
            {
                Menu("AddOns", id);
            }
            if (str == "debug")
            {
               Menu("Help/Debug", id);
            }
            else if (cmd == "menuto")
            {
                key av = (key)llList2String(params, 1);
                if (KeyIsAv(av))
                {
                    Menu("Main", av);
                }
            }
            else if (cmd == "refreshmenu")
            {
                llDialog(id, "Rebuilding menu.  This may take several seconds.", [], -341321);
                //MenuInit();
                llResetScript();
            }
        }
        else if (num == MENUNAME_RESPONSE)
        {
            //str will be in form of "parent|menuname"
            //ignore unless parent is in our list of menu names
            HandleMenuResponse(str);
        }
        else if (num == MENUNAME_REMOVE)
        {
            //str should be in form of parentmenu|childmenu
            list params = llParseString2List(str, ["|"], []);
            string parent = llList2String(params, 0);
            string child = llList2String(params, 1);
            integer menuindex = llListFindList(menunames, [parent]);
            if (menuindex != -1)
            {
                list guts = llParseString2List(llList2String(menulists, menuindex), ["|"], []);
                integer gutindex = llListFindList(guts, [child]);
                //only remove if it's there
                if (gutindex != -1)        
                {
                    guts = llDeleteSubList(guts, gutindex, gutindex);
                    menulists = llListReplaceList(menulists, [llDumpList2String(guts, "|")], menuindex, menuindex);                    
                }        
            }
        }
        else if (num == SUBMENU)
        {
            if (llListFindList(menunames, [str]) != -1)
            {
                Menu(str, id);
            }
        }
    }
    
    listen(integer channel, string name, key id, string message)
    {
        //kill listener
        llListenRemove(listener);
        if (message == UPMENU)
        {
            Menu("Main", id);
        }
        else
        {
            if (message == GIVECARD)
            {
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "help", id);
                Menu("Help/Debug", id);
            }
            else if (message == REFRESH_MENU)
            {//send a command telling other plugins to rebuild their menus
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "refreshmenu", id);
            }
            else if (message == RESET_MENU)
            {//send a command to reset scripts
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "resetscripts", id);
            }
            else
            {
                llMessageLinked(LINK_SET, SUBMENU, message, id);
            }
        }
    }
    
    timer()
    {
        llListenRemove(listener);
        llSetTimerEvent(0);
    }

    on_rez(integer param)
    {
        llResetScript();
    }
    
    changed(integer change)
    {
        if (change & CHANGED_INVENTORY)
        {
            if (llGetInventoryNumber(INVENTORY_SCRIPT) != scriptcount)
            {//a script has been added or removed.  Reset to rebuild menu
                llResetScript();
            }
        }
    }
}
