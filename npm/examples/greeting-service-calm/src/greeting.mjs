// Tangled from service.md.
// Edit the specification, not this file.
// Every comment below is generated from the prose there.

/** Empty names must fail so callers cannot mistake a missing identity for a successful greeting.
 *
 * Specified by service S1.
 */
export function greetingFor(name) {
  if (typeof name !== 'string' || name.trim().length === 0) {
    throw new Error('A nonempty name is required');
  }
  return { greeting: `Hello, ${name.trim()}!` };
}
