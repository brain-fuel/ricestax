import {spawnSync} from 'node:child_process';
const commands = [
  ['python3', '-m', 'venv', 'build/venv'],
  ['build/venv/bin/python3', '-m', 'pip', 'install', '--disable-pip-version-check', '-r', 'requirements-test.txt'],
  ['build/venv/bin/python3', '-m', 'py_compile', 'src/greeting.py', 'test/test_service.py'],
];
for (const [command, ...args] of commands) {
  const result = spawnSync(command, args, {stdio: 'inherit'});
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 2);
}
