//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//give 3 menus:
//Clothing
//Attachment
//Folder

string submenu = "Un/Dress";
string parentmenu = "RLV";

list children = ["Clothing","Attachment","LockClothing","LockAttachment"];//,"LockClothing","UnlockClothing"];
list submenus= [];
string SELECT_CURRENT = "*InFolder";
string SELECT_RECURS= "*Recursively";
list rlvcmds = ["attach","detach","remoutfit", "addoutfit"];

list settings;//2-strided list in form of [option, param]


list clothpoints = [
    "Gloves",
    "Jacket",
    "Pants",
    "Shirt",
    "Shoes",
    "Skirt",
    "Socks",
    "Underpants",
    "Undershirt"//,  The below are commented out because.... can you really remove skin?
        //"skin",
        //"eyes",
        //"hair",
        //"shape"
        ];
// well you can't remove it, but you can certainly lock it!
list extraclothpoints = [
    "skin",
    "eyes",
    "hair",
    "shape"
        ];

list attachpoints = [
    "None",
    "Chest",
    "Skull",
    "Left Shoulder",
    "Right Shoulder",
    "Left Hand",
    "Right Hand",
    "Left Foot",
    "Right Foot",
    "Spine",
    "Pelvis",
    "Mouth",
    "Chin",
    "Left Ear",
    "Right Ear",
    "Left Eyeball",
    "Right Eyeball",
    "Nose",
    "R Upper Arm",
    "R Forearm",
    "L Upper Arm",
    "L Forearm",
    "Right Hip",
    "R Upper Leg",
    "R Lower Leg",
    "Left Hip",
    "L Upper Leg",
    "L Lower Leg",
    "Stomach",
    "Left Pec",
    "Right Pec",
    "Center 2",
    "Top Right",
    "Top",
    "Top Left",
    "Center",
    "Bottom Left",
    "Bottom",
    "Bottom Right"
        ];

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
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.
integer RLV_VERSION = 6003; //RLV Plugins can recieve the used rl viewer version upon receiving this message..

integer RLV_OFF = 6100; // send to inform plugins that RLV is disabled now, no message or key needed
integer RLV_ON = 6101; // send to inform plugins that RLV is enabled now, no message or key needed


//string UPMENU = "?";
//string MORE = "?";
string UPMENU = "^";
string MORE = ">";
string ALL = "*All*";
//string TICKED = "?";
//string UNTICKED = "?";
string TICKED = "(*)";
string UNTICKED = "( )";

integer timeout = 60;
integer mainchannel = 583909;
integer clothchannel = 583910;
integer attachchannel = 583911;
integer lockchannel = 583913;
integer lockattachchannel = 583914;

integer clothrlv = 78465;
integer attachrlv = 78466;
integer listener;
key menuuser;
integer page = 0;
integer pagesize = 10;
integer buttoncount;

string dbtoken = "undress";
integer remenu = FALSE;

integer rlvon = FALSE;

list lockedItems; // list of locked clothes
list lockedAttachments; // list of locked attachmemts

key wearer;
string wearerName;

debug(string msg)
{
    //llOwnerSay(llGetScriptName() + ": " + msg);
}

Notify(key id, string msg, integer alsoNotifyWearer)
{
    if (id == wearer)
    {
        llOwnerSay(msg);
    }
    else
    {
        llInstantMessage(id,msg);
        if (alsoNotifyWearer)
        {
            llOwnerSay(msg);
        }
    }
}

list RestackMenu(list in)
{ //adds empty buttons until the list length is multiple of 3, to max of 12
    while (llGetListLength(in) % 3 != 0 && llGetListLength(in) < 12)
    {
        in += [" "];
    }
    //look for ^ and > in the menu
    integer p = llListFindList(in, [ALL]);
    if (p != -1)
    {
        in = llDeleteSubList(in, p, p);
    }
    integer u = llListFindList(in, [UPMENU]);
    if (u != -1)
    {
        in = llDeleteSubList(in, u, u);
    }
    integer m = llListFindList(in, [MORE]);
    if (m != -1)
    {
        in = llDeleteSubList(in, m, m);
    }
    //re-orders a list so dialog buttons start in the top row
    list out = llList2List(in, 9, 11);
    out += llList2List(in, 6, 8);
    out += llList2List(in, 3, 5);
    out += llList2List(in, 0, 2);
    //make sure we move ^ and > to position 1 and 2
    if (p != -1)
    {
        out = llListInsertList(out, [ALL], 0);
    }
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

MainMenu(key id)
{
    string prompt = "(Menu will time out in " + (string)timeout + " seconds.)";
    list buttons = children+submenus;
    buttons += [UPMENU];
    buttons = RestackMenu(buttons);
    listener = llListen(mainchannel, "", id, "");
    llSetTimerEvent(timeout);
    llDialog(id, prompt, buttons, mainchannel);
}

QueryClothing()
{    //open listener
    listener = llListen(clothrlv, "", wearer, "");
    //start timer
    llSetTimerEvent(timeout);
    //send rlvcmd
    llMessageLinked(LINK_THIS, RLV_CMD, "getoutfit=" + (string)clothrlv, NULL_KEY);
}

ClothingMenu(key id, string str)
{
    //str looks like 0110100001111
    //loop through clothpoints, look at char of str for each
    //for each 1, add capitalized button
    string prompt = "Select an article of clothing to remove.";
    prompt += "\n(Menu will time out in " + (string)timeout + " seconds.)";
    list buttons = [];
    integer stop = llGetListLength(clothpoints);
    integer n;
    for (n = 0; n < stop; n++)
    {
        integer worn = (integer)llGetSubString(str, n, n);
        list item = [llList2String(clothpoints, n)];
        if (worn && llListFindList(lockedItems,item) == -1)
        {
            buttons += item;
        }
    }
    buttons += [UPMENU];
    buttons = RestackMenu(buttons);
    listener = llListen(clothchannel, "", id, "");
    llSetTimerEvent(timeout);
    llDialog(id, prompt, buttons, clothchannel);
}

LockMenu(key id)
{
    remenu=FALSE;
    string prompt = "Select an article of clothing to un/lock.";
    prompt += "\n(Menu will time out in " + (string)timeout + " seconds.)";
    list buttons;
    if (llListFindList(lockedItems,[ALL]) == -1)
        buttons += [UNTICKED+ALL];
    else  buttons += [TICKED+ALL];

    integer stop = llGetListLength(clothpoints+extraclothpoints);
    integer n;
    for (n = 0; n < stop; n++)
    {
        string cloth = llList2String(clothpoints+extraclothpoints, n);
        if (llListFindList(lockedItems,[cloth]) == -1)
            buttons += [UNTICKED+cloth];
        else  buttons += [TICKED+cloth];
    }
    buttoncount = llGetListLength(buttons);
    if (buttoncount > 11)
    {
        //get the subpart of buttons that corresponds to the current page
        integer start = page * pagesize;
        integer end = page * pagesize + (pagesize - 1);
        if (end > buttoncount - 1)
        {
            end = buttoncount - 1;
        }
        buttons = llList2List(buttons, start, end);
        buttons += [MORE];
    }

    buttons += [UPMENU];
    buttons = RestackMenu(buttons);
    listener = llListen(lockchannel, "", id, "");
    llSetTimerEvent(timeout);
    llDialog(id, prompt, buttons, lockchannel);
}

QueryAttachments()
{    //open listener
    listener = llListen(attachrlv, "", wearer, "");
    //start timer
    llSetTimerEvent(timeout);
    //send rlvcmd
    llMessageLinked(LINK_THIS, RLV_CMD, "getattach=" + (string)attachrlv, NULL_KEY);
}

LockAttachmentMenu(key id)
{
    remenu=FALSE;
    string prompt = "Select an attachment to un/lock.";
    prompt += "\n(Menu will time out in " + (string)timeout + " seconds.)";
    list buttons;
//    if (llListFindList(lockedAttachments,[ALL]) == -1)
//        buttons += [UNTICKED+ALL];
//    else  buttons += [TICKED+ALL];

    integer stop = llGetListLength(attachpoints);
    integer n;
    for (n = 1; n < stop; n++) //starting at 1 as "None" cannot be locked
    {
        string attachment = llList2String(attachpoints, n);
        if (llListFindList(lockedAttachments,[attachment]) == -1)
            buttons += [UNTICKED+attachment];
        else  buttons += [TICKED+attachment];
    }
    buttoncount = llGetListLength(buttons);
    if (buttoncount > 11)
    {
        //get the subpart of buttons that corresponds to the current page
        integer start = page * pagesize;
        integer end = page * pagesize + (pagesize - 1);
        if (end > buttoncount - 1)
        {
            end = buttoncount - 1;
        }
        buttons = llList2List(buttons, start, end);
        buttons += [MORE];
    }

    buttons += [UPMENU];
    buttons = RestackMenu(buttons);
    listener = llListen(lockattachchannel, "", id, "");
    llSetTimerEvent(timeout);
    llDialog(id, prompt, buttons, lockattachchannel);
}

DetachMenu(key id, string str)
{

    //remember not to add button for current object
    //str looks like 0110100001111
    //loop through clothpoints, look at char of str for each
    //for each 1, add capitalized button
    string prompt = "Select an attachment to remove.";

    //prevent detaching the collar itself
    integer myattachpoint = llGetAttached();

    list buttons;
    integer stop = llGetListLength(attachpoints);
    integer n;
    for (n = 0; n < stop; n++)
    {
        if (n != myattachpoint)
        {
            integer worn = (integer)llGetSubString(str, n, n);
            if (worn)
            {
                buttons += [llList2String(attachpoints, n)];
            }
        }
    }
    //handle multi page menu
    buttoncount = llGetListLength(buttons);
    if (buttoncount > 11)
    {
        //get the subpart of buttons that corresponds to the current page
        integer start = page * pagesize;
        integer end = page * pagesize + (pagesize - 1);
        if (end > buttoncount - 1)
        {
            end = buttoncount - 1;
        }
        buttons = llList2List(buttons, start, end);
        buttons += [MORE];
    }

    buttons += [UPMENU];
    buttons = RestackMenu(buttons);
    listener = llListen(attachchannel, "", id, "");
    llSetTimerEvent(timeout);
    llDialog(id, prompt, buttons, attachchannel);
}

UpdateSettings()
{    //build one big string from the settings list
    //llOwnerSay("TP settings: " + llDumpList2String(settings, ","));
    integer settingslength = llGetListLength(settings);
    if (settingslength > 0)
    {
        lockedItems=[];
        lockedAttachments=[];
        integer n;
        list newlist;
        for (n = 0; n < settingslength; n = n + 2)
        {
            list option=llParseString2List(llList2String(settings, n),[":"],[]);
            string value=llList2String(settings, n + 1);
            //debug(llList2String(settings, n) + "=" + value);
            newlist += [llList2String(settings, n) + "=" + llList2String(settings, n + 1)];
            if (llGetListLength(option)==2&&llList2String(option,0)=="remoutfit"&&value=="n")
                lockedItems += [llList2String(option,1)];
            if (llGetListLength(option)==1&&llList2String(option,0)=="remoutfit"&&value=="n")
                lockedItems += [ALL];
                
            if (llGetListLength(option)==2&&llList2String(option,0)=="detach"&&value=="n")
                lockedAttachments += [llList2String(option,1)];
        }
        //output that string to viewer
        llMessageLinked(LINK_THIS, RLV_CMD, llDumpList2String(newlist, ","), NULL_KEY);
    }
}

ClearSettings()
{   //clear settings list
    settings = [];
    //clear the list of locked items
    lockedItems = [];
    lockedAttachments=[];
    //remove tpsettings from DB
    llMessageLinked(LINK_THIS, HTTPDB_DELETE, dbtoken, NULL_KEY);
    //main RLV script will take care of sending @clear to viewer
}
default
{
    state_entry()
    {
        wearer = llGetOwner();
        wearerName = llKey2Name(wearer);
        mainchannel = - llRound(llFrand(9999999.0)) -99999;
        clothchannel = - llRound(llFrand(9999999.0)) -99999;
        attachchannel = - llRound(llFrand(9999999.0)) -99999;
        lockchannel = - llRound(llFrand(9999999.0)) -99999;
        lockattachchannel = - llRound(llFrand(9999999.0)) -99999;
        llMessageLinked(LINK_THIS, MENUNAME_REQUEST, submenu, NULL_KEY);
        llSleep(1.0);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
    }

    link_message(integer sender, integer num, string str, key id)
    {
        if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
        {   //the command was given by either owner, secowner, group member, or wearer
            list params = llParseString2List(str, [":", "="], []);
            string command = llList2String(params, 0);
            //debug(str + " ## " + command);
            if (llListFindList(rlvcmds, [command]) != -1)
            {    //we've received an RLV command that we control.  only execute if not sub
                if (num == COMMAND_WEARER)
                {
                    llOwnerSay("Sorry, but RLV commands may only be given by owner, secowner, or group (if set).");
                }
                else
                {
                    llMessageLinked(LINK_THIS, RLV_CMD, str, id);
                    string option = llList2String(llParseString2List(str, ["="], []), 0);
                    string param = llList2String(llParseString2List(str, ["="], []), 1);
                    integer index = llListFindList(settings, [option]);
                    string opt1 = llList2String(llParseString2List(option, [":"], []), 0);
                    string opt2 = llList2String(llParseString2List(option, [":"], []), 1);
                    if (param == "n")
                    {
                        if (index == -1)
                        {   //we don't alread have this exact setting.  add it
                            settings += [option, param];
                        }
                        else
                        {   //we already have a setting for this option.  update it.
                            settings = llListReplaceList(settings, [option, param], index, index + 1);
                        }
                        llMessageLinked(LINK_THIS, HTTPDB_SAVE, dbtoken + "=" + llDumpList2String(settings, ","), NULL_KEY);
                    }
                    else if (param == "y")
                    {
                        if (index != -1)
                        {   //we already have a setting for this option.  remove it.
                            settings = llDeleteSubList(settings, index, index + 1);
                        }
                        if (llGetListLength(settings)>0)
                            llMessageLinked(LINK_THIS, HTTPDB_SAVE, dbtoken + "=" + llDumpList2String(settings, ","), NULL_KEY);
                        else
                            llMessageLinked(LINK_THIS, HTTPDB_DELETE, dbtoken, NULL_KEY);
                    }
                    if (remenu)
                    {
                        remenu = FALSE;
                        MainMenu(id);
                    }
                }
            }
            else if (str == "lockclothingmenu")
            {
                 if (!rlvon)
                {
                    Notify(id, "RLV features are now disabled in this collar. You can enable those in RLV submenu. Opening it now.", FALSE);
                    llMessageLinked(LINK_SET, SUBMENU, "RLV", id);
                    return;
                }
                menuuser = id;
                LockMenu(id);
            }
            else if (str == "lockattachmentmenu")
            {
                 if (!rlvon)
                {
                    Notify(id, "RLV features are now disabled in this collar. You can enable those in RLV submenu. Opening it now.", FALSE);
                    llMessageLinked(LINK_SET, SUBMENU, "RLV", id);
                    return;
                }
                menuuser = id;
                LockAttachmentMenu(id);
            }
            else  if (llGetSubString(str, 0, 11) == "lockclothing")            {
                string message = llGetSubString(str, 13, -1);
                if (num == COMMAND_WEARER)
                {
                    Notify(id, "Sorry you need owner privileges for locking clothes.", FALSE);
                }
                else if (message==ALL||str== "lockclothing")
                {
                    lockedItems += [ALL];
                    Notify(id, wearerName+"'s clothing has been locked.", TRUE);
                    llMessageLinked(LINK_THIS, num,  "remoutfit=n", id);
                    llMessageLinked(LINK_THIS, num,  "addoutfit=n", id);
                }
                else if (llListFindList(clothpoints+extraclothpoints,[message])!=-1)
                {
                    lockedItems += message;
                    Notify(id, wearerName+"'s "+message+" has been locked.", TRUE);
                    llMessageLinked(LINK_THIS, num,  "remoutfit:" + message + "=n", id);
                    llMessageLinked(LINK_THIS, num,  "addoutfit:" + message + "=n", id);
                }
                else Notify(id, "Sorry you must either specify a cloth name or not use a parameter (which locks all the clothing layers).", FALSE);
                if (remenu) LockMenu(id);
            }
            else if (llGetSubString(str, 0, 13) == "unlockclothing")
            {
                if (num == COMMAND_WEARER)
                {
                    Notify(id, "Sorry you need owner privileges for unlocking clothes.", FALSE);
                }
                else
                {
                    string message = llGetSubString(str, 15, -1);
                    if (message==ALL||str=="unlockclothing")
                    {
                        llMessageLinked(LINK_THIS, num,  "remoutfit=y", id);
                        llMessageLinked(LINK_THIS, num,  "addoutfit=y", id);
                        Notify(id, wearerName+"'s clothing has been unlocked.", TRUE);
                        integer index = llListFindList(lockedItems,[ALL]);
                        if (index!=-1) lockedItems = llDeleteSubList(lockedItems,index,index);
                    }
                    else
                    {
                        llMessageLinked(LINK_THIS, num,  "remoutfit:" + message + "=y", id);
                        llMessageLinked(LINK_THIS, num,  "addoutfit:" + message + "=y", id);
                        Notify(id, wearerName+"'s "+message+" has been unlocked.", TRUE);
                        integer index = llListFindList(lockedItems,[message]);
                        if (index!=-1) lockedItems = llDeleteSubList(lockedItems,index,index);
                    }
                }
                if (remenu) LockMenu(id);
            }
            else  if (llGetSubString(str, 0, 13) == "lockattachment")            {
                string message = llGetSubString(str, 15, -1);

                if (num == COMMAND_WEARER)
                {
                    Notify(id, "Sorry you need owner privileges for locking attachments.", FALSE);
                }
                else if (llListFindList(attachpoints ,[message])!=-1)
                {
                    lockedAttachments += message;
                    Notify(id, wearerName+"'s "+message+" has been locked.", TRUE);
                    llMessageLinked(LINK_THIS, num,  "detach:" + message + "=n", id);
                }
                else Notify(id, "Sorry you must either specify a attachment name.", FALSE);
                if (remenu) LockAttachmentMenu(id);
            }
            
            else if (llGetSubString(str, 0, 15) == "unlockattachment")
            {
                if (num == COMMAND_WEARER)
                {
                    Notify(id, "Sorry you need owner privileges for unlocking attachments.", FALSE);
                }
                else
                {
                    string message = llGetSubString(str, 17, -1);
                    {
                        llMessageLinked(LINK_THIS, num,  "detach:" + message + "=y", id);
                        Notify(id, wearerName+"'s "+message+" has been unlocked.", TRUE);
                        integer index = llListFindList(lockedAttachments,[message]);
                        if (index!=-1) lockedAttachments = llDeleteSubList(lockedAttachments,index,index);
                    }
                }
                if (remenu) LockAttachmentMenu(id);
            }
            else if (str == "refreshmenu")
            {
                submenus = [];
                llMessageLinked(LINK_SET, MENUNAME_REQUEST, submenu, NULL_KEY);
            }
            else if (str == "undress")
            {
                if (!rlvon)
                {
                    Notify(id, "RLV features are now disabled in this collar. You can enable those in RLV submenu. Opening it now.", FALSE);
                    llMessageLinked(LINK_SET, SUBMENU, "RLV", id);
                    return;
                }

                MainMenu(id);
            }
            else if (str == "clothing")
            {
                if (!rlvon)
                {
                    Notify(id, "RLV features are now disabled in this collar. You can enable those in RLV submenu. Opening it now.", FALSE);
                    llMessageLinked(LINK_SET, SUBMENU, "RLV", id);
                    return;
                }
                menuuser = id;
                QueryClothing();
            }
            else if (str == "attachment")
            {
                if (!rlvon)
                {
                    Notify(id, "RLV features are now disabled in this collar. You can enable those in RLV submenu. Opening it now.", FALSE);
                    llMessageLinked(LINK_SET, SUBMENU, "RLV", id);
                    return;
                }
                menuuser = id;
                QueryAttachments();
            }
        }
        // rlvoff -> we have to turn the menu off too
        else if (num>=COMMAND_OWNER && str=="rlvoff") rlvon=FALSE;

        // rlvoff -> we have to turn the menu off too
        else if (num == RLV_OFF) rlvon=FALSE;
        // rlvon -> we have to turn the menu on again
        else if (num == RLV_ON) rlvon=TRUE;
        
        else if (num == SUBMENU && str == submenu)
        {//give this plugin's menu to id
            MainMenu(id);
        }
        else if (num == MENUNAME_REQUEST && str == parentmenu)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        else if (num == HTTPDB_RESPONSE)
        {   //this is tricky since our db value contains equals signs
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
        {//rlvmain just started up.  Tell it about our current restrictions
            rlvon = TRUE;
            UpdateSettings();
        }
        else if (num == RLV_CLEAR)
        {   //clear db and local settings list
            ClearSettings();
        }
        else if (num == MENUNAME_RESPONSE)
        {
            list params = llParseString2List(str, ["|"], []);
            if (llList2String(params, 0)==submenu)
            {
                string child = llList2String(params, 1);
                //only add submenu if not already present
                if (llListFindList(submenus, [child]) == -1)
                {
                    submenus += [child];
                    submenus = llListSort(submenus, 1, TRUE);
                }
            }
        }
        else if (num == MENUNAME_REMOVE)
        {
            //str should be in form of parentmenu|childmenu
            list params = llParseString2List(str, ["|"], []);
            string child = llList2String(params, 1);
            if (llList2String(params, 0)==submenu)
            {
                integer index = llListFindList(submenus, [child]);
                //only remove if it's there
                if (index != -1)
                {
                    submenus = llDeleteSubList(submenus, index, index);
                }
            }
        }

    }

    listen(integer channel, string name, key id, string message)
    {
        llListenRemove(listener);
        llSetTimerEvent(0.0);
        if (channel == mainchannel)
        {
            page = 0;
            if (message == UPMENU)
            {
                llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);
            }
            else if (message == "Clothing")
            {
                menuuser = id;
                QueryClothing();
            }
            else if (message == "Attachment")
            {
                menuuser = id;
                QueryAttachments();
            }
            else if (message == "LockClothing")
            {
                menuuser = id;
                LockMenu(id);
            }
            else if (message == "LockAttachment")
            {
                menuuser = id;
                LockAttachmentMenu(id);
            }
            else if (llListFindList(submenus,[message]) != -1)
            {
                llMessageLinked(LINK_THIS, SUBMENU, message, id);
            }
            else
            {
                //something went horribly wrong.  We got a command that we can't find in the list
            }
        }
        else if (channel == clothrlv)
        {   //llOwnerSay(message);
            ClothingMenu(menuuser, message);
        }
        else if (channel == clothchannel)
        {
            if (message == UPMENU)
            {
                llMessageLinked(LINK_THIS, SUBMENU, submenu, id);
            }
            else if (message == ALL)
            { //send the RLV command to remove it.
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH,  "remoutfit=force", id);
                //Return menu
                menuuser = id;
                QueryClothing();
            }
            else
            { //we got a cloth point.
                message = llToLower(message);
                //send the RLV command to remove it.
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH,  "remoutfit:" + message + "=force", id);
                //Return menu
                menuuser = id;
                QueryClothing();
            }
        }
        else if (channel == lockchannel)
        {
            if (message == UPMENU)
            {
                llMessageLinked(LINK_THIS, SUBMENU, submenu, id);
            }
            else if (message == MORE)
            {
                page++;
                if (page * pagesize > buttoncount - 1)
                {
                    page = 0;
                }
                LockMenu(id);
            }
            else
            { //we got a cloth point.
                string cstate = llGetSubString(message,0,llStringLength(TICKED) - 1);
                message=llGetSubString(message,llStringLength(TICKED),-1);
                if (cstate==UNTICKED)
                {
                    llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "lockclothing "+message, id);
                }
                else if (cstate==TICKED)
                {
                    llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "unlockclothing "+message, id);
                }
                remenu = TRUE;
            }
        }
        else if (channel == lockattachchannel)
        {
            if (message == UPMENU)
            {
                llMessageLinked(LINK_THIS, SUBMENU, submenu, id);
            }
            else if (message == MORE)
            {
                page++;
                if (page * pagesize > buttoncount - 1)
                {
                    page = 0;
                }
                LockAttachmentMenu(id);
            }
            else
            { //we got a cloth point.
                string cstate = llGetSubString(message,0,llStringLength(TICKED) - 1);
                message=llGetSubString(message,llStringLength(TICKED),-1);
                if (cstate==UNTICKED)
                {
                    llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "lockattachment "+message, id);
                }
                else if (cstate==TICKED)
                {
                    llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "unlockattachment "+message, id);
                }
                remenu = TRUE;
            }
        }
        else if (channel == attachrlv)
        {
            DetachMenu(menuuser, message);
        }
        else if (channel == attachchannel)
        {
            if (message == UPMENU)
            {
                llMessageLinked(LINK_THIS, SUBMENU, submenu, id);
            }
            else if (message == MORE)
            {
                page++;
                if (page * pagesize > buttoncount - 1)
                {
                    page = 0;
                }
                QueryAttachments();
            }
            else
            {    //we got an attach point.  send a message to detach
                //we got a cloth point.
                message = llToLower(message);
                //send the RLV command to remove it.
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH,  "detach:" + message + "=force", id);
                //sleep for a sec to let tihngs detach
                llSleep(0.5);
                //Return menu
                menuuser = id;
                QueryAttachments();
            }
        }
    }

    timer()
    {
        llListenRemove(listener);
        llSetTimerEvent(0.0);
    }
    /* //no more needed
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
    */
    }
