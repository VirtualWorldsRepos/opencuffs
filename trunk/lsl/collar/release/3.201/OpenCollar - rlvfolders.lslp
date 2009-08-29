//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//give 4 menus:
    //Folder

integer rlvver = 115; //temporary hack until we can parse the version string in a sensible way
//string submenu = "#RLV Folder";
string parentmenu = "Un/Dress";

list children = ["Browse #RLV","Save","Restore"];

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

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer MENUNAME_REMOVE = 3003;

integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.
integer RLV_VERSION = 6003; //RLV Plugins can recieve the used rl viewer version upon receiving this message..
/* // unicode characters
string UPMENU = "↑";
string MORE = "→";
string ALL = "*All*";
string SELECT_CURRENT = "*This*";
string TICKED = "☒";
string STICKED = "☑";
string UNTICKED = "☐";
string FOLDER = "↳";
*/ //#############

string UPMENU = "^";
string MORE = ">";
string ALL = "*All*";
string SELECT_CURRENT = "*This*";
string TICKED = "(*)";  //checked
string STICKED = "(.)";   //partchecked
string UNTICKED = "( )";
string FOLDER = " / ";

integer timeout = 60;
integer folderchannel = 583912;
integer folderrlv = 78467;

integer listener;
key menuuser;
integer page = 0;
integer pagesize = 10;
integer buttoncount;
string foldertype; //what to do with those folders
string currentfolder;

string dbtoken = "folders";
integer remenu = FALSE;

list outfit; //saved folder list
list tocheck; //stack of folders to check, used for subfolder tree search
string searchstring; //search pattern

debug(string msg)
{
//    llOwnerSay(llGetScriptName() + ": " + msg);
}

parentfolder() {
    list folders = llParseString2List(currentfolder,["/"],[]);
    if (llGetListLength(folders)>1) {
        currentfolder=llList2String(folders,0);
        integer i;
        for (i=1;i<llGetListLength(folders)-1;i++) currentfolder+="/"+llList2String(folders,i);
    }
    else currentfolder="";
}

list FillMenu(list in)
{    //adds empty buttons until the list length is multiple of 3, to max of 12
    while (llGetListLength(in) != 3 && llGetListLength(in) != 6 && llGetListLength(in) != 9 && llGetListLength(in) < 12)
    {
        in += [" "];
    }
    return in;
}

list RestackMenu(list in)
{    //re-orders a list so dialog buttons start in the top row
    list out = llList2List(in, 9, 11);
    out += llList2List(in, 6, 8);
    out += llList2List(in, 3, 5);    
    out += llList2List(in, 0, 2);    
    return out;
}


QueryFolders()
{    //open listener
    listener = llListen(folderrlv, "", llGetOwner(), "");
    //start timer
    llSetTimerEvent(timeout);
    //send rlvcmd            
    //if (rlvver<115) llMessageLinked(LINK_THIS, RLV_CMD, "getinv"+currentfolder+"=" + (string)folderrlv, NULL_KEY);
    //RLV 1.15: getinvworn gives more data                     
    //else
    llMessageLinked(LINK_THIS, RLV_CMD, "getinvworn"+currentfolder+"=" + (string)folderrlv, NULL_KEY);                     
}

FolderMenu(key id, string str)
{
    string prompt = "";
//    if (rlvver>=115) prompt += "\nOnly folders with items you can "+foldertype+" are shown.";
    prompt+="\n"+UNTICKED+": nothing worn. Make the sub wear it.";
    prompt+="\n"+STICKED+": some items worn. Make the sub remove them.";
    prompt+="\n"+TICKED+": all items worn. Make the sub remove them.";
    prompt+="\n"+FOLDER+": this folder has subfolders. Browse it.";
    prompt += "\n(Menu will time out in " + (string)timeout + " seconds.)";
    //str will be in form of folder1,folder2,etc   <- RLV 1.15: not anymore:  |xx,folder1|xx,folder2|xx,etc
    //build menu of folders.
    //    list buttons = llParseString2List(str, [","], []);
    list data = llParseString2List(str, [","], []);
    integer i; list item; integer worn;
    list buttons = [];
//    if (rlvver<115) buttons= data;
//    else {
        for (i=1;i<llGetListLength(data);i++) {
            item=llParseString2List(llList2String(data,i),["|"],[]);
            worn=llList2Integer(item,1);
            buttoncount++;
            if  (worn%10>=1)  buttons+= [FOLDER+llList2String(item,0)];
            else if  (worn==10)  buttons+= [UNTICKED+llList2String(item,0)];
            else if  (worn==20)  buttons+= [STICKED+llList2String(item,0)];
            else if  (worn==30)  buttons+= [TICKED+llList2String(item,0)];
            else buttoncount--;
        }
//    }
    buttons = llListSort(buttons, 1, TRUE);    
    buttoncount = llGetListLength(buttons);
/*    if (buttoncount < 1 && currentfolder!="") {
        if (foldertype == "wear")
            llMessageLinked(LINK_THIS, RLV_CMD,  "attach" + currentfolder + "=force", NULL_KEY);
        else if (foldertype == "remove")
            llMessageLinked(LINK_THIS, RLV_CMD,  "detach" + currentfolder + "=force", NULL_KEY);
        parentfolder();
        menuuser = id;                
        QueryFolders();
    }
    else
    {
        if (rlvver>=115) {
*/
            item=llParseString2List(llList2String(data,0),["|"],[]);
            worn=llList2Integer(item,0);
            // now add the button for wearing all recursively when it makes sense
            if (currentfolder!="") {
                if  (worn%10==1)  buttons+= [UNTICKED+ALL];
                else if  (worn%10==2)  buttons+= [STICKED+ALL];
                else if  (worn%10==3)  buttons+= [TICKED+ALL];
                else buttoncount--;
                buttoncount+=2;
                // and only then add the button for current foldder... if it makes also sense
                if  (worn/10==1)  buttons+= [UNTICKED+SELECT_CURRENT];
                else if  (worn/10==2)  buttons+= [STICKED+SELECT_CURRENT];
                else if  (worn/10==3)  buttons+= [TICKED+SELECT_CURRENT];
                else buttoncount--;
            }
//        }
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
//        if ((rlvver>=115&&llGetListLength(data)<=1)||llGetListLength(data)<=0) prompt = "\n\nEither your #RLV folder is empty, or you did not set up your shared folders.\nCheck Real Restraint blog for more information.";
//        else 
        if (buttoncount<1) prompt = "\n\nThere is no item to "+foldertype+" in the current folder.";
        else //check length of buttons, make sure none are > 24
        {
            if ((buttons = CheckButtonLengths(buttons)) != buttons)
            {
                prompt+="\n\nAt least one folder has a too long name (> 21 characters) and cannot be displayed. Please rename it.";
                llOwnerSay("At least one folder has a too long name (> 21 characters) and cannot be displayed. Please rename it.");
            }
        buttons += [UPMENU];
        buttons = RestackMenu(FillMenu(buttons));
        listener = llListen(folderchannel, "", id, "");
        llSetTimerEvent(timeout);
        llDialog(id, prompt, buttons, folderchannel);
    }
}

SaveFolder(key id, string str)
{
    list data = llParseString2List(str, [","], []);
    integer i; list item; integer worn;
    if (currentfolder=="") currentfolder=":"; else currentfolder+="/";
    for (i=1;i<llGetListLength(data);i++) {
        item=llParseString2List(llList2String(data,i),["|"],[]);
        worn=llList2Integer(item,1);
        if (worn>=30) outfit+=[currentfolder+llList2String(item,0)];
        else if (worn>=20) outfit=[currentfolder+llList2String(item,0)]+outfit;
        if (worn%10>=2) tocheck+=[currentfolder+llList2String(item,0)];
    }
    if (llGetListLength(tocheck)>0)
    {
        currentfolder=llList2String(tocheck,-1);
        tocheck=llDeleteSubList(tocheck,-1,-1);
        QueryFolders();
    }
    else
    {
        llInstantMessage(id,"Current outfit has been saved.");
        if (id!=llGetOwner()) llInstantMessage(llGetOwner(),"Your current outfit has been saved.");
        if (remenu) {remenu=FALSE;  llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);}
    }
}


list CheckButtonLengths(list buttons)
{    //return only buttons whose length <= 24
    //complain about others
    integer n;
    integer stop = llGetListLength(buttons);
    list out;
    for (n = 0; n < stop; n++)
    {
        string button = llList2String(buttons, n);
        integer length = llStringLength(button)-1; //number of *chars* (not bytes) in the folder name
//        if (length > 21) //the limit is 21 instead of 23 because the unicode symbols we use have 3 bytes
//        {
//            llOwnerSay("The folder '" + llGetSubString(button,1,-1) + "' has " + (string)length + " characters.  It cannot be used for Restrained Life automatic wearing until you rename it to have 21 characters or fewer.");
//        }
//        else
        if (length <= 21)
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
        folderchannel = -9999 - llRound(llFrand(9999999.0));          
        folderrlv = 9999 + llRound(llFrand(9999999.0));          
        llSleep(1.0);
        integer i;
        for (i=0;i < llGetListLength(children);i++)              
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + llList2String(children,i), NULL_KEY);
        }
    }
    
    link_message(integer sender, integer num, string str, key id)
    {
        if (num == MENUNAME_REQUEST && str == parentmenu)
        {
            integer i;
            for (i=0;i < llGetListLength(children);i++)              
            {
                llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + llList2String(children,i), NULL_KEY);
            }
        }
        else if (num == SUBMENU && llListFindList(children,[str]) != -1)
        {
            page = 0;
/*            if (str == "+Folder")
            {
                foldertype = "wear";
                currentfolder = "";
                menuuser = id;
                QueryFolders();                 
            }
            else if (str == "-Folder")
            {
                foldertype = "remove";
                currentfolder = "";
                menuuser = id;
                QueryFolders();             
            }
else */
            if (str == "Browse #RLV")
            {
                currentfolder = "";
                foldertype="browse";
                menuuser = id;
                QueryFolders();             
            }
            else if (str == "Save")
            {
                remenu=TRUE;
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "save", id);
            }
            else if (str == "Restore")
            {
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "restore", id);
                llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);;
            }
            else
            {
                //should not happen
            }
        }
        else if (num == RLV_VERSION)
        {   //get rlv version
            rlvver=(integer) str;
        }  
        else if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
        {
            menuuser = id;
            if (str=="save")
            {
                foldertype = "save";
                currentfolder = "";
                outfit=[];
                tocheck=[];
                QueryFolders();
            }
            else if (str=="restore")
            {
                integer i;
                for (i=0; i<=llGetListLength(outfit);i++)
                    llMessageLinked(LINK_THIS, RLV_CMD,  "attach" + llList2String(outfit,i) + "=force", NULL_KEY);
                llInstantMessage(id,"Saved outfit has been restored.");
                if (id!=llGetOwner()) llInstantMessage(llGetOwner(),"Current outfit has been saved.");
            }
            else if (llGetSubString(str,0,0)=="+")
            {
                foldertype = "searchwear";
                searchstring = llToLower(llGetSubString(str,1,-1));
                //open listener
                listener = llListen(folderrlv, "", llGetOwner(), "");
                //start timer
                llSetTimerEvent(timeout);
                llMessageLinked(LINK_THIS, RLV_CMD,  "findfolder:"+searchstring+"="+(string)folderrlv, NULL_KEY);       
            }
            else if (llGetSubString(str,0,0)=="-")
            {
                foldertype = "searchremove";
                //open listener
                listener = llListen(folderrlv, "", llGetOwner(), "");
                //start timer
                llSetTimerEvent(timeout);
                searchstring = llToLower(llGetSubString(str,1,-1));
                llMessageLinked(LINK_THIS, RLV_CMD,  "findfolder:"+searchstring+"="+(string)folderrlv, NULL_KEY);       
            }
        }  
    } 
    
    listen(integer channel, string name, key id, string message)
    {
        llListenRemove(listener);
        llSetTimerEvent(0.0);
        if (channel == folderrlv)
        {   //we got a list of folders
            if (foldertype=="browse") FolderMenu(menuuser, message);
            else if (foldertype=="save") SaveFolder(menuuser,message);
            else if (foldertype=="searchwear")
            {
                if (message=="") llInstantMessage(id,message+"No matching folder found");
                else
                {
                    llMessageLinked(LINK_THIS, RLV_CMD,  "attachall:"+message+"=force", NULL_KEY);
                    llInstantMessage(llGetOwner(),"Now attaching "+message);
                    if (menuuser!=llGetOwner()) llInstantMessage(menuuser,"Now attaching "+llKey2Name(llGetOwner())+"'s "+message);
                }    
            }
            else if (foldertype=="searchremove")
            {
                if (message=="") llInstantMessage(id,"No matching folder found");
                else
                {
                    llMessageLinked(LINK_THIS, RLV_CMD,  "detachall:"+message+"=force", NULL_KEY);
                    llInstantMessage(llGetOwner(),"Now detaching "+message);
                    if (menuuser!=llGetOwner()) llInstantMessage(menuuser,"Now detaching "+llKey2Name(llGetOwner())+"'s "+message);
                }    
            }
        }
        else if (channel == folderchannel)
        {
            if (message == UPMENU)
            {
                if (currentfolder=="") llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);
                else {
                    parentfolder();
                    QueryFolders();
                }
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
            { //we got a folder.  send a message to detach
                message = llToLower(message);
                //send the RLV command to remove it.
/*                if (rlvver<113) {
                    if (foldertype == "wear")
                        llMessageLinked(LINK_THIS, RLV_CMD,  "attach:" + message + "=force", NULL_KEY);
                    else if (foldertype == "remove")
                        llMessageLinked(LINK_THIS, RLV_CMD,  "detach:" + message + "=force", NULL_KEY);}
                else
*/
                    
                //string cstate=llGetSubString(message,0,0);
                //message=llGetSubString(message,1,-1);
                // with no unicode we use 3 chars to indicate checked etc...
                string cstate = llGetSubString(message,0,llStringLength(TICKED) - 1);
                message=llGetSubString(message,llStringLength(TICKED),-1);
                string newfolder;
                if (currentfolder=="") newfolder=":"+message; else newfolder = currentfolder + "/" + message;
                if (cstate==FOLDER) currentfolder=newfolder;
                else if (cstate==TICKED||cstate==STICKED)
                {
                    if (message== llToLower(ALL))
                    {
                        llMessageLinked(LINK_THIS, RLV_CMD,  "detachall" + currentfolder + "=force", NULL_KEY);
                        llInstantMessage(llGetOwner(),"Now detaching everything in "+currentfolder);
                        if (id!=llGetOwner()) llInstantMessage(id,"Now detaching everything in "+currentfolder);
                    }
                    else if (message== llToLower(SELECT_CURRENT))
                    {
                        llMessageLinked(LINK_THIS, RLV_CMD,  "detach" + currentfolder + "=force", NULL_KEY);
                        llInstantMessage(llGetOwner(),"Now detaching "+currentfolder);
                        if (id!=llGetOwner()) llInstantMessage(id,"Now detaching "+currentfolder);
                    }
                    else 
                    {
                        llMessageLinked(LINK_THIS, RLV_CMD,  "detach" + newfolder + "=force", NULL_KEY);
                        llInstantMessage(llGetOwner(),"Now detaching "+newfolder);
                        if (id!=llGetOwner()) llInstantMessage(id,"Now detaching "+newfolder);
                    }
                    llSleep(1);
                }
                else if (cstate==UNTICKED)
                {
                    if (message== llToLower(ALL))
                    {
                        llMessageLinked(LINK_THIS, RLV_CMD,  "attachall" + currentfolder + "=force", NULL_KEY);
                        llInstantMessage(llGetOwner(),"Now attaching everything in "+currentfolder);
                        if (id!=llGetOwner()) llInstantMessage(id,"Now attaching everything in "+currentfolder);
                    }
                    else if (message== llToLower(SELECT_CURRENT))
                    {
                        llMessageLinked(LINK_THIS, RLV_CMD,  "attach" + currentfolder + "=force", NULL_KEY);
                        llInstantMessage(llGetOwner(),"Now attaching "+currentfolder);
                        if (id!=llGetOwner()) llInstantMessage(id,"Now attaching "+currentfolder);
                        
                    }
                
                    else
                    {
                        llMessageLinked(LINK_THIS, RLV_CMD,  "attach" + newfolder + "=force", NULL_KEY);
                        llInstantMessage(llGetOwner(),"Now attaching "+newfolder);
                        if (id!=llGetOwner()) llInstantMessage(id,"Now attaching "+newfolder);
                    }
                    llSleep(1);
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

//    changed(integer change)
//    {
//        if (change & CHANGED_OWNER)
//        {
//            llResetScript();
//        }
//    }

    on_rez(integer param)
    {
        llResetScript();
    }
}
