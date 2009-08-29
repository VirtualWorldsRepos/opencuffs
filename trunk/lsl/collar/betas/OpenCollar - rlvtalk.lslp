//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
string parentmenu = "RLV";
string submenu = "Talk";
string dbtoken = "rlvtalk";
string extoken = "rlvtalkex";

list settings;//2-strided list in form of [option, param]
list exceptions;//2-strided list in form of [option, uuid]
list removexptns;//2-strided list in form of [option, uuid], of exceptions that need to be removed.  cleared after being sent to main rlv script

list rlvcmds = [
    "sendchat",
    "chatshout",
    "chatnormal",
    "sendim",
    "recvchat",
    "recvim",
    "emote",
    "recvemote"
        ];

list prettycmds = [ //showing menu-friendly command names for each item in rlvcmds
    "Chat",
    "Shouting",
    "Normal",
    "IM",
    "RcvChat",
    "RcvIM",
    "Emote",
    "RcvEmote"
        ];

list descriptions = [ //showing descriptions for commands
    "Ability to Send Chat",
    "Ability to Shout Chat",
    "Disable = Forced whisper",
    "Ability to Send IM",
    "Ability to Receive Chat",
    "Ability to Receive IM",
    "Allowed length of Emotes",
    "Ability to Receive Emote"
        ];

list auto_exceptions = [//when these restrictions are enabled, an exception will
    "sendim",               //automatically be made for the person giving the command
    "recvchat",
    "recvim",
    "recvemote"
        ];

string TURNON = "Allow";
string TURNOFF = "Forbid";

integer timeout = 60;
integer menuchannel = 987345;
integer listener;
integer returnmenu = FALSE;

integer rlvon=FALSE;

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
    //llOwnerSay(llGetScriptName() + ": " + msg);
    //llInstantMessage(llGetOwner(), llGetScriptName() + ": " + msg);
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
    string prompt = "Pick an option";
    prompt += "\n(Menu willl expire in " + (string)timeout + " seconds.)";
    prompt += "\nCurrent Settings: ";
    list buttons;
    //debug(llDumpList2String(settings, ","));
    integer n;
    integer stop = llGetListLength(rlvcmds);

    //Default to hide emote, chatnormal(forced whisper) and chatshout(ability to shout).
    //If they are allowed, they will be set to TRUE in the following block
    integer show_chatnormal  = FALSE;
    integer show_chatshout   = FALSE;
    integer show_emote       = FALSE;
    if (llList2String(settings, (llListFindList(settings, ["sendchat"])+1)) == "n"){
        //debug("hide chatshout and chatnormal");
        show_emote = TRUE;
    }
    else {
        //debug("show chatnormal");
        show_chatnormal = TRUE;

        if (llList2String(settings, (llListFindList(settings, ["chatnormal"])+1)) == "n"){
            //debug("hide chatshout");
        }
        else {
            //debug("show chatshout");
            show_chatshout   = TRUE;
        }
    }
    //

    for (n = 0; n < stop; n++)
    {
        //Check if current value should even be processed
        if (
             (llList2String(rlvcmds, n) == "chatnormal" && !show_chatnormal)
             ||
             (llList2String(rlvcmds, n) == "chatshout" && !show_chatshout)
             ||
             (llList2String(rlvcmds, n) == "emote" && !show_emote)
           )
        {
            //debug("skipping: "+llList2String(rlvcmds, n));
        }
        else
        {
            //Process as usual....

            //see if there's a setting for this in the settings list
            string cmd = llList2String(rlvcmds, n);
            string pretty = llList2String(prettycmds, n);
            string desc = llList2String(descriptions, n);
            integer index = llListFindList(settings, [cmd]);

            if (index == -1)
            {
                //if this cmd not set, then give button to enable
                if (pretty=="Emote"){
                    //When sendchat='n' then emote defaults to short mode (rem), so you allow long emotes(add)......
                    prompt += "\n" + pretty + " = Short (" + desc + ")";
                    buttons += [TURNON + " " + llList2String(prettycmds, n)];
                }
                else
                {
                    prompt += "\n" + pretty + " = Enabled (" + desc + ")";
                    buttons += [TURNOFF + " " + llList2String(prettycmds, n)];
                }
                
            }
            else
            {
                //else this cmd is set, then show in prompt, and make button do opposite
                //get value of setting
                string value1 = llList2String(settings, index + 1);

                //For some odd reason, the emote command uses add (short;16 char max) and rem (no limit)
                if (value1 == "y" || (pretty=="Emote" && value1 == "add"))
                {
                    {
                        if (pretty=="Emote") {
                            prompt += "\n" + pretty + " = Long (" + desc + ")";
                        }
                        else {
                            prompt += "\n" + pretty + " = Enabled (" + desc + ")";
                        }
                        
                        buttons += [TURNOFF + " " + llList2String(prettycmds, n)];
                    }
                }
                else if (value1 == "n" || (pretty=="Emote" && value1 == "rem"))
                {
                    {
                        if (pretty=="Emote") {
                            prompt += "\n" + pretty + " = Short (" + desc + ")";
                        }
                        else {
                            prompt += "\n" + pretty + " = Disabled (" + desc + ")";
                        }
                        
                        buttons += [TURNON + " " + llList2String(prettycmds, n)];
                    }
                }
            }
            //end process as usual
        }
    }
    //give an Allow All button
    buttons += [TURNON + " All"];
    buttons += [TURNOFF + " All"];
    buttons += [UPMENU];
    buttons = RestackMenu(buttons);
    menuchannel = - llRound(llFrand(9999999.0)) - 99999;
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
        list temp_settings;
        string out;
        integer n;
        list newlist;
        for (n = 0; n < settingslength; n = n + 2)
        {
            string token = llList2String(settings, n);
            string value = llList2String(settings, n + 1);

            if (token == "emote")
            {
                if (value == "y")
                {
                    value = "add";
                }
                else if (value == "n")
                {
                    value = "rem";
                }
            }

            newlist += [token + "=" + value];
            if (value!="y")
            {
                temp_settings+=[token,value];
            }
        }
        out = llDumpList2String(newlist, ",");
        //output that string to viewer
        llMessageLinked(LINK_THIS, RLV_CMD, out, NULL_KEY);
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
}

SaveSettings()
{
    //save to DB
    if (llGetListLength(settings)>0)
        llMessageLinked(LINK_THIS, HTTPDB_SAVE, dbtoken + "=" + llDumpList2String(settings, ","), NULL_KEY);
    else
        llMessageLinked(LINK_THIS, HTTPDB_DELETE, dbtoken, NULL_KEY);
}

ClearSettings()
{
    //clear settings list
    settings = [];
    //remove tpsettings from DB
    llMessageLinked(LINK_THIS, HTTPDB_DELETE, dbtoken, NULL_KEY);
    //main RLV script will take care of sending @clear to viewer
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

default
{
        state_entry()
        {
            wearer = llGetOwner();

            //llSleep(1.0);
            //llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
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
            /* //no more needed
                else if ((str == "reset" || str == "runaway") && (num == COMMAND_OWNER || num == COMMAND_WEARER))
                {
                    //clear db, reset script
                    llMessageLinked(LINK_THIS, HTTPDB_DELETE, dbtoken, NULL_KEY);
                    llMessageLinked(LINK_THIS, HTTPDB_DELETE, extoken, NULL_KEY);
                    llResetScript();
                }
            */
                else if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
                {//added for short chat-menu command
                    if (llToLower(str) == "talk")
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
                    {
                        //split off the parameters (anything after a : or =)
                        //and see if the thing being set concerns us
                        string thisitem = llList2String(items, n);
                        string behavior = llList2String(llParseString2List(thisitem, ["=", ":"], []), 0);
                        if (llListFindList(rlvcmds, [behavior]) != -1)
                        {
                            //this is a behavior that we handle.

                            //filter commands from wearer
                            if (num == COMMAND_WEARER)
                            {
                                llOwnerSay("Sorry, but RLV commands may only be given by owner, secowner, or group (if set).");
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

                            //handle exceptions
                            if (llListFindList(auto_exceptions, [option]) != -1)
                            {
                                //this is a setting for which we should automatically create an exception for the person sending the command
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
