// Tangled from service.md.
// Edit the specification, not this file.
// Every comment below is generated from the prose there.

/** Reject an empty or whitespace-only name, trim surrounding whitespace, and greet the caller.
 * The Node HTTP adapter maps rejection to 400, routes other requests to 404, and
 * JSON-encodes successful text. The typescript implementation below owns validation
 * and greeting construction.
 *
 * Specified by service.
 */
export function greetingFor(input: string): string {
  const name = input.trim();
  if (name.length === 0) throw new Error('A nonempty name is required');
  return 'Hello, ' + name + '!';
}
