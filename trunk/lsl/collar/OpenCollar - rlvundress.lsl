//give 3 menus:
    //Clothing
    //Attachment
    //Folder

string submenu = "Un/Dress";
string parentmenu = "RLV";

list children = ["Clothing","Attachment","+Folder","-Folder"];
list rlvcmds = ["attach","detach","remoutfit"];

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

string UPMENU = "~PrevMenu~";//when your menu hears this, give the parent menu

string MORE = "*More*";
string ALL = "*All*";

integer timeout = 30;
integer mainchannel = 583909;
integer clothchannel = 583910;
integer attachchannel = 583911;
integer folderchannel = 583912;

integer clothrlv = 78465;
integer attachrlv = 78466;
integer folderrlv = 78467;
integer listener;
key menuuser;
integer page = 0;
integer pagesize = 10;
integer buttoncount;
string foldertype;


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

MainMenu(key id)
{
    string prompt = "Select an option.";
    prompt += "\n(Menu will time out in " + (string)timeout + " seconds.)";
    list buttons = children;
    buttons += [UPMENU];
    buttons = RestackMenu(FillMenu(buttons));
    listener = llListen(mainchannel, "", id, "");
    llSetTimerEvent(timeout);
    llDialog(id, prompt, buttons, mainchannel);
}

QueryClothing()
{
    //open listener
    listener = llListen(clothrlv, "", llGetOwner(), "");
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
    list buttons = [ALL];
    integer stop = llGetListLength(clothpoints);
    integer n;
    for (n = 0; n < stop; n++)
    {
        integer worn = (integer)llGetSubString(str, n, n);
        if (worn)
        {
            buttons += [llList2String(clothpoints, n)];
        }
    }    
    buttons += [UPMENU];
    buttons = RestackMenu(FillMenu(buttons));
    listener = llListen(clothchannel, "", id, "");
    llSetTimerEvent(timeout);
    llDialog(id, prompt, buttons, clothchannel);    
}

QueryAttachments()
{
    //open listener
    listener = llListen(attachrlv, "", llGetOwner(), "");
    //start timer
    llSetTimerEvent(timeout);
    //send rlvcmd            
    llMessageLinked(LINK_THIS, RLV_CMD, "getattach=" + (string)attachrlv, NULL_KEY);    
}

DetachMenu(key id, string str)
{
    //remember not to add button for current object
    //str looks like 0110100001111
    //loop through clothpoints, look at char of str for each
    //for each 1, add capitalized button
    string prompt = "Select an attachment to remove.";
    prompt += "\n(Menu will time out in " + (string)timeout + " seconds.)";
    
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
    buttons = RestackMenu(FillMenu(buttons));
    listener = llListen(attachchannel, "", id, "");
    llSetTimerEvent(timeout);
    llDialog(id, prompt, buttons, attachchannel);     
}

QueryFolders()
{
    //open listener
    listener = llListen(folderrlv, "", llGetOwner(), "");
    //start timer
    llSetTimerEvent(timeout);
    //send rlvcmd            
    llMessageLinked(LINK_THIS, RLV_CMD, "getinv=" + (string)folderrlv, NULL_KEY);                     
}

FolderMenu(key id, string str)
{
    string prompt = "Select an outfit to " + foldertype + ".";
    prompt += "\n(Menu will time out in " + (string)timeout + " seconds.)";    
    //str will be in form of folder1,folder2,etc
    //build menu of folders.
    list buttons = llParseString2List(str, [","], []);
    buttons = llListSort(buttons, 1, TRUE);    
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
    
    buttons = CheckButtonLengths(buttons);
    
    buttons += [UPMENU];
    buttons = RestackMenu(FillMenu(buttons));
    listener = llListen(folderchannel, "", id, "");
    llSetTimerEvent(timeout);
    //check length of buttons, make sure none are > 24
    llDialog(id, prompt, buttons, folderchannel);
}

list CheckButtonLengths(list buttons)
{
    //return only buttons whose length <= 24
    //complain about others
    integer n;
    integer stop = llGetListLength(buttons);
    list out;
    for (n = 0; n < stop; n++)
    {
        string button = llList2String(buttons, n);
        integer length = llStringLength(button);
        if (length > 24)
        {
            llOwnerSay("The folder '" + button + "' has " + (string)length + " characters.  It cannot be used for Restrained Life automatic wearing until you rename it to have 24 characters or fewer.");
        }
        else
        {
            out += [button];
        }
    }
    return out;
}

default
{
    state_entry()
    {
        mainchannel = llRound(llFrand(9999999.0));
        clothchannel = llRound(llFrand(9999999.0));
        attachchannel = llRound(llFrand(9999999.0));
        folderchannel = llRound(llFrand(9999999.0));          
        llSleep(1.0);              
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);        
    }
    
    link_message(integer sender, integer num, string str, key id)
    {
        if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
        {
            //the command was given by either owner, secowner, group member, or wearer
            list params = llParseString2List(str, [":", "="], []);
            string command = llList2String(params, 0);
            if (llListFindList(rlvcmds, [command]) != -1)
            {
                //we've received an RLV command that we control.  only execute if not sub
                if (num == COMMAND_WEARER)
                {
                    llInstantMessage(llGetOwner(), "Sorry, but RLV commands may only be given by owner, secowner, or group (if set).");
                }
                else
                {
                    llMessageLinked(LINK_THIS, RLV_CMD, str, id);
                }
            }
        }
        else if (num == SUBMENU && str == submenu)
        {
            //give this plugin's menu to id
            MainMenu(id);
        }
        else if (num == MENUNAME_REQUEST && str == parentmenu)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
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
            else if (message == "+Folder")
            {
                foldertype = "wear";
                menuuser = id;
                QueryFolders();                 
            }
            else if (message == "-Folder")
            {
                foldertype = "remove";
                menuuser = id;
                QueryFolders();             
            }
        }
        else if (channel == clothrlv)
        {
            //llOwnerSay(message);
            ClothingMenu(menuuser, message);
        }
        else if (channel == clothchannel)
        {
            if (message == UPMENU)
            {
                llMessageLinked(LINK_THIS, SUBMENU, submenu, id);                
            }
            else if (message == ALL)
            {
                //send the RLV command to remove it. 
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH,  "remoutfit=force", id);
                //Return menu
                menuuser = id;                
                QueryClothing();                
            }
            else
            {
                //we got a cloth point.
                message = llToLower(message);
                //send the RLV command to remove it. 
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH,  "remoutfit:" + message + "=force", id);
                //Return menu
                menuuser = id;                
                QueryClothing(); 
            }
        }
        else if (channel == attachrlv)
        {
            //llOwnerSay(message);
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
            {
                //we got an attach point.  send a message to detach
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
        else if (channel == folderrlv)
        {
            //we got a list of folders
            FolderMenu(menuuser, message);
        }
        else if (channel == folderchannel)
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
                QueryFolders();
            }
            else
            {
                //we got a folder.  send a message to detach
                message = llToLower(message);
                //send the RLV command to remove it. 
                if (foldertype == "wear")
                {
                    llMessageLinked(LINK_THIS, COMMAND_NOAUTH,  "attach:" + message + "=force", id);                    
                }
                else if (foldertype == "remove")
                {
                    llMessageLinked(LINK_THIS, COMMAND_NOAUTH,  "detach:" + message + "=force", id);
                }
                //Return menu
                menuuser = id;                
                QueryFolders();
            }
        }
    }
    
    timer()
    {
        llListenRemove(listener);
        llSetTimerEvent(0.0);
    }
}
