//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//if list isn't blank, open listener on channel 0, with sub's key <== only for the first badword???

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
integer COMMAND_SAFEWORD = 510;  // new for safeword

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

key wearer;

integer menuhandle;
integer menuchannel = -87473732;
string submenu = "Badwords";
string parentmenu = "Main";
//string UPMENU = "↑";
//string MORE = "→";
string UPMENU = "^";
string isEnabled = "badwordson=false";

//added to stop abdword anim only if it was started by using a badword
integer hasSworn = FALSE;


debug(string msg)
{
    //Notify(wearer,llGetScriptName() + ": " + msg,TRUE);
}

integer enabled()
{
    integer index = llSubStringIndex(isEnabled, "=");
    string value = llGetSubString(isEnabled, index + 1, llStringLength(isEnabled) - 1);
    if(value == "true")
    {
        return TRUE;
    }
    else
    {
        return FALSE;
    }
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
    buttons = RestackMenu(buttons);
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
        in = llDeleteSubList(in, u, u );
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

ListenControl()
{
    if(enabled())
    {
        if (llGetListLength(badwords))
        {
            listener = llListen(0, "", wearer, "");
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
    list words = llParseString2List(str, [" "], []);
    integer n;
    for (n = 0; n < llGetListLength(words); n++)
    {
        string word = llList2String(words, n);
        word = DePunctuate(word);
        
        if (llListFindList(badwords, [word]) != -1)
        {
            return TRUE;
        }
    }
    return FALSE;
}

integer contains(string haystack, string needle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return 0 <= llSubStringIndex(haystack, needle);
}

string WordPrompt()
{
    string name = llKey2Name(wearer);    
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

string right(string src, string divider) {
    integer index = llSubStringIndex( src, divider );
    if(~index)
        return llDeleteSubString( src, 0, index + llStringLength(divider) - 1);
    return src;
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
{     /* // no more needed
    state_entry()
    {
        llSleep(0.8);
        llMessageLinked(LINK_SET, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
    }
*/
    on_rez(integer param)
    {
        llResetScript();
    }
    
    state_entry()
    {
        wearer=llGetOwner();
    }
    
    listen(integer channel, string name, key id, string message)
    {
        if(channel == menuchannel)
        {
            llListenRemove(menuhandle);
            llSetTimerEvent(0.0);
            if(message == "Ok")
            {
                DialogBadwords(id);
            }
            if (message == UPMENU)
            {    //give id the parent menu
                llMessageLinked(LINK_SET, SUBMENU, parentmenu, id);
            }
            else if(message == "Clear ALL")
            {
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "badwords clearall", id);
            }
            else if(message == "ON")
            {
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "badwords on", id);
            }
            else if(message == "OFF")
            {
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "badwords off", id);
            }
            else if(message == "List Words")
            {
                DialogBadwords(id);
                Notify(id, "Badwords are: " + llDumpList2String(badwords, " or "),FALSE);
            }
            else if(message == "Say Penance")
            {
                DialogBadwords(id);
                Notify(id, "The penance phrase to release the sub from the punishment anim is:\n" + penance,FALSE);
            }
            else if(message == "Quick Help")
                DialogHelp(id);
            
        }
        //release anim if penance & play anim if swear  
        else if (channel == 0)
        {      
            if (~llSubStringIndex(llToLower(message), llToLower(penance)) && hasSworn )
            { //stop anim
                llMessageLinked(LINK_SET, ANIM_STOP, badwordanim, NULL_KEY);
                Notify(wearer, "Penance accepted.",FALSE);
                hasSworn = FALSE;        
            }
            else if (contains(message, "rembadword"))
            {//subs could theoretically circumvent this feature by sticking "rembadowrd" in all chat, but it doesn't seem likely to happen often
                return;
            }
            else if (HasSwear(message))
            {   //start anim
                llMessageLinked(LINK_SET, ANIM_START, badwordanim, NULL_KEY);
                llWhisper(0, llList2String(llParseString2List(llKey2Name(wearer), [" "], []), 0) + " has said a bad word and is being punished.");
                hasSworn = TRUE;        
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
            }
            else if (token == "badwords")
            {
                badwords = llParseString2List(llToLower(value), ["~"], []);
                ListenControl();
            }               
            else if (token == "penance")
            {
                penance = value;
            } 
        }
         /* // no more self - resets     
        else if ((num == COMMAND_OWNER || num == COMMAND_WEARER) && (str == "reset" || str == "runaway"))
        {
            llResetScript();
        }
        */
        else if (num >= COMMAND_OWNER && num <= COMMAND_WEARER && str == "settings")
        {
            Notify(id, "Bad Words: " + llDumpList2String(badwords, ", "),FALSE);                        
            Notify(id, "Bad Word Anim: " + badwordanim,FALSE);
            Notify(id, "Penance: " + penance,FALSE);
        }
        else if (num == SUBMENU && str == submenu)
        {
            DialogBadwords(id);
        }
        else if(num > COMMAND_OWNER && num <= COMMAND_EVERYONE)
        {
            list params = llParseString2List(str, [" "], []);
            string command = llList2String(params, 0);
            if(command == "badwords")
            {
                Notify(id, "Sorry, only the owner can toggle badwords.",FALSE);
            }
        }
        else if (num == COMMAND_OWNER)
        {
            list params = llParseString2List(str, [" "], []);
            string command = llList2String(params, 0);
            string value = llList2String(params, 1);
            if(str == "badwords")
            {
                DialogBadwords(id);
            }
            else if (command == "badword")
            {
                //support owner adding words
                integer oldlength = llGetListLength(badwords);
                list newbadwords = llDeleteSubList(llParseString2List(str, [" "], []), 0, 0);
                integer n;
                integer length = llGetListLength(newbadwords);
                for (n = 0; n < length; n++)
                {  //add new swear if not already in list
                    string new = llList2String(newbadwords, n);
                    new = DePunctuate(new);
                    new = llToLower(new);
                    if (llListFindList(badwords, [new]) == -1)
                    {
                        badwords += [new];
                    }
                }
                integer newlength = llGetListLength(badwords);
                if(!oldlength && newlength)
                {
                    isEnabled = "badwordson=true";
                    llMessageLinked(LINK_SET, HTTPDB_SAVE, isEnabled, NULL_KEY);
                }
                //save to database
                llMessageLinked(LINK_SET, HTTPDB_SAVE, "badwords=" + llDumpList2String(badwords, "~"), NULL_KEY);
                ListenControl();
                Notify(id, WordPrompt(),TRUE);                                       
            }
            else if (command == "badwordanim")
            {
                //Get all text after the command, strip spaces from start and end
                string anim = right(str, command);
                anim = llStringTrim(anim, STRING_TRIM);
                
                if (llGetInventoryType(anim) == INVENTORY_ANIMATION)
                {
                    badwordanim = anim;
                    //debug(badwordanim);
                    llMessageLinked(LINK_SET, HTTPDB_SAVE, "badwordanim=" + badwordanim, NULL_KEY);
                    Notify(id, "Punishment anim for bad words is now '" + badwordanim + "'.",FALSE);
                }
                else
                {
                    Notify(id, llList2String(params, 1) + " is not a valid animation name.",FALSE);                    
                }
            }
            else if (command == "penance")
            {
                penance = llDumpList2String(llDeleteSubList(params, 0, 0), " ");
                llMessageLinked(LINK_SET, HTTPDB_SAVE, "penance=" + penance, NULL_KEY);
                string prompt = WordPrompt();
                Notify(id, prompt,TRUE);

            }
            else if (command == "rembadword")
            {    //support owner adding words
                list rembadwords = llDeleteSubList(llParseString2List(str, [" "], []), 0, 0);
                integer n;
                integer length = llGetListLength(rembadwords);
                for (n = 0; n < length; n++)
                {  //add new swear if not already in list
                    string rem = llList2String(rembadwords, n);
                    integer index = llListFindList(badwords, [rem]);
                    if (index != -1)
                    {
                        badwords = llDeleteSubList(badwords, index, index);
                    }
                }
                //save to database
                llMessageLinked(LINK_SET, HTTPDB_SAVE, "badwords=" + llDumpList2String(badwords, "~"), NULL_KEY);
                ListenControl();
                Notify(id, WordPrompt(),TRUE);             
            }
            else if (command == "badwords")
            {
                if(value == "on")
                {
                    if(llGetListLength(badwords))
                    {
                        isEnabled = "badwordson=true";
                        llMessageLinked(LINK_SET, HTTPDB_SAVE, isEnabled, NULL_KEY);
                        //llMessageLinked(LINK_SET, HTTPDB_SAVE, "badwords=" + isEnabled, NULL_KEY);
                        ListenControl();
                        Notify(id, "Badwords are now turned on for: " + llDumpList2String(badwords, "~"),FALSE);
                    }
                    else
                        Notify(id, "There are no badwords set. Define at least one badword before turning it on.",FALSE);

                }
                else if(value == "off")
                {
                    isEnabled = "badwordson=false";
                    llMessageLinked(LINK_SET, HTTPDB_SAVE, isEnabled, NULL_KEY);
                    ListenControl();
                    Notify(id, "Badwords are now turned off.",FALSE);
                }
                else if(value == "clearall")
                {
                    badwords = [];
                    isEnabled = "badwordson=false";
                    llMessageLinked(LINK_SET, HTTPDB_SAVE, isEnabled, NULL_KEY);
                    llMessageLinked(LINK_SET, HTTPDB_SAVE, "badwords=", NULL_KEY);
                    ListenControl();
                    DialogBadwords(id);
                    Notify(id, "You cleared the badword list and turned it off.",FALSE);
                }
            }
        }
        else if(num == COMMAND_SAFEWORD)
        { // safeword disables badwords !
            isEnabled = "badwords=false";
            llMessageLinked(LINK_SET, HTTPDB_SAVE, isEnabled, NULL_KEY);
            ListenControl();
        }
        else if (num == MENUNAME_REQUEST)
        {
            if (str == parentmenu)
            {
                llMessageLinked(LINK_SET, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
            }
        }
    }
    
    timer()
    {
        llListenRemove(menuhandle);
        llSetTimerEvent(0.0);
    }
}
