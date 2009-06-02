//if list isn't blank, open listener on channel 0, with sub's key

string badwordanim = "shock";
list badwords;
string penance = "pet is very sorry for her mistake";
integer listener;

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

integer menuhandle;
integer menuchannel = -87473732;
string submenu = "Badwords";
string parentmenu = "Main";
string UPMENU = "~PrevMenu~";
string isEnabled = "badwordson=false";


integer enabled()
{
    integer index = llSubStringIndex(isEnabled, "=");
    string value = llGetSubString(isEnabled, index + 1, llStringLength(isEnabled) - 1);
    if(value == "true")
        return TRUE;
    else 
        return FALSE;
}

DialogBadwords(key id)
{
    llListenRemove(menuhandle);
    string text;
    list buttons = ["List Words", "Clear ALL", "Say Penance"];
    if(enabled())
    {
        buttons += ["OFF"];
        text += "Badwords are turned ON.\n";
    }
    else
    {
        buttons += ["ON"];
        text += "Badwords are turned OFF.\n";
    }
    text += "'List Words' show you all badwords.\n";
    text += "'Clear ALL' will delete all set badwords.\n";
    text += "'Say Penance' will tell you the current penance phrase.\n";
    text += "'Quick Help' will give you a brief help how to add or remove badwords.\n"; 
    buttons += ["Quick Help", UPMENU];
    buttons = RestackMenu(FillMenu(buttons));
    menuchannel = -(integer)(llFrand(999999.0) + 5555);
    menuhandle = llListen(menuchannel, "", id, "");
    llDialog(id, text, buttons, menuchannel);
    llSetTimerEvent(30.0);
}

DialogHelp(key id)
{
    llListenRemove(menuhandle);
    string message = "Usage of Badwords.\n";
    message += "Put in front of each command your subs prefix then use them as followed:\n";
    message += "badword <badword> where <badword> is the word you want to add.\n";
    message += "rembadword <badword> where <badword> is the word you want to remove.\n";
    message += "penance <what your sub has to say to get release from the badword anim.\n";
    message += "badwordanim <anim name> , make sure the animation is inside the collar.";
    menuchannel = -(integer)(llFrand(999999.0) + 5555);
    menuhandle = llListen(menuchannel, "", id, "");
    llDialog(id, message, ["Ok"], menuchannel);
    llSetTimerEvent(45.0);
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

ListenControl()
{
    if(enabled())
    {
        if (llGetListLength(badwords))
        {
            listener = llListen(0, "", llGetOwner(), "");
        }
    }
    else
    {
        llListenRemove(listener);
    }
}

string DePunctuate(string str)
{
    string lastchar = llGetSubString(str, -1, -1);
    if (lastchar == "," || lastchar == "." || lastchar == "!" || lastchar == "?")
    {
        str = llGetSubString(str, 0, -2);
    }    
    return str;
}

integer HasSwear(string str)
{
    str = llToLower(str);
    //llOwnerSay(str);     
    
    list words = llParseString2List(str, [" "], []);
    integer n;
    for (n = 0; n < llGetListLength(words); n++)
    {
        string word = llList2String(words, n);
        word = DePunctuate(word);
        
        if (llListFindList(badwords, [word]) != -1)
        {
            //llOwnerSay(word + " found");
            return TRUE;
        }
    }
    return FALSE;
}

ClearDB()
{
    //llMessageLinked(LINK_THIS, HTTPDB_DELETE, "badwords", NULL_KEY);
    //llMessageLinked(LINK_THIS, HTTPDB_DELETE, "penance", NULL_KEY); 
    //llMessageLinked(LINK_THIS, HTTPDB_DELETE, "badwordanim", NULL_KEY);     
}

string WordPrompt()
{
    string name = llKey2Name(llGetOwner());    
    string prompt = name + " is forbidden from saying ";
    integer length = llGetListLength(badwords);
    if (!length)
    {
        prompt = name + " is not forbidden from saying anything.";
    }
    else if (length == 1)
    {
        prompt += llList2String(badwords, 0);                    
    }
    else if (length == 2)
    {
        prompt += llList2String(badwords, 0) + " or " + llList2String(badwords, 1);
    }
    else
    {
        prompt += llDumpList2String(llDeleteSubList(badwords, -1, -1), ", ") + ", or " + llList2String(badwords, -1);
    }
    

    prompt += "\nThe penance phrase to clear the punishment anim is '" + penance + "'.";    
    return prompt;
}

default
{    
    state_entry()
    {
        //llMessageLinked(LINK_THIS, HTTPDB_REQUEST, "badwords", NULL_KEY);
        //llMessageLinked(LINK_THIS, HTTPDB_REQUEST, "penance", NULL_KEY);     
        //llMessageLinked(LINK_THIS, HTTPDB_REQUEST, "badwordanim", NULL_KEY); 
        llSleep(0.8);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);            
    }
    
    changed(integer change)
    {
         if (change & CHANGED_OWNER)
        {
            llResetScript();
        }
    }
    
    listen(integer channel, string name, key id, string message)
    {
        if(channel == menuchannel)
        {
            llListenRemove(menuhandle);
            llSetTimerEvent(0.0);
            if(message == "Ok")
                DialogBadwords(id);
            if (message == UPMENU)
            {
                //give id the parent menu
                llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);
            }
            else if(message == "Clear ALL")
            {
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "badwords clearall", id);
//                badwords = [];
//                isEnabled = "badwordson=false";
//                llMessageLinked(LINK_THIS, HTTPDB_SAVE, isEnabled, NULL_KEY);
//                ListenControl();
//                DialogBadwords(id);
//                llInstantMessage(id, "You cleared the badword list and turned it off.");
            }
            else if(message == "ON")
            {
//                if(llGetListLength(badwords))
//                {
                    llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "badwords on", id);
//                    isEnabled = "badwordson=true";
//                    llMessageLinked(LINK_THIS, HTTPDB_SAVE, isEnabled, NULL_KEY);
//                    ListenControl();
//                    llInstantMessage(id, "You turned badwords for the following words on: " + llDumpList2String(badwords, "~"));
//                }
//                else
//                    llInstantMessage(id, "There are no badwords set. Define at least one badword before turning it on.");
//                DialogBadwords(id);
            }
            else if(message == "OFF")
            {
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "badwords off", id);
//                isEnabled = "badwordson=false";
//                llListenRemove(listener);
//                llMessageLinked(LINK_THIS, HTTPDB_SAVE, isEnabled, NULL_KEY);
//                DialogBadwords(id);
//                llInstantMessage(id, "You turned badwords OFF!.");
            }
            else if(message == "List Words")
            {
                DialogBadwords(id);
                llInstantMessage(id, "Badwords are: " + llDumpList2String(badwords, " or "));
            }
            else if(message == "Say Penance")
            {
                DialogBadwords(id);
                llInstantMessage(id, "The penance phrase to release the sub from the punishment anim is: " + penance);
            }
            else if(message == "Quick Help")
                DialogHelp(id);
            
        }
        //release anim if penance
        //play anim if swear  
        else
        {      
            if (~llSubStringIndex(llToLower(message), llToLower(penance)))
            {
                //stop anim
                llMessageLinked(LINK_THIS, ANIM_STOP, badwordanim, NULL_KEY);
                llInstantMessage(llGetOwner(), "Penance accepted.");            
            }
            else if (HasSwear(message))
            {                     
                //start anim
                llMessageLinked(LINK_THIS, ANIM_START, badwordanim, NULL_KEY);
                llInstantMessage(llGetOwner(), "You said a bad word!");            
            }      
        }  
    }
    
    link_message(integer sender, integer num, string str, key id)
    {
        if (num == HTTPDB_RESPONSE)
        {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if(token == "badwordson")
            {
                isEnabled = "badwordson" + "=" + value;;
            }      
            if (token == "badwordanim")
            {                    
                badwordanim = value;
                //llInstantMessage(llGetOwner(), "Loaded bad word anim '" + badwordanim + "' from database.");                  
            }
            else if (token == "badwords")
            {
                badwords = llParseString2List(value, ["~"], []);
                //if (llGetListLength(badwords))
                //{
                //    llInstantMessage(llGetOwner(), "Loaded bad words '" + llDumpList2String(badwords, ", ") + "' from database.");                    
                //}
                ListenControl();
            }               
            else if (token == "penance")
            {
                penance = value;
                //llInstantMessage(llGetOwner(), "Loaded penance phrase '" + penance + "' from database.");                                    
            } 
        }        
        else if ((num == COMMAND_OWNER || num == COMMAND_WEARER) && (str == "reset" || str == "runaway"))
        {
            //ClearDB();
            llResetScript();
        }
        else if (num >= COMMAND_OWNER && num <= COMMAND_WEARER && str == "settings")
        {
            llInstantMessage(id, "Bad Words: " + llDumpList2String(badwords, ", "));                        
            llInstantMessage(id, "Bad Word Anim: " + badwordanim);
            llInstantMessage(id, "Penance: " + penance);
        }
        else if (num == SUBMENU && str == submenu)
        {
            DialogBadwords(id);
        }
        else if (num == COMMAND_OWNER)
        {
            list params = llParseString2List(str, [" "], []);
            string command = llList2String(params, 0);
            string value = llList2String(params, 1);
            if(str == "badwords")
                DialogBadwords(id);
            else if (command == "badword")
            {
                //support owner adding words
                integer oldlength = llGetListLength(badwords);
                list newbadwords = llDeleteSubList(llParseString2List(str, [" "], []), 0, 0);
                integer n;
                integer length = llGetListLength(newbadwords);
                for (n = 0; n < length; n++)
                {
                    //add new swear if not already in list
                    string new = llList2String(newbadwords, n);
                    new = DePunctuate(new);
                    if (llListFindList(badwords, [new]) == -1)
                    {
                        badwords += [new];
                    }
                }
                integer newlength = llGetListLength(badwords);
                if(!oldlength && newlength)
                {
                    isEnabled = "badwordson=true";
                    llMessageLinked(LINK_THIS, HTTPDB_SAVE, isEnabled, NULL_KEY);
                }
                //save to database
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "badwords=" + llDumpList2String(badwords, "~"), NULL_KEY);
                ListenControl();

                //Popup(llGetOwner(), prompt);
                llInstantMessage(id, WordPrompt());     
                if (id != llGetOwner())
                {
                    llInstantMessage(llGetOwner(), WordPrompt());
                }                                         
            }
            else if (command == "badwordanim")
            {
                if (llGetInventoryType(llList2String(params, 1)) == INVENTORY_ANIMATION)
                {
                    badwordanim = llList2String(params, 1);
                    llMessageLinked(LINK_THIS, HTTPDB_SAVE, "badwordanim=" + badwordanim, NULL_KEY);
                    llInstantMessage(id, "Punishment anim for bad words is now " + badwordanim + ".");
                }
                else
                {
                    llInstantMessage(id, llList2String(params, 1) + " is not a valid animation name.");                    
                }
            }
            else if (command == "penance")
            {
                penance = llDumpList2String(llDeleteSubList(params, 0, 0), " ");
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "penance=" + penance, NULL_KEY);
                string prompt = WordPrompt();
                llInstantMessage(id, prompt);
                if (id != llGetOwner())
                {
                    llInstantMessage(llGetOwner(), prompt);
                }
            }
            else if (command == "rembadword")
            {
                //support owner adding words
                list rembadwords = llDeleteSubList(llParseString2List(str, [" "], []), 0, 0);
                integer n;
                integer length = llGetListLength(rembadwords);
                for (n = 0; n < length; n++)
                {
                    //add new swear if not already in list
                    string rem = llList2String(rembadwords, n);
                    integer index = llListFindList(badwords, [rem]);
                    if (index != -1)
                    {
                        badwords = llDeleteSubList(badwords, index, index);
                    }
                }
                //save to database
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "badwords=" + llDumpList2String(badwords, "~"), NULL_KEY);
                ListenControl();

                //Popup(llGetOwner(), prompt);
                llInstantMessage(id, WordPrompt());     
                if (id != llGetOwner())
                {
                    llInstantMessage(llGetOwner(),  WordPrompt());
                }                    
            }
            else if (command == "badwords")
            {
                if(value == "on")
                {
                    if(llGetListLength(badwords))
                    {
                        isEnabled = "badwords=true";
                        llMessageLinked(LINK_THIS, HTTPDB_SAVE, "badwords=" + isEnabled, NULL_KEY);
                        ListenControl();
                        llInstantMessage(id, "Badwords are now turned on for: " + llDumpList2String(badwords, "~"));
                    }
                    else
                        llInstantMessage(id, "There are no badwords set. Define at least one badword before turning it on.");

                }
                else if(value == "off")
                {
                    isEnabled = "badwords=false";
                    llMessageLinked(LINK_THIS, HTTPDB_SAVE, "badwords=" + isEnabled, NULL_KEY);
                    ListenControl();
                    llInstantMessage(id, "Badwords are now turned off.");
                }
                else if(value == "clearall")
                {
                    badwords = [];
                    isEnabled = "badwordson=false";
                    llMessageLinked(LINK_THIS, HTTPDB_SAVE, isEnabled, NULL_KEY);
                    ListenControl();
                    DialogBadwords(id);
                    llInstantMessage(id, "You cleared the badword list and turned it off.");
                }
            }
        }
    }
    timer()
    {
        llListenRemove(menuhandle);
        llSetTimerEvent(0.0);
    }
}
