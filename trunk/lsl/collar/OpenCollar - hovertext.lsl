string parentmenu = "Help/Debug";
string submenu = "FloatText";

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
integer SEND_IM = 1000;
integer POPUP_HELP = 1001;

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

ShowText(string newtext, integer rank)
{ 
    text = newtext;
    lastrank = rank;
    llSetText(text, color, 1.0);
    llSetScale(showscale);    
    on = TRUE;
    
}

HideText()
{
    llSetText("", <1,1,1>, 1.0);
    llSetScale(hidescale); 
    on = FALSE;
}

default
{
    state_entry()
    {
        color = llGetColor(ALL_SIDES);
        HideText();
        llMessageLinked(LINK_SET, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);          
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
                            ShowText(newtext, auth);                            
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
                        ShowText(newtext, auth);                    
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
                        HideText();
                    }
                }
                else
                {
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
            llMessageLinked(LINK_SET, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        else if (auth == SUBMENU && str == submenu)
        {
            //popup help on how to set label
            llMessageLinked(LINK_SET, POPUP_HELP, "To set floating text , say _PREFIX_text followed by the text you wish to set.  \nExample: _PREFIX_text I have text above my head!", id);
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
                ShowText(text, lastrank);
            }
        }
    }
}
