//pose

//needs to handle anim requests from sister scripts as well
//this script as essentially two layers
//lower layer: coordinate animation requests that come in on link messages.  keep a list of playing anims disable AO when needed
//upper layer: use the link message anim api to provide a pose menu

list anims;

string currentpose = "";
integer lastrank = 0; //in this integer, save the rank of the person who posed the av, according to message map.  0 means unposed
string parentmenu = "Main";
string submenu = "Pose";
string aomenu = "AO";
string giveao = "Give AO";
string triggerao = "AO Menu";

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
integer HTTPDB_EMPTY = 2004;//sent by httpdb script when a token has no value in the db

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer MENUNAME_REMOVE = 3003;

integer RLV_CMD = 6000;

integer ANIM_START = 7000;
integer ANIM_STOP = 7001;

//5000 block is reserved for IM slaves

string UPMENU = "~PrevMenu~";

integer page = 0;
integer menuchannel = 2348208;
integer aomenuchannel = 2348209;
integer timeout = 30;
integer listener;
integer aochannel = -782690;
string AO_ON = "ZHAO_STANDON";
string AO_OFF = "ZHAO_STANDOFF";
string AO_MENU = "ZHAO_MENU";

debug(string str)
{
    //llOwnerSay(llGetScriptName() + ": " + str);
}

RefreshAnim()
{
    //anims can get lost on TP, so re-play anims[0] here, and call this function in "changed" event on TP
    if (llGetListLength(anims))
    {
        if (llGetPermissions() & PERMISSION_TRIGGER_ANIMATION)
        {
            string anim = llList2String(anims, 0);
            if (llGetInventoryType(anim) == INVENTORY_ANIMATION)
            {
                //get and stop currently playing anim
                if (llGetListLength(anims))
                {
                    string current = llList2String(anims, 0);
                    llStopAnimation(current);
                }
                //add anim to list
                anims = [anim] + anims;//this way, anims[0] is always the currently playing anim
                llStartAnimation(anim);
                llSay(aochannel, AO_OFF);                      
            }
            else
            {
                Popup(llGetOwner(), "Error: Couldn't find anim: " + anim);            
            }                     
        }
        else
        {
            Popup(llGetOwner(), "Error: Somehow I lost permission to animate you.  Try taking me off and re-attaching me.");
        }        
    }
}

StartAnim(string anim)
{
    if (llGetPermissions() & PERMISSION_TRIGGER_ANIMATION)
    {
        if (llGetInventoryType(anim) == INVENTORY_ANIMATION)
        {
            //get and stop currently playing anim
            if (llGetListLength(anims))
            {
                string current = llList2String(anims, 0);
                llStopAnimation(current);
            }
            //add anim to list
            anims = [anim] + anims;//this way, anims[0] is always the currently playing anim
            llStartAnimation(anim);
            llSay(aochannel, AO_OFF);                      
        }
        else
        {
            Popup(llGetOwner(), "Error: Couldn't find anim: " + anim);            
        }                    
    }
    else
    {
        Popup(llGetOwner(), "Error: Somehow I lost permission to animate you.  Try taking me off and re-attaching me.");
    }
}

StopAnim(string anim)
{
    if (llGetPermissions() & PERMISSION_TRIGGER_ANIMATION)
    {
        if (llGetInventoryType(anim) == INVENTORY_ANIMATION)
        {
            //remove all instances of anim from anims
            //loop from top to avoid skipping
            integer n;
            for (n = llGetListLength(anims) - 1; n >= 0; n--)
            {
                if (llList2String(anims, n) == anim)
                {
                    anims = llDeleteSubList(anims, n, n);
                }
            }
            llStopAnimation(anim);    
            
            //play the new anims[0]
            //if anim list is empty, turn AO back on
            if (llGetListLength(anims))
            {
                llStartAnimation(llList2String(anims, 0));                
            }
            else
            {
                llSay(aochannel, AO_ON);
            }
        }
        else
        {
            Popup(llGetOwner(), "Error: Couldn't find anim: " + anim);            
        }        
    }
    else
    {
        Popup(llGetOwner(), "Error: Somehow I lost permission to animate you.  Try taking me off and re-attaching me.");
    }
}

Popup(key id, string message)
{
    //one-way popup message.  don't listen for these anywhere
    llDialog(id, message, [], 298479);
}

AOMenu(key id)
{
    string prompt = "Choose an option.";
    prompt += "  (This menu will expire in " + (string)timeout + " seconds.)\n";
    list buttons = [triggerao, giveao, UPMENU];
    llSetTimerEvent(timeout);
    aomenuchannel = llRound(llFrand(999999)) + 1;
    listener = llListen(aomenuchannel, "", id, "");
    llDialog(id, prompt, buttons, aomenuchannel);    
}

AnimMenu(key id)
{
    //create a list
    list buttons = ["*Release*"];
    string prompt = "Choose an anim to play.  (This menu will expire in " + (string)timeout + " seconds.)\n";
    //build a button list with the dances, and "More"
    //get number of anims
    integer num_anims = llGetInventoryNumber(INVENTORY_ANIMATION);
    integer n;
    if (num_anims <= 10)
    {
        //if 12 or less, just put them all in the list
        for (n=0;n<num_anims;n++)
        {
            string name = llGetInventoryName(INVENTORY_ANIMATION,n);
            if (name != "")
            {
                prompt += "\n" + (string)(n + 1) + " - " + name;
                buttons += [(string)(n + 1)];
            }
        }  
    }
    else
    {
        //there are more than 12 dances, use page number in adding buttons
        integer pagesize = 9;
        for (n=0;n<pagesize;n++)
        {
            //check for anim existence, add to list if it exists
            string name = llGetInventoryName(INVENTORY_ANIMATION, n + (page * pagesize));
            if (name != "")
            {
                prompt += "\n" + (string)(n + (page * pagesize) + 1) + " - " + name;
                buttons += [(string)(n + (page * pagesize) + 1)];                
            }
        }
        //add the More button
        buttons = buttons + ["*More*"];
    }
    buttons += [UPMENU];
    buttons = RestackMenu(FillMenu(buttons));    
    menuchannel = llRound(llFrand(999999)) + 1;
    listener = llListen(menuchannel, "", id, "");
    llDialog(id, prompt, buttons, menuchannel);
    //the menu needs to time out
    llSetTimerEvent((float)timeout);
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

DeliverAO(key id)
{
    string name = "OpenCollar Sub AO";
    string version = "0.0";
    
    string url = "http://collardata.appspot.com/updater/check?";
    url += "object=" + llEscapeURL(name);
    url += "&version=" + llEscapeURL(version);
    llHTTPRequest(url, [HTTP_METHOD, "GET",HTTP_MIMETYPE,"text/plain;charset=utf-8"], "");     
    llInstantMessage(id, "Queuing delivery of " + name + ".  It should be delivered in about 30 seconds.");
}

default
{
    state_entry()
    {
        llRequestPermissions(llGetOwner(), PERMISSION_TRIGGER_ANIMATION);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);             
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + aomenu, NULL_KEY);         
    }
    
    changed(integer change)
    {
        if (change & CHANGED_OWNER)
        {
            llResetScript();
        }
        else if (change & CHANGED_TELEPORT)
        {
            RefreshAnim();
        }
    }
    
    attach(key id)
    {
        if (id == NULL_KEY)
        {
            debug("detached");
            //we were just detached.  clear the anim list and tell the ao to play stands again.
            llSay(aochannel, AO_ON);
            anims = [];
        }
    }
    
    link_message(integer sender, integer auth, string str, key id)
    {
        //ignore "hug" and "kiss"
        if (str == "hug" || str == "kiss")
        {
            return;
        }
        
        //only respond to owner, secowner, group, wearer
        if (auth >= COMMAND_OWNER && auth <= COMMAND_WEARER)
        {
            if (str == "release")
            {
                //only release if person giving command outranks person who posed us
                if (auth <= lastrank)
                {
                    lastrank = auth;
                    //StopAnim(currentpose);
                    llMessageLinked(LINK_THIS, ANIM_STOP, currentpose, NULL_KEY);                    
                    currentpose = "";
                }  
            }            
            else if (str == "settings")
            {
                if (currentpose != "")
                {
                    llInstantMessage(id, "Current Pose: " + currentpose);
                }
            }
            else if ((str == "runaway" || str == "reset") && (auth == COMMAND_OWNER || auth == COMMAND_WEARER))            
            {
                //stop pose
                if (currentpose != "")
                {
                    StopAnim(currentpose);
                }
                //reset script
                llResetScript();
            }
            else if (str == "pose")
            {
                //do multi page menu listing anims
                AnimMenu(id);
            }
            else if (str == "triggerao")
            {
                llSay(aochannel, AO_MENU + "|" + (string)id);
                llInstantMessage(id, "Attempting to trigger the AO menu.  This will only work if " + llKey2Name(llGetOwner()) + " is wearing the OpenCollar Sub AO.");
            }
            else if (llGetInventoryType(str) == INVENTORY_ANIMATION)
            {
                if (currentpose == "")
                {
                    currentpose = str;
                    //not currently in a pose.  play one
                    lastrank = auth;
                    //StartAnim(str);                
                    llMessageLinked(LINK_THIS, ANIM_START, currentpose, NULL_KEY);
                }            
                else
                {
                    //only change if command rank is same or higher (lower integer) than that of person who posed us
                    if (auth <= lastrank)
                    {
                        lastrank = auth;
                        llMessageLinked(LINK_THIS, ANIM_STOP, currentpose, NULL_KEY);
                        currentpose = str;                        
                        llMessageLinked(LINK_THIS, ANIM_START, currentpose, NULL_KEY);
                    }
                }
            }            
        }
        else if (auth == ANIM_START)
        {
            StartAnim(str);
        }
        else if (auth == ANIM_STOP)
        {
            StopAnim(str);            
        }
        else if (auth == MENUNAME_REQUEST)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + aomenu, NULL_KEY);            
        }
        else if (auth == SUBMENU && str == submenu)
        {
            //we don't know the authority of the menu requester, so send a message through the auth system
            llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "pose", id);
        }        
        else if (auth == SUBMENU && str == aomenu)
        {
            //give menu
            AOMenu(id);
        }
    }
    
    listen(integer channel, string name, key id, string message)
    {
        llSetTimerEvent(0);
        llListenRemove(listener);        
        if (channel == menuchannel)
        {
            if (message == "*More*")
            {
                //increment page number
                if (llGetInventoryNumber(INVENTORY_ANIMATION) > (10 * (page + 1)))
                {
                    //there are more pages
                    page++;
                }
                else
                {
                    page = 0;
                }                    
            }
            else if (message == "*Release*")
            {
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "release", id);            
            }
            else if ((integer)message)
            {
                //we don't know any more what the speaker's auth is, so pass the command back through the auth system.  then it will play only if authed
                string animname = llGetInventoryName(INVENTORY_ANIMATION, (integer)message - 1);
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, animname, id);
            }
            else if (message == UPMENU)
            {
                llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);
                //return on parent menu, so the animmenu below doesn't come up
                return;
            }
            AnimMenu(id);             
        }         
        else if (channel == aomenuchannel)
        {
            if (message == triggerao)
            {
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "triggerao", id);                
            }
            else if (message == giveao)
            {
                //queue a delivery
                DeliverAO(id);
                AOMenu(id);
            }
            else if (message == UPMENU)
            {
                llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);                
            }
        }
    }
    
    timer()
    {
        llSetTimerEvent(0);
        llListenRemove(listener);
    }
}