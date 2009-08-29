//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//coupleanim1
string parentmenu = "Animations";
string submenu = "Couples";
//string UPMENU = "↑";
//string MORE = "→";
string UPMENU = "^";
string MORE = ">";
integer listener;
integer animmenuchannel = 9817243;
integer partnerchannel = 9817244;
string sensormode;//will be set to "chat" or "menu" later
string timermode;//set to "menu" or "anim" later
list partners;
integer menutimeout = 60;

key wearer;

string STOP_COUPLES = "Stop";
string TIME_COUPLES = "Time";

integer line;
key dataid;
string CARD1 = "coupleanims";
string CARD2 = "coupleanims_personal";
string noteCard2Read;

list animcmds;//1-strided list of strings that will trigger
list animsettings;//4-strided list of subanim|domanim|offset|text, running parallel to animcmds, 
                  //such that animcmds[0] corresponds to animsettings[0:3], and animcmds[1] corresponds to animsettings[4:7], etc
                  
key cardid1;//used to detect whether coupleanims card has changed
key cardid2;
float range = 10.0;//only scan within this range for anim partners
float tau = 1.5; //how hard to push sub toward 

key cmdgiver;
integer cmdindex;
string tmpname;
key partner;
string partnername;
float timeout = 20.0;//duration of anim
//i dont think this flag is needed at all
integer arrived;//a flag used to revent a flood of messages in the at_target event
string dbtoken = "coupletime";
string subanim;
string domanim;

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
integer CPLANIM_PERMREQUEST = 7002;//id should be av's key, str should be cmd name "hug", "kiss", etc
integer CPLANIM_PERMRESPONSE = 7003;//str should be "1" for got perms or "0" for not.  id should be av's key
integer CPLANIM_START = 7004;//str should be valid anim name.  id should be av
integer CPLANIM_STOP = 7005;//str should be valid anim name.  id should be av

debug(string str)
{
    //llOwnerSay(llGetScriptName() + ": " + str);
}

PartnerMenu(key id, list avs)
{
    string prompt = "Pick a partner.";
    prompt += "  (Menu will time out in " + (string)menutimeout + " seconds.)";
    
    if (llGetListLength(avs) > 11)
    {
        avs = llList2List(avs, 0, 10);
    }
    list buttons = avs;//we're limiting this to 11 avs
    buttons += [UPMENU];
    buttons = RestackMenu(buttons);
    timermode = "menu";
    llSetTimerEvent(menutimeout);
    llListenRemove(listener);
    partnerchannel = - llRound(llFrand(9999999.0)) - 9999;
    listener = llListen(partnerchannel, "", id, "");
    llDialog(id, prompt, buttons, partnerchannel);    
}

CoupleAnimMenu(key id)
{
    string prompt = "Pick an animation to play.";
    prompt += "  (Menu will time out in " + (string)menutimeout + " seconds.)";
    
    list buttons = animcmds;//we're limiting this to 9 couple anims then
    buttons += [TIME_COUPLES, STOP_COUPLES, UPMENU];
    buttons = RestackMenu(buttons);
    timermode = "menu";    
    llSetTimerEvent(menutimeout);
    llListenRemove(listener);
    animmenuchannel = llRound(llFrand(9999999.0)) + 1;    
    listener = llListen(animmenuchannel, "", id, "");
    llDialog(id, prompt, buttons, animmenuchannel);
}

TimerMenu(key id)
{
    string prompt = "Pick an time to play.";
    prompt += "  (Menu will time out in " + (string)menutimeout + " seconds.)";    
    list buttons = ["10", "20", "30"];
    buttons += ["40", "50", "60"];
    buttons += ["90", "120", "endless"];
    buttons += [UPMENU];
    buttons = RestackMenu(buttons);
    timermode = "menu";    
    llSetTimerEvent(menutimeout);
    llListenRemove(listener);
    partnerchannel = llRound(llFrand(9999950.0)) + 40;    
    listener = llListen(partnerchannel, "", id, "");
    llDialog(id, prompt, buttons, partnerchannel);    
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

integer AnimExists(string anim)
{
    return llGetInventoryType(anim) == INVENTORY_ANIMATION;
}

integer ValidLine(list params)
{
    //valid if length = 4 or 5 (since text is optional) and anims exist
    integer length = llGetListLength(params);
    if (length < 4)
    {
        return FALSE;
    }
    else if (length > 5)
    {
        return FALSE;
    }
    else if (!AnimExists(llList2String(params, 1)))
    {
        llOwnerSay(CARD1 + " line " + (string)line + ": animation '" + llList2String(params, 1) + "' is not present.  Skipping.");
        return FALSE;
    }
    else if (!AnimExists(llList2String(params, 2)))
    {
        llOwnerSay(CARD1 + " line " + (string)line + ": animation '" + llList2String(params, 2) + "' is not present.  Skipping.");        
        return FALSE;
    }
    else
    {
        return TRUE;
    }
}

integer startswith(string haystack, string needle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(haystack, llStringLength(needle), -1) == needle;
}

string str_replace(string src, string from, string to)
{//replaces all occurrences of 'from' with 'to' in 'src'.
    integer len = (~-(llStringLength(from)));
    if(~len)
    {
        string  buffer = src;
        integer b_pos = -1;
        integer to_len = (~-(llStringLength(to)));
        @loop;//instead of a while loop, saves 5 bytes (and run faster).
        integer to_pos = ~llSubStringIndex(buffer, from);
        if(to_pos)
        {
//            b_pos -= to_pos;
//            src = llInsertString(llDeleteSubString(src, b_pos, b_pos + len), b_pos, to);
//            b_pos += to_len;
//            buffer = llGetSubString(src, (-~(b_pos)), 0x8000);
            buffer = llGetSubString(src = llInsertString(llDeleteSubString(src, b_pos -= to_pos, b_pos + len), b_pos, to), (-~(b_pos += to_len)), 0x8000);
            jump loop;
        }
    }
    return src;
}

PrettySay(string text)
{
    string name = llGetObjectName();
    list words = llParseString2List(text, [" "], []);
    llSetObjectName(llList2String(words, 0));
    words = llDeleteSubList(words, 0, 0);
    llSay(0, "/me " + llDumpList2String(words, " "));
    llSetObjectName(name);
}

string FirstName(string name)
{
    return llList2String(llParseString2List(name, [" "], []), 0);
}

//added to stop eventual still going animations
StopAnims()
{
    if (AnimExists(subanim))
    {
        llMessageLinked(LINK_THIS, ANIM_STOP, subanim, NULL_KEY);
    }
    
    if (AnimExists(domanim))
    {
        llMessageLinked(LINK_THIS, CPLANIM_STOP, domanim, NULL_KEY);
    }
    
    subanim = "";
    domanim = "";
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
                        
default
{    
    state_entry()
    {
        wearer = llGetOwner();
        if (llGetInventoryType(CARD1) == INVENTORY_NOTECARD)
        {//card is present, start reading
            cardid1 = llGetInventoryKey(CARD1);
            
            //re-initialize just in case we're switching from other state
            line = 0;
            animcmds = [];
            animsettings = [];
            noteCard2Read = CARD1;
            dataid = llGetNotecardLine(noteCard2Read, line);            
        }
        else
        {
            //card isn't present, switch to nocard state
        }
    }
    link_message(integer sender, integer num, string str, key id)
    {
        if (num == HTTPDB_RESPONSE)
        {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if(token == dbtoken)
            {
                timeout = (float)value;
            }      
        }
    }
    
    dataserver(key id, string data)
    {
        if (id == dataid)
        {
            if (data == EOF)
            {
                if(noteCard2Read == CARD1)
                {
                    if(llGetInventoryType(CARD2) == INVENTORY_NOTECARD)
                    {
                        cardid2 = llGetInventoryKey(CARD2);
                        noteCard2Read = CARD2;
                        line = 0;
                        dataid = llGetNotecardLine(noteCard2Read, line);
                    }
                    else
                    {
                        //no Mycoupleanims notecard so...
                        state ready;
                    }
                }
                else
                {
                    debug("done reading card");
                    state ready;
                }
            }
            else
            {
                list params = llParseString2List(data, ["|"], []);
                //don't try to add empty or misformatted lines                
                if (ValidLine(params))
                {
                    integer index = llListFindList(animcmds, llList2List(params, 0, 0));
                    if(index == -1)
                    {
                        //add cmd, and text
                        animcmds += llList2List(params, 0, 0);
                        //anim names, offset, 
                        animsettings += llList2List(params, 1, 3);
                        //text.  this has to be done by casting to string instead of list2list, else lines that omit text will throw off the stride
                        animsettings += [llList2String(params, 4)];
                        debug(llDumpList2String(animcmds, ","));
                        debug(llDumpList2String(animsettings, ","));
                    }
                    else
                    {
                         index = index * 4;
                        //add cmd, and text
                        //animcmds = llListReplaceList(animcmds, llList2List(params, 0, 0), index, index);
                        //anim names, offset, 
                        animsettings = llListReplaceList(animsettings, llList2List(params, 1, 3), index, index + 2);
                        //text.  this has to be done by casting to string instead of list2list, else lines that omit text will throw off the stride
                        animsettings = llListReplaceList(animsettings,[llList2String(params, 4)], index + 3, index + 3);
                        debug(llDumpList2String(animcmds, ","));
                        debug(llDumpList2String(animsettings, ","));
                    }
                }
                line++;
                dataid = llGetNotecardLine(noteCard2Read, line);
            }
        }
    }
}

state nocard
{
    changed(integer change)
    {
        if (change & CHANGED_INVENTORY)
        {
            if (llGetInventoryType(CARD1) == INVENTORY_NOTECARD)
            {//card is now present, switch to default state and read it.
                state default;
            }
            if (llGetInventoryType(CARD2) == INVENTORY_NOTECARD)
            {//card is now present, switch to default state and read it.
                state default;
            }
        }
    }
}

state ready
{    //leaving this here due to delay of nc reading
    state_entry()
    {
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
    }
    
    
    on_rez(integer start)
    {
        llResetScript();
        
        //Nan: Commented out below because I'm not sure that we still need to worry about this if we (and the anim/pose script) reset on rez.
        
        //added to stop anims after relog when you logged off while in an endless couple anim        
        //if (subanim != "" && domanim != "")
        //{
        //    StopAnims();
        //}
    }
    
    link_message(integer sender, integer num, string str, key id)
    {
        //if you don't care who gave the command, so long as they're one of the above, you can just do this instead:
        if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
        {
            //the command was given by either owner, secowner, group member, or wearer
            list params = llParseString2List(str, [" "], []);
            cmdgiver = id;
            string cmd = llList2String(params, 0);
            integer tmpindex = llListFindList(animcmds, [cmd]);
            if (tmpindex != -1)
            {
                cmdindex = tmpindex;
                debug(cmd);
                //we got an anim cmd.  
                //else set partner to commander
                if (llGetListLength(params) > 1)
                {
                    //we've been given a name of someone to kiss.  scan for it
                    tmpname = llDumpList2String(llList2List(params, 1, -1), " ");//this makes it so we support even full names in the command
                    sensormode = "chat";
                    llSensor("", NULL_KEY, AGENT, range, PI);                    
                }
                else
                {
                    //no name given.  if commander is not sub, then treat commander as partner
                    if (id == wearer)
                    {
                        llMessageLinked(LINK_THIS, POPUP_HELP, "Error: you didn't give the name of the person you want to animate.  To " + cmd + " Nandana Singh, for example, you could say /_CHANNEL__PREFIX" + cmd + " nan", wearer);
                    }
                    else
                    {
                        partner = cmdgiver;
                        partnername = llKey2Name(partner);
                        //added to stop eventual still going animations
                        StopAnims();  
                        llMessageLinked(LINK_THIS, CPLANIM_PERMREQUEST, cmd, partner);      
                        llOwnerSay("Offering to " + cmd + " " + partnername + ".");
                    }
                }
            }
            else if (str == "stopcouples")
            {
                StopAnims();
            } 
            else if (str == "couples")
            {
               CoupleAnimMenu(id);
            } 
                       
        }
        else if (num == CPLANIM_PERMRESPONSE)
        {
            if (str == "1")
            {
                //we got permission to animate.  start moving to target
                float offset = (float)llList2String(animsettings, cmdindex * 4 + 2);
                vector pos = llList2Vector(llGetObjectDetails(partner, [OBJECT_POS]), 0);
                llTarget(pos, offset);
                llMoveToTarget(pos, tau);
                arrived = FALSE;
            }
            else if (str == "0")
            {
                //we did not get permission to animate
                llInstantMessage(cmdgiver, partnername + " did not accept your " + llList2String(animcmds, cmdindex) + ".");                
            }
        }
        else if (num == MENUNAME_REQUEST && str == parentmenu)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        else if (num == SUBMENU && str == submenu)
        {
            CoupleAnimMenu(id);
        }
        else if (num == HTTPDB_RESPONSE)
        {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if(token == dbtoken)
            {
                timeout = (float)value;
            }      
        }
    }
    
    not_at_target()
    {
        if (!arrived)
        {
            //this might make us chase the partner.  we'll see.  that might not be bad
            float offset = (float)llList2String(animsettings, cmdindex * 4 + 2);        
            vector pos = llList2Vector(llGetObjectDetails(partner, [OBJECT_POS]), 0);
            llTarget(pos, offset);
            llMoveToTarget(pos, tau);                    
        }
        else
        {
            llStopMoveToTarget();
        }
    }
    
    at_target(integer tnum, vector targetpos, vector ourpos)
    {
        if (!arrived)
        {
            debug("arrived");
            llTargetRemove(tnum);
            llStopMoveToTarget();
            //we've arrived.  let's play the anim and spout the text
            subanim = llList2String(animsettings, cmdindex * 4);
            domanim = llList2String(animsettings, cmdindex * 4 + 1);        
            llMessageLinked(LINK_THIS, ANIM_START, subanim, NULL_KEY);
            llMessageLinked(LINK_THIS, CPLANIM_START, domanim, NULL_KEY);
            
            string text = llList2String(animsettings, cmdindex * 4 + 3);
            if (text != "")
            {
                text = str_replace(text, "_SELF_", FirstName(llKey2Name(wearer)));
                text = str_replace(text, "_PARTNER_", FirstName(partnername));            
                PrettySay(text);
            }            
            timermode = "anim";
            llSetTimerEvent(timeout);
            arrived = TRUE;
        }
    }
    
    timer()
    {
        if (timermode == "menu")
        {
            llListenRemove(listener);
        }
        StopAnims();
        llSetTimerEvent(0.0);       
    }
    
    sensor(integer num)
    {
        debug(sensormode);
        if (sensormode == "menu")
        {
            partners = [];
            list avs;//just used for menu building
            integer n;
            for (n = 0; n < num; n++)
            {
                partners += [llDetectedKey(n), llDetectedName(n)];
                avs += [llDetectedName(n)];
            }
            PartnerMenu(cmdgiver, avs);
        }
        else if (sensormode == "chat")
        {
            //loop through detected avs, seeing if one matches tmpname
            integer n;
            for (n = 0; n < num; n++)
            {
                string name = llDetectedName(n);
                if (startswith(llToLower(name), llToLower(tmpname)) || llToLower(name) == llToLower(tmpname))
                {
                    partner = llDetectedKey(n);
                    partnername = name;
                    string cmd = llList2String(animcmds, cmdindex);
                //added to stop eventual still going animations
                    StopAnims();  
                    llMessageLinked(LINK_THIS, CPLANIM_PERMREQUEST, cmd, partner);
                    llOwnerSay("Offering to " + cmd + " " + partnername + ".");                
                    return;
                }
            }
            //if we got to this point, then no one matched
            llInstantMessage(cmdgiver, "Could not find '" + tmpname + "' to " + llList2String(animcmds, cmdindex) + ".");             
        }               
    }
    
    no_sensor()
    {
        if (sensormode == "chat")
        {
            llInstantMessage(cmdgiver, "Could not find '" + tmpname + "' to " + llList2String(animcmds, cmdindex) + ".");
        }
        else if (sensormode == "menu")
        {
            llInstantMessage(cmdgiver, "Could not find anyone nearby to " + llList2String(animcmds, cmdindex) + ".");
            CoupleAnimMenu(cmdgiver);
        }
    }
    
    changed(integer change)
    {
        if (change & CHANGED_INVENTORY)
        {
            if (llGetInventoryKey(CARD1) != cardid1)
            {
                //because notecards get new uuids on each save, we can detect if the notecard has changed by seeing if the current uuid is the same as the one we started with
                //just switch states instead of restarting, so we can preserve any settings we may have gotten from db
                state default;
            }
            if (llGetInventoryKey(CARD2) != cardid1)
            {
                state default;
            }
        }
    }
    
    listen(integer channel, string name, key id, string message)
    {
        debug(message);
        llListenRemove(listener);
        llSetTimerEvent(0.0);
        if (channel == animmenuchannel)
        {
            if (message == UPMENU)
            {
                llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);
            }
            else if (message == STOP_COUPLES)
            {
                StopAnims();
                CoupleAnimMenu(id);
            }             
            else if (message == TIME_COUPLES)
            {
                TimerMenu(id);
            }             
            else
            {
                integer index = llListFindList(animcmds, [message]);
                if (index != -1)
                {
                    cmdgiver = id;
                    cmdindex = index;
                    sensormode = "menu";
                    llSensor("", NULL_KEY, AGENT, range, PI);                    
                }
            }
        }
        else if (channel == partnerchannel)
        {
            if (message == UPMENU)
            {
                CoupleAnimMenu(id);
            }
            else if ((integer)message > 0 && ((string)((integer)message) == message))
            {
                timeout = (float)((integer)message);
                llMessageLinked(LINK_SET, HTTPDB_SAVE, dbtoken + "=" + (string)timeout, NULL_KEY);
                Notify (id, "Couple Anmiations play now for " + (string)llRound(timeout) + " seconds.",TRUE);
                CoupleAnimMenu(id);
            }
            else if (message == "endless")
            {
                timeout = 0.0;
                llMessageLinked(LINK_SET, HTTPDB_SAVE, dbtoken + "=" + (string)timeout, NULL_KEY);
                Notify (id, "Couple Anmiations play now for ever. Use the menu or type *stopcouples to stop them again.",TRUE);
            }           
            else
            {
                integer index = llListFindList(partners, [message]);
                if (index != -1)
                {
                    partner = llList2String(partners, index - 1);
                    partnername = message;
                    //added to stop eventual still going animations
                    StopAnims();  
                    string cmdname = llList2String(animcmds, cmdindex);
                    llMessageLinked(LINK_THIS, CPLANIM_PERMREQUEST, cmdname, partner);      
                    llOwnerSay("Offering to " + cmdname + " " + partnername + ".");                    
                }
            }
        }
    }
}
