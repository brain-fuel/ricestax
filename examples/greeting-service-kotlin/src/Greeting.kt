// Tangled from service.md.
// Edit the specification, not this file.
// Every comment below is generated from the prose there.

/** Reject an empty or whitespace-only name, trim surrounding whitespace, and greet the caller.
 * The Node HTTP adapter maps rejection to 400, routes other requests to 404, and
 * JSON-encodes successful text. The kotlin implementation below owns validation
 * and greeting construction.
 *
 * Specified by service.
 */
fun main(args: Array<String>) {
    val name = args[0].trim()
    if (name.isEmpty()) kotlin.system.exitProcess(2)
    println("Hello, " + name + "!")
}
