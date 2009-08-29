//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
//integer CHAT = 505;//deprecated
integer COMMAND_OBJECT = 506;
integer COMMAND_RLV_RELAY = 507;
integer COMMAND_SAFEWORD = 510;
integer COMMAND_RELAY_SAFEWORD = 511;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer MENUNAME_REMOVE = 3003;

integer RLVR_CMD = 6010; //let's do that for now


string parentmenu = "RLV";
string submenu = "Relay";
integer remenu = FALSE;

//string UPMENU = "↑";
//string MORE = "→";
string UPMENU = "^";
string MORE = ">";
string ALL = "*All*";


list chatcommands=["auto","ask","restricted","off","safeword","safeword on","safeword off","playful on", "playful off","land on","land off","pending","access"];
list prettycommands=["Auto","Ask","Restricted","Off","Safeword", "( )Safeword", "(*)Safeword","( )Playful","(*)Playful","( )Land","(*)Land","Pending","Access Lists"];
//list prettycommands=["Auto","Ask","Restricted","Off","Safeword", "☐Safeword", "☒Safeword","☐Playful","☒Playful","☐Land","☒Land","Pending","Access Lists"];

integer RELAY_CHANNEL = -1812221819;
integer MENU_CHANNEL;
integer AUTH_MENU_CHANNEL;
integer LIST_MENU_CHANNEL;
integer LIST_CHANNEL;
integer SIT_CHANNEL;
string PROTOCOL_VERSION = "1030"; //with some additions, but backward compatible, nonetheless
string IMPL_VERSION = "Satomi's Multi-Relay v0.25";

string mode="ask";
integer safe=TRUE;
integer playful=FALSE;
integer land=FALSE;

list sources=[];
//list users=[];
key lastuser=NULL_KEY;
list tempwhitelist=[];
list tempblacklist=[];
list tempuserwhitelist=[];
list tempuserblacklist=[];
list objwhitelist=[];
list objblacklist=[];
list avwhitelist=[];
list avblacklist=[];
list objwhitelistnames=[];
list objblacklistnames=[];
list avwhitelistnames=[];
list avblacklistnames=[];


list queue=[];
integer QSTRIDES=3;
integer listener=0;
integer authlistener=0;
string timertype="";
string listtype;
integer MAXLOAD=8;    //prevents stack-heap collisions due to malicious devices

//message map
integer CMD_ADDSRC = 11;
integer CMD_REMSRC = 12;


integer ischannelcommand(string cmd)
{
    return (llSubStringIndex(cmd,"@version")==0)||(llSubStringIndex(cmd,"@get")==0)||(llSubStringIndex(cmd,"@findfolder")==0);
}

integer iswho(string cmd)
{
    return llGetSubString(cmd,0,4)=="!who/";
}
key getwho(string cmd)
{
    if (iswho(cmd)) return (key)llGetSubString(cmd,5,40);
    else return NULL_KEY;
}

integer auth(key object, key user)
{
    integer auth=1;
    //object auth
    integer source_index=llListFindList(sources,[object]);
    if (source_index!=-1) {}
    else if (llListFindList(tempblacklist+objblacklist,[object])!=-1) return -1;
    else if (llListFindList(avblacklist,[llGetOwnerKey(object)])!=-1) return -1;
    else if (mode=="auto") {}
    else if (land && llGetOwnerKey(object)==llGetLandOwnerAt(llGetPos())) {}
    else if (llListFindList(tempwhitelist+objwhitelist,[object])!=-1) {}
    else if (llListFindList(avwhitelist,[llGetOwnerKey(object)])!=-1) {}
    else if (mode=="restricted") return -1;
    else auth=0;
    //user auth
    if (user==NULL_KEY) {}
//    else if (source_index!=-1&&user==(key)llList2String(users,source_index)) {}
    else if (user==lastuser) {}
    else if (llListFindList(avblacklist+tempuserblacklist,[user])!=-1) return -1;
    else if (mode=="auto") {}
    else if (llListFindList(avwhitelist+tempuserwhitelist,[user])!=-1) {}
    else if (mode=="restricted") return -1;
    else return 0;

    return auth;
}

//--- queue and command handling functions section---//
string getqident(integer i)
{
    return llList2String(queue,QSTRIDES*i);
}

key getqobj(integer i)
{
    return (key)llList2String(queue,QSTRIDES*i+1);
}

string getqcom(integer i)
{
    return llList2String(queue,QSTRIDES*i+2);
}

deleteqitem(integer i)
{
    queue=llDeleteSubList(queue,i,i+QSTRIDES-1);
}

integer getqlength()
{
    return llGetListLength(queue)/QSTRIDES;
}


enqueue(string  msg, key id)
{
    list args=llParseString2List(msg,[","],[]);
    if (llGetListLength(args)!=3) return;
    if (llList2String(args,1)!=(string)llGetOwner()) return;
    string ident=llList2String(args,0);
    string command=llToLower(llList2String(args,2));
    integer auth=auth(id,getwho(command));
    if (auth==1) handlecommand(ident,id,command,TRUE);
    else if (auth!=-1&&getqlength()<MAXLOAD) //keeps margin for this event + next arriving chat message
    {
        queue+=[ident, id, command];
        if (authlistener==0) dequeue();
    }
    else llShout(RELAY_CHANNEL,ident+","+(string)id+","+command+",ko");
}

dequeue()
{
    if (queue==[])
    {
        timertype="expire";
        llSetTimerEvent(5);
        return;
    }
    string curident=getqident(0);
    key curid=getqobj(0);
    string command=getqcom(0);
    key user;
    string newcommand=handlecommand(curident,curid,command,FALSE);
    deleteqitem(0);
    if (newcommand=="")
    {
        dequeue();
    }
    else
    {
        queue=[curident,curid,newcommand]+queue;
        timertype="authmenu";
        llSetTimerEvent(120);
        AUTH_MENU_CHANNEL=-9999 - llFloor(llFrand(9999999.0));
        list buttons=["Yes","No","Trust Object","Ban Object","Trust Owner","Ban Owner"];
        string owner=llKey2Name(llGetOwnerKey(curid));
        if (owner!="") owner= ", owned by "+owner+",";
        string prompt=llKey2Name(curid)+owner+" wants to control your viewer.";
        if (iswho(command))
        {
            buttons+=["Trust User","Ban User"];
            prompt+="\n"+llKey2Name(getwho(command))+" is currently using this device.";
        }
        prompt+="\nDo you want to allow this?";
        authlistener=llListen(AUTH_MENU_CHANNEL,"",llGetOwner(),"");    
        llDialog(llGetOwner(),prompt,buttons,AUTH_MENU_CHANNEL);
    }
}


//cleans newly authed events, while preserving the order of arrival for every device
cleanqueue()
{
    list on_hold=[];
    integer i=0;
    while (i<getqlength())
    {
        string ident=getqident(0);
        key object=getqobj(0);
        string command=getqcom(0);
        key user=getwho(command);
        integer auth=auth(object,user);
        if(llListFindList(on_hold,[object])!=-1) i++;
        else if(auth==1)
        {
          deleteqitem(i);
          handlecommand(ident,object,command,TRUE);
        }
        else if(auth==-1)
        {
          deleteqitem(i);
          llShout(RELAY_CHANNEL,ident+","+(string)object+","+command+",ko");
        }
        else
        {
            i++;
            on_hold+=[object];
        }
    }
}

string handlecommand(string ident, key id, string com, integer auth)
{
    list commands=llParseString2List(com,["|"],[]);
    integer i;
    for (i=0;i<llGetListLength(commands);i++)
    {
        string command=llList2String(commands,i);
        integer wrong=FALSE;
        list subargs=llParseString2List(command,["="],[]);
        string val=llList2String(subargs,1);
        string ack="ok";
        if (command=="!release"||command=="@clear") llMessageLinked(LINK_THIS,RLVR_CMD,"clear",id);
        else if (command=="!version") ack=PROTOCOL_VERSION;
        else if (command=="!implversion") ack=IMPL_VERSION;
        else if (iswho(command)) lastuser=getwho(com);
        else if (llGetSubString(command,0,0)!="@") ack="ko";
        else if (ischannelcommand(command))
        {
            if ((integer)val>0) llMessageLinked(LINK_THIS,RLVR_CMD, llGetSubString(command,1,-1), id);
            else ack="ko";
        }
        else if (playful&&val!="n"&&val!="add")
            llMessageLinked(LINK_THIS,RLVR_CMD, llGetSubString(command,1,-1), id);
        else if (!auth)
        {
            if (iswho(com)) return "!who/"+(string)getwho(com)+"|"+llDumpList2String(llList2List(commands,i,-1),"|");
            else return llDumpList2String(llList2List(commands,i,-1),"|");
        }
        else if (llGetListLength(subargs)==2&&llGetSubString(command,0,0)=="@")
        {
            string behav=llGetSubString(llList2String(subargs,0),1,-1);
            if (val=="force"||val=="n"||val=="add"||val=="y"||val=="rem"||behav=="clear")
            {
                llMessageLinked(LINK_THIS,RLVR_CMD,behav+"="+val,id);
            }
            else ack="ko";
        }
        else ack="ko";
        llShout(RELAY_CHANNEL,ident+","+(string)id+","+command+","+ack);
    }
    return "";
}

debug (string msg)
{
    llInstantMessage(llGetOwner(),msg);
}

safeword ()
{
    if (safe)
    {
        llMessageLinked(LINK_THIS, COMMAND_RELAY_SAFEWORD, "","");
        llOwnerSay("You have safeworded");
        tempblacklist=[];
        tempwhitelist=[];
        tempuserblacklist=[];
        tempuserwhitelist=[];
        integer i;
        for (i=0;i<llGetListLength(sources);i++)
        {
            llShout(RELAY_CHANNEL,"release,"+llList2String(sources,i)+",!release,ok");
        }
        sources=[];
        timertype="safeword";
        llSetTimerEvent(5.);
    }
    else
    {
        llOwnerSay("Sorry, you disabled safewording, remember? Now get what you deserve!");
    }
}

//----Menu functions section---//
menu (key id)
{
        timertype="menu";
        llSetTimerEvent(120);
        string prompt="";        
        list buttons=[];
        prompt+="\nCurrent mode is: "+mode;
        if (safe) prompt+=", with safeword";
        else prompt+=", without safeword";
        if (playful) prompt+=", playful,";
        else prompt+=", not playful";
        if (land) prompt+=", landowner trusted.";
        else prompt+=", landowner not trusted.";
        if (mode!="auto") buttons+=["Auto"];
        if (mode!="ask") buttons+=["Ask"];
        if (mode!="restricted") buttons+=["Restricted"];
        if (sources!=[])
        {
            prompt+="\nYou are currently grabbed by "+(string)llGetListLength(sources)+" object";
            if (llGetListLength(sources)==1) prompt+=".";
            else prompt+="s.";
            buttons+=["Grabbed by"];
            if (safe) buttons+=["Safeword"];
        }
        else
        {
            if (mode!="off") buttons+=["Off"];
            if (safe) buttons+=["(*)Safeword"];
            else buttons+=["( )Safeword"];
        }
        if (playful) buttons+=["(*)Playful"];
        else buttons+=["( )Playful"];
        if (land) buttons+=["(*)Land"];
        else buttons+=["( )Land"];
        if (queue!=[])
        {
            prompt+="\nYou have pending requests.";
            buttons+=["Pending"];
        }
        buttons+=["Access Lists"];
        buttons+=["Help"];
        buttons+=[UPMENU];
        prompt+="\n\nMake a choice:";
        llDialog(id,prompt,buttons,MENU_CHANNEL);
        listener=llListen(MENU_CHANNEL,"",id,"");
}

listsmenu(key id)
{
        string prompt="What list do you want to remove items from?";
        list buttons=["Trusted Object","Banned Object","Trusted Avatar","Banned Avatar",UPMENU];
        prompt+="\n\nMake a choice:";
        llDialog(id,prompt,buttons,LIST_MENU_CHANNEL);
        listener=llListen(LIST_MENU_CHANNEL,"",id,"");    
}

plistmenu(key id, string msg)
{
    list olist;
    list olistnames;
    string prompt;
    if (msg==UPMENU)
    {
        menu(id);
        return;
    }
    else if (msg=="Trusted Object")
    {
        olist=objwhitelist;
        olistnames=objwhitelistnames;
        prompt="What object do you want to stop trusting?";
        if (llGetListLength(olistnames)==0) prompt+="\n\nNo object in list.";
        else  prompt+="\n\nObserve chat for the list.";
    }
    else if (msg=="Banned Object")
    {
        olist=objblacklist;
        olistnames=objblacklistnames;
        prompt="What object do you want not to ban anymore?";
        if (llGetListLength(olistnames)==0) prompt+="\n\nNo object in list.";
        else prompt+="\n\nObserve chat for the list.";
    }
    else if (msg=="Trusted Avatar")
    {
        olist=avwhitelist;
        olistnames=avwhitelistnames;
        prompt="What avatar do you want to stop trusting?";
        if (llGetListLength(olistnames)==0) prompt+="\n\nNo avatar in list.";
        else prompt+="\n\nObserve chat for the list.";
    }
    else if (msg=="Banned Avatar")
    {
        olist=avblacklist;
        olistnames=avblacklistnames;
        prompt="What avatar do you want not to ban anymore?";
        if (llGetListLength(olistnames)==0) prompt+="\n\nNo avatar in list.";
        else prompt+="\n\nObserve chat for the list.";
    }
    else return;
    listtype=msg;

    list buttons=[ALL];
    buttons+=[UPMENU];
    integer i;
    for (i=0;i<llGetListLength(olist);i++)
    {
        buttons+=(string)(i+1);
        llOwnerSay((string)(i+1)+": "+llList2String(olistnames,i)+", "+llList2String(olist,i));
    }
    prompt+="\n\nMake a choice:";
    listener=llListen(LIST_CHANNEL,"",id,"");    
    llDialog(id,prompt,buttons,LIST_CHANNEL);
}

remlistitem(string msg)
{
    integer i=((integer) msg) -1;
    if (listtype=="Trusted Object")
    {
        if (msg==ALL) {objwhitelist=[];objwhitelistnames=[];return;}
        if  (i<llGetListLength(objwhitelist))
        {
            objwhitelist=llDeleteSubList(objwhitelist,i,i);
            objwhitelistnames=llDeleteSubList(objwhitelistnames,i,i);
        }
    }
    else if (listtype=="Banned Object")
    {
        if (msg==ALL) {objblacklist=[];objblacklistnames=[];return;}
        if  (i<llGetListLength(objblacklist))
        {
            objblacklist=llDeleteSubList(objblacklist,i,i);
            objblacklistnames=llDeleteSubList(objblacklistnames,i,i);
        }
    }
    else if (listtype=="Trusted Avatar")
    {
        if (msg==ALL) {avwhitelist=[];avwhitelistnames=[];return;}
        if  (i<llGetListLength(avwhitelist)) 
        { 
            avwhitelist=llDeleteSubList(avwhitelist,i,i);
            avwhitelistnames=llDeleteSubList(avwhitelistnames,i,i);
        }
    }
    else if (listtype=="Banned Avatar")
    {
        if (msg==ALL) {avblacklist=[];avblacklistnames=[];return;}
        if  (i<llGetListLength(avblacklist))
        { 
            avblacklist=llDeleteSubList(avblacklist,i,i);
            avblacklistnames=llDeleteSubList(avblacklistnames,i,i);
        }
    }
    
}


default
{
    state_entry()
    {
        MENU_CHANNEL=-9999 - llFloor(llFrand(9999999.0));
        LIST_MENU_CHANNEL=-9999 - llFloor(llFrand(9999999.0));
        LIST_CHANNEL=-9999 - llFloor(llFrand(9999999.0));
        SIT_CHANNEL=9999 + llFloor(llFrand(9999999.0));
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);    
    }

    listen(integer chan, string who, key id, string msg)
    {
        if (chan==MENU_CHANNEL)
        {
            llListenRemove(listener);
            llSetTimerEvent(0);
            integer index=llListFindList(prettycommands,[msg]);
            if (index!=-1)
            {
                llMessageLinked(LINK_THIS,COMMAND_NOAUTH,"relay "+llList2String(chatcommands,index),id);
                if (msg!="Access Lists") remenu=TRUE;
            }
            else if (msg=="Grabbed by")
            {
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH,"showrestrictions",id);
                remenu=TRUE;
            }
            else if (msg=="Help")
            {
                llGiveInventory(id,"OpenCollar - rlvrelay - Help");
                menu(id);
            }
            else if (msg==UPMENU)
            {
                llMessageLinked(LINK_THIS,SUBMENU,parentmenu,id);
            }
        }
        else if (chan==LIST_MENU_CHANNEL)
        {
            llSetTimerEvent(0);
            llListenRemove(listener);
            plistmenu(id,msg);
        }
        else if (chan==LIST_CHANNEL)
        {
            llSetTimerEvent(0);
            llListenRemove(listener);
            if (msg==UPMENU)
            {
                listsmenu(id);
            }
            else 
            {
                remlistitem(msg);
                listsmenu(id);
            }
        }
        else if (chan==AUTH_MENU_CHANNEL)
        {
            llListenRemove(authlistener);
            llSetTimerEvent(0);
            authlistener=0;
            key curid=getqobj(0);
            key user=getwho(getqcom(0));
            if (msg=="Yes")
            {
                tempwhitelist+=[curid];
                if (user) tempuserwhitelist+=[user];
            }
            else if (msg=="No")
            {
                tempblacklist+=[curid];
                if (user) tempuserblacklist+=[user];
            }
            else if (msg=="Trust Object")
            {
                objwhitelist+=[curid];
                objwhitelistnames+=[llKey2Name(curid)];
            }
            else if (msg=="Ban Object")
            {
                objblacklist+=[curid];
                objblacklistnames+=[llKey2Name(curid)];
            }
            else if (msg=="Trust Owner")
            {
                avwhitelist+=[llGetOwnerKey(curid)];
                avwhitelistnames+=[llKey2Name(llGetOwnerKey(curid))];
            }
            else if (msg=="Ban Owner")
            {
                avblacklist+=[llGetOwnerKey(curid)];
                avblacklistnames+=[llKey2Name(llGetOwnerKey(curid))];
            }
            else if (msg=="Trust User")
            {
                avwhitelist+=[user];
                avwhitelistnames+=[llKey2Name(user)];
            }
            else if (msg=="Ban User")
            {
                avblacklist+=[user];
                avblacklistnames+=[llKey2Name(user)];
            }
            cleanqueue();
            dequeue();
        }
    }
    
    on_rez(integer num)
    {
        llSleep(10.); //let some time for the world to rez and the ping/pong work
        sources=[];
    }
    
    timer()
    {
        llSetTimerEvent(0);
        if (timertype=="authmenu")
        {
            llListenRemove(authlistener);
            authlistener=0;
            //dequeue();
        }
        else if (timertype=="menu")
        {
            llListenRemove(listener);
        }
        timertype="";
        tempblacklist=[];
        tempwhitelist=[];
        tempuserblacklist=[];
        tempuserwhitelist=[];
    }
    
    link_message(integer sender_num, integer num, string str, key id )
    {
        if (num == MENUNAME_REQUEST && str == parentmenu)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        else if (num == SUBMENU && str == submenu)
        {
            //give menu
            menu(id);
        }
        else if (num==CMD_ADDSRC)
        {
            sources+=[id];
//            users+=[lastuser];
        }
        else if (num==CMD_REMSRC)
        {
            integer i= llListFindList(sources,[id]);
            if (i!=-1)
            {
                sources=llDeleteSubList(sources,i,i);
//                users=llDeleteSubList(users,i,i);
            }
        }
        else if (num==COMMAND_RLV_RELAY&&mode!="off"&&timertype!="safeword")
        {
            if (iswho(str)) llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "relayuserauth:"+str,getwho(str));
            llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "relayobjectauth:"+str,id);
        }
        else if (num>=COMMAND_OWNER&&num<=COMMAND_EVERYONE&&llSubStringIndex(str,"relayobjectauth:")==0)
        {
            str=llGetSubString(str,16,-1);
            if (num<=COMMAND_SECOWNER&&llListFindList(tempwhitelist,[id])==-1) tempwhitelist+=[id];
            enqueue(str,id);
        }
        else if (num>=COMMAND_OWNER&&num<=COMMAND_EVERYONE&&llSubStringIndex(str,"relayuserauth:")==0)
        {
            if (num<=COMMAND_GROUP&&llListFindList(tempuserwhitelist,[id])==-1) tempuserwhitelist+=[id];
        }
        else if ((num>=COMMAND_OWNER&&num<=COMMAND_WEARER)&&llSubStringIndex(str,"relay")==0)
        {
            if (str=="relay") {menu(id);return;}
            if (num==COMMAND_OWNER||id==llGetOwner())
            {
                str=llGetSubString(str,6,-1);
                if (str=="safeword") safeword();
                else if (str=="safeword on")
                {
                    if (sources==[]) {safe=TRUE;llOwnerSay("Oh come on! No fun! Well, at least you are kinda safe now.");}
                    else llOwnerSay("Nice try. Unfortunately, it is too late to change that now!");
                }
                else if (str=="safeword off")
                {
                    safe=FALSE;
                    llOwnerSay("Ok, safewording is disabled now. Hope you know what you are doing! (sadistic laughters!)");
                }
                else if (str=="off")
                {
                    if (sources==[])
                    {
                        mode="off";
                        llOwnerSay("Oh come on! No fun! Ok, I'll stop bugging you for now.");
                    }
                    else llOwnerSay("Nice try. Unfortunately, it is too late to change that now!");
                }
                else if (str=="ask")
                {
                    llOwnerSay("Relay in ask mode. You will be asked to confirm commands from unkown sources.");
                    mode="ask";
                }
                else if (str=="auto")
                {
                    llOwnerSay("Relay in automatic mode. Accepting every relay command (except from banned sources).");
                    mode="auto";
                }
                else if (str=="restricted")
                {
                    llOwnerSay("Relay in restriced mode. Rejecting every relay command (except from trusted sources)");
                    mode="restricted";
                }
                else if (str=="playful on")
                {
                    playful=TRUE;
                    llOwnerSay("Now you auto-accept every non-restraining command.");
                }
                else if (str=="playful off")
                {
                    playful=FALSE;
                    llOwnerSay("Tired of being played with? Ok, you'll be left alone now.");
                }
                else if (str=="land on")
                {
                    land=TRUE;
                    llOwnerSay("Now you auto-accept every command from the land owner.");
                }
                else if (str=="land off")
                {
                    land=FALSE;
                    llOwnerSay("Now you land owner's commands are handled like every other command.");
                }
                else if (str=="pending")
                {
                    dequeue();
                }
                else if (str=="access")
                {
                    listsmenu(id);
                }
            }
            else llInstantMessage(id, "Sorry, only the wearer of the collar or their owner can change the relay options.");
            if (remenu) {remenu=FALSE; menu(id);}
        }
    }
}
