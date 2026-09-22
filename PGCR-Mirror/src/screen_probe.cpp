#include <dlfcn.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* QNX Screen 6.5/6.6 property IDs. Read-only probe: no set/create-window calls. */
#define SCREEN_PROPERTY_BUFFER_SIZE 5
#define SCREEN_PROPERTY_DISPLAY 11
#define SCREEN_PROPERTY_FORMAT 14
#define SCREEN_PROPERTY_GLOBAL_ALPHA 16
#define SCREEN_PROPERTY_GROUP 18
#define SCREEN_PROPERTY_ID_STRING 20
#define SCREEN_PROPERTY_NAME 30
#define SCREEN_PROPERTY_OWNER_PID 31
#define SCREEN_PROPERTY_POSITION 35
#define SCREEN_PROPERTY_ROTATION 38
#define SCREEN_PROPERTY_SIZE 40
#define SCREEN_PROPERTY_SOURCE_POSITION 41
#define SCREEN_PROPERTY_SOURCE_SIZE 42
#define SCREEN_PROPERTY_SWAP_INTERVAL 45
#define SCREEN_PROPERTY_TRANSPARENCY 46
#define SCREEN_PROPERTY_TYPE 47
#define SCREEN_PROPERTY_USAGE 48
#define SCREEN_PROPERTY_VISIBLE 51
#define SCREEN_PROPERTY_RENDER_BUFFER_COUNT 53
#define SCREEN_PROPERTY_ZORDER 54
#define SCREEN_PROPERTY_DISPLAY_COUNT 59
#define SCREEN_PROPERTY_DISPLAYS 60
#define SCREEN_PROPERTY_WINDOW_COUNT 108
#define SCREEN_PROPERTY_WINDOWS 109

#define SCREEN_DISPLAY_MANAGER_CONTEXT (1 << 3)
#define SCREEN_WINDOW_MANAGER_CONTEXT (1 << 0)

typedef int (*create_context_fn)(void **, int);
typedef int (*destroy_context_fn)(void *);
typedef int (*get_context_iv_fn)(void *, int, int *);
typedef int (*get_context_pv_fn)(void *, int, void **);
typedef int (*get_display_iv_fn)(void *, int, int *);
typedef int (*get_display_cv_fn)(void *, int, int, char *);
typedef int (*get_window_iv_fn)(void *, int, int *);
typedef int (*get_window_cv_fn)(void *, int, int, char *);
typedef int (*get_window_pv_fn)(void *, int, void **);

static void get_pair(get_window_iv_fn fn, void *w, int prop, int *a, int *b) {
    int v[2] = {-9999, -9999};
    if (fn(w, prop, v) == 0) { *a=v[0]; *b=v[1]; }
    else { *a=-9999; *b=-9999; }
}
static int get_one(get_window_iv_fn fn, void *w, int prop) {
    int v=-9999;
    return fn(w, prop, &v)==0 ? v : -9999;
}
static void get_text(get_window_cv_fn fn, void *w, int prop, char *out, int n) {
    if (!out || n<=0) return;
    memset(out,0,(size_t)n);
    if (!fn || fn(w,prop,n,out)!=0) {
        strncpy(out,"?",(size_t)n-1);
        out[n-1]=0;
    }
}
static int display_index(void *d, void **list, int count) {
    for (int i=0;i<count;++i) if (list[i]==d) return i;
    return -1;
}
static bool contains_ci(const char *s,const char *needle){
    if(!s||!needle||!*needle)return false;
    size_t n=strlen(needle);
    for(const char *p=s;*p;++p){
        size_t i=0;
        for(;i<n&&p[i];++i){
            char a=p[i],b=needle[i];
            if(a>='A'&&a<='Z')a=(char)(a-'A'+'a');
            if(b>='A'&&b<='Z')b=(char)(b-'A'+'a');
            if(a!=b)break;
        }
        if(i==n)return true;
    }
    return false;
}
static bool carplay_hint(const char *id,const char *name,const char *group){
    static const char *terms[]={"carplay","apple","projection","smartphone","phone","iap","video","mirrorlink",0};
    for(int i=0;terms[i];++i)
        if(contains_ci(id,terms[i])||contains_ci(name,terms[i])||contains_ci(group,terms[i]))return true;
    return false;
}

int main(void) {
    void *lib=dlopen("libscreen.so.1",RTLD_LAZY);
    if(!lib) lib=dlopen("libscreen.so",RTLD_LAZY);
    if(!lib){ fprintf(stderr,"PROBE_ERROR libscreen unavailable\n"); return 2; }

    create_context_fn create_ctx=(create_context_fn)dlsym(lib,"screen_create_context");
    destroy_context_fn destroy_ctx=(destroy_context_fn)dlsym(lib,"screen_destroy_context");
    get_context_iv_fn ctx_iv=(get_context_iv_fn)dlsym(lib,"screen_get_context_property_iv");
    get_context_pv_fn ctx_pv=(get_context_pv_fn)dlsym(lib,"screen_get_context_property_pv");
    get_display_iv_fn disp_iv=(get_display_iv_fn)dlsym(lib,"screen_get_display_property_iv");
    get_display_cv_fn disp_cv=(get_display_cv_fn)dlsym(lib,"screen_get_display_property_cv");
    get_window_iv_fn win_iv=(get_window_iv_fn)dlsym(lib,"screen_get_window_property_iv");
    get_window_cv_fn win_cv=(get_window_cv_fn)dlsym(lib,"screen_get_window_property_cv");
    get_window_pv_fn win_pv=(get_window_pv_fn)dlsym(lib,"screen_get_window_property_pv");

    if(!create_ctx||!destroy_ctx||!ctx_iv||!ctx_pv||!disp_iv||!win_iv||!win_cv||!win_pv){
        fprintf(stderr,"PROBE_ERROR required Screen API missing\n");
        dlclose(lib); return 3;
    }

    /*
     * Probe windows through WINDOW_MANAGER first. On P0915 the
     * DISPLAY_MANAGER context can enumerate physical displays but reports
     * WINDOW_COUNT=0, which makes a CarPlay differential impossible.
     * WINDOW_MANAGER is still read-only here: this binary resolves no Screen
     * setters and creates/destroys no vehicle windows.
     */
    void *ctx=0;
    int ctx_type=SCREEN_WINDOW_MANAGER_CONTEXT;
    if(create_ctx(&ctx,ctx_type)!=0){
        ctx=0; ctx_type=SCREEN_DISPLAY_MANAGER_CONTEXT;
        if(create_ctx(&ctx,ctx_type)!=0){
            fprintf(stderr,"PROBE_ERROR cannot create manager context errno=%d\n",errno);
            dlclose(lib); return 4;
        }
    }

    int dc=0;
    if(ctx_iv(ctx,SCREEN_PROPERTY_DISPLAY_COUNT,&dc)!=0) dc=0;
    if(dc<0) dc=0; if(dc>32) dc=32;
    void *displays[32]; memset(displays,0,sizeof(displays));
    if(dc>0 && ctx_pv(ctx,SCREEN_PROPERTY_DISPLAYS,displays)!=0) dc=0;

    printf("===== PGCR v0.4.1 CarPlay Source Probe =====\n");
    printf("mode=READ_ONLY\n");
    printf("NOTE=no existing vehicle window is created/moved/resized/destroyed\n");
    printf("PGCR_SCREEN_PROBE_V04\n");
    printf("context_type=%s\n",ctx_type==SCREEN_DISPLAY_MANAGER_CONTEXT?"DISPLAY_MANAGER":"WINDOW_MANAGER");
    printf("display_count=%d\n",dc);
    for(int i=0;i<dc;++i){
        int sz[2]={-1,-1};
        if(disp_iv(displays[i],SCREEN_PROPERTY_SIZE,sz)!=0){sz[0]=-1;sz[1]=-1;}
        char did[128]; memset(did,0,sizeof(did));
        if(!disp_cv || disp_cv(displays[i],SCREEN_PROPERTY_ID_STRING,(int)sizeof(did)-1,did)!=0) strcpy(did,"?");
        printf("DISPLAY index=%d size=%dx%d id=\"%s\" handle=%p\n",i,sz[0],sz[1],did,displays[i]);
    }

    int wc=0;
    if(ctx_iv(ctx,SCREEN_PROPERTY_WINDOW_COUNT,&wc)!=0){
        printf("window_count=ERROR errno=%d\n",errno);
        destroy_ctx(ctx); dlclose(lib); return 5;
    }
    if(wc<0) wc=0; if(wc>512) wc=512;
    void **wins=(void**)calloc((size_t)(wc?wc:1),sizeof(void*));
    if(!wins){ destroy_ctx(ctx); dlclose(lib); return 6; }
    if(wc>0 && ctx_pv(ctx,SCREEN_PROPERTY_WINDOWS,wins)!=0){
        printf("windows=ERROR errno=%d\n",errno);
        free(wins); destroy_ctx(ctx); dlclose(lib); return 7;
    }

    printf("window_count=%d\n",wc);
    int hinted=0;
    for(int i=0;i<wc;++i){
        void *w=wins[i];
        int posx,posy,sizew,sizeh,srcx,srcy,srcw,srch;
        get_pair(win_iv,w,SCREEN_PROPERTY_POSITION,&posx,&posy);
        get_pair(win_iv,w,SCREEN_PROPERTY_SIZE,&sizew,&sizeh);
        get_pair(win_iv,w,SCREEN_PROPERTY_SOURCE_POSITION,&srcx,&srcy);
        get_pair(win_iv,w,SCREEN_PROPERTY_SOURCE_SIZE,&srcw,&srch);
        int pid=get_one(win_iv,w,SCREEN_PROPERTY_OWNER_PID);
        int vis=get_one(win_iv,w,SCREEN_PROPERTY_VISIBLE);
        int z=get_one(win_iv,w,SCREEN_PROPERTY_ZORDER);
        int fmt=get_one(win_iv,w,SCREEN_PROPERTY_FORMAT);
        int usage=get_one(win_iv,w,SCREEN_PROPERTY_USAGE);
        int type=get_one(win_iv,w,SCREEN_PROPERTY_TYPE);
        int rb=get_one(win_iv,w,SCREEN_PROPERTY_RENDER_BUFFER_COUNT);
        int trans=get_one(win_iv,w,SCREEN_PROPERTY_TRANSPARENCY);
        int alpha=get_one(win_iv,w,SCREEN_PROPERTY_GLOBAL_ALPHA);
        int rotation=get_one(win_iv,w,SCREEN_PROPERTY_ROTATION);
        int swap=get_one(win_iv,w,SCREEN_PROPERTY_SWAP_INTERVAL);
        int bufx,bufy;
        get_pair(win_iv,w,SCREEN_PROPERTY_BUFFER_SIZE,&bufx,&bufy);
        char id[128],name[128],group[128];
        get_text(win_cv,w,SCREEN_PROPERTY_ID_STRING,id,sizeof(id));
        get_text(win_cv,w,SCREEN_PROPERTY_NAME,name,sizeof(name));
        get_text(win_cv,w,SCREEN_PROPERTY_GROUP,group,sizeof(group));
        void *disp=0;
        int di=-1;
        if(win_pv(w,SCREEN_PROPERTY_DISPLAY,&disp)==0 && disp) di=display_index(disp,displays,dc);
        bool hint=carplay_hint(id,name,group);
        if(hint)++hinted;

        printf("WINDOW index=%d%s pid=%d display=%d visible=%d z=%d type=%d format=%d usage=0x%x rb=%d trans=%d alpha=%d rot=%d swap=%d pos=%d,%d size=%dx%d src=%d,%d+%dx%d buf=%dx%d id=\"%s\" name=\"%s\" group=\"%s\" handle=%p\n",
            i,hint?" [CARPLAY_HINT]":"",pid,di,vis,z,type,fmt,usage,rb,trans,alpha,rotation,swap,posx,posy,sizew,sizeh,srcx,srcy,srcw,srch,bufx,bufy,id,name,group,w);
    }

    printf("CARPLAY_HINT_WINDOWS=%d\n",hinted);
    printf("PROBE_RESULT=OK\n");
    printf("===== END PGCR v0.4 PROBE =====\n");

    free(wins);
    destroy_ctx(ctx);
    dlclose(lib);
    return 0;
}
