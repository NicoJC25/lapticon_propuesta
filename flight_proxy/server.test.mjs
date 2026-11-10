import test from 'node:test';
import assert from 'node:assert/strict';
import {createHandler, normalizeFlights} from './server.mjs';
const origin = {iata:'BOG', city:'Bogotá', country:'CO'};
const destination = {iata:'MAD', city:'Madrid', country:'ES'};
const date = new Date(Date.now()+86400000).toISOString().slice(0,10);
const flight = {number:'AV 40', airline:{name:'Avianca'},
  departure:{scheduledTime:{local:`${date}T08:00:00`}}, arrival:{airport:{iata:'MAD'}}};
const token = `a.${Buffer.from(JSON.stringify({sub:'test-uid'})).toString('base64url')}.c`;
function response(status,body) { return {status,ok:status===200,json:async()=>body}; }
async function invoke(handler, {authorization=`Bearer ${token}`, query=`origin=BOG&destination=MAD&date=${date}`}={}) {
  let status,body;
  await handler({method:'GET',url:`/api/flights/search?${query}`,headers:{authorization}},
    {writeHead(s){status=s;},end(s){body=JSON.parse(s);}});
  return {status,body};
}
test('Filtra la ruta, cancela vuelos y elimina duplicados',()=>{
  assert.equal(normalizeFlights({departures:[flight,flight,
    {...flight,number:'AV41',arrival:{airport:{iata:'MIA'}}},
    {...flight,number:'AV42',status:'Canceled'},
    {...flight,number:'AV43',departure:{scheduledTime:{local:'2020-01-01T00:00'}}}
  ]},origin,destination,date).length,1);
});
test('Formato desconocido no produce vuelos inventados',()=>{
  assert.throws(()=>normalizeFlights({ok:true},origin,destination,date));
});
test('No hace consultas al proveedor si el backend rechaza la sesión',async()=>{
  let calls=0;
  const h=createHandler({key:'secret',fetcher:async()=>{calls++;return response(401,{});}});
  assert.equal((await invoke(h)).status,401);assert.equal(calls,1);
});
test('Clave ausente muestra error de configuración sin exponer secretos',async()=>{
  const h=createHandler({key:'',fetcher:async()=>response(200,{user:{uid:'test-uid'}})});
  assert.equal((await invoke(h)).status,503);
});
test('Consulta proveedor, comprueba ruta y cachea sin saltar autenticación',async()=>{
  let providerCalls=0,authCalls=0;
  const h=createHandler({key:'secret',fetcher:async(url,options)=>{
    if(url.pathname==='/api/ciudades/ciudades') return response(200,['Bogotá','Madrid']);
    if(url.hostname==='lapticon-backend.onrender.com') {authCalls++;return response(200,{user:{uid:'test-uid'}});}
    providerCalls++;assert.equal(options.headers['X-RapidAPI-Key'],'secret');
    if(url.pathname==='/airports/iata/BOG') return response(200,{iata:'BOG',municipalityName:'Bogotá',countryCode:'CO'});
    if(url.pathname==='/airports/iata/MAD') return response(200,{iata:'MAD',municipalityName:'Madrid',countryCode:'ES'});
    assert.equal(url.searchParams.get('withLeg'),'true');
    return response(200,{departures:[flight]});
  }});
  const r=await invoke(h);assert.equal(r.status,200);assert.equal(r.body[0].number,'AV40');
  assert.equal(r.body.length,1);assert.equal(providerCalls,4);
  await invoke(h);assert.equal(providerCalls,4);assert.equal(authCalls,2);
});
test('Rechaza ruta igual y fechas inexistentes antes de llamar al proveedor',async()=>{
  const h=createHandler({key:'secret',fetcher:async()=>response(200,{user:{uid:'test-uid'}})});
  assert.equal((await invoke(h,{query:`origin=BOG&destination=BOG&date=${date}`})).status,400);
  assert.equal((await invoke(h,{query:'origin=BOG&destination=MAD&date=2026-02-31'})).status,400);
});
test('Busca aeropuertos por ciudad y solo devuelve códigos IATA utilizables',async()=>{
  const h=createHandler({key:'secret',fetcher:async(url)=>{
    if(url.hostname==='lapticon-backend.onrender.com') return response(200,{user:{uid:'test-uid'}});
    assert.equal(url.pathname,'/airports/search/term');
    return response(200,{items:[{iata:'BOG',name:'El Dorado',municipalityName:'Bogotá'},{name:'Sin código'}]});
  }});
  let status,body;
  await h({method:'GET',url:'/api/flights/airports?q=Bogota',headers:{authorization:`Bearer ${token}`}},
      {writeHead(s){status=s;},end(s){body=JSON.parse(s);}});
  assert.equal(status,200);assert.equal(body.length,1);assert.equal(body[0].iata,'BOG');
});
