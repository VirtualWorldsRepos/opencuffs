//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//listener

integer listenchannel = 1;
integer listenChannel0 = TRUE;
string prefix = ".";
integer objectchannel = -1812221819;
integer lockmeisterchannel = -8888;

integer listener1;
integer listener2;
integer objectlistener;
integer lockmeisterlistener;

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
integer COMMAND_COLLAR = 499;
//integer CHAT = 505; //deprecated.  Too laggy to make every single script parse a link message any time anyone says anything
integer COMMAND_OBJECT = 506;
integer COMMAND_RLV_RELAY = 507;
integer COMMAND_SAFEWORD = 510;  // new for safeword
//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bt of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
                            //str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent when a token has no value in the httpdb

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;

//5000 block is reserved for IM slaves

// new safeword
string safeword = "SAFEWORD"; 

//added for attachment auth
integer interfaceChannel = -12587429;
integer listenHandleAtt;

integer ATTACHMENT_REQUEST = 600;
integer ATTACHMENT_RESPONSE = 601;
integer ATTACHMENT_FORWARD = 610;

key wearer;
string separator = "|";
string auth;
string UUID;
string objectID;
string command;

debug(string str)
{
    //llOwnerSay(llGetScriptName() + " Debug: " + str);
}

SetListeners()
{
    llListenRemove(listener1);
    llListenRemove(listener2);
    llListenRemove(objectlistener); 
    llListenRemove(lockmeisterlistener);
    llListenRemove(listenHandleAtt);
    if(listenChannel0 == TRUE)
    {
        listener1 = llListen(0, "", NULL_KEY, "");
    }
    interfaceChannel = (integer)("0x" + llGetSubString(wearer,30,-1));
    if (interfaceChannel > 0) interfaceChannel = -interfaceChannel;
    listenHandleAtt = llListen(interfaceChannel, "", "", "");
    listener2 = llListen(listenchannel, "", NULL_KEY, "");
    objectlistener = llListen(objectchannel, "", NULL_KEY, "");
    lockmeisterlistener = llListen(lockmeisterchannel, "", NULL_KEY, (string)wearer + "collar");
}

Popup(key id, string message)
{
    //one-way popup message.  don't listen for these anywhere
    llDialog(id, message, [], 298479);
}

string AutoPrefix()
{
    list name = llParseString2List(llKey2Name(wearer), [" "], []);    
    return llToLower(llGetSubString(llList2String(name, 0), 0, 0)) + llToLower(llGetSubString(llList2String(name, 1), 0, 0));
}

string StringReplace(string src, string from, string to)
{//replaces all occurrences of 'from' with 'to' in 'src'.
//Ilse: blame/applaud Strife Onizuka for this godawfully ugly though apparently optimized function
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
 
integer startswith(string haystack, string needle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(haystack, llStringLength(needle), -1) == needle;
}

default
{
    state_entry()
    {
        wearer = llGetOwner();
        prefix = AutoPrefix();
        //llInstantMessage(, "Prefix set to '" + prefix + "'.", wearer);
        SetListeners();
        //llMessageLinked(LINK_THIS, HTTPDB_REQUEST, "prefix", NULL_KEY);    
        //llMessageLinked(LINK_THIS, HTTPDB_REQUEST, "channel", NULL_KEY);        
    }
    
    attach(key id)
    {
        if (id == NULL_KEY)
        {
            llWhisper(interfaceChannel, "OpenCollar=No");
        }
        else
        {
            llWhisper(interfaceChannel, "OpenCollar=Yes");
        }
    }
    
    listen(integer channel, string name, key id, string message)
    {
        if (channel == objectchannel)
        {
            //check for our uuid at start of message, followed by a colon (":")
            string keystring = (string)wearer + ":";
            if (startswith(message, keystring))
            {
                message = llGetSubString(message, llStringLength(keystring), -1);                
                llMessageLinked(LINK_SET, COMMAND_OBJECT, message, id);                
            }
            else if (llGetSubString(message, 0, 1) == "*:")
            {
                //it's a collar command for anyone in range
                message = llGetSubString(message, 2, -1);
                llMessageLinked(LINK_SET, COMMAND_OBJECT, message, id);            
            }
            else
            {
                //it still might be a formal RLV relay command
                list relaybits = llParseString2List(message, [","], []);
                if (llGetListLength(relaybits) == 3 && llList2String(relaybits, 1) == (string)wearer)
                {
                    //we've gotten an RLV relay command for this av
                    llMessageLinked(LINK_SET, COMMAND_RLV_RELAY, message, id);
                }
            }
        }
        else if (channel == lockmeisterchannel)
        {
            llWhisper(lockmeisterchannel,(string)wearer + "collar ok");
        }
        else if(id == wearer && message == safeword)
        { // new safeword
            llMessageLinked(LINK_THIS, COMMAND_SAFEWORD, "", NULL_KEY);
            llOwnerSay("You used your safeword, your owner will be notified you did.");
        }
        //added for attachment auth (garvin)
        else if (channel == interfaceChannel)
        {
            debug(message);
            //do nothing if wearer isnt owner of the object
            if (llGetOwnerKey(id) != wearer) return;
            if (message == "OpenCollar?")
            {
                llWhisper(interfaceChannel, "OpenCollar=Yes");
                return;
            }
            //(string)num + SEPARATOR + msg + SEPARATOR + (string)UserID + (string)objectID
            integer index = llSubStringIndex(message, separator);
            auth = llGetSubString(message, 0, index - 1);
            if (auth == "0") //auth request
            {
                command = llGetSubString(message, index + 1, -1);
                index = llSubStringIndex(command, separator);
                UUID = llGetSubString(command, index + 1, llStringLength(message) - 40);
                debug(UUID);
                //just send ATTACHMENT_REQUEST and ID to auth, as no script IN the collar needs the command anyway
                llMessageLinked(LINK_THIS, ATTACHMENT_REQUEST, "", (key)UUID);
            }
            else if (auth == (string)COMMAND_COLLAR) //command from attachment to AO
            {
                llWhisper(interfaceChannel, message);
            }
            
            else
            {
                // we received a unkown command, so we just forward it via LM into the cuffs
                llMessageLinked(LINK_SET, ATTACHMENT_FORWARD, message, id);
            }

        }
        else
        { //check for our prefix, or *
            if (startswith(message, prefix))
            {
                //trim 
                message = llGetSubString(message, llStringLength(prefix), -1);
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, message, id);
            }
            else if (llGetSubString(message, 0, 0) == "*")
            {
                message = llGetSubString(message, 1, -1);
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, message, id);            
            }            
        }      
    }
    
    link_message(integer sender, integer num, string str, key id)
    {     //handle changing prefix and channel from owner
        if (num == COMMAND_OWNER)
        {
            list params = llParseString2List(str, [" "], []);
            string command = llList2String(params, 0);
            if (command == "prefix")
            {
                string newprefix = llList2String(params, 1);
                if (newprefix == "auto")
                {
                    prefix = AutoPrefix();
                }
                else if (newprefix != "")
                {
                    prefix = newprefix;
                }
                SetListeners();
                Popup(id, "\n" + llKey2Name(wearer) + "'s prefix is '" + prefix + "'.\nTouch the collar or say '" + prefix + "menu' for the main menu.\nSay '" + prefix + "help' for a list of chat commands.");                          
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "prefix=" + prefix, NULL_KEY);
            }
            else if (command == "channel")
            {
                integer newchannel = (integer)llList2String(params, 1);
                if (newchannel > 0)
                {
                    listenchannel =  newchannel;
                    SetListeners();
                    Popup(id, "Now listening on channel " + (string)listenchannel + ".");
                    if (listenChannel0)
                    {
                        llMessageLinked(LINK_THIS, HTTPDB_SAVE, "channel=" + (string)listenchannel + ",TRUE", NULL_KEY);           
                    }
                    else
                    {
                         llMessageLinked(LINK_THIS, HTTPDB_SAVE, "channel=" + (string)listenchannel + ",FALSE", NULL_KEY);
                    }             
                }
                else if (newchannel == 0)
                {
                    listenChannel0 = TRUE;
                    SetListeners();
                    Popup(id, "You enabled the public channel listener.\nTo disable it use -1 as channel command.");
                    llMessageLinked(LINK_THIS, HTTPDB_SAVE, "channel=" + (string)listenchannel + ",TRUE", NULL_KEY);
                }
                else if (newchannel == -1)
                {
                    listenChannel0 = FALSE;
                    SetListeners();
                    Popup(id, "You disabled the public channel listener.\nTo enable it use 0 as channel command, remember you have to do this on your channel /" +(string)listenchannel);
                    llMessageLinked(LINK_THIS, HTTPDB_SAVE, "channel=" + (string)listenchannel + ",FALSE", NULL_KEY);
                }                            
                else
                {  //they left the param blank
                    Popup(id, "Error: 'channel' must be given a number.");
                }
            }
            else if(id == wearer)
            {
                    if (command == "safeword")
                    {   // new for safeword
                    string value = llList2String(params, 1);
                    if(llStringTrim(value, STRING_TRIM) != "")
                    {
                        safeword = value;
                        llOwnerSay("You set a new safeword: " + value + ".");
                        llMessageLinked(LINK_THIS, HTTPDB_SAVE, "safeword=" + value, NULL_KEY);
                    }
                    else
                    {
                        llOwnerSay("Your safeword is: " + safeword + ".");
                    }
                }
                else if (str == safeword)
                { //safeword used with prefix
                    llMessageLinked(LINK_THIS, COMMAND_SAFEWORD, "", NULL_KEY);
                    llOwnerSay("You used your safeword, your owner will be notified you did.");
                }
            }
        }
        else if (num == COMMAND_WEARER)
        {
            list params = llParseString2List(str, [" "], []);
            string command = llList2String(params, 0);
            string value = llList2String(params, 1);
            if (command == "safeword")
            {   // new for safeword
                if(llStringTrim(value, STRING_TRIM) != "")
                {
                    safeword = value;
                    llOwnerSay("You set a new safeword: " + value + ".");
                    llMessageLinked(LINK_THIS, HTTPDB_SAVE, "safeword=" + value, NULL_KEY);
                }
                else
                {
                    llOwnerSay("Your safeword is: " + safeword + ".");
                }
            }
            else if (str == safeword)
            { //safeword used with prefix
                llMessageLinked(LINK_THIS, COMMAND_SAFEWORD, "", NULL_KEY);
                llOwnerSay("You used your safeword, your owner will be notified you did.");
            }
        }
        else if (num == HTTPDB_RESPONSE)
        {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if (token == "prefix")
            {
                //prefix is the only token for which the httpdb will send a blank value, just so that
                //this script can know it's time to send the helpful popup.
                prefix = value;
                //llInstantMessage(wearer, "Loaded prefix " + prefix + " from database.");
                SetListeners();                                
                //Popup(wearer "\nPrefix set to '" + prefix + "'.\nTouch the collar or say '" + prefix + "menu' for the main menu.\nSay '" + prefix + "help' for a list of chat commands.");
            }
            else if (token == "channel")
            {
                listenchannel = (integer)value;
                if (llGetSubString(value, llStringLength(value) - 6 , -1) == "FALSE")
                {
                    listenChannel0 = FALSE;
                }
                else
                {
                    listenChannel0 = TRUE;
                }
                //llInstantMessage(wearer, "Commands may be given on channel " + value + ".");
                SetListeners();                
            }
            else if (token == "safeword")
            {
                safeword = value;
//                llOwnerSay("Your safeword " + safeword + " was loaded from the httpdb.");
            }
        }
//        else if (num == HTTPDB_EMPTY && str == "prefix")
//        {
//            SetListeners();                                
//            Popup(wearer, "\nPrefix set to '" + prefix + "'.\nTouch the collar or say '" + prefix + "menu' for the main menu.\nSay '" + prefix + "help' for a list of chat commands.");            
//        }
        else if (num >= COMMAND_OWNER && num <= COMMAND_WEARER && str == "settings")
        {
            llInstantMessage(id, "prefix: " + prefix);
            llInstantMessage(id, "channel: " + prefix);            
        }
        else if (num == POPUP_HELP)
        {
            //replace _PREFIX_ with prefix, and _CHANNEL_ with (strin) channel
            str = StringReplace(str, "_PREFIX_", prefix);
            str = StringReplace(str, "_CHANNEL_", (string)listenchannel);
            Popup(id, str);
        }
        //added for attachment auth (garvin)
        else if (num == ATTACHMENT_RESPONSE)
        {
            debug(str);
            //here the response from auth has to be:
            // llMessageLinked(LINK_THIS, ATTACHMENT_RESPONSE, "auth", UUID);
            //where "auth" has to be (string)COMMAND_XY
            //reason for this is: i dont want to have all other scripts recieve a COMMAND+xy and check further for the command
            llWhisper(interfaceChannel, "RequestReply|" + str + separator + command);
        }
    }
    //no more self resets
    changed(integer change)
    {
        if (change & CHANGED_OWNER)
        {
            llResetScript();
        }
    }
    
    on_rez(integer param)
    {
        llResetScript();
    }
}