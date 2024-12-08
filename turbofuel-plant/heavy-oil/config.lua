-- turbofuel-plant/heavy-oil/config.lua

return {
    HISTORY_LENGTH = 1800, -- 30 minutes in seconds (30 * 60)
    UPDATE_INTERVAL = 1,
    REFINERY_IDS = {
        "D1F743E04B122411F5D883AB9451315A",
        "721DAD354B8903283D76468DFA21F5CF",
        "0FD5BAA340D21090089A2888EFF3B7D9",
        "AA53C7D249E53DD14B7D788555DEE324",
        "9C553AF643B61B0C29C73CA58A0ACB09",
        "C1AEBA9240916640D14DCC829A6AA0A6",
        "D122A9324B19B6CC5FB7F0A4D060502C",
        "C3E5FD184B00880FD1D4BBBB175979C5",
        "6219710B43C39AA12F160B94B53508E6",
        "7E6E1EB04760890578B999A1C6BBF42B",
        "60C77D5E471DFC60D4FF82B9F3AD6032",
        "9E1B36C54E26D5F64A3E07B69A82232B",
        "189179C1442816689CDCD5834C86420A",
        "313F4B4E42D7FFA6CD278EBD21B43D35",
        "B8D928A3432EE5C2C0A27591977BD518",
        "913F69C94DA8C3AD8A2EFB81F89F1855",
        "60C7ECD54CC53E684D3E109FD61B7BC5",
        "2E380D4C4651306316A200A011506A82",
        "CDA12295462C694CEC78A8B4D0F1EB73",
        "1F5C2DAD4EAB3F3C8DFFF689615F9693",
        "E57C9F4944DB2B3448DF728711136FE8",
        "B9A3725C47A2094A1BAB40991F333540",
        "CA52A0E1434598E98EF7DB89D46225C2",
        "D8BA6DCA458E9DBF3BFDAAB2DF0F8C90",
        "C4E5005349995BD214AA44B25D440E26",
        "0651ECD44B05EDF9A7EF1187474ADF4D",
        "6DFB13CE44542C149B98739C0AC13ED6",
        "CCCB4923440639ADD82EF78CD399C5A4",
        "597BF7064A73B55231B08EAEF3882105",
        "3A83F2BF47E7DA6B5E25CCBDF4EB4AD0",
        "B5BEF44448ABD35D836A6BB9BAFC389F",
        "F5F07CBC43FB837DFB3E0DB343F15420",
        "21CB2C6443FA6DE19195F3BF6D15D123",
        "4B68A800421659C88DB74C8C13FE3DB0",
        "3A88C23243D8274D667E68B39E0E718A",
        "D77626ED459A4DCC0A276892A6B629F6",
        "57DD34CB4D6993FDD92C03B88B36144E",
        "95FDC8C346E19F9ED8500CB7B064695A",
        "BE13C59148ACB3079913E498E3CB6D87",
        "29CE0F114F66EB494941179A738BE076"
    },
    COMPONENT_IDS = {
        POWER_SWITCH = "D29CF4FE4E0E688D1BDCA5A656156CF9",
        BATTERY_SWITCH = "D41817DE4531874AD41C0E8AA61CAC3A",
        LIGHT_SWITCH = "B6AD10DE4F9BCFD751CA49A2A74917ED",
        DISPLAY_PANEL = "84B30B434C7A0A65FAAD739267DC1F3C",

        VALVE_CONFIG = {
            crude = {
                "E3FB1A38422706A9FB8AD7A99A51CB61",
                "EC6110814188803DA5C8D9B42E46527B"
            },
            heavy = {
                "468DB01947A740ED7BC7BC825779CFF7",
                "32CEDE4046EEC8C58772F2949CB68667",
                "D9F6A4F64268576DA45D728E43ED87CB"
            }
        }
    },
    DISPLAY_LAYOUT = {
        PRODUCTIVITY_ROWS = {
            -- First row of 10 machines
            { startX = 1, startY = 2, panelNum = 0, count = 10 },
            -- Second row of 10 machines
            { startX = 1, startY = 0, panelNum = 0, count = 10 },
            -- Third row of 10 machines
            { startX = 1, startY = 7, panelNum = 0, count = 10 },
            -- Fourth row of 10 machines
            { startX = 1, startY = 5, panelNum = 0, count = 10 }
        },
        EMERGENCY_STOP = { x = 10, y = 10, z = 0 },
        HEALTH_INDICATOR = { x = 1, y = 10, z = 0 },
        PRODUCTIVITY_DISPLAY = { x = 2, y = 9, z = 0 }
    }
}
