//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.

//needs to handle anim requests from sister scripts as well
//this script as essentially two layers
//lower layer: coordinate animation requests that come in on link messages.  keep a list of playing anims disable AO when needed
//upper layer: use the link message anim api to provide a pose menu

//2009-03-22, Lulu Pink, animlock - issue 367

list anims;
integer num_anims;//the number of anims that don't start with "~"
integer pagesize = 8;//number of anims we can fit on one page of a multi-page menu
list PoseList;

//for the height scaling feature
key dataid;
string card = "~heightscalars";
integer line = 0;
list anim_scalars;//a 3-strided list in form animname,scalar,delay
integer adjustment = 0;

string currentpose = "";
integer lastrank = 0; //in this integer, save the rank of the person who posed the av, according to message map.  0 means unposed
string rootmenu = "Main";
string animmenu = "Animations";
string posemenu = "Pose";
string aomenu = "AO";
list animbuttons = ["AO", "Pose", "( )AnimLock"];
string giveao = "Give AO";
string triggerao = "AO Menu";
//added for animlock
string TICKED = "(*)";
string UNTICKED = "( )";
string ANIMLOCK = "AnimLock";
integer animLock = FALSE;
string locktoken = "animlock";

string animtoken = "currentpose";
//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_COLLAR = 499; //added for collar or cuff commands to put ao to pause or standOff
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
integer CHAT = 505;
integer COMMAND_SAFEWORD = 510;  // new for safeword

//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bt of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
                            //str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent by httpdb script when a token has no value in the db

integer LOCALSETTING_SAVE = 2500;
integer LOCALSETTING_REQUEST = 2501;
integer LOCALSETTING_RESPONSE = 2502;
integer LOCALSETTING_DELETE = 2503;
integer LOCALSETTING_EMPTY = 2504;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer MENUNAME_REMOVE = 3003;

integer RLV_CMD = 6000;

integer ANIM_START = 7000;
integer ANIM_STOP = 7001;

//5000 block is reserved for IM slaves

//string UPMENU = "?";
//string MORE = "?";
string UPMENU = "^";
string MORE = ">";
string PREV = "<";

integer page = 0;
integer animmenuchannel = 2348207;
integer posemenuchannel = 2348208;
integer aomenuchannel = 2348209;
integer timeout = 60;
integer listener;
integer aochannel = -782690;
integer interfaceChannel = -12587429;
string AO_ON = "ZHAO_STANDON";
string AO_OFF = "ZHAO_STANDOFF";
string AO_MENU = "ZHAO_MENU";

key wearer;

Notify(key id, string msg, integer alsoNotifyWearer) 
{
    if (id == wearer) 
    {
        llOwnerSay(msg);
    } else {
        llInstantMessage(id,msg);
        if (alsoNotifyWearer) 
        {
            llOwnerSay(msg);
        }
    }    
}

debug(string str)
{
    //llOwnerSay(llGetScriptName() + ": " + str);
}

AnimMenu(key id)
{
    string prompt = "Choose an option.\n";
    if(animLock)
    {
        prompt += TICKED + ANIMLOCK + " is an Owner only option.\n";
        prompt += "Owner issued animations/poses are locked and only the Owner can release the sub now.";
    }
    else
    {
        prompt += UNTICKED + ANIMLOCK + " is an Owner only option.\n";
        prompt += "The sub is free to self-release or change poses as well as any secowner.";
    }
    prompt += "  (This menu will expire in " + (string)timeout + " seconds.)\n";
    list buttons = llListSort(animbuttons, 1, TRUE);
    buttons += [UPMENU];
    llSetTimerEvent(timeout);
    animmenuchannel = - llRound(llFrand(999999)) - 9999;
    llListenRemove(listener);
    listener = llListen(animmenuchannel, "", id, "");
    buttons = RestackMenu(buttons);
    llDialog(id, prompt, buttons, animmenuchannel);     
}

RefreshAnim()
{ //anims can get lost on TP, so re-play anims[0] here, and call this function in "changed" event on TP
    if (llGetListLength(anims))
    {
        if (llGetPermissions() & PERMISSION_TRIGGER_ANIMATION)
        {
            string anim = llList2String(anims, 0);
            if (llGetInventoryType(anim) == INVENTORY_ANIMATION)
            { //get and stop currently playing anim
                StartAnim(anim);
                /*
                if (llGetListLength(anims))
                {
                    string current = llList2String(anims, 0);
                    llStopAnimation(current);
                }
                //add anim to list
                anims = [anim] + anims;//this way, anims[0] is always the currently playing anim
                llStartAnimation(anim);
                llSay(interfaceChannel, AO_OFF); 
                */                    
            }
            else
            {
                //Popup(wearer, "Error: Couldn't find anim: " + anim);            
            }                     
        }
        else
        {
            Popup(wearer, "Error: Somehow I lost permission to animate you.  Try taking me off and re-attaching me.");
        }        
    }
}

StartAnim(string anim)
{
    if (llGetPermissions() & PERMISSION_TRIGGER_ANIMATION)
    {
        if (llGetInventoryType(anim) == INVENTORY_ANIMATION)
        {   //get and stop currently playing anim
            if (llGetListLength(anims))
            {
                string current = llList2String(anims, 0);
                llStopAnimation(current);
            }
            
            //stop any currently playing height adjustment
            if (adjustment)
            {
                llStopAnimation("~" + (string)adjustment);
                adjustment = 0;
            }
            
            //add anim to list
            anims = [anim] + anims;//this way, anims[0] is always the currently playing anim
            llStartAnimation(anim);
            llWhisper(interfaceChannel, "CollarComand|499|" + AO_OFF);
            llWhisper(aochannel, AO_OFF);      
            
            //adjust height for anims in anim_scalars
            integer index = llListFindList(anim_scalars, [anim]);
            if (index != -1)
            {//we just started playing an anim in our adjustment list
                //pause to give certain anims time to ease in
                llSleep((float)llList2String(anim_scalars, index + 2));
                vector avscale = llGetAgentSize(wearer);
                float scalar = (float)llList2String(anim_scalars, index + 1);
                adjustment = llRound(avscale.z * scalar);
                if (adjustment > -30)
                {
                    adjustment = -30;
                }
                else if (adjustment < -50)
                {
                    adjustment = -50;
                }
                llStartAnimation("~" + (string)adjustment);
            }
        }
        else
        {
            //Popup(wearer, "Error: Couldn't find anim: " + anim);            
        }                    
    }
    else
    {
        Popup(wearer, "Error: Somehow I lost permission to animate you.  Try taking me off and re-attaching me.");
    }
}

StopAnim(string anim)
{
    if (llGetPermissions() & PERMISSION_TRIGGER_ANIMATION)
    {
        if (llGetInventoryType(anim) == INVENTORY_ANIMATION)
        {   //remove all instances of anim from anims
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
            
            //stop any currently-playing height adjustment
            if (adjustment)
            {
                llStopAnimation("~" + (string)adjustment);
                adjustment = 0;
            }                
            //play the new anims[0]
            //if anim list is empty, turn AO back on
            if (llGetListLength(anims))
            {
                string newanim = llList2String(anims, 0);
                llStartAnimation(newanim);
                
                //adjust height for anims in anim_scalars
                integer index = llListFindList(anim_scalars, [newanim]);
                if (index != -1)
                {//we just started playing an anim in our adjustment list
                    //pause to give certain anims time to ease in
                    llSleep((float)llList2String(anim_scalars, index + 2));
                    vector avscale = llGetAgentSize(wearer);
                    float scalar = (float)llList2String(anim_scalars, index + 1);
                    adjustment = llRound(avscale.z * scalar);
                    if (adjustment > -30)
                    {
                        adjustment = -30;
                    }
                    else if (adjustment < -50)
                    {
                        adjustment = -50;
                    }
                    llStartAnimation("~" + (string)adjustment);
                }                
            }
            else
            {
                llWhisper(interfaceChannel, "CollarComand|499|" + AO_ON);
                llWhisper(aochannel, AO_ON);
            }
        }
        else
        {
            //Popup(wearer, "Error: Couldn't find anim: " + anim);            
        }        
    }
    else
    {
        Popup(wearer, "Error: Somehow I lost permission to animate you.  Try taking me off and re-attaching me.");
    }
}

Popup(key id, string message)
{ //one-way popup message.  don't listen for these anywhere
    llDialog(id, message, [], 298479);
}

AOMenu(key id)
{
    string prompt = "Choose an option.";
    prompt += "ATTENTION!!!!!!\nYou need the OpenCollar sub AO 2.6 or higer to work with this collar menu!";
    prompt += "  (This menu will expire in " + (string)timeout + " seconds.)\n";
    list buttons = [triggerao, giveao, UPMENU];
    buttons += ["AO ON", "AO OFF"];
    llSetTimerEvent(timeout);
    aomenuchannel = - llRound(llFrand(999999)) - 9999;
    llListenRemove(listener);
    listener = llListen(aomenuchannel, "", id, "");
    llDialog(id, prompt, buttons, aomenuchannel);    
}

PoseMenu(key id)
{ //create a list
    list buttons = ["*Release*"];
    string prompt = "Choose an anim to play.  (This menu will expire in " + (string)timeout + " seconds.)\n";
    //build a button list with the dances, and "More"
    //get number of anims
    integer n;
    if (num_anims <= pagesize + 1)
    {  //if pagesize + 1 or less, just put them all in the list
        for (n=0;n<num_anims;n++)
        {   /*
            string name = llList2String(PoseList,n);
            //do this check when creating the list no more need here at all!
            //if (name != "" && llGetSubString(name, 0, 0) != "~")
            //{
                 //prompt += "\n" + (string)(n + 1) + " - " + name;
                //buttons += [(string)(n + 1)];
            buttons += [name];
            //}
            */
            //actually why not saving one var and:
            buttons += llList2List(PoseList, n, n);
        }  
    }
    else
    {  //there are more than 12 poses, use page number in adding buttons
        for (n=0;n<pagesize;n++)
        {   //check for anim existence, add to list if it exists
        /*
            string name = llList2String(PoseList, n + (page * pagesize));
            //do this check when creating the list no more need here at all!
            //if (name != "" && llGetSubString(name, 0, 0) != "~")
            //{
                    //prompt += "\n" + (string)(n + (page * pagesize) + 1) + " - " + name;
                    //buttons += [(string)(n + (page * pagesize) + 1)];                
            buttons += [name];
            //}
            */
            //actually why not saving one var and:
            buttons += llList2List(PoseList, n + (page * pagesize), n + (page * pagesize));
        }
        //add the More button
        buttons = buttons + [PREV] + [MORE];
    }
    buttons += [UPMENU];
    buttons = RestackMenu(buttons);    
    posemenuchannel = - llRound(llFrand(999999)) - 9999;
    llListenRemove(listener);
    listener = llListen(posemenuchannel, "", id, "");
    llDialog(id, prompt, buttons, posemenuchannel);
    //the menu needs to time out
    llSetTimerEvent((float)timeout);
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
    integer p = llListFindList(in, [PREV]);
    if (p != -1)
    {
        in = llDeleteSubList(in, p, p);
    } 
    //re-orders a list so dialog buttons start in the top row
    list out = llList2List(in, 9, 11);
    out += llList2List(in, 6, 8);
    out += llList2List(in, 3, 5);    
    out += llList2List(in, 0, 2);
    //make sure we move ^ and > to position 1 and 2
    if (p != -1)
    {
        out = llListInsertList(out, [PREV], 0);
    }
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

DeliverAO(key id)
{
    string name = "OpenCollar Sub AO";
    string version = "0.0";
    
    string url = "http://collardata.appspot.com/updater/check?";
    url += "object=" + llEscapeURL(name);
    url += "&version=" + llEscapeURL(version);
    llHTTPRequest(url, [HTTP_METHOD, "GET",HTTP_MIMETYPE,"text/plain;charset=utf-8"], "");     
    Notify(id, "Queuing delivery of " + name + ".  It should be delivered in about 30 seconds.", FALSE);
}

integer startswith(string haystack, string needle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(haystack, llStringLength(needle), -1) == needle;
}

RequestPerms()
{
    if (llGetAttached())
    {
        llRequestPermissions(wearer, PERMISSION_TRIGGER_ANIMATION);
    }
}


CreateAnimList()
{
    PoseList=[];
    integer max = llGetInventoryNumber(INVENTORY_ANIMATION);
    //eehhh why writing this here?
    //num_anims;
    integer i;
    string name;
    for (i=0;i<max;i++)
    {
        name=llGetInventoryName(INVENTORY_ANIMATION, i);
        if (llStringLength(name) > 24)
        {
            Notify (wearer,"The collar contains the animation '"+name+"'. That name is longer than 24 characters and will not be displayed in the menu. Please remove or change the name.",FALSE);
        }
        //check here if the anim start with ~ or for some reason does not get a name returned (spares to check that all again in the menu ;) 
        else if (name != "" && llGetSubString(name, 0, 0) != "~")
        {    
            PoseList+=[name];
        }
    }
    num_anims=llGetListLength(PoseList);
}
    

default
{
    on_rez(integer num)
    {
        llResetScript();
    }
    state_entry()
    {
        wearer = llGetOwner();
        interfaceChannel = (integer)("0x" + llGetSubString(wearer,30,-1));
        if (interfaceChannel > 0) interfaceChannel = -interfaceChannel;
        RequestPerms();
        
        CreateAnimList();
        
        llMessageLinked(LINK_THIS, MENUNAME_REQUEST, animmenu, NULL_KEY);
        /*
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, rootmenu + "|" + animmenu, NULL_KEY);
        */
        //start reading the ~heightscalars notecard
        dataid = llGetNotecardLine(card, line);
    }
    
    dataserver(key id, string data)
    {
        if (id == dataid)
        {
            if (data != EOF)
            {
                anim_scalars += llParseString2List(data, ["|"], []);
                line++;
                dataid = llGetNotecardLine(card, line);
            }
        }
    }
    
    changed(integer change)
    {
        /* // no more self - resets
        if (change & CHANGED_OWNER)
        {
            llResetScript();
        }
        */
        if (change & CHANGED_TELEPORT)
        {
            RefreshAnim();
        }
        
        if (change & CHANGED_INVENTORY)
        {
            CreateAnimList();
            anim_scalars = [];
            //start re-reading the ~heightscalars notecard
            line = 0;
            dataid = llGetNotecardLine(card, line);
        }
    }
    
    attach(key id)
    {
        if (id == NULL_KEY)
        {
            debug("detached");
            //we were just detached.  clear the anim list and tell the ao to play stands again.
            llWhisper(interfaceChannel, "499|" + AO_ON);
            llWhisper(aochannel, AO_ON);
            anims = [];
        }
    }
    
    link_message(integer sender, integer auth, string str, key id)
    {  //only respond to owner, secowner, group, wearer
        if (auth >= COMMAND_OWNER && auth <= COMMAND_WEARER)
        {
            list params = llParseString2List(str, [" "], []);
            string command = llToLower(llList2String(params, 0));
            string value = llToLower(llList2String(params, 1));
            if (str == "release")
            { //only release if person giving command outranks person who posed us
                if ((auth <= lastrank) || !animLock)
                {
                    lastrank = auth;
                    llMessageLinked(LINK_THIS, ANIM_STOP, currentpose, NULL_KEY);                    
                    currentpose = "";
                    llMessageLinked(LINK_SET, LOCALSETTING_DELETE, animtoken, "");
                }  
            }            
            else if (str == "animations")
            {   //give menu
                AnimMenu(id);
            }        
            else if (str == "settings")
            {
                if (currentpose != "")
                {
                    Notify(id, "Current Pose: " + currentpose, FALSE);
                }
            }
            else if ((str == "runaway" || str == "reset") && (auth == COMMAND_OWNER || auth == COMMAND_WEARER))            
            {   //stop pose
                if (currentpose != "")
                {
                    StopAnim(currentpose);
                }
                llMessageLinked(LINK_SET, LOCALSETTING_DELETE, animtoken, "");
                llResetScript();
            }
            else if (str == "pose")
            {  //do multi page menu listing anims
                PoseMenu(id);
            }
            //added for anim lock
            else if((llGetSubString(str, llStringLength(TICKED), -1) == ANIMLOCK) && (auth == COMMAND_OWNER))
            {
                integer index = llListFindList(animbuttons, [str]);
                if(llGetSubString(str, 0, llStringLength(TICKED) - 1) == TICKED)
                {
                    animLock = FALSE;
                    llMessageLinked(LINK_THIS, HTTPDB_DELETE, locktoken, NULL_KEY);
                    animbuttons = llListReplaceList(animbuttons, [UNTICKED + ANIMLOCK], index, index);
                    Notify(wearer, "You are now able to self-release animations/poses set by onwers or secowner.", FALSE);
                    if(id != wearer)
                    {
                        Notify(id, llKey2Name(wearer) + " is able to self-release animations/poses set by onwers or secowner.", FALSE);
                    }
                }
                else
                {
                    animLock = TRUE;
                    llMessageLinked(LINK_THIS, HTTPDB_SAVE, locktoken + "=1", NULL_KEY);
                    animbuttons = llListReplaceList(animbuttons, [TICKED + ANIMLOCK], index, index);
                    Notify(wearer, "You are now locked into animations/poses set by onwers or secowner.", FALSE);
                    if(id != wearer)
                    {
                        Notify(id, llKey2Name(wearer) + " is now locked into animations/poses set by onwers or secowner.", FALSE);
                    }
                }
                AnimMenu(id);
            }
            else if((command == llToLower(ANIMLOCK)) && (auth == COMMAND_OWNER))
            {
                if(value == "on" && !animLock)
                {
                    integer index = llListFindList(animbuttons, [UNTICKED + ANIMLOCK]);
                    animLock = TRUE;
                    llMessageLinked(LINK_THIS, HTTPDB_SAVE, locktoken + "=1", NULL_KEY);
                    animbuttons = llListReplaceList(animbuttons, [TICKED + ANIMLOCK], index, index);
                    Notify(wearer, "You are now locked into animations your owner or secowner issues.", FALSE);
                    if(id != wearer)
                    {
                        Notify(id, llKey2Name(wearer) + " is now locked in animations/poses set by onwers or secowner and cannot self-release.", FALSE);
                    }
                }
                else if(value == "off" && animLock)
                {
                    integer index = llListFindList(animbuttons, [TICKED + ANIMLOCK]);
                    animLock = FALSE;
                    llMessageLinked(LINK_THIS, HTTPDB_DELETE, locktoken, NULL_KEY);
                    animbuttons = llListReplaceList(animbuttons, [UNTICKED + ANIMLOCK], index, index);
                    Notify(wearer,"You are able to release all animations by yourself.", FALSE);
                    if(id != wearer)
                    {
                        Notify(id, llKey2Name(wearer) + " is able to self-release animations/poses set by onwers or secowner.", FALSE);
                    }
                }
            }
            else if(command == "ao")
            {
                if(value == "")
                {
                    AOMenu(id);
                }
                else if(value == "off")
                {
                    llWhisper(interfaceChannel, "CollarCommand|" + (string)auth + "|ZHAO_AOOFF" + "|" + (string)id);
                    llWhisper(aochannel,"ZHAO_AOOFF");
                }
                else if(value == "on")
                {
                    llWhisper(interfaceChannel, "CollarCommand|" + (string)auth + "|ZHAO_AOON" + "|" + (string)id);
                    llWhisper(aochannel,"ZHAO_AOON");
                }
                else if(value == "menu")
                {
                    llWhisper(interfaceChannel, "CollarCommand|" + (string)auth + "|" + AO_MENU + "|" + (string)id);
                    llWhisper(aochannel, AO_MENU + "|" + (string)id);
                }
                else if (value == "lock")
                {
                    llWhisper(interfaceChannel, "CollarCommand|" + (string)auth + "|ZHAO_LOCK"  + "|" + (string)id);
                }
                else if (value == "unlock")
                {
                    llWhisper(interfaceChannel, "CollarCommand|" + (string)auth + "|ZHAO_UNLOCK"  + "|" + (string)id);
                }
                else if(value == "hide")
                {
                    llWhisper(interfaceChannel, "CollarCommand|" + (string)auth + "|ZHAO_AOHIDE" + "|" + (string)id);
                }
                else if(value == "show")
                {
                    llWhisper(interfaceChannel, "CollarCommand|" + (string)auth + "|ZHAO_AOSHOW" + "|" + (string)id);
                }
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
                    llMessageLinked(LINK_THIS, LOCALSETTING_SAVE, animtoken + "=" + currentpose, "");
                }            
                else
                {  //only change if command rank is same or higher (lower integer) than that of person who posed us
                    if ((auth <= lastrank) || !animLock)
                    {
                        lastrank = auth;
                        llMessageLinked(LINK_THIS, ANIM_STOP, currentpose, NULL_KEY);
                        currentpose = str;                        
                        llMessageLinked(LINK_THIS, ANIM_START, currentpose, NULL_KEY);
                        llMessageLinked(LINK_THIS, LOCALSETTING_SAVE, animtoken + "=" + currentpose, "");
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
        else if (auth == MENUNAME_REQUEST && str == rootmenu)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, rootmenu + "|" + animmenu, NULL_KEY); 
        }
        else if (auth == MENUNAME_RESPONSE)
        {
            if (startswith(str, animmenu + "|"))
            {
                string child = llList2String(llParseString2List(str, ["|"], []), 1);
                if (llListFindList(animbuttons, [child]) == -1)
                {
                    animbuttons += [child];
                }
            }
        }
        else if (auth == SUBMENU && str == posemenu)
        {//we don't know the authority of the menu requester, so send a message through the auth system
            llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "pose", id);
        }        
        else if (auth == SUBMENU && str == aomenu)
        {   //give menu
            AOMenu(id);
        }
        else if (auth == SUBMENU && str == animmenu)
        {   //give menu
            AnimMenu(id);
        }        
        else if (auth == COMMAND_SAFEWORD)
        { // saefword command recieved, release animation
            if(llGetInventoryType(currentpose) == INVENTORY_ANIMATION)
            {
                llMessageLinked(LINK_THIS, ANIM_STOP, currentpose, NULL_KEY);
                animLock = FALSE;
                llMessageLinked(LINK_THIS, HTTPDB_DELETE, locktoken, NULL_KEY);
                currentpose = "";
            }
        }
        else if (auth == HTTPDB_RESPONSE)
        {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            if (token == locktoken)
            {
                if(llList2String(params, 1) == "1")
                {
                    animLock = TRUE;
                }
            }
        }
        else if (auth == LOCALSETTING_RESPONSE)
        {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            if (token == animtoken)
            {
                //
                currentpose = llList2String(params, 1);
                llMessageLinked(LINK_THIS, ANIM_START, currentpose, NULL_KEY);                
            }            
        }
    }
    
    listen(integer channel, string name, key id, string message)
    {
        llSetTimerEvent(0);
        llListenRemove(listener);        
        if (channel == animmenuchannel)
        {
            if (message == UPMENU)
            {
                llMessageLinked(LINK_THIS, SUBMENU, rootmenu, id);
            }
            else if (message == "Pose")
            {
                PoseMenu(id);
            }
            else if (message == "AO")
            {
                AOMenu(id);
            }
            else if(llGetSubString(message, llStringLength(TICKED), -1) == ANIMLOCK)
            {
                llMessageLinked(LINK_THIS,COMMAND_NOAUTH, message, id);
            }
            else if (~llListFindList(animbuttons, [message]))
            {
                llMessageLinked(LINK_THIS, SUBMENU, message, id);
            }
        }
        else if (channel == posemenuchannel)
        {
            if (message == MORE)
            { //increment page number
                if (num_anims > (pagesize * (page + 1)))
                {  //there are more pages
                    page++;
                }
                else
                {
                    page = 0;
                }                    
            }
            if (message == PREV)
            { //decrement page number
                if (page > 0)
                {  //there are more pages
                    page--;
                }
                else
                {
                    page = (num_anims-1)/pagesize;
                }                    
            }
            else if (message == UPMENU)
            { //return on parent menu, so the animmenu below doesn't come up
                llMessageLinked(LINK_THIS, SUBMENU, animmenu, id);
                return;
            }
            else if (message == "*Release*")
            {
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "release", id);            
            }
            else  //we got an animation name
            //if ((integer)message)
            { //we don't know any more what the speaker's auth is, so pass the command back through the auth system.  then it will play only if authed
                //string animname = llGetInventoryName(INVENTORY_ANIMATION, (integer)message - 1);
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, message, id);
            }
            PoseMenu(id);             
        }         
        else if (channel == aomenuchannel)
        {
            if (message == triggerao)
            {
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "ao menu", id);
                //llSay(interfaceChannel, AO_MENU + "|" + (string)id);
                Notify(id, "Attempting to trigger the AO menu.  This will only work if " + llKey2Name(wearer) + " is wearing the OpenCollar Sub AO.", FALSE);
//                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "triggerao", id);                
            }
            else if (message == giveao)
            {    //queue a delivery
                DeliverAO(id);
                AOMenu(id);
            }
            else if (message == UPMENU)
            {
                llMessageLinked(LINK_THIS, SUBMENU, animmenu, id);                
            }
            else if(message == "AO ON")
            {
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "ao on", id);
                //llSay(interfaceChannel, "ZHAO_AOON" + "|" + (string)id);
                AOMenu(id);
            }
            else if(message == "AO OFF" )
            {
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "ao off", id);
                //llSay(interfaceChannel, "ZHAO_AOOFF" + "|" + (string)id);
                AOMenu(id);
            }
        }
    }
    
    timer()
    {
        llSetTimerEvent(0);
        llListenRemove(listener);
    }
}