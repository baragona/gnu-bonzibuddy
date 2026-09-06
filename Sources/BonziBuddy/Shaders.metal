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
float4 shadeSurface(Varying in,depth2d<float> shadow,constant Uniforms& u,constant FanEyeUniforms& eyes,float sheenScale,float minimumSheen) {
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
        // Character-calibrated per-eye horizontal offsets for head counter-motion.
        pupilUV.x-=(in.eyeUV.z>1.5 ? eyes.closures.w:eyes.closures.z)*0.20;
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
    float sheen = max(minimumSheen,smoothstep(0.42,0.65,max(surfaceColor.r,max(surfaceColor.g,surfaceColor.b))));
    float3 color = surfaceColor.rgb * (0.36 + 0.60*diffuse*shade + 0.12*fill) + 0.16*spec*shade*sheen*sheenScale;
    color=mix(color,float3(0.98,0.98,1.0),eyeCatchlight*0.94);
    return float4(color * in.color.a, in.color.a);
}
fragment float4 fragmentMain(Varying in [[stage_in]],depth2d<float> shadow [[texture(0)]],constant Uniforms& u [[buffer(2)]],constant FanEyeUniforms& eyes [[buffer(3)]]) {
    return shadeSurface(in,shadow,u,eyes,1.0,0.0);
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
struct PropVertex { float4 position; float4 normal; float4 uv; float4 openedPosition; float4 openedNormal; };
struct PropUniforms { float4x4 model; float4 color; float4 material; float4 deformation; };
float3 bananaFruitPosition(float u,float v,float cap,float remaining) {
    float t=cap>1.5 ? 0.0:cap>0.5 ? remaining:v*remaining;
    float angle=u*2.0*M_PI_F;
    float3 radial=normalize(float3(1,-0.44*t,0))*cos(angle)+float3(0,0,sin(angle));
    float radius=0.105*pow(max(0.0,sin(M_PI_F*t)),0.35)+0.01;
    return float3(0.22*t*t,t,0)+radial*radius*(1.0+0.035*cos(5.0*angle))*(cap>0.5 ? v:1.0);
}
PropVertex deformProp(PropVertex v,constant PropUniforms& prop) {
    if (prop.material.y==1.0) {
        float amount=prop.deformation[min(uint(v.uv.z),2u)];
        v.position=mix(v.position,v.openedPosition,amount);
        v.normal=float4(normalize(mix(v.normal.xyz,v.openedNormal.xyz,amount)),0);
    } else if (prop.material.y==2.0) {
        float remaining=max(0.001,prop.deformation.w);
        v.position=float4(bananaFruitPosition(v.uv.x,v.uv.y,v.uv.z,remaining),1);
        if(v.uv.z>0.5) {
            v.normal=float4(v.uv.z>1.5 ? float3(0,-1,0):normalize(float3(0.44*remaining,1,0)),0);
        } else {
            float3 du=bananaFruitPosition(v.uv.x+0.0001,v.uv.y,0,remaining)-bananaFruitPosition(v.uv.x-0.0001,v.uv.y,0,remaining);
            float3 dv=bananaFruitPosition(v.uv.x,min(1.0,v.uv.y+0.0001),0,remaining)-bananaFruitPosition(v.uv.x,max(0.0,v.uv.y-0.0001),0,remaining);
            v.normal=float4(normalize(cross(dv,du)),0);
        }
    }
    if (prop.material.y==3.0) {
        v.position=mix(v.position,v.openedPosition,prop.deformation.x);
        v.normal=float4(normalize(mix(v.normal.xyz,v.openedNormal.xyz,prop.deformation.x)),0);
    }
    return v;
}
struct PropVarying {float4 position [[position]];float3 world;float3 normal;float4 color;float4 uv;};
vertex PropVarying propVertex(const device PropVertex* vertices [[buffer(0)]],constant Uniforms& u [[buffer(2)]],constant PropUniforms& prop [[buffer(5)]],uint id [[vertex_id]]) {
    PropVertex v=deformProp(vertices[id],prop);float4 world=prop.model*v.position;PropVarying out;
    out.position=u.projection*world;out.world=world.xyz;out.normal=transformNormal(prop.model,v.normal.xyz);
    out.color=prop.color;out.uv=v.uv;return out;
}
vertex float4 propShadowVertex(const device PropVertex* vertices [[buffer(0)]],constant Uniforms& u [[buffer(2)]],constant PropUniforms& prop [[buffer(5)]],uint id [[vertex_id]]) {
    return u.light*prop.model*deformProp(vertices[id],prop).position;
}
fragment float4 propFragment(PropVarying vertexIn [[stage_in]],depth2d<float> shadow [[texture(0)]],texture2d<float> land [[texture(1)]],constant Uniforms& u [[buffer(2)]],constant FanEyeUniforms& eyes [[buffer(3)]],constant PropUniforms& prop [[buffer(5)]]) {
    // Props share lighting, never anatomical pupil/eyelid or mouth shading.
    Varying in;in.position=vertexIn.position;in.world=vertexIn.world;in.normal=vertexIn.normal;
    in.color=vertexIn.color;in.jaw=0;in.eyeUV=float3(vertexIn.uv.xy,0);in.eyeHeight=vertexIn.uv.w;
    constexpr sampler mapSampler(s_address::repeat,t_address::clamp_to_edge,filter::linear,mip_filter::linear);
    if (prop.material.x==0.0) {
        float mask=land.sample(mapSampler,in.eyeUV.xy).r;
        in.color.rgb=mix(float3(0.23,0.025,0.72),float3(0.02,0.92,0.13),mask);
    } else if (prop.material.x==1.0 || prop.material.x==5.0) {
        float2 uv=in.eyeUV.xy;
        float gx=uv.x*603.0+sin(uv.y*123.0)*2.0,gy=uv.y*347.0+sin(uv.x*79.0);
        float grain=sin(gx)*sin(gy)*exp(-0.35*(fwidth(gx)+fwidth(gy)));
        float strand=uv.x*1301.0+sin(uv.y*31.0)*5.0;
        float fiber=pow(0.5+0.5*sin(strand),8.0)*exp(-0.35*fwidth(strand));
        float coarse=sin(uv.x*187.0+sin(uv.y*49.0)*3.0)*sin(uv.y*149.0+cos(uv.x*35.0));
        float detail=clamp(0.5+coarse*0.23+grain*0.25+fiber*0.20,0.0,1.0);
        in.color.rgb=mix(float3(0.50,0.235,0.045),float3(0.93,0.64,0.22),detail);
        float pores=0;
        for (int i=0;i<3;i++) {
            float2 center=float2(0.48+0.025*cos(float(i)*2.094),0.20+0.04*sin(float(i)*2.094));
            float d=length((uv-center)/float2(0.012,0.019));
            pores=max(pores,1.0-smoothstep(0.7,1.1,d));
        }
        in.color.rgb*=1.0-pores*0.7;
    }
    if (prop.material.x==2.0) {
        float fiber=sin(in.eyeUV.x*83.0+sin(in.eyeUV.y*27.0))*0.015;
        in.color.rgb=float3(0.98,0.91,0.66)+fiber;
    } else if (prop.material.x==3.0) {
        float t=in.eyeUV.y;
        float stripe=pow(abs(cos(in.eyeUV.x*M_PI_F)),12.0);
        float tip=smoothstep(0.91,0.99,t)+(1.0-smoothstep(0.01,0.07,t));
        float3 yellow=mix(float3(1.0,0.83,0.018),float3(0.70,0.50,0.025),stripe*0.3);
        float3 shell=mix(yellow,float3(0.30,0.15,0.018),clamp(tip,0.0,1.0));
        in.color.rgb=mix(shell,float3(0.98,0.91,0.62),in.eyeHeight*0.92);
    }
    if (prop.material.x==4.0) {
        in.color.rgb=mix(float3(0.035,0.025,0.045),float3(0.008,0.016,0.021),in.eyeHeight);
    }
    if (prop.material.x==5.0) {
        if (in.eyeHeight>2.5) in.color.rgb=float3(0.32,0.33,0.35);
        else if (in.eyeHeight>1.5) in.color.rgb=float3(0.94,0.88,0.66);
        else if (in.eyeHeight>0.5) in.color.rgb=float3(0.025,0.023,0.030);
    }
    if (prop.material.x==6.0) {
        float2 uv=in.eyeUV.xy;
        float edge=smoothstep(0.78,0.98,vertexIn.uv.z);
        float spot=1.0-smoothstep(0.11,0.15,length((uv-float2(0.63,0.70))*float2(0.8,1.0)));
        float lower=1.0-smoothstep(0.10,0.14,length(uv-float2(0.38,0.20)));
        in.color.rgb=mix(float3(1.0,0.88,0.08),float3(0.97,0.46,0.025),edge);
        in.color.rgb=mix(in.color.rgb,float3(0.49,0.46,0.08),max(spot,lower));
    } else if (prop.material.x==7.0) in.color.rgb=float3(0.37,0.35,0.06);
    if (prop.material.x>=8.0 && prop.material.x<=10.0) {
        float2 uv=vertexIn.uv.xy;
        bool paper=vertexIn.uv.w>0.5;
        in.color.rgb=paper ? float3(0.97,0.94,0.82):float3(0.46,0.255,0.055);
        if (!paper && vertexIn.uv.z>0.5) {
            float border=(1.0-smoothstep(0.025,0.035,min(min(uv.x,1.0-uv.x),min(uv.y,1.0-uv.y))));
            in.color.rgb=mix(in.color.rgb,float3(0.78,0.57,0.12),border);
            if (prop.material.x==9.0) {
                float2 p=(uv-float2(0.57,0.60))*3.1;
                float r=dot(p,p);
                if (r<1.0) {
                    float z=sqrt(1.0-r);
                    float2 mapUV=float2(atan2(p.x,z)/(2.0*M_PI_F)+0.5,0.5-asin(p.y)/M_PI_F);
                    float mask=land.sample(mapSampler,mapUV).r;
                    in.color.rgb=mix(float3(0.23,0.025,0.72),float3(0.02,0.80,0.13),mask)*(0.65+0.35*z);
                }
            } else {
                float line=1.0-smoothstep(0.012,0.022,abs(uv.y-(0.50+0.08*sin(uv.x*9.0))));
                in.color.rgb=mix(in.color.rgb,float3(0.80,0.60,0.13),line*step(0.15,uv.x)*step(uv.x,0.85));
            }
        }
        if (paper && vertexIn.uv.z< -0.5) {
            float line=1.0-smoothstep(0.06,0.12,abs(fract(uv.y*16.0)-0.5));
            in.color.rgb*=1.0-0.35*line*step(0.12,uv.x)*step(uv.x,0.88)*step(0.12,uv.y)*step(uv.y,0.88);
        }
    }
    if (prop.material.x==11.0 || prop.material.x==12.0) {
        int region=int(vertexIn.uv.w+0.5);
        const float3 colors[7]={float3(0.55,0.32,0.09),float3(0.98,0.97,0.86),float3(0.98,0.68,0.025),float3(0.72,0.55,0.18),float3(0.08),float3(0.79,0.58,0.32),float3(0.82,0.28,0.22)};
        in.color.rgb=colors[clamp(region,0,6)];
        if (prop.material.x==11.0 && region==0 && vertexIn.uv.z< -0.5) {
            float2 p=(vertexIn.uv.xy-float2(0.5))*2.7;
            float r=dot(p,p);
            if (r<1.0) {
                float z=sqrt(1.0-r);
                float2 mapUV=float2(atan2(p.x,z)/(2.0*M_PI_F)+0.5,0.5-asin(p.y)/M_PI_F);
                float mask=land.sample(mapSampler,mapUV).r;
                in.color.rgb=mix(float3(0.23,0.025,0.72),float3(0.02,0.80,0.13),mask)*(0.65+0.35*z);
            }
        }
    }
    if (prop.material.x==13.0 || prop.material.x==14.0) {
        float region=vertexIn.uv.w;
        float grain=0.025*sin(vertexIn.uv.x*180.0);
        in.color.rgb=region>2.5 ? float3(0.20,0.48,0.08):region>1.5 ? float3(0.88,0.66,0.24):region>0.5 ? float3(0.43,0.29,0.09):float3(0.90,0.68,0.26)+grain;
    }
    if (prop.material.x==15.0 || prop.material.x==16.0) {
        float2 uv=vertexIn.uv.xy;
        in.color.rgb=float3(0.985,0.985,1.0);
        if (vertexIn.uv.z>0.5) {
            float line=1.0-smoothstep(0.07,0.14,abs(fract(uv.y*22.0)-0.5));
            float margin=step(0.13,uv.x)*step(uv.x,0.87)*step(0.17,uv.y)*step(uv.y,0.84);
            in.color.rgb*=1.0-0.10*line*margin;
        }
    }
    float sheen=prop.material.x==4.0 ? 1.0:prop.material.x<0.5 ? 1.0:prop.material.x<1.5 ? 0.15:0.4;
    float4 shaded=shadeSurface(in,shadow,u,eyes,sheen,prop.material.z);
    if (prop.material.x==15.0 || prop.material.x==16.0) {
        shaded.rgb=mix(shaded.rgb,in.color.rgb*shaded.a,0.40);
    }
    if (prop.material.x==4.0) {
        // A broad studio-light reflection gives the original's gray lens bands.
        // It follows the surface normal as the head turns, independent of the clip.
        float band=pow(max(0.0,dot(normalize(in.normal),normalize(float3(-0.15,0.10,1.5)))),5.0);
        shaded.rgb+=float3(0.40,0.41,0.42)*band*in.eyeHeight*in.color.a;
    }
    return shaded;
}

// Offline audit readback uses the same deformation functions as rendering.
kernel void auditFanPositions(const device FanVertex* vertices [[buffer(0)]],const device Instance* bones [[buffer(1)]],const device FanMorphDelta* morphs [[buffer(3)]],constant FanMorphUniforms& mu [[buffer(4)]],device float4* output [[buffer(6)]],uint id [[thread_position_in_grid]]) {
    if(id<mu.selection.z) output[id]=deformFan(morphFan(vertices[id],id,morphs,mu),bones).world;
}
kernel void auditPropPositions(const device PropVertex* vertices [[buffer(0)]],constant PropUniforms& prop [[buffer(5)]],device float4* output [[buffer(6)]],constant uint& count [[buffer(7)]],uint id [[thread_position_in_grid]]) {
    if(id<count) output[id]=prop.model*deformProp(vertices[id],prop).position;
}
