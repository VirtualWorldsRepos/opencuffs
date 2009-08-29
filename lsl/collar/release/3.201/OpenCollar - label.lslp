//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
string parentmenu = "Help/Debug";
string submenu = "Label";
string fontparent = "Appearance";
string fontmenu = "Font";

//opencollar MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
integer CHAT = 505;

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
integer charlimit = 12;

//string UPMENU = "↑";
//string MORE = "→";
string UPMENU = "^";
string MORE = ">";
integer timeout = 60;
integer menuchannel;
integer listener;
string labeltext = "OpenCollar";
string designprefix;

list design_rotations = ["oc_", <0.0, 0.0, -0.992462, 0.122556>];//strided list of default rotations for label prim 0, by dbprefix
float rotincrement = 11.75;

//////////////////////////////////////////// 
// Changed for the OpenColar label, only one face per prim on a cut cylinder,
// HEAVILY reduced to what we need, else functions removed for easier reading
// Lulu Pink 11/2008
//
// XyzzyText v2.1.UTF8 (UTF8-support) by Salahzar Stenvaag
// XyzzyText v2.1 Script (Set Line Color) by Huney Jewell
// XyzzyText v2.0 Script (5 Face, Single Texture) 
//
// Heavily Modified by Thraxis Epsilon, Gigs Taggart 5/2007 and Strife Onizuka 8/2007
// Rewrite to allow one-script-per-object operation w/ optional slaves
// Enable prim-label functionality
// Enabled Banking
//
// Modified by Kermitt Quirk 19/01/2006 
// To add support for 5 face prim instead of 3 
// 
// Core XyText Originally Written by Xylor Baysklef 
// 
//
//////////////////////////////////////////// 
 
/////////////// CONSTANTS /////////////////// 
// XyText Message Map. 
integer DISPLAY_STRING      = 204000; 
integer DISPLAY_EXTENDED    = 204001; 
integer REMAP_INDICES       = 204002; 
integer RESET_INDICES       = 204003; 
//integer SET_FADE_OPTIONS    = 204004; 
integer SET_FONT_TEXTURE    = 204005; 
//integer SET_LINE_COLOR      = 204006; 
//integer SET_COLOR           = 204007; 
integer RESCAN_LINKSET      = 204008;
 
// This is an extended character escape sequence. 
string  ESCAPE_SEQUENCE = "\\e"; 
 
// This is used to get an index for the extended character. 
string  EXTENDED_INDEX  = "12345"; 
 
// Face numbers. 
// only one face needed, for us face 1
integer FACE          = 1; 
 
// Used to hide the text after a fade-out. 
key     TRANSPARENT     = "701917a8-d614-471f-13dd-5f4644e36e3c";
key     null_key        = NULL_KEY;
///////////// END CONSTANTS //////////////// 
 
///////////// GLOBAL VARIABLES /////////////// 
// This is the key of the font we are displaying. 
//key     gFontTexture        = "b2e7394f-5e54-aa12-6e1c-ef327b6bed9e"; 
// 48 pixel font key     gFontTexture        = "f226766c-c5ac-690e-9018-5a37367ae95a";
// 38 pixel font
//key gFontTexture= "ac955f98-74bb-290f-7eb6-dca54e5e4491";
//key gFontTexture= "e5efeead-c69e-eb81-e7bd-dad2bb787d2b"; // BitStream Vera Monotype // SALAHZAR

//key gFontTexture= "41b57e2d-e60b-01f0-8f23-e109f532d01d"; //oldEnglish Chars
//key gFontTexture = "0d3c99c1-5df4-638c-0f51-ed8591ae8b93";  //Bitstream Vera Serif
//key gFontTexture = "a37110e0-5a1f-810d-f999-d0b88568adf0";  //Apple Chancery
//key gFontTexture = "020f8783-0d0d-88e3-487d-df3e07d068e7"; //Lucida Bright
//key gFontTexture = "fa87184c-35ca-5143-fe24-cdf70e427a09"; // monotype Corsiva
//key gFontTexture = "34835ebf-b13a-a054-46bc-678d0849025c"; // DejaVu Sans Mono
//key gFontTexture = "316b2161-0669-1796-fec2-976526a29efd";//Andale Mono, Etched
//key gFontTexture = "f38c6993-d85e-cffb-fce9-7aed87b80c2e";//andale mono etched 45 point
key gFontTexture = "bf2b6c21-e3d7-877b-15dc-ad666b6c14fe";//verily serif 40 etched, on white

list fonts = [
"Andale 1", "ccc5a5c9-6324-d8f8-e727-ced142c873da",
"Andale 2", "8e10462f-f7e9-0387-d60b-622fa60aefbc",
"Serif 1", "2c1e3fa3-9bdb-2537-e50d-2deb6f2fa22c",
"Serif 2", "bf2b6c21-e3d7-877b-15dc-ad666b6c14fe",
"LCD", "014291dc-7fd5-4587-413a-0d690a991ae1"
];

// All displayable characters.  Default to ASCII order. 
string gCharIndex; 
list decode=[]; // to handle special characters from CP850 page for european countries // SALAHZAR
 
/////////// END GLOBAL VARIABLES //////////// 

FontMenu(key id)
{
    list buttons;
    integer n;
    integer stop = llGetListLength(fonts);
    for (n = 0; n < stop; n = n + 2)
    {
        buttons += llList2String(fonts, n);
    }
    
    buttons += [UPMENU];
    
    string prompt = "Select the font for the collar's label.  (Not all collars have a label that can use this feature.)";
    prompt += "  This menu will time out in " + (string)timeout + " seconds.";
    
    menuchannel = - llRound(llFrand(999999.0)) - 9999;
    llListenRemove(listener);
    listener = llListen(menuchannel, "", id, "");
    buttons = RestackMenu(FillMenu(buttons));    
    llDialog(id, prompt, buttons, menuchannel);
    llSetTimerEvent(timeout);
}

list FillMenu(list in)
{ //adds empty buttons until the list length is multiple of 3, to max of 12
    while (llGetListLength(in) != 3 && llGetListLength(in) != 6 && llGetListLength(in) != 9 && llGetListLength(in) < 12)
    {
        in += [" "];
    }
    return in;
}

list RestackMenu(list in)
{ //re-orders a list so dialog buttons start in the top row
    list out = llList2List(in, 9, 11);
    out += llList2List(in, 6, 8);
    out += llList2List(in, 3, 5);    
    out += llList2List(in, 0, 2);    
    return out;
}
 
ResetCharIndex() { 
 
     gCharIndex  = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`"; 
     gCharIndex += "abcdefghijklmnopqrstuvwxyz{|}~\n\n\n\n\n";
 
     // special UTF-8 chars for European languages // SALAHZAR special chars according to a selection from CP850
     // these 80 chars correspond to the following chars in CP850 codepage: (some are not viewable in editor)
     // rows(11)="Çüéâäàåçêë"
     // rows(12)="èïîìÄÅÉæÆ◄"
     // rows(13)="öòûùÿÖÜ¢£¥"
     // rows(14)="₧ƒáíóúñÑªº"
     // rows(15)="¿⌐¬½¼¡«»αß"
     // rows(16)="ΓπΣσµτΦΘΩδ"
     // rows(17)="∞φε∩≡±≥≤⌠⌡"
     // rows(18)="÷≈°∙·√ⁿ²€ "     
     decode= [ "%C3%87", "%C3%BC", "%C3%A9", "%C3%A2", "%C3%A4", "%C3%A0", "%C3%A5", "%C3%A7", "%C3%AA", "%C3%AB" ];
     decode+=[ "%C3%A8", "%C3%AF", "%C3%AE", "%C3%AC", "%C3%84", "%C3%85", "%C3%89", "%C3%A6", "%C3%AE", "xxxxxx" ];
     decode+=[ "%C3%B6", "%C3%B2", "%C3%BB", "%C3%B9", "%C3%BF", "%C3%96", "%C3%9C", "%C2%A2", "%C2%A3", "%C2%A5" ];
     decode+=[ "%E2%82%A7", "%C6%92", "%C3%A1", "%C3%AD", "%C3%B3", "%C3%BA", "%C3%B1", "%C3%91", "%C2%AA", "%C2%BA"];
     decode+=[ "%C2%BF", "%E2%8C%90", "%C2%AC", "%C2%BD", "%C2%BC", "%C2%A1", "%C2%AB", "%C2%BB", "%CE%B1", "%C3%9F" ];
     decode+=[ "%CE%93", "%CF%80", "%CE%A3", "%CF%83", "%C2%B5", "%CF%84", "%CE%A6", "%CE%98", "%CE%A9", "%CE%B4" ];
     decode+=[ "%E2%88%9E", "%CF%86", "%CE%B5", "%E2%88%A9", "%E2%89%A1", "%C2%B1", "%E2%89%A5", "%E2%89%A4", "%E2%8C%A0", "%E2%8C%A1" ];
     decode+=[ "%C3%B7", "%E2%89%88", "%C2%B0", "%E2%88%99", "%C2%B7", "%E2%88%9A", "%E2%81%BF", "%C2%B2", "%E2%82%AC", "" ];
 
     // END // SALAHZAR
 
} 
 
vector GetGridOffset(integer index) { 
   // Calculate the offset needed to display this character. 
   integer Row = index / 10; 
   integer Col = index % 10; 
 
   // Return the offset in the texture. 
   //return <-0.45 + 0.1 * Col, 0.45 - 0.1 * Row, 0.0>; 
   return <-0.725 + 0.1 * Col, 0.425 - 0.05 * Row, 0.0>; // SALAHZAR modified vertical offsets for 512x1024 textures    // Lulu modified for cut cylinders
//     return <-0.725 + 0.1 * Col, 0.472 - 0.05 * Row, 0.0>;
} 
 
//ShowChars(integer link,vector grid_offset1, vector grid_offset2, vector grid_offset3, vector grid_offset4, vector grid_offset5) 
ShowChars(integer link,vector grid_offset)
{ 
   // Set the primitive textures directly. 
 
   // <-0.256, 0, 0> 
   // <0, 0, 0> 
   // <0.130, 0, 0> 
   // <0, 0, 0> 
   // <-0.74, 0, 0> 
 
// SALAHZAR modified .1 to .05 to handle different sized texture
   llSetLinkPrimitiveParams( link,[ 
        PRIM_TEXTURE, FACE, (string)gFontTexture, <1.434, 0.05, 0>, grid_offset - <0.037, 0, 0>, 0.0 
        ]); 
} 
 
// SALAHZAR intelligent procedure to extract UTF-8 codes and convert to index in our "cp850"-like table
integer GetIndex(string char)
{
    integer  ret=llSubStringIndex(gCharIndex, char);
    if(ret>=0) return ret;
 
    // special char do nice trick :)
    string escaped=llEscapeURL(char);
    integer found=llListFindList(decode, [escaped]);
 
    // Return blank if not found
    if(found<0) return 0;
 
    // return correct index
    return 100+found;
 
}
// END SALAHZAR
 
 
RenderString(integer link, string str) { 
   // Get the grid positions for each pair of characters. 
   vector GridOffset1 = GetGridOffset( GetIndex(llGetSubString(str, 0, 0)) ); // SALAHZAR intermediate function
 
   // Use these grid positions to display the correct textures/offsets. 
//   ShowChars(link,GridOffset1, GridOffset2, GridOffset3, GridOffset4, GridOffset5); 
    ShowChars(link,GridOffset1);
} 
 
integer ConvertIndex(integer index) { 
   // This converts from an ASCII based index to our indexing scheme. 
   if (index >= 32) // ' ' or higher 
       index -= 32; 
   else { // index < 32 
       // Quick bounds check. 
       if (index > 15) 
           index = 15; 
 
       index += 94; // extended characters 
   } 
 
   return index; 
} 

/////END XYTEXT FUNCTIONS

GetLabelPrim(string data)
{
    string label;
    list temp;
    integer i;
    integer linkcount = llGetNumberOfPrims();
    for(i=2; i <= linkcount; i++)
    {
        label = (string)llGetObjectDetails(llGetLinkKey(i), [OBJECT_NAME]);
        temp = llParseString2List(label, ["~"],[]);
        label = llList2String(temp,0);
        if(label == "Label")
        {
            integer charPosition = (integer)llList2String(temp,1);
            RenderString(i, llGetSubString(data, charPosition, charPosition));
            
            //rotate label prims depending on num of chars
            integer index = llListFindList(design_rotations, [designprefix]);
            if (index != -1)//only correct for rotation if this design has an entry in design_rotations
            {
                rotation default_label_rotation = llList2Rot(design_rotations, index + 1);
                rotation oddoffset = ZERO_ROTATION;
                
                //offset by half the increment if odd num of chars
                if (!(llStringLength(labeltext) % 2))
                {
                    oddoffset = llEuler2Rot(<0, 0, (rotincrement / 2.0) * DEG_TO_RAD>);
                }
                
                rotation rot = default_label_rotation * oddoffset * llEuler2Rot(<0, 0, rotincrement * charPosition *
        DEG_TO_RAD>);
                llSetLinkPrimitiveParams(i, [PRIM_ROTATION, ZERO_ROTATION * rot / llGetLocalRot()]);                
            }
        }
    }    
}

string CenterJustify(string in, integer cellsize)
{
    string padding;
    while(llStringLength(padding + in + padding) < cellsize)
    {
        padding += " ";
    }
    return padding + in;
}

SetLabel(string text)
{
    text = CenterJustify(text, charlimit);
    GetLabelPrim(text);    
}

default 
{ 
    state_entry() 
    {   // Initialize the character index. 
        ResetCharIndex();
        designprefix = llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);

        labeltext = llList2String(llParseString2List(llKey2Name(llGetOwner()), [" "], []), 0);
        SetLabel(labeltext);
        llSleep(1.0);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);        
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, fontparent + "|" + fontmenu, NULL_KEY);             
    } 
 
    on_rez(integer num)
    {
        llResetScript();       
    }
   
    link_message(integer sender, integer auth, string str, key id)
    {
        if (auth == COMMAND_OWNER)
        {
            list params = llParseString2List(str, [" "], []);
            string command = llList2String(params, 0);
            if (command == "label")
            {
                params = llDeleteSubList(params, 0, 0);
                labeltext = llDumpList2String(params, " ");
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "label=" + labeltext, NULL_KEY);                   
                SetLabel(labeltext);
            }
            else if (str == "reset")
            {
                llMessageLinked(LINK_THIS, HTTPDB_DELETE, "label", NULL_KEY);                    
                llResetScript();
            }
        }
        else if (auth == HTTPDB_RESPONSE)
        {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if (token == "label")
            {
                labeltext = value;
                SetLabel(labeltext);
                //llInstantMessage(llGetOwner(), "Loaded label " + value + " from database.");
            }            
            else if (token == designprefix + "font")
            {
                gFontTexture = (key)value;
                SetLabel(labeltext);                
            }
        }
        else if (auth == COMMAND_WEARER && str == "reset")
        {
            llMessageLinked(LINK_THIS, HTTPDB_DELETE, "label", NULL_KEY);                    
            llResetScript();            
        }
        else if (auth == MENUNAME_REQUEST)
        {
            if (str == parentmenu)
            {
                llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);     
            }
            else if (str == fontparent)
            {
                llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, fontparent + "|" + fontmenu, NULL_KEY);     
            }
        }
        else if (auth == SUBMENU)
        {
            if (str == submenu)
            {
                  //popup help on how to set label
                llMessageLinked(LINK_THIS, POPUP_HELP, "To set the label on the collar, say _PREFIX_label followed by the text you wish to set.\nExample: _PREFIX_label I Rock!", id);                
            }
            else if (str == fontmenu)
            {
                //give font selection menu
                FontMenu(id);
            }
        }    
    }
    
    listen(integer channel, string name, key id, string message)
    {
        llListenRemove(listener);
        llSetTimerEvent(0.0);
        if (channel == menuchannel)
        {
            if (message == UPMENU)
            {
                llMessageLinked(LINK_THIS, SUBMENU, fontparent, id);
            }
            else
            {
                //we've got the name of a font. look up the texture id, and re-set label
                integer index = llListFindList(fonts, [message]);
                if (index != -1)
                {
                    gFontTexture = (key)llList2String(fonts, index + 1);
                    SetLabel(labeltext);
                    llMessageLinked(LINK_THIS, HTTPDB_SAVE, designprefix + "font=" + (string)gFontTexture, NULL_KEY);
                }
                FontMenu(id);
            }
        }
    }
    
    timer()
    {
        llListenRemove(listener);
        llSetTimerEvent(0.0);
    }
 
    changed(integer change)
    {
        if (change & CHANGED_OWNER)
        {
            llResetScript();
        }
    }
} 
