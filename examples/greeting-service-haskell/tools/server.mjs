import {createServer} from 'node:http';
import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
const {run} = JSON.parse(readFileSync(new URL('../commands.json', import.meta.url)));
export function createGreetingServer() {
  return createServer((request,response)=>{
    const url=new URL(request.url,'http://localhost');
    response.setHeader('content-type','application/json');
    if(request.method!=='GET'||url.pathname!=='/greet') {
      response.writeHead(404).end(JSON.stringify({error:'Not found'})); return;
    }
    const child=spawnSync(run[0],[...run.slice(1),url.searchParams.get('name')??''],{encoding:'utf8',timeout:10000});
    if(child.error || (child.status!==0 && child.status!==2)) {
      response.writeHead(500).end(JSON.stringify({error:'Greeting process failed'})); return;
    }
    if(child.status===2) {
      response.writeHead(400).end(JSON.stringify({error:'A nonempty name is required'})); return;
    }
    response.end(JSON.stringify({greeting:child.stdout.replace(/\r?\n$/,'')}));
  });
}
if(process.argv[1]===new URL(import.meta.url).pathname) createGreetingServer().listen(8097,'127.0.0.1');
