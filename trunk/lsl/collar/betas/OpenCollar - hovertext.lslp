string parentmenu = "Help/Debug";
string submenu = "FloatText";

//has to be same as in the update script !!!!
integer updatePin = 4711;

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
integer SEND_IM = 1000;
integer POPUP_HELP = 1001;
integer UPDATE = 10001;

integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
                            //str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;

vector hidescale = <.02,.02,.02>;
vector showscale = <.02,.02,1.0>;

integer lastrank = 0;
integer on = FALSE;
string text;
vector color;

string dbtoken = "hovertext";

debug(string msg)
{
    //llOwnerSay(llGetScriptName() + " (debug): " + msg);
}

SafeRemoveInventory(string item)
{
    if (llGetInventoryType(item) != INVENTORY_NONE)
    {
        llRemoveInventory(item);
    }
}

ShowText(string newtext)
{ 
    text = newtext;
    list tmp = llParseString2List(text, ["\\n"], []);
    if(llGetListLength(tmp) > 1)
    {
        integer i;
        newtext = "";
        for (i = 0; i < llGetListLength(tmp); i++)
        {
            newtext += llList2String(tmp, i) + "\n";
        }
    }
    llSetText(newtext, color, 1.0);
    if (llGetLinkNumber() > 1)
    {//don't scale the root prim
        llSetScale(showscale);
    }
    on = TRUE;
}

HideText()
{
    debug("hide text");
    llSetText("", <1,1,1>, 1.0);
    if (llGetLinkNumber() > 1)
    {
        llSetScale(hidescale);
    }
    on = FALSE;
    //    if (text!="")
    //    {
    //        llMessageLinked(LINK_ROOT, HTTPDB_SAVE, dbtoken + "=off:" + (string)lastrank + ":" + llEscapeURL(text), NULL_KEY);
    //    }
    //    else
    //    {
    //        llMessageLinked(LINK_ROOT, HTTPDB_DELETE, dbtoken, NULL_KEY);
    //    }
    
}

CleanPrim()
{
    integer i;
    for (i = 0; i  < llGetInventoryNumber(INVENTORY_SCRIPT); i++)
    {
        if (llGetInventoryName(INVENTORY_SCRIPT, i) != llGetScriptName())
        {
            SafeRemoveInventory(llGetInventoryName(INVENTORY_SCRIPT, i));
        }
    }
    SafeRemoveInventory(llGetScriptName());
}
CleanUp()
{
    integer i;
    list scripts;
    for (i = 0; i < llGetInventoryNumber(INVENTORY_SCRIPT); i++)
    {
        scripts += [llGetInventoryName(INVENTORY_SCRIPT, i)];
    }
    for (i = 0 ; i < llGetListLength(scripts); i++)
    {
        string script1;
        string script2;
        float version1;
        float version2;
        list temp;
        temp = llParseString2List(llList2String(scripts, i), [" - "], []);
        script1 =  llList2String(temp, 1);
        version1 = (float)llList2String(temp, 2);
        temp = [] + llParseString2List(llList2String(scripts, i + 1), [" - "], []);
        script2 = llList2String(temp, 1);
        version2 = (float)llList2String(temp, 2);
        if(script1 == script2)
        {
            if (llGetInventoryType(llList2String(scripts, i)) != INVENTORY_NONE)
            {
                SafeRemoveInventory(llList2String(scripts, i));
            }
        }
    }
    for (i = 0; i < llGetInventoryNumber(INVENTORY_SCRIPT); i++)
    {
        string name = llGetInventoryName(INVENTORY_SCRIPT, i);
        if (name != llGetScriptName())
        {
            if(llGetInventoryType(name) == INVENTORY_SCRIPT)
            {
                llResetOtherScript(name);
            }
        }
    }
    llResetScript();
}
default
{
    state_entry()
    { 
        color = llGetColor(ALL_SIDES);
        llSetText("", <1,1,1>, 0.0);
        if (llGetLinkNumber() > 1)
        {
            llSetScale(hidescale);
        }
        llMessageLinked(LINK_ROOT, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);          
    }
    on_rez(integer start)
    {
        if(on && text != "")
        {
            ShowText(text);
        }
        else
        {
            llSetText("", <1,1,1>, 0.0);
            if (llGetLinkNumber() > 1)
            {
                llSetScale(hidescale);
            }
        }
    }
    link_message(integer sender, integer auth, string str, key id)
    {
        list params = llParseString2List(str, [" "], []);
        string command = llList2String(params, 0);
        if (auth >= COMMAND_OWNER && auth <= COMMAND_WEARER)
        {
            if (command == "text")
            {
                //llSay(0, "got text command");
                params = llDeleteSubList(params, 0, 0);//pop off the "text" command
                string newtext = llDumpList2String(params, " ");       
                if (on)
                {
                    //only change text if commander has smae or greater auth
                    if (auth <= lastrank)
                    {
                        if (newtext == "")
                        {
                            text = "";
                            HideText();
                        }
                        else
                        {
                            ShowText(newtext);
                            lastrank = auth;
                            //llMessageLinked(LINK_ROOT, HTTPDB_SAVE, dbtoken + "=on:" + (string)auth + ":" + llEscapeURL(newtext), NULL_KEY);
                        }
                    }
                }
                else
                {
                    //set text
                    if (newtext == "")
                    {
                        text = "";
                        HideText();
                    }
                    else
                    {
                        ShowText(newtext);
                        lastrank = auth;
                        //llMessageLinked(LINK_ROOT, HTTPDB_SAVE, dbtoken + "=on:" + (string)auth + ":" + llEscapeURL(newtext), NULL_KEY);
                    }
                }                
            }
            else if (command == "textoff")
            {
                if (on)
                {
                    //only turn off if commander auth is >= lastrank
                    if (auth <= lastrank)
                    {
                        lastrank = COMMAND_WEARER;
                        HideText();
                    }
                }
                else
                {
                    lastrank = COMMAND_WEARER;
                    HideText();
                }
            }
            else if (command == "texton")
            {
                if( text != "")
                {
                    lastrank = auth;
                    ShowText(text);
                }
            }
            else if (str == "reset" && (auth == COMMAND_OWNER || auth == COMMAND_WEARER))            
            {
                text = "";
                HideText();
                llResetScript();
            }
        }
        else if (auth == MENUNAME_REQUEST)
        {
            llMessageLinked(LINK_ROOT, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        else if (auth == SUBMENU && str == submenu)
        {
            //popup help on how to set label
            llMessageLinked(LINK_ROOT, POPUP_HELP, "To set floating text , say _PREFIX_text followed by the text you wish to set.  \nExample: _PREFIX_text I have text above my head!", id);
        }
        else if (auth == HTTPDB_RESPONSE)
        {
            params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            debug("token: " + token);
            if (token == dbtoken)
        {
            // no more storing or restoring of text in the db
            //                token = llGetSubString(str, llStringLength(token) + 1, -1);
            //                params = [] + llParseString2List(token, [":"], []);
            //
            //                string status = llList2String(params, 0);
            //                debug("Status: " + status);
            //                if(status == "on")
            //                {
            //                    auth = (integer)llList2String(params, 1);
            //                    params = llDeleteSubList(params, 0, 1);
            //                    text = llUnescapeURL( llDumpList2String(params, ":"));
            //                    ShowText(text);
            //                    lastrank = auth;
            //                }
            //                else
            //                {
            //                    lastrank = COMMAND_WEARER;
            //                    HideText();
            //                }

            // but kil any entries in the db to clean the house

                llMessageLinked(LINK_ROOT, HTTPDB_DELETE, dbtoken , NULL_KEY);
            }            
        }
        else if (auth == UPDATE)
        {
            if(str == "prepare")
            {
                llSetRemoteScriptAccessPin(updatePin);
                string scriptName = llList2String(llParseString2List(llGetScriptName(), [" - "], []), 1);
                llMessageLinked(LINK_ROOT, UPDATE, scriptName + "|" + (string)updatePin, llGetKey());
            }
            else if(str == "reset")
            {
                llSetRemoteScriptAccessPin(0);
                CleanUp();
            }
            else if(str == "cleanup prim")
            {
                CleanPrim();
            }
        }
    }
    
    changed(integer change)
    {
        if (change & CHANGED_OWNER)
        {
            llResetScript();
        }
        
        if (change & CHANGED_COLOR)
        {
            color = llGetColor(ALL_SIDES);
            if (on)
            {
                ShowText(text);
            }
        }
    }
}
