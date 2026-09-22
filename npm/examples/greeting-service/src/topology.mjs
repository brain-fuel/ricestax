// Service identities come from the reviewed architecture.
/** Limits lookups to services declared by the architecture. */
export function isKnownService(id) {
  return ["greeting-api"].includes(id);
}
