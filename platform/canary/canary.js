const https = require('https');
const http = require('http');
const synthetics = require('Synthetics');
const log = require('SyntheticsLogger');

const CANARY_TOKEN = process.env.CANARY_TOKEN || 'eerf-canary-token';

function getStatus(targetUrl) {
  const parsed = new URL(targetUrl);
  const client = parsed.protocol === 'https:' ? https : http;
  const options = {
    hostname: parsed.hostname,
    port: parsed.port || (parsed.protocol === 'https:' ? 443 : 80),
    path: parsed.pathname + parsed.search,
    method: 'GET',
    timeout: 10000,
    headers: { 'x-canary-token': CANARY_TOKEN }
  };
  return new Promise((resolve) => {
    const req = client.request(options, (res) => {
      res.resume();
      resolve({ url: targetUrl, statusCode: res.statusCode, ok: res.statusCode >= 200 && res.statusCode < 400 });
    });
    req.on('timeout', () => { req.destroy(); resolve({ url: targetUrl, statusCode: 0, ok: false, error: 'timeout' }); });
    req.on('error', (err) => { resolve({ url: targetUrl, statusCode: 0, ok: false, error: err.message }); });
    req.end();
  });
}

exports.handler = async () => {
  const cfUrl = process.env.CLOUDFRONT_URL;
  const originUrl = process.env.ORIGIN_URL;

  log.info(`CDN check: ${cfUrl}`);
  log.info(`Origin check: ${originUrl}`);

  const [cdnResult, originResult] = await Promise.all([
    getStatus(cfUrl),
    getStatus(originUrl),
  ]);

  log.info(`CDN: ${JSON.stringify(cdnResult)}`);
  log.info(`Origin: ${JSON.stringify(originResult)}`);

  // Canary PASS condition: CDN OK OR Origin OK
  // Canary FAIL condition: CDN FAIL AND Origin OK (= Edge-only failure)
  if (!cdnResult.ok && originResult.ok) {
    throw new Error(`CDN path failed (${cdnResult.statusCode}) but Origin OK - Edge failure detected`);
  }

  if (!cdnResult.ok && !originResult.ok) {
    throw new Error(`Both CDN and Origin failed - Infrastructure issue (not Edge-only)`);
  }

  return 'PASSED: CDN path healthy';
};
