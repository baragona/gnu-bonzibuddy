#include <metal_stdlib>
using namespace metal;
struct Vertex { float4 position0; float4 normal0; float4 position1; float4 normal1; float4 color; float4 skin; };
struct Instance { float4x4 model; float4 color; };
struct Uniforms { float4x4 projection; float4x4 light; float4x4 ground; float4 options; float4 jawAxis; };
struct Varying { float4 position [[position]]; float3 normal; float3 world; float4 color; float jaw; };
float3 transformNormal(float4x4 model, float3 normal) {
    float3x3 m = float3x3(model[0].xyz,model[1].xyz,model[2].xyz);
    return m[0]*normal.x/dot(m[0],m[0])+m[1]*normal.y/dot(m[1],m[1])+m[2]*normal.z/dot(m[2],m[2]);
}
float3 armEndpoint(float4x4 m,float sign) {
    float3 axis=m[1].xyz;
    return m[3].xyz+normalize(axis)*(length(axis)-length(m[0].xyz)*0.35)*sign;
}
float3 armCenter(float t,float3 shoulder,float3 elbow,float3 wrist) {
    bool first=t<=0.5; float u=first ? t*2 : (t-0.5)*2;
    float3 a=first ? shoulder : elbow,b=first ? elbow : wrist;
    float3 m0=first ? elbow-shoulder : (wrist-shoulder)*0.5;
    float3 m1=first ? (wrist-shoulder)*0.5 : wrist-elbow;
    return (2*u*u*u-3*u*u+1)*a+(u*u*u-2*u*u+u)*m0+(-2*u*u*u+3*u*u)*b+(u*u*u-u*u)*m1;
}
float3 armSurface(float t,float c,float s,float3 shoulder,float3 elbow,float3 wrist,float3 frameAxis) {
    float3 tangent=normalize(armCenter(min(1.0,t+0.001),shoulder,elbow,wrist)-armCenter(max(0.0,t-0.001),shoulder,elbow,wrist));
    float3 x=normalize(cross(tangent,frameAxis)),z=normalize(cross(x,tangent));
    return armCenter(t,shoulder,elbow,wrist)+(x*c+z*s)*(0.105-0.060*t);
}
struct Deformed { float4 world; float3 normal; };
Deformed deform(Vertex vert,const device Instance* bones,constant Uniforms& u) {
    float4x4 a=bones[uint(vert.skin.x)].model,b=bones[uint(vert.skin.y)].model;
    Deformed out;
    if (vert.skin.z == -2) {
        float open=clamp(bones[uint(vert.skin.x)].color.a,0.0,1.0);
        float start=asin(clamp(open*2.0-1.0,-0.995,0.995));
        float latitude=mix(start,M_PI_F/2.0-0.001,vert.position0.y);
        float phi=(vert.position0.x-0.5)*2.0*M_PI_F;
        float3 local=float3(cos(latitude)*sin(phi),sin(latitude),cos(latitude)*cos(phi));
        bool back=vert.position0.z>0.5;
        out.world=a*float4(local*(back ? 0.98 : 1.0),1);
        // Retract the folded cap into the forehead instead of leaving a visible nub.
        out.world.xyz-=normalize(a[2].xyz)*0.120*smoothstep(0.95,1.0,open);
        out.normal=normalize(transformNormal(a,local))*(back ? -1.0 : 1.0);
    } else if (vert.skin.z == -1) {
        float t=vert.position0.x;
        float3 shoulder=armEndpoint(a,-1),elbow=armEndpoint(a,1),wrist=armEndpoint(b,1)-normalize(bones[uint(vert.skin.y)+1].model[1].xyz)*0.035;
        float3 bendNormal=cross(elbow-shoulder,wrist-elbow);
        float3 frameAxis=length_squared(bendNormal)>0.000001 ? normalize(bendNormal) : normalize(a[2].xyz);
        float3 tangent=normalize(armCenter(min(1.0,t+0.001),shoulder,elbow,wrist)-armCenter(max(0.0,t-0.001),shoulder,elbow,wrist));
        float3 x=normalize(cross(tangent,frameAxis)),z=normalize(cross(x,tangent));
        float3 radial=x*vert.position0.y+z*vert.position0.z;
        out.world=float4(armCenter(t,shoulder,elbow,wrist)+radial*vert.position0.w,1);
        if (vert.position0.w>0) {
            // The swept surface bends and tapers; its normal is not purely radial.
            float3 along=armSurface(min(1.0,t+0.001),vert.position0.y,vert.position0.z,shoulder,elbow,wrist,frameAxis)
                        -armSurface(max(0.0,t-0.001),vert.position0.y,vert.position0.z,shoulder,elbow,wrist,frameAxis);
            float3 around=-x*vert.position0.z+z*vert.position0.y;
            out.normal=normalize(cross(around,along));
            if (dot(out.normal,radial)<0) out.normal=-out.normal;
        } else out.normal=tangent*(t<0.5 ? -1.0 : 1.0);
    } else {
        out.world=mix(b*vert.position1,a*vert.position0,vert.skin.z);
        out.world.xyz-=u.jawAxis.xyz*u.options.z*vert.skin.w;
        out.normal=normalize(mix(transformNormal(b,vert.normal1.xyz),transformNormal(a,vert.normal0.xyz),vert.skin.z));
    }
    return out;
}
vertex Varying vertexMain(const device Vertex* vertices [[buffer(0)]], const device Instance* bones [[buffer(1)]], constant Uniforms& u [[buffer(2)]], uint v [[vertex_id]]) {
    Vertex vert=vertices[v]; Deformed d=deform(vert,bones,u);
    Varying out; out.position=u.projection*d.world; out.normal=d.normal;
    out.world=d.world.xyz; out.color=vert.color; out.jaw=vert.skin.w; return out;
}
// Both passes evaluate precisely the same articulated polygon surface.
vertex float4 shadowVertex(const device Vertex* vertices [[buffer(0)]], const device Instance* bones [[buffer(1)]], constant Uniforms& u [[buffer(2)]], uint v [[vertex_id]]) {
    return u.light*deform(vertices[v],bones,u).world;
}
constant float2 shadowDisk[16] = {
    float2(-0.61,-0.35),float2(0.20,-0.82),float2(0.66,-0.44),float2(-0.11,-0.25),
    float2(-0.91,0.07),float2(-0.40,0.25),float2(0.24,0.10),float2(0.89,0.03),
    float2(-0.60,0.70),float2(-0.12,0.91),float2(0.38,0.66),float2(0.78,0.55),
    float2(-0.26,-0.62),float2(0.53,-0.02),float2(-0.02,0.44),float2(0.08,-0.02)
};
float visibility(float3 world,float3 normal,depth2d<float> shadow,constant Uniforms& u) {
    if (u.options.x < 0.5) return 1.0;
    float4 p = u.light*float4(world+normal*0.007,1);
    float2 uv = float2(p.x*0.5+0.5,0.5-p.y*0.5);
    if (any(uv<0.0) || any(uv>1.0) || p.z<0.0 || p.z>1.0) return 1.0;
    constexpr sampler nearest(coord::normalized,address::clamp_to_edge,filter::nearest);
    constexpr sampler comparison(coord::normalized,address::clamp_to_edge,filter::linear,compare_func::less_equal);
    float facing = max(0.0,dot(normal,normalize(float3(-0.5,0.8,1.4))));
    float receiver = p.z - (0.0005 + 0.0008*(1.0-facing));
    float blocker = 0.0, count = 0.0;
    for (uint i=0;i<16;i++) {
        float d = shadow.sample(nearest,uv+shadowDisk[i]*0.015);
        if (d<receiver) { blocker+=d; count+=1.0; }
    }
    if (count==0.0) return 1.0;
    // Penumbrae widen with receiver/blocker separation, while contact stays tight.
    float radius = clamp((receiver-blocker/count)*0.5,0.003,0.035);
    float lit=0.0;
    for (uint i=0;i<16;i++) {
        float2 offset = shadowDisk[i]*radius;
        lit += shadow.sample_compare(comparison,uv+offset,receiver);
        // A rotated, interleaved ring reduces visible quantization in broad penumbrae.
        float2 second = float2(offset.x*0.707-offset.y*0.707,offset.x*0.707+offset.y*0.707)*0.83;
        lit += shadow.sample_compare(comparison,uv+second,receiver);
    }
    return lit/32.0;
}
fragment float4 fragmentMain(Varying in [[stage_in]],depth2d<float> shadow [[texture(0)]],constant Uniforms& u [[buffer(2)]]) {
    float3 n = normalize(in.normal);
    float3 geometric = normalize(cross(dfdx(in.world),dfdy(in.world)));
    if (dot(geometric,n)<0.0) geometric=-geometric;
    // The moving inner lip needs normals from the deformed surface, not its closed pose.
    if (in.jaw>0.001) n=normalize(mix(n,geometric,min(0.35,u.options.z/0.006)));
    float diffuse = max(0.0, dot(n, normalize(float3(-0.5,0.8,1.4))));
    float fill = max(0.0, dot(n, normalize(float3(1,0.1,0.8))));
    float spec = pow(max(0.0, dot(n, normalize(float3(-0.25,0.4,1.8)))), 14.0);
    float shade = visibility(in.world,n,shadow,u);
    // Dark oral surfaces and pupils do not share the skin highlight.
    float sheen = smoothstep(0.42,0.65,max(in.color.r,max(in.color.g,in.color.b)));
    float3 color = in.color.rgb * (0.36 + 0.60*diffuse*shade + 0.12*fill) + 0.16*spec*shade*sheen;
    return float4(color * in.color.a, in.color.a);
}
vertex Varying groundVertex(uint v [[vertex_id]],constant Uniforms& u [[buffer(2)]]) {
    const float2 corners[6] = {float2(-1.4,-1.4),float2(1.4,-1.4),float2(-1.4,1.4),float2(-1.4,1.4),float2(1.4,-1.4),float2(1.4,1.4)};
    float4 world = u.ground*float4(corners[v].x,0,corners[v].y,1);
    Varying out; out.world=world.xyz;out.position=u.projection*world;out.normal=(u.ground*float4(0,1,0,0)).xyz;out.color=float4(corners[v],0,0);out.jaw=0;
    return out;
}
fragment float4 groundFragment(Varying in [[stage_in]],depth2d<float> shadow [[texture(0)]],constant Uniforms& u [[buffer(2)]]) {
    float shade = visibility(in.world,normalize(in.normal),shadow,u);
    float fade = 1.0-smoothstep(0.65,1.25,length(in.color.xy));
    float alpha = (1.0-shade)*u.options.y*fade;
    return float4(float3(0.08,0.055,0.10)*alpha,alpha);
}
