import {mkdirSync, readdirSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {delimiter} from 'node:path';
function run(command, args) {
  const result = spawnSync(command, args, {stdio: 'inherit'});
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 2);
}
mkdirSync('build', {recursive: true});
run('mvn', ['-q', 'org.apache.maven.plugins:maven-dependency-plugin:3.8.1:copy-dependencies', '-DoutputDirectory=build/dependency']);
run('javac', ['-cp', 'build/dependency/*', '-d', 'build', 'src/Greeting.java', 'test/GreetingTest.java']);
