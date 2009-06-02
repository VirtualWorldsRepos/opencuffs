//Adapted by Nandana Singh to be compatible with OpenCollar
    //remove listeners.  Instead, responds to COMMAND_RLVRELAY link messages
    //remove ownersays.  Instead, send COMMAND_OWNER, COMMAND_GROUP, etc link messages 
    //remove touch event.  Use OpenCollar menu system instead.
    //remove nMode.  permissions will now work thusly:
        //commands from objects owned by sub owner, secowner, or group (if set) will be relayed automatically with corresponding auth
        //commands from everyone else will raise a popup.  If wearer's consent is given, will be relayed with auth COMMAND_WEARER
    

//~ RestrainedLife Viewer Relay Script example code
//~ By Marine Kelley
//~ 2008-02-03
//~ 2008-02-03
//~ v1.1
//~ 2008-02-16 with fixes by Maike Short
//~ 2008-02-24 more fixes by Maike Short
//~ 2008-03-03 code cleanup by Maike Short
//~ 2008-03-05 silently ignore commands for removing restrictions if they are not active anyway 
//~ 2008-06-24 fix of loophole in ask-mode by Felis Darwin
//~ 2008-09-01 changed llSay to llShout, increased distance check (MK)
 
//~ This code is provided AS-IS, OPEN-SOURCE and holds NO WARRANTY of accuracy,
//~ completeness or performance. It may only be distributed in its full source code,
//~ this header and disclaimer and is not to be sold.
 
//~ * Possible improvements
//~ Do some error checking
//~ Handle more than one object
//~ Periodically check that the in-world objects are still around, when one is missing purge its restrictions
//~ Manage an access list
//~ Reject some commands if not on access list (force remove clothes, force remove attachments...)
//~ and much more...
 
//OpenCollar Message Map

integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
//integer CHAT = 505; //deprecated.  Too laggy to make every single script parse a link message any time anyone says anything
integer COMMAND_OBJECT = 506;
integer COMMAND_RLV_RELAY = 507;

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
integer MENUNAME_REMOVE = 3003;

integer RLV_CMD = 6000;

//openCollar-related vars
key owner;
key group = NULL_KEY;
list secowners;
string dbtoken = "rlvrelaysettings";
integer timeout = 30;
list settings = ["landowner_control", "n"];
integer listener;
integer menu_wait_start;
integer waiting_for_menu;
integer returnmenu;
list cmds = [
"landowner_control",
"anyone_control"
];

list prettycmds = [ //showing menu-friendly command names for each item in cmds
"Landowners",
"Anyone"
];

list descriptions = [ //showing descriptions for commands
"Control by Landowner's Objects",
"Control by Anyone's Objects"
];
string parentmenu = "RLV";
string submenu = "Relay";

string TURNON = "Enable";
string TURNOFF = "Disable";
string UPMENU = "~PrevMenu~";

integer menuchannel = 210789;
 
// ---------------------------------------------------
//                     Constants
// ---------------------------------------------------
 
integer RLVRS_PROTOCOL_VERSION = 1020; // version of the protocol, stated on the specification page
 
string PREFIX_RL_COMMAND = "@";
string PREFIX_METACOMMAND = "!";
 
integer RLVRS_CHANNEL = -1812221819;  // RLVRS in numbers
integer DIALOG_CHANNEL = -1812220409; // RLVDI in numbers
 
integer MAX_OBJECT_DISTANCE = 100;     // 100m is llShout distance
integer MAX_TIME_AUTOACCEPT_AFTER_FORCESIT = 300; // 300 is 5 minutes
 
integer PERMISSION_DIALOG_TIMEOUT = 30;
 
integer LOGIN_DELAY_WAIT_FOR_PONG = 10;
integer LOGIN_DELAY_WAIT_FOR_FORCE_SIT = 60;
 
integer MODE_OFF = 0;
integer MODE_ASK = 1;
integer MODE_AUTO = 2;
 
 
// ---------------------------------------------------
//                      Variables
// ---------------------------------------------------
 
integer nMode = 1;//hard code it to accept all.
 
list lRestrictions; // restrictions currently applied (without the "=n" part)
key kSource;        // UUID of the object I'm commanded by, always equal to NULL_KEY if lRestrictions is empty, always set if not
 
string sPendingName; // name of initiator of pending request (first request of a session in mode 1)
key sPendingId;      // UUID of initiator of pending request (first request of a session in mode 1)
string sPendingMessage; // message of pending request (first request of a session in mode 1)
integer sPendingTime;
 
// used on login
integer timerTickCounter; // count the number of time events on login (forceSit has to be delayed a bit)
integer loginWaitingForPong;
integer loginPendingForceSit;
 
key     lastForceSitDestination;
integer lastForceSitTime;
 
// ---------------------------------------------------
//               Low Level Communication
// ---------------------------------------------------
 
 
debug(string x)
{
    //llOwnerSay("DEBUG: " + x);
}
 
// acknowledge or reject
ack(string cmd_id, key id, string cmd, string ack)
{
    string out = cmd_id + "," + (string)id + "," + cmd + "," + ack;
    llShout(RLVRS_CHANNEL, out);
    debug("ACK: " + out);
}
 
// cmd begins with a '@' 
sendRLCmd(string cmd, key id)
{
    //llOwnerSay(cmd);
    //mini auth system
    integer auth;
    if (llGetOwnerKey(id) == owner)
    {
        auth = COMMAND_OWNER;
    }
    else if (~llListFindList(secowners, [id]))
    {
        auth = COMMAND_SECOWNER;
    }
    else if (group != NULL_KEY && llList2Key(llGetObjectDetails(id, [OBJECT_GROUP]), 0) == group)
    {
        auth = COMMAND_GROUP;
    }
    else
    {
        //this ought to be safe to do, because we will have only gotten to this point if the wearer gave permission
        auth = COMMAND_GROUP;
    }
    //remove the "@", and send a link message    
    llMessageLinked(LINK_THIS, auth, llGetSubString(cmd, 1, -1), id);
}
 
// get current mode as string
string getModeDescription()
{
    if (nMode == 0) return "RLV Relay is OFF"; 
    else if (nMode == 1) return "RLV Relay is ON (permission needed)"; 
    else return "RLV Relay is ON (auto-accept)"; 
}
 
// check that this command is for us and not someone else
//OpenCollar listen script handles this, so commented out here
//integer verifyWeAreTarget(string message)
//{
//    list tokens = llParseString2List(message, [","], []);
//    if (llGetListLength(tokens) == 3) // this is a normal command
//    {
//      if (llList2String(tokens, 1) == llGetOwner()) // talking to me ?
//      {
//         return TRUE;
//      }
//    }
//    return FALSE;
//}
 
// ---------------------------------------------------
//               Permission Handling
// ---------------------------------------------------
 
// are we already under command by this object?
integer isObjectKnow(key id)
{
    // first some error handling
    if (id == NULL_KEY)
    {
        return FALSE;
    }
 
    // are we already under command by this object?
    if (kSource == id)
    {
        return TRUE;
    }
 
    // are we not under command by any object but were we forced to sit on this object recently?
    if ((kSource == NULL_KEY) && (id == lastForceSitDestination))
    {
        debug("on last force sit target");
        if (lastForceSitTime + MAX_TIME_AUTOACCEPT_AFTER_FORCESIT > llGetUnixTime())
        {
            debug("and recent enough to auto accept");
            return TRUE;
        }
    }
 
    return FALSE;
}
 
 
// check whether the object is in llShout distance. It could have moved
// before the message is received (chatlag)
integer isObjectNear(key id)
{
    vector myPosition = llGetRootPosition();
    list temp = llGetObjectDetails(id, ([OBJECT_POS]));
    vector objPostition = llList2Vector(temp,0);
    float distance = llVecDist(objPostition, myPosition);
    return distance <= MAX_OBJECT_DISTANCE;
}
 
// do a basic check on the identity of the object trying to issue a command
//Nandana: commented out as it collides with our owner system
//integer isObjectIdentityTrustworthy(key id)
//{
//    key parcel_owner=llList2Key (llGetParcelDetails (llGetPos (), [PARCEL_DETAILS_OWNER]), 0);
//    key parcel_group=llList2Key (llGetParcelDetails (llGetPos (), [PARCEL_DETAILS_GROUP]), 0);
//    key object_owner=llGetOwnerKey(id);
//    key object_group=llList2Key (llGetObjectDetails (id, [OBJECT_GROUP]), 0);
// 
//    debug("owner= " + (string) parcel_owner + " / " + (string) object_owner);
//    debug("group= " + (string) parcel_group + " / " + (string) object_group);
// 
//    if (object_owner==llGetOwner ()        // IF I am the owner of the object
//      || object_owner==parcel_owner        // OR its owner is the same as the parcel I'm on
//      || object_group==parcel_group        // OR its group is the same as the parcel I'm on
//    )
//    {
//        return TRUE;
//    }
//    return FALSE;
//}
 
 
// Is this a simple request for information or a meta command like !release?
integer isSimpleRequest(list list_of_commands) 
{
    integer len = llGetListLength(list_of_commands);
    integer i;
 
    // now check every single atomic command
    for (i=0; i < len; ++i)
    {
        string command = llList2String(list_of_commands, i);
        if (!isSimpleAtomicCommand(command))
        {
           return FALSE;
        }
    }
 
    // all atomic commands passed the test
    return TRUE;
}
 
// is this a simple atmar command
// (a command which only queries some information or releases restrictions)
// (e. g.: cmd ends with "=" and a number (@version, @getoutfit, @getattach) or is a !-meta-command)
integer isSimpleAtomicCommand(string cmd)
{
    // check right hand side of the "=" - sign
    integer index = llSubStringIndex (cmd, "=");
    if (index > -1) // there is a "=" 
    {
        // check for a number after the "="
        string param = llGetSubString (cmd, index + 1, -1);
        if ((integer)param!=0 || param=="0") // is it an integer (channel number)?
        {
            return TRUE;
        }
 
        // removing restriction
        if ((param == "y") || (param == "rem"))
        {
            return TRUE;
        }
    }
 
    // check for a leading ! (meta command)
    if (llSubStringIndex(cmd, PREFIX_METACOMMAND) == 0)
    {
        return TRUE;
    }
 
    // check for @clear
    // Note: @clear MUST NOT be used because the restrictions will be reapplied on next login
    // (but we need this check here because "!release|@clear" is a BROKEN attempt to work around
    // a bug in the first relay implementation. You should refuse to use relay versions < 1013
    // instead.)
    if (cmd == "@clear")
    {
        return TRUE;
    }
 
    // this one is not "simple".
    return FALSE;
}
 
// If we already have commands from this object pending
// because of a permission request dialog, just add the
// new commands at the end.
// Note: We use a timeout here because the player may
// have "ignored" the dialog.
integer tryToGluePendingCommands(key id, string commands)
{
    if ((sPendingId == id) && (sPendingTime + PERMISSION_DIALOG_TIMEOUT > llGetUnixTime()))
    {
        debug("Gluing " + sPendingMessage + " with " + commands);
        sPendingMessage = sPendingMessage + "|" + commands;
        return TRUE;
    }
    return FALSE;
}
 
// verifies the permission. This includes mode 
// (off, permission, auto) of the relay and the
// identity of the object (owned by parcel people).
integer verifyPermission(key id, string name, string message)
{

    // is it switched off?
    if (nMode == MODE_OFF)
    {
        return FALSE;
    }
 
    // extract the commands-part
    list tokens = llParseString2List (message, [","], []);
    if (llGetListLength (tokens) < 3)
    {
        return FALSE;
    }    
    string commands = llList2String(tokens, 2);
    list list_of_commands = llParseString2List(commands, ["|"], []);
 
    // accept harmless commands silently
    if (isSimpleRequest(list_of_commands))
    {
        return TRUE;
    }    
 
    // if we are already having a pending permission-dialog request for THIS object,
    // just add the new commands at the end of the pending command list.
    if (tryToGluePendingCommands(id, commands))
    {
        return FALSE;
    }
 
    // check whether this object belongs here
    //integer trustworthy = isObjectIdentityTrustworthy(id);
    //string warning = "";
    //if (!trustworthy)
    //{
    //    warning = "\n\nWARNING: This object is not owned by the people owning this parcel. Unless you know the owner, you should deny this request.";
    //}
 
    //return TRUE if passes owner, secowner, or group checks.     
    
    //else return FALSE
    if (llGetOwnerKey(id) == owner)
    {
        return TRUE;
    }
    else if (~llListFindList(secowners, [id]))
    {
        return TRUE;
    }
    else if (group != NULL_KEY && llList2Key(llGetObjectDetails(id, [OBJECT_GROUP]), 0) == group)
    {
        return TRUE;
    }
    else if (~llListFindList(settings, ["landowner_control", "y"]) && llGetOwnerKey(id) == llGetLandOwnerAt(llGetPos()))
    {
        //landowner control is enabled, and this object belongs to landowner
        return TRUE;
    }
    else if (~llListFindList(settings, ["anyone_control", "y"]))
    {
        return TRUE;
    }
    else
    {
        sPendingId=id;
        sPendingName=name;
        sPendingMessage=message;
        sPendingTime = llGetUnixTime();
        llDialog (llGetOwner(), name + " would like control your viewer.\n\nDo you accept ?", ["Yes", "No"], DIALOG_CHANNEL);
        debug("Asking for permission");
        return FALSE;        
    }
}
 
 
// ---------------------------------------------------
//               Executing of commands
// ---------------------------------------------------
 
// execute a non-parsed message
// this command could be denied here for policy reasons, (if it were implemenetd)
// but this time there will be an acknowledgement
execute(string name, key id, string message)
{
    //Nandana: removed list length and target checks.  those are already done in our listener
    list tokens=llParseString2List (message, [","], []);

    string cmd_id=llList2String (tokens, 0); // CheckAttach

    list list_of_commands=llParseString2List (llList2String (tokens, 2), ["|"], []);
    integer len=llGetListLength (list_of_commands);
    integer i;
    string command;
    string prefix;
    for (i=0; i<len; ++i) // execute every command one by one
    {
        // a command is a RL command if it starts with '@' or a metacommand if it starts with '!'
        command=llList2String (list_of_commands, i);
        prefix=llGetSubString (command, 0, 0);

        if (prefix==PREFIX_RL_COMMAND) // this is a RL command
        {
            executeRLVCommand(cmd_id, id, command);
        }
        else if (prefix==PREFIX_METACOMMAND) // this is a metacommand, aimed at the relay itself
        {
            executeMetaCommand(cmd_id, id, command);
        }
    }
}
 
// executes a command for the restrained life viewer 
// with some additinal magic like book keeping
executeRLVCommand(string cmd_id, string id, string command)
{
    // we need to know whether whether is a rule or a simple command
    list tokens_command=llParseString2List (command, ["="], []);
    string behav=llList2String (tokens_command, 0); // @getattach:skull
    string param=llList2String (tokens_command, 1); // 2222
    integer ind=llListFindList (lRestrictions, [behav]);
 
    if (param=="n" || param=="add") // add to lRestrictions
    {
        if (ind<0) lRestrictions+=[behav];
        kSource=id; // we know that kSource is either NULL_KEY or id already
    }
    else if (param=="y" || param=="rem") // remove from lRestrictions
    {
        if (ind > -1) lRestrictions=llDeleteSubList (lRestrictions, ind, ind);
        if (llGetListLength (lRestrictions)==0) kSource=NULL_KEY;
    }
 
    workaroundForAtClear(command);
    rememberForceSit(command);
    sendRLCmd(command, id); // execute command
    ack(cmd_id, id, command, "ok"); // acknowledge
}
 
// check for @clear
// Note: @clear MUST NOT be used because the restrictions will be reapplied on next login
// (but we need this check here because "!release|@clear" is a BROKEN attempt to work around
// a bug in the first relay implementation. You should refuse to use relay versions < 1013
// instead.)
workaroundForAtClear(string command)
{
    if (command == "@clear")
    {
        releaseRestrictions();
    }
}
 
// remembers the time and object if this command is a force sit
rememberForceSit(string command)
{
    list tokens_command=llParseString2List (command, ["="], []);
    string behav=llList2String (tokens_command, 0); // @sit:<uuid>
    string param=llList2String (tokens_command, 1); // force
    if (param != "force")
    {
        return;
    }
 
    tokens_command=llParseString2List(behav, [":"], []);
    behav=llList2String (tokens_command, 0); // @sit
    param=llList2String (tokens_command, 1); // <uuid>
    debug("'force'-command:" + behav + "/" + param);
    if (behav != "@sit")
    {
        return;
    }
    lastForceSitDestination = (key) param;
    lastForceSitTime = llGetUnixTime();
    debug("remembered force sit");
}
 
// executes a meta command which is handled by the relay itself
executeMetaCommand(string cmd_id, string id, string command)
{
    if (command==PREFIX_METACOMMAND+"version") // checking relay version
    {
        ack(cmd_id, id, command, (string)RLVRS_PROTOCOL_VERSION);
    }
    else if (command==PREFIX_METACOMMAND+"release") // release all the restrictions (end session)
    {
        releaseRestrictions();
        ack(cmd_id, id, command, "ok");
    }
}
 
// lift all the restrictions (called by !release and by turning the relay off)
releaseRestrictions ()
{
    kSource=NULL_KEY;
    integer i;
    integer len=llGetListLength (lRestrictions);
    for (i=0; i<len; ++i)
    {
        sendRLCmd(llList2String (lRestrictions, i)+"=y", kSource);
    }
    lRestrictions = [];
    loginPendingForceSit = FALSE;
}
 
 
// ---------------------------------------------------
//            initialisation and login handling
// ---------------------------------------------------
 
init() {
    nMode=1;
    kSource=NULL_KEY;
    lRestrictions=[];
    sPendingId=NULL_KEY;
    sPendingName="";
    sPendingMessage="";
    //llListen (RLVRS_CHANNEL, "", "", "");
    llListen (DIALOG_CHANNEL, "", llGetOwner(), "");
    //llOwnerSay (getModeDescription());
    
    //get OpenCollar settings
    owner = llGetOwner();//wearer is owner if not explicitly set otherwise in DB
    //llMessageLinked(LINK_THIS, HTTPDB_REQUEST, "owner", NULL_KEY);
    //llMessageLinked(LINK_THIS, HTTPDB_REQUEST, "group", NULL_KEY);
    //llMessageLinked(LINK_THIS, HTTPDB_REQUEST, "secowners", NULL_KEY);     
    //llMessageLinked(LINK_THIS, HTTPDB_REQUEST, dbtoken, NULL_KEY);        
    llSleep(1.0);
    llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);    
}
 
// sends the known restrictions (again) to the RL-viewer
// (call this functions on login)
reinforceKnownRestrictions()
{
    integer i;
    integer len=llGetListLength(lRestrictions);
    string restr;
    debug("kSource=" + (string) kSource);
    for (i=0; i<len; ++i)
    {
        restr=llList2String(lRestrictions, i);
        debug("restr=" + restr);
        sendRLCmd(restr+"=n", kSource);
        if (restr=="@unsit")
        {
            loginPendingForceSit = TRUE;
        }
    }
}
 
// send a ping request and start a timer
pingWorldObjectIfUnderRestrictions()
{
    loginWaitingForPong = FALSE;
    if (kSource != NULL_KEY)
    {
        ack("ping", kSource, "ping", "ping");
        timerTickCounter = 0;
        llSetTimerEvent(1.0);
        loginWaitingForPong = TRUE;
    }
}

Menu(key id)
{
    //build prompt showing current settings
    //make enable/disable buttons
    string prompt = "Pick an option";
    prompt += "\n(Menu will expire in " + (string)timeout + " seconds.)";
    prompt += "\nCurrent Settings: ";
    list buttons;
    
        
    integer n;
    integer stop = llGetListLength(cmds);
    for (n = 0; n < stop; n++)
    {
        //see if there's a setting for this in the settings list
        string cmd = llList2String(cmds, n);
        string pretty = llList2String(prettycmds, n);
        string desc = llList2String(descriptions, n);
        integer index = llListFindList(settings, [cmd]);
        if (index == -1)
        {
            //if this cmd not set, then give button to enable
            buttons += [TURNON + " " + llList2String(prettycmds, n)];
            prompt += "\n" + pretty + " = Disabled (" + desc + ")";
        }
        else
        {
            //else this cmd is set, then show in prompt, and make button do opposite
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
    //buttons += [TURNON + " All"];
    //buttons += [TURNOFF + " All"];      
    buttons += [UPMENU];
    buttons = RestackMenu(FillMenu(buttons));
    menu_wait_start = timerTickCounter;
    waiting_for_menu = TRUE;
    menuchannel = llRound(llFrand(9999999.0));    
    listener = llListen(menuchannel, "", id, "");
    llSetTimerEvent(1.0);
    llDialog(id, prompt, buttons, menuchannel);
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
 
default
{
    state_entry()
    {
        init();
    }
 
    on_rez(integer start_param)
    {
        // relogging, we must refresh the viewer and ping the object if any
        // if mode is not OFF, fire all the stored restrictions
        if (nMode)
        {
            reinforceKnownRestrictions();
            pingWorldObjectIfUnderRestrictions();
        }
        // remind the current mode to the user
        //llOwnerSay(getModeDescription());
    }
 
 
    timer()
    {
        timerTickCounter++;
        debug("timer (" + (string) timerTickCounter + "): waiting for pong: " + (string) loginWaitingForPong + " pendingForceSit: " + (string) loginPendingForceSit);
        if (loginWaitingForPong && (timerTickCounter == LOGIN_DELAY_WAIT_FOR_PONG))
        {
            //llWhisper(0, "Lucky Day: " + llKey2Name(llGetOwner()) + " is freed because the device is not available.");
            loginWaitingForPong = FALSE;
            loginPendingForceSit = FALSE;
            releaseRestrictions();
        }
 
        if (loginPendingForceSit)
        {
            integer agentInfo = llGetAgentInfo(llGetOwner());
            if (agentInfo & AGENT_SITTING)
            {
                loginPendingForceSit = FALSE;
                debug("is sitting now");
            }
            else if (timerTickCounter == LOGIN_DELAY_WAIT_FOR_FORCE_SIT)
            {
                //llWhisper(0, "Lucky Day: " + llKey2Name(llGetOwner()) + " is freed because sitting down again was not possible.");
                loginPendingForceSit = FALSE;
                releaseRestrictions();
            }
            else
            {
                 sendRLCmd ("@sit:"+(string)lastForceSitDestination+"=force", kSource);
            }
        }
        
        if (timerTickCounter - menu_wait_start >= timeout)
        {
            llListenRemove(listener);
            waiting_for_menu = FALSE;
            returnmenu = FALSE;
        }
 
        if (!loginPendingForceSit && !loginWaitingForPong  && !waiting_for_menu)
        {
            llSetTimerEvent(0.0);
        }
    }
    
    link_message(integer sender, integer num, string message, key id)
    {
        if (num == COMMAND_RLV_RELAY)
        {
            //OpenCollar listen script handles this
            //if (!verifyWeAreTarget(message))
            //{
            //   return;
            //}
            
            //check here whether we're still in the same sim as kSource.  If not, re-set it
            if (kSource != NULL_KEY && llKey2Name(kSource) == "")
            {
                releaseRestrictions();
            }
            
            //because we're using a link message instead of a listener, need to provide name
            string name = llKey2Name(id);
            
            //if (nMode== MODE_OFF)
            //{
            //    debug("deactivated - ignoring commands");
            //    return; // mode is 0 (off) => reject
            //}
            if (!isObjectNear(id)) return;
 
            debug("Got message (active world object " + (string) kSource + "): name=" + name+ "id=" + (string) id + " message=" + message);
 
            if (kSource != NULL_KEY && kSource != id)
            {
                debug("already used by another object => reject");
                return;
            }
 
            loginWaitingForPong = FALSE; // whatever the message, it is for me => it satisfies the ping request
 
            if (!isObjectKnow(id))
            {
                debug("asking for permission because kSource is NULL_KEY");
                if (!verifyPermission(id, name, message))
                {
                    return;
                }
            }
 
            debug("Executing: " + (string) kSource);
            execute(name, id, message);            
        }
        else if (num == HTTPDB_RESPONSE)
        {
            list params = llParseString2List(message, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if (token == "owner")
            {
                list tmp = llParseString2List(value, [","], []);
                owner = (key)llList2String(tmp, 0);
            }
            else if (token == "group")
            {
                group = (key)message;
            }
            else if (token == "secowners")
            {
                secowners = llParseString2List(value, [","], []);                                
            }
            else if (token == dbtoken)
            {
                //save value in settings list
                settings = llParseString2List(value, [","], []);
            }
        }
        else if (num == MENUNAME_REQUEST && message == parentmenu)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        else if (num == SUBMENU && message == submenu)
        {
            //give menu
            Menu(id);
        }
        else if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
        {
            list params = llParseString2List(message, ["="], []);
            
            string option = llList2String(params, 0);
            //before doing anything more, see if we handle this cmd
            if (~llListFindList(cmds, [option]))
            {
                //filter commands from wearer, if wearer is not owner
                if (num == COMMAND_WEARER)
                {
                    llInstantMessage(llGetOwner(), "Sorry, but RLV commands may only be given by owner, secowner, or group (if set).");
                    return;
                }                
                
                string param = llList2String(params, 1);
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
                
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, dbtoken + "=" + llDumpList2String(settings, ","), NULL_KEY);
                
                if (returnmenu)
                {
                    Menu(id);
                }           
            }
        }
    }
    listen(integer channel, string name, key id, string message)
    {
        if (channel==DIALOG_CHANNEL)
        {
            if (id != llGetOwner())
            {
                return; // only accept dialog responses from the owner
            }
            if (sPendingId!=NULL_KEY)
            {
                if (message=="Yes") // pending request authorized => process it
                {
                    execute(sPendingName, sPendingId, sPendingMessage);
                }
 
                // clear pending request
                sPendingName="";
                sPendingId=NULL_KEY;
                sPendingMessage="";
            }
        }
        else if (channel==menuchannel)
        {
            llListenRemove(listener);
            waiting_for_menu = FALSE;
            //if we got *Back*, then request submenu RLV
            if (message == UPMENU)
            {
                llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);
                returnmenu = FALSE;
            }
            else
            {
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
                    integer stop = llGetListLength(cmds);                
                    for (n = 0; n < stop; n++)
                    {
                        //prefix all but the first value with a comma, so we have a comma-separated list
                        if (n)
                        {
                            out += ",";
                        }
                        out += llList2String(cmds, n) + "=" + ONOFF;
                    }
                    llMessageLinked(LINK_THIS, COMMAND_NOAUTH, out, id);
                    returnmenu = TRUE;   
                }
                else if (index != -1)
                {
                    string out = llList2String(cmds, index);                
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
 
    changed(integer change)
    {
        if (change & CHANGED_OWNER) 
        {
             llResetScript();
        }
    }
}
