#include <metal_stdlib>
using namespace metal;
struct Vertex { float4 position0; float4 normal0; float4 position1; float4 normal1; float4 color; float4 skin; };
struct Instance { float4x4 model; float4 color; };
struct Uniforms { float4x4 projection; float4x4 light; float4x4 ground; float4 options; float4 jawAxis; };
struct Varying { float4 position [[position]]; float3 normal; float3 world; float4 color; float jaw; float3 eyeUV; float eyeHeight; };
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
    out.world=d.world.xyz; out.color=vert.color; out.jaw=vert.skin.w; out.eyeHeight=0; out.eyeUV=vert.skin.z==2 ? float3(vert.normal0.w,vert.normal1.w,1) : float3(0); return out;
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
struct FanEyeUniforms { float4 face; float4 closures; };
float4 shadeSurface(Varying in,depth2d<float> shadow,constant Uniforms& u,constant FanEyeUniforms& eyes) {
    float4 face=eyes.face;
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
    float4 surfaceColor=in.color;
    float eyeCatchlight=0.0;
    if (in.eyeUV.z>0.5) {
        // Preserve the source gradient edge, shaping fan pupils into the original tall ovals.
        float eyeSide=in.eyeUV.z>1.5 ? -1.0:1.0;
        float2 pupilUV=(in.eyeUV.xy-float2(0.5))*eyeSide-face.yz*0.20;
        float2 pupilShape=face.w>0.5 ? float2(1.15,1.6):float2(1.0);
        if (face.w>0.5) pupilUV.y-=0.035;
        float radius=2.0*length(pupilUV/pupilShape);
        float aa=max(fwidth(radius),0.001);
        float pupil=1.0-smoothstep(0.431-aa,0.4407+aa,radius);
        surfaceColor.rgb=mix(surfaceColor.rgb,float3(0.16,0.065,0.23),pupil);
        // Anatomical left eye is screen-right in a frontal view (UV side 1).
        float individual=in.eyeUV.z>1.5 ? eyes.closures.y:eyes.closures.x;
        float closure=clamp(max(face.x,individual),0.0,1.0);
        float lid=closure<=0 ? 0 : smoothstep(1.02-1.04*closure-0.015,1.02-1.04*closure+0.015,in.eyeHeight);
        surfaceColor.rgb=mix(surfaceColor.rgb,float3(0.53,0.305,0.76),lid);
        float crease=exp(-pow((in.eyeHeight-0.18)/0.025,2.0))*smoothstep(0.75,1.0,closure);
        surfaceColor.rgb*=1.0-0.25*crease;
        if (face.w>0.5 && face.w<1.5) {
            // Small antialiased corneal catchlight follows the pupil on both mirrored UV maps.
            float spot=length((pupilUV-float2(-0.065,0.085))/float2(0.048,0.060));
            float edge=max(fwidth(spot),0.01);
            eyeCatchlight=(1.0-smoothstep(1.0-edge,1.0+edge,spot))*pupil*(1.0-lid);
        }
    }
    float sheen = smoothstep(0.42,0.65,max(surfaceColor.r,max(surfaceColor.g,surfaceColor.b)));
    float3 color = surfaceColor.rgb * (0.36 + 0.60*diffuse*shade + 0.12*fill) + 0.16*spec*shade*sheen;
    color=mix(color,float3(0.98,0.98,1.0),eyeCatchlight*0.94);
    return float4(color * in.color.a, in.color.a);
}
fragment float4 fragmentMain(Varying in [[stage_in]],depth2d<float> shadow [[texture(0)]],constant Uniforms& u [[buffer(2)]],constant FanEyeUniforms& eyes [[buffer(3)]]) {
    return shadeSurface(in,shadow,u,eyes);
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

// Eight-influence native skinning of the imported fan mesh, shared by both passes.
struct FanVertex { float4 position; float4 normal; float4 color; float4 uv; float4 joints0; float4 joints1; float4 weights0; float4 weights1; };
struct FanMorphDelta { float4 position; float4 normal; };
struct FanMorphUniforms { uint4 selection; float4 weights[4]; float4 face; };
FanVertex morphFan(FanVertex v,uint id,const device FanMorphDelta* morphs,constant FanMorphUniforms& u) {
    if(v.uv.w>0.5) {
        float opening=clamp(u.weights[0].x*0.8+u.weights[0].y,0.0,1.8);
        if(v.uv.w>1.5) {
            v.position.y=0.45+(v.position.y-0.45)*0.70+0.065-0.07*opening;
            v.position.z-=0.025;
            v.normal.y/=0.70;v.normal.xyz=normalize(v.normal.xyz);
        }
        // Keep the rigid tooth rows inside narrowed lip expressions.
        float narrow=clamp(u.weights[2].z*0.5+u.weights[2].w*0.35,0.0,0.7);
        v.position.x*=1.0-narrow;
        v.normal.x/=1.0-narrow;v.normal.xyz=normalize(v.normal.xyz);
        return v;
    }
    for(uint i=0;i<u.selection.w;i++) {
        float weight=u.weights[i/4][i%4];
        if(weight==0)continue;
        FanMorphDelta d=morphs[i*u.selection.z+id];
        v.position+=d.position*weight;v.normal+=d.normal*weight;
    }
    if (u.selection.x!=0) {
        // Smooth upper-face remap, with the inverse Jacobian applied to normals.
        // Shared by eye/head meshes and color/shadow passes; crown and muzzle base stay fixed.
        float y=v.position.y;
        float lo=0.48,plateauStart=0.68,plateauEnd=0.90,hi=1.25;
        if (y>lo && y<hi) {
            float t=1.0,dt=0.0;
            if (y<plateauStart) { t=(y-lo)/(plateauStart-lo);dt=1.0/(plateauStart-lo); }
            else if (y>plateauEnd) { t=(hi-y)/(hi-plateauEnd);dt=-1.0/(hi-plateauEnd); }
            float lift=0.10*t*t*(3.0-2.0*t);
            float derivative=0.10*6.0*t*(1.0-t)*dt;
            v.position.y+=lift;
            v.normal.y/=1.0+derivative;
        }
    }
    v.normal.xyz=normalize(v.normal.xyz);return v;
}
Deformed deformFan(FanVertex v,const device Instance* bones) {
    Deformed d;d.world=float4(0);d.normal=float3(0);
    for(uint j=0;j<8;j++) {
        float weight=j<4 ? v.weights0[j] : v.weights1[j-4];
        if(weight<=0)continue;
        uint joint=uint(j<4 ? v.joints0[j] : v.joints1[j-4]);
        float4x4 m=bones[joint].model;
        d.world+=(m*v.position)*weight;
        d.normal+=transformNormal(m,v.normal.xyz)*weight;
    }
    d.normal=normalize(d.normal);return d;
}
vertex Varying fanVertexMain(const device FanVertex* vertices [[buffer(0)]],const device Instance* bones [[buffer(1)]],constant Uniforms& u [[buffer(2)]],const device FanMorphDelta* morphs [[buffer(3)]],constant FanMorphUniforms& mu [[buffer(4)]],uint id [[vertex_id]]) {
    FanVertex v=morphFan(vertices[id],id,morphs,mu);Deformed d=deformFan(v,bones);Varying out;
    out.position=u.projection*d.world;out.world=d.world.xyz;out.normal=d.normal;out.color=v.color;out.jaw=0;out.eyeUV=float3(v.uv.xy,v.uv.z>0.5 ? (vertices[id].position.x<0 ? 2.0:1.0) : 0.0);out.eyeHeight=(vertices[id].position.y-0.62501)/0.23836;return out;
}
vertex float4 fanShadowVertex(const device FanVertex* vertices [[buffer(0)]],const device Instance* bones [[buffer(1)]],constant Uniforms& u [[buffer(2)]],const device FanMorphDelta* morphs [[buffer(3)]],constant FanMorphUniforms& mu [[buffer(4)]],uint id [[vertex_id]]) {
    return u.light*deformFan(morphFan(vertices[id],id,morphs,mu),bones).world;
}

// Rigid polygon props share the character's lighting and the same shadow map.
struct PropVertex { float4 position; float4 normal; float4 uv; };
struct PropUniforms { float4x4 model; float4 color; float4 material; };
vertex Varying propVertex(const device PropVertex* vertices [[buffer(0)]],constant Uniforms& u [[buffer(2)]],constant PropUniforms& prop [[buffer(5)]],uint id [[vertex_id]]) {
    PropVertex v=vertices[id];float4 world=prop.model*v.position;Varying out;
    out.position=u.projection*world;out.world=world.xyz;out.normal=transformNormal(prop.model,v.normal.xyz);
    out.color=prop.color;out.jaw=0;out.eyeUV=float3(v.uv.xy,0);out.eyeHeight=0;return out;
}
vertex float4 propShadowVertex(const device PropVertex* vertices [[buffer(0)]],constant Uniforms& u [[buffer(2)]],constant PropUniforms& prop [[buffer(5)]],uint id [[vertex_id]]) {
    return u.light*prop.model*vertices[id].position;
}
fragment float4 propFragment(Varying in [[stage_in]],depth2d<float> shadow [[texture(0)]],texture2d<float> land [[texture(1)]],constant Uniforms& u [[buffer(2)]],constant FanEyeUniforms& eyes [[buffer(3)]],constant PropUniforms& prop [[buffer(5)]]) {
    constexpr sampler mapSampler(s_address::repeat,t_address::clamp_to_edge,filter::linear,mip_filter::linear);
    float mask=land.sample(mapSampler,in.eyeUV.xy).r;
    in.color.rgb=mix(float3(0.23,0.025,0.72),float3(0.02,0.92,0.13),mask);
    return shadeSurface(in,shadow,u,eyes);
}
