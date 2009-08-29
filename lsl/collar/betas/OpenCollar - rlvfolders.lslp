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
//string ALL = "*All*";
//string SELECT_CURRENT = "*This*";
string ATTACH_ALL = "(+) *All*";
string DETACH_ALL = "(-) *All*";
string ATTACH_THIS = "(+) *This*";
string DETACH_THIS = "(-) *This*";
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
string prompt;
string foldertype; //what to do with those folders
string currentfolder;

string dbtoken = "folders";
integer remenu = FALSE;

list outfit; //saved folder list
list tocheck; //stack of folders to check, used for subfolder tree search

list searchlist; //list of folders to search

list longfolders; //full names of the subfolders in current folder 
list shortfolders; //shortened names of the subfolders in current folder 

key wearer;


debug(string msg)
{
//    llOwnerSay(llGetScriptName() + ": " + msg);
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

parentfolder() {
    list folders = llParseString2List(currentfolder,["/"],[]);
    if (llGetListLength(folders)>1) {
        currentfolder=llList2String(folders,0);
        integer i;
        for (i=1;i<llGetListLength(folders)-1;i++) currentfolder+="/"+llList2String(folders,i);
    }
    else currentfolder="";
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

FolderMenu(string str)
{
    page = 0;
    prompt = "";
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
    shortfolders = [];
    longfolders = [];
//    if (rlvver<115) buttons= data;
//    else {
        for (i=1;i<llGetListLength(data);i++) {
            item=llParseString2List(llList2String(data,i),["|"],[]);
            string folder = llList2String(item,0);
            worn=llList2Integer(item,1);
            if  (worn%10>=1)
            {
                longfolders += folder;
                shortfolders += [llGetSubString(FOLDER+folder,0,20)];
            }
            else if  (worn==10)
            {
                longfolders += folder;
                shortfolders += [llGetSubString(UNTICKED+folder,0,20)];
            }
            else if  (worn==20)
            {
                longfolders += folder;
                shortfolders += [llGetSubString(STICKED+folder,0,20)];
            }
            else if  (worn==30)
            {
                longfolders += folder;
                shortfolders += [llGetSubString(TICKED+folder,0,20)];
            }
        }
//    }
//    buttons = llListSort(buttons, 1, TRUE);    
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
                if  (worn%10==1)  {shortfolders+= [ATTACH_ALL]; longfolders+=[];}
                else if  (worn%10==2)  {shortfolders+= [ATTACH_ALL, DETACH_ALL]; longfolders+=[];}
                else if  (worn%10==3)  {shortfolders+= [DETACH_ALL]; longfolders+=[];}
                // and only then add the button for current foldder... if it makes also sense
                if  (worn/10==1)  {shortfolders+= [ATTACH_THIS]; longfolders+=[];}
                else if  (worn/10==2)  {shortfolders+= [ATTACH_THIS, DETACH_THIS]; longfolders+=[];}
                else if  (worn/10==3)  {shortfolders+= [DETACH_THIS]; longfolders+=[];}
            }
//        }
//        if ((rlvver>=115&&llGetListLength(data)<=1)||llGetListLength(data)<=0) prompt = "\n\nEither your #RLV folder is empty, or you did not set up your shared folders.\nCheck Real Restraint blog for more information.";
//        else
        if (shortfolders==[]) prompt = "\n\nThere is no item to "+foldertype+" in the current folder.";
        else mdialog();

}


mdialog()
{
    list buttons;
    integer buttoncount = llGetListLength(shortfolders);
    if (buttoncount > 11)
    {
        //get the subpart of buttons that corresponds to the current page
        integer start = page * pagesize;
        integer end = page * pagesize + (pagesize - 1);
        if (end > buttoncount - 1)
        {
            end = buttoncount - 1;
        }
        buttons = llList2List(shortfolders, start, end);
        buttons += [MORE];
    }
    else buttons = shortfolders;
    buttons += [UPMENU];
    buttons = RestackMenu(buttons);
    listener = llListen(folderchannel, "", menuuser, "");
    llSetTimerEvent(timeout);
    llDialog(menuuser, prompt, buttons, folderchannel);
}

SaveFolder(string str)
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
        Notify(menuuser,"Current outfit has been saved.", TRUE);
        if (remenu) {remenu=FALSE;  llMessageLinked(LINK_THIS, SUBMENU, parentmenu, menuuser);}
    }
}



handleMultiSearch()
{
    string item=llList2String(searchlist,0);
    string searchstring;
    searchlist=llDeleteSubList(searchlist,0,0);
    if (llGetSubString(item,0,1)=="++")
    {
        foldertype = "searchattachall";
        searchstring = llToLower(llGetSubString(item,2,-1));
    }
    else if (llGetSubString(item,0,0)=="+")
    {
        foldertype = "searchattach";
        searchstring = llToLower(llGetSubString(item,1,-1));
    }
    else if (llGetSubString(item,0,1)=="--")
    {
        foldertype = "searchdetachall";
        searchstring = llToLower(llGetSubString(item,2,-1));
    }
    else if (llGetSubString(item,0,0)=="-")
    {
        foldertype = "searchdetach";
        searchstring = llToLower(llGetSubString(item,1,-1));
    }
    //open listener
    listener = llListen(folderrlv, "", llGetOwner(), "");
    //start timer
    llSetTimerEvent(timeout);
    llMessageLinked(LINK_THIS, RLV_CMD,  "findfolder:"+searchstring+"="+(string)folderrlv, NULL_KEY);       
}

default
{
    state_entry()
    {
        wearer = llGetOwner();
        folderchannel = -9999 - llRound(llFrand(9999999.0));          
        folderrlv = 9999 + llRound(llFrand(9999999.0));
        /* //no more needed         
        llSleep(1.0);
        integer i;
        for (i=0;i < llGetListLength(children);i++)              
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + llList2String(children,i), NULL_KEY);
        }
        */
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
            if (llToLower(str) == "#rlv")
            {
                currentfolder = "";
                foldertype="browse";
                QueryFolders(); 
            }
            else if (str=="save")
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
                Notify(id, "Saved outfit has been restored.", TRUE );
            }
            else if (llGetSubString(str,0,0)=="+"||llGetSubString(str,0,0)=="-")
            {
                searchlist=llParseString2List(str,[","],[]);
                handleMultiSearch();
            }
        }  
    } 
    
    listen(integer channel, string name, key id, string message)
    {
        llListenRemove(listener);
        llSetTimerEvent(0.0);
        if (channel == folderrlv)
        {   //we got a list of folders
            if (foldertype=="browse") FolderMenu(message);
            else if (foldertype=="save") SaveFolder(message);
            else if (llGetSubString(foldertype,0,5)=="search")
            {
                if (message=="") Notify(id,message+"No matching folder found", FALSE);
                else
                {
                    llMessageLinked(LINK_THIS, RLV_CMD,  llGetSubString(foldertype,6,-1)+":"+message+"=force", NULL_KEY);
                    Notify(menuuser, "Now "+llGetSubString(foldertype,6,11)+"ing "+message, TRUE);
                }
                if (searchlist!=[]) handleMultiSearch();
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
                if (page * pagesize > llGetListLength(shortfolders) - 1)
                {
                    page = 0;
                }
                mdialog();
            }
            else
            { //we got a folder.  send a message to detach
                //send the RLV command to remove it.
                integer index = llListFindList(shortfolders,[message]);
                string oldfolder = currentfolder;
                if (message == ATTACH_THIS)
                {
                    llMessageLinked(LINK_THIS, RLV_CMD,  "attach" + currentfolder + "=force", NULL_KEY);
                    Notify(id, "Now attaching "+currentfolder, TRUE);
                }
                else if (message == DETACH_THIS)
                {
                    llMessageLinked(LINK_THIS, RLV_CMD,  "detach" + currentfolder + "=force", NULL_KEY);
                    Notify(id, "Now detaching "+currentfolder, TRUE);
                }
                else if (message == ATTACH_ALL)
                {
                    llMessageLinked(LINK_THIS, RLV_CMD,  "attachall" + currentfolder + "=force", NULL_KEY);
                    Notify(id, "Now attaching everything in "+currentfolder, TRUE);
                }
                else if (message == DETACH_ALL)
                {
                    llMessageLinked(LINK_THIS, RLV_CMD,  "detachall" + currentfolder + "=force", NULL_KEY);
                    Notify(id, "Now detaching everything in "+currentfolder, TRUE);
                }
                else if (index != -1)
                {
                    string cstate = llGetSubString(message,0,llStringLength(TICKED) - 1);
                    string newfolder;
                    string folder = llList2String(longfolders,index);
                    if (currentfolder=="") newfolder=":"+folder;
                    else newfolder = currentfolder + "/" + folder;
                    if (cstate==FOLDER || cstate==STICKED) currentfolder=newfolder;
                    else if (cstate==TICKED)
                    {
                        llMessageLinked(LINK_THIS, RLV_CMD,  "detach" + newfolder + "=force", NULL_KEY);
                        Notify(id, "Now detaching "+newfolder, TRUE);
                    }
                    else if (cstate==UNTICKED)
                    {
                        llMessageLinked(LINK_THIS, RLV_CMD,  "attach" + newfolder + "=force", NULL_KEY);
                        Notify(id ,"Now attaching "+newfolder, TRUE);
                    }
                }
                if (oldfolder==currentfolder) llSleep(1.0); //time for command to take effect so that we see the result in menu
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
/* //no more self resets
    on_rez(integer param)
    {
        llResetScript();
    }
    */
}
