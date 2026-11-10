import http from 'node:http';
import {pathToFileURL} from 'node:url';

class HttpError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
export function normalizeFlights(data, origin, destination, date) {
  if (!Array.isArray(data?.departures)) throw new HttpError(502, 'Respuesta del proveedor de vuelos inválida.');
  const flights = new Map();
  for (const f of data.departures) {
    const departure = f.departure?.scheduledTime?.local;
    const number = f.number?.replace(/\s/g, '').toUpperCase();
    if (!number || !/^[A-Z0-9]{2}\d{1,4}[A-Z]?$/.test(number) ||
        f.status?.toLowerCase() === 'canceled' || f.status?.toLowerCase() === 'cancelled' ||
        f.arrival?.airport?.iata !== destination.iata ||
        (f.departure?.airport?.iata && f.departure.airport.iata !== origin.iata) ||
        !departure?.startsWith(date) || Number.isNaN(Date.parse(departure))) continue;
    flights.set(`${number}:${departure}`, {number, departure,
      airline: f.airline?.name ?? '', origin, destination});
  }
  return [...flights.values()].sort((a,b) => a.departure.localeCompare(b.departure));
}

export function createHandler({key = process.env.RAPIDAPI_KEY,
    authBase = process.env.AUTH_API_BASE_URL || 'https://lapticon-backend.onrender.com',
    fetcher = fetch} = {}) {
  const authOrigin = new URL(authBase);
  if (authOrigin.protocol !== 'https:' || authOrigin.username || authOrigin.password ||
      authOrigin.pathname !== '/' || authOrigin.search || authOrigin.hash) throw new Error('AUTH_API_BASE_URL inválida');
  const cache = new Map(), limits = new Map();
  const json = (res,status,value) => { res.writeHead(status, {'Content-Type':'application/json; charset=utf-8', 'Cache-Control':'no-store'}); res.end(JSON.stringify(value)); };
  async function provider(path, query = {}) {
    if (!key) throw new HttpError(503, 'Falta configurar RAPIDAPI_KEY en el servidor de vuelos.');
    const url = new URL(path, 'https://aerodatabox.p.rapidapi.com');
    url.search = new URLSearchParams(query).toString();
    const r = await fetcher(url, {headers: {'X-RapidAPI-Key':key,
      'X-RapidAPI-Host':'aerodatabox.p.rapidapi.com'}, redirect:'error', signal:AbortSignal.timeout(20000)});
    if (r.status === 204 || r.status === 404) return null;
    if (!r.ok) throw new HttpError(r.status === 429 ? 429 : 502,
      r.status === 429 ? 'Se agotó la cuota temporal del proveedor de vuelos.' : 'No se pudo consultar el proveedor de vuelos. Revisa la suscripción y la clave del servidor.');
    return r.json();
  }
  return async (req,res) => {
    try {
      const url = new URL(req.url,'http://localhost');
      if (req.method !== 'GET' || !['/api/flights/search','/api/flights/airports'].includes(url.pathname)) throw new HttpError(404,'Ruta no encontrada.');
      const token = /^Bearer ([A-Za-z0-9_.-]+)$/.exec(req.headers.authorization ?? '')?.[1];
      if (!token || token.length > 10000) throw new HttpError(401,'Inicia sesión para buscar vuelos.');
      let uid;
      try { uid = JSON.parse(Buffer.from(token.split('.')[1],'base64url')).sub; } catch {}
      if (typeof uid !== 'string' || !uid || uid.length > 128) throw new HttpError(401,'Sesión inválida.');
      // La identidad no se confía al JWT decodificado: el backend verifica su firma,
      // proyecto y expiración antes de permitir leer el perfil del mismo uid.
      const auth = await fetcher(new URL(`/api/users/${encodeURIComponent(uid)}`, authOrigin),
          {headers:{Authorization:`Bearer ${token}`}, redirect:'error', signal:AbortSignal.timeout(20000)});
      if (auth.status === 401 || auth.status === 403) throw new HttpError(auth.status,'La sesión no fue aceptada.');
      if (!auth.ok) throw new HttpError(503,'No se pudo verificar tu perfil con el backend.');
      const profile = (await auth.json())?.user;
      if (profile?.uid !== uid) throw new HttpError(403,'El perfil no corresponde a la sesión.');
      const now = Date.now();
      if (limits.size > 2000) for (const [k,v] of limits) if (now-v.start > 60000) limits.delete(k);
      const limit = limits.get(uid);
      if (limit && now-limit.start < 60000) { if (++limit.count > 20) throw new HttpError(429,'Demasiadas búsquedas. Espera un minuto.'); }
      else limits.set(uid,{start:now,count:1});
      if (url.pathname === '/api/flights/airports') {
        const query = url.searchParams.get('q')?.trim() ?? '';
        if (query.length < 3 || query.length > 80) throw new HttpError(400,'Escribe entre 3 y 80 caracteres.');
        const data = await provider('/airports/search/term',{q:query,limit:'15',withFlightInfoOnly:'true',withSearchByCode:'true'});
        if (data === null) return json(res,200,[]);
        if (!Array.isArray(data.items)) throw new HttpError(502,'Respuesta de aeropuertos inválida.');
        return json(res,200,data.items.filter(a=>/^[A-Z]{3}$/.test(a.iata)).map(a=>({iata:a.iata,label:`${a.municipalityName ?? a.name} · ${a.name} (${a.iata})`})));
      }
      const origin = url.searchParams.get('origin') ?? '', destination = url.searchParams.get('destination') ?? '', date = url.searchParams.get('date') ?? '';
      const parsed = new Date(`${date}T00:00:00Z`);
      const today = new Date(Date.now()-86400000).toISOString().slice(0,10);
      if (!/^[A-Z]{3}$/.test(origin) || !/^[A-Z]{3}$/.test(destination) || origin === destination ||
          !/^\d{4}-\d{2}-\d{2}$/.test(date) || Number.isNaN(+parsed) || parsed.toISOString().slice(0,10) !== date ||
          date < today || +parsed > Date.now()+180*86400000) throw new HttpError(400,'Revisa origen, destino y fecha (hasta 180 días).');
      const cacheKey = `${origin}:${destination}:${date}`, cached = cache.get(cacheKey);
      if (cached && now-cached.time < 120000) return json(res,200,cached.flights);
      let cities = [];
      try {
        const r = await fetcher(new URL('/api/ciudades/ciudades', authOrigin),
          {redirect:'error',signal:AbortSignal.timeout(20000)});
        const data = r.ok ? await r.json() : null;
        if (Array.isArray(data)) cities = data.filter(c=>typeof c==='string');
      } catch { /* Si el catálogo no está disponible, conservar nombre del proveedor. */ }
      const fold = s=>s.normalize('NFD').replace(/\p{Diacritic}/gu,'').toLowerCase().trim();
      const airport = async code => {
        const a = await provider(`/airports/iata/${code}`);
        if (!a || a.iata !== code || typeof a.municipalityName !== 'string') throw new HttpError(400,'Aeropuerto no encontrado o sin ciudad identificada.');
        return {iata:code, city:cities.find(c=>fold(c)===fold(a.municipalityName)) ?? a.municipalityName, country:a.countryCode ?? ''};
      };
      const from = await airport(origin), to = await airport(destination);
      // Dos ventanas de 12 h para planes con límite de 12 h por petición.
      const result = [];
      const nextDate = new Date(+parsed+86400000).toISOString().slice(0,10);
      for (const [start,end] of [[`${date}T00:00`,`${date}T12:00`],[`${date}T12:00`,`${nextDate}T00:00`]]) {
        const data = await provider(`/flights/airports/iata/${origin}/${start}/${end}`,
          {direction:'Departure', withLeg:'true', withCancelled:'false', withCodeshared:'false', withCargo:'false', withPrivate:'false'});
        if (data) result.push(...normalizeFlights(data,from,to,date));
      }
      const flights = [...new Map(result.map(f=>[`${f.number}:${f.departure}`,f])).values()];
      if (cache.size > 500) cache.clear();
      cache.set(cacheKey,{time:now,flights});
      json(res,200,flights);
    } catch (e) { json(res,e instanceof HttpError ? e.status : 502,
      {error:e instanceof HttpError ? e.message : 'El servicio de vuelos no pudo completar la consulta.'}); }
  };
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  http.createServer(createHandler()).listen(Number(process.env.PORT || 8080), '0.0.0.0',
    () => console.log('Servicio de vuelos iniciado.'));
}
