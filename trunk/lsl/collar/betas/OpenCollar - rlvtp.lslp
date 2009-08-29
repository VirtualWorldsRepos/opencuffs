//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.

//3.004 - adding "accepttp" support.  No button, just automatically turned on for owner.

key owner = NULL_KEY;

string parentmenu = "RLV";
string submenu = "Map/TP";
string dbtoken = "rlvtp";
string extoken = "rlvtpex";

string latestRLVersionSupport = "1.15.1"; //the version which brings the latest used feature to check against
string detectedRLVersion;
list settings;//2-strided list in form of [option, param]
list exceptions;//2-strided list in form of [option, uuid]
list removexptns;//2-strided list in form of [option, uuid], of exceptions that need to be removed.  cleared after being sent to main rlv script

list rlvcmds = [
    "tplm",
    "tploc",
    "tplure",
    "showworldmap",
    "showminimap",
    "showloc",
    "accepttp"
        ];

list prettycmds = [ //showing menu-friendly command names for each item in rlvcmds
    "LM",
    "Loc",
    "Lure",
    "Map",
    "Minimap",
    "ShowLoc",
    "refuseTP"
        ];

list descriptions = [ //showing descriptions for commands
    "Teleport to Landmark",
    "Teleport to Location",
    "Teleport by Friend",
    "World Map",
    "Mini Map",
    "Current Location",
    "Forbids the sub to refuse a tp offer from the owner"
        ];

list auto_exceptions = [
    "tplure"
        ];

string TURNON = "Allow";
string TURNOFF = "Forbid";

integer timeout = 60;
integer menuchannel = 987345;
integer listener;
integer returnmenu = FALSE;

integer rlvon=TRUE;

key wearer;

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
integer RLV_VERSION = 6003; //RLV Plugins can recieve the used rl viewer version upon receiving this message.

integer RLV_OFF = 6100; // send to inform plugins that RLV is disabled now, no message or key needed
integer RLV_ON = 6101; // send to inform plugins that RLV is enabled now, no message or key needed

integer ANIM_START = 7000;//send this with the name of an anim in the string part of the message to play the anim
integer ANIM_STOP = 7001;//send this with the name of an anim in the string part of the message to stop the anim

//string UPMENU = "?";
//string MORE = "?";
string UPMENU = "^";
//string MORE = ">";

debug(string msg)
{
    //    llOwnerSay(llGetScriptName() + ": " + msg);
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

Menu(key id)
{
    if (!rlvon)
    {
        Notify(id, "RLV features are now disabled in this collar. You can enable those in RLV submenu. Opening it now.", FALSE);
        llMessageLinked(LINK_SET, SUBMENU, "RLV", id);
        return;
    }

    //build prompt showing current settings
    //make enable/disable buttons
    //    string prompt = "Pick an option";
    //    prompt += " (Menu will expire in " + (string)timeout + " seconds.)";
    string prompt = "Current Settings: ";
    list buttons;

    integer acceptTpButton = FALSE;
    integer n;
    integer stop = llGetListLength(rlvcmds);
    for (n = 0; n < stop; n++)
    {
        //see if there's a setting for this in the settings list
        string cmd = llList2String(rlvcmds, n);
        string pretty = llList2String(prettycmds, n);
        string desc = llList2String(descriptions, n);
        integer index = llListFindList(settings, [cmd]);
        debug((string)index);
        if (index == -1)
        {   //if this cmd not set, then give button to enable

            integer i;
            if (llList2String(prettycmds, n) != "refuseTP")
            {
                buttons += [TURNOFF + " " + llList2String(prettycmds, n)];
                prompt += "\n" + pretty + " = Enabled (" + desc + ")";
            }
            else if (!acceptTpButton && AtLeastVersion(latestRLVersionSupport, detectedRLVersion))
            {
                for (i = 0; i < llGetListLength(settings); i = i + 2)
                {
                    debug(llGetSubString(llList2String(settings, i), 0, 7));
                    if (llGetSubString(llList2String(settings, i), 0, 7) == "accepttp")
                    {
                        if (llList2String(settings, i + 1) == "add")
                        {
                            buttons += [TURNON + " refuseTP"];
                            prompt += "\nrefuseTP = Disabled (Forbids the sub to refuse a tp offer from the owner)";
                        }
                        else
                        {
                            buttons += [TURNOFF + " refuseTP"];
                            prompt += "\nrefuseTP = Enabled (Forbids the sub to refuse a tp offer from the owner)";
                        }
                        acceptTpButton = TRUE;
                    }
                }
                if (!acceptTpButton && llGetSubString(llList2String(settings, i), 0, 7) != "accepttp")
                {
                    buttons += [TURNOFF + " " + llList2String(prettycmds, n)];
                    prompt += "\n" + pretty + " = Enabled (" + desc + ")";
                }
            }


        }
        else
        {   //else this cmd is set, then show in prompt, and make button do opposite
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

    //give an Allow All button
    buttons += [TURNON + " All"];
    buttons += [TURNOFF + " All"];
    debug(prompt);
    debug((string)llStringLength(prompt));
    buttons += [UPMENU];
    buttons = RestackMenu(buttons);
    menuchannel = -llRound(llFrand(9999999.0)) -99999;
    listener = llListen(menuchannel, "", id, "");
    llSetTimerEvent(timeout);
    llDialog(id, prompt, buttons, menuchannel);
}

integer AtLeastVersion(string cutoff, string checkme)
{//returns TRUE if checkme is >= cutoff, else FALSE.  Loops through major.minor.reallyminor versions ad nauseum to do compare
    //cutoff and checkme strings must have only numbers and dots.  No letters. ("1.15.5" is ok, "1.15c" is not)
    list lcutoff = llParseString2List(cutoff, ["."], []);
    list lcheckme = llParseString2List(checkme, ["."], []);
    integer n;
    integer stop = llGetListLength(lcutoff);
    for (n = 0; n < stop; n++)
    {
        integer checkpart = (integer)llList2String(lcheckme, n);
        integer cutoffpart = (integer)llList2String(lcutoff, n);
        if (checkpart < cutoffpart)
        {
            return FALSE;
        }
        else if (checkpart > cutoffpart)
        {
            return TRUE;
        }
    }
    return TRUE;
}

UpdateSettings()
{
    //build one big string from the settings list
    //llOwnerSay("TP settings: " + llDumpList2String(settings, ","));
    integer settingslength = llGetListLength(settings);
    if (settingslength > 0)
    {
        list temp_settings;
        string temp_rlvsetting;
        string temp_rlvvalue;
        integer n;
        list newlist;
        for (n = 0; n < settingslength; n = n + 2)
        {
            temp_rlvsetting=llList2String(settings, n);
            temp_rlvvalue=llList2String(settings, n + 1);
            newlist += [ temp_rlvsetting+ "=" + temp_rlvvalue];
            if (temp_rlvvalue!="y")
            {
                temp_settings+=[temp_rlvsetting,temp_rlvvalue];
            }
        }
        //output that string to viewer
        llMessageLinked(LINK_THIS, RLV_CMD, llDumpList2String(newlist, ","), NULL_KEY);
        settings=temp_settings;
    }

    //Handle adding exceptions to RLV restrictions
    integer exptnlength = llGetListLength(exceptions);
    if (exptnlength > 0)
    {
        list exptnlist;
        integer n;
        for (n = 0; n < exptnlength; n = n + 2)
        {
            exptnlist += [llList2String(exceptions, n) + ":" + llList2String(exceptions, n + 1) + "=add"];
        }
        llMessageLinked(LINK_THIS, RLV_CMD, llDumpList2String(exptnlist, ","), NULL_KEY);
    }

    //Handle removing exceptions to RLV restrictions
    integer remlength = llGetListLength(removexptns);
    if (remlength > 0)
    {
        list remlist;
        integer n;
        for (n = 0; n < remlength; n = n + 2)
        {
            remlist += [llList2String(removexptns, n) + ":" + llList2String(removexptns, n + 1) + "=rem"];
        }
        llMessageLinked(LINK_THIS, RLV_CMD, llDumpList2String(remlist, ","), NULL_KEY);
        removexptns = [];
    }

    AcceptOwnerTPs("add");
}

SaveSettings()
{
    //save to DB
    if (llGetListLength(settings)>0)
        llMessageLinked(LINK_THIS, HTTPDB_SAVE, dbtoken + "=" + llDumpList2String(settings, ","), NULL_KEY);
    else
        llMessageLinked(LINK_THIS, HTTPDB_DELETE, dbtoken, NULL_KEY);

    if (llGetListLength(exceptions)>0)
        llMessageLinked(LINK_THIS, HTTPDB_SAVE, extoken + "=" + llDumpList2String(exceptions, ","), NULL_KEY);
    else
        llMessageLinked(LINK_THIS, HTTPDB_DELETE, extoken, NULL_KEY);
}

ClearSettings()
{
    //clear settings list
    settings = [];
    //remove tpsettings from DB... now done by httpdb itself
    llMessageLinked(LINK_THIS, HTTPDB_DELETE, dbtoken, NULL_KEY);
    llMessageLinked(LINK_THIS, HTTPDB_DELETE, extoken, NULL_KEY);
    //main RLV script will take care of sending @clear to viewer
    //avoid race conditions
    llSleep(1.0);
    AcceptOwnerTPs("add");
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

AcceptOwnerTPs(string val)
{
    if (owner != NULL_KEY)
    {
        llMessageLinked(LINK_THIS, RLV_CMD, "accepttp:" + (string)owner + "=" +val, NULL_KEY);
    }
}

default
{   /* //no more needed
        on_rez(integer param)
        {
            llResetScript();
        }
    */
        state_entry()
        {
            wearer = llGetOwner();

            //llSleep(1.0);
            //llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
            //llMessageLinked(LINK_THIS, HTTPDB_REQUEST, dbtoken, NULL_KEY);
        }

            link_message(integer sender, integer num, string str, key id)
            {
                //llOwnerSay("LinkMessage--num: " + (string)num + "str: " + str);
                if (num == MENUNAME_REQUEST && str == parentmenu)
                {
                    llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
                }
                else if (num == SUBMENU && str == submenu)
                {
                    Menu(id);
                }
                else if ((str == "reset" || str == "runaway") && (num == COMMAND_OWNER || num == COMMAND_WEARER))
                {   //clear db, reset script
                    //llMessageLinked(LINK_THIS, HTTPDB_DELETE, dbtoken, NULL_KEY);
                    //llMessageLinked(LINK_THIS, HTTPDB_DELETE, extoken, NULL_KEY);
                    AcceptOwnerTPs("rem");
                    /* //no more needed
                        llResetScript();
                    */
                    }
                else if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
                {//added for short chat-menu command
                    if (llToLower(str) == "tp")
                    {
                        Menu(id);
                        return;
                    }
                    //do simple pass through for chat commands

                    //since more than one RLV command can come on the same line, loop through them
                    list items = llParseString2List(str, [","], []);
                    integer n;
                    integer stop = llGetListLength(items);
                    integer change = FALSE;//set this to true if we see a setting that concerns us
                    for (n = 0; n < stop; n++)
                    {   //split off the parameters (anything after a : or =)
                        //and see if the thing being set concerns us
                        string thisitem = llList2String(items, n);
                        string behavior = llList2String(llParseString2List(thisitem, ["=", ":"], []), 0);
                        if (behavior == "tpto")
                        {
                            //if (num == COMMAND_WEARER)
                            //{
                            //    llInstantMessage(llGetOwner(), "Sorry, but RLV commands may only be given by owner, secowner, or group (if set).");
                            //    return;
                            //}
                            llMessageLinked(LINK_THIS, RLV_CMD, thisitem, NULL_KEY);
                        }
                        else if (behavior == "accepttp")
                        {
                            if (num != COMMAND_OWNER)
                            {
                                llInstantMessage(id, "Sorry, but only the Owner can set this.");
                            }
                            else
                            {
                                change = TRUE;
                                string param;
                                debug(thisitem);
                                if (llList2String(llParseString2List(thisitem, ["="], []), 1) == "n")
                                {
                                    param = "add";
                                }
                                else
                                {
                                    param = "rem";
                                }
                                integer i;
                                string test = llDumpList2String(settings, ",");
                                string option = behavior + ":" + (string)id;
                                integer replaced = FALSE;
                                for (i = 0; i < llGetListLength(settings); i = i + 2)
                                {
                                    if (llGetSubString(llList2String(settings, i), 0, 7) == behavior)
                                    {
                                        settings = llListReplaceList(settings, [option, param], i, i + 1);
                                        replaced = TRUE;
                                    }
                                }
                                if (!replaced)
                                {
                                    settings += [option, param];
                                }
                                //                        llMessageLinked(LINK_THIS, RLV_CMD, behavior + ":" + (string)id + ON, NULL_KEY);
                                debug(llDumpList2String(settings, ","));
                            }
                        }
                        else if (llListFindList(rlvcmds, [behavior]) != -1)
                        {   //this is a behavior that we handle.
                            //filter commands from wearer, if wearer is not owner
                            if (num == COMMAND_WEARER)
                            {
                                llOwnerSay("Sorry, but RLV commands may only be given by owner, secowner, or group (if set).");
                                return;
                            }

                            string option = llList2String(llParseString2List(thisitem, ["="], []), 0);
                            string param = llList2String(llParseString2List(thisitem, ["="], []), 1);
                            integer index = llListFindList(settings, [option]);
                            if (index == -1)
                            {   //we don't alread have this exact setting.  add it
                                settings += [option, param];
                            }
                            else
                            {   //we already have a setting for this option.  update it.
                                settings = llListReplaceList(settings, [option, param], index, index + 1);
                            }
                            change = TRUE;

                            //handle exceptions
                            if (llListFindList(auto_exceptions, [option]) != -1)
                            {//this is a setting for which we should automatically create an exception for the person sending the command
                                list xptn = [option, id];
                                //only add exception if not already in list
                                if (llListFindList(exceptions, xptn) == -1)
                                {
                                    exceptions += xptn;
                                }
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
                    string token = llList2String(params, 0);
                    string value = llList2String(params, 1);
                    if (token == dbtoken)
                    {
                        //throw away first element
                        //everything else is real settings (should be even number)
                        settings = llParseString2List(value, [","], []);
                        UpdateSettings();
                    }
                    else if (token == "owner")
                    {
                        AcceptOwnerTPs("rem");
                        //owner comes in form key,name, we only need key
                        owner = (key)llList2String(llParseString2List(value, [","], []), 0);
                        //send accepttp command
                        AcceptOwnerTPs("add");
                    }
                }
                else if (num == HTTPDB_SAVE)
                {
                    //handle saving new owner here
                    list params = llParseString2List(str, ["="], []);
                    string token = llList2String(params, 0);
                    string value = llList2String(params, 1);
                    if (token == "owner")
                    {
                        AcceptOwnerTPs("rem");
                        owner = (key)llList2String(llParseString2List(value, [","], []), 0);
                        AcceptOwnerTPs("add");
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
                else if (num == RLV_VERSION)
                {
                    detectedRLVersion = str;
                }
                 // rlvoff -> we have to turn the menu off too
                else if (num == RLV_OFF) rlvon=FALSE;
                // rlvon -> we have to turn the menu on again
                else if (num == RLV_ON) rlvon=TRUE;
         
          }

        timer()
        {
            llListenRemove(listener);
            llSetTimerEvent(0.0);
            returnmenu = FALSE;
        }

        listen(integer channel, string name, key id, string message)
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
                        string cmd1 = llList2String(rlvcmds, n);
                        if (cmd1 != "accepttp")
                        {
                            //prefix all but the first value with a comma, so we have a comma-separated list
                            if (n)
                            {
                                out += ",";
                            }
                            out +=  cmd1 + "=" + ONOFF;
                        }
                    }
                    llMessageLinked(LINK_THIS, COMMAND_NOAUTH, out, id);
                    returnmenu = TRUE;
                }
                else if (index != -1)
                {
                    string out = llList2String(rlvcmds, index);
                    out += "=";
                    if (switch == TURNON)
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
