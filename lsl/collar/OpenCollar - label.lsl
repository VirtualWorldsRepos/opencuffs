string parentmenu = "Help/Debug";
string submenu = "Label";

//opencollar MESSAGE MAP
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

////////////////////////////////////////////
// XyText v1.0.2 Script
//
// Written by Xylor Baysklef
////////////////////////////////////////////
// hacked for one face only on the first 0.075 part of the outside of a cylinder 
// Changed to look for child prims with name Label~n and set the part of the text string to n and n+1
// by Lulu Pink
// removed not needed part *shivers*


/////////////// XYTEXT CONSTANTS ///////////////////
// XyText Message Map.
integer DISPLAY_STRING      = 204000;
integer DISPLAY_EXTENDED    = 204001;
integer REMAP_INDICES       = 204002;
integer RESET_INDICES       = 204003;
integer SET_CELL_INFO       = 204004;

// This is an extended character escape sequence.
string  ESCAPE_SEQUENCE = "\\e";

// This is used to get an index for the extended character.
string  EXTENDED_INDEX  = "123456789abcdef";

// Face numbers.
integer FACE = 1;

// This is a list of textures for all 2-character combinations.
list    CHARACTER_GRID  = [
        "00e9f9f7-0669-181c-c192-7f8e67678c8d",
        "347a5cb6-0031-7ec0-2fcf-f298eebf3c0e",
        "4e7e689e-37f1-9eca-8596-a958bbd23963",
        "19ea9c21-67ba-8f6f-99db-573b1b877eb1",
        "dde7b412-cda1-652f-6fc2-73f4641f96e1",
        "af6fa3bb-3a6c-9c4f-4bf5-d1c126c830da",
        "a201d3a2-364b-43b6-8686-5881c0f82a94",
        "b674dec8-fead-99e5-c28d-2db8e4c51540",
        "366e05f3-be6b-e5cf-c33b-731dff649caa",
        "75c4925c-0427-dc0c-c71c-e28674ff4d27",
        "dcbe166b-6a97-efb2-fc8e-e5bc6a8b1be6",
        "0dca2feb-fc66-a762-db85-89026a4ecd68",
        "a0fca76f-503a-946b-9336-0a918e886f7a",
        "67fb375d-89a1-5a4f-8c7a-0cd1c066ffc4",
        "300470b2-da34-5470-074c-1b8464ca050c",
        "d1f8e91c-ce2b-d85e-2120-930d3b630946",
        "2a190e44-7b29-dadb-0bff-c31adaf5a170",
        "75d55e71-f6f8-9835-e746-a45f189f30a1",
        "300fac33-2b30-3da3-26bc-e2d70428ec19",
        "0747c776-011a-53ce-13ee-8b5bb9e87c1e",
        "85a855c3-a94f-01ca-33e0-7dde92e727e2",
        "cbc1dab2-2d61-2986-1949-7a5235c954e1",
        "f7aef047-f266-9596-16df-641010edd8e1",
        "4c34ebf7-e5e1-2e1a-579f-e224d9d5e71b",
        "4a69e98c-26a5-ad05-e92e-b5b906ad9ef9",
        "462a9226-2a97-91ac-2d89-57ab33334b78",
        "20b24b3a-8c57-82ee-c6ed-555003f5dbcd",
        "9b481daa-9ea8-a9fa-1ee4-ab9a0d38e217",
        "c231dbdc-c842-15b0-7aa6-6da14745cfdc",
        "c97e3cbb-c9a3-45df-a0ae-955c1f4bf9cf",
        "f1e7d030-ff80-a242-cb69-f6951d4eae3b",
        "ed32d6c4-d733-c0f1-f242-6df1d222220d",
        "88f96a30-dccf-9b20-31ef-da0dfeb23c72",
        "252f2595-58b8-4bcc-6515-fa274d0cfb65",
        "f2838c4f-de80-cced-dff8-195dfdf36b2c",
        "cc2594fe-add2-a3df-cdb3-a61711badf53",
        "e0ce2972-da00-955c-129e-3289b3676776",
        "3e0d336d-321f-ddfa-5c1b-e26131766f6a",
        "d43b1dc4-6b51-76a7-8b90-38865b82bf06",
        "06d16cbb-1868-fd1d-5c93-eae42164a37d",
        "dd5d98cf-273e-3fd0-f030-48be58ee3a0b",
        "0e47c89e-de4a-6233-a2da-cb852aad1b00",
        "fb9c4a55-0e13-495b-25c4-f0b459dc06de",
        "e3ce8def-312c-735b-0e48-018b6799c883",
        "2f713216-4e71-d123-03ed-9c8554710c6b",
        "4a417d8a-1f4f-404b-9783-6672f8527911",
        "ca5e21ec-5b20-5909-4c31-3f90d7316b33",
        "06a4fcc3-e1c4-296d-8817-01f88fbd7367",
        "130ac084-6f3c-95de-b5b6-d25c80703474",
        "59d540a0-ae9d-3606-5ae0-4f2842b64cfa",
        "8612ae9a-f53c-5bf4-2899-8174d7abc4fd",
        "12467401-e979-2c49-34e0-6ac761542797",
        "d53c3eaa-0404-3860-0675-3e375596c3e3",
        "9f5b26bd-81d3-b25e-62fe-5b671d1e3e79",
        "f57f0b64-a050-d617-ee00-c8e9e3adc9cb",
        "beff166a-f5f3-f05e-e020-98f2b00e27ed",
        "02278a65-94ba-6d5e-0d2b-93f2e4f4bf70",
        "a707197d-449e-5b58-846c-0c850c61f9d6",
        "021d4b1a-9503-a44f-ee2b-976eb5d80e68",
        "0ae2ffae-7265-524d-cb76-c2b691992706",
        "f6e41cf2-1104-bd0b-0190-dffad1bac813",
        "2b4bb15e-956d-56ae-69f5-d26a20de0ce7",
        "f816da2c-51f1-612a-2029-a542db7db882",
        "345fea05-c7be-465c-409f-9dcb3bd2aa07",
        "b3017e02-c063-5185-acd5-1ef5f9d79b89",
        "4dcff365-1971-3c2b-d73c-77e1dc54242a"
          ];

///////////// END XYTEXT CONSTANTS ////////////////

///////////// XYTEXT GLOBAL VARIABLES ///////////////
// All displayable characters.  Default to ASCII order.
string gCharIndex;
// This is the starting character position in the cell channel message
// to render.
integer gCellCharPosition = 0;
/////////// END XYTEXT GLOBAL VARIABLES ////////////




integer charlimit = 12;


/////XYTEXT FUNCTIONS

ResetCharIndex() {
    gCharIndex  = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`";
    // \" <-- Fixes LSL syntax highlighting bug.
    gCharIndex += "abcdefghijklmnopqrstuvwxyz{|}~";
    gCharIndex += "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n";
}

vector GetGridPos(integer index1, integer index2) {
    // There are two ways to use the lookup table...
    integer Col;
    integer Row;
    if (index1 >= index2) {
        // In this case, the row is the index of the first character:
        Row = index1;
        // And the col is the index of the second character (x2)
        Col = index2 * 2;
    }
    else { // Index1 < Index2
        // In this case, the row is the index of the second character:
        Row = index2;
        // And the col is the index of the first character, x2, offset by 1.
        Col = index1 * 2 + 1;
    }
    return < Col, Row, 0>;
}

string GetGridTexture(vector grid_pos) {
    // Calculate the texture in the grid to use.
    integer GridCol = llRound(grid_pos.x) / 20;
    integer GridRow = llRound(grid_pos.y) / 10;

    // Lookup the texture.
    key Texture = llList2Key(CHARACTER_GRID, GridRow * (GridRow + 1) / 2 + GridCol);
    return Texture;
}

vector GetGridOffset(vector grid_pos) {
    // Zoom in on the texture showing our character pair.
    integer Col = llRound(grid_pos.x) % 20;
    integer Row = llRound(grid_pos.y) % 10;

    // Return the offset in the texture.
    return <-0.787 + 0.05 * Col, 0.45 - 0.1 * Row, 0.0>;
}

ShowChars(vector grid_pos1, integer linknum)
{
    // Set the primitive textures directly to the label prims.
    // changed to SetLinkParams and added linknum
    llSetLinkPrimitiveParams(linknum,[ 
    PRIM_TEXTURE, FACE,   GetGridTexture(grid_pos1), <1.434, 0.1, 0>, GetGridOffset(grid_pos1), 0.0
    ]);
}

RenderString(string str, integer linknumber) {
    // Get the grid positions for each pair of characters.
    vector GridPos1 = GetGridPos( llSubStringIndex(gCharIndex, llGetSubString(str, 0, 0)), llSubStringIndex(gCharIndex, llGetSubString(str, 1, 1)) );

    // Use these grid positions to display the correct textures/offsets. *added linknumber
    ShowChars(GridPos1, linknumber); 
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

// find the label prims and give the parts to display based on prim name to the RenderString function

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
            gCellCharPosition = (integer)llList2String(temp,1);
            RenderString( llGetSubString(data, gCellCharPosition, gCellCharPosition + 1), i );
        }
    }    
}
/////END XYTEXT FUNCTIONS

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
    // chnaged to LINK_THIS as we now give the text to a script in the root and no more to scripts in each label prim
    //llMessageLinked(LINK_THIS, SET_LINE_CHANNEL, text, "");   
    GetLabelPrim(text);    
}

default
{
    state_entry()
    {
        //xytext initialization
        // Initialize the character index.
        ResetCharIndex();                
        
        string firstname = llList2String(llParseString2List(llKey2Name(llGetOwner()), [" "], []), 0);
        //llMessageLinked(LINK_SET, COMMAND_OWNER, "label " + firstname, llGetOwner());
        SetLabel(firstname);
        //llMessageLinked(LINK_THIS, HTTPDB_REQUEST, "label", NULL_KEY);      
        llSleep(1.0);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);  
                
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
                string text = llDumpList2String(params, " ");
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "label=" + text, NULL_KEY);                   
                SetLabel(text);
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
                SetLabel(value);
                //llInstantMessage(llGetOwner(), "Loaded label " + value + " from database.");
            }            
        }
        else if (auth == COMMAND_WEARER && str == "reset")
        {
            llMessageLinked(LINK_THIS, HTTPDB_DELETE, "label", NULL_KEY);                    
            llResetScript();            
        }
        else if (auth == MENUNAME_REQUEST)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        else if (auth == SUBMENU && str == submenu)
        {
            //popup help on how to set label
            llMessageLinked(LINK_THIS, POPUP_HELP, "To set the label on the collar, say _PREFIX_label followed by the text you wish to set.\nExample: _PREFIX_label I Rock!", id);
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
