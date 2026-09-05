// Offline interchange exporter. SDK types stay out of the native app.
#include <vector>
#include "c4d_customdatatype/customgui_gradient.h"
#include <algorithm>
static FILE* jf;
static std::vector<BaseObject*> objects;
static std::vector<BaseMaterial*> materials;
static void str(const String& s){
 Char* p=s.GetCStringCopy(STRINGENCODING_UTF8);fputc('"',jf);
 for(const unsigned char* c=(unsigned char*)p;c && *c;c++){
  if(*c=='"'||*c=='\\')fprintf(jf,"\\%c",*c);
  else if(*c<32)fprintf(jf,"\\u%04x",*c);else fputc(*c,jf);
 }fputc('"',jf);DeleteMem(p);
}
static void vec(Vector p){fprintf(jf,"[%.17g,%.17g,%.17g]",(double)p.x,(double)p.y,(double)p.z);}
// Four columns: X, Y, Z axes followed by translation, in source coordinates.
static void mat(Matrix m){fputc('[',jf);vec(m.v1);fputc(',',jf);vec(m.v2);fputc(',',jf);vec(m.v3);fputc(',',jf);vec(m.off);fputc(']',jf);}
static void params(BaseList2D* node){
 auto* bc=node->GetDataInstance();fprintf(jf,"{ ");bool first=true;
 for(int i=0;bc->GetIndexId(i)!=NOTOK;i++){
  int id=bc->GetIndexId(i);const auto& d=bc->GetData(id);int type=d.GetType();
  if(type!=DA_LONG && type!=DA_REAL && type!=DA_VECTOR && type!=DA_STRING)continue;
  if(!first)fputc(',',jf);first=false;fprintf(jf,"\"%d\":",id);
  if(type==DA_LONG)fprintf(jf,"%d",d.GetInt32());else if(type==DA_REAL)fprintf(jf,"%.17g",(double)d.GetFloat());else if(type==DA_VECTOR)vec(d.GetVector());else str(d.GetString());
 }fputc('}',jf);
}
static void shaders(BaseShader* shader){
 fputc('[',jf);bool first=true;
 for(;shader;shader=shader->GetNext()){
  if(!first)fputc(',',jf);first=false;fprintf(jf,"{\"type\":%d,\"name\":",(int)shader->GetType());str(shader->GetName());fprintf(jf,",\"parameters\":");params(shader);
  if(shader->GetType()==1011100){auto* g=static_cast<Gradient*>(shader->GetDataInstance()->GetData(1007).GetCustomDataType(CUSTOMDATATYPE_GRADIENT));if(g){fprintf(jf,",\"gradientKnots\":[");for(int i=0;i<g->GetKnotCount();i++){if(i)fputc(',',jf);auto k=g->GetKnot(i);fprintf(jf,"{\"position\":%.17g,\"color\":",(double)k.pos);vec(k.col);fprintf(jf,",\"interpolation\":%d}",k.interpolation);}fputc(']',jf);}}
  fprintf(jf,",\"children\":");shaders(shader->GetDown());fputc('}',jf);
 }fputc(']',jf);
}
static int oid(BaseObject* o){auto i=std::find(objects.begin(),objects.end(),o);return i==objects.end()?-1:int(i-objects.begin());}
static int mid(BaseMaterial* m){auto i=std::find(materials.begin(),materials.end(),m);return i==materials.end()?-1:int(i-materials.begin());}
static void collect(BaseObject* o){for(;o;o=o->GetNext()){objects.push_back(o);collect(o->GetDown());}}
static bool exportScene(BaseDocument* doc,const char* path){
 jf=fopen(path,"w");if(!jf)return false;
 objects.clear();materials.clear();collect(doc->GetFirstObject());
 for(auto* m=doc->GetFirstMaterial();m;m=m->GetNext())materials.push_back(m);
 fprintf(jf,"{\"version\":1,\"coordinates\":\"C4D source local points; matrices are axis columns plus translation\",\"materials\":[");
 for(size_t i=0;i<materials.size();i++){if(i)fputc(',',jf);fprintf(jf,"{\"name\":");str(materials[i]->GetName());fprintf(jf,",\"sourceColor\":");vec(materials[i]->GetDataInstance()->GetVector(2100));fprintf(jf,",\"parameters\":");params(materials[i]);fprintf(jf,",\"shaders\":");shaders(materials[i]->GetFirstShader());fputc('}',jf);}
 fprintf(jf,"],\"objects\":[");
 for(size_t oi=0;oi<objects.size();oi++){
  auto* o=objects[oi];if(oi)fputc(',',jf);
  fprintf(jf,"{\"id\":%zu,\"parent\":%d,\"type\":%d,\"name\":",oi,oid(o->GetUp()),(int)o->GetType());str(o->GetName());
  fprintf(jf,",\"editorMode\":%d,\"renderMode\":%d,\"worldMatrix\":",o->GetEditorMode(),o->GetRenderMode());mat(o->GetMg());
  fprintf(jf,",\"localMatrix\":");mat(o->GetMl());
  int count=0;
  if(o->GetType()==Opolygon){
   auto* mesh=static_cast<PolygonObject*>(o);count=mesh->GetPointCount();fprintf(jf,",\"points\":[");
   for(int p=0;p<count;p++){if(p)fputc(',',jf);vec(mesh->GetPointR()[p]);}
   fprintf(jf,"],\"faces\":[");for(int p=0;p<mesh->GetPolygonCount();p++){if(p)fputc(',',jf);auto f=mesh->GetPolygonR()[p];fprintf(jf,"[%d,%d,%d",f.a,f.b,f.c);if(f.c!=f.d)fprintf(jf,",%d",f.d);fputc(']',jf);}fputc(']',jf);
  }
  fprintf(jf,",\"tags\":[");bool first=true;
  for(auto* t=o->GetFirstTag();t;t=t->GetNext()){
   if(!first)fputc(',',jf);first=false;fprintf(jf,"{\"type\":%d,\"name\":",(int)t->GetType());str(t->GetName());
   if(t->GetType()==5616){fprintf(jf,",\"material\":%d,\"selection\":",mid(static_cast<TextureTag*>(t)->GetMaterial()));str(t->GetDataInstance()->GetString(1006));fprintf(jf,",\"parameters\":");params(t);fprintf(jf,",\"projectionMatrix\":");mat(static_cast<TextureTag*>(t)->GetMl());}
   if(t->GetType()==5673 && count){auto* s=static_cast<SelectionTag*>(t)->GetBaseSelect();fprintf(jf,",\"faces\":[");bool a=true;for(int p=0;p<static_cast<PolygonObject*>(o)->GetPolygonCount();p++)if(s->IsSelected(p)){if(!a)fputc(',',jf);a=false;fprintf(jf,"%d",p);}fputc(']',jf);}
   if(t->GetType()==5671){auto* uv=static_cast<UVWTag*>(t);fprintf(jf,",\"uvw\":[");for(int p=0;p<uv->GetDataCount();p++){if(p)fputc(',',jf);UVWStruct u;UVWTag::Get(uv->GetDataAddressR(),p,u);fputc('[',jf);vec(u.a);fputc(',',jf);vec(u.b);fputc(',',jf);vec(u.c);fputc(',',jf);vec(u.d);fputc(']',jf);}fputc(']',jf);}
   if(t->GetType()==1019365 && t->GetNodeData()){
    auto* w=static_cast<WeightTagData*>(t->GetNodeData());fprintf(jf,",\"geometryBindMatrix\":");mat(w->GetGeomMg());fprintf(jf,",\"joints\":[");
    for(int j=0;j<w->GetJointCount();j++){if(j)fputc(',',jf);auto r=w->GetJointRestState(j);fprintf(jf,"{\"object\":%d,\"bindMatrix\":",oid(w->GetJoint(j,doc)));mat(r.m_oMg);fprintf(jf,",\"inverseBindMatrix\":");mat(r.m_oMi);fprintf(jf,",\"weights\":[");for(int p=0;p<count;p++){if(p)fputc(',',jf);fprintf(jf,"%.17g",(double)w->GetWeight(j,p));}fprintf(jf,"]}");}fputc(']',jf);
   }
   if(t->GetType()==1024237 && t->GetNodeData()){
    auto* pm=static_cast<PoseMorphTagData*>(t->GetNodeData());fprintf(jf,",\"morphs\":[");
    for(int m=0;m<pm->GetMorphCount();m++){if(m)fputc(',',jf);auto* morph=pm->GetMorph(m);fprintf(jf,"{\"name\":");str(morph->GetName());fprintf(jf,",\"strength\":%.17g,\"points\":[",(double)morph->GetStrength());auto* n=morph->GetFirst();for(int p=0;n && p<n->GetPointCount();p++){if(p)fputc(',',jf);vec(n->GetPoint(p));}fprintf(jf,"]}");}fputc(']',jf);
   }
   fputc('}',jf);
  }fprintf(jf,"]}");
 }
 fprintf(jf,"]}\n");bool ok=!ferror(jf);if(fclose(jf))ok=false;return ok;
}
