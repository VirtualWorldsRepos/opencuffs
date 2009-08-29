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

ShowText(string newtext)
{ 
    text = newtext;
    llSetText(text, color, 1.0);
    if (llGetLinkNumber() > 1)
    {//don't scale the root prim
        llSetScale(showscale);
    }
    on = TRUE;
}

HideText()
{
    llSetText("", <1,1,1>, 1.0);
    if (llGetLinkNumber() > 1)
    {
        llSetScale(hidescale);
    }
    on = FALSE;
    llMessageLinked(LINK_ROOT, HTTPDB_SAVE, dbtoken + "=off", NULL_KEY); 
}

CleanPrim()
{
    integer i;
    for (i = 0; i  < llGetInventoryNumber(INVENTORY_SCRIPT); i++)
    {
        if (llGetInventoryName(INVENTORY_SCRIPT, i) != llGetScriptName())
        {
            llRemoveInventory(llGetInventoryName(INVENTORY_SCRIPT, i));
        }
    }
    llRemoveInventory(llGetScriptName());
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
                llRemoveInventory(llList2String(scripts, i));
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
    { /* //debugging
        llOwnerSay(llGetScriptName() + " in prim #" + (string)llGetLinkNumber() + " started.");
        if( llGetStartParameter() == 42)
        {
            llOwnerSay(llGetScriptName() + " in prim #" + (string)llGetLinkNumber() + " stopping myself.");
            llSetScriptState(llGetScriptName(), FALSE);
            llOwnerSay(llGetScriptName() + " in prim #" + (string)llGetLinkNumber() + " this should not show.");
        }
        */
        color = llGetColor(ALL_SIDES);
        HideText();
        llMessageLinked(LINK_ROOT, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);          
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
                            HideText();
                        }
                        else
                        {
                            ShowText(newtext);
                            lastrank = auth;
                            llMessageLinked(LINK_ROOT, HTTPDB_SAVE, dbtoken + "=on:" + (string)auth + ":" + newtext, NULL_KEY);
                        }
                    }
                }
                else
                {
                    //set text
                    if (newtext == "")
                    {
                        HideText();
                    }
                    else
                    {
                        ShowText(newtext);
                        lastrank = auth;
                        llMessageLinked(LINK_ROOT, HTTPDB_SAVE, dbtoken + "=on:" + (string)auth + ":" + newtext, NULL_KEY);
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
                        lastrank = 0;
                        HideText();
                    }
                }
                else
                {
                    lastrank = 0;
                    HideText();
                }
            }
            else if (str == "reset" && (auth == COMMAND_OWNER || auth == COMMAND_WEARER))            
            {
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
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            if (token == dbtoken)
            {
                token = llGetSubString(str, llStringLength(token) + 1, -1);
                params = [] + llParseString2List(token, [":"], []);
                
                string status = llList2String(params, 0);
                if(status == "on")
                {
                    auth = (integer)llList2String(params, 1);
                    params = llDeleteSubList(params, 0, 1);
                    text = llDumpList2String(params, ":");
                    ShowText(text);
                    lastrank = auth;   
                }
                else
                {
                    lastrank = 0;
                    HideText();
                }
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
