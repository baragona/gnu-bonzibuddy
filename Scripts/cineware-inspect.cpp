#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include "c4d.h"
#define DONT_INCLUDE_MEMORY_OVERLOADS
#include "default_alien_overloads.h"
using namespace cineware;
namespace cineware {
void* MemAllocNC(Int n){return malloc(n);}
void* MemAlloc(Int n){return calloc(1,n);}
void* MemRealloc(void* p,Int n){return realloc(p,n);}
void MemFree(void*& p){free(p);p=nullptr;}
}
void GetWriterInfo(Int32& id,String& name){id=0;name="Bonzi offline inspection";}
#include "cineware-export.h"
FILE* objFile=nullptr; long vertexOffset=1;
void walk(BaseObject* op,int depth){
 for(;op;op=op->GetNext()){
  Char* name=op->GetName().GetCStringCopy();
  printf("%*s%s type=%d",depth*2,"",name,(int)op->GetType());DeleteMem(name);
  if(op->GetType()==Opolygon){auto* mesh=static_cast<PolygonObject*>(op);printf(" points=%d polygons=%d",(int)mesh->GetPointCount(),(int)mesh->GetPolygonCount());}
  printf("\n");
  if(objFile && op->GetType()==Opolygon){
   auto* mesh=static_cast<PolygonObject*>(op);Char* label=op->GetName().GetCStringCopy();
   bool core=strcmp(label,"head")==0 || strcmp(label,"mouth")==0 || strcmp(label,"Sphere.1")==0 || strcmp(label,"eye")==0;
   if(core){
    fprintf(objFile,"o %s\n",label);auto matrix=op->GetMg();auto* points=mesh->GetPointR();auto* polys=mesh->GetPolygonR();
    for(int i=0;i<mesh->GetPointCount();i++){auto p=matrix*points[i];fprintf(objFile,"v %.9g %.9g %.9g\n",(double)p.x,(double)p.y,(double)p.z);}
    for(int i=0;i<mesh->GetPolygonCount();i++){auto p=polys[i];fprintf(objFile,"f %ld %ld %ld",vertexOffset+p.a,vertexOffset+p.b,vertexOffset+p.c);if(p.c!=p.d)fprintf(objFile," %ld",vertexOffset+p.d);fprintf(objFile,"\n");}
    vertexOffset+=mesh->GetPointCount();
   }
   DeleteMem(label);
  }
  for(BaseTag* tag=op->GetFirstTag();tag;tag=tag->GetNext()){Char* n=tag->GetName().GetCStringCopy();printf("%*stag %s type=%d\n",depth*2+2,"",n,(int)tag->GetType());DeleteMem(n);
   if(tag->GetType()==1024237 && tag->GetNodeData()){
    auto* morphs=static_cast<PoseMorphTagData*>(tag->GetNodeData());
    for(int i=0;i<morphs->GetMorphCount();i++){
     auto* morph=morphs->GetMorph(i);Char* mn=morph->GetName().GetCStringCopy();auto* node=morph->GetFirst();
     printf("%*smorph %d %s points=%d strength=%g\n",depth*2+4,"",i,mn,node?node->GetPointCount():0,(double)morph->GetStrength());DeleteMem(mn);
     auto* base=morphs->GetMorph(0)->GetFirst();double maxDelta=0;
     if(node && base && node->GetPointCount()==base->GetPointCount()){
      for(int p=0;p<node->GetPointCount();p++){auto d=node->GetPoint(p)-base->GetPoint(p);double delta=std::sqrt(d.x*d.x+d.y*d.y+d.z*d.z);if(!std::isfinite(delta)){fprintf(stderr,"Nonfinite morph point\n");exit(4);}if(delta>maxDelta)maxDelta=delta;}
      printf("%*smaximum point difference from base=%g\n",depth*2+6,"",maxDelta);
     }
    }
   }
   if(tag->GetType()==1019365 && tag->GetNodeData()){
    auto* weights=static_cast<WeightTagData*>(tag->GetNodeData());printf("%*sweighted joints=%d\n",depth*2+4,"",weights->GetJointCount());
   }
  }
  walk(op->GetDown(),depth+1);
 }
}
int main(int argc,char** argv){if(argc<2 || argc>4)return 2;if(argc>=3){objFile=fopen(argv[2],"w");if(!objFile)return 3;}auto* doc=LoadDocument(Filename(argv[1]),SCENEFILTER_OBJECTS|SCENEFILTER_MATERIALS);if(!doc){fprintf(stderr,"load failed\n");return 1;}walk(doc->GetFirstObject(),0);if(argc==4 && !exportScene(doc,argv[3]))return 5;BaseDocument::Free(doc);if(objFile)fclose(objFile);return 0;}
