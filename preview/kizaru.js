// Light has a readable tell: an unhurried preparation followed by a sharp release.
window.KizaruPreview=function(A){
 const {T,scene,camera,basePos}=A,V=(x=0,y=0,z=0)=>new T.Vector3(x,y,z),gold=0xffd54b,fx=[];
 const cfg={lightLaser:[.65,1.05,42,90],lightKick:[.85,1.4,65,12],lightJewels:[1.25,2.8,12,80],lightMirror:[.45,.85,0,24]};
 const names={lightLaser:['指先の光','손끝 레이저'],lightKick:['光速の蹴り','빛의 속도로 차여본 적 있나?'],lightJewels:['八尺瓊勾玉','야사카니의 곡옥'],lightMirror:['八咫鏡','야타의 거울']};
 const ease=x=>{x=T.MathUtils.clamp(x,0,1);return x*x*(3-2*x);};let selected=false;
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
 function tone(f,len,end,volume=.08){if(A.muted||!A.audio)return;const ac=A.audio,o=ac.createOscillator(),g=ac.createGain();o.type='sine';o.frequency.setValueAtTime(f,ac.currentTime);o.frequency.exponentialRampToValueAtTime(end,ac.currentTime+len);g.gain.setValueAtTime(volume,ac.currentTime);g.gain.exponentialRampToValueAtTime(.001,ac.currentTime+len);o.connect(g);g.connect(ac.destination);o.start();o.stop(ac.currentTime+len);o.onended=()=>{o.disconnect();g.disconnect();};}
 function limit(from,dir,range,margin=0){for(let d=.15;d<=range;d+=.15){const p=from.clone().addScaledVector(dir,d);if(A.obstacles.some(o=>p.y<o.h&&p.x>o.x0-margin&&p.x<o.x1+margin&&p.z>o.z0-margin&&p.z<o.z1+margin)||Math.hypot(p.x,p.z)>57)return Math.max(0,d-.3);}return range;}
 function beam(c,offset=V(),spread=V(),damage=cfg[c.type][2]){const from=basePos.clone().add(offset),dir=c.direction.clone().add(spread).normalize(),range=cfg[c.type][3],dist=limit(from,dir,range),end=from.clone().addScaledVector(dir,dist);line(from,end,c.type==='lightKick'?.17:.055,.32);line(from,end,.018,.2,0xffffff);let impacted=false;
  for(const t of A.targets){if(t.hp<=0)continue;const p=t.g.position.clone().add(V(0,1.3,0)),delta=p.clone().sub(from),along=delta.dot(dir),width=c.type==='lightKick'?2.4:c.type==='lightJewels'?1.25:.8;if(along>0&&along<dist&&(delta.addScaledVector(dir,-along)).length()<width&&!A.wallOnRay(from,p.clone().sub(from).normalize(),from.distanceTo(p))){A.hit(t,damage,'#ffe38c');boom(p,c.type==='lightKick'?1.5:.5);if(c.type==='lightKick')A.launch(t,dir.clone().multiplyScalar(22).add(V(0,7,0)));impacted=true;}}
  if(dist<range)boom(end,.65);if(impacted&&c.type!=='lightJewels')A.hitstop(55);tone(1600,.2,90,.12);return end;
 }
 function begin(c){c.kizaru=true;c.windup=cfg[c.type][0];c.duration=cfg[c.type][1];c.shots=0;c.origin=basePos.clone();const n=names[c.type];A.title(n[0],n[1],c.type==='lightKick'?'오른발을 들어 빛을 모은다 → 오른쪽에서 왼쪽으로':'빛이 모이는 동안 이동이 느려집니다','#ffe38c');tone(380,c.windup,1800,.045);}
 function update(c,a){const wind=ease(a/c.windup),release=ease((a-c.windup)/.12),back=ease((a-c.windup-.18)/(c.duration-c.windup-.18)),k=wind*(1-back);
  glint.visible=true;other.visible=false;boot.visible=c.type==='lightKick';lamp.intensity=3*k;lamp.position.copy(glint.position);glint.scale.setScalar(.25+wind*.8);glint.rotation.z=a*.5;
  if(c.type==='lightKick'){
   const sweep=ease((a-.85)/.12);boot.position.set(.58-1.15*sweep,-1.1+.95*wind-.9*back,-.65-.6*wind);boot.rotation.set(-.5*wind,.7-1.7*sweep,-.25+.65*wind-1.35*sweep);footStar.scale.setScalar(.3+wind);glint.visible=false;
   A.pose(A.right,[.65,-.28,-.65],[.2,.2,.55]);A.pose(A.left,[-.48,-.45,-.85],[.1,.2,-.4]);camera.rotation.z+=(.065*wind-.15*release)*(1-back)*(A.comfort?.3:1);camera.rotation.y+=(.04*wind-.09*release)*(1-back);camera.fov=66-5*wind+17*release*(1-back);
   if(a>.85&&a<1.03){const p=boot.getWorldPosition(V());if(c.trail)line(c.trail,p,.07,.25);c.trail=p;}
  }else if(c.type==='lightJewels'){
   A.pose(A.left,[-.36,-.1+.16*k,-.86],[.1,0,-.65]);A.pose(A.right,[.36,-.1+.16*k,-.86],[.1,0,.65]);glint.position.set(.36,.12,-.88);other.visible=true;other.position.set(-.36,.12,-.88);other.scale.copy(glint.scale);camera.fov=66-7*k;camera.position.y+=.12*k;
  }else{A.pose(A.right,[.28,-.3+.32*k,-.9-.22*k],[-.35*k,0,.12]);glint.position.set(.28,.18*k,-1.15-.22*k);if(c.type==='lightMirror'){A.pose(A.left,[-.24,-.22,-1],[.2,0,-.3]);camera.fov=66+25*release*(1-back);}}
  if(c.type==='lightJewels'){while(c.shots<12&&a>=1.25+c.shots*.085){const i=c.shots++;beam(c,V(i%2?.38:-.38,.25,0),V(Math.sin(i*2.4)*.055,Math.cos(i*2.4)*.035,0));}}
  else if(a>=c.windup&&!c.fired){c.fired=true;if(c.type==='lightMirror'){const dir=c.direction.clone().setY(0).normalize(),dist=limit(basePos,dir,24,.7),end=basePos.clone().addScaledVector(dir,dist);for(let i=0;i<8;i++){const p=basePos.clone().lerp(end,i/8);boom(p,.25);}line(basePos,end,.16,.5);basePos.copy(end);tone(900,.25,2200,.08);}else{beam(c);A.flash('#fff2bd',A.comfort?.08:.22);}}
 }
 function frame(){for(let i=fx.length-1;i>=0;i--){const f=fx[i],u=(A.time-f.born)/f.life;if(u>=1){dispose(f.o);fx.splice(i,1);}else f.fn(f.o,u);}if(!selected||!A.cast?.kizaru){boot.visible=glint.visible=other.visible=false;lamp.intensity=0;}view.visible=selected;}
 function reset(){for(const f of fx)dispose(f.o);fx.length=0;boot.visible=glint.visible=other.visible=false;lamp.intensity=0;}
 return {skills:new Set(Object.keys(cfg)),begin,update,frame,reset,activate:v=>{selected=v;reset();},hud:()=>{},state:()=>({active:selected,boot:boot.visible,effects:fx.length,shots:A.cast?.shots??0})};
};
