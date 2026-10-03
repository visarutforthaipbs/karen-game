import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';

// Exercise the Worker handler without Cloudflare credentials or live R2 writes.
const source = await readFile(new URL('../../server/download/worker.js', import.meta.url), 'utf8');
const { default: worker } = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
const origin = 'https://downloads.example';
function object({ conditional = false, range = null } = {}) {
  return {
    size: 8, httpEtag: '"fixture"', range,
    ...(conditional ? {} : { body: new Blob(['ZIPBYTES']).stream() }),
    writeHttpMetadata(headers) { headers.set('Content-Type', 'application/zip'); },
  };
}
function bucket(value) {
  const calls = [];
  return { calls, async get(key, options) { calls.push({ key, options }); return value; } };
}
for (const version of [1, 2, 3]) {
  test(`beta${version} retains versioned download and HEAD`, async () => {
    const key = `beta${version}/UnderTwoSkies-macOS.zip`;
    let store = bucket(object());
    let response = await worker.fetch(new Request(`${origin}/${key}`), { BUCKET: store });
    assert.equal(response.status, 200);
    assert.equal(await response.text(), 'ZIPBYTES');
    assert.equal(response.headers.get('Content-Length'), '8');
    assert.equal(response.headers.get('Content-Disposition'), 'attachment; filename="UnderTwoSkies-macOS.zip"');
    assert.equal(store.calls[0].key, key);
    store = bucket(object());
    response = await worker.fetch(new Request(`${origin}/${key}`, { method: 'HEAD' }), { BUCKET: store });
    assert.equal(response.status, 200);
    assert.equal(await response.text(), '');
    assert.equal(response.headers.get('Content-Length'), '8');
  });
}
test('range request forwards R2 headers and responds with a partial body', async () => {
  const store = bucket(object({ range: { offset: 2, length: 3 } }));
  const response = await worker.fetch(new Request(`${origin}/beta3/UnderTwoSkies-Linux.zip`, { headers: { Range: 'bytes=2-4' } }), { BUCKET: store });
  assert.equal(response.status, 206);
  assert.equal(response.headers.get('Content-Range'), 'bytes 2-4/8');
  assert.equal(response.headers.get('Accept-Ranges'), 'bytes');
  assert.equal(store.calls[0].options.range.get('Range'), 'bytes=2-4');
});
test('conditional unchanged response has no body', async () => {
  const store = bucket(object({ conditional: true }));
  const response = await worker.fetch(new Request(`${origin}/beta3/UnderTwoSkies-Windows.zip`, { headers: { 'If-None-Match': '"fixture"' } }), { BUCKET: store });
  assert.equal(response.status, 304);
  assert.equal(await response.text(), '');
  assert.equal(store.calls[0].options.onlyIf.get('If-None-Match'), '"fixture"');
});
test('missing archives return 404', async () => {
  const response = await worker.fetch(new Request(`${origin}/beta3/missing.zip`), { BUCKET: bucket(null) });
  assert.equal(response.status, 404);
});
test('unknown release prefixes do not reach storage', async () => {
  const store = bucket(object());
  const response = await worker.fetch(new Request(`${origin}/beta4/missing.zip`), { BUCKET: store });
  assert.equal(response.status, 404);
  assert.equal(store.calls.length, 0);
});
test('writes and malformed percent encoding never reach R2', async () => {
  const store = bucket(object());
  let response = await worker.fetch(new Request(`${origin}/beta3/file.zip`, { method: 'POST' }), { BUCKET: store });
  assert.equal(response.status, 405);
  response = await worker.fetch(new Request(`${origin}/beta3/file%ZZ.zip`), { BUCKET: store });
  assert.equal(response.status, 400);
  assert.equal(store.calls.length, 0);
});
test('checksums remain readable without an attachment disposition', async () => {
  const response = await worker.fetch(new Request(`${origin}/beta3/SHA256SUMS.txt`), { BUCKET: bucket(object()) });
  assert.equal(response.status, 200);
  assert.equal(response.headers.has('Content-Disposition'), false);
});
for (const path of ['/', '/th/', '/th', '/en/', '/en']) {
  test(`bilingual latest-release page ${path}`, async () => {
    const response = await worker.fetch(new Request(origin + path), {});
    assert.equal(response.status, 200);
    const html = await response.text();
    assert.match(html, path.startsWith('/en') ? /<html lang="en">/ : /<html lang="th">/);
    for (const os of ['Windows', 'macOS', 'Linux']) assert.ok(html.includes(`/beta3/UnderTwoSkies-${os}.zip`));
    assert.ok(html.includes('/beta3/SHA256SUMS.txt'));
    assert.ok(html.includes('0.3.0'));
    assert.ok(!/Thai only|Thai-language beta|ภาษาไทยเท่านั้น|beta 2|เบตา 2/.test(html));
  });
}
