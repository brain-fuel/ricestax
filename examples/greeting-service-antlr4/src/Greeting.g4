// Tangled from service.md.
// Edit the specification, not this file.
// Every comment below is generated from the prose there.

/** Reject an empty or whitespace-only name, trim surrounding whitespace, and greet the caller.
 * The Node HTTP adapter maps rejection to 400, routes other requests to 404, and
 * JSON-encodes successful text. The antlr4 implementation below owns validation
 * and greeting construction together with the Java visitor-free driver.
 *
 * Specified by service.
 */
grammar Greeting;

/** Accept a nonempty name and consume the complete input.
 *
 * Specified by service S1.
 */
name : WORD (SPACE WORD)* EOF ;

/** A visible word retains punctuation and Unicode characters.
 *
 * Specified by service S2.
 */
WORD : ~[ \t\r\n]+ ;

/** Spaces and tabs separate words inside a name.
 *
 * Specified by service S3.
 */
SPACE : [ \t]+ ;
