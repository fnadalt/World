// App state
const int APP_STATE_NULL = 0;
const int APP_STATE_START = 1;
const int APP_STATE_WORLD = 2;
const int APP_STATE_TERRAIN = 3;

// World modes
const int WRLD_MODE_LOCAL = 0;
const int WRLD_MODE_SERVER = 1;
const int WRLD_MODE_CLIENT = 2;

// Camera modes
const int CAM_MODE_UI = 0;
const int CAM_MODE_SELECT = 1;
const int CAM_MODE_RIG = 2;

// Camera rig
const int CAM_RIG_FREE = 0;
const int CAM_RIG_FSTP = 1;
const int CAM_RIG_THRDP = 2;

// Collision masks
const int COLL_MSK_NULL = 0;
const int COLL_MSK_CHAR = 1;
const int COLL_MSK_PROP = 2;
const int COLL_MSK_RAY = 4;

// Tags
const String TAG_SELECTABLE = "Selectable";
const String TAG_CHARACTER = "Character";
const String TAG_ITEM = "Item";
const String TAG_PROP = "Prop";

// Controls
const int CTRL_ALL = 127;
const int CTRL_FORWARD = 1;
const int CTRL_BACK = 2;
const int CTRL_LEFT = 4;
const int CTRL_RIGHT = 8;
const int CTRL_JUMP = 16;
const int CTRL_ACTION = 32;
const int CTRL_PICK = 64;

// Terrain
const float WATER_PLANE_ALTITUDE = 0.1f;

