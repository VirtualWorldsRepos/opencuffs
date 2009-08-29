//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
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
integer rlvnotify = FALSE;//if TRUE, ownersay on each RLV restriction
integer listener;
float versiontimeout = 30.0;
integer versionchannel = 293847;
integer checkcount;//increment this each time we say @version.  check it each time timer goes off in default state. give up if it's >= 2
integer returnmenu;
string rlvString = "RestrainedLife viewer v1.20";

//"checked" state - HANDLING RLV SUBMENUS AND COMMANDS
//on start, request RLV submenus
//on rlv submenu response, add to list
//on main submenu "RLV", bring up this menu

string parentmenu = "Main";
string submenu = "RLV";
list menulist;
integer menutimeout = 60;
integer menulistener;
integer menuchannel = 2380982;
integer RELAY_CHANNEL = -1812221819;
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
integer COMMAND_SAFEWORD = 510;
integer COMMAND_RELAY_SAFEWORD = 511;

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
integer RLVR_CMD = 6010;
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.
integer RLV_VERSION = 6003; //RLV Plugins can recieve the used rl viewer version upon receiving this message..

integer RLV_OFF = 6100; // send to inform plugins that RLV is disabled now, no message or key needed
integer RLV_ON = 6101; // send to inform plugins that RLV is enabled now, no message or key needed

integer ANIM_START = 7000;//send this with the name of an anim in the string part of the message to play the anim
integer ANIM_STOP = 7001;//send this with the name of an anim in the string part of the message to stop the anim

//string UPMENU = "â†‘";
//string MORE = "â†’";
string UPMENU = "^";
//string MORE = ">";
string TURNON = "*Turn On*";
string TURNOFF = "*Turn Off*";
string CLEAR = "*Clear All*";

key wearer;

debug(string str)
{
    //llOwnerSay(llGetScriptName() + ": " + str);
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

CheckVersion()
{
    //llOwnerSay("checking version");
    if (verbose)
    {
        Notify(wearer, "Attempting to enable Restrained Life Viewer functions.  " + rlvString+ " or higher is required for all features to work.", TRUE);
    }
    //open listener
    listener = llListen(versionchannel, "", wearer, "");
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
    buttons = RestackMenu(buttons);
    llDialog(id, prompt, buttons, menuchannel);
    //TO-DO: handle multi-page menus, in case we ever have like 13 RLV plugins (please god no)
    //TO-DO: sort the buttons alphabetically before delivering the dialog.  fill and restack
}

list RestackMenu(list in)
{ //adds empty buttons until the list length is multiple of 3, to max of 12
    while (llGetListLength(in) % 3 != 0 && llGetListLength(in) < 12)
    {
        in += [" "];
    }
    //look for ^ and > in the menu
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
    return out;
}

integer startswith(string haystack, string needle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(haystack, llStringLength(needle), -1) == needle;
}


// Book keeping functions



integer SIT_CHANNEL;

key owner;

list sources=[];
list restrictions=[];
list old_restrictions;
list old_sources;

list baked=[];

integer sitlistener;
integer relaylistener;
string timertype="";

key sitter=NULL_KEY;
key sittarget=NULL_KEY;


//message map

integer CMD_ADDSRC = 11;
integer CMD_REMSRC = 12;

integer CMD_ML=31;


sendCommand(string cmd)
{
    if (cmd=="thirdview=n")
    {
        llMessageLinked(LINK_THIS,CMD_ML,"on",NULL_KEY);
    }
    else if (cmd=="thirdview=y")
    {
        llMessageLinked(LINK_THIS,CMD_ML,"off",NULL_KEY);
    }
    else llOwnerSay("@"+cmd);
    if (rlvnotify)
    {
        Notify(wearer, "Sent RLV Command: " + cmd, TRUE);
    }

}

handlecommand(key id, string command)
{
    string str=llToLower(command);
    list args = llParseString2List(str,["="],[]);
    string com = llList2String(args,0);
    if (llGetSubString(com,-1,-1)==":") com=llGetSubString(com,0,-2);
    string val = llList2String(args,1);
    if (val=="n"||val=="add") addrestriction(id,com);
    else if (val=="y"||val=="rem") remrestriction(id,com);
    else if (com=="clear") release(id,val);
    else
    {
        sendCommand(str);
        if (sitter==NULL_KEY&&llGetSubString(str,0,3)=="sit:")
        {
            sitter=id;
            //debug("Sitter:"+(string)(sitter));
            sittarget=(key)llGetSubString(str,4,-1);
            //debug("Sittarget:"+(string)(sittarget));
        }
    }
}

addrestriction(key id, string behav)
{
    integer source=llListFindList(sources,[id]);
    integer restr;
    if (source==-1)
    {
        sources+=[id];
        restrictions+=[behav];
        restr=-1;
        if (id!=NULL_KEY) llMessageLinked(LINK_THIS, CMD_ADDSRC,"",id);
    }
    else
    {
        list srcrestr = llParseString2List(llList2String(restrictions,source),["/"],[]);
        restr=llListFindList(srcrestr, [behav]);
        if (restr==-1)
        {
            restrictions=llListReplaceList(restrictions,[llDumpList2String(srcrestr+[behav],"/")],source, source);
        }
    }
    if (restr==-1)
    {
        applyadd(behav);
        if (behav=="unsit")
        {
            sitlistener=llListen(SIT_CHANNEL,"",wearer,"");
            sendCommand("getsitid="+(string)SIT_CHANNEL);
            sitter=id;
        }
    }
}

applyadd (string behav)
{
    integer restr=llListFindList(baked, [behav]);
    if (restr==-1)
    {
        //if (baked==[]) sendCommand("detach=n");  removed this as locking is owner privilege
        baked+=[behav];
        sendCommand(behav+"=n");
        //debug(behav);
    }
}

remrestriction(key id, string behav)
{
    integer source=llListFindList(sources,[id]);
    integer restr;
    if (source!=-1)
    {
        list srcrestr = llParseString2List(llList2String(restrictions,source),["/"],[]);
        restr=llListFindList(srcrestr,[behav]);
        if (restr!=-1)
        {
            if (llGetListLength(srcrestr)==1)
            {
                restrictions=llDeleteSubList(restrictions,source, source);
                sources=llDeleteSubList(sources,source, source);
                if (id!=NULL_KEY) llMessageLinked(LINK_THIS, CMD_REMSRC,"",id);
            }
            else
            {
                srcrestr=llDeleteSubList(srcrestr,restr,restr);
                restrictions=llListReplaceList(restrictions,[llDumpList2String(srcrestr,"/")] ,source,source);
            }
            applyrem(behav);
        }
    }
}

applyrem(string behav)
{
    integer restr=llListFindList(baked, [behav]);
    if (restr!=-1)
    {
        integer i;
        integer found=FALSE;
        for (i=0;i<=llGetListLength(restrictions);i++)
        {
            list srcrestr=llParseString2List(llList2String(restrictions,i),["/"],[]);
            if (llListFindList(srcrestr, [behav])!=-1) found=TRUE;
        }
        if (!found)
        {
            baked=llDeleteSubList(baked,restr,restr);
            if (behav!="no_hax") sendCommand(behav+"=y");
        }
    }
    //    if (baked==[]) sendCommand("detach=y");
}

release(key id, string pattern)
{
    integer source=llListFindList(sources,[id]);
    if (source!=-1)
    {
        list srcrestr=llParseString2List(llList2String(restrictions,source),["/"],[]);
        restrictions=llDeleteSubList(restrictions,source, source);
        sources=llDeleteSubList(sources,source, source);
        llMessageLinked(LINK_THIS, CMD_REMSRC,"",id);
        integer i;
        for (i=0;i<=llGetListLength(srcrestr);i++)
        {
            string  behav=llList2String(srcrestr,i);
            if (pattern==""||llSubStringIndex(behav,pattern)!=-1)
            {
                applyrem(behav);
                if (behav=="unsit"&&sitter==id)
                {
                    sitter=NULL_KEY;
                    sittarget=NULL_KEY;
                }
            }
        }
    }
}


safeword (integer collartoo)
{
    //    integer index=llListFindList(sources,[NULL_KEY]);
    //    list collarrestr=llParseString2List(llList2String(restrictions,index),["/"],[]);
    sendCommand("clear");
    baked=[];
    sources=[];
    restrictions=[];
    sendCommand("no_hax=n");
    integer i;
    if (!collartoo) llMessageLinked(LINK_THIS,RLV_REFRESH,"",NULL_KEY);
}




// End of book keeping functions

default
{    /* //no more self resets
        on_rez(integer param)
        {
            llResetScript();
        }
        */
            state_entry()
            {
                wearer = llGetOwner();
                //request setting from DB
                llSleep(1.0);
                llMessageLinked(LINK_THIS, HTTPDB_REQUEST, "rlvon", NULL_KEY);
                llMessageLinked(LINK_THIS, HTTPDB_REQUEST, "owner", NULL_KEY);
                /* //no more needed
                    //Tell main menu we've got a submenu
                    llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
                */
                    SIT_CHANNEL=9999 + llFloor(llFrand(9999999.0));
            }

        link_message(integer sender, integer num, string str, key id)
        {
            if (num == HTTPDB_RESPONSE)
            {
                if (str == "rlvon=0")
                {//RLV is turned off in DB.  just switch to checked state without checking viewer
                    //llOwnerSay("rlvdb false");
                    state checked;
                    llMessageLinked(LINK_THIS, RLV_OFF, "", NULL_KEY);

                }
                else if (str == "rlvon=1")
                {//DB says we were running RLV last time it looked.  do @version to check.
                    //llOwnerSay("rlvdb true");
                    rlvon = TRUE;
                    //check viewer version
                    CheckVersion();
                }
                else if (str == "rlvnotify=1")
                {
                    rlvnotify = TRUE;
                }
                else if (str == "rlvnotify=0")
                {
                    rlvnotify = FALSE;
                }
                else if (str == "rlvon=unset")
                {
                    CheckVersion();
                } else if (llGetSubString(str, 0, 5) == "owner=") {
                        owner = (key)llList2String(llParseString2List(llGetSubString(str,6,-1), [","], []), 0);
                }
            }
            else if ((num == HTTPDB_EMPTY && str == "rlvon"))
            {
                CheckVersion();
            }
            else if (num == MENUNAME_REQUEST && str == parentmenu)
            {
                llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
            }
            else if (num == SUBMENU && str == submenu)
            {
                if (num == SUBMENU)
                {   //someone clicked "RLV" on the main menu.  Tell them we're not ready yet.
                    Notify(id, "Still querying for viewer version.  Please try again in a minute.", FALSE);
                    llResetScript();
                }
                else if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
                {//someone used "RLV" chat command.  Tell them we're not ready yet.
                    Notify(id, "Still querying for viewer version.  Please try again in a minute.", FALSE);
                    llResetScript();
                }
            }
        }

        listen(integer channel, string name, key id, string message)
        {
            if (channel == versionchannel)
            {
                //llOwnerSay("heard " + message);
                llListenRemove(listener);
                llSetTimerEvent(0.0);
                //get the version to send to rlv plugins
                string rlvVersion = llList2String(llParseString2List(message, [" "], []), 2);
                list temp = llParseString2List(rlvVersion, ["."], []);
                string majorV = llList2String(temp, 0);
                string minorV = llList2String(temp, 1);
                rlvVersion = llGetSubString(majorV, -1, -1) + llGetSubString(minorV, 0, 1);
                llMessageLinked(LINK_THIS, RLV_VERSION, rlvVersion, NULL_KEY);
                //this is already TRUE if rlvon=1 in the DB, but not if rlvon was unset.  set it to true here regardless, since we're setting rlvon=1 in the DB
                rlvon = TRUE;
                llMessageLinked(LINK_THIS, RLV_VERSION, rlvVersion, NULL_KEY);
                
                //someone thought it would be a good idea to use a whisper instead of a ownersay here
                //for both privacy and spamminess reasons, I've reverted back to an ownersay. --Nan
                llOwnerSay("Restrained Life functions enabled. " + message + " detected.");
                viewercheck = TRUE;

                llMessageLinked(LINK_THIS, RLV_ON, "", NULL_KEY);

                state checked;
            }
        }

        timer()
        {
            llListenRemove(listener);
            llSetTimerEvent(0.0);
            if (checkcount == 1)
            {   //the viewer hasn't responded after 30 seconds, but maybe it was still logging in when we did @version
                //give it one more chance
                CheckVersion();
            }
            else if (checkcount >= 2)
            {   //we've given the viewer a full 60 seconds
                viewercheck = FALSE;
                rlvon = FALSE;
                llMessageLinked(LINK_THIS, RLV_OFF, "", NULL_KEY);


                //            llMessageLinked(LINK_THIS, HTTPDB_SAVE, "rlvon=0", NULL_KEY); <--- what was the point???
                //else the user normally logs in with RLv, but just not this time
                //in which case, leave it turned on in the database, until user manually changes it
                //i think this should always be said
                //            if (verbose)
                //            {
                Notify(wearer,"Could not detect Restrained Life Viewer.  Restrained Life functions disabled.",TRUE);
                //            }
                if (llGetListLength(restrictions) > 0 && owner != NULL_KEY && owner != wearer) {
                    Notify(wearer,"Your owner has been notified.",TRUE);
                    Notify(owner, llKey2Name(wearer)+" appears to have logged in without using the Restrained Life Viewer.  Their Restrained Life functions have been disabled.", FALSE);
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
        state default;
    }
    
    
/* Bad!  (would prevent reattach on detach)    
    attach(key id)
    {
        if (id == NULL_KEY && rlvon && viewercheck)
        {
            llOwnerSay("@clear");
        }
    }
*/
    state_entry()
    {
        menulist = [];//clear this list now in case there are old entries in it
        //we only need to request submenus if rlv is turned on and running
        if (rlvon && viewercheck)
        {   //ask RLV plugins to tell us about their rlv submenus
            llMessageLinked(LINK_THIS, MENUNAME_REQUEST, submenu, NULL_KEY);
            //initialize restrictions and protect against the "arbitrary string on arbitrary channel" exploit
            sendCommand("clear");
            sendCommand("no_hax=n");
            //ping inworld object so that they reinstate their restrictions
            integer i;
            for (i=0;i<llGetListLength(sources);i++)
            {
                if ((key)llList2String(sources,i)) llShout(RELAY_CHANNEL,"ping,"+llList2String(sources,i)+",ping,ping");
                //debug("ping,"+llList2String(sources,i)+",ping,ping");
            }
            old_restrictions=restrictions;
            old_sources=sources;
            restrictions=[];
            sources=[];
            baked=[];
            timertype="pong";
            llSetTimerEvent(2);

            //tell rlv plugins to reinstate restrictions
            llMessageLinked(LINK_THIS, RLV_REFRESH, "", NULL_KEY);
        }
        //llOwnerSay("entered checked state.  rlvon=" + (string)rlvon + ", viewercheck=" + (string)viewercheck);
    }

    link_message(integer sender, integer num, string str, key id)
    {
        if (num == MENUNAME_REQUEST && str == parentmenu)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        // added chat command for menu:
        else if (llToUpper(str) == submenu)
        {
            if (num == SUBMENU)
            {   //someone clicked "RLV" on the main menu.  Give them our menu now
                DoMenu(id);
            }
            else if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
            { //someone used the chat command
                DoMenu(id);
            }
        }
        else if (str == "rlvon")
        {
            if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
            {
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "rlvon=1", NULL_KEY);
                rlvon = TRUE;
                verbose = TRUE;
                state default;
            }
        }
        else if (startswith(str, "rlvnotify") && num >= COMMAND_OWNER && num <= COMMAND_WEARER)
        {
            string onoff = llList2String(llParseString2List(str, [" "], []), 1);
            if (onoff == "on")
            {
                rlvnotify = TRUE;
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "rlvnotify=1", NULL_KEY);
            }
            else if (onoff == "off")
            {
                rlvnotify = FALSE;
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "rlvnotify=0", NULL_KEY);
            }
        }

        //these are things we only do if RLV is ready to go
        if (rlvon && viewercheck)
        {   //if RLV is off, don't even respond to RLV submenu events
            if (num == MENUNAME_RESPONSE)
            {    //str will be in form of "parentmenu|menuname"
                list params = llParseString2List(str, ["|"], []);
                string thisparent = llList2String(params, 0);
                string child = llList2String(params, 1);
                if (thisparent == submenu)
                {     //add this str to our menu buttons
                    if (llListFindList(menulist, [child]) == -1)
                    {
                        menulist += [child];
                    }
                }
            }
            else if (num == MENUNAME_REMOVE)
            {    //str will be in form of "parentmenu|menuname"
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
                list commands=llParseString2List(str,[","],[]);
                integer i;
                for (i=0;i<llGetListLength(commands);i++) handlecommand(NULL_KEY,llList2String(commands,i));
            }
            else if (num == RLV_CMD||num == RLVR_CMD)
            {
                handlecommand(id,str);
            }
            else if (num == COMMAND_RLV_RELAY && timertype=="pong" && str=="ping,"+(string)wearer+",!pong")
            {
                if (id==sitter) sendCommand("sit:"+(string)sittarget+"=force");
                integer sourcenum=llListFindList(old_sources, [id]);
                integer j;
                list restr=llParseString2List(llList2String(old_restrictions,sourcenum),["/"],[]);
                for (j=0;j<llGetListLength(restr);j++) addrestriction(id,llList2String(restr,j));
            }
            else if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
            {
                debug("cmd: " + str);
                if (str == "clear")
                {
                    if (num == COMMAND_WEARER)
                    {
                        Notify(wearer,"Sorry, but the sub cannot clear RLV settings.",TRUE);
                    }
                    else
                    {
                        llMessageLinked(LINK_THIS, RLV_CLEAR, "", NULL_KEY);
                        safeword(TRUE);
                    }
                }
                else if (str == "rlvon")
                {
                    llMessageLinked(LINK_THIS, HTTPDB_SAVE, "rlvon=1", NULL_KEY);
                    rlvon = TRUE;
                    verbose = TRUE;
                    state default;
                }
                else if (str == "rlvoff")
                {
                    if (num == COMMAND_OWNER)
                    {
                        rlvon = FALSE;
                        llMessageLinked(LINK_THIS, HTTPDB_SAVE, "rlvon=0", NULL_KEY);
                        safeword(TRUE);
                        llMessageLinked(LINK_THIS, RLV_OFF, "", NULL_KEY);


                    }
                    else
                    {
                        Notify(id, "Sorry, only owner may disable Restrained Life functions", FALSE);
                    }

                    if (returnmenu)
                    {
                        returnmenu = FALSE;
                        DoMenu(id);
                    }
                }
                else if (str=="showrestrictions")
                {
                    string out="You are being restricted by the following object";
                    if (llGetListLength(sources)==2) out+=":";
                    else out+="s:";
                    integer i;
                    for (i=0;i<llGetListLength(sources);i++)
                        if (llList2String(sources,i)!=NULL_KEY) out+="\n"+llKey2Name((key)llList2String(sources,i))+" ("+llList2String(sources,i)+"): "+llList2String(restrictions,i);
                    else out+="\nThis collar: "+llList2String(restrictions,i);
                    Notify(id,out,FALSE);
                }
            }
            else if (num == COMMAND_SAFEWORD)
            {// safeword used, clear rlv settings
                llMessageLinked(LINK_THIS, RLV_CLEAR, "", NULL_KEY);
                safeword(TRUE);
            }
            else if (num == HTTPDB_RESPONSE)
            {
                if (str == "rlvnotify=1")
                {
                    rlvnotify = TRUE;
                }
                else if (str == "rlvnotify=0")
                {
                    rlvnotify = FALSE;
                }
            }
            else if (num==COMMAND_RELAY_SAFEWORD) safeword(FALSE);

        }
    }

    listen(integer channel, string name, key id, string message)
    {
        if (channel == menuchannel)
        {
            debug(message);
            llListenRemove(menulistener);
            llSetTimerEvent(0.0);
            if (message == TURNON)
            {
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "rlvon", id);
            }
            else if (message == TURNOFF)
            {
                returnmenu = TRUE;
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "rlvoff", id);
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
                llMessageLinked(LINK_SET, SUBMENU, message, id);
            }
        }
        else if (channel==SIT_CHANNEL)
        {
            sittarget=message;
            llListenRemove(sitlistener);
        }

    }

    timer()
    {
        returnmenu = FALSE;
        llListenRemove(menulistener);
        llSetTimerEvent(0.0);
        if (timertype=="pong")
        {
            old_sources=[];
            old_restrictions=[];
            llListenRemove(relaylistener);
        }
        timertype="";
    }
}