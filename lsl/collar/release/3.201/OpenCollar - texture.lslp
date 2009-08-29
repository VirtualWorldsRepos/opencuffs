//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//color

//set textures by uuid, and save uuids instead of texture names to DB

//on getting texture command, give menu to choose which element, followed by menu to pick texture

list elements;
string currentelement = "";
list textures;
string parentmenu = "Appearance";
string submenu = "Textures";
string dbtoken = "textures";

integer page = 0;

integer listenchannel = 202984;//just something i randomly chose
integer listener;
integer timeout = 60;

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
integer HTTPDB_EMPTY = 2004;//sent when a token has no value in the httpdb

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;

//5000 block is reserved for IM slaves

//string UPMENU = "↑";
//string MORE = "→";
string UPMENU = "^";
string MORE = ">";
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

TextureMenu(key id)
{
    //create a list
    list buttons;
    string prompt = "Choose the texture to apply.  (This menu will expire in " + (string)timeout + " seconds.)\n";
    //build a button list with the dances, and "More"
    //get number of anims
    integer num_textures = llGetInventoryNumber(INVENTORY_TEXTURE);
    integer n;
    if (num_textures <= 11)
    {
        //if 12 or less, just put them all in the list
        for (n=0;n<num_textures;n++)
        {
            string name = llGetInventoryName(INVENTORY_TEXTURE,n);
            if (name != "")
            {
                prompt += "\n" + (string)(n + 1) + " - " + name;
                buttons += [(string)(n + 1)];
            }
        }  
        buttons += [UPMENU] ;
    }
    else
    {
        //there are more than 12 items, use page number in adding buttons
        for (n=0;n<10;n++)
        {
            //check for anim existence, add to list if it exists
            string name = llGetInventoryName(INVENTORY_TEXTURE, n + (page * 10));
            if (name != "")
            {
                prompt += "\n" + (string)(n + (page * 10) + 1) + " - " + name;
                buttons += [(string)(n + (page * 10) + 1)];                
            }
        }
        //add the More button        
        buttons = buttons + [MORE];
        buttons += [UPMENU] ;          
    }
    buttons = RestackMenu(FillMenu(buttons));    
    listener = llListen(listenchannel, "", id, "");
    llDialog(id, prompt, buttons, listenchannel);
    //the menu needs to time out
    llSetTimerEvent((float)timeout);
}

ElementMenu(key av)
{
    string prompt = "Pick which part of the collar you would like to retexture";
    prompt += "\n(Menu will time out in " + (string)timeout + " seconds.";    
    list buttons = llListSort(elements, 1, TRUE);
    buttons += [UPMENU] ;  
    buttons = RestackMenu(FillMenu(buttons));        
    llListenRemove(listener);
    listener = llListen(listenchannel, "", av, "");
    llDialog(av, prompt, buttons, listenchannel);    
    llSetTimerEvent((float)timeout);
}

string ElementType(integer linknumber)
{
    string desc = (string)llGetObjectDetails(llGetLinkKey(linknumber), [OBJECT_DESC]);
    //prim desc will be elementtype~notexture(maybe)
    list params = llParseString2List(desc, ["~"], []);
    if (~llListFindList(params, ["notexture"]) || desc == "" || desc == " " || desc == "(No Description)")
    {
        return "notexture";
    }
    else
    {
        return llList2String(llParseString2List(desc, ["~"], []), 0);
    }
}


LoadTextureSettings()
{
    //llOwnerSay(llDumpList2String(textures, ","));
    //loop through links, setting each's color according to entry in textures list
    integer n;
    integer linkcount = llGetNumberOfPrims();
    for (n = 2; n <= linkcount; n++)
    {
        string element = ElementType(n);
        integer index = llListFindList(textures, [element]);
        string tex = llList2String(textures, index + 1);        
        //llOwnerSay(llList2String(textures, index + 1));
        if (index != -1)
        {
            //set link to new texture
            llSetLinkTexture(n, tex, ALL_SIDES);
        }
    }        
}

integer startswith(string haystack, string needle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(haystack, llStringLength(needle), -1) == needle;
}

SetElementTexture(string element, key tex)
{
    integer n;
    integer linkcount = llGetNumberOfPrims();
    for (n = 2; n <= linkcount; n++)
    {
        string thiselement = ElementType(n);
        if (thiselement == element)
        {
            //set link to new texture
            llSetLinkTexture(n, tex, ALL_SIDES);
        }
    }            
    
    //change the textures list entry for the current element
    integer index;
    index = llListFindList(textures, [element]);
    if (index == -1)
    {
        textures += [currentelement, tex];
    }
    else
    {
        textures = llListReplaceList(textures, [tex], index + 1, index + 1);
    }
    //save to httpdb
    llMessageLinked(LINK_THIS, HTTPDB_SAVE, dbtoken + "=" + llDumpList2String(textures, "~"), NULL_KEY);     
}

default
{
    state_entry()
    {
        listenchannel = -(llRound(llFrand(999999)) + 99999);
        //get dbprefix from object desc, so that it doesn't need to be hard coded, and scripts between differently-primmed collars can be identical
        string prefix = llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
        if (prefix != "")
        {
            dbtoken = prefix + dbtoken;
        }        
        
        //loop through non-root prims, build element list
        integer n;
        integer linkcount = llGetNumberOfPrims();
        
        //root prim is 1, so start at 2
        for (n = 2; n <= linkcount; n++)
        {
            string element = ElementType(n);
            if (!(~llListFindList(elements, [element])) && element != "notexture")
            {
                elements += [element];
                //llSay(0, "added " + element + " to elements");
            }
        }
        //llMessageLinked(LINK_THIS, HTTPDB_REQUEST, dbtoken, NULL_KEY);
        llSleep(1.0);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);         
    }

    link_message(integer sender, integer auth, string str, key id)
    {
        //owner, secowner, group, and wearer may currently change colors
        if (auth >= COMMAND_OWNER && auth <= COMMAND_WEARER && str == "texture")
        {
            currentelement = "";
            ElementMenu(id);
        }
        else if (str == "reset" && (auth == COMMAND_OWNER || auth == COMMAND_WEARER))
        {
            //clear saved settings            
            //llMessageLinked(LINK_THIS, HTTPDB_DELETE, dbtoken, NULL_KEY);      
            llResetScript();
        }
        else if (auth >= COMMAND_OWNER && auth <= COMMAND_WEARER)
        {
            if (str == "settings")
            {
                llInstantMessage(id, "Texture Settings: " + llDumpList2String(textures, ","));
            }
            else if (startswith(str, "settexture"))
            {
                list params = llParseString2List(str, [" "], []);
                string element = llList2String(params, 1);
                key tex = (key)llList2String(params, 2);
                SetElementTexture(element, tex);
            }
        }
        else if (auth == HTTPDB_RESPONSE)
        {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if (token == dbtoken)
            {
                textures = llParseString2List(value, ["~"], []);
                //llInstantMessage(llGetOwner(), "Loaded texture settings.");
                LoadTextureSettings();
            }            
        }
        else if (auth == MENUNAME_REQUEST)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        else if (auth == SUBMENU && str == submenu)
        {
            //we don't know the authority of the menu requester, so send a message through the auth system
            llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "texture", id);
        }        
    }
    
    listen(integer channel, string name, key id, string message)
    {
        if (message == UPMENU)
        {
            if (currentelement == "")
            {
                //main menu
                llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);              
            }
            else
            {
                currentelement = "";
                ElementMenu(id);
            }     
        }
        else if (currentelement == "")
        {
            //we just got the element name
            currentelement = message;
            page = 0;
            TextureMenu(id);
        }
        else if (message == MORE)
        {
            //increment page number
            if (llGetInventoryNumber(INVENTORY_TEXTURE) > (11 * (page + 1)))
            {
                //there are more pages
                page++;
            }
            else
            {
                page = 0;
            }           
            TextureMenu(id);                     
        }        
        else if ((integer)message)
        {
            //got a number button
            string tex = (string)llGetInventoryKey(llGetInventoryName(INVENTORY_TEXTURE, (integer)message - 1));
            //loop through links, setting texture if element type matches what we're changing
            //root prim is 1, so start at 2
            SetElementTexture(currentelement, (key)tex);
            //currentelement = "";
            //ElementMenu(id);            
            TextureMenu(id);
        }            
    }
    
    timer()
    {
        //menus need to time out
        llListenRemove(listener);
        llSetTimerEvent(0);
    }
    
    changed(integer change)
    {
        if (change & CHANGED_OWNER)
        {
            llResetScript();
        }
    }    
}
