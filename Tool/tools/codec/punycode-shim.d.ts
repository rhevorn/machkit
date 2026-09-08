declare module "punycode/punycode.es6.js" {
  export function toASCII(input: string): string;
  export function toUnicode(input: string): string;
  export function encode(input: string): string;
  export function decode(input: string): string;
}
