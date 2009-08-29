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

integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
                            //str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer MENUNAME_REMOVE = 3003;

integer RLVR_CMD = 6010; //let's do that for now (note this is not RLV_CMD)
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.

integer RLV_OFF = 6100; // send to inform plugins that RLV is disabled now, no message or key needed
integer RLV_ON = 6101; // send to inform plugins that RLV is enabled now, no message or key needed

string parentmenu = "RLV";
string submenu = "Relay";
integer remenu = FALSE;
integer menuuserauth;
integer menu_timeout = 60;

//string UPMENU = "↑";
//string MORE = "→";
string UPMENU = "^";
string MORE = ">";
string ALL = "*All*";

key wearer;

list chatcommands=["auto","ask","restricted","off","safeword","safeword on","safeword off","playful on", "playful off","land on","land off","pending","access"];
list prettycommands=["Auto","Ask","Restricted","Off","Safeword", "( )Safeword", "(*)Safeword","( )Playful","(*)Playful","( )Land","(*)Land","Pending","Access Lists"];
//list prettycommands=["Auto","Ask","Restricted","Off","Safeword", "☐Safeword", "☒Safeword","☐Playful","☒Playful","☐Land","☒Land","Pending","Access Lists"];

integer RELAY_CHANNEL = -1812221819;
integer MENU_CHANNEL;
integer AUTH_MENU_CHANNEL;
integer LIST_MENU_CHANNEL;
integer LIST_CHANNEL;
integer SIT_CHANNEL;
string PROTOCOL_VERSION = "1100"; //with some additions, but backward compatible, nonetheless
string IMPL_VERSION = "OpenCollar 3.3";
string ORG_VERSIONS = "ORG=0001/who=001";

//settings
integer mode=0;
integer minmode=0;

integer garbage_rate = 180; //garbage collection rate

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

integer rlv=FALSE;
list queue=[];
integer QSTRIDES=3;
integer listener=0;
integer authlistener=0;
string timertype="";
string listtype;
integer MAXLOAD=8;    //prevents stack-heap collisions due to malicious devices

//relay specific message map
integer CMD_ADDSRC = 11;
integer CMD_REMSRC = 12;

string dbtoken="relay";

//querying mode from mode bitfield
integer modeoff() {return (mode & 7)==0;}
integer moderestricted() {return (mode & 7)==1;}
integer modeask() {return (mode & 7)==2;}
integer modeauto() {return (mode & 7)==3;}
integer modesafe() {return !(mode & 8);} //notice the negation
integer modeland() {return (mode & 16);}
integer modeplayful() {return (mode & 32);}
string mode2string(integer mode)
{
    string out;
    if ((mode & 7)==0) out+="off";
    else if ((mode & 7)==1) out+="restricted";
    else if ((mode & 7)==2) out+="ask";
    else if ((mode & 7)==3) out+="auto";
    if (mode & 8) out+=", without safeword";
    else out+=", with safeword";
    if (mode & 32) out+=", playful";
    else out+=", not playful";
    if (mode & 16) out+=", landowner trusted.";
    else out+=", landowner not trusted.";
    return out;
}

integer maxmode(integer mode1, integer mode2)
{
    integer mainmode;
    if ((mode1 & 7) < (mode2 & 7)) mainmode = mode2; else mainmode = mode1; //come on, where is llMaxInteger()?
    return (mainmode & 7) |(~7 & (mode1|mode2));
}

notify(key id, string msg, integer alsoNotifyWearer) {
    if (id == wearer) {
        llOwnerSay(msg);
    } else {
        llInstantMessage(id,msg);
        if (alsoNotifyWearer) {
            llOwnerSay(msg);
        }
    }    
}

SaveSettings()
{
    string settings=dbtoken+"=mode:"+(string)mode;
    settings+=",minmode:"+(string)minmode;
    if (objwhitelist) settings+=",objwhitelist:"+llDumpList2String(objwhitelist,"/");
    if (objblacklist) settings+=",objblacklist:"+llDumpList2String(objblacklist,"/");
    if (avwhitelist) settings+=",avwhitelist:"+llDumpList2String(avwhitelist,"/");
    if (avblacklist) settings+=",avblacklist:"+llDumpList2String(avblacklist,"/");
//    if (objwhitelistnames) settings+=",objwhitelistnames:"+llDumpList2String(objwhitelistnames,"/");
//    if (objblacklistnames) settings+=",objblacklistnames:"+llDumpList2String(objblacklistnames,"/");
//    if (avwhitelistnames) settings+=",avwhitelistnames:"+llDumpList2String(avwhitelistnames,"/");
//    if (avblacklistnames) settings+=",avblacklistnames:"+llDumpList2String(avblacklistnames,"/");    
    llMessageLinked(LINK_THIS, HTTPDB_SAVE, settings, NULL_KEY);
}

UpdateSettings(string settings)
{
    list args = llParseString2List(settings,[","],[]);
    integer i;
    for (i=0;i<llGetListLength(args);i++)
    {
        list setting=llParseString2List(llList2String(args,i),[":"],[]);
        string var=llList2String(setting,0);
        list vals=llParseString2List(llList2String(setting,1),["/"],[]);
        if (var=="mode") setmode(llList2Integer(setting,1),wearer);
        if (var=="minmode") setminmode(llList2Integer(setting,1),wearer);
//        else if (var=="objwhitelist") objwhitelist=vals;
//        else if (var=="objblacklist") objblacklist=vals;
        else if (var=="avwhitelist") avwhitelist=vals;
        else if (var=="avblacklist") avblacklist=vals;
//        else if (var=="objwhitelistnames") objwhitelistnames=vals;
//        else if (var=="objblacklistnames") objblacklistnames=vals;
        else if (var=="avwhitelistnames") avwhitelistnames=vals;
        else if (var=="avblacklistnames") avblacklistnames=vals;
    }
}

integer ischannelcommand(string cmd)
{
    return (llSubStringIndex(cmd,"@version")==0)||(llSubStringIndex(cmd,"@get")==0)||(llSubStringIndex(cmd,"@findfolder")==0);
}


integer iswho(string cmd)
{
    return llGetSubString(cmd,0,4)=="!who/"||llGetSubString(cmd,0,6)=="!x-who/";
}

key getwho(string cmd)
{
    integer index=llSubStringIndex(cmd,"who/")+4;
    if (iswho(cmd)) return (key)llGetSubString(cmd,index,index+35);
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
    else if (modeauto()) {}
    else if (modeland() && llGetOwnerKey(object)==llGetLandOwnerAt(llGetPos())) {}
    else if (llListFindList(tempwhitelist+objwhitelist,[object])!=-1) {}
    else if (llListFindList(avwhitelist,[llGetOwnerKey(object)])!=-1) {}
    else if (moderestricted()) return -1;
    else auth=0;
    //user auth
    if (user==NULL_KEY) {}
//    else if (source_index!=-1&&user==(key)llList2String(users,source_index)) {}
    else if (user==lastuser) {}
    else if (llListFindList(avblacklist+tempuserblacklist,[user])!=-1) return -1;
    else if (modeauto()) {}
    else if (llListFindList(avwhitelist+tempuserwhitelist,[user])!=-1) {}
    else if (moderestricted()) return -1;
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
    if (llList2String(args,1)!=(string)wearer) return;
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
        llSetTimerEvent(menu_timeout);
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
        authlistener=llListen(AUTH_MENU_CHANNEL,"",wearer,"");    
        llDialog(wearer,prompt,buttons,AUTH_MENU_CHANNEL);
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
          list commands = llParseString2List(command,["|"],[]);
          integer j;
          for (j=0;j<llGetListLength(commands);j++)
          llShout(RELAY_CHANNEL,ident+","+(string)object+","+llList2String(commands,j)+",ko");
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
        else if (command=="!x-orgversions") ack=ORG_VERSIONS;
        else if (iswho(command)) lastuser=getwho(com);
        else if (llGetSubString(command,0,0)=="!") ack="ko"; // ko unknown meta-commands
        else if (llGetSubString(command,0,0)!="@")
        {
            if (iswho(com)) return llList2String(commands,0)+"|"+llDumpList2String(llList2List(commands,i,-1),"|");
            else return llDumpList2String(llList2List(commands,i,-1),"|");
        }//probably an ill-formed command, not answering
        else if (ischannelcommand(command))
        {
            if ((integer)val>0) llMessageLinked(LINK_THIS,RLVR_CMD, llGetSubString(command,1,-1), id);
            else ack="ko";
        }
        else if (modeplayful()&&llGetSubString(command,0,0)=="@"&&val!="n"&&val!="add")
            llMessageLinked(LINK_THIS,RLVR_CMD, llGetSubString(command,1,-1), id);
        else if (!auth)
        {
            if (iswho(com)) return llList2String(commands,0)+"|"+llDumpList2String(llList2List(commands,i,-1),"|");
            else return llDumpList2String(llList2List(commands,i,-1),"|");
        }
        else if (llGetListLength(subargs)==2)
        {
            string behav=llGetSubString(llList2String(subargs,0),1,-1);
            if (val=="force"||val=="n"||val=="add"||val=="y"||val=="rem"||behav=="clear")
            {
                llMessageLinked(LINK_THIS,RLVR_CMD,behav+"="+val,id);
            }
            else ack="ko";
        }
        else
        {
            if (iswho(com)) return llList2String(commands,0)+"|"+llDumpList2String(llList2List(commands,i,-1),"|");
            else return llDumpList2String(llList2List(commands,i,-1),"|");
        }//probably an ill-formed command, not answering
        llShout(RELAY_CHANNEL,ident+","+(string)id+","+command+","+ack);
    }
    return "";
}

debug (string msg)
{
    llInstantMessage(wearer,msg);
}

safeword ()
{
    if (modesafe())
    {
        llMessageLinked(LINK_THIS, COMMAND_RELAY_SAFEWORD, "","");
        notify(wearer, "You have safeworded",TRUE);
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
        notify(wearer, "Sorry, safewording is disabled now!", TRUE);
    }
}

//----Menu functions section---//
menu (key id)
{
        timertype="menu";
        llSetTimerEvent(menu_timeout);
        string prompt="";        
        list buttons=[];
        integer modebackup=mode; //stupid hack....
        if (id==wearer) prompt+="\nCurrent mode is: " + mode2string(mode);
        else
        {
            prompt+="\nCurrent minimal authorized mode is: " + mode2string(minmode);
            mode = minmode; //stupid hack
        }
        if (!modeauto()) buttons+=["Auto"];
        if (!modeask()&&id==wearer) buttons+=["Ask"];
        if (!moderestricted()) buttons+=["Restricted"];
        if (sources!=[])
        {
            prompt+="\nCurrently grabbed by "+(string)llGetListLength(sources)+" object";
            if (llGetListLength(sources)==1) prompt+=".";
            else prompt+="s.";
            buttons+=["Grabbed by"];
            if (modesafe()) buttons+=["Safeword"];
        }
        else
        {
            if (!modeoff()) buttons+=["Off"];
            if (modesafe()) buttons+=["(*)Safeword"];
            else buttons+=["( )Safeword"];
        }
        if (modeplayful()) buttons+=["(*)Playful"];
        else buttons+=["( )Playful"];
        if (modeland()) buttons+=["(*)Land"];
        else buttons+=["( )Land"];
        if (queue!=[])
        {
            prompt+="\nYou have pending requests.";
            buttons+=["Pending"];
        }
        buttons+=["Access Lists"];
        buttons+=["Help"];
        buttons+=[UPMENU];
        buttons = RestackMenu(buttons);
        prompt+="\n\nMake a choice:";
        llDialog(id,prompt,buttons,MENU_CHANNEL);
        listener=llListen(MENU_CHANNEL,"",id,"");
        mode=modebackup;//end of stupid hack
}

listsmenu(key id)
{
        string prompt="What list do you want to remove items from?";
        list buttons=["Trusted Object","Banned Object","Trusted Avatar","Banned Avatar",UPMENU];
        buttons = RestackMenu(buttons);
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
        llInstantMessage(id, (string)(i+1)+": "+llList2String(olistnames,i)+", "+llList2String(olist,i));
    }
    buttons = RestackMenu(buttons);
    prompt+="\n\nMake a choice:";
    listener=llListen(LIST_CHANNEL,"",id,"");    
    llDialog(id,prompt,buttons,LIST_CHANNEL);
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

remlistitem(string msg)
{
    
    integer i=((integer) msg) -1;
    if (listtype=="Banned Avatar")
    {
        if (msg==ALL) {avblacklist=[];avblacklistnames=[];return;}
        if  (i<llGetListLength(avblacklist))
        { 
            avblacklist=llDeleteSubList(avblacklist,i,i);
            avblacklistnames=llDeleteSubList(avblacklistnames,i,i);
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
    else if (menuuserauth==COMMAND_WEARER && (minmode & 7) > 0)
    {
        notify(wearer,"Sorry, your owner does not allow you do remove trusted sources.",TRUE);
    }
    else if (listtype=="Trusted Object")
    {
        if (msg==ALL) {objwhitelist=[];objwhitelistnames=[];return;}
        if  (i<llGetListLength(objwhitelist))
        {
            objwhitelist=llDeleteSubList(objwhitelist,i,i);
            objwhitelistnames=llDeleteSubList(objwhitelistnames,i,i);
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
}

setminmode(integer newminmode, key id)
{
    minmode = newminmode;
    //do we really want that all the time??
    //notify(id, "Relay minimal authorized mode is now: "+mode2string(minmode),TRUE);
    integer maxmode = maxmode(mode,minmode);
    if (maxmode!= mode) setmode(maxmode, id);
    else SaveSettings();
}

setmode(integer newmode, key id)
{
    if (sources!=[] && (newmode & 8))
    {
        notify(id, "Nice try. Unfortunately, it is too late to change that now!", TRUE);
        return;
    }
    integer maxmode=maxmode(newmode, minmode);
//    llOwnerSay(mode2string(minmode));
//    llOwnerSay(mode2string(mode));
//    llOwnerSay(mode2string(newmode));
//    llOwnerSay(mode2string(maxmode));
    if (newmode != maxmode)
    {
        notify(id, "Sorry, your owner forbids you to change this settings now.", TRUE);
        return;
    }
    mode = newmode;
    //do we really want that all the time??
    //notify(id, "Relay mode is now: "+mode2string(mode),TRUE);
    SaveSettings();
}

default
{
    state_entry()
    {
        wearer = llGetOwner();
        MENU_CHANNEL=-9999 - llFloor(llFrand(9999999.0));
        LIST_MENU_CHANNEL=-9999 - llFloor(llFrand(9999999.0));
        LIST_CHANNEL=-9999 - llFloor(llFrand(9999999.0));
        SIT_CHANNEL=9999 + llFloor(llFrand(9999999.0));
        /* //no more needed
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        */    
        sources=[];
        llSetTimerEvent(garbage_rate); //start garbage collection timer
    }

    listen(integer chan, string who, key id, string msg)
    {
        if (chan==MENU_CHANNEL)
        {
            llListenRemove(listener);
            llSetTimerEvent(garbage_rate);
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
            llSetTimerEvent(garbage_rate);
            llListenRemove(listener);
            plistmenu(id,msg);
        }
        else if (chan==LIST_CHANNEL)
        {
            llSetTimerEvent(garbage_rate);
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
            llSetTimerEvent(garbage_rate);
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
    /* //no more self-reset
    on_rez(integer num)
    {
        llResetScript();
    }
    */
    timer()
    {
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

        //garbage collection
        vector myPosition = llGetRootPosition();
        integer i;
        for (i=0;i<llGetListLength(sources);i++)
        {
            key id = (key) llList2String(sources,i);
            list temp = llGetObjectDetails(id, ([OBJECT_POS]));
            vector objPosition = llList2Vector(temp,0);
            if (objPosition == <0, 0, 0> || llVecDist(objPosition, myPosition) > 100) // 100: max shout distance
            llMessageLinked(LINK_THIS,RLVR_CMD,"clear",id);
        }
        llSetTimerEvent(garbage_rate);
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
        else if (num==COMMAND_RLV_RELAY&&rlv&&!modeoff()&&timertype!="safeword")
        {
            if (str=="ping,"+(string)wearer+",!pong") return;
            if (iswho(str)) llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "relayuserauth:"+str,getwho(str));
            llMessageLinked(LINK_THIS, COMMAND_OBJECT, "relayobjectauth:"+str,id);
        }
// relay command auth        
        else if (num>=COMMAND_OWNER&&num<=COMMAND_EVERYONE&&llSubStringIndex(str,"relayobjectauth:")==0)
        {
            str=llGetSubString(str,16,-1);
            if (num<=COMMAND_SECOWNER && (llListFindList(tempwhitelist, [id]) == -1)) {tempwhitelist+=[id];}
            enqueue(str,id);
        }
        else if (num>=COMMAND_OWNER&&num<=COMMAND_EVERYONE&&llSubStringIndex(str,"relayuserauth:")==0)
        {
            if (num<=COMMAND_GROUP && (llListFindList(tempuserwhitelist, [id]) == -1)) {tempuserwhitelist+=[id];}
        }
// rlvoff -> we have to turn the relay off too
        else if (num>=COMMAND_OWNER && num<=COMMAND_WEARER && str=="rlvoff") rlv=FALSE;
// collar commands
        else if ((num>=COMMAND_OWNER&&num<=COMMAND_WEARER)&&llSubStringIndex(str,"relay")==0)
        {
            if (str=="relay") 
            {
                if (rlv)
                {
                    menuuserauth=num;
                    menu(id);
                    return;
                }
                else
                {
                    notify(id, "RLV features are now disabled in this collar. You can enable those in RLV submenu. Opening it now.", FALSE);
                    llMessageLinked(LINK_SET, SUBMENU, "RLV", id);
                    return;
                }
            }
            if (num==COMMAND_OWNER||id==wearer)
            {
                str=llGetSubString(str,6,-1);
                if (str=="safeword") safeword();
                else if (str=="pending")
                {
                    dequeue();
                }
                else if (str=="access")
                {
                    if(!rlv)
                    {
                        notify(id, "RLV features are now disabled in this collar. You can enable those in RLV submenu. Opening it now.", FALSE);
                        llMessageLinked(LINK_SET, SUBMENU, "RLV", id);
                        return;
                    }
                    listsmenu(id);
                }
                else
                {
                    integer newmode;
                    if (id==wearer) newmode = mode;
                    else newmode = minmode;
                    string modetype=llList2String(llParseString2List(str, [" "], []),0);
                    string modechange=llList2String(llParseString2List(str, [" "], []),1);
                    if (modetype=="off") newmode = newmode & ~7;
                    else if (modetype=="restricted") newmode = (newmode & ~7) | 1;
                    else if (modetype=="ask") newmode = (newmode & ~7) | (2 - (wearer!=id));
                    else if (modetype=="auto") newmode = (newmode & ~7) | 3;
                    else if (modetype=="safeword") newmode = (newmode & ~8) | 8*(modechange=="off");
                    else if (modetype=="land") newmode = (newmode & ~16) | 16*(modechange=="on");
                    else if (modetype=="playful") newmode = (newmode & ~32) | 32*(modechange=="on");
                    if (id==wearer)
                    {
                        if (num==COMMAND_OWNER) minmode=0;
                        setmode(newmode, id);
                    }
                    else setminmode(newmode,id);
                }
            }
            else llInstantMessage(id, "Sorry, only the wearer of the collar or their owner can change the relay options.");
            if (remenu) {remenu=FALSE; menu(id);}
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
                UpdateSettings(llList2String(params, 1));
            }
        }
        // rlvoff -> we have to turn the menu off too
        else if (num == RLV_OFF) rlv=FALSE;
        // rlvon -> we have to turn the menu on again
        else if (num == RLV_ON) rlv=TRUE;
        else if (num==RLV_REFRESH) rlv=TRUE;
    }
}
