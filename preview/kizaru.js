// Light has a readable tell: an unhurried preparation followed by a sharp release.
// Kick: gather light in the right foot -> rush at light speed -> kick (target is blown away).
// Jewels: crouch -> leap high -> volley from the air -> fall back to the ground.
window.KizaruPreview=function(A){
 const {T,scene,camera,basePos}=A,V=(x=0,y=0,z=0)=>new T.Vector3(x,y,z),gold=0xffd54b,fx=[];
 const cfg={lightLaser:[.65,1.05,42,90],lightKick:[.3,1.1,65,30],lightJewels:[.5,2.9,12,80],lightMirror:[.45,.85,0,24]};
 const KICK={dash:.05,sweep:.1},AIR={rise:.45,hover:2.25,fall:.5,height:15,first:.95,gap:.085};
 const names={lightLaser:['指先の光','손끝 레이저'],lightKick:['光速の蹴り','빛의 속도로 차여본 적 있나?'],lightJewels:['八尺瓊勾玉','야사카니의 곡옥'],lightMirror:['八咫鏡','야타의 거울']};
 const ease=x=>{x=T.MathUtils.clamp(x,0,1);return x*x*(3-2*x);},clamp=T.MathUtils.clamp;let selected=false,blurred=false;
 const view=new T.Group();camera.add(view);
 const boot=new T.Mesh(new T.BoxGeometry(.26,.32,.62),new T.MeshStandardMaterial({color:0x29251c,roughness:.3,metalness:.3}));view.add(boot);
 const shin=new T.Mesh(new T.BoxGeometry(.24,.75,.25),new T.MeshStandardMaterial({color:0x303746}));shin.position.set(0,-.48,.18);boot.add(shin);
 function star(parent,size){const g=new T.Group();parent.add(g);for(let i=0;i<2;i++){const m=new T.Mesh(new T.PlaneGeometry(size,.025),new T.MeshBasicMaterial({color:gold,transparent:true,depthWrite:false,side:T.DoubleSide,blending:T.AdditiveBlending}));m.rotation.z=i*Math.PI/2;g.add(m);}const core=new T.Mesh(new T.SphereGeometry(.055,12,8),new T.MeshBasicMaterial({color:0xfffbe2}));g.add(core);return g;}
 const glint=star(view,.8),other=star(view,.65),footStar=star(boot,1.1);footStar.position.set(0,.05,-.32);
 const lamp=new T.PointLight(gold,0,5);view.add(lamp);boot.visible=glint.visible=other.visible=false;
 function dispose(o){o.removeFromParent();o.traverse(x=>{x.geometry?.dispose();x.material?.dispose();});}
 function effect(o,life,fn){fx.push({o,born:A.time,life,fn});}
 function line(a,b,width=.04,life=.3,color=gold){const d=b.clone().sub(a);if(d.length()<.001)return;const o=new T.Mesh(new T.CylinderGeometry(width,width,d.length(),8),new T.MeshBasicMaterial({color,transparent:true,depthWrite:false,blending:T.AdditiveBlending}));o.position.copy(a).addScaledVector(d,.5);o.quaternion.setFromUnitVectors(V(0,1,0),d.normalize());scene.add(o);effect(o,life,(m,u)=>{m.material.opacity=1-u;m.scale.x=m.scale.z=1+u;});}
 function boom(p,scale=1){A.burst(p,gold,18,7*scale);const o=new T.Mesh(new T.SphereGeometry(1,20,12),new T.MeshBasicMaterial({color:0xffe492,transparent:true,wireframe:true,depthWrite:false}));o.position.copy(p);scene.add(o);effect(o,.45,(m,u)=>{m.scale.setScalar((.3+u*2)*scale);m.material.opacity=(1-u)*.8;});}
 function ring(p,radius,life=.5){const o=new T.Mesh(new T.RingGeometry(.85,1,48),new T.MeshBasicMaterial({color:0xffe9a0,transparent:true,depthWrite:false,side:T.DoubleSide,blending:T.AdditiveBlending}));o.rotation.x=-Math.PI/2;o.position.set(p.x,.12,p.z);scene.add(o);effect(o,life,(m,u)=>{m.scale.setScalar(.4+radius*ease(u));m.material.opacity=(1-u)*.9;});}
 function tone(f,len,end,volume=.08){if(A.muted||!A.audio)return;const ac=A.audio,o=ac.createOscillator(),g=ac.createGain();o.type='sine';o.frequency.setValueAtTime(f,ac.currentTime);o.frequency.exponentialRampToValueAtTime(end,ac.currentTime+len);g.gain.setValueAtTime(volume,ac.currentTime);g.gain.exponentialRampToValueAtTime(.001,ac.currentTime+len);o.connect(g);g.connect(ac.destination);o.start();o.stop(ac.currentTime+len);o.onended=()=>{o.disconnect();g.disconnect();};}
 function limit(from,dir,range,margin=0){for(let d=.15;d<=range;d+=.15){const p=from.clone().addScaledVector(dir,d);if(A.obstacles.some(o=>p.y<o.h&&p.x>o.x0-margin&&p.x<o.x1+margin&&p.z>o.z0-margin&&p.z<o.z1+margin)||Math.hypot(p.x,p.z)>57)return Math.max(0,d-.3);}return range;}
 function beam(c,offset=V(),spread=V(),damage=cfg[c.type][2],base=c.direction){const from=basePos.clone().add(offset),dir=base.clone().add(spread).normalize(),range=cfg[c.type][3];let dist=limit(from,dir,range);if(dir.y<-.01)dist=Math.min(dist,Math.max(0,(from.y-.05)/-dir.y));const end=from.clone().addScaledVector(dir,dist);line(from,end,.055,.32);line(from,end,.018,.2,0xffffff);let impacted=false;
  for(const t of A.targets){if(t.hp<=0)continue;const p=t.g.position.clone().add(V(0,1.3,0)),delta=p.clone().sub(from),along=delta.dot(dir),width=c.type==='lightJewels'?1.25:.8;if(along>0&&along<dist&&(delta.addScaledVector(dir,-along)).length()<width&&!A.wallOnRay(from,p.clone().sub(from).normalize(),from.distanceTo(p))){A.hit(t,damage,'#ffe38c');boom(p,.5);impacted=true;}}
  if(dist<range)boom(end,.65);if(impacted&&c.type==='lightLaser')A.hitstop(55);tone(1600,.2,90,.12);return end;
 }
 // Jewels are fired from the air, so every shot is steered to the target nearest the committed aim (or angled down at the ground).
 function airAim(c,from){const flat=c.direction.clone().setY(0).normalize();let best=null,bestAngle=.62;for(const t of A.targets){if(t.hp<=0)continue;const p=t.g.position.clone().add(V(0,1.3,0)),d=p.clone().sub(from);if(d.length()>cfg.lightJewels[3])continue;const angle=Math.acos(clamp(d.setY(0).normalize().dot(flat),-1,1));if(angle<bestAngle){bestAngle=angle;best=p;}}return best?best.sub(from).normalize():flat.multiplyScalar(Math.cos(.49)).add(V(0,-Math.sin(.49),0));}
 function kickPlan(c){const dir=c.direction.clone().setY(0).normalize(),from=basePos.clone(),range=cfg.lightKick[3];let target=null,near=Infinity;
  for(const t of A.targets){if(t.hp<=0)continue;const d=t.g.position.clone().setY(from.y).sub(from),along=d.dot(dir);if(along<1||along>range||d.addScaledVector(dir,-along).length()>4.2)continue;if(along<near){near=along;target=t;}}
  const dist=limit(from,dir,target?Math.max(0,near-2.2):12,.6);return {dir,from,to:from.clone().addScaledVector(dir,dist),target};}
 function kickImpact(c){const {dir,target}=c.plan;let any=false;
  for(const t of A.targets){if(t.hp<=0)continue;const d=t.g.position.clone().setY(basePos.y).sub(basePos),along=d.dot(dir);if(t===target||(along>-.5&&along<3.6&&d.addScaledVector(dir,-along).length()<2.4)){A.hit(t,cfg.lightKick[2],'#ffe38c');A.launch(t,dir.clone().multiplyScalar(34).add(V(0,15,0)));boom(t.g.position.clone().add(V(0,1.3,0)),1.7);any=true;}}
  boom(basePos.clone().addScaledVector(dir,1.7).setY(1.2),any?1.2:.6);ring(basePos,any?7:4,.5);tone(170,.32,48,.22);tone(2400,.12,300,.1);A.flash('#fff2bd',A.comfort?.12:.4);if(any)A.hitstop(95);}
 function begin(c){c.kizaru=true;c.windup=cfg[c.type][0];c.duration=cfg[c.type][1];c.shots=0;c.origin=basePos.clone();const n=names[c.type];
  A.title(n[0],n[1],c.type==='lightKick'?'오른발에 빛을 모은다 → 광속 돌진 → 걷어차기':c.type==='lightJewels'?'웅크렸다 → 높이 도약 → 공중에서 탄막 → 낙하':'빛이 모이는 동안 이동이 느려집니다','#ffe38c');tone(380,c.windup,1800,.045);}
 function kick(c,a){const W=cfg.lightKick[0],D=KICK.dash,S=KICK.sweep,wind=ease(a/W),dash=ease((a-W)/D),sweep=ease((a-W-D)/S),back=ease((a-W-D-.2)/(c.duration-W-D-.2));
  glint.visible=false;boot.visible=true;lamp.position.set(.3,-.8,-1.2);lamp.intensity=3*wind*(1-back);
  if(a>=W&&!c.plan){const p=c.plan=kickPlan(c);line(p.from.clone().setY(1.3),p.to.clone().setY(1.3),.26,.4);line(p.from.clone().setY(1.3),p.to.clone().setY(1.3),.08,.28,0xffffff);boom(p.from.clone().setY(1.3),.8);A.flash('#fff4c4',A.comfort?.1:.24);tone(260,.16,3400,.14);}
  if(c.plan){basePos.lerpVectors(c.plan.from,c.plan.to,dash);camera.position.copy(basePos);if(a>=W+D+.03&&!c.kicked){c.kicked=true;kickImpact(c);}}
  boot.position.set(.58-1.15*sweep,-1.1+.95*wind-.9*back,-.65-.6*wind);boot.rotation.set(-.5*wind,.7-1.7*sweep,-.25+.65*wind-1.35*sweep);footStar.scale.setScalar(.3+wind+2*dash*(1-sweep));
  A.pose(A.right,[.65,-.28,-.65],[.2,.2,.55]);A.pose(A.left,[-.48,-.45,-.85],[.1,.2,-.4]);
  const rush=Math.sin(Math.PI*clamp((a-W)/(D+.15),0,1)),m=A.comfort?.3:1;
  camera.rotation.z+=(.065*wind-.15*sweep)*(1-back)*m;camera.rotation.y+=(.04*wind-.09*sweep)*(1-back)*m;camera.fov=66-5*wind*(1-dash)+(A.comfort?10:30)*rush+8*Math.sin(Math.PI*clamp((a-W-D)/.3,0,1));
  if(!A.comfort){document.getElementById('scene').style.filter=rush>.02?`blur(${(rush*6).toFixed(1)}px)`:'';blurred=true;}
  if(a>W+D&&a<W+D+.15){const p=boot.getWorldPosition(V());if(c.trail)line(c.trail,p,.07,.25);c.trail=p;}
 }
 function jewels(c,a){const W=cfg.lightJewels[0],up=clamp((a-W)/AIR.rise,0,1),rise=1-(1-up)*(1-up),dn=clamp((a-AIR.hover)/AIR.fall,0,1),fall=dn*dn,h=AIR.height*rise*(1-fall),k=ease(a/W)*(1-fall),crouch=ease(a/W)*(1-ease((a-W)/.08));
  glint.visible=true;boot.visible=false;
  if(a>=W&&!c.rose){c.rose=true;c.ground=basePos.clone().setY(0);ring(c.ground,6,.6);boom(c.ground.clone().setY(.8),1.1);line(c.ground,c.ground.clone().setY(AIR.height+2.1),.22,.5);A.flash('#fff4c4',A.comfort?.1:.22);tone(220,.45,1900,.14);}
  basePos.y=2.1+h;camera.position.copy(basePos);camera.position.y-=.4*crouch;
  if(a>=AIR.hover+AIR.fall&&!c.landed){c.landed=true;basePos.y=2.1;camera.position.y=2.1;const at=basePos.clone().setY(0);ring(at,10,.6);boom(at.clone().setY(.6),1.3);A.flash('#fff2bd',A.comfort?.12:.3);A.hitstop(55);tone(130,.3,40,.2);}
  lamp.position.set(0,0,-.9);lamp.intensity=3*k;glint.position.set(.36,.12,-.88);glint.scale.setScalar(.25+k*.8);glint.rotation.z=a*.5;other.visible=true;other.position.set(-.36,.12,-.88);other.scale.copy(glint.scale);
  A.pose(A.left,[-.36,-.1+.16*k,-.86],[.1,0,-.65]);A.pose(A.right,[.36,-.1+.16*k,-.86],[.1,0,.65]);
  camera.fov=66-7*k+12*Math.sin(Math.PI*up)+8*Math.sin(Math.PI*dn);camera.rotation.x-=.24*rise*(1-fall)*(A.comfort?.4:1);
  while(c.shots<12&&a>=AIR.first+c.shots*AIR.gap){const i=c.shots++,off=V(i%2?.38:-.38,.25,0);beam(c,off,V(Math.sin(i*2.4)*.055,Math.cos(i*2.4)*.035,0),cfg.lightJewels[2],airAim(c,basePos.clone().add(off)));}
 }
 function update(c,a){
  if(c.type==='lightKick')return kick(c,a);
  if(c.type==='lightJewels')return jewels(c,a);
  const wind=ease(a/c.windup),release=ease((a-c.windup)/.12),back=ease((a-c.windup-.18)/(c.duration-c.windup-.18)),k=wind*(1-back);
  glint.visible=true;other.visible=false;boot.visible=false;lamp.intensity=3*k;lamp.position.copy(glint.position);glint.scale.setScalar(.25+wind*.8);glint.rotation.z=a*.5;
  A.pose(A.right,[.28,-.3+.32*k,-.9-.22*k],[-.35*k,0,.12]);glint.position.set(.28,.18*k,-1.15-.22*k);if(c.type==='lightMirror'){A.pose(A.left,[-.24,-.22,-1],[.2,0,-.3]);camera.fov=66+25*release*(1-back);}
  if(a>=c.windup&&!c.fired){c.fired=true;if(c.type==='lightMirror'){const dir=c.direction.clone().setY(0).normalize(),dist=limit(basePos,dir,24,.7),end=basePos.clone().addScaledVector(dir,dist);for(let i=0;i<8;i++){const p=basePos.clone().lerp(end,i/8);boom(p,.25);}line(basePos,end,.16,.5);basePos.copy(end);tone(900,.25,2200,.08);}else{beam(c);A.flash('#fff2bd',A.comfort?.08:.22);}}
 }
 function frame(){for(let i=fx.length-1;i>=0;i--){const f=fx[i],u=(A.time-f.born)/f.life;if(u>=1){dispose(f.o);fx.splice(i,1);}else f.fn(f.o,u);}if(!selected||!A.cast?.kizaru){boot.visible=glint.visible=other.visible=false;lamp.intensity=0;if(blurred){document.getElementById('scene').style.filter='';blurred=false;}}view.visible=selected;}
 function reset(){for(const f of fx)dispose(f.o);fx.length=0;boot.visible=glint.visible=other.visible=false;lamp.intensity=0;}
 return {skills:new Set(Object.keys(cfg)),begin,update,frame,reset,activate:v=>{selected=v;reset();},hud:()=>{},state:()=>({active:selected,boot:boot.visible,effects:fx.length,shots:A.cast?.shots??0,y:+basePos.y.toFixed(2),kicked:!!A.cast?.kicked,plan:A.cast?.plan?{to:A.cast.plan.to.toArray().map(v=>+v.toFixed(1)),target:!!A.cast.plan.target}:null})};
};
