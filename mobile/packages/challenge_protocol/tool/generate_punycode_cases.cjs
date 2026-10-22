// Offline reference vectors from the retained, checksummed MIT upstream codec.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const source = path.join(root, 'third_party/tr46/punycode.js');
const hash = crypto.createHash('sha256').update(fs.readFileSync(source)).digest('hex');
if (hash !== '6052a80eac47e46bd4de17ae0095e0192c336d3d7c387d292ad2176ebfc53d04') {
  throw Error('Punycode reference source changed');
}
const codec = require(source);
let seed = 0x3492;
function next() {
  seed ^= seed << 13; seed ^= seed >>> 17; seed ^= seed << 5;
  return seed >>> 0;
}
const alphabet = [0x61, 0x62, 0x2d, 0x30, 0xe0, 0x301, 0x316, 0x5d0,
  0x1f600, 0x10ffff, 0x10000];
const input = ['', 'a', '-', 'bücher', 'mañana', '例え',
  'a' + '\u0301'.repeat(28000),
  String.fromCodePoint(...Array.from({length: 12000}, (_, i) => 0x10000 + i)),
  String.fromCodePoint(...Array.from({length: 12000}, (_, i) => 0x10000 + 11999 - i))];
for (let i = 0; i < 192; i++) {
  input.push(Array.from({length: next() % 100}, () =>
    String.fromCodePoint(alphabet[next() % alphabet.length])).join(''));
}
const encode = input.map(value => {
  try { return {input: value, output: codec.encode(value)}; }
  catch { return {input: value, output: null}; }
});
const encoded = ['-', 'a-', 'a', 'z', '\u0080-', '/', '9999999999999999999',
  'a'.repeat(58000), ...encode.filter(row => row.output !== null).map(row => row.output)];
for (let i = 0; i < 128; i++) {
  encoded.push(Array.from({length: next() % 30}, () =>
    'abcXYZ019-/'[next() % 11]).join(''));
}
const decode = encoded.map(value => {
  try { return {input: value, output: codec.decode(value)}; }
  catch { return {input: value, output: null}; }
});
fs.writeFileSync(path.join(root, 'test/fixtures/punycode-reference.json'),
  JSON.stringify({encode, decode}) + '\n');
console.log(`${encode.length} encode and ${decode.length} decode reference vectors`);
